---
layout: guide-lesson.liquid
title: Adding Node 1 as RKE2 Worker

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 5
guide_lesson_id: 24
guide_lesson_abstract: >
  Install Rocky Linux 9 on Node 1 and configure it as an RKE2 worker node to complete the cluster.
guide_lesson_conclusion: >
  Node 1 has joined Cluster B as a worker node, completing the 4-node cluster configuration.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-24.md
---

With k3s decommissioned, we'll now install Rocky Linux 9 on Node 1 and add it to Cluster B as a worker node.

{% include guide-overview-link.liquid.html %}

## Current State

```
Before:                         After:
┌─────────────────────┐        ┌─────────────────────┐
│ Node 1 (empty)      │        │ Node 1 (Worker) ✓   │
│                     │        │                     │
│ Node 2 (CP)         │   →    │ Node 2 (CP)         │
│ Node 3 (CP)         │        │ Node 3 (CP)         │
│ Node 4 (CP)         │        │ Node 4 (CP)         │
└─────────────────────┘        └─────────────────────┘
    3 CP nodes                     3 CP + 1 Worker
```

## Install Rocky Linux 9

Follow the same process as previous nodes:

### Using Hetzner Rescue System

```bash
# SSH into rescue system
ssh root@<node1-public-ip>

# Run installimage
installimage

# Select Rocky-9, configure partitions as before
```

### Post-Installation

```bash
# After reboot, SSH into the new system
ssh root@node1

# Update system
dnf update -y

# Set hostname
hostnamectl set-hostname node1.k8s.example.com
```

## Configure System for Kubernetes

Apply the same configurations as other nodes:

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

# Install essential tools
dnf install -y curl wget vim git bash-completion jq
```

## Configure Hetzner vSwitch

```bash
# Configure vSwitch interface
nmcli connection add \
    type vlan \
    con-name vswitch \
    dev enp0s31f6 \
    id 4000 \
    ipv4.method manual \
    ipv4.addresses 10.1.1.1/24 \
    ipv6.method disabled

nmcli connection up vswitch

# Verify connectivity
ping -c 3 10.1.1.2
ping -c 3 10.1.1.3
ping -c 3 10.1.1.4
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

Worker nodes need fewer ports than control planes:

```bash
# Enable firewalld
systemctl enable --now firewalld

# Create kubernetes zone
firewall-cmd --permanent --new-zone=kubernetes

# Add vSwitch interface
firewall-cmd --permanent --zone=kubernetes --add-interface=enp0s31f6.4000

# Worker node ports (subset of control plane ports)
firewall-cmd --permanent --zone=kubernetes --add-port=10250/tcp    # Kubelet
firewall-cmd --permanent --zone=kubernetes --add-port=8472/udp     # Cilium VXLAN
firewall-cmd --permanent --zone=kubernetes --add-port=4240/tcp     # Cilium health
firewall-cmd --permanent --zone=kubernetes --add-port=30000-32767/tcp  # NodePorts
firewall-cmd --permanent --zone=kubernetes --add-port=30000-32767/udp
firewall-cmd --permanent --zone=kubernetes --add-port=30080/tcp    # Traefik HTTP
firewall-cmd --permanent --zone=kubernetes --add-port=30443/tcp    # Traefik HTTPS
firewall-cmd --permanent --zone=kubernetes --add-masquerade
firewall-cmd --permanent --zone=kubernetes --add-protocol=icmp

# Reload
firewall-cmd --reload
firewall-cmd --zone=kubernetes --list-all
```

## Install RKE2 Agent

Unlike control plane nodes, workers install the agent component:

```bash
# Install RKE2 agent
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -

# Enable the service
systemctl enable rke2-agent.service
```

## Configure RKE2 Agent

Get the cluster token from an existing control plane node:

```bash
# On any control plane node (e.g., node4):
# cat /root/rke2-token.txt

# Or find it in the config:
# grep token /etc/rancher/rke2/config.yaml
```

Configure the agent on Node 1:

```bash
# Create configuration directory
mkdir -p /etc/rancher/rke2

# Get token from control plane
TOKEN="<your-cluster-token>"

# Create agent configuration
cat <<EOF > /etc/rancher/rke2/config.yaml
# Connect to control plane (can use any control plane node)
server: https://10.1.1.4:9345

# Cluster token
token: ${TOKEN}

# Network configuration
node-ip: 10.1.1.1
EOF
```

