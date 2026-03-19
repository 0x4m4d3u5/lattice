---
title: Typed Content Tour
date: 2026-03-18
description: One post that exercises YAML frontmatter, code fences, footnotes, TOC output, tags, and internal links.
tags:
  - demo
  - moonbit
author: Lattice Team
---

# Typed Content Tour

This post is the main inspection target for the example site. It links to [[template-composition]] and [[release-checkpoint]] so the generated internal graph is easy to verify.[^graph]

## YAML Frontmatter

The frontmatter above uses YAML syntax rather than TOML syntax. That keeps the demo honest about mixed authoring styles.

## Syntax Highlighting

MoonBit fences should be highlighted:

```moonbit
fn build_site(title : String) -> String {
  "building " + title
}
```

TypeScript fences should be highlighted too:

```typescript
export function breadcrumb(label: string, href: string) {
  return { label, href }
}
```

## Table Of Contents

This document has enough heading depth for the `{{table_of_contents}}` slot in the page template to render a useful outline.

### Structural Metadata

`title`, `date`, `description`, `tags`, and `author` flow into templates, feeds, and structured data.

### Cross-References

Wikilinks such as [[about]] and [[template-composition]] are resolved against the full site index.

## Footnotes

Footnotes render at the end of the page and backlink to the reference site of the citation.[^foot]

[^graph]: That helps the example demonstrate internal link validation instead of only isolated pages.
[^foot]: This note exists purely to prove the renderer emits the footnotes section.
