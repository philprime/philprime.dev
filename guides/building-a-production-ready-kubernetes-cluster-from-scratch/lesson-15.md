---
layout: guide-lesson.liquid
title: Configuring Load Balancing for the Control Plane

guide_component: lesson
guide_id: building-a-production-ready-kubernetes-cluster-from-scratch
guide_section_id: 5
guide_lesson_id: 15
guide_lesson_abstract: >
  Discuss the importance of load balancing for the control plane in a Kubernetes cluster and guide you through choosing
  and configuring a suitable load balancer.
guide_lesson_conclusion: >
  With Keepalived and HAProxy configured, your control plane is now set up for high availability, and traffic to the
  Kubernetes API server will be load balanced across all control plane nodes.
---

In this lesson, we will discuss the importance of load balancing for the control plane in a Kubernetes cluster and guide
you through choosing and configuring a suitable load balancer. Load balancing is essential to ensure that your control
plane remains accessible, reliable, and highly available even in the face of node failures or increased traffic.

{% include guide-overview-link.liquid.html %}

## What is a Load Balancer?

A **Load Balancer** is a device or software application that distributes incoming network traffic across multiple
servers or nodes. In the context of a Kubernetes cluster, a load balancer ensures that client requests, such as API
calls, are evenly distributed among the control plane nodes. This helps to prevent any single node from being
overwhelmed with too many requests, reducing the risk of failure and improving overall cluster reliability and
performance. Load balancers also provide failover capabilities, automatically redirecting traffic to healthy nodes if
one or more nodes become unavailable.

## Why is Load Balancing Important for the Control Plane?

The control plane of a Kubernetes cluster consists of multiple components, such as the API server, controller manager,
and scheduler, running on separate nodes. To ensure high availability and fault tolerance, it is essential to distribute
incoming requests across all control plane nodes. Load balancing helps to achieve this by evenly spreading the load and
providing redundancy in case of node failures. By implementing a load balancer for the control plane, you can ensure
that the Kubernetes API server remains accessible and responsive at all times, even if individual nodes go down or
experience issues.

If you decide to not use a load balancer for the control plane, your control plane nodes will try to access your
Kubernetes API server via a master node's IP address. If that master node goes down, the control plane will be unable to
access the API server, resulting in a loss of control over the cluster.

## What kind of Load Balancer do you need?

For a Kubernetes control plane, you need a load balancer that can handle traffic across multiple control plane nodes to
ensure high availability. The load balancer should support **Layer 4 (Transport Layer)** for TCP/UDP traffic to handle
incoming API server requests efficiently. It should also be capable of **health checking** the control plane nodes to
detect any failures and automatically reroute traffic to healthy nodes. In addition, it should support **sticky
sessions** or **session persistence** to ensure that requests from the same client are routed to the same control plane
node, which can be important for specific workloads or applications.

## Which Load Balancer to choose?

For a small-scale, self-hosted Kubernetes cluster using Raspberry Pi devices, there are a few options to consider:

- **Keepalived with HAProxy**: This combination is popular for high availability in Kubernetes clusters. **Keepalived**
  provides a virtual IP address (VIP) that floats between control plane nodes, while **HAProxy** acts as a Layer 4 load
  balancer to distribute traffic among them. This setup is lightweight, easy to configure, and works well in
  resource-constrained environments like a Raspberry Pi cluster.

- **Nginx**: Although primarily known as a web server, **Nginx** can also function as a reverse proxy and load balancer.
  It supports Layer 4 and Layer 7 load balancing and can be used to handle traffic for the Kubernetes API server. Nginx
  is highly configurable, but it may require more complex setup compared to HAProxy.

- **MetalLB**: If you want to implement load balancing entirely within your Kubernetes cluster, **MetalLB** is a good
  choice. It is a load balancer for bare-metal Kubernetes clusters that provides a way to expose services externally.
  MetalLB can run in either Layer 2 or BGP mode, but it requires careful network configuration and is more suitable if
  you plan to scale your cluster or if you want a native Kubernetes solution.

For this course, we will use **Keepalived with HAProxy** due to its simplicity, reliability, and low resource
requirements, making it ideal for a Raspberry Pi environment.

## Preparing the Kubernetes API Server

By default the Kubernetes API server binds to all network interfaces on the control plane nodes on the port `6443`. You
can verify this by checking the `netstat` output for `:::6443`, which indicates that the API server is listening on all
interfaces:

```bash
$ sudo netstat -tuln | grep 6443
tcp6       0      0 :::6443                 :::*                    LISTEN
```

