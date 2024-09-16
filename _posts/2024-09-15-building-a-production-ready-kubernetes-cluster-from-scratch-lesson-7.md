---
layout: post
title: Networking Setup and Configuration (L7)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-7
---

In this lesson, we will set up the network configuration for your Raspberry Pi
Kubernetes cluster. Proper network setup is essential to ensure that all devices
can communicate effectively and reliably, allowing your Kubernetes cluster to
function as intended.

This is the seventh lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-6)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## Configuring the Network for Your Cluster

To ensure your Raspberry Pi devices are properly connected, follow these steps:

- Verify that all Raspberry Pi devices are connected to your gigabit Ethernet
  switch using CAT5e or higher Ethernet cables. The switch should be connected
  to your router to provide internet access to each Raspberry Pi.

- Double-check that each Raspberry Pi device has a unique static IP address
  within your local network range (e.g., `192.168.1.10`, `192.168.1.11`, etc.),
  as configured in Lesson 5. Ensure these IP addresses are also reserved in your
  router's DHCP settings to prevent IP conflicts.

- SSH into each Raspberry Pi and use the `ping` command to test communication
  with the other Raspberry Pi devices. For example:
  ```bash
  ping 192.168.1.11
  ping 192.168.1.12
  ```

Make sure each device can successfully ping the others. If any device fails to
ping, check the Ethernet connections and network settings.

- Edit the `/etc/hosts` file on each Raspberry Pi to set up hostname resolution,
  which simplifies communication between devices. Open the file with:

  ```bash
  sudo nano /etc/hosts
  ```

  Add the IP addresses and hostnames of all Raspberry Pi devices in your
  cluster:

  ```plaintext
  192.168.1.10  kubernetes-node-1
  192.168.1.11  kubernetes-node-2
  192.168.1.12  kubernetes-node-3
  ```

  Save and close the file. This allows you to reference the nodes by hostname
  instead of IP address.

- Set up SSH key-based authentication to allow passwordless access between
  Raspberry Pi devices. Generate an SSH key pair on your main computer if you
  haven’t already:
  ```bash
  ssh-keygen -t rsa
  ```
  Copy the public key to each Raspberry Pi:
  ```bash
  ssh-copy-id pi@192.168.1.10
  ssh-copy-id pi@192.168.1.11
  ssh-copy-id pi@192.168.1.12
  ```
  This enables you to SSH into each device without needing to enter a password.

## Verifying the Network Configuration

To ensure your network setup is complete and functional, test SSH access to each
Raspberry Pi using its hostname:

```bash
ssh pi@kubernetes-node-1
ssh pi@kubernetes-node-2
ssh pi@kubernetes-node-3
```

Make sure you can log in without entering a password, and check that each device
can communicate with the others using both IP addresses and hostnames.

## Configuring Additional Network Security (Optional)

Consider configuring additional network settings to enhance security:

- Install and enable `ufw` (Uncomplicated Firewall) to control incoming and
  outgoing traffic on each Raspberry Pi:

  ```bash
  sudo apt install ufw
  sudo ufw allow ssh
  sudo ufw enable
  ```

- Ensure that only necessary services are running on each Raspberry Pi and
  disable any unused services to reduce potential attack surfaces.

## Lesson Conclusion

Congratulations! With your network configuration complete, your Raspberry Pi
devices are now ready to communicate effectively within your Kubernetes cluster.
Next, we will prepare the environment for Kubernetes by installing essential
tools and setting up the container runtime.

You have completed this lesson and you can now continue with
[the next section](/building-a-production-ready-kubernetes-cluster-from-scratch/section-3).
