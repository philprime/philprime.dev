I recently noted that my node number two of my Kubernetes cluster built with Raspberry Pi's started to fail and I noticed that it must be related to the SD card being faulty. This can happen very easily especially because during a power outage there was a short voltage spike when it came back on. Unfortunately the node did not boot correctly any more.

Thinking about it we already have a Raspberry Pi node set up to have an NVMe SSD connected via M.2 head. Perfect opportunity to just go for it and set up the node as a fresh one but this time I'm going to install the OS directly on the NVMe SSD.

As a first step I set up the node to be connected to my monitor, to have some power, and to have a direct Ethernet connection to my router. On top of that I added a keyboard because if you set up the node from scratch, all of the WiFi utilities or wireless utilities are not support.

Now that the node is ready, I'm booting it up by pressing the button to power it on. This one is a Raspberry Pi 5 so if you don't have one, you might have to just plug in your power cable and it will boot directly. After it boots we need to immediately press Shift, which will select the network boot.

What this will do is use the direct downloader of the net install boot image from Raspberry Pi.com. We can use this to not run an OS from an SD card or from the connected SSD but instead directly from the memory.

When you're connecting a keyboard to your Raspberry Pi, make sure that it is actually not drawing too much power from the Raspberry Pi. I noticed while using my Kikron keyboard that it used more power so I had warnings for overcurrent on the USB ports. The keyboard actually did not get activated.

As soon as we are in the dashboard to set up the Raspberry Pi, we select Raspberry Pi 5. We want to install Raspberry Pi OS Lite 64-bit because we don't need a UI. For the storage we're actually picking our SSD NVMe disk, which should show up. All of these steps are explained in more detail in the following article of my guide, "How to Set Up a Raspberry Pi Cluster from Scratch".

After the installation is done the Raspberry Pi will reboot and on the first reboot it also sets up itself to run from the disk itself.

So after the system was booted, I used raspi-config to set up the node.

1. As a first step I am opening up the advanced options then go for boot order and select b2 NVMe-USB-Boot from NVMe before trying USB. This one is important because even if you plug in an SD card, we want the system to just go for the connected NVMe.
2. As a next step I am going under locale and actually finding our locale because it might not have been set during setup.

As a first step I am going into the interface options under i1 SSH and we're enabling the SSH server. This one is especially important because from now on we can directly connect to our Raspberry Pi from our main machine and don't need a keyboard or display anymore.

After I am done I'm pressing reboot now, just so the system boots up in a fresh state with our applied configuration.

In my setup i assign static ip addresses to all of my nodes. As this is node 2 i am assigning the ip 10.1.1.2 in a 255.255.0.0 subnet using nmcli:

```bash
nmcli connection modify "Wired connection 1" ipv4.method manual ipv4.addresses "10.1.1.2/16" ipv4.gateway "10.1.0.1" ipv4.dns "10.1.0.1" autoconnect yes

echo "Bringing up the connection..."
nmcli connection up "Wired connection 1"
```

After this is set up I am able to setup my SSH key on the node so I don't need to rely on passwords anymore:

```bash
ssh-copy-id -i ~/.ssh/k8s_cluster_id_ed25519 -p 32022 10.0.0.10
```

Now we need to double-chekc if our disk is correctly set up by running lsblk:

```shell
root@kubernetes-node-2:/home/pi# lsblk -f
NAME        FSTYPE FSVER LABEL  UUID                                 FSAVAIL FSUSE% MOUNTPOINTS
loop0       swap   1
zram0       swap   1     zram0  4449a0e9-143e-46bc-af80-19a3e3f1faf9                [SWAP]
nvme0n1
├─nvme0n1p1 vfat   FAT32 bootfs 0D58-6978                             431.1M    14% /boot/firmware
└─nvme0n1p2 ext4   1.0   rootfs e634e0a4-a958-46cb-abad-862d2102573f  435.2G     1% /
```

As our OS is installed straight to the NVME disk, we can not further edit it here, but as it is already in ext4, we are all set.

The next step is setting up the firewall using `ufw`:

```shell
# Install ufw for firewall management
root@kubernetes-node-2:/home/pi# apt install ufw
Installing:
  ufw

Installing dependencies:
  iptables  libip4tc2  libip6tc2

Suggested packages:
  firewalld  rsyslog

Summary:
  Upgrading: 0, Installing: 4, Removing: 0, Not Upgrading: 0
  Download size: 562 kB
  Space needed: 9,721 kB / 467 GB available

Continue? [Y/n]
```

Next we disable all incoming and outgoing network traffic, except SSH:

```shell
root@kubernetes-node-2:/home/pi# ufw default deny incoming
Default incoming policy changed to 'deny'
(be sure to update your rules accordingly)
root@kubernetes-node-2:/home/pi# ufw default deny outgoing
Default outgoing policy changed to 'deny'
(be sure to update your rules accordingly)
root@kubernetes-node-2:/home/pi# ufw allow ssh comment 'Allow SSH access'
Rules updated
Rules updated (v6)
root@kubernetes-node-2:/home/pi# ufw enable
Command may disrupt existing ssh connections. Proceed with operation (y|n)? y
Firewall is active and enabled on system startup
root@kubernetes-node-2:/home/pi# ufw status verbose
Status: active
Logging: on (low)
Default: deny (incoming), deny (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere                   # Allow SSH access
22/tcp (v6)                ALLOW IN    Anywhere (v6)              # Allow SSH access
```

As this node still needs to resolve DNS, NTP and HTTP, we need to allow a couple protocols:

```shell
root@kubernetes-node-2:/home/pi# ufw allow out domain comment 'Allow outgoing DNS traffic'
Rule added
Rule added (v6)
root@kubernetes-node-2:/home/pi# ufw allow out ntp comment 'Allow outgoing NTP traffic'
Rule added
Rule added (v6)
root@kubernetes-node-2:/home/pi# ufw allow out http comment 'Allow outgoing HTTP traffic'
Rule added
Rule added (v6)
root@kubernetes-node-2:/home/pi# ufw allow out https comment 'Allow outgoing HTTPS traffic'
Rule added
Rule added (v6)
```

After applying the ICMP traffic fix as described in [lesson 7 of my guide]() we can reload the ufw rules:

```bash
root@kubernetes-node-2:/home/pi# ufw reload
Firewall reloaded
root@kubernetes-node-2:/home/pi# ufw status verbose
Status: active
Logging: on (low)
Default: deny (incoming), deny (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere                   # Allow SSH access
22/tcp (v6)                ALLOW IN    Anywhere (v6)              # Allow SSH access

53                         ALLOW OUT   Anywhere                   # Allow outgoing DNS traffic
123/udp                    ALLOW OUT   Anywhere                   # Allow outgoing NTP traffic
80/tcp                     ALLOW OUT   Anywhere                   # Allow outgoing HTTP traffic
443                        ALLOW OUT   Anywhere                   # Allow outgoing HTTPS traffic
53 (v6)                    ALLOW OUT   Anywhere (v6)              # Allow outgoing DNS traffic
123/udp (v6)               ALLOW OUT   Anywhere (v6)              # Allow outgoing NTP traffic
80/tcp (v6)                ALLOW OUT   Anywhere (v6)              # Allow outgoing HTTP traffic
443 (v6)                   ALLOW OUT   Anywhere (v6)              # Allow outgoing HTTPS traffic
```

As the next step we need to set up the Kubernetes apt repository. My cluster is still running on 1.31 I am going to use the opportunity and start the migration toi 1.32. The general rule of thumb i2 that it's okay to have a version drift of up to one minor version, so having nodes on 1.32 an 133 isG not ideal but possible:

```shell
$ apt install -y apt-transport-https ca-certificates curl gnupg
$ mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
$ echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' >> /etc/apt/sources.list.d/kubernetes.list
$ apt update
$ apt install -y kubelet kubeadm kubectl
root@kubernetes-node-2:/home/pi# apt-mark hold kubelet kubeadm kubectl
kubelet set on hold.
kubeadm set on hold.
kubectl set on hold.
root@kubernetes-node-2:/home/pi# kubectl version --client
Client Version: v1.32.13
Kustomize Version: v5.5.0
root@kubernetes-node-2:/home/pi# kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"32", GitVersion:"v1.32.13", GitCommit:"6172d7357c6287643350a4fc7e048f24098f2a1b", GitTreeState:"clean", BuildDate:"2026-02-26T20:22:27Z", GoVersion:"go1.24.13", Compiler:"gc", Platform:"linux/arm64"}
root@kubernetes-node-2:/home/pi# kubelet --version
Kubernetes v1.32.13
```

Next we install containerd

root@kubernetes-node-2:/home/pi# apt install -y apt-transport-https curl gnupg2 software-properties-common
root@kubernetes-node-2:/home/pi# apt install -y containerd
root@kubernetes-node-2:/home/pi# mkdir -p /etc/containerd
root@kubernetes-node-2:/home/pi# containerd config default | tee /etc/containerd/config.toml

We need to configure the system cgroup driver to systemd because we are using the systemd cgroup driver. cgroup is a Linux kernel feature that limits the resources that can be used by a process.

In the same section as the root setting, we need to configure the SystemdCgroup setting to true:

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
SystemdCgroup = true
Save the changes and exit the editor (in vi, press Esc followed by :wq and Enter).

"/etc/containerd/config.toml" 291 lines, 8394 bytes written
root@kubernetes-node-2:/home/pi# systemctl enable containerd
root@kubernetes-node-2:/home/pi# systemctl restart containerd
root@kubernetes-node-2:/home/pi# systemctl status containerd
WARNING: terminal is not fully functional
Press RETURN to continue
● containerd.service - containerd container runtime
Loaded: loaded (/usr/lib/systemd/system/containerd.service; enabled; preset: enabled)
Active: active (running) since Tue 2026-04-28 20:28:05 CEST; 3s ago
Invocation: 576b5d3a4bf64599b52281b29177fcfc
Docs: https://containerd.io
Process: 9797 ExecStartPre=/sbin/modprobe overlay (code=exited, status=0/SUCCESS)
Main PID: 9799 (containerd)
Tasks: 9
CPU: 78ms
CGroup: /system.slice/containerd.service
└─9799 /usr/bin/containerd

To prepare the node for kubernets it's time to do some smaller changes:

```
root@kubernetes-node-2:/home/pi# dphys-swapfile swapoff
basGh: dphys-swapfile: command not found
root@kubernetes-node-2:/home/pi# systemctl stop dphys-swapfile
Failed to stop dphys-swapfile.service: Unit dphys-swapfile.service not loaded.
root@kubernetes-node-2:/home/pi# free -h
               total        used        free      shared  buff/cache   available
Mem:           7.9Gi       286Mi       6.5Gi        12Mi       1.1Gi       7.6Gi
Swap:          2.0Gi          0B       2.0Gi
root@kubernetes-node-2:/home/pi# swapoff -a
root@kubernetes-node-2:/home/pi# free -h
               total        used        free      shared  buff/cache   available
Mem:           7.9Gi       292Mi       6.5Gi        12Mi       1.1Gi       7.6Gi
Swap:          2.0Gi          0B       2.0Gi
root@kubernetes-node-2:/home/pi# swapon --show
NAME       TYPE      SIZE USED PRIO
/dev/zram0 partition   2G   0B  100
root@kubernetes-node-2:/home/pi# swapoff /dev/zram0\
> ^C
root@kubernetes-node-2:/home/pi# swapoff /dev/zram0
root@kubernetes-node-2:/home/pi# systemctl disable --now systemd-zram-setup@zram0
The unit files have no installation config (WantedBy=, RequiredBy=, UpheldBy=,
Also=, or Alias= settings in the [Install] section, and DefaultInstance= for
template units). This means they are not meant to be enabled or disabled using systemctl.

Possible reasons for having these kinds of units are:
• A unit may be statically enabled by being symlinked from another unit's
  .wants/, .requires/, or .upholds/ directory.
• A unit's purpose may be to act as a helper for some other unit which has
  a requirement dependency on it.
• A unit may be started when needed via activation (socket, path, timer,
  D-Bus, udev, scripted systemctl call, ...).
• In case of template units, the unit is meant to be enabled with some
  instance name specified.
root@kubernetes-node-2:/home/pi# systemctl mask systemd-zram-setup@zram0
Created symlink '/etc/systemd/system/systemd-zram-setup@zram0.service' → '/dev/null'.
root@kubernetes-node-2:/home/pi# swapon --show
```

