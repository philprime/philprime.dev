---
layout: guide-lesson.liquid
title: Joining Additional Control Plane Nodes

guide_component: lesson
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
guide_section_id: 4
guide_lesson_id: 13
guide_lesson_abstract: >
  Join additional Raspberry Pi devices as control plane nodes to create a high-availability Kubernetes cluster.
guide_lesson_conclusion: >
  With all control plane nodes successfully joined and the high-availability configuration verified, your Kubernetes
  cluster is now more resilient and can withstand node failures.
repo_file_path: guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-13.md
---

In this lesson, we will join additional Raspberry Pi devices as control plane nodes to create a high-availability
Kubernetes cluster. Adding more control plane nodes ensures that your cluster remains resilient and operational, even if
one of the nodes fails.

{% include guide-overview-link.liquid.html %}

## Joining Additional Control Plane Nodes

To join additional control plane nodes, you need to use the `kubeadm join` command that you saved from the
initialization of the first control plane node. The command should look similar to this:

```bash
$ kubeadm join 10.1.1.1:6443 \
  --token <your token> \
  --discovery-token-ca-cert-hash <your hash> \
  --certificate-key <your certificate key> \
  --control-plane
```

Replace `<your-token>`, `<your certificate key>` and `<your hash>` with the actual values from the output of the
`kubeadm init` command. The `--control-plane` flag indicates that this node will be part of the control plane.

**Example:**

```bash
$ sudo kubeadm join 10.1.1.1:6443 \
  --token wjuudc.jqqqqrfx6vau3vyw \
  --discovery-token-ca-cert-hash sha256:ba65057d5290647aa8fcceb33a9624d3e9eb3640d13d11265fe48a611c5b8f3f \
  --certificate-key a1a135bf8be403583d2b1e6f7de7b14357e5e96c23deb8718bf2d1a807b08612 \
  --control-plane
```

In case you have lost the `kubeadm join` command, you can create a new certificate key and token by running these
commands on the first control plane node:

```bash
$ sudo kubeadm init phase upload-certs --upload-certs
[upload-certs] Storing the certificates in Secret "kubeadm-certs" in the "kube-system" Namespace
[upload-certs] Using certificate key:
d28d8618a4435b9173682516702696b6346b9b9c4c83e19dba03d478c672f85b

$ sudo kubeadm token create --print-join-command --certificate-key d28d8618a4435b9173682516702696b6346b9b9c4c83e19dba03d478c672f85b
# Output:
kubeadm join 10.1.1.1:6443 --token 9d83iw.dtu6bd7wc9n31s49 --discovery-token-ca-cert-hash sha256:da8ae30fec57d12427ddd753cc12befce7f7e6251fc2cb12cd784bdcfb45d82d --control-plane --certificate-key d28d8618a4435b9173682516702696b6346b9b9c4c83e19dba03d478c672f85b
```

### Optional: Recover from a failed control plane join

In case your node failed to join the etcd cluster, the following error might be shown in the etcd pod logs:

```
{"level":"warn","ts":"2025-02-21T19:47:17.855340Z","caller":"etcdserver/cluster_util.go:294","msg":"failed to reach the peer URL","address":"https://10.1.1.2:2380/version","remote-member-id":"fb6d6ed0973a1121","error"
:"Get \"https://10.1.1.2:2380/version\": dial tcp 10.1.1.2:2380: connect: connection refused"}
{"level":"warn","ts":"2025-02-21T19:47:17.855396Z","caller":"etcdserver/cluster_util.go:158","msg":"failed to get version","remote-member-id":"fb6d6ed0973a1121","error":"Get \"https://10.1.1.2:2380/version\": dial tcp
 10.1.1.2:2380: connect: connection refused"}
```

To recover from this, you can remove the Kubernetes node from the cluster using `kubeadm reset` and remove the etcd
member by running a shell in one of running etcd pods.

First install `etcdctl`:

```bash
$ export ETCD_VER=v3.5.19
$ export DOWNLOAD_URL="https://github.com/etcd-io/etcd/releases/download"
$ export ARCH=arm64
$ rm -f /tmp/etcd-${ETCD_VER}-linux-${ARCH}.tar.gz
$ rm -rf /tmp/etcd-download-test && mkdir -p /tmp/etcd-download-test
$ curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-${ARCH}.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-${ARCH}.tar.gz
$ tar xzvf /tmp/etcd-${ETCD_VER}-linux-${ARCH}.tar.gz -C /tmp/etcd-download-test --strip-components=1
$ rm -f /tmp/etcd-${ETCD_VER}-linux-${ARCH}.tar.gz
$ install /tmp/etcd-download-test/etcdctl /usr/local/bin/etcdctl
```

