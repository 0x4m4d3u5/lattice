# Build into a fresh output directory

Use `--fresh-output` to prepare a new release without carrying files forward from
an earlier build:

```sh
lattice inventory content -o releases/release-002 --fresh-output --format json
lattice build content -o releases/release-002 --fresh-output
```

The destination must not exist, even as an empty directory. Review the inventory
before building. A successful build creates that directory; a second build to
the same path is refused. Choose another unused destination for the next release.
`--force` does not override this refusal.

This workflow addresses stale artifacts without deleting anything. If a note,
redirect, tag page or attachment is no longer part of the prepared output, the
new release never inherits its old file. Earlier release directories remain
unchanged. A deployment still needs to replace its served file set rather than
copy new files over old ones. This command does not deploy or withdraw content.

## What changes in fresh mode

- The builder performs a full preparation with an empty cache. Existing cache or
  manifest files are not loaded.
- Generated `.lattice-cache` and `.lattice-manifest.json` files are omitted.
  These root-level names are reserved and cannot be supplied by another writer.
- Only the final writer for each file destination is published. Superseded
  intermediate pages are never written to the fresh directory.
- Default CSS is part of the required output. A write failure is an error rather
  than a warning-only incomplete export.
- The destination is checked before preparation and again before publication.
  Existing destinations and lexical overlaps with configured source, collection,
  static, standalone, template and data roots or configuration files are errors.
- `inventory --fresh-output` uses the same plan and refusal rules without writing
  anything. It lists no generated build metadata. Excluded entries can still
  contain source paths, so keep inventory reports as local audit records.

The ordinary `build` and `inventory` modes retain their existing cache, output
and overwrite behavior. `check` remains read-only. `--fresh-output` cannot be
combined with `build --watch`, and is not a `serve` or `dev` option: those modes
need to reuse a destination.

Drafts, visibility, static selection and link-validation policy remain separate.
`--drafts` still includes drafts when explicitly requested. Private, invalid or
duplicate visibility declarations still reject preparation. The
[`static_allowlist`](static-allowlist.md) still controls exact static-file
selection, and omission still means copy all static files. A reference does not
expand the allowlist. Use `--strict-wikilinks` and `--strict-local-links` when you
want their existing validation policies on a fresh build.

## Filesystem and deployment limits

Use a dedicated destination outside the input trees, with trusted stable inputs,
no symbolic links, and one writer. Isolation checks normalize absolute paths
lexically using the filesystem path library. They do not resolve symlinks,
filesystem-specific aliases or concurrent changes. The portable filesystem API
does not provide the primitives for an atomic release-directory swap.

Validation and generation failures create no destination. A disk or permission
failure during publication can leave a partial new directory. The build reports
failure and leaves that directory intact. Inspect it, then retry with a different
unused path. There is no automatic cleanup, rollback or deletion of user files.
A failed export must not be deployed.

A fresh artifact avoids old output and internal build metadata, but it does not
prove that authored prose, templates, data or selected attachments contain no
private information. Final-writer selection is per output file: it does not change
search/index policy, so excerpts from a superseded authored page can still appear
in another generated file. It does not make a mixed private/public vault safe. Continue
using a curated public source tree and the
[public-only visibility guard](publication-visibility.md).

The additive builder APIs accept `fresh_output=true` on `build`, `inventory` and
`inventory_with_fragments`. `BuildConfig` and the default API behavior are
unchanged. Fresh builds ignore a cache store supplied by the caller.

## Implementation decision

AI-assisted implementation chose new release directories instead of inferring
ownership from the old incremental manifest. That manifest is not a complete
record of generated pages and copied assets. Deleting files based on it could
remove unrelated data while still missing stale files. The new mode reuses the
full preparation plan and enforces an unused destination, leaving deployment
replacement to a separate explicit step.

Synthetic regressions cover removed notes and attachments, hidden-source paths
in old manifests, final-writer publication, exact inventory parity, reused and
overlapping destinations, read-only previews, rejected private inputs and partial
I/O failure recovery. JavaScript and native CLI fixtures exercise the same API.
