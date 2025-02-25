---
layout: guide-lesson.liquid
title: Installing Longhorn for Distributed Block Storage

guide_component: lesson
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
guide_section_id: 6
guide_lesson_id: 17
guide_lesson_abstract: >
  Install and configure **Longhorn**, a lightweight and reliable distributed block storage solution for your Kubernetes
  cluster.
guide_lesson_conclusion: >
  With Longhorn installed and configured, your Kubernetes cluster now has a robust distributed block storage solution to
  manage persistent volumes
repo_file_path: guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-17.md
---

In this lesson, we will install and configure **Longhorn**, a lightweight and reliable distributed block storage
solution for your Kubernetes cluster. Longhorn provides persistent storage for applications running in your cluster,
enabling you to create, manage, and scale persistent volumes across multiple nodes.

{% include guide-overview-link.liquid.html %}

## What is Longhorn?

Longhorn is an open-source, cloud-native block storage solution for Kubernetes. It provides a simple, reliable, and
easy-to-deploy option for managing persistent volumes. Longhorn creates a highly available, replicated storage system
within your Kubernetes cluster, ensuring data redundancy and fault tolerance. It also offers features like incremental
backups, snapshots, and disaster recovery, making it ideal for production workloads.

## Why do we need a storage provisioner?

To run stateful applications in Kubernetes, you need a reliable storage solution which can provide persistent volumes
for your pods. As pods can be rescheduled on different nodes over time, the storage solution must be available across
the cluster and provide data redundancy to prevent data loss in case of node failures.

Longhorn acts as a storage provisioner in Kubernetes, managing the creation, replication, and scaling of persistent
volumes. It abstracts the underlying storage infrastructure and provides a unified interface for managing storage.

## Preparing the System for Longhorn Installation

Before starting off with the Longhorn installation, we are preparing the system to have all the necessary requirements
for Longhorn to run smoothly.

### Installing Longhornctl

