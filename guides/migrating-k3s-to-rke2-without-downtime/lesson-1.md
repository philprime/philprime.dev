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
In this lesson, we'll establish the context for our migration, develop the complete strategy, and understand the risks involved.

{% include guide-overview-link.liquid.html %}

## The Migration Challenge

Migrating a production Kubernetes cluster is one of the most complex operations in infrastructure management.
Our migration must accomplish several goals simultaneously:

- Maintain zero downtime with services available throughout
- Change the underlying distribution from k3s to RKE2
- Reconfigure topology from 1 control plane + 2 workers to 3 control planes + 1 worker
- Replace the operating system with Rocky Linux 10
- Upgrade networking and storage with Cilium and Longhorn

{% include alert.liquid.html type='tip' title='Why not 5 nodes?' content='
A 5-node setup would make this migration significantly easier.
You could build a full 3-node HA control plane by removing only a single node from the original cluster while keeping 2 nodes running workloads.
With only 4 nodes, we must navigate a critical phase where both clusters run with reduced redundancy.
' %}

## Current State vs Target State

**Current state** - 3-node k3s cluster with critical limitations:

- Node 1 is a single point of failure as the only control plane
- No replicated storage, relying on local storage per node
- Flannel CNI with external ingress routed directly to fixed node IPs

**Target state** - 4-node RKE2 cluster providing:

- 3 control plane nodes for high availability
- Extensibility to add more worker nodes
- Longhorn for replicated volumes and local-path for performance workloads
- Cilium for advanced networking and observability
- HA ingress with Traefik DaemonSet and Hetzner Cloud Load Balancer

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

Create a new RKE2 cluster on Node 4 while Cluster A remains fully operational.

**Steps:**

- Install Rocky Linux 10 on Node 4
- Configure Hetzner vSwitch networking
- Install RKE2 as first control plane
- Deploy Cilium CNI
- Verify cluster functionality

**Result:** Single-node RKE2 cluster on Node 4, Cluster A unchanged with Nodes 1-3.

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

Remove Node 3 from Cluster A and add it as a control plane to Cluster B.

{% include alert.liquid.html type='warning' title='etcd Quorum with 2 Nodes' content='
etcd requires a strict majority for quorum.
Two nodes have the same fault tolerance as one node (zero), so this phase is not more dangerous than the initial single-node bootstrap.
Mitigate by minimizing time in this state and ensuring both nodes are stable before proceeding.
' %}

**Steps:**

- Cordon and drain Node 3 from Cluster A
- Remove Node 3 from Cluster A
- Reinstall OS with Rocky Linux 10 (optional)
- Join as RKE2 control plane
- Verify etcd cluster health

**Prerequisites:** All workloads running on Nodes 1-2, DNS not pointing to Node 3, external traffic routed elsewhere.

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

Remove Node 2 from Cluster A and add it as a control plane to Cluster B, achieving high availability.

**Steps:**

- Cordon and drain Node 2 from Cluster A
- Remove Node 2 and uninstall k3s
- Reinstall with Rocky Linux 10 (optional)
- Join as RKE2 control plane
- Verify 3-node etcd quorum

**Result:** Cluster B has 3 control planes with full HA. Workload migration can begin.

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

**Risk Level: LOW** - Both clusters operational, DNS can be switched back if issues arise.

**Steps:**

- Set up storage on Cluster B (Longhorn + local-path)
- Configure ingress (Traefik + Hetzner LB)
- Export workload manifests from Cluster A
- Migrate persistent data if needed
- Deploy workloads to Cluster B
- Switch DNS to Cluster B ingress

**Result:** All workloads running on Cluster B, Cluster A idle with only Node 1.

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

Decommission Cluster A and complete the RKE2 cluster.

**Steps:**

- Verify Cluster B stability (24-48 hour soak)
- Drain and remove Node 1 from Cluster A
- Uninstall k3s on Node 1
- Reinstall with Rocky Linux 10 (optional)
- Join as RKE2 agent (worker)

**Result:** Complete 4-node RKE2 cluster with 3 control planes and 1 worker.

## Risk Considerations

The highest-risk phase is Phase 2 when both clusters run at minimum viable capacity.
Never proceed to workload migration until Cluster B achieves full HA with 3 control plane nodes.

Before starting:

- Review all lessons thoroughly
- Practice the node installation process on a test system if possible
- Ensure complete backups of all persistent data
