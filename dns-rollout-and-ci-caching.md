# NodeLocal DNS Rollout and CI Build Caching

This document covers two related changes made during the same session: rolling out the NodeLocal DNS Cache configuration to application workloads and adding Go build caching to CI workflows.

## Context

After deploying NodeLocal DNS Cache (documented in `dns-optimization.md`), the kubelet on each node was reconfigured to set `--cluster-dns=169.254.20.10`. New pods started using the NodeLocal DNS link-local address instead of the CoreDNS ClusterIP (`10.43.0.10`). However, application deployments with egress network policies began failing.

## Problem 1: Network Policies Blocking NodeLocal DNS

### Symptom

The `shipable-generator` deploy workflow failed with:

```
the Kubernetes API server reported that "shipable-generator-production/api-4131d223"
failed to fully initialize or become live: Unauthorized
```

This error was misleading. Investigation revealed:

1. The `api-4131d223` Deployment had `ProgressDeadlineExceeded` — a new pod was stuck in `Init:1/2`
2. The `migrate` init container (Atlas database migration) was crash-looping with DNS timeouts:
   ```
   dial tcp: lookup postgresql-ha-cluster-1.cloud.kula.app on 169.254.20.10:53:
   read udp 10.42.0.155:59943->169.254.20.10:53: i/o timeout
   ```
3. The Pulumi operation waited so long for the deployment to become healthy that the GitHub OIDC token expired (confirmed in kube-apiserver logs):
   ```
   "Unable to authenticate the request" err="[invalid bearer token, oidc: verify token:
   oidc: token is expired (Token Expiry: 2026-03-08 21:39:18 +0000 UTC)]"
   ```

### Root Cause

Application namespaces had NetworkPolicy egress rules restricting DNS traffic to `kube-system` pods only:

```yaml
egress:
  - to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: kube-system
    ports:
      - port: 53
        protocol: UDP
      - port: 53
        protocol: TCP
```

NodeLocal DNS runs with `hostNetwork: true` on a link-local address (`169.254.20.10`). Calico does not see it as a `kube-system` pod — it sees traffic to a link-local IP on the node's network. The egress policy silently dropped all DNS packets to `169.254.20.10`.

Test pods in the `default` namespace (no network policies) resolved DNS fine via `169.254.20.10`, which confirmed the network policy was the cause.

### Fix

Added `169.254.20.10/32` as an `ipBlock` peer alongside the `kube-system` namespace selector in every NetworkPolicy with a DNS egress rule:

```go
&networkingv1.NetworkPolicyPeerArgs{
    IpBlock: &networkingv1.IPBlockArgs{
        Cidr: pulumi.String("169.254.20.10/32"),
    },
},
```

### Affected Repos

Each repo's `deploy/internal/*/network_policy.go` files were updated:

- `shipable-generator` (api + redis policies)
- `shipable-builder` (api policy)
- `shipable-screenshot` (api policy)
- `shipable-deployer` (api + redis policies)
- `app-store-metadata-api` (api + redis + relay + mcp + web policies)
- `metrics` (web policy)

### Cluster-Wide Rollout

After fixing the network policies, a rolling restart was triggered for all deployments, statefulsets, and daemonsets across all namespaces. This was necessary so all pods would pick up the new `nameserver 169.254.20.10` in their `/etc/resolv.conf` (pods created before the kubelet restart still had `nameserver 10.43.0.10`).

The rollout of `node-local-dns` itself caused a brief DNS outage on each node as the daemonset pods cycled. Some application pods created during this window got stuck in crash-looping init containers (DNS timeout on first attempt, then exponential backoff). These were resolved by deleting the stuck pods so fresh replacements could start with DNS working.

### Key Learnings

- **Network policies must allow DNS to `169.254.20.10/32`** when using NodeLocal DNS Cache with `hostNetwork: true`. This is the same issue as Attempt 2 in `dns-optimization.md` (CIS policies in `default` namespace) but for application-specific policies.
- **Restart order matters**: restart NodeLocal DNS daemonset first and wait for it to stabilize, then restart application workloads. Restarting everything simultaneously creates a window where pods start before their node's DNS cache is ready.
- **GitHub OIDC tokens expire quickly** (~5-10 minutes). If a Pulumi operation gets stuck waiting on an unhealthy resource, the token can expire before the operation completes or times out. The kubectl exec credential plugin refreshes tokens per-call, but Pulumi's Kubernetes provider may hold a token for the duration of a resource operation.

