---
layout: post
title: Joining Additional Control Plane Nodes (L12)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-12
---

In this lesson, we will join additional Raspberry Pi devices as control plane
nodes to create a high-availability Kubernetes cluster. Adding more control
plane nodes ensures that your cluster remains resilient and operational, even if
one of the nodes fails.

This is the twelfth lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-11)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## Joining Additional Control Plane Nodes

**Step 1: SSH into the Additional Control Plane Nodes**

- SSH into each Raspberry Pi device that you want to join as an additional
  control plane node. Ensure these nodes have been prepared as outlined in the
  previous lessons and have `kubeadm`, `kubectl`, `kubelet`, and `containerd`
  installed and configured.

**Step 2: Use the kubeadm Join Command**

- On each additional control plane node, use the `kubeadm join` command that you
  saved from the initialization of the first control plane node. The command
  should look similar to this:

  ```bash
  sudo kubeadm join <your-control-plane-ip>:6443 --token <your-token> --discovery-token-ca-cert-hash sha256:<your-hash> --control-plane --certificate-key <your-certificate-key>
  ```

  Replace `<your-control-plane-ip>`, `<your-token>`, `<your-hash>`, and
  `<your-certificate-key>` with the actual values from the output of the
  `kubeadm init` command.

- This command will connect the additional control plane nodes to the existing
  cluster and synchronize the necessary control plane components.

**Step 3: Verify the Nodes Have Joined the Cluster**

- After executing the join command on each additional control plane node, return
  to your first control plane node and run:
  ```bash
  kubectl get nodes
  ```
  You should see all the nodes listed with a status of "Ready," indicating that
  the additional control plane nodes have successfully joined the cluster.

**Step 4: Verify Control Plane High Availability**

- To ensure high availability, check that all control plane components are
  running correctly on each node:
  ```bash
  kubectl get pods -n kube-system -o wide
  ```
  You should see the control plane components (like `kube-apiserver`,
  `kube-scheduler`, and `kube-controller-manager`) distributed across all
  control plane nodes.

**Step 5: Distribute the etcd Cluster**

- Verify that the `etcd` cluster is also running across all control plane nodes:
  ```bash
  kubectl get pods -n kube-system -l component=etcd -o wide
  ```
  You should see one `etcd` pod per control plane node, confirming that the
  `etcd` cluster is distributed and redundant.

## Lesson Conclusion

Congratulations! With all control plane nodes successfully joined and the
high-availability configuration verified, your Kubernetes cluster is now more
resilient and can withstand node failures. In the next lesson, we will install a
pod network (CNI plugin) to enable communication between all pods within the
cluster.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-12).
