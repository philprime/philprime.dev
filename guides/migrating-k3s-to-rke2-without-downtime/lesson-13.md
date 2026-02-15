---
layout: guide-lesson.liquid
title: "Verifying the 3-Node Control Plane"

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 3
guide_lesson_id: 13
guide_lesson_abstract: >
  Comprehensively verify the 3-node RKE2 control plane, test HA capabilities, and confirm readiness for workload migration.
guide_lesson_conclusion: >
  The 3-node control plane is verified as highly available and ready to receive production workloads.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-13.md
---

With all three control plane nodes running, we need to verify the cluster's high availability before migrating production workloads.

{% include guide-overview-link.liquid.html %}

## What Makes a Cluster HA

A highly available Kubernetes cluster requires:

| Component          | Requirement                     | Our Setup   |
| ------------------ | ------------------------------- | ----------- |
| etcd               | 3+ members for quorum tolerance | 3 members   |
| API Server         | Multiple endpoints              | 3 endpoints |
| Controller Manager | Leader election across nodes    | Enabled     |
| Scheduler          | Leader election across nodes    | Enabled     |

If any single node fails, the remaining two maintain quorum and continue serving requests.

## Verifying etcd

### Member Status

```bash
$ sudo /var/lib/rancher/rke2/bin/etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/rancher/rke2/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/rke2/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/rke2/server/tls/etcd/server-client.key \
  member list --write-out=table
```

Should show 3 members, all started:

```
+------------------+---------+-------------+-----------------------+-----------------------+
|        ID        | STATUS  |    NAME     |      PEER ADDRS       |     CLIENT ADDRS      |
+------------------+---------+-------------+-----------------------+-----------------------+
| xxxxxxxxxxxx     | started | node2-xxxxx | https://10.1.1.2:2380 | https://10.1.1.2:2379 |
| yyyyyyyyyyyy     | started | node3-xxxxx | https://10.1.1.3:2380 | https://10.1.1.3:2379 |
| zzzzzzzzzzzz     | started | node4-xxxxx | https://10.1.1.4:2380 | https://10.1.1.4:2379 |
+------------------+---------+-------------+-----------------------+-----------------------+
```

### Endpoint Health

```bash
$ sudo /var/lib/rancher/rke2/bin/etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/rancher/rke2/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/rke2/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/rke2/server/tls/etcd/server-client.key \
  endpoint health --cluster
```

All three endpoints should report healthy:

```
https://10.1.1.2:2379 is healthy: successfully committed proposal: took = 5.1ms
https://10.1.1.3:2379 is healthy: successfully committed proposal: took = 4.8ms
https://10.1.1.4:2379 is healthy: successfully committed proposal: took = 5.2ms
```

### Leader Status

```bash
$ sudo /var/lib/rancher/rke2/bin/etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/rancher/rke2/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/rke2/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/rke2/server/tls/etcd/server-client.key \
  endpoint status --cluster --write-out=table
```

One node should show `IS LEADER = true`.
The other two show `false`, indicating they're followers ready to take over if needed.

## Verifying Control Plane Components

### API Server Endpoints

```bash
$ kubectl get endpoints -n default kubernetes
```

Should list all three control plane IPs:

```
NAME         ENDPOINTS                                      AGE
kubernetes   10.1.1.2:6443,10.1.1.3:6443,10.1.1.4:6443     4h
```

Clients can connect to any of these endpoints.
If one fails, they automatically failover to another.

### Controller Manager and Scheduler

These components use leader election — only one instance is active at a time:

```bash
$ kubectl get leases -n kube-system kube-controller-manager -o jsonpath='{.spec.holderIdentity}'
$ echo
$ kubectl get leases -n kube-system kube-scheduler -o jsonpath='{.spec.holderIdentity}'
$ echo
```

Each shows which node currently holds the lease.
If that node fails, another node acquires the lease within seconds.

## Testing Failover (Optional)

To verify the cluster survives a node failure, you can temporarily stop one node:

```bash
# Monitor from your workstation
$ watch kubectl get nodes

# Stop one node (not the etcd leader for faster recovery)
$ ssh root@node2 "sudo systemctl stop rke2-server"
```

Within 30-60 seconds:

- Node 2 becomes `NotReady`
- etcd elects a new leader if needed
- `kubectl` commands continue working via the other nodes

Restore the node:

```bash
$ ssh root@node2 "sudo systemctl start rke2-server"
```

{% include alert.liquid.html type='info' title='Test Carefully' content='
Only perform this test if you are comfortable with cluster recovery procedures.
The cluster should handle single-node failure gracefully.
' %}

## Verifying Networking and Pods

### Canal Status

```bash
$ kubectl get pods -n kube-system -l k8s-app=canal -o wide
```

Should show one Canal pod per node, all Running.

### System Pods

```bash
$ kubectl get pods -n kube-system -o wide
```

Verify pods are distributed across nodes:

- Canal agent on each node
- CoreDNS replicas on different nodes
- No pods in Pending or Error state

### Resource Availability

```bash
$ kubectl top nodes
```

Check that nodes have headroom for workloads:

```
NAME    CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
node2   150m         3%     1200Mi          15%
node3   140m         3%     1150Mi          14%
node4   160m         4%     1250Mi          16%
```

## Verification Checklist

### etcd

- [ ] 3 members listed and started
- [ ] All endpoints healthy
- [ ] One leader elected

### Control Plane

- [ ] API server accessible on all 3 nodes
- [ ] Controller manager lease held
- [ ] Scheduler lease held

### Networking

- [ ] Canal running on all nodes
- [ ] All Canal pods show Running

### Resources

- [ ] All nodes Ready
- [ ] No pods in error state
- [ ] Sufficient CPU/memory headroom

With verification complete, the cluster is ready for storage setup and workload migration.