After a reboot:

pi@kubernetes-node-2:~$ free -h
total used free shared buff/cache available
Mem: 7.9Gi 290Mi 7.4Gi 12Mi 296Mi 7.6Gi
Swap: 0B 0B 0B

next we prepare the kernel modules

```
root@kubernetes-node-2:/home/pi# modprobe overlay
root@kubernetes-node-2:/home/pi# modprobe br_netfilter
root@kubernetes-node-2:/home/pi# touch /etc/modules-load.d/k8s.conf
root@kubernetes-node-2:/home/pi# tee /etc/modules-load.d/k8s.conf <<EOF
> overlay
> br_netfilter
> EOF
overlay
br_netfilter
root@kubernetes-node-2:/home/pi# lsmod | grep -e overlay -e br_netfilter
br_netfilter           65536  0
bridge                344064  1 br_netfilter
overlay               180224  0
ipv6                  622592  35 bridge,br_netfilter,nf_reject_ipv6
```

Next we adapt some of the sysctl settings:

```shell
root@kubernetes-node-2:/home/pi# tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

root@kubernetes-node-2:/home/pi# sysctl --system
* Applying /usr/lib/sysctl.d/10-coredump-debian.conf ...
* Applying /usr/lib/sysctl.d/50-default.conf ...
* Applying /usr/lib/sysctl.d/50-pid-max.conf ...
* Applying /run/sysctl.d/70-rpi-swap.conf ...
* Applying /etc/sysctl.d/98-rpi.conf ...
* Applying /etc/sysctl.d/k8s.conf ...
kernel.core_pattern = core
kernel.sysrq = 0x01b6
kernel.core_uses_pid = 1
net.ipv4.conf.default.rp_filter = 2
net.ipv4.conf.eth0.rp_filter = 2
net.ipv4.conf.lo.rp_filter = 2
net.ipv4.conf.wlan0.rp_filter = 2
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.eth0.accept_source_route = 0
net.ipv4.conf.lo.accept_source_route = 0
net.ipv4.conf.wlan0.accept_source_route = 0
net.ipv4.conf.default.promote_secondaries = 1
net.ipv4.conf.eth0.promote_secondaries = 1
net.ipv4.conf.lo.promote_secondaries = 1
net.ipv4.conf.wlan0.promote_secondaries = 1
net.ipv4.ping_group_range = 0 2147483647
net.core.default_qdisc = fq_codel
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_regular = 2
fs.protected_fifos = 1
vm.max_map_count = 1048576
kernel.pid_max = 4194304
vm.page-cluster = 0
kernel.printk = 3 4 1 3
vm.min_free_kbytes = 16384
net.ipv4.ping_group_range = 0 2147483647
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
```

Next we need to adapt our boot command to enable cgroups:

```
root@kubernetes-node-2:/home/pi# cat /boot/firmware/cmdline.txt
console=serial0,115200 console=tty1 root=PARTUUID=1e13ba14-02 rootfstype=ext4 fsck.repair=yes rootwait cgroup_memory=1 cgroup_enable=memory
```

next step is making sure the NTP times are correct:

```
root@kubernetes-node-2:/home/pi# apt install -y chrony
Installing:
  chrony

Suggested packages:
  dnsutils  networkd-dispatcher

REMOVING:
  systemd-timesyncd

Summary:
  Upgrading: 0, Installing: 1, Removing: 1, Not Upgrading: 0
  Download size: 299 kB
  Space needed: 518 kB / 467 GB available

Get:1 http://deb.debian.org/debian trixie/main arm64 chrony arm64 4.6.1-3+deb13u1 [299 kB]
Fetched 299 kB in 0s (8,298 kB/s)
(Reading database ... 66927 files and directories currently installed.)
Removing systemd-timesyncd (257.9-1~deb13u1) ...
Selecting previously unselected package chrony.
(Reading database ... 66906 files and directories currently installed.)
Preparing to unpack .../chrony_4.6.1-3+deb13u1_arm64.deb ...
Unpacking chrony (4.6.1-3+deb13u1) ...
Setting up chrony (4.6.1-3+deb13u1) ...
Creating config file /etc/chrony/chrony.conf with new version
Creating config file /etc/chrony/chrony.keys with new version
dpkg-statoverride: warning: --update given but /var/log/chrony does not exist
Created symlink '/etc/systemd/system/chronyd.service' → '/usr/lib/systemd/system/chrony.service'.
Created symlink '/etc/systemd/system/multi-user.target.wants/chrony.service' → '/usr/lib/systemd/system/chrony.service'.
Processing triggers for dbus (1.16.2-2) ...
Processing triggers for man-db (2.13.1-1) ...
root@kubernetes-node-2:/home/pi# systemctl enable chrony
Synchronizing state of chrony.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install enable chrony
root@kubernetes-node-2:/home/pi# systemctl start chrony
root@kubernetes-node-2:/home/pi# chronyc -a makestep
200 OK
root@kubernetes-node-2:/home/pi# chronyc sources
MS Name/IP address         Stratum Poll Reach LastRx Last sample
===============================================================================
^* fetchmail.mediainvent.at      2   6    17    35    +98us[  +52us] +/-   28ms
^+ sv2.ggsrv.de                  2   6    17    35    -71us[ -111us] +/-   11ms
^+ extern1.nemox.net             2   6    17    35    +52us[  +52us] +/-   43ms
^- 83-215-130-11.dyn.cablel>     2   6    17    35  -1513us[-1513us] +/-  136ms
```

as we are now hosting kubernetes we need to loosen our firewall to enable traffic between nodes:

```
root@kubernetes-node-2:/home/pi# ufw allow from 10.1.1.0/24 to any port 6443 proto tcp comment 'Allow incoming and outgoing intra-node traffic to the Kubernetes API server'
Rule added
root@kubernetes-node-2:/home/pi# ufw allow out to 10.1.1.0/24 port 6443 proto tcp comment 'Allow incoming and outgoing intra-node traffic to the Kubernetes API server'
Rule added
root@kubernetes-node-2:/home/pi# ufw allow from 10.1.1.0/24 to any port 2379:2380 proto tcp comment 'Allow incoming and outgoing intra-node traffic to the etcd server'
Rule added
root@kubernetes-node-2:/home/pi# ufw allow out to 10.1.1.0/24 port 2379:2380 proto tcp comment 'Allow incoming and outgoing intra-node traffic to the etcd server'
Rule added
root@kubernetes-node-2:/home/pi# ufw allow from 10.1.1.0/24 to any port 10250 proto tcp comment 'Allow incoming and outgoing intra-node traffic to the Kubelet API Server'
Rule added
root@kubernetes-node-2:/home/pi# ufw allow out to 10.1.1.0/24 port 10250 proto tcp comment 'Allow incoming and outgoing intra-node traffic to the Kubelet API Server'
Rule added
root@kubernetes-node-2:/home/pi# ufw allow from 127.0.0.1 to any port 10251 proto tcp comment 'Allow incoming and outgoing intra-node traffic to the Scheduler'
Rule added
root@kubernetes-node-2:/home/pi# ufw allow out to 127.0.0.1 port 10251 proto tcp comment 'Allow incoming and outgoing intra-node traffic to the Scheduler'
Rule added
root@kubernetes-node-2:/home/pi# ufw allow from 127.0.0.1 to any port 10252 proto tcp comment 'Allow incoming and outgoing intra-node traffic to the Controller Manager'
Rule added
root@kubernetes-node-2:/home/pi# ufw allow out to 127.0.0.1 port 10252 proto tcp comment 'Allow incoming and outgoing intra-node traffic to the Controller Manager'
Rule added
root@kubernetes-node-2:/home/pi# ufw reload
ufw status
Firewall reloaded
root@kubernetes-node-2:/home/pi# ufw status
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere                   # Allow SSH access
6443/tcp                   ALLOW       10.1.1.0/24                # Allow incoming and outgoing intra-node traffic to the Kubernetes API server
2379:2380/tcp              ALLOW       10.1.1.0/24                # Allow incoming and outgoing intra-node traffic to the etcd server
10250/tcp                  ALLOW       10.1.1.0/24                # Allow incoming and outgoing intra-node traffic to the Kubelet API Server
10251/tcp                  ALLOW       127.0.0.1                  # Allow incoming and outgoing intra-node traffic to the Scheduler
10252/tcp                  ALLOW       127.0.0.1                  # Allow incoming and outgoing intra-node traffic to the Controller Manager
22/tcp (v6)                ALLOW       Anywhere (v6)              # Allow SSH access

53                         ALLOW OUT   Anywhere                   # Allow outgoing DNS traffic
123/udp                    ALLOW OUT   Anywhere                   # Allow outgoing NTP traffic
80/tcp                     ALLOW OUT   Anywhere                   # Allow outgoing HTTP traffic
443                        ALLOW OUT   Anywhere                   # Allow outgoing HTTPS traffic
10.1.1.0/24 6443/tcp       ALLOW OUT   Anywhere                   # Allow incoming and outgoing intra-node traffic to the Kubernetes API server
10.1.1.0/24 2379:2380/tcp  ALLOW OUT   Anywhere                   # Allow incoming and outgoing intra-node traffic to the etcd server
10.1.1.0/24 10250/tcp      ALLOW OUT   Anywhere                   # Allow incoming and outgoing intra-node traffic to the Kubelet API Server
127.0.0.1 10251/tcp        ALLOW OUT   Anywhere                   # Allow incoming and outgoing intra-node traffic to the Scheduler
127.0.0.1 10252/tcp        ALLOW OUT   Anywhere                   # Allow incoming and outgoing intra-node traffic to the Controller Manager
53 (v6)                    ALLOW OUT   Anywhere (v6)              # Allow outgoing DNS traffic
123/udp (v6)               ALLOW OUT   Anywhere (v6)              # Allow outgoing NTP traffic
80/tcp (v6)                ALLOW OUT   Anywhere (v6)              # Allow outgoing HTTP traffic
443 (v6)                   ALLOW OUT   Anywhere (v6)              # Allow outgoing HTTPS traffic
```

Now it's time to set up our node as an additional kubernetes control plane node.
on one of our control plane nodes we need to get the join token:

root@kubernetes-node-1:~$ kubeadm token create --print-join-command
kubeadm join 10.1.233.1:6443 --token n2ukdw.l21va8fyuycc7w5r --discovery-token-ca-cert-hash sha256:da8ae30fec57d12427ddd753cc12befce7f7e6251fc2cb12cd784bdcfb45d82d
root@kubernetes-node-1:/home/pi# kubeadm init phase upload-certs --upload-certs
I0428 20:54:18.358218 25923 version.go:261] remote version is much newer: v1.36.0; falling back to: stable-1.31
[upload-certs] Storing the certificates in Secret "kubeadm-certs" in the "kube-system" Namespace
[upload-certs] Using certificate key:
7bbcbe3fc6e7a8e42bf896eeb318c4cc4a1bb838dd296da23cf0011b5316e605

before we can join i had to cleanup etcd
pi@kubernetes-node-1:~$ kubectl -n kube-system exec etcd-kubernetes-node-1 -- etcdctl \

>     --endpoints=https://127.0.0.1:2379 \
>     --cacert=/etc/kubernetes/pki/etcd/ca.crt \
>     --cert=/etc/kubernetes/pki/etcd/server.crt \
>     --key=/etc/kubernetes/pki/etcd/server.key \
>     member list

10245a05f8465cc0, started, kubernetes-node-2, https://10.1.1.2:2380, https://10.1.1.2:2379, false
90b779032a51236a, started, kubernetes-node-1, https://10.1.1.1:2380, https://10.1.1.1:2379, false
ec5480f06817178e, started, kubernetes-node-3, https://10.1.1.3:2380, https://10.1.1.3:2379, false

pi@kubernetes-node-1:~$ kubectl -n kube-system exec etcd-kubernetes-node-1 -- etcdctl \

>     --endpoints=https://127.0.0.1:2379 \
>     --cacert=/etc/kubernetes/pki/etcd/ca.crt \
>     --cert=/etc/kubernetes/pki/etcd/server.crt \
>     --key=/etc/kubernetes/pki/etcd/server.key \
>     member remove 10245a05f8465cc0

Member 10245a05f8465cc0 removed from cluster 1e877b745497a387

with this token is used to join the cluster:

kubeadm join 10.1.1.1:6443\
--token n2ukdw.l21va8fyuycc7w5r\
--discovery-token-ca-cert-hash sha256:da8ae30fec57d12427ddd753cc12befce7f7e6251fc2cb12cd784bdcfb45d82d\
--certificate-key 7bbcbe3fc6e7a8e42bf896eeb318c4cc4a1bb838dd296da23cf0011b5316e605\
--control-plane
[preflight] Running pre-flight checks
[WARNING SystemVerification]: missing optional cgroups: hugetlb
[preflight] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
[preflight] Use 'kubeadm init phase upload-config --config your-config.yaml' to re-upload it.
[preflight] Running pre-flight checks before initializing the new control plane instance
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action beforehand using 'kubeadm config images pull'
W0428 21:13:04.996931 4406 checks.go:843] detected that the sandbox image "registry.k8s.io/pause:3.8" of the container runtime is inconsistent with that used by kubeadm.It is recommended to use "registry.k8s.io/pause:3.10" as the CRI sandbox image.
[download-certs] Downloading the certificates in Secret "kubeadm-certs" in the "kube-system" Namespace
[download-certs] Saving the certificates to the folder: "/etc/kubernetes/pki"
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [kubernetes kubernetes-node-1 kubernetes-node-2 kubernetes-node-3 kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.96.0.1 10.1.1.2 10.1.1.1 127.0.0.1 10.1.233.1 10.1.1.3 10.0.0.10]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/healthcheck-client" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [kubernetes-node-2 localhost] and IPs [10.1.1.2 127.0.0.1 ::1]
[certs] Generating "etcd/peer" certificate and key
[certs] etcd/peer serving cert is signed for DNS names [kubernetes-node-2 localhost] and IPs [10.1.1.2 127.0.0.1 ::1]
[certs] Generating "apiserver-etcd-client" certificate and key
[certs] Valid certificates and keys now exist in "/etc/kubernetes/pki"
[certs] Using the existing "sa" key
[kubeconfig] Generating kubeconfig files
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
[control-plane] Creating static Pod manifest for "kube-scheduler"
[check-etcd] Checking that the etcd cluster is healthy
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-check] Waiting for a healthy kubelet at http://127.0.0.1:10248/healthz. This can take up to 4m0s
[kubelet-check] The kubelet is healthy after 2.001063682s
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap
[etcd] Announced new etcd member joining to the existing etcd cluster
[etcd] Creating static Pod manifest for "etcd"
{"level":"warn","ts":"2026-04-28T21:13:14.070475+0200","logger":"etcd-client","caller":"v3@v3.5.16/retry_interceptor.go:63","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0x4000af81e0/10.1.1.1:2379","attempt":0,"error":"rpc error: code = FailedPrecondition desc = etcdserver: can only promote a learner member which is in sync with leader"}
{"level":"warn","ts":"2026-04-28T21:13:14.551865+0200","logger":"etcd-client","caller":"v3@v3.5.16/retry_interceptor.go:63","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0x4000af81e0/10.1.1.1:2379","attempt":0,"error":"rpc error: code = FailedPrecondition desc = etcdserver: can only promote a learner member which is in sync with leader"}
{"level":"warn","ts":"2026-04-28T21:13:15.050042+0200","logger":"etcd-client","caller":"v3@v3.5.16/retry_interceptor.go:63","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0x4000af81e0/10.1.1.1:2379","attempt":0,"error":"rpc error: code = FailedPrecondition desc = etcdserver: can only promote a learner member which is in sync with leader"}
{"level":"warn","ts":"2026-04-28T21:13:15.551164+0200","logger":"etcd-client","caller":"v3@v3.5.16/retry_interceptor.go:63","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0x4000af81e0/10.1.1.1:2379","attempt":0,"error":"rpc error: code = FailedPrecondition desc = etcdserver: can only promote a learner member which is in sync with leader"}
{"level":"warn","ts":"2026-04-28T21:13:16.050389+0200","logger":"etcd-client","caller":"v3@v3.5.16/retry_interceptor.go:63","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0x4000af81e0/10.1.1.1:2379","attempt":0,"error":"rpc error: code = FailedPrecondition desc = etcdserver: can only promote a learner member which is in sync with leader"}
{"level":"warn","ts":"2026-04-28T21:13:16.550366+0200","logger":"etcd-client","caller":"v3@v3.5.16/retry_interceptor.go:63","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0x4000af81e0/10.1.1.1:2379","attempt":0,"error":"rpc error: code = FailedPrecondition desc = etcdserver: can only promote a learner member which is in sync with leader"}
{"level":"warn","ts":"2026-04-28T21:13:17.050800+0200","logger":"etcd-client","caller":"v3@v3.5.16/retry_interceptor.go:63","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0x4000af81e0/10.1.1.1:2379","attempt":0,"error":"rpc error: code = FailedPrecondition desc = etcdserver: can only promote a learner member which is in sync with leader"}
{"level":"warn","ts":"2026-04-28T21:13:17.550771+0200","logger":"etcd-client","caller":"v3@v3.5.16/retry_interceptor.go:63","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0x4000af81e0/10.1.1.1:2379","attempt":0,"error":"rpc error: code = FailedPrecondition desc = etcdserver: can only promote a learner member which is in sync with leader"}
{"level":"warn","ts":"2026-04-28T21:13:18.050700+0200","logger":"etcd-client","caller":"v3@v3.5.16/retry_interceptor.go:63","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0x4000af81e0/10.1.1.1:2379","attempt":0,"error":"rpc error: code = FailedPrecondition desc = etcdserver: can only promote a learner member which is in sync with leader"}
{"level":"warn","ts":"2026-04-28T21:13:18.550892+0200","logger":"etcd-client","caller":"v3@v3.5.16/retry_interceptor.go:63","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0x4000af81e0/10.1.1.1:2379","attempt":0,"error":"rpc error: code = FailedPrecondition desc = etcdserver: can only promote a learner member which is in sync with leader"}
{"level":"warn","ts":"2026-04-28T21:13:19.049992+0200","logger":"etcd-client","caller":"v3@v3.5.16/retry_interceptor.go:63","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0x4000af81e0/10.1.1.1:2379","attempt":0,"error":"rpc error: code = FailedPrecondition desc = etcdserver: can only promote a learner member which is in sync with leader"}
{"level":"warn","ts":"2026-04-28T21:13:19.550837+0200","logger":"etcd-client","caller":"v3@v3.5.16/retry_interceptor.go:63","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0x4000af81e0/10.1.1.1:2379","attempt":0,"error":"rpc error: code = FailedPrecondition desc = etcdserver: can only promote a learner member which is in sync with leader"}
[etcd] Waiting for the new etcd member to join the cluster. This can take up to 40s
[mark-control-plane] Marking the node kubernetes-node-2 as control-plane by adding the labels: [node-role.kubernetes.io/control-plane node.kubernetes.io/exclude-from-external-load-balancers]
[mark-control-plane] Marking the node kubernetes-node-2 as control-plane by adding the taints [node-role.kubernetes.io/control-plane:NoSchedule]

