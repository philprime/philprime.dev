---
layout: course-lesson
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
  within your local network range (e.g., `10.1.1.1`, `10.1.2.1`, etc.), as
  configured in Lesson 5. Ensure these IP addresses are also reserved in your
  router's DHCP settings to prevent IP conflicts.

- SSH into each Raspberry Pi and use the `ping` command to test communication
  with the other Raspberry Pi devices. For example:
  ```bash
  $ ping 10.1.1.1
  $ ssh pi@10.1.1.1
  ```

## Configuring Additional Network Security

Install and enable `ufw` (Uncomplicated Firewall) to control incoming and
outgoing traffic on each Raspberry Pi:

```bash
$ sudo apt install ufw
$ sudo ufw allow ssh
$ sudo ufw enable
```

When enabling `ufw`, you may be prompted to allow or deny certain services.
Ensure that you allow SSH access to prevent being locked out of your devices.

## Lesson Conclusion

Congratulations! With your network configuration complete, your Raspberry Pi
devices are now ready to communicate effectively within your Kubernetes cluster.
Next, we will prepare the environment for Kubernetes by installing essential
tools and setting up the container runtime.

You have completed this lesson and you can now continue with
[the next section](/building-a-production-ready-kubernetes-cluster-from-scratch/section-3).
