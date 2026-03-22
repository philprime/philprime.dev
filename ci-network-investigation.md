# CI Network Issues Investigation

## Problem

CI jobs are regularly failing due to network issues on the Kubernetes cluster. Two categories observed:

1. **DNS issues (UDP)** — Alpine `apk` failing with `DNS: transient error (try again later)`
2. **TCP packet issues** — connection stalls/failures during CI builds

### Example Failure

- **Run:** https://github.com/kula-app/kula-cloud/actions/runs/22704226677/job/65828439248
- **Job:** Build - Worker RSS / Build & Publish
- **Runner:** `k8s-ci-default-hwjnd-runner-r2q8q`
- **Error:** `apk add --no-cache bash` failed because DNS couldn't resolve `dl-cdn.alpinelinux.org`
- **Timestamp:** 2026-03-05T05:53:12Z

## Cluster Network Architecture

Discovered via investigation and the [Migrating from k3s to RKE2 guide](/guides/migrating-k3s-to-rke2):

- **CNI:** Canal (Calico Felix for routing/policy + Flannel for overlay)
- **Overlay:** Flannel with **WireGuard** backend (not VXLAN)
- **WireGuard tunnel MTU:** 1420
- **Pod veth MTU:** 1360 (correctly configured via `calico.vethuMTU`)
- **TCP MSS clamping:** Active via `mss-clamp` DaemonSet (4/4 nodes)
- **CoreDNS `bufsize`:** 1232 (configured to prevent large DNS responses from fragmenting)
- **Nodes:** kang, juggernaut, mystique, doom (all running Canal DaemonSet, 0 restarts)

## Root Cause: Confirmed

### IP Fragment Reassembly Failures

The root cause is **UDP packet fragmentation inside the WireGuard tunnel**, with fragments being silently dropped by conntrack + iptables INVALID rules.

Evidence from `/proc/net/snmp` on kang (2026-03-05):

| Counter | Value | Meaning |
|---|---|---|
| `ReasmReqds` | 295 | Total reassembly attempts |
| `ReasmOKs` | 88 | Successful reassemblies |
| `ReasmFails` | **103** | **Failed reassemblies (54% failure rate)** |
| `FragOKs` | 9 | Successful fragmentations |
| `FragCreates` | 18 | Fragments created |

Cumulative `ReasmFails` per node (since last reboot):

| Node | ReasmFails |
|---|---|
| kang | 103 |
| doom | 56 |
| mystique | 19 |
| juggernaut | 8 |

### How It Happens

1. A DNS response (or any UDP packet > tunnel MTU) enters the WireGuard tunnel between nodes
2. The kernel fragments the packet to fit the 1420-byte tunnel MTU
3. Linux conntrack (`nf_conntrack`) attempts to reassemble fragments — and fails
4. Conntrack marks the individual fragments as `INVALID`
5. **85 iptables rules** from kube-proxy (`KUBE-FORWARD`) and Calico Felix (`cali-fw-*`, `cali-tw-*`) silently drop all `INVALID` packets
6. The DNS client in the CI pod sees no response → `DNS: transient error (try again later)`

Small DNS queries succeed (response fits in one packet). Large responses (DNSSEC, dual-stack records, big TXT) fail silently.

### Two Distinct Failure Modes

| Mode | Cause | Metric signal | Example error |
|---|---|---|---|
| **UDP fragmentation** | Large DNS responses fragment in WireGuard tunnel, conntrack drops INVALID fragments | `ReasmFails > 0` | `DNS: transient error` |
| **TCP congestion** | WireGuard tunnel saturated during CI load spikes, TCP connections time out | `RetransSegs` spike, `ReasmFails = 0` | `dial tcp 10.43.0.10:53: i/o timeout` |

### Why CoreDNS `bufsize 1232` Isn't Enough

CoreDNS is configured with `bufsize 1232` which tells clients to limit EDNS0 buffer size. However:

- The `bufsize` plugin only controls CoreDNS → pod responses
- Upstream DNS replies (from Cloudflare 1.1.1.1) arriving at the node before CoreDNS processes them can still exceed the tunnel MTU
- Cross-node traffic where the CoreDNS pod is on a different node than the requesting pod traverses the WireGuard tunnel

### TCP Issues Correlation

TCP retransmissions spiked significantly during the failure window (05:51-05:53 UTC):

| Node | Peak retransmits/sec |
|---|---|
| kang | 0.31 |
| juggernaut | 2.97 |
| mystique | 2.51 |
| doom | 3.00 |

A second larger spike occurred around 06:05-06:10 UTC (up to 7.4/sec on doom). TCP MSS clamping is active and working (9.35M packets clamped), so TCP stalls are less severe than UDP, but the retransmissions indicate general WireGuard tunnel congestion during CI load spikes.

### Second Failure: TCP Timeout (09:18 UTC, 2026-03-05)

- **Run:** https://github.com/kula-app/infra/actions/runs/22710796878/job/65848143161
- **Error:** `lookup charts.bitnami.com on 10.43.0.10:53: dial tcp 10.43.0.10:53: i/o timeout`
- **Failure mode:** TCP congestion (not UDP fragmentation)

The DNS client fell back from UDP to TCP, and the TCP connection itself timed out trying to reach the CoreDNS ClusterIP.

Metrics during failure window (09:10–09:25 UTC):

| Metric | Result |
|---|---|
| `IP ReasmFails` | **0 on all nodes** — fragmentation NOT the cause |
| `TCP RetransSegs` | juggernaut 9.09/s, doom 8.58/s, mystique 7.97/s, kang 2.81/s |
| `TCP Timeouts` | kang 2.04/s, mystique 0.075/s |

This confirms the **TCP congestion failure mode**: CI load bursts saturate the WireGuard tunnel, causing massive TCP retransmissions and connection timeouts even for DNS traffic on port 53.

## What Was Ruled Out

Metrics queried for the failure window (05:30-06:15 UTC on 2026-03-05):

| Hypothesis | Metric | Result | Verdict |
|---|---|---|---|
| UDP buffer exhaustion (`rmem_max`) | `node_netstat_Udp_RcvbufErrors` | 0 on all nodes | **NOT the cause** |
| UDP send buffer overflow | `node_netstat_Udp_SndbufErrors` | 0 on all nodes | **NOT the cause** |
| UDP input errors | `node_netstat_Udp_InErrors` | 0 on all nodes | **NOT the cause** |
| Softnet backlog drops (`netdev_max_backlog`) | `node_softnet_dropped_total` | 0 on all nodes | **NOT the cause** |
| Softnet CPU squeeze | `node_softnet_times_squeezed_total` | Noise-level (max 0.12/sec) | **NOT the cause** |
| NIC-level drops | `node_network_receive_drop_total` | 0 on all nodes | **NOT the cause** |
| Conntrack table exhaustion | `node_nf_conntrack_stat_drop` | 0 on all nodes | **NOT the cause** |
| CoreDNS returning SERVFAIL | `coredns_dns_responses_total{rcode="SERVFAIL"}` | No data (zero) | **CoreDNS healthy** |
| CoreDNS upstream broken | `coredns_forward_healthcheck_broken_total` | 0 | **Upstream fine** |
| CoreDNS overloaded | `coredns_forward_max_concurrent_rejects_total` | 0 | **Not overloaded** |
| CoreDNS slow | `coredns_dns_request_duration_seconds` p99 | 17-26ms | **Normal latency** |

The initial hypothesis about `rmem_max` / `netdev_max_backlog` sysctl values being too low was **disproven** — those metrics showed zero errors. The sysctl values in `/etc/sysctl.d/99-kubernetes.conf` are not the cause.

## Sysctl Configuration (Reference)

Current `/etc/sysctl.d/99-kubernetes.conf`:

```ini
# Inotify limits for container workloads
fs.inotify.max_user_watches = 502453
fs.inotify.max_user_instances = 2048
fs.inotify.max_queued_events = 16384

# Socket backlog for high-concurrency workloads
net.core.somaxconn = 65535

# Disable swap for Kubernetes best practice
vm.swappiness = 0
```

While the network buffer defaults are low (e.g. `rmem_max = 212992`), the data shows they are **not being exhausted**. Tuning them may improve general performance but will not fix the fragmentation issue.

## Changes Made

### 1. node_exporter: Added IP reassembly/fragmentation metrics

**File:** `infra/stacks/shared-analytics/setupPrometheus.ts`
**Change:** Added `--collector.netstat.fields` regex to node-exporter `extraArgs`

New metrics now being collected:

| Metric | Purpose |
|---|---|
| `node_netstat_Ip_ReasmFails` | Fragment reassembly failures (the smoking gun) |
| `node_netstat_Ip_ReasmOKs` | Successful reassemblies |
| `node_netstat_Ip_ReasmReqds` | Reassembly attempts |
| `node_netstat_Ip_ReasmTimeout` | Reassembly timeouts |
| `node_netstat_Ip_FragOKs` | Successful fragmentations |
| `node_netstat_Ip_FragFails` | Failed fragmentations |
| `node_netstat_Ip_FragCreates` | Fragments created |
| `node_netstat_TcpExt_ListenOverflows` | TCP listen queue overflows |
| `node_netstat_TcpExt_ListenDrops` | TCP listen drops |
| + additional TCP/UDP counters | General network health |

