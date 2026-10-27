# Review planned HTML path changes

Save two explicit publication inventories to compare the planned HTML file paths
before and after an authoring or configuration change:

```sh
node "$LATTICE_CLI" inventory --format json > before.json
# Make the intended content/configuration edits, then capture a new preview.
node "$LATTICE_CLI" inventory --format json > after.json
node "$LATTICE_CLI" inventory-diff --before before.json --after after.json
node "$LATTICE_CLI" inventory-diff --before before.json --after after.json --format json
```

Use `lattice` instead of `node "$LATTICE_CLI"` with an installed CLI. The shell
redirections above save the snapshots; the comparison command itself only reads
the two files. It does not load the current site's configuration, inspect output,
render pages or write sources, cache, manifest, redirects or output. Keep snapshots
outside content/static directories so they are not accidentally published.

For a collection renamed from `notes` to `articles`, the report can show:

```text
removed "notes/guide/index.html"
removed "notes/index.html"
added "articles/guide/index.html"
added "articles/index.html"
```

These are separate removals and additions, **not inferred moves**. Review the
removed paths against your publishing setup and any known shared links before
publishing. No redirects are created automatically.

## Exact scope

Only final `planned` entries ending in `.html` or `.htm` (case-insensitive suffix)
are compared; build metadata is excluded. This includes authored pages, generated
indexes and redirect HTML, and static HTML. Draft/excluded candidates do not enter
the sets. Other assets, feeds, search indexes and retained optional CSS are outside
this report. It reads the [inventory's final file view](publication-inventory.md),
not the incomplete build manifest, old output on disk or guessed heading history.

Path strings are compared exactly and sorted lexically. Output roots, source
paths, ownership and entry ordering do not affect path identity. `unchanged`
means only that the same path occurs in both sets; contents, headings, redirect
destinations and ownership may have changed. Neither snapshot contains enough
information to establish domain/base-URL changes, server URL rewriting, external
backlinks or heading-anchor impact. `index.html` is not converted into a guessed
public URL. Non-HTML public URLs are not covered.

Use comparable configurations and draft flags, and retain a snapshot from the
version you actually published if you want a meaningful before/after reference.
A saved preview is not proof that a deployment happened. Inventory warnings remain
important: the report includes warning counts for each snapshot; consult the
original JSON diagnostics for details. No output is deleted if a path disappears
from the plan, and stale files may still exist on disk or a host.

## Machine-readable output and errors

Success returns exit status 0, even when paths differ. JSON has `version: 1`,
`scope: "planned_html_paths"`, `ready: true`, `notice`, sorted `added` and `removed`
arrays, `unchanged`, `before_warnings` and `after_warnings` counts.

Both inputs must be ready version-1 inventory JSON with valid entry fields and
known kinds/statuses. Blocked inventories, error diagnostics, malformed JSON,
unsupported versions, empty paths and duplicate planned destinations are rejected.
Unknown extra fields are ignored for additive compatibility. No path from a
snapshot is opened; paths are treated as data and quoted in text output.

Read/input failures return exit status 1. With `--format json`, they return
`ready: false`, `error` and the version/scope/notice fields, with no partial diff.
Unknown options and unsupported output formats remain ordinary CLI usage errors.

The pure additive API is `@builder.compare_inventories(before_json, after_json)`,
with `format_inventory_comparison` and `format_inventory_comparison_json` helpers.
Existing inventory output, publishing policies and runtime support are unchanged.
