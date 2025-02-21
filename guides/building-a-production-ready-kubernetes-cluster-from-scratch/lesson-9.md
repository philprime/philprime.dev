---
layout: guide-lesson.liquid
title: Setting Up Docker or Container Runtime

guide_component: lesson
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
guide_section_id: 3
guide_lesson_id: 9
guide_lesson_abstract: >
  Set up Docker or another container runtime to run containers on your Raspberry Pi devices as part of the Kubernetes
  cluster.
---

In this lesson, we will set up **containerd** as the container runtime on each Raspberry Pi device. Containerd is a
lightweight and efficient container runtime that is widely used in Kubernetes environments due to its simplicity and
compatibility with Kubernetes' container runtime interface (CRI).

This is the ninth lesson in the series on building a production-ready Kubernetes cluster from scratch. Make sure you
have completed the [previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-8) before
continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

<div class="alert-warning" role="alert">
<strong>WARNING:</strong> All commands used in this lesson require <code>sudo</code> privileges.
Either prepend <code>sudo</code> to each command or switch to the root user using <code>sudo -i</code>.
</div>

## Installing containerd on Each Raspberry Pi

To begin, make sure you are connected to each Raspberry Pi via SSH. Perform the following steps on each device:

Update the package list and install required dependencies:

```bash
$ apt update
$ apt install -y apt-transport-https curl gnupg2 software-properties-common
```

Next you can install containerd using the following commands:

```bash
$ apt install -y containerd
```

## Preparing the containerd Configuration

Once containerd is installed, it needs to be configured properly to work with Kubernetes.

Create a default configuration file for containerd:

```bash
$ mkdir -p /etc/containerd
$ containerd config default | tee /etc/containerd/config.toml
```

## Configuring containerd to Use the NVMe Drive

Configure containerd to use the path `/mnt/nvme/containerd` as the root dir, so that containerd can store its data on
the NVMe drive:

```bash
$ mkdir -p /mnt/nvme/containerd
```

Open the configuration file with a text editor like `vi` or `nano` to modify the `root` setting:

```bash
$ vi /etc/containerd/config.toml
```

Find the line that specifies the `root` setting (typically under the
`[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]` section) and set it to `/mnt/nvme/containerd`.
This section is the configuration related to the `runc` runtime, which is the default runtime used by containerd:

```toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  root = "/mnt/nvme/containerd"
```

Save the changes and exit the editor (in `vi`, press `Esc` followed by `:wq` and `Enter`).

## Configuring containerd for Kubernetes

Open the configuration file with a text editor like `vi` or `nano` to modify the cgroup driver:

```bash
$ vi /etc/containerd/config.toml
```

Find the line that specifies the `SystemdCgroup` setting (typically under the
`[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]` section) and set it to `true`. When using `vi`,
you can search for the line using `/SystemdCgroup`:

```toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
```

Save the changes and exit the editor (in `vi`, press `Esc` followed by `:wq` and `Enter`).

## Adding symbolic link to the containerd directory

Adding a symbolic link to the containerd directory will allow containerd to store its data on the NVMe drive:

```bash
$ ln -s /mnt/nvme/containerd /var/lib/containerd
```

Restart containerd to apply the configuration changes and enable it to start on boot:

```bash
$ systemctl restart containerd
$ systemctl enable containerd
```

## Verifying containerd Installation

To confirm that containerd is installed and configured correctly, checkout the status of the containerd service:

```bash
$ systemctl status containerd
● containerd.service - containerd container runtime
     Loaded: loaded (/lib/systemd/system/containerd.service; enabled; preset: enabled)
     Active: active (running) since Sun 2025-01-12 20:16:00 CET; 21s ago
       Docs: https://containerd.io
   Main PID: 4629 (containerd)
      Tasks: 10
        CPU: 86ms
     CGroup: /system.slice/containerd.service
             └─4629 /usr/bin/containerd

Jan 12 20:16:00 kubernetes-node-1 containerd[4629]: time="2025-01-12T20:16:00.483721289+01:00" level=info msg="Start subscribing containerd event"
Jan 12 20:16:00 kubernetes-node-1 containerd[4629]: time="2025-01-12T20:16:00.483770622+01:00" level=info msg="Start recovering state"
Jan 12 20:16:00 kubernetes-node-1 containerd[4629]: time="2025-01-12T20:16:00.483840678+01:00" level=info msg="Start event monitor"
Jan 12 20:16:00 kubernetes-node-1 containerd[4629]: time="2025-01-12T20:16:00.483866549+01:00" level=info msg="Start snapshots syncer"
Jan 12 20:16:00 kubernetes-node-1 containerd[4629]: time="2025-01-12T20:16:00.483879086+01:00" level=info msg="Start cni network conf syncer for default"
Jan 12 20:16:00 kubernetes-node-1 containerd[4629]: time="2025-01-12T20:16:00.483890030+01:00" level=info msg="Start streaming server"
Jan 12 20:16:00 kubernetes-node-1 containerd[4629]: time="2025-01-12T20:16:00.484237568+01:00" level=info msg=serving... address=/run/containerd/containerd.sock.ttrpc
Jan 12 20:16:00 kubernetes-node-1 containerd[4629]: time="2025-01-12T20:16:00.484282883+01:00" level=info msg=serving... address=/run/containerd/containerd.sock
Jan 12 20:16:00 kubernetes-node-1 systemd[1]: Started containerd.service - containerd container runtime.
Jan 12 20:16:00 kubernetes-node-1 containerd[4629]: time="2025-01-12T20:16:00.485584240+01:00" level=info msg="containerd successfully booted in 0.038755s"
```

As you can see, the output shows that the containerd service is active and running.

## Lesson Conclusion

Congratulations! With containerd installed and configured, your Raspberry Pi devices are now ready to run containers as
part of the Kubernetes cluster. Next, we will prepare the nodes for Kubernetes initialization by ensuring they meet all
requirements and are correctly configured.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-10).
