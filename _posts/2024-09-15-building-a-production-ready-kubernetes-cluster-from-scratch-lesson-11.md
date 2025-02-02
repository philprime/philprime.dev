---
layout: course-lesson
title: Initializing the First Control Plane Node (L11)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-11
---

In this lesson, we will initialize the first control plane node for your
Kubernetes cluster. The control plane is responsible for managing the state of
the cluster, and setting it up correctly is crucial for the operation of your
cluster.

This is the eleventh lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-10)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## Initializing the First Control Plane Node

SSH into the Raspberry Pi that you want to designate as the first control plane
node. In this lesson, we will use `kubernetes-node-1` with the IP `10.1.1.1`.

Run the following `kubeadm` command to initialize the control plane. This
command sets up the Kubernetes control plane components, such as the API server,
controller manager, and scheduler.

In preparation for the next lesson, we will also specify the IP address of the
control plane node, additional IP addresses for the API server certificate, and
upload the certificates to the Kubernetes cluster for secure communication.

Additionally, we will specify the local root directory to be on the NVMe drive
mounted at the path `/mnt/nvme/kubelet`. Therefore create a file named `kubeadm-config.yaml` with the following content:

```yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  kubeletExtraArgs:
    root-dir: "/mnt/nvme/kubelet"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
controlPlaneEndpoint: "10.1.1.1"
networking:
  podSubnet: "10.244.0.0/16"
apiServer:
  certSANs:
  - "127.0.0.1"
  - "10.1.233.1"
  - "10.1.1.1"
  - "10.1.1.2"
  - "10.1.1.3"
  - "kubernetes-node-1"
  - "kubernetes-node-2"
  - "kubernetes-node-3"
  - "10.0.0.10"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: UploadCertsConfiguration
```

Now run the following command to initialize the control plane:

```bash
$ sudo kubeadm init --config=kubeadm-config.yaml
```

- The flags `--control-plane-endpoint` is used to define the IP address of the
  control plane node.
- The `--upload-certs` flag uploads the certificates to the Kubernetes cluster
  for secure communication.
- To support a virtual network, we specify the `--pod-network-cidr` flag with a
  compatible CIDR range, in this case `10.244.0.0/16` for compatibility with the
  Flannel CNI plugin (which we will install later).
- The `--apiserver-cert-extra-sans` flag is used to add additional IP addresses
  to the API server certificate. This is useful when you have multiple IP
  addresses on the control plane node, such as the virtual IP `10.1.233.1` used
  by a load balancer (which we will set up later) or `127.0.0.1` when the
  kube-api-server is bound to the local host. If you are planning on
  port-forwarding the API server, you should also add the external IP address of
  the control plane node to the certificate by repeating the argument
  `--apiserver-cert-extra-sans=EXTERNAL_IP_ADDRESS`, i.e.
  `--apiserver-cert-extra-sans=10.0.0.10`

At the beginning of the output, you might see a warning about the remote version
being newer than the local version. This is because we are using an older
version of `kubeadm` to update it later, but it could also show up in the future
if newer versions are released:

```
[..] remote version is much newer: v1.32.0; falling back to: stable-1.31
```

Once the initialization is complete, you will see a message displaying a
`kubeadm join` command. This command is crucial for joining additional nodes to
the cluster. Copy and save it somewhere safe, as you will need it in the next
lesson.

**Example:**

```bash
$ kubeadm join 10.1.1.1:6443 \
  --token wjuudc.jqqqqrfx6vau3vyw \
  --discovery-token-ca-cert-hash sha256:ba65057d5290647aa8fcceb33a9624d3e9eb3640d13d11265fe48a611c5b8f3f \
  --control-plane \
  --certificate-key a1a135bf8be403583d2b1e6f7de7b14357e5e96c23deb8718bf2d1a807b08612
```

<div class="alert alert-info" role="alert">
  <strong>TIP</strong>: If anything goes wrong, you can always reset your Kubernetes server
  using <code>kubeadm reset</code>.
</div>

## Set Up kubectl for the Local User

To manage the cluster from your control plane node, you need to set up `kubectl`
for the local user:

```bash
$ mkdir -p $HOME/.kube
$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

This command copies the Kubernetes configuration file to the local user's home
directory, allowing you to use `kubectl` commands to interact with the cluster.

## Verify the Control Plane Setup

Run the following command to check the status of the nodes:

```bash
$ kubectl get nodes
NAME                STATUS     ROLES           AGE     VERSION
kubernetes-node-1   NotReady   control-plane   2m44s   v1.31.5
```

As you can see the node is currently in the `NotReady` state. This is because
the control plane has no CNI plugin installed yet. We will install the Flannel
CNI plugin in the next lesson, so it is safe to ignore for now

## Allow Scheduling on the Control Plane Node

By default, the control plane node is tainted to prevent workloads from being
scheduled on it.

```bash
$ kubectl describe nodes kubernetes-node-1
Name:               kubernetes-node-1
Roles:              control-plane
[...]
Taints:             node-role.kubernetes.io/control-plane:NoSchedule
                    node.kubernetes.io/not-ready:NoSchedule
[...]
```

As our cluster is quite small, we want to allow scheduling on the control plane
node (but not recommended for production environments), you can remove the taint
with:

```bash
$ kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

## Lesson Conclusion

Congratulations! With the control plane initialized, your first node is now set
up to manage your Kubernetes cluster. In the next lesson, we will setup the CNI
plugin to enable networking between pods.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-12).
