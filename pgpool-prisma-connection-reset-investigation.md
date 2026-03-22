# Investigating PrismaClientKnownRequestError: Cross-Cloud PostgreSQL Connection Resets

## The Problem

Our application `asm-api` — a NestJS service that indexes Apple App Store metadata — was reporting persistent `PrismaClientKnownRequestError` exceptions in Sentry. The error message was always the same:

```
Can't reach database server at `postgresql-ha-cluster-1.cloud.kula.app:45432`
```

Over a three-week period (Feb 16 – Mar 10, 2026), we accumulated over 1,100 events across multiple Sentry issues (ASM-API-22, ASM-API-2H, ASM-API-26, and others). The errors affected both `findUnique()` and `upsert()` operations on the `imageProbingCacheEntry` table, all originating from the `ImageProbingService.getLargestImageUrl` function.

The initial assumption was that this was a networking issue — perhaps the NIC couldn't handle burst traffic from our batch import jobs. CPU and memory were not saturated, which made the networking theory compelling. This document traces the full investigation from that hypothesis through to the actual root cause and fix.

## Tools Used

This investigation was conducted from a terminal session on `kang`, one of the cluster worker nodes. The following tools and data sources were used:

- **Sentry CLI** (`sentry` v0.14.0): To retrieve issue details, stack traces, span trees, and event metadata directly from Sentry
- **kubectl**: To inspect pods, services, deployments, configmaps, and exec into containers across two Kubernetes clusters (Hetzner `prod-hel1-2` and AWS EKS `kula-shared`)
- **Grafana MCP server** (via Claude Code): To query Prometheus metrics for TCP statistics, bandwidth utilization, and connection counts with PromQL
- **AWS CLI** (`scripts/aws.sh`): To inspect NLB attributes and target group configuration
- **ethtool / ip / tc / /proc/net/softnet_stat**: For NIC hardware stats, ring buffers, qdisc drops, and kernel network processing metrics
- **SSH**: To access all four cluster nodes (kang, juggernaut, mystique, doom) for log collection and sysctl changes

## Discovering the Architecture

The first step was understanding the full network path between the application and the database.

### Where the pods run

Using `kubectl get pods -A -o wide` on the Hetzner cluster (`prod-hel1-2`), we found:

| Pod | Node | Role |
|-----|------|------|
| asm-api-b0a9ef88-ccbbdb6c6-2rtjn | doom | API server |
| asm-api-b0a9ef88-ccbbdb6c6-q6chp | juggernaut | API server |
| asm-mcp-25ca97ab-68cd5f945b-s7scv | mystique | MCP worker |
| asm-mcp-25ca97ab-68cd5f945b-xl5s6 | juggernaut | MCP worker |
| asm-relay-bff44bfb-7f68d965dc-lmphq | doom | Relay |
| asm-relay-bff44bfb-7f68d965dc-srpwn | kang | Relay |
| asm-web-7f7cb6df-855884b79c-jxst4 | kang | Web frontend |
| asm-web-7f7cb6df-855884b79c-rq586 | juggernaut | Web frontend |

Critically, **kang only runs asm-relay and asm-web** — no database-connected workloads. This became important later.

### Where the database lives

The `DATABASE_URL` environment variable in the asm-api pods pointed to:

```
postgresql://asm-production:***@postgresql-ha-cluster-1.cloud.kula.app:45432/asm-production?sslmode=require
```

DNS resolution of `postgresql-ha-cluster-1.cloud.kula.app` returned AWS IP addresses (`52.57.207.219`, `3.66.53.164`), confirming the database was not on the local Hetzner cluster but on the AWS EKS cluster (`kula-shared`).

### The full network path

By inspecting the AWS cluster's services, configmaps, and nginx-ingress configuration, we mapped the complete path:

```
asm-api pods (Hetzner: doom, juggernaut, mystique, kang)
  → internet (Hetzner → AWS, cross-cloud)
    → AWS NLB (a497c1b2..., TCP passthrough)
      → nginx-ingress TCP stream proxy (port 45432 → pgpool:5432, proxy_timeout=600s)
        → pgpool-II (2 replicas, 64 child processes each)
          → PostgreSQL HA (3 nodes: 1 primary + 2 standby via repmgr)
```

