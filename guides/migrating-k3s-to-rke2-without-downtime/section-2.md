---
layout: guide-section.liquid
title: Preparing Rocky Linux and RKE2 Environment

guide_component: section
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 2
guide_section_abstract: >
  Install Rocky Linux 10 on the first node, configure Hetzner networking, set up firewall rules, and bootstrap the
  initial RKE2 control plane with Canal CNI.
guide_section_cta: >
  learn how to prepare the new cluster environment with Rocky Linux and RKE2.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/section-2.md
---

This section covers the preparation of the new cluster environment.
You will install Rocky Linux 10 on the first new node (Node 4), configure the Hetzner vSwitch networking, set up firewalld for Kubernetes, and bootstrap the initial RKE2 control plane with Canal as the CNI plugin.

## Topics Covered

- Installing and configuring Rocky Linux 10 for Kubernetes
- Setting up Hetzner vSwitch private networking
- Configuring firewalld for RKE2 and Canal traffic
- Installing and configuring the first RKE2 control plane node with Canal CNI

The section concludes with a functional single-node RKE2 cluster ready to accept additional control plane nodes.
