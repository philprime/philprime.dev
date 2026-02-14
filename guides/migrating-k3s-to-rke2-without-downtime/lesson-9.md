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

## Understanding Cilium

### Why Cilium for Dual-Stack

Cilium provides native dual-stack support with significant advantages over traditional CNI plugins:

| Feature          | Cilium            | Traditional CNI           |
| ---------------- | ----------------- | ------------------------- |
| Dual-stack       | Native support    | Often limited or complex  |
| Data plane       | eBPF (kernel)     | iptables/ipvs             |
| Performance      | High              | Moderate                  |
| Observability    | Built-in (Hubble) | Requires additional tools |
| Network Policies | L3-L7             | L3-L4 only                |
| Load Balancing   | eBPF-based        | kube-proxy/iptables       |

### Key Components

| Component       | Purpose                                  |
| --------------- | ---------------------------------------- |
| cilium-agent    | Runs on each node, manages eBPF programs |
| cilium-operator | Cluster-wide operations and IPAM         |
| hubble-relay    | Aggregates flow data from agents         |
| hubble-ui       | Web interface for network visibility     |

### What is eBPF?

eBPF (extended Berkeley Packet Filter) is a technology that allows running sandboxed programs inside the Linux kernel without changing kernel source code or loading kernel modules.
Originally designed for packet filtering, eBPF has evolved into a general-purpose execution engine for kernel-level programming.

eBPF programs are:

- Verified by the kernel for safety before execution
- JIT-compiled to native machine code for performance
- Attached to kernel hooks (network, tracing, security)
- Able to share data with userspace through maps

### Why eBPF for Networking?

Traditional Kubernetes networking uses iptables, which processes packets through a chain of rules.
As clusters grow, iptables rules multiply and performance degrades.
Each Service adds rules, and with dual-stack, the rule count doubles.

Cilium replaces iptables with eBPF programs that:

- Process packets at the earliest possible point in the network stack
- Use hash maps for O(1) lookups instead of linear rule chains
- Handle both IPv4 and IPv6 in the same code path
- Provide load balancing, masquerading, and policy enforcement without context switches

For dual-stack specifically, eBPF programs can inspect packet headers and route IPv4 and IPv6 traffic using unified logic, rather than maintaining separate iptables rule sets for each protocol.

### IPAM (IP Address Management)

IPAM controls how pod IP addresses are allocated.
Cilium supports several IPAM modes:

| Mode         | Description                                             |
| ------------ | ------------------------------------------------------- |
| kubernetes   | Delegates to Kubernetes, uses node's PodCIDR allocation |
| cluster-pool | Cilium manages a cluster-wide pool of IPs               |
| multi-pool   | Multiple pools with different CIDRs per node            |

We use `kubernetes` mode because RKE2 already configures the pod CIDRs and assigns ranges to each node.
Cilium simply uses the addresses that Kubernetes provides, ensuring consistency with the cluster configuration from lesson 8.

For dual-stack, Kubernetes allocates both an IPv4 and IPv6 CIDR range to each node.
When a pod starts, it receives one address from each range.

### kube-proxy Replacement

Cilium can fully replace kube-proxy, handling Kubernetes Service load balancing using eBPF instead of iptables.
This provides better performance and native dual-stack support without the complexity of managing iptables rules for both IPv4 and IPv6.

## Configuration Planning

### Key Options

| Option                  | Value        | Purpose                               |
| ----------------------- | ------------ | ------------------------------------- |
| `ipv6.enabled`          | true         | Enable IPv6 support                   |
| `kubeProxyReplacement`  | true         | Replace kube-proxy with eBPF          |
| `routingMode`           | native       | Use native routing instead of overlay |
| `ipv4NativeRoutingCIDR` | 10.42.0.0/16 | IPv4 pod CIDR for native routing      |
| `ipv6NativeRoutingCIDR` | fd00:42::/56 | IPv6 pod CIDR for native routing      |
| `enableIPv4Masquerade`  | true         | SNAT for IPv4 traffic leaving cluster |
| `enableIPv6Masquerade`  | true         | SNAT for IPv6 traffic leaving cluster |

### Native Routing vs Overlay

Cilium supports two routing modes:

**Native routing** sends packets directly between nodes without encapsulation.
This provides better performance but requires the underlying network to route pod CIDRs.
On a vSwitch where all nodes are Layer 2 adjacent, native routing works well.

**Overlay (VXLAN/Geneve)** encapsulates packets to tunnel them between nodes.
This works on any network but adds overhead.

We use native routing since our vSwitch provides direct Layer 2 connectivity.

## Installing Cilium

### Install Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

### Add Cilium Repository

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update
```

### Create Configuration

```bash
cat <<'EOF' > /root/cilium-values.yaml
ipv6:
  enabled: true

kubeProxyReplacement: true

k8sServiceHost: 10.0.0.4
k8sServicePort: 6443

ipam:
  mode: kubernetes

hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true

operator:
  replicas: 1

