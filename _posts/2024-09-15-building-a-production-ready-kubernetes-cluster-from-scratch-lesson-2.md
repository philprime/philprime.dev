---
layout: course-lesson
title: Tools and Equipment Needed (L2)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-2
---

In this lesson, you will discover the hardware and software requirements for
building your Kubernetes cluster, and learn about the specific tools and
equipment you’ll need to follow along with the course.

This is the second lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-1)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

Before we start building our Kubernetes cluster, it’s important to gather all
the necessary tools and equipment. In this lesson, we’ll go over everything you
need to follow along with this course, from hardware components to essential
software tools.

## Hardware Requirements

To set up your Kubernetes cluster, you will need several hardware components:

- You will need at least three Raspberry Pi 4 devices, ideally with 4GB or 8GB
  of RAM for better performance.
- Each Raspberry Pi requires a 32GB (or higher) microSD card, with
  high-endurance cards recommended for reliability.
- For persistent storage, you will need 512GB NVMe SSDs along with compatible
  NVMe HATs for each Raspberry Pi.
- Each device also requires a 5V/3A USB-C power supply to ensure stable
  operation.
- To connect all Raspberry Pi devices, you will need a gigabit Ethernet switch,
  such as the TL-SG108, and a wired router like the ER605 to link the cluster to
  your home network.
- You should have CAT5e or higher Ethernet cables available to connect the
  Raspberry Pi devices to the switch.
- It is recommended to use heatsinks or cooling fans for each Raspberry Pi to
  prevent overheating during continuous operation.

## Software Requirements

You will also need several software tools to complete this course:

- Raspberry Pi OS Lite (without a desktop environment) should be installed on
  all Raspberry Pi devices.
- An SSH client, such as OpenSSH (pre-installed on most Unix-like systems) or
  PuTTY (for Windows), is required to remotely access the Raspberry Pi devices.
- The Kubernetes tools `kubectl`, `kubeadm`, and `kubelet` need to be installed
  on your Raspberry Pi devices to manage the cluster.
- A container runtime like Docker is necessary to run containers on the devices.
- A text editor like `nano` or `vim` is useful for editing configuration files
  directly on the Raspberry Pi devices.

## Additional Requirements

There are a few more things that will be helpful as you follow along:

- You should have a basic understanding of Linux command line usage and
  networking concepts, such as IP addresses, subnets, and SSH.
- A computer running a Unix-like system, such as Linux, macOS, or Windows
  Subsystem for Linux, with an Ethernet port is required for the initial setup.
- An internet connection is needed for downloading software, updates, and
  Kubernetes components.

## Getting Ready

Make sure to gather all the hardware components and install the necessary
software tools before proceeding to the next lesson. Having everything prepared
will make the setup process smoother and allow you to focus on building your
Kubernetes cluster step-by-step.

## Lesson Conclusion

Congratulations! You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-3).
