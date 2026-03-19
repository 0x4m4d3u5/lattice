---
title: Template Composition
date: 2026-03-17
description: How the example site uses a base layout plus reusable partial templates.
tags:
  - demo
  - templates
author: Lattice Team
---

# Template Composition

The example templates are deliberately small:

- `base.html` defines the outer document shell
- `head.html`, `header.html`, and `footer.html` are reusable partials
- `page.html` extends the layout and includes `article.html`

That makes it easy to inspect both `{{layout: ...}}` and `{{include: ...}}` behavior in one place.

For more authoring-facing features, continue to [[typed-content-tour]]. For release-oriented content, see [[release-checkpoint]].
