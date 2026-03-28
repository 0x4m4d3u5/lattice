# lattice

A MoonBit static site generator for the 2026 MoonBit Software Synthesis Challenge.

`lattice` is built around one claim: content integrity should be structural.
Typed frontmatter schemas, validated wikilinks, and content contracts are checked during the build pipeline so violations are surfaced as hard errors instead of runtime surprises.

## Purpose

- Build a practical SSG in MoonBit.
- Use MoonBit's type system to make schema/link correctness explicit.
- Keep the pipeline simple and auditable: parse -> validate -> render -> emit.

## Structural-integrity angle

`lattice` treats these as build-time failures:

- Missing required frontmatter fields (for example `title`, `date`).
- Frontmatter type mismatches (for example `tags` is not `Array[String]`).
- Broken wikilinks (`[[target]]` where target is missing from the page index).

The builder performs a two-pass build:

1. Collect all markdown sources, compute slugs, and build a complete page index.
2. Parse frontmatter, validate schema, resolve wikilinks, render markdown, emit HTML.

Because wikilinks resolve against the complete index from pass 1, forward references are deterministic and unresolved targets are hard errors.

## Project structure

- `cmd/main/` - CLI entrypoint.
- `src/builder/` - Build orchestration, file I/O, site-index generation.
- `src/frontmatter/` - Frontmatter parser (`FrontmatterValue` ADT).
- `src/schema/` - Typed schema declarations + validation.
- `src/wikilink/` - Wikilink extraction and index resolution.
- `src/markdown/` - Markdown parser/renderer.
- `src/html/` - HTML document and helper emitters.
- `src/slug/` - Filename-to-slug and slug-to-URL helpers.
- `content/` - Example markdown content.
- `dist/` - Build output.

## CLI

`lattice` uses subcommands powered by `@clap`:

```
lattice build   [content-dir] [output-dir] [options]
lattice check   [content-dir] [output-dir] [options]
lattice serve   [content-dir] [output-dir] [options]
```

### `lattice build`

Build the site and write HTML to the output directory.

```bash
# defaults: ./content → ./dist
lattice build

# explicit paths
lattice build ./content ./dist

# with config and collections overrides
lattice build ./content ./dist --config ./example/site.cfg --collections ./example/collections.cfg

# watch mode — rebuild on file changes
lattice build ./content ./dist --watch

# custom polling interval (default: 500 ms)
lattice build ./content ./dist --watch --watch-interval 1000

# include draft posts
lattice build ./content ./dist --drafts

# force full rebuild (ignore incremental cache)
lattice build ./content ./dist --force
```

### `lattice check`

Run validation and lint pipeline only — no output writes.

```bash
lattice check ./content ./dist
```

### `lattice serve`

Start the dev server with live reload and file watching.

```bash
# defaults: port 4321
lattice serve ./content ./dist

# custom port
lattice serve ./content ./dist --port 8080

# include drafts
lattice serve ./content ./dist --drafts
```

### Common flags

| Flag | Subcommands | Description |
|------|------------|-------------|
| `-c, --config <path>` | build, check, serve | Override site config file |
| `--collections <path>` | build, check, serve | Override collections config file |
| `--drafts` | build, serve | Include draft posts |
| `--watch` | build | Rebuild on file changes with polling |
| `--watch-interval <ms>` | build | Polling interval (default: 500) |
| `--force` | build | Ignore incremental cache |
| `-p, --port <N>` | serve | HTTP port for dev server (default: 4321) |

### Defaults

- `content-dir` → `./content`
- config file → `<content-dir>/lattice.conf`
- `output-dir` → `config.output_dir` or `./dist`

## Output

A successful build emits:

- `dist/<slug>/index.html` for each content page.
- `dist/tags/index.html` listing all tags with counts.
- `dist/tags/<tag>/index.html` for each extracted tag.
- `dist/site-index/index.html` containing:
  - all pages with titles and slugs,
  - wikilink relationships grouped by source page.
- `dist/style.css` default stylesheet.

## Templates

`lattice` supports optional user templates in a templates directory:

- Default: `<content-dir>/templates`
- Override with config: `templates_dir=./path/to/templates`

Supported files:

- `templates/page.html` for individual content pages.
- `templates/index.html` for collection index pages.
- `templates/tag.html` for per-tag pages (`/tags/<tag>/`).
- `templates/tags.html` for tags index (`/tags/`).

If a template file is missing, lattice falls back to the built-in hardcoded renderer for that page type.

Template placeholders use `{{slot_name}}` syntax. Available typed slots:

- `{{title}}` full page title
- `{{content}}` rendered HTML body fragment
- `{{date}}` frontmatter date (empty when unavailable)
- `{{description}}` page/index description text
- `{{url}}` page URL path (for example `/posts/hello/`)
- `{{site_name}}` site title from config
- `{{nav_links}}` generated collection navigation HTML
- `{{custom_css}}` default lattice CSS string
- `{{tag_name}}` tag name (tag pages)
- `{{tag_count}}` page count (tag pages / tags index)

## Notes for SCC explainability

Keep an execution log of cases where type/schema validation prevented invalid output. Those examples can be reused directly in the challenge retrospective's architectural decisions and AI-tooling sections.