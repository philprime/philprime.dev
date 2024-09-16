---
layout: post
title: Installing a Pod Network (CNI Plugin) (L13)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-13
---

In this lesson, we will install a Container Network Interface (CNI) plugin to
enable communication between the pods running on different nodes in your
Kubernetes cluster. The CNI plugin is essential for networking in Kubernetes, as
it ensures that all pods can communicate securely and efficiently across the
cluster.

This is the thirteenth lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-12)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## What is a CNI Plugin?

A **CNI (Container Network Interface) plugin** is a critical component in
Kubernetes that facilitates networking for containers running across multiple
nodes in a cluster. It provides the necessary networking capabilities to allow
pods (the smallest deployable units in Kubernetes) to communicate with each
other and with services both inside and outside the cluster. A CNI plugin works
by configuring the network interfaces of containers and managing the underlying
network policies, routes, and IP address assignments to ensure that all
containers can communicate seamlessly and securely.

## Why Choose Flannel as the CNI Plugin?

We chose **Flannel** as our CNI plugin for this course because it is
lightweight, simple to set up, and well-suited for use with resource-constrained
environments like Raspberry Pi devices. Flannel creates a virtual overlay
network that connects all pods across the cluster, ensuring that each pod gets a
unique IP address from a pre-defined CIDR range. This setup simplifies
networking by abstracting the complexities of the underlying network
infrastructure, making it easier to deploy and manage a Kubernetes cluster.
Flannel is also highly compatible with Kubernetes and requires minimal
configuration, which makes it an ideal choice for those who are new to
Kubernetes or working with smaller clusters.

## Setup

**Step 1: Choose a CNI Plugin**

- For this course, we will use the **Flannel** CNI plugin, a simple and widely
  used networking solution for Kubernetes. Flannel works well with the Raspberry
  Pi architecture and provides a stable network overlay for your cluster.
  Alternatively, you can use other CNI plugins like **Calico**, **Weave**, or
  **Cilium** depending on your needs, but for simplicity, we will proceed with
  Flannel.

**Step 2: Install the Flannel CNI Plugin**

- To install Flannel, run the following command on any of the control plane
  nodes:
  ```bash
  kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
  ```
  This command applies the Flannel configuration file to the cluster, setting up
  the network overlay.

**Step 3: Verify the CNI Plugin Installation**

- To confirm that Flannel is correctly installed, check the status of the pods
  in the `kube-system` namespace:
  ```bash
  kubectl get pods -n kube-system
  ```
  You should see several `kube-flannel-ds` pods, one for each node, with a
  status of "Running." This indicates that Flannel is successfully deployed and
  operating across all nodes.

**Step 4: Validate Pod Communication**

- To validate that the pod network is functioning correctly, deploy a test pod
  and check its connectivity to other pods in the cluster:
  ```bash
  kubectl run test-pod --image=busybox --command -- sleep 3600
  ```
  Once the pod is running, open a shell session inside it:
  ```bash
  kubectl exec -it test-pod -- sh
  ```
  From within the test pod, use the `ping` command to test connectivity to
  another pod or service in the cluster:
  ```bash
  ping <another-pod-ip>
  ```
  If the network is correctly configured, the ping should be successful,
  confirming that the pod network is operational.

**Step 5: Check the Pod Network CIDR**

- Ensure the pod network CIDR matches the one specified during control plane
  initialization (`10.244.0.0/16` for Flannel). You can check this by looking at
  the cluster configuration:
  ```bash
  kubectl cluster-info dump | grep -m 1 cluster-cidr
  ```
  The output should confirm the correct CIDR range.

## Lesson Conclusion

Congratulations! With the CNI plugin installed and verified, your Kubernetes
cluster is now ready to support communication between all pods across nodes. In
the next lesson, we will focus on setting up high availability for the control
plane to ensure that your cluster remains resilient and accessible.

You have completed this lesson and you can now continue with
[the next section](/building-a-production-ready-kubernetes-cluster-from-scratch/section-5).