The nginx TCP proxy configuration was found in the `ingress-nginx-nlb-tcp` ConfigMap:

```yaml
"45432": shared-datastore/postgresql-ha-cluster-1-pgpool:5432
```

This meant every database query from the Hetzner cluster traversed the public internet, through an AWS NLB, through an nginx TCP proxy, and into pgpool before reaching PostgreSQL.

## Examining the Sentry Errors

Using the Sentry CLI, we pulled detailed event data for the three most active PrismaClientKnownRequestError issues.

### The call pattern

Every error originated from the same code path. The `AppIndexImportConsumer` processes batch import jobs from a BullMQ queue. For each app, it calls `AppleAppStoreService.getAppById()`, which calls `mapLookupItemToAppleApp()`. That function fires a `Promise.all` with 6 concurrent image probing operations:

```typescript
const [r60, r100, r512, iphoneUrls, ipadUrls, appletvUrls] = await Promise.all([
    this.imageProbingService.getLargestImageUrlWithNullableUrl(lookupItem.artworkUrl60, { ignoreCache }),
    this.imageProbingService.getLargestImageUrlWithNullableUrl(lookupItem.artworkUrl100, { ignoreCache }),
    this.imageProbingService.getLargestImageUrlWithNullableUrl(lookupItem.artworkUrl512, { ignoreCache }),
    this.imageProbingService.mapImageUrlsToLargestImageUrls(iphoneScreenshots, { ignoreCache }),
    this.imageProbingService.mapImageUrlsToLargestImageUrls(ipadScreenshots, { ignoreCache }),
    this.imageProbingService.mapImageUrlsToLargestImageUrls(appletvScreenshots, { ignoreCache }),
]);
```

Each of these calls executes a `prisma.imageProbingCacheEntry.findUnique()` (cache read) and potentially a `prisma.imageProbingCacheEntry.upsert()` (cache write). During batch imports, this creates bursts of 6+ concurrent database operations per job.

### The Prisma client configuration

Examining the application code at `packages/database/src/prisma.service.ts`:

```typescript
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit() {
    await this.$connect();
  }
  async onModuleDestroy() {
    await this.$disconnect();
  }
}
```

A plain `PrismaClient()` with no `connection_limit`, `pool_timeout`, or `connect_timeout` configured. Prisma's default connection pool size is `num_cpus * 2 + 1`, and it holds persistent TCP connections to the database.

## Examining the Database Cluster

### PostgreSQL health

All three PostgreSQL backends were healthy. Using `SHOW pool_nodes` via psql inside the pgpool container:

| Node | Status | Role | Replication Delay |
|------|--------|------|-------------------|
| postgresql-0 | up | primary | 0 |
| postgresql-1 | up | standby | 0 |
| postgresql-2 | up | standby | 0 |

No FATAL errors in any PostgreSQL log. No `max_connections` exhaustion. The database itself was fine.

### Pgpool configuration

The pgpool deployment (from the Pulumi IaC in `createPostgreSqlHaCluster.ts`) had these parameters:

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `numInitChildren` | 64 | 64 preforked child processes per pgpool replica |
| `maxPool` | 16 | 16 cached backend connections per child |
| `childMaxConnections` | **100** | Kill child after 100 client connections |
| `childLifeTime` | **60s** | Kill idle child after 60 seconds |
| `clientIdleLimit` | **60s** | Disconnect idle client after 60 seconds |
| `connectionLifeTime` | **60s** | Kill cached backend connection after 60 seconds |

### Pgpool logs

We dumped 24 hours of pgpool logs to local files and analyzed them. The key finding from pgpool-1:

```
$ grep -c "child exiting, 100 connections reached" /tmp/pgpool-1.log
88
```

**88 child process recycles in 6 hours** on pgpool-1 alone — roughly one every 4 minutes. Each time a child exits, any in-flight connection proxied through that child is terminated.

Meanwhile, pgpool-2 showed only 1 recycle in the same period. This indicated **heavily skewed traffic** between the two pgpool replicas.

At the exact time of a Sentry error (04:16 UTC), the pgpool logs showed no errors whatsoever — just normal authentication handshakes. The pgpool was accepting connections fine. This meant the problem was not pgpool rejecting connections, but the TCP path between Prisma and pgpool breaking when children were recycled.