Before configuring the load balancer, we need to ensure that the Kubernetes API server is binding only to the local IP
address of each control plane node. This is necessary to avoid conflicts when the virtual IP address is assigned by the
load balancer. Edit the Kubernetes API server configuration file:

```bash
$ sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

Locate the `--advertise-address` and `--bind-address` to set both to the local nodes IP address. If the flags do not
exist, add them to the list. For example, if the local IP address of the node is `10.1.1.1`, the flag should look like
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

Afterwards, check the `netstat` output again to verify that the API server is now bound to the local IP address:

```bash
$ sudo netstat -tuln | grep 6443
tcp        0      0 10.1.1.3:6443           0.0.0.0:*               LISTEN
```

To connect to the local API server, you must also configure the `kubectl` client configuration to use the local IP
address of the control plane node. Edit the `~/.kube/config` file and replace the `server` field with the local IP
address of the control plane node:

```yaml
clusters:
  - cluster:
      certificate-authority-data: DATA+OMITTED
      server: https://10.1.1.X:6443
```

```bash
$ kubectl get pods -n kube-system -w -v=6
I0201 18:35:22.919015    8694 loader.go:395] Config loaded from file:  /root/.kube/config
I0201 18:35:22.949778    8694 round_trippers.go:553] GET https://10.1.1.3:6443/api/v1/namespaces/kube-system/pods?limit=500 200 OK in 23 milliseconds
NAME                                        READY   STATUS    RESTARTS       AGE
coredns-7c65d6cfc9-px2jq                    1/1     Running   1 (52m ago)    17h
coredns-7c65d6cfc9-vclq2                    1/1     Running   1 (52m ago)    17h
etcd-kubernetes-node-1                      1/1     Running   5 (52m ago)    14m
etcd-kubernetes-node-2                      1/1     Running   1              30m
etcd-kubernetes-node-3                      1/1     Running   1              10m
kube-apiserver-kubernetes-node-1            1/1     Running   11 (52m ago)   17h
kube-apiserver-kubernetes-node-2            1/1     Running   1              30m
kube-apiserver-kubernetes-node-3            1/1     Running   0              89s
kube-controller-manager-kubernetes-node-1   1/1     Running   1 (52m ago)    17h
kube-controller-manager-kubernetes-node-2   1/1     Running   1              30m
kube-controller-manager-kubernetes-node-3   1/1     Running   79             10m
kube-proxy-2l4px                            1/1     Running   1 (52m ago)    17h
kube-proxy-6l4wr                            1/1     Running   0              10m
kube-proxy-r794n                            1/1     Running   0              30m
kube-scheduler-kubernetes-node-1            1/1     Running   4 (52m ago)    17h
kube-scheduler-kubernetes-node-2            1/1     Running   1              30m
kube-scheduler-kubernetes-node-3            1/1     Running   81             10m
I0201 18:35:22.963015    8694 round_trippers.go:553] GET https://10.1.1.3:6443/api/v1/namespaces/kube-system/pods?resourceVersion=7097&watch=true 200 OK in 1 milliseconds
```

Wait for the API server pod to restart and become ready before proceeding.

```bash
$ curl -k https://10.1.1.X:6443/healthz
ok
```

Repeat this process for all control plane nodes, replacing the IP address with the local IP address of each node.

## Configuring Keepalived

Install Keepalived on each control plane node, by running:

```bash
$ sudo apt install -y keepalived haproxy
```

Configure the Keepalived service on each control plane node to manage the virtual IP address, by editing the
configuration file:

```bash
$ sudo nano /etc/keepalived/keepalived.conf
```

Let's look at the options `we need to configure in the Keepalived configuration:

The section vrrp_instance` defines the VRRP instance configuration, including:

- **state**: Set to `MASTER` for the primary node and `BACKUP` for the secondary node. In our case we are going to use
  the node `1` as the primary node and all other nodes as backup.
- **interface**: Set to the network interface that will be used for the virtual IP address. In our case, it is `eth0`.
- **virtual_router_id**: A unique identifier for the VRRP instance. Ensure that this value is the same across all
  control plane nodes. We can use any number between 1 and 255.
- **priority**: The priority of the node in the VRRP group. The node with the highest priority will become the MASTER
  node. Adjust the priority value for each node, with the primary node having the highest priority. Make sure the
  priority values are unique and consistent across all nodes.
- **advert_int**: The interval in seconds between sending VRRP advertisement packets. The default value is `1`.
- **auth_pass**: The password used for authentication between the nodes. Make sure to use a strong password.
- **virtual_ipaddress**: The virtual IP address that will be used to access the Kubernetes API server. Our network is
  configured with the IP range `10.1.1.0/16`, so we can use an IP address from this range. Let's use `10.1.233.1` as the
  virtual IP address. This IP address should be unique and not used by any other device on the network. It must be the
  same across all control plane nodes.

Furthermore we have to define a `static_ipaddress` block to ensure the virtual IP address is assigned to the network
interface on system boot.

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

For the secondary nodes (nodes `2` and `3`), set the `state` to `BACKUP` and adjust the `priority` accordingly:

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

In order for the Keepalived service to forward network packets properly to the real servers, each router node must have
IP forwarding turned on in the kernel.

Edit the `/etc/sysctl.conf` file to enable IP forwarding by adding or editing the following line:

```conf
net.ipv4.ip_forward = 1
```

Load balancing in HAProxy and Keepalived at the same time also requires the ability to bind to an IP address that are
nonlocal, meaning that it is not assigned to a device on the local system. This allows a running load balancer instance
to bind to an IP that is not local for failover.

To enable, edit the line in `/etc/sysctl.conf` and edit or append the following line:

```conf
net.ipv4.ip_nonlocal_bind = 1
```

Apply the changes to the kernel by running:

```bash
$ sudo sysctl -p
net.ipv4.ip_forward = 1
net.ipv4.ip_nonlocal_bind = 1
```

Before we are able to start the Keepalived service, we need to allow the service to advertise itself via multicast,
which is currently blocked in our firewall settings (managed by `ufw`, as configured in lesson 7).

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
Synchronizing state of keepalived.service with SysV service script with /lib/systemd/systemd-sysv-install.
Executing: /lib/systemd/systemd-sysv-install enable keepalived

$ sudo systemctl status keepalived
● keepalived.service - Keepalive Daemon (LVS and VRRP)
     Loaded: loaded (/lib/systemd/system/keepalived.service; enabled; preset: enabled)
     Active: active (running) since Sat 2025-01-25 15:52:48 CET; 17s ago
       Docs: man:keepalived(8)
             man:keepalived.conf(5)
             man:genhash(1)
             https://keepalived.org
   Main PID: 6993 (keepalived)
      Tasks: 2 (limit: 9566)
     Memory: 3.8M
        CPU: 14ms
     CGroup: /system.slice/keepalived.service
             ├─6993 /usr/sbin/keepalived --dont-fork
             └─6994 /usr/sbin/keepalived --dont-fork

Jan 25 15:52:48 kubernetes-node-3 Keepalived[6993]: Running on Linux 6.6.62+rpt-rpi-2712 #1 SMP PREEMPT Debian 1:6.6.62-1+rpt1 (2024-11-25) (built for Linux 5.19.11)
Jan 25 15:52:48 kubernetes-node-3 Keepalived[6993]: Command line: '/usr/sbin/keepalived' '--dont-fork'
Jan 25 15:52:48 kubernetes-node-3 Keepalived[6993]: Configuration file /etc/keepalived/keepalived.conf
Jan 25 15:52:48 kubernetes-node-3 Keepalived[6993]: NOTICE: setting config option max_auto_priority should result in better keepalived performance
Jan 25 15:52:48 kubernetes-node-3 Keepalived[6993]: Starting VRRP child process, pid=6994
Jan 25 15:52:48 kubernetes-node-3 systemd[1]: keepalived.service: Got notification message from PID 6994, but reception only permitted for main PID 6993
Jan 25 15:52:48 kubernetes-node-3 Keepalived_vrrp[6994]: (/etc/keepalived/keepalived.conf: Line 13) Truncating auth_pass to 8 characters
Jan 25 15:52:48 kubernetes-node-3 Keepalived[6993]: Startup complete
Jan 25 15:52:48 kubernetes-node-3 systemd[1]: Started keepalived.service - Keepalive Daemon (LVS and VRRP).
Jan 25 15:52:48 kubernetes-node-3 Keepalived_vrrp[6994]: (VI_1) Entering BACKUP STATE (init)
```

To make sure the Keepalived service is running correctly, reboot the system to test if the virtual IP address is
assigned to the network interface on system boot.

```bash
$ sudo reboot
```

After the system has rebooted, check the network interfaces to verify that the virtual IP address is assigned:

