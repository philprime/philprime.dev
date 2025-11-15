---
layout: guide-lesson.liquid
title: Tools and Equipment Needed

guide_component: lesson
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
guide_section_id: 1
guide_lesson_id: 2
guide_lesson_abstract: >
  Discover the hardware and software requirements for building your Kubernetes cluster. Learn about the specific tools
  and equipment you’ll need to follow along with the guide.
repo_file_path: guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-2.md
---

{% include assign-guide.liquid.html %}

In this lesson, you will discover the hardware and software requirements for building your Kubernetes cluster, and learn
about the specific tools and equipment you’ll need to follow along with the guide.

{% include guide-overview-link.liquid.html %}

Before we start building our Kubernetes cluster, it’s important to gather all the necessary tools and equipment. In this
lesson, we’ll go over everything you need to follow along with this guide, from hardware components to essential
software tools.

## Hardware Requirements

To set up your Kubernetes cluster, you will need several hardware components:

- You will need at least three Raspberry Pi 5 devices, ideally with 8GB of RAM for better performance.
- Each Raspberry Pi requires a 64GB (or higher) microSD card, with high-endurance cards recommended for reliability.
- For persistent storage, you will need 500GB NVMe SSDs along with compatible NVMe HATs for each Raspberry Pi. Make sure
  the lengths of the SSDs are supported by the HATs.
- Each device also requires a 5V/5A USB-C power supply to ensure stable operation.
- To connect all Raspberry Pi devices, you will need a gigabit wired router like the TP-LINK ER605 (or any other
  networking router) to create a local network for your cluster.
- You should have CAT5e or higher Ethernet cables available to connect the Raspberry Pi devices to the router.

![Hardware Overview](/assets/guides/building-a-production-ready-kubernetes-cluster-from-scratch/hardware-overview.webp)

### Exact Hardware List

The following is the exact list of hardware components used in this guide:

**Raspberry Pi 5:**

- Raspberry Pi 5 (8GB RAM)
- 64-bit quad-core Cortex-A76 processor
- 8GB LPDDR4X SDRAM
- Gigiabit Ethernet port
- 5V/5A USB-C power supply recommended, 5V/3A minimum requirement

![Raspberry Pi 5](/assets/guides/building-a-production-ready-kubernetes-cluster-from-scratch/raspberry-pi.webp)

**Power Supply:**

- Official Raspberry Pi USB-C Power Supply 27W
- Provides 5.1V, 5.0A DC output

![Power Supply](/assets/guides/building-a-production-ready-kubernetes-cluster-from-scratch/power-supply.webp)

**MicroSD Card:**

- 64GB High-Speed MicroSD Card
- SanDisk Extreme microSDXC UHS-I Card with Adapter

![MicroSD Card](/assets/guides/building-a-production-ready-kubernetes-cluster-from-scratch/microsd-card.webp)

{% include alert.liquid.html type='warning' title='WARNING:' content='

<p>In previous versions of this guide, I recommended using a 64GB microSD card from a no-name brand. However, I recently had disk corruption with the cards and decided to switch to a SanDisk Extreme microSDXC UHS-I Card with Adapter.</p>
  <p>I highly recommend using a reputable brand for your microSD cards to avoid any potential issues.</p>
  <p>In a future extension of this guide, we will cover installing the OS on the NVMe SSDs instead of the microSD cards.</p>
' %}

**Raspberry PI NVMe HAT:**

- Pimoroni - PIM699
- Supports M.2 NVMe SSDs
- Supports 2280, 2260, 2242, and 2230 form factors

![NVMe HAT](/assets/guides/building-a-production-ready-kubernetes-cluster-from-scratch/nvme-hat.webp)

**NVMe SSD:**

- Kingston SNV3S/500G
- 500GB PCIe 4.0 NVMe M.2

![NVMe SSD](/assets/guides/building-a-production-ready-kubernetes-cluster-from-scratch/nvme-ssd.webp)

**Router:**

- TP-LINK ER605
- Gigabit Wired Router
- 4x Gigabit LAN Ports / 1x Gigabit WAN Port

![Router](/assets/guides/building-a-production-ready-kubernetes-cluster-from-scratch/router.webp)

**Ethernet Cable:**

- CAT6 Ethernet Cable
- Length: 0.15m

![Ethernet Cable](/assets/guides/building-a-production-ready-kubernetes-cluster-from-scratch/ethernet-cables.webp)

## Software Requirements

You will also need several software tools to complete this guide:

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
