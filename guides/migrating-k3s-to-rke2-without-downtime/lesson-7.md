---
layout: guide-lesson.liquid
title: Firewall Configuration with firewalld

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 2
guide_lesson_id: 7
guide_lesson_abstract: >
  Configure firewalld on Node 4 to allow RKE2, Cilium, and Kubernetes traffic while maintaining security.
guide_lesson_conclusion: >
  The firewall is now configured to allow all necessary Kubernetes cluster traffic while blocking unauthorized access.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-7.md
---

Proper firewall configuration is critical for a secure Kubernetes cluster. In this lesson, we'll configure firewalld
to allow necessary traffic while maintaining security.

{% include guide-overview-link.liquid.html %}

## Understanding Firewalld

Rocky Linux 9 uses firewalld as its default firewall manager. Unlike iptables rules, firewalld uses zones and
services for a more intuitive configuration.

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

## Create a Kubernetes Zone

For better organization, we'll create a dedicated zone for Kubernetes traffic:

```bash
# Create a new zone for internal Kubernetes traffic
firewall-cmd --permanent --new-zone=kubernetes

# Set the vSwitch interface to the kubernetes zone
firewall-cmd --permanent --zone=kubernetes --add-interface=enp0s31f6.4000

# Reload to apply zone creation
firewall-cmd --reload
```

## Configure Control Plane Ports

Since Node 4 will be a control plane node, it needs all control plane ports:

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

The public zone handles traffic from the internet (via the public IP):

```bash
# Ensure SSH remains accessible
firewall-cmd --permanent --zone=public --add-service=ssh

# Allow Kubernetes API from specific IPs (optional, for external kubectl access)
# Replace with your admin IP
# firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" source address="YOUR.ADMIN.IP/32" port protocol="tcp" port="6443" accept'

# Allow HTTP/HTTPS for ingress (if using public IPs directly)
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https
```

## Allow ICMP (Ping)

For troubleshooting, allow ICMP:

```bash
# Allow ping on kubernetes zone
firewall-cmd --permanent --zone=kubernetes --add-icmp-block-inversion
firewall-cmd --permanent --zone=kubernetes --add-icmp-block=echo-reply
firewall-cmd --permanent --zone=kubernetes --remove-icmp-block=echo-reply

# Simpler: just allow all ICMP
firewall-cmd --permanent --zone=kubernetes --add-protocol=icmp
```

## Configure Masquerading

Enable masquerading for pod network traffic:

```bash
# Enable masquerading on kubernetes zone
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
  protocols: icmp
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
# Kubernetes Firewall Configuration Script
# Run this to restore firewall rules

set -e

echo "Configuring firewalld for Kubernetes..."

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

# Allow ICMP
firewall-cmd --permanent --zone=kubernetes --add-protocol=icmp

# Reload
firewall-cmd --reload

echo "Firewall configuration complete!"
firewall-cmd --zone=kubernetes --list-all
EOF

chmod +x /root/setup-firewall.sh
```

## Verify Connectivity

Test that the firewall allows necessary traffic:

```bash
# Test SSH (should work)
ssh root@10.1.1.1 "echo 'SSH to node1 OK'"

# Test ping (should work)
ping -c 3 10.1.1.1

# From another node, test port 6443 (after RKE2 is installed)
# nc -zv 10.1.1.4 6443
```

## Troubleshooting

### Check Dropped Packets

```bash
# View denied connections
journalctl -f -u firewalld

# Or check dmesg for drops
dmesg | grep -i "DROPPED"
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

1. **Principle of least privilege**: Only open ports that are necessary
2. **Zone segregation**: Keep public and cluster traffic separate
3. **Regular audits**: Review firewall rules periodically
4. **Logging**: Enable logging for denied connections in production

```bash
# Enable logging for denied packets (optional)
firewall-cmd --permanent --zone=kubernetes --set-target=REJECT
firewall-cmd --permanent --zone=public --set-log-denied=all
firewall-cmd --reload
```

With the firewall properly configured, Node 4 is now ready for RKE2 installation. In the next lesson, we'll install
and configure the first RKE2 control plane.
