---
layout: course-lesson
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

In this lesson, we will install the essential Kubernetes tools required to set
up and manage your cluster: `kubectl`, `kubeadm`, and `kubelet`. These tools
will allow you to initialize the control plane, manage nodes, and control your
cluster.

> [!WARNING] We are not using the latest version of Kubernetes tools in this
> lesson, so we will be able to upgrade them in lesson 30.

## Installing Kubernetes Tools on Each Raspberry Pi

The Kubernetes tools are essential for managing your cluster and interacting
with the Kubernetes API. To install these tools on your Raspberry Pi devices,
follow these steps (or follow the
[documentation](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-using-native-package-management)):

1.  Update the apt package index and install packages needed to use the
    Kubernetes apt repository:

    ```bash
    $ sudo apt update
    $ sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
    ```

2.  Download the public signing key for the Kubernetes package repositories. The
    same signing key is used for all repositories so you can disregard the
    version in the URL:

    ```bash
    $ sudo mkdir -p -m 755 /etc/apt/keyrings
    $ curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    # allow unprivileged APT programs to read this keyring
    $ sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    ```

3.  Add the appropriate Kubernetes apt repository. We will install version 1.31,
    which is not the latest version at the time of this writing, allow us to
    upgrade it later on:

    ```bash
    $ echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    # helps tools such as command-not-found to work correctly
    $ sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list
    ```

4.  Update apt package index, then install `kubeadm`, `kubectl`, and `kubelet`:

    ```bash
    $ sudo apt update
    $ sudo apt install -y kubelet kubeadm kubectl
    ```

5.  Holding these packages ensures they will not be automatically updated, which
    helps maintain cluster stability.

    ```bash
    $ sudo apt-mark hold kubelet kubeadm kubectl
    ```

## Verifying the Installation

To confirm that the Kubernetes tools have been successfully installed:

- Check the versions of the installed tools by running:
  ```bash
  $ kubectl version --client
  $ kubeadm version
  $ kubelet --version
  ```
  Ensure that each command returns a version number, indicating the tools are
  correctly installed.

## Configuring Kubernetes Tools

- Ensure that `kubelet` is enabled to start on boot and is running:

  ```bash
  $ sudo systemctl enable kubelet
  $ sudo systemctl start kubelet
  ```

## Lesson Conclusion

Congratulations! With the Kubernetes tools installed and configured, your
Raspberry Pi devices are now ready to initialize the cluster. In the next
lesson, we will set up a container runtime like container.d or Docker, which is
necessary to run containers on your cluster.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-9).
