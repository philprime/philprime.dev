---
layout: course-lesson
title: Joining Additional Control Plane Nodes (L12)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-12
---

In this lesson, we will join additional Raspberry Pi devices as control plane
nodes to create a high-availability Kubernetes cluster. Adding more control
plane nodes ensures that your cluster remains resilient and operational, even if
one of the nodes fails.

This is the twelfth lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-11)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## Joining Additional Control Plane Nodes

On each additional control plane node, use the `kubeadm join` command that you
saved from the initialization of the first control plane node. The command
should look similar to this:

```bash
$ kubeadm join 10.1.1.1:6443 \
  --token <your token> \
  --discovery-token-ca-cert-hash <your hash> \
  --certificate-key <your certificate key> \
  --control-plane
```

Replace `<your-token>`, `<your certificate key>` and `<your hash>` with the
actual values from the output of the `kubeadm init` command. The
`--control-plane` flag indicates that this node will be part of the control
plane.

**Example:**

```bash
$ sudo kubeadm join 10.1.1.1:6443 \
  --token wjuudc.jqqqqrfx6vau3vyw \
  --discovery-token-ca-cert-hash sha256:ba65057d5290647aa8fcceb33a9624d3e9eb3640d13d11265fe48a611c5b8f3f \
  --certificate-key a1a135bf8be403583d2b1e6f7de7b14357e5e96c23deb8718bf2d1a807b08612 \
  --control-plane
```

This command will connect the additional control plane nodes to the existing
cluster and synchronize the necessary control plane components.

## Verify the Nodes Have Joined the Cluster

To start administering your cluster from this node, you need to run the
following as a regular user:

```bash
$ mkdir -p $HOME/.kube
$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Run 'kubectl get nodes' to see this node join the cluster:

```bash
$ kubectl get nodes
NAME                STATUS     ROLES           AGE     VERSION
kubernetes-node-1   Ready   control-plane   3m58s   v1.31.4
kubernetes-node-2   Ready   control-plane   87s     v1.31.4
kubernetes-node-3   Ready   control-plane   84s     v1.31.4
```

You should see all control plane nodes in the list with a status of "Ready."

> [!TIP] If the nodes are not ready, check the logs for any errors that may have
> occurred during the join process. You can use `journalctl -u kubelet` to
> inspect the logs.
>
> Consider running `kubeadm reset` on the node and rejoining it to the cluster
> if you encounter any issues.
>
> You can also use `sudo reboot` to restart the node.

> [!TIP] If you want to communicate with the Kubernetes API server running on
> the local node, you can edit the `~/.kube/config` file and replace the server
> address with `10.1.1.X` (with `X` being the number of the node).

## Verify Control Plane High Availability

To ensure high availability, check that all control plane components are running
correctly on each node:

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

You should see the control plane components (like `kube-apiserver`,
`kube-scheduler`, and `kube-controller-manager`) distributed across all control
plane nodes.

## Distribute the etcd Cluster

Verify that the `etcd` cluster is also running across all control plane nodes:

```bash
$ kubectl get pods -n kube-system -l component=etcd -o wide
NAME                     READY   STATUS    RESTARTS        AGE   IP         NODE                NOMINATED NODE   READINESS GATES
etcd-kubernetes-node-1   1/1     Running   13              24m   10.1.1.1   kubernetes-node-1   <none>           <none>
etcd-kubernetes-node-2   1/1     Running   0               19m   10.1.1.2   kubernetes-node-2   <none>           <none>
etcd-kubernetes-node-3   1/1     Running   2               19m   10.1.1.3   kubernetes-node-3   <none>           <none>
```

You should see one `etcd` pod per control plane node, confirming that the `etcd`
cluster is distributed and redundant.

## Lesson Conclusion

Congratulations! With all control plane nodes successfully joined and the
high-availability configuration verified, your Kubernetes cluster is now more
resilient and can withstand node failures. In the next lesson, we will install a
pod network (CNI plugin) to enable communication between all pods within the
cluster.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-12).
