---
layout: guide-section.liquid
title: Cluster Consolidation and Cleanup

guide_component: section
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 5
guide_section_abstract: >
  Validate the migration, decommission the k3s cluster, add the final node as an RKE2 worker, and complete
  post-migration cleanup and documentation.
guide_section_cta: >
  learn how to finalize the migration and clean up the old cluster.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/section-5.md
---

This section covers the final phase of the migration: validating everything works correctly, safely decommissioning
the old k3s cluster, adding the final node as an RKE2 worker, and completing post-migration tasks.

## Topics Covered

- Final validation checklist before decommissioning
- Safely decommissioning the k3s cluster on Node 1
- Installing Rocky Linux and adding Node 1 as an RKE2 worker
- Post-migration cleanup tasks
- Documentation and operational handoff

By the end of this section, you will have a fully operational 4-node RKE2 cluster with 3 control plane nodes and
1 worker node, with the old k3s cluster completely decommissioned.