## Start RKE2 Agent

```bash
# Start the agent
systemctl start rke2-agent.service

# Watch the startup logs
journalctl -u rke2-agent -f
```

Wait for the node to join. You should see messages like:

```
level=info msg="Starting rke2 agent..."
level=info msg="Connecting to proxy"
level=info msg="Running kubelet..."
```

## Verify Node Joined

### From a Control Plane Node

```bash
# Check nodes
kubectl get nodes -o wide

# Expected output:
# NAME    STATUS   ROLES                       AGE   VERSION          INTERNAL-IP
# node1   Ready    <none>                      1m    v1.28.x+rke2r1   10.1.1.1
# node2   Ready    control-plane,etcd,master   2d    v1.28.x+rke2r1   10.1.1.2
# node3   Ready    control-plane,etcd,master   2d    v1.28.x+rke2r1   10.1.1.3
# node4   Ready    control-plane,etcd,master   3d    v1.28.x+rke2r1   10.1.1.4
```

Note that Node 1 has no roles (worker only).

### Label the Worker Node (Optional)

```bash
# Add worker label for clarity
kubectl label node node1 node-role.kubernetes.io/worker=true

# Verify
kubectl get nodes

# Now shows:
# NAME    STATUS   ROLES                       AGE   VERSION
# node1   Ready    worker                      5m    v1.28.x+rke2r1
# node2   Ready    control-plane,etcd,master   2d    v1.28.x+rke2r1
# ...
```

## Verify Cilium

Cilium should automatically deploy to the new node:

```bash
# Check Cilium pods
kubectl get pods -n kube-system -l k8s-app=cilium -o wide

# Should show 4 pods, one per node
# cilium-xxxxx   1/1   Running   0   1m   10.1.1.1   node1
# ...
```

## Verify Traefik

Traefik DaemonSet should deploy to the worker:

```bash
# Check Traefik pods
kubectl get pods -n traefik -o wide

# Should show 4 pods, one per node
```

## Add Node 1 to Load Balancer

Add Node 1 as a target in the Hetzner Load Balancer:

```bash
# Add Node 1 to load balancer
hcloud load-balancer add-target k8s-ingress \
  --server node1-servername \
  --use-private-ip

# Verify targets
hcloud load-balancer describe k8s-ingress

# Check target health (may take a minute)
hcloud load-balancer describe k8s-ingress -o json | jq '.targets[].health_status'
```

## Test Worker Node

### Schedule a Test Pod on Node 1

```bash
# Create a test pod that specifically schedules on node1
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-worker-node1
spec:
  nodeSelector:
    kubernetes.io/hostname: node1
  containers:
  - name: test
    image: nginx:alpine
    ports:
    - containerPort: 80
EOF

# Verify pod is on node1
kubectl get pod test-worker-node1 -o wide

# Test the pod
kubectl exec test-worker-node1 -- curl -s localhost

# Cleanup
kubectl delete pod test-worker-node1
```

## Verify Full Cluster

```bash
# Check all nodes
kubectl get nodes -o wide

# Check node resources
kubectl top nodes

# Check pod distribution
kubectl get pods -A -o wide | grep node1

# Run full cluster check
/root/validation-report.sh
```

## Update Documentation

```bash
cat <<EOF >> /root/migration-log.txt

=== Node 1 Added as Worker ===
Timestamp: $(date)

Node 1 configuration:
- Role: Worker (agent)
- IP: 10.1.1.1
- OS: Rocky Linux 9
- RKE2: Agent mode

Final cluster configuration:
- node1: worker
- node2: control-plane, etcd, master
- node3: control-plane, etcd, master
- node4: control-plane, etcd, master

Total: 3 control plane + 1 worker = 4 nodes

Load Balancer updated: YES
Traefik running on node1: YES
Cilium running on node1: YES

MIGRATION COMPLETE!
EOF
```

## Summary

The cluster is now complete:

| Node  | Role          | IP       |
| ----- | ------------- | -------- |
| node1 | Worker        | 10.1.1.1 |
| node2 | Control Plane | 10.1.1.2 |
| node3 | Control Plane | 10.1.1.3 |
| node4 | Control Plane | 10.1.1.4 |

- **3 control plane nodes** for HA
- **1 worker node** for dedicated workload capacity
- **4 nodes in load balancer** for HA ingress
- **All workloads migrated** from k3s

In the final lesson, we'll cover post-migration cleanup and documentation.
