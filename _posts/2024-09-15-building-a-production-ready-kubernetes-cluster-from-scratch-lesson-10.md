---
layout: course-lesson
title: Preparing Nodes for Kubernetes Initialization (L10)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-10
---

In this lesson, we will prepare each Raspberry Pi node for Kubernetes
initialization. This involves ensuring that all nodes meet the necessary system
requirements and configurations to join the Kubernetes cluster. By the end of
this lesson, your nodes will be ready to initialize the control plane and join
additional worker nodes.

This is the tenth lesson in the series on building a production-ready Kubernetes
cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-9)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

**Updating System Settings for Kubernetes**

Before initializing the Kubernetes cluster, we need to adjust some system
settings to optimize the nodes for Kubernetes:

- Disable swap on each Raspberry Pi. Kubernetes requires swap to be disabled to
  function correctly:

  ```bash
  sudo swapoff -a
  ```

  To make this change permanent, open the `/etc/fstab` file and comment out any
  line that includes the word `swap`:

  ```bash
  sudo nano /etc/fstab
  ```

  Add a `#` at the beginning of the swap line, save the file, and exit.

- Ensure that all necessary kernel modules are loaded. Run the following
  commands to load the required modules:

  ```bash
  sudo modprobe overlay
  sudo modprobe br_netfilter
  ```

  To make these changes persistent, create a configuration file:

  ```bash
  sudo tee /etc/modules-load.d/k8s.conf <<EOF
  overlay
  br_netfilter
  EOF
  ```

- Adjust the sysctl settings for Kubernetes networking. Configure the necessary
  settings using:
  ```bash
  sudo tee /etc/sysctl.d/k8s.conf <<EOF
  net.bridge.bridge-nf-call-iptables  = 1
  net.ipv4.ip_forward                 = 1
  net.bridge.bridge-nf-call-ip6tables = 1
  EOF
  ```
  Apply the changes:
  ```bash
  sudo sysctl --system
  ```

**Synchronizing System Clocks**

- Install and configure `ntp` or `chrony` to ensure the system clocks are
  synchronized across all Raspberry Pi devices. Time synchronization is critical
  for Kubernetes operations:
  ```bash
  sudo apt install -y chrony
  sudo systemctl enable chrony
  sudo systemctl start chrony
  ```

**Configuring Firewall Rules**

If you are using `ufw` or another firewall, ensure that the necessary ports are
open for Kubernetes:

- Run the following commands to allow traffic on required ports:
  ```bash
  sudo ufw allow 6443/tcp
  sudo ufw allow 2379:2380/tcp
  sudo ufw allow 10250:10252/tcp
  sudo ufw allow 10255/tcp
  ```

**Verifying Node Preparation**

To ensure your nodes are ready for Kubernetes initialization:

- Verify that swap is disabled, the necessary kernel modules are loaded, sysctl
  settings are correctly applied, and system clocks are synchronized. Run the
  following command to check the system configuration:
  ```bash
  kubectl get nodes
  ```
  All nodes should be listed as "Ready."

## Lesson Conclusion

Congratulations! With the nodes properly configured and prepared, you are ready
to initialize the Kubernetes control plane. In the next lesson, we will guide
you through the process of setting up the first control plane node for your
cluster.

You have completed this lesson and you can now continue with
[the next section](/building-a-production-ready-kubernetes-cluster-from-scratch/section-4).
