---
layout: guide-lesson.liquid
title: "Achieving HA: Verifying 3-Node Control Plane"

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 3
guide_lesson_id: 15
guide_lesson_abstract: >
  Comprehensively verify the 3-node RKE2 control plane, test HA capabilities, and confirm readiness for workload migration.
guide_lesson_conclusion: >
  The 3-node control plane is verified as highly available and ready to receive production workloads.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-15.md
---

With all three control plane nodes running, we need to thoroughly verify the cluster's high availability before
migrating production workloads.

{% include guide-overview-link.liquid.html %}

## HA Verification Overview

We'll verify:

1. etcd cluster health and quorum
2. Control plane component distribution
3. Failover capability
4. Network connectivity between all nodes
5. System pod distribution

## 1. etcd Cluster Verification

### Check Member Status

```bash
# List all etcd members
etcdctl member list --write-out=table

# Expected output:
# +------------------+---------+-------------+------------------------+------------------------+------------+
# |        ID        | STATUS  |    NAME     |       PEER ADDRS       |      CLIENT ADDRS      | IS LEARNER |
# +------------------+---------+-------------+------------------------+------------------------+------------+
# | xxxxxxxxxxxxx    | started | node2-xxxxx | https://10.1.1.2:2380  | https://10.1.1.2:2379  |      false |
# | yyyyyyyyyyyyy    | started | node3-xxxxx | https://10.1.1.3:2380  | https://10.1.1.3:2379  |      false |
# | zzzzzzzzzzzzz    | started | node4-xxxxx | https://10.1.1.4:2380  | https://10.1.1.4:2379  |      false |
# +------------------+---------+-------------+------------------------+------------------------+------------+
```

### Check Endpoint Health

```bash
# Check all endpoints
etcdctl endpoint health --cluster

# Expected:
# https://10.1.1.2:2379 is healthy: successfully committed proposal: took = 5.123ms
# https://10.1.1.3:2379 is healthy: successfully committed proposal: took = 4.567ms
# https://10.1.1.4:2379 is healthy: successfully committed proposal: took = 5.789ms
```

### Check Leader Status

```bash
# Get detailed endpoint status
etcdctl endpoint status --cluster --write-out=table

# Expected: One node shows IS LEADER = true
# +------------------------+------------------+---------+---------+-----------+------------+-----------+...+----------+
# |        ENDPOINT        |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | ..| RAFT IDX |
# +------------------------+------------------+---------+---------+-----------+------------+-----------+...+----------+
# | https://10.1.1.2:2379  | xxxx             | 3.5.x   | 6.1 MB  | false     | false      | 3         | ..| 12345    |
# | https://10.1.1.3:2379  | yyyy             | 3.5.x   | 6.1 MB  | false     | false      | 3         | ..| 12345    |
# | https://10.1.1.4:2379  | zzzz             | 3.5.x   | 6.1 MB  | true      | false      | 3         | ..| 12345    |
# +------------------------+------------------+---------+---------+-----------+------------+-----------+...+----------+
```

## 2. Test Failover Capability

### Simulate Node Failure (Non-Destructive)

Test that the cluster remains operational if one node's etcd is temporarily unavailable:

```bash
# On Node 4, temporarily stop RKE2 (or use any node except the leader)
# Note: This will cause temporary disruption to THIS node only
# The cluster should remain functional

# From your workstation, monitor cluster
watch kubectl get nodes

# In another terminal, on Node 4:
ssh root@node4 "systemctl stop rke2-server"

# Wait 30 seconds and observe:
# - Node 4 should become NotReady
# - etcd should elect new leader
# - kubectl commands should still work (might be slow briefly)

# Check etcd (from Node 2 or 3)
ssh root@node3 "etcdctl member list"
ssh root@node3 "etcdctl endpoint health --cluster"

# One endpoint will be unhealthy, but cluster functions

# Restart Node 4
ssh root@node4 "systemctl start rke2-server"

# Wait for recovery
watch kubectl get nodes
```

