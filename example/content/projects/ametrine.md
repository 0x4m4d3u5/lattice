---
title: Ametrine
date: 2024-03-01
status: archived
priority: 3
homepage: https://github.com/kurisu/ametrine
description: Astro-based personal site and content engine. Succeeded by Lattice.
tags:
  - astro
  - typescript
---

# Ametrine

Ametrine was a personal publishing platform built on top of Astro. It handled blog posts, project pages, and tag navigation — the same feature set that Lattice now covers with structural guarantees.

## Why it was superseded

Astro's content layer is behavioral: schema validation runs at build time, but errors are runtime exceptions surfaced by Zod, not compile-time type failures. A typo in frontmatter produces a JavaScript error during the build, not a structured diagnostic with file path, line number, and a hint.

Ametrine worked, but it demonstrated the problem Lattice was built to solve: in a dynamically-typed content pipeline, you discover content errors by running the build, not by declaring a schema. The schema is documentation, not enforcement.

Lattice's type system is the direct response to Ametrine's behavioral validation model. Every structural guarantee in Lattice has a corresponding pain point from Ametrine as its motivation.
