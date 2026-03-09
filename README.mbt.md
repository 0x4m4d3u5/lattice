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

## Build and check

Run from repo root:

```bash
moon check
moon run cmd/main
```

Optional custom paths:

```bash
moon run cmd/main -- ./content ./dist
```

## Output

A successful build emits:

- `dist/<slug>/index.html` for each content page.
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

## Notes for SCC explainability

Keep an execution log of cases where type/schema validation prevented invalid output. Those examples can be reused directly in the challenge retrospective's architectural decisions and AI-tooling sections.
