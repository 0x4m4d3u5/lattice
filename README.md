<h1 align="center">lattice</h1>

<p align="center">
  <strong>A MoonBit static site generator with typed content models and runtime validation.</strong>
</p>

<p align="center">
  <a href="https://www.moonbitlang.com/2026-scc">2026 MoonBit Software Synthesis Challenge</a> ·
  <a href="https://github.com/0x4m4d3u5/lattice">GitHub</a> ·
  <a href="docs/retrospective.md">Retrospective</a> ·
  <a href="docs/getting-started.md">Getting Started</a>
</p>

---

For editorial reading paths, see [author-selected related notes](docs/related-notes.md).

## The Problem With Existing SSGs

Every static site generator discovers content errors too late. Hugo renders pages with `page.title` as an empty string. Astro's content layer checks schemas at runtime. Wikilinks to deleted pages become silent 404s. A missing required field doesn't fail the build — it produces wrong output that someone has to catch by eye.

**lattice** models frontmatter and validation errors with MoonBit types. Content validation happens at runtime during `check` and `build`; it is not a compile-time proof of site correctness. Use `lattice check` for strict validation without output writes.

## How It Works

lattice uses a **two-pass build**:

1. **Pass 1 — Collect & Index.** Walk markdown sources, compute slugs, and build a page index.
2. **Pass 2 — Prepare & Publish.** Validate sources, resolve wikilinks, render pages and indexes, and snapshot static assets in memory. Publish only after preparation succeeds.

The page index supports forward references. Unresolved wikilinks are errors in `check`, but warnings in `build`, which still emits the page. Validation or generation errors leave existing output, cache, and manifest unchanged; a failed first build creates no output. Predictable destination conflicts are checked before writing. Publication itself is not atomic: disk-write failures or interruption can leave partial output, and stale files can remain. See [build safety](docs/build-safety.md) for the exact boundary.

### Structural Guarantees

These are content-validation diagnostics in lattice:

| Violation | What happens |
|-----------|-------------|
| Missing required frontmatter field | `ValidationError` — no prepared output is published |
| Frontmatter type mismatch (e.g., string where int expected) | `SchemaError` — no prepared output is published |
| Broken wikilink `[[target]]` to non-existent page | `BrokenWikilink` violation in `check`; warning in `build` |
| Collection schema constraint violated (bounds, enum, URL format) | Precise diagnostic with constraint and rejected value |
| Duplicate slug between collections/standalone/root | `DuplicateSlug` — only one page claims the URL |
| Invalid template slot name | `TemplateSlotError` diagnostic |
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

## Editorial conventions

Opt in to `require_image_alt = true` to make `check` and `build` reject Markdown
images without descriptive alt text and whitespace-only alt values in built-in
image/figure shortcodes. Intentional decorative images can use the
existing image shortcode with explicit `alt=""`. See [editorial checks](docs/editorial-checks.md)
for the supported scope; raw HTML and templates are not audited.

## Quick Start

