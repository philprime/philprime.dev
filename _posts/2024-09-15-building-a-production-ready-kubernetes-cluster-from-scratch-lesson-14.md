---
layout: course-lesson
title: Configuring Load Balancing for the Control Plane (L14)
tags: cloud kubernetes devops
permalink: /building-a-production-ready-kubernetes-cluster-from-scratch/lesson-14
---

In this lesson, we will discuss the importance of load balancing for the control
plane in a Kubernetes cluster and guide you through choosing and configuring a
suitable load balancer. Load balancing is essential to ensure that your control
plane remains accessible, reliable, and highly available even in the face of
node failures or increased traffic.

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

## Why is Load Balancing Important for the Control Plane?

The control plane of a Kubernetes cluster consists of multiple components, such
as the API server, controller manager, and scheduler, running on separate nodes.
To ensure high availability and fault tolerance, it is essential to distribute
incoming requests across all control plane nodes. Load balancing helps to
achieve this by evenly spreading the load and providing redundancy in case of
node failures. By implementing a load balancer for the control plane, you can
ensure that the Kubernetes API server remains accessible and responsive at all
times, even if individual nodes go down or experience issues.

If you decide to not use a load balancer for the control plane, your control
plane nodes will try to access your Kubernetes API server via a master node's IP
address. If that master node goes down, the control plane will be unable to
access the API server, resulting in a loss of control over the cluster.

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

## Preparing the Kubernetes API Server

By default the Kubernetes API server binds to all network interfaces on the
control plane nodes on the port `6443`. You can verify this by checking the
`netstat` output for `:::6443`, which indicates that the API server is listening
on all interfaces:

```bash
$ sudo netstat -tuln | grep 6443
tcp6       0      0 :::6443                 :::*                    LISTEN
```

Before configuring the load balancer, we need to ensure that the Kubernetes API
server is binding only to the local IP address of each control plane node. This
is necessary to avoid conflicts when the virtual IP address is assigned by the
load balancer. Edit the Kubernetes API server configuration file:

```bash
$ sudo nano /etc/kubernetes/manifests/kube-apiserver.yaml
```

Locate the `--advertise-address` and `--bind-address` to set both to the local
nodes IP address. If the flags do not exist, add them to the list. For example,
if the local IP address of the node is `10.1.1.1`, the flag should look like
this:

```yaml
spec:
  containers:
    - command:
        - kube-apiserver
        - --advertise-address=10.1.1.1
        - --bind-address=10.1.1.1
```

Restart the API server to apply the changes:

```bash
$ sudo systemctl restart kubelet
```

Afterwards, check the `netstat` output again to verify that the API server is
now bound to the local IP address:

```bash
$ sudo netstat -tuln | grep 6443
tcp        0      0 10.1.1.3:6443           0.0.0.0:*               LISTEN
```

```bash
$ kubectl get pods -n kube-system -w
```

Wait for the API server pod to restart and become ready before proceeding.

```bash
$ curl -k https://10.1.1.1:6443/healthz
ok
```

Repeat this process for all control plane nodes, replacing the IP address with
the local IP address of each node.

## Configuring Keepalived

Install Keepalived on each control plane node, by running:

```bash
$ sudo apt install -y keepalived haproxy
```

Configure the Keepalived service on each control plane node to manage the
virtual IP address, by editing the configuration file:

```bash
$ sudo nano /etc/keepalived/keepalived.conf
```

Let's look at the options `we need to configure in the Keepalived configuration:

The section vrrp_instance` defines the VRRP instance configuration, including:

- **state**: Set to `MASTER` for the primary node and `BACKUP` for the secondary
  node. In our case we are going to use the node `1` as the primary node and all
  other nodes as backup.
- **interface**: Set to the network interface that will be used for the virtual
  IP address. In our case, it is `eth0`.
- **virtual_router_id**: A unique identifier for the VRRP instance. Ensure that
  this value is the same across all control plane nodes. We can use any number
  between 1 and 255.
- **priority**: The priority of the node in the VRRP group. The node with the
  highest priority will become the MASTER node. Adjust the priority value for
  each node, with the primary node having the highest priority. Make sure the
  priority values are unique and consistent across all nodes.
- **advert_int**: The interval in seconds between sending VRRP advertisement
  packets. The default value is `1`.
- **auth_pass**: The password used for authentication between the nodes. Make
  sure to use a strong password.
- **virtual_ipaddress**: The virtual IP address that will be used to access the
  Kubernetes API server. Our network is configured with the IP range
  `10.1.1.0/16`, so we can use an IP address from this range. Let's use
  `10.1.233.1` as the virtual IP address. This IP address should be unique and
  not used by any other device on the network. It must be the same across all
  control plane nodes.

Furthermore we have to define a `static_ipaddress` block to ensure the virtual
IP address is assigned to the network interface on system boot.

Here is an example configuration for the primary node (node `1`):

```conf
static_ipaddress {
    10.1.233.1 dev eth0 scope global
}

vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass password123
    }
    virtual_ipaddress {
        10.1.233.1
    }
}
```

For the secondary nodes (nodes `2` and `3`), set the `state` to `BACKUP` and
adjust the `priority` accordingly:

```conf
static_ipaddress {
    10.1.233.1 dev eth0 scope global
}

vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 99 # or 98 for the third node
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass password123
    }
    virtual_ipaddress {
      10.1.233.1
    }
}
```

In order for the Keepalived service to forward network packets properly to the
real servers, each router node must have IP forwarding turned on in the kernel.

Edit the `/etc/sysctl.conf` file to enable IP forwarding by adding or editing
the following line:

```conf
net.ipv4.ip_forward = 1
```

Load balancing in HAProxy and Keepalived at the same time also requires the
ability to bind to an IP address that are nonlocal, meaning that it is not
assigned to a device on the local system. This allows a running load balancer
instance to bind to an IP that is not local for failover.

To enable, edit the line in `/etc/sysctl.conf` and edit or append the following
line:

```conf
net.ipv4.ip_nonlocal_bind = 1
```

Before we are able to start the Keepalived service, we need to allow the service
to advertise itself via multicast, which is currently blocked in our firewall
settings (managed by `ufw`, as configured in lesson 7).

```bash
# Allow incoming VRRP multicast traffic
$ sudo ufw allow in to 224.0.0.18

# Allow outgoing VRRP multicast traffic
$ sudo ufw allow out to 224.0.0.18
```

Enable and start the Keepalived service on each control plane node:

```bash
$ sudo systemctl start keepalived
$ sudo systemctl enable keepalived
```

To make sure the Keepalived service is running correctly, reboot the system to
test if the virtual IP address is assigned to the network interface on system
boot.

```bash
$ sudo reboot
```

After the system has rebooted, check the network interfaces to verify that the
virtual IP address is assigned:

```bash
$ sysctl net.ipv4.ip_forward
net.ipv4.ip_forward = 1

$ sysctl net.ipv4.ip_nonlocal_bind
net.ipv4.ip_nonlocal_bind = 1

$ ip addr show eth0 | grep 10.1.233.1
    inet 10.1.233.1/32 scope global eth0
```

## Configuring HAProxy

Configure HAProxy to load balance traffic to the Kubernetes API server on each
control plane node. Edit the HAProxy configuration file:

```bash
$ sudo nano /etc/haproxy/haproxy.cfg
```

In this configuration file we need to define two sections: the `frontend`
section, which listens for incoming requests on the virtual IP address and port
`6443`, and the `backend` section, which defines the backend servers (control
plane nodes) the requests will be load balanced to.

The frontend will listen on the virtual IP address we defined in the Keepalived
configuration `10.1.233.1` on the port of the Kubernetes API server `6443`. The
`mode` is set to `tcp` to enable TLS passthrough, which allows the Kubernetes
API server to handle the TLS termination. The `default_backend` directive
specifies the backend servers to which the requests will be forwarded.

The backend section will define the control plane nodes as servers and specify
the load balancing algorithm. In this example, we use the `roundrobin` algorithm
to distribute requests evenly across all control plane nodes. Replace the IP
addresses with the actual IP addresses of your control plane nodes. The `check`
option enables health checks on the backend servers to ensure that only healthy
nodes receive traffic. By setting `mode` to `tcp`, HAProxy forwards the TCP
traffic to the control plane nodes and allowing TLS passthrough.

```conf
frontend kubernetes-api
    mode tcp
    bind 10.1.233.1:6443
    default_backend kube-apiservers
    option tcplog

backend kube-apiservers
    mode tcp
    balance roundrobin
    option tcp-check
    default-server inter 3s fall 3 rise 2
    server master-1 10.1.1.1:6443 check
    server master-2 10.1.1.2:6443 check
    server master-3 10.1.1.3:6443 check
```

Save the file and exit the editor.

```bash
$ sudo systemctl restart haproxy
$ sudo systemctl enable haproxy
```

<div class="alert alert-info" role="alert">
    <strong>Note:</strong> If you decide to add additional nodes later on, which are also part of the control plane, make sure to update the HAProxy configuration file with the new node information.

  </div>

<div class="alert alert-warning" role="alert">
  <strong>Warning:</strong> If you decide to add additional nodes later on, which are <strong>not</strong> part of the control plane, make sure to <strong>not</strong> include them in the HAProxy configuration file.
</div>

## Verify the Load Balancer Setup

To verify that the load balancer setup is working correctly, first check the
status of the Keepalived service on each control plane node:

```bash
$ sudo systemctl status keepalived
```

You should see the status of the Keepalived service as `active (running)` on the
primary node and `standby` on the secondary nodes.

Next, check the status of the HAProxy service on each control plane node:

```bash
$ sudo systemctl status haproxy
```

You should see the status of the HAProxy service as `active (running)` on all
control plane nodes.

To verify that the virtual IP address is correctly assigned and the load
balancer is working, you can check the network interfaces on each control plane
node:

```bash
ip addr show
```

It should show the virtual IP address `10.1.233.1` assigned to the `eth0`.

Finally, you can test the reachability of the Kubernetes API server on every
node:

```bash
# Use the IP of the first node
$ curl -k https://10.1.1.1:6443/healthz
ok

# Use the IP of the second node
$ curl -k https://10.1.1.2:6443/healthz
ok

# Use the IP of the third node
$ curl -k https://10.1.1.3:6443/healthz
ok

# Or use the virtual IP address given by Keepalived
$ curl -k https://10.1.233.1:6443/healthz
ok
```

## Lesson Conclusion

Congratulations! With Keepalived and HAProxy configured, your control plane is
now set up for high availability, and traffic to the Kubernetes API server will
be load balanced across all control plane nodes. In the next lesson, we will
implement redundancy with Keepalived or HAProxy to ensure continuous access to
the control plane even in case of node failures.

You have completed this lesson and you can now continue with
[the next one](/building-a-production-ready-kubernetes-cluster-from-scratch/lesson-15).
