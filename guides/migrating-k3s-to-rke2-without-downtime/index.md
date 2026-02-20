---
layout: guide.liquid
title: Migrating from k3s to RKE2 Without Downtime
permalink: /guides/migrating-k3s-to-rke2-without-downtime

guide_component: guide
guide_id: migrating-k3s-to-rke2-without-downtime
guide_abstract: >
  A comprehensive guide for migrating from a 3-node k3s cluster to a 4-node RKE2 Kubernetes cluster with zero downtime,
  using Rocky Linux 10, Canal CNI, and Hetzner infrastructure.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/index.md
description:
  "Complete guide to migrating from k3s to RKE2 Kubernetes without downtime. Covers node-by-node migration strategy,
  Rocky Linux 10 setup, Canal CNI, Longhorn storage, Traefik ingress with Hetzner Load Balancer, and HA configuration."
excerpt:
  "Learn to migrate from k3s to RKE2 Kubernetes with zero downtime. Step-by-step tutorial covering node migration,
  Rocky Linux setup, Canal networking, persistent storage migration, and high-availability ingress configuration
  on Hetzner infrastructure."
keywords:
  "k3s migration, RKE2, Kubernetes migration, zero downtime, Rocky Linux, Canal CNI, Longhorn storage, Traefik ingress,
  Hetzner, high availability, cluster migration, SUSE Rancher"
tags: Kubernetes RKE2 k3s migration DevOps Rocky-Linux Canal Longhorn Traefik Hetzner high-availability
author: Philip Niedertscheider
---

Welcome to my guide on migrating from k3s to RKE2 while keeping downtime to a minimum.
Follow along as I walk through the complete process of transitioning a 3-node k3s setup to a 4-node RKE2 cluster with high availability, using enterprise-grade tools and practices.

{% include alert.liquid.html type='note' title='Please read this' content='

<p>I originally planned to offer this guide as a paid online course, but as a strong believer in free open source resources, I made it available for free instead.</p>
  <p>Please, if my guides helped you, I would be very grateful if you could support my work by becoming a <a href="https://github.com/sponsors/philprime" style="color: #000;">GitHub Sponsor</a> and by sharing the guides in your network. 🙏</p>
  <p>Eventually I might offer additional guides as paid online courses, but for now, I want to focus on providing free guides.</p>
  <p>Thank you ❤️</p>
' %}

## Why Migrate from k3s to RKE2?

I started our original cluster using k3s due to the ease of setup and lightweight nature for our CI/CD workloads, which were not considered mission-critical at the time.
As our migration from bare-metal GitHub Action runners to Kubernetes GitHub Action Runner Controller (ARC) continued, we noticed a significant increase in our resource demand.
I decided to add two additional Hetzner dedicated servers as worker nodes to our cluster and looked into getting them production-ready, using inter-node communication via vSwitch (see my existing blog post [New K3s agent node for our cluster](/2025-11-23-new-k3s-agent-node) if you want to learn more).

This enabled us to move additional development and proof-of-concept workloads from a comparably expensive Elastic Kubernetes Service (EKS) in Amazon Web Services (AWS) to our self-managed infrastructure, saving us a fortune.
However, as we continued to grow, we started to feel the limitations of k3s — it was not designed for larger, complex clusters with high availability requirements, but instead focused on simplicity and ease of use for edge and IoT environments.

This made me look into alternatives, and RKE2 stood out as a robust and enterprise-grade Kubernetes distribution also maintained by SUSE/Rancher, the same company behind k3s.
While k3s offers a lot of built-in features and convenience tools, I wanted to be closer to enterprise-level Kubernetes behavior and have greater control over the components as our environment grows — exactly what RKE2 provides.

On top of that, the etcd component in k3s was showing stability issues, especially since I had not yet migrated to high availability.
With RKE2, I can set up a proper HA control plane with multiple etcd nodes, significantly improving reliability.
RKE2's focus on security and compliance also gives me a stronger foundation — crucial as we continue adding production workloads.

The final push to migrate came when we decided to add another bare-metal dedicated server.
This allowed me to bootstrap RKE2 on the new node without touching the existing k3s nodes — enabling a zero-downtime migration.

## What This Guide Covers

- Plan and execute a zero-downtime Kubernetes cluster migration
- Deploy RKE2 with high-availability control plane configuration
- Configure dual-stack IPv4/IPv6 networking with Canal CNI for large-scale cluster communication
- Set up dual storage classes with Longhorn (highly available) and local-path-provisioner (fast)
- Implement highly available ingress using Traefik DaemonSet with Hetzner Cloud Load Balancer
- Handle the critical 2-node transition phase safely

## Prerequisites

To follow this guide, you must have:

- Basic understanding of Kubernetes concepts (pods, services, deployments, persistent volumes)
- Experience with Linux system administration (command line, systemd, networking)
- Familiarity with k3s cluster management
- Access to 4 dedicated servers in Hetzner for exact networking replication
- A working k3s cluster to migrate from