{% include alert.liquid.html type='info' title='Test Carefully' content='
Only perform this test if you are confident in your ability to recover. The cluster should handle single-node failure gracefully, but always have rollback plans ready.
' %}

### Verify Leader Election

```bash
# After restart, check leader status
etcdctl endpoint status --cluster --write-out=table

# A new leader may have been elected (or the same node if it recovered quickly)
```

## 3. Control Plane Component Verification

### Check API Server Endpoints

```bash
# List API server endpoints
kubectl get endpoints -n default kubernetes

# Should show all 3 control plane IPs:
# NAME         ENDPOINTS                                         AGE
# kubernetes   10.1.1.2:6443,10.1.1.3:6443,10.1.1.4:6443        3h
```

### Verify Controller Manager and Scheduler

These run as leader-elected singletons:

```bash
# Check controller-manager leader
kubectl get leases -n kube-system kube-controller-manager -o yaml | grep holderIdentity

# Check scheduler leader
kubectl get leases -n kube-system kube-scheduler -o yaml | grep holderIdentity

# Both should show one of the nodes as the holder
```

## 4. Network Connectivity Matrix

### Test Node-to-Node Connectivity

```bash
# Create a connectivity test script
cat <<'SCRIPT' > /root/test-connectivity.sh
#!/bin/bash
NODES="10.1.1.2 10.1.1.3 10.1.1.4"

echo "=== Connectivity Matrix ==="
for from in $NODES; do
    for to in $NODES; do
        if [ "$from" != "$to" ]; then
            result=$(ssh -o ConnectTimeout=2 root@$from "ping -c 1 -W 1 $to > /dev/null 2>&1 && echo OK || echo FAIL")
            echo "$from -> $to: $result"
        fi
    done
done

echo ""
echo "=== API Server Accessibility ==="
for node in $NODES; do
    for api in $NODES; do
        result=$(ssh -o ConnectTimeout=2 root@$node "nc -zv -w 2 $api 6443 2>&1 | grep -q succeeded && echo OK || echo FAIL")
        echo "$node -> $api:6443: $result"
    done
done
SCRIPT

chmod +x /root/test-connectivity.sh
/root/test-connectivity.sh
```

### Verify Cilium Connectivity

```bash
# Run Cilium connectivity test
cilium connectivity test

# This performs comprehensive network tests
# Some tests may be skipped on control-plane-only clusters
```

## 5. System Pod Distribution

### Check Pod Distribution

```bash
# Get pods with node assignment
kubectl get pods -n kube-system -o wide

# Verify pods are distributed:
# - Cilium: one per node
# - CoreDNS: distributed (usually 2 replicas)
# - Other components: appropriately placed
```

### Check for Pending Pods

```bash
# Ensure no pods are stuck
kubectl get pods -A | grep -v Running | grep -v Completed

# Should be empty or show only completed jobs
```

## 6. Resource Availability

### Check Node Resources

```bash
# View resource usage
kubectl top nodes

# Example output:
# NAME    CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
# node2   150m         3%     1200Mi          15%
# node3   140m         3%     1150Mi          14%
# node4   160m         4%     1250Mi          16%

# Check allocatable resources
kubectl describe nodes | grep -A 5 "Allocatable:"
```

### Verify Sufficient Capacity for Workloads

```bash
# Calculate available resources
for node in node2 node3 node4; do
    echo "=== $node ==="
    kubectl describe node $node | grep -A 10 "Allocated resources:"
done
```

## 7. Create HA Verification Report

```bash
cat <<'EOF' > /root/ha-verification-report.sh
#!/bin/bash
echo "================================================================"
echo "           RKE2 Cluster HA Verification Report"
echo "           Generated: $(date)"
echo "================================================================"
echo ""

echo "=== Nodes ==="
kubectl get nodes -o wide
echo ""

echo "=== etcd Members ==="
etcdctl member list --write-out=table
echo ""

echo "=== etcd Health ==="
etcdctl endpoint health --cluster
echo ""

echo "=== etcd Status ==="
etcdctl endpoint status --cluster --write-out=table
echo ""

echo "=== API Server Endpoints ==="
kubectl get endpoints -n default kubernetes
echo ""

echo "=== Controller Manager Leader ==="
kubectl get leases -n kube-system kube-controller-manager -o jsonpath='{.spec.holderIdentity}'
echo ""

echo "=== Scheduler Leader ==="
kubectl get leases -n kube-system kube-scheduler -o jsonpath='{.spec.holderIdentity}'
echo ""

echo "=== System Pods ==="
kubectl get pods -n kube-system -o wide
echo ""

echo "=== Node Resources ==="
kubectl top nodes
echo ""

echo "=== Cilium Status ==="
cilium status --brief
echo ""

echo "================================================================"
echo "                    Verification Complete"
echo "================================================================"
EOF

chmod +x /root/ha-verification-report.sh
/root/ha-verification-report.sh | tee /root/ha-verification-$(date +%Y%m%d).txt
```

## HA Verification Checklist

Complete this checklist before proceeding:

### etcd

- [ ] 3 members in the cluster
- [ ] All endpoints healthy
- [ ] Leader election working
- [ ] Can survive single node failure

### Control Plane

- [ ] API server accessible on all nodes
- [ ] Controller manager leader election working
- [ ] Scheduler leader election working

### Networking

- [ ] All nodes can reach each other
- [ ] Cilium running on all nodes
- [ ] DNS resolution working

### Resources

- [ ] All nodes Ready
- [ ] Sufficient capacity for workloads
- [ ] No pods in error state

## Summary

Cluster B now provides:

| Feature                | Status               |
| ---------------------- | -------------------- |
| Control Plane Nodes    | 3 (HA)               |
| etcd Members           | 3 (quorum tolerant)  |
| Node Failure Tolerance | 1                    |
| API Availability       | Multi-endpoint       |
| Networking             | Cilium (distributed) |

## Ready for Workload Migration

The cluster is verified and ready for:

1. Storage setup (Longhorn + local-path)
2. Ingress configuration (Traefik + Hetzner LB)
3. Workload migration from Cluster A

In the next section, we'll set up the infrastructure needed for workloads and migrate applications from the k3s
cluster.
