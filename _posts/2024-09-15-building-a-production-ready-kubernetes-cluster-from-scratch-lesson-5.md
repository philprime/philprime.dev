---
layout: course-lesson
title: Flashing Raspberry Pi OS and Initial Configuration (L5)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-5
---

In this lesson, you will follow a step-by-step guide to install Raspberry Pi OS
on your devices, configure essential settings, and prepare them for networking.

This is the fifth lesson in the series on building a production-ready Kubernetes
cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-4)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

Now that your Raspberry Pi devices are unboxed, assembled, and connected, it's
time to install the operating system. In this lesson, we’ll walk through the
process of flashing Raspberry Pi OS onto your microSD cards and performing the
initial configuration needed to prepare your devices for the Kubernetes cluster.

## Preparing the MicroSD Cards

To begin, you need to prepare the microSD cards that will host the Raspberry Pi
OS:

- Insert each microSD card into your computer using a card reader.
- Download the latest version of **Raspberry Pi OS Lite** (without a desktop
  environment) from the
  [official Raspberry Pi website](https://www.raspberrypi.org/software/).
- Use a tool like **Raspberry Pi Imager**, **balenaEtcher**, or **Rufus** to
  flash the Raspberry Pi OS image onto each microSD card. Select the Raspberry
  Pi OS Lite image you downloaded and choose the target microSD card.
- Follow the instructions provided by the tool to complete the flashing process.
  Once done, safely eject the microSD cards from your computer.

## Enabling SSH for Headless Setup

To enable SSH access without connecting a monitor and keyboard:

- Insert each microSD card back into your computer.
- Open the boot partition on the microSD card, which should be accessible once
  the OS is flashed.
- Create a new empty file named `ssh` (without any file extension) in the boot
  partition. This will enable SSH by default when the Raspberry Pi boots up.
- Safely eject the microSD cards from your computer.

## Initial Raspberry Pi Configuration

Insert the prepared microSD cards into each Raspberry Pi:

- Power on each Raspberry Pi by connecting it to a power outlet.
- Use an SSH client (like OpenSSH or PuTTY) on your main computer to connect to
  each Raspberry Pi device. You can find the IP address of each Raspberry Pi by
  checking your router’s DHCP lease table or using a network scanner tool.
- SSH into each Raspberry Pi using the default username `pi` and password
  `raspberry`. It’s a good practice to change this default password immediately
  after logging in:
  ```bash
  passwd
  ```
- Set a unique hostname for each Raspberry Pi to easily identify them in your
  network. For example:
  ```bash
  sudo hostnamectl set-hostname kubernetes-node-1
  ```
  Replace `kubernetes-node-1` with a unique name for each device.

## Updating and Upgrading the System

Once logged in, update and upgrade the Raspberry Pi OS packages to ensure all
components are up-to-date:

- Run the following commands to update the package list and upgrade installed
  packages:
  ```bash
  sudo apt update
  sudo apt upgrade -y
  ```
- Reboot the Raspberry Pi devices after the upgrade process is complete:
  ```bash
  sudo reboot
  ```

## Configuring Static IP Addresses

To ensure each Raspberry Pi device has a consistent IP address:

- Open the DHCP client configuration file with the following command:
  ```bash
  sudo nano /etc/dhcpcd.conf
  ```
- Add the following lines to configure a static IP address:
  ```bash
  interface eth0
  static ip_address=192.168.1.x/24
  static routers=192.168.1.1
  static domain_name_servers=192.168.1.1
  ```
  Replace `192.168.1.x` with a unique IP for each Raspberry Pi device, and
  adjust the gateway and DNS server as needed.
- Save the file and exit, then restart the DHCP service:
  ```bash
  sudo systemctl restart dhcpcd
  ```

## Verifying Connectivity

To verify that each Raspberry Pi is correctly configured and accessible:

- Ping each Raspberry Pi from your main computer or from one Raspberry Pi to
  another to ensure network connectivity:
  ```bash
  ping 192.168.1.x
  ```
  Replace `192.168.1.x` with the IP address of the target Raspberry Pi.

If all devices respond successfully, your network configuration is correct, and
your Raspberry Pi devices are ready for the next steps.

## Lesson Conclusion

Congratulations! With the operating system flashed and the initial configuration
complete, you are now ready to set up the NVMe SSDs for persistent storage. You
have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-6).
