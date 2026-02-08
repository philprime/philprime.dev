---
layout: guide-lesson.liquid
title: Welcome and Migration Overview

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 1
guide_lesson_id: 1
guide_lesson_abstract: >
  Get an overview of the migration project, understand the goals, and learn what to expect throughout this guide.
guide_lesson_conclusion: >
  You now understand the migration objectives, the cluster topology changes, and what this guide will help you achieve.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-1.md
---

Welcome to this comprehensive guide on migrating from k3s to RKE2 without downtime. In this first lesson, we will
establish the context for our migration, understand the goals, and preview the journey ahead.

{% include guide-overview-link.liquid.html %}

## The Migration Challenge

Migrating a production Kubernetes cluster is one of the most complex operations in infrastructure management. The
challenge multiplies when you need to:

1. **Maintain zero downtime** - Your services must remain available throughout
2. **Change the underlying distribution** - Moving from k3s to RKE2
3. **Reconfigure the node topology** - Shifting from 1 control plane + 2 workers to 3 control planes + 1 worker
4. **Replace the operating system** - Moving to Rocky Linux 9
5. **Upgrade networking and storage** - Implementing Cilium and Longhorn

## Current State: Cluster A (k3s)

Our starting point is a 3-node k3s cluster:

```mermaid!
%%{init: {
  "theme": "base",
  "flowchart": {
    "nodeSpacing": 20,
    "rankSpacing": 30
  },
  "themeVariables": {
    "padding": 6,
    "nodePadding": 6,
    "subGraphPadding": 8,
    "fontSize": "12px"
  }
}}%%

flowchart LR

%% =========================
%% Global Styles
%% =========================
classDef clusterA fill:#2563eb,color:#ffffff,stroke:#1e40af
classDef clusterB fill:#16a34a,color:#ffffff,stroke:#166534
classDef unassigned fill:#9ca3af,color:#ffffff,stroke:#6b7280
classDef critical stroke:#dc2626,stroke-width:3px
classDef success stroke:#16a34a,stroke-width:2px

%% =========================
%% Phase 0 — Initial State
%% =========================
subgraph Phase0["Phase 0 · Initial State"]
  direction LR

  subgraph P0A["Cluster A - (k3s)"]
    direction TB
    P0A1["🧠 Node 1"]
    P0A2["⚙️ Node 2"]
    P0A3["⚙️ Node 3"]
  end

  P0U["Node 4 · Unassigned"]
end

class P0A clusterA
class P0U unassigned
```

This setup has served well, but it presents a couple of critical limitations:

- Node 1 is a single point of failure as it's the only control plane node
- No distributed or replicated storage solution is in place, relying on local storage on each node
- Flannel CNI provides basic networking but external ingress is routed directly to fixed node IPs, limiting flexibility

## Target State: Cluster B (RKE2)

Our target is a 4-node RKE2 cluster with high availability set up for the control plane, storage and networking:

```mermaid!
%%{init: {
  "theme": "base",
  "flowchart": {
    "nodeSpacing": 20,
    "rankSpacing": 30
  },
  "themeVariables": {
    "padding": 6,
    "nodePadding": 6,
    "subGraphPadding": 8,
    "fontSize": "12px"
  }
}}%%

flowchart LR

%% =========================
%% Global Styles
%% =========================
classDef clusterA fill:#2563eb,color:#ffffff,stroke:#1e40af
classDef clusterB fill:#16a34a,color:#ffffff,stroke:#166534
classDef unassigned fill:#9ca3af,color:#ffffff,stroke:#6b7280
classDef critical stroke:#dc2626,stroke-width:3px
classDef success stroke:#16a34a,stroke-width:2px

%% =========================
%% Phase 4 — Migration Complete
%% =========================
subgraph Phase4["Phase 4 · Complete"]
  direction LR

  subgraph P4B["RKE2"]
    direction TB
    P4B1["⚙️ Node 1"]
    P4B2["🧠 Node 2"]
    P4B3["🧠 Node 3"]
    P4B4["🧠 Node 4"]
  end
end

class P4B clusterB
class Phase4 success

%% =========================
%% Timeline
%% =========================
Phase0 -.-> Phase1 -.-> Phase2 -.-> Phase3 -.-> Phase4
```

This configuration provides:

- 3 control plane nodes for high availability and resilience
- Extensibility to add more worker nodes in the future
- Robust storage options using Longhorn for slower replicated volumes and local-path for performance-sensitive workloads
- Advanced networking with Cilium for better performance and observability
- High-availability ingress with Traefik DaemonSet and Hetzner Cloud Load Balancer

## Guide Structure

This guide is organized into 5 sections with 25 lessons:

| Section                                       | Focus                      |
| --------------------------------------------- | -------------------------- |
| 1. Introduction and Migration Strategy        | Planning and preparation   |
| 2. Preparing Rocky Linux and RKE2 Environment | Bootstrap Cluster B        |
| 3. Migrating Nodes to the New Cluster         | Node-by-node transition    |
| 4. Workload Migration and Cutover             | Move workloads and traffic |
| 5. Cluster Consolidation and Cleanup          | Finalize and document      |

## Time and Risk Considerations

This migration requires careful execution. While the actual migration can be completed in a single maintenance
window, I recommend:

- Thoroughly review all lessons before starting
- Practice the node installation process on a test system if possible
- Ensure you have complete backups of all persistent data

The highest-risk phase occurs during the 2-node transition when both clusters are at minimum viable capacity. We
will cover this in detail in the migration strategy lesson.

Let's begin by understanding the RKE2 architecture and how it differs from k3s in the next lesson.
