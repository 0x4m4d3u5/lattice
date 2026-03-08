---
title = "Welcome to Lattice"
date = "2026-03-08"
description = "A static site generator where structural violations are type errors."
tags = ["lattice", "moonbit", "ssg"]
---
# Welcome to Lattice

**Lattice** is a static site generator written in MoonBit. Its central claim:
*structural violations should be type errors, not runtime surprises.*

Most SSGs discover broken links and invalid content schemas at render time —
or worse, at deploy time when users hit a 404. Lattice catches them at build time.

## How it works

The build is deliberately two-pass:

1. **Collection pass**: every `.md` file in the content directory is loaded,
   its slug computed from the filename, and its entry added to the page index.
2. **Render pass**: each file runs through the full pipeline —
   frontmatter parsing → schema validation → wikilink resolution → markdown render → HTML emit.

The wikilink resolver runs in pass 2 against the *complete* page index from pass 1.
Every wikilink target is known before any HTML is written.

## Getting started

See [[about]] for more about the project.

## The structural guarantee

A schema violation is a build error:

```
[error] hello-world: schema: title: field required but missing
```

A broken wikilink is a build error:

```
[error] index: broken wikilink: target 'nonexistent' not found in page index
```

Neither reaches the output directory. The `dist/` folder only contains
structurally valid content.
