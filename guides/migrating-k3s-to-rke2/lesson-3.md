---
layout: guide-lesson.liquid
title: Configuring Hetzner vSwitch Networking

guide_component: lesson
guide_id: migrating-k3s-to-rke2
guide_section_id: 1
guide_lesson_id: 3
guide_lesson_abstract: >
  Dual-stack networking is nearly impossible to retrofit into an existing Kubernetes cluster, so this lesson tackles it during the initial build.
  We plan IPv4 and IPv6 CIDR allocations for all three Kubernetes networks and configure the Hetzner vSwitch private interface on Node 4.
guide_lesson_conclusion: >
  Node 4 is now connected to the vSwitch with both IPv4 and IPv6 addresses, ready for dual-stack Kubernetes networking.
repo_file_path: guides/migrating-k3s-to-rke2/lesson-3.md
---

Hetzner's vSwitch provides Layer 2 private networking between dedicated servers, allowing cluster nodes to communicate without traversing the public internet.
Before we can use this private network for Kubernetes, we need to make an important architectural decision: should we configure IPv4 only, or invest the extra effort now to support both IPv4 and IPv6?

{% include guide-overview-link.liquid.html %}

## Understanding Dual-Stack Networking

### Why Dual-Stack Matters

Kubernetes networking configuration is deeply embedded in a cluster's DNA.
The CIDR ranges we choose become part of certificates, etcd data, and running workloads, making them nearly impossible to change without rebuilding the entire cluster.
This means that adding IPv6 support later is not a simple configuration change, it requires migrating to a completely new cluster.

Since we are already building a new cluster to migrate from k3s to RKE2, this is the ideal time to future-proof our networking.
Dual-stack gives us IPv4 compatibility for existing services while preparing for the gradual transition to IPv6 as addresses become scarcer and more services adopt the newer protocol.
The additional configuration effort is minimal compared to the cost of rebuilding later.

### Kubernetes Network Architecture

Every Kubernetes cluster operates across three distinct network ranges, each serving a specific purpose and requiring its own CIDR allocation.
The **node network** consists of the actual IP addresses assigned to physical or virtual machines, which are, in our case, the vSwitch addresses we configure in this lesson.
The **pod network** provides addresses for individual containers, with each node receiving a subnet from which it allocates IPs to pods it runs.
The **service network** gives stable virtual IPs to Kubernetes Services, allowing pods to discover and communicate with each other through consistent addresses even as the underlying pods come and go.

