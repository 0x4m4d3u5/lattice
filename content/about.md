---
title = "About Lattice"
date = "2026-03-08"
description = "Design decisions and motivation behind the lattice SSG."
tags = ["lattice", "design", "moonbit"]
---
# About Lattice

Lattice is a MoonBit project for the **Software Craftsmanship Competition 2026**.

## Why MoonBit

MoonBit is a statically typed, functional-first language that compiles to native code
and WebAssembly. Its type system makes the central guarantee here — *structural violations
are type errors* — natural to express.

The `declare` keyword in MoonBit 0.8 is a notable example: you can declare an interface
that the compiler enforces must be implemented. The obligation is structural, not behavioral.

## Why a static site generator

The domain is familiar (most developers have used one) but the structural-integrity angle
is underexplored. Existing SSGs treat broken wikilinks and invalid frontmatter as warnings,
or worse, silently produce malformed output.

Lattice treats them as the build errors they are.

## Architecture

```
src/frontmatter/   — TOML-style key-value frontmatter parser
src/schema/        — FieldType ADT + typed validation
src/wikilink/      — wikilink extraction and resolution
src/markdown/      — recursive-descent inline + block parser
src/html/          — HTML5 page emitter
src/slug/          — filename → URL slug (pure, total function)
src/builder/       — file I/O layer + two-pass build orchestration
cmd/main/          — CLI entry point
```

Return to [[index]] to see the full build pipeline demonstrated.
