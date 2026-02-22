---
layout: guide-section.liquid
title: Migrating Nodes to the New Cluster

guide_component: section
guide_id: migrating-k3s-to-rke2
guide_section_id: 3
guide_section_abstract: >
  Safely migrate nodes from the k3s cluster to RKE2 as control plane members, handling the critical 2-node transition phase and
  achieving high availability with a 3-node control plane.
guide_section_cta: >
  learn how to safely migrate nodes while maintaining service availability.
repo_file_path: guides/migrating-k3s-to-rke2/section-3.md
---

This section covers the most critical phase of the migration: moving nodes from the k3s cluster to RKE2.
Each node follows the same pattern — analyze workloads, create backups, drain, reinstall the OS, and join RKE2.

## Topics Covered

- Draining nodes from Cluster A and joining them to Cluster B as RKE2 control plane members
- Understanding etcd quorum and why 3 nodes is the HA threshold
- Verifying the completed control plane with failover testing

The section concludes with Cluster B (RKE2) running a fully operational 3-node high-availability control plane, while Cluster A (k3s) continues to serve traffic on its remaining node.
