# Claude Code Instructions

This file contains instructions for LLM agents working on this codebase.

## Writing Style for Guides

The canonical style reference lives in each guide's `WRITING_STYLE.md`.
For the migration guide, that file is at `guides/migrating-k3s-to-rke2-without-downtime/WRITING_STYLE.md`.

Read it before writing or rewriting any lesson content.

The essential rules that apply across the entire project:

- Each sentence starts on its own line (clean diffs)
- Em-dashes ( — ) have a space on each side
- No bold-header list patterns like `- **Header** - Description`
- No filler words: "So,", "Basically,", "In order to"
- Use "and" instead of semicolons
- Use Mermaid diagrams instead of ASCII art
- Cross-link between documents instead of duplicating content

## Technical Guidelines

- Check the Makefile for existing commands before creating new ones
- Follow existing patterns in the codebase
- Test changes locally before committing
