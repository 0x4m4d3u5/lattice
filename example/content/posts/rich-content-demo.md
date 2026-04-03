---
title: Rich Content Demo
date: 2026-04-01
description: Demonstrates shortcodes (callout, image, figure), data file rendering, and frontmatter array iteration in the example site.
tags:
  - demo
  - moonbit
author: Lattice Team
---

# Rich Content Demo

This post exercises lattice features that go beyond basic Markdown rendering: typed shortcodes with validated parameters, data file integration, and frontmatter-driven template rendering.

For the foundational feature tour, see [[typed-content-tour]]. For the template system itself, see [[template-composition]].

## Callout Shortcodes

Shortcodes are validated at parse time — unknown names and missing required parameters produce build errors, not runtime surprises.

### Note

{{< callout type="note" title="Structural validation" >}}Every shortcode parameter is typed. Passing a string where an integer is expected, or omitting a required key, fails the build with a diagnostic.{{< /callout >}}

### Warning

{{< callout type="warning" title="Breaking change" >}}The shortcode DSL is part of the template contract. Adding a new required parameter to an existing shortcode is a breaking change for any content file that uses it.{{< /callout >}}

### Tip

{{< callout type="tip" title="Authoring tip" >}}Use callouts sparingly. They work best for information that is genuinely exceptional relative to the surrounding prose.{{< /callout >}}

## Image and Figure Shortcodes

The `image` shortcode produces an `<img>` with typed parameters. The `figure` shortcode wraps the image with an optional caption and link.

### Plain Image

{{< image src="/static/img/lattice-architecture.png" alt="Lattice build pipeline diagram" width=800 >}}

### Figure with Caption

{{< figure src="/static/img/schema-validation.png" alt="Schema validation flow" caption="Figure 1: Frontmatter schema validation catches type mismatches at build time." >}}

## Data File Integration

The navigation header uses a data file (`data/nav.toml`) rendered via `{{#each data.nav.links}}`. Data files are TOML documents in `content/data/` exposed to all templates as `{{data.filename.key}}`.

This means site-wide configuration — navigation items, author metadata, feature flags — lives in typed data files rather than being hardcoded in templates. Changing the nav requires editing a TOML file, not a template.

## Cross-Collection Linking

The projects collection (see [[lattice]], [[ametrine]]) demonstrates schema-validated frontmatter with `Enum`, `Int(min,max)`, `Url`, and `Date(after)` constraints. Each project page is a separate collection with its own template, but wikilinks work across collections because the page index is built before any rendering begins.
