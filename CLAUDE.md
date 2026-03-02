# Claude Code Instructions

This file contains instructions for LLM agents working on this codebase.

## Writing Style for Guides

Read this section before writing or rewriting any lesson content.

### Core Principle: Knowledge-First Writing

Explain before instructing.
Every lesson builds understanding first and guides the reader through implementation second.
The reader should walk away knowing _why_ something works, not just _how_ to type the commands.

Write in prose paragraphs — not bullet-point checklists — so that ideas develop naturally across sentences.
Each paragraph should focus on one idea, with sentences building on each other.
Keep paragraphs to 3–5 sentences so they remain approachable on a screen.
Merge short 1–2 sentence paragraphs into fuller ones by connecting related ideas under a shared theme.

Bullet lists are acceptable inside table cells, for short enumerations of 3–5 items where prose would be awkward, and nowhere else as the primary content of a section.

### Lesson Layout

#### Frontmatter

Every lesson begins with YAML frontmatter.
The fields that matter most for writing quality are `guide_lesson_abstract` and `guide_lesson_conclusion`.

`guide_lesson_abstract` is a two-to-three sentence summary of what the lesson covers and why it matters.
Write it as a standalone paragraph — it appears in navigation and section overviews, so it must make sense without the surrounding lesson.

`guide_lesson_conclusion` is a single sentence that captures what the reader accomplished.
Frame it as a result, not a summary: "Our RKE2 cluster now has a working CNI with dual-stack networking" rather than "We covered Canal CNI installation and dual-stack configuration."

#### Opening Paragraph

The lesson body starts with a brief contextual paragraph placed directly after the frontmatter — no heading above it.
This paragraph connects to previous lessons and frames what the current lesson accomplishes.
The overview link include (`{% include guide-overview-link.liquid.html %}`) goes immediately after the opening paragraph, before any `##` heading.

#### Section Menu

Lessons draw from these sections as needed — not every lesson uses all of them:

- **Understanding / Concepts** (`##`) — Explain what the reader needs to know before acting. Use subsections (`###`) for individual concepts.
- **Planning / Architecture** (`##`) — Document decisions, CIDR allocations, or design choices. Use tables for structured reference data.
- **Implementation** (`##`) — Commands grouped by logical operation, with comments in code blocks and expected output.
- **Verification** (`##`) — Consolidated tests that confirm everything works, with prose explaining what each result means.

Use the sections that fit the content.

#### Heading Depth

Use `##` for major sections and `###` for subsections.
Go to `####` only when a subsection genuinely needs further breakdown.

### Sentence Formatting

Each sentence starts on its own line.
This keeps diffs clean and makes individual sentences easy to edit.

### Inline Formatting

Use backticks for anything the reader would type, see in output, or reference as a technical identifier:
port numbers, commands, CIDR ranges, IP addresses, config values, file paths, interface names, protocol flags.

Do not use backticks for general technical concepts used as regular English words.
The rule: if the reader would type it into a terminal, paste it into a config file, or see it literally in program output, use backticks.
If it is an English word describing a concept — even a technical one — leave it unformatted.

Use bold sparingly for genuinely critical points the reader must not miss.

Use descriptive link text that reads naturally in the sentence — never "click here."

Do not use em-dashes. Use commas, parentheses, or "and" instead.

### Code Blocks

- Use the `bash` language tag and a `$` prefix for commands the reader should type
- Show expected output directly below without a prefix
- Place comments above the command to explain what to customize
- For config files, use the `yaml` (or appropriate) tag and place a comment on the first line showing the file path
- After a code block, add a sentence explaining what to look for or what the output means
- Never leave a code block without a language tag

### Alerts and Callouts

Use the Liquid alert include for information that stands apart from the main prose.
Choose the type based on severity: `tip`, `info`, `note`, `warning`.
Keep alert content to one or two sentences.

### Tables

Use tables for structured reference data, comparisons, and configuration values.
Never use a table as a substitute for prose explanation.
Follow a table with prose that interprets or contextualizes the data when the meaning is not self-evident.

### Diagrams

Use Mermaid diagrams for architecture, network topology, and migration phases.
Follow each diagram with a prose paragraph explaining what it shows.

### Multi-Node Operations

Show the full command sequence for the first node, then provide a condensed version for subsequent nodes that highlights only what changes.
Use a table to summarize per-node differences when there are more than two nodes.

### Cross-References

Reference other lessons naturally within prose: "We configure Calico Network Policies in Lesson 9 to close this gap."
Do not use parenthetical references like "(see Lesson 9)."
Cross-link between documents instead of duplicating content.
Always verify that lesson numbers and section anchors in cross-references are correct.

### Transitions

Bridge sections with a sentence that connects what was just covered to what comes next.
Do not use filler transitions like "Let's move on to..." or "Now that we've covered...".

### Tone and Voice

Write as a knowledgeable colleague explaining their setup — direct, authoritative, and honest about trade-offs.

Use "we" in lesson content to include the reader as a collaborator.
The guide introduction and index page use author voice ("I") where personal motivation is relevant.
Do not mix "I" and "we" within the same lesson.

Avoid filler words: "So,", "Basically,", "In order to", "It's worth noting that".
Do not hedge when certain: write "this is" not "this might be".
No exclamation marks.

Vary sentence structure and length across paragraphs.
If three consecutive sentences start the same way, rewrite one of them.

### What to Avoid

- Bullet-point-heavy sections that read like a checklist
- Bold-header list patterns like `- **Header** - Description`
- Summary sections at the end of lessons — the frontmatter `guide_lesson_conclusion` handles this
- "In this lesson we will learn..." introductions
- Unnecessary warnings or disclaimers
- Convenience scripts that duplicate inline commands
- Verbose expected output — show only what the reader needs to verify success
- Duplicate explanations across lessons, reference the earlier lesson instead
- Reference tables (config options, file locations, CIDRs) that duplicate what appears in implementation sections below
- Generic Kubernetes knowledge in Understanding sections, focus on migration-specific context and comparisons with k3s

## Technical Guidelines

- Check the Makefile for existing commands before creating new ones
- Follow existing patterns in the codebase
- Test changes locally before committing

## Build Commands

| Command         | Description                                     |
| --------------- | ----------------------------------------------- |
| `make install`  | Install Ruby gem dependencies                   |
| `make build`    | Build the Jekyll site                           |
| `make serve`    | Start local dev server at http://localhost:4000 |
| `make optimize` | Optimize images in `assets/images/`             |

## Deployment

- Site is deployed via **Netlify** (project: `philprime`, site ID: `3e01d389-76b3-4faf-982e-f0cfb4e2f810`)
- Build configuration lives in `netlify.toml` (repo-managed, not the UI)
- Use the **Netlify MCP** tools to check deploys, projects, and environment variables
- Fall back to the `netlify` CLI if MCP is unavailable

## Guide-Specific Patterns

- `HelmChartConfig` resources go in `/var/lib/rancher/rke2/server/manifests/` as `yaml` code blocks with a comment showing the file path
- Lesson 5/6 are the reference for `HelmChartConfig` resources
- Lesson 7 (Longhorn) is the reference for `HelmChart` resources
- Understanding sections should ground concepts in the Hetzner/migration context, comparing with k3s where relevant
