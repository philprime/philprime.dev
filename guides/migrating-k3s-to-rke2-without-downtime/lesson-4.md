---
layout: guide-lesson.liquid
title: Prerequisites and Infrastructure Audit

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 1
guide_lesson_id: 4
guide_lesson_abstract: >
  Audit your existing infrastructure, verify all prerequisites, and prepare the necessary tools and access for the
  migration.
guide_lesson_conclusion: >
  Your infrastructure audit is complete and you have verified all prerequisites are in place for the migration.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-4.md
---

Before beginning the migration, we need to thoroughly audit the existing infrastructure and ensure all prerequisites
are in place. This lesson provides checklists and commands to verify your readiness.

{% include guide-overview-link.liquid.html %}

## Hardware Requirements

Verify each node meets the minimum requirements for RKE2:

| Component      | Minimum | Recommended              |
| -------------- | ------- | ------------------------ |
| CPU            | 2 cores | 4+ cores                 |
| RAM            | 4 GB    | 8+ GB                    |
| Storage (OS)   | 20 GB   | 50+ GB SSD               |
| Storage (etcd) | -       | Separate SSD recommended |
| Network        | 1 Gbps  | 10 Gbps for production   |

### Verify Current Nodes

Run these commands on each node to verify hardware:

```bash
# CPU information
lscpu | grep -E "^CPU\(s\)|^Model name"

# Memory
free -h | grep Mem

# Disk space
df -h /

# Network interfaces
ip link show
```

## Network Requirements

### Hetzner vSwitch Configuration

Ensure your vSwitch is properly configured:

```bash
# Verify private network interface exists
ip addr show | grep -A 2 "enp"

# Check routing
ip route

# Test connectivity between nodes (from each node)
ping -c 3 <other-node-private-ip>
```

### Required Ports

These ports must be accessible between cluster nodes:

| Port      | Protocol | Component       | Direction                  |
| --------- | -------- | --------------- | -------------------------- |
| 6443      | TCP      | Kubernetes API  | All nodes → Control planes |
| 9345      | TCP      | RKE2 supervisor | Workers → Control planes   |
| 2379-2380 | TCP      | etcd            | Control planes only        |
| 10250     | TCP      | Kubelet         | All nodes                  |
| 8472      | UDP      | Cilium VXLAN    | All nodes                  |
| 4240      | TCP      | Cilium health   | All nodes                  |

### DNS Requirements

Verify DNS configuration:

```bash
# Check DNS resolution
nslookup google.com
dig +short google.com

# Verify /etc/resolv.conf
cat /etc/resolv.conf
```

## Audit Cluster A (k3s)

### Cluster Health

```bash
# Node status
kubectl get nodes -o wide

# System pods
kubectl get pods -n kube-system

# All pods health
kubectl get pods -A | grep -v Running

# Resource usage
kubectl top nodes
kubectl top pods -A
```

### Workload Inventory

Create a complete inventory of running workloads:

```bash
# Namespaces
kubectl get namespaces

# Deployments
kubectl get deployments -A -o wide

# StatefulSets
kubectl get statefulsets -A -o wide

# DaemonSets
kubectl get daemonsets -A -o wide

# Services
kubectl get svc -A

# Ingress resources
kubectl get ingress -A
```

### Storage Audit

Understand your current storage configuration:

```bash
# Storage classes
kubectl get storageclass

# Persistent Volumes
kubectl get pv

# Persistent Volume Claims
kubectl get pvc -A

# Check actual data sizes
kubectl get pvc -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {.status.capacity.storage}{"\n"}{end}'
```

### Secrets and ConfigMaps

Inventory configuration that will need migration:

```bash
# Secrets (excluding service account tokens)
kubectl get secrets -A | grep -v "kubernetes.io/service-account-token"

# ConfigMaps
kubectl get configmaps -A | grep -v "kube-root-ca.crt"

# Export critical secrets (be careful with these!)
# Only run if you have secure storage for the output
kubectl get secrets -n <namespace> <secret-name> -o yaml > secret-backup.yaml
```

### Network Policies

Check existing network policies:

```bash
# List network policies
kubectl get networkpolicies -A

# Export for review (may need adjustment for Cilium)
kubectl get networkpolicies -A -o yaml > networkpolicies-backup.yaml
```

## Required Tools and Access

### Local Machine Tools

Ensure you have these tools installed on your workstation:

```bash
# kubectl
kubectl version --client

# Helm (for Cilium, Longhorn, Traefik installation)
helm version

# hcloud CLI (Hetzner Cloud management)
hcloud version

# SSH client
ssh -V
```

### Server Access

Verify you have appropriate access to all nodes:

```bash
# SSH access to all nodes
ssh root@node1 "hostname"
ssh root@node2 "hostname"
ssh root@node3 "hostname"
ssh root@node4 "hostname"

# Out-of-band access (IPMI/KVM) - verify in Hetzner Robot console
# This is critical for OS reinstallation
```

### Hetzner Requirements

Verify Hetzner resources:

```bash
# List servers
hcloud server list

# List vSwitch (if using hcloud-cli with Robot API access)
# Or verify in Hetzner Robot console

# Verify Cloud Load Balancer quota
hcloud load-balancer list
```

## Backup Verification

### k3s etcd Backup

Create and verify a backup of the k3s data:

```bash
# On the k3s control plane node (Node 1)
sudo k3s etcd-snapshot save --name pre-migration-$(date +%Y%m%d)

# List snapshots
sudo k3s etcd-snapshot ls

# Verify snapshot file
ls -la /var/lib/rancher/k3s/server/db/snapshots/
```

### Persistent Data Backup

For each PersistentVolume, ensure you have a backup strategy:

```bash
# Example: backup using kubectl exec
kubectl exec -n <namespace> <pod-name> -- tar czf - /data > backup.tar.gz

# Or use your backup tool (Velero, Kasten, etc.)
velero backup describe <backup-name>
```

## Pre-Migration Checklist

Complete this checklist before proceeding:

### Infrastructure

- [ ] All 4 nodes meet hardware requirements
- [ ] vSwitch configured and tested between nodes
- [ ] SSH access to all nodes verified
- [ ] IPMI/KVM access available for OS reinstallation
- [ ] Hetzner Cloud Load Balancer quota available

### Cluster A Health

- [ ] All nodes in Ready state
- [ ] No pods in error state
- [ ] etcd backup created and verified
- [ ] Workload inventory documented

### Storage

- [ ] All PVCs documented
- [ ] Backup strategy for each PVC
- [ ] Backups created and verified

### Network

- [ ] Required ports documented
- [ ] DNS TTL lowered (recommend 300s)
- [ ] Ingress configuration documented

### Access and Tools

- [ ] kubectl configured for Cluster A
- [ ] Helm 3.x installed
- [ ] hcloud CLI configured
- [ ] Rocky Linux 9 installation media/rescue system ready

### Documentation

- [ ] Current cluster state documented
- [ ] Rollback procedures documented
- [ ] Stakeholders notified

## Node 4 Preparation

Before we begin Section 2, verify Node 4 is ready:

```bash
# If Node 4 already has an OS
ssh root@node4 "uname -a"

# If Node 4 needs OS installation
# Verify rescue system access in Hetzner Robot

# Verify network connectivity to other nodes
# (from any existing node)
ping -c 3 <node4-private-ip>
```

## Infrastructure Diagram

Document your current network topology:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            HETZNER INFRASTRUCTURE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Public Network (Internet)                                                 │
│   ┌────────────────────────────────────────────────────────────────────┐   │
│   │  Node 1: x.x.x.1    Node 2: x.x.x.2    Node 3: x.x.x.3    Node 4   │   │
│   └────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│   vSwitch Private Network (10.1.1.0/24)                                    │
│   ┌────────────────────────────────────────────────────────────────────┐   │
│   │  Node 1: 10.1.1.1  Node 2: 10.1.1.2  Node 3: 10.1.1.3  Node 4: ?   │   │
│   └────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│   Current Cluster A (k3s)          Target Cluster B (RKE2)                 │
│   ┌────────────────────────┐       ┌────────────────────────┐             │
│   │ CP: Node 1             │       │ CP: Node 2             │             │
│   │ Workers: Node 2, 3     │   →   │ CP: Node 3             │             │
│   │                        │       │ CP: Node 4             │             │
│   │                        │       │ Worker: Node 1         │             │
│   └────────────────────────┘       └────────────────────────┘             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

Fill in your actual IP addresses and save this diagram for reference during the migration.

With the audit complete and all prerequisites verified, we're ready to begin the hands-on work. In the next section,
we'll install Rocky Linux on Node 4 and bootstrap the first RKE2 control plane.
