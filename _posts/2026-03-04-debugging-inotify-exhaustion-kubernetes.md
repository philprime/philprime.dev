---
layout: post.liquid
title: "Debugging inotify instance exhaustion on a busy Kubernetes node"
date: 2026-03-04 23:00:00 +0100
categories: blog
tags: Kubernetes RKE2 Linux sysctl inotify debugging infrastructure bare-metal
description: "How to diagnose and fix inotify instance exhaustion on a Kubernetes node running 50+ pods, where the default max_user_instances limit of 128 silently breaks file watching for containers."
excerpt: "A busy Kubernetes node started failing with too many open files errors. The culprit was the default inotify max_user_instances limit of 128, quietly exhausted by containerd-shim processes."
keywords: "Kubernetes, inotify, max_user_instances, containerd, RKE2, sysctl, too many open files, debugging, Linux kernel tuning"
author: Philip Niedertscheider
---

One of our RKE2 Kubernetes nodes started showing intermittent "too many open files" errors.
The node was running fine for days, but as CI runner pods churned and new workloads landed on the machine, things started breaking in subtle ways.
Containers failed to start, file watchers stopped working, and build jobs timed out without clear reasons.

## The Problem

Linux uses the inotify subsystem to let processes watch files and directories for changes.
Every process that needs file watching (and on a Kubernetes node, that includes containerd shims, kubelet, the API server, and your actual workloads) creates inotify instances.
The kernel enforces a per-user limit on how many instances can exist simultaneously, controlled by `fs.inotify.max_user_instances`.

The default value on most Linux distributions is `128`.
On a Kubernetes node running 50+ pods, that number is far too low.

## The Symptoms

The symptoms were not obvious at first glance.
Pod scheduling appeared normal, `kubectl get pods` showed everything as `Running`, and system memory and CPU looked healthy.
The errors surfaced inside containers and in kubelet logs as generic "too many open files" messages, which can point to many different causes.

The first step was checking the current limits and actual usage:

```bash
$ sysctl fs.inotify.max_user_instances
fs.inotify.max_user_instances = 128

$ find /proc/*/fd -lname anon_inode:inotify 2>/dev/null | wc -l
132
```

The node had 132 inotify file descriptors open against a limit of 128.
It was already over the limit, and any new process requesting an inotify instance would fail.

## Debugging

The next question was which processes consumed all those instances.
A quick script groups inotify usage by PID and maps each process to its command line and cgroup (to identify containerized processes):

```bash
$ find /proc/*/fd -lname anon_inode:inotify 2>/dev/null | \
    awk -F'/' '{print $3}' | sort | uniq -c | sort -rn | head -10
7 3828842  kubelet
7 24457    kube-apiserver
6 25203    kube-controller-manager
5 1        systemd
4 3975178  containerd-shim-runc
3 3971310  containerd-shim-runc
3 3613610  containerd-shim-runc
3 2855897  containerd-shim-runc
2 944981   containerd-shim-runc
2 943671   containerd-shim-runc
```

No single process was misbehaving.
The kubelet needed 7 instances, the API server another 7, and the controller manager 6.
On top of that, every pod on the node spawns a `containerd-shim-runc` process that typically uses 2 to 4 instances each.

A count of pods on the node confirmed the scale of the problem:

```bash
$ kubectl get pods --all-namespaces --field-selector spec.nodeName=juggernaut --no-headers | wc -l
53
```

With 53 pods, each needing a containerd shim, plus the system-level Kubernetes components, systemd, and containerd itself, the math works out to roughly 130+ instances.
The default limit of 128 had no chance.

## The Solution

The fix is a one-line sysctl change.
Increase `fs.inotify.max_user_instances` to a value that provides comfortable headroom for the number of pods the node runs.

For a node running up to 60 pods, `2048` provides roughly 10x the needed capacity.
For larger nodes running 100+ pods, values of `4096` or `8192` are common.
The instances themselves are lightweight kernel structures, so higher values have negligible memory impact.

To apply immediately and persist across reboots, create (or update) a sysctl configuration file:

```ini
# /etc/sysctl.d/99-kubernetes.conf
fs.inotify.max_user_watches = 502453
fs.inotify.max_user_instances = 2048
fs.inotify.max_queued_events = 16384
net.core.somaxconn = 65535
vm.swappiness = 0
```

Then reload:

```bash
$ sysctl --system
```

The `max_user_watches` setting controls how many individual files can be watched across all instances, and defaults to a reasonable value on most systems.
The `somaxconn` increase helps with socket connection backlogs on nodes handling many services, and disabling swap with `swappiness = 0` is a Kubernetes best practice to avoid unpredictable latency.

We applied this across all four nodes in the cluster, using a higher `max_user_instances` of `8192` for the largest node (running 115 pods) and `2048` for the three smaller ones.
At the same time, we consolidated several fragmented sysctl files (`99-inotify.conf`, `99-file-max.conf`, `99-k3s-ci.conf`) into a single `99-kubernetes.conf` per node to make future maintenance simpler.

## Verification

After applying the changes, a quick check confirmed the new limits were active:

```bash
$ sysctl fs.inotify.max_user_instances
fs.inotify.max_user_instances = 2048
```

The "too many open files" errors stopped immediately, and pod scheduling returned to normal.

## Conclusion

The default `fs.inotify.max_user_instances` value of `128` is too low for any Kubernetes node running more than a handful of pods.
Each container's containerd shim consumes 2 to 4 inotify instances, and system components like kubelet and the API server add another 20 or so.
A node with 50 pods blows through the default limit without any single process doing anything unusual.

If you run bare-metal or self-managed Kubernetes clusters, adding inotify tuning to your node provisioning process saves you from debugging this the hard way.
The fix takes 30 seconds, the debugging takes an afternoon.
