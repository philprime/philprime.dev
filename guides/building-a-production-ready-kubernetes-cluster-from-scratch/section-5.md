---
layout: guide-section.liquid
title: Setting Up High Availability for the Control Plane

guide_component: section
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
guide_section_id: 5
guide_section_abstract: >
  Implement load balancing for the control plane API, set up redundancy using tools like Keepalived or HAProxy, and
  verify high availability.
---

In this section, you will learn how to mplement load balancing for the control plane API, set up redundancy using tools
like Keepalived or HAProxy, and verify high availability.

This is the fifth section in the series on building a production-ready Kubernetes cluster from scratch. Make sure you
have completed the [previous section](#) before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## Lessons

- [L14: Configuring Load Balancing for the Control Plane](/2024/XX/XX/building-a-production-ready-kubernetes-cluster-from-scratch-l14)

  > Learn how to set up load balancing for the Kubernetes API server to distribute traffic evenly and ensure high
  > availability.

- [L15: Implementing Redundancy with Keepalived or HAProxy](/2024/XX/XX/building-a-production-ready-kubernetes-cluster-from-scratch-l15)

  > Implement redundancy using tools like Keepalived or HAProxy to ensure continuous access to the control plane in case
  > of failures.

- [L16: Testing Control Plane High Availability](/2024/XX/XX/building-a-production-ready-kubernetes-cluster-from-scratch-l16)

  > Test and verify the high-availability configuration of your control plane to ensure it remains functional during
  > node failures.

## Getting Started

To get started with the section, head over to the
[fourteenth lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lession-14) to learn how to configure
load balancing for the Kubernetes API server.