As a first step, we are installing `longhornctl` which is a command-line interface for Longhorn as defined in
[their documentation](https://longhorn.io/docs/1.7.2/advanced-resources/longhornctl/install-longhornctl/) on our primary
node.

1. Download the binary:

   ```bash
   $ curl -LO "https://github.com/longhorn/cli/releases/download/v1.7.2/longhornctl-linux-arm64"
     % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                   Dload  Upload   Total   Spent    Left  Speed
     0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
   66 38.9M   66 26.0M    0     0  1301k      0  0:00:30  0:00:20  0:00:10  190k^C
   ```

2. Validate the binary (optional but recommended)

   ```bash
   # Download the checksum for your architecture.
   $ curl -LO "https://github.com/longhorn/cli/releases/download/v1.7.2/longhornctl-linux-arm64.sha256"
     % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                   Dload  Upload   Total   Spent    Left  Speed
     0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
   100    90  100    90    0     0    108      0 --:--:-- --:--:-- --:--:--   108

   # Verify the downloaded binary matches the checksum.
   $ echo "$(cat longhornctl-linux-arm64.sha256 | awk '{print $1}') longhornctl-linux-arm64" | sha256sum --check
   longhornctl-linux-amd64: OK
   ```

3. Install the binary:

   ```bash
   $ sudo install longhornctl-linux-arm64 /usr/local/bin/longhornctl
   ```

4. Validate the installation:

   ```bash
   $ longhornctl version
   v1.7.2
   ```

   You should see the version of `longhornctl` you just installed.

### Running the Longhorn Preflight Check

`longhornctl` provides a preflight check command that can be used to verify the environment before installing Longhorn.
This command checks for the necessary dependencies and configurations required for Longhorn to run successfully.

<div class="alert alert-warning">
<strong>Warning:</strong> The preflight check needs to be run on every node in your
Kubernetes cluster to ensure that all nodes meet the requirements for Longhorn.
Make sure you have removed the `control-plane` taint from the nodes before
running the preflight check using <code>kubectl taint nodes --all node-role.kubernetes.io/control-plane-</code>.
</div>

On the node you installed the CLI on, run the following command:

```bash
$ longhornctl --kube-config ~/.kube/config check preflight
INFO[2025-01-17T18:23:25+01:00] Initializing preflight checker
INFO[2025-01-17T18:23:25+01:00] Cleaning up preflight checker
INFO[2025-01-17T18:23:25+01:00] Running preflight checker
INFO[2025-01-17T18:23:58+01:00] Retrieved preflight checker result:
kubernetes-node-1:
  error:
  - Neither iscsid.service nor iscsid.socket is running
  - 'Module dm_crypt is not loaded: failed to execute: nsenter [--mount=/host/proc/17142/ns/mnt --net=/host/proc/17142/ns/net grep dm_crypt /proc/modules], output , stderr : exit status 1'
  info:
  - NFS4 is supported
  - Package nfs-common is installed
  - Package open-iscsi is installed
  - Package cryptsetup is installed
kubernetes-node-2:
  error:
  - Neither iscsid.service nor iscsid.socket is running
  - 'Module dm_crypt is not loaded: failed to execute: nsenter [--mount=/host/proc/18801/ns/mnt --net=/host/proc/18801/ns/net grep dm_crypt /proc/modules], output , stderr : exit status 1'
  info:
  - NFS4 is supported
  - Package nfs-common is installed
  - Package open-iscsi is installed
  - Package cryptsetup is installed
kubernetes-node-3:
  error:
  - Neither iscsid.service nor iscsid.socket is running
  - 'Module dm_crypt is not loaded: failed to execute: nsenter [--mount=/host/proc/11679/ns/mnt --net=/host/proc/11679/ns/net grep dm_crypt /proc/modules], output , stderr : exit status 1'
  info:
  - NFS4 is supported
  - Package nfs-common is installed
  - Package open-iscsi is installed
  - Package cryptsetup is installed
INFO[2025-01-17T18:23:58+01:00] Cleaning up preflight checker
INFO[2025-01-17T18:23:58+01:00] Completed preflight checker
```

### Installing Longhorn Dependencies

The preflight check has identified some missing dependencies that need to be installed before Longhorn can be deployed.
The missing dependencies include:

- `iscsid` service not running
- `dm_crypt` module not loaded

To install the missing dependencies, we can use the `longhornctl` command once again:

```bash
$ longhornctl --kube-config ~/.kube/config install preflight
INFO[2025-01-17T18:25:40+01:00] Initializing preflight installer
INFO[2025-01-17T18:25:40+01:00] Cleaning up preflight installer
INFO[2025-01-17T18:25:40+01:00] Running preflight installer
INFO[2025-01-17T18:25:40+01:00] Installing dependencies with package manager
INFO[2025-01-17T18:25:55+01:00] Installed dependencies with package manager
INFO[2025-01-17T18:25:55+01:00] Cleaning up preflight installer
INFO[2025-01-17T18:25:55+01:00] Completed preflight installer. Use 'longhornctl check preflight' to check the result.
```

Ensure that all necessary kernel modules are loaded. Run the following commands to load the required modules:

```bash
$ sudo modprobe iscsi_tcp
```

To make these changes persistent, create a configuration file:

```bash
$ sudo touch /etc/modules-load.d/longhorn.conf
$ sudo tee /etc/modules-load.d/longhorn.conf <<EOF
dm_crypt
iscsi_tcp
EOF

$ cat /etc/modules-load.d/longhorn.conf
dm_crypt
iscsi_tcp
```

### Verifying the Longhorn Dependencies

After installing the dependencies, you can run the preflight check again to verify that all the necessary dependencies
are now installed and configured correctly:

```bash
$ longhornctl --kube-config ~/.kube/config check preflight
INFO[2025-01-17T18:27:13+01:00] Initializing preflight checker
INFO[2025-01-17T18:27:13+01:00] Cleaning up preflight checker
INFO[2025-01-17T18:27:13+01:00] Running preflight checker
INFO[2025-01-17T18:27:17+01:00] Retrieved preflight checker result:
kubernetes-node-1:
  info:
  - Service iscsid is running
  - NFS4 is supported
  - Package nfs-common is installed
  - Package open-iscsi is installed
  - Package cryptsetup is installed
  - Module dm_crypt is loaded
kubernetes-node-2:
  info:
  - Service iscsid is running
  - NFS4 is supported
  - Package nfs-common is installed
  - Package open-iscsi is installed
  - Package cryptsetup is installed
  - Module dm_crypt is loaded
kubernetes-node-3:
  info:
  - Service iscsid is running
  - NFS4 is supported
  - Package nfs-common is installed
  - Package open-iscsi is installed
  - Package cryptsetup is installed
  - Module dm_crypt is loaded
INFO[2025-01-17T18:27:17+01:00] Cleaning up preflight checker
INFO[2025-01-17T18:27:17+01:00] Completed preflight checker
```

#### Checking the Environment (Optional / Deprecated)

In addition to the `longhornctl` preflight check, you can also run deprecated environment checks using the following
command on every node in your cluster:

```bash
# Install dependencies of the environment check script
$ sudo apt install -y jq

# Run the script to check the environment
$ curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/v1.7.2/scripts/environment_check.sh | bash
```

{% include alert.liquid.html type='warning' title='Warning:' content='
The script above is deprecated and may not work with newer versions of Longhorn. It is recommended to use the
<code>longhornctl</code> preflight check instead.
' %}

{% include alert.liquid.html type='warning' title='Warning:' content='
In general it is not recommended to run scripts directly from the internet. Make sure to review the script content
before executing it.
' %}

## Installing Longhorn in Your Kubernetes Cluster

To install Longhorn, you will use the official Longhorn manifests. Run the following command on any control plane node:

```bash
$ kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.7.2/deploy/longhorn.yaml
```

One way to monitor the progress of the installation is to watch pods being created in the longhorn-system namespace:

```bash
$ kubectl get pods \
  --namespace longhorn-system \
  --watch
NAME                                                READY   STATUS              RESTARTS   AGE
discover-proc-kubelet-cmdline                       0/1     Pending             0          10s
engine-image-ei-51cc7b9c-dqnv9                      1/1     Running             0          56s
engine-image-ei-51cc7b9c-txp62                      1/1     Running             0          56s
engine-image-ei-51cc7b9c-x24cq                      1/1     Running             0          56s
instance-manager-8ba9c8da191e28c0eca0cfed99f863d7   0/1     ContainerCreating   0          21s
instance-manager-a7d663c3e34d55048903a0f46fbf0883   0/1     ContainerCreating   0          23s
...
```

The installation process may take a few minutes to complete. Once all the pods are running, Longhorn is successfully
installed in your Kubernetes cluster.

## Exploring the Longhorn Installation

Let's take a closer look at the resources that were deployed as part of the Longhorn installation:

### Longhorn Manager

The Longhorn Manager is the core component of Longhorn. It manages the storage system, including volume creation,
replication, and scheduling. The Longhorn Manager is responsible for orchestrating the storage operations across the
cluster.

### Engine Image EI

The Engine Image (EI) is a container image that contains the Longhorn Engine binary. The Longhorn Engine is responsible
for managing the data on the nodes and ensuring that the data is replicated and available across the cluster.

### Instance Manager

The Instance Manager is responsible for managing the Longhorn Engine instances running on each node. It ensures that the
Longhorn Engine is running and healthy on every node in the cluster.

### Longhorn CSI Plugin

The Longhorn CSI Plugin is a Container Storage Interface (CSI) driver that provides a standard interface for creating
and managing persistent volumes in Kubernetes. The Longhorn CSI Plugin integrates Longhorn with Kubernetes, enabling you
to use Longhorn volumes as persistent storage for your applications.

### Longhorn Driver Deployer

The Longhorn Driver Deployer is a Kubernetes controller that deploys the Longhorn CSI Plugin and other Longhorn
components in the cluster. It ensures that the Longhorn components are running and healthy on all nodes.

### CSI Attacher

The CSI Attacher is a Kubernetes controller that attaches Longhorn volumes to pods. It ensures that the Longhorn volumes
are mounted and available to the pods that need them.

### CSI Provisioner

The CSI Provisioner is a Kubernetes controller that creates Longhorn volumes when requested by users. It dynamically
provisions Longhorn volumes based on the storage class and volume specifications provided by users.

### CSI Resizer

The CSI Resizer is a Kubernetes controller that resizes Longhorn volumes when requested by users. It allows users to
expand or shrink Longhorn volumes to meet the changing storage requirements of their applications.

### CSI Snapshotter

The CSI Snapshotter is a Kubernetes controller that creates snapshots of Longhorn volumes. It allows users to take
point-in-time snapshots of their volumes for backup, disaster recovery, or testing purposes.

### Longhorn UI

The Longhorn UI is a web-based user interface for managing and monitoring your storage. It provides a dashboard where
you can create, manage, and monitor persistent volumes, snapshots, and backups.

## Accessing the Longhorn UI

To enable access to the Longhorn UI, we will need to set up an Ingress controller. Authentication to the Longhorn UI is
not enabled by default. For information on creating an NGINX Ingress controller with basic authentication, refer to this
section.

Longhorn provides a web-based user interface for managing and monitoring your storage. To access the Longhorn UI, you
need to expose it as a service. Run the following command:

```bash
$ kubectl patch svc longhorn-frontend -n longhorn-system -p '{"spec": {"type": "NodePort"}}'
```

This command changes the Longhorn UI service to a NodePort type, making it accessible via any node's IP address.

Now you can access the Longhorn UI in a web browser using any node's IP address and the NodePort assigned to the
Longhorn UI service. To find the NodePort assigned to the Longhorn UI, run the following command:

```bash
$ kubectl get svc longhorn-frontend -n longhorn-system
NAME                TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
longhorn-frontend   NodePort   10.106.184.77   <none>        80:32756/TCP   19m
```

In this example, the NodePort assigned to the Longhorn UI is `32756`. You can access the Longhorn UI in a web browser
using any node's IP address and this port, e.g., `http://10.1.1.1:32756`.

![Longhorn Dashboard](/assets/blog/2024-09-15-building-a-production-ready-kubernetes-cluster-from-scratch/longhorn-1.png)

Looking at the dashboard above, you can see that longhorn has been successfully deployed and a total of 95.8 Gigabyte of
unused storage is available for use. 51.1 Gigabyte of data is reserved, as it will be used for the replication of the
data.

Now you might be wondering why it is only 95.8 Gigabyte of storage available when we have a 500 Gigabyte disk attached
to each node. This is because Longhorn uses `/var/lib/longhorn` on the host by default for storing the volume data,
which is path that is mounted on the microSD card of the Raspberry Pi.

You can explore it in detail by clicking on the `Node` tab at the top, where you can then view the storage per node.

![Longhorn Nodes](/assets/blog/2024-09-15-building-a-production-ready-kubernetes-cluster-from-scratch/longhorn-2.png)

We can avoid this behavior by adding the NVMe disks and then disabling scheduling for `/var/lib/longhorn`. This is
useful so we can keep the internal storage for the system and use the NVMe disks for the Kubernetes Cluster.

## Adding NVMe Disks to Longhorn

To make the NVMe disk available for Longhorn, we need to add the path of the mounted disk to the disk list of the node.

Longhorn will then detect the storage information (e.g. maximum space, available space) about the disk automatically.

When adding a disk to Longhorn, a certain amount of disk space can be reserved to stop Longhorn from using it. This is
useful for example when you want to use the disk for other purposes as well.

As a first step let's identify the necessary information for the NVMe disk. If you have followed along the guide, you
should have the NVMe disk mounted at `/mnt/nvme`, but for the sake of completeness, let's check it again:

```bash
$ lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
mmcblk0     179:0    0  58.2G  0 disk
├─mmcblk0p1 179:1    0   512M  0 part /boot/firmware
└─mmcblk0p2 179:2    0  57.7G  0 part /
nvme0n1     259:0    0 465.8G  0 disk
└─nvme0n1p1 259:1    0 465.8G  0 part /mnt/nvme
```

In this example, the NVMe disk is identified as `nvme0n1` and its partition is mounted at `/mnt/nvme` with `465.8G` of
disk space.

Next, we need to add the NVMe disk to Longhorn. This can be done using the Longhorn UI or via the Kubernetes API.

### Adding NVMe Disks to Longhorn via the Longhorn UI

Switch to the tab `Node` at the top to view your three nodes. Scroll to the right side of the table and click on
`Edit node and disks` in the `Operations` dropdown.

![Longhorn Nodes Dropdown](/assets/blog/2024-09-15-building-a-production-ready-kubernetes-cluster-from-scratch/longhorn-3.png)

In the dialog that opens, you can see the default disk path `/var/lib/longhorn` and the disk space available. To add the
NVMe disk, click on the `Add Disk` at the bottom of the dialog.

![Longhorn Dashboard](/assets/blog/2024-09-15-building-a-production-ready-kubernetes-cluster-from-scratch/longhorn-4.png)

When adding the disk you need to specify a name, e.g. `storage-1`, the path of the disk, i.e. `/mnt/nvme/storage-1`.

For the disk type you can choose between `File System` and `Block Device`. The `File System` option is used when the
disk is formatted with a file system, while the `Block Device` option is used when the disk is a raw block device.

Even tough the [documentation](https://longhorn.io/docs/1.7.2/v2-data-engine/quick-start/) on the V2 Data Engine states
that the `Block Device` significantly significantly reduces I/O latency while simultaneously boosting IOPS and
throughput, due to the power of the Storage Performance Development Kit (SPDK), it also states that the `Block Device`
option is currently Experimental not recommended for production use.

{% include alert.liquid.html type='warning' title='Warning:' content='
If you feel confident and want to try out the <code>Block Device</code> option, make sure to have a backup of your data
and be aware that it is not recommended for production use.
' %}

Next we need to specify the disk space reserved for Longhorn. This is useful if you want to use the disk for other
purposes as well. In this example, we are reserving `0G` of disk space.

Also do not forget to enable the disk for scheduling, otherwise Longhorn will not use the disk for storage operations.

To confirm the changes, click on the `Save` button.

![Longhorn Add Disk](/assets/blog/2024-09-15-building-a-production-ready-kubernetes-cluster-from-scratch/longhorn-5.png)

When confirming the changes, the dialog will disappear and by clicking on `Expand All` you can see all disks of the
node. Initially the disk will be detected with a size of `0G`, as Longhorn needs to scan the disk first.

![Longhorn Node Disks](/assets/blog/2024-09-15-building-a-production-ready-kubernetes-cluster-from-scratch/longhorn-6.png)

While waiting for the disk to be scanned, repeat the steps for the other nodes as well. Once the disk is scanned on
every node you will see the disk space of roughly `457.38 Gi` available for use.

![Longhorn Node Disks](/assets/blog/2024-09-15-building-a-production-ready-kubernetes-cluster-from-scratch/longhorn-7.png)

Now that the NVMe disk is added to Longhorn, we can remove the default disk on `/var/lib/longhorn` to avoid using the
internal storage for the system.

To do this, click on the `Edit node and disks` again, click on `Disable` scheduling for the default disk, then click on
the trash icon to remove the disk, and confirm the changes by clicking `Save`. Repeat the steps for the other nodes as
well.

![Longhorn Node Disks](/assets/blog/2024-09-15-building-a-production-ready-kubernetes-cluster-from-scratch/longhorn-8.png)

After removing the default disk, click on `Dashboard` at the top to return to the main dashboard. You can now see that
the disk space has changed to `1.34 Ti` being available for use.

![Longhorn Dashboard](/assets/blog/2024-09-15-building-a-production-ready-kubernetes-cluster-from-scratch/longhorn-9.png)

TODO: change to reserve 100GB because we use NVMe for other purposes as well.

### Adding NVMe Disks to Longhorn via the Kubernetes API

The Longhorn configuration for each node is actually stored in a Kubernetes Custom Resource Definition (CRD) called
`node.longhorn.io`. You can view and edit the node configuration using `kubectl` commands.

To view the available Longhorn nodes and their disks, run the following command:

```bash
$ kubectl get node.longhorn.io -n longhorn-system
NAME                READY   ALLOWSCHEDULING   SCHEDULABLE   AGE
kubernetes-node-1   True    true              True          3h35m
kubernetes-node-2   True    true              True          3h35m
kubernetes-node-3   True    true              True          3h35m
```

To view details about a specific node, run the following command:

```bash
$ kubectl get node.longhorn.io kubernetes-node-1 -n longhorn-system -o yaml
apiVersion: longhorn.io/v1beta2
kind: Node
metadata:
  creationTimestamp: "2025-01-17T17:38:27Z"
  finalizers:
  - longhorn.io
  generation: 4
  name: kubernetes-node-1
  namespace: longhorn-system
  resourceVersion: "46566"
  uid: 749b004f-2412-4f7f-833e-c293493abb2b
spec:
  allowScheduling: true
  disks:
    nvme-1:
      allowScheduling: true
      diskDriver: ""
      diskType: filesystem
      evictionRequested: false
      path: /mnt/nvme
      storageReserved: 0
      tags: []
  evictionRequested: false
  instanceManagerCPURequest: 0
  name: kubernetes-node-1
  tags: []
status:
  autoEvicting: false
  conditions:
  - lastProbeTime: ""
    lastTransitionTime: "2025-01-17T17:38:27Z"
    message: Node kubernetes-node-1 is ready
    reason: ""
    status: "True"
    type: Ready
  - lastProbeTime: ""
    lastTransitionTime: "2025-01-17T17:38:27Z"
    message: ""
    reason: ""
    status: "True"
    type: Schedulable
  - lastProbeTime: ""
    lastTransitionTime: "2025-01-17T17:39:01Z"
    message: ""
    reason: ""
    status: "True"
    type: MountPropagation
  - lastProbeTime: ""
    lastTransitionTime: "2025-01-17T17:39:02Z"
    message: All required packages [nfs-common open-iscsi cryptsetup dmsetup] are
      installed on node kubernetes-node-1
    reason: ""
    status: "True"
    type: RequiredPackages
  - lastProbeTime: ""
    lastTransitionTime: "2025-01-17T17:39:02Z"
    message: ""
    reason: ""
    status: "True"
    type: Multipathd
  - lastProbeTime: ""
    lastTransitionTime: "2025-01-17T17:39:02Z"
    message: Kernel modules [dm_crypt] are loaded on node kubernetes-node-1
    reason: ""
    status: "True"
    type: KernelModulesLoaded
  - lastProbeTime: ""
    lastTransitionTime: "2025-01-17T17:39:02Z"
    message: ""
    reason: ""
    status: "True"
    type: NFSClientInstalled
  diskStatus:
    nvme-1:
      conditions:
      - lastProbeTime: ""
        lastTransitionTime: "2025-01-17T20:54:27Z"
        message: Disk nvme-1(/mnt/nvme) on node kubernetes-node-1 is ready
        reason: ""
        status: "True"
        type: Ready
      - lastProbeTime: ""
        lastTransitionTime: "2025-01-17T20:54:27Z"
        message: Disk nvme-1(/mnt/nvme) on node kubernetes-node-1 is schedulable
        reason: ""
        status: "True"
        type: Schedulable
      diskDriver: ""
      diskName: nvme-1
      diskPath: /mnt/nvme
      diskType: filesystem
      diskUUID: 4fc8c312-9495-4e5e-b690-9d868b38f5c0
      filesystemType: ext2/ext3
      instanceManagerName: instance-manager-8ba9c8da191e28c0eca0cfed99f863d7
      scheduledReplica: {}
      storageAvailable: 491048140800
      storageMaximum: 491106525184
      storageScheduled: 0
  region: ""
  snapshotCheckStatus: {}
  zone: ""
```

Looking at the `diskStatus` section, you can see the disk `nvme-1` with the path `/mnt/nvme` which we added to Longhorn
via the UI.

By editing the `spec` section of the node configuration, you can add or remove disks, change the disk type, and adjust
the disk space reserved for Longhorn.

As an example let's reserve `10G` of disk space for the NVMe disk `nvme-1` on `kubernetes-node-1`. To do this we need to
set the `.spec.disks.nvme-1.storageReserved` to the number of bytes we want to reserve, i.e. `10737418240`:

```bash
$ kubectl patch node.longhorn.io kubernetes-node-1 -n longhorn-system --type merge --patch '{"spec": {"disks": {"nvme-1": {"storageReserved": 10737418240}}}}'
```

To confirm the changes, run the following command to view the updated node spec:

```bash
$ kubectl get node.longhorn.io kubernetes-node-1 -n longhorn-system -o yaml
apiVersion: longhorn.io/v1beta2
kind: Node
metadata:
  creationTimestamp: "2025-01-17T17:38:27Z"
  finalizers:
  - longhorn.io
  generation: 6
  name: kubernetes-node-1
  namespace: longhorn-system
  resourceVersion: "48292"
  uid: 749b004f-2412-4f7f-833e-c293493abb2b
spec:
  allowScheduling: true
  disks:
    nvme-1:
      allowScheduling: true
      diskDriver: ""
      diskType: filesystem
      evictionRequested: false
      path: /mnt/nvme
      storageReserved: 10737418240
      tags: []
...
```

You can also view the changes in the Longhorn UI by refreshing the page:

![Longhorn Node Disks](/assets/blog/2024-09-15-building-a-production-ready-kubernetes-cluster-from-scratch/longhorn-10.png)

To revert the changes, you can set the `storageReserved` back to `0`:

```bash
$ kubectl patch node.longhorn.io kubernetes-node-1 -n longhorn-system --type merge --patch '{"spec": {"disks": {"nvme-1": {"storageReserved": 0}}}}'
```

## Cleaning Up

To unexpose the Longhorn UI, you can change the service type back to `ClusterIP` by running the following command:

```bash
$ kubectl patch svc longhorn-frontend -n longhorn-system -p '{"spec": {"type": "ClusterIP"}}'
```
