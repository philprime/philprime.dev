---
layout: guide-lesson.liquid
title: Installing Kubernetes Tools (kubectl, kubeadm, kubelet)

guide_component: lesson
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
guide_section_id: 3
guide_lesson_id: 8
guide_lesson_abstract: >
  Install and configure essential Kubernetes tools on your Raspberry Pi devices to prepare them for cluster
  initialization.
guide_lesson_conclusion: >
  With the Kubernetes tools installed and configured, your Raspberry Pi devices are now ready to initialize the cluster
repo_file_path: guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-8.md
---

In this lesson, you will learn how to install and configure essential Kubernetes tools on your Raspberry Pi devices to
prepare them for cluster initialization.

{% include guide-overview-link.liquid.html %}

In this lesson, we will install the essential Kubernetes tools required to set up and manage your cluster: `kubectl`,
`kubeadm`, and `kubelet`. These tools will allow you to initialize the control plane, manage nodes, and control your
cluster.

{% include alert.liquid.html type='warning' title='WARNING:' content='
We are not using the latest version of Kubernetes tools in this lesson, so we will be able to upgrade them in lesson 30.
' %}

{% include alert.liquid.html type='warning' title='WARNING:' content='
All commands used in this lesson require <code>sudo</code> privileges.
Either prepend <code>sudo</code> to each command or switch to the root user using <code>sudo -i</code>.
' %}

## Update the System

Before installing the Kubernetes tools, ensure your Raspberry Pi devices are up to date by running the following
commands:

```bash
# Update the package list
$ apt update
# Upgrade the installed packages
$ apt upgrade
```

## Installing Kubernetes Tools on Each Raspberry Pi

The Kubernetes tools are essential for managing your cluster and interacting with the Kubernetes API. To install these
tools on your Raspberry Pi devices, follow these steps (or the
[documentation](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-using-native-package-management)):

1.  Install dependencies required for the Kubernetes apt repository:

    ```bash
    $ apt install -y apt-transport-https ca-certificates curl gnupg
    ```

2.  Download the public signing key for the Kubernetes package repositories. The same signing key is used for all
    repositories so you can disregard the version in the URL:

    ```bash
    $ mkdir -p -m 755 /etc/apt/keyrings
    $ curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    # allow unprivileged APT programs to read this keyring
    $ chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    ```

3.  Add the appropriate Kubernetes apt repository. We will install version 1.31, which is not the latest version at the
    time of this writing, allow us to upgrade it later on:

    ```bash
    $ echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' >> /etc/apt/sources.list.d/kubernetes.list
    $ chmod 644 /etc/apt/sources.list.d/kubernetes.list
    ```

4.  Update apt package index, then install `kubeadm`, `kubectl`, and `kubelet`:

    ```bash
    $ apt update
    Hit:1 http://deb.debian.org/debian bookworm InRelease
    Hit:2 http://deb.debian.org/debian-security bookworm-security InRelease
    Hit:3 http://deb.debian.org/debian bookworm-updates InRelease
    Hit:4 http://archive.raspberrypi.com/debian bookworm InRelease
    Get:5 https://prod-cdn.packages.k8s.io/repositories/isv:/kubernetes:/core:/stable:/v1.31/deb  InRelease [1,186 B]
    Get:6 https://prod-cdn.packages.k8s.io/repositories/isv:/kubernetes:/core:/stable:/v1.31/deb  Packages [9,749 B]
    Fetched 10.9 kB in 1s (21.1 kB/s)
    Reading package lists... Done
    Building dependency tree... Done
    Reading state information... Done
    All packages are up to date.

    $ apt install -y kubelet kubeadm kubectl
    Reading package lists... Done
    Building dependency tree... Done
    Reading state information... Done
    The following additional packages will be installed:
      conntrack cri-tools kubernetes-cni
    The following NEW packages will be installed:
      conntrack cri-tools kubeadm kubectl kubelet kubernetes-cni
    ...
    ```

5.  Holding these packages ensures they will not be automatically updated, which helps maintain cluster stability.

    ```bash
    $ apt-mark hold kubelet kubeadm kubectl
    kubelet set on hold.
    kubeadm set on hold.
    kubectl set on hold.
    ```

## Verifying the Installation

To confirm that the Kubernetes tools have been successfully installed:

- Check the versions of the installed tools by running:
  ```bash
  $ kubectl version --client
  Client Version: v1.31.6
  Kustomize Version: v5.4.2
  $ kubeadm version
  kubeadm version: &version.Info{Major:"1", Minor:"31", GitVersion:"v1.31.6", GitCommit:"6b3560758b37680cb713dfc71da03c04cadd657c", GitTreeState:"clean", BuildDate:"2025-02-12T21:31:09Z", GoVersion:"go1.22.12", Compiler:"gc", Platform:"linux/arm64"}
  $ kubelet --version
  Kubernetes v1.31.6
  ```
  Ensure that each command returns a version number, indicating the tools are correctly installed.

## Configuring Kubernetes Tools

Ensure that `kubelet` is enabled to start on boot and is running:

```bash
$ systemctl enable kubelet
$ systemctl start kubelet
```

We can see the status of the service by using `systemctl` and `journalctl`:

```bash
$ systemctl status kubelet
● kubelet.service - kubelet: The Kubernetes Node Agent
     Loaded: loaded (/lib/systemd/system/kubelet.service; enabled; preset: enabled)
    Drop-In: /usr/lib/systemd/system/kubelet.service.d
             └─10-kubeadm.conf
     Active: activating (auto-restart) (Result: exit-code) since Fri 2025-01-17 16:19:50 CET; 5s ago
       Docs: https://kubernetes.io/docs/
    Process: 18044 ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS (code=exited, status=1/FAILURE)
   Main PID: 18044 (code=exited, status=1/FAILURE)
        CPU: 66ms
```

```bash
$ journalctl -u kubelet.service
Jan 17 16:14:53 kubernetes-node-1 systemd[1]: Started kubelet.service - kubelet: The Kubernetes Node Agent.
Jan 17 16:14:53 kubernetes-node-1 kubelet[17651]: E0117 16:14:53.701110   17651 run.go:72] "command failed" err="failed to load kubelet config file, path: /var/lib/kubelet/config.yaml, error: failed to load Kubelet config file /var/lib/kubelet/config.yaml, error failed to read kubelet config file \"/var/lib/kubelet/config.yaml\", error: open /var/lib/kubelet/co>
Jan 17 16:14:53 kubernetes-node-1 systemd[1]: kubelet.service: Main process exited, code=exited, status=1/FAILURE
Jan 17 16:14:53 kubernetes-node-1 systemd[1]: kubelet.service: Failed with result 'exit-code'.
Jan 17 16:15:03 kubernetes-node-1 systemd[1]: kubelet.service: Scheduled restart job, restart counter is at 1.
Jan 17 16:15:03 kubernetes-node-1 systemd[1]: Stopped kubelet.service - kubelet: The Kubernetes Node Agent.
Jan 17 16:15:03 kubernetes-node-1 systemd[1]: Started kubelet.service - kubelet: The Kubernetes Node Agent.
Jan 17 16:15:03 kubernetes-node-1 kubelet[17660]: E0117 16:15:03.937337   17660 run.go:72] "command failed" err="failed to load kubelet config file, path: /var/lib/kubelet/config.yaml, error: failed to load Kubelet config file /var/lib/kubelet/config.yaml, error failed to read kubelet config file \"/var/lib/kubelet/config.yaml\", error: open /var/lib/kubelet/co>
Jan 17 16:15:03 kubernetes-node-1 systemd[1]: kubelet.service: Main process exited, code=exited, status=1/FAILURE
```

As you can see the service is not running correctly, because we have not yet set up a Kubernetes cluster. We will do
that in an upcoming lesson and you can safely ignore the errors for now.

## Installing k9s (Optional)

k9s offers a terminal-based UI for interacting with your Kubernetes clusters and is available for free on
[GitHub](https://github.com/derailed/k9s). This tool simplifies the navigation, observation, and management of your
applications in the terminal. It continuously monitors Kubernetes for changes and provides commands to interact with the
observed resources.

To install k9s on your Raspberry Pi devices, we will add the k9s Debian repository to your system:

```bash
$ wget https://github.com/derailed/k9s/releases/download/v0.32.7/k9s_linux_arm64.deb -O /tmp/k9s_linux_arm64.deb
```

{% include alert.liquid.html type='note' title='NOTE:' content='
Replace `v0.32.7` with the latest version available on the
<a href="https://github.com/derailed/k9s/releases" target="_blank">k9s GitHub releases page</a>.
' %}

{% include alert.liquid.html type='note' title='NOTE:' content='
We are downloading the ARM64 version of k9s because we are using Raspberry Pi devices.
If you are using a different architecture, download the appropriate version.
' %}

Install the k9s package: Install the k9s package:

```bash
$ dpkg -i /tmp/k9s_linux_arm64.deb

Selecting previously unselected package k9s.
(Reading database ... 78776 files and directories currently installed.)
Preparing to unpack /tmp/k9s_linux_arm64.deb ...
Unpacking k9s (0.32.7) ...
Setting up k9s (0.32.7) ...
```

Run k9s to verify the installation:

```bash
$ k9s version

 ____  __.________
|    |/ _/   __   \______
|      < \____    /  ___/
|    |  \   /    /\___ \
|____|__ \ /____//____  >
        \/            \/

Version:    v0.32.7
Commit:     6b5d24f5741a1789fb97ba3e11f0ee868d93459d
Date:       2024-11-16T20:22:28Z
root@kubernetes-node-2:~#
```

{% include alert.liquid.html type='note' title='NOTE:' content='
We are downloading the debian package to the <code>/tmp</code> directory, so it gets removed
automatically by the system after a reboot. We do not need to keep the package after installation.
' %}
