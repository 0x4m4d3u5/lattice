# Export a private memory view

`--audience private` explicitly exports all configured Markdown sources, including
`visibility: public`, `visibility: private` and sources with no visibility field.
It produces ordinary HTML, a content index and other enabled site artifacts in a
new directory. **These are plaintext private files, not access-controlled files.**
The command does not start a server, upload, deploy, change permissions or encrypt.

Choose a destination outside every served, published, synchronized or shared
public directory. A new subdirectory inside a public server root is not private.
The private plan refuses a destination equal to or nested under the configuration's
`output_dir` (or `./dist` when absent), even when CLI `-o` overrides it or the
publication root does not yet exist. Keep that configured root pointing at the
public destination when reusing or copying a public config. This is a lexical,
normalized-path check, not realpath containment: symlinks, filesystem aliases and
concurrent changes remain outside the guarantee. Lattice cannot discover other
server, synchronization or sharing roots. Keep the
entire export, its inventory and its diagnostics local and private.

## Explicit inputs and destination

Use an explicitly reviewed configuration for this export. A content index and an explicit
static allowlist are required; an empty allowlist is valid:

```cfg
title = Local memory
base_url = /
content_index_file = content-index.json
static_allowlist = []
```

`base_url` must be exactly `/` (origin-free links), or an `http://` or `https://`
origin with the literal host `127.0.0.1` or `[::1]`, optionally a decimal port
1–65535 and one trailing slash. Hostnames (including `localhost`), credentials,
paths, queries and fragments are rejected. This deliberately narrow grammar
avoids accidentally retaining a public origin; it does not restrict authored
links, browser requests or the origin an evidence consumer independently chooses.
Origin-free links resolve against whichever host serves the files, not necessarily
a private host.

Retain the collection schemas and template/data paths appropriate for the input.
Check and inspect one unused destination, then build it:

```sh
lattice check content -c private.cfg -o ../local-memory/export-001 --audience private --format json
lattice inventory content -c private.cfg -o ../local-memory/export-001 --audience private --fresh-output --format json
lattice build content -c private.cfg -o ../local-memory/export-001 --audience private --fresh-output
```

Every private CLI command requires an explicit `-o` or `--output-dir`; it does not
fall back to a configured output or `dist`. Build and inventory also require
`--fresh-output`. Check prepares the same fresh plan without writes. Existing
paths, including empty directories, and lexical overlap with configured inputs
are refused. Choose a new path for each export. Public and private exports cannot
reuse each other's existing destinations, and `--force` does not override this.

Caches are ignored and generated cache/manifest files are omitted. A successful
export contains only its prepared final files. The content-index destination must
not collide with another output writer. Fresh output never deletes or changes an
older export. A validation failure writes nothing; an I/O failure can leave a
partial directory. Do not use a failed export. See [fresh output](fresh-output.md)
for symlink, concurrent-writer and filesystem-alias limitations.

## Source and validation semantics

- Private means the whole configured source set, not only private-labelled notes.
  Sources outside configured collection, standalone and root discovery are not
  automatically imported. The custom `404.md` is included separately.
- `draft` remains readiness, not audience. Drafts stay omitted unless `--drafts`
  is requested. Even omitted drafts must have valid visibility declarations.
- Invalid visibility strings/types, duplicate declarations and malformed
  frontmatter reject the export. Quoted keys follow the same rules as bare keys.
- Missing frontmatter remains an error unless `allow_missing_frontmatter = true`
  is explicitly configured. That setting does not waive required schema fields.
- Ordinary schemas and supported wikilink/local Markdown link/image checks apply.
  Public-to-private links are allowed in this private export because both sources
  belong to this audience. Links to omitted drafts can still fail.
- Static files are copied whole only when explicitly allowlisted. Referencing a
  file never expands the list. Templates, data, raw HTML and authored text remain
  trusted inputs; this is not a content sanitizer.
- `type: private`, `publish` and vault organization helpers are not reinterpreted.

The ordinary command without an audience still [rejects private declarations](publication-visibility.md).
[`--audience public`](public-audience.md) still selects only explicit public
sources and rejects supported cross-boundary references. Building a private export
does not change either policy or make later default/public exports include private
notes. Do not relabel private information to satisfy a public build.

## Using the index and citations

The export reuses the [content-index](content-index.md), passage pairing/retention
and [authored evidence context](content-index.md#authored-evidence-context) contracts. Old and superseding
passages can both remain available. Citation bindings are not proof of truth,
recency, answer support or authenticated metadata. Output replacement by templates,
static assets or generated pages can leave indexed text without a valid final HTML
binding; consumers must retain the existing strict citation checks.

Private mode omits generated collection/site RSS and JSON feeds, feed
autodiscovery links, `sitemap.xml` and `robots.txt`, even when site feed or robots
settings say `true`. The original config and ordinary/public behavior are unchanged.
This is reduced discovery, not crawler access control. Trusted templates, authored
content and explicit static assets can still supply their own links or files.
Every retained artifact can contain private information, not just the index:
HTML, search, graph, tags, backlinks, aliases and selected assets.
This milestone adds no private server or retrieval network policy. A loopback
`base_url` labels generated links but does not confine network access or protect
files from another server.

The existing [evidence host](agent-evidence.md) accepts its own independent origin.
If you use it later, choose a trusted loopback-only server and trusted HTML. Its
browser validation may follow redirects and load subresources even with JavaScript
disabled. It is not a local-only network sandbox. This export does not start that
workflow or authorize sending private material to external services.

## API and regression coverage

The additive filesystem APIs accept `audience=Some(Audience::Private)` on `build`,
`check`, `inventory` and `inventory_with_fragments`. Build/inventory require
`fresh_output=true`; all require the explicit allowlist and content-index setting.
The API applies the same configured-public-root and base-URL guards; the caller still supplies and protects the output directory. `BuildConfig` defaults
remain unchanged. Private audience is unsupported by watch, serve, dev and stats.

Synthetic API and JS/native CLI tests exercise every configured source kind,
external collections, 404 snapshots and links, typed/quoted/duplicate visibility,
drafts, optional frontmatter, read-only previews, index collision rejection,
source/old-export preservation and byte scans across public/private switches.
No real private corpus or external inference service is part of these tests.
