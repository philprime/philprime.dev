---
layout: guide-lesson.liquid
title: Setting Up Container Runtime

guide_component: lesson
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
guide_section_id: 3
guide_lesson_id: 9
guide_lesson_abstract: >
  Set up container runtime to run containers on your Raspberry Pi devices as part of the Kubernetes cluster.
guide_lesson_conclusion: >
  With containerd installed and configured, your Raspberry Pi devices are now ready to run containers as part of the
  Kubernetes cluster.
repo_file_path: guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-9.md
---

In this lesson, we will set up **containerd** as the container runtime on each Raspberry Pi device. Containerd is a
lightweight and efficient container runtime that is widely used in Kubernetes environments due to its simplicity and
compatibility with Kubernetes' container runtime interface (CRI).

{% include guide-overview-link.liquid.html %}

{% include alert.liquid.html type='warning' title='WARNING:' content='
All commands used in this lesson require <code>sudo</code> privileges.
Either prepend <code>sudo</code> to each command or switch to the root user using <code>sudo -i</code>.
' %}

## Preparing the NVMe Directory

First, create the directory where containerd will be installed:

```bash
$ mkdir -p /mnt/nvme/containerd
```

## Installing containerd on Each Raspberry Pi

To begin, make sure you are connected to each Raspberry Pi via SSH. Perform the following steps on each device:

Update the package list and install required dependencies:

```bash
$ apt update
$ apt install -y apt-transport-https curl gnupg2 software-properties-common
```

Next, install containerd:

```bash
$ apt install -y containerd
```

## Configuring containerd

Once containerd is installed, we need to configure it properly to work with Kubernetes and use the NVMe drive.

First, stop the containerd service:

```bash
$ systemctl stop containerd
```

Create a default configuration file for containerd:

```bash
$ mkdir -p /etc/containerd
$ containerd config default | tee /etc/containerd/config.toml
```

## Configuring containerd Storage and Runtime

Now we'll modify the configuration to use the NVMe drive for storage for any persistent data and configure the system
cgroup driver. Open the configuration file with a text editor like `vim` or `nano`:

```bash
$ vim /etc/containerd/config.toml
```

At the top of the file, find the line that specifies the `root` setting which is the directory where containerd will
store its data:

```toml
root = "/mnt/nvme/containerd"
```

Change the value to the path of the NVMe drive:

```toml
root = "/mnt/nvme/containerd"
```

## Configuring containerd for Kubernetes

We need to configure the system cgroup driver to `systemd` because we are using the `systemd` cgroup driver. `cgroup` is
a Linux kernel feature that limits the resources that can be used by a process.

In the same section as the `root` setting, we need to configure the `SystemdCgroup` setting to `true`:

```toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
SystemdCgroup = true
```

Save the changes and exit the editor (in `vi`, press `Esc` followed by `:wq` and `Enter`).

## Starting containerd Service

Restart containerd to apply the configuration changes and enable it to start on boot:

```bash
$ systemctl enable containerd
$ systemctl restart containerd
```

## Verifying containerd Installation

To confirm that containerd is installed and configured correctly, check the status of the containerd service:

```bash
$ systemctl status containerd
● containerd.service - containerd container runtime
     Loaded: loaded (/lib/systemd/system/containerd.service; enabled; preset: enabled)
     Active: active (running) since Sun 2025-01-12 20:16:00 CET; 21s ago
       Docs: https://containerd.io
   Main PID: 4629 (containerd)
      Tasks: 10
        CPU: 86ms
     CGroup: /system.slice/containerd.service
             └─4629 /usr/bin/containerd

Jan 12 20:16:00 kubernetes-node-1 containerd[4629]: time="2025-01-12T20:16:00.483721289+01:00" level=info msg="Start subscribing containerd event"
Jan 12 20:16:00 kubernetes-node-1 containerd[4629]: time="2025-01-12T20:16:00.483770622+01:00" level=info msg="Start recovering state"
Jan 12 20:16:00 kubernetes-node-1 containerd[4629]: time="2025-01-12T20:16:00.483840678+01:00" level=info msg="Start event monitor"
Jan 12 20:16:00 kubernetes-node-1 containerd[4629]: time="2025-01-12T20:16:00.483866549+01:00" level=info msg="Start snapshots syncer"
Jan 12 20:16:00 kubernetes-node-1 containerd[4629]: time="2025-01-12T20:16:00.483879086+01:00" level=info msg="Start cni network conf syncer for default"
Jan 12 20:16:00 kubernetes-node-1 containerd[4629]: time="2025-01-12T20:16:00.483890030+01:00" level=info msg="Start streaming server"
Jan 12 20:16:00 kubernetes-node-1 containerd[4629]: time="2025-01-12T20:16:00.484237568+01:00" level=info msg=serving... address=/run/containerd/containerd.sock.ttrpc
Jan 12 20:16:00 kubernetes-node-1 containerd[4629]: time="2025-01-12T20:16:00.484282883+01:00" level=info msg=serving... address=/run/containerd/containerd.sock
Jan 12 20:16:00 kubernetes-node-1 systemd[1]: Started containerd.service - containerd container runtime.
Jan 12 20:16:00 kubernetes-node-1 containerd[4629]: time="2025-01-12T20:16:00.485584240+01:00" level=info msg="containerd successfully booted in 0.038755s"
```

To verify that containerd is using the NVMe drive for storage, check the log output of the containerd service:

```bash
$ journalctl -u containerd
...
Mar 16 16:40:53 kubernetes-node-1 containerd[20982]: time="2025-03-16T16:40:53.491421451+01:00" level=info msg="Connect containerd service"
Mar 16 16:40:53 kubernetes-node-1 containerd[20982]: time="2025-03-16T16:40:53.491479507+01:00" level=info msg="Get image filesystem path \"/mnt/nvme/containerd/io.containerd.snapshotter.v1.overlayfs\""
...
```

The output should show that the containerd service is active and running, now using the NVMe drive for storage.