```bash
$ systemctl status keepalived
● keepalived.service - Keepalive Daemon (LVS and VRRP)
     Loaded: loaded (/lib/systemd/system/keepalived.service; enabled; preset: enabled)
     Active: active (running) since Fri 2025-01-17 17:26:04 CET; 18s ago
       Docs: man:keepalived(8)
             man:keepalived.conf(5)
             man:genhash(1)
             https://keepalived.org
   Main PID: 787 (keepalived)
      Tasks: 2 (limit: 9566)
     Memory: 6.0M
        CPU: 15ms
     CGroup: /system.slice/keepalived.service
             ├─787 /usr/sbin/keepalived --dont-fork
             └─805 /usr/sbin/keepalived --dont-fork

Jan 17 17:26:04 kubernetes-node-1 systemd[1]: keepalived.service: Got notification message from PID 805, but reception only permitted for main PID 787
Jan 17 17:26:04 kubernetes-node-1 Keepalived_vrrp[805]: (/etc/keepalived/keepalived.conf: Line 13) Truncating auth_pass to 8 characters
Jan 17 17:26:04 kubernetes-node-1 Keepalived[787]: Startup complete
Jan 17 17:26:04 kubernetes-node-1 systemd[1]: Started keepalived.service - Keepalive Daemon (LVS and VRRP).
Jan 17 17:26:04 kubernetes-node-1 Keepalived_vrrp[805]: (VI_1) Entering BACKUP STATE (init)
Jan 17 17:26:05 kubernetes-node-1 Keepalived_vrrp[805]: (VI_1) received lower priority (99) advert from 10.1.1.2 - discarding
Jan 17 17:26:06 kubernetes-node-1 Keepalived_vrrp[805]: (VI_1) received lower priority (99) advert from 10.1.1.2 - discarding
Jan 17 17:26:07 kubernetes-node-1 Keepalived_vrrp[805]: (VI_1) received lower priority (99) advert from 10.1.1.2 - discarding
Jan 17 17:26:08 kubernetes-node-1 Keepalived_vrrp[805]: (VI_1) received lower priority (99) advert from 10.1.1.2 - discarding
Jan 17 17:26:08 kubernetes-node-1 Keepalived_vrrp[805]: (VI_1) Entering MASTER STATE

$ sysctl net.ipv4.ip_forward
net.ipv4.ip_forward = 1

$ sysctl net.ipv4.ip_nonlocal_bind
net.ipv4.ip_nonlocal_bind = 1
```

To check if the virtual IP address is assigned to the network interface, run:

```bash
$ ip addr show eth0 | grep 10.1.233.1
    inet 10.1.233.1/32 scope global eth0
```

On the master node, you should see the virtual IP address assigned to the network, while the backup nodes should not
have the virtual IP address assigned.

## Configuring HAProxy

Configure HAProxy to load balance traffic to the Kubernetes API server on each control plane node. Edit the HAProxy
configuration file:

```bash
$ sudo vi /etc/haproxy/haproxy.cfg
```

In this configuration file we need to define two sections: the `frontend` section, which listens for incoming requests
on the virtual IP address and port `6443`, and the `backend` section, which defines the backend servers (control plane
nodes) the requests will be load balanced to.

The frontend will listen on the virtual IP address we defined in the Keepalived configuration `10.1.233.1` on the port
of the Kubernetes API server `6443`. The `mode` is set to `tcp` to enable TLS passthrough, which allows the Kubernetes
API server to handle the TLS termination. The `default_backend` directive specifies the backend servers to which the
requests will be forwarded.

The backend section will define the control plane nodes as servers and specify the load balancing algorithm. In this
example, we use the `roundrobin` algorithm to distribute requests evenly across all control plane nodes. Replace the IP
addresses with the actual IP addresses of your control plane nodes. The `check` option enables health checks on the
backend servers to ensure that only healthy nodes receive traffic. By setting `mode` to `tcp`, HAProxy forwards the TCP
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
Synchronizing state of haproxy.service with SysV service script with /lib/systemd/systemd-sysv-install.
Executing: /lib/systemd/systemd-sysv-install enable haproxy
$ sudo systemctl status haproxy
● haproxy.service - HAProxy Load Balancer
     Loaded: loaded (/lib/systemd/system/haproxy.service; enabled; preset: enabled)
     Active: active (running) since Fri 2025-02-21 21:22:36 CET; 1min 14s ago