### NLB and nginx configuration

The AWS NLB had no explicit idle timeout override (default 350s for TCP). The target group for port 45432 had `proxy_protocol_v2.enabled=false` and `stickiness.enabled=false`.

The nginx TCP stream proxy was configured with `proxy_timeout=600s` and `proxy_next_upstream_tries=3`.

No component in the chain was explicitly rejecting connections. The issue was subtler.

## The TCP Metrics: Finding the Smoking Gun

Using the Grafana MCP server, we queried Prometheus for TCP-level metrics on the Hetzner cluster nodes during the error window (03:50–04:40 UTC on March 10).

### TCP Established Resets

```promql
rate(node_netstat_Tcp_EstabResets[5m])
```

| Node | EstabResets/sec | Runs DB workloads? |
|------|----------------|--------------------|
| **kang** | **0.008** | No (relay + web only) |
| juggernaut | **1.65** | Yes (asm-api + asm-mcp) |
| mystique | **1.65** | Yes (asm-mcp) |
| doom | **1.70** | Yes (asm-api) |

This was the smoking gun. Three nodes were seeing ~1.65 established TCP connections reset per second — consistently, not in spikes. That's ~100 resets per minute per node. But kang, on the same physical network and VLAN, saw almost zero resets.

The only difference between kang and the other nodes: **kang doesn't run any pods that connect to the PostgreSQL database**. The resets were isolated to nodes running asm-api and asm-mcp — the database-connected workloads.

If this were a NIC or physical network issue, kang would show similar reset rates. It didn't. The resets were application-layer, caused by the pgpool connection lifecycle.

### Bandwidth utilization

```promql
rate(node_network_receive_bytes_total{device="enp35s0"}[5m]) * 8 / 1e6
```

Peak bandwidth during the error window:

| Node | Peak RX (Mbps) | NIC Speed | Utilization |
|------|---------------|-----------|-------------|
| kang | ~49 | 1000 Mbps | ~5% |
| juggernaut | ~47 | 1000 Mbps | ~5% |
| mystique | ~60 | 1000 Mbps | ~6% |

Nowhere near NIC saturation. The 1Gbps NICs were barely utilized.

### NIC-level drops

All zero:
- `node_network_receive_drop_total`: 0 on all nodes, all devices
- `node_netstat_TcpExt_ListenDrops`: 0 on all nodes
- NIC RX queue drops (`ethtool -S`): 0 on all queues
- Ring buffers: already maxed at 4096 RX/TX

### Other TCP metrics

- `node_netstat_Tcp_CurrEstab`: ~400-520 per node — normal levels
- `node_netstat_Tcp_AttemptFails`: ~0.07-0.13/s — negligible
- `felix_bpf_conntrack_used`: 0 on all nodes (BPF mode, not using iptables conntrack)

### Kernel network processing

While not the root cause, we found some kernel-level concerns:

**Softnet time_squeeze** (from `/proc/net/softnet_stat`): CPU9 had 53,763 time_squeeze events — the kernel's NAPI budget (300 packets) was being exhausted during bursts. This means the kernel had to yield and come back later to process remaining packets, adding microseconds of latency.

**TX qdisc drops**: The `fq_codel` queuing discipline had accumulated 885,995 dropped packets since boot (across 4 TX queues). These were deliberate `fq_codel` drops during congestion, not hardware failures.

## Root Cause: Pgpool Connection Lifecycle vs. Prisma Connection Pool

The root cause was a **timeout mismatch** between pgpool's aggressive connection recycling and Prisma's persistent connection pool, amplified by the cross-cloud network path.

### The sequence of events

1. Prisma's connection pool opens persistent TCP connections through the full path: Hetzner → internet → AWS NLB → nginx → pgpool
2. Pgpool assigns a child process to handle each connection
3. The child process serves queries, but after 100 connections (`childMaxConnections=100`) it exits and a new child spawns
4. Alternatively, after 60 seconds of idle time (`childLifeTime=60`), the child exits
5. When the child exits, the TCP connection between nginx and pgpool is closed
6. nginx detects the upstream close and closes its side of the connection
7. The NLB propagates the close to the Hetzner-side client
8. But Prisma's connection pool still holds a reference to the now-dead TCP socket
9. The next query on that socket gets a RST → "Can't reach database server"