### 2. Calico Felix metrics: Added scraping

**File:** `ci-infra/scripts/manifests/calico-felix-metrics.yaml`
**Deployed to:** `/var/lib/rancher/rke2/server/manifests/calico-felix-metrics.yaml` on doom

Created a headless Service for Felix metrics (port 9091) with `prometheus.io/scrape: "true"` annotation. The existing `kubernetes-service-endpoints` Prometheus job auto-discovers it.

Key Felix metrics now available:

| Metric | Purpose |
|---|---|
| `felix_int_dataplane_failures` | Felix couldn't apply routing/policy rules |
| `felix_iptables_restore_errors` | iptables rule programming failures |
| `felix_iptables_save_errors` | iptables save failures |
| `felix_nft_errors` | nftables errors |
| `felix_active_local_endpoints` | Managed pod endpoints per node |
| `felix_resyncs_started` | Policy resync events (instability indicator) |

### 3. Cluster Nodes dashboard: Added monitoring panels

**Dashboard:** Cluster Nodes (`cluster-nodes`), version 8

Added two new row sections between "TCP & Connection Health" and "System Health":

**IP Fragmentation & DNS row:**

| Panel | Queries | Purpose |
|---|---|---|
| IP Reassembly Failures | `rate(Ip_ReasmFails[5m])`, `rate(Ip_ReasmOKs[5m])`, `rate(Ip_ReasmReqds[5m])` | The primary signal — spikes here correlate with DNS failures |
| IP Fragmentation | `rate(Ip_FragOKs[5m])`, `rate(Ip_FragFails[5m])`, `rate(Ip_FragCreates[5m])` | Shows when/where packets are being fragmented |
| UDP Errors | `rate(Udp_RcvbufErrors[5m])`, `rate(Udp_SndbufErrors[5m])`, `rate(Udp_InErrors[5m])` | Socket buffer exhaustion (ruled out but monitored) |
| Softnet & Listen Overflows | `rate(softnet_dropped[5m])`, `rate(softnet_squeezed[5m])`, `rate(ListenOverflows[5m])` | Backlog and TCP queue health |

**Calico Felix row:**

| Panel | Queries | Purpose |
|---|---|---|
| Felix Dataplane & iptables | `dataplane_failures`, `iptables_restore_errors`, `iptables_save_errors`, `nft_errors` | CNI health monitoring |
| Felix Endpoints & Resyncs | `active_local_endpoints`, `resyncs_started` | Policy sync stability |

## Mitigations Deployed

### 4. CoreDNS: Scaled to 4 replicas

CoreDNS had 3 replicas with `podAntiAffinity` (one per node), leaving **juggernaut without a local CoreDNS pod**. All DNS queries from juggernaut had to cross the WireGuard tunnel. Scaled to 4 replicas so every node has a local CoreDNS instance.

CoreDNS service had `internalTrafficPolicy: Cluster`, meaning DNS queries were load-balanced to any CoreDNS pod cluster-wide — even pods co-located with CoreDNS could be routed cross-node.

### 5. NodeLocal DNS Cache: Deployed

**File:** `ci-infra/scripts/manifests/nodelocaldns.yaml`
**Deployed to:** `/var/lib/rancher/rke2/server/manifests/nodelocaldns.yaml` on doom
**Upstream reference:** https://github.com/kubernetes/kubernetes/blob/master/cluster/addons/dns/nodelocaldns/nodelocaldns.yaml

DaemonSet running `k8s-dns-node-cache:1.26.0` on all 4 nodes.

#### How it works with CoreDNS

NodeLocal DNS Cache does **not** replace CoreDNS. They work in layers:

```
Pod DNS query
    │
    ▼
resolv.conf: nameserver 10.43.0.10  (unchanged)
    │
    ▼
iptables DNAT (added by node-local-dns)
    │  intercepts 10.43.0.10 → serves locally
    ▼
NodeLocal DNS Cache (on same node, binds to both 169.254.20.10 and 10.43.0.10)
    │
    ├── Cache HIT → respond immediately (no network)
    │
    └── Cache MISS → forward upstream:
            ├── cluster.local, arpa → CoreDNS via kube-dns-upstream service (UDP)
            └── everything else    → Cloudflare 1.1.1.1 directly (TCP)
```

CoreDNS remains the authoritative source for `cluster.local` (service/pod DNS). NodeLocal DNS Cache reduces cross-node traffic by caching responses locally.

#### Design decisions

| Decision | Rationale |
|---|---|
| **Binds to both `169.254.20.10` and `10.43.0.10`** | Required for iptables mode — node-cache takes over the ClusterIP on each node. Matches upstream manifest. |
| **Internal zones → CoreDNS via UDP** | Internal DNS responses are small, won't fragment. TCP forwarding was tried first but timed out due to the same tunnel congestion we're fixing. |
| **External zone → Cloudflare 1.1.1.1 via force_tcp** | Bypasses CoreDNS entirely for external lookups. Uses TCP to avoid large UDP response fragmentation. |
| **`-setupiptables=true`** | Transparently intercepts traffic to ClusterIP — no kubelet `--cluster-dns` change needed. |
| **`-setupinterface=true`** | Creates dummy interface with `169.254.20.10`. Requires `NET_ADMIN`. |
| **`__PILLAR__CLUSTER__DNS__` in Corefile** | Resolved at startup by node-cache via `-upstreamsvc kube-dns-upstream`. Resolves to the `kube-dns-upstream` Service ClusterIP. |
| **`kube-dns-upstream` headless Service** | Dedicated service for node-cache → CoreDNS forwarding (matches upstream pattern). |
| **`node-local-dns` headless Service** | Exposes port 9253 metrics for Prometheus service discovery. |
| **`-skipteardown=true`** | Prevents DNS downtime if container is OOMKilled (iptables rules persist). |
| **Security hardened** | `drop: ALL` + explicit `NET_ADMIN`, `NET_BIND_SERVICE`, `allowPrivilegeEscalation: false`. Stricter than upstream. |

#### Differences from upstream manifest

| Item | Upstream | Ours | Reason |
|---|---|---|---|
| Internal zone forwarding | `force_tcp` | UDP | TCP times out under WireGuard congestion |
| External zone forwarding | Via CoreDNS (`__PILLAR__UPSTREAM__SERVERS__`) | Direct to Cloudflare `1.1.1.1` | Reduces cross-node traffic, faster external DNS |
| Security context | `NET_ADMIN` only | `drop: ALL` + `NET_ADMIN` + `NET_BIND_SERVICE` | Stricter security |
| Readiness probe | Missing | Added | Prevents traffic before DNS is ready |
| `skipteardown` | Default (false) | `true` | Prevents DNS downtime on OOM |
| `maxUnavailable` | 10% | 1 | Safer for DNS availability |

#### Iterative fixes during deployment

1. **Image version** — `1.25.1` doesn't exist; corrected to `1.26.0`
2. **`-setupinterface=false`** caused bind failure — `169.254.20.10` didn't exist on the host. Changed to `true`.
3. **`drop: ALL` capabilities** blocked port 53 binding — added `NET_BIND_SERVICE` back.
4. **Missing `/etc/coredns/Corefile.base`** — restored `config-volume` mount.
5. **`force_tcp` to CoreDNS** caused health check timeouts — the TCP congestion we're fixing also affected the cache's own upstream. Removed `force_tcp` for internal zones.
6. **`-setupiptables=false`** — pods couldn't reach `169.254.20.10` (link-local not routable from pod network). Changed to `true` and restored `xtables-lock` mount.
7. **`bind` and `-localip` only had `169.254.20.10`** — in iptables mode, must bind to both `169.254.20.10` AND `10.43.0.10`. Cross-checked against upstream manifest.
8. **Added `kube-dns-upstream` Service** — enables `__PILLAR__CLUSTER__DNS__` substitution and matches upstream pattern.
9. **Image `1.26.7`** from upstream master doesn't exist — `1.26.0` is the latest release.

### 6. CoreDNS dashboard: Added NodeLocal DNS Cache section

**Dashboard:** CoreDNS (`coredns`), version 5

Added **NodeLocal DNS Cache** row with 6 panels:

| Panel | Queries | Purpose |
|---|---|---|
| Requests (by node) | `rate(coredns_dns_requests_total{k8s_app="node-local-dns"}[5m])` by node | DNS traffic volume per node |
| Cache hitrate (by node) | cache hits / cache requests by node | Cache efficiency — high = DNS stays node-local |
| Response Latency (by node) | p50/p99 `coredns_dns_request_duration_seconds` by node | Low = cache hit, high = upstream |
| Responses (by node & code) | `coredns_dns_responses_total` by node, rcode | SERVFAIL detection per node |
| Upstream Forwards (by node & dest) | `coredns_forward_requests_total` by node, to | Shows which nodes forward to CoreDNS vs Cloudflare |
| Cache Size (by node) | `coredns_cache_entries` by node | Cached entries per node |

