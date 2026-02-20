---
layout: guide-lesson.liquid
title: Firewall Configuration

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 1
guide_lesson_id: 4
guide_lesson_abstract: >
  Before any RKE2 component can communicate across nodes, the Hetzner firewall must permit cluster traffic.
  This lesson explains the three-layer security model, walks through each firewall rule, and verifies that the configuration works from both the private vSwitch and the public internet.
guide_lesson_conclusion: >
  Our Hetzner firewall now permits all necessary cluster, service, and return traffic while keeping unused ports blocked.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-4.md
---

With the vSwitch network in place from Lesson 3, our nodes can reach each other over a private Layer 2 link.
Traffic on that link still passes through Hetzner's firewall infrastructure, though, so we need explicit rules before RKE2 components can communicate.
This lesson covers the first layer of our three-layer security model: the Hetzner network firewall.

{% include guide-overview-link.liquid.html %}

## Understanding the Three-Layer Security Model

We use a layered approach to network security, with each layer serving a specific purpose:

| Layer | Component                  | Purpose                                                          |
| ----- | -------------------------- | ---------------------------------------------------------------- |
| 1     | Hetzner Firewall           | Coarse network-level filtering before traffic reaches the server |
| 2     | Calico Network Policies    | Fine-grained port control on the host                            |
| 3     | Kubernetes NetworkPolicies | Pod-to-pod isolation and service-level access control            |

This architecture provides defense-in-depth.
If one layer fails or is misconfigured, the others still provide protection.

### Why Layers?

Hetzner's firewall has a 10-rule limit, which forces us to use broad port ranges.
Opening ports `22-587`, for example, allows SSH, SMTP, HTTP, and HTTPS but also opens unused ports like `23-24` and `81-442`.

We configure Calico Network Policies in Lesson 9 to close this gap by explicitly allowing only the specific ports we need.
Even though Hetzner permits the range, Calico blocks everything except SSH (`22`), SMTP (`25`), HTTP (`80`), HTTPS (`443`), and SMTP-submission (`587`).
If Calico fails, the system falls back to Hetzner rules only, which are broader but still reasonably secure.

## Understanding Hetzner's Firewall

Hetzner's dedicated server firewall operates at the network level, filtering packets before they reach the server.
This is more secure than host-based firewalls because malicious traffic never touches the machine's network stack.
The firewall is stateless, meaning it evaluates each packet independently without tracking connection state.

This stateless design has an important implication: we need explicit rules to allow return traffic from outbound connections.
When the server makes an HTTPS request to download a container image, the response packets need a rule that permits them.
We handle this with a rule that allows TCP packets with the `ACK` flag set on ephemeral ports.

### vSwitch Traffic

A critical point that is easy to overlook: **vSwitch traffic passes through Hetzner's firewall**.
Even though the vSwitch is a private Layer 2 network between servers, packets still traverse the firewall infrastructure.
Without a rule explicitly allowing traffic from the vSwitch subnet, pod-to-pod communication across nodes will fail and the cluster will not function.

### Ephemeral Ports and NodePorts

When the server makes an outbound connection — downloading container images, querying APIs — the kernel assigns a temporary source port from the ephemeral port range.
The response packets return to this port, so the firewall must allow them through.
We can check the system's ephemeral port range:

```bash
$ cat /proc/sys/net/ipv4/ip_local_port_range
32768	60999
```

Linux defaults to `32768-60999` for ephemeral ports.
Kubernetes defaults to `30000-32767` for NodePort services.
These ranges are intentionally non-overlapping:

| Range         | Purpose                  | Used by      |
| ------------- | ------------------------ | ------------ |
| `30000-32767` | NodePort services        | Kubernetes   |
| `32768-60999` | Ephemeral (source) ports | Linux kernel |

The boundary at `32767`/`32768` is `2^15 - 1` / `2^15`, a deliberate design choice to prevent conflicts.
Our firewall rules respect this boundary: the tcp-established rule covers `32768-65535` for return traffic, while the nodeports rule covers `30000-32767` for inbound service access.

### Port Strategy

Some ports are dictated by protocol standards and must use specific numbers:

| Port   | Service         | Reason                            |
| ------ | --------------- | --------------------------------- |
| `22`   | SSH             | Standard remote access            |
| `25`   | SMTP            | Receiving mail from other servers |
| `80`   | HTTP            | ACME challenges and redirects     |
| `443`  | HTTPS           | Web traffic                       |
| `587`  | SMTP submission | Sending mail                      |
| `6443` | Kubernetes API  | RKE2 default                      |