Then run the following command to list the etcd members:

```bash
$ ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    member list
11a85cd56d9530bf, started, kubernetes-node-1, https://10.1.1.1:2380, https://10.1.1.1:2379, false
fb6d6ed0973a1121, started, kubernetes-node-2, https://10.1.1.2:2380, https://10.1.1.2:2379, false
29402253d0a36abd, started, kubernetes-node-3, https://10.1.1.3:2380, https://10.1.1.3:2379, false
```

If only node-1 is in the list or if the cluster is unhealthy, etcd is the problem. Also, check etcd logs:

```bash
journalctl -u etcd --no-pager | tail -n 20
```

If, for example, the node you want to remove is `kubernetes-node-2`, you can remove it by running:

```bash
$ ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    member remove fb6d6ed0973a1121
```

## Changing the root-dir for containerd

After the node has joined the cluster, you need to change the `root-dir` for the kubelet to use the NVMe drive. This is
useful when pods require ephemeral storage and the default location on the SD card is insufficient.

As a first step, stop the kubelet service:

```bash
$ systemctl stop kubelet
```

The kubelet might still have active mount points (volumes, projected secrets, etc.) that need to be moved to the NVMe
drive. You can list all active mount points using the following command:

```bash
$ mount | grep kubelet
tmpfs on /var/lib/kubelet/pods/19b71363-5f60-48e8-bc2e-6469da490d76/volumes/kubernetes.io~projected/kube-api-access-5x64j type tmpfs (rw,relatime,size=8139008k,noswap)
tmpfs on /var/lib/kubelet/pods/2aebdfd6-b321-4128-a5cb-bd8c47dbeaa3/volumes/kubernetes.io~projected/kube-api-access-nt9ms type tmpfs (rw,relatime,size=8139008k,noswap)
tmpfs on /var/lib/kubelet/pods/b373c8b8-dd3e-4f76-aabc-ed166ebaab5d/volumes/kubernetes.io~secret/longhorn-grpc-tls type tmpfs (rw,relatime,size=8139008k,noswap)
...
```

Before we move the kubelet data to the NVMe drive, we need to unmount the active mount points. We can do this by running
the following command:

```bash
$ sudo umount -lf /var/lib/kubelet/pods/*/volumes/kubernetes.io~projected/*
```

Then create a directory on the NVMe drive to store the kubelet data, move the existing kubelet data to the new location,
and create a symlink to the new location. The symlink is necessary because some services might require the kubelet data
to be in the default location:

```bash
$ mkdir -p /mnt/nvme/kubelet
$ rsync -av /var/lib/kubelet/ /mnt/nvme/kubelet/
$ rm -rf /var/lib/kubelet/
$ ln -s /mnt/nvme/kubelet /var/lib/kubelet
```

Next, edit the systemctl override file for the kubelet service to set the `--root-dir` flag to the new location:

```bash
$ systemctl edit kubelet
```

Add the following lines to the file:

```ini
[Service]
Environment="KUBELET_EXTRA_ARGS=--root-dir=/mnt/nvme/kubelet"
```

Save and close the file. Then reload the systemd manager configuration and start the kubelet service:

```bash
$ systemctl daemon-reload
$ systemctl start kubelet
```

Verify that the kubelet service is running and the kubelet data is stored on the NVMe drive:

```bash
$ systemctl status kubelet

● kubelet.service - kubelet: The Kubernetes Node Agent
     Loaded: loaded (/lib/systemd/system/kubelet.service; enabled; preset: enabled)
    Drop-In: /usr/lib/systemd/system/kubelet.service.d
             └─10-kubeadm.conf
             /etc/systemd/system/kubelet.service.d
             └─override.conf
     Active: active (running) since Fri 2025-02-21 21:07:31 CET; 5s ago
...

root@kubernetes-node-2:~# mount | grep kubelet
tmpfs on /mnt/nvme/kubelet/pods/19b71363-5f60-48e8-bc2e-6469da490d76/volumes/kubernetes.io~projected/kube-api-access-5x64j type tmpfs (rw,relatime,size=8139008k,noswap)
...
```

## Verify the Nodes Have Joined the Cluster

To start administering your cluster from this node, you need to run the following as a regular user:

```bash
$ mkdir -p $HOME/.kube
$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Make sure to remove the `control-plane` tainted effect from the node to allow workloads to be scheduled on it:

```bash
$ kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

Run `kubectl get nodes` to see this node join the cluster:

```bash
$ kubectl get nodes
NAME                STATUS     ROLES           AGE     VERSION
kubernetes-node-1   Ready   control-plane   3m58s   v1.31.4
kubernetes-node-2   Ready   control-plane   87s     v1.31.4
kubernetes-node-3   Ready   control-plane   84s     v1.31.4
```

You should see all control plane nodes in the list with a status of "Ready."

{% include alert.liquid.html type='tip' title='TIP:' content=' If the nodes are not ready, check the logs for any errors
that may have occurred during the join process. You can use <code>journalctl -u kubelet</code> to inspect the logs.

Consider running <code>kubeadm reset</code> on the node and rejoining it to the cluster if you encounter any issues.

You can also use <code>sudo reboot</code> to restart the node. ' %}

{% include alert.liquid.html type='tip' title='TIP:' content='
If you want to communicate with the Kubernetes API server running on the local node, you can edit the
<code>~/.kube/config</code> file and replace the server address with <code>10.1.1.X</code> (with <code>X</code> being the
number of the node).
' %}

## Verify Control Plane High Availability

To ensure high availability, check that all control plane components are running correctly on each node:

```bash
$ kubectl get pods -n kube-system -o wide
NAME                                        READY   STATUS    RESTARTS       AGE   IP           NODE                NOMINATED NODE   READINESS GATES
coredns-7c65d6cfc9-ccqh9                    1/1     Running   0              23m   10.244.0.3   kubernetes-node-1   <none>           <none>
coredns-7c65d6cfc9-s6tll                    1/1     Running   0              23m   10.244.0.2   kubernetes-node-1   <none>           <none>
etcd-kubernetes-node-1                      1/1     Running   13             23m   10.1.1.1     kubernetes-node-1   <none>           <none>
etcd-kubernetes-node-2                      1/1     Running   0              19m   10.1.1.2     kubernetes-node-2   <none>           <none>
etcd-kubernetes-node-3                      1/1     Running   2 (104s ago)   19m   10.1.1.3     kubernetes-node-3   <none>           <none>
kube-apiserver-kubernetes-node-1            1/1     Running   13             23m   10.1.1.1     kubernetes-node-1   <none>           <none>
kube-apiserver-kubernetes-node-2            1/1     Running   0              19m   10.1.1.2     kubernetes-node-2   <none>           <none>
kube-apiserver-kubernetes-node-3            1/1     Running   2 (104s ago)   19m   10.1.1.3     kubernetes-node-3   <none>           <none>
kube-controller-manager-kubernetes-node-1   1/1     Running   13             23m   10.1.1.1     kubernetes-node-1   <none>           <none>
kube-controller-manager-kubernetes-node-2   1/1     Running   3              19m   10.1.1.2     kubernetes-node-2   <none>           <none>
kube-controller-manager-kubernetes-node-3   1/1     Running   6 (104s ago)   19m   10.1.1.3     kubernetes-node-3   <none>           <none>
kube-proxy-d8nzr                            1/1     Running   0              23m   10.1.1.1     kubernetes-node-1   <none>           <none>
kube-proxy-vmnfr                            1/1     Running   2 (104s ago)   19m   10.1.1.3     kubernetes-node-3   <none>           <none>
kube-proxy-wcdxf                            1/1     Running   0              19m   10.1.1.2     kubernetes-node-2   <none>           <none>
kube-scheduler-kubernetes-node-1            1/1     Running   13             23m   10.1.1.1     kubernetes-node-1   <none>           <none>
kube-scheduler-kubernetes-node-2            1/1     Running   3              19m   10.1.1.2     kubernetes-node-2   <none>           <none>
kube-scheduler-kubernetes-node-3            1/1     Running   6 (104s ago)   19m   10.1.1.3     kubernetes-node-3   <none>           <none>
```

You should see the control plane components (like `kube-apiserver`, `kube-scheduler`, and `kube-controller-manager`)
distributed across all control plane nodes.

## Distribute the etcd Cluster

Verify that the `etcd` cluster is also running across all control plane nodes:

```bash
$ kubectl get pods -n kube-system -l component=etcd -o wide
NAME                     READY   STATUS    RESTARTS        AGE   IP         NODE                NOMINATED NODE   READINESS GATES
etcd-kubernetes-node-1   1/1     Running   13              24m   10.1.1.1   kubernetes-node-1   <none>           <none>
etcd-kubernetes-node-2   1/1     Running   0               19m   10.1.1.2   kubernetes-node-2   <none>           <none>
etcd-kubernetes-node-3   1/1     Running   2               19m   10.1.1.3   kubernetes-node-3   <none>           <none>
```

You should see one `etcd` pod per control plane node, confirming that the `etcd` cluster is distributed and redundant.
