# Writing Style Guide

This is the single source of truth for the writing style used in this guide.
Refer to it when rewriting or creating lessons.

## Core Principle: Knowledge-First Writing

Explain before instructing.
Every lesson builds understanding first and guides the reader through implementation second.
The reader should walk away knowing _why_ something works, not just _how_ to type the commands.

Write in prose paragraphs — not bullet-point checklists — so that ideas develop naturally across sentences.
Each paragraph should focus on one idea, with sentences building on each other.
Keep paragraphs to 3–5 sentences so they remain approachable on a screen.

Bullet lists are acceptable inside table cells, for short enumerations of 3–5 items where prose would be awkward, and nowhere else as the primary content of a section.

## Lesson Layout

### Frontmatter

Every lesson begins with YAML frontmatter.
The fields that matter most for writing quality are `guide_lesson_abstract` and `guide_lesson_conclusion`.

`guide_lesson_abstract` is a two-to-three sentence summary of what the lesson covers and why it matters.
Write it as a standalone paragraph — it appears in navigation and section overviews, so it must make sense without the surrounding lesson.

`guide_lesson_conclusion` is a single sentence that captures what the reader accomplished.
Frame it as a result, not a summary: "Our RKE2 cluster now has a working CNI with dual-stack networking" rather than "We covered Canal CNI installation and dual-stack configuration."

### Opening Paragraph

The lesson body starts with a brief contextual paragraph placed directly after the frontmatter — no heading above it.
This paragraph connects to previous lessons and frames what the current lesson accomplishes:

```markdown
---
(frontmatter)
---

Before installing RKE2, we need to configure firewall rules that allow cluster components to communicate.
This lesson covers the first layer of our three-layer security model: the Hetzner network firewall.

{% include guide-overview-link.liquid.html %}
```

The overview link include goes immediately after the opening paragraph, before any `##` heading.

### Section Menu

Lessons draw from these sections as needed — not every lesson uses all of them:

- **Understanding / Concepts** (`##`) — Explain what the reader needs to know before acting. Use subsections (`###`) for individual concepts.
- **Planning / Architecture** (`##`) — Document decisions, CIDR allocations, or design choices. Use tables for structured reference data.
- **Implementation** (`##`) — Commands grouped by logical operation, with comments in code blocks and expected output.
- **Verification** (`##`) — Consolidated tests that confirm everything works, with prose explaining what each result means.

A strategy lesson like Lesson 1 has no implementation section.
A decommissioning lesson like Lesson 14 has almost no concepts section.
Use the sections that fit the content.

### Heading Depth

Use `##` for major sections and `###` for subsections.
Go to `####` only when a subsection genuinely needs further breakdown — for example, individual rules inside a planning section.

## Sentence Formatting

Each sentence starts on its own line.
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

### Backticks

Use backticks for anything the reader would type, see in output, or reference as a technical identifier:

- Port numbers and ranges: `22`, `443`, `6443`, `30000-32767`
- Commands and binaries: `ip addr show`, `kubectl`, `nmcli`
- CIDR ranges and IP addresses: `10.1.0.0/16`, `fd00::/64`
- Configuration values and enum-like names: `PreferDualStack`, `RestrictedPSS`
- File paths: `/etc/rancher/rke2/config.yaml`
- Interface names: `enp195s0`, `enp195s0.4000`
- Protocol flags and output states: `ACK`, `SYN`, `closed`, `filtered`

Do not use backticks for general technical concepts used as regular English words:

```markdown
<!-- Correct -->

The firewall is stateless, meaning it evaluates each packet independently.
Kubernetes needs forwarding enabled so that pod traffic can flow between nodes.

<!-- Wrong -->

The `firewall` is `stateless`, meaning it evaluates each `packet` independently.
```

The rule: if the reader would type it into a terminal, paste it into a config file, or see it literally in program output, use backticks.
If it is an English word describing a concept — even a technical one — leave it unformatted.

### Bold

Use bold sparingly for genuinely critical points the reader must not miss:

```markdown
<!-- Correct: a non-obvious gotcha -->

A critical point that's easy to overlook: **vSwitch traffic passes through Hetzner's firewall**.

<!-- Correct: labeling a rule -->

**Rule #1 (vswitch)** is the most critical rule for cluster operation.

<!-- Wrong: bold on routine information -->

**The firewall** is configured through the **Hetzner Robot** interface.
```

### Links

Use descriptive text that reads naturally in the sentence:

```markdown
<!-- Correct -->

[Canal](https://docs.rke2.io/networking/basic_network_options) is the default CNI for RKE2.

<!-- Wrong -->

Click [here](https://docs.rke2.io/networking/basic_network_options) to learn about Canal.
```

### Em-Dashes

Use em-dashes ( — ) with a space on each side for parenthetical clauses:

```markdown
<!-- Correct -->

The node network consists of the actual IP addresses assigned to your machines — in our case, the vSwitch addresses we configure in this lesson.

<!-- Wrong: no spaces -->

The node network consists of the actual IP addresses assigned to your machines—in our case, the vSwitch addresses we configure in this lesson.
```

Use em-dashes or "and" instead of semicolons.

