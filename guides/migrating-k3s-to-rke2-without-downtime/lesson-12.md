---
layout: guide-lesson.liquid
title: Migrating Node 2 to Cluster B

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 3
guide_lesson_id: 12
guide_lesson_abstract: >
  Migrate Node 2 from Cluster A to Cluster B, achieving high availability with 3 control plane nodes and etcd quorum.
guide_lesson_conclusion: >
  Node 2 has joined Cluster B as the third control plane node, achieving full high availability with etcd quorum tolerance.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-12.md
---

The process for migrating Node 2 is identical to Node 3 — backup, drain, reinstall, join.
This lesson focuses on what's different: the impact on Cluster A capacity, and the significance of reaching 3 control plane nodes for etcd quorum.
Refer to [Lesson 11](/guides/migrating-k3s-to-rke2-without-downtime/lesson-11) for detailed explanations of each step.

{% include guide-overview-link.liquid.html %}

## Current State

```mermaid!
flowchart LR
  subgraph A["Cluster A · k3s"]
    A1["🧠 Node 1"]
    A2["⚙️ Node 2"]
  end

  subgraph B["Cluster B · RKE2"]
    B3["🧠 Node 3"]
    B4["🧠 Node 4"]
  end

  A2 -.->|"migrating"| B

  classDef clusterA fill:#2563eb,color:#fff,stroke:#1e40af
  classDef clusterB fill:#16a34a,color:#fff,stroke:#166534

  class A clusterA
  class B clusterB
```

This migration reduces Cluster A to a single node temporarily, but completes Cluster B's HA setup.

## Understanding etcd Quorum

etcd uses the Raft consensus algorithm, which requires a majority of nodes to agree on any change.
This majority is called quorum.

| Nodes | Quorum Needed | Can Lose | HA Status |
| ----- | ------------- | -------- | --------- |
| 1     | 1             | 0        | None      |
| 2     | 2             | 0        | None      |
| 3     | 2             | 1        | HA        |
| 5     | 3             | 2        | Better HA |

With 2 nodes, losing either one breaks quorum.
With 3 nodes, the cluster continues operating if one node fails.
This is why achieving 3 control planes is a critical milestone.

## Draining Node 2 from Cluster A

### Backup

Create an etcd snapshot before making changes:

```bash
# On Node 1
$ ssh root@node1
$ sudo k3s etcd-snapshot save --name pre-node2-migration-$(date +%Y%m%d-%H%M%S)
```

### Drain and Remove

```bash
$ export KUBECONFIG=/path/to/cluster-a-kubeconfig

$ kubectl cordon node2
$ kubectl drain node2 \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=300 \
  --timeout=600s

$ kubectl delete node node2

$ ssh root@node2 "sudo systemctl stop k3s-agent && sudo systemctl disable k3s-agent"
```