### 7. Alerting: Network health alerts

Three alert rules created in the **Network Health** group, routing to `slack-feed-infra-alerts`:

| Alert | Condition | Severity | Pending |
|---|---|---|---|
| **IP Fragment Reassembly Failures** | `rate(Ip_ReasmFails[5m]) > 0` on any node | critical | 2m |
| **High TCP Retransmissions** | `rate(Tcp_RetransSegs[5m]) > 5/sec` on any node | warning | 5m |
| **NodeLocal DNS Cache Errors** | `coredns_dns_responses_total{rcode="SERVFAIL"} > 0.1/sec` on any node | critical | 5m |

## Incident: NodeLocal DNS Cache Caused Cluster-Wide DNS Outage

**Time:** 2026-03-05 ~10:18 UTC
**Duration:** ~10 minutes
**Impact:** Complete DNS failure across all nodes — all pods unable to resolve any DNS

### What happened

After deploying the final version of NodeLocal DNS Cache with `-setupiptables=true` and binding to both `169.254.20.10` and `10.43.0.10`, DNS worked correctly for ~12 minutes. Then external DNS lookups started timing out.

The `.` zone forwarded to Cloudflare `1.1.1.1` via `force_tcp`. When those TCP connections to Cloudflare stalled (likely due to the same WireGuard tunnel congestion), node-local-dns couldn't resolve external domains. Since node-local-dns had taken over the `10.43.0.10` ClusterIP via iptables, pods couldn't fall back to CoreDNS either — **all DNS was routed through node-local-dns with no fallback path**.

### Why it was a full outage (not just degraded)

1. `-setupiptables=true` added NOTRACK rules in the `raw` iptables table, bypassing kube-proxy's DNAT rules for `10.43.0.10`
2. Node-local-dns bound to `10.43.0.10` directly on the host, replacing kube-proxy's load balancing to CoreDNS pods
3. When node-local-dns's upstream forwarding failed, there was **no fallback** — CoreDNS was completely bypassed
4. `-skipteardown=true` meant deleting the DaemonSet **did not clean up the iptables rules** — DNS remained broken until rules were manually flushed

### Recovery

1. Deleted the manifest from `/var/lib/rancher/rke2/server/manifests/`
2. Deleted all k8s resources (`kubectl delete daemonset/svc/configmap/serviceaccount`)
3. **Manually flushed iptables NOTRACK rules on all nodes** — this was required because `-skipteardown=true` preserved the rules after pod deletion

### Why the upstream Kubernetes guide didn't work for us

