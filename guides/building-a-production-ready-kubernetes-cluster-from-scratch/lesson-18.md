---
layout: guide-lesson.liquid
title: Configuring Longhorn Storage Classes

guide_component: lesson
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
guide_section_id: 6
guide_lesson_id: 18
guide_lesson_abstract: >
  Configure Longhorn storage classes to manage your Kubernetes cluster's storage resources efficiently.
guide_lesson_conclusion: >
  With your Longhorn storage classes configured, your Kubernetes cluster is now set up to efficiently manage persistent
  storage resources
repo_file_path: guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-18.md
---

In this lesson, we will configure Longhorn storage classes to manage your Kubernetes cluster's storage resources
efficiently. Storage classes define how storage is dynamically provisioned for your applications and allow you to
specify different parameters, such as replication settings, access modes, and performance optimizations.

{% include guide-overview-link.liquid.html %}

## What is a Storage Class?

A **Storage Class** in Kubernetes is a way to define different types of storage offered in a cluster. It allows
administrators to map storage requirements, such as volume size, performance, and replication, to specific storage
backends. By creating custom storage classes, you can control how Longhorn allocates and manages storage resources,
ensuring optimal performance and redundancy for different workloads.

## Understanding Longhorn Replicas

To quote the [Longhorn documentation](https://longhorn.io/docs/1.7.2/concepts/) on replicas:

> When the Longhorn Manager is asked to create a volume, it creates a Longhorn Engine instance on the node the volume is
> attached to, and it creates a replica on each node where a replica will be placed. Replicas should be placed on
> separate hosts to ensure maximum availability.
>
> The multiple data paths of the replicas ensure high availability of the Longhorn volume. Even if a problem happens
> with a certain replica or with the Engine, the problem won’t affect all the replicas or the Pod’s access to the
> volume. The Pod will still function normally.
>
> The Longhorn Engine always runs in the same node as the Pod that uses the Longhorn volume. It synchronously replicates
> the volume across the multiple replicas stored on multiple nodes.

In simpler terms, Longhorn uses replicas to ensure that your data is stored on multiple nodes. By configuring the number
of replicas in your storage class, you can control the level of redundancy and fault tolerance for your volumes.

## Creating a Longhorn Storage Class

To create a new storage class, define a YAML file with the desired configuration (see
[reference](https://longhorn.io/docs/1.7.2/references/storage-class-parameters/) for all possible fields). By default
Longhorn creates two storage classes `longhorn` and `longhorn-static` with different default settings. The `longhorn`
storage class is used for dynamic provisioning of volumes, while the `longhorn-static` storage class is used for static
provisioning of volumes:

```bash
$ kubectl get storageclasses
NAME                 PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
longhorn (default)   driver.longhorn.io   Delete          Immediate           true                   4h
longhorn-static      driver.longhorn.io   Delete          Immediate           true                   4h
```

To view the default settings for the `longhorn` storage class, run:

```bash
$ kubectl describe storageclass longhorn
```

```yaml
Name:            longhorn
IsDefaultClass:  Yes
Annotations:     longhorn.io/last-applied-configmap=kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: longhorn
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: "Delete"
volumeBindingMode: Immediate
parameters:
  numberOfReplicas: "3"
  staleReplicaTimeout: "30"
  fromBackup: ""
  fsType: "ext4"
  dataLocality: "disabled"
  unmapMarkSnapChainRemoved: "ignored"
  disableRevisionCounter: "true"
  dataEngine: "v1"
,storageclass.kubernetes.io/is-default-class=true
Provisioner:           driver.longhorn.io
Parameters:            dataEngine=v1,dataLocality=disabled,disableRevisionCounter=true,fromBackup=,fsType=ext4,numberOfReplicas=3,staleReplicaTimeout=30,unmapMarkSnapChainRemoved=ignored
AllowVolumeExpansion:  True
MountOptions:          <none>
ReclaimPolicy:         Delete
VolumeBindingMode:     Immediate
Events:                <none>
```

Let's create another storage class for Longhorn we can use later on to deploy our first services. Define the
`apiVersion` and the `kind` indicate the Kubernetes resource type. The `metadata` section specifies the `name` of the
storage class, which must be unique and will be used later on to request storage. The `provisioner` field specifies the
Longhorn driver and must always be `driver.longhorn.io`.

The `parameters` section allows you to configure the storage class with additional settings. As we run at least two
nodes in our cluster, we can set the `numberOfReplicas` to `2` to ensure that each volume has two replicas for fault
tolerance. The `staleReplicaTimeout` parameter specifies the timeout (in minutes) for stale replicas, which can be set
to `30` minutes after a replica is marked unhealthy before it is deemed useless for rebuilds and is just deleted.

Write the following configuration to a file named `longhorn-example-storage-class.yaml`:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-example
provisioner: driver.longhorn.io
parameters:
  numberOfReplicas: "2"
  staleReplicaTimeout: "30"
```

Apply the storage class to your Kubernetes cluster using `kubectl`:

```bash
kubectl apply -f longhorn-storage-class.yaml
```

## Using the Longhorn Storage Class

Now that you have created a new Longhorn storage class, you can use it to dynamically provision volumes for your
applications. When creating a new PersistentVolumeClaim (PVC), specify the storage class name in the `storageClassName`
field to use the Longhorn storage class:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: example-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-example
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-example
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
          volumeMounts:
            - name: html
              mountPath: /usr/share/nginx/html
      volumes:
        - name: html
          persistentVolumeClaim:
            claimName: example-pvc
```

Apply this configuration using:

```bash
$ kubectl apply -f example-deployment.yaml
```

This creates a simple nginx deployment with a persistent volume using our new storage class. You can check the status of
the deployment using:

```bash
$ kubectl get pods
NAME                           READY   STATUS    RESTARTS   AGE
nginx-example-d9d77448-jptwk   1/1     Running   0          30s

$ kubectl get pvc
NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS       VOLUMEATTRIBUTESCLASS   AGE
example-pvc   Bound    pvc-c5777d29-69e8-48f1-9f2a-b12e66808ab4   1Gi        RWO            longhorn-example   <unset>                 63s

$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                 STORAGECLASS       VOLUMEATTRIBUTESCLASS   REASON   AGE
pvc-c5777d29-69e8-48f1-9f2a-b12e66808ab4   1Gi        RWO            Delete           Bound    default/example-pvc   longhorn-example   <unset>                          77s

$ kubectl describe pv pvc-c5777d29-69e8-48f1-9f2a-b12e66808ab4
Name:            pvc-c5777d29-69e8-48f1-9f2a-b12e66808ab4
Labels:          <none>
Annotations:     longhorn.io/volume-scheduling-error:
                 pv.kubernetes.io/provisioned-by: driver.longhorn.io
                 volume.kubernetes.io/provisioner-deletion-secret-name:
                 volume.kubernetes.io/provisioner-deletion-secret-namespace:
Finalizers:      [kubernetes.io/pv-protection external-attacher/driver-longhorn-io]
StorageClass:    longhorn-example
Status:          Bound
Claim:           default/example-pvc
Reclaim Policy:  Delete
Access Modes:    RWO
VolumeMode:      Filesystem
Capacity:        1Gi
Node Affinity:   <none>
Message:
Source:
    Type:              CSI (a Container Storage Interface (CSI) volume source)
    Driver:            driver.longhorn.io
    FSType:            ext4
    VolumeHandle:      pvc-c5777d29-69e8-48f1-9f2a-b12e66808ab4
    ReadOnly:          false
    VolumeAttributes:      numberOfReplicas=2
                           staleReplicaTimeout=30
                           storage.kubernetes.io/csiProvisionerIdentity=1737135687617-3747-driver.longhorn.io
Events:                <none>
```

To view the available storage in the example app, exec into the pod and view the disk space using `df`:

```bash
$ kubectl exec -it nginx-example-d9d77448-jptwk -- df -h
Filesystem                                              Size  Used Avail Use% Mounted on
overlay                                                  57G  8.1G   46G  16% /
tmpfs                                                    64M     0   64M   0% /dev
/dev/mmcblk0p2                                           57G  8.1G   46G  16% /etc/hosts
shm                                                      64M     0   64M   0% /dev/shm
/dev/longhorn/pvc-c5777d29-69e8-48f1-9f2a-b12e66808ab4  974M   24K  958M   1% /usr/share/nginx/html
tmpfs                                                   7.8G   48K  7.8G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs                                                   4.0G     0  4.0G   0% /proc/asound
tmpfs                                                   4.0G     0  4.0G   0% /sys/firmware
```

As you can see, the volume is mounted at `/usr/share/nginx/html` and has a size of `958M`, or `1Gi` as requested in the
PVC.

## Cleaning Up

To clean up the resources created in this lesson, delete the deployment and the storage class:

```bash
$ kubectl delete -f example-deployment.yml
persistentvolumeclaim "example-pvc" deleted
deployment.apps "nginx-example" deleted

$ rm example-deployment.yaml
```

```bash
$ kubectl delete -f longhorn-example-storage-class.yaml
storageclass.storage.k8s.io "longhorn-example" deleted

$ rm longhorn-example-storage-class.yaml
```

## Optimizing Longhorn Storage Class for Performance

To optimize your Longhorn storage class for performance:

- **Adjust the number of replicas** to balance between performance and redundancy. A higher number of replicas increases
  fault tolerance but may impact write performance.
- **Configure volume access modes** based on your workload requirements. For example, use `ReadWriteOnce` for
  single-node access or `ReadWriteMany` for multi-node access.
- **Enable data locality** if you want to ensure that the data remains on the node where the volume is attached,
  reducing latency for read and write operations.
