---
layout: course-lesson
title: Understanding High Availability and Kubernetes Basics (L3)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-3
---

In this lesson, you will learn the basics of Kubernetes, its core components,
and the principles of high availability. Furthremore, you will understand how
these concepts apply to the cluster you’ll build in this course.

This is the third lesson in the series on building a production-ready Kubernetes
cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-2)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## What is Kubernetes?

Kubernetes is an open-source platform for automating the deployment, scaling,
and management of containerized applications. Originally developed by Google,
Kubernetes has become the standard for container orchestration, allowing you to
run and manage your applications across a cluster of servers efficiently.

At its core, Kubernetes groups containers that make up an application into
logical units for easy management and discovery. It automates the deployment and
operation of application containers across clusters of hosts, providing
mechanisms for deployment, maintenance, and scaling.

## Key Components of Kubernetes

Kubernetes consists of several key components:

- The **Kubernetes Control Plane** manages the state of the cluster, making
  global decisions about the cluster (like scheduling) and detecting and
  responding to cluster events (like starting up new pods when a deployment’s
  replicas field is unsatisfied).
- The **Kubelet** is an agent that runs on each node in the cluster. It ensures
  that containers are running in a pod as expected.
- The **Pod** is the smallest and simplest Kubernetes object. A pod represents a
  single instance of a running process in your cluster and can contain one or
  more containers.
- **Kube-Proxy** is a network proxy that runs on each node in the cluster. It
  maintains network rules on nodes, allowing network communication to your pods
  from network sessions inside or outside of your cluster.
- The **etcd** component is a consistent and highly available key-value store
  used as Kubernetes' backing store for all cluster data.

## What is High Availability (HA)?

High Availability (HA) refers to the ability of a system to remain operational
and accessible even in the presence of faults or failures. In the context of
Kubernetes, HA ensures that your cluster remains functional even when one or
more components fail. This is achieved by:

- Deploying multiple instances of critical components, such as the control plane
  and etcd, across different nodes to eliminate single points of failure.
- Using load balancers to distribute traffic evenly across these components,
  ensuring that the cluster continues to respond to client requests even if some
  instances go down.
- Implementing redundant networking and storage configurations to maintain data
  integrity and network connectivity during failures.

## Why High Availability is Important for Kubernetes

High availability is critical for any production environment because it
minimizes downtime and ensures consistent access to applications and services.
In Kubernetes, high availability protects against hardware failures, software
bugs, and other unexpected issues that could otherwise lead to service
disruptions.

For example, if one of your control plane nodes fails, a high-availability
configuration with multiple control plane nodes will continue to function
without any downtime. This is essential for applications that require continuous
uptime or have high service-level agreements (SLAs).

## Applying These Concepts to Your Raspberry Pi Cluster

Throughout this course, we will build a high-availability Kubernetes cluster
using Raspberry Pi devices. You will learn to set up multiple control plane
nodes, configure etcd for fault tolerance, and use load balancers to distribute
traffic. By the end of this course, you will have a robust cluster that can
handle real-world scenarios and continue running even when faced with
challenges.

## Lesson Conclusion

Congratulations! You have completed this lesson and you can now continue with
[the next section](/building-a-production-ready-kubernetes-cluster-from-scratch/section-2).