For a connected note library with shared navigation and local section search, use
the [wiki starter](docs/wiki-search-page.md#start-a-new-wiki). It creates a new
project from the existing reader, templates and a small typed sample collection.

From the repository root, first follow the [pinned installation instructions](docs/reliability-baseline.md#reproduce). The supported source workflow uses the JavaScript target and Node; no globally installed `lattice` executable is needed.

### Build from source

```bash
moon build cmd/main --target js --deny-warn
export LATTICE_CLI="$PWD/_build/js/debug/build/kurisu/lattice/cmd/main/main.js"
```

Keep this terminal open: the absolute `LATTICE_CLI` path continues to work after changing into your site directory.

### Check and build the example site

From the repository root:

```bash
node "$LATTICE_CLI" check ./example/content --config ./example/site.cfg &&
node "$LATTICE_CLI" build ./example/content -o ./dist --config ./example/site.cfg
```

`check` prepares and validates pages without writing output. Run it before `build` for strict wikilink validation; ordinary `build` treats broken wikilinks as warnings. For a single publication command that rejects unresolved wiki page and fragment targets, use `node "$LATTICE_CLI" build --strict-wikilinks`. This opt-in rebuilds all pages and validates links against the final prepared HTML before writing output; ordinary `build` keeps its warning policy. `check` remains the read-only lint workflow. Enable `wikilink_aliases = true` to declare [alternate names in frontmatter](docs/vault-workflows.md#alternate-note-names) for wikilinks without changing their published URLs. Ordinary Markdown URLs have a separate [opt-in local-link audit](docs/local-links.md): `check --local-links` or `build --strict-local-links`. Nearby one-character page typos can include [valid wikilink suggestions](docs/link-suggestions.md), with labels and verified fragments preserved; choose a target and edit the source yourself.

### Scaffold a new site

Choose a destination that does not exist. From the repository root:

```bash
node "$LATTICE_CLI" init ../my-site
cd ../my-site
```

### Create and publish a new post

```bash
node "$LATTICE_CLI" new posts --name my-first-post
```

Edit `content/posts/my-first-post.md`, replacing its placeholders with your own writing. The [frontmatter example below](#frontmatter) is a complete replacement you can copy. Then validate and build from `my-site/`:

```bash
node "$LATTICE_CLI" check && node "$LATTICE_CLI" build
```

Preview the result over local HTTP:

```bash
python3 -m http.server 8000 --directory dist
```

Open `http://localhost:8000/posts/my-first-post/`. Stop the server with Ctrl+C. Repeat check and build after edits; this server does not rebuild. These commands only prepare local output and start a local preview, without deploying it.

The CLI reference below uses `lattice` as shorthand for an installed executable; from this source checkout, substitute `node "$LATTICE_CLI"`. For an editing preview with automatic rebuild and browser reload, run `node "$LATTICE_CLI" serve` and open `http://127.0.0.1:4321/`. The Node preview binds loopback only; stop it with Ctrl+C. Native builds retain their existing server backend.

String and enum stubs are quoted, including array members, so choices such as
`"true"`, `"42"`, or `"draft # review"` retain their text in YAML. Review placeholders
and run `lattice check` before publishing. Numeric placeholders use the declared
minimum, or zero capped by the maximum when no minimum is given; float values
retain a decimal point. References and date constraints can still require author
input.

## CLI Reference

```
lattice build   [content-dir] [-o <dir>] [options]   — build the site
lattice check   [content-dir] [-o <dir>] [options]   — validate/lint only (no output)
lattice serve   [content-dir] [-o <dir>] [options]   — dev server with live reload
lattice init    <name>                                — scaffold a new site
lattice new     <collection> --name <slug> [options]  — create content from schema
lattice stats   [content-dir] [options]               — print site statistics
lattice inventory [content-dir] [options]           — preview final files and exclusions (no writes)
lattice inventory-diff --before <json> --after <json> — compare planned HTML paths (no writes)
lattice explain <code>                                — describe an error code (e.g. E001)
```

| Flag | Description |
|------|-------------|
| `-c, --config <path>` | Override site config file |
| `--collections <path>` | Override collections config file |
| `--drafts` | Include draft pages and their derived entries |
| `--watch` | Rebuild on file changes (polling) |
| `--watch-interval <ms>` | Polling interval (default: 500) |
| `--force` | Ignore incremental cache, rebuild everything |
| `--strict-wikilinks` | Build only: reject broken wiki page/fragment targets before publishing; rebuild all pages |
| `--local-links` | Check only: audit ordinary local Markdown URLs against final publication output |
| `--strict-local-links` | Build only: reject broken ordinary local Markdown URLs before writing; rebuild all pages |
| `-p, --port <N>` | HTTP port for dev server (default: 4321) |
| `-o <dir>` | Output directory |

Defaults: `content-dir` → `./content`, config → `<content-dir>/lattice.conf`, output → config `output_dir` or `./dist`.

Preview the final files of a forced build without publishing:

```bash
node "$LATTICE_CLI" inventory --format json
```

The [publication inventory](docs/publication-inventory.md) lists authored pages,
generated files, static assets and build metadata, with draft/overwrite exclusions.
It uses the build's preparation plan. It is not a privacy guarantee: vault metadata
such as `type: private` does not exclude a note, and configured static assets are
copied wholesale. Use `check` for strict wikilink validation before publishing. Compare two saved previews with [`inventory-diff`](docs/inventory-comparison.md) to review added and removed HTML paths without inferring renames.

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
| `serve` | Dev server with live reload (Node and native backends) |
| `watch` | File-system polling watcher |
| `vault` | Obsidian vault import support |
| `strutil` | Shared string/char utilities (eliminates 15+ duplicate implementations) |

## Project Stats

- **~25k lines** of MoonBit in `src/` (43k total including tests)
- **31 packages** with focused responsibilities
- **1,280 test declarations**; see [Reliability baseline](docs/reliability-baseline.md) for actual check results
- **249 commits** across 47 days of development
- **2 dependencies**: [`moonbitlang/x`](https://github.com/moonbitlang/x) (filesystem, system) and [`TheWaWaR/clap`](https://github.com/TheWaWaR/clap) (CLI parsing; vendored with a compatibility patch)
- `scripts/check-baseline.sh` passes on the pinned toolchain with the JavaScript target: 1,280 project tests; existing warnings remain

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
moon run cmd/main --target js -- build ./example/content --config ./example/site.cfg
```

## Content Format

### Frontmatter

YAML frontmatter uses `---` fences and `key: value` assignments. The example below is ready to copy into the scaffolded post. To use TOML instead, switch to `+++` fences and `key = value` assignments.

```markdown
---
title: My First Post
date: 2024-01-15
tags: [intro, lattice, demo]
draft: false
---

# Hello World

Content goes here. Return to [[welcome|the welcome post]].
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
