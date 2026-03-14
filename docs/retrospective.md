# lattice retrospective

## What lattice is

`lattice` is a static site generator written in MoonBit for the 2026 MoonBit Software Synthesis Challenge. The project goal is narrow and explicit: treat content integrity as a structural property of the build, not a runtime convention.

In practice that means frontmatter, collection schemas, template slots, data-file keys, and wikilinks are all checked before HTML is emitted. A page is not considered valid because the renderer happened to produce output. It is valid because it satisfied the typed contracts the builder expects.

## Why MoonBit

The reason for building this in MoonBit was not that MoonBit is already the obvious language for static site generation. It is a new language with a still-forming ecosystem, native WebAssembly support, and a type system that looked strong enough to make the "structural guarantees" story real instead of rhetorical.

I wanted a real project to test the edges of the ecosystem: file I/O, parsing, string-heavy code, WASI builds, package boundaries, test ergonomics, and whether the language stays workable once the code stops being toy-sized. An SSG is a good stress case because it mixes parsing, validation, graph construction, templating, and output generation in one pipeline.

## Architecture decisions

The core pipeline in `src/builder/builder.mbt` is organized as a sequence of explicit stages.

### Frontmatter parsing

The first layer is `src/frontmatter/frontmatter.mbt`. It parses the `---` block into a typed `FrontmatterValue` tree instead of a loose string map. That gives the rest of the build something better than "maybe metadata, maybe not." Dates, ints, bools, arrays, and strings are distinguished before schema validation starts.

This layer exists because schema validation is only useful if the raw metadata has already been normalized into something typed. If frontmatter stayed untyped, every later stage would have to repeat coercion logic or silently accept bad values.

### Schema validation

The second layer is `src/schema/schema.mbt`. Collections declare field contracts such as `title:String`, `date:Date`, or `tags:Optional[Array[String]]`, and the builder validates parsed frontmatter against those contracts before rendering.

This layer exists to make content models explicit. A page in `posts` is not just "a markdown file under a folder"; it is an instance of a declared schema. Missing required fields and incompatible types are surfaced as build diagnostics instead of becoming empty template output, broken feeds, or malformed search metadata later.

### Template rendering

After metadata is valid, the builder resolves wikilinks against a complete site index, renders markdown to HTML, and then renders the page through the template engine. The template system is deliberately strict: built-in slots are enumerated, `data.*` paths are validated, and missing values fail the build instead of collapsing to empty strings.

This layer exists because template bugs are content bugs. If `{{data.nav.title}}` is wrong or a slot name is misspelled, the build should stop at the contract boundary where the mistake happened.

### Incremental build manifest

The builder keeps a manifest in `dist/.lattice-manifest.json` and uses file snapshots plus link-target tracking to decide what actually needs to be rebuilt. Source fingerprints still flow through the page cache, but the manifest adds a dependency view over templates, config, collections, data, and backlink targets.

This layer exists because a site generator should not force full rebuilds for every edit once the project grows. The important detail is that incremental behavior still preserves structural checks: the page index is built before wikilinks are resolved, and backlink changes can force dependent pages to rebuild even if the page itself did not change.

## What worked well

MoonBit's type system carried a lot of the project. The frontmatter ADT, schema ADT, template slot enum, and typed error surfaces made the pipeline easier to reason about than a stringly implementation would have been. The "structural vs behavioral" idea held up in code, not just in docs.

The schema validation approach worked particularly well. It is small, readable, and strict enough to matter. Required fields, `Optional[...]`, `Array[...]`, and `Date` cover a surprising amount of real content modeling without turning the syntax into its own language.

Test coverage also paid off. The repo currently has 74 tests across frontmatter parsing, schema validation, collections config parsing, templates, markdown, highlighting, wikilinks, pagination, manifest parsing, cache behavior, and builder integration. That mattered because a lot of the code is parser and renderer code where off-by-one and edge-case regressions are easy to introduce.

## What was hard

MoonBit string handling was the hardest consistent friction point. There is no general-purpose buffer type in the prelude for this kind of work, so `StringBuilder` becomes the default tool for slicing, token assembly, escaping, and emitting. That is workable, but it means writing and maintaining a lot of helper code.

Character handling is also sharper than expected. `s[i]` returns `UInt16`, not `Char`, so nearly every parser ended up with a `char_at` helper to convert code units before doing comparisons. String slicing is similarly manual because the obvious operations are either missing or easier to misuse, and invalid slice boundaries raise errors. None of this is fatal, but it increases the amount of defensive plumbing in parser-heavy code.

The ecosystem is still thin. That showed up in configuration parsing, frontmatter parsing, and templating: many pieces that would normally come from a library were implemented directly in the repo. That was good for control and explainability, but it also meant spending time on infrastructure rather than only on site features.

The WASI component pipeline was also more complex than I wanted. MoonBit's WASM-native story is part of the reason to use it, but taking a nontrivial CLI project through native and WASI-shaped toolchains is still more involved than in a mature ecosystem. For this project, native development stayed the practical path and WASI remained more of an ecosystem-learning exercise than the default target.

## Features shipped

The current repo ships these major features:

- frontmatter parsing with typed values
- schema validation with `String`, `Date`, `Int`, `Bool`, `Array[...]`, and `Optional[...]`
- strict template parsing and rendering
- multiple typed content collections
- wikilink resolution against a complete site index plus `graph.json` output
- backlinks generation
- incremental builds backed by a manifest and dependency snapshots
- per-collection page template overrides
- `Date` as a first-class schema type
- syntax highlighting for fenced code blocks

Around those core pieces, the builder also emits collection indexes, paginated tag pages, feeds, sitemap output, a search index, static assets, and watch-mode rebuilds.

## Test coverage

There are 74 tests in the repo today.

They cover the main failure-prone areas:

- frontmatter parsing, including malformed assignments and date handling
- schema validation for required, optional, array, and date fields
- collection parsing, including optional template overrides
- template rendering and missing data paths
- markdown rendering, shortcodes, and syntax highlighting
- wikilink extraction and resolution
- pagination behavior
- manifest render/parse roundtrips
- cache behavior
- builder integration for collection template overrides

That is not exhaustive end-to-end coverage, but it does cover the structural contracts that the project depends on most heavily.

## What comes next

Two next steps are clear from the current state of the code.

- full TOML config: the current config format is intentionally simple and narrower than real TOML
- richer template slots: the current slot model is strict and useful, but it is still shallow compared with the layout composition people expect from mature SSGs

The main lesson from building `lattice` is that MoonBit is already capable of supporting a serious small-to-medium systems-style application, but the friction is still mostly in libraries and tooling, not in the language core. That is exactly the kind of thing I wanted this project to test.
