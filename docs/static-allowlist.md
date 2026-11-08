# Select static assets explicitly

By default, Lattice copies every file beneath the configured static directory,
including unreferenced files and attachments used only by a hidden draft. Set the
optional top-level `static_allowlist` to choose exact files instead:

```toml
static_dir = static
static_allowlist = ["logo.png", "downloads/guide.pdf"]
```

The list is a strict JSON array of strings on one line. The lowercase key may be
bare or single/double quoted; these spellings are the same setting, including
JSON escapes in double-quoted keys, and cannot bypass duplicate checks. Invalid
double-quoted key syntax is rejected, not silently ignored. Paths are relative to
`static_dir`, not the content directory or output directory. The example emits
`static/logo.png` and `static/downloads/guide.pdf`. With `static_dir = attachments`,
`["photo.png"]` selects `attachments/photo.png`. Spaces and Unicode filenames
are supported. Each entry must name an existing regular file.

- Omitted setting: preserve the existing copy-all behavior.
- `static_allowlist = []`: plan no static files or empty static directories.
- Nonempty list: copy exactly the named files, even if no page references them.
- Invalid JSON/types, duplicate entries or declarations, noncanonical paths,
  missing files and directory entries fail `build`, `check` and `inventory`.
  Use forward slashes, no absolute paths, empty components, `.` or `..`.
- Entries are exact names, not glob patterns or directory prefixes. Selecting a
  file does not include siblings or dependencies referenced by its HTML or CSS.

The filesystem builder API uses the same `SiteConfig.static_allowlist` policy.
`--drafts`, `--force`, cached builds and watch rebuilds do not expand the list.

## References and preview

A public reference is not permission to publish an attachment. Obsidian image
embeds resolve only against selected assets; an embed targeting a withheld asset
rejects publication. Withheld files with the same basename do not make a selected
image ambiguous. Ordinary Markdown links, HTML and CSS do not expand the list.
Use `check --local-links` or `build --strict-local-links` for the existing supported
local-link validation; this is not a complete audit of references in arbitrary
HTML, CSS or scripts.

`inventory --format json` marks discovered but unselected files as
`kind: "static_asset", status: "excluded"`, with an allowlist explanation.
Selected files remain `planned`. Inventory contains file paths, not attachment
bytes. Treat the inventory as a local audit record rather than publishing it.
Static selection enumerates withheld paths without opening their file bytes.
This does not prevent separate watch/dependency scanning or another configured
source role from reading those files.
`check` and `inventory` remain read-only.

## Safety limits

This is a static-file selection policy, **not a complete privacy boundary**.
Private visibility declarations still reject the whole build. Do not publish a
mixed public/private vault with this option. Keep using a deliberately curated
public source tree.

The allowlist controls new static writes only. It does not delete stale output,
withdraw a deployed file, or sanitize old build metadata. Narrowing the list or
removing a source leaves any previously copied output intact. Verify a **fresh,
dedicated output directory**, and separately ensure deployment removes withdrawn
files. A failed build also preserves the previous output.

The setting does not filter Markdown sources, generated pages, search/content
indexes, templates, data files, or cache/manifest metadata. Those can still
contain private information copied into public content or source paths. Other
planned writers can use the same output path, so an excluded static entry is not
a promise that no other writer emits that path. The inventory shows final owners.

Use trusted, stable filesystem trees without symlinks and a single builder.
The portable filesystem API does not provide symlink inspection or atomic
snapshot/publication operations. A listed symlink can refer outside the static
root; symbolic links and filesystem races are outside this policy's guarantee.
Selection authorizes the entire selected file, not only the bytes referenced by
a page. See [build safety](build-safety.md) for publication failure limits.

## Implementation decision

AI-assisted implementation chose explicit exact paths rather than automatically
publishing referenced files: a reference does not establish the owner's intent
to disclose an attachment. The existing default stays compatible, while an empty
list has an unambiguous deny-all meaning. The same typed selection is used for
publication planning, lint and image discovery; static selection does not load
withheld bytes just to decide whether they should be published. Synthetic
fixtures exercise
binary preservation, malformed policies, exclusions, custom roots, image
ambiguity, read-only commands and the deliberately retained stale-output limit.
