---
layout: post
title: Building a production-ready Kubernetes cluster from scratch
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch
---

Welcome to my new series on building a production-ready Kubernetes cluster from
scratch using Raspberry Pi devices. In this series, you can follow along to
build your own dedicated Kubernetes cluster at home, from hardware assembly to
cluster setup and management. The learnings can then be applied to real-world
scenarios, and scaled up to larger clusters as needed.

In particular, this series will cover the following topics:

- Set up a high-availability Kubernetes cluster using Raspberry Pi devices, from
  hardware assembly to network configuration
- Install, configure, and manage Kubernetes control plane nodes for redundancy
  and fault tolerance
- Deploy persistent storage and learn to manage container images and data
  effectively across multiple nodes.
- Implement security best practices, monitoring, and logging to maintain a
  resilient and secure Kubernetes cluster.

> [!IMPORTANT] As a strong believer in free open source resources, I made this
> written series available for free.
>
> **Please, if you can support my work, this series can also be purchased as a
> course on [Udemy](https://TODO), you can become a
> [GitHub Sponsor](https://github.com/sponsors/philprime) and you can share it
> in your network.**
>
> Thank you! ❤️

This series is perfect for you, if you are any one of the following:

- Tech enthusiasts, developers, and IT professionals who want to prototype
  cluster using Raspberry Pi devices.
- Beginner to intermediate learners with basic Linux and networking knowledge
  who want to deepen their understanding of Kubernetes.
- DIY hobbyists and makers interested in hands-on projects and building home
  labs or edge computing solutions with affordable hardware.
- DevOps engineers and system administrators looking to explore Kubernetes
  clustering, high availability, and storage management in resource-constrained
  environments.
- Educators and students in computer science or IT fields seeking practical
  experience with Kubernetes and cloud-native technologies.

To follow along you will need to meet these requirements:

- Basic understanding of Linux command line and shell scripting (e.g.,
  navigating directories, editing files, running commands).
- Basic understanding of Kubernetes concepts (pods, services, deployments) is
  helpful but not required.
- Familiarity with networking concepts, including IP addresses, subnets, DNS,
  and SSH.
- A computer running a unix-like system, such as Linux/macOS or Windows
  Subsystem with Linux (WSL), with an ethernet port for connecting to network.
- SSH client (e.g., OpenSSH, PuTTY) for remote access to Raspberry Pi devices.
- At least 3 Raspberry Pi devices (e.g. Raspberry Pi 4 with 4GB RAM) with
  MicroSD card (32GB or higher, high endurance recommended), USB-C power
  supplies for each
- A gigabit Ethernet router and switch (e.g., ER605) and Ethernet cables (CAT5e
  or higher).
- NVMe HATs for each Raspberry Pi with an SSD (512GB or higher)

## Series Overview

> [!NOTE] As this series was written for a Udemy course, the series is
> structured as a curriculum with sections and lessons. Each lesson is a
> separate post in this series, and the names lesson, article, posts are used
> interchangeably.

This series is divided into multiple sections, each focusing on a specific area
of the build process and setup. Here’s an overview of what you can expect in
each section, with links to individual lessons:

- [Section 1: Introduction to the Course and Project](/building-a-production-ready-kubernetes-cluster-from-scratch/section-1)

  > Understand the course objectives, the hardware and software requirements,
  > and the fundamentals of Kubernetes and high availability.

  - [Lesson 1: Welcome and Course Overview](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-1)

    > Get an introduction to the course structure, objectives, and the skills
    > you will acquire by the end. Understand how this course will help you
    > build a high-availability Kubernetes cluster with Raspberry Pi devices.

  - [Lesson 2: Tools and Equipment Needed](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-2)

    > Discover the hardware and software requirements for building your
    > Kubernetes cluster. Learn about the specific tools and equipment you’ll
    > need to follow along with the course.

  - [Lesson 3: Understanding High Availability and Kubernetes Basics](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-3)

    > Learn the basics of Kubernetes, its core components, and the principles of
    > high availability. Understand how these concepts apply to the cluster
    > you’ll build in this course.

- [Section 2: Building the Physical Setup](/building-a-production-ready-kubernetes-cluster-from-scratch/section-2)

  > Assemble the Raspberry Pi hardware, set up and configure the operating
  > system, and establish a reliable network connection for the cluster.

  - [Lesson 4: Unboxing and Preparing the Raspberry Pi Devices](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-4)

    > Unbox your Raspberry Pi devices and prepare them for the cluster setup.
    > Learn about the hardware components and their roles in the Kubernetes
    > cluster.

  - [Lesson 5: Flashing Raspberry Pi OS and Initial Configuration](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-5)

    > Follow a step-by-step guide to install Raspberry Pi OS on your devices,
    > configure essential settings, and prepare them for networking.

  - [Lesson 6: Setting Up NVMe SSDs for Persistent Storage](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-6)

    > Learn how to install NVMe HATs and configure 512GB SSDs for use with
    > Longhorn and local container image storage.

  - [Lesson 7: Networking Setup and Configuration](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-7)
    > Set up the network for your Raspberry Pi cluster, including configuring
    > static IPs, ensuring connectivity, and verifying network settings.

- [Section 3: Preparing the Environment for Kubernetes](/building-a-production-ready-kubernetes-cluster-from-scratch/section-3)

  > Install essential Kubernetes tools, configure a container runtime, and
  > prepare all Raspberry Pi nodes for cluster initialization.

  - [Lesson 8: Installing Kubernetes Tools (kubectl, kubeadm, kubelet)](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-8)

    > Install and configure essential Kubernetes tools on your Raspberry Pi
    > devices to prepare them for cluster initialization.

  - [Lesson 9: Setting Up Docker or Container Runtime](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-9)

    > Set up Docker or another container runtime to run containers on your
    > Raspberry Pi devices as part of the Kubernetes cluster.

  - [Lesson 10: Preparing Nodes for Kubernetes Initialization](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-10)

    > Configure each Raspberry Pi node to ensure it’s ready for Kubernetes
    > cluster initialization, including system requirements and configurations.

- [Section 4: Configuring the Kubernetes Cluster](/building-a-production-ready-kubernetes-cluster-from-scratch/section-4)

  > Initialize the Kubernetes control plane, join additional nodes to the
  > cluster, and install a pod network to enable communication between nodes.

  - [Lesson 11: Initializing the First Control Plane Node](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-11)

    > Step-by-step guide to initializing the first control plane node in your
    > Kubernetes cluster, including running kubeadm init and configuring the
    > control plane.

  - [Lesson 12: Joining Additional Control Plane Nodes](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-12)

    > Learn how to join additional Raspberry Pi devices to the cluster to create
    > a high-availability control plane.

  - [Lesson 13: Installing a Pod Network (CNI Plugin)](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-13)

    > Install and configure a CNI plugin (e.g., Calico or Flannel) to enable pod
    > communication across nodes in the Kubernetes cluster.

- [Section 5: Setting Up High Availability for the Control Plane](/building-a-production-ready-kubernetes-cluster-from-scratch/section-5)

  > Implement load balancing for the control plane API, set up redundancy using
  > tools like Keepalived or HAProxy, and verify high availability.

  - [Lesson 14: Configuring Load Balancing for the Control Plane](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-14)

    > Learn how to set up load balancing for the Kubernetes API server to
    > distribute traffic evenly and ensure high availability.

  - [Lesson 15: Implementing Redundancy with Keepalived or HAProxy](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-15)

    > Implement redundancy using tools like Keepalived or HAProxy to ensure
    > continuous access to the control plane in case of failures.

  - [Lesson 16: Testing Control Plane High Availability](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-16)

    > Test and verify the high-availability configuration of your control plane
    > to ensure it remains functional during node failures.

- [Section 6: Deploying Persistent Storage with Longhorn](/building-a-production-ready-kubernetes-cluster-from-scratch/section-6)

  > Install and configure Longhorn for distributed block storage, create storage
  > classes, and manage persistent volumes across the cluster.

  - [Lesson 17: Installing Longhorn for Distributed Block Storage](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-17)

    > Install Longhorn, a lightweight and reliable distributed block storage
    > solution, to manage persistent volumes across your Kubernetes cluster.

  - [Lesson 18: Configuring Longhorn Storage Classes](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-18)

    > Learn how to create and configure storage classes in Longhorn to manage
    > your storage resources efficiently.

  - [Lesson 19: Testing and Optimizing Longhorn Performance](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-19)

    > Test the performance of your Longhorn storage setup and learn optimization
    > techniques for better performance and reliability.

- [Section 7: Securing the Cluster](/building-a-production-ready-kubernetes-cluster-from-scratch/section-7)

  > Apply role-based access control (RBAC), enable mutual TLS authentication,
  > and implement network policies to secure the Kubernetes cluster.

  - [Lesson 20: Implementing Role-Based Access Control (RBAC)](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-20)

    > Configure RBAC in Kubernetes to manage access and permissions for users
    > and applications securely.

  - [Lesson 21: Enabling Mutual TLS Authentication](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-21)

    > Set up mutual TLS authentication to secure communication between
    > Kubernetes components and protect your cluster.

  - [Lesson 22: Applying Network Policies](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-22)

    > Learn how to create and apply network policies to control traffic between
    > pods and enhance the security of your cluster.

- [Section 8: Monitoring and Logging](/building-a-production-ready-kubernetes-cluster-from-scratch/section-8)

  > Deploy and configure monitoring tools like Prometheus and Grafana, set up
  > the EFK stack (ElasticSearch, Fluentd, Kibana) for logging, and create
  > alerts and dashboards.

  - [Lesson 23: Installing Prometheus and Grafana](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-23)

    > Deploy Prometheus and Grafana for real-time monitoring and visualization
    > of your Kubernetes cluster’s performance and health.

  - [Lesson 24: Setting Up the EFK Stack (Elasticsearch, Fluentd, Kibana)](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-24)

    > Install and configure the EFK stack for centralized logging and log
    > analysis within your Kubernetes cluster.

  - [Lesson 25: Creating Alerts and Dashboards](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-25)

    > Set up alerts and create custom dashboards in Grafana to monitor critical
    > metrics and receive notifications of potential issues.

- [Section 9: Testing and Validating Cluster Resilience](/building-a-production-ready-kubernetes-cluster-from-scratch/section-9)

  > Deploy applications, simulate failures, test cluster resilience, and verify
  > that security and monitoring configurations are working correctly.

  - [Lesson 26: Deploying Sample Applications](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-26)

    > Deploy example applications to test your Kubernetes cluster’s
    > functionality and ensure that it’s correctly configured.

  - [Lesson 27: Simulating Node Failures and Recovery](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-27)

    > Simulate node failures and practice recovery procedures to validate the
    > resilience of your Kubernetes cluster.

  - [Lesson 28: Verifying Security and Monitoring Configurations](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-28)

    > Verify that your security measures, monitoring tools, and configurations
    > are working correctly to protect and maintain your cluster.

- [Section 10: Regular Maintenance and Updates](/building-a-production-ready-kubernetes-cluster-from-scratch/section-10)

  > Perform backups and disaster recovery for etcd, update Kubernetes
  > components, and conduct routine security audits and vulnerability scans.

  - [Lesson 29: Backup and Disaster Recovery for etcd](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-29)

    > Learn how to back up and restore the etcd data store to protect your
    > cluster’s critical data and configurations.

  - [Lesson 30: Updating Kubernetes Components and Nodes](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-30)

    > Safely update Kubernetes components and manage node updates to keep your
    > cluster secure and up to date.

  - [Lesson 31: Performing Routine Security Audits](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-31)

    > Conduct regular security audits and vulnerability scans to identify and
    > mitigate potential risks in your cluster.

- [Section 11: Conclusion and Next Steps](/building-a-production-ready-kubernetes-cluster-from-scratch/section-11)

  > Review key concepts learned, access additional resources for further study,
  > and provide feedback for course improvements.

  - [Lesson 32: Review and Final Thoughts](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-32)

    > Recap key concepts covered throughout the course and reflect on what you
    > have learned.

  - [Lesson 33: Additional Resources and Further Learning](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-33)

    > Access additional resources, tools, and materials for further learning and
    > exploring Kubernetes in more depth.

  - [Lesson 34: Course Feedback and Future Updates](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-34)

    > Provide feedback on the course and learn about potential updates and
    > future enhancements.

## Getting Started

To get started with the series, head over to the
[first section](/building-a-production-ready-kubernetes-cluster-from-scratch/section-1)
to learn more about the course objectives and the skills you will acquire by the
end.
