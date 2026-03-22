# TCP Retransmit Investigation — 2026-03-22

## Problem

Grafana dashboard `cluster-nodes` showed elevated TCP retransmits across all nodes, with kang experiencing severe spikes up to **14 retransmits/sec**. kang → doom latency was **4–6ms** (expected <0.5ms within the same datacenter).

## Root Causes Identified

1. **Longhorn iSCSI cross-node traffic** — CI runner PVCs had `dataLocality: disabled`, so a pod on kang could have its storage replica on doom, generating heavy iSCSI traffic across the network.
2. **Disk saturation on kang** — A CI runner BuildKit build saturated a Longhorn iSCSI disk (`sde`) at 100% utilization with 155ms write latency, causing 11% iowait. This delayed network softirq processing, leading to TCP retransmissions.
3. **CPU overload on doom** — Load average of 22, with BuildKit at 350% CPU. Softnet time_squeeze events (kernel packet processing budget exhausted) caused packet processing delays.
4. **Stale container images** — 167GB on kang, 426GB on doom. Kubelet image GC was set to trigger at 85% disk usage (default), which never triggered on the large disks.
5. **Insufficient softnet budget** — `netdev_budget` was at 600/4000μs, still producing time_squeeze events on doom during CI bursts.
6. **Unbounded BuildKit CPU** — Dynamic BuildKit pods created by `docker buildx create --driver kubernetes` had no resource limits, allowing unbounded CPU consumption on doom.

## Diagnostic Process

### How we identified the root causes

1. **Prometheus metrics** — `rate(node_netstat_Tcp_RetransSegs[5m])` showed retransmits across all nodes, with kang peaking at 14/s. `rate(node_netstat_TcpExt_TCPTimeouts[5m])` and `rate(node_netstat_TcpExt_TCPSynRetrans[5m])` confirmed the pattern.
2. **`ss -ti`** — Showed per-connection retransmit counts. Top offenders on kang: SSH over Tailscale (20K retrans), RKE2 connections to doom:9345 (10K retrans), K8s API to doom:6443 (4K retrans).
3. **`ping` between nodes** — Revealed kang → doom at 4–6ms while juggernaut → doom was 0.2ms. Same datacenter, so kang was the problem.
4. **`iostat -xz`** — Showed `sde` (Longhorn iSCSI volume) at 100% utilization with 155ms w_await on kang.
5. **`/proc/net/softnet_stat`** — Column 3 (time_squeeze) on doom showed 500–800 events per CPU. Zero drops (column 2), meaning packets were delayed but not lost.
6. **`top` on doom** — BuildKit at 350% CPU, load average 22 on 64 CPUs.
7. **`ethtool -S`** — Zero NIC hardware errors on all nodes, ruling out physical network issues.
8. **`nstat -az`** — Confirmed doom had 283K TCP timeouts (vs 19K on kang) and 156K SYN retransmits.
9. **`lsblk` + `kubectl get volumes.longhorn.io`** — Connected the saturated `sde` to a CI runner PVC with remote replica placement.

### Key insight

The latency asymmetry (kang → doom 4–6ms, juggernaut → doom 0.2ms) pointed to kang as the source, not the network. Combined with 11% iowait and 4% softirq on kang's 16 CPUs, the diagnosis was clear: disk I/O from remote Longhorn replicas was starving the network stack.

## Changes Applied

### 1. Kubelet Image Garbage Collection (all nodes)

**File**: `/var/lib/rancher/rke2/agent/etc/kubelet.conf.d/01-image-gc.yaml` on each node

```yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
imageMaximumGCAge: 720h
imageGCHighThresholdPercent: 30
imageGCLowThresholdPercent: 15
```

- Images unused for 30 days are evicted regardless of disk pressure
- GC starts at 30% disk usage, targets 15%
- Required kubelet restart (rolling restart of rke2-agent/rke2-server)
- Previous defaults (85%/80%) never triggered because the disks are large (906GB–1.8TB)

