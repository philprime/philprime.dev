---
layout: guide-lesson.liquid
title: Setting Up Storage (Longhorn + local-path)

guide_component: lesson
guide_id: migrating-k3s-to-rke2
guide_section_id: 2
guide_lesson_id: 7
guide_lesson_abstract: >
  Persistent storage is a prerequisite for any stateful workload.
  This lesson configures two storage classes on Cluster B: Longhorn for replicated block storage with data redundancy, and local-path-provisioner for high-performance local volumes that serve caching and ephemeral data.
guide_lesson_conclusion: >
  Cluster B now has Longhorn and local-path storage classes provisioned, verified, and ready for workload deployment.
repo_file_path: guides/migrating-k3s-to-rke2/lesson-7.md
---

With Canal networking verified and network policies in place from [Lesson 6](/guides/migrating-k3s-to-rke2/lesson-6), Cluster B can route traffic between pods and enforce security boundaries.
The next layer our cluster needs before accepting workloads is persistent storage.
We configure two storage classes in this lesson: Longhorn for replicated volumes and local-path-provisioner for fast local storage.

{% include guide-overview-link.liquid.html %}

## Why Longhorn

Several storage provisioners exist for Kubernetes, with [Rook-Ceph](https://rook.io/), [OpenEBS](https://openebs.io/), and [Longhorn](https://longhorn.io/) being the most common self-hosted options. Based on our research these seem to be the key differences:

Rook-Ceph is a powerful distributed storage system that provides block, file, and S3-compatible object storage.
It is designed for large clusters with dozens of nodes and dedicated storage disks, and carries significant operational complexity.

OpenEBS offers multiple storage engines, with its flagship Mayastor engine using NVMe-oF and SPDK for high-performance replicated block storage.
Mayastor requires NVMe drives and has higher resource demands than Longhorn.
The project has gone through several engine generations (Jiva, cStor, Mayastor), which makes the documentation landscape harder to navigate.

Longhorn is a lightweight distributed block storage system built by SUSE/Rancher alongside RKE2, making it a natural fit for our cluster size and tooling.
It works well on small-to-medium clusters (1 to 10 nodes), has minimal resource overhead, and is straightforward to deploy and manage via Helm.

We use Longhorn for this guide because it matches our 4-node cluster size, integrates tightly with the Rancher ecosystem, and keeps operational complexity low.
If our storage requirements grow to need object storage or multi-petabyte capacity, we may revisit this decision and migrate to Rook-Ceph in a future guide.

## Understanding Longhorn

[Longhorn](https://longhorn.io/) replicates volumes across multiple nodes to provide data redundancy.
When a pod requests storage through a PersistentVolumeClaim (PVC), Longhorn's CSI driver provisions a PersistentVolume (PV) and synchronizes its data across replicas on different nodes.
If a node fails, the remaining replicas continue serving data while Longhorn rebuilds a new replica on a healthy node.

For a deeper introduction to Longhorn (including its architecture, component breakdown, and storage class configuration), see [Installing Longhorn](/guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-17) and [Configuring Longhorn Storage Classes](/guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-18) in the guide [Building a Production-Ready Kubernetes Cluster from Scratch](/guides/building-a-production-ready-kubernetes-cluster-from-scratch).

## Choosing Storage Classes

The two storage classes serve different workload profiles:

| Storage Class | Replication | Performance | Use Cases                                     |
| ------------- | ----------- | ----------- | --------------------------------------------- |
| Longhorn      | Yes         | Good        | Databases, stateful apps, data you can't lose |
| local-path    | No          | Excellent   | Caching, temp storage, build artifacts        |

We configure both to match the flexibility most k3s clusters have.

## Planning Storage Capacity

Longhorn stores replicas on each node's local disk, so disk space planning matters before installation.

| Component        | Minimum | Recommended | Notes                                 |
| ---------------- | ------- | ----------- | ------------------------------------- |
| OS and RKE2      | 20GB    | 40GB        | Container images, logs, etcd data     |
| Longhorn storage | 50GB    | 100GB+      | Per-node, depends on workload volumes |
| local-path       | 10GB    | 20GB        | Fast local storage for caching        |

For simple partition layouts (`/boot` + `/`), all storage shares the root partition.
Consider a dedicated partition or disk for `/var/lib/longhorn` if large storage requirements apply.

## Preparing the Node for Longhorn

Longhorn requires several system-level dependencies, most importantly iSCSI for block storage and NFSv4 for RWX volume support.
The `longhornctl` CLI can check and install these automatically.
Repeat these steps on every node that joins the cluster.

### Installing longhornctl

Download the CLI matching the Longhorn version we install:

```bash
$ curl -fL -o /usr/local/bin/longhornctl \
    https://github.com/longhorn/cli/releases/download/v1.11.0/longhornctl-linux-amd64

$ curl -fL -o /tmp/longhornctl-linux-amd64.sha256 \
    https://github.com/longhorn/cli/releases/download/v1.11.0/longhornctl-linux-amd64.sha256

$ echo "$(cat /tmp/longhornctl-linux-amd64.sha256 | awk '{print $1}')  /usr/local/bin/longhornctl" | sha256sum --check
/usr/local/bin/longhornctl: OK

$ chmod +x /usr/local/bin/longhornctl
$ /usr/local/bin/longhornctl version
v1.11.0
```

### Running the Preflight Check

The preflight tool deploys DaemonSets into the `longhorn-system` namespace to check and install dependencies on each node.
Create the namespace first, then run the check.
Since RKE2 places its kubeconfig at `/etc/rancher/rke2/rke2.yaml`, pass it explicitly:

```bash
$ kubectl create namespace longhorn-system
namespace/longhorn-system created

$ /usr/local/bin/longhornctl --kubeconfig /etc/rancher/rke2/rke2.yaml check preflight
INFO[2026-02-15T03:15:55+02:00] Initializing preflight checker
INFO[2026-02-15T03:15:55+02:00] Cleaning up preflight checker
INFO[2026-02-15T03:15:55+02:00] Running preflight checker
INFO[2026-02-15T03:16:03+02:00] Retrieved preflight checker result:
node4:
  error:
  - '[IscsidService] Neither iscsid.service nor iscsid.socket is running. - Service iscsid.service is not found (exit code: 4) - Service iscsid.socket is not found (exit code: 4)'
  - '[Packages] nfs-utils is not installed (exit code: 1)'
  - '[Packages] iscsi-initiator-utils is not installed (exit code: 1)'
  - '[KernelModules] nfs is not loaded. (exit code: 1)'
  - '[KernelModules] iscsi_tcp is not loaded. (exit code: 1)'
  - '[KernelModules] dm_crypt is not loaded. (exit code: 1)'
  info:
  - '[MultipathService] multipathd.service is not found (exit code: 4)'
  - '[MultipathService] multipathd.socket is not found (exit code: 4)'
  - '[NFSv4] NFS4 is supported'
  - '[Packages] cryptsetup is installed'
  - '[Packages] device-mapper is installed'
  warn:
  - '[KubeDNS] Kube DNS "rke2-coredns-rke2-coredns" is set with fewer than 2 replicas; consider increasing replica count for high availability'
INFO[2026-02-15T03:16:03+02:00] Cleaning up preflight checker
INFO[2026-02-15T03:16:03+02:00] Completed preflight checker
```

If the check reports missing packages or modules, run the preflight installer to resolve them automatically:

```bash
$ /usr/local/bin/longhornctl --kubeconfig /etc/rancher/rke2/rke2.yaml install preflight
INFO[2026-02-15T03:16:23+02:00] Initializing preflight installer
INFO[2026-02-15T03:16:23+02:00] Cleaning up preflight installer
INFO[2026-02-15T03:16:23+02:00] Running preflight installer
INFO[2026-02-15T03:16:23+02:00] Installing dependencies with package manager
INFO[2026-02-15T03:17:32+02:00] Installed dependencies with package manager
INFO[2026-02-15T03:17:32+02:00] Retrieved preflight installer result:
node4:
  info:
  - Successfully installed package nfs-utils
  - Successfully installed package iscsi-initiator-utils
  - Successfully probed module nfs
  - Successfully probed module iscsi_tcp
  - Successfully probed module dm_crypt
  - Successfully started service iscsid
INFO[2026-02-15T03:17:32+02:00] Cleaning up preflight installer
INFO[2026-02-15T03:17:32+02:00] Completed preflight installer. Use 'longhornctl check preflight' to check the result (on some os a reboot and a new install execution is required first)
```

Run the check again to confirm everything passes:

```bash
$ /usr/local/bin/longhornctl --kubeconfig /etc/rancher/rke2/rke2.yaml check preflight
INFO[2026-02-15T03:17:43+02:00] Initializing preflight checker
INFO[2026-02-15T03:17:43+02:00] Cleaning up preflight checker
INFO[2026-02-15T03:17:43+02:00] Running preflight checker
INFO[2026-02-15T03:17:45+02:00] Retrieved preflight checker result:
node4:
  info:
  - '[IscsidService] Service iscsid is running'
  - '[MultipathService] multipathd.service is not found (exit code: 4)'
  - '[MultipathService] multipathd.socket is not found (exit code: 4)'
  - '[NFSv4] NFS4 is supported'
  - '[Packages] nfs-utils is installed'
  - '[Packages] iscsi-initiator-utils is installed'
  - '[Packages] cryptsetup is installed'
  - '[Packages] device-mapper is installed'
  - '[KernelModules] nfs is loaded'
  - '[KernelModules] iscsi_tcp is loaded'
  - '[KernelModules] dm_crypt is loaded'
  warn:
  - '[KubeDNS] Kube DNS "rke2-coredns-rke2-coredns" is set with fewer than 2 replicas; consider increasing replica count for high availability'
INFO[2026-02-15T03:17:45+02:00] Cleaning up preflight checker
INFO[2026-02-15T03:17:45+02:00] Completed preflight checker
```

All errors should be gone, with only informational and warning messages remaining.
The CoreDNS replica warning is expected on a single-node cluster and resolves once additional nodes join.

## Installing Longhorn

RKE2 includes a Helm controller that automatically installs and manages Helm charts from manifest files, the same mechanism we used for the Canal `HelmChartConfig` in [Lesson 6](/guides/migrating-k3s-to-rke2/lesson-6).
For external charts like Longhorn, we use a `HelmChart` resource instead of `HelmChartConfig`.

We start with a single node, so `defaultReplicaCount` is set to `1` because replicas require separate nodes to be useful.
We increase this to `2` once additional nodes join the cluster.

Create the manifest at `/var/lib/rancher/rke2/server/manifests/longhorn.yaml`:

```yaml
# /var/lib/rancher/rke2/server/manifests/longhorn.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: longhorn
  namespace: kube-system
spec:
  repo: https://charts.longhorn.io
  chart: longhorn
  version: "1.11.0"
  targetNamespace: longhorn-system
  valuesContent: |-
    defaultSettings:
      defaultReplicaCount: 1
      storageMinimalAvailablePercentage: 15
      defaultDataLocality: "best-effort"
      nodeDrainPolicy: "block-if-contains-last-replica"
      guaranteedEngineManagerCPU: 12
      guaranteedReplicaManagerCPU: 12
    persistence:
      defaultClass: false
      defaultClassReplicaCount: 1
      reclaimPolicy: Delete
    ingress:
      enabled: false
```

The most important settings control replica behavior and disk reservation:

| Setting                             | Value                            | Purpose                                                  |
| ----------------------------------- | -------------------------------- | -------------------------------------------------------- |
| `defaultReplicaCount`               | `1`                              | Single replica while only one node exists                |
| `storageMinimalAvailablePercentage` | `15`                             | Reserve disk space for system operations                 |
| `defaultDataLocality`               | `best-effort`                    | Prefer placing replicas on the node running the workload |
| `nodeDrainPolicy`                   | `block-if-contains-last-replica` | Prevent data loss during node maintenance                |

RKE2 detects the new manifest and installs the chart automatically within a few seconds.

```bash
$ kubectl get pods -n longhorn-system -w
NAME                                                READY   STATUS    RESTARTS   AGE
csi-attacher-896ffc747-kvcg9                        1/1     Running   0          2m46s
csi-attacher-896ffc747-l6p92                        1/1     Running   0          2m46s
csi-attacher-896ffc747-m5brz                        1/1     Running   0          2m46s
csi-provisioner-688964c44b-2r5br                    1/1     Running   0          2m46s
csi-provisioner-688964c44b-bx5l4                    1/1     Running   0          2m46s
csi-provisioner-688964c44b-gq967                    1/1     Running   0          2m46s
csi-resizer-6585bb54-4fgzf                          1/1     Running   0          2m46s
csi-resizer-6585bb54-89s2w                          1/1     Running   0          2m46s
csi-resizer-6585bb54-9rpx9                          1/1     Running   0          2m46s
csi-snapshotter-65884686fc-5mcdm                    1/1     Running   0          2m46s
csi-snapshotter-65884686fc-m8zbh                    1/1     Running   0          2m46s
csi-snapshotter-65884686fc-q5p94                    1/1     Running   0          2m46s
engine-image-ei-ff1cedad-c9zsl                      1/1     Running   0          3m24s
instance-manager-9d6cce936720fe18ca09b3a5b9c3bb4a   1/1     Running   0          2m54s
longhorn-csi-plugin-gz98r                           3/3     Running   0          2m46s
longhorn-driver-deployer-5d7995fc74-dbnjh           1/1     Running   0          3m40s
longhorn-manager-v6sr8                              2/2     Running   0          3m40s
longhorn-ui-7fc9b4667f-fxwr9                        1/1     Running   0          3m40s
longhorn-ui-7fc9b4667f-gvmp9                        1/1     Running   0          3m40s
```

Every pod in the `longhorn-system` namespace should show `Running` with all containers ready.

## Understanding local-path-provisioner

[local-path-provisioner](https://github.com/rancher/local-path-provisioner) is a lightweight storage provisioner developed by Rancher that creates PersistentVolumes backed by directories on the node's local filesystem.
Unlike Longhorn, it provides no replication, snapshots, or cross-node data availability. When a node goes down, volumes on that node become inaccessible until the node recovers.

This simplicity is its strength.

local-path uses the node's native filesystem directly, avoiding the overhead of network-attached block storage and iSCSI.
For workloads that manage their own replication (like distributed databases with a write-ahead log) or store ephemeral data (build artifacts, caches, temporary files), local-path delivers better I/O performance with lower resource consumption.

| Feature              | Longhorn                      | local-path                          |
| -------------------- | ----------------------------- | ----------------------------------- |
| Replication          | Across nodes                  | None                                |
| Snapshots            | Yes                           | No                                  |
| Volume binding       | Immediate                     | WaitForFirstConsumer                |
| Node failure         | Data survives on other nodes  | Data unavailable until node is back |
| Performance overhead | iSCSI + replication           | Direct filesystem access            |
| Use cases            | Databases, stateful workloads | Caches, build artifacts, temp data  |

The `WaitForFirstConsumer` volume binding mode ensures that a local-path volume is only created on the node where the pod is actually scheduled.
This prevents Kubernetes from provisioning a volume on one node and then scheduling the pod on a different node where the data does not exist, effectively breaking the workload until the pod is rescheduled back to the correct node.

## Installing local-path-provisioner

We place the local-path-provisioner manifest in RKE2's auto-deploy directory so it is applied automatically on cluster startup, consistent with our Longhorn and Canal deployments.

Download the manifest and save it to the manifests directory:

```bash
$ curl -fL -o /var/lib/rancher/rke2/server/manifests/local-path-provisioner.yaml \
    https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml
```

RKE2 detects the new manifest and creates the namespace, deployment, and storage class automatically.
The default configuration stores volumes at `/opt/local-path-provisioner` on each node.

Verify the deployment is running:

```bash
$ kubectl get pods -n local-path-storage
NAME                                      READY   STATUS    RESTARTS   AGE
local-path-provisioner-5f96558fc6-txcw7   1/1     Running   0          4s
```

## Verification

### Checking Storage Classes

All three storage classes should appear, with none marked as default:

```bash
$ kubectl get storageclass
NAME              PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION
local-path        rancher.io/local-path   Delete          WaitForFirstConsumer   false
longhorn          driver.longhorn.io      Delete          Immediate              true
longhorn-static   driver.longhorn.io      Delete          Immediate              true
```

Longhorn creates two classes: `longhorn` for dynamically provisioned volumes and `longhorn-static` for pre-provisioned volumes that reference existing Longhorn volumes by name.
For most workloads, `longhorn` is the correct choice.

**For our cluster, no default storage class is set, so every PVC must specify a `storageClassName` explicitly.**

This forces workload authors to make a deliberate choice between replicated and local storage.
A database that accidentally used local-path would restart with an empty disk if its node went down, while a CI/CD pipeline might prefer the performance of local storage and manage its own replication.
Requiring explicit selection prevents these mismatches.

Verify that Longhorn recognizes the cluster nodes as schedulable for storage:

```bash
$ kubectl get nodes.longhorn.io -n longhorn-system
NAME   READY   ALLOWSCHEDULING   SCHEDULABLE   AGE
node4   True    true              True          10m
```

### Testing Volume Provisioning

Create a test PVC and pod that writes to a Longhorn volume to confirm end-to-end provisioning works:

```bash
$ cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: storage-test
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: storage-test
spec:
  containers:
  - name: test
    image: busybox
    command: ['sh', '-c', 'echo "Storage works" > /data/test.txt && cat /data/test.txt && sleep 30']
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: storage-test
EOF

$ kubectl wait --for=condition=Ready pod/storage-test --timeout=120s
persistentvolumeclaim/storage-test created
pod/storage-test created
pod/storage-test condition met

$ kubectl logs storage-test
Storage works
```

The output `Storage works` confirms that Longhorn provisioned the volume and the pod can write to it.
We can also confirm that the PV is bound to the PVC:

```bash
$ kubectl get pvc -w
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
storage-test   Bound    pvc-b49021d6-5fa7-4b16-8d13-a125aba696e9   1Gi        RWO            longhorn       <unset>                 46s
```

Remove the test resources once verified:

```bash
$ kubectl delete pod storage-test
$ kubectl delete pvc storage-test
```

## Accessing the Longhorn UI

Longhorn ships with a web UI for managing volumes, viewing replica status, and troubleshooting storage issues.
The UI is not exposed publicly because our firewall configuration from [Lesson 4](/guides/migrating-k3s-to-rke2/lesson-4) blocks all inbound traffic except SSH.
Instead, we use SSH port forwarding to tunnel the UI to our local machine.

The approach requires two forwarding hops: one SSH tunnel from your workstation to the node, and one `kubectl port-forward` inside the SSH session to reach the Longhorn service.

```bash
# From your local machine, open an SSH tunnel that forwards local port 8080 to the node
$ ssh -L 8080:localhost:8080 node4.example.com

# Inside the SSH session on the node, forward port 8080 to the Longhorn UI service
$ kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
Forwarding from 127.0.0.1:8080 -> 8000
Forwarding from [::1]:8080 -> 8000
```

Open `http://localhost:8080` in your browser to access the Longhorn dashboard.
From there you can inspect volume health, monitor replica distribution across nodes, and trigger manual snapshots or backups.
The port-forward session stays active until you close the SSH connection or press `Ctrl+C`.
