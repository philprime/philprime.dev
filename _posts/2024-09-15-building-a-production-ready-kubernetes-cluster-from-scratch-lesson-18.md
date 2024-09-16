---
layout: post
title: Configuring Longhorn Storage Classes (L18)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-18
---

In this lesson, we will configure Longhorn storage classes to manage your
Kubernetes cluster's storage resources efficiently. Storage classes define how
storage is dynamically provisioned for your applications and allow you to
specify different parameters, such as replication settings, access modes, and
performance optimizations.

This is the eighteenth lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-17)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## What is a Storage Class?

A **Storage Class** in Kubernetes is a way to define different types of storage
offered in a cluster. It allows administrators to map storage requirements, such
as volume size, performance, and replication, to specific storage backends. By
creating custom storage classes, you can control how Longhorn allocates and
manages storage resources, ensuring optimal performance and redundancy for
different workloads.

## Creating a Longhorn Storage Class

1. **Create a New Storage Class for Longhorn:**

   To create a new storage class, define a YAML file with the desired
   configuration. For example, create a file named
   `longhorn-storage-class.yaml`:

   ```yaml
   apiVersion: storage.k8s.io/v1
   kind: StorageClass
   metadata:
     name: longhorn
   provisioner: driver.longhorn.io
   parameters:
     numberOfReplicas: '2' # Number of replicas for each volume
     staleReplicaTimeout: '30' # Timeout (in minutes) for stale replicas
   reclaimPolicy: Delete # Defines whether volumes are retained or deleted when their claims are deleted
   allowVolumeExpansion: true # Allow dynamic volume expansion
   volumeBindingMode: Immediate
   ```

2. **Apply the Storage Class Configuration:**

   Apply the storage class to your Kubernetes cluster using `kubectl`:

   ```bash
   kubectl apply -f longhorn-storage-class.yaml
   ```

   This command creates a new storage class named `longhorn` that provisions
   volumes with two replicas by default, allowing for fault tolerance.

3. **Set the Longhorn Storage Class as Default (Optional):**

   If you want Longhorn to be the default storage class for all persistent
   volume claims (PVCs) that do not specify a particular storage class, you can
   set it as the default:

   ```bash
   kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
   ```

## Verifying Storage Class Configuration

- List all storage classes in your cluster to ensure that the Longhorn storage
  class is correctly created:

  ```bash
  kubectl get storageclass
  ```

  The output should display the new `longhorn` storage class with the desired
  settings.

- Test the storage class by creating a Persistent Volume Claim (PVC) that uses
  it:

  ```yaml
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: test-claim
  spec:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 1Gi
    storageClassName: longhorn
  ```

  Save this file as `test-pvc.yaml` and apply it with:

  ```bash
  kubectl apply -f test-pvc.yaml
  ```

- Check the status of the PVC to ensure it is correctly provisioned:

  ```bash
  kubectl get pvc
  ```

  The PVC should be in a "Bound" state, indicating that the storage class is
  functioning correctly and the volume has been provisioned.

## Optimizing Longhorn Storage Class for Performance

To optimize your Longhorn storage class for performance:

- **Adjust the number of replicas** to balance between performance and
  redundancy. A higher number of replicas increases fault tolerance but may
  impact write performance.
- **Configure volume access modes** based on your workload requirements. For
  example, use `ReadWriteOnce` for single-node access or `ReadWriteMany` for
  multi-node access.
- **Enable data locality** if you want to ensure that the data remains on the
  node where the volume is attached, reducing latency for read and write
  operations.

## Lesson Conclusion

Congratulations! With your Longhorn storage classes configured, your Kubernetes
cluster is now set up to efficiently manage persistent storage resources. In the
next lesson, we will test and optimize the performance of your Longhorn storage
setup to ensure it meets your application's requirements.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-19).
