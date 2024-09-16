---
layout: post
title: Understanding High Availability and Kubernetes Basics (L4)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-4
---

In this lesson, you will unbox your Raspberry Pi devices and prepare them for
the cluster setup, and learn about the hardware components and their roles in
the Kubernetes cluster.

This is the fourth lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-3)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## What You Will Need for This Lesson

To get started, make sure you have the following components:

- At least three Raspberry Pi 4 devices, ideally with 4GB or 8GB of RAM.
- MicroSD cards (32GB or higher) for each Raspberry Pi, formatted and ready to
  be used.
- NVMe SSDs (512GB or higher) along with NVMe HATs for each Raspberry Pi.
- USB-C power supplies (5V/3A) for each Raspberry Pi.
- A gigabit Ethernet switch (e.g., TL-SG108) and a wired router (e.g., ER605).
- Ethernet cables (CAT5e or higher) to connect all devices.
- Heatsinks or cooling fans for the Raspberry Pi devices (optional but
  recommended).

## Unboxing the Raspberry Pi Devices

When you unbox each Raspberry Pi, make sure you have:

- The Raspberry Pi board itself.
- The protective case (if you’re using one).
- The microSD card that you will use for the operating system.
- The power supply and any necessary cables.
- The NVMe HATs and SSDs for storage.

Check that all components are in good condition and set aside any packaging
materials. Carefully handle the Raspberry Pi devices by the edges to avoid
touching the board’s components.

## Installing Heatsinks or Cooling Fans

If you have purchased heatsinks or cooling fans, now is the time to install
them.

- Attach the heatsinks to the appropriate chips on the Raspberry Pi board,
  following the instructions provided with the heatsinks. Make sure they are
  securely attached and cover the main chips, like the CPU and RAM.
- If using a cooling fan, attach it to the case or directly onto the Raspberry
  Pi board as per the manufacturer’s instructions. This will help keep the
  devices cool during operation, especially under heavy workloads.

## Preparing the NVMe SSDs and HATs

Next, you will need to set up the NVMe SSDs for persistent storage.

- Insert each NVMe SSD into the corresponding NVMe HAT.
- Attach the NVMe HAT to each Raspberry Pi. Ensure the connection is secure and
  that the SSD is correctly seated.
- Place the assembled Raspberry Pi, with the SSD and HAT, into the protective
  case, ensuring that all components fit properly and are securely positioned.

## Connecting the Raspberry Pi Devices

Once you have assembled your Raspberry Pi devices with their cases, NVMe SSDs,
and cooling solutions:

- Connect each Raspberry Pi to the gigabit Ethernet switch using an Ethernet
  cable. Make sure each device is connected to a different port on the switch.
- Plug in the USB-C power supply to each Raspberry Pi and connect it to a power
  outlet.
- Ensure all devices are powered on and that the LEDs on the Raspberry Pi boards
  are lit, indicating they are receiving power.

## Verifying the Hardware Setup

After everything is connected and powered on, perform a quick check:

- Ensure all Raspberry Pi devices have power and are properly connected to the
  switch.
- Double-check that the cooling solutions (heatsinks or fans) are properly
  installed and functioning.
- Verify that the NVMe SSDs are securely attached and recognized by each
  Raspberry Pi device (we will confirm this again later during the OS setup).

## Lesson Conclusion

Congratulations! You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-5).
