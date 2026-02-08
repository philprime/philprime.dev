---
layout: guide-section.liquid
title: Workload Migration and Cutover

guide_component: section
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 4
guide_section_abstract: >
  Export workloads from the k3s cluster, set up storage and ingress on RKE2, migrate persistent volumes, and
  perform the traffic cutover to complete the migration.
guide_section_cta: >
  learn how to migrate workloads and switch traffic to the new cluster.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/section-4.md
---

This section covers the migration of your actual workloads from Cluster A (k3s) to Cluster B (RKE2). You will export
manifests, set up storage classes, configure high-availability ingress, migrate persistent data, and perform the
final DNS cutover.

## Topics Covered

- Exporting workload manifests from the k3s cluster
- Setting up Longhorn and local-path-provisioner storage classes
- Configuring Traefik DaemonSet with Hetzner Cloud Load Balancer for HA ingress
- Migrating persistent volumes and data
- Deploying workloads to the new cluster
- Performing DNS cutover and traffic switching

By the end of this section, all your workloads will be running on Cluster B with traffic flowing through the new
ingress infrastructure.
