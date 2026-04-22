<h1 align="center">lattice</h1>

<p align="center">
  <strong>A static site generator where structural violations are type errors, not runtime surprises.</strong>
</p>

<p align="center">
  <a href="https://www.moonbitlang.com/2026-scc">2026 MoonBit Software Synthesis Challenge</a> ·
  <a href="https://github.com/0x4m4d3u5/lattice">GitHub</a> ·
  <a href="docs/retrospective.md">Retrospective</a> ·
  <a href="docs/getting-started.md">Getting Started</a>
</p>

---

## The Problem With Existing SSGs

Every static site generator discovers content errors too late. Hugo renders pages with `page.title` as an empty string. Astro's content layer checks schemas at runtime. Wikilinks to deleted pages become silent 404s. A missing required field doesn't fail the build — it produces wrong output that someone has to catch by eye.

**lattice** makes content integrity a structural property of the build pipeline. Schema violations, broken wikilinks, type mismatches, and missing required fields are caught before a single HTML file is written. The render pipeline structurally cannot produce output from invalid input.

## How It Works

lattice uses a **two-pass build**:

1. **Pass 1 — Collect & Index.** Walk all markdown sources, compute slugs, parse frontmatter, validate schemas, and build a complete page index.
2. **Pass 2 — Validate & Render.** Resolve wikilinks against the full index, render markdown, apply templates, and emit HTML.

Because the page index is complete before rendering begins, forward references are deterministic and unresolved targets are hard errors. The HTML renderer receives pre-validated data — it cannot produce broken links or missing-field output.

### Structural Guarantees

These are build-time failures in lattice:

| Violation | What happens |
|-----------|-------------|
| Missing required frontmatter field | `ValidationError` — render never runs |
| Frontmatter type mismatch (e.g., string where int expected) | `SchemaError` — render never runs |
| Broken wikilink `[[target]]` to non-existent page | `BrokenWikilink` diagnostic at exact file:line:col |
| Collection schema constraint violated (bounds, enum, URL format) | Precise diagnostic with constraint and rejected value |
| Duplicate slug between collections/standalone/root | `DuplicateSlug` — only one page claims the URL |
| Invalid template slot name | `TemplateSlotError` before any rendering |
| Data file missing required field | `DataError` — template never receives incomplete data |

The schema language supports domain constraints as type parameters:

```
schema = title:String(minlen=5,maxlen=80),
         date:Date(after=2020-01-01),
         status:Enum["active","archived","planned"],
         priority:Int(min=1,max=5),
         homepage:Url,
         tags:Optional[Array[String]]
```

A project with `priority: 0` or `status: completed` fails at validation — not at render time, not at reader time.

## Quick Start

### Build from source

```bash
moon build
```

### Build the example site

```bash
moon run cmd/main -- build ./example/content --config ./example/site.cfg
```

### Check content without rendering

```bash
moon run cmd/main -- check ./example/content --config ./example/site.cfg
```

### Start the dev server

```bash
moon run cmd/main -- serve ./example/content --config ./example/site.cfg
```

### Scaffold a new site

```bash
moon run cmd/main -- init my-site
cd my-site
moon run cmd/main -- build content dist --config content/lattice.conf
```

### Create a new post from the collection schema

```bash
moon run cmd/main -- new posts my-first-post --config content/lattice.conf
# Generates content/posts/my-first-post.md with correct frontmatter stubs
```

## CLI Reference

```
lattice build   [content-dir] [-o <dir>] [options]   — build the site
lattice check   [content-dir] [-o <dir>] [options]   — validate/lint only (no output)
lattice serve   [content-dir] [-o <dir>] [options]   — dev server with live reload
lattice init    <name>                                — scaffold a new site
lattice new     <collection> --name <slug> [options]  — create content from schema
lattice stats   [content-dir] [options]               — print site statistics
lattice explain <code>                                — describe an error code (e.g. E001)
```

| Flag | Description |
|------|-------------|
| `-c, --config <path>` | Override site config file |
| `--collections <path>` | Override collections config file |
| `--drafts` | Include draft posts |
| `--watch` | Rebuild on file changes (polling) |
| `--watch-interval <ms>` | Polling interval (default: 500) |
| `--force` | Ignore incremental cache, rebuild everything |
| `-p, --port <N>` | HTTP port for dev server (default: 4321) |
| `-o <dir>` | Output directory |