## Problem 2: Slow Pulumi Deploys (Go Build Caching)

### Symptom

Pulumi deploy workflows took excessively long during the initial "building program" phase. The Go compilation of the Pulumi program spiked to 2000m vCPU and 8GB RAM on CI runners. Verbose logging revealed:

```
Attempting to build go program in .../deploy with: /usr/local/go/bin/go build -o /tmp/pulumi-go.*
```

Pulumi builds the Go program to a random temp path (`/tmp/pulumi-go.*`) every time, so Go's build cache was never reused.

### Root Cause

All workflows had `actions/setup-go` configured with `cache: false`:

```yaml
- name: Set up Go
  uses: actions/setup-go@v6
  with:
    go-version-file: go.mod
    cache: false
```

This was intentional — module downloads are served by an internal Athena Go proxy (configured via `GOPROXY`), avoiding upload/download traffic to GitHub's cache storage. However, this also disabled caching of **compiled build objects** (`~/.cache/go-build`), which are not served by the module proxy.

### Fix: Composite Action with Build Caching

Created a reusable composite action (`.github/actions/setup-go/action.yml`) in each repo that:

1. Installs Go with `cache: false` (module downloads via Athena proxy)
2. Configures `GOPROXY`, `GOINSECURE`, `GOSUMDB` for the proxy
3. Caches `~/.cache/go-build` using `actions/cache@v5` (compiled objects only)

```yaml
name: Setup Go Environment
description: Sets up Go with proxy configuration and build caching

inputs:
  go-mod-path:
    description: Path to go.mod file
    required: false
    default: go.mod
  go-sum-path:
    description: Path to go.sum file (for build cache key)
    required: false
    default: go.sum

runs:
  using: composite
  steps:
    - name: Set up Go
      uses: actions/setup-go@v6
      with:
        go-version-file: ${{ inputs.go-mod-path }}
        cache: false

    - name: Configure Go Environment Globally
      shell: bash
      run: |
        go env -w GOPROXY="http://${{ env.GO_PROXY_ENDPOINT }},direct"
        go env -w GOINSECURE="${{ env.GO_PROXY_ENDPOINT }}"
        go env -w GOSUMDB=off

    - name: Cache Go build artifacts
      uses: actions/cache@v5
      with:
        path: ~/.cache/go-build
        key: go-build-${{ hashFiles(inputs.go-sum-path) }}
        restore-keys: go-build-
```

Workflows now reference the composite action instead of inlining Go setup:

```yaml
# Non-deploy workflows (root module)
- uses: ./.github/actions/setup-go
  env:
    GO_PROXY_ENDPOINT: ${{ vars.GO_PROXY_ENDPOINT }}

# Deploy workflows (deploy/ module)
- uses: ./.github/actions/setup-go
  with:
    go-mod-path: deploy/go.mod
    go-sum-path: deploy/go.sum
  env:
    GO_PROXY_ENDPOINT: ${{ vars.GO_PROXY_ENDPOINT }}
```

### Why Two Cache Inputs

Deploy workflows use `deploy/go.mod` and `deploy/go.sum` (separate Go module for infrastructure code). Non-deploy workflows (build, test, format, analyze) use the root `go.mod` and `go.sum`. The `go-sum-path` input allows the cache key to hash the correct file.

### Affected Repos and Workflows

| Repo | Workflows Updated |
|------|-------------------|
| shipable-generator | deploy, build, build-binaries, test, format, analyze |
| shipable-builder | deploy, build, build-binaries, test, format, analyze |
| shipable-screenshot | deploy, build, build-binaries, test, format, analyze |
| shipable-deployer | deploy, build, build-binaries, test, format, analyze |
| app-store-metadata-api | Existing composite action updated (covers build, test, format, analyze) |
| metrics | deploy |

### Expected Impact

- **First run (cold cache)**: No improvement — full compilation still occurs
- **Subsequent runs (warm cache)**: Near-instant Go compilation, significant reduction in CPU and memory usage
- **Cache size**: Build cache is typically tens of MB, so upload/download overhead is minimal
- **Cache invalidation**: Key is based on `go.sum` hash, so cache refreshes when dependencies change
