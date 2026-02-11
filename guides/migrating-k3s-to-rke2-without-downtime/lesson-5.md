---
layout: guide-lesson.liquid
title: Installing Rocky Linux 9 on Node 4

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 2
guide_lesson_id: 5
guide_lesson_abstract: >
  Install Rocky Linux 9 on Node 4 and plan the dual-stack architecture decisions required before cluster creation.
guide_lesson_conclusion: >
  Node 4 is now running Rocky Linux 9 with security hardening complete and dual-stack architecture decisions documented for the cluster build.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-5.md
---

In this lesson, we'll install Rocky Linux 9 on Node 4 and configure it for Kubernetes workloads.
Rocky Linux is a community-driven, enterprise-grade Linux distribution that is fully compatible with Red Hat Enterprise Linux.
We chose Rocky Linux for its open source nature, stability, and first-class support by Hetzner.

{% include guide-overview-link.liquid.html %}

{% include alert.liquid.html type='note' title='Detailed Node Setup Guide' content='
For a comprehensive walkthrough of adding nodes to a Hetzner bare-metal cluster, see my blog post <a href="/2025-11-23-new-k3s-agent-node">New K3s agent node for our cluster</a>.
This lesson covers the essential steps specific to our RKE2 migration.
' %}

## Installing Rocky Linux via Hetzner Robot

Before we can install the operating system, we need to configure the server identity in Hetzner's management interface.
Log into the [Hetzner Robot](https://robot.hetzner.com/servers) web interface and set the server name (e.g., `node4`) along with a reverse DNS entry.
Having a proper reverse DNS entry helps with server identification in logs and monitoring tools.

After receiving the root credentials via email, access the server through SSH:

```bash
$ ssh root@<node4-public-ip>
# Enter password from email
```

Hetzner provides the `installimage` tool which makes OS installation straightforward on their dedicated servers.
This tool handles disk partitioning, OS deployment, and basic configuration in one step:

```bash
$ installimage
```

In the configuration editor, select Rocky Linux 9 and set the hostname to match your naming convention.
We use a simple partition layout without swap, dedicating the entire disk to the root partition with a small separate `/boot`:

```
PART  /boot  ext3   1024M
PART  /      ext4   all
```

Kubernetes requires swap to be disabled, and RKE2 will verify this during installation.
Rather than creating swap space we'd immediately disable, we allocate all available disk space to the root partition where container images and volumes will live.

After installation completes, reboot the server to boot into the new operating system:

```bash
$ reboot
```

When reconnecting via SSH, you'll see a host key warning because the server's SSH keys changed with the new OS installation.
This is expected behavior - remove the old entries from `~/.ssh/known_hosts` on your local machine and accept the new key when prompted.

## Essential Security Configuration

A freshly installed server needs immediate security hardening before we proceed with any other configuration.
These steps protect the server from unauthorized access and establish good security practices from the start.

### Change the Root Password

The default root password was sent via email, which means it has already been transmitted over the network.
Change it to something only you know:

```bash
$ whoami
root
$ passwd
Changing password for root.
New password: ********
Retype new password: ********
passwd: all authentication tokens updated successfully.
```

### Update the System

Security vulnerabilities are discovered regularly, and the installation image may be weeks or months old.
Update all packages to ensure the system has the latest security patches before exposing it to any workloads:

```bash
$ dnf update -y
```

### Create a Dedicated User Account

Running commands as root is dangerous as it provides unrestricted access to the system. We create a dedicated admin account that requires explicit `sudo` for privileged operations, providing both safety and accountability.

For the username, choose something that indicates the account's purpose, but ultimately it's up to you.
I recommend using a consistent naming convention across all cluster nodes, such as `k8sadmin` for Kubernetes administration:

```bash
$ useradd k8sadmin
$ passwd k8sadmin
$ usermod -aG wheel k8sadmin
```

We add the user to the `wheel` group, as it is the standard group for granting sudo privileges on RHEL-based systems.

Test that the new user account works by opening a new SSH session from your local machine:

```bash
$ ssh k8sadmin@<node4-public-ip>
```

### Set Up SSH Key Authentication

Password authentication is vulnerable to brute-force attacks and requires typing the password every time you connect.
SSH key authentication is both more secure (keys are much harder to crack than passwords) and more convenient (no password prompts).

Generate an ED25519 key pair on your local machine, as it offers better security and performance than RSA:

```bash
$ ssh-keygen -t ed25519 -f ~/.ssh/node4_k8sadmin_ed25519
$ ssh-copy-id -i ~/.ssh/node4_k8sadmin_ed25519 k8sadmin@<node4-public-ip>
```

To avoid typing the full connection details every time, add an entry to your `~/.ssh/config` file:

```
Host node4
  HostName <node4-public-ip>
  User k8sadmin
  IdentityFile ~/.ssh/node4_k8sadmin_ed25519
  IdentitiesOnly yes
```

Now you can connect with just `ssh node4` and verify that key-based authentication works before proceeding:

```bash
$ ssh node4
```

### Disable Root Login

With SSH key authentication working for our admin user, we can now disable root login entirely.
This is a critical security measure as automated bots constantly scan the internet for servers accepting root SSH connections:

```bash
$ sudo vi /etc/ssh/sshd_config

# Set: PermitRootLogin no

$ sudo systemctl restart sshd
```

From this point forward, only the `k8sadmin` account can be used to access the server, and all administrative tasks require explicit `sudo` elevation.

Using `sudo` will also log all privileged commands to the system journal, providing an audit trail of who did what and when.

## Optional: Set Up Tailscale

Managing bare-metal servers often means dealing with changing IP addresses, firewall rules, and VPN configurations.
Tailscale simplifies this by creating a secure mesh network that works regardless of network topology.

With Tailscale, you can access your cluster nodes using consistent hostnames (like `node4.tailnet-name.ts.net`) from anywhere, even behind NAT or firewalls.
This is especially valuable when you're troubleshooting cluster issues remotely.

```bash
$ sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/centos/9/tailscale.repo
$ sudo dnf install -y tailscale
$ sudo systemctl enable --now tailscaled
$ sudo tailscale up
```

Follow the authentication URL provided in the output to connect the machine to your Tailscale network.
After authentication, verify the Tailscale IP address:

```bash
$ tailscale ip -4
```

For servers that should remain permanently accessible, consider disabling key expiry in the Tailscale admin console. While it removes the need for periodic re-authentication, it also means that if the server is compromised, the attacker could maintain access indefinitely, so use this option with caution.

## Configure Timezone and Hostname

Consistent timezone configuration across all cluster nodes is important for log correlation and debugging. When investigating issues, you need timestamps to match across nodes, so all of the nodes should be set to their correct local timezone.

As our cluster nodes are located in Helsinki, we will set the timezone to `Europe/Helsinki`:

```bash
$ sudo timedatectl set-timezone Europe/Helsinki
```

The hostname should already be set from the installation, but verify it matches your naming convention:

```bash
$ hostname
node4

# If not correct, set it with:
$ sudo hostnamectl set-hostname node4
```

## Install Essential Tools

A Kubernetes node needs various tools for administration, troubleshooting, and automation.
Install these now so they're available when you need them:

```bash
$ sudo dnf install -y \
    curl \
    wget \
    vim \
    git \
    bash-completion \
    tar \
    unzip \
    net-tools \
    bind-utils \
    htop \
    jq
```

Each tool serves a specific purpose:

- `curl` and `wget` download files and test HTTP endpoints
- `vim` edits configuration files directly on the server
- `git` manages configuration as code and pulls deployment scripts
- `bash-completion` makes command-line work faster with tab completion
- `tar` and `unzip` extract downloaded archives
- `net-tools` and `bind-utils` provide networking diagnostics like `netstat` and `nslookup`
- `htop` monitors system resources in real-time
- `jq` parses JSON output from kubectl and APIs

## Verify System Readiness

Before proceeding to the next lesson, verify that the system is properly configured and can communicate with the outside world.
These checks catch common issues like DNS misconfiguration or firewall problems:

```bash
# Check kernel version (should be 5.14+ for Rocky 9)
$ uname -r

# Check available memory (RKE2 needs at least 4GB, 8GB+ recommended)
$ free -h

# Check disk space (need at least 20GB free for container images)
$ df -h /

# Verify DNS resolution works
$ nslookup philprime.dev

# Verify HTTPS connectivity (needed to download RKE2)
$ curl -s https://get.rke2.io > /dev/null && echo "Internet OK"
```

If any of these checks fail, resolve the issue before continuing.
Network problems at this stage will cause harder-to-diagnose failures during RKE2 installation.

## Planning Your Dual-Stack Architecture

Before configuring networking in the next lessons, you need to make several architectural decisions that cannot be changed after the cluster is created.
Dual-stack (IPv4 + IPv6) networking is one of those decisions.

### Why Dual-Stack Now?

Kubernetes cluster networking CIDRs are embedded in certificates, etcd data, and running workloads.
Changing from single-stack to dual-stack later requires a complete cluster rebuild.
Since we're building a new cluster anyway, this is the perfect opportunity to future-proof it.

### Decisions You Must Make Now

**Pod and Service CIDRs** define the IP ranges for all pods and services in your cluster.
You need ranges for both IPv4 and IPv6:

| Network         | IPv4 CIDR    | IPv6 CIDR     | Purpose                  |
| --------------- | ------------ | ------------- | ------------------------ |
| Pod Network     | 10.42.0.0/16 | fd00:42::/56  | IP addresses for pods    |
| Service Network | 10.43.0.0/16 | fd00:43::/112 | ClusterIP services       |
| Node Network    | 10.1.1.0/24  | fd00:1::/64   | vSwitch inter-node comms |

We use Unique Local Addresses (fd00::/8) for IPv6 as they are the equivalent of private IPv4 ranges and are not routable on the public internet.

**CNI Selection** determines your networking capabilities.
Not all CNIs support dual-stack equally:

- Cilium has excellent dual-stack support with eBPF, native routing, and WireGuard encryption
- Calico supports dual-stack but requires more configuration
- Flannel has limited dual-stack support

We'll use Cilium for its superior dual-stack implementation and observability features.

**IP Family Preference** controls which address family Kubernetes prefers for services.
With `PreferDualStack`, services get both IPv4 and IPv6 addresses, with IPv4 as the primary.
This provides maximum compatibility while enabling IPv6 where supported.

### What About NAT64 for IPv4-Only Services?

You might wonder if you need NAT64/DNS64 to reach IPv4-only external services like github.com from IPv6-only pods.
The answer is no—in a true dual-stack cluster, pods have both IPv4 and IPv6 addresses.
When a pod needs to reach an IPv4-only service, it uses its IPv4 address automatically.
The kernel handles address family selection based on DNS resolution.

NAT64 is only needed in IPv6-only environments where nodes lack IPv4 connectivity entirely.
Since Hetzner dedicated servers have both IPv4 and IPv6 public addresses, this isn't a concern.

### Ingress and Load Balancer Considerations

Your ingress controller and load balancer must also support dual-stack from day one:

- Traefik supports dual-stack natively
- Hetzner Cloud Load Balancer supports both IPv4 and IPv6 targets
- MetalLB requires separate address pools for each family

We'll configure Traefik as a DaemonSet with the Hetzner Cloud Load Balancer in later lessons.

{% include alert.liquid.html type='warning' title='Document Your Choices' content='
Write down your chosen CIDR ranges before proceeding.
You will use these values in lessons 6 (vSwitch), 8 (RKE2), and 9 (Cilium).
Inconsistent values between lessons will cause networking failures.
' %}

## Planning Your Storage Architecture

Storage decisions affect disk partitioning, which is done during OS installation.
While you can add storage classes later, the underlying disk layout is set now.

### Longhorn Disk Requirements

Longhorn stores volume replicas on each node's local disk.
With the default replica count of 2, a 10GB volume consumes 20GB of total cluster storage.
Plan your disk space accordingly:

| Component        | Minimum | Recommended | Notes                                 |
| ---------------- | ------- | ----------- | ------------------------------------- |
| OS and RKE2      | 20GB    | 40GB        | Container images, logs, etcd data     |
| Longhorn storage | 50GB    | 100GB+      | Per-node, depends on workload volumes |
| local-path       | 10GB    | 20GB        | Fast local storage for caching        |

For our simple partition layout (`/boot` + `/`), all storage shares the root partition.
If you have large storage requirements, consider a dedicated partition or disk for `/var/lib/longhorn`.

### Storage Class Strategy

We'll configure two storage classes with different trade-offs:

| Storage Class | Replicas | Use Case                                   |
| ------------- | -------- | ------------------------------------------ |
| longhorn      | 2        | Databases, stateful apps needing HA        |
| local-path    | 0        | Build caches, temp data, performance needs |

This is configured in [Lesson 17](/guides/migrating-k3s-to-rke2-without-downtime/lesson-17), but plan your disk sizes now.

### Backup Target

Longhorn supports backup to S3 or NFS.
If you plan to use backups (recommended for production), ensure you have:

- S3-compatible storage (AWS S3, MinIO, Hetzner Object Storage)
- Or an NFS server accessible from all nodes

This can be configured later but is easier to set up from the start.

## Security Decisions

Some security features are easier to enable during initial cluster setup.

### Secrets Encryption at Rest

By default, Kubernetes secrets are stored unencrypted in etcd.
RKE2 supports encrypting secrets at rest, but enabling it later requires re-encrypting all existing secrets.

To enable secrets encryption, add to your RKE2 config (covered in [Lesson 8](/guides/migrating-k3s-to-rke2-without-downtime/lesson-8)):

```yaml
secrets-encryption: true
```

This is optional but recommended for production clusters handling sensitive data.

### Pod Security Standards

Kubernetes Pod Security Standards (PSS) replace the deprecated PodSecurityPolicy.
RKE2 supports enforcing these at the cluster level:

- `privileged` - No restrictions (default)
- `baseline` - Prevents known privilege escalations
- `restricted` - Heavily restricted, follows security best practices

You can start with `privileged` and tighten later, but consider your security requirements now.

### Network Policies

With Cilium, you get L3-L7 network policies out of the box.
Decide early whether you want a default-deny policy (more secure, requires explicit allow rules) or default-allow (easier to start, less secure).

This can be changed later, but planning now helps with workload manifest preparation.

## System Information

Document the system information for your records.
This is useful when troubleshooting issues or comparing configurations across nodes:

```bash
echo "=== Node 4 System Information ==="
echo "Hostname: $(hostname)"
echo "OS: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "Disk: $(df -h / | tail -1 | awk '{print $2}')"
```

With Rocky Linux 9 installed and secured, Node 4 is ready for network configuration.
In the next lesson, we'll set up the Hetzner vSwitch private networking that allows secure communication between cluster nodes.
