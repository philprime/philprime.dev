---
layout: guide-lesson.liquid
title: Installing Cilium CNI with Dual-Stack

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 2
guide_lesson_id: 9
guide_lesson_abstract: >
  Install and configure Cilium as the CNI plugin with dual-stack IPv4/IPv6 support for eBPF-based networking.
guide_lesson_conclusion: >
  Cilium is providing dual-stack pod networking. Node 4 is Ready and Cluster B can accept additional nodes.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-9.md
---

Cilium is an advanced CNI plugin that uses eBPF to provide networking, security, and observability for Kubernetes.
In this lesson, we'll install Cilium with dual-stack support on our RKE2 cluster.

{% include guide-overview-link.liquid.html %}

## Why Cilium for Dual-Stack?

Cilium has excellent dual-stack support and offers significant advantages:

| Feature          | Cilium            | Traditional CNI           |
| ---------------- | ----------------- | ------------------------- |
| Dual-stack       | Native support    | Often limited or complex  |
| Data plane       | eBPF (kernel)     | iptables/ipvs             |
| Performance      | High              | Moderate                  |
| Observability    | Built-in (Hubble) | Requires additional tools |
| Network Policies | L3-L7             | L3-L4 only                |
| Load Balancing   | eBPF-based        | kube-proxy/iptables       |

## Install Helm

Cilium is best installed using Helm:

```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
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

## Prepare Dual-Stack Cilium Configuration

Create a values file for Cilium with dual-stack networking:

```bash
cat <<'EOF' > /root/cilium-values.yaml
# Cilium Dual-Stack Configuration for RKE2

# Enable IPv6 support
ipv6:
  enabled: true

# Use kube-proxy replacement (recommended for RKE2)
kubeProxyReplacement: true

# Kubernetes API server details (use IPv4 for stability)
k8sServiceHost: 10.1.1.4
k8sServicePort: 6443

# IPAM configuration for dual-stack
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
  replicas: 1  # Increase when more nodes join

# BPF settings
bpf:
  masquerade: true
  clockProbe: true
  preallocateMaps: true

# Enable native routing for both stacks
routingMode: native
ipv4NativeRoutingCIDR: 10.42.0.0/16
ipv6NativeRoutingCIDR: fd00:42::/56
autoDirectNodeRoutes: true

# Enable bandwidth manager for better QoS
bandwidthManager:
  enabled: true
  bbr: true

# Enable local redirect policy
localRedirectPolicy: true

# Container runtime (RKE2 uses k3s containerd path)
containerRuntime:
  integration: containerd
  socketPath: /run/k3s/containerd/containerd.sock

# Roll out Cilium without disruption
rollOutCiliumPods: true

# Mount BPF filesystem
bpf:
  root: /sys/fs/bpf
  autoMount:
    enabled: true

# Enable endpoint health checking
endpointHealthChecking:
  enabled: true

# Enable IPv4 and IPv6 masquerading
enableIPv4Masquerade: true
enableIPv6Masquerade: true
EOF
```

{% include alert.liquid.html type='note' title='RKE2 Socket Path' content='
RKE2 uses the same containerd socket path as k3s: /run/k3s/containerd/containerd.sock.
This is intentional for compatibility.
' %}

## Install Cilium

Install Cilium using Helm:

```bash
# Set KUBECONFIG
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

# Install Cilium with dual-stack configuration
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

### Install Cilium CLI (Recommended)

```bash
# Download Cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz
tar xzf cilium-linux-${CLI_ARCH}.tar.gz -C /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz

# Verify installation
cilium version

# Check Cilium status (should show IPv4 and IPv6 enabled)
cilium status --wait
```

### Verify Dual-Stack Configuration

```bash
# Check Cilium status for dual-stack
cilium status | grep -E "IPv4|IPv6"

# Expected output should show both:
# IPv4 BPF NodePort:   Enabled
# IPv6 BPF NodePort:   Enabled
# IPv4 Masquerade:     Enabled
# IPv6 Masquerade:     Enabled

# Verify Cilium config
kubectl -n kube-system get configmap cilium-config -o yaml | grep -E "enable-ipv6|ipv6"
```

### Run Connectivity Test

```bash
# Run Cilium connectivity test (includes dual-stack tests)
cilium connectivity test

# This tests:
# - Pod-to-pod connectivity (IPv4 and IPv6)
# - Pod-to-service connectivity (IPv4 and IPv6)
# - External connectivity
# - Network policy enforcement
```

