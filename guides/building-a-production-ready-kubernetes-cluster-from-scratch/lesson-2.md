---
layout: guide-lesson.liquid
title: Tools and Equipment Needed

guide_component: lesson
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
guide_section_id: 1
guide_lesson_id: 2
guide_lesson_abstract: >
  Discover the hardware and software requirements for building your Kubernetes cluster. Learn about the specific tools
  and equipment you’ll need to follow along with the course.
---

{% include assign-guide.liquid.html %}

In this lesson, you will discover the hardware and software requirements for building your Kubernetes cluster, and learn
about the specific tools and equipment you’ll need to follow along with the course.

{% include guide-overview-link.liquid.html %}

Before we start building our Kubernetes cluster, it’s important to gather all the necessary tools and equipment. In this
lesson, we’ll go over everything you need to follow along with this course, from hardware components to essential
software tools.

## Hardware Requirements

To set up your Kubernetes cluster, you will need several hardware components:

- You will need at least three Raspberry Pi 5 devices, ideally with 8GB of RAM for better performance.
- Each Raspberry Pi requires a 64GB (or higher) microSD card, with high-endurance cards recommended for reliability.
- For persistent storage, you will need 500GB NVMe SSDs along with compatible NVMe HATs for each Raspberry Pi. Make sure
  the lengths of the SSDs are supported by the HATs.
- Each device also requires a 5V/5A USB-C power supply to ensure stable operation.
- To connect all Raspberry Pi devices, you will need a gigabit wired router like the [TP-LINK ER605](// TODO: ADD
  AFFILIATE LINK) (or any other networking router) to create a local network for your cluster.
- You should have CAT5e or higher Ethernet cables available to connect the Raspberry Pi devices to the router.

![Hardware Overview](/assets/blog/2024-09-15-building-a-production-ready-kubernetes-cluster-from-scratch/hardware-overview.jpg)

### Exact Hardware List

// TODO: add more details on the hardware components

The following is the exact list of hardware components used in this course:

**Raspberry Pi 5:**

- Raspberry Pi 5 (8GB RAM)
- 64-bit quad-core Cortex-A76 processor
- 8GB LPDDR4X SDRAM
- Gigiabit Ethernet port
- 5V/5A USB-C power supply recommended, 5V/3A minimum requirement

![Raspberry Pi 5](/assets/blog/2024-09-15-building-a-production-ready-kubernetes-cluster-from-scratch/raspberry-pi.jpg)

**Power Supply:**

- Official Raspberry Pi USB-C Power Supply 27W
- Provides 5.1V, 5.0A DC output

![Power Supply](/assets/blog/2024-09-15-building-a-production-ready-kubernetes-cluster-from-scratch/power-supply.jpg)

**MicroSD Card:**

- 64GB High-Speed MicroSD Card
- Model: HSTF
- Manufacturer: Shenzhen Haishitongda Technology Co., Ltd.

![MicroSD Card](/assets/blog/2024-09-15-building-a-production-ready-kubernetes-cluster-from-scratch/microsd-card.jpg)

**Raspberry PI NVMe HAT:**

- Pimoroni - PIM699
- Supports M.2 NVMe SSDs
- Supports 2280, 2260, 2242, and 2230 form factors

![NVMe HAT](/assets/blog/2024-09-15-building-a-production-ready-kubernetes-cluster-from-scratch/nvme-hat.jpg)

**NVMe SSD:**

- Kingston SNV3S/500G
- 500GB PCIe 4.0 NVMe M.2

![NVMe SSD](/assets/blog/2024-09-15-building-a-production-ready-kubernetes-cluster-from-scratch/nvme-ssd.jpg)

**Router:**

- TP-LINK ER605
- Gigabit Wired Router
- 4x Gigabit LAN Ports / 1x Gigabit WAN Port

![Router](/assets/blog/2024-09-15-building-a-production-ready-kubernetes-cluster-from-scratch/router.jpg)

**Ethernet Cable:**

- CAT6 Ethernet Cable
- Length: 0.15m

![Ethernet Cable](/assets/blog/2024-09-15-building-a-production-ready-kubernetes-cluster-from-scratch/ethernet-cables.jpg)

## Software Requirements

You will also need several software tools to complete this course:

- An SSH client, such as OpenSSH (pre-installed on most Unix-like systems) or PuTTY (for Windows), is required to
  remotely access the Raspberry Pi devices.

## Additional Requirements

There are a few more things that will be helpful as you follow along:

- You should have a basic understanding of Linux command line usage and networking concepts, such as IP addresses,
  subnets, and SSH.
- A computer running a Unix-like system, such as Linux, macOS, or Windows Subsystem for Linux, with an Ethernet port is
  required for the initial setup.
- An internet connection is needed for downloading software, updates, and Kubernetes components.

## Getting Ready

Make sure to gather all the hardware components and install the necessary software tools before proceeding to the next
lesson. Having everything prepared will make the setup process smoother and allow you to focus on building your
Kubernetes cluster step-by-step.
