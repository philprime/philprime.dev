---
layout: guide-lesson.liquid
title: Installing Rocky Linux 9 on Node 4

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 2
guide_lesson_id: 5
guide_lesson_abstract: >
  Install and configure Rocky Linux 9 on Node 4, preparing it as the first node for the new RKE2 cluster.
guide_lesson_conclusion: >
  Node 4 is now running Rocky Linux 9 with all the necessary kernel modules and system configurations for Kubernetes.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-5.md
---

In this lesson, we'll install Rocky Linux 9 on Node 4 and configure it for Kubernetes workloads. Rocky Linux is a
community-driven, enterprise-grade Linux distribution that is 100% compatible with Red Hat Enterprise Linux.

{% include guide-overview-link.liquid.html %}

## Why Rocky Linux?

Rocky Linux offers several advantages for Kubernetes deployments:

- **RHEL compatibility**: Binary-compatible with Red Hat Enterprise Linux
- **Long-term support**: 10-year lifecycle with regular security updates
- **Enterprise stability**: Predictable updates and conservative approach to changes
- **SELinux support**: Full security-enhanced Linux integration
- **Wide ecosystem**: Excellent support for RKE2 and enterprise tools

## Installation Methods

Depending on your Hetzner server type, you have several options:

### Option A: Hetzner Robot Rescue System (Dedicated Servers)

1. Log into Hetzner Robot console
2. Navigate to your server (Node 4)
3. Select "Rescue" tab
4. Activate Linux rescue system
5. Reset the server

After the server boots into rescue mode:

```bash
# SSH into the rescue system
ssh root@<node4-public-ip>

# Run installimage
installimage
```

In the installimage menu:

1. Select "Rocky Linux"
2. Choose "Rocky-9"
3. Configure disk layout (see below)

### Option B: Hetzner Cloud (Virtual Servers)

If using Hetzner Cloud:

```bash
# Using hcloud CLI
hcloud server rebuild <server-id> --image rocky-9
```

### Option C: Manual Installation via KVM

For servers with KVM access:

1. Mount Rocky Linux 9 ISO
2. Boot from ISO
3. Follow standard installation wizard

## Recommended Disk Layout

For Kubernetes nodes, I recommend this partition layout:

```
DRIVE1 /dev/sda
├── /boot     512MB   ext4
├── /boot/efi 256MB   vfat    (if UEFI)
├── swap      8GB     swap
├── /         50GB    xfs
└── /var/lib  rest    xfs     (for container storage)
```

In `installimage`, configure like this:

```bash
# Example installimage config
SWRAID 0
SWRAIDLEVEL 0
BOOTLOADER grub
HOSTNAME node4
PART /boot ext4 512M
PART /boot/efi vfat 256M
PART swap swap 8G
PART / xfs 50G
PART /var/lib xfs all
IMAGE /root/.oldroot/nfs/images/Rocky-9-latest-amd64-base.tar.gz
```

## Post-Installation Configuration

After Rocky Linux is installed and the server reboots:

```bash
# SSH into the new system
ssh root@<node4-public-ip>

# Verify installation
cat /etc/os-release
```

### Update the System

```bash
# Update all packages
dnf update -y

# Reboot if kernel was updated
needs-restarting -r || reboot
```

### Set Hostname

```bash
# Set a descriptive hostname
hostnamectl set-hostname node4.k8s.example.com

# Verify
hostname -f
```

### Configure Timezone

```bash
# Set timezone (adjust for your location)
timedatectl set-timezone Europe/Berlin

# Verify
timedatectl
```

### Disable SELinux (or Configure for RKE2)

RKE2 can work with SELinux, but for simplicity during migration, we'll set it to permissive:

```bash
# Check current status
getenforce

# Set to permissive
setenforce 0

# Make persistent
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Verify
grep ^SELINUX= /etc/selinux/config
```

{% include alert.liquid.html type='note' title='SELinux Note' content='
If you require SELinux enforcement, RKE2 includes SELinux policies. You can enable enforcement after the cluster is stable by setting SELINUX=enforcing and rebooting.
' %}

### Configure Kernel Modules

Kubernetes requires specific kernel modules for networking:

```bash
# Create module configuration
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Load modules immediately
modprobe overlay
modprobe br_netfilter

# Verify modules are loaded
lsmod | grep -E "overlay|br_netfilter"
```

### Configure Sysctl Parameters

Set required kernel parameters for Kubernetes networking:

```bash
# Create sysctl configuration
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl settings
sysctl --system

# Verify settings
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.ipv4.ip_forward
```

### Disable Swap (Optional but Recommended)

While newer Kubernetes versions support swap, it's traditionally disabled:

```bash
# Disable swap immediately
swapoff -a

# Remove swap from fstab to persist across reboots
sed -i '/swap/d' /etc/fstab

# Verify
free -h | grep Swap
```

### Install Essential Tools

Install tools that will be useful for cluster management:

```bash
# Install essential packages
dnf install -y \
    curl \
    wget \
    vim \
    git \
    bash-completion \
    tar \
    unzip \
    net-tools \
    bind-utils \
    tcpdump \
    htop \
    iotop \
    jq \
    yq

# Install container tools (useful for debugging)
dnf install -y \
    container-selinux \
    iptables-nft
```

### Configure SSH

Ensure SSH is properly configured for secure access:

```bash
# Verify SSH service
systemctl status sshd

# Recommended: Add your SSH key if not already done
mkdir -p ~/.ssh
chmod 700 ~/.ssh
# Add your public key to ~/.ssh/authorized_keys
```

## Verify System Readiness

Run these checks to ensure the system is ready for RKE2:

```bash
# 1. Check kernel version (should be 5.14+)
uname -r

# 2. Verify modules
lsmod | grep -E "overlay|br_netfilter"

# 3. Verify sysctl
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables

# 4. Check available memory
free -h

# 5. Check disk space
df -h /var/lib

# 6. Verify DNS resolution
nslookup google.com

# 7. Verify internet connectivity
curl -s https://get.rke2.io > /dev/null && echo "Internet OK"
```

## System Information

Document the system information for your records:

```bash
# Generate system summary
echo "=== Node 4 System Information ===" > /root/node4-info.txt
echo "Hostname: $(hostname -f)" >> /root/node4-info.txt
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME)" >> /root/node4-info.txt
echo "Kernel: $(uname -r)" >> /root/node4-info.txt
echo "CPU: $(lscpu | grep 'Model name')" >> /root/node4-info.txt
echo "Memory: $(free -h | grep Mem | awk '{print $2}')" >> /root/node4-info.txt
echo "Disk: $(df -h / | tail -1 | awk '{print $2}')" >> /root/node4-info.txt
cat /root/node4-info.txt
```

With Rocky Linux 9 installed and configured, Node 4 is ready for network configuration. In the next lesson, we'll
set up the Hetzner vSwitch private networking.