...
```

{% include alert.liquid.html type='note' title='Note:' content='
If you decide to add additional nodes later on, which are also part of the control plane, make sure to update the
HAProxy configuration file with the new node information.
' %}

{% include alert.liquid.html type='warning' title='Warning:' content='
If you decide to add additional nodes later on, which are <strong>not</strong> part of the control plane, make sure to
<strong>not</strong> include them in the HAProxy configuration file.
' %}

## Verify the Load Balancer Setup

To verify that the load balancer setup is working correctly, first check the status of the Keepalived service on each
control plane node:

```bash
$ systemctl status keepalived
● keepalived.service - Keepalive Daemon (LVS and VRRP)
     Loaded: loaded (/lib/systemd/system/keepalived.service; enabled; preset: enabled)
     Active: active (running) since Fri 2025-01-17 17:26:04 CET; 1min 37s ago
...
Jan 17 17:26:08 kubernetes-node-1 Keepalived_vrrp[805]: (VI_1) Entering MASTER STATE
```

You should see the status of the Keepalived service as `active (running)` on the primary node and entering the
`MASTER STATE`. The secondary nodes should show the status as `active (running)` and entering the `BACKUP STATE`.

```bash
$ systemctl status keepalived
● keepalived.service - Keepalive Daemon (LVS and VRRP)
     Loaded: loaded (/lib/systemd/system/keepalived.service; enabled; preset: enabled)
     Active: active (running) since Fri 2025-01-17 17:16:20 CET; 12min ago
...
Jan 17 17:25:36 kubernetes-node-2 Keepalived_vrrp[812]: (VI_1) Entering MASTER STATE
Jan 17 17:26:08 kubernetes-node-2 Keepalived_vrrp[812]: (VI_1) Master received advert from 10.1.1.1 with higher priority 100, ours 99
Jan 17 17:26:08 kubernetes-node-2 Keepalived_vrrp[812]: (VI_1) Entering BACKUP STATE
```

Next, check the status of the HAProxy service on each control plane node:

```bash
$ systemctl status haproxy
● haproxy.service - HAProxy Load Balancer
     Loaded: loaded (/lib/systemd/system/haproxy.service; enabled; preset: enabled)
     Active: active (running) since Fri 2025-01-17 17:27:05 CET; 1min 7s ago
...
```

You should see the status of the HAProxy service as `active (running)` on all control plane nodes.

Finally, you can test the reachability of the Kubernetes API server on every node:

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

## Configure Kubernetes to Use the Load Balancer

// TODO: Is this really the way to go?

To ensure that Kubernetes uses the virtual IP address for the API server, you need to update the `kubeconfig` file on
each control plane node. Edit the `kubeconfig` file:

```bash
$ sudo nano /etc/kubernetes/admin.conf
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0t...
    server: https://10.1.1.1:6443
  name: kubernetes
...
```

Locate the `server` field and replace the IP address with the virtual IP address `10.1.233.1`. Save the file and exit
the editor.

Next edit the `~/.kube/config` file to update the `server` field with the virtual IP address, to ensure that the
`kubectl` command uses the virtual IP address:

```bash
$ nano ~/.kube/config
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0t...
    server: https://10.1.1.1:6443
  name: kubernetes
...
```

To verify the changes, run the following command to list all nodes in your cluster and check if the control plane nodes
are listed with a status of `Ready`. By setting the `v` flag to `7`, you can see the verbose output of the `kubectl`
command, which includes the API requests and responses:

```bash
$ kubectl get nodes -v=7
I0117 17:38:34.344933    7174 loader.go:395] Config loaded from file:  /home/pi/.kube/config
I0117 17:38:34.350130    7174 round_trippers.go:463] GET https://10.1.233.1:6443/api/v1/nodes?limit=500
I0117 17:38:34.350174    7174 round_trippers.go:469] Request Headers:
I0117 17:38:34.350190    7174 round_trippers.go:473]     Accept: application/json;as=Table;v=v1;g=meta.k8s.io,application/json;as=Table;v=v1beta1;g=meta.k8s.io,application/json
I0117 17:38:34.350198    7174 round_trippers.go:473]     User-Agent: kubectl/v1.31.4 (linux/arm64) kubernetes/a78aa47
I0117 17:38:34.373393    7174 round_trippers.go:574] Response Status: 200 OK in 23 milliseconds
NAME                STATUS   ROLES           AGE   VERSION
kubernetes-node-1   Ready    control-plane   33m   v1.31.5
kubernetes-node-2   Ready    control-plane   26m   v1.31.4
kubernetes-node-3   Ready    control-plane   27m   v1.31.4
```