This node has joined the cluster and a new control plane instance was created:

- Certificate signing request was sent to apiserver and approval was received.
- The Kubelet was informed of the new secure connection details.
- Control plane label and taint were applied to the new node.
- The Kubernetes control plane instances scaled up.
- A new etcd member was added to the local/stacked etcd cluster.

To start administering your cluster from this node, you need to run the following as a regular user:

    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

Run 'kubectl get nodes' to see this node join the cluster.

```
to finish setting up networking we install Flannel CNI

kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

to see what is going on:

pi@kubernetes-node-2:~$ kubectl get pods -n kube-flannel -o wide --watch
NAME                    READY   STATUS    RESTARTS   AGE   IP         NODE                NOMINATED NODE   READINESS GATES
kube-flannel-ds-54r6c   1/1     Running   0          37s   10.1.1.3   kubernetes-node-3   <none>           <none>
kube-flannel-ds-gm2tt   1/1     Running   0          29s   10.1.1.1   kubernetes-node-1   <none>           <none>
kube-flannel-ds-znkdt   1/1     Running   0          21s   10.1.1.2   kubernetes-node-2   <none>           <none>

Allow Flannel Traffic Through the Firewall#
Flannel uses UDP ports 8285 and 8472 for backend communication between nodes. Ensure these ports are open in the firewall on every single node, to allow Flannel to function correctly:

# Allowing Flannel UDP backend traffic
$ sudo ufw allow 8285/udp
$ sudo ufw allow out 8285/udp

# Allow Flannel VXLAN backend traffic
$ sudo ufw allow 8472/udp
$ sudo ufw allow out 8472/udp
Next up, we need to allow traffic from our pod network CIDR range (10.244.0.0/16). This is necessary for the pods to communicate with each other across nodes:

# Allow traffic from pod network CIDR to Kubernetes API server
$ sudo ufw allow from 10.244.0.0/16 to any port 6443
$ sudo ufw allow out to 10.244.0.0/16 port 6443
Flannel also requires node-to-node communication for overlay networking.

# Allow incoming intra-pod network communication within pod network CIDR
$ sudo ufw allow from 10.244.0.0/16 to 10.244.0.0/16
# Allow outgoing intra-pod network communication within pod network CIDR
$ sudo ufw allow out to 10.244.0.0/16
Allow routed traffic for Flannel overlay network

$ sudo ufw allow in on flannel.1
$ sudo ufw allow out on flannel.1
Enable packet forwarding in the kernel. Open the sysctl.conf file for and uncomment the following lines to route packets between interfaces:

$ sudo nano /etc/ufw/sysctl.conf
#net/ipv4/ip_forward=1
#net/ipv6/conf/default/forwarding=1
#net/ipv6/conf/all/forwarding=1
Remove the leading # from the lines to uncomment them:

$ sudo nano /etc/ufw/sysctl.conf
net/ipv4/ip_forward=1
net/ipv6/conf/default/forwarding=1
net/ipv6/conf/all/forwarding=1
Save the file and exit the editor.

After opening these ports, reload the firewall to apply the changes:

$ sudo ufw reload

after this our firewall looks like this:

pi@kubernetes-node-2:~$ sudo ufw status verbose
Status: active
Logging: on (low)
Default: deny (incoming), deny (outgoing), deny (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere                   # Allow SSH access
6443/tcp                   ALLOW IN    10.1.1.0/24                # Allow incoming and outgoing intra-node traffic to the Kubernetes API server
2379:2380/tcp              ALLOW IN    10.1.1.0/24                # Allow incoming and outgoing intra-node traffic to the etcd server
10250/tcp                  ALLOW IN    10.1.1.0/24                # Allow incoming and outgoing intra-node traffic to the Kubelet API Server
10251/tcp                  ALLOW IN    127.0.0.1                  # Allow incoming and outgoing intra-node traffic to the Scheduler
10252/tcp                  ALLOW IN    127.0.0.1                  # Allow incoming and outgoing intra-node traffic to the Controller Manager
8285/udp                   ALLOW IN    Anywhere
8472/udp                   ALLOW IN    Anywhere
6443                       ALLOW IN    10.244.0.0/16
10.244.0.0/16              ALLOW IN    10.244.0.0/16
Anywhere on flannel.1      ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)              # Allow SSH access
8285/udp (v6)              ALLOW IN    Anywhere (v6)
8472/udp (v6)              ALLOW IN    Anywhere (v6)
Anywhere (v6) on flannel.1 ALLOW IN    Anywhere (v6)

53                         ALLOW OUT   Anywhere                   # Allow outgoing DNS traffic
123/udp                    ALLOW OUT   Anywhere                   # Allow outgoing NTP traffic
80/tcp                     ALLOW OUT   Anywhere                   # Allow outgoing HTTP traffic
443                        ALLOW OUT   Anywhere                   # Allow outgoing HTTPS traffic
10.1.1.0/24 6443/tcp       ALLOW OUT   Anywhere                   # Allow incoming and outgoing intra-node traffic to the Kubernetes API server
10.1.1.0/24 2379:2380/tcp  ALLOW OUT   Anywhere                   # Allow incoming and outgoing intra-node traffic to the etcd server
10.1.1.0/24 10250/tcp      ALLOW OUT   Anywhere                   # Allow incoming and outgoing intra-node traffic to the Kubelet API Server
127.0.0.1 10251/tcp        ALLOW OUT   Anywhere                   # Allow incoming and outgoing intra-node traffic to the Scheduler
127.0.0.1 10252/tcp        ALLOW OUT   Anywhere                   # Allow incoming and outgoing intra-node traffic to the Controller Manager
8285/udp                   ALLOW OUT   Anywhere
8472/udp                   ALLOW OUT   Anywhere
10.244.0.0/16 6443         ALLOW OUT   Anywhere
10.244.0.0/16              ALLOW OUT   Anywhere
Anywhere                   ALLOW OUT   Anywhere on flannel.1
53 (v6)                    ALLOW OUT   Anywhere (v6)              # Allow outgoing DNS traffic
123/udp (v6)               ALLOW OUT   Anywhere (v6)              # Allow outgoing NTP traffic
80/tcp (v6)                ALLOW OUT   Anywhere (v6)              # Allow outgoing HTTP traffic
443 (v6)                   ALLOW OUT   Anywhere (v6)              # Allow outgoing HTTPS traffic
8285/udp (v6)              ALLOW OUT   Anywhere (v6)
8472/udp (v6)              ALLOW OUT   Anywhere (v6)
Anywhere (v6)              ALLOW OUT   Anywhere (v6) on flannel.1
```

