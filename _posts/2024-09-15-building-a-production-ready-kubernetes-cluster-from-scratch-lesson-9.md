---
layout: course-lesson
title: Setting Up Docker or Container Runtime (L9)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-9
---

In this lesson, we will set up **containerd** as the container runtime on each
Raspberry Pi device. Containerd is a lightweight and efficient container runtime
that is widely used in Kubernetes environments due to its simplicity and
compatibility with Kubernetes' container runtime interface (CRI).

This is the ninth lesson in the series on building a production-ready Kubernetes
cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-8)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

**Installing containerd on Each Raspberry Pi**

To begin, make sure you are connected to each Raspberry Pi via SSH. Perform the
following steps on each device:

- Update the package list and install required dependencies:

  ```bash
  sudo apt update
  sudo apt install -y apt-transport-https curl gnupg2 software-properties-common
  ```

- Install containerd:
  ```bash
  sudo apt install -y containerd
  ```

**Configuring containerd for Kubernetes**

Once containerd is installed, it needs to be configured properly to work with
Kubernetes:

- Create a default configuration file for containerd:

  ```bash
  sudo mkdir -p /etc/containerd
  sudo containerd config default | sudo tee /etc/containerd/config.toml
  ```

- Open the configuration file with a text editor like `nano` to modify the
  cgroup driver:

  ```bash
  sudo nano /etc/containerd/config.toml
  ```

  Find the line that specifies the `SystemdCgroup` setting (typically under the
  `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]`
  section) and set it to `true`:

  ```toml
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
  ```

- Save the changes and exit the editor.

- Restart containerd to apply the configuration:

  ```bash
  sudo systemctl restart containerd
  ```

- Enable containerd to start on boot:
  ```bash
  sudo systemctl enable containerd
  ```

**Verifying containerd Installation**

To confirm that containerd is correctly installed and configured:

- Check the status of containerd to ensure it is running:

  ```bash
  sudo systemctl status containerd
  ```

  The output should show that containerd is active and running.

- Verify the cgroup driver configuration:
  ```bash
  crictl info | grep "cgroupDriver"
  ```
  Ensure that the output shows `"cgroupDriver": "systemd"`.

**Next Step: Moving Forward**

## Lesson Conclusion

Congratulations! With containerd installed and configured, your Raspberry Pi
devices are now ready to run containers as part of the Kubernetes cluster. Next,
we will prepare the nodes for Kubernetes initialization by ensuring they meet
all requirements and are correctly configured.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-9).
