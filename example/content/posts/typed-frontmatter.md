---
title = Typed Frontmatter in Practice
date = "2024-01-18"
tags = [types, schema, moonbit]
---
# Typed Frontmatter

Frontmatter is validated before rendering, so missing required keys fail fast. That means fields like `title` and `date` are enforced as structural contracts instead of conventions. The follow-up on link integrity is in [[wikilink-graph]], and the implementation details live in [[lattice-core]].
