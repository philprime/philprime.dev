---
layout: post
title: Implementing Redundancy with Keepalived or HAProxy (L15)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-15
---

In this lesson, we will implement redundancy in the control plane of your
Kubernetes cluster using tools like Keepalived or HAProxy. Redundancy is crucial
to ensure that your control plane remains accessible even if one or more nodes
fail, providing a high-availability setup for critical Kubernetes components.

This is the fifteenth lesson in the series on building a production-ready
Kubernetes cluster from scratch. Make sure you have completed the
[previous lesson](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-14)
before continuing here. The full list of lessons in the series can be found
[in the overview](/building-a-production-ready-kubernetes-cluster-from-scratch).

## Understanding Redundancy for the Control Plane

Redundancy involves creating multiple instances of critical components, such as
the Kubernetes API server, across different control plane nodes. This prevents a
single point of failure and allows the cluster to remain operational even if one
node goes offline. We will use Keepalived to provide a floating virtual IP (VIP)
that can switch between nodes, and HAProxy to distribute traffic evenly across
the control plane nodes.

## Configuring Keepalived for Redundancy

1. **Install Keepalived on Each Control Plane Node:**

   Run the following command on each control plane node:

   ```bash
   sudo apt update
   sudo apt install -y keepalived
   ```

2. **Configure Keepalived for Virtual IP Failover:**

   Edit the Keepalived configuration file on each control plane node:

   ```bash
   sudo nano /etc/keepalived/keepalived.conf
   ```

   Use the following configuration as a template, modifying it for each node:

   ```conf
   vrrp_instance VI_1 {
       state MASTER  # Change this to BACKUP on the secondary nodes
       interface eth0  # Network interface connected to your cluster
       virtual_router_id 51
       priority 100  # Set this higher on the primary node and lower on backups
       advert_int 1
       authentication {
           auth_type PASS
           auth_pass yourpassword
       }
       virtual_ipaddress {
           192.168.1.100  # Replace with your desired virtual IP
       }
   }
   ```

   Save and close the file, then restart Keepalived:

   ```bash
   sudo systemctl restart keepalived
   sudo systemctl enable keepalived
   ```

3. **Verify Keepalived Setup:**

   Ensure that the virtual IP (VIP) is active on the primary control plane node
   by running:

   ```bash
   ip addr show
   ```

   Check that the VIP moves to another node if the primary node goes offline.

## Configuring HAProxy for Traffic Distribution

1. **Install HAProxy on Each Control Plane Node:**

   Run the following command on each control plane node:

   ```bash
   sudo apt update
   sudo apt install -y haproxy
   ```

2. **Configure HAProxy to Load Balance Kubernetes API Traffic:**

   Edit the HAProxy configuration file on each control plane node:

   ```bash
   sudo nano /etc/haproxy/haproxy.cfg
   ```

   Add the following configuration to set up HAProxy for load balancing:

   ```conf
   frontend kubernetes-api
       bind 192.168.1.100:6443  # Replace with your virtual IP and port
       default_backend kube-apiservers

   backend kube-apiservers
       balance roundrobin
       server control-plane-1 192.168.1.10:6443 check
       server control-plane-2 192.168.1.11:6443 check
       server control-plane-3 192.168.1.12:6443 check
   ```

   Save and close the file, then restart HAProxy:

   ```bash
   sudo systemctl restart haproxy
   sudo systemctl enable haproxy
   ```

3. **Test the Load Balancer Configuration:**

   Verify that HAProxy is distributing traffic correctly by running:

   ```bash
   curl -k https://192.168.1.100:6443/version
   ```

   This should return the Kubernetes API server version, confirming that traffic
   is being properly routed through HAProxy.

## Lesson Conclusion

Congratulations! With Keepalived and HAProxy configured, your Kubernetes control
plane is now set up for redundancy and high availability. In the next lesson, we
will test the control plane's high-availability configuration to ensure it
remains functional during node failures.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-16).