Defaults: `content-dir` → `./content`, config → `<content-dir>/lattice.conf`, output → config `output_dir` or `./dist`.

## Architecture

```
                    ┌─────────────────────────────────────────────┐
                    │             lattice build pipeline           │
                    └─────────────────────────────────────────────┘
                                        │
                   ┌────────────────────┼────────────────────┐
                   ▼                    ▼                    ▼
            ┌─────────────┐    ┌──────────────┐    ┌──────────────┐
            │   Pass 1     │    │  Pass 1.5    │    │   Pass 2     │
            │  Collect &   │───▶│  Validate &  │───▶│  Render &    │
            │   Index      │    │  Resolve     │    │  Emit        │
            └─────────────┘    └──────────────┘    └──────────────┘
            • Walk sources       • Schema check       • Markdown → HTML
            • Parse frontmatter  • Wikilink resolve    • Template apply
            • Compute slugs      • Shortcode validate  • Write output
            • Build page index   • Backlink index      • Sitemap/RSS/robots
```

### Module overview (`src/` — 30 packages)

| Module | Responsibility |
|--------|---------------|
| `builder` | Two-pass build orchestration, file I/O, site-index generation |
| `frontmatter` | Frontmatter parser → typed `FrontmatterValue` ADT tree |
| `schema` | Schema ADTs and frontmatter validation with domain constraints |
| `wikilink` | `[[target]]` extraction and resolution against page index |
| `markdown` | Markdown parser/renderer with diagnostics |
| `template` | Template slot parser/renderer with typed slot and data-path checks |
| `html` | HTML document emitters from typed metadata |
| `collections` | Parser for typed collection and data-schema definitions |
| `config` | Site config parser with typed parse/validation errors |
| `data` | Typed data-file loader and schema validation |
| `shortcode` | Shortcode parsing/rendering with typed params/errors |
| `lint` | Typed violation model (`ViolationType` enum) and formatting |
| `tags` | Tag extraction, automatic tag index and per-tag page generation |
| `rss` | Atom feed rendering from typed page graph |
| `sitemap` | Sitemap XML rendering |
| `robots` | robots.txt generation |
| `search` | JSON search index rendering |
| `highlight` | Syntax tokenization for fenced code blocks |
| `scaffold` | `lattice init` / `lattice new` — onboarding from schema |
| `slug` | Deterministic slug/path normalization |
| `pagination` | Typed pagination model for index pages |
| `diagnostic` | Shared diagnostic types (error, warning, info) |
| `cache` | Incremental build cache (hash-based change detection) |
| `manifest` | Build manifest for reproducible output verification |
| `graph` | Shared typed page graph structures for emitters |
| `assets` | Static file validation/copy |
| `serve` | Dev server with live reload (native backend) |
| `watch` | File-system polling watcher |
| `vault` | Obsidian vault import support |
| `strutil` | Shared string/char utilities (eliminates 15+ duplicate implementations) |

## Project Stats

