---
title: Lattice SSG
date: 2026-02-01
status: active
priority: 5
homepage: https://github.com/kurisu/lattice
description: A MoonBit static site generator where structural violations are type errors.
tags:
  - moonbit
  - tooling
---

# Lattice SSG

Lattice is a static site generator built with MoonBit for the 2026 MoonBit Software Synthesis Challenge. Its core thesis: content integrity is a structural property.

Broken wikilinks, schema mismatches, and missing required fields are build-time errors — not runtime surprises discovered by visitors.

## Key features

- Typed frontmatter schemas with domain-constraint type parameters (`Int(min=1,max=5)`, `Date(after=2020-01-01)`, `Enum["draft","published"]`)
- Wikilink resolution with a complete two-pass page index
- Cross-reference validation via `TRef` — a field type that validates slug existence at build time
- Syntax highlighting for 15 languages, hand-tokenized in pure MoonBit
- RSS feeds, sitemap, `search-index.json`, robots.txt, JSON-LD structured data
- Incremental builds via FNV-1a content fingerprinting
- Live-reload dev server via SSE

The structural guarantee: the render pipeline cannot produce output from invalid input. Every type in the schema DSL carries optional domain constraints. The build fails fast with actionable diagnostics.
