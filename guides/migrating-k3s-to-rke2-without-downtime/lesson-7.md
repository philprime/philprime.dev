---
layout: guide-lesson.liquid
title: Firewall Configuration for Dual-Stack

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 2
guide_lesson_id: 7
guide_lesson_abstract: >
  Configure firewalld on Node 4 to allow RKE2, Cilium, and Kubernetes traffic over both IPv4 and IPv6.
guide_lesson_conclusion: >
  The firewall is configured for dual-stack traffic, allowing Kubernetes communication over both IPv4 and IPv6.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-7.md
---

Proper firewall configuration is critical for a secure Kubernetes cluster.
In this lesson, we'll configure firewalld to allow necessary traffic over both IPv4 and IPv6 while maintaining security.

{% include guide-overview-link.liquid.html %}

## Firewalld and Dual-Stack

Rocky Linux 10 uses firewalld as its default firewall manager.
The good news is that firewalld handles both IPv4 and IPv6 automatically for most rules.
Port and service rules apply to both protocols by default.

```bash
# Check firewalld status
systemctl status firewalld

# If not running, start and enable it
systemctl enable --now firewalld

# Check current configuration
firewall-cmd --state
firewall-cmd --get-active-zones
firewall-cmd --list-all
```

## Required Ports Overview

RKE2 with Cilium requires these ports to be open between cluster nodes:

| Port      | Protocol | Component       | Description                         |
| --------- | -------- | --------------- | ----------------------------------- |
| 22        | TCP      | SSH             | Remote administration               |
| 6443      | TCP      | Kubernetes API  | kubectl and API access              |
| 9345      | TCP      | RKE2 Supervisor | Node registration                   |
| 2379-2380 | TCP      | etcd            | Cluster state (control planes only) |
| 10250     | TCP      | Kubelet         | Pod logs, exec, metrics             |
| 8472      | UDP      | Cilium VXLAN    | Pod network overlay                 |
| 4240      | TCP      | Cilium Health   | Cluster connectivity checks         |
| 4244      | TCP      | Hubble Relay    | Cilium observability (optional)     |
| 4245      | TCP      | Hubble UI       | Cilium observability (optional)     |

All ports need to be accessible over both IPv4 and IPv6.

## Create a Kubernetes Zone

Create a dedicated zone for Kubernetes traffic on the vSwitch interface:

```bash
# Create a new zone for internal Kubernetes traffic
firewall-cmd --permanent --new-zone=kubernetes

# Set the vSwitch interface to the kubernetes zone
firewall-cmd --permanent --zone=kubernetes --add-interface=enp0s31f6.4000

# Reload to apply zone creation
firewall-cmd --reload
```

## Configure Control Plane Ports

Since Node 4 will be a control plane node, it needs all control plane ports.
These rules automatically apply to both IPv4 and IPv6:

```bash
# Kubernetes API Server
firewall-cmd --permanent --zone=kubernetes --add-port=6443/tcp

# RKE2 Supervisor API (for node registration)
firewall-cmd --permanent --zone=kubernetes --add-port=9345/tcp

# etcd server client API
firewall-cmd --permanent --zone=kubernetes --add-port=2379/tcp

# etcd peer communication
firewall-cmd --permanent --zone=kubernetes --add-port=2380/tcp

# Kubelet API
firewall-cmd --permanent --zone=kubernetes --add-port=10250/tcp

# Kubelet read-only (optional, for metrics)
firewall-cmd --permanent --zone=kubernetes --add-port=10255/tcp
```

## Configure Cilium CNI Ports

Cilium requires specific ports for its eBPF-based networking:

```bash
# Cilium VXLAN overlay network
firewall-cmd --permanent --zone=kubernetes --add-port=8472/udp

# Cilium health checks
firewall-cmd --permanent --zone=kubernetes --add-port=4240/tcp

# Cilium Hubble (observability - optional but recommended)
firewall-cmd --permanent --zone=kubernetes --add-port=4244/tcp
firewall-cmd --permanent --zone=kubernetes --add-port=4245/tcp

# Cilium agent health
firewall-cmd --permanent --zone=kubernetes --add-port=9879/tcp

# Cilium operator metrics (optional)
firewall-cmd --permanent --zone=kubernetes --add-port=9963/tcp
firewall-cmd --permanent --zone=kubernetes --add-port=9964/tcp
```

## Configure NodePort Range

Kubernetes services of type NodePort use ports 30000-32767 by default:

```bash
# Allow NodePort range for services
firewall-cmd --permanent --zone=kubernetes --add-port=30000-32767/tcp
firewall-cmd --permanent --zone=kubernetes --add-port=30000-32767/udp
```

## Configure Ingress Ports

For our Traefik ingress controller running as a DaemonSet:

```bash
# Traefik NodePort for HTTP (will be load balanced)
firewall-cmd --permanent --zone=kubernetes --add-port=30080/tcp

# Traefik NodePort for HTTPS (will be load balanced)
firewall-cmd --permanent --zone=kubernetes --add-port=30443/tcp
```

## Configure Public Zone

The public zone handles traffic from the internet via the public IP:

```bash
# Ensure SSH remains accessible
firewall-cmd --permanent --zone=public --add-service=ssh

# Allow HTTP/HTTPS for ingress (if using public IPs directly)
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https
```

## Allow ICMP and ICMPv6

Both ICMP (IPv4) and ICMPv6 are essential for network diagnostics.
ICMPv6 is particularly important as it handles neighbor discovery, which IPv6 requires to function:

```bash
# Allow ICMPv4 (ping)
firewall-cmd --permanent --zone=kubernetes --add-protocol=icmp

# Allow ICMPv6 (required for IPv6 neighbor discovery)
firewall-cmd --permanent --zone=kubernetes --add-protocol=ipv6-icmp
```

