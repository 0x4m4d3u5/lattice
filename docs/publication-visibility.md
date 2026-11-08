# Public-only visibility guard

Lattice currently publishes a curated public source tree. It does **not** support
building a mixed private/public vault, even with this guard enabled.

`visibility` is now a reserved frontmatter key. Ordinary `build`, `check` and
`inventory` enforce it without an opt-in flag:

- Missing `visibility` preserves existing publication behavior.
- `visibility: public` permits the existing pipeline to continue. Schema, draft
  and other validation rules still apply.
- `visibility: private` rejects the entire build preparation. There is no private
  audience or private-output flag yet.
- Any other value, type, capitalization or surrounding whitespace inside a string
  is an error. Use exactly the strings `public` or `private`.
- Repeating the `visibility` key is an error, including two identical values.
  A later `public` assignment cannot erase an earlier `private` declaration.

For YAML-style frontmatter, write `visibility: public` between `---` fences. For
TOML-style frontmatter, write `visibility = "public"` between `+++` fences. The
key is the lowercase `visibility` key, either bare or wrapped in single or
double quotes. Quoted and unquoted spellings name the same reserved field. A collection does not need to declare it in its schema. An explicit
collection constraint on that field still applies; it cannot bypass the guard.

The guard runs on collected collection, standalone and root Markdown sources,
plus the dedicated root `404.md`, before rendered outputs or cache reuse. A
source that would later be overwritten by a generated page is still checked.
`--drafts`, `--force`, strict-link options and watch rebuilds do not disable the
guard. The same rules apply through the filesystem builder API. Supplied-text
rendering APIs are not publication pipelines; their hosts own access and output.

Diagnostics identify the source path and field line. `check --format json`
reports `kind: "publication_visibility"`; build and inventory use `E015`.
Run `lattice explain E015` for the short explanation. Blocked inventory returns
`ready: false` and no partial entry list.

## Compatibility

This reserves a field that applications may previously have declared for another
purpose. Such schemas can no longer use arbitrary `visibility` values during
publication. Rename unrelated metadata rather than marking private material
public simply to pass the check.

`draft` remains a separate readiness flag. Even a hidden draft with
`visibility: private` rejects the build. `type: private` remains organizational
metadata, and `publish` is not a publication switch. Neither is reinterpreted by
this change. Missing visibility is **not** a private-by-default policy.

## What this guard does not protect

A rejected build leaves the existing output, cache and manifest unchanged. It
neither removes previously published content nor withdraws a deployed site. If a
published note becomes private, the previous public file still exists. Handle
that takedown explicitly and do not deploy an old output directory after failure.

Configured static assets are still copied wholesale on successful builds,
including unreferenced files. This guard does not classify attachments, data,
templates, copied Markdown assets or prose, and it cannot detect private text
copied into a public note. It does not inspect arbitrary notes outside the
configured Markdown source set. Keep private notes **and** private attachments
out of the public build inputs and public repository.

A complete audience boundary still needs explicit asset classification, isolated
public/private outputs and caches, stale-artifact handling, and public-only
metadata/link derivation. This prerequisite deliberately rejects private input
instead of offering an incomplete private-page filter. Continue using the
[curated-copy workflow](vault-workflows.md) and review the
[publication inventory](publication-inventory.md) and [build safety](build-safety.md).

## Regression coverage

`scripts/check-publication-visibility.mjs` uses synthetic sources to exercise
ordinary build/check/inventory, all authored page kinds, external collection
paths, YAML/TOML values and duplicate keys, hidden drafts, cold and warm caches,
strict and forced builds, output preservation, and repair after rejection. Its
JavaScript run also exercises watch rejection and recovery. The target gate runs
the command-level cases against the native executable. MoonBit tests cover the
builder APIs and parser behavior on all supported targets.