Services without protocol-mandated ports must use the Kubernetes NodePort range (`30000-32767`).
PostgreSQL can run on port `30432` instead of `5432`, and Redis on `30379` instead of `6379`.
Ports outside this range (like `35432`) will not be accessible through the firewall.
Calico Network Policies control which specific ports within this range are actually accessible.

### IPv6 Considerations

Hetzner's firewall has some limitations with IPv6.
ICMPv6 traffic is always allowed and cannot be filtered, which is actually helpful since IPv6 requires ICMPv6 for neighbor discovery.
However, we cannot filter IPv6 traffic by source or destination IP address — only by protocol and port.
For our dual-stack cluster, the vSwitch rule only applies to IPv4, but since our ULA addresses (`fd00::/64`) are not routable on the public internet, this is not a security concern.

## Configuring the Firewall

Navigate to the [Hetzner Robot](https://robot.hetzner.com/server) interface, select the server (node4), and click "Firewall" to access the rules configuration.

### Firewall Settings

| Setting                     | Value  | Notes                                  |
| --------------------------- | ------ | -------------------------------------- |
| Status                      | active | Enable the firewall                    |
| Filter IPv6 packets         | yes    | Enable IPv6 filtering                  |
| Hetzner Services (incoming) | yes    | Allow rescue system, DNS, SysMon, etc. |

### Rules (incoming)

The firewall has a **10-rule limit**.
ICMPv6 is always allowed and cannot be blocked, so we do not need a rule for it.
Most rules are mirrored for IPv4 and IPv6 to provide full dual-stack coverage.

| ID | Name               | Version | Protocol | Source IP   | Source Port | Dest Port   | TCP Flags | Action |
| -- | ------------------ | ------- | -------- | ----------- | ----------- | ----------- | --------- | ------ |
| #1 | vswitch            | ipv4    | *        | 10.1.0.0/16 |             |             |           | accept |
| #2 | tcp established    | ipv4    | tcp      |             |             | 32768-65535 | ack       | accept |
| #3 | tcp established-v6 | ipv6    | tcp      |             |             | 32768-65535 | ack       | accept |
| #4 | dns responses      | ipv4    | udp      |             | 53          | 32768-65535 |           | accept |
| #5 | well-known         | ipv4    | tcp      |             |             | 22-587      |           | accept |
| #6 | well-known-v6      | ipv6    | tcp      |             |             | 22-587      |           | accept |
| #7 | k8s-api            | ipv4    | tcp      |             |             | 6443        |           | accept |
| #8 | k8s-api-v6         | ipv6    | tcp      |             |             | 6443        |           | accept |
| #9 | nodeports          | *       | *        |             |             | 30000-32767 |           | accept |

Rule #10 is available for future use.
Calico Network Policies (Layer 2) handle fine-grained filtering within these ranges.

### Rules (outgoing)

| ID | Name      | Version | Protocol | Source IP | Dest IP | Source Port | Dest Port | TCP Flags | Action |
| -- | --------- | ------- | -------- | --------- | ------- | ----------- | --------- | --------- | ------ |
| #1 | allow all | *       | *        |           |         |             |           |           | accept |

### Rule Explanations

Rule #1 (vswitch) is the most critical rule for cluster operation.
It allows all traffic from the private vSwitch network, enabling Kubernetes API communication between nodes, etcd cluster synchronization, Calico's pod networking, and kubelet communication.
Without this rule, the cluster cannot function.

Rules #2-3 (tcp established) handle return traffic for outbound TCP connections.
When the server connects to external services — container registries, package repositories, APIs — the responses arrive as packets with the `ACK` flag set.
These rules allow those responses on ephemeral ports (`32768-65535`) for both IPv4 and IPv6.

Rule #4 (dns responses) permits DNS reply packets.
DNS queries go out on a random high port, and responses come back from port `53`.
This rule ensures those responses reach the server.

Rules #5-6 (well-known) cover SSH (`22`), SMTP (`25`), HTTP (`80`), HTTPS (`443`), and SMTP-submission (`587`) for both IPv4 and IPv6.
This opens some unused ports (`23-24`, `26-79`, `81-442`, `444-586`), but Calico Network Policies block those at Layer 2.

Rules #7-8 (k8s-api) open port `6443` for Kubernetes API access over both IPv4 and IPv6.
This allows `kubectl` commands and other API clients to reach the cluster from outside the vSwitch network.

Rule #9 (nodeports) opens the standard Kubernetes NodePort range (`30000-32767`) for both IPv4 and IPv6.
It uses wildcard version (`*`) and protocol (`*`) to cover both address families in a single rule.
PostgreSQL (`30432`), Redis (`30379`), and other services can use ports in this range, with Calico Network Policies controlling which specific ports are accessible.

Tailscale is not listed because it uses NAT traversal with outbound connections.
Since we allow all outbound traffic, Tailscale works without an inbound rule.
ICMP is omitted to stay within the limit; we can still ping via the vSwitch since Rule #1 allows all traffic from that subnet.

### Applying the Rules

After entering all rules, click "Save" to apply them.
Changes typically propagate within 30-60 seconds.

## Verification

### vSwitch Connectivity

We test that nodes can communicate over the private network using IPv4.
From node1, ping node4:

```bash
$ ping -c 3 10.1.0.14
64 bytes from 10.1.0.14: icmp_seq=1 ttl=64 time=0.351 ms
...
3 packets transmitted, 3 received, 0% packet loss
```

From node4, ping node1:

```bash
$ ping -c 3 10.1.0.11
64 bytes from 10.1.0.11: icmp_seq=1 ttl=64 time=0.348 ms
...
3 packets transmitted, 3 received, 0% packet loss
```

This works because Rule #1 allows all traffic from the vSwitch subnet, including ICMP.
If pings fail, verify that Rule #1 has the correct source IP (`10.1.0.0/16`) and is set to `accept`.
IPv6 connectivity over the vSwitch is not configured on the existing nodes yet, so we only test IPv4 here.

### Port Scan from vSwitch

Install nmap on node1 if it is not already available:

```bash
$ dnf install -y nmap
```

Verify that the vSwitch rule allows unrestricted access by scanning node4 from node1:

```bash
# Scan all ports on node4's private IP from node1
$ nmap -sT 10.1.0.14 -p-
Nmap scan report for 10.1.0.14
Host is up (0.00018s latency).
Not shown: 65534 closed tcp ports (conn-refused)

PORT   STATE SERVICE
22/tcp open  ssh

Nmap done: 1 IP address (1 host up) scanned in 1.33 seconds
```

Only SSH (port `22`) is open since it is the only service running on the fresh server.
The remaining 65534 ports show as `closed` (reachable but no service listening), and none show as `filtered`.
This confirms Rule #1 permits all traffic from the vSwitch subnet regardless of port or protocol.

### Port Scan from Public Internet

From a machine outside the vSwitch, scan node4's public IP to verify the firewall boundaries:

```bash
# From an external machine, scan node4's public IP for relevant ports
$ nmap -Pn -sT -v -T4 --min-rate 5000 <node4-public-ip> -p 21,22,443,587,588,6443,6444,29999,30000,32767,32768

PORT      STATE    SERVICE
21/tcp    filtered ftp
22/tcp    open     ssh
443/tcp   closed   https
587/tcp   closed   submission
588/tcp   filtered cal
6443/tcp  closed   sun-sr-https
6444/tcp  filtered sge_qmaster
29999/tcp filtered bingbang
30000/tcp closed   ndmps
32767/tcp closed   filenet-powsrm
32768/tcp filtered filenet-tms
```

The results confirm each firewall zone:

| Port  | State    | Reason                                            |
| ----- | -------- | ------------------------------------------------- |
| 21    | filtered | Below well-known range, blocked by firewall       |
| 22    | open     | In well-known range (`22-587`), SSH is listening  |
| 443   | closed   | In well-known range, allowed but no service yet   |
| 587   | closed   | End of well-known range, allowed but no service   |
| 588   | filtered | Above well-known range, blocked                   |
| 6443  | closed   | k8s-api rule, allowed but RKE2 not installed yet  |
| 6444  | filtered | Not in any allowed range, blocked                 |
| 29999 | filtered | Below nodeport range, blocked                     |
| 30000 | closed   | Start of nodeport range, allowed but no service   |
| 32767 | closed   | End of nodeport range, allowed but no service     |
| 32768 | filtered | Ephemeral range requires ACK flag, SYN is blocked |

The `-Pn` flag skips host discovery since there is no public ICMP rule.
Ports showing `closed` are reachable through the firewall but have no service listening.
Ports showing `filtered` are blocked by the firewall and never reach the server.

### Full Port Scan

To scan all 65535 ports from the public internet, use `--min-rate` to prevent nmap from slowing down on filtered ports:

```bash
$ nmap -Pn -sT -v --min-rate 1000 <node4-public-ip> -p-
```

{% include alert.liquid.html type='warning' title='Long Running Scan' content='
A full port scan against a firewalled host can take 30 minutes or more, even with --min-rate.
Filtered ports cause timeouts that slow the scan significantly.
The targeted scan above covers all firewall zone boundaries and is sufficient for verification.
' %}