{% include alert.liquid.html type='warning' title='Single Point of Failure' content='
Cluster A is now running on Node 1 only.
Any issue with Node 1 will cause complete cluster failure.
Proceed with Node 2 installation promptly.
' %}

## Installing RKE2 on Node 2

### Prepare the OS

1. Install Rocky Linux 10 ([Lesson 5](/guides/migrating-k3s-to-rke2-without-downtime/lesson-5))
2. Configure dual-stack networking with `10.1.0.12` and `fd00::12` ([Lesson 6](/guides/migrating-k3s-to-rke2-without-downtime/lesson-6))
3. Configure firewall ([Lesson 7](/guides/migrating-k3s-to-rke2-without-downtime/lesson-7))

### Install and Configure RKE2

```bash
$ sudo hostnamectl set-hostname node2

$ curl -sfL https://get.rke2.io | sudo sh -
$ sudo systemctl enable rke2-server.service
```

Create the configuration using the same multi-file layout as Node 3 ([Lesson 11](/guides/migrating-k3s-to-rke2-without-downtime/lesson-11)), replacing the node-specific addresses:

```bash
$ sudo mkdir -p /etc/rancher/rke2/config.yaml.d
```

```yaml
# /etc/rancher/rke2/config.yaml.d/00-join.yaml

server: https://10.1.0.14:9345
token: <paste-token-from-node4>
```

```yaml
# /etc/rancher/rke2/config.yaml.d/10-network.yaml

cni: canal

node-ip: 10.1.0.12,fd00::12
node-external-ip:
  - 65.109.XX.XX
  - 2a01:4f9:XX:XX::2
advertise-address: 10.1.0.12
bind-address: 10.1.0.12

cluster-cidr: 10.42.0.0/16,fd00:42::/56
service-cidr: 10.43.0.0/16,fd00:43::/112
cluster-dns: 10.43.0.10
```

```yaml
# /etc/rancher/rke2/config.yaml.d/20-external-access.yaml

tls-san:
  - node2
  - node2.k8s.local
  - 10.1.0.12
  - fd00::12
  - cluster.yourdomain.com

write-kubeconfig-mode: "0644"
```

```yaml
# /etc/rancher/rke2/config.yaml.d/30-security.yaml

secrets-encryption: true

disable:
  - rke2-ingress-nginx

etcd-snapshot-schedule-cron: "0 */6 * * *"
etcd-snapshot-retention: 5
```

### Start RKE2

```bash
$ sudo systemctl start rke2-server.service
$ sudo journalctl -u rke2-server -f
```

When Node 2 starts, several things happen in sequence.
The node contacts Node 4's supervisor API on port `9345` and retrieves cluster certificates.
It then joins the etcd cluster as the third member — bringing the cluster to quorum tolerance for the first time.
Canal deploys automatically and establishes WireGuard tunnels to both Node 3 and Node 4.

Unlike the Node 3 join, there should be no WireGuard/VXLAN mismatch here because all existing nodes are already running the WireGuard backend.
If you do see "no route to host" errors, restart the Canal DaemonSet as described in [Lesson 11's troubleshooting section](/guides/migrating-k3s-to-rke2-without-downtime/lesson-11#wireguard--vxlan-backend-mismatch).

## Verification

### Configure kubectl

```bash
$ mkdir -p ~/.kube
$ sudo cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
$ sudo chown $(id -u):$(id -g) ~/.kube/config
$ echo 'export PATH=$PATH:/var/lib/rancher/rke2/bin' >> ~/.bashrc
$ export PATH=$PATH:/var/lib/rancher/rke2/bin
```

### Check 3-Node Control Plane

```bash
$ kubectl get nodes -o wide
```

Expected output:

```
NAME    STATUS   ROLES                       AGE   VERSION          INTERNAL-IP
node2   Ready    control-plane,etcd,master   2m    v1.31.x+rke2r1   10.1.0.12,fd00::12
node3   Ready    control-plane,etcd,master   2h    v1.31.x+rke2r1   10.1.0.13,fd00::13
node4   Ready    control-plane,etcd,master   4h    v1.31.x+rke2r1   10.1.0.14,fd00::14
```

### Verify etcd HA

```bash
$ sudo /var/lib/rancher/rke2/bin/etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/rancher/rke2/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/rke2/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/rke2/server/tls/etcd/server-client.key \
  member list
```

Should show 3 members:

```
xxxx, started, node2-xxxx, https://10.1.0.12:2380, https://10.1.0.12:2379, false
yyyy, started, node3-xxxx, https://10.1.0.13:2380, https://10.1.0.13:2379, false
zzzz, started, node4-xxxx, https://10.1.0.14:2380, https://10.1.0.14:2379, true
```

Check cluster health:

```bash
$ sudo /var/lib/rancher/rke2/bin/etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/rancher/rke2/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/rke2/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/rke2/server/tls/etcd/server-client.key \
  endpoint health --cluster
```

All 3 endpoints should be healthy, with one showing as leader.

### Verify Canal and WireGuard

```bash
$ kubectl get pods -n kube-system -l k8s-app=canal -o wide
```

Should show 3 Canal pods, one per node, all `2/2` Ready.

Verify the WireGuard mesh is complete:

```bash
$ wg show flannel-wg
```

Node 2 should show two peers (Node 3 and Node 4), each with a recent handshake and an `allowed ips` entry for their pod subnet.
With 3 nodes, the WireGuard mesh forms a full triangle — each node maintains a direct encrypted tunnel to every other node.

## Current State

```mermaid!
flowchart LR
  subgraph A["Cluster A · k3s"]
    A1["🧠 Node 1<br/><small>all workloads</small>"]
  end

  subgraph B["Cluster B · RKE2 ✓ HA"]
    B2["🧠 Node 2"]
    B3["🧠 Node 3"]
    B4["🧠 Node 4"]
  end

  classDef clusterA fill:#2563eb,color:#fff,stroke:#1e40af
  classDef clusterB fill:#16a34a,color:#fff,stroke:#166534

  class A clusterA
  class B clusterB
```

Cluster B now has 3 control plane nodes with full HA.
The cluster can tolerate one node failure while maintaining quorum.

With the control plane complete, we can proceed to verify the cluster's HA capabilities in detail.
