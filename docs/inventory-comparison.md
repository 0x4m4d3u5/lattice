# Review planned HTML path and fragment changes

Save two explicit publication inventories to compare the planned HTML file paths
and verified fragment targets before and after an authoring or configuration change:

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
not the incomplete build manifest, old output on disk or guessed heading slugs.

Path strings are compared exactly and sorted lexically. Output roots, source
paths, ownership and entry ordering do not affect path identity. `unchanged`
means only that the same path occurs in both sets; contents, redirect destinations
and ownership may have changed. Fragment changes on those common paths are reported
separately. The snapshots do not establish domain/base-URL changes, server URL
rewriting or external backlinks. `index.html` is not converted into a guessed
public URL. Non-HTML public URLs are not covered.

Use comparable configurations and draft flags, and retain a snapshot from the
version you actually published if you want a meaningful before/after reference.
A saved preview is not proof that a deployment happened. Inventory warnings remain
important: the report includes warning counts for each snapshot; consult the
original JSON diagnostics for details. No output is deleted if a path disappears
from the plan, and stale files may still exist on disk or a host.

## Published fragment changes

Current CLI inventories attach `fragments` to final planned HTML entries. An
array lists raw, decoded, scanner-verified unique IDs and legacy anchor names,
including emitted nested headings and template/static targets. It is not a list
of source heading slugs. Omitted headings and inert template/comment/script
markup do not contribute targets. Duplicate IDs/names lose verification; their
removal from the verified set means a target became ambiguous, not necessarily
that its spelling disappeared. The browser's implicit `top` target is not added.

A heading rename at an unchanged path can therefore report:

```text
fragment removed "notes/guide/index.html" #"setup"
fragment added "notes/guide/index.html" #"installation"
```

These are separate set changes, not an inferred rename. Values are raw identifiers,
not assembled or percent-encoded public URLs. Base paths do not alter output-relative
file identity. This does not promise browser navigation equivalence for malformed
HTML or server rewriting.

An empty array means no verified targets. Missing metadata in an older snapshot,
or explicit `null`, means **unknown**. Unsupported parsing contexts (`select`,
`noscript`, `plaintext`), uncertain entity decoding, whitespace/control-bearing target attributes (the shared
decoder normalizes whitespace), and non-UTF-8 static HTML
produce unknown metadata rather than a misleading empty set. The scanner is not
a full browser DOM parser. Only paths present in both inventories and known on
both sides are compared; other common paths are listed as unknown. Added/removed
files remain in the existing path report rather than duplicating every target.

## Machine-readable output and errors

Success returns exit status 0, even when paths differ. JSON has `version: 1`,
`scope: "planned_html_paths"`, `ready: true`, `notice`, sorted `added` and `removed`
arrays, `unchanged`, `before_warnings` and `after_warnings` counts. The additive
`fragments` object has `scope: "verified_html_targets_v1"`, `compared` (common
paths with known sets), sorted `unknown` paths, and sorted `changes` objects
containing `path`, `added` and `removed` identifier arrays. Legacy snapshots still
produce the original path comparison, with their common fragment sets unknown.

Both inputs must be ready version-1 inventory JSON with valid entry fields and
known kinds/statuses. Blocked inventories, error diagnostics, malformed JSON,
unsupported versions, empty paths and duplicate planned destinations are rejected.
Fragment arrays must contain distinct nonempty strings without ASCII controls; malformed
fragment metadata is rejected. Other unknown extra fields are ignored for additive compatibility. No path from a
snapshot is opened; paths are treated as data and quoted in text output.

Read/input failures return exit status 1. With `--format json`, they return
`ready: false`, `error` and the version/scope/notice fields, with no partial diff.
Unknown options and unsupported output formats remain ordinary CLI usage errors.

The existing path-only `@builder.compare_inventories` API and its formatters keep
their contracts. Use `compare_inventory_targets` with
`format_inventory_target_comparison` / `format_inventory_target_comparison_json`
for the detailed report used by the CLI. Publishing policies and runtime support
are unchanged.
