---
layout: course-lesson
title: Initializing the First Control Plane Node (L11)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-11
---

In this lesson, we will initialize the first control plane node for your
Kubernetes cluster. The control plane is responsible for managing the state of
the cluster, and setting it up correctly is crucial for the operation of your
cluster.

This is the eleventh lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-10)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

**Step 1: Initialize the Control Plane**

- SSH into the Raspberry Pi that you want to designate as the first control
  plane node.
- Run the following `kubeadm` command to initialize the control plane. This
  command sets up the Kubernetes control plane components, such as the API
  server, controller manager, and scheduler:

  ```bash
  sudo kubeadm init --pod-network-cidr=10.244.0.0/16
  ```

  The `--pod-network-cidr` flag specifies the CIDR for the pod network. In this
  example, we use `10.244.0.0/16` for compatibility with the Flannel CNI plugin,
  which we will install later.

- Once the initialization is complete, you will see a message displaying a
  `kubeadm join` command. This command is crucial for joining additional nodes
  to the cluster. Copy and save it somewhere safe, as you will need it in the
  next lesson.

**Step 2: Set Up kubectl for the Local User**

- To manage the cluster from your control plane node, you need to set up
  `kubectl` for the local user:
  ```bash
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  ```
  This command copies the Kubernetes configuration file to the local user's home
  directory, allowing you to use `kubectl` commands to interact with the
  cluster.

**Step 3: Verify the Control Plane Setup**

- Run the following command to check the status of the nodes:
  ```bash
  kubectl get nodes
  ```
  The output should show the control plane node with a status of "Ready." This
  indicates that the control plane is initialized correctly.

**Step 4: Allow Scheduling on the Control Plane Node (Optional)**

- By default, the control plane node is tainted to prevent workloads from being
  scheduled on it. If you want to allow scheduling on the control plane node
  (not recommended for production environments), you can remove the taint with:
  ```bash
  kubectl taint nodes --all node-role.kubernetes.io/control-plane-
  ```

## Lesson Conclusion

Congratulations! With the control plane initialized, your first node is now set
up to manage your Kubernetes cluster. In the next lesson, we will learn how to
join additional Raspberry Pi devices as control plane or worker nodes to create
a highly available cluster.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-12).
