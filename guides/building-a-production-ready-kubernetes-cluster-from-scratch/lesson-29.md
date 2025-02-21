---
layout: guide-lesson.liquid
title: Backup and Disaster Recovery for etcd

guide_component: lesson
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
guide_section_id: 10
guide_lesson_id: 29
guide_lesson_abstract: >
  Learn how to back up and restore the etcd data store to protect your cluster’s critical data and configurations.
---

In this lesson, we will learn how to back up and restore the `etcd` data store, which is the central database for
storing all Kubernetes cluster state and configuration. Protecting `etcd` is critical because it contains all the data
needed to recover your cluster in the event of a disaster. Regular backups and a robust disaster recovery plan are
essential to ensure that you can quickly restore your cluster to a functional state after an unexpected failure.

This is the twenty-ninth lesson in the series on building a production-ready Kubernetes cluster from scratch. Make sure
you have completed the [previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-28) before
continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## What is etcd?

**etcd** is a distributed, consistent key-value store that Kubernetes uses as its backing store for all cluster data,
including cluster state, configurations, secrets, and service discovery information. Since etcd is a critical component
of Kubernetes, losing its data can result in a total loss of the cluster. Therefore, taking regular backups of etcd is
crucial to protect against data loss and facilitate disaster recovery.

## Important Considerations: Impact on Cluster Availability

Before proceeding, it is essential to understand that **restoring etcd from a backup will impact the cluster and cause
downtime**. During the restoration process:

- The **etcd** service will be stopped, making the Kubernetes API server unavailable.
- All **control plane components** that rely on etcd will become inaccessible.
- **Node status updates, pod scheduling, and other cluster operations** will be paused until etcd is fully restored and
  running.

Make sure to schedule the backup and restoration process during a maintenance window or at a time when cluster downtime
has the least impact on your applications and users.

## Step 1: Backup etcd

To back up the etcd data store, we will use the `etcdctl` command-line utility, which provides tools to interact with
the etcd cluster. Ensure that `etcdctl` is installed on your control plane nodes and is configured to communicate with
your etcd cluster.

1. **Identify the Leader Node:**

   Run the following command to find the etcd leader:

   ```bash
   kubectl exec -n kube-system etcd-<control-plane-node-name> -- etcdctl --endpoints=https://127.0.0.1:2379 endpoint status --write-out=table
   ```

   Replace `<control-plane-node-name>` with the name of your control plane node. Look for the node that shows `leader`
   in the output.

2. **Backup etcd Data:**

   SSH into the etcd leader node and create a snapshot of the etcd data:

   ```bash
   sudo ETCDCTL_API=3 etcdctl \
     --endpoints=https://127.0.0.1:2379 \
     --cacert=/etc/kubernetes/pki/etcd/ca.crt \
     --cert=/etc/kubernetes/pki/etcd/server.crt \
     --key=/etc/kubernetes/pki/etcd/server.key \
     snapshot save /path/to/backup/etcd-snapshot.db
   ```

   Replace `/path/to/backup/etcd-snapshot.db` with the desired path where you want to save the backup file.

3. **Verify the Backup:**

   Check the status of the snapshot to ensure it was created correctly:

   ```bash
   sudo ETCDCTL_API=3 etcdctl snapshot status /path/to/backup/etcd-snapshot.db --write-out=table
   ```

   This should display details about the snapshot, such as its size and the revision number.

4. **Automate Regular Backups:**

   To ensure that you have up-to-date backups, create a cron job or use a scheduling tool to automate regular etcd
   snapshots. Here is an example cron job that takes a backup every day at midnight:

   ```bash
   0 0 * * * /usr/bin/etcdctl --endpoints=https://127.0.0.1:2379 \
     --cacert=/etc/kubernetes/pki/etcd/ca.crt \
     --cert=/etc/kubernetes/pki/etcd/server.crt \
     --key=/etc/kubernetes/pki/etcd/server.key \
     snapshot save /path/to/backup/etcd-snapshot-$(date +\%Y\%m\%d).db
   ```

## Step 2: Restore etcd from Backup

To restore etcd from a backup, you need to use the saved snapshot file to reinitialize the etcd cluster.

1. **Plan for Downtime:**

   Inform users and stakeholders about the planned downtime. Make sure that all critical operations are paused or
   completed before proceeding with the restoration.

2. **Stop the etcd Service:**

   SSH into each control plane node and stop the etcd service:

   ```bash
   sudo systemctl stop etcd
   ```

3. **Restore etcd Data from the Snapshot:**

   On the leader node (or the node where you will initialize etcd), run the following command to restore the etcd data
   from the snapshot:

   ```bash
   sudo ETCDCTL_API=3 etcdctl snapshot restore /path/to/backup/etcd-snapshot.db \
     --data-dir=/var/lib/etcd-restored
   ```

   Replace `/path/to/backup/etcd-snapshot.db` with the path to your backup file, and `/var/lib/etcd-restored` with the
   directory where the restored etcd data will be stored.

4. **Update etcd Configuration:**

   Update the etcd configuration to point to the restored data directory. Edit the etcd manifest located at
   `/etc/kubernetes/manifests/etcd.yaml` and modify the `--data-dir` parameter:

   ```yaml
   - --data-dir=/var/lib/etcd-restored
   ```

   Save the changes and exit the editor.

5. **Restart the etcd Service:**

   Start the etcd service on the control plane nodes:

   ```bash
   sudo systemctl start etcd
   ```

   Verify that etcd is running correctly:

   ```bash
   kubectl get pods -n kube-system
   ```

   All etcd pods should be in a "Running" state.

6. **Rejoin Other Control Plane Nodes:**

   If you have multiple control plane nodes, ensure they rejoin the etcd cluster after the restoration. Repeat the
   process of updating the etcd configuration and restarting the etcd service on each control plane node.

## Step 3: Verify the etcd Restoration

1. **Check Cluster Health:**

   Run the following command to check the health of the etcd cluster:

   ```bash
   sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
     --cacert=/etc/kubernetes/pki/etcd/ca.crt \
     --cert=/etc/kubernetes/pki/etcd/server.crt \
     --key=/etc/kubernetes/pki/etcd/server.key \
     endpoint health --write-out=table
   ```

   Ensure that all etcd endpoints report "healthy."

2. **Verify Kubernetes Cluster State:**

   Confirm that the Kubernetes control plane components are operational and that all cluster resources (pods, services,
   deployments) are in their expected states:

   ```bash
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```

   Everything should be in the "Ready" or "Running" state, indicating a successful recovery.

## Lesson Conclusion

Congratulations! By implementing regular backups and a disaster recovery plan for `etcd`, you have ensured that your
cluster can quickly recover from data loss or catastrophic failures, despite the necessary downtime. In the next lesson,
we will focus on updating Kubernetes components and nodes to keep your cluster secure and up to date.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-29).
