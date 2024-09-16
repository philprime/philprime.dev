---
layout: post
title: Updating Kubernetes Components and Nodes (L30)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-30
---

In this lesson, we will learn how to safely update the components and nodes of
your Kubernetes cluster. Regular updates are essential to keep your cluster
secure, take advantage of new features, and fix bugs or vulnerabilities.
However, updating a production cluster requires careful planning to minimize
disruption and avoid downtime.

This is the thirtieth lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-30)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## Important Considerations: Planning for Updates

Before proceeding with updates, consider the following:

- **Plan for Potential Downtime**: Depending on your cluster's size, the update
  process may cause some temporary disruptions, particularly for control plane
  components. Schedule updates during a maintenance window to minimize the
  impact.
- **Backup etcd Data**: Always take a fresh backup of your etcd data store
  before updating any control plane components. Refer to Lesson 29 for details
  on how to perform a backup.
- **Test Updates in a Staging Environment**: If possible, test updates in a
  non-production environment to identify any potential issues beforehand.

## Step 1: Update Kubernetes Control Plane Components

Updating the control plane components involves updating the `kube-apiserver`,
`kube-controller-manager`, `kube-scheduler`, and `etcd`.

1. **Check the Current Kubernetes Version:**

   Before proceeding, check the current Kubernetes version running in your
   cluster:

   ```bash
   kubectl version --short
   ```

2. **Drain the Control Plane Node:**

   To prevent disruptions to workloads, drain the control plane node to be
   updated:

   ```bash
   kubectl drain <control-plane-node-name> --ignore-daemonsets --delete-local-data
   ```

   Replace `<control-plane-node-name>` with the name of the control plane node
   you are updating. This command safely evicts all pods from the node.

3. **Update kubeadm:**

   SSH into the control plane node and update the `kubeadm` package to the
   desired version:

   ```bash
   sudo apt-get update && sudo apt-get install -y kubeadm=<desired-version>
   ```

   Replace `<desired-version>` with the target Kubernetes version.

4. **Run kubeadm Upgrade:**

   Run the `kubeadm upgrade` command to update the control plane components:

   ```bash
   sudo kubeadm upgrade apply <desired-version>
   ```

   Follow the instructions to confirm and complete the upgrade.

5. **Update kubelet and kubectl:**

   After upgrading the control plane components, update the `kubelet` and
   `kubectl` binaries on the control plane node:

   ```bash
   sudo apt-get install -y kubelet=<desired-version> kubectl=<desired-version>
   sudo systemctl restart kubelet
   ```

6. **Uncordon the Control Plane Node:**

   Once the update is complete and verified, uncordon the control plane node to
   make it schedulable again:

   ```bash
   kubectl uncordon <control-plane-node-name>
   ```

7. **Repeat for All Control Plane Nodes:**

   Repeat the above steps for each control plane node in your cluster, one at a
   time, to ensure that the cluster remains operational during the update
   process.

## Step 2: Update Worker Nodes

After the control plane is updated, proceed with updating the worker nodes.

1. **Drain the Worker Node:**

   Drain the worker node to prevent new pods from being scheduled and to safely
   evict existing pods:

   ```bash
   kubectl drain <worker-node-name> --ignore-daemonsets --delete-local-data
   ```

   Replace `<worker-node-name>` with the name of the worker node you are
   updating.

2. **Update kubeadm, kubelet, and kubectl:**

   SSH into the worker node and update the `kubeadm`, `kubelet`, and `kubectl`
   binaries:

   ```bash
   sudo apt-get update && sudo apt-get install -y kubeadm=<desired-version>
   sudo apt-get install -y kubelet=<desired-version> kubectl=<desired-version>
   ```

3. **Restart kubelet:**

   Restart the `kubelet` service to apply the updates:

   ```bash
   sudo systemctl restart kubelet
   ```

4. **Uncordon the Worker Node:**

   Once the update is complete and verified, uncordon the worker node to make it
   schedulable again:

   ```bash
   kubectl uncordon <worker-node-name>
   ```

5. **Repeat for All Worker Nodes:**

   Repeat the above steps for each worker node in your cluster, one at a time,
   to ensure that workloads are not interrupted.

## Step 3: Verify the Cluster Update

1. **Check Node Status:**

   Verify that all nodes are in a "Ready" state and running the desired
   Kubernetes version:

   ```bash
   kubectl get nodes
   ```

2. **Verify Cluster Functionality:**

   Test the cluster functionality by deploying sample applications, running test
   workloads, and checking the status of existing applications to ensure that
   they are running correctly.

3. **Monitor Cluster Health:**

   Use your monitoring tools (such as Grafana) to monitor the cluster’s health,
   performance, and resource usage. Check for any anomalies or issues that may
   have arisen due to the update.

## Step 4: Update Kubernetes Add-Ons

1. **Update CNI Plugins:**

   Check for updates to your Container Network Interface (CNI) plugins (such as
   Calico, Flannel, or Weave) and apply them as needed. This ensures
   compatibility with the new Kubernetes version.

   ```bash
   kubectl apply -f <cni-plugin-updated-yaml>
   ```

   Replace `<cni-plugin-updated-yaml>` with the path to the updated CNI plugin
   YAML file.

2. **Update Storage Add-Ons:**

   If you are using storage add-ons (like Longhorn or OpenEBS), check for
   updates and apply them to maintain compatibility and take advantage of new
   features or fixes.

   ```bash
   kubectl apply -f <storage-add-on-updated-yaml>
   ```

   Replace `<storage-add-on-updated-yaml>` with the path to the updated storage
   add-on YAML file.

## Lesson Conclusion

Congratulations! By carefully updating your Kubernetes components and nodes, you
have ensured that your cluster remains secure, stable, and up-to-date. In the
next lesson, we will focus on performing routine security audits and
vulnerability scans to maintain your cluster’s security posture.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-31).