### 2. Longhorn storageReserved (all nodes)

Set to **250 GiB** on all 4 nodes via `kubectl patch nodes.longhorn.io`. Prevents Longhorn from scheduling replicas into system space. Takes effect immediately, no restart needed.

### 3. Longhorn StorageClass `dataLocality: best-effort`

**File**: `/var/lib/rancher/rke2/server/manifests/longhorn.yaml` on doom

Added `defaultDataLocality: "best-effort"` to both the `defaultSettings` and `persistence` sections. The `persistence` section controls the StorageClass parameters; `defaultSettings` controls the Longhorn API default — both are needed.

This ensures new Longhorn PVCs place their single replica on the same node as the consuming pod, eliminating cross-node iSCSI traffic. Only affects new PVCs (CI runner PVCs are ephemeral, so this took effect immediately for new jobs).

**Biggest impact** — kang → doom latency dropped from 4–6ms to 0.14–0.46ms.

### 4. Softnet Budget Increase (all nodes)

**File**: `/etc/sysctl.d/99-kubernetes.conf` on each node

Changed values:
```
net.core.netdev_budget = 2400        # was 600 (default 300)
net.core.netdev_budget_usecs = 16000  # was 4000 (default 2000)
```

Full file contents (kang/juggernaut/mystique version — doom has a similar file with different inotify values):
```ini
# Kubernetes node tuning for kang, juggernaut, mystique
fs.inotify.max_user_watches = 502453
fs.inotify.max_user_instances = 2048
fs.inotify.max_queued_events = 16384
net.core.somaxconn = 65535
vm.swappiness = 0

# --- Softnet / packet processing ---
net.core.netdev_budget = 2400
net.core.netdev_budget_usecs = 16000

# --- TCP keepalive (cross-cloud DB connections) ---
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 3

# --- TCP FIN/TIME_WAIT ---
net.ipv4.tcp_fin_timeout = 15

# --- SYN backlog ---
net.ipv4.tcp_max_syn_backlog = 65535
```

Applied live via `sysctl -p`, no restart needed. Gives the kernel 4x more budget per softirq cycle to process network packets before yielding to other work. On doom (64 CPUs, heavy CI load), the previous 600/4000μs was still producing time_squeeze events.

### 5. BuildKit LimitRange (ci-infra repo)

**File**: `ci-infra/src/services/createGitHubActionsBuildKit.ts`

Dynamic BuildKit pods created by `docker buildx create --driver kubernetes` had no resource limits (`resources: {}`), allowing unbounded CPU consumption. Added a LimitRange to the `github-buildkit` namespace:

- **Default limit**: 4 CPU / 16Gi memory per container
- **Default request**: 500m CPU / 2Gi memory per container

Deployed via Pulumi. Existing pods unaffected until recreated. The existing ResourceQuota in the same file has CPU/memory limits commented out (lines 97–101) — these could be re-enabled if total namespace resource consumption needs capping.

### 6. Longhorn Metrics Scraping

**File**: `/var/lib/rancher/rke2/server/manifests/longhorn.yaml` on doom

Added `longhornManager.serviceAnnotations` with `prometheus.io/scrape: "true"` and `prometheus.io/port: "9500"` to the Helm values. Longhorn manager exposes metrics on port 9500 at `/metrics` but had no scrape annotations configured. This enables 11,783 native Longhorn metric series including per-volume I/O latency, IOPS, throughput, and replica state.

Note: The Longhorn Helm chart has a `metrics.serviceMonitor` option, but we use annotation-based scraping (not Prometheus Operator), so service annotations are the correct approach.

### 7. Longhorn Dashboard Update

Updated Grafana dashboard `longhorn-storage` with native Longhorn metrics panels:

**Volume I/O** (6 panels):
- Volume Write/Read Latency per volume (unit: nanoseconds)
- Volume Write/Read IOPS per volume
- Volume Write/Read Throughput per volume

**Node Storage** (2 panels):
- Node Storage Capacity vs Usage vs Reserved
- Scheduled vs Available Storage

