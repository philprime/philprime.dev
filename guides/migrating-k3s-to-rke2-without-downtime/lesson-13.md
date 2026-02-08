---
layout: guide-lesson.liquid
title: Installing Rocky Linux and RKE2 on Node 3

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 3
guide_lesson_id: 13
guide_lesson_abstract: >
  Install Rocky Linux 9 on Node 3 and join it to Cluster B as the second control plane node.
guide_lesson_conclusion: >
  Node 3 is now running RKE2 as the second control plane node in Cluster B, with etcd showing 2 members.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-13.md
---

With Node 3 drained and removed from Cluster A, we'll now install Rocky Linux 9 and configure it as an RKE2
control plane node to join Cluster B.

{% include guide-overview-link.liquid.html %}

## Install Rocky Linux 9

Follow the same installation process as Node 4 (Lesson 5).

### Using Hetzner Rescue System

```bash
# SSH into rescue system
ssh root@<node3-public-ip>

# Run installimage
installimage

# Select Rocky-9 and configure partitions
```

### Post-Installation

After reboot:

```bash
# SSH into the new system
ssh root@node3

# Update system
dnf update -y

# Set hostname
hostnamectl set-hostname node3.k8s.example.com
```

## Configure System for Kubernetes

Apply the same configurations as Node 4:

```bash
# SELinux
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# Sysctl settings
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# Disable swap
swapoff -a
sed -i '/swap/d' /etc/fstab
```

## Configure Hetzner vSwitch

Configure the private network interface:

```bash
# Create VLAN interface (adjust interface name and VLAN ID for your setup)
nmcli connection add \
    type vlan \
    con-name vswitch \
    dev enp0s31f6 \
    id 4000 \
    ipv4.method manual \
    ipv4.addresses 10.1.1.3/24 \
    ipv6.method disabled

# Bring up the connection
nmcli connection up vswitch

# Verify connectivity
ping -c 3 10.1.1.4  # Should reach Node 4
```

## Configure /etc/hosts

```bash
cat <<EOF >> /etc/hosts

# Kubernetes Cluster Nodes
10.1.1.1  node1 node1.k8s.example.com
10.1.1.2  node2 node2.k8s.example.com
10.1.1.3  node3 node3.k8s.example.com
10.1.1.4  node4 node4.k8s.example.com
EOF
```

## Configure Firewall

Apply the same firewall rules as Node 4:

```bash
# Enable firewalld
systemctl enable --now firewalld

# Create kubernetes zone
firewall-cmd --permanent --new-zone=kubernetes

# Add vSwitch interface
firewall-cmd --permanent --zone=kubernetes --add-interface=enp0s31f6.4000

# Add all required ports (control plane)
firewall-cmd --permanent --zone=kubernetes --add-port=6443/tcp
firewall-cmd --permanent --zone=kubernetes --add-port=9345/tcp
firewall-cmd --permanent --zone=kubernetes --add-port=2379/tcp
firewall-cmd --permanent --zone=kubernetes --add-port=2380/tcp
firewall-cmd --permanent --zone=kubernetes --add-port=10250/tcp
firewall-cmd --permanent --zone=kubernetes --add-port=8472/udp
firewall-cmd --permanent --zone=kubernetes --add-port=4240/tcp
firewall-cmd --permanent --zone=kubernetes --add-port=30000-32767/tcp
firewall-cmd --permanent --zone=kubernetes --add-port=30000-32767/udp
firewall-cmd --permanent --zone=kubernetes --add-port=30080/tcp
firewall-cmd --permanent --zone=kubernetes --add-port=30443/tcp
firewall-cmd --permanent --zone=kubernetes --add-masquerade
firewall-cmd --permanent --zone=kubernetes --add-protocol=icmp

# Reload
firewall-cmd --reload
```

## Install RKE2

```bash
# Install RKE2
curl -sfL https://get.rke2.io | sh -

# Enable the service
systemctl enable rke2-server.service
```

## Configure RKE2 to Join Cluster B

This is the key difference from Node 4 - we configure Node 3 to join the existing cluster:

```bash
# Create configuration directory
mkdir -p /etc/rancher/rke2

# Get the token from Node 4
# You saved this in /root/rke2-token.txt on Node 4
TOKEN="<your-cluster-token>"

# Create configuration to join the existing cluster
cat <<EOF > /etc/rancher/rke2/config.yaml
# Join existing cluster
server: https://10.1.1.4:9345

# Use the same token as the first node
token: ${TOKEN}

# TLS SANs for this node
tls-san:
  - node3
  - node3.k8s.example.com
  - 10.1.1.3

# Disable CNI (Cilium is already installed)
cni: none

# Network configuration
node-ip: 10.1.1.3
advertise-address: 10.1.1.3

# Cluster configuration (must match Node 4)
cluster-cidr: 10.42.0.0/16
service-cidr: 10.43.0.0/16
cluster-dns: 10.43.0.10
EOF
```

