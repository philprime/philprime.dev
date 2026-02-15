---
layout: guide-lesson.liquid
title: Installing Rocky Linux 10 on Node 4

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 2
guide_lesson_id: 2
guide_lesson_abstract: >
  Install Rocky Linux 10 on Node 4 with security hardening, essential tools, and storage planning for the RKE2 cluster.
guide_lesson_conclusion: >
  Node 4 is now running Rocky Linux 10 with security hardening complete, ready for network configuration.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-5.md
---

Node 4 needs a fresh operating system before it can serve as the first RKE2 control plane.
Rocky Linux is a community-driven, enterprise-grade Linux distribution that is fully compatible with Red Hat Enterprise Linux.
We chose it for its open source nature, stability, and first-class support by Hetzner.

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

In the configuration editor, select Rocky Linux 10 and set the hostname to match your naming convention.
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
This is expected—remove the old entries from `~/.ssh/known_hosts` on your local machine and accept the new key when prompted.

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
passwd: password updated successfully
```

### Update the System

Security vulnerabilities are patched regularly, and the installation image may be weeks or months old.
Update all packages to ensure the system has the latest security patches before exposing it to any workloads:

```bash
$ dnf update -y
```

### Create a Dedicated User Account

Running commands as root is dangerous as it provides unrestricted access to the system.
We create a dedicated admin account that requires explicit `sudo` for privileged operations, providing both safety and accountability.

Choose a username that indicates the account's purpose and remains consistent across all cluster nodes.
We use `k8sadmin` throughout this guide for Kubernetes administration:

```bash
$ useradd k8sadmin
$ passwd k8sadmin
New password:
Retype new password:
passwd: password updated successfully
$ usermod -aG wheel k8sadmin
```

Adding the user to the `wheel` group grants sudo privileges on RHEL-based systems.

Test that the new user account works by opening a new SSH session from your local machine:

```bash
$ ssh k8sadmin@<node4-public-ip>
```

### Set Up SSH Key Authentication

Password authentication is vulnerable to brute-force attacks and requires typing credentials on every connection.
SSH key authentication eliminates both problems—keys are far harder to crack and connect without password prompts.

Generate an ED25519 key pair on your local machine, which offers better security and performance than RSA:

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
Using `sudo` also logs all privileged commands to the system journal, providing an audit trail of who did what and when.

## Optional: Set Up Tailscale

Managing bare-metal servers often means dealing with changing IP addresses, firewall rules, and VPN configurations.
Tailscale simplifies this by creating a secure mesh network that works regardless of network topology.

With Tailscale, you can access your cluster nodes using consistent hostnames (like `node4.tailnet-name.ts.net`) from anywhere, even behind NAT or firewalls.
This is especially valuable when you're troubleshooting cluster issues remotely.

```bash
$ sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/fedora//tailscale.repo
$ sudo dnf install -y tailscale
$ sudo systemctl enable --now tailscaled
$ sudo tailscale up
```

Follow the authentication URL provided in the output to connect the machine to your Tailscale network.
After authentication, verify the Tailscale IP address:

```bash
$ tailscale ip -4
```

For servers that should remain permanently accessible, consider disabling key expiry in the Tailscale admin console.
This removes the need for periodic re-authentication, but it also means a compromised server could maintain access indefinitely—use this option with caution.

## Configure Timezone and Hostname

Consistent timezone configuration across all cluster nodes is important for log correlation and debugging.
When investigating issues, you need timestamps to match across nodes, so set all nodes to their correct local timezone.

As our cluster nodes are located in Helsinki, we set the timezone to `Europe/Helsinki`:

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
    vim \
    git \
    bash-completion \
    tar \
    unzip \
    net-tools \
    bind-utils \
    jq
```

| Tool                         | Purpose                                              |
| ---------------------------- | ---------------------------------------------------- |
| `git`                        | Manages configuration as code and deployment scripts |
| `bash-completion`            | Enables tab completion for faster command-line work  |
| `tar` and `unzip`            | Extract downloaded archives                          |
| `net-tools` and `bind-utils` | Networking diagnostics like `netstat` and `nslookup` |
| `jq`                         | Parses JSON output from `kubectl` and APIs           |

## Verify System Readiness

Before proceeding, verify that the system is properly configured and can communicate with the outside world.
These checks catch common issues like DNS misconfiguration or firewall problems:

```bash
# Check kernel version (should be 6.12+ for Rocky 10)
$ uname -r
6.12.0-124.27.1.el10_1.x86_64

# Check available memory (RKE2 needs at least 4GB, 8GB+ recommended)
$ free -h
               total        used        free      shared  buff/cache   available
Mem:           125Gi       5.0Gi       119Gi       4.3Mi       1.2Gi       120Gi
Swap:             0B          0B          0B

# Check disk space (need at least 20GB free for container images)
$ df -h /
Filesystem      Size  Used Avail Use% Mounted on
/dev/md1        1.8T  1.5G  1.7T   1% /

# Verify DNS resolution works
$ nslookup philprime.dev
Server:		100.100.100.100
Address:	100.100.100.100#53

Non-authoritative answer:
Name:	philprime.dev
Address: 104.21.66.10
Name:	philprime.dev
Address: 172.67.197.206
Name:	philprime.dev
Address: 2606:4700:3032::6815:420a
Name:	philprime.dev
Address: 2606:4700:3036::ac43:c5ce

# Verify HTTPS connectivity (needed to download RKE2)
$ curl -s https://get.rke2.io > /dev/null && echo "Internet OK"
Internet OK
```

If any of these checks fail, resolve the issue before continuing.
Network problems at this stage will cause harder-to-diagnose failures during RKE2 installation.
