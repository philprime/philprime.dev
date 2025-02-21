---
layout: guide-lesson.liquid
title: Preparing Nodes for Kubernetes Initialization

guide_component: lesson
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
guide_section_id: 3
guide_lesson_id: 10
guide_lesson_abstract: >
  Configure each Raspberry Pi node to ensure it’s ready for Kubernetes cluster initialization, including system
  requirements and configurations.
---

In this lesson, we will prepare each Raspberry Pi node for Kubernetes initialization. This involves ensuring that all
nodes meet the necessary system requirements and configurations to join the Kubernetes cluster. By the end of this
lesson, your nodes will be ready to initialize the control plane and join additional worker nodes.

This is the tenth lesson in the series on building a production-ready Kubernetes cluster from scratch. Make sure you
have completed the [previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-9) before
continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

<div class="alert-warning" role="alert">
<strong>WARNING:</strong> All commands used in this lesson require <code>sudo</code> privileges.
Either prepend <code>sudo</code> to each command or switch to the root user using <code>sudo -i</code>.
</div>

## Updating System Settings for Kubernetes

Before initializing the Kubernetes cluster, we need to adjust some system settings to optimize the nodes for Kubernetes:

- Disable swap on each Raspberry Pi. Kubernetes requires swap to be disabled to function correctly:

  ```bash
  $ swapoff -a
  ```

  To make this change permanent, edit the `/etc/fstab` file and remove the swap entry. If your system uses
  `dphys-swapfile`, you will see the following line in the file:

  ```bash
  $ vi /etc/fstab
  # a swapfile is not a swap partition, no line here
  #   use  dphys-swapfile swap[on|off]  for that
  ```

  To disable the `dphys-swapfile` service, remove the system service by running:

  ```bash
  $ dphys-swapfile swapoff
  $ systemctl stop dphys-swapfile
  $ systemctl disable dphys-swapfile
  Synchronizing state of dphys-swapfile.service with SysV service script with /lib/systemd/systemd-sysv-install.
  Executing: /lib/systemd/systemd-sysv-install disable dphys-swapfile
  Removed "/etc/systemd/system/multi-user.target.wants/dphys-swapfile.service".
  ```

  To verify that swap is disabled, reboot the system, and run the following command:

  ```bash
  $ free -h
                total        used        free      shared  buff/cache   available
  Mem:           7.9Gi       314Mi       5.8Gi       5.2Mi       1.8Gi       7.6Gi
  Swap:             0B          0B          0B
  ```

  It should show 0 bytes of free swap.

- Ensure that all necessary kernel modules are loaded. Run the following commands to load the required modules:

  ```bash
  $ modprobe overlay
  $ modprobe br_netfilter
  ```

  To make these changes persistent, create a configuration file:

  ```bash
  $ touch /etc/modules-load.d/k8s.conf
  $ tee /etc/modules-load.d/k8s.conf <<EOF
  overlay
  br_netfilter
  EOF

  $ cat /etc/modules-load.d/k8s.conf
  overlay
  br_netfilter
  ```

- Adjust the sysctl settings for Kubernetes networking. Configure the necessary settings using:

  ```bash
  $ tee /etc/sysctl.d/k8s.conf <<EOF
  net.bridge.bridge-nf-call-iptables  = 1
  net.ipv4.ip_forward                 = 1
  net.bridge.bridge-nf-call-ip6tables = 1
  EOF

  $ cat /etc/sysctl.d/k8s.conf
  net.bridge.bridge-nf-call-iptables  = 1
  net.ipv4.ip_forward                 = 1
  net.bridge.bridge-nf-call-ip6tables = 1
  ```

  Apply the changes:

  ```bash
  $ sysctl --system
  * Applying /usr/lib/sysctl.d/50-pid-max.conf ...
  * Applying /etc/sysctl.d/98-rpi.conf ...
  * Applying /usr/lib/sysctl.d/99-protect-links.conf ...
  * Applying /etc/sysctl.d/99-sysctl.conf ...
  * Applying /etc/sysctl.d/k8s.conf ...
  * Applying /etc/sysctl.conf ...
  kernel.pid_max = 4194304
  kernel.printk = 3 4 1 3
  vm.min_free_kbytes = 16384
  net.ipv4.ping_group_range = 0 2147483647
  fs.protected_fifos = 1
  fs.protected_hardlinks = 1
  fs.protected_regular = 2
  fs.protected_symlinks = 1
  net.bridge.bridge-nf-call-iptables = 1
  net.ipv4.ip_forward = 1
  net.bridge.bridge-nf-call-ip6tables = 1
  ```

