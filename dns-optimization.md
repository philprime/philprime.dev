# DNS Optimization for CI Cluster

## Problem

CI workflows running on our self-hosted RKE2 cluster intermittently fail with DNS resolution errors:

```
Error: getaddrinfo EAI_AGAIN productionresultssa14.blob.core.windows.net
```

```
WARNING: fetching https://dl-cdn.alpinelinux.org/...: DNS: transient error (try again later)
```

These failures occur during artifact uploads (Azure Blob Storage), package installs (`apk add`, `npm install`), and image pulls, causing entire CI pipelines to fail.

## Root Cause Analysis

### 1. DNS search domain amplification (ndots:5)

Kubernetes pods default to `ndots:5` in `/etc/resolv.conf`. This means any hostname with fewer than 5 dots is first resolved through all search domains before trying the actual name. For an external hostname like `productionresultssa14.blob.core.windows.net` (4 dots < 5), the resolution path is:

1. `productionresultssa14.blob.core.windows.net.github-arc-*.svc.cluster.local` -> NXDOMAIN
2. `productionresultssa14.blob.core.windows.net.svc.cluster.local` -> NXDOMAIN
3. `productionresultssa14.blob.core.windows.net.cluster.local` -> NXDOMAIN
4. `productionresultssa14.blob.core.windows.net.` -> NOERROR (finally resolves)

This means **every external DNS lookup generates 4 queries**, 3 of which are guaranteed to fail. Prometheus metrics confirmed a 3:1 NXDOMAIN-to-NOERROR ratio across the cluster.

### 2. High upstream DNS latency

Unlike AWS EKS (which forwards to a local VPC resolver at <1ms latency), our CoreDNS forwards to Cloudflare (`1.1.1.1`, `1.0.0.1`) over the public internet. The measured p99 upstream latency ranged from 60ms to 660ms. Combined with the 4x query amplification, a single DNS resolution could take 2+ seconds during bursts.

### 3. CI burst traffic

With 30+ runner pods and 10+ BuildKit pods all performing external DNS lookups simultaneously, CoreDNS request rates spike from a baseline of ~73 req/s to ~172 req/s. During these bursts, upstream latency spikes cause DNS resolution timeouts (`EAI_AGAIN`).

### Comparison with AWS EKS

