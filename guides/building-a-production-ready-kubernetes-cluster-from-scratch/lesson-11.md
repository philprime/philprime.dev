---
layout: guide-lesson.liquid
title: Initializing the First Control Plane Node

guide_component: lesson
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
guide_section_id: 4
guide_lesson_id: 11
guide_lesson_abstract: >
  Step-by-step guide to initializing the first control plane node in your Kubernetes cluster, including running kubeadm
  init and configuring the control plane.
guide_lesson_conclusion: >
  With the control plane initialized, your first node is now set up to manage your Kubernetes cluster.
repo_file_path: guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-11.md
---

In this lesson, we will initialize the first control plane node for your Kubernetes cluster. The control plane is
responsible for managing the state of the cluster, and setting it up correctly is crucial for the operation of your
cluster.

This is the eleventh lesson in the series on building a production-ready Kubernetes cluster from scratch. Make sure you
have completed the [previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-10) before
continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## Initializing the First Control Plane Node

SSH into the Raspberry Pi that you want to designate as the first control plane node. In this lesson, we will use
`kubernetes-node-1` with the IP `10.1.1.1`.

We will use `kubeadm` to initialize the control plane. This command sets up the Kubernetes control plane
components, such as the API server, controller manager, and scheduler.

For now, the cluster will use Node 1's address to reach the API server. The virtual IP `10.1.233.1` is not available
yet, so we will configure the load balancer and switch to that endpoint in lesson 15. We include the virtual IP in
the API server certificate now so that clients can validate it when we make that change.

Additionally, we will specify kubelet's local root directory to be on the NVMe drive mounted at the path `/mnt/nvme/kubelet`.
Make sure that the NVMe filesystem is mounted before continuing. This setting does not change the storage location of
etcd or containerd, which have their own configuration.

Therefore, create a file named `kubeadm-config.yaml` with the following content. This example uses the kubeadm `v1beta3`
configuration API supported by the Kubernetes 1.31 version used in this guide:

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
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
systemReserved:
  cpu: 250m
  memory: 512Mi
kubeReserved:
  cpu: 250m
  memory: 512Mi
```

Let's take a closer look at the settings before we initialize the node:

- `InitConfiguration.nodeRegistration.kubeletExtraArgs` sets kubelet's `root-dir` to the NVMe-backed directory.
- `ClusterConfiguration.controlPlaneEndpoint` defines the address that clients and joining nodes use to reach the
  API server. We start with `10.1.1.1` and change it to the load-balancer endpoint later.
- `networking.podSubnet` reserves `10.244.0.0/16` for pod addresses. We will use the same range when installing
  Flannel in the next lesson.
- `apiServer.certSANs` lists the additional addresses and hostnames that clients can use to validate the API server's
  certificate. If you need another address, add it here before initializing the cluster.

The final YAML document configures kubelet's resource reservations. Because we will also run application workloads
on these small control-plane nodes, we want to leave some capacity for the OS and Kubernetes node services.
`systemReserved` and `kubeReserved` each reserve 250m CPU and 512 MiB memory, for a total of half a CPU core and
1 GiB memory per node. These are starting values for our four-core, 8 GiB Raspberry Pis. Measure usage and adjust
these values for your hardware and workloads.

The reservations reduce the capacity that the scheduler can allocate to pods. They do not reserve capacity for
control-plane pods themselves or add hard limits to the system and kubelet cgroups. Applications still need sensible
resource requests and limits, since the scheduler uses requests rather than observed usage when placing pods.

Now run the following command to initialize the control plane:

```bash
$ sudo kubeadm init --config=kubeadm-config.yaml --upload-certs
```

The `--config` flag loads the YAML file above. We also pass `--upload-certs` so kubeadm uploads the shared
control-plane certificates in encrypted form. When we join the additional control-plane nodes in lesson 13, they
will use the certificate key printed by this command to retrieve those certificates.

At the beginning of the output, you might see a warning about the remote version being newer than the local version.
This means kubeadm found a newer Kubernetes release than its own minor version and selected a release from its
compatible minor series instead:

```
[..] remote version is much newer: v1.32.0; falling back to: stable-1.31
```

Once the initialization is complete, you will see a message displaying a `kubeadm join` command. This command is crucial
for joining additional nodes to the cluster. Copy and save it somewhere safe, as you will need it in lesson 13.
The token and certificate key are credentials, so do not publish them.

**Example:** The values below are fictitious. Use the command from your own initialization output:

```bash
$ sudo kubeadm join 10.1.1.1:6443 \
  --token wjuudc.jqqqqrfx6vau3vyw \
  --discovery-token-ca-cert-hash sha256:ba65057d5290647aa8fcceb33a9624d3e9eb3640d13d11265fe48a611c5b8f3f \
  --control-plane \
  --certificate-key a1a135bf8be403583d2b1e6f7de7b14357e5e96c23deb8718bf2d1a807b08612
```

By default, the bootstrap token expires after 24 hours, while the uploaded certificates are available for two hours.
If you continue with lesson 13 after these have expired, follow its instructions to create a new token and upload the
certificates again.

{% include alert.liquid.html type='warning' title='Warning:' content='
Do not rerun <code>kubeadm init</code> or use <code>kubeadm reset</code> as a general troubleshooting step.
Reset removes node-local cluster configuration and, on a control-plane node, local etcd member data.
Inspect the error first and use a deliberate recovery procedure before resetting an initialized node.
' %}

## Set Up kubectl for the Local User

To manage the cluster from your control plane node, you need to set up `kubectl` for the local user:

```bash
$ mkdir -p "$HOME/.kube"
$ chmod 700 "$HOME/.kube"
$ sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
$ sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
$ chmod 600 "$HOME/.kube/config"
```

These commands copy the Kubernetes configuration file to the local user's home directory, allowing you to use `kubectl`
commands to interact with the cluster. The file contains administrator credentials, so the permissions restrict access
to your user.

## Verify the Control Plane Setup

Run the following command to check the status of the nodes:

```bash
$ kubectl get nodes
NAME                STATUS     ROLES           AGE     VERSION
kubernetes-node-1   NotReady   control-plane   2m44s   v1.31.5
```

At this stage, we expect the node to be `NotReady` because we have not installed a CNI plugin yet. Let's check the
reason rather than assuming that every `NotReady` condition is harmless:

```bash
$ kubectl describe node kubernetes-node-1
```

Look for the `Ready` condition reporting that the container runtime network is not ready because the CNI plugin has
not been initialized. We will address that by installing Flannel in the next lesson. If the output instead reports
another problem, investigate it before continuing.

We can also check that kubelet has applied the resource reservations from our configuration:

```bash
$ kubectl get node kubernetes-node-1 -o custom-columns=NAME:.metadata.name,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory
```

On our four-core node, the allocatable CPU should be `3500m` after reserving `500m` for node services.

## Allow Scheduling on the Control Plane Node

By default, the control plane node is tainted to prevent workloads from being scheduled on it.

```bash
$ kubectl describe nodes kubernetes-node-1
Name:               kubernetes-node-1
Roles:              control-plane
[...]
Taints:             node-role.kubernetes.io/control-plane:NoSchedule
                    node.kubernetes.io/not-ready:NoSchedule
[...]
```

As our cluster is quite small, we want to allow scheduling on the control plane node (but not recommended for production
environments). You can remove the taint with:

```bash
$ kubectl taint node kubernetes-node-1 node-role.kubernetes.io/control-plane-
```
