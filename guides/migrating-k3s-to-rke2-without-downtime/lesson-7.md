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

## Understanding firewalld

### Zones and Interfaces

Rocky Linux 10 uses firewalld as its default firewall manager.
Firewalld organizes rules into zones, each with different trust levels and rule sets.
Interfaces are assigned to zones, and traffic is filtered according to that zone's rules.

For our cluster, we'll use two zones:

| Zone       | Interface      | Purpose                               |
| ---------- | -------------- | ------------------------------------- |
| public     | Main interface | Internet-facing traffic (SSH, HTTP/S) |
| kubernetes | vSwitch VLAN   | Internal cluster communication        |

This separation ensures that internal Kubernetes traffic is isolated from public internet traffic.

### Dual-Stack Behavior

Firewalld handles both IPv4 and IPv6 automatically.
Port and service rules apply to both protocols by default, so you don't need to create separate rules for each address family.

### ICMPv6 Requirements

Unlike IPv4 where ICMP is optional for basic functionality, IPv6 requires ICMPv6 for neighbor discovery.
Neighbor discovery is how IPv6 nodes find each other on the local network segment.
Blocking ICMPv6 will break IPv6 connectivity entirely.

## Required Ports

RKE2 with Cilium requires specific ports for cluster communication.
All ports need to be accessible over both IPv4 and IPv6.

### Control Plane Ports

| Port      | Protocol | Component       | Description                         |
| --------- | -------- | --------------- | ----------------------------------- |
| 6443      | TCP      | Kubernetes API  | kubectl and API access              |
| 9345      | TCP      | RKE2 Supervisor | Node registration                   |
| 2379-2380 | TCP      | etcd            | Cluster state (control planes only) |
| 10250     | TCP      | Kubelet         | Pod logs, exec, metrics             |

### Cilium CNI Ports

| Port | Protocol | Component     | Description                 |
| ---- | -------- | ------------- | --------------------------- |
| 8472 | UDP      | Cilium VXLAN  | Pod network overlay         |
| 4240 | TCP      | Cilium Health | Cluster connectivity checks |
| 4244 | TCP      | Hubble Relay  | Observability (optional)    |
| 4245 | TCP      | Hubble UI     | Observability (optional)    |

### Service Ports

| Port        | Protocol | Component | Description                     |
| ----------- | -------- | --------- | ------------------------------- |
| 30000-32767 | TCP/UDP  | NodePort  | Kubernetes NodePort services    |
| 30080       | TCP      | Traefik   | HTTP ingress via load balancer  |
| 30443       | TCP      | Traefik   | HTTPS ingress via load balancer |

## Configuring the Firewall

### Verify firewalld Status

```bash
sudo systemctl status firewalld

# If not running, enable and start it
sudo systemctl enable --now firewalld
```

### Create the Kubernetes Zone

Create a dedicated zone for internal cluster traffic and assign the vSwitch interface:

```bash
# Create the zone
sudo firewall-cmd --permanent --new-zone=kubernetes

# Assign the vSwitch interface (replace with your interface name)
sudo firewall-cmd --permanent --zone=kubernetes --add-interface=enp195s0.4000

# Apply the zone
sudo firewall-cmd --reload
```

### Open Control Plane Ports

```bash
sudo firewall-cmd --permanent --zone=kubernetes --add-port=6443/tcp   # API Server
sudo firewall-cmd --permanent --zone=kubernetes --add-port=9345/tcp   # RKE2 Supervisor
sudo firewall-cmd --permanent --zone=kubernetes --add-port=2379/tcp   # etcd client
sudo firewall-cmd --permanent --zone=kubernetes --add-port=2380/tcp   # etcd peer
sudo firewall-cmd --permanent --zone=kubernetes --add-port=10250/tcp  # Kubelet
```

### Open Cilium Ports

```bash
sudo firewall-cmd --permanent --zone=kubernetes --add-port=8472/udp   # VXLAN overlay
sudo firewall-cmd --permanent --zone=kubernetes --add-port=4240/tcp   # Health checks
sudo firewall-cmd --permanent --zone=kubernetes --add-port=4244/tcp   # Hubble Relay
sudo firewall-cmd --permanent --zone=kubernetes --add-port=4245/tcp   # Hubble UI
```

### Open Service Ports

```bash
sudo firewall-cmd --permanent --zone=kubernetes --add-port=30000-32767/tcp  # NodePort TCP
sudo firewall-cmd --permanent --zone=kubernetes --add-port=30000-32767/udp  # NodePort UDP
sudo firewall-cmd --permanent --zone=kubernetes --add-port=30080/tcp        # Traefik HTTP
sudo firewall-cmd --permanent --zone=kubernetes --add-port=30443/tcp        # Traefik HTTPS
```

### Enable ICMP Protocols

```bash
sudo firewall-cmd --permanent --zone=kubernetes --add-protocol=icmp       # IPv4 ping
sudo firewall-cmd --permanent --zone=kubernetes --add-protocol=ipv6-icmp  # IPv6 neighbor discovery
```

{% include alert.liquid.html type='warning' title='ICMPv6 is Required' content='
Skipping the ipv6-icmp rule will break IPv6 neighbor discovery and cause connectivity failures.
' %}

### Enable Masquerading

Masquerading allows pods to communicate with external networks:

```bash
sudo firewall-cmd --permanent --zone=kubernetes --add-masquerade
```

### Configure Public Zone

Ensure the public zone allows necessary services:

```bash
sudo firewall-cmd --permanent --zone=public --add-service=ssh
sudo firewall-cmd --permanent --zone=public --add-service=http
sudo firewall-cmd --permanent --zone=public --add-service=https
```

### Apply and Verify

```bash
sudo firewall-cmd --reload
sudo firewall-cmd --zone=kubernetes --list-all
```

Expected output:

```
kubernetes (active)
  target: default
  icmp-block-inversion: no
  interfaces: enp195s0.4000
  sources:
  services:
  ports: 6443/tcp 9345/tcp 2379/tcp 2380/tcp 10250/tcp 8472/udp 4240/tcp 4244/tcp 4245/tcp 30000-32767/tcp 30000-32767/udp 30080/tcp 30443/tcp
  protocols: icmp ipv6-icmp
  forward: yes
  masquerade: yes
  forward-ports:
  source-ports:
  icmp-blocks:
  rich rules:
```

## Verification

Test connectivity over both protocols:

```bash
# Test IPv4
ping -c 3 10.1.1.1

# Test IPv6
ping6 -c 3 fd00:1::1
```

After RKE2 is installed, you can verify API server access:

```bash
nc -zv 10.1.1.4 6443
nc -zv fd00:1::4 6443
```

## Troubleshooting

### Check Dropped Packets

```bash
# View firewalld logs
journalctl -u firewalld -f

# Check kernel drops
dmesg | grep -i "DROPPED"
```

### IPv6 Not Working

```bash
# Verify ICMPv6 is allowed
sudo firewall-cmd --zone=kubernetes --query-protocol=ipv6-icmp

# Check neighbor discovery
ip -6 neigh show
```

### Verify Specific Ports

```bash
# Check if a port is open
sudo firewall-cmd --zone=kubernetes --query-port=6443/tcp

# Compare runtime vs permanent config
sudo firewall-cmd --zone=kubernetes --list-all
sudo firewall-cmd --zone=kubernetes --list-all --permanent
```

### Temporarily Disable Firewall

For debugging only:

```bash
sudo systemctl stop firewalld
# Test connectivity
sudo systemctl start firewalld
```

In the next lesson, we'll install and configure RKE2 with dual-stack networking.
