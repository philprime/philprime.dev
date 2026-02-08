---
layout: guide-lesson.liquid
title: Installing Cilium CNI

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 2
guide_lesson_id: 9
guide_lesson_abstract: >
  Install and configure Cilium as the Container Network Interface plugin for advanced eBPF-based networking.
guide_lesson_conclusion: >
  Cilium is now providing pod networking for the RKE2 cluster with eBPF-based data plane and kube-proxy replacement.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-9.md
---

Cilium is an advanced CNI plugin that uses eBPF (extended Berkeley Packet Filter) to provide networking, security,
and observability for Kubernetes. In this lesson, we'll install Cilium on our new RKE2 cluster.

{% include guide-overview-link.liquid.html %}

## Why Cilium?

Cilium offers significant advantages over traditional CNI plugins:

| Feature          | Cilium            | Traditional CNI           |
| ---------------- | ----------------- | ------------------------- |
| Data plane       | eBPF (kernel)     | iptables/ipvs             |
| Performance      | High              | Moderate                  |
| Observability    | Built-in (Hubble) | Requires additional tools |
| Network Policies | L3-L7             | L3-L4 only                |
| Service Mesh     | Native support    | Requires sidecar          |
| Load Balancing   | eBPF-based        | kube-proxy/iptables       |

## Install Helm

Cilium is best installed using Helm:

```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version

# Add to PATH permanently if needed
which helm
```

## Add Cilium Helm Repository

```bash
# Add the Cilium Helm repository
helm repo add cilium https://helm.cilium.io/

# Update repository cache
helm repo update

# Search for available versions
helm search repo cilium/cilium --versions | head -10
```

## Prepare Cilium Configuration

Create a values file for Cilium configuration optimized for RKE2:

```bash
cat <<'EOF' > /root/cilium-values.yaml
# Cilium Configuration for RKE2

# Use kube-proxy replacement (recommended for RKE2)
kubeProxyReplacement: true

# Kubernetes API server details
k8sServiceHost: 10.1.1.4
k8sServicePort: 6443

# IPAM configuration
ipam:
  mode: kubernetes

# Enable Hubble for observability
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true

# Operator configuration
operator:
  replicas: 1  # Single replica for now, increase when more nodes join

# Enable host firewall
hostFirewall:
  enabled: false  # Enable after cluster is stable

# BPF settings
bpf:
  masquerade: true
  clockProbe: true
  preallocateMaps: true

# Enable native routing (better performance on vSwitch)
routingMode: native
ipv4NativeRoutingCIDR: 10.42.0.0/16
autoDirectNodeRoutes: true

# Tunnel mode (use vxlan for cross-node pod communication)
# If native routing doesn't work with your network, switch to:
# tunnelProtocol: vxlan
# routingMode: tunnel

# Enable bandwidth manager for better QoS
bandwidthManager:
  enabled: true
  bbr: true

# Enable local redirect policy
localRedirectPolicy: true

# Container runtime
containerRuntime:
  integration: containerd
  socketPath: /run/k3s/containerd/containerd.sock  # RKE2 uses this path

# Roll out Cilium without disruption
rollOutCiliumPods: true

# Mount BPF filesystem
bpf:
  root: /sys/fs/bpf
  autoMount:
    enabled: true

# Enable Cilium endpoint health checking
endpointHealthChecking:
  enabled: true
EOF
```