- **~25k lines** of MoonBit in `src/` (42k total including tests)
- **31 packages** with focused responsibilities
- **764 tests**, all passing
- **240 commits** across 45 days of development
- **2 external dependencies**: [`moonbitlang/x`](https://github.com/moonbitlang/x) (filesystem, system) and [`TheWaWaR/clap`](https://github.com/TheWaWaR/clap) (CLI parsing)
- Builds cleanly with `moon build` (0 errors, 0 warnings)

## Example Site

The `example/` directory exercises the full feature set:

- **Two collections**: `posts` (blog with dates, tags, drafts) and `projects` (six domain-constrained types)
- **Standalone pages**: content outside any collection
- **Root page**: `index.md` as homepage at URL `/`
- **Custom 404**: `404.md` → `dist/404.html`
- **Template composition**: `base.html` → `head.html` + `header.html` + `footer.html` → `page.html`
- **Wikilinks**: cross-page references validated against the full index
- **Syntax highlighting**: fenced code blocks with token classification
- **Data files**: TOML data loaded into templates via `{{data.nav.title}}` slots
- **Pagination**: collection index pages with configurable page size
- **Tags**: automatic tag index at `/tags/` and per-tag pages at `/tags/<tag>/`
- **Feeds**: Atom feed at `feed.xml`
- **Search index**: `search-index.json` for client-side search
- **Sitemap**: `sitemap.xml` with all page URLs
- **Robots**: `robots.txt` with sitemap reference

Build it:

```bash
moon run cmd/main -- build ./example/content --config ./example/site.cfg
```

## Content Format

### Frontmatter

Fenced with `---`, using key-value assignments:

```markdown
---
title = My First Post
date = 2024-01-15
tags = [intro, lattice, demo]
draft = false
---

# Hello World

Content goes here. Wikilinks like [[my-other-post]] are validated at build time.
```

### Schema Declaration

Schemas define the structural contract for a collection:

```
[posts]
schema = title:String, date:Date, tags:Optional[Array[String]], draft:Optional[Bool]
dir = content/posts
```

Available field types:
- `String(minlen=N, maxlen=N)` — bounded string
- `Int(min=N, max=N)` — bounded integer
- `Float(min=N, max=N)` — bounded float
- `Date(after=YYYY-MM-DD, before=YYYY-MM-DD)` — bounded date
- `DateTime` — ISO 8601 datetime
- `Bool` — boolean
- `Enum["a", "b", "c"]` — categorical constraint
- `Url` — URL format validation
- `Array[T]` — homogeneous array
- `Optional[T]` — optional field
- `TRef` — cross-reference to another collection entry

### Templates

HTML templates use `{{slot_name}}` syntax with conditional blocks:

```html
<article>
  <h2>{{title}}</h2>
  <time>{{date}}</time>
  {{content}}
  {{?tags}}
  <div class="tags">
    {{tags}}
  </div>
  {{/?tags}}
</article>
```

Built-in slots: `title`, `content`, `date`, `description`, `url`, `site_name`, `nav_links`, `custom_css`, `tag_name`, `tag_count`, and `data.*` paths for TOML data files.

## Why MoonBit

MoonBit's type system is the right tool for this thesis:

- **ADTs make violations classifiable.** `ViolationType` is a closed sum type — every failure mode has a name. No "other" bucket, no stringly-typed errors.
- **Typed frontmatter trees.** `FrontmatterValue` is an enum (`FStr`, `FDate`, `FInt`, `FBool`, `FArray`, `FMap`), not a raw string map. Schema validation converts this tree into typed data before rendering.
- **Error types as API boundaries.** Each module exposes typed error sub-errors (`CacheError`, `ConfigError`, `CollectionsError`, `ShortcodeError`) — callers can't accidentally ignore error categories.
- **Expression-oriented control flow.** Two-pass build logic is natural with MoonBit's `match` and `loop` expressions.

## Documentation

| Document | Content |
|----------|---------|
| [Getting Started](docs/getting-started.md) | Walkthrough of a minimal lattice site |
| [Collections](docs/collections.md) | Collection and schema configuration |
| [Schema Syntax](docs/schema-syntax.md) | Field types, constraints, and validation |
| [Templates](docs/templates.md) | Template slots, conditionals, and composition |
| [Tags](docs/tags.md) | Tag extraction and tag index generation |
| [Feeds](docs/feeds.md) | Atom/RSS feed configuration |
| [Vault Workflows](docs/vault-workflows.md) | Obsidian vault import support |
| [Retrospective](docs/retrospective.md) | Architectural decisions and AI tool usage (explainability rubric) |

## Challenge Alignment

Built for the [2026 MoonBit Software Synthesis Challenge](https://www.moonbitlang.com/2026-scc):

- **Functional completeness (25%)**: Full SSG pipeline — parse → validate → render → emit. Collections, wikilinks, templates, feeds, search, sitemap, dev server, incremental builds, scaffolding, stats.
- **Engineering quality (25%)**: MoonBit's type system does real work. 30 packages with typed error boundaries. `FrontmatterValue` ADT, `ViolationType` closed enum, schema validation as a structural gate.
- **Explainability (25%)**: [2100-line retrospective](docs/retrospective.md) documenting every architectural decision. Commit history traces *why* the code looks the way it does. AI tool usage annotated honestly.
- **UX (25%)**: Error messages include file:line:column. `lattice check` for CI pipelines. `lattice new` generates schema-compliant stubs. `lattice stats` for site metrics. `lattice explain <E-code>` for error code documentation. Clear CLI with subcommands.

## License

Apache-2.0