## Enable CGroup Memory

Kubernetes requires the memory cgroup memory controller to be enabled on the Raspberry Pi nodes.

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

If the `memory` cgroup is not enabled, you will need to enable it by appending `cgroup_memory=1 cgroup_enable=memory` to
the boot command line in the `/boot/cmdline.txt` file using `nano` or `vi`:

```bash
$ vi /boot/cmdline.txt
```

<div class="alert-warning" role="alert">
<strong>WARNING:</strong> If the file contains a warning with "The file you are looking for has moved to /boot/firmware/cmdline.txt", you should edit the file at <code>/boot/firmware/cmdline.txt</code> instead.
</div>

The full line should look similar to this:

```
console=serial0,115200 console=tty1 root=PARTUUID=ef0feb6e-02 rootfstype=ext4 fsck.repair=yes rootwait cfg80211.ieee80211_regdom=AT cgroup_memory=1 cgroup_enable=memory
```

Save the file and reboot the Raspberry Pi:

```bash
$ reboot
```

After the reboot, verify that the `memory` cgroup is enabled:

```bash
$ cat /proc/cgroups
#subsys_name	hierarchy	num_cgroups	enabled
cpuset	0	73	1
cpu	0	73	1
cpuacct	0	73	1
blkio	0	73	1
memory	0	73	1
devices	0	73	1
freezer	0	73	1
net_cls	0	73	1
perf_event	0	73	1
net_prio	0	73	1
pids	0	73	1
```

## Synchronizing System Clocks

Install and configure `ntp` or `chrony` to ensure the system clocks are synchronized across all Raspberry Pi devices.
Time synchronization is critical for Kubernetes operations:

```bash
$ apt update

$ apt install -y chrony
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
Suggested packages:
  dnsutils networkd-dispatcher
The following packages will be REMOVED:
  systemd-timesyncd
The following NEW packages will be installed:
  chrony
0 upgraded, 1 newly installed, 1 to remove and 0 not upgraded.
Need to get 278 kB of archives.
After this operation, 540 kB of additional disk space will be used.
Get:1 http://deb.debian.org/debian bookworm/main arm64 chrony arm64 4.3-2+deb12u1 [278 kB]
Fetched 278 kB in 0s (7,947 kB/s)
(Reading database ... 79942 files and directories currently installed.)
Removing systemd-timesyncd (252.33-1~deb12u1) ...
Selecting previously unselected package chrony.
(Reading database ... 79926 files and directories currently installed.)
Preparing to unpack .../chrony_4.3-2+deb12u1_arm64.deb ...
Unpacking chrony (4.3-2+deb12u1) ...
Setting up chrony (4.3-2+deb12u1) ...

Creating config file /etc/chrony/chrony.conf with new version

Creating config file /etc/chrony/chrony.keys with new version
dpkg-statoverride: warning: --update given but /var/log/chrony does not exist
Created symlink /etc/systemd/system/chronyd.service → /lib/systemd/system/chrony.service.
Created symlink /etc/systemd/system/multi-user.target.wants/chrony.service → /lib/systemd/system/chrony.service.
Processing triggers for dbus (1.14.10-1~deb12u1) ...
Processing triggers for man-db (2.11.2-2) ...

$ systemctl enable chrony
Synchronizing state of chrony.service with SysV service script with /lib/systemd/systemd-sysv-install.
Executing: /lib/systemd/systemd-sysv-install enable chrony

$ systemctl start chrony
```

We already enabled NTP on the router in the
[Lesson 7](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-7). To test the NTP service, you can
check the time synchronization with an external NTP server using `chrony`:

```bash
# Trigger a time synchronization
$ chronyc -a makestep
200 OK

# Check the synchronization status
$ chronyc sources
MS Name/IP address         Stratum Poll Reach LastRx Last sample
===============================================================================
^- 185.119.117.217               2   6     0  1095    -99us[  -99us] +/- 9024us
^- 91.206.8.70                   2   6     0  1095   +593us[ +708us] +/-   29ms
^- 185.144.161.170               2   6     0  1095  -1116ns[ +113us] +/- 5438us
^- 91.206.8.34                   2   6     1     0   +752us[ +752us] +/-   26ms
```

Looking at the output of `chronyc sources`, you should see a list of NTP servers with their synchronization status. The
`*` symbol indicates the selected source for synchronization, while the `^` symbol indicates candidate sources.

If you see a `?` or `x` symbol, it means the source is unreachable.

<div class="alert-note" role="alert">
<strong>NOTE:</strong> The list of NTP servers may vary depending on your location and
network configuration. Ensure that the selected sources are reachable and
provide accurate time synchronization.
</div>

## Configuring Firewall Rules

If you are using `ufw` or another firewall, ensure that the necessary ports are open for Kubernetes. As we have denied
all incoming and outgoing traffic by default, we need to allow specific ports for Kubernetes to function correctly both
ways.

- To allow incoming and outgoing traffic to the Kubernetes API server from the nodes, run the following commands:

  ```bash
  # Allow incoming and outgoing intra-node traffic to the Kubernetes API server
  $ ufw allow from 10.1.1.0/24 to any port 6443 proto tcp
  $ ufw allow out to 10.1.1.0/24 port 6443 proto tcp
  ```

- Next we want to allow our etcd replicas to communicate with each other:

  ```bash
  # Allow incoming and outgoing intra-node traffic to the etcd server
  $ ufw allow from 10.1.1.0/24 to any port 2379:2380 proto tcp
  $ ufw allow out to 10.1.1.0/24 port 2379:2380 proto tcp
  ```

- Next we want to allow the Kubelet API Server (port 10250), the Scheduler (port 10251), and the Controller Manager
  (port 10252) to communicate with each other. The Kubelet API Server is used for intra-node communication, while the
  Scheduler and Controller Manager are used for local communication, therefore we need to the Kubelet API Server ports
  open for intra-node communication and the Scheduler and Controller Manager ports open only for local communication:

  ```bash
  # Allow Kubelet (10250) for Intra-Node Communication:
  $ ufw allow from 10.1.1.0/24 to any port 10250 proto tcp
  $ ufw allow out to 10.1.1.0/24 port 10250 proto tcp

  # Restrict Scheduler (10251) to local communication:
  $ ufw allow from 127.0.0.1 to any port 10251 proto tcp
  $ ufw allow out to 127.0.0.1 port 10251 proto tcp

  # Restrict Controller Manager (10252) to local communication:
  $ ufw allow from 127.0.0.1 to any port 10252 proto tcp
  $ ufw allow out to 127.0.0.1 port 10252 proto tcp
  ```

- Apply the changes:

  ```bash
  $ ufw reload
  ```

## Verifying Node Preparation

To ensure your nodes are ready for Kubernetes initialization:

- Verify that swap is disabled:

  ```bash
  $ free -h
                total        used        free      shared  buff/cache   available
  Mem:           7.9Gi       302Mi       7.0Gi       5.2Mi       639Mi       7.6Gi
  Swap:             0B          0B          0B
  ```

  The output should show 0 bytes of free swap.

- Check that the necessary kernel modules are loaded:

  ```bash
  $ lsmod | grep -e overlay -e br_netfilter
  br_netfilter           65536  0
  bridge                294912  1 br_netfilter
  overlay               163840  0
  ipv6                  589824  29 bridge,br_netfilter,nf_reject_ipv6
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

Congratulations! With the nodes properly configured and prepared, you are ready to initialize the Kubernetes control
plane. In the next lesson, we will guide you through the process of setting up the first control plane node for your
cluster.

You have completed this lesson and you can now continue with
[the next section](/building-a-production-ready-kubernetes-cluster-from-scratch/section-4).