next we need to setup HAProxy and Keepalived for the HA setup of Kubernetes API
first we need to change the bound ip address:

```shell
$ sudo vim /etc/kubernetes/manifests/kube-apiserver.yaml
Locate the --advertise-address and --bind-address to set both to the local nodes IP address. If the flags do not exist, add them to the list. For example, if the local IP address of the node is 10.1.1.1, the flag should look like this:

spec:
  containers:
    - command:
        - kube-apiserver
        - --advertise-address=10.1.1.2
        - --bind-address=10.1.1.2


root@kubernetes-node-2:/home/pi# systemctl restart kubelet
root@kubernetes-node-2:/home/pi# sudo netstat -tuln | grep 6443
tcp        0      0 10.1.1.2:6443           0.0.0.0:*               LISTEN
```

next we install the services

```
root@kubernetes-node-2:/home/pi# apt install -y keepalived haproxy
Installing:
  haproxy  keepalived

Installing dependencies:
  ipvsadm  libjemalloc2  liblua5.4-0  libopentracing-c-wrapper0t64  libopentracing1  libsnmp-base  libsnmp40t64

Suggested packages:
  vim-haproxy  haproxy-doc  heartbeat  ldirectord  snmp-mibs-downloader

Summary:
  Upgrading: 0, Installing: 9, Removing: 0, Not Upgrading: 0
  Download size: 7,803 kB
  Space needed: 17.4 MB / 465 GB available

Get:1 http://deb.debian.org/debian trixie/main arm64 libjemalloc2 arm64 5.3.0-3 [216 kB]
Get:2 http://deb.debian.org/debian trixie/main arm64 liblua5.4-0 arm64 5.4.7-1+b2 [134 kB]
Get:3 http://deb.debian.org/debian trixie/main arm64 libopentracing1 arm64 1.6.0-4+b2 [50.0 kB]
Get:4 http://deb.debian.org/debian trixie/main arm64 libopentracing-c-wrapper0t64 arm64 1.1.3-3.1+b1 [28.3 kB]
Get:5 http://deb.debian.org/debian trixie/main arm64 haproxy arm64 3.0.11-1+deb13u2 [2,501 kB]
Get:6 http://deb.debian.org/debian trixie/main arm64 ipvsadm arm64 1:1.31-5 [41.0 kB]
Get:7 http://deb.debian.org/debian trixie/main arm64 libsnmp-base all 5.9.4+dfsg-2+deb13u1 [1,770 kB]
Get:8 http://deb.debian.org/debian trixie/main arm64 libsnmp40t64 arm64 5.9.4+dfsg-2+deb13u1 [2,497 kB]
Get:9 http://deb.debian.org/debian trixie/main arm64 keepalived arm64 1:2.3.3-1 [566 kB]
Fetched 7,803 kB in 0s (22.1 MB/s)
Selecting previously unselected package libjemalloc2:arm64.
(Reading database ... 69388 files and directories currently installed.)
Preparing to unpack .../0-libjemalloc2_5.3.0-3_arm64.deb ...
Unpacking libjemalloc2:arm64 (5.3.0-3) ...
Selecting previously unselected package liblua5.4-0:arm64.
Preparing to unpack .../1-liblua5.4-0_5.4.7-1+b2_arm64.deb ...
Unpacking liblua5.4-0:arm64 (5.4.7-1+b2) ...
Selecting previously unselected package libopentracing1:arm64.
Preparing to unpack .../2-libopentracing1_1.6.0-4+b2_arm64.deb ...
Unpacking libopentracing1:arm64 (1.6.0-4+b2) ...
Selecting previously unselected package libopentracing-c-wrapper0t64:arm64.
Preparing to unpack .../3-libopentracing-c-wrapper0t64_1.1.3-3.1+b1_arm64.deb ...
Unpacking libopentracing-c-wrapper0t64:arm64 (1.1.3-3.1+b1) ...
Selecting previously unselected package haproxy.
Preparing to unpack .../4-haproxy_3.0.11-1+deb13u2_arm64.deb ...
Unpacking haproxy (3.0.11-1+deb13u2) ...
Selecting previously unselected package ipvsadm.
Preparing to unpack .../5-ipvsadm_1%3a1.31-5_arm64.deb ...
Unpacking ipvsadm (1:1.31-5) ...
Selecting previously unselected package libsnmp-base.
Preparing to unpack .../6-libsnmp-base_5.9.4+dfsg-2+deb13u1_all.deb ...
Unpacking libsnmp-base (5.9.4+dfsg-2+deb13u1) ...
Selecting previously unselected package libsnmp40t64:arm64.
Preparing to unpack .../7-libsnmp40t64_5.9.4+dfsg-2+deb13u1_arm64.deb ...
Unpacking libsnmp40t64:arm64 (5.9.4+dfsg-2+deb13u1) ...
Selecting previously unselected package keepalived.
Preparing to unpack .../8-keepalived_1%3a2.3.3-1_arm64.deb ...
Unpacking keepalived (1:2.3.3-1) ...
Setting up ipvsadm (1:1.31-5) ...
Created symlink '/etc/systemd/system/multi-user.target.wants/ipvsadm.service' → '/usr/lib/systemd/system/ipvsadm.service'.
Setting up libsnmp-base (5.9.4+dfsg-2+deb13u1) ...
Setting up libjemalloc2:arm64 (5.3.0-3) ...
Setting up liblua5.4-0:arm64 (5.4.7-1+b2) ...
Setting up libopentracing1:arm64 (1.6.0-4+b2) ...
Setting up libsnmp40t64:arm64 (5.9.4+dfsg-2+deb13u1) ...
Setting up keepalived (1:2.3.3-1) ...
Created symlink '/etc/systemd/system/multi-user.target.wants/keepalived.service' → '/usr/lib/systemd/system/keepalived.service'.
Setting up libopentracing-c-wrapper0t64:arm64 (1.1.3-3.1+b1) ...
Setting up haproxy (3.0.11-1+deb13u2) ...
Created symlink '/etc/systemd/system/multi-user.target.wants/haproxy.service' → '/usr/lib/systemd/system/haproxy.service'.
Processing triggers for dbus (1.16.2-2) ...
Processing triggers for libc-bin (2.41-12+rpt1+deb13u2) ...
Processing triggers for man-db (2.13.1-1) ...
```

