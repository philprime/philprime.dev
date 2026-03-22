---
layout: guide-section.liquid
title: Introduction and Migration Strategy

guide_component: section
guide_id: migrating-k3s-to-rke2
guide_section_id: 1
guide_section_abstract: >
  Understand the migration objectives, develop a migration strategy, install Rocky Linux 10 on the first new node,
  configure Hetzner vSwitch networking, and set up the firewall for Kubernetes traffic.
guide_section_cta: >
  learn about the migration strategy, prepare the new node with Rocky Linux, and configure networking and firewall rules.
repo_file_path: guides/migrating-k3s-to-rke2/section-1.md
---

Every migration starts with a plan and a blank server.
This section develops the phased strategy that guides the rest of the guide, then turns Node 4 into a production-ready base for the first RKE2 control plane: Rocky Linux installed, vSwitch networking configured with dual-stack addressing, and firewall rules locked down for Kubernetes traffic.

By the end, Node 4 is ready to bootstrap RKE2 without the existing k3s cluster being touched.
