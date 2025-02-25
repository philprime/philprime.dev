---
layout: guide-lesson.liquid
title: Installing a Pod Network (CNI Plugin)

guide_component: lesson
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
guide_section_id: 4
guide_lesson_id: 12
guide_lesson_abstract: >
  Install a Container Network Interface (CNI) plugin to enable communication between pods running on different nodes.
guide_lesson_conclusion: >
  With the CNI plugin installed and verified, your Kubernetes cluster is now ready to support communication between all
  pods across nodes
repo_file_path: guides/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-12.md
---

In this lesson, we will install a Container Network Interface (CNI) plugin to enable communication between the pods
running on different nodes in your Kubernetes cluster. The CNI plugin is essential for networking in Kubernetes, as it
ensures that all pods can communicate securely and efficiently across the cluster.

{% include guide-overview-link.liquid.html %}

## What is a CNI Plugin?

A **CNI (Container Network Interface) plugin** is a critical component in Kubernetes that facilitates networking for
containers running across multiple nodes in a cluster. It provides the necessary networking capabilities to allow pods
(the smallest deployable units in Kubernetes) to communicate with each other and with services both inside and outside
the cluster. A CNI plugin works by configuring the network interfaces of containers and managing the underlying network
policies, routes, and IP address assignments to ensure that all containers can communicate seamlessly and securely.

## Why Choose Flannel as the CNI Plugin?

We chose **Flannel** as our CNI plugin for this guide because it is lightweight, simple to set up, and well-suited for
use with resource-constrained environments like Raspberry Pi devices. Flannel creates a virtual overlay network that
connects all pods across the cluster, ensuring that each pod gets a unique IP address from a pre-defined CIDR range.
This setup simplifies networking by abstracting the complexities of the underlying network infrastructure, making it
easier to deploy and manage a Kubernetes cluster. Flannel is also highly compatible with Kubernetes and requires minimal
configuration, which makes it an ideal choice for those who are new to Kubernetes or working with smaller clusters.

## Install the Flannel CNI Plugin

To install Flannel, run the following command on any of the control plane nodes:

```bash
$ kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

This command downloads the Flannel manifest file from the official GitHub page and applies it to your cluster. The
manifest file contains the necessary configurations to deploy Flannel across all nodes in your cluster.

## Verify the CNI Plugin Installation

To confirm that Flannel is correctly installed, check the status of the pods in the `kube-flannel` namespace:

```bash
$ kubectl get pods -n kube-flannel -o wide --watch
NAME                    READY   STATUS    RESTARTS      AGE   IP         NODE                NOMINATED NODE   READINESS GATES
kube-flannel-ds-8d9tg   1/1     Running   0             1m    10.1.1.1   kubernetes-node-1   <none>           <none>
```

You should see several `kube-flannel-ds` pods, one for each node, with a status of "Running". This indicates that
Flannel is successfully deployed and operating across all nodes.

## Check the Node Status

We conclued the [previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-11) with our node
in a `NotReady` state, due to the abscence of a CNI plugin. After installing Flannel, the node should now be in a
`Ready` state:

```bash
$ kubectl get nodes
NAME                STATUS   ROLES           AGE   VERSION
kubernetes-node-1   Ready    control-plane   17m   v1.31.5
```

### Common Issues

Here are some common issues you may encounter and how to fix them:

#### Error: `Node kubernetes-node-1 status is now: CIDRAssignmentFailed`

Try to restart the `kubelet` service on the node:

```bash
$ sudo systemctl restart kubelet
```

## Check the Pod Network CIDR

Ensure the pod network CIDR matches the one specified during control plane initialization (`10.244.0.0/16` for Flannel).
The pod network CIDR is a range of IP addresses used for assigning IPs to pods within the cluster. It is crucial to
ensure that this range matches the one specified during the control plane initialization to avoid network conflicts and
ensure proper communication between pods.

You can check this by looking at the cluster configuration:

```bash
$ kubectl cluster-info dump | grep -m 1 cluster-cidr
                            "--cluster-cidr=10.244.0.0/16",
