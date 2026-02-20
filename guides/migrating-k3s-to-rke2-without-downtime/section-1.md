---
layout: guide-section.liquid
title: Introduction and Migration Strategy

guide_component: section
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 1
guide_section_abstract: >
  Understand the migration objectives, develop a migration strategy, install Rocky Linux 10 on the first new node,
  configure Hetzner vSwitch networking, and set up the firewall for Kubernetes traffic.
guide_section_cta: >
  learn about the migration strategy, prepare the new node with Rocky Linux, and configure networking and firewall rules.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/section-1.md
---

This section introduces the migration project, walks through building a migration strategy, and prepares the first new node for Kubernetes.
You will understand the current and target cluster states, plan the phased approach, install Rocky Linux 10 on Node 4, configure Hetzner vSwitch networking, and set up the firewall.

## Topics Covered

- Understanding the migration challenge and objectives
- Current k3s cluster limitations vs target RKE2 capabilities
- Detailed breakdown of all 5 migration phases
- Risk levels and considerations for each phase
- Installing and configuring Rocky Linux 10 on Node 4
- Setting up Hetzner vSwitch private networking with dual-stack IPv4/IPv6
- Configuring the Hetzner Robot firewall for RKE2 and Canal traffic

The section concludes with Node 4 running Rocky Linux 10, connected to the vSwitch, and with firewall rules configured for Kubernetes traffic.
