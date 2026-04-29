---
layout: post.liquid
title: "Replacing a Failed Kubernetes Node with NVMe Boot on Raspberry Pi 5"
date: 2026-04-28 22:30:00 +0200
categories: blog
tags: [Kubernetes, Raspberry Pi, DevOps, NVMe, Debian]
description:
  "Step-by-step rebuild of a failed Kubernetes control plane node on a Raspberry Pi 5 — booted directly from NVMe, joined
  back into the existing HA cluster, and migrated to Kubernetes 1.32 on Debian Trixie."
excerpt:
  "When my SD card died after a power blip, I rebuilt the node booting straight from NVMe and took the opportunity to
  migrate to Kubernetes 1.32 on Debian Trixie. Here are the steps that worked — and the Trixie gotchas that didn't."
keywords:
  "Kubernetes, Raspberry Pi 5, NVMe boot, Debian Trixie, kubeadm, control plane, HA cluster, containerd, flannel"
image: /assets/guides/building-a-production-ready-kubernetes-cluster-from-scratch/hardware-overview.webp
author: Philip Niedertscheider
---

Node 2 of my home Kubernetes cluster started misbehaving after a power blip — the SD card it booted from took a hit and
the OS refused to come back up. The node already had an NVMe SSD attached via the Pi 5's M.2 HAT, so this was the
perfect excuse to rebuild it the way it should have been from the start: booted directly from NVMe, on Debian Trixie,
and migrated from Kubernetes 1.31 to 1.32.

This is a short companion piece to my
[Building a production-ready Kubernetes cluster from scratch](/guides/building-a-production-ready-kubernetes-cluster-from-scratch)
guide. I'll point at the relevant lessons rather than repeat them, and call out the parts that needed adjusting on
Trixie.

## Flashing the OS straight to the NVMe

With a keyboard, monitor, and Ethernet cable attached, I booted the Pi 5 with **Shift** held down to enter the network
install. From there I picked _Raspberry Pi OS Lite (64-bit)_ and selected the NVMe disk as the install target.

(See [lesson 5 — Flashing Raspberry Pi OS](/guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-5)
for the full flow.)

After first boot I ran `raspi-config` to:

1. Set the boot order to **B2 NVMe / USB Boot** (advanced options) so the system always picks NVMe over any SD card.
2. Set the locale.
3. Enable SSH (interface options), so the keyboard and monitor could go away.

Because the OS is installed straight to the NVMe partition, the storage prep from
[lesson 6](/guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-6) isn't needed — `lsblk -f`
already shows `nvme0n1p2` mounted at `/` as ext4.

## Static IP and SSH key

Following [lesson 7](/guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-7), I assigned a static
IP via NetworkManager and copied my cluster SSH key over:

```bash
nmcli connection modify "Wired connection 1" \
  ipv4.method manual \
  ipv4.addresses "10.1.1.2/16" \
  ipv4.gateway "10.1.0.1" \
  ipv4.dns "10.1.0.1" \
  autoconnect yes
nmcli connection up "Wired connection 1"

ssh-copy-id -i ~/.ssh/k8s_cluster_id_ed25519 pi@10.1.1.2
```

Then the baseline firewall (deny all in/out, allow SSH and outbound DNS/NTP/HTTP/HTTPS) and the ICMP fix from
[lesson 7](/guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-7).

## Kubernetes tools — and a small version drift

I'm running 1.31 on the rest of the cluster. Since this was a clean install I took the opportunity to start migrating
to 1.32 — the kubeadm skew policy allows the control plane components to drift by one minor, so a 1.31/1.32 mix is
fine.

Following [lesson 8](/guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-8), but with the
`v1.32` repo:

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' \
  > /etc/apt/sources.list.d/kubernetes.list
apt update && apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
```

## Container runtime — first Trixie gotcha

Installing containerd, configuring `SystemdCgroup = true`, and pointing `root` at the NVMe path is exactly as in
[lesson 9](/guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-9).

**But Debian 13 (Trixie) ships a containerd whose default CNI `bin_dir` is `/usr/lib/cni`, not `/opt/cni/bin`.** The
Flannel daemonset installs its CNI binary into `/opt/cni/bin` (the upstream default), so containerd will fail every
sandbox creation with `failed to find plugin "flannel" in path [/usr/lib/cni]` and pods stay stuck in
`ContainerCreating`. Fix it before joining:

```bash
sudo sed -i 's|bin_dir = "/usr/lib/cni"|bin_dir = "/opt/cni/bin"|' /etc/containerd/config.toml
sudo systemctl restart containerd
```

This is not needed on Bookworm — Bookworm's containerd defaults to `/opt/cni/bin` already.

## Preparing the node — second Trixie gotcha

Disable swap (including zram, which Raspberry Pi OS now ships by default):

```bash
swapoff -a
systemctl mask systemd-zram-setup@zram0
```

Load the kernel modules and apply sysctl from
[lesson 10](/guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-10), then enable cgroups in
`/boot/firmware/cmdline.txt`. Install `chrony` (replacing `systemd-timesyncd`) to keep the clock in line.

The Trixie gotcha here only bit me later (when configuring HAProxy/Keepalived), so I'll explain it in that section, but
it's worth fixing up front: **on Trixie, `systemd-sysctl` no longer reads `/etc/sysctl.conf` at boot.** It only loads
files under `/etc/sysctl.d/`, `/run/sysctl.d/`, and `/usr/lib/sysctl.d/`. So put all your custom kernel parameters into
`/etc/sysctl.d/k8s.conf`, not `/etc/sysctl.conf`:

```ini
# /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.ipv4.ip_nonlocal_bind           = 1   # needed for HAProxy on backup nodes (see lesson 15)
```

Apply with `sudo sysctl --system`.

## Joining as an additional control plane

Open the cluster ports for intra-node traffic per
[lesson 12](/guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-12) and
[lesson 13](/guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-13), then on an existing master:

```bash
kubeadm token create --print-join-command
kubeadm init phase upload-certs --upload-certs
```

### Cleaning up etcd before joining

Because the failed node had previously been a member of the cluster, etcd still listed it. Trying to join would fail
with `can only promote a learner member which is in sync with leader`. List and remove the stale member from any
working master:

```bash
kubectl -n kube-system exec etcd-kubernetes-node-1 -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list