{% include alert.liquid.html type='info' title='Connectivity Test' content='
The connectivity test deploys test pods and runs various network tests.
On a single-node cluster, some tests may be skipped.
Full dual-stack testing will be possible once we have multiple nodes.
' %}

## Check Node Status

With Cilium installed, the node should now be Ready:

```bash
kubectl get nodes -o wide

# Expected output (note both IPs in INTERNAL-IP):
# NAME    STATUS   ROLES                       AGE   VERSION          INTERNAL-IP
# node4   Ready    control-plane,etcd,master   15m   v1.28.x+rke2r1   10.1.1.4,fd00:1::4
```

## Verify kube-proxy Replacement

Confirm Cilium is handling service load balancing for both protocols:

```bash
# Check if kube-proxy is replaced
cilium status | grep KubeProxyReplacement

# Verify no kube-proxy pods are running
kubectl get pods -n kube-system | grep kube-proxy

# Check Cilium's service handling
kubectl get ciliumendpoints -n kube-system
```

## Test Dual-Stack Pod Networking

Deploy a test pod to verify dual-stack networking:

```bash
# Create a test pod
kubectl run dual-stack-test --image=busybox:1.36 --restart=Never -- sleep 3600

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod/dual-stack-test --timeout=60s

# Check pod IPs (should have both IPv4 and IPv6)
kubectl get pod dual-stack-test -o jsonpath='{.status.podIPs}' | jq .

# Expected output:
# [
#   { "ip": "10.42.x.x" },
#   { "ip": "fd00:42:x:x::x" }
# ]

# Test connectivity from inside the pod
kubectl exec dual-stack-test -- ping -c 2 10.1.1.4
kubectl exec dual-stack-test -- ping6 -c 2 fd00:1::4

# Clean up
kubectl delete pod dual-stack-test
```

## Access Hubble UI (Optional)

Hubble provides real-time visibility into network flows for both protocols:

```bash
# Port-forward Hubble UI (from your local machine)
kubectl port-forward -n kube-system svc/hubble-ui 12000:80

# Then access http://localhost:12000 in your browser
```

## Troubleshooting Cilium Dual-Stack

### Cilium Pod Not Starting

```bash
# Check Cilium pod logs
kubectl logs -n kube-system -l k8s-app=cilium --tail=100

# Common issues:
# - BPF filesystem not mounted
# - containerd socket not accessible
# - Kernel version too old (need 4.19+ for IPv6 eBPF)

# Check kernel version
uname -r
```

### IPv6 Not Working in Pods

```bash
# Verify IPv6 is enabled in Cilium
kubectl -n kube-system get configmap cilium-config -o yaml | grep enable-ipv6

# Check Cilium agent logs for IPv6 errors
kubectl logs -n kube-system -l k8s-app=cilium | grep -i ipv6

# Verify node has IPv6 forwarding enabled
sysctl net.ipv6.conf.all.forwarding

# Check if pods are getting IPv6 addresses
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIPs}{"\n"}{end}'
```

### BPF Issues

```bash
# Verify BPF filesystem is mounted
mount | grep bpf

# If not mounted:
mount -t bpf bpf /sys/fs/bpf

# Check BPF features (including IPv6)
bpftool feature probe | grep -i ipv6
```

### Connectivity Issues

```bash
# Check Cilium agent logs
kubectl logs -n kube-system -l k8s-app=cilium

# Check endpoint status (should show IPv4 and IPv6)
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

# Export current Cilium config
kubectl -n kube-system get configmap cilium-config -o yaml > /root/rke2-backup/cilium-config.yaml
```

## Performance Tuning (Optional)

For optimal dual-stack performance, consider these kernel parameters:

```bash
cat <<EOF > /etc/sysctl.d/99-cilium.conf
# Increase BPF JIT limit
net.core.bpf_jit_limit = 1000000000

# Increase socket buffer sizes
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

# Increase conntrack table size (for both IPv4 and IPv6)
net.netfilter.nf_conntrack_max = 262144

# IPv6 specific tuning
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
EOF

sysctl --system
```

## Summary

Cilium is now installed and providing:

- Dual-stack eBPF-based pod networking (IPv4 and IPv6)
- kube-proxy replacement for efficient service load balancing on both protocols
- Hubble for network observability
- Foundation for advanced L3-L7 network policies

The node is now fully Ready with dual-stack networking.
With Cluster B operational, we can begin the critical phase of migrating nodes from Cluster A in the next section.
