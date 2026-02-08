---
layout: guide-section.liquid
title: Migrating Nodes to the New Cluster

guide_component: section
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 3
guide_section_abstract: >
  Safely migrate worker nodes from the k3s cluster to RKE2, handling the critical 2-node transition phase and
  achieving high availability with a 3-node control plane.
guide_section_cta: >
  learn how to safely migrate nodes while maintaining service availability.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/section-3.md
---

This section covers the most critical phase of the migration: moving nodes from the k3s cluster to RKE2. You will
learn how to safely drain nodes, handle the 2-node transition phase, and build a highly available 3-node control
plane on the new cluster.

## Topics Covered

- Preparing nodes for migration with proper cordoning and draining
- Navigating the critical 2-node transition phase
- Installing Rocky Linux and RKE2 on migrated nodes
- Joining nodes to the RKE2 cluster as control plane members
- Verifying etcd cluster health and HA status

By the end of this section, Cluster B (RKE2) will have a fully operational 3-node high-availability control plane,
while Cluster A (k3s) continues to serve traffic with its remaining nodes.
