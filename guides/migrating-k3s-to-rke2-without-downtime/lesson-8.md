---
layout: guide-lesson.liquid
title: Installing the RKE2 Server

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 2
guide_lesson_id: 8
guide_lesson_abstract: >
  Install and configure RKE2 as the first control plane node with dual-stack networking and security settings.
guide_lesson_conclusion: >
  The first RKE2 control plane is running with dual-stack networking and Canal CNI.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-8.md
---

With networking and firewall configured, Node 4 is ready to run the first RKE2 control plane with dual-stack networking.
This establishes the foundation of Cluster B that will eventually replace the k3s cluster.

{% include guide-overview-link.liquid.html %}

{% include alert.liquid.html type='warning' title='WARNING:' content='
All commands used in this lesson require <code>sudo</code> privileges.
Either prepend <code>sudo</code> to each command or switch to the root user using <code>sudo -i</code>.
' %}

## Understanding RKE2

### Architecture Overview

RKE2 (also known as RKE Government) is a fully conformant Kubernetes distribution focused on security and compliance.
Unlike k3s which prioritizes minimal resource usage, RKE2 prioritizes security hardening and FIPS compliance.

```mermaid!
flowchart TB
    subgraph RKE2["RKE2 Server · Control Plane"]
        subgraph CP["Control Plane Components"]
            API["API Server"]
            CM["Controller Manager"]
            SCHED["Scheduler"]
        end

        ETCD["etcd<br/><i>Embedded</i>"]

        subgraph Node["Node Components"]
            KUB["Kubelet"]
            CTD["Containerd"]
        end

        API --> ETCD
    end

    classDef cp fill:#2563eb,color:#fff,stroke:#1e40af
    classDef etcd fill:#16a34a,color:#fff,stroke:#166534
    classDef node fill:#9ca3af,color:#fff,stroke:#6b7280

    class API,CM,SCHED cp
    class ETCD etcd
    class KUB,CTD node
```

Each RKE2 node runs as either a server (control plane) or an agent (worker), with the server embedding etcd directly:

| Component   | Description                                                    |
| ----------- | -------------------------------------------------------------- |
| rke2-server | Control plane: API server, controller manager, scheduler, etcd |
| rke2-agent  | Worker node: kubelet and container runtime                     |
| etcd        | Embedded distributed key-value store for cluster state         |
| containerd  | Container runtime (Docker is not used)                         |

### Security Features

RKE2 includes several security features that should be configured during initial setup.

Secrets encryption at rest protects Kubernetes secrets stored in etcd.
Enabling this later requires re-encrypting all existing secrets, so it's best to turn it on from the start.

Pod Security Standards (PSS) replace the deprecated PodSecurityPolicy and define three escalating profiles:

| Profile    | Description                                         |
| ---------- | --------------------------------------------------- |
| privileged | No restrictions (default)                           |
| baseline   | Prevents known privilege escalations                |
| restricted | Heavily restricted, follows security best practices |

You can start with `privileged` and tighten later, or start strict with `restricted`.
For our use case we are going with `restricted` from the start to enforce security best practices.

Network policies are enforced by the CNI plugin.
Canal uses Calico's policy engine to provide L3-L4 network policies out of the box.

### Bundled Addons

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

We disable `rke2-ingress-nginx` because k3s ships with Traefik as its default ingress controller.
Our existing Ingress and IngressRoute definitions already target Traefik, so deploying Traefik on the RKE2 cluster lets us reuse them without changes.

## Configuration Planning

### Network CIDRs

These CIDR ranges were planned in [Lesson 6](/guides/migrating-k3s-to-rke2-without-downtime/lesson-6) and cannot be changed after cluster creation:

| Network         | IPv4 CIDR    | IPv6 CIDR     |
| --------------- | ------------ | ------------- |
| Node Network    | 10.0.0.0/24  | fd00::/64     |
| Pod Network     | 10.42.0.0/16 | fd00:42::/56  |
| Service Network | 10.43.0.0/16 | fd00:43::/112 |
| Cluster DNS     | 10.43.0.10   | fd00:43::a    |

### Configuration Options

The RKE2 configuration file supports these key options for dual-stack:

| Option               | Purpose                                    |
| -------------------- | ------------------------------------------ |
| `token`              | Authenticates nodes joining the cluster    |
| `tls-san`            | Additional names/IPs for API server cert   |
| `cni`                | CNI plugin (Canal is the default)          |
| `node-ip`            | Node's IPs, comma-separated for dual-stack |
| `cluster-cidr`       | Pod network CIDRs, comma-separated         |
| `service-cidr`       | Service network CIDRs, comma-separated     |
| `cluster-dns`        | DNS service IP                             |
| `secrets-encryption` | Enable encryption at rest                  |

### File Locations

RKE2 stores its configuration, certificates, and data across several directories:

| Path                                      | Content             |
| ----------------------------------------- | ------------------- |
| `/etc/rancher/rke2/config.yaml.d/`        | RKE2 configuration  |
| `/etc/rancher/rke2/rke2.yaml`             | Kubeconfig file     |
| `/var/lib/rancher/rke2/bin/`              | Kubernetes binaries |
| `/var/lib/rancher/rke2/server/node-token` | Cluster join token  |
| `/var/lib/rancher/rke2/server/tls/`       | TLS certificates    |
| `/var/lib/rancher/rke2/server/db/`        | etcd data           |

## Installing RKE2

### Run the Installer

RKE2 provides an install script that downloads the correct binary for your architecture.
You can explore the available options and flags in the [RKE2 installation guide](https://docs.rke2.io/install/).

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

### Create Configuration

RKE2 reads configuration from `/etc/rancher/rke2/config.yaml` and `/etc/rancher/rke2/config.yaml.d/*.yaml` in alphabetical order.
Splitting settings into numbered files keeps each concern isolated and makes it easy to add or remove features later without editing a single monolithic file.

```bash
$ mkdir -p /etc/rancher/rke2/config.yaml.d
```

The network configuration sets up dual-stack node addressing, keeps API server traffic on the private vSwitch, and defines the pod and service CIDRs planned in [Lesson 6](/guides/migrating-k3s-to-rke2-without-downtime/lesson-6):

```yaml
# /etc/rancher/rke2/config.yaml.d/10-network.yaml

# Canal is the default CNI and auto-detects dual-stack from the cluster CIDRs
cni: canal

# Dual-stack node IPs on the private vSwitch interface
node-ip: 10.0.0.4,fd00::4
# Public IPs so Kubernetes knows how to reach this node externally
node-external-ip:
  - 135.181.XX.XX
  - 2a01:4f9:XX:XX::2
# Advertise the API server on the private vSwitch IP for cluster communication
advertise-address: 10.0.0.4
# Bind the API server to the private vSwitch IP
bind-address: 10.0.0.4

# Dual-stack pod and service CIDRs (cannot be changed after cluster creation)
cluster-cidr: 10.42.0.0/16,fd00:42::/56
service-cidr: 10.43.0.0/16,fd00:43::/112
cluster-dns: 10.43.0.10
```

The external access configuration adds SANs to the API server certificate so `kubectl` can connect via hostname, IP, or a public DNS name without TLS errors:

```yaml
# /etc/rancher/rke2/config.yaml.d/20-external-access.yaml

tls-san:
  - node4
  - node4.k8s.local
  - 10.0.0.4
  - fd00::4
  - cluster.yourdomain.com # Optional: a public DNS name for external kubectl access

# Allow non-root users to read the generated kubeconfig
write-kubeconfig-mode: "0644"
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
Wait until you see the API server is ready:

```bash
rke2[108343]: time="2026-02-15T01:12:47+02:00" level=info msg="Kube API server is now running"
```

Press `Ctrl+C` to exit the log view.

After startup, RKE2 generates a cluster join token at `/var/lib/rancher/rke2/server/node-token`.
This token is needed when registering additional server or agent nodes to the cluster.

### Configure kubectl

RKE2 generates a kubeconfig file at `/etc/rancher/rke2/rke2.yaml` and places the `kubectl` binary in `/var/lib/rancher/rke2/bin/`.
Copy the kubeconfig to the standard location and add the binary path to your shell:

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
We need `etcdctl` to inspect cluster health, list members, and debug issues—tasks that become essential once additional control plane nodes join.

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

Every `etcdctl` command against RKE2's etcd requires TLS certificate flags.
A shell alias keeps these out of the way:

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

## Verification

### Cluster Status

Check that the node is registered with the cluster:

```bash
$ kubectl get nodes -o wide
NAME   STATUS   ROLES                AGE   VERSION          INTERNAL-IP   EXTERNAL-IP     OS-IMAGE                        KERNEL-VERSION                  CONTAINER-RUNTIME
node4   Ready    control-plane,etcd   10m   v1.34.3+rke2r3   10.0.0.4      135.181.1.252   Rocky Linux 10.1 (Red Quartz)   6.12.0-124.27.1.el10_1.x86_64   containerd://2.1.5-k3s1
```

The node may initially show `NotReady` while Canal deploys, then transition to `Ready` when the cluster is fully operational.

### Dual-Stack Configuration

Verify the node has both IPv4 and IPv6 addresses registered:

```bash
$ kubectl get nodes -o jsonpath='{.items[*].status.addresses}' | jq .
[
  {
    "address": "10.0.0.4",
    "type": "InternalIP"
  },
  {
    "address": "fd00::4",
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

You should see both `InternalIP` entries—one for `10.0.0.4` and one for `fd00::4`.

Confirm the cluster CIDR configuration matches what we planned:

```bash
$ kubectl cluster-info dump | grep -E "cluster-cidr|service-cluster-ip-range"
                            "--cluster-cidr=10.42.0.0/16,fd00:42::/56",
                            "--service-cluster-ip-range=10.43.0.0/16,fd00:43::/112",
                            "--cluster-cidr=10.42.0.0/16,fd00:42::/56",
                            "--service-cluster-ip-range=10.43.0.0/16,fd00:43::/112",
                            "--cluster-cidr=10.42.0.0/16,fd00:42::/56",
```

The output should show both IPv4 and IPv6 CIDRs for `cluster-cidr` and `service-cluster-ip-range`.

### etcd Health

Verify the embedded etcd instance is healthy using the `etcdctl` alias we configured earlier:

```bash
$ etcdctl endpoint health --cluster --write-out=table
+-----------------------+--------+------------+-------+
|       ENDPOINT        | HEALTH |    TOOK    | ERROR |
+-----------------------+--------+------------+-------+
| https://10.0.0.4:2379 |   true | 2.527854ms |       |
+-----------------------+--------+------------+-------+
```

A single-node cluster shows one endpoint.
As we add control plane nodes in later lessons, this table will grow to three entries.

## Create Initial Backup

Before making any further changes, back up the configuration files and take an etcd snapshot:

```bash
$ mkdir -p /root/rke2-backup
$ cp -r /etc/rancher/rke2/config.yaml.d /root/rke2-backup/
$ cp /var/lib/rancher/rke2/server/node-token /root/rke2-backup/
$ cp ~/.kube/config /root/rke2-backup/kubeconfig

$ rke2 etcd-snapshot save --name initial-setup
```

This gives us a restore point in case anything goes wrong during subsequent configuration.

## Troubleshooting

### RKE2 Won't Start

If the service fails to start, check the status and logs for details:

```bash
$ systemctl status rke2-server
$ journalctl -xeu rke2-server
```

The most common cause is port `6443` already being in use by an existing k3s or Kubernetes installation.
Firewall rules blocking required ports can also prevent startup—check that the vSwitch rule from Lesson 7 is in place.
Another frequent issue is invalid CIDR format in the dual-stack configuration: IPv4 and IPv6 ranges must be comma-separated without spaces.

### Dual-Stack Issues

If pods aren't receiving IPv6 addresses or the API server rejects dual-stack configurations, verify that IPv6 is enabled on the system—the value should be `0`:

```bash
$ sysctl net.ipv6.conf.all.disable_ipv6
```

Also confirm the API server certificate includes the IPv6 SAN entries we configured:

```bash
$ openssl s_client -connect 127.0.0.1:6443 -showcerts </dev/null 2>/dev/null | \
  openssl x509 -noout -text | grep -A1 "Subject Alternative Name"
```

If `fd00::4` is missing from the output, the `tls-san` entries in `config.yaml` may not have been applied before the first start.

### Canal Flannel CrashLoopBackOff

If the `rke2-canal` pod shows `CrashLoopBackOff` with only the `kube-flannel` container failing, check its logs:

```bash
$ kubectl -n kube-system logs -l k8s-app=canal -c kube-flannel
```

The error `failed to get default v6 interface: unable to find default v6 route` means the host has no IPv6 default route.
Flannel auto-detects which interface to use by looking for a default route, and without one for IPv6 it refuses to start.

Verify whether a default IPv6 route exists:

```bash
$ ip -6 route show default
```

If the output is empty, the public interface is missing its IPv6 configuration.
Follow the "Configuring Public IPv6" section in [Lesson 6](/guides/migrating-k3s-to-rke2-without-downtime/lesson-6) to add the address and gateway, then delete the failing pod to force a restart:

```bash
$ kubectl -n kube-system delete pod -l k8s-app=canal
```

### etcd Issues

Check the etcd-related log entries and ensure the data directory has sufficient disk space:

```bash
$ journalctl -u rke2-server | grep etcd
$ df -h /var/lib/rancher/rke2/
```

The node may briefly show `NotReady` while Canal finishes deploying.
Once the Canal pods are running, the node transitions to `Ready`.
