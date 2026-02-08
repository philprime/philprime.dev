---
layout: guide-lesson.liquid
title: Verifying Cluster B Initial Setup

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 2
guide_lesson_id: 10
guide_lesson_abstract: >
  Perform comprehensive verification of the initial RKE2 cluster setup before proceeding with node migration.
guide_lesson_conclusion: >
  Cluster B is verified and ready for additional nodes. All core components are functioning correctly.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-10.md
---

Before we begin the critical phase of migrating nodes from Cluster A, we must thoroughly verify that Cluster B is
functioning correctly. This lesson provides a comprehensive verification checklist.

{% include guide-overview-link.liquid.html %}

## Verification Overview

We'll verify the following components:

1. Node health and status
2. Control plane components
3. etcd cluster
4. Networking (Cilium)
5. DNS resolution
6. Test workload deployment

## 1. Node Health Verification

### Check Node Status

```bash
# Node should be Ready
kubectl get nodes -o wide

# Expected output:
# NAME    STATUS   ROLES                       AGE   VERSION          INTERNAL-IP   ...
# node4   Ready    control-plane,etcd,master   20m   v1.28.x+rke2r1   10.1.1.4      ...

# Check node conditions
kubectl describe node node4 | grep -A 20 "Conditions:"

# All conditions should be healthy:
# - MemoryPressure: False
# - DiskPressure: False
# - PIDPressure: False
# - Ready: True
```

### Check Node Resources

```bash
# View resource usage
kubectl top node node4

# Check allocatable resources
kubectl describe node node4 | grep -A 10 "Allocatable:"
```

## 2. Control Plane Verification

### Check Control Plane Pods

```bash
# List all kube-system pods
kubectl get pods -n kube-system -o wide

# Verify critical pods are running:
kubectl get pods -n kube-system | grep -E "etcd|kube-apiserver|kube-controller|kube-scheduler"

# Expected output (embedded in RKE2, might show as static pods or managed differently):
# etcd-node4                                1/1     Running   0          20m
# kube-apiserver-node4                      1/1     Running   0          20m
# kube-controller-manager-node4             1/1     Running   0          20m
# kube-scheduler-node4                      1/1     Running   0          20m
```

### Check API Server Health

```bash
# API server health endpoint
curl -k https://127.0.0.1:6443/healthz
# Expected: ok

# Detailed health check
curl -k https://127.0.0.1:6443/healthz?verbose

# Check API server is responding
kubectl cluster-info
```

### Verify RKE2 Service

```bash
# Check RKE2 server service
systemctl status rke2-server

# Check for any errors in logs
journalctl -u rke2-server --since "10 minutes ago" | grep -i error
```

## 3. etcd Verification

### Check etcd Health

```bash
# Using our alias from earlier
etcdctl endpoint health

# Check member status
etcdctl endpoint status --write-out=table

# Expected output:
# +------------------------+------------------+---------+---------+-----------+...
# |        ENDPOINT        |        ID        | VERSION | DB SIZE | IS LEADER |...
# +------------------------+------------------+---------+---------+-----------+...
# | https://127.0.0.1:2379 | xxxxxxxxxxxx     | 3.5.x   | 5.8 MB  | true      |...
# +------------------------+------------------+---------+---------+-----------+
```

### Check etcd Snapshots

```bash
# List etcd snapshots
ls -la /var/lib/rancher/rke2/server/db/snapshots/

# Verify snapshot mechanism is working
/var/lib/rancher/rke2/bin/rke2 etcd-snapshot list
```

## 4. Networking Verification

### Check Cilium Status

```bash
# Using Cilium CLI
cilium status

# Expected output should show:
# - Cilium: OK
# - Operator: OK
# - Hubble: OK (if enabled)

# Check Cilium pods
kubectl get pods -n kube-system -l k8s-app=cilium
```

### Check Pod Networking

```bash
# Verify Cilium endpoints
kubectl get ciliumendpoints -A

# Check Cilium node status
kubectl get ciliumnodes
```

### Test DNS Resolution

```bash
# Deploy a test pod
kubectl run dns-test --image=busybox:1.36 --restart=Never -- sleep 3600

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod/dns-test --timeout=60s

# Test internal DNS resolution
kubectl exec dns-test -- nslookup kubernetes.default

# Expected output:
# Server:    10.43.0.10
# Address 1: 10.43.0.10 kube-dns.kube-system.svc.cluster.local
# Name:      kubernetes.default
# Address 1: 10.43.0.1 kubernetes.default.svc.cluster.local

# Test external DNS resolution
kubectl exec dns-test -- nslookup google.com

# Cleanup
kubectl delete pod dns-test
```

## 5. Test Workload Deployment

### Deploy a Test Application

