# lattice

`lattice` is a MoonBit static site generator built for the 2026 MoonBit Software Synthesis Challenge (SCC).

The project goal is structural integrity: content contract violations should fail the build, not appear later as runtime surprises.

## Core Thesis

Content integrity is treated as a structural property of the build pipeline:

- typed frontmatter schemas
- validated wikilinks against a full site index
- schema-enforced content collections and data files

In `lattice`, these are build-time failures:

- missing required frontmatter fields
- frontmatter type mismatches
- broken wikilink targets
- invalid template slots/data-slot paths
- collection and data-schema configuration errors

## Quick Start

Build the project:

```bash
moon build
```

Run with defaults (`./content` -> `./dist`, config at `./content/lattice.conf`):

```bash
moon run cmd/main
```

Run with explicit content/output directories:

```bash
moon run cmd/main -- ./content ./dist
```

Run with explicit config and collections files:

```bash
moon run cmd/main -- ./content ./dist --config ./example/site.cfg --collections ./example/collections.cfg
```

Run structural checks only (no output writes):

```bash
moon run cmd/main -- ./content ./dist --check
```

Run in polling watch mode for local development:

```bash
moon run cmd/main -- ./content ./dist --watch
```

Adjust the polling interval if needed:

```bash
moon run cmd/main -- ./content ./dist --watch --watch-interval 1000
```

### CLI flags

- `--config <path>`: override site config file (also supports `--config=<path>`)
- `--collections <path>`: override collections config file (also supports `--collections=<path>`)
- `--check`: run validation/lint pipeline only
- `--watch`: do an initial build, then poll source/config/template/data/static inputs and rebuild on change
- `--watch-interval <ms>`: override the polling interval in milliseconds (also supports `--watch-interval=<ms>`, default `500`)
- `--help`: print CLI usage

## Module Overview (`src/`)

- `assets`: static file validation/copy with typed copy errors.
- `builder`: two-pass orchestration (collect/index, then validate/render/emit).
- `collections`: parser for typed collection and data-schema definitions.
- `config`: site config parser with typed parse/validation errors.
- `data`: typed data-file loader and schema validation for template data slots.
- `frontmatter`: frontmatter parser to typed `FrontmatterValue` trees.
- `graph`: shared typed page graph structures for downstream emitters.
- `highlight`: syntax tokenization/highlighting for fenced code blocks.
- `html`: HTML document emitters from typed metadata.
- `lint`: typed violation model and formatting for check mode.
- `markdown`: markdown parser/renderer with diagnostics.
- `pagination`: typed pagination model for index-like pages.
- `rss`: Atom feed rendering from typed page graph input.
- `schema`: schema ADTs and frontmatter validation.
- `search`: JSON search index rendering.
- `shortcode`: shortcode parsing/rendering with typed params/errors.
- `sitemap`: sitemap XML rendering.
- `slug`: deterministic slug/path normalization helpers.
- `tags`: typed tag extraction from frontmatter with automatic tag index and per-tag page generation.
- `template`: template slot parser/renderer with typed slot and data-path checks.
- `wikilink`: wikilink extraction/resolution against page index.

## Example Site

The `example/` directory is a compact feature demo site:

- content: `example/content/`
- templates: `example/templates/`
- static assets: `example/content/static/`
- config: `example/site.cfg`
- notes: `example/README.md`

Run it with:

```bash
moon run cmd/main -- ./example/content ./example/dist --config ./example/site.cfg
```

For local preview, pair `--watch` with a static file server such as `simple-http-server`:

```bash
simple-http-server ./dist
```

## Build Instructions

From repo root:

```bash
moon build
```