bpf:
  masquerade: true
  preallocateMaps: true

routingMode: native
ipv4NativeRoutingCIDR: 10.42.0.0/16
ipv6NativeRoutingCIDR: fd00:42::/56
autoDirectNodeRoutes: true

bandwidthManager:
  enabled: true
  bbr: true

containerRuntime:
  integration: containerd
  socketPath: /run/k3s/containerd/containerd.sock

enableIPv4Masquerade: true
enableIPv6Masquerade: true
EOF
```

{% include alert.liquid.html type='note' title='RKE2 Socket Path' content='
RKE2 uses the same containerd socket path as k3s: /run/k3s/containerd/containerd.sock
' %}

### Install Cilium

```bash
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

helm install cilium cilium/cilium \
  --namespace kube-system \
  --values /root/cilium-values.yaml \
  --wait
```

Watch the installation:

```bash
kubectl get pods -n kube-system -l k8s-app=cilium -w
```

Wait until all Cilium pods show `Running` status, then press `Ctrl+C`.

### Install Cilium CLI

The Cilium CLI provides useful status and connectivity testing commands:

```bash
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --fail --remote-name-all \
  https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz
sudo tar xzf cilium-linux-amd64.tar.gz -C /usr/local/bin
rm cilium-linux-amd64.tar.gz

cilium version
```

## Verification

### Cilium Status

```bash
cilium status --wait
```

The output should show IPv4 and IPv6 enabled:

```
    /¯¯\
 /¯¯\__/¯¯\    Cilium:          OK
 \__/¯¯\__/    Operator:        OK
 /¯¯\__/¯¯\    Hubble Relay:    OK
 \__/¯¯\__/
    \__/

KubeProxyReplacement:    True
IPv4 BPF NodePort:       Enabled
IPv6 BPF NodePort:       Enabled
IPv4 Masquerade:         Enabled
IPv6 Masquerade:         Enabled
```

### Node Status

The node should now be Ready:

```bash
kubectl get nodes -o wide
```

Expected output showing both IPs:

```
NAME    STATUS   ROLES                       AGE   VERSION          INTERNAL-IP
node4   Ready    control-plane,etcd,master   20m   v1.31.x+rke2r1   10.0.0.4,fd00::4
```

### Dual-Stack Pod Test

```bash
kubectl run dual-stack-test --image=busybox:1.36 --restart=Never -- sleep 3600
kubectl wait --for=condition=Ready pod/dual-stack-test --timeout=60s

# Check pod has both IPv4 and IPv6 addresses
kubectl get pod dual-stack-test -o jsonpath='{.status.podIPs}' | jq .
```

Expected output:

```json
[
  { "ip": "10.42.x.x" },
  { "ip": "fd00:42:x:x::x" }
]
```

Test connectivity:

```bash
kubectl exec dual-stack-test -- ping -c 2 10.0.0.4
kubectl exec dual-stack-test -- ping6 -c 2 fd00::4

kubectl delete pod dual-stack-test
```

### Connectivity Test

Run the full Cilium connectivity test:

```bash
cilium connectivity test
```

This deploys test pods and validates pod-to-pod, pod-to-service, and external connectivity for both IPv4 and IPv6.

{% include alert.liquid.html type='info' title='Single Node Limitations' content='
Some tests may be skipped on a single-node cluster.
Full dual-stack testing will be possible once additional nodes join.
' %}

## Hubble UI

Hubble provides real-time network flow visibility:

```bash
kubectl port-forward -n kube-system svc/hubble-ui 12000:80
```

Access `http://localhost:12000` in your browser.

## Troubleshooting

### Cilium Pod Not Starting

```bash
kubectl logs -n kube-system -l k8s-app=cilium --tail=100
```

Common issues:

- BPF filesystem not mounted
- containerd socket not accessible
- Kernel version too old (need 4.19+ for IPv6 eBPF)

### IPv6 Not Working

```bash
# Verify IPv6 is enabled in config
kubectl -n kube-system get configmap cilium-config -o yaml | grep enable-ipv6

# Check if pods are getting IPv6 addresses
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIPs}{"\n"}{end}'

# Verify node has IPv6 forwarding
sysctl net.ipv6.conf.all.forwarding
```

### BPF Issues

```bash
# Verify BPF filesystem is mounted
mount | grep bpf

# If not mounted
sudo mount -t bpf bpf /sys/fs/bpf
```

### Connectivity Issues

```bash
kubectl exec -n kube-system -l k8s-app=cilium -- cilium-health status
kubectl exec -n kube-system -l k8s-app=cilium -- cilium endpoint list
```

## Backup Configuration

```bash
cp /root/cilium-values.yaml /root/rke2-backup/
kubectl -n kube-system get configmap cilium-config -o yaml > /root/rke2-backup/cilium-config.yaml
```

The node is now fully Ready with dual-stack networking.
In the next section, we'll begin migrating nodes from the k3s cluster to RKE2.
