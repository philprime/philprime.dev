---
layout: post
title: Installing Longhorn for Distributed Block Storage (L17)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-17
---

In this lesson, we will install and configure **Longhorn**, a lightweight and
reliable distributed block storage solution for your Kubernetes cluster.
Longhorn provides persistent storage for applications running in your cluster,
enabling you to create, manage, and scale persistent volumes across multiple
nodes.

This is the seventeenth lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-16)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## What is Longhorn?

Longhorn is an open-source, cloud-native block storage solution for Kubernetes.
It provides a simple, reliable, and easy-to-deploy option for managing
persistent volumes. Longhorn creates a highly available, replicated storage
system within your Kubernetes cluster, ensuring data redundancy and fault
tolerance. It also offers features like incremental backups, snapshots, and
disaster recovery, making it ideal for production workloads.

## Installing Longhorn in Your Kubernetes Cluster

1. **Prepare Your Cluster for Longhorn Installation:**

   Before installing Longhorn, ensure your cluster meets the following
   prerequisites:

   - Each node in your cluster should have direct access to the storage disks
     (in this case, the NVMe SSDs configured earlier).
   - Kubernetes version 1.16 or later is required.
   - Make sure you have sufficient disk space available on each node for storing
     data and replicas.

2. **Install Longhorn Using kubectl:**

   To install Longhorn, you will use the official Longhorn manifests. Run the
   following command on any control plane node:

   ```bash
   kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml
   ```

   This command will deploy Longhorn components, including the manager, engine,
   UI, and drivers, to your Kubernetes cluster.

3. **Verify the Longhorn Installation:**

   After installation, verify that all Longhorn components are running
   correctly:

   ```bash
   kubectl get pods -n longhorn-system
   ```

   You should see several pods with names like `longhorn-manager`,
   `longhorn-driver`, and `longhorn-ui` in a "Running" state.

## Accessing the Longhorn UI

Longhorn provides a web-based user interface for managing and monitoring your
storage.

1. **Expose the Longhorn UI:**

   To access the Longhorn UI, you need to expose it as a service. Run the
   following command:

   ```bash
   kubectl patch svc longhorn-frontend -n longhorn-system -p '{"spec": {"type": "NodePort"}}'
   ```

   This command changes the Longhorn UI service to a NodePort type, making it
   accessible via any node's IP address.

2. **Find the Port Number for the Longhorn UI:**

   Run the following command to get the NodePort assigned to the Longhorn UI:

   ```bash
   kubectl get svc longhorn-frontend -n longhorn-system
   ```

   Note the `NodePort` value. You can access the Longhorn UI in a web browser
   using any node's IP address and this port, e.g.,
   `http://<node-ip>:<node-port>`.

## Lesson Conclusion

Congratulations! With Longhorn installed and configured, your Kubernetes cluster
now has a robust distributed block storage solution to manage persistent
volumes. In the next lesson, we will configure Longhorn storage classes to
optimize how your storage resources are allocated and used.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-18).
