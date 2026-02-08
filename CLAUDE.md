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

## Technical Guidelines

- Check the Makefile for existing commands before creating new ones
- Follow existing patterns in the codebase
- Test changes locally before committing
