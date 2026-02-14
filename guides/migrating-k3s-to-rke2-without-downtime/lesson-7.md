---
layout: guide-lesson.liquid
title: Firewall Configuration

guide_component: lesson
guide_id: migrating-k3s-to-rke2-without-downtime
guide_section_id: 2
guide_lesson_id: 7
guide_lesson_abstract: >
  Configure Hetzner Robot firewall rules to allow RKE2 cluster traffic while maintaining security.
guide_lesson_conclusion: >
  The Hetzner firewall is configured to allow cluster communication over the vSwitch and necessary public services.
repo_file_path: guides/migrating-k3s-to-rke2-without-downtime/lesson-7.md
---

Before installing RKE2, we need to configure firewall rules that allow cluster components to communicate.
This lesson covers the first layer of our three-layer security model: the Hetzner network firewall.

{% include guide-overview-link.liquid.html %}

## Understanding the Three-Layer Security Model

We use a layered approach to network security, with each layer serving a specific purpose:

| Layer | Component                  | Purpose                                                          |
| ----- | -------------------------- | ---------------------------------------------------------------- |
| 1     | Hetzner Firewall           | Coarse network-level filtering before traffic reaches the server |
| 2     | Cilium Host Policies       | Fine-grained port control on the host using eBPF                 |
| 3     | Kubernetes NetworkPolicies | Pod-to-pod isolation and service-level access control            |

This architecture provides defense-in-depth: if one layer fails or is misconfigured, the others still provide protection.

### Why Layers?

Hetzner's firewall has a 10-rule limit, which forces us to use broad port ranges.
For example, opening ports `22-587` allows SSH, SMTP, HTTP, and HTTPS, but also opens unused ports like `23-24` and `81-442`.

Cilium Host Policies (configured in Lesson 9) close this gap by explicitly allowing only the specific ports we need.
Even though Hetzner permits the range, Cilium blocks everything except SSH (`22`), SMTP (`25`), HTTP (`80`), HTTPS (`443`), and SMTP-submission (`587`).

If Cilium fails, the system falls back to Hetzner rules only, which are broader but still reasonably secure.

## Understanding Hetzner's Firewall

Hetzner's dedicated server firewall operates at the network level, filtering packets before they reach your server.
This is more secure than host-based firewalls because malicious traffic never touches your machine's network stack.
The firewall is stateless, meaning it evaluates each packet independently without tracking connection state.

This stateless design has an important implication: you need explicit rules to allow return traffic from outbound connections.
When your server makes an HTTPS request to download a container image, the response packets need a rule that permits them.
We'll handle this with a rule that allows TCP packets with the `ACK` flag set on ephemeral ports.

### vSwitch Traffic

A critical point that's easy to overlook: **vSwitch traffic passes through Hetzner's firewall**.
Even though the vSwitch is a private Layer 2 network between your servers, packets still traverse the firewall infrastructure.
Without a rule explicitly allowing traffic from your vSwitch subnet, pod-to-pod communication across nodes will fail and your cluster won't function.

### Ephemeral Ports and NodePorts

When your server makes an outbound connection (downloading container images, querying APIs), the kernel assigns a temporary source port from the ephemeral port range.
The response packets return to this port, so the firewall must allow them through.

You can check your system's ephemeral port range:

```bash
cat /proc/sys/net/ipv4/ip_local_port_range
# Output: 32768    60999
```

Linux defaults to `32768-60999` for ephemeral ports.
Kubernetes defaults to `30000-32767` for NodePort services.

These ranges are intentionally non-overlapping:

| Range         | Purpose                  | Used by      |
| ------------- | ------------------------ | ------------ |
| `30000-32767` | NodePort services        | Kubernetes   |
| `32768-60999` | Ephemeral (source) ports | Linux kernel |

The boundary at `32767`/`32768` is `2^15 - 1` / `2^15`, a deliberate design choice to prevent conflicts.
Our firewall rules respect this boundary: the `tcp established` rule covers `32768-65535` for return traffic, while the `nodeports` rule covers `30000-32767` for inbound service access.

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
For example, PostgreSQL can run on port `30432` instead of `5432`, and Redis on `30379` instead of `6379`.
Ports outside this range (like `35432`) won't be accessible through the firewall.
Cilium Host Policies control which specific ports within this range are actually accessible.

### IPv6 Considerations

Hetzner's firewall has some limitations with IPv6.
ICMPv6 traffic is always allowed and cannot be filtered, which is actually helpful since IPv6 requires ICMPv6 for neighbor discovery.
However, you cannot filter IPv6 traffic by source or destination IP address, only by protocol and port.
For our dual-stack cluster, the vSwitch rule only applies to IPv4, but since our ULA addresses (`fd00::/64`) are not routable on the public internet, this isn't a security concern.

## Configuring the Firewall

