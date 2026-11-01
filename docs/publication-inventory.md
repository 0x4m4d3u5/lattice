# Preview publication

`lattice inventory` shows the final file destinations of a forced build without
writing sources, output, cache or manifest. It uses the same preparation pipeline
as `build`, including template rendering, final tag regeneration, pruning, static
asset snapshots and destination preflight. No second discovery or slug algorithm
is used to approximate what will be published.

From your site directory, using the source-built JavaScript CLI:

```sh
node "$LATTICE_CLI" inventory
node "$LATTICE_CLI" inventory --format json
node "$LATTICE_CLI" inventory --drafts --format json
```

With an installed CLI, substitute `lattice`. The command also accepts the usual
content directory, `-o`, `--config` and `--collections` options. It adds no backend
restrictions or new filesystem primitives. Native execution still requires the
native toolchain; the pinned verified profile is JavaScript/Node.

## Read the report

Text output starts with `prepared` or `blocked`. JSON has `version: 1`,
`output_dir`, `ready`, `notice`, `entries` and `diagnostics` fields. Each entry has:

| Field | Meaning |
|---|---|
| `path` | Normalized path relative to the output directory |
| `source` | Source path for an authored page or static asset; otherwise `null` |
| `kind` | `page`, `generated`, `static_asset` or `build_metadata` |
| `status` | `planned` for the final owner, or `excluded` |
| `reason` | Final output, optional output, draft, retained stylesheet, superseded writer or final-plan pruning explanation |

Entries sort by path, status, kind, source and reason. Diagnostics retain severity,
code, path, available line/column, message and note; their presentation is sorted.
Paths in text output are quoted, so unusual filenames remain unambiguous. No page
body or attachment bytes are printed.

For example, an authored page at a collection index route may be listed as
excluded because generated navigation owns that destination. A static overwrite
is shown as the final static owner. Earlier writers may still be transiently
written during publication: `excluded` here describes the **final file view**,
not a guarantee that an intermediate write never occurs. A custom draft 404 is
excluded while its generated default remains planned. Existing optional CSS is
listed as retained rather than planned for replacement.

`--drafts` uses existing build policy. Without it, draft source destinations are
listed as excluded. This is not a recursive inventory of every file in an arbitrary
vault: discovery remains the configured collections, root/standalone content and
static directory. Omitted derived pages are not independently fabricated as rows.
Empty directories are not file entries.

## Errors and limits

Exit status is zero when preparation and destination preflight succeed; warnings
remain warnings. A preparation or preflight error returns status 1, `ready: false`
and an empty entry list rather than presenting a partial plan as complete. Setup
errors use the same JSON envelope with `output_dir: null`. Unknown CLI options or
invalid format values are ordinary CLI usage errors.

Inventory follows **build's** validation policy. Broken wikilinks can be warnings;
use `lattice check` for strict validation, including published fragment checks.
An excluded draft is still validated according to current build policy.

The preview deliberately forces full preparation with a fresh in-memory cache.
It lists intended final files, not the subset an incremental build would rewrite.
Existing optional stylesheets and destination conflicts still affect the plan.
Input changes, permissions, disk exhaustion, interruption or filesystem races
can invalidate the preview. It is not a promise that a future build will succeed,
a directory transaction, or a deployment operation.

Vault helpers are not publication filters: `type: private`, inbox or WIP metadata
alone does not prevent publication. Every file under the configured static
source directory is copied according to existing rules, even if its related note
is excluded. Review attachment inclusion explicitly. Existing stale output is
neither inventoried nor removed; inspect a fresh output directory when evaluating
what a build emits. The inventory adds no migration, filtering, deletion or
privacy guarantee. See [build safety](build-safety.md) and
[vault helper boundaries](vault-workflows.md).

The additive MoonBit API is `@builder.inventory(config)` returning
`PublicationInventory`, with `format_inventory` and `format_inventory_json` for
presentation. It never calls `OutputPlan::publish` and does not change `build`,
`check`, `serve` or their runtime contracts.

Compare two saved JSON inventories with [`inventory-diff`](inventory-comparison.md)
to review planned HTML path additions/removals without inferring moves or anchors.

## Verified HTML targets

CLI JSON inventories add an optional `fragments` member to final planned HTML
entries. It contains sorted unique IDs/legacy anchor names from the actual final
HTML, or `null` when the scanner cannot establish the set. Excluded/non-HTML
entries omit it. An empty array is known empty; absent legacy metadata is unknown.
See [inventory comparison](inventory-comparison.md#published-fragment-changes)
for scope and interpretation. Text inventories list the same metadata.

The existing `PublicationInventory`/`InventoryEntry` records and `inventory` API
remain intact. `inventory_with_fragments(config)` returns the inventory plus a
map of output-relative paths to optional target arrays. Pass that map as the
optional `fragments` argument to either inventory formatter. Without it, the
existing formatters retain their original output.
