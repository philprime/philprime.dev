---
layout: course-lesson
title: Installing a Pod Network (CNI Plugin) (L13)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-13
---

In this lesson, we will install a Container Network Interface (CNI) plugin to
enable communication between the pods running on different nodes in your
Kubernetes cluster. The CNI plugin is essential for networking in Kubernetes, as
it ensures that all pods can communicate securely and efficiently across the
cluster.

This is the thirteenth lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-12)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## What is a CNI Plugin?

A **CNI (Container Network Interface) plugin** is a critical component in
Kubernetes that facilitates networking for containers running across multiple
nodes in a cluster. It provides the necessary networking capabilities to allow
pods (the smallest deployable units in Kubernetes) to communicate with each
other and with services both inside and outside the cluster. A CNI plugin works
by configuring the network interfaces of containers and managing the underlying
network policies, routes, and IP address assignments to ensure that all
containers can communicate seamlessly and securely.

## Why Choose Flannel as the CNI Plugin?

We chose **Flannel** as our CNI plugin for this course because it is
lightweight, simple to set up, and well-suited for use with resource-constrained
environments like Raspberry Pi devices. Flannel creates a virtual overlay
network that connects all pods across the cluster, ensuring that each pod gets a
unique IP address from a pre-defined CIDR range. This setup simplifies
networking by abstracting the complexities of the underlying network
infrastructure, making it easier to deploy and manage a Kubernetes cluster.
Flannel is also highly compatible with Kubernetes and requires minimal
configuration, which makes it an ideal choice for those who are new to
Kubernetes or working with smaller clusters.

## Install the Flannel CNI Plugin

To install Flannel, run the following command on any of the control plane nodes:

```bash
$ kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

This command downloads the Flannel manifest file from the official GitHub page
and applies it to your cluster. The manifest file contains the necessary
configurations to deploy Flannel across all nodes in your cluster.

## Verify the CNI Plugin Installation

To confirm that Flannel is correctly installed, check the status of the pods in
the `kube-flannel` namespace:

```bash
$ kubectl get pods -n kube-flannel -o wide
NAME                    READY   STATUS    RESTARTS      AGE   IP         NODE                NOMINATED NODE   READINESS GATES
kube-flannel-ds-4c28n   1/1     Running   0             1m    10.1.1.2   kubernetes-node-2   <none>           <none>
kube-flannel-ds-8d9tg   1/1     Running   0             1m    10.1.1.1   kubernetes-node-1   <none>           <none>
kube-flannel-ds-j8xnq   1/1     Running   0             1m    10.1.1.3   kubernetes-node-3   <none>           <none>
```

You should see several `kube-flannel-ds` pods, one for each node, with a status
of "Running". This indicates that Flannel is successfully deployed and operating
across all nodes.

## Check the Pod Network CIDR

Ensure the pod network CIDR matches the one specified during control plane
initialization (`10.244.0.0/16` for Flannel). You can check this by looking at
the cluster configuration:

```bash
$ kubectl cluster-info dump | grep -m 1 cluster-cidr
                            "--cluster-cidr=10.244.0.0/16",
