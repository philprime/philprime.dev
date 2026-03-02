---
layout: guide-lesson.liquid
title: Installing the RKE2 Server

guide_component: lesson
guide_id: migrating-k3s-to-rke2
guide_section_id: 2
guide_lesson_id: 5
guide_lesson_abstract: >
  The first RKE2 control plane node forms the foundation of the new cluster.
  This lesson walks through installing RKE2 on Node 4 with dual-stack networking, security hardening, and CoreDNS upstream DNS configuration.
  It also covers etcdctl setup and verification of the running cluster.
guide_lesson_conclusion: >
  Node 4 is running a single-node RKE2 control plane with secrets encryption and verified etcd health.
repo_file_path: guides/migrating-k3s-to-rke2/lesson-5.md
---

With networking and firewall configured, Node 4 is ready to run the first RKE2 control plane.
This establishes the foundation of Cluster B that will eventually replace the k3s cluster.

{% include guide-overview-link.liquid.html %}

{% include alert.liquid.html type='warning' title='Root Privileges Required' content='
All commands in this lesson require <code>sudo</code> privileges.
Either prepend <code>sudo</code> to each command or switch to the root user using <code>sudo -i</code>.
' %}

## Understanding RKE2

### How RKE2 Differs from k3s

k3s embeds the entire control plane (API server, scheduler, controller-manager, etcd) as goroutines inside a single binary.
RKE2 runs each of these components as static pods in `kube-system`, visible through `kubectl get pods` like any other workload.
This means you can inspect logs, resource usage, and restart behavior for each component individually, which becomes valuable when debugging a multi-node control plane.

RKE2 splits responsibilities across two systemd-managed binaries: `rke2-server` for control plane nodes and `rke2-agent` for workers, while k3s uses a single binary with `server` and `agent` subcommands.
The practical difference is that you enable and manage `rke2-server.service` or `rke2-agent.service` through systemd rather than passing subcommands.

Tooling requires a small adjustment.
RKE2 places `kubectl` and `crictl` in `/var/lib/rancher/rke2/bin/` rather than on `PATH`, so they are not available until you add that directory to your shell profile.
Configuration uses a drop-in directory at `/etc/rancher/rke2/config.yaml.d/` where numbered YAML files are merged in alphabetical order, a pattern that keeps concerns separated instead of growing a single config file.

### Security Defaults

RKE2 applies CIS Kubernetes Benchmark hardening by default with restrictive file permissions on certificates and keys, audit logging enabled, and anonymous authentication disabled.
These defaults mean the cluster starts closer to a production-hardened state than k3s, which prioritizes ease of setup over strict defaults.
For a migration this is an advantage: rather than retrofitting hardening onto a running cluster, we get a secure baseline from the first boot.

Secrets encryption at rest protects Kubernetes secrets stored in etcd, and RKE2 makes it available as a single config flag.
Enabling it after secrets already exist requires re-encrypting every secret in etcd, so we enable it from the start before any workloads are deployed.
Pod Security Admission follows the same principle: we enforce the `restricted` profile from the beginning rather than tightening policies later when workloads are already running and might break under stricter rules.

Canal, RKE2's default CNI, uses Calico's policy engine to provide L3-L4 network policies out of the box.
We will configure Canal's network settings in [Lesson 6](/guides/migrating-k3s-to-rke2/lesson-6).

### Bundled Addons and HelmChartConfig

RKE2 automatically installs several components as Helm charts during startup:

| Addon                            | Purpose                   | Our action |
| -------------------------------- | ------------------------- | ---------- |
| CNI plugin (Canal by default)    | Pod networking            | Keep       |
| rke2-coredns                     | Cluster DNS               | Keep       |
| rke2-metrics-server              | Resource metrics          | Keep       |
| rke2-ingress-nginx               | Ingress controller        | Disable    |
| rke2-snapshot-controller         | CSI volume snapshots      | Keep       |
| rke2-snapshot-controller-crd     | Snapshot custom resources | Keep       |
| rke2-snapshot-validation-webhook | Snapshot validation       | Keep       |

We disable `rke2-ingress-nginx` because our existing Ingress and IngressRoute definitions target Traefik, and deploying Traefik on the RKE2 cluster lets us reuse them without changes.
The snapshot-controller trio is only useful once a CSI driver is installed, and we add Longhorn in [Lesson 7](/guides/migrating-k3s-to-rke2/lesson-7).

RKE2 deploys these addons as Helm charts and watches `/var/lib/rancher/rke2/server/manifests/` for override files.
A `HelmChartConfig` resource placed in that directory customizes an addon's Helm values without forking the chart itself.
We use this mechanism later in this lesson to configure CoreDNS upstream DNS, and in [Lesson 6](/guides/migrating-k3s-to-rke2/lesson-6) to tune Canal's network settings.

## Installing RKE2

### Run the Installer

RKE2 provides an install script that downloads the correct binary for our architecture.
The available options and flags are documented in the [RKE2 installation guide](https://docs.rke2.io/install/).

{% include alert.liquid.html type='warning' title='Inspect Before Piping to Shell' content='
Piping a remote script directly into <code>sh</code> executes whatever the server returns and can potentially be dangerous and harmful to your system.
Always review scripts before executing them, especially when they are run with root privileges.
' %}

```bash
$ curl -sfL https://get.rke2.io | sh -
[INFO]  finding release for channel stable
[INFO]  using 1.34 series from channel stable
Rancher RKE2 Common (stable)                                                                                                                                                                                                                                  4.0 kB/s | 659  B     00:00
Rancher RKE2 Common (stable)                                                                                                                                                                                                                                   29 kB/s | 2.4 kB     00:00
Importing GPG key 0xE257814A:
...

# Verify installation
$ rke2 --version
rke2 version v1.34.3+rke2r3 (7598946e0086a9131564ccbb3c142b3fa54516ad)
go version go1.24.11 X:boringcrypto
```

### Patching runc (Workaround for Container Exec Failures)

{% include alert.liquid.html type='note' title='Check Your runc Version' content='
If your RKE2 release bundles runc v1.4.1 or later, this regression is already fixed and you can skip this section.
' %}

RKE2 v1.34.x ships with runc v1.4.0, which has a [known regression](https://github.com/opencontainers/runc/issues/5089) on systems using cgroup v2.
Containers that move themselves into a child cgroup, such as BuildKit, cause systemd to garbage-collect the original cgroup scope.
When runc tries to exec into the container (for readiness probes or `kubectl exec`), it fails with:

```sh
can't open cgroup: openat2 /sys/fs/cgroup/kubepods.slice/...: no such file or directory
```

Luckily the fix is merged in runc and will ship as v1.4.1, but no RKE2 release bundles it yet.
Until then, we replace the bundled runc binary with v1.3.4 directly.

RKE2 stores its binaries in a versioned data directory under `/var/lib/rancher/rke2/data/`.
Find the runc binary path and verify the current version:

```bash
# Find the most recent RKE2 data directory (there may be older ones from previous versions)
$ RKE2_DATA_DIR=$(ls -dt /var/lib/rancher/rke2/data/v*/bin 2>/dev/null | head -1)
$ echo $RKE2_DATA_DIR
/var/lib/rancher/rke2/data/v1.34.4-rke2r1-0d52262ea640/bin

$ $RKE2_DATA_DIR/runc --version
runc version 1.4.0
...
```

Download runc v1.3.4 to `/etc/rancher/rke2/` so it is clearly visible as a manual patch, back up the original, and hardlink the patched binary into the data directory:

```bash
$ curl -fL https://github.com/opencontainers/runc/releases/download/v1.3.4/runc.amd64 \
    -o /etc/rancher/rke2/runc-v1.3.4
$ chmod +x /etc/rancher/rke2/runc-v1.3.4

# Verify the download
$ /etc/rancher/rke2/runc-v1.3.4 --version
runc version 1.3.4
commit: v1.3.4-0-g63757986
...

# Back up the original and replace with a hardlink
$ cp $RKE2_DATA_DIR/runc $RKE2_DATA_DIR/runc.v1.4.0.bak
$ ln -f /etc/rancher/rke2/runc-v1.3.4 $RKE2_DATA_DIR/runc
$ $RKE2_DATA_DIR/runc --version
runc version 1.3.4
commit: v1.3.4-0-gd6d73eb8
spec: 1.2.1
go: go1.24.10
libseccomp: 2.5.6
```

Using a hardlink means both paths point to the same file on disk.
Verify the hardlink is in place by checking that the patched binary and the active runc share the same inode, while the backup has a different one:

```bash
$ ls -li $RKE2_DATA_DIR/runc $RKE2_DATA_DIR/runc.v1.4.0.bak /etc/rancher/rke2/runc-v1.3.4
12060145 -rwxr-xr-x. 2 root root 13031032 Feb 21 00:45 /var/lib/rancher/rke2/data/v1.34.4-rke2r1-0d52262ea640/bin/runc
12060145 -rwxr-xr-x. 2 root root 13031032 Feb 21 00:45 /etc/rancher/rke2/runc-v1.3.4
43647257 -rwxr-xr-x. 1 root root 14227840 Feb 21 00:54 /var/lib/rancher/rke2/data/v1.34.4-rke2r1-0d52262ea640/bin/runc.v1.4.0.bak
```

The first column is the inode number.
`runc` and `runc-v1.3.4` share inode `12060145` with a link count of `2`, confirming they are the same file.
The backup has a different inode and a link count of `1`.

The copy in `/etc/rancher/rke2/` makes it obvious that a patch is in place.
If you see `runc-v1.3.4` there, you know the node is patched.

RKE2 creates a new versioned data directory on upgrade, so a newer release uses its own bundled runc binary and ignores the patched one in the old directory.
That release should include runc v1.4.1 with the fix.
At that point, clean up the leftover file:

```bash
$ rm /etc/rancher/rke2/runc-v1.3.4
```

Restart RKE2 to pick up the new binary:

```bash
$ systemctl restart rke2-server.service
$ journalctl -u rke2-server -f
# Wait for: "rke2 is up and running"
```

{% include alert.liquid.html type='note' title='Apply on every node' content='
This workaround must be applied on every node after installing RKE2 and before starting it for the first time, or before restarting it on existing nodes.
The same steps apply to Lessons 11, 12, and 15 when joining additional nodes.
' %}

### Create Configuration

RKE2 reads configuration from `/etc/rancher/rke2/config.yaml` and `/etc/rancher/rke2/config.yaml.d/*.yaml` in alphabetical order.
Splitting settings into numbered files keeps each concern isolated and makes it easy to add or remove features later without editing a single monolithic file.

```bash
$ mkdir -p /etc/rancher/rke2/config.yaml.d
```

The network configuration sets up node addressing, keeps API server traffic on the private vSwitch, and defines the dual-stack pod and service CIDRs:

```yaml
# /etc/rancher/rke2/config.yaml.d/10-network.yaml

# Canal is the default CNI and auto-detects dual-stack from the cluster CIDRs
cni: canal

# Dual-stack node IPs on the private vSwitch interface
node-ip: 10.1.0.14,fd00::14
# Public IPs so Kubernetes knows how to reach this node externally
node-external-ip:
  - 135.181.XX.XX
  - 2a01:4f9:XX:XX::2

# Advertise the API server on the private vSwitch IP for cluster communication
advertise-address: 10.1.0.14
# Bind the API server to the private vSwitch IP
bind-address: 10.1.0.14

# Dual-stack pod and service CIDRs (cannot be changed after cluster creation)
cluster-cidr: 10.42.0.0/16,fd00:42::/56
service-cidr: 10.43.0.0/16,fd00:43::/112
cluster-dns: 10.43.0.10

# Use a clean resolv.conf so Tailscale's MagicDNS does not leak search domains into pods.
kubelet-arg:
  - "resolv-conf=/etc/rancher/rke2/resolv.conf"
```

Kubelet normally reads the host's `/etc/resolv.conf` to build each pod's DNS configuration.
When Tailscale is installed on the host, it replaces `/etc/resolv.conf` with its MagicDNS proxy and adds search domains like `tailc7bf.ts.net` that leak into every pod.
Combined with the Kubernetes default of `ndots:5`, this causes pod DNS lookups for external hostnames to generate unnecessary queries against these search domains, leading to intermittent timeouts under concurrent load.
The `resolv-conf` kubelet argument points to a static file with only the upstream nameservers.

Create the clean `resolv.conf` with Cloudflare's public DNS servers, which are globally available and support both IPv4 and IPv6.
This file must exist on every node in the cluster since each node's kubelet references it:

```bash
$ cat <<'EOF' | sudo tee /etc/rancher/rke2/resolv.conf
nameserver 1.1.1.1
nameserver 1.0.0.1
nameserver 2606:4700:4700::1111
nameserver 2606:4700:4700::1001
EOF
```

The external access configuration adds SANs to the API server certificate so `kubectl` can connect via hostname, IP, or a public DNS name without TLS errors:

```yaml
# /etc/rancher/rke2/config.yaml.d/20-external-access.yaml

tls-san:
  - node4
  - node4.k8s.local
  - 10.1.0.14
  - fd00::14
  - cluster.yourdomain.com # Optional: a public DNS name for external kubectl access
```

The security configuration enables secrets encryption from the start, disables bundled components we replace ourselves, and schedules automatic etcd backups:

```yaml
# /etc/rancher/rke2/config.yaml.d/30-security.yaml

# Encrypt secrets at rest in etcd, best enabled before storing any secrets
secrets-encryption: true

# Disable the bundled ingress controller since we will deploy Traefik later
disable:
  - rke2-ingress-nginx

# Automatic etcd snapshots every 6 hours, keeping the last 5
etcd-snapshot-schedule-cron: "0 */6 * * *"
etcd-snapshot-retention: 5
```

### Start RKE2

Enable the service so it starts on boot, then start it:

```bash
$ systemctl enable rke2-server.service
Created symlink '/etc/systemd/system/multi-user.target.wants/rke2-server.service' → '/usr/lib/systemd/system/rke2-server.service'.
$ systemctl start rke2-server.service

$ journalctl -u rke2-server -f
...
rke2[108343]: time="2026-02-15T01:12:50+02:00" level=info msg="rke2 is up and running"
systemd[1]: Started rke2-server.service - Rancher Kubernetes Engine v2 (server).
...
```

The first start takes several minutes as RKE2 downloads images, initializes etcd, and generates certificates.
Wait until the log shows the API server is ready:

```bash
rke2[108343]: time="2026-02-15T01:12:47+02:00" level=info msg="Kube API server is now running"
```

After startup, RKE2 generates a cluster join token at `/var/lib/rancher/rke2/server/node-token`.
This token is needed when registering additional server or agent nodes to the cluster and needs to be kept secret.

### Configure kubectl

RKE2 generates a kubeconfig file at `/etc/rancher/rke2/rke2.yaml` and places the `kubectl` binary in `/var/lib/rancher/rke2/bin/`.
We copy the kubeconfig to the standard location and add the binary path to our shell:

```bash
# Create the kubeconfig directory with the correct permissions
$ mkdir -p ~/.kube
$ cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
$ chown $(id -u):$(id -g) ~/.kube/config
$ chmod 600 ~/.kube/config

# Add kubectl to PATH
$ echo 'export PATH=$PATH:/var/lib/rancher/rke2/bin' >> ~/.bashrc
$ export PATH=$PATH:/var/lib/rancher/rke2/bin

# Verify kubectl can connect to the cluster
$ kubectl version
Client Version: v1.34.3+rke2r3
Kustomize Version: v5.7.1
Server Version: v1.34.3+rke2r3
```

### Install etcdctl

RKE2 embeds etcd as a static pod but does not ship the `etcdctl` CLI on the host.
We need `etcdctl` to inspect cluster health, list members, and debug issues, tasks that become essential once additional control plane nodes join.

Query the etcd pod image to determine the running version:

```bash
$ kubectl -n kube-system get pod -l component=etcd -o jsonpath='{.items[0].spec.containers[0].image}'
index.docker.io/rancher/hardened-etcd:v3.6.7-k3s1-build20260126
```

Download and install the corresponding `etcdctl` release:

```bash
# Replace with the version from the previous command
$ export ETCD_VER=v3.6.7
$ curl -fL https://storage.googleapis.com/etcd/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz \
    -o /tmp/etcd-linux-amd64.tar.gz
$ mkdir -p /tmp/etcd-download
$ tar xzf /tmp/etcd-linux-amd64.tar.gz -C /tmp/etcd-download --strip-components=1
$ cp /tmp/etcd-download/etcdctl /usr/local/bin/
$ rm -rf /tmp/etcd-download /tmp/etcd-linux-amd64.tar.gz

$ /usr/local/bin/etcdctl version
etcdctl version: 3.6.7
API version: 3.6
```

Every `etcdctl` command against RKE2's etcd requires TLS certificate flags we need to define as arguments.
This can become repetitive, so a shell alias keeps these out of the way:

```bash
$ cat <<'EOF' >> ~/.bashrc
alias etcdctl='/usr/local/bin/etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/rancher/rke2/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/rke2/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/rke2/server/tls/etcd/server-client.key'
EOF
$ source ~/.bashrc
```

From this point forward, any `etcdctl` command automatically includes the necessary TLS flags to connect to the embedded etcd instance, so we can run commands like `etcdctl endpoint health` without extra arguments.

## Verification

Now that RKE2 is running, we verify the cluster status, dual-stack configuration, and etcd health before proceeding to further configuration in the next lessons.

### Cluster Status

Check that the node is registered with the cluster and is ready to schedule workloads:

```bash
$ kubectl get nodes -o wide
NAME   STATUS   ROLES                AGE   VERSION          INTERNAL-IP   EXTERNAL-IP     OS-IMAGE                        KERNEL-VERSION                  CONTAINER-RUNTIME
node4   Ready    control-plane,etcd   10m   v1.34.3+rke2r3   10.1.0.14      135.181.XX.XX   Rocky Linux 10.1 (Red Quartz)   6.12.0-124.27.1.el10_1.x86_64   containerd://2.1.5-k3s1
```

The node may initially show `NotReady` while Canal deploys, then transition to `Ready` when the cluster is fully operational.

### Dual-Stack Configuration

Verify the node has both IPv4 and IPv6 addresses registered:

```bash
$ kubectl get nodes -o jsonpath='{.items[*].status.addresses}' | jq .
[
  {
    "address": "10.1.0.14",
    "type": "InternalIP"
  },
  {
    "address": "fd00::14",
    "type": "InternalIP"
  },
  {
    "address": "135.181.X.X",
    "type": "ExternalIP"
  },
  {
    "address": "2a01:4f9:X:X::2",
    "type": "ExternalIP"
  },
  {
    "address": "node4",
    "type": "Hostname"
  }
]
```

We should see both `InternalIP` entries, one for `10.1.0.14` and one for `fd00::14`.

Confirm the cluster CIDR configuration matches what we planned:

```bash
$ kubectl cluster-info dump | grep -E "cluster-cidr|service-cluster-ip-range"
                            "--cluster-cidr=10.42.0.0/16,fd00:42::/56",
                            "--service-cluster-ip-range=10.43.0.0/16,fd00:43::/112",
                            "--cluster-cidr=10.42.0.0/16,fd00:42::/56",
                            "--service-cluster-ip-range=10.43.0.0/16,fd00:43::/112",
                            "--cluster-cidr=10.42.0.0/16,fd00:42::/56",
```

The output shows both IPv4 and IPv6 CIDRs for `cluster-cidr` and `service-cluster-ip-range`.

### etcd Health

Verify the embedded etcd instance is healthy using the `etcdctl` alias we configured earlier:

```bash
$ etcdctl endpoint health --cluster --write-out=table
+------------------------+--------+------------+-------+
|       ENDPOINT         | HEALTH |    TOOK    | ERROR |
+------------------------+--------+------------+-------+
| https://10.1.0.14:2379 |  true  | 2.527854ms |       |
+------------------------+--------+------------+-------+
```

A single-node cluster shows one endpoint and as we add control plane nodes in later lessons, this table will then grow to three entries.

## Configuring CoreDNS Upstream DNS

The kubelet `resolv-conf` override above gives pods a clean `/etc/resolv.conf` with Cloudflare's nameservers.
CoreDNS pods inherit the same file through their `dnsPolicy: Default` setting, so the default `forward . /etc/resolv.conf` already resolves against Cloudflare rather than Tailscale's MagicDNS.

A `HelmChartConfig` override is still worth adding to make the upstream forwarder explicit in the cluster configuration, set resource limits, and expose Prometheus metrics.
This way the CoreDNS setup is visible and tunable from a single manifest rather than inherited indirectly from a kubelet flag.

Create the manifest at `/var/lib/rancher/rke2/server/manifests/rke2-coredns-config.yaml`:

```yaml
# /var/lib/rancher/rke2/server/manifests/rke2-coredns-config.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-coredns
  namespace: kube-system
spec:
  # Fully reinstall the Helm release if an upgrade fails, rather than leaving it broken
  failurePolicy: reinstall
  valuesContent: |-
    # Optional: resource limits prevent a DNS surge from starving other kube-system workloads
    resources:
      requests:
        cpu: 200m
        memory: 256Mi
      limits:
        cpu: 1000m
        memory: 512Mi
    # Optional: automatically scale CoreDNS replicas based on cluster size
    autoscaler:
      enabled: true
      # Minimum number of replicas, even on a single-node cluster
      min: 3
      # Add one replica per 16 nodes
      nodesPerReplica: 16
      # Add one replica per 256 cores
      coresPerReplica: 256
      # Ensure replicas are spread across nodes to avoid a single point of failure
      preventSinglePointFailure: true
    servers:
    - zones:
      - zone: .
      port: 53
      plugins:
      - name: errors
      - name: health
        configBlock: |-
          lameduck 5s
      - name: ready
      - name: kubernetes
        parameters: cluster.local in-addr.arpa ip6.arpa
        configBlock: |-
          pods insecure
          fallthrough in-addr.arpa ip6.arpa
          ttl 30
      - name: prometheus
        parameters: 0.0.0.0:9153
      # Cloudflare public DNS over both IPv4 and IPv6
      - name: forward
        parameters: . 1.1.1.1 1.0.0.1 2606:4700:4700::1111 2606:4700:4700::1001
      # Cache TTL in seconds for resolved records
      - name: cache
        parameters: 300
      # Limit EDNS0 UDP buffer size to prevent IP fragmentation over the WireGuard tunnel
      # See https://coredns.io/plugins/bufsize/
      - name: bufsize
        parameters: 1232
      - name: loop
      - name: reload
      - name: loadbalance
    # Optional: expose CoreDNS metrics for Prometheus scraping
    service:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9153"
```

The `forward` line points CoreDNS at Cloudflare's public resolvers over both IPv4 and IPv6, matching the `resolv.conf` we created earlier.
The resource limits, autoscaler, and Prometheus annotations are optional but recommended for production clusters.
The autoscaler ensures CoreDNS replicas grow with the cluster, and `preventSinglePointFailure` spreads them across nodes so that losing one node does not take down cluster DNS.

RKE2 detects the new manifest and upgrades the CoreDNS Helm release automatically.
Restart the deployment to apply the change:

```bash
$ kubectl rollout restart deployment rke2-coredns-rke2-coredns -n kube-system
$ kubectl rollout status deployment rke2-coredns-rke2-coredns -n kube-system --timeout=60s
Waiting for deployment "rke2-coredns-rke2-coredns" rollout to finish: 2 out of 3 new replicas have been updated...
deployment "rke2-coredns-rke2-coredns" successfully rolled out
```

Verify that external DNS resolution works from within the cluster:

```bash
$ kubectl run dns-test -n kube-system --rm -it --image=busybox:1.36 --restart=Never -- nslookup charts.longhorn.io
Server:         10.43.0.10
Address:        10.43.0.10:53

Non-authoritative answer:
charts.longhorn.io      canonical name = longhorn.github.io
Name:   longhorn.github.io
Address: 2606:50c0:8000::153
Name:   longhorn.github.io
Address: 2606:50c0:8001::153
Name:   longhorn.github.io
Address: 2606:50c0:8003::153
Name:   longhorn.github.io
Address: 2606:50c0:8002::153

Non-authoritative answer:
charts.longhorn.io      canonical name = longhorn.github.io
Name:   longhorn.github.io
Address: 185.199.110.153
Name:   longhorn.github.io
Address: 185.199.109.153
Name:   longhorn.github.io
Address: 185.199.108.153
Name:   longhorn.github.io
Address: 185.199.111.153

pod "dns-test" deleted from kube-system namespace
```

If the lookup returns addresses, CoreDNS is forwarding correctly and the cluster can reach external services.

## Create Initial Backup

Before making any further changes, we back up the configuration files and take an etcd snapshot:

```bash
$ mkdir -p /root/rke2-backup
$ chmod 700 /root/rke2-backup
$ cp -r /etc/rancher/rke2/config.yaml.d /root/rke2-backup/
$ cp /var/lib/rancher/rke2/server/node-token /root/rke2-backup/
$ cp ~/.kube/config /root/rke2-backup/kubeconfig

$ rke2 etcd-snapshot save --name initial-setup
```

This gives us a restore point in case anything goes wrong during subsequent configuration.

## Troubleshooting

These are common issues that can occur during this setup and how to resolve them.

### RKE2 Fails to Start

If the service fails to start, check the status and logs for details:

```bash
$ systemctl status rke2-server
$ journalctl -xeu rke2-server
```

The most common cause is port `6443` already being in use by an existing k3s or Kubernetes installation.
Firewall rules blocking required ports can also prevent startup, so check that the vSwitch rule from Lesson 4 is in place.
Another frequent issue is invalid CIDR format in the dual-stack configuration: IPv4 and IPv6 ranges must be comma-separated without spaces.

### Dual-Stack Issues

If pods are not receiving IPv6 addresses or the API server rejects dual-stack configurations, verify that IPv6 is enabled on the system. The value should be `0`:

```bash
$ sysctl net.ipv6.conf.all.disable_ipv6
net.ipv6.conf.all.disable_ipv6 = 0
```

Also confirm the API server certificate includes the IPv6 SAN entries we configured:

```bash
$ openssl s_client -connect 127.0.0.1:6443 -showcerts </dev/null 2>/dev/null | \
  openssl x509 -noout -text | grep -A1 "Subject Alternative Name"
  openssl x509 -noout -text | grep -A1 "Subject Alternative Name"
            X509v3 Subject Alternative Name:
                DNS:kubernetes, DNS:kubernetes.default, DNS:kubernetes.default.svc, DNS:kubernetes.default.svc.cluster.local, DNS:node4, DNS:node4.k8s.local, DNS:node4.nodes.kula.app, DNS:localhost, DNS:node4, IP Address:10.1.0.14, IP Address:FD00:0:0:0:0:0:0:14, IP Address:127.0.0.1, IP Address:0:0:0:0:0:0:0:1, IP Address:10.1.0.14, IP Address:FD00:0:0:0:0:0:0:14, IP Address:10.1.0.14, IP Address:10.43.0.1
```

If `fd00::14` is missing from the output, the `tls-san` entries in the configuration may not have been applied before the first start.

### Canal Flannel CrashLoopBackOff

If the `rke2-canal` pod shows `CrashLoopBackOff` with only the `kube-flannel` container failing, check its logs:

```bash
$ kubectl -n kube-system logs -l k8s-app=canal -c kube-flannel
...
E0215 01:12:52.345678       1 main.go:123] failed to get default v6 interface: unable to find default v6 route
...
```

The error `failed to get default v6 interface: unable to find default v6 route` means the host has no IPv6 default route.
This is a host configuration issue, because Flannel auto-detects which interface to use by looking for a default route, and without one for IPv6 it refuses to start.

Verify whether a default IPv6 route exists:

```bash
$ ip -6 route show default
default via fe80::1 dev enp195s0 proto static metric 103 pref medium
```

If the output is empty, the public interface is missing its IPv6 configuration.
Follow the "Configuring Public IPv6" section in [Lesson 3](/guides/migrating-k3s-to-rke2/lesson-3#configuring-public-ipv6) to add the address and gateway, then delete the failing pod to force a restart:

```bash
$ kubectl -n kube-system delete pod -l k8s-app=canal
pod "rke2-canal-5jnm7" deleted from kube-system namespace
```

### etcd Issues

Check the etcd-related log entries and ensure the data directory has sufficient disk space:

```bash
$ journalctl -u rke2-server | grep etcd
...
Mar 02 18:00:00 node4 rke2[467421]: time="2026-03-02T18:00:00+02:00" level=info msg="Saving etcd snapshot to /var/lib/rancher/rke2/server/db/snapshots/etcd-snapshot-node4-1772467201"
...
$ df -h /var/lib/rancher/rke2/
Filesystem      Size  Used Avail Use% Mounted on
/dev/md1        1.8T  244G  1.4T  15% /
```

The node may briefly show `NotReady` while Canal finishes deploying, but once the Canal pods are running, the node transitions to `Ready`.