next we need to create the keepalived config file:

```
vim vim /etc/keepalived/keepalived.conf
static_ipaddress {
    10.1.233.1 dev eth0 scope global
}

vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 99 # or 98 for the third node
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass password123
    }
    virtual_ipaddress {
      10.1.233.1
    }
}
```

Edit the /etc/sysctl.conf file to enable IP forwarding by adding or editing the following line:

```
net.ipv4.ip_forward = 1
net.ipv4.ip_nonlocal_bind = 1
```

Apply the changes to the kernel by running:

$ sudo sysctl -p
net.ipv4.ip_forward = 1
net.ipv4.ip_nonlocal_bind = 1

Before we are able to start the Keepalived service, we need to allow the service to advertise itself via multicast, which is currently blocked in our firewall settings (managed by ufw, as configured in lesson 7).

# Allow incoming VRRP multicast traffic

$ sudo ufw allow in to 224.0.0.18 comment 'Allow incoming VRRP multicast traffic'

# Allow outgoing VRRP multicast traffic

$ sudo ufw allow out to 224.0.0.18 comment 'Allow outgoing VRRP multicast traffic'

now that keepalived is configured lets restart the service:

```
root@kubernetes-node-2:/home/pi# systemctl start keepalived
root@kubernetes-node-2:/home/pi# systemctl enable keepalived
Synchronizing state of keepalived.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install enable keepalived
root@kubernetes-node-2:/home/pi# systemctl status keepalived
WARNING: terminal is not fully functional
Press RETURN to continue
● keepalived.service - Keepalive Daemon (LVS and VRRP)
     Loaded: loaded (/usr/lib/systemd/system/keepalived.service; enabled; preset: enabled)
     Active: active (running) since Tue 2026-04-28 21:29:28 CEST; 7s ago
 Invocation: 2b32ff91f7e84644a90741bd531849a4
       Docs: man:keepalived(8)
             man:keepalived.conf(5)
             man:genhash(1)
             https://keepalived.org
   Main PID: 11694 (keepalived)
      Tasks: 2 (limit: 9583)
     Memory: 3.5M (peak: 6.4M)
        CPU: 22ms
     CGroup: /system.slice/keepalived.service
             ├─11694 /usr/sbin/keepalived --dont-fork
             └─11695 /usr/sbin/keepalived --dont-fork

Apr 28 21:29:28 kubernetes-node-2 Keepalived[11694]: Starting Keepalived v2.3.3 (03/30,2025)
Apr 28 21:29:28 kubernetes-node-2 Keepalived[11694]: Running on Linux 6.12.75+rpt-rpi-2712 #1 SMP PREEMPT Debian 1:6.12.75-1+rpt1 (2026-03-11) (built for Linu>
Apr 28 21:29:28 kubernetes-node-2 Keepalived[11694]: Command line: '/usr/sbin/keepalived' '--dont-fork'
Apr 28 21:29:28 kubernetes-node-2 Keepalived[11694]: Configuration file /etc/keepalived/keepalived.conf
Apr 28 21:29:28 kubernetes-node-2 Keepalived[11694]: NOTICE: setting config option max_auto_priority should result in better keepalived performance
Apr 28 21:29:28 kubernetes-node-2 Keepalived[11694]: Starting VRRP child process, pid=11695
Apr 28 21:29:28 kubernetes-node-2 Keepalived_vrrp[11695]: (/etc/keepalived/keepalived.conf: Line 13) Truncating auth_pass to 8 characters
Apr 28 21:29:28 kubernetes-node-2 Keepalived[11694]: Startup complete
Apr 28 21:29:28 kubernetes-node-2 systemd[1]: Started keepalived.service - Keepalive Daemon (LVS and VRRP).
Apr 28 21:29:28 kubernetes-node-2 Keepalived_vrrp[11695]: (VI_1) Entering BACKUP STATE (init)
```

next we need to set up haproxy by appending the following to /etc/haproxy/haproxy.cfg

```
frontend kubernetes-api
    mode tcp
    bind 10.1.233.1:6443
    default_backend kube-apiservers
    option tcplog

backend kube-apiservers
    mode tcp
    balance roundrobin
    option tcp-check
    default-server inter 3s fall 3 rise 2
    server master-1 10.1.1.1:6443 check
    server master-2 10.1.1.2:6443 check
    server master-3 10.1.1.3:6443 check

# NGINX Ingress Controller Frontend
frontend nginx-ingress
    mode tcp
    bind 10.1.233.1:80
    bind 10.1.233.1:443
    default_backend ingress-backend
    option tcplog

# NGINX Ingress Controller Backend
backend ingress-backend
    mode tcp
    balance roundrobin
    option tcp-check
    default-server inter 3s fall 3 rise 2
    server node-1 10.1.1.1:30080 check
    server node-2 10.1.1.2:30080 check
    server node-3 10.1.1.3:30080 check

# Frontend for CoreDNS
frontend coredns
    mode tcp
    bind 10.1.233.1:30053
    default_backend coredns-backend
    option tcplog

# Backend for CoreDNS instances
backend coredns-backend
    mode tcp
    balance roundrobin
    option tcp-check
    default-server inter 2s fall 3 rise 2
    server dns-1 10.1.1.1:30053 check
    server dns-2 10.1.1.2:30053 check
    server dns-3 10.1.1.3:30053 check
```
