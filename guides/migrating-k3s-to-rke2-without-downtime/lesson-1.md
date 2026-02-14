---
layout: guide-lesson.liquid
title: Migration Strategy and Planning

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 1
guide_lesson_id: 1
guide_lesson_abstract: >
  Understand the migration challenge, develop a phased migration strategy, and learn the risk considerations for each phase.
guide_lesson_conclusion: >
  You now have a detailed migration strategy with clear phases and understand the risk levels for each step.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-1.md
---

A successful zero-downtime migration requires meticulous planning.
This lesson establishes the context for our migration, develops a phased strategy, and maps the risks involved at each step.

{% include guide-overview-link.liquid.html %}

## The Migration Challenge

Migrating a production Kubernetes cluster is one of the most complex operations in infrastructure management.
Our migration must maintain zero downtime while keeping services available, change the underlying distribution from k3s to RKE2, and reconfigure the topology from a single control plane with two workers to three control planes with one worker—all at the same time.
We're also replacing the operating system with Rocky Linux 10 and upgrading to Cilium for networking and Longhorn for storage.

{% include alert.liquid.html type='tip' title='Why not 5 nodes?' content='
A 5-node setup would make this migration significantly easier.
You could build a full 3-node HA control plane by removing only a single node from the original cluster while keeping 2 nodes running workloads.
With only 4 nodes, we must navigate a critical phase where both clusters run with reduced redundancy.
' %}

## Current State vs Target State

The current k3s cluster has Node 1 as its sole control plane—a single point of failure that puts the entire cluster at risk if that node goes down.
Storage relies on local volumes per node with no replication, and Flannel provides basic CNI networking with external ingress routed directly to fixed node IPs.

The target RKE2 cluster addresses each of these limitations:

| Aspect        | Current (k3s)                         | Target (RKE2)                        |
| ------------- | ------------------------------------- | ------------------------------------ |
| Control Plane | Node 1 only (single point of failure) | Nodes 2, 3, 4 (HA with etcd quorum)  |
| Workers       | Nodes 2, 3                            | Node 1 (extensible to more)          |
| Storage       | Local storage per node                | Longhorn replicated + local-path     |
| CNI           | Flannel                               | Cilium with eBPF                     |
| Ingress       | Fixed node IPs                        | Traefik DaemonSet + Hetzner Cloud LB |

The migration happens in five phases, each moving one step closer to the target architecture while preserving service availability.

## Phase 1: Bootstrap Cluster B

```mermaid!
%%{init: {"theme": "base", "flowchart": {"nodeSpacing": 15, "rankSpacing": 25}, "themeVariables": {"fontSize": "12px"}}}%%
flowchart LR
classDef clusterA fill:#2563eb,color:#ffffff,stroke:#1e40af
classDef clusterB fill:#16a34a,color:#ffffff,stroke:#166534
classDef unassigned fill:#9ca3af,color:#ffffff,stroke:#6b7280

subgraph before["Before"]
  direction TB
  subgraph bA["k3s"]
    bA1["🧠 Node 1"]
    bA2["⚙️ Node 2"]
    bA3["⚙️ Node 3"]
  end
  bU["Node 4"]
end

subgraph after["After"]
  direction TB
  subgraph aB["RKE2"]
    aB4["🧠 Node 4"]
  end
  subgraph aA["k3s"]
    aA1["🧠 Node 1"]
    aA2["⚙️ Node 2"]
    aA3["⚙️ Node 3"]
  end
end

before --> after
class bA,aA clusterA
class aB clusterB
class bU unassigned
```

This phase creates a new RKE2 cluster on Node 4 while Cluster A remains fully operational with all three nodes.
We install Rocky Linux 10 on Node 4, configure the Hetzner vSwitch networking, install RKE2 as the first control plane, and deploy Cilium as the CNI plugin.
After verifying cluster functionality, Node 4 runs as a single-node RKE2 cluster while Nodes 1-3 continue serving workloads unchanged.

## Phase 2: First Node Migration

```mermaid!
%%{init: {"theme": "base", "flowchart": {"nodeSpacing": 15, "rankSpacing": 25}, "themeVariables": {"fontSize": "12px"}}}%%
flowchart LR
classDef clusterA fill:#2563eb,color:#ffffff,stroke:#1e40af
classDef clusterB fill:#16a34a,color:#ffffff,stroke:#166534
classDef critical stroke:#dc2626,stroke-width:3px

subgraph before["Before"]
  direction TB
  subgraph bB["RKE2"]
    bB4["🧠 Node 4"]
  end
  subgraph bA["k3s"]
    bA1["🧠 Node 1"]
    bA2["⚙️ Node 2"]
    bA3["⚙️ Node 3"]
  end
end

subgraph after["After"]
  direction TB
  subgraph aB["RKE2"]
    aB3["🧠 Node 3"]
    aB4["🧠 Node 4"]
  end
  subgraph aA["k3s"]
    aA1["🧠 Node 1"]
    aA2["⚙️ Node 2"]
  end
end

before --> after
class bA,aA clusterA
class bB,aB clusterB
class after critical
```

Node 3 leaves Cluster A and joins Cluster B as a second control plane, giving the new cluster its first step toward high availability.
Before beginning, ensure all workloads run on Nodes 1 and 2, DNS does not point to Node 3, and external traffic is routed elsewhere.

{% include alert.liquid.html type='warning' title='etcd Quorum with 2 Nodes' content='
etcd requires a strict majority for quorum.
Two nodes have the same fault tolerance as one node (zero), so this phase is not more dangerous than the initial single-node bootstrap.
Mitigate by minimizing time in this state and ensuring both nodes are stable before proceeding.
' %}

The process involves cordoning and draining Node 3, removing it from Cluster A, optionally reinstalling the OS with Rocky Linux 10, and joining it as an RKE2 control plane.
After verifying etcd cluster health, both clusters operate at minimum viable capacity—Cluster A with two nodes and Cluster B with two etcd members, neither of which tolerates losing a node.

## Phase 3: Second Node Migration

```mermaid!
%%{init: {"theme": "base", "flowchart": {"nodeSpacing": 15, "rankSpacing": 25}, "themeVariables": {"fontSize": "12px"}}}%%
flowchart LR
classDef clusterA fill:#2563eb,color:#ffffff,stroke:#1e40af
classDef clusterB fill:#16a34a,color:#ffffff,stroke:#166534
classDef success stroke:#16a34a,stroke-width:2px

subgraph before["Before"]
  direction TB
  subgraph bA["k3s"]
    bA1["🧠 Node 1"]
    bA2["⚙️ Node 2"]
  end
  subgraph bB["RKE2"]
    bB3["🧠 Node 3"]
    bB4["🧠 Node 4"]
  end
end

subgraph after["After · HA Achieved"]
  direction TB
  subgraph aA["k3s"]
    aA1["🧠 Node 1"]
  end
  subgraph aB["RKE2"]
    aB2["🧠 Node 2"]
    aB3["🧠 Node 3"]
    aB4["🧠 Node 4"]
  end
end

before --> after
class bA,aA clusterA
class bB,aB clusterB
class after success
```

Node 2 follows the same process: cordon, drain, remove from Cluster A, uninstall k3s, optionally reinstall the OS, and join Cluster B as the third control plane.
With three etcd members, Cluster B achieves full high availability—it can tolerate the loss of one control plane node while maintaining quorum.
Workload migration can now begin safely.

## Phase 4: Workload Migration

```mermaid!
%%{init: {"theme": "base", "flowchart": {"nodeSpacing": 15, "rankSpacing": 25}, "themeVariables": {"fontSize": "12px"}}}%%
flowchart LR
classDef clusterA fill:#2563eb,color:#ffffff,stroke:#1e40af
classDef clusterB fill:#16a34a,color:#ffffff,stroke:#166534
classDef success stroke:#16a34a,stroke-width:2px

subgraph before["Before"]
  direction TB
  subgraph bA["k3s · workloads here"]
    bA1["🧠 Node 1"]
  end
  subgraph bB["RKE2 · empty"]
    bB2["🧠 Node 2"]
    bB3["🧠 Node 3"]
    bB4["🧠 Node 4"]
  end
end

subgraph after["After"]
  direction TB
  subgraph aA["k3s · idle"]
    aA1["🧠 Node 1"]
  end
  subgraph aB["RKE2 · workloads here"]
    aB2["🧠 Node 2"]
    aB3["🧠 Node 3"]
    aB4["🧠 Node 4"]
  end
end

before --> after
class bA,aA clusterA
class bB,aB clusterB
class after success
```

With Cluster B running three control planes and both clusters fully operational, the risk of this phase is low—DNS can be switched back to Cluster A if issues arise.
We set up storage on Cluster B with Longhorn and local-path provisioner, configure ingress through Traefik and the Hetzner Cloud Load Balancer, and export workload manifests from Cluster A.
After migrating any persistent data and deploying workloads to Cluster B, we switch DNS to point at the new cluster's ingress.
All workloads now run on Cluster B while Cluster A sits idle with only Node 1.

## Phase 5: Cleanup and Consolidation

```mermaid!
%%{init: {"theme": "base", "flowchart": {"nodeSpacing": 15, "rankSpacing": 25}, "themeVariables": {"fontSize": "12px"}}}%%
flowchart LR
classDef clusterB fill:#16a34a,color:#ffffff,stroke:#166534
classDef success stroke:#16a34a,stroke-width:2px

subgraph before["Before"]
  direction TB
  bA1["Node 1 · k3s idle"]
  subgraph bB["RKE2"]
    bB2["🧠 Node 2"]
    bB3["🧠 Node 3"]
    bB4["🧠 Node 4"]
  end
end

subgraph after["After · Complete"]
  direction TB
  subgraph aB["RKE2"]
    aB1["⚙️ Node 1"]
    aB2["🧠 Node 2"]
    aB3["🧠 Node 3"]
    aB4["🧠 Node 4"]
  end
end

before --> after
class bB,aB clusterB
class after success
```

The final phase decommissions Cluster A and brings Node 1 into the RKE2 cluster as a worker node.
After a 24-48 hour soak period to verify Cluster B stability, we drain Node 1, uninstall k3s, optionally reinstall with Rocky Linux 10, and join it as an RKE2 agent.
The result is a complete 4-node RKE2 cluster with three control planes and one dedicated worker.

## Risk Considerations

The highest-risk phase is Phase 2, when both clusters run at minimum viable capacity.
Cluster A loses one of its three nodes, and Cluster B has only two etcd members—which has zero fault tolerance, the same as a single-node cluster.
Minimize time in this state by ensuring both nodes are stable and proceeding to Phase 3 as quickly as practical.

Never proceed to workload migration until Cluster B achieves full HA with three control plane nodes.
Before starting the migration, review all lessons thoroughly, practice the node installation process on a test system if possible, and ensure you have complete backups of all persistent data.
