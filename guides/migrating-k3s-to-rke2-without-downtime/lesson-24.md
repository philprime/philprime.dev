---
layout: guide-lesson.liquid
title: Adding Node 1 as RKE2 Worker

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 5
guide_lesson_id: 24
guide_lesson_abstract: >
  Install Rocky Linux 10 on Node 1 and configure it as an RKE2 worker node to complete the cluster.
guide_lesson_conclusion: >
  Node 1 has joined Cluster B as a worker node, completing the 4-node cluster configuration.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-24.md
---

With k3s decommissioned, we'll install Rocky Linux 10 on Node 1 and add it to Cluster B as a worker node.

{% include guide-overview-link.liquid.html %}

## Understanding Worker Nodes

Worker nodes (agents) differ from control plane nodes:

| Aspect     | Control Plane | Worker |
| ---------- | ------------- | ------ |
| RKE2 type  | server        | agent  |
| etcd       | Yes           | No     |
| API server | Yes           | No     |
| Scheduler  | Yes           | No     |
| Workloads  | Optional      | Yes    |

Workers run application workloads without the overhead of control plane components.

## Current State

```mermaid!
flowchart LR
  subgraph before["Before"]
    direction TB
    B1["Node 1<br/><small>empty</small>"]
    B2["🧠 Node 2"]
    B3["🧠 Node 3"]
    B4["🧠 Node 4"]
  end

  subgraph after["After"]
    direction TB
    A1["⚙️ Node 1 ✓"]
    A2["🧠 Node 2"]
    A3["🧠 Node 3"]
    A4["🧠 Node 4"]
  end

  before -->|"add worker"| after

  classDef empty fill:#9ca3af,color:#fff,stroke:#6b7280
  classDef cp fill:#2563eb,color:#fff,stroke:#1e40af
  classDef worker fill:#16a34a,color:#fff,stroke:#166534

  class B1 empty
  class B2,B3,B4,A2,A3,A4 cp
  class A1 worker
```

## Prepare Node 1

Follow the same setup process as previous nodes:

1. Install Rocky Linux 10 ([Lesson 5](/guides/migrating-k3s-to-rke2-without-downtime/lesson-5))
2. Configure dual-stack vSwitch networking with `10.1.1.1` and `fd00:1::1` ([Lesson 6](/guides/migrating-k3s-to-rke2-without-downtime/lesson-6))
3. Configure firewall ([Lesson 7](/guides/migrating-k3s-to-rke2-without-downtime/lesson-7))

{% include alert.liquid.html type='info' title='Worker Firewall' content='
Worker nodes need fewer ports than control planes.
You can skip etcd ports (2379, 2380) and API server port (6443).
' %}

Set hostname and verify connectivity:

```bash
hostnamectl set-hostname node1

ping -c 3 10.1.1.4
nc -zv 10.1.1.4 9345
```

## Install RKE2 Agent

Unlike control plane nodes, workers install the agent component:

```bash
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -
systemctl enable rke2-agent.service
```

## Configure RKE2 Agent

Get the cluster token from an existing control plane node, then configure the agent:

```bash
mkdir -p /etc/rancher/rke2

TOKEN="<your-cluster-token>"

cat <<EOF > /etc/rancher/rke2/config.yaml
server: https://10.1.1.4:9345
token: ${TOKEN}
node-ip: 10.1.1.1,fd00:1::1
EOF
```

## Start RKE2 Agent

```bash
systemctl start rke2-agent.service
journalctl -u rke2-agent -f
```

Wait for the node to join.
You should see messages indicating successful connection to the control plane.

## Verification

### Check Node Status

```bash
kubectl get nodes -o wide
```

Expected output:

```
NAME    STATUS   ROLES                       AGE   VERSION          INTERNAL-IP
node1   Ready    <none>                      1m    v1.31.x+rke2r1   10.1.1.1,fd00:1::1
node2   Ready    control-plane,etcd,master   2d    v1.31.x+rke2r1   10.1.1.2,fd00:1::2
node3   Ready    control-plane,etcd,master   2d    v1.31.x+rke2r1   10.1.1.3,fd00:1::3
node4   Ready    control-plane,etcd,master   3d    v1.31.x+rke2r1   10.1.1.4,fd00:1::4
```

### Label Worker Node (Optional)

```bash
kubectl label node node1 node-role.kubernetes.io/worker=true
```

### Verify Cilium and Traefik

Both should automatically deploy to the new node:

```bash
kubectl get pods -n kube-system -l k8s-app=cilium -o wide
kubectl get pods -n traefik -o wide
```

Should show 4 pods each, one per node.

## Add to Load Balancer

Add Node 1 as a target in the Hetzner Load Balancer:

```bash
hcloud load-balancer add-target k8s-ingress --server node1 --use-private-ip
```

## Final Cluster State

| Node  | Role          | IP       |
| ----- | ------------- | -------- |
| node1 | Worker        | 10.1.1.1 |
| node2 | Control Plane | 10.1.1.2 |
| node3 | Control Plane | 10.1.1.3 |
| node4 | Control Plane | 10.1.1.4 |

The cluster now has:

- 3 control plane nodes for HA
- 1 worker node for dedicated workload capacity
- 4 nodes in load balancer for HA ingress

In the final lesson, we'll cover post-migration cleanup and documentation.
