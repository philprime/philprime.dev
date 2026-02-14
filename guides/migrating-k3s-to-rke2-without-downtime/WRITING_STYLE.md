# Writing Style Instructions

This document defines the writing style used in this guide.
Use it as a reference when rewriting or creating lessons.

## Core Principle: Book-Style Prose

Write each lesson as a chapter in a technical book, not as a tutorial blog post or README.
The reader should feel like they are reading a well-structured technical reference that builds understanding before asking them to do anything.

### What This Means in Practice

- Use full, flowing sentences organized into prose paragraphs.
- Avoid bullet-point lists as the primary content delivery mechanism.
- Each paragraph should develop a single idea, with sentences building on each other.
- Let the writing breathe: explain the "why" and "how" before the "do".

### When Bullet Lists Are Acceptable

- Inside tables (as cell content).
- Short enumeration of items where prose would be awkward (maximum 3-5 items).
- Never as the main body of a section.

## Sentence Formatting

Each sentence must start on its own line.
This keeps diffs clean and makes individual sentences easy to edit.

```markdown
<!-- Correct -->

Hetzner's vSwitch provides Layer 2 private networking between dedicated servers.
Unlike traffic over the public internet, communication through the vSwitch flows directly between servers at wire speed.

<!-- Wrong: multiple sentences on one line -->

Hetzner's vSwitch provides Layer 2 private networking between dedicated servers. Unlike traffic over the public internet, communication through the vSwitch flows directly between servers at wire speed.

<!-- Wrong: one sentence wrapped across lines -->

Hetzner's vSwitch provides Layer 2 private networking
between dedicated servers.
```

## Inline Formatting

### Backticks for Technical Identifiers

Use backticks for anything the reader would type, see in output, or reference as a technical identifier:

- Port numbers: `22`, `443`, `6443`
- Port ranges: `32768-65535`, `30000-32767`
- Commands and binaries: `ip addr show`, `nmcli`, `kubectl`, `nmap`
- CIDR ranges and IP addresses: `10.0.0.0/24`, `fd00::/64`, `135.181.x.x`
- Configuration values and enum-like names: `PreferDualStack`, `SingleStack`, `RequireDualStack`
- File and directory paths: `/etc/sysctl.d/99-ipv6-forward.conf`, `/proc/sys/net/ipv4/ip_local_port_range`
- Protocol flags and technical terms used as identifiers: `ACK`, `SYN`
- Interface names: `enp195s0`, `enp195s0.4000`
- States in output: `closed`, `filtered`, `open`

### When NOT to Use Backticks

Do not use backticks for general technical concepts used as regular English words:

```markdown
<!-- Correct -->

The firewall is stateless, meaning it evaluates each packet independently.
Kubernetes needs forwarding enabled so that pod traffic can flow between nodes.
Your choice of CNI directly impacts how well dual-stack works.

<!-- Wrong: backticks on general concepts -->

The `firewall` is `stateless`, meaning it evaluates each `packet` independently.
```

The rule: if it's something you would type into a terminal, paste into a config file, or see literally in program output, use backticks.
If it's an English word describing a concept, even a technical one, leave it unformatted.

### Bold for Emphasis

Use bold sparingly for genuinely critical points the reader must not miss:

```markdown
<!-- Correct: highlighting a non-obvious gotcha -->

A critical point that's easy to overlook: **vSwitch traffic passes through Hetzner's firewall**.

<!-- Correct: labeling rule explanations -->

**Rule #1 (vswitch)** is the most critical rule for cluster operation.

<!-- Wrong: using bold for routine information -->

**The firewall** is configured through the **Hetzner Robot** interface.
```

### Links

Use descriptive text that reads naturally in the sentence:

```markdown
<!-- Correct -->

[Cilium](https://cilium.io/) stands out with its eBPF-based architecture.
Navigate to the [Hetzner Robot](https://robot.hetzner.com/server) interface.

<!-- Wrong: generic link text -->

Click [here](https://cilium.io/) to learn about Cilium.
```

### Em-Dashes

Use em-dashes (—) for parenthetical clauses that add context or clarification:

```markdown
The node network consists of the actual IP addresses assigned to your machines—in our case, the vSwitch addresses we'll configure in this lesson.
The CIDR ranges you choose become part of certificates, etcd data, and running workloads, making them nearly impossible to change without rebuilding the entire cluster.
```

Do not use semicolons for this purpose. Use "and" or em-dashes instead.

## Section Structure

### Knowledge-First Ordering

Each lesson follows this structure:

1. **Opening paragraph** - One to two sentences stating what this lesson covers and why it matters. No heading, placed directly after the frontmatter.
2. **Understanding / Concepts** - Explain what the reader needs to know before acting. Use subsections to break down individual concepts.
3. **Planning / Architecture** - Document decisions, CIDR allocations, or design choices. Use tables for structured reference data.
4. **Implementation** - Step-by-step commands grouped by logical operation. Include comments in code blocks and show expected output.
5. **Verification** - Consolidated tests to confirm everything works. Explain what each result means.

### Opening Paragraph

The lesson starts with a brief contextual paragraph before any heading.
It connects to previous lessons and frames what this lesson accomplishes:

```markdown
---
(frontmatter)
---

Before installing RKE2, we need to configure firewall rules that allow cluster components to communicate.
This lesson covers the first layer of our three-layer security model: the Hetzner network firewall.
```

### Subsection Depth

Use `##` for major sections and `###` for subsections.
Avoid going deeper than `###` unless the content genuinely warrants it (like `####` for a specific sub-topic within a planning section).

## Tables

Use tables for structured reference data, comparisons, and configuration values.
Never use tables as a substitute for prose explanation.

```markdown
<!-- Correct: table for reference data -->

| Network      | IPv4 CIDR    | IPv6 CIDR    | Purpose                  |
| ------------ | ------------ | ------------ | ------------------------ |
| Node Network | 10.0.0.0/24  | fd00::/64    | vSwitch inter-node comms |
| Pod Network  | 10.42.0.0/16 | fd00:42::/56 | IP addresses for pods    |

<!-- Correct: table followed by prose explaining it -->

The diagram illustrates how these networks interact: each node receives a subnet from the pod CIDR.
```

Always follow a table with prose that interprets or contextualizes the data when the meaning isn't self-evident.

## Code Blocks

### Command Formatting

Use `$` prefix for commands the reader should type.
Show expected output directly below without a prefix:

````markdown
```bash
$ ping -c 3 10.0.0.1
64 bytes from 10.0.0.1: icmp_seq=1 ttl=64 time=0.351 ms
...
3 packets transmitted, 3 received, 0% packet loss
```
````

````
### Comments in Code Blocks

Place comments above the command to explain what to customize:

```markdown
```bash
# Replace enp195s0 with your actual interface name
# Replace 4000 with your VLAN ID
$ sudo nmcli connection add \
    type vlan \
    con-name vswitch \
    dev enp195s0 \
    id 4000
````

````
### Post-Code Prose

After a code block, add a sentence explaining what to look for or what the output means:

```markdown
You should see both an `inet` line with your IPv4 address and an `inet6` line with your IPv6 ULA address.
If either is missing, check the nmcli command for typos before proceeding.
````

## Diagrams

Use Mermaid diagrams for architecture and network topology.
Include consistent class definitions for styling.
Follow each diagram with a prose paragraph explaining what it shows:

```markdown
The diagram illustrates how these networks interact: each node receives a subnet from the pod CIDR (Node 1 uses 10.42.0.x while Node 2 uses 10.42.1.x), and the CNI plugin assigns individual pod addresses from that per-node range.
```

## Cross-References

Reference other lessons naturally within prose:

```markdown
<!-- Correct -->

We'll configure Cilium Host Policies in Lesson 9 to close this gap.
Since we're already building a new cluster to migrate from k3s to RKE2, this is the ideal time.

<!-- Wrong: parenthetical lesson references -->

We'll configure Cilium Host Policies (see Lesson 9) to close this gap.
```

## Transitions

Bridge sections with sentences that connect what was just covered to what comes next:

```markdown
With the planning complete, we can now configure the actual network interface.
```

```markdown
Before moving on to firewall configuration, verify that the vSwitch is working correctly.
```

## Tone

- Direct and authoritative, like a knowledgeable colleague explaining their setup.
- No filler words: avoid "So,", "Basically,", "In order to", "It's worth noting that".
- No hedging: say "this is" not "this might be" when you are certain.
- No exclamation marks.
- Use "we" to include the reader as a collaborator: "we'll configure", "our cluster", "we need to".
- Explain trade-offs honestly: "This is generally acceptable, but for defense in depth we'll add encryption."

## What to Avoid

- Bullet-point-heavy sections that read like a checklist.
- Bold-header list patterns like `- **Header** - Description`.
- Summary sections at the end (the frontmatter `guide_lesson_conclusion` handles this).
- "In this lesson we will learn..." introductions.
- Repetitive patterns across paragraphs (varying sentence structure and length).
- Unnecessary warnings or disclaimers.
- Filler transitions like "Let's move on to..." or "Now that we've covered...".