**Volume Health** (5 panels):
- Degraded / Detached / Attached / Faulted volume counts
- Volume Actual Size per volume

## Results

| Metric | Before | After |
|---|---|---|
| kang → doom latency | 4–6 ms | 0.14–0.46 ms |
| kang retransmits (peak) | 14/s | ~1.5/s (steady state) |
| kang disk sde utilization | 100% (155ms await) | <8% (local NVMe) |
| doom load average | 22 | 6.3 |
| Longhorn metrics in Prometheus | 0 | 11,783 series |

## Node Reference

| Node | IP | Role | CPUs | Disk | Datacenter |
|---|---|---|---|---|---|
| kang | 10.1.0.11 | worker (rke2-agent) | 16 | 906 GB | HEL1-DC4 |
| juggernaut | 10.1.0.12 | control-plane (rke2-server) | — | 937 GB | HEL1-DC4 |
| mystique | 10.1.0.13 | control-plane (rke2-server) | — | 937 GB | HEL1-DC7 |
| doom | 10.1.0.14 | control-plane (rke2-server) | 64 | 1.8 TB | HEL1-DC4 |

## Notes

- **Released/Failed PVs** shown on the Longhorn dashboard are transient — CI runner PVCs briefly enter Released state when jobs finish, then auto-delete via the `Delete` reclaim policy. Not a problem.
- **Mystique write latency** is 155–405ms (up to 2.26s under load) because it's in HEL1-DC7 while other nodes are in HEL1-DC4. Cross-DC replica traffic is expected when volumes attach on mystique. This is a separate issue that hasn't been addressed.
- **Existing TCP retransmit alert** (15/s for 5min, severity: warning) is appropriate — lowering it would create noise from normal CI bursts (3–5/s).
- **Longhorn I/O limits** — investigated but skipped. Longhorn v1.11.0 (V1 data engine) has no native IOPS/throughput QoS. With data locality active, volumes write to local NVMe which is fast enough to not cause issues.
- **Not a Hetzner network issue** — zero NIC hardware errors, zero packet drops, zero softnet drops. All nodes at 1Gbps full duplex. The retransmit pattern was bursty and correlated with CI build activity, not persistent. The [Hetzner network diagnosis guide](https://docs.hetzner.com/robot/dedicated-server/troubleshooting/network-diagnosis-and-report-to-hetzner) is not applicable.
- **Disk usage breakdown on kang** (321GB / 906GB): 167GB container images, 82GB /home/philprime, 16GB /usr, 10GB old GH Actions runner at /apps/github-actions-runner-1 (stale, could be removed).

## Collateral Damage

The `rke2-agent` restart on kang at ~16:07 UTC killed running CI pods, including `k8s-ci-android-7ch92-runner-x2kcj` which was mid-execution on [workflow run 23406925511](https://github.com/kula-app/shipable-ci-worker/actions/runs/23406925511/job/68087375747). The `screenshot-android.sh` script was in its 15-second sleep (Step 7) when the pod was terminated. The subsequent "Verify Screenshots Output" step failed because the `./output` directory was never created. **Re-running the workflow resolves this.**

Lesson: when doing rolling kubelet restarts, drain CI-heavy nodes first or wait for running jobs to complete.

## Files Modified

| File | Node(s) | Managed by |
|---|---|---|
| `/var/lib/rancher/rke2/agent/etc/kubelet.conf.d/01-image-gc.yaml` | all | Manual (drop-in file) |
| `/etc/sysctl.d/99-kubernetes.conf` | all | Manual |
| `/var/lib/rancher/rke2/server/manifests/longhorn.yaml` | doom | RKE2 HelmChart controller |
| `ci-infra/src/services/createGitHubActionsBuildKit.ts` | — | Pulumi (ci-infra repo) |
| Longhorn node `storageReserved` | all | kubectl patch (not persisted in code) |
| Grafana dashboard `longhorn-storage` | — | Grafana MCP |