```

The output should confirm the correct CIDR range we configured for Flannel.

## Allow Flannel Traffic Through the Firewall

1. Flannel uses UDP ports `8285` and `8472` for backend communication between
   nodes. Ensure these ports are open in the firewall on every single node, to
   allow Flannel to function correctly:

   ```bash
   # Allowing Flannel UDP backend traffic
   $ sudo ufw allow 8285/udp
   $ sudo ufw allow out 8285/udp

   # Allow Flannel VXLAN backend traffic
   $ sudo ufw allow 8472/udp
   $ sudo ufw allow out 8472/udp
   ```

2. Next up, we need to allow traffic from our pod network CIDR range
   (`10.244.0.0/16`). This is necessary for the pods to communicate with each
   other across nodes:

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

5. Enable packet forwarding in the kernel. Open the `sysctl.conf` file for and
   uncomment the following lines to route packets between interfaces:

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

## Verify connection and network speed between pods

To test the network speed between pods, you can use the `iperf3` tool. This tool
allows you to measure the network bandwidth between two pods in your cluster.

1. To deploy the `iperf3` server pod on every node at the same time, we can use
   a Kubernetes `DaemonSet`. Connect to one of your nodes and create a file
   named `iperf3-daemonset.yaml` with the following content (e.g. using `nano`
   or `vi`):

   ```yaml
   apiVersion: apps/v1
   kind: DaemonSet
   metadata:
     name: iperf3
   spec:
     selector:
       matchLabels:
         app: iperf3
     template:
       metadata:
         labels:
           app: iperf3
       spec:
         containers:
           - name: iperf3
             image: networkstatic/iperf3
             ports:
               - containerPort: 5201
             command: ['iperf3']
             args: ['-s'] # Run in server mode
   ```

2. Apply the DaemonSet configuration to deploy the `iperf3` server pods:

   ```bash
   $ kubectl apply -f iperf3-daemonset.yaml
   ```

3. Get the list of pods to verify that the `iperf3` server pods are running:

   ```bash
   $ kubectl get pods -l app=iperf3 -o wide
   NAME           READY   STATUS    RESTARTS   AGE     IP           NODE                NOMINATED NODE   READINESS GATES
   iperf3-b7tp5   1/1     Running   0          5m45s   10.244.0.6   kubernetes-node-1   <none>           <none>
   iperf3-g4k2b   1/1     Running   0          5m45s   10.244.2.4   kubernetes-node-3   <none>           <none>
   iperf3-zztwd   1/1     Running   0          5m45s   10.244.1.5   kubernetes-node-2   <none>           <none>
   ```

4. Create an interactive shell session in one of the `iperf3` server pods to
   check the network speed:

   ```bash
   $ kubectl exec -it iperf3-b7tp5 -- /bin/bash
   ```

5. Run the following command to test the network speed to one of the other
   `iperf3` server pods:

   ```bash
   root@iperf3-pgt7j:/# iperf3 -c 10.244.2.9
   Connecting to host 10.244.2.9, port 5201
   [  5] local 10.244.0.9 port 48980 connected to 10.244.2.9 port 5201
   [ ID] Interval           Transfer     Bitrate         Retr  Cwnd
   [  5]   0.00-1.00   sec   111 MBytes   933 Mbits/sec    0   3.87 MBytes
   [  5]   1.00-2.00   sec   109 MBytes   912 Mbits/sec    0   3.87 MBytes
   [  5]   2.00-3.00   sec   109 MBytes   912 Mbits/sec    0   3.87 MBytes
   [  5]   3.00-4.00   sec   108 MBytes   902 Mbits/sec    0   3.87 MBytes
   [  5]   4.00-5.00   sec   109 MBytes   912 Mbits/sec    0   3.87 MBytes
   [  5]   5.00-6.00   sec   108 MBytes   902 Mbits/sec    0   3.87 MBytes
   [  5]   6.00-7.00   sec   109 MBytes   912 Mbits/sec    0   3.87 MBytes
   [  5]   7.00-8.00   sec   109 MBytes   912 Mbits/sec    0   3.87 MBytes
   [  5]   8.00-9.00   sec   109 MBytes   912 Mbits/sec    0   3.87 MBytes
   [  5]   9.00-10.00  sec   108 MBytes   902 Mbits/sec    0   3.87 MBytes
   - - - - - - - - - - - - - - - - - - - - - - - - -
   [ ID] Interval           Transfer     Bitrate         Retr
   [  5]   0.00-10.00  sec  1.06 GBytes   911 Mbits/sec    0             sender
   [  5]   0.00-10.03  sec  1.06 GBytes   909 Mbits/sec                  receiver

   iperf Done.
   ```

6. Cleanup the `iperf3` server pods after you are done testing:

   ```bash
   $ kubectl delete -f iperf3-daemonset.yaml
   $ rm iperf3-daemonset.yaml
   ```

## Lesson Conclusion

Congratulations! With the CNI plugin installed and verified, your Kubernetes
cluster is now ready to support communication between all pods across nodes. In
the next lesson, we will focus on setting up high availability for the control
plane to ensure that your cluster remains resilient and accessible.

You have completed this lesson and you can now continue with
[the next section](/building-a-production-ready-kubernetes-cluster-from-scratch/section-5).
