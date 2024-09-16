---
layout: post
title: Configuring Load Balancing for the Control Plane (L14)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-14
---

In this lesson, we will discuss the importance of load balancing for the control
plane in a Kubernetes cluster and guide you through choosing and configuring a
suitable load balancer. Load balancing is essential to ensure that your control
plane remains accessible, reliable, and highly available.

This is the second lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-13)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## What is a Load Balancer?

A **Load Balancer** is a device or software application that distributes
incoming network traffic across multiple servers or nodes. In the context of a
Kubernetes cluster, a load balancer ensures that client requests, such as API
calls, are evenly distributed among the control plane nodes. This helps to
prevent any single node from being overwhelmed with too many requests, reducing
the risk of failure and improving overall cluster reliability and performance.
Load balancers also provide failover capabilities, automatically redirecting
traffic to healthy nodes if one or more nodes become unavailable.

## What kind of Load Balancer do you need?

For a Kubernetes control plane, you need a load balancer that can handle traffic
across multiple control plane nodes to ensure high availability. The load
balancer should support **Layer 4 (Transport Layer)** for TCP/UDP traffic to
handle incoming API server requests efficiently. It should also be capable of
**health checking** the control plane nodes to detect any failures and
automatically reroute traffic to healthy nodes. In addition, it should support
**sticky sessions** or **session persistence** to ensure that requests from the
same client are routed to the same control plane node, which can be important
for specific workloads or applications.

## Which Load Balancer to choose?

For a small-scale, self-hosted Kubernetes cluster using Raspberry Pi devices,
there are a few options to consider:

- **Keepalived with HAProxy**: This combination is popular for high availability
  in Kubernetes clusters. **Keepalived** provides a virtual IP address (VIP)
  that floats between control plane nodes, while **HAProxy** acts as a Layer 4
  load balancer to distribute traffic among them. This setup is lightweight,
  easy to configure, and works well in resource-constrained environments like a
  Raspberry Pi cluster.

- **Nginx**: Although primarily known as a web server, **Nginx** can also
  function as a reverse proxy and load balancer. It supports Layer 4 and Layer 7
  load balancing and can be used to handle traffic for the Kubernetes API
  server. Nginx is highly configurable, but it may require more complex setup
  compared to HAProxy.

- **MetalLB**: If you want to implement load balancing entirely within your
  Kubernetes cluster, **MetalLB** is a good choice. It is a load balancer for
  bare-metal Kubernetes clusters that provides a way to expose services
  externally. MetalLB can run in either Layer 2 or BGP mode, but it requires
  careful network configuration and is more suitable if you plan to scale your
  cluster or if you want a native Kubernetes solution.

For this course, we will use **Keepalived with HAProxy** due to its simplicity,
reliability, and low resource requirements, making it ideal for a Raspberry Pi
environment.

## Configuring Keepalived with HAProxy for the Control Plane

To set up Keepalived and HAProxy on your control plane nodes:

1. **Install Keepalived and HAProxy**: On each control plane node, run:

   ```bash
   sudo apt update
   sudo apt install -y keepalived haproxy
   ```

2. **Configure Keepalived**: Edit the Keepalived configuration file on each
   control plane node:

   ```bash
   sudo nano /etc/keepalived/keepalived.conf
   ```

   Use the following sample configuration as a template:

   ```conf
   vrrp_instance VI_1 {
       state MASTER
       interface eth0
       virtual_router_id 51
       priority 100  # Adjust the priority for each node (e.g., 100 for master, 99 for backup)
       advert_int 1
       authentication {
           auth_type PASS
           auth_pass password123
       }
       virtual_ipaddress {
           192.168.1.100  # Replace with your virtual IP address
       }
   }
   ```

   Save the file and restart Keepalived:

   ```bash
   sudo systemctl restart keepalived
   sudo systemctl enable keepalived
   ```

3. **Configure HAProxy**: Edit the HAProxy configuration file on each control
   plane node:

   ```bash
   sudo nano /etc/haproxy/haproxy.cfg
   ```

   Add the following configuration:

   ```conf
   frontend kubernetes-api
       bind 192.168.1.100:6443  # Replace with your virtual IP and port
       default_backend kube-apiservers

   backend kube-apiservers
       balance roundrobin
       server master-1 192.168.1.10:6443 check
       server master-2 192.168.1.11:6443 check
       server master-3 192.168.1.12:6443 check
   ```

   Save the file and restart HAProxy:

   ```bash
   sudo systemctl restart haproxy
   sudo systemctl enable haproxy
   ```

4. **Verify the Load Balancer Setup**: Ensure that the virtual IP is active on
   one of the control plane nodes:
   ```bash
   ip addr show
   ```
   Test the load balancer by accessing the Kubernetes API server via the virtual
   IP:
   ```bash
   curl -k https://192.168.1.100:6443/version
   ```

## Lesson Conclusion

Congratulations! With Keepalived and HAProxy configured, your control plane is
now set up for high availability, and traffic to the Kubernetes API server will
be load balanced across all control plane nodes. In the next lesson, we will
implement redundancy with Keepalived or HAProxy to ensure continuous access to
the control plane even in case of node failures.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-15).