This was happening ~1.65 times per second across the cluster because:
- 88 child recycles in 6 hours from `childMaxConnections=100` on pgpool-1 alone
- Additional churn from `childLifeTime=60s` and `connectionLifeTime=60s`
- The `clientIdleLimit=60s` disconnecting idle Prisma pool connections

### Why it was worse during batch imports

The `mapLookupItemToAppleApp` function creates 6+ concurrent database queries per job via `Promise.all`. During batch imports (which process thousands of apps), this creates sustained high connection throughput. More connections per minute means more children hitting the 100-connection limit faster, more recycling, and more chances for a query to land on a stale connection.

### Why the keepalive was making it worse

The Linux `tcp_keepalive_time` on all nodes was at the kernel default: **7200 seconds (2 hours)**. This is an RFC 1122 recommendation from 1988, designed for expensive dial-up links. It meant that when pgpool killed a child and the TCP connection was reset on the server side, the client-side kernel wouldn't send a keepalive probe for 2 hours. Prisma's connection pool had no way to detect the dead connection until it tried to use it and got a RST.

## The Fix

We applied fixes at two levels: node-level sysctl tuning (immediate effect) and pgpool configuration changes (requires Pulumi deployment).

### Node-level sysctl changes

Applied to all 4 nodes (`/etc/sysctl.d/99-kubernetes.conf`):

```ini
# Softnet / packet processing
net.core.netdev_budget = 600          # was 300
net.core.netdev_budget_usecs = 4000   # was 2000

# TCP keepalive (cross-cloud DB connections)
net.ipv4.tcp_keepalive_time = 60      # was 7200 (!)
net.ipv4.tcp_keepalive_intvl = 10     # was 75
net.ipv4.tcp_keepalive_probes = 3     # was 9

# TCP FIN/TIME_WAIT
net.ipv4.tcp_fin_timeout = 15         # was 60

# SYN backlog
net.ipv4.tcp_max_syn_backlog = 65535  # was 8192
```

The most impactful change was `tcp_keepalive_time` from 7200s to 60s. This aligns with pgpool's `childLifeTime` so dead connections are detected within ~90 seconds (60s + 10s * 3 probes) instead of 2 hours.

GKE ships with `tcp_keepalive_time=60` by default. Our RKE2 cluster was using the upstream Linux default.

### Pgpool configuration changes

Updated in the Pulumi IaC (`createPostgreSqlHaCluster.ts`):

| Parameter | Before | After | Rationale |
|-----------|--------|-------|-----------|
| `childMaxConnections` | 100 | 10000 | Reduce child recycling from ~88/6h to negligible |
| `childLifeTime` | 60s | 300s | Keep idle children alive longer, match NLB idle timeout |
| `clientIdleLimit` | 60s | 300s | Don't disconnect idle Prisma pool connections so aggressively |
| `connectionLifeTime` | 60s | 300s | Keep cached backend connections to PostgreSQL alive longer |

These changes reduce the connection churn that was causing the constant ~1.65/s TCP reset rate. With `childMaxConnections=10000`, a child would need to serve 10,000 connections before being recycled — at current throughput, that would take days instead of minutes. With the timeout values at 300s instead of 60s, idle connections survive 5x longer, giving Prisma's connection pool time to reuse them or detect them as dead via keepalive probes.

## Conclusion

The initial hypothesis — that the NIC couldn't handle burst traffic — was wrong. The NICs were at 5% utilization with zero hardware-level drops. The problem was entirely in the application/middleware layer: pgpool's aggressive 60-second timeouts and 100-connection child lifecycle were constantly recycling child processes, breaking TCP connections that Prisma's connection pool still considered alive. The 2-hour kernel keepalive default meant dead connections went undetected until a real query hit them.

The key insight came from the TCP EstabResets metric: 1.65/s on nodes running database workloads, 0.008/s on the node that didn't connect to the database. Same NICs, same network, same VLAN — the only variable was whether the node ran pgpool-connected pods.

The fix was two-fold: increase pgpool timeouts to reduce connection churn (the primary fix), and lower the kernel TCP keepalive timer to detect dead connections faster (the secondary fix). Together, these should eliminate the "Can't reach database server" errors without any application code changes.