## Code Blocks

### Shell Commands

Use the `bash` language tag and a `$` prefix for commands the reader should type.
Show expected output directly below without a prefix:

````markdown
```bash
$ ping -c 3 10.1.0.1
64 bytes from 10.1.0.1: icmp_seq=1 ttl=64 time=0.351 ms
...
3 packets transmitted, 3 received, 0% packet loss
```
````

### Comments in Code Blocks

Place comments above the command to explain what to customize:

````markdown
```bash
# Replace enp195s0 with your actual interface name
# Replace 4000 with your VLAN ID
$ sudo nmcli connection add \
    type vlan \
    con-name vswitch \
    dev enp195s0 \
    id 4000
```
````

### Configuration Files

Use the `yaml` (or appropriate) language tag.
Place a comment on the first line showing the file path:

````markdown
```yaml
# /etc/rancher/rke2/config.yaml
node-name: node-2
server: https://10.1.0.1:9345
token: <your-token>
```
````

### Post-Code Prose

After a code block, add a sentence explaining what to look for or what the output means:

```markdown
You should see both an `inet` line with your IPv4 address and an `inet6` line with your IPv6 ULA address.
If either is missing, check the nmcli command for typos before proceeding.
```

### Language Tags

Use `bash` for shell commands and their output, `yaml` for YAML configuration, `text` for generic output that is not shell-specific, and the appropriate language tag for anything else.
Never leave a code block without a language tag.

## Alerts and Callouts

Use the Liquid alert include for information that stands apart from the main prose:

```markdown
{% include alert.liquid.html type='warning' title='etcd Quorum with 2 Nodes' content='
During the transition period the cluster runs with only two control-plane nodes.
If either node fails, the cluster loses quorum and becomes read-only.
' %}
```

Choose the type based on severity:

| Type      | Purpose                                                                 |
| --------- | ----------------------------------------------------------------------- |
| `tip`     | Useful but non-essential — a shortcut, alternative approach, or insight |
| `info`    | Context that helps the reader understand but is not critical            |
| `note`    | Important context the reader should be aware of                         |
| `warning` | Risk of data loss, downtime, or an irreversible action                  |

Keep alert content to one or two sentences.
If the explanation needs more space, it belongs in the prose body, not inside an alert.

## Tables

Use tables for structured reference data, comparisons, and configuration values.
Never use a table as a substitute for prose explanation.

```markdown
| Network      | IPv4 CIDR      | IPv6 CIDR      | Purpose                  |
| ------------ | -------------- | -------------- | ------------------------ |
| Node Network | `10.1.0.0/16`  | `fd00::/64`    | vSwitch inter-node comms |
| Pod Network  | `10.42.0.0/16` | `fd00:42::/56` | IP addresses for pods    |
```

Follow a table with prose that interprets or contextualizes the data when the meaning is not self-evident.

## Diagrams

Use Mermaid diagrams for architecture, network topology, and migration phases.
Include consistent class definitions for styling.
Follow each diagram with a prose paragraph explaining what it shows:

```markdown
The diagram illustrates how these networks interact: each node receives a subnet from the pod CIDR (Node 1 uses `10.42.0.x` while Node 2 uses `10.42.1.x`) and the CNI plugin assigns individual pod addresses from that per-node range.
```

## Multi-Node Operations

Many lessons repeat an operation across several nodes.
Show the full command sequence for the first node, then provide a condensed version for subsequent nodes that highlights only what changes — typically the node name, IP address, or config values.
Use a table to summarize per-node differences when there are more than two nodes.

## Cross-References

Reference other lessons naturally within prose:

```markdown
<!-- Correct -->

We configure Calico Network Policies in Lesson 9 to close this gap.

<!-- Wrong: parenthetical -->

We configure Calico Network Policies (see Lesson 9) to close this gap.
```

## Transitions

Bridge sections with a sentence that connects what was just covered to what comes next:

```markdown
With the planning complete, we can now configure the actual network interface.
```

Do not use filler transitions like "Let's move on to..." or "Now that we've covered...".

## Tone and Voice

Write as a knowledgeable colleague explaining their setup — direct, authoritative, and honest about trade-offs.

Use "we" in lesson content to include the reader as a collaborator: "we'll configure", "our cluster", "we need to".
The guide introduction and index page use author voice ("I") where personal motivation is relevant.
Do not mix "I" and "we" within the same lesson.

Avoid filler words: "So,", "Basically,", "In order to", "It's worth noting that".
Do not hedge when certain: write "this is" not "this might be".
No exclamation marks.

Vary sentence structure and length across paragraphs.
If three consecutive sentences start the same way, rewrite one of them.

## What to Avoid

- Bullet-point-heavy sections that read like a checklist
- Bold-header list patterns like `- **Header** - Description`
- Summary sections at the end of lessons — the frontmatter `guide_lesson_conclusion` handles this
- "In this lesson we will learn..." introductions
- Unnecessary warnings or disclaimers
- Convenience scripts that duplicate inline commands
- Verbose expected output — show only what the reader needs to verify success
- Duplicate explanations across lessons — reference the earlier lesson instead
