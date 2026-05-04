---
layout: guide-lesson.liquid
title: "Verifying High Availability"

guide_component: lesson
guide_id: migrating-k3s-to-rke2
guide_section_id: 3
guide_lesson_id: 13
guide_lesson_abstract: >
  A running control plane is not necessarily a highly available one.
  This lesson tests API server redundancy, leader election failover, and individual node failure scenarios to confirm that our 3-node RKE2 cluster can survive losing any single node.
guide_lesson_conclusion: >
  Every node in the cluster can go down individually without breaking the control plane, confirming true high availability.
repo_file_path: guides/migrating-k3s-to-rke2/lesson-13.md
---

[Lesson 12](/guides/migrating-k3s-to-rke2/lesson-12) brought the cluster to three control plane nodes and verified that etcd, Canal, and WireGuard are healthy across all of them.
That confirms the components are running, but running is not the same as highly available.
This lesson tests the cluster's ability to survive individual node failures, which is the actual definition of HA.

{% include guide-overview-link.liquid.html %}

## What High Availability Means in Practice

A Kubernetes control plane has four critical components, each with its own HA mechanism:

| Component          | HA Mechanism       | Failure Tolerance      |
| ------------------ | ------------------ | ---------------------- |
| etcd               | Raft consensus     | Majority must be alive |
| API Server         | Multiple endpoints | Any one can serve      |
| Controller Manager | Leader election    | Standby takes over     |
| Scheduler          | Leader election    | Standby takes over     |

etcd requires a strict majority, meaning with three members, two must be alive to maintain quorum.
The API server runs independently on each node, so clients can connect to any of the three.
The controller manager and scheduler use lease-based leader election and only one instance is active at a time, with the others on standby ready to acquire the lease if the leader disappears.

The verification in [Lesson 12](/guides/migrating-k3s-to-rke2/lesson-12) confirmed these components are present and started.
The tests in this lesson confirm they actually fail over correctly.

## Verifying API Server Redundancy

The Kubernetes API service in the `default` namespace lists all active API server endpoints:

```bash
$ kubectl get endpoints -n default kubernetes
NAME         ENDPOINTS                                          AGE
kubernetes   10.1.0.12:6443,10.1.0.13:6443,10.1.0.14:6443       4h
```

All three control plane IPs should appear.
When a client (such as `kubectl`, a kubelet, or an in-cluster pod) connects to the API, it can reach any of these endpoints.
If one becomes unavailable, clients automatically retry against the remaining ones.

## Checking Leader Election

The controller manager and scheduler each hold a lease in the `kube-system` namespace.
Only the lease holder actively reconciles resources. The others watch and wait:

```bash
$ kubectl get leases -n kube-system kube-controller-manager -o jsonpath='{.spec.holderIdentity}'
node2_8c7a5cf9-52db-4a78-ace6-5187f4f93828%

$ kubectl get leases -n kube-system kube-scheduler -o jsonpath='{.spec.holderIdentity}'
node_ddfe2115-9b91-4bf3-a293-522659cd0edc
```

Each command prints the name of the node currently holding the lease.
Note which node holds each lease before the failover tests. We will see these change when that node goes down.

## Testing Node Failure

The real test of high availability is stopping a node and confirming the cluster keeps working.
With three control plane nodes, the cluster should tolerate any single node going down while continuing to serve API requests, schedule pods, and maintain etcd consensus.

{% include alert.liquid.html type='warning' title='Workload Availability' content='
If application workloads are already deployed to the new cluster, ensure they are highly available through replication before testing node failures.
A single-replica Deployment will go down when its node stops.
' %}

### Preparation

Open a terminal on the workstation and start a continuous watch:

```bash
$ watch -n 2 kubectl get nodes
```

This shows node status updates in near real-time.
A node transitions from `Ready` to `NotReady` within 30-60 seconds of its control plane processes stopping.

### Stopping Node 3

Start with a non-leader node to see the simplest failure scenario.
If Node 3 does not hold the controller manager or scheduler lease, it is a good candidate:

```bash
$ ssh node3 "sudo systemctl stop rke2-server"
```

Within about a minute, the watch terminal shows Node 3 as `NotReady`.
We can verify that `kubectl` still works. The client connects through one of the two remaining API servers:

```bash
$ kubectl get nodes
NAME    STATUS     ROLES                       AGE
node2   Ready      control-plane,etcd,master   1d
node3   NotReady   control-plane,etcd,master   5d
node4   Ready      control-plane,etcd,master   5d
```

Check etcd health from one of the remaining nodes:

```bash
$ etcdctl endpoint health --cluster
https://10.1.0.12:2379 is healthy: successfully committed proposal: took = 3.1ms
https://10.1.0.14:2379 is healthy: successfully committed proposal: took = 4.2ms
https://10.1.0.13:2379 is unhealthy: context deadline exceeded
```

Two of three endpoints remain healthy, so etcd still has quorum.
The unhealthy endpoint confirms that Node 3's etcd member is down, which is expected.

Restore Node 3 before testing the next node:

```bash
$ ssh node3 "sudo systemctl start rke2-server"
```

Wait until Node 3 returns to `Ready` in the watch terminal before continuing.

### Stopping Node 4

Node 4 was the bootstrap node, the first control plane node in the cluster.
Stopping it confirms there is nothing special about the original node:

```bash
$ ssh node4 "sudo systemctl stop rke2-server"
```

Again, verify that `kubectl` commands still succeed and that etcd reports two healthy endpoints.
If Node 4 held the controller manager or scheduler lease, check that the lease has moved to another node:

```bash
$ kubectl get leases -n kube-system kube-controller-manager -o jsonpath='{.spec.holderIdentity}'
node3_8c7a5cf9-52db-4a78-ace6-5187f4f93828%
```

The holder should now be a different node than before.
Restore Node 4:

```bash
$ ssh node4 "sudo systemctl start rke2-server"
```

### Stopping Node 2

Repeat the same process for Node 2:

```bash
$ ssh node2 "sudo systemctl stop rke2-server"
```

Verify `kubectl` still works, check etcd health, and confirm lease failover if applicable.
Restore Node 2:

```bash
$ ssh node2 "sudo systemctl start rke2-server"
```

### After All Tests

Once all three nodes have been tested and restored, confirm the cluster is fully healthy:

```bash
$ kubectl get nodes
NAME    STATUS   ROLES                       AGE
node2   Ready    control-plane,etcd,master   1d
node3   Ready    control-plane,etcd,master   5d
node4   Ready    control-plane,etcd,master   5d
```

```bash
$ etcdctl endpoint health --cluster
https://10.1.0.12:2379 is healthy: successfully committed proposal: took = 3.0ms
https://10.1.0.13:2379 is healthy: successfully committed proposal: took = 4.1ms
https://10.1.0.14:2379 is healthy: successfully committed proposal: took = 3.8ms
```

All three nodes are `Ready` and all three etcd endpoints are healthy.
The cluster survived each node going down individually. It is genuinely highly available and ready to receive production workloads.