```

The output should confirm the correct CIDR range we configured for Flannel.

## Allow Flannel Traffic Through the Firewall

1. Flannel uses UDP ports `8285` and `8472` for backend communication between nodes. Ensure these ports are open in the
   firewall on every single node, to allow Flannel to function correctly:

   ```bash
   # Allowing Flannel UDP backend traffic
   $ sudo ufw allow 8285/udp
   $ sudo ufw allow out 8285/udp

   # Allow Flannel VXLAN backend traffic
   $ sudo ufw allow 8472/udp
   $ sudo ufw allow out 8472/udp
   ```

2. Next up, we need to allow traffic from our pod network CIDR range (`10.244.0.0/16`). This is necessary for the pods
   to communicate with each other across nodes:

   ```bash
   # Allow traffic from pod network CIDR to Kubernetes API server
   $ sudo ufw allow from 10.244.0.0/16 to any port 6443
   $ sudo ufw allow out to 10.244.0.0/16 port 6443
   ```

3. Flannel also requires node-to-node communication for overlay networking.

   ```bash
   # Allow incoming intra-pod network communication within pod network CIDR
   $ sudo ufw allow from 10.244.0.0/16 to 10.244.0.0/16
   # Allow outgoing intra-pod network communication within pod network CIDR
   $ sudo ufw allow out to 10.244.0.0/16
   ```

4. Allow routed traffic for Flannel overlay network

   ```bash
   $ sudo ufw allow in on flannel.1
   $ sudo ufw allow out on flannel.1
   ```

5. Enable packet forwarding in the kernel. Open the `sysctl.conf` file for and uncomment the following lines to route
   packets between interfaces:

   ```
   $ sudo nano /etc/ufw/sysctl.conf
   #net/ipv4/ip_forward=1
   #net/ipv6/conf/default/forwarding=1
   #net/ipv6/conf/all/forwarding=1
   ```

   Remove the leading `#` from the lines to uncomment them:

   ```
   $ sudo nano /etc/ufw/sysctl.conf
   net/ipv4/ip_forward=1
   net/ipv6/conf/default/forwarding=1
   net/ipv6/conf/all/forwarding=1
   ```

   Save the file and exit the editor.

6. After opening these ports, reload the firewall to apply the changes:

   ```bash
   $ sudo ufw reload
   ```

7. Afterwards you firewall table should include these rules:

   ```bash
   $ sudo ufw status verbose
   Status: active
   Logging: on (low)
   Default: deny (incoming), deny (outgoing), deny (routed)
   New profiles: skip

   To                         Action      From
   --                         ------      ----
   22/tcp                     ALLOW IN    Anywhere
   6443/tcp                   ALLOW IN    10.1.1.0/24
   2379:2380/tcp              ALLOW IN    10.1.1.0/24
   10250/tcp                  ALLOW IN    10.1.1.0/24
   10251/tcp                  ALLOW IN    127.0.0.1
   10252/tcp                  ALLOW IN    127.0.0.1
   8285/udp                   ALLOW IN    Anywhere
   8472/udp                   ALLOW IN    Anywhere
   6443                       ALLOW IN    10.244.0.0/16
   10.244.0.0/16              ALLOW IN    10.244.0.0/16
   Anywhere on flannel.1      ALLOW IN    Anywhere
   22/tcp (v6)                ALLOW IN    Anywhere (v6)
   8285/udp (v6)              ALLOW IN    Anywhere (v6)
   8472/udp (v6)              ALLOW IN    Anywhere (v6)
   Anywhere (v6) on flannel.1 ALLOW IN    Anywhere (v6)

   53                         ALLOW OUT   Anywhere
   123/udp                    ALLOW OUT   Anywhere
   10.1.1.0/24 6443/tcp       ALLOW OUT   Anywhere
   10.1.1.0/24 2379:2380/tcp  ALLOW OUT   Anywhere
   10.1.1.0/24 10250/tcp      ALLOW OUT   Anywhere
   127.0.0.1 10251/tcp        ALLOW OUT   Anywhere
   127.0.0.1 10252/tcp        ALLOW OUT   Anywhere
   8285/udp                   ALLOW OUT   Anywhere
   8472/udp                   ALLOW OUT   Anywhere
   10.244.0.0/16 6443         ALLOW OUT   Anywhere
   10.244.0.0/16              ALLOW OUT   Anywhere
   Anywhere                   ALLOW OUT   Anywhere on flannel.1
   53 (v6)                    ALLOW OUT   Anywhere (v6)
   123/udp (v6)               ALLOW OUT   Anywhere (v6)
   8285/udp (v6)              ALLOW OUT   Anywhere (v6)
   8472/udp (v6)              ALLOW OUT   Anywhere (v6)
   Anywhere (v6)              ALLOW OUT   Anywhere (v6) on flannel.1
   ```

For details on the ports required to be allowed for Flannel, please see the
[Flannel documentation on firewalls](https://github.com/flannel-io/flannel/blob/master/Documentation/troubleshooting.md#firewalls)