{% include alert.liquid.html type='note' title='RKE2 Socket Path' content='
RKE2 uses the same containerd socket path as k3s: /run/k3s/containerd/containerd.sock. This is intentional for compatibility.
' %}

## Install Cilium

Install Cilium using Helm:

```bash
# Set KUBECONFIG
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

# Install Cilium
helm install cilium cilium/cilium \
  --namespace kube-system \
  --values /root/cilium-values.yaml \
  --wait

# Watch the installation progress
kubectl get pods -n kube-system -l k8s-app=cilium -w
```

Wait for all Cilium pods to be running:

```
NAME           READY   STATUS    RESTARTS   AGE
cilium-xxxxx   1/1     Running   0          2m
```

Press `Ctrl+C` to exit the watch.

## Verify Cilium Installation

### Check Cilium Status

```bash
# Check all Cilium components
kubectl get pods -n kube-system | grep cilium

# Expected output:
# cilium-xxxxx                          1/1     Running   0          3m
# cilium-operator-xxxxx                 1/1     Running   0          3m
# hubble-relay-xxxxx                    1/1     Running   0          3m
# hubble-ui-xxxxx                       2/2     Running   0          3m
```

### Install Cilium CLI (Optional but Recommended)

```bash
# Download Cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz
tar xzf cilium-linux-${CLI_ARCH}.tar.gz -C /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz

# Verify installation
cilium version

# Check Cilium status
cilium status --wait
```

### Verify Connectivity

```bash
# Run Cilium connectivity test
cilium connectivity test

# This runs a series of tests to verify:
# - Pod-to-pod connectivity
# - Pod-to-service connectivity
# - External connectivity
# - Network policy enforcement
```

{% include alert.liquid.html type='info' title='Connectivity Test' content='
The connectivity test deploys test pods and runs various network tests. On a single-node cluster, some tests may be skipped. Full connectivity testing will be possible once we have multiple nodes.
' %}

## Check Node Status

With Cilium installed, the node should now be Ready:

```bash
kubectl get nodes

# Expected output:
# NAME    STATUS   ROLES                       AGE   VERSION
# node4   Ready    control-plane,etcd,master   10m   v1.28.x+rke2r1
```

## Verify kube-proxy Replacement

Confirm Cilium is handling service load balancing:

```bash
# Check if kube-proxy is replaced
cilium status | grep KubeProxyReplacement

# Verify no kube-proxy pods are running
kubectl get pods -n kube-system | grep kube-proxy

# Check Cilium's service handling
kubectl get ciliumendpoints -n kube-system
```

## Access Hubble UI (Optional)

Hubble provides real-time visibility into network flows:

```bash
# Port-forward Hubble UI (from your local machine)
# Run this on your workstation, not the server
kubectl port-forward -n kube-system svc/hubble-ui 12000:80

# Then access http://localhost:12000 in your browser
```

Alternatively, we'll set up proper ingress for Hubble later.

## Cilium Network Policies

Cilium supports both Kubernetes NetworkPolicies and its own CiliumNetworkPolicies:

```bash
# Check for any existing network policies
kubectl get networkpolicies -A
kubectl get ciliumnetworkpolicies -A

# Verify Cilium is enforcing policies
kubectl get ciliumendpoints -A
```

## Troubleshooting Cilium

### Cilium Pod Not Starting

```bash
# Check Cilium pod logs
kubectl logs -n kube-system -l k8s-app=cilium --tail=100

# Common issues:
# - BPF filesystem not mounted
# - containerd socket not accessible
# - Kernel version too old (need 4.19+)

# Check kernel version
uname -r
```

### BPF Issues

```bash
# Verify BPF filesystem is mounted
mount | grep bpf

# If not mounted:
mount -t bpf bpf /sys/fs/bpf

# Check BPF features
bpftool feature probe
```

### Connectivity Issues

```bash
# Check Cilium agent logs
kubectl logs -n kube-system -l k8s-app=cilium

# Check endpoint status
kubectl exec -n kube-system -l k8s-app=cilium -- cilium endpoint list

# Debug connectivity
kubectl exec -n kube-system -l k8s-app=cilium -- cilium-health status
```

## Save Cilium Configuration

Back up the Cilium configuration:

```bash
# Save Helm values
cp /root/cilium-values.yaml /root/rke2-backup/

# Get current Cilium version
helm list -n kube-system | grep cilium >> /root/rke2-backup/installed-versions.txt
```

## Performance Tuning (Optional)

For optimal performance, consider these kernel parameters:

```bash
# Add to /etc/sysctl.d/99-cilium.conf
cat <<EOF > /etc/sysctl.d/99-cilium.conf
# Increase BPF JIT limit
net.core.bpf_jit_limit = 1000000000

# Increase socket buffer sizes
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

# Increase conntrack table size
net.netfilter.nf_conntrack_max = 262144
EOF

sysctl --system
```

## Summary

Cilium is now installed and providing:

- eBPF-based pod networking
- kube-proxy replacement for efficient service load balancing
- Hubble for network observability
- Foundation for advanced network policies

The node is now fully Ready and can run workloads. In the next lesson, we'll verify the entire initial setup
before proceeding with node migration.