# remove the stale node-2 member by ID
kubectl -n kube-system exec etcd-kubernetes-node-1 -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member remove <member-id>
```

Then on the new node, run the join command with `--control-plane` and the certificate key from `upload-certs`.

After that, install Flannel and open up its firewall rules per
[lesson 12](/guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-12) (or just wait for the
DaemonSet to schedule a pod on the new node — the existing install covers it).

## HAProxy and Keepalived — three things lesson 15 doesn't warn about

[Lesson 15](/guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-15) walks through Keepalived +
HAProxy in detail, so I won't repeat the configs. Three things tripped me up specifically on Trixie / on a node joining
an existing HA setup:

**1. `ip_nonlocal_bind` only sticks if it's in `/etc/sysctl.d/`.** The lesson tells you to add it to
`/etc/sysctl.conf` and run `sudo sysctl -p`. That works for the current session, but as noted above, Trixie won't
re-read `/etc/sysctl.conf` on the next boot. After a reboot, HAProxy starts before Keepalived has assigned the VIP
locally, tries to bind to `10.1.233.1:*`, and silently fails because `ip_nonlocal_bind=0`. The result is HAProxy
"running" with zero TCP listeners. Put the setting in `/etc/sysctl.d/k8s.conf` (as shown earlier) and it survives
reboot.

**2. ufw needs an outbound rule for the VIP itself.** The lesson's intra-node rule allows TCP out to `10.1.1.0/24:6443`,
which covers the real node IPs but **not** the VIP at `10.1.233.1`. The VIP responds to ping (ICMP isn't gated by ufw's
defaults), so the breakage is easy to misdiagnose. Add explicit rules:

```bash
sudo ufw allow out to 10.1.233.1 port 6443  proto tcp comment 'k8s API VIP'
sudo ufw allow out to 10.1.233.1 port 80    proto tcp comment 'ingress VIP (HTTP)'
sudo ufw allow out to 10.1.233.1 port 443   proto tcp comment 'ingress VIP (HTTPS)'
sudo ufw allow out to 10.1.233.1 port 30053 proto tcp comment 'CoreDNS VIP'
sudo ufw reload
```

**3. Verify HAProxy actually listens.** `systemctl status haproxy` happily reports `active (running)` even when every
single bind silently failed. Always check with `ss`:

```bash
sudo ss -tlnp | grep haproxy
# expected:
# LISTEN ... 10.1.233.1:6443  ... ("haproxy",...)
# LISTEN ... 10.1.233.1:80    ...
# LISTEN ... 10.1.233.1:443   ...
# LISTEN ... 10.1.233.1:30053 ...
```

Once those four entries are there, point your local kubeconfig at the VIP and confirm round-robin works:

```bash
sed -i 's|server: https://10.1.1.2:6443|server: https://10.1.233.1:6443|' ~/.kube/config
for i in 1 2 3 4 5; do curl -k -s https://10.1.233.1:6443/healthz; echo; done
```

## Longhorn host dependencies

If your cluster uses [Longhorn](/guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-17), the
`longhorn-manager` DaemonSet will land on the new node as soon as it joins, and crash-loop until you install the iSCSI
client tooling on the host:

```
fatal ... please make sure you have iscsiadm/open-iscsi installed on the host
```

Install both iSCSI and NFS clients (NFS is needed for `ReadWriteMany` volumes), and enable iscsid:

```bash
sudo apt install -y open-iscsi nfs-common
sudo systemctl enable --now iscsid
```

The crash-looping `longhorn-manager` pod will recover on its next restart — no kubectl action needed.

## Letting workloads schedule on the new node

`kubeadm join --control-plane` adds `node-role.kubernetes.io/control-plane:NoSchedule` to the new node, which prevents
ordinary workloads from landing there. If your other masters are running workloads (mine are — small home cluster,
every Pi pulls weight), remove the taint:

```bash
kubectl taint nodes kubernetes-node-2 node-role.kubernetes.io/control-plane:NoSchedule-
```

A quick sanity check that the node both reaches the apiserver _and_ runs pods end-to-end:

```bash
kubectl run sched-check --image=busybox:1.36 --restart=Never --overrides='
  {"spec":{"nodeName":"kubernetes-node-2"}}' \
  --command -- sh -c 'echo running on $(hostname)'
kubectl logs sched-check
kubectl delete pod sched-check
```

## What I'd add to the guide

The Trixie-specific findings (containerd `bin_dir`, `sysctl.d` vs `sysctl.conf`, the missing VIP outbound ufw rules)
only really matter when bringing up a node on Debian 13. The Longhorn `open-iscsi` step applies to any new node, but
the existing nodes already have it from their original install, so it's only a surprise when you add a fresh one. I'll
fold all of these into the guide as warnings on the relevant lessons (9, 10, 15, 17). Until then — if you're following
the guide on Trixie or on a Pi 5 with NVMe boot, the steps above are what you'll want to layer on top.

If you found this helpful, the full guide is free at
[Building a production-ready Kubernetes cluster from scratch](/guides/building-a-production-ready-kubernetes-cluster-from-scratch).
You can support its continued maintenance via
[GitHub Sponsors](https://github.com/sponsors/philprime). 🙏
