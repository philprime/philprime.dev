---
layout: course-lesson
title: Preparing Nodes for Kubernetes Initialization (L10)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-10
---

In this lesson, we will prepare each Raspberry Pi node for Kubernetes
initialization. This involves ensuring that all nodes meet the necessary system
requirements and configurations to join the Kubernetes cluster. By the end of
this lesson, your nodes will be ready to initialize the control plane and join
additional worker nodes.

This is the tenth lesson in the series on building a production-ready Kubernetes
cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-9)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## Updating System Settings for Kubernetes

Before initializing the Kubernetes cluster, we need to adjust some system
settings to optimize the nodes for Kubernetes:

- Disable swap on each Raspberry Pi. Kubernetes requires swap to be disabled to
  function correctly:

  ```bash
  $ sudo swapoff -a
  ```

  To make this change permanent, edit the `/etc/fstab` file and remove the swap
  entry. If your system uses `dphys-swapfile`, you will see the following line
  in the file:

  ```bash
  $ sudo vi /etc/fstab
  # a swapfile is not a swap partition, no line here
  #   use  dphys-swapfile swap[on|off]  for that
  ```

  To disable the `dphys-swapfile` service, remove the system service by running:

  ```bash
  $ sudo dphys-swapfile swapoff
  $ sudo systemctl stop dphys-swapfile
  $ sudo systemctl disable dphys-swapfile
  ```

  To verify that swap is disabled, reboot the system, and run the following
  command:

  ```bash
  $ free -h
  ```

  It should show 0 bytes of free swap.

- Ensure that all necessary kernel modules are loaded. Run the following
  commands to load the required modules:

  ```bash
  $ sudo modprobe overlay
  $ sudo modprobe br_netfilter
  ```

  To make these changes persistent, create a configuration file:

  ```bash
  $ touch /etc/modules-load.d/k8s.conf
  $ sudo tee /etc/modules-load.d/k8s.conf <<EOF
  overlay
  br_netfilter
  EOF
  ```

- Adjust the sysctl settings for Kubernetes networking. Configure the necessary
  settings using:

  ```bash
  $ sudo tee /etc/sysctl.d/k8s.conf <<EOF
  net.bridge.bridge-nf-call-iptables  = 1
  net.ipv4.ip_forward                 = 1
  net.bridge.bridge-nf-call-ip6tables = 1
  EOF
  ```

  Apply the changes:

  ```bash
  $ sudo sysctl --system
  ```

## Enable CGroup Memory

Kubernetes requires the memory cgroup memory controller to be enabled on the
Raspberry Pi nodes.

```bash
$ cat /proc/cgroups
#subsys_name  hierarchy  num_cgroups  enabled
cpuset        0          55           1
cpu           0          55           1
cpuacct       0          55           1
blkio         0          55           1
memory        0          55           0
devices       0          55           1
freezer       0          55           1
net_cls       0          55           1
perf_event    0          55           1
net_prio      0          55           1
pids          0          55           1
```

If the `memory` cgroup is not enabled, you will need to enable it by appending
`cgroup_memory=1 cgroup_enable=memory` to the boot command line in the
`/boot/cmdline.txt` file using `nano` or `vi`:

```bash
$ sudo vi /boot/cmdline.txt
```

> [!WARNING] If the file contains a warning with "The file you are looking for
> has moved to /boot/firmware/cmdline.txt", you should edit the file at
> `/boot/firmware/cmdline.txt` instead.

The full line should look like this:

```
console=serial0,115200 console=tty1 root=PARTUUID=ef0feb6e-02 rootfstype=ext4 fsck.repair=yes rootwait cfg80211.ieee80211_regdom=AT cgroup_memory=1 cgroup_enable=memory
```

Save the file and reboot the Raspberry Pi:

```bash
$ sudo reboot
```

## Synchronizing System Clocks

- Install and configure `ntp` or `chrony` to ensure the system clocks are
  synchronized across all Raspberry Pi devices. Time synchronization is critical
  for Kubernetes operations:

  ```bash
  $ sudo apt install -y chrony
  $ sudo systemctl enable chrony
  $ sudo systemctl start chrony
  ```

## Configuring Firewall Rules

If you are using `ufw` or another firewall, ensure that the necessary ports are
open for Kubernetes. As we have denied all incoming and outgoing traffic by
default, we need to allow specific ports for Kubernetes to function correctly
both ways.

- To allow incoming and outgoing traffic to the Kubernetes API server from the
  nodes, run the following commands:

  ```bash
  # Allow incoming and outgoing intra-node traffic to the Kubernetes API server
  $ sudo ufw allow from 10.1.1.0/24 to any port 6443 proto tcp
  $ sudo ufw allow out to 10.1.1.0/24 port 6443 proto tcp
  ```

- Next we want to allow our etcd replicas to communicate with each other:

  ```bash
  # Allow incoming and outgoing intra-node traffic to the etcd server
  $ sudo ufw allow from 10.1.1.0/24 to any port 2379:2380 proto tcp
  $ sudo ufw allow out to 10.1.1.0/24 port 2379:2380 proto tcp
  ```

- Next we want to allow the Kubelet API Server (port 10250), the Scheduler (port
  10251), and the Controller Manager (port 10252) to communicate with each
  other. The Kubelet API Server is used for intra-node communication, while the
  Scheduler and Controller Manager are used for local communication, therefore
  we need to the Kubelet API Server ports open for intra-node communication and
  the Scheduler and Controller Manager ports open only for local communication:

  ```bash
  # Allow Kubelet (10250) for Intra-Node Communication:
  $ sudo ufw allow from 10.1.1.0/24 to any port 10250 proto tcp
  $ sudo ufw allow out to 10.1.1.0/24 port 10250 proto tcp

  # Restrict Scheduler (10251) to local communication:
  $ sudo ufw allow from 127.0.0.1 to any port 10251 proto tcp
  $ sudo ufw allow out to 127.0.0.1 port 10251 proto tcp

  # Restrict Controller Manager (10252) to local communication:
  $ sudo ufw allow from 127.0.0.1 to any port 10252 proto tcp
  $ sudo ufw allow out to 127.0.0.1 port 10252 proto tcp
  ```

- Apply the changes:

  ```bash
  $ sudo ufw reload
  ```

## Verifying Node Preparation

To ensure your nodes are ready for Kubernetes initialization:

- Verify that swap is disabled:

  ```bash
  $ free -h
  ```

  The output should show 0 bytes of free swap.

- Check that the necessary kernel modules are loaded:

  ```bash
  $ lsmod | grep -e overlay -e br_netfilter
  ```

  The output should show the `overlay` and `br_netfilter` modules.

- Verify that the sysctl settings are applied:

  ```bash
  $ sysctl net.bridge.bridge-nf-call-iptables
  net.bridge.bridge-nf-call-iptables = 1

  $ sysctl net.ipv4.ip_forward
  net.ipv4.ip_forward = 1

  $ sysctl net.bridge.bridge-nf-call-ip6tables
  net.bridge.bridge-nf-call-ip6tables = 1
  ```

## Lesson Conclusion

Congratulations! With the nodes properly configured and prepared, you are ready
to initialize the Kubernetes control plane. In the next lesson, we will guide
you through the process of setting up the first control plane node for your
cluster.

You have completed this lesson and you can now continue with
[the next section](/building-a-production-ready-kubernetes-cluster-from-scratch/section-4).
