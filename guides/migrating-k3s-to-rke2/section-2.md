---
layout: guide-section.liquid
title: Preparing Rocky Linux and RKE2 Environment

guide_component: section
guide_id: migrating-k3s-to-rke2
guide_section_id: 2
guide_section_abstract: >
  Bootstrap the initial RKE2 control plane with Canal CNI, configure WireGuard encryption and network policies,
  and set up storage, ingress, access control, and TLS certificates.
guide_section_cta: >
  learn how to bootstrap RKE2 and configure all cluster services.
repo_file_path: guides/migrating-k3s-to-rke2/section-2.md
---

This section bootstraps the RKE2 cluster on Node 4 and configures all services needed before migrating workloads.
You will install and configure the first RKE2 control plane node with Canal CNI, set up WireGuard encryption and network policies, configure storage, deploy ingress, set up access control, and issue TLS certificates.

## Topics Covered

- Installing and configuring the first RKE2 control plane node with Canal CNI
- Configuring Canal with WireGuard encryption and network policies
- Setting up Longhorn and local-path storage classes
- Deploying Traefik as a DaemonSet with Hetzner Cloud Load Balancer
- Configuring access control with OIDC and RBAC
- Setting up TLS certificates with cert-manager

The section concludes with a fully configured single-node RKE2 cluster ready to accept additional control plane nodes.
