# Claude Code Instructions

This file contains instructions for LLM agents working on this codebase.

## Writing Style for Guides and Documentation

### Sentence Formatting

- Each sentence must start on a new line
- This improves readability and makes diffs cleaner
- Do not wrap sentences across multiple lines

```markdown
<!-- Good -->

This is the first sentence.
This is the second sentence that provides more detail.

<!-- Bad -->

This is the first sentence. This is the second sentence
that wraps to a new line mid-sentence.
```

### List Formatting

- Use simple one-liner sentences for bullet points
- Avoid bold header patterns like `- **Header** - Description`
- Keep list items concise and direct

```markdown
<!-- Good -->

- Maintain zero downtime while keeping services available
- Change the underlying distribution from k3s to RKE2

<!-- Bad -->

- **Maintain zero downtime** - Your services must remain available throughout
- **Change the underlying distribution** - Moving from k3s to RKE2
```

### Language and Tone

- Remove filler words like "So,", "e.g.", "i.e." where possible
- Use "and" instead of semicolons for smoother reading
- Write naturally, avoid LLM-generated repetitive patterns
- Be direct and concise

### Content Organization

- Cross-link between documents instead of duplicating content
- Keep index files compact and focused
- Move detailed content to appropriate lessons/sections
- Delete redundant lessons rather than keeping repetitive content

### Diagrams

- Use mermaid diagrams instead of ASCII art
- Keep diagram styling consistent across the guide
- Include proper class definitions for colors and styles

## Lesson Structure

Write lessons in book-style rather than tutorial-style.
Build knowledge first, then guide through implementation.

### Recommended Section Order

1. **Understanding/Concepts** - Explain what and why before how
2. **Planning/Configuration** - Document decisions and options
3. **Implementation** - Step-by-step commands grouped logically
4. **Verification** - Consolidated checks and tests
5. **Troubleshooting** - Common issues and solutions

### Knowledge Building

Start each lesson by explaining concepts the reader needs to understand.
Use tables to compare options or list components.
Explain technical terms when first introduced.

```markdown
<!-- Good -->

## Understanding Cilium

### What is eBPF?

eBPF is a technology that allows running sandboxed programs inside the Linux kernel.
[Explanation continues...]

### Why eBPF for Networking?

Traditional Kubernetes networking uses iptables...
[Comparison and reasoning...]

## Installing Cilium

[Commands come after understanding is established]
```

```markdown
<!-- Bad -->

## Install Helm

curl https://... | bash

## Add Repository

helm repo add ...

[Jumping straight to commands without context]
```

### Consolidate Related Content

Group related steps together rather than creating many small sections.

````markdown
<!-- Good -->

## Configuring the Firewall

### Open Required Ports

```bash
firewall-cmd --add-port=6443/tcp
firewall-cmd --add-port=2379/tcp
firewall-cmd --add-port=2380/tcp
```
````

<!-- Bad - too many tiny sections -->

## Open API Server Port

```bash
firewall-cmd --add-port=6443/tcp
```

## Open etcd Client Port

```bash
firewall-cmd --add-port=2379/tcp
```

## Open etcd Peer Port

```bash
firewall-cmd --add-port=2380/tcp
```

````
### What to Avoid

- **Summary sections** - The conclusion in frontmatter serves this purpose
- **Multiple options** - Pick one approach unless alternatives are truly necessary
- **Redundant scripts** - Don't create "convenience scripts" that duplicate inline commands
- **Verbose expected output** - Show only what's needed to verify success
- **Duplicate explanations** - Reference earlier lessons instead of repeating

### Tables for Reference

Use tables for configuration options, components, or comparisons:

```markdown
| Option        | Value      | Purpose                    |
| ------------- | ---------- | -------------------------- |
| `cluster-cidr`| 10.42.0.0/16 | Pod network CIDR         |
| `service-cidr`| 10.43.0.0/16 | Service network CIDR     |
````

## Technical Guidelines

- Check the Makefile for existing commands before creating new ones
- Follow existing patterns in the codebase
- Test changes locally before committing
