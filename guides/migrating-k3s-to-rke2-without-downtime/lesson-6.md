---
layout: guide-lesson.liquid
title: Configuring Hetzner vSwitch Networking

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 2
guide_lesson_id: 6
guide_lesson_abstract: >
  Configure the Hetzner vSwitch private network interface on Node 4 to enable secure cluster communication.
guide_lesson_conclusion: >
  Node 4 is now connected to the vSwitch private network and can communicate with the other nodes.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-6.md
---

Hetzner's vSwitch provides Layer 2 private networking between dedicated servers. This is essential for secure
Kubernetes cluster communication without exposing internal traffic to the public internet.

{% include guide-overview-link.liquid.html %}

## Understanding Hetzner vSwitch

A vSwitch creates a private network segment between your servers:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         HETZNER DATACENTER                               │
│                                                                         │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                      vSwitch (VLAN 4000)                        │   │
│   │                    Private: 10.1.1.0/24                         │   │
│   │                                                                 │   │
│   │   Node 1           Node 2           Node 3           Node 4     │   │
│   │   10.1.1.1         10.1.1.2         10.1.1.3         10.1.1.4   │   │
│   │      │                │                │                │       │   │
│   └──────┼────────────────┼────────────────┼────────────────┼───────┘   │
│          │                │                │                │           │
│   ┌──────┴────────────────┴────────────────┴────────────────┴───────┐   │
│   │                     PHYSICAL NETWORK                            │   │
│   │                      Public Internet                            │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

Before proceeding, ensure:

1. **vSwitch is created** in Hetzner Robot console
2. **All servers are added** to the vSwitch
3. **VLAN ID is noted** (we'll use 4000 as an example)
4. **IP range is planned** (we'll use 10.1.1.0/24)

## Identify the Network Interface

First, identify the network interface that connects to the vSwitch:

```bash
# List all network interfaces
ip link show

# Typical output on Hetzner dedicated servers:
# 1: lo: <LOOPBACK,UP,LOWER_UP> ...
# 2: enp0s31f6: <BROADCAST,MULTICAST,UP,LOWER_UP> ...  ← Main interface
# 3: enp4s0: <BROADCAST,MULTICAST> ...                 ← Could be this one

# Check which interface has the public IP
ip addr show
```

The interface connected to the vSwitch is typically a secondary Ethernet interface (e.g., `enp4s0`). If you only
have one interface, you'll create a VLAN subinterface on the main interface.

## Configuration with NetworkManager

Rocky Linux 9 uses NetworkManager for network configuration. We'll create a VLAN interface for the vSwitch.

### Option A: VLAN on Main Interface (Most Common)

If your vSwitch uses VLAN tagging on the main interface:

```bash
# Create VLAN interface
# Replace enp0s31f6 with your actual interface name
# Replace 4000 with your VLAN ID

nmcli connection add \
    type vlan \
    con-name vswitch \
    dev enp0s31f6 \
    id 4000 \
    ipv4.method manual \
    ipv4.addresses 10.1.1.4/24 \
    ipv6.method disabled

# Bring up the connection
nmcli connection up vswitch

# Verify
ip addr show enp0s31f6.4000
```

### Option B: Dedicated Interface (No VLAN Tag)

If you have a dedicated interface for the vSwitch without VLAN tagging:

```bash
# Configure the interface directly
nmcli connection add \
    type ethernet \
    con-name vswitch \
    ifname enp4s0 \
    ipv4.method manual \
    ipv4.addresses 10.1.1.4/24 \
    ipv6.method disabled

# Bring up the connection
nmcli connection up vswitch

# Verify
ip addr show enp4s0
```

### Verify Configuration Files

NetworkManager stores connection files in `/etc/NetworkManager/system-connections/`:

```bash
# View the created connection
cat /etc/NetworkManager/system-connections/vswitch.nmconnection

# Expected content for VLAN configuration:
# [connection]
# id=vswitch
# type=vlan
# interface-name=enp0s31f6.4000
#
# [vlan]
# id=4000
# parent=enp0s31f6
#
# [ipv4]
# address1=10.1.1.4/24
# method=manual
#
# [ipv6]
# method=disabled
```

## Alternative: Manual Configuration

If you prefer manual configuration without NetworkManager:

```bash
# Create network script (legacy method)
cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-vswitch
DEVICE=enp0s31f6.4000
BOOTPROTO=none
ONBOOT=yes
VLAN=yes
IPADDR=10.1.1.4
NETMASK=255.255.255.0
EOF

# Restart NetworkManager
systemctl restart NetworkManager
```

## Test Connectivity

Verify connectivity to other nodes on the vSwitch:

```bash
# Ping other nodes
ping -c 3 10.1.1.1  # Node 1
ping -c 3 10.1.1.2  # Node 2
ping -c 3 10.1.1.3  # Node 3

# If ping fails, check:
# 1. VLAN ID matches in Hetzner Robot
# 2. Server is assigned to vSwitch in Robot console
# 3. Interface is UP
ip link show enp0s31f6.4000
```

## Configure /etc/hosts

Add entries for all cluster nodes:

```bash
cat <<EOF >> /etc/hosts

# Kubernetes Cluster Nodes
10.1.1.1  node1 node1.k8s.example.com
10.1.1.2  node2 node2.k8s.example.com
10.1.1.3  node3 node3.k8s.example.com
10.1.1.4  node4 node4.k8s.example.com
EOF

# Verify
ping -c 1 node1
ping -c 1 node2
ping -c 1 node3
```

## Document Network Configuration

Save the network configuration for reference:

```bash
# Document network setup
cat <<EOF > /root/network-config.txt
=== Node 4 Network Configuration ===
Date: $(date)

Public Interface: enp0s31f6
Public IP: $(ip -4 addr show enp0s31f6 | grep inet | awk '{print $2}')

vSwitch Interface: enp0s31f6.4000
vSwitch VLAN ID: 4000
Private IP: 10.1.1.4/24

DNS Servers: $(cat /etc/resolv.conf | grep nameserver)

Routing Table:
$(ip route)

Other Nodes:
- node1: 10.1.1.1
- node2: 10.1.1.2
- node3: 10.1.1.3
- node4: 10.1.1.4 (this node)
EOF

cat /root/network-config.txt
```

## Troubleshooting

### Interface Not Coming Up

```bash
# Check interface status
nmcli device status

# Check for errors
journalctl -u NetworkManager | tail -20

# Verify VLAN module is loaded
lsmod | grep 8021q
modprobe 8021q
```

### Cannot Ping Other Nodes

```bash
# Verify interface has IP
ip addr show enp0s31f6.4000

# Check if interface is in correct VLAN
ip -d link show enp0s31f6.4000

# Verify in Hetzner Robot that:
# 1. vSwitch exists
# 2. All servers are added to vSwitch
# 3. VLAN ID matches
```

### MTU Issues

If you experience packet loss with large packets:

```bash
# Check current MTU
ip link show enp0s31f6.4000 | grep mtu

# Set MTU (Hetzner vSwitch typically supports 1400)
nmcli connection modify vswitch ethernet.mtu 1400
nmcli connection up vswitch
```

## Network Security Considerations

The vSwitch provides Layer 2 isolation, but consider:

1. **No encryption by default**: Traffic on vSwitch is not encrypted
2. **Layer 2 only**: No routing between vSwitches
3. **Shared infrastructure**: Other Hetzner customers may be on same physical switches

For additional security, RKE2 and Cilium will encrypt cluster traffic. We'll configure this in later lessons.

## Summary

Node 4 now has:

- Rocky Linux 9 with proper kernel configuration
- vSwitch private network interface configured
- Connectivity to all other nodes on the private network

In the next lesson, we'll configure firewalld to allow the necessary Kubernetes traffic.
