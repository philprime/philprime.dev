---
layout: guide-lesson.liquid
title: Adding Node 1 as a Worker

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 4
guide_lesson_id: 15
guide_lesson_abstract: >
  With Cluster A decommissioned, Node 1 is a blank server ready for a fresh OS install.
  This lesson walks through installing Rocky Linux, joining Node 1 to Cluster B as a dedicated worker (agent) node, and preparing it for Longhorn storage.
guide_lesson_conclusion: >
  Node 1 has joined Cluster B as a worker node, giving the cluster dedicated workload capacity alongside three control plane nodes.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-15.md
---

Node 1 follows the same OS preparation as the previous node migrations — install Rocky Linux, configure networking, and set up the firewall.
The key difference is that Node 1 joins as a worker (agent) rather than a control plane node (server), so it does not run etcd, the API server, or the scheduler.
We covered the full OS setup process in Lesson 11.

{% include guide-overview-link.liquid.html %}

## Current State

```mermaid!
flowchart LR
  subgraph B["Cluster B · RKE2"]
    B1["Node 1<br/><small>empty</small>"]
    B2["🧠 Node 2"]
    B3["🧠 Node 3"]
    B4["🧠 Node 4"]
  end

  classDef empty fill:#9ca3af,color:#fff,stroke:#6b7280
  classDef cp fill:#2563eb,color:#fff,stroke:#1e40af

  class B1 empty
  class B2,B3,B4 cp
```

Cluster A was decommissioned in the previous lesson.
Node 1 is a blank server ready for a fresh OS install.

## Server vs Agent

The previous nodes all joined as `rke2-server` — running the full control plane stack alongside workloads.
Node 1 joins as `rke2-agent`, which is a lighter process that only runs the components needed to schedule and execute pods.

| Component          | Server (Nodes 2-4) | Agent (Node 1) |
| ------------------ | ------------------ | -------------- |
| kubelet            | Yes                | Yes            |
| Container runtime  | Yes                | Yes            |
| Canal (CNI)        | Yes                | Yes            |
| etcd               | Yes                | No             |
| API server         | Yes                | No             |
| Controller manager | Yes                | No             |
| Scheduler          | Yes                | No             |

A worker node only needs the cluster token and the address of a control plane node to join.
The configuration is simpler — no `tls-san`, no security settings, no authentication config.

## Preparing the OS

The OS preparation follows the same process we used for the other nodes in Lesson 11 — install Rocky Linux 10, configure dual-stack networking with `10.1.0.11` and `fd00::11`, and set up the Hetzner firewall.

Worker nodes need fewer firewall ports than control plane nodes.
The etcd ports (`2379`, `2380`) and API server port (`6443`) are not required since the agent does not run those services.

## Installing RKE2 Agent

We set the hostname and install the agent variant of RKE2:

```bash
$ sudo hostnamectl set-hostname node1

$ curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sudo sh -
$ sudo systemctl enable rke2-agent.service
```

The `INSTALL_RKE2_TYPE="agent"` environment variable tells the installer to set up the agent service instead of the server.

We create the configuration directory next:

```bash
$ sudo mkdir -p /etc/rancher/rke2
```

The agent needs only two things — where to connect and how to authenticate:

```yaml
# /etc/rancher/rke2/config.yaml
server: https://10.1.0.14:9345
token: <paste-token-from-node4>
node-ip: 10.1.0.11,fd00::11

kubelet-arg:
  - "resolv-conf=/etc/rancher/rke2/resolv.conf"
```

Create the clean resolv.conf to isolate pod DNS from Tailscale on the host, as in [Lesson 6](/guides/migrating-k3s-to-rke2-without-downtime/lesson-6#isolating-host-dns-from-pod-dns):

```bash
$ cat <<'EOF' | sudo tee /etc/rancher/rke2/resolv.conf
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
```

We retrieve the token from any control plane node at `/var/lib/rancher/rke2/server/node-token`.
The `server` address points to Node 4's supervisor API — the same endpoint used when joining Nodes 2 and 3.

## Starting the Agent

```bash
$ sudo systemctl start rke2-agent.service
$ sudo journalctl -u rke2-agent -f
```

The agent contacts Node 4's supervisor API, retrieves certificates, and registers itself with the cluster.
Canal deploys automatically and establishes WireGuard tunnels to all three control plane nodes.

## Verification

### Node Status

All four nodes should appear, with Node 1 showing no control plane roles:

```bash
$ kubectl get nodes -o wide
NAME    STATUS   ROLES                       AGE
node1   Ready    <none>                      2m
node2   Ready    control-plane,etcd,master   3d
node3   Ready    control-plane,etcd,master   7d
node4   Ready    control-plane,etcd,master   8d
```

The `<none>` role for Node 1 indicates it is a pure worker.
We can add a label for clarity:

```bash
$ kubectl label node node1 node-role.kubernetes.io/worker=true
```

### Canal and WireGuard

We verify that Canal has deployed a pod on Node 1:

```bash
$ kubectl get pods -n kube-system -l k8s-app=canal -o wide
```

Four Canal pods should appear — one per node, all `Running`.

On Node 1, we check the WireGuard interface to confirm tunnels to all three control plane nodes:

```bash
$ sudo wg show flannel-wg
```

The output should list three peers — one for each control plane node — each with a recent handshake timestamp.

## Preparing Longhorn Storage

Longhorn needs system-level dependencies on every node before it can schedule replicas.
The process is identical to the other nodes — we covered what each dependency does in Lesson 7.

We install `longhornctl` and run the preflight installer:

```bash
$ curl -fL -o /usr/local/bin/longhornctl \
    https://github.com/longhorn/cli/releases/download/v1.11.0/longhornctl-linux-amd64
$ chmod +x /usr/local/bin/longhornctl

$ /usr/local/bin/longhornctl --kubeconfig /etc/rancher/rke2/rke2.yaml install preflight
```

We run the preflight check to confirm all dependencies are in place:

```bash
$ /usr/local/bin/longhornctl --kubeconfig /etc/rancher/rke2/rke2.yaml check preflight
```

The check should report no errors for Node 1.
We verify that Longhorn recognizes all four nodes as schedulable:

```bash
$ kubectl get nodes.longhorn.io -n longhorn-system
NAME    READY   ALLOWSCHEDULING   SCHEDULABLE   AGE
node1   True    true              True          2m
node2   True    true              True          3d
node3   True    true              True          7d
node4   True    true              True          8d
```

With four storage nodes, Longhorn has more capacity for distributing replicas across the cluster.

## Final State

```mermaid!
flowchart LR
  subgraph B["Cluster B · RKE2 ✓"]
    B1["⚙️ Node 1"]
    B2["🧠 Node 2"]
    B3["🧠 Node 3"]
    B4["🧠 Node 4"]
  end

  classDef cp fill:#2563eb,color:#fff,stroke:#1e40af
  classDef worker fill:#16a34a,color:#fff,stroke:#166534

  class B2,B3,B4 cp
  class B1 worker
```

Cluster B now has three control plane nodes for high availability and one dedicated worker node for additional workload capacity.
All four nodes participate in Longhorn storage and the WireGuard mesh.