| Aspect              | RKE2 (our cluster)                                | AWS EKS                                 |
| ------------------- | ------------------------------------------------- | --------------------------------------- |
| Upstream DNS        | Cloudflare over internet (60-660ms p99)           | AWS VPC resolver (<1ms)                 |
| Cache TTL           | Was 300s                                          | 30s (doesn't matter with fast upstream) |
| The core difference | Upstream latency makes every cache miss expensive | Upstream is effectively free            |

## Changes Applied

### 1. Set `ndots:1` on CI runner pods

**Files changed**: All scale set configurations in `src/github-actions-runner/`

- `kubernetes-scaleset/createKubernetesRunnerScaleSet.ts` (runner + listener templates)
- `kubernetes-scaleset/createRunnerTemplateConfigMap.ts` (workflow job pods)
- `dind-scaleset/createDockerInDockerScaleSet.ts` (runner + listener templates)
- `android-scaleset/createAndroidRunnerScaleSet.ts` (runner + listener templates)
- `android-scaleset/createAndroidRunnerTemplateConfigMap.ts` (workflow job pods)

**Effect**: External hostnames (anything with 1+ dots) resolve on the first attempt instead of trying 3 search domains first. This eliminates ~75% of DNS queries. Internal Kubernetes service names using FQDNs (e.g., `service.namespace.svc.cluster.local`) continue to work normally since they already contain dots.

### 2. Increase CoreDNS cache TTL to 1 hour

**File changed**: `/var/lib/rancher/rke2/server/manifests/rke2-coredns-config.yaml` on the `doom` server node

**Changes**:

- Success cache: 300s -> 3600s (1 hour)
- Denial cache: added explicit 600s (10 minutes)

**Rationale**: With expensive upstream lookups (60-660ms to Cloudflare), caching results longer dramatically reduces upstream pressure. The 1-hour TTL for successful responses is safe because external DNS records rarely change faster than that. The 10-minute denial cache is shorter to ensure newly created DNS records become resolvable within a reasonable window.

### 3. Deploy NodeLocal DNS Cache (per-node caching)

**Status**: Initially deferred, then implemented after continued DNS failures under CI burst load.

Despite the cache TTL increase, DNS failures persisted during heavy CI bursts. The problem was that all DNS queries still traversed the VXLAN/WireGuard overlay to reach CoreDNS pods, which could be on a different node. Under burst load, the overlay became a bottleneck — not because of bandwidth, but because of conntrack table pressure, packet queuing, and the latency multiplier of encapsulation.

NodeLocal DNS Cache runs a lightweight DNS caching agent (`node-cache`) on every node as a DaemonSet with `hostNetwork: true`. Pods query the local agent at `169.254.20.10` instead of the CoreDNS ClusterIP (`10.43.0.10`). Cache hits are served locally without touching the network. Cache misses are forwarded to CoreDNS via UDP.

**Files changed**:

- `/var/lib/rancher/rke2/server/manifests/nodelocaldns.yaml` on doom (manual manifest, not Helm-managed)
- `/var/lib/rancher/rke2/server/manifests/rke2-coredns-config.yaml` on doom (disabled Helm-managed nodelocal)
- `/etc/rancher/rke2/config.yaml.d/10-network.yaml` on doom, juggernaut, mystique (added `cluster-dns=169.254.20.10` to kubelet-arg)
- `/etc/rancher/rke2/config.yaml` on kang (same kubelet-arg change)

## Investigation: NodeLocal DNS Cache on Hetzner Dedicated Servers

The path from "let's deploy NodeLocal DNS" to a working setup was not straightforward. This section documents every failure mode we encountered, because the RKE2 built-in NodeLocal DNS Cache is fundamentally broken on Hetzner dedicated servers with public IPs.

### Attempt 1: Helm chart with ipvs=false (iptables NOTRACK mode)

RKE2's `rke2-coredns` Helm chart bundles NodeLocal DNS Cache. The simplest deployment is:

```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-coredns-config.yaml
nodelocal:
  enabled: true
```

With `ipvs: false` (the default), the node-cache binary injects iptables NOTRACK rules that hijack the CoreDNS ClusterIP (`10.43.0.10`). DNS packets destined for the ClusterIP are intercepted before kube-proxy can DNAT them, so the local node-cache handles them directly.

**Result**: Complete DNS outage.

The NOTRACK rules bypass conntrack, which breaks kube-proxy's connection tracking for DNS. After a rolling restart of CoreDNS pods, all DNS resolution failed cluster-wide. We had to delete the NodeLocal DaemonSet to recover.

### Attempt 2: ipvs=false with CIS network policies

After recovering from Attempt 1, we re-enabled nodelocal and discovered a second failure mode. DNS worked for pods in production namespaces but failed in the `default` namespace.

**Root cause**: The CIS hardening network policies from our initial cluster setup (Lesson 6 of the migration guide) included an `allow-dns` egress policy in the `default` namespace that only permitted DNS traffic to pods in `kube-system`. NodeLocal DNS runs with `hostNetwork: true`, so Calico does not see it as a `kube-system` pod — it sees the node's IP. The network policy silently blocked DNS to the nodelocal agent.

**Fix**: Removed `/var/lib/rancher/rke2/server/manifests/default-network-policies.yaml` and deleted the network policies from the cluster. CIS-hardened network policies are incompatible with NodeLocal DNS Cache in hostNetwork mode.

### Attempt 3: ipvs=true (link-local only mode)

To avoid the NOTRACK iptables issues, we switched to `ipvs: true`:

```yaml
nodelocal:
  enabled: true
  ipvs: true
```

In this mode, node-cache only binds to the link-local address `169.254.20.10` and does not inject any iptables rules. Pods must be explicitly configured to use `169.254.20.10` via a kubelet `--cluster-dns` override. This is cleaner — no iptables manipulation, no interference with kube-proxy.

**Result**: Internal DNS (`cluster.local`) completely broken. External DNS (`.` zone) worked fine.

### Root cause: force_tcp + hostNetwork = asymmetric routing

The Helm chart's nodelocal Corefile hardcodes `force_tcp` for forwarding to CoreDNS:

```
cluster.local:53 {
    forward . 10.43.0.10 {
            force_tcp
    }
}
```

This creates a fatal asymmetric routing problem on Hetzner dedicated servers:

1. The node-cache pod runs with `hostNetwork: true`, so its source IP is the node's **public IP** (e.g., `135.181.1.252` on doom).
2. node-cache opens a TCP connection (SYN) from `135.181.1.252:55038` to `10.43.0.10:53` (CoreDNS ClusterIP).
3. kube-proxy DNATs the destination to a CoreDNS pod IP (e.g., `10.42.1.90` on mystique).
4. The SYN packet travels through the WireGuard tunnel to mystique.
5. CoreDNS on mystique sends a SYN-ACK back to `135.181.1.252`.
6. **The SYN-ACK routes out mystique's public interface** (not back through WireGuard), because `135.181.1.252` is a public IP and the kernel's routing table sends it via the default gateway.
7. The SYN-ACK either gets dropped by the Hetzner firewall (wrong source) or arrives via a different path than the SYN, and the connection never establishes.

All TCP connections from node-cache to CoreDNS were stuck in `SYN-SENT`:

```
$ sudo ss -tnp | grep node-cache
SYN-SENT  0  1  135.181.1.252:55038  10.43.0.10:53  users:(("node-cache",pid=732304,fd=16))
SYN-SENT  0  1  135.181.1.252:58126  10.43.0.10:53  users:(("node-cache",pid=732304,fd=13))
```

External DNS worked because the `.` zone forwards to `/etc/resolv.conf` (Cloudflare `1.1.1.1`) via UDP directly — no ClusterIP, no kube-proxy DNAT, no asymmetric routing.

**This is a fundamental incompatibility**: any Kubernetes cluster where nodes have public IPs as their primary address and use an overlay network (VXLAN, WireGuard) for pod traffic will hit this issue with `force_tcp` from `hostNetwork` pods to ClusterIPs.

### Attempt 4: Tailscale DNS interference

During debugging, we discovered that Tailscale's MagicDNS (`--accept-dns=true`, the default) replaces `/etc/resolv.conf` on each node with `nameserver 100.100.100.100`. Since NodeLocal DNS's `.` zone forwards to `/etc/resolv.conf` for external queries, all external DNS was routing through Tailscale's resolver instead of Cloudflare.

We disabled Tailscale DNS on all nodes:

```bash
tailscale set --accept-dns=false
```

**Side effect**: Nodes can no longer resolve `.ts.net` hostnames. SSH between nodes must use Tailscale IPs directly (e.g., `ssh 100.122.121.38` instead of `ssh doom-nodes-kula-app.tailc7bf.ts.net`).

### The fix: prefer_udp instead of force_tcp

The `force_tcp` option is hardcoded in the rke2-coredns Helm chart template — there is no Helm value to disable it. The fix required abandoning the Helm-managed nodelocal deployment entirely and creating a manual manifest.

Replacing `force_tcp` with `prefer_udp` in the Corefile resolves the asymmetric routing issue:

```
cluster.local:53 {
    forward . 10.43.0.10 {
            prefer_udp
    }
}
```

**Why this works**: UDP is connectionless. The request goes from node-cache to CoreDNS via kube-proxy DNAT, and the response returns via the same DNAT mapping (conntrack handles the reverse path). There is no TCP handshake, so there is no SYN-ACK that needs to find its way back to a public IP.

## What is NOT changed (and why)

### CoreDNS internalTrafficPolicy: Local

We investigated setting `internalTrafficPolicy: Local` on the CoreDNS Service to keep DNS queries on the same node. The rke2-coredns Helm chart does not template `service.internalTrafficPolicy`, so it cannot be set through `HelmChartConfig`. A manual `kubectl patch` works but is not scalable — it gets overwritten on every Helm reconciliation. With NodeLocal DNS Cache deployed, this optimization is unnecessary anyway.

### Upstream DNS resolvers

The current upstream resolvers (`1.1.1.1`, `1.0.0.1`, plus IPv6 variants) are reliable and widely used. Switching to Hetzner's local resolvers could reduce latency but would add a provider-specific dependency. The cache TTL increase makes upstream latency less impactful.

## Monitoring

The CoreDNS Grafana dashboard (`/d/coredns/coredns`) tracks:

- **Requests by zone**: NXDOMAIN ratio should drop significantly after `ndots:1` rollout
- **Upstream latency (p50/p90/p99)**: should show fewer requests reaching upstream
- **Cache hit rate**: should increase substantially with the 1-hour TTL
- **SERVFAIL/REFUSED rates**: should remain near zero
- **NodeLocal DNS by node**: requests, cache hit rate, latency, and upstream forwards per node (requires the headless `node-local-dns` Service for Prometheus scraping)

## Final Solution

The complete DNS optimization stack for our RKE2 cluster on Hetzner dedicated servers:

### Architecture

```
Pod DNS query
    |
    v
169.254.20.10 (NodeLocal DNS Cache — same node, hostNetwork)
    |
    |-- cluster.local → forward to 10.43.0.10 (CoreDNS) via UDP (prefer_udp)
    |                        |
    |                        |-- cache hit → respond (1h TTL success, 10m denial)
    |                        |-- cache miss → forward to Cloudflare (1.1.1.1)
    |
    |-- external (.) → forward directly to Cloudflare (1.1.1.1, 1.0.0.1) via UDP
    |
    |-- cache hit at nodelocal → respond immediately (30s cluster.local, 30s external)
```

### Components

| Layer | Component | Purpose | Key Config |
| ----- | --------- | ------- | ---------- |
| 1 | Pod `dnsConfig` | Reduce query amplification | `ndots:1` on CI runner pods |
| 2 | NodeLocal DNS Cache | Per-node caching, eliminate overlay traversal for DNS | `prefer_udp`, manual manifest (not Helm) |
| 3 | CoreDNS | Cluster DNS authority + upstream forwarding | 1h success cache, 10m denial cache, `bufsize 1232` |
| 4 | Cloudflare | Upstream resolver | `1.1.1.1`, `1.0.0.1` (IPv4), `2606:4700:4700::1111/1001` (IPv6) |

### Key files

| File | Node | Purpose |
| ---- | ---- | ------- |
| `scripts/manifests/nodelocaldns.yaml` | repo | Source of truth for NodeLocal DNS manifest |
| `/var/lib/rancher/rke2/server/manifests/nodelocaldns.yaml` | doom | Deployed NodeLocal DNS manifest (auto-applied on RKE2 start) |
| `/var/lib/rancher/rke2/server/manifests/rke2-coredns-config.yaml` | doom | CoreDNS HelmChartConfig (nodelocal.enabled: false) |
| `/etc/rancher/rke2/config.yaml.d/10-network.yaml` | doom, juggernaut, mystique | kubelet-arg: cluster-dns=169.254.20.10 |
| `/etc/rancher/rke2/config.yaml` | kang | kubelet-arg: cluster-dns=169.254.20.10 |

### Critical learnings for Hetzner / bare-metal with public IPs

1. **Never use `force_tcp` from hostNetwork pods to ClusterIPs** on nodes with public IPs and overlay networking. TCP's three-way handshake causes asymmetric routing because the SYN-ACK routes via the public interface instead of the overlay tunnel.
2. **CIS network policies break hostNetwork DaemonSets**. The `allow-dns` egress policy restricts DNS to `kube-system` pods, but Calico doesn't see hostNetwork pods as belonging to any namespace.
3. **Tailscale MagicDNS hijacks `/etc/resolv.conf`**. Use `tailscale set --accept-dns=false` on cluster nodes, or use a custom `resolv-conf` kubelet arg to isolate pod DNS from host DNS.
4. **RKE2's built-in NodeLocal DNS is broken on Hetzner**. The Helm chart hardcodes `force_tcp` with no override. Deploy NodeLocal DNS manually with `prefer_udp` instead.
5. **The `ipvs: true` mode is cleaner than `ipvs: false`**. It avoids iptables NOTRACK rules entirely and only requires a kubelet `--cluster-dns` override. The tradeoff is that existing pods must be restarted to pick up the new nameserver.