```bash
# Create a test namespace
kubectl create namespace test-verification

# Deploy nginx
kubectl create deployment nginx-test --image=nginx:alpine -n test-verification

# Expose as a service
kubectl expose deployment nginx-test --port=80 -n test-verification

# Wait for pod to be ready
kubectl wait --for=condition=Available deployment/nginx-test -n test-verification --timeout=60s

# Check pod status
kubectl get pods -n test-verification -o wide
```

### Test Service Connectivity

```bash
# Get the service IP
SVC_IP=$(kubectl get svc nginx-test -n test-verification -o jsonpath='{.spec.clusterIP}')

# Test from a pod
kubectl run curl-test --image=curlimages/curl --restart=Never --rm -it -- curl -s http://${SVC_IP}

# Should return nginx welcome page HTML
```

### Test NodePort Service

```bash
# Expose as NodePort
kubectl expose deployment nginx-test --port=80 --type=NodePort --name=nginx-nodeport -n test-verification

# Get the NodePort
NODE_PORT=$(kubectl get svc nginx-nodeport -n test-verification -o jsonpath='{.spec.ports[0].nodePort}')

echo "NodePort: $NODE_PORT"

# Test from the node itself
curl -s http://10.1.1.4:${NODE_PORT} | head -5
```

### Cleanup Test Resources

```bash
# Delete test namespace (removes all test resources)
kubectl delete namespace test-verification
```

## 6. Storage Verification

### Check Default StorageClass

```bash
# List storage classes
kubectl get storageclass

# At this point, we haven't installed storage yet
# This is expected - we'll add Longhorn and local-path later
```

## 7. Security Verification

### Check Pod Security Standards

```bash
# RKE2 enforces Pod Security Standards by default
# Check namespace labels
kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels}{"\n"}{end}'
```

### Check RBAC

```bash
# Verify RBAC is enabled
kubectl auth can-i create pods --as=system:anonymous
# Expected: no

# Check cluster roles
kubectl get clusterroles | head -20
```

## 8. System Component Summary

Run a comprehensive check:

```bash
# Create a verification script
cat <<'EOF' > /root/verify-cluster.sh
#!/bin/bash
echo "=== Cluster B Verification ==="
echo ""
echo "--- Node Status ---"
kubectl get nodes -o wide
echo ""
echo "--- System Pods ---"
kubectl get pods -n kube-system --no-headers | wc -l
echo "Total system pods: $(kubectl get pods -n kube-system --no-headers | wc -l)"
echo "Running: $(kubectl get pods -n kube-system --no-headers | grep Running | wc -l)"
echo ""
echo "--- Cilium Status ---"
cilium status --brief 2>/dev/null || echo "Cilium CLI not installed"
echo ""
echo "--- etcd Health ---"
etcdctl endpoint health 2>/dev/null || echo "etcdctl alias not set"
echo ""
echo "--- API Server ---"
curl -sk https://127.0.0.1:6443/healthz
echo ""
echo "--- Cluster Info ---"
kubectl cluster-info
echo ""
echo "=== Verification Complete ==="
EOF

chmod +x /root/verify-cluster.sh
/root/verify-cluster.sh
```

## Verification Checklist

Complete this checklist before proceeding:

### Node

- [ ] Node is in Ready status
- [ ] All node conditions are healthy
- [ ] Resource allocation is correct

### Control Plane

- [ ] RKE2 server service is running
- [ ] No errors in service logs
- [ ] API server responds to health checks

### etcd

- [ ] etcd endpoint is healthy
- [ ] Snapshots are being created
- [ ] Single member (expected at this stage)

### Networking

- [ ] Cilium pods are running
- [ ] DNS resolution works (internal and external)
- [ ] Pod-to-service connectivity works
- [ ] NodePort services are accessible

### Workloads

- [ ] Can create deployments
- [ ] Pods start correctly
- [ ] Services route traffic properly

## Record Cluster State

Document the current cluster state:

```bash
# Save cluster state
mkdir -p /root/cluster-state
kubectl get nodes -o yaml > /root/cluster-state/nodes.yaml
kubectl get pods -A -o yaml > /root/cluster-state/pods.yaml
kubectl cluster-info dump > /root/cluster-state/cluster-dump.txt 2>&1

# Save to backup
cp -r /root/cluster-state /root/rke2-backup/
```

## Ready for Node Migration

With all verifications passing, Cluster B is ready for the next phase. In Section 3, we'll begin migrating nodes
from Cluster A, starting with the critical 2-node transition.

### Current State Summary

```
Cluster A (k3s):          Cluster B (RKE2):
┌─────────────────┐       ┌─────────────────┐
│ Node 1 (CP)     │       │ Node 4 (CP) ✓   │
│ Node 2 (Worker) │       │                 │
│ Node 3 (Worker) │       │                 │
└─────────────────┘       └─────────────────┘
     Active                   Verified
```

Next steps:

1. Prepare Node 3 for migration
2. Drain and remove from Cluster A
3. Install Rocky Linux and join Cluster B

This begins the critical 2-node transition phase covered in the next section.
