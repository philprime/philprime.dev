---
layout: guide-section.liquid
title: Completing the Migration

guide_component: section
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 4
guide_section_abstract: >
  Decommission the k3s cluster, add Node 1 as an RKE2 worker, and finalize the 4-node cluster.
guide_section_cta: >
  learn how to decommission the old cluster and complete the migration.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/section-4.md
---

With Cluster B running a 3-node HA control plane and all workloads migrated, this section covers the final steps: safely removing the k3s cluster, adding its former node as an RKE2 worker, and reviewing the completed architecture.

## Topics Covered

- Decommissioning Cluster A and uninstalling k3s from Node 1
- Installing Rocky Linux and joining Node 1 as a dedicated worker node
- Reviewing the final cluster architecture and exploring next steps

The section concludes with a completed migration — a 4-node RKE2 cluster with 3 control plane nodes and 1 worker node, fully replacing the original k3s cluster.