These three networks must never overlap, and in a dual-stack cluster each one needs both an IPv4 and IPv6 CIDR range.
We choose our specific allocations in the [CIDR Allocation](#cidr-allocation) section below.

| Network         | Purpose                                            |
| --------------- | -------------------------------------------------- |
| Node Network    | Physical or virtual IPs assigned to cluster nodes  |
| Pod Network     | Virtual IPs assigned to individual pods            |
| Service Network | Virtual IPs for Kubernetes Services (ClusterIP/LB) |

```mermaid!
%%{init: {"theme": "base", "flowchart": {"nodeSpacing": 50, "rankSpacing": 60, "diagramPadding": 30}, "themeVariables": {"fontSize": "12px", "background": "#181818", "textColor": "#c8c8d0", "lineColor": "#505060", "primaryColor": "#2a2a3a", "primaryTextColor": "#e6e6e6", "primaryBorderColor": "#404050", "clusterBkg": "#1e1e28", "clusterBorder": "#3a3a4a", "edgeLabelBackground": "#1e1e28", "titleColor": "#c8c8d0"}}}%%
flowchart TB
classDef svcnet fill:#2e1065,color:#c4b5fd,stroke:#6d28d9
classDef service fill:#7c3aed,color:#ffffff,stroke:#6d28d9
classDef node fill:#2563eb,color:#ffffff,stroke:#1e40af
classDef pod fill:#16a34a,color:#ffffff,stroke:#166534
classDef podnet fill:#065f46,color:#a7f3d0,stroke:#16a34a,stroke-dasharray: 4 4
classDef network fill:#9ca3af,color:#ffffff,stroke:#6b7280

subgraph SVC["Service Network"]
    S1["App Service<br/>10.43.0.10 · fd00:43::10"]
end

subgraph NODE["Node Network"]

    subgraph N1["Node 1 · 10.1.0.11 · fd00::11"]
        subgraph POD1["Pod Network"]
            P1["Pod A<br/>10.42.0.5<br/>fd00:42::5"]
            P2["Pod B<br/>10.42.0.6<br/>fd00:42::6"]
        end
    end

    subgraph N2["Node 2 · 10.1.0.12 · fd00::12"]
        subgraph POD2["Pod Network"]
            P3["Pod C<br/>10.42.1.3<br/>fd00:42:1::3"]
        end
    end

end

S1 -->|Load-balanced| P1
S1 -->|Load-balanced| P3

class SVC svcnet
class S1 service
class NODE network
class N1,N2 node
class P1,P2,P3 pod
class POD1,POD2 podnet
```

The diagram illustrates how these networks interact: each node receives a subnet from the pod CIDR (Node 1 uses `10.42.0.x` while Node 2 uses `10.42.1.x`), and the CNI plugin assigns individual pod addresses from that per-node range.
Services sit above this layer, providing stable virtual IPs that load-balance traffic across pods regardless of which node they run on.

### CNI and Dual-Stack Support

The Container Network Interface (CNI) plugin is responsible for all pod networking, from assigning addresses, configuring routes, to handling network policies.
The choice of CNI directly impacts how well dual-stack works in practice, as not all plugins implement both address families equally well.

RKE2 bundles [Canal](https://docs.rke2.io/networking/basic_network_options) as its default CNI, which combines [Flannel](https://github.com/flannel-io/flannel) for inter-node traffic with [Calico](https://docs.tigera.io/) for intra-node traffic and network policies.
Canal auto-detects dual-stack from the cluster CIDRs and requires no additional configuration.
We use Canal throughout this guide since it is the RKE2 default, supports dual-stack out of the box, and provides Calico's network policy engine for L3-L4 security.

### IP Family Preference

When creating a Kubernetes Service in a dual-stack cluster, we need to decide how it handles the two address families.
Kubernetes offers three policies: `SingleStack` assigns only one family (IPv4 or IPv6), `RequireDualStack` demands both families and fails if either is unavailable, and `PreferDualStack` requests both but gracefully falls back if one is not available.

We configure our cluster CIDRs with IPv4 listed first, making dual-stack available at the network level.
Individual Services default to `SingleStack` (IPv4-only) unless their manifest explicitly sets `ipFamilyPolicy: PreferDualStack`, so existing IPv4-only clients continue working and services that need IPv6 can opt in.
Kubernetes does not offer a cluster-wide setting to change this default, so each Service that needs dual-stack ClusterIPs must declare the policy itself.

### NAT64 Considerations

A common question when planning dual-stack is whether [NAT64](https://en.wikipedia.org/wiki/NAT64) or [DNS64](https://en.wikipedia.org/wiki/DNS64) is needed to reach IPv4-only external services like `github.com` from pods that prefer IPv6.
The answer in a true dual-stack environment is **no**, because every pod has both an IPv4 and an IPv6 address, so when DNS resolution returns only an A record (IPv4), the pod simply uses its IPv4 address to make the connection.
The kernel handles this address family selection automatically based on what DNS returns.

NAT64 becomes necessary only in pure IPv6 environments where nodes have no IPv4 connectivity at all.
Since our Hetzner dedicated servers have both IPv4 and IPv6 on the public interface and we are configuring dual-stack on the vSwitch, this complexity does not apply.

## Hetzner vSwitch Architecture

### How vSwitch Works

Hetzner's vSwitch service creates a private Layer 2 network segment connecting dedicated servers within the same datacenter.
Unlike traffic over the public internet, communication through the vSwitch flows directly between servers at wire speed, never leaving Hetzner's internal infrastructure.
This makes it ideal for Kubernetes cluster traffic where nodes need to exchange large volumes of data with minimal latency.

```mermaid!
%%{init: {"theme": "base", "flowchart": {"nodeSpacing": 30, "rankSpacing": 50, "diagramPadding": 30}, "themeVariables": {"fontSize": "12px", "background": "#181818", "textColor": "#c8c8d0", "lineColor": "#505060", "primaryColor": "#2a2a3a", "primaryTextColor": "#e6e6e6", "primaryBorderColor": "#404050", "clusterBkg": "#1e1e28", "clusterBorder": "#3a3a4a", "edgeLabelBackground": "#1e1e28", "titleColor": "#c8c8d0"}}}%%
flowchart TB
classDef node fill:#2563eb,color:#ffffff,stroke:#1e40af
classDef router fill:#16a34a,color:#ffffff,stroke:#166534
classDef internet fill:#9ca3af,color:#ffffff,stroke:#6b7280

subgraph DC["Hetzner Datacenter"]
    subgraph NODES[" "]
        direction LR
        N1["Node 1<br/>135.181.x.x<br/>10.1.0.11 · fd00::11"]
        N2["Node 2<br/>135.181.x.x<br/>10.1.0.12 · fd00::12"]
        N1 -- "vSwitch traffic · VLAN 4000" --- N2
    end
    R["Switch"]
    NODES --- R
end

PN["Public Internet"]
R --- PN

N1 -. "public traffic" .-> R -. "public traffic" .-> PN

class N1,N2 node
class R router
class PN internet
```

The diagram shows how each server maintains two distinct network paths: a connection to the public internet for external traffic, and the private vSwitch for inter-node communication.
Since vSwitch uses VLAN tagging to separate traffic from other customers, we need to create a VLAN subinterface on each node to access it.

### Security Characteristics

While the vSwitch provides logical isolation through VLAN tagging, it is important to understand what this means for security.
The physical network infrastructure is shared across Hetzner customers, with VLAN segmentation preventing direct access between tenants, but the traffic itself travels unencrypted over the shared switches.
This is generally acceptable for a private datacenter network, but for defense in depth we add encryption at the cluster level using Canal's [WireGuard](https://www.wireguard.com/) support in [Lesson 6](/guides/migrating-k3s-to-rke2/lesson-6).

### ULA Addresses for IPv6

For our private IPv6 addresses, we use [Unique Local Addresses (ULA)](https://datatracker.ietf.org/doc/html/rfc4193) from the `fd00::/8` range.
Think of ULA as the IPv6 equivalent of familiar private IPv4 ranges like `10.0.0.0/8` or `192.168.0.0/16` which are guaranteed not to be routable on the public internet, making them safe to use for internal cluster communication without worrying about conflicts with globally routable addresses.

## Planning the Network

### CIDR Allocation

Before touching any configuration files, we need to document our chosen CIDR ranges.
These values appear in multiple places throughout the cluster setup (vSwitch configuration, RKE2 settings, and firewall rules) and inconsistencies between them are a common source of subtle networking failures that can be difficult to debug.

| Network         | IPv4 CIDR      | IPv6 CIDR       | Purpose                  |
| --------------- | -------------- | --------------- | ------------------------ |
| Node Network    | `10.1.0.0/16`  | `fd00::/64`     | vSwitch inter-node comms |
| Pod Network     | `10.42.0.0/16` | `fd00:42::/56`  | IP addresses for pods    |
| Service Network | `10.43.0.0/16` | `fd00:43::/112` | ClusterIP services       |

{% include alert.liquid.html type='warning' title='CIDRs Cannot Be Changed Later' content='
The pod and service CIDRs are baked into certificates, etcd data, and running workloads at cluster creation time.
Changing them requires rebuilding the cluster from scratch.
' %}

#### Understanding IPv6 CIDR Sizing

Kubernetes allocates each node a `/64` subnet from the cluster's pod CIDR, and a `/64` contains 2^64 addresses, a number so vast that even running 10,000 pods on a single node would use a negligible fraction.
The practical limit on pods per node comes from CPU, memory, and kubelet configuration, not from address space.

The real constraint is how many `/64` subnets fit within the cluster's pod CIDR:

| Cluster Pod CIDR | Max Nodes (with /64 per node) |
| ---------------- | ----------------------------- |
| `/56`            | 256                           |
| `/52`            | 4,096                         |
| `/48`            | 65,536                        |

We have chosen `/56` for this guide because 256 nodes comfortably exceeds what most organizations need, even accounting for growth.
If building infrastructure that might eventually scale beyond that, consider using `/48` instead. There is no practical downside to the larger range, just a longer prefix to type.

For the service network, `/112` provides 65,536 addresses, deliberately matching the capacity of our IPv4 `/16` service range.
Most clusters use only a few hundred services at most, so this is more than sufficient.

### Node Address Assignment

For clarity and easier troubleshooting, we assign each node a consistent address across both address families.
Using the same final number (node1 gets `.11` and `::11`, node2 gets `.12` and `::12`) makes it obvious which addresses belong to which node when debugging network issues at 2 AM.

We start at `.11` rather than `.1` because the Hetzner Cloud network gateway claims the first address in the subnet (`.1`) when a Hetzner Cloud network is attached to the vSwitch, as we do in [Lesson 8](/guides/migrating-k3s-to-rke2/lesson-8) for the load balancer.
Starting at `.11` leaves `.1` through `.10` available for infrastructure.

| Node  | IPv4 Address | IPv6 Address |
| ----- | ------------ | ------------ |
| node1 | `10.1.0.11`  | `fd00::11`   |
| node2 | `10.1.0.12`  | `fd00::12`   |
| node3 | `10.1.0.13`  | `fd00::13`   |
| node4 | `10.1.0.14`  | `fd00::14`   |

### Ingress Planning

Whatever ingress controller and load balancer we choose must support dual-stack from day one. Retrofitting this later creates the same migration headaches we discussed earlier with Kubernetes networking itself.
[Traefik](https://traefik.io/traefik) handles dual-stack natively without special configuration, and Hetzner's [Cloud Load Balancer](https://www.hetzner.com/cloud/load-balancer/) can target both IPv4 and IPv6 backends.
If we prefer [MetalLB](https://metallb.io/) for bare-metal load balancing, it requires separate address pools for each address family.

We configure Traefik with the Hetzner Cloud Load Balancer in [Lesson 8](/guides/migrating-k3s-to-rke2/lesson-8), but keep these requirements in mind when substituting different components.

### Existing Infrastructure

If following this guide with an existing k3s cluster, the nodes likely already have IPv4 addresses on the vSwitch but no IPv6 yet.
We configure Node 4 with dual-stack from the start and add IPv6 to the existing nodes when we migrate each one to RKE2 in later lessons.
This approach avoids touching the running k3s cluster's networking until we are ready to migrate each node.

## Prerequisites

Before proceeding with the configuration, we need to verify that the Hetzner infrastructure is ready.
The vSwitch should already be created in the Hetzner Robot console, with all servers added to it and the VLAN ID noted (we use `4000` throughout this guide, but the actual value may differ).
The chosen IP ranges shown in the tables above should be documented, as we reference them repeatedly throughout the configuration process.

## Configuring the vSwitch Interface

With the planning complete, we can now configure the actual network interface.
The vSwitch appears as a VLAN on the server's physical network interface, so the first step is identifying which interface to use.

### Identifying the Network Interface

List the network interfaces on the server to see what is available:

```bash
$ ip link show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: enp5s0f3u2u2c2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN mode DEFAULT group default qlen 1000
    link/ether 4a:d7:b5:34:aa:ce brd ff:ff:ff:ff:ff:ff
    altname enx4ad7b534aace
3: enp195s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP mode DEFAULT group default qlen 1000
    link/ether d4:5d:64:08:e8:30 brd ff:ff:ff:ff:ff:ff
    altname enxd45d6408e830
4: tailscale0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1280 qdisc fq_codel state UNKNOWN mode DEFAULT group default qlen 500
    link/none
```

The interface names vary depending on server hardware, but we are looking for the one carrying the public IP address.
Running `ip addr show` reveals which interface has an address like `135.181.x.x`. That is the main network interface, and the vSwitch VLAN will be created as a subinterface on it.

```bash
$ ip addr show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute
       valid_lft forever preferred_lft forever
2: enp5s0f3u2u2c2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN group default qlen 1000
    link/ether 4a:d7:b5:34:aa:ce brd ff:ff:ff:ff:ff:ff
    altname enx4ad7b534aace
    inet6 fe80::d9e6:c53b:7c65:ca8c/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
3: enp195s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether d4:5d:64:08:e8:30 brd ff:ff:ff:ff:ff:ff
    altname enxd45d6408e830
    inet 135.181.XX.XX/26 brd 135.181.XX.255 scope global dynamic noprefixroute enp195s0
       valid_lft 31318sec preferred_lft 31318sec
    inet6 fe80::81d8:8f88:4416:3876/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
4: tailscale0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1280 qdisc fq_codel state UNKNOWN group default qlen 500
    link/none
    inet 100.122.121.38/32 scope global tailscale0
       valid_lft forever preferred_lft forever
    inet6 fd7a:115c:a1e0::e332:7926/128 scope global
       valid_lft forever preferred_lft forever
    inet6 fe80::4b3c:4678:6c60:e7b1/64 scope link stable-privacy proto kernel_ll
       valid_lft forever preferred_lft forever
```

### Creating the VLAN Interface

Rocky Linux 10 uses NetworkManager for all network configuration, which makes creating VLAN interfaces straightforward.
The following command creates a new VLAN subinterface with both IPv4 and IPv6 addresses configured.
Replace `enp195s0` with your actual interface name, `4000` with your VLAN ID, and the addresses with your node's assigned IPs from the table above.

```bash
$ sudo nmcli connection add \
    type vlan \
    con-name vswitch \
    dev enp195s0 \
    id 4000 \
    ipv4.method manual \
    ipv4.addresses 10.1.0.14/16 \
    ipv4.routes "10.0.0.0/24 10.1.0.1" \
    ipv6.method manual \
    ipv6.addresses fd00::14/64
Connection 'vswitch' (2ecf2e01-122a-4ce2-b786-f4d41fe459cf) successfully added.
```

The `ipv4.routes` line adds a static route for the Hetzner Cloud subnet (`10.0.0.0/24`) via the Cloud Network gateway at `10.1.0.1`.
Without this route, return traffic from the node cannot reach the load balancer's private IP and health checks will fail when we attach a Hetzner Cloud Load Balancer to the vSwitch.
The gateway at `10.1.0.1` is created automatically by Hetzner when a Cloud Network is attached to the vSwitch.

After bringing up the connection, verify that both addresses are properly assigned:

```bash
$ sudo nmcli connection up vswitch
Connection successfully activated (D-Bus active path: /org/freedesktop/NetworkManager/ActiveConnection/1997)

$ ip addr show enp195s0.4000
5: enp195s0.4000@enp195s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether d4:5d:64:08:e8:30 brd ff:ff:ff:ff:ff:ff
    inet 10.1.0.14/16 brd 10.1.255.255 scope global noprefixroute enp195s0.4000
       valid_lft forever preferred_lft forever
    inet6 fd00::14/64 scope global noprefixroute
       valid_lft forever preferred_lft forever
    inet6 fe80::cad:c5f2:6cc4:d67b/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
```

We should see both an `inet` line with the IPv4 address `10.1.0.14/16` and an `inet6` line with the IPv6 ULA address `fd00::14/64`.
If either is missing, check the nmcli command for typos before proceeding.

### Configuring Public IPv6

Hetzner assigns each dedicated server an IPv6 subnet (typically a `/64`), but Rocky Linux's default DHCP configuration only picks up the IPv4 address automatically.

{% include alert.liquid.html type='warning' title='Required for Dual-Stack' content='
Without a public IPv6 address and default route, Canal cannot detect a valid IPv6 interface and pods will have no outbound IPv6 connectivity.
Do not skip this step if you are configuring dual-stack.
' %}

The assigned IPv6 subnet is available in the Hetzner Robot panel under the server's IPs tab.
Replace `"Wired connection 1"` with your connection name (run `nmcli connection` to check) and the address with your assigned IPv6 from Hetzner.
Hetzner uses `fe80::1` as the IPv6 gateway across all dedicated servers.

```bash
$ nmcli connection modify "Wired connection 1" \
    ipv6.method manual \
    ipv6.addresses "2a01:4f9:XX:XX::2/64" \
    ipv6.gateway "fe80::1"
$ nmcli connection up "Wired connection 1"
```

After applying the change, verify that both the address and default route are in place:

```bash
$ ip -6 addr show dev enp195s0
3: enp195s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    altname enxd45d6408e830
    inet6 2a01:4f9:XX:XX::2/64 scope global noprefixroute
       valid_lft forever preferred_lft forever
    inet6 fe80::81d8:8f88:4416:3876/64 scope link noprefixroute
       valid_lft forever preferred_lft forever

$ ip -6 route show default
default via fe80::1 dev enp195s0 proto static metric 103 pref medium
```

The public IPv6 address should appear with `scope global` and a default route via `fe80::1`.

### Enabling IPv6 Forwarding

IP forwarding controls whether the Linux kernel routes packets between network interfaces or drops them.
When forwarding is disabled, the kernel only processes traffic addressed directly to the host itself.
Any packet arriving on one interface that needs to reach a different interface (or a different host via that interface) is silently discarded.

Kubernetes nodes act as routers for pod traffic.
A pod on Node 1 sending traffic to a pod on Node 2 generates a packet on the pod's virtual interface that must cross the node's network stack and leave through the vSwitch interface toward the other node.
Without forwarding enabled, the kernel refuses to pass that packet between interfaces and the connection fails.

IPv4 forwarding is typically enabled by RKE2 automatically, but IPv6 forwarding must be configured explicitly in the kernel:

```bash
$ sudo tee /etc/sysctl.d/99-ipv6-forward.conf <<EOF
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
EOF

$ sudo sysctl -p /etc/sysctl.d/99-ipv6-forward.conf
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
```

## Verifying Connectivity

As a final check, ping one of the existing nodes over the vSwitch to confirm the VLAN interface is working:

```bash
$ ping -c 3 10.1.0.11
PING 10.1.0.11 (10.1.0.11) 56(84) bytes of data.
64 bytes from 10.1.0.11: icmp_seq=1 ttl=64 time=0.351 ms
64 bytes from 10.1.0.11: icmp_seq=2 ttl=64 time=0.182 ms
64 bytes from 10.1.0.11: icmp_seq=3 ttl=64 time=0.175 ms

--- 10.1.0.11 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2027ms
rtt min/avg/max/mdev = 0.175/0.236/0.351/0.081 ms
```

Zero packet loss confirms that Node 4 can reach the existing cluster over the vSwitch.
IPv6 connectivity testing is not possible yet because the other nodes do not have IPv6 on their vSwitch interfaces.
We verify full dual-stack connectivity in [Lesson 11](/guides/migrating-k3s-to-rke2/lesson-11) when the first existing node joins the new cluster with IPv6 configured.