{% include alert.liquid.html type='warning' title='ICMPv6 is Required' content='
Unlike IPv4 where ICMP is optional, IPv6 requires ICMPv6 for basic functionality.
Blocking ICMPv6 will break IPv6 neighbor discovery and cause connectivity failures.
' %}

## Configure Masquerading

Enable masquerading for pod network traffic on both protocols:

```bash
# Enable masquerading on kubernetes zone (applies to both IPv4 and IPv6)
firewall-cmd --permanent --zone=kubernetes --add-masquerade
```

## Apply All Changes

```bash
# Reload firewalld to apply all changes
firewall-cmd --reload

# Verify configuration
firewall-cmd --zone=kubernetes --list-all
```

Expected output:

```
kubernetes (active)
  target: default
  icmp-block-inversion: no
  interfaces: enp0s31f6.4000
  sources:
  services:
  ports: 6443/tcp 9345/tcp 2379/tcp 2380/tcp 10250/tcp 10255/tcp 8472/udp 4240/tcp 4244/tcp 4245/tcp 9879/tcp 30000-32767/tcp 30000-32767/udp 30080/tcp 30443/tcp
  protocols: icmp ipv6-icmp
  forward: yes
  masquerade: yes
  forward-ports:
  source-ports:
  icmp-blocks:
  rich rules:
```

## Create Firewall Script

For convenience and documentation, create a script that can recreate the firewall configuration:

```bash
cat <<'EOF' > /root/setup-firewall.sh
#!/bin/bash
# Kubernetes Dual-Stack Firewall Configuration Script

set -e

echo "Configuring firewalld for dual-stack Kubernetes..."

# Ensure firewalld is running
systemctl enable --now firewalld

# Create kubernetes zone if it doesn't exist
firewall-cmd --permanent --new-zone=kubernetes 2>/dev/null || true

# Add interface to kubernetes zone
firewall-cmd --permanent --zone=kubernetes --add-interface=enp0s31f6.4000

# Control plane ports
firewall-cmd --permanent --zone=kubernetes --add-port=6443/tcp   # API Server
firewall-cmd --permanent --zone=kubernetes --add-port=9345/tcp   # RKE2 Supervisor
firewall-cmd --permanent --zone=kubernetes --add-port=2379/tcp   # etcd client
firewall-cmd --permanent --zone=kubernetes --add-port=2380/tcp   # etcd peer
firewall-cmd --permanent --zone=kubernetes --add-port=10250/tcp  # Kubelet

# Cilium ports
firewall-cmd --permanent --zone=kubernetes --add-port=8472/udp   # VXLAN
firewall-cmd --permanent --zone=kubernetes --add-port=4240/tcp   # Health
firewall-cmd --permanent --zone=kubernetes --add-port=4244/tcp   # Hubble
firewall-cmd --permanent --zone=kubernetes --add-port=4245/tcp   # Hubble UI

# NodePort range
firewall-cmd --permanent --zone=kubernetes --add-port=30000-32767/tcp
firewall-cmd --permanent --zone=kubernetes --add-port=30000-32767/udp

# Ingress ports
firewall-cmd --permanent --zone=kubernetes --add-port=30080/tcp
firewall-cmd --permanent --zone=kubernetes --add-port=30443/tcp

# Enable masquerading
firewall-cmd --permanent --zone=kubernetes --add-masquerade

# Allow ICMP (IPv4) and ICMPv6 (required for IPv6)
firewall-cmd --permanent --zone=kubernetes --add-protocol=icmp
firewall-cmd --permanent --zone=kubernetes --add-protocol=ipv6-icmp

# Reload
firewall-cmd --reload

echo "Firewall configuration complete!"
firewall-cmd --zone=kubernetes --list-all
EOF

chmod +x /root/setup-firewall.sh
```

## Verify Dual-Stack Connectivity

Test that the firewall allows traffic over both protocols:

```bash
# Test IPv4 ping
ping -c 3 10.1.1.1

# Test IPv6 ping
ping6 -c 3 fd00:1::1

# Test SSH over IPv4
ssh k8sadmin@10.1.1.1 "echo 'SSH via IPv4 OK'"

# Test SSH over IPv6
ssh k8sadmin@fd00:1::1 "echo 'SSH via IPv6 OK'"

# After RKE2 is installed, test API server on both protocols:
# nc -zv 10.1.1.4 6443
# nc -zv fd00:1::4 6443
```

## Troubleshooting

### Check Dropped Packets

```bash
# View denied connections
journalctl -f -u firewalld

# Check dmesg for drops
dmesg | grep -i "DROPPED"
```

### IPv6 Not Working

```bash
# Verify ICMPv6 is allowed
firewall-cmd --zone=kubernetes --query-protocol=ipv6-icmp

# Check if IPv6 neighbor discovery is working
ip -6 neigh show

# Test basic IPv6 connectivity
ping6 -c 3 fd00:1::1
```

### Temporarily Disable Firewall (Testing Only)

```bash
# DANGER: Only for debugging
systemctl stop firewalld

# Re-enable immediately after testing
systemctl start firewalld
```

### Debug Specific Rules

```bash
# Check if a specific port is open
firewall-cmd --zone=kubernetes --query-port=6443/tcp

# List rich rules
firewall-cmd --zone=kubernetes --list-rich-rules

# Check runtime vs permanent config
firewall-cmd --zone=kubernetes --list-all
firewall-cmd --zone=kubernetes --list-all --permanent
```

## Security Considerations

- Only open ports that are necessary
- Keep public and cluster traffic in separate zones
- Review firewall rules periodically
- Enable logging for denied connections in production

```bash
# Enable logging for denied packets (optional)
firewall-cmd --permanent --zone=kubernetes --set-target=REJECT
firewall-cmd --permanent --zone=public --set-log-denied=all
firewall-cmd --reload
```

With the firewall configured for dual-stack, Node 4 is ready for RKE2 installation.
In the next lesson, we'll install and configure the first RKE2 control plane with dual-stack networking.