## Start RKE2 Server

```bash
# Start RKE2
systemctl start rke2-server.service

# Watch the startup
journalctl -u rke2-server -f
```

Wait for the node to join the cluster. You should see messages like:

```
level=info msg="Waiting to retrieve agent configuration; server is not ready"
level=info msg="Starting etcd member..."
level=info msg="etcd member started"
level=info msg="Running kube-apiserver..."
```

This process takes a few minutes as the node:

1. Contacts the existing cluster
2. Joins the etcd cluster
3. Starts control plane components
4. Syncs with existing state

## Verify Node Joined

### Check from Node 3

```bash
# Set up kubectl
mkdir -p ~/.kube
cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
chmod 600 ~/.kube/config
export PATH=$PATH:/var/lib/rancher/rke2/bin

# Check nodes
kubectl get nodes

# Expected output:
# NAME    STATUS   ROLES                       AGE   VERSION
# node3   Ready    control-plane,etcd,master   1m    v1.28.x+rke2r1
# node4   Ready    control-plane,etcd,master   2h    v1.28.x+rke2r1
```

### Check from Node 4

```bash
# SSH to Node 4
ssh root@node4

# Verify both nodes
kubectl get nodes -o wide
```

## Verify etcd Cluster

The etcd cluster should now have 2 members:

```bash
# On Node 3 or Node 4
/var/lib/rancher/rke2/bin/etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/rancher/rke2/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/rke2/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/rke2/server/tls/etcd/server-client.key \
  member list

# Expected output:
# xxxx, started, node3-xxxx, https://10.1.1.3:2380, https://10.1.1.3:2379, false
# yyyy, started, node4-xxxx, https://10.1.1.4:2380, https://10.1.1.4:2379, true

# Check endpoint health
etcdctl endpoint health --cluster

# Both endpoints should be healthy
```

## Verify Cilium

Cilium should automatically deploy to Node 3:

```bash
# Check Cilium pods
kubectl get pods -n kube-system -l k8s-app=cilium

# Should show pods on both nodes:
# NAME           READY   STATUS    RESTARTS   AGE
# cilium-xxxxx   1/1     Running   0          2m    (node3)
# cilium-yyyyy   1/1     Running   0          2h    (node4)

# Check Cilium status
cilium status
```

## Verify System Pods

```bash
# Check all system pods
kubectl get pods -n kube-system -o wide

# All pods should be Running
# CoreDNS, Cilium, and other components should be distributed
```

## Current Cluster State

```
Cluster A (k3s):          Cluster B (RKE2):
┌─────────────────┐       ┌─────────────────┐
│ Node 1 (CP)     │       │ Node 3 (CP) ✓   │
│ Node 2 (Worker) │       │ Node 4 (CP) ✓   │
│                 │       │                 │
└─────────────────┘       └─────────────────┘
  2 nodes (stable)          2 nodes (NOT yet HA)
```

{% include alert.liquid.html type='warning' title='Not Yet HA' content='
With 2 control plane nodes, Cluster B is NOT yet highly available. An etcd cluster needs 3 members for quorum tolerance. If one node fails, etcd loses quorum. Proceed with Node 2 migration to achieve HA.
' %}

## Troubleshooting

### Node Won't Join

```bash
# Check connectivity to Node 4
ping -c 3 10.1.1.4
nc -zv 10.1.1.4 9345

# Verify token matches
cat /etc/rancher/rke2/config.yaml | grep token

# Check RKE2 logs for errors
journalctl -u rke2-server -n 100 | grep -i error
```

### etcd Issues

```bash
# Check etcd logs
journalctl -u rke2-server | grep etcd

# Verify etcd can reach other members
nc -zv 10.1.1.4 2380
```

### Certificate Issues

```bash
# Verify certificates
ls -la /var/lib/rancher/rke2/server/tls/

# Check certificate validity
openssl x509 -in /var/lib/rancher/rke2/server/tls/server-ca.crt -text -noout | head -20
```

## Record Progress

```bash
cat <<EOF >> /root/migration-log.txt
=== Node 3 Joined Cluster B ===
Timestamp: $(date)
Cluster B nodes: $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
etcd members: 2
HA Status: Not yet (need 3 members)
EOF
```

In the next lesson, we'll migrate Node 2 to achieve full HA with 3 control plane nodes.