The [upstream NodeLocal DNS guide](https://kubernetes.io/docs/tasks/administer-cluster/nodelocaldns/) and its [reference manifest](https://github.com/kubernetes/kubernetes/blob/master/cluster/addons/dns/nodelocaldns/nodelocaldns.yaml) are not wrong — they assume a different network topology.

**What the guide assumes:**
- Flat L2/L3 network between nodes (standard CNI like Calico IPIP, Flannel VXLAN, or cloud provider networking)
- CoreDNS is reachable via a reliable, low-latency path from every node
- Binding to ClusterIP + iptables interception is safe because the fallback path (forwarding to CoreDNS upstream) always works
- `-skipteardown=true` is safe because the cache pod restarts quickly, and during the gap kube-proxy handles retries

**What our cluster has:**
- **WireGuard-encrypted tunnels** between nodes (Canal CNI with WireGuard backend)
- The tunnels are the exact bottleneck causing DNS failures — the forwarding path **is** the problem
- When the tunnel congests, **both UDP and TCP to CoreDNS fail**

**Why the guide's recommendations broke our cluster:**

1. **ClusterIP binding + iptables** — NodeLocal DNS took over `10.43.0.10` via `raw/NOTRACK` iptables rules. All DNS traffic went to the local cache instead of CoreDNS. This is working as designed — but it removes the ability to fall back to CoreDNS.

2. **`force_tcp` to Cloudflare** — External DNS forwarded over TCP through the WireGuard tunnel to `1.1.1.1`. When the tunnel congested, TCP connections stalled. The cache couldn't resolve external names.

3. **Internal forwarding also traverses WireGuard** — The `cluster.local` zone forwarding to CoreDNS upstream goes through WireGuard if CoreDNS runs on a different node. Under congestion, *both* internal and external DNS fail.

4. **`-skipteardown=true`** — When we deleted the DaemonSet, iptables rules survived. DNS traffic kept getting redirected to `10.43.0.10` on the local dummy interface with nothing listening. Complete blackhole. The guide recommends this to prevent DNS downtime during OOM restarts — but it assumes the pod *will come back*.

**In a standard cluster**, the forwarding path to CoreDNS is reliable, so the cache is purely a performance optimization. **In our cluster**, the forwarding path is the problem, so a cache in front of it doesn't help on cache misses — it just adds another layer that can fail, and the iptables interception removes the fallback to direct CoreDNS access.

### Lessons learned

1. **`-skipteardown=true` is dangerous** — it prevents cleanup of iptables rules on pod shutdown, turning a DaemonSet deletion into a DNS outage
2. **Binding to the ClusterIP (`10.43.0.10`) is a single point of failure** — if node-local-dns fails, there is no fallback to CoreDNS
3. **`force_tcp` to external upstreams fails under the same WireGuard congestion** we're trying to fix — the mitigation has the same failure mode as the problem
4. **NodeLocal DNS Cache needs more careful testing** — it should be validated under CI load (the exact condition that triggers failures), not just with manual `nslookup` tests
5. **Always validate upstream guides against your network topology** — standard Kubernetes patterns assume flat networking; WireGuard tunnels fundamentally change failure modes

### Status

**NodeLocal DNS Cache is rolled back and NOT deployed.** CoreDNS (4 replicas) is the only DNS provider.

## Analysis: Why WireGuard Congests Under CI Load

The WireGuard congestion isn't a bug — it's an architectural consequence of how WireGuard works, amplified by CI burst patterns.

### Single tunnel per node pair, no prioritization

All pod-to-pod traffic between two nodes shares **one WireGuard tunnel**. DNS, container image pulls, git clones, artifact uploads — everything gets encrypted into the same UDP stream. When CI jobs burst (many pods pulling images simultaneously), bulk transfers starve small critical traffic like DNS. The network can't help because everything inside the tunnel is encrypted and opaque — no QoS, no priority queuing.

### Single-threaded encryption bottleneck

WireGuard encrypts/decrypts using a **single CPU core per peer**. During CI bursts with heavy cross-node traffic, the crypto becomes a CPU bottleneck. Packets queue up waiting for encryption, adding latency to everything — including DNS.

### No built-in congestion control

WireGuard transports everything over UDP. It has **no congestion control of its own**. The inner TCP streams have their own congestion control, but they're unaware of each other — they each independently try to fill the tunnel. When the tunnel saturates:

- Inner TCP streams detect loss and back off, but slowly (retransmit timers)
- The tunnel's UDP packets may get dropped by intermediate switches/routers
- A single dropped WireGuard UDP packet can carry fragments of multiple TCP streams, causing **correlated losses** across unrelated connections

### Head-of-line blocking

If a large encrypted packet is being processed, smaller packets (like DNS) queue behind it. Unlike a flat network where DNS packets can take a different path or be prioritized, inside WireGuard everything is serialized through the crypto pipeline.

### MTU overhead amplifies packet count

WireGuard adds ~60 bytes of overhead per packet (WireGuard header + UDP encapsulation), reducing effective MTU from 1500 → 1420 (tunnel) → 1360 (pod veth). The same data transfer requires **~10% more packets**, meaning more encryption work and more tunnel load.

### CI burst pattern is the worst case

Normal cluster traffic is spread out over time. CI is the opposite:

- A workflow starts → 5-10 pods spawn simultaneously across nodes
- Each pod pulls a container image (hundreds of MB of cross-node traffic)
- Each pod runs `apk add` / `npm install` / `apt-get` (many DNS queries + downloads in parallel)
- All of this hits the WireGuard tunnels at once

This creates a **thundering herd** through the single-threaded crypto pipeline. The tunnel backs up, retransmissions spike, and small UDP packets (DNS) get caught in the queue or dropped.

### Why this wasn't expected

WireGuard is fast for point-to-point VPN use cases (single stream, moderate throughput). The problem surfaces when it's used as a **CNI overlay for an entire cluster** — it carries hundreds of concurrent flows through per-peer tunnels with no traffic shaping. Most clusters use VXLAN (no encryption overhead) or run on cloud provider networks with hardware-accelerated encryption. WireGuard as a Flannel backend is a niche configuration that trades security for throughput.

### The fundamental tension

WireGuard was chosen for **encryption between nodes** (nodes communicate over untrusted networks). But encryption adds CPU cost and serialization, and the CI workload creates exactly the burst pattern that overwhelms it. The options are:

1. **Keep WireGuard, reduce cross-node traffic** — NodeLocal DNS Cache (needs safer retry), local image caches, node affinity for CI pods
2. **Keep WireGuard, increase tunnel capacity** — multi-threaded WireGuard (kernel 5.17+ has some parallelism), faster CPUs, or multiple tunnels per peer
3. **Drop WireGuard, use VXLAN** — no encryption overhead, but traffic between nodes is unencrypted
4. **Drop WireGuard, use IPsec** — hardware-accelerated encryption on some NICs, better throughput than WireGuard under high concurrency

## Incident: WireGuard Backend Toggle Caused Cluster-Wide Networking Outage

**Date:** 2026-03-06
**Duration:** ~2 hours
**Impact:** Complete cross-node pod-to-pod networking failure — all pods unable to reach services on other nodes (DNS, databases, external APIs)

### What happened

The WireGuard backend for Canal/Flannel was temporarily disabled (commented out in HelmChartConfig) and then re-enabled. This left stale VXLAN interfaces on all nodes that broke cross-node routing.

### Timeline

1. WireGuard backend was disabled in `HelmChartConfig` (`rke2-canal`), switching Flannel to default VXLAN backend
2. Canal pods restarted, creating VXLAN interfaces (`flannel.1`, `flannel-v6.1`) and registering VXLAN backend-type in node annotations
3. WireGuard backend was re-enabled in HelmChartConfig
4. Canal pods restarted again, creating WireGuard interfaces (`flannel-wg`, `flannel-wg-v6`)
5. **Problem:** The old VXLAN interfaces persisted, and their more-specific `/24` routes took precedence over the WireGuard `/16` route

### Root cause: Stale VXLAN interfaces and route conflicts

After re-enabling WireGuard, the routing table on each node looked like:

```
10.42.0.0/16 dev flannel-wg scope link          ← WireGuard (correct, but less specific)
10.42.1.0/24 via 10.42.1.0 dev flannel.1 onlink ← stale VXLAN (wrong, but more specific)
10.42.2.0/24 via 10.42.2.0 dev flannel.1 onlink ← stale VXLAN (wrong, but more specific)
10.42.3.0/24 via 10.42.3.0 dev flannel.1 onlink ← stale VXLAN (wrong, but more specific)
```

The `/24` VXLAN routes were more specific than the `/16` WireGuard route, so all cross-node traffic was routed through the old `flannel.1` interface — which was no longer functioning because the VXLAN backend was deactivated.

### Additional complications during recovery

1. **Flannel node annotations persisted:** Even after re-enabling WireGuard in the ConfigMap, Flannel read the cached `backend-type: vxlan` from node annotations. Required manually removing `flannel.alpha.coreos.com/backend-data`, `flannel.alpha.coreos.com/backend-type`, and `flannel.alpha.coreos.com/backend-v6-data` annotations from all nodes.

2. **Longhorn webhook blocked recovery:** The `longhorn-webhook-validator` ValidatingWebhookConfiguration had `failurePolicy: Fail`. Since Longhorn's admission webhook pod couldn't be reached (cross-node networking was broken), it blocked all node annotation updates. Required temporarily deleting the webhook to proceed.

3. **RKE2 restart did NOT clean up VXLAN interfaces:** Restarting `rke2-server`/`rke2-agent` on all nodes did not remove the stale `flannel.1` and `flannel-v6.1` interfaces. They had to be manually deleted with `ip link delete flannel.1` and `ip link delete flannel-v6.1` on each node.

4. **CoreDNS `cache denial 600`:** The CoreDNS config caches negative (NXDOMAIN/SERVFAIL) responses for 600 seconds (10 minutes). During the outage, failed DNS lookups were cached, prolonging the impact even after networking was restored.

### Recovery steps

1. Re-enabled WireGuard in HelmChartConfig (`rke2-canal`)
2. Deleted `longhorn-webhook-validator` ValidatingWebhookConfiguration to unblock operations
3. Removed stale Flannel node annotations from all nodes (`flannel.alpha.coreos.com/backend-data`, `backend-type`, `backend-v6-data`)
4. Restarted Canal DaemonSet (nodes re-registered with WireGuard backend)
5. Restarted RKE2 on all nodes (control-plane first, then worker)
6. Manually deleted stale VXLAN interfaces on all nodes: `sudo ip link delete flannel.1` and `sudo ip link delete flannel-v6.1`
7. Restarted all affected deployments to clear CrashLoopBackOff timers
8. Deleted stuck Prometheus pod to trigger fresh Longhorn volume attachment

### Lessons learned

1. **Never toggle the Flannel backend without a full node reboot/cleanup plan.** Flannel does not clean up interfaces from a previous backend when switching. The stale interfaces and routes persist and conflict with the new backend.

2. **Flannel backend state is stored in node annotations.** Changing the ConfigMap/HelmChartConfig alone is insufficient — the node annotations must also be cleared for Flannel to re-register with the new backend type.

3. **Longhorn `failurePolicy: Fail` is dangerous during network outages.** It blocks all mutating operations on resources that Longhorn watches (including nodes). Consider switching to `failurePolicy: Ignore` or ensuring Longhorn webhook pods are highly available and local to each node.

4. **Route specificity matters.** A `/24` route via a broken interface will always win over a `/16` route via a working interface. When switching overlay backends, all routes from the old backend must be explicitly removed.

5. **To safely switch Flannel backends:**
   - Drain all workloads
   - Stop RKE2 on all nodes
   - Delete old tunnel interfaces (`flannel.1`, `flannel-v6.1`, or `flannel-wg`, `flannel-wg-v6`)
   - Remove Flannel node annotations
   - Update the HelmChartConfig
   - Start RKE2 on all nodes

### PostgreSQL DNS note

During investigation, `postgresql-ha-cluster-1.cloud.kula.app` was found to only resolve via Tailscale MagicDNS (`100.100.100.100` in host `/etc/resolv.conf`), not via CoreDNS upstream (`1.1.1.1`/`1.0.0.1`). This is a pre-existing configuration — pods needing this hostname rely on it resolving through the host's Tailscale DNS, not through CoreDNS. This was unrelated to the WireGuard incident but surfaced during troubleshooting.

## Open Questions

### Why do fragments still occur despite `bufsize 1232`?

The CoreDNS `bufsize 1232` plugin is correctly configured, yet `ReasmFails` is non-zero. Possible explanations:

1. **Upstream DNS → CoreDNS path crosses WireGuard:** If CoreDNS pods run on a different node than where the upstream response arrives, the response traverses the WireGuard tunnel before CoreDNS can clamp it
2. **Non-DNS UDP traffic:** Other UDP traffic (not DNS) may be fragmenting
3. **Historical counters:** The `ReasmFails` values are cumulative since last reboot — some may predate the `bufsize 1232` configuration

## Analysis: Can WireGuard Be Scaled to Handle CI Bursts?

**Investigated 2026-03-07** during a live CI burst from multiple Renovate cronjobs.

### Current hardware and kernel state

| Node | CPU | Cores | Kernel | WG multi-thread | WG Queues |
|---|---|---|---|---|---|
| doom | EPYC 7502P | 64 | 6.12 | Yes (5.17+) | 1 rx, 1 tx |
| juggernaut | Ryzen 7 3700X | 16 (8C/16T) | 6.12 | Yes (5.17+) | 1 rx, 1 tx |
| mystique | Ryzen 7 3700X | 16 (8C/16T) | 6.12 | Yes (5.17+) | 1 rx, 1 tx |
| kang | Ryzen 7 3700X | 16 (8C/16T) | **5.14** | **No** | 1 rx, 1 tx |

All nodes use SIMD-accelerated ChaCha20 (`chacha20-simd`), so per-core crypto is already optimal.

### Observations during live CI burst

TCP retransmissions spiked from near-zero to critical levels within minutes:

| Node | Retrans/sec (idle) | Retrans/sec (CI burst) | Status |
|---|---|---|---|
| doom | 0.13 | **9.0** | Above 5/sec alert threshold |
| juggernaut | 0.0 | **8.7** | Above 5/sec alert threshold |
| mystique | 0.1 | **7.1** | Above 5/sec alert threshold |
| kang | 0.12 | 0.35 | OK (but TCP timeouts elevated) |

IP reassembly failures: **0 on all nodes** (UDP fragmentation mitigations are holding).

Multiple production pods had readiness/liveness probe failures with `context deadline exceeded`, and kube-apiserver on mystique failed etcd-readiness checks — all consistent with WireGuard tunnel congestion.

### Why WireGuard cannot scale for this workload

**1. Single queue per interface.** Even on kernel 6.12 with multi-threaded crypto, Flannel's `flannel-wg` has one TX/RX queue. The kernel parallelizes the ChaCha20 work across cores via workqueues, but packet processing (NAPI polling, softirq) funnels through one core. Doom has 64 cores but the tunnel can only use a fraction.

**2. One tunnel per node pair (Flannel constraint).** WireGuard supports multiple peers per interface, but Flannel creates exactly one `flannel-wg` interface carrying ALL cross-node pod traffic. No way to create parallel tunnels per peer without a different CNI.

**3. Kang is the worst bottleneck.** Kernel 5.14 has no multi-threaded WireGuard. Kang is the worker node where CI pods run, so every CI pod's traffic to services on doom/juggernaut/mystique goes through kang's single-threaded crypto. Upgrading to Rocky 10 (kernel 6.12) would help but not eliminate the problem.

**4. Burst traffic defeats any tuning.** The CI pattern (10+ pods simultaneously pulling images + package installs) creates spikes that overwhelm a single encrypted tunnel regardless of throughput. Retransmissions went from 0 to 9/sec in minutes — this is a burst problem, not a steady-state throughput problem.

### Tuning options (marginal improvement only)

| Tuning | Effect | Impact |
|---|---|---|
| Upgrade kang to Rocky 10 / kernel 6.12 | Multi-threaded WireGuard crypto on worker node | Moderate |
| Increase `tx_queue_len` on `flannel-wg` | Absorb small bursts instead of dropping | Small |
| Increase `net.core.netdev_budget` | More packets processed per softirq cycle | Small |
| CPU pinning for WireGuard softirqs | Dedicate cores to crypto | Small-moderate |

These are marginal — would shift the breaking point from ~10 concurrent CI pods to maybe ~15.

### Conclusion

WireGuard as a Flannel backend **cannot be scaled to handle CI burst traffic**. The architecture (single queue, single tunnel per peer, CPU-bound encryption) is fundamentally mismatched with the thundering-herd pattern of CI workloads. The realistic options are:

1. **Switch to VXLAN** — eliminates encryption overhead entirely (~10x throughput improvement, simple UDP encapsulation). Tradeoff: pod traffic between nodes is unencrypted. Acceptable if nodes are on a private network (Hetzner vSwitch).
2. **Keep WireGuard + reduce cross-node traffic** — per-node image cache, NodeLocal DNS, node affinity for CI pods. Treats symptoms, not root cause.
3. **Switch to IPsec (Calico native)** — hardware-accelerated encryption on some NICs, better concurrency than WireGuard. More complex to set up.

## Analysis: VXLAN + NodeLocal DNS Cache as Combined Solution

Switching to VXLAN removes the WireGuard encryption bottleneck. This also makes NodeLocal DNS Cache **safe to deploy** — the previous outage was caused by WireGuard congestion affecting NodeLocal DNS's upstream forwarding path, which would not happen with VXLAN.

### Why NodeLocal DNS Cache failed with WireGuard but would work with VXLAN

The previous NodeLocal DNS outage (2026-03-05) had this failure chain:

1. NodeLocal DNS took over `10.43.0.10` via iptables NOTRACK rules
2. External DNS forwarded to Cloudflare `1.1.1.1` via `force_tcp`
3. **TCP to Cloudflare stalled** because the WireGuard tunnel was congested
4. Internal DNS forwarded to CoreDNS upstream — **also stalled** through WireGuard
5. No fallback path existed → complete DNS blackhole

With VXLAN, steps 3 and 4 don't happen — there's no encryption bottleneck, so TCP to Cloudflare and UDP to CoreDNS both work reliably. The forwarding path that caused the outage becomes the reliable, low-latency path that the upstream Kubernetes guide assumes.

### Recommended deployment approach

**Switch to VXLAN first**, then deploy NodeLocal DNS Cache:

1. **VXLAN switch** — follow the safe backend switching procedure documented in the WireGuard toggle incident above (drain → stop RKE2 → delete old interfaces → remove annotations → update config → restart)
2. **Validate VXLAN is stable** — run CI burst, confirm retransmissions stay low, no DNS failures
3. **Deploy NodeLocal DNS Cache** with the original upstream-aligned config:
   - `-setupiptables=true`, bind to both `169.254.20.10` and `10.43.0.10`
   - `force_tcp` to Cloudflare for external DNS (safe now that TCP path is reliable)
   - Internal zones → CoreDNS via UDP (as before)
   - `-skipteardown=false` (safer — cleans up iptables on pod shutdown)
   - `kube-dns-upstream` headless Service for internal forwarding
4. **Test under CI load** — trigger Renovate batch and monitor retransmissions, DNS latency, cache hit rate

### Why NodeLocal DNS Cache is still valuable without WireGuard

Even with VXLAN (fast, reliable cross-node networking), NodeLocal DNS provides:

- **Lower DNS latency** — cache hits are served locally with no network hop
- **Reduced CoreDNS load** — CI bursts generate many repeated DNS queries (`dl-cdn.alpinelinux.org`, `registry.npmjs.org`, etc.) that cache perfectly
- **Resilience** — if CoreDNS pods restart or a node has a transient issue, cached DNS continues to work
- **Less cross-node traffic** — even though VXLAN handles it fine, less traffic is always better

### Risk assessment

| Risk | With WireGuard | With VXLAN |
|---|---|---|
| Upstream TCP forwarding stalls | **High** — WireGuard congestion blocks TCP | **Low** — no encryption bottleneck |
| Internal DNS forwarding stalls | **High** — same tunnel congestion | **Low** — VXLAN is fast |
| iptables NOTRACK takeover of ClusterIP | Same risk | Same risk |
| `-skipteardown` leaving stale rules | Mitigated with `-skipteardown=false` | Mitigated with `-skipteardown=false` |
| NodeLocal DNS pod crash | Falls back cleanly with `-skipteardown=false` | Falls back cleanly with `-skipteardown=false` |

## VXLAN Switch: Completed 2026-03-07

### Procedure used (faster than documented safe procedure)

Instead of stopping RKE2 on all nodes, we performed a live switch with minimal downtime (~1-2 min):

1. **Pre-cleaned flannel node annotations** (no disruption) — removed `flannel.alpha.coreos.com/backend-data`, `backend-type`, `backend-v6-data` from all 4 nodes
2. **Set Longhorn webhook to `failurePolicy: Ignore`** as a safety net
3. **Deleted WireGuard interfaces on all 4 nodes** (sudo): `ip link delete flannel-wg` and `ip link delete flannel-wg-v6`
4. **Immediately restarted Canal DaemonSet**: `kubectl rollout restart daemonset/rke2-canal -n kube-system`
5. **Verified all 4 nodes show `backend-type: vxlan`** in annotations
6. **Confirmed cross-node DNS** works (test pod on kang resolving `kubernetes.default.svc.cluster.local` and `dl-cdn.alpinelinux.org`)
7. **Restored Longhorn webhook to `failurePolicy: Fail`**

The HelmChartConfig had already been updated on doom (`/var/lib/rancher/rke2/server/manifests/rke2-canal-config.yaml`) to `backend: "vxlan"` before starting.

**Key insight:** A rolling node-by-node approach does NOT work — VXLAN and WireGuard are different encapsulation protocols and nodes on different backends cannot communicate through the overlay. All nodes must switch at roughly the same time.

### Post-switch issues

#### 1. CoreDNS negative cache caused CI DNS failure

A CI job at 23:11 UTC failed with `getaddrinfo EAI_AGAIN release-assets.githubusercontent.com`. The Canal rollout completed at 23:08-23:09 UTC — during the ~30s networking gap, a DNS query for `release-assets.githubusercontent.com` failed and CoreDNS cached it as a negative result for up to 600 seconds (`cache denial 600`). The job started 2 minutes later and hit the cached failure. DNS resolved fine after the cache expired.

#### 2. VXLAN checksum offloading bug (RKE2 known issue)

After the switch, pods on doom could not reach external hosts (S3, google.com). Investigation showed `tx-checksum-ip-generic: on` on the `flannel.1` VXLAN interface. This is a [known Calico+VXLAN kernel bug](https://github.com/projectcalico/calico/issues/4865) ([RKE2 #1541](https://github.com/rancher/rke2/issues/1541)) — packets leaving through `flannel.1` have offloaded (incomplete) checksums that get dropped.

RKE2 documents this and applies `ChecksumOffloadBroken=true` in the `rke2-calico` chart, but the `rke2-canal` chart uses a different helm value: `calico.felixFeatureDetectOverride`. This value was empty by default, so the fix was never applied.

**Fixed 2026-03-08:** Added `felixFeatureDetectOverride: "ChecksumOffloadBroken=true"` to the HelmChartConfig in `/var/lib/rancher/rke2/server/manifests/rke2-canal-config.yaml`. This sets `FELIX_FEATUREDETECTOVERRIDE=ChecksumOffloadBroken=true` on all calico-node containers, causing Felix to disable `tx-checksum-ip-generic` on `flannel.1` whenever the interface is created. Verified off on all 4 nodes after Canal DaemonSet rollout.

**Note:** Testing outbound connectivity from the `default` namespace was misleading — the `default-deny-ingress` network policy (from RKE2's CIS mode) blocks egress from test pods. Pods in production namespaces (e.g. `kula-production`) had working outbound.

#### 3. doom `maxPods` at capacity

doom had 121 pods running against a kubelet `maxPods` limit of 110. New pods requiring `kubernetes.io/hostname: doom` via node affinity could not be scheduled. Needs `max-pods=250` added to kubelet args in `/etc/rancher/rke2/config.yaml.d/10-network.yaml`.

### RKE2 known issues check

Fetched the [RKE2 known issues page](https://github.com/rancher/rke2-docs/blob/main/docs/known_issues.md) — our findings are **not documented**:

1. WireGuard as Flannel backend cannot handle burst CI workloads (single queue, CPU-bound encryption)
2. Flannel does not clean up old interfaces when switching backends (causes route conflicts and networking outage)
3. Flannel node annotations persist across backend changes (must be manually removed)
4. UDP fragment reassembly failures inside WireGuard tunnels silently dropped by conntrack + iptables INVALID rules

The only related known issue is "Calico with vxlan encapsulation" — the checksum offloading bug, which RKE2 mitigates with `ChecksumOffloadBroken=true`.

## Network Tuning: 2026-03-08

After switching from WireGuard to VXLAN, the encryption bottleneck was eliminated but the cluster still ran with default kernel network settings. All 4 nodes (kang, mystique, juggernaut, doom) use Intel I350 NICs (`igb` driver) and had never been tuned for high-burst Kubernetes workloads. This section documents each tuning change, why it matters, and how to revert it.

### Cluster hardware reference

| Node | CPU | Cores/Threads | Kernel | NIC | HW Queues |
|---|---|---|---|---|---|
| kang | Ryzen 7 3700X | 8c/16t | 5.14 (Rocky 9) | I350 (igb) | 4 rx / 4 tx |
| juggernaut | Ryzen 7 3700X | 8c/16t | 6.12 (Rocky 10) | I350 (igb) | 4 rx / 4 tx |
| mystique | Ryzen 7 3700X | 8c/16t | 6.12 (Rocky 10) | I350 (igb) | 4 rx / 4 tx |
| doom | EPYC 7502P | 32c/64t | 6.12 (Rocky 10) | I350 (igb) | 8 rx / 8 tx |

### 8. VXLAN checksum offloading fix (permanent)

**What:** Set `calico.felixFeatureDetectOverride: "ChecksumOffloadBroken=true"` in the Canal HelmChartConfig on doom (`/var/lib/rancher/rke2/server/manifests/rke2-canal-config.yaml`).

**Why:** VXLAN encapsulation uses a virtual `flannel.1` interface. The Linux kernel's TX checksum offloading assumes a hardware NIC will compute the checksum, but `flannel.1` is a software interface — there's no hardware to offload to. The kernel marks the packet's checksum as "to be computed later" and sends it into the VXLAN tunnel. The receiving node sees an incomplete checksum and drops the packet. This is a [known Calico bug](https://github.com/projectcalico/calico/issues/4865) ([RKE2 #1541](https://github.com/rancher/rke2/issues/1541)).

RKE2 documents a fix via `ChecksumOffloadBroken=true` in the `rke2-calico` chart, but we use `rke2-canal` which has a different helm value path: `calico.felixFeatureDetectOverride` (maps to the `FELIX_FEATUREDETECTOVERRIDE` env var on calico-node). This value was empty by default, so the fix was never applied.

**Effect:** Felix now runs `ethtool -K flannel.1 tx-checksum-ip-generic off` automatically whenever the VXLAN interface is created. The kernel computes checksums in software before sending — packets arrive with valid checksums and are no longer dropped. This is persistent across Canal restarts and node reboots.

**Revert:** Remove `felixFeatureDetectOverride` from the HelmChartConfig. Canal will redeploy and `flannel.1` will revert to offloaded checksums on next interface recreation.

**Verification:**
```bash
ethtool -k flannel.1 | grep tx-checksum-ip-generic
# Expected: tx-checksum-ip-generic: off
```

### 9. BBR congestion control + fq qdisc

**What:** Created `/etc/sysctl.d/90-network-tuning.conf` on all 4 nodes with:
```ini
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
```

**Why:** The default Linux TCP congestion control is **CUBIC**. CUBIC uses a loss-based algorithm — it increases the send rate until packets are dropped, then backs off sharply. This creates a sawtooth pattern of burst → loss → backoff → burst. In a Kubernetes cluster with many concurrent TCP connections (CI pods pulling images, downloading packages, talking to APIs), this means:

1. Multiple TCP connections independently probe for bandwidth
2. They all burst simultaneously, overwhelming NIC queues and VXLAN tunnel buffers
3. Packets drop, all connections back off at once
4. Brief quiet period, then all connections burst again simultaneously
5. This synchronized oscillation creates the retransmission spikes we observed (0 → 9/sec in minutes)

**BBR** (Bottleneck Bandwidth and Round-trip) works differently. Instead of probing until loss, it continuously estimates the available bandwidth and the minimum RTT, then **paces** packets to match the bottleneck rate. There are no bursts — traffic flows smoothly.

**fq** (Fair Queue) qdisc is required for BBR to work properly. BBR tells the kernel "send this packet at time T" and `fq` enforces that pacing. The previous `fq_codel` qdisc doesn't support per-flow pacing — it would batch BBR's carefully-timed packets into bursts, defeating the purpose.

Together, BBR + fq mean:
- Packets are sent at a steady rate instead of in bursts
- Multiple TCP connections share bandwidth fairly without synchronized oscillation
- Retransmissions drop dramatically because congestion is avoided rather than detected-and-recovered
- DNS and other small flows aren't starved by bulk transfers

**Revert:** On each node:
```bash
sudo sysctl net.ipv4.tcp_congestion_control=cubic net.core.default_qdisc=fq_codel
```
Takes effect immediately for new connections. To make permanent, remove the lines from `/etc/sysctl.d/90-network-tuning.conf`.

**Verification:**
```bash
sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc
# Expected: bbr / fq
```

### 10. Kernel socket buffer increase

**What:** Added to `/etc/sysctl.d/90-network-tuning.conf` on all 4 nodes:
```ini
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
```

**Why:** The Linux kernel auto-tunes TCP buffer sizes per connection, but enforces hard ceilings via `rmem_max` and `wmem_max`. The defaults were 208KB — meaning no TCP connection could buffer more than ~200KB of in-flight data, regardless of available bandwidth or RTT.

For a 1 Gbps link with 1ms RTT, the bandwidth-delay product is ~125KB — the default barely covers it. But CI traffic often crosses longer paths (container registries, npm, GitHub) with 20-50ms RTT, where the BDP is 2.5-6.25 MB. At 208KB, the kernel throttles every connection to a fraction of available bandwidth.

The three values in `tcp_rmem` / `tcp_wmem` control auto-tuning:
- **min (4096):** Minimum buffer per socket, even under memory pressure
- **default (87380 / 65536):** Starting buffer for new connections — modest, doesn't waste memory
- **max (134217728 = 128MB):** Upper limit the kernel can auto-tune to for large, long-lived transfers

The kernel only grows buffers when a connection actually needs them (based on RTT and throughput), so setting a high max doesn't waste memory — it just removes the artificial ceiling. A CI pod pulling a 500MB container image over a 20ms path can now use appropriately-sized buffers instead of being capped at 208KB.

**Revert:** On each node:
```bash
sudo sysctl net.core.rmem_max=212992 net.core.wmem_max=212992 \
  net.core.rmem_default=262144 net.core.wmem_default=262144 \
  'net.ipv4.tcp_rmem=4096 131072 6291456' \
  'net.ipv4.tcp_wmem=4096 16384 4194304'
```

**Verification:**
```bash
sysctl net.core.rmem_max net.core.wmem_max net.ipv4.tcp_rmem net.ipv4.tcp_wmem
# Expected: 268435456 / 268435456 / 4096 87380 134217728 / 4096 65536 134217728
```

### 11. NIC ring buffer increase

**What:** Increased hardware ring buffers from 256 to 4096 (the I350's maximum) on all 4 nodes via `ethtool -G <NIC> rx 4096 tx 4096`.

| Node | NIC | Interface |
|---|---|---|
| kang | Intel I350 | enp35s0 |
| mystique | Intel I350 | enp35s0 |
| juggernaut | Intel I350 | enp35s0 |
| doom | Intel I350 | enp195s0 |

**Why:** The NIC ring buffer is a fixed-size circular queue in DMA-accessible memory where the NIC places incoming packets via DMA (Direct Memory Access) before the CPU processes them via softirq. The CPU drains the ring in batches during NAPI polling — if new packets arrive faster than the CPU polls, the ring fills up and the NIC silently drops packets at the hardware level. These drops don't show up in most kernel counters (`netstat`, `ip -s`) — the packet simply never enters the kernel networking stack.

At 256 entries, a burst of ~256 packets arriving within one NAPI poll interval (~1-4ms depending on load) causes drops. For context:

- A single 500MB container image pull over a 1 Gbps link at MTU 1450 generates ~360,000 packets
- At line rate, that's ~45,000 packets/second, or ~180 packets per 4ms NAPI interval — from **one** connection
- During CI bursts, 10+ pods pull images simultaneously — easily exceeding 256 packets between polls

At 4096 entries, the NIC can buffer 16x more packets, absorbing multi-millisecond CPU stalls (garbage collection, context switches, other interrupt work) without dropping.

**Note:** This change does not persist across reboots. Persistence will be handled via a systemd service after all ethtool changes are finalized.

**Revert:** On each node:
```bash
sudo ethtool -G <NIC> rx 256 tx 256
```

**Verification:**
```bash
ethtool -g <NIC> | grep -A4 "Current hardware"
# Expected: RX: 4096, TX: 4096
```

### 12. RPS (Receive Packet Steering) enabled

**What:** Set `rps_cpus` to all CPUs on every hardware RX queue of the physical NIC on all 4 nodes.

| Node | NIC | Queues | CPU mask |
|---|---|---|---|
| kang | enp35s0 | rx-0..3 | `ffff` (16 threads) |
| mystique | enp35s0 | rx-0..3 | `ffff` (16 threads) |
| juggernaut | enp35s0 | rx-0..3 | `ffff` (16 threads) |
| doom | enp195s0 | rx-0..7 | `ffffffff,ffffffff` (64 threads) |

**Why:** When a network packet arrives, the NIC places it in one of its hardware RX queues and raises an interrupt. The CPU core that handles the interrupt also runs the entire networking stack for that packet: IP header parsing, conntrack lookup, iptables/nftables rule evaluation, VXLAN decapsulation, and finally delivery to the socket. Without RPS, each RX queue is bound to a single CPU core — so 4 queues means only 4 of the node's 16 (or 64) cores handle all network processing.

During CI bursts, these 4 cores hit 100% softirq utilization while the remaining cores are idle (for networking). This creates a CPU-side bottleneck that looks identical to network congestion: packets queue up, latency spikes, TCP retransmits increase, and DNS queries time out.

RPS (Receive Packet Steering) fixes this by adding a software hash step after the NIC interrupt. The interrupt handler computes a hash of each packet's flow (src/dst IP + port), and uses it to select a target CPU from the `rps_cpus` mask. The actual packet processing (the expensive part — conntrack, iptables, VXLAN) then runs on the target CPU via an inter-processor interrupt (IPI). This distributes the work across all cores while preserving per-flow ordering (same flow always goes to the same CPU, preventing TCP reordering).

The CPU mask should include all available cores. The kernel handles load balancing — flows are distributed by hash, and since CI workloads have many concurrent connections (each pod has multiple TCP streams), the distribution is naturally even.

**Note:** This change does not persist across reboots. Persistence will be handled via a systemd service after all ethtool/sysfs changes are finalized.

**Revert:** On each node:
```bash
echo 0 | sudo tee /sys/class/net/<NIC>/queues/rx-*/rps_cpus
```

**Verification:**
```bash
cat /sys/class/net/<NIC>/queues/rx-*/rps_cpus
# Expected: ffff (16t) or ffffffff,ffffffff (64t) for each queue
```

### 13. netdev_max_backlog and tcp_max_syn_backlog increase

**What:** Added to `/etc/sysctl.d/90-network-tuning.conf` on all 4 nodes:
```ini
net.core.netdev_max_backlog = 250000
net.ipv4.tcp_max_syn_backlog = 8192
```

**Why — netdev_max_backlog (1000 → 250000):**

When a packet arrives at a CPU core (either directly from a hardware interrupt or via RPS), it's placed in that core's **backlog queue** before being processed by the networking stack. The kernel processes this queue in softirq context — but softirq has a time budget (`netdev_budget`). If packets arrive faster than the softirq budget allows processing, they accumulate in the backlog. When the backlog reaches `netdev_max_backlog`, new packets are dropped and the `softnet_dropped` counter increments.

At the default of 1000, a single burst of >1000 packets arriving at one core (before the next softirq cycle) causes drops. With VXLAN overlay traffic and CI bursts, this is easily exceeded — a 1 Gbps burst at MTU 1450 delivers ~86,000 packets/second, or ~860 packets per 10ms softirq interval per core. A brief 15ms stall (e.g., a context switch or lock contention) and the backlog overflows.

250000 provides deep buffering: even if softirq is delayed for 100ms, the queue absorbs the burst instead of dropping.

**Why — tcp_max_syn_backlog (4096 → 8192):**

This controls the maximum number of pending TCP connections in the SYN_RECV state (connection half-open, waiting for the final ACK). During CI bursts, many pods simultaneously open connections to external services (registries, npm, GitHub). If the SYN backlog fills up, new connection attempts are silently dropped, causing connection timeouts. 8192 provides headroom for burst connection storms.

**Revert:** On each node:
```bash
sudo sysctl net.core.netdev_max_backlog=1000 net.ipv4.tcp_max_syn_backlog=4096
```

**Verification:**
```bash
sysctl net.core.netdev_max_backlog net.ipv4.tcp_max_syn_backlog
# Expected: 250000 / 8192
```

### Burst test results after tuning (fixes 8-13)

Triggered all 4 Renovate cronjobs simultaneously to create a CI burst. Compared against the pre-tuning burst from 2026-03-07.

| Metric | | kang | doom | mystique | juggernaut |
|---|---|---|---|---|---|
| **TCP retransmits/sec** | pre-tuning | 0.35 | 9.0 | 7.1 | 8.7 |
| | **post-tuning** | **4.12** | **6.35** | **6.15** | **6.82** |
| | change | +3.77 (was idle) | **-29%** | **-13%** | **-22%** |
| **Softirq CPU (cores)** | post-tuning | 0.11/16 | 0.41/64 | 0.18/16 | 0.22/16 |
| **Softnet dropped** | post-tuning | 0 | 0 | 0 | 0 |
| **Softnet squeezed** | post-tuning | 0.13 | 0.63 | 0.44 | 0.46 |
| **IP ReasmFails** | post-tuning | 0 | 0 | 0 | 0 |

**Conclusions:**
- TCP retransmits improved ~20-30% on the nodes that were worst affected
- CPU is **not** the bottleneck — softirq uses <1% of available cores, GRO tuning would not help
- No packet drops at any layer (softnet, reassembly)
- Retransmits still above 5/sec on 3 nodes during burst — remaining issue is likely physical network path (Hetzner vSwitch, inter-node link) or needs further investigation
- Kang shows higher retransmits than baseline because it was idle during pre-tuning test but now has CI pods running on it

### 14. nf_conntrack_max increase

**What:** Added to `/etc/sysctl.d/90-network-tuning.conf` on kang, mystique, and juggernaut:
```ini
net.netfilter.nf_conntrack_max = 1048576
```
Doom was already at 2097152 (kernel auto-calculated based on its larger RAM) and was left unchanged.

**Why:** Linux's `nf_conntrack` module tracks every network connection that passes through iptables NAT or stateful firewall rules. In a Kubernetes cluster, **every** pod-to-service connection creates a conntrack entry — kube-proxy uses iptables DNAT to translate the Service ClusterIP to a backend pod IP, and conntrack stores this mapping so return packets can be un-NAT'd correctly.

Each conntrack entry consumes ~320 bytes of kernel memory and lives for the duration of the connection (plus a timeout — 120s for established TCP, 30s for UDP). The table is a hash table with a fixed number of buckets; when it fills up, the kernel drops new connections with `nf_conntrack: table full, dropping packet` in dmesg. This manifests as random connection failures — DNS queries that sometimes work and sometimes don't, HTTP requests that intermittently time out.

The previous default of 524288 (~167MB of kernel memory) wasn't being exhausted during normal operation (~5000 entries in use), but with the other tunings increasing throughput and concurrency, the headroom was too thin. At 1048576 (~335MB), the table has 200x headroom over current usage, ensuring it won't be a bottleneck even during extreme CI bursts.

**Revert:** On each affected node:
```bash
sudo sysctl net.netfilter.nf_conntrack_max=524288
```

**Verification:**
```bash
sysctl net.netfilter.nf_conntrack_max
# Expected: 1048576 (kang/mystique/juggernaut), 2097152 (doom)
# Current usage: cat /proc/sys/net/netfilter/nf_conntrack_count
```

### DNS failure during burst test

During the burst test (4 simultaneous Renovate jobs), one pod failed with:

```
Error generating config: getaddrinfo EAI_AGAIN api.github.com
```

This was the `generate-config` init container in `renovate-f2afae12-4943b678-29549835-jz9w9` on doom. Notably, `yarn install` in the same container succeeded (fetched 41 packages) — the DNS failure occurred ~3 seconds later when querying `api.github.com`.

**Root cause identified: CoreDNS `internalTrafficPolicy: Cluster`**

The CoreDNS service (`rke2-coredns-rke2-coredns`, ClusterIP `10.43.0.10`) was configured with `internalTrafficPolicy: Cluster`. This means kube-proxy load-balances DNS queries across all 4 CoreDNS pods regardless of node locality. With 4 CoreDNS pods (one per node), any DNS query has a 75% chance of crossing the VXLAN overlay to a CoreDNS on another node.

During CI bursts, the VXLAN overlay is congested (6-7 retransmits/sec). A DNS query that crosses the overlay is a small UDP packet that can easily be lost — unlike TCP, there's no automatic retry at the transport level. The application's DNS resolver has a timeout (typically 5s), after which it returns `EAI_AGAIN`.

The fix: set `internalTrafficPolicy: Local`. This tells kube-proxy to only route DNS queries to the CoreDNS pod on the same node as the requesting pod. Since we already have 4 CoreDNS replicas (one per node with `podAntiAffinity`), every DNS query stays node-local — no VXLAN traversal for DNS at all.

This is simpler and safer than NodeLocal DNS Cache because:
- No iptables NOTRACK rules that can blackhole DNS
- No new DaemonSet to manage
- CoreDNS remains the DNS server (no cache layer in front)
- Instantly reversible with a single kubectl patch

The upstream query from CoreDNS to Cloudflare `1.1.1.1` still goes over the physical NIC, but that path doesn't traverse VXLAN and is not affected by inter-node congestion.

### 15. CoreDNS `internalTrafficPolicy: Local` — not applied

**What:** Set `internalTrafficPolicy: Local` on the CoreDNS service via the RKE2 HelmChartConfig on doom (`/var/lib/rancher/rke2/server/manifests/rke2-coredns-config.yaml`):

```yaml
    service:
      internalTrafficPolicy: Local
```

**Why:** With `internalTrafficPolicy: Cluster` (the default), kube-proxy load-balances DNS queries to any CoreDNS pod in the cluster. With 4 CoreDNS pods (one per node), each DNS query has a 75% probability of crossing the VXLAN overlay to reach a CoreDNS pod on a different node.

DNS uses UDP — a single packet with no transport-level retransmission. If that packet (or the response) is lost due to VXLAN congestion during a CI burst, the application's resolver waits for its timeout (typically 5 seconds) and returns `EAI_AGAIN`. TCP has retransmission built in, so a lost TCP segment is automatically resent. UDP does not — a single dropped packet means a failed DNS query.

Setting `internalTrafficPolicy: Local` tells kube-proxy to only route to endpoints on the same node. Since we have 4 CoreDNS replicas with `podAntiAffinity` ensuring one per node, every DNS query stays entirely within the node — no VXLAN traversal, no exposure to inter-node congestion.

This is simpler and safer than NodeLocal DNS Cache because:
- No iptables `NOTRACK` rules that can blackhole DNS if the cache pod dies
- No new DaemonSet to manage
- CoreDNS remains the DNS server (no extra caching layer)
- Instantly reversible by changing back to `Cluster`

The upstream query from CoreDNS to Cloudflare (`1.1.1.1`) still goes over the physical NIC directly — it doesn't traverse VXLAN and is unaffected by inter-node congestion.

**Prerequisite:** CoreDNS replica count must be >= node count. If a node has no local CoreDNS pod, all DNS from pods on that node will fail. The current config has `replicaCount: 4` with `autoscaler.min: 4` and `preventSinglePointFailure: true`, satisfying this requirement.

**Why not applied:** The RKE2 `rke2-coredns` helm chart (bundled with RKE2) does not template `service.internalTrafficPolicy` in its service manifest. The helm value `service.internalTrafficPolicy` is silently ignored — the rendered service never includes the field. The only way to apply it is via `kubectl patch`, which is not scalable: any helm chart reconciliation (triggered by RKE2 upgrades or HelmChartConfig changes) resets the service and drops the patched field. A proper fix requires either an upstream chart change or an alternative approach like NodeLocal DNS Cache.

**Revert (if applied manually):**
```bash
kubectl patch service rke2-coredns-rke2-coredns -n kube-system -p '{"spec":{"internalTrafficPolicy":"Cluster"}}'
```

**Verification:**
```bash
kubectl get service rke2-coredns-rke2-coredns -n kube-system -o jsonpath='{.spec.internalTrafficPolicy}'
# Expected: Local
```

## Next Steps

### High priority — Post-VXLAN stabilization
- [x] ~~Switch Flannel backend to VXLAN~~ — completed 2026-03-07
- [x] ~~Update `vethuMTU` to `1450` in HelmChartConfig~~ — already applied, pod veth and flannel.1 both at 1450, verified 2026-03-08
- [x] ~~Update MSS clamp DaemonSet~~ — already uses `--clamp-mss-to-pmtu` (auto-adapts to path MTU), no hardcoded value to change
- [x] ~~Fix VXLAN checksum offloading~~ — added `calico.felixFeatureDetectOverride: "ChecksumOffloadBroken=true"` to HelmChartConfig, completed 2026-03-08
- [ ] Increase doom `maxPods` to 250 — add `"max-pods=250"` to `kubelet-arg` in `/etc/rancher/rke2/config.yaml.d/10-network.yaml`, requires `systemctl restart rke2-server`
- [ ] Validate: run CI burst after stabilization, confirm TCP retransmissions stay below 1/sec
- [ ] Upgrade kang from Rocky 9 (kernel 5.14) to Rocky 10 (kernel 6.12) — even with VXLAN, the newer kernel has better networking performance. Kang is the only node still on the old OS.

### High priority — DNS locality
- [ ] ~~Set CoreDNS service `internalTrafficPolicy: Local`~~ — not applied, RKE2's `rke2-coredns` helm chart does not template this field. `kubectl patch` is not scalable (reset on chart reconciliation). Need alternative approach (NodeLocal DNS Cache or upstream chart fix).
- [ ] Test under CI load — trigger Renovate batch and confirm no `EAI_AGAIN` errors
- [ ] Monitor for 48h before declaring stable
- [ ] Re-evaluate NodeLocal DNS Cache — may still be valuable for caching (reduced CoreDNS load, lower latency), but no longer critical for reliability now that DNS stays node-local

### High priority — Longhorn webhook resilience
- [ ] Evaluate changing Longhorn `ValidatingWebhookConfiguration` `failurePolicy` from `Fail` to `Ignore` — during network outages, `Fail` blocks all cluster operations including recovery
- [ ] Verify Longhorn auto-recreates the `longhorn-webhook-validator` after deletion (was deleted during 2026-03-06 incident recovery)

### Medium priority — DNS resilience
- [ ] Reduce CoreDNS `cache denial 600` to 30-60s — 10-minute negative cache prolongs outages (confirmed during VXLAN switch: a 30s networking gap caused 10 minutes of DNS failures for affected domains)
- [ ] Investigate `postgresql-ha-cluster-1.cloud.kula.app` DNS — only resolves via Tailscale MagicDNS, not CoreDNS upstream. Consider adding a CoreDNS forward zone for `cloud.kula.app` to Tailscale DNS (`100.100.100.100`) or adding it as a static entry.

### High priority — Network tuning (all nodes)
- [x] ~~Enable BBR + fq qdisc~~ — switched from cubic/fq_codel to bbr/fq on all 4 nodes via `/etc/sysctl.d/90-network-tuning.conf`, completed 2026-03-08. BBR paces packets smoothly, reducing retransmits during CI bursts.
- [x] ~~Increase kernel socket buffers~~ — rmem_max/wmem_max to 256MB, tcp_rmem/tcp_wmem max to 128MB, completed 2026-03-08
- [x] ~~Increase NIC ring buffers from 256 to 4096~~ — all nodes, Intel I350, completed 2026-03-08 (not yet persistent across reboots)
- [x] ~~Enable RPS to spread packet processing across CPU cores~~ — all cores on all nodes, completed 2026-03-08 (not yet persistent across reboots)
- [x] ~~Increase netdev_max_backlog from 1000 to 250000~~ — also tcp_max_syn_backlog to 8192, completed 2026-03-08
- [x] ~~Increase nf_conntrack_max to 1048576~~ — kang/mystique/juggernaut (doom already at 2097152), completed 2026-03-08
- [x] ~~Evaluate disabling GRO on physical NIC~~ — tested under CI burst 2026-03-08, softirq CPU at 0.4 cores (doom, 64 available) — CPU is not a bottleneck, GRO change not needed

### Medium priority — Persistence for non-sysctl tunings
- [ ] Create systemd service to persist NIC ring buffers (4096) and RPS across reboots — currently lost on reboot
- [ ] Verify `ChecksumOffloadBroken=true` persists across Canal restarts (should, via HelmChartConfig)

### Medium priority — remaining investigation
- [ ] Investigate upstream DNS response sizes hitting CoreDNS (may need packet capture)
- [ ] Evaluate `nf_conntrack` tuning to allow fragment reassembly (e.g. `net.netfilter.nf_conntrack_frag6_timeout`)
  - Note: with VXLAN, the fragmentation issue may change character (different overhead, no crypto) — re-evaluate after switching

### Low priority
- [ ] Report WireGuard backend switching issues to [rke2 GitHub](https://github.com/rancher/rke2/issues) — stale interfaces and annotations are a bug affecting anyone switching Flannel backends