Navigate to the [Hetzner Robot](https://robot.hetzner.com/server) interface, select your server (node4), and click "Firewall" to access the rules configuration.

### Firewall Settings

| Setting                     | Value  | Notes                                  |
| --------------------------- | ------ | -------------------------------------- |
| Status                      | active | Enable the firewall                    |
| Filter IPv6 packets         | ☑      | Enable IPv6 filtering                  |
| Hetzner Services (incoming) | ☑      | Allow rescue system, DNS, SysMon, etc. |

### Rules (incoming)

The firewall has a **10-rule limit**.
ICMPv6 is always allowed and cannot be blocked, so we don't need a rule for it.
Most rules are mirrored for IPv4 and IPv6 to provide full dual-stack coverage.

| ID | Name               | Version | Protocol | Source IP   | Source Port | Dest Port   | TCP Flags | Action |
| -- | ------------------ | ------- | -------- | ----------- | ----------- | ----------- | --------- | ------ |
| #1 | vswitch            | ipv4    | *        | 10.0.0.0/24 |             |             |           | accept |
| #2 | tcp established    | ipv4    | tcp      |             |             | 32768-65535 | ack       | accept |
| #3 | tcp established-v6 | ipv6    | tcp      |             |             | 32768-65535 | ack       | accept |
| #4 | dns responses      | ipv4    | udp      |             | 53          | 32768-65535 |           | accept |
| #5 | well-known         | ipv4    | tcp      |             |             | 22-587      |           | accept |
| #6 | well-known-v6      | ipv6    | tcp      |             |             | 22-587      |           | accept |
| #7 | k8s-api            | ipv4    | tcp      |             |             | 6443        |           | accept |
| #8 | k8s-api-v6         | ipv6    | tcp      |             |             | 6443        |           | accept |
| #9 | nodeports          | *       | *        |             |             | 30000-32767 |           | accept |

Rule #10 is available for future use.
Cilium Host Policies (Layer 2) handle fine-grained filtering within these ranges.

### Rules (outgoing)

| ID | Name      | Version | Protocol | Source IP | Dest IP | Source Port | Dest Port | TCP Flags | Action |
| -- | --------- | ------- | -------- | --------- | ------- | ----------- | --------- | --------- | ------ |
| #1 | allow all | *       | *        |           |         |             |           |           | accept |

### Rule Explanations

**Rule #1 (vswitch)** is the most critical rule for cluster operation.
It allows all traffic from the private vSwitch network, enabling Kubernetes API communication between nodes, etcd cluster synchronization, Cilium's pod networking, and kubelet communication.
Without this rule, your cluster cannot function.

**Rules #2-3 (tcp established)** handle return traffic for outbound TCP connections.
When your server connects to external services (container registries, package repositories, APIs), the responses arrive as packets with the `ACK` flag set.
These rules allow those responses on ephemeral ports (`32768-65535`) for both IPv4 and IPv6.

**Rule #4 (dns responses)** permits DNS reply packets.
DNS queries go out on a random high port, and responses come back from port `53`.
This rule ensures those responses reach your server.

**Rules #5-6 (well-known)** cover SSH (`22`), SMTP (`25`), HTTP (`80`), HTTPS (`443`), and SMTP-submission (`587`) for both IPv4 and IPv6.
This opens some unused ports (`23-24`, `26-79`, `81-442`, `444-586`), but Cilium Host Policies block those at Layer 2.

**Rules #7-8 (k8s-api)** open port `6443` for Kubernetes API access over both IPv4 and IPv6.
This allows `kubectl` commands and other API clients to reach your cluster from outside the vSwitch network.

**Rule #9 (nodeports)** opens the standard Kubernetes NodePort range (`30000-32767`) for both IPv4 and IPv6.
It uses wildcard version (`*`) and protocol (`*`) to cover both address families in a single rule.
PostgreSQL (`30432`), Redis (`30379`), and other services can use ports in this range.
Cilium Host Policies control which specific ports are accessible.

Tailscale is not listed because it uses NAT traversal with outbound connections.
Since we allow all outbound traffic, Tailscale works without an inbound rule.
ICMP is omitted to stay within the limit; you can still ping via the vSwitch since Rule #1 allows all traffic from that subnet.

### Applying the Rules

After entering all rules, click "Save" to apply them.
Changes typically propagate within 30-60 seconds.

## Verification

Test that the vSwitch connectivity works through the firewall by pinging another node over the private network:

```bash
$ ping -c 3 10.0.0.1
PING 10.0.0.1 (10.0.0.1) 56(84) bytes of data.
64 bytes from 10.0.0.1: icmp_seq=1 ttl=64 time=0.351 ms
64 bytes from 10.0.0.1: icmp_seq=2 ttl=64 time=0.182 ms
64 bytes from 10.0.0.1: icmp_seq=3 ttl=64 time=0.175 ms
```

This works because Rule #1 allows all traffic from the vSwitch subnet, including ICMP.
If pings fail, verify that Rule #1 has the correct source IP (`10.0.0.0/24`) and is set to `accept`.

External ping (from the public internet) will not work since we don't have an ICMP rule for public traffic.
This is intentional—ICMP is useful for diagnostics but not required for cluster operation.

## What's Next

The Hetzner firewall provides coarse filtering at Layer 1.
In Lesson 9, we'll configure Cilium Host Policies (Layer 2) to provide fine-grained port control, blocking the unused ports within the ranges we opened here.

With the network-level firewall configured, we're ready to install RKE2 in the next lesson.
