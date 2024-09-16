---
layout: post
title: Installing Kubernetes Tools (kubectl, kubeadm, kubelet) (L8)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-8
---

In this lesson, you will learn how to install and configure essential Kubernetes
tools on your Raspberry Pi devices to prepare them for cluster initialization.

This is the eighth lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-7)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

---

we are not using the latest version, because in lesson 30 we will upgrade it.

Here is the content for Lesson 8: Installing Kubernetes Tools (kubectl, kubeadm,
kubelet) formatted as requested:

---

### Section 3, Lesson 8: Installing Kubernetes Tools (kubectl, kubeadm, kubelet)

In this lesson, we will install the essential Kubernetes tools required to set
up and manage your cluster: `kubectl`, `kubeadm`, and `kubelet`. These tools
will allow you to initialize the control plane, manage nodes, and control your
cluster.

**Installing Kubernetes Tools on Each Raspberry Pi**

First, ensure that each Raspberry Pi is connected to the network and accessible
via SSH. You will need to perform the following steps on each device:

- Update the package list and install dependencies needed for Kubernetes tools:

  ```bash
  sudo apt update
  sudo apt install -y apt-transport-https curl
  ```

- Add the Kubernetes APT repository to your Raspberry Pi devices:

  ```bash
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
  ```

- Install `kubeadm`, `kubectl`, and `kubelet`:
  ```bash
  sudo apt update
  sudo apt install -y kubelet kubeadm kubectl
  sudo apt-mark hold kubelet kubeadm kubectl
  ```
  Holding these packages ensures they will not be automatically updated, which
  helps maintain cluster stability.

**Verifying the Installation**

To confirm that the Kubernetes tools have been successfully installed:

- Check the versions of the installed tools by running:
  ```bash
  kubectl version --client && kubeadm version && kubelet --version
  ```
  Ensure that each command returns a version number, indicating the tools are
  correctly installed.

**Configuring Kubernetes Tools**

- Ensure that `kubelet` is enabled to start on boot and is running:

  ```bash
  sudo systemctl enable kubelet
  sudo systemctl start kubelet
  ```

- Repeat these steps on all Raspberry Pi devices to ensure all nodes are
  prepared for the Kubernetes cluster setup.

**Next Step: Moving Forward**

## Lesson Conclusion

Congratulations! With the Kubernetes tools installed and configured, your
Raspberry Pi devices are now ready to initialize the cluster. In the next
lesson, we will set up a container runtime like Docker, which is necessary to
run containers on your cluster.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-9).
