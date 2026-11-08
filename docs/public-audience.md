# Select explicit public sources

`--audience public` opts into a source-selection policy for configured Markdown
collections, standalone pages, root pages and the dedicated `404.md`. Only a
source with exactly `visibility: public` may enter the publishing pipeline.
Missing visibility and `visibility: private` are excluded before page names,
aliases, tags, backlinks, related notes, graph edges or indexes are derived.

This is a source boundary, not a general private-information detector. Review
[the trusted publication inputs and limits](#trusted-publication-inputs) before
using it with a mixed source tree. The default commands still use the
[public-only guard](publication-visibility.md); this policy is never inferred.

## Use a new release directory

Set an explicit attachment allowlist in the site configuration. An empty list is
valid when the release has no static files:

```cfg
static_allowlist = ["diagram.png", "styles/reader.css"]
content_index_file = content-index.json
```

Mark each intended public source:

```yaml
---
title: Public field notes
visibility: public
---
Only information intended for publication belongs here.
```

Then check, inspect and build the same unused destination:

```sh
lattice check content -c site.cfg -o releases/public-001 --audience public --format json
lattice inventory content -c site.cfg -o releases/public-001 --audience public --fresh-output --format json
lattice build content -c site.cfg -o releases/public-001 --audience public --fresh-output
```

The `build` and `inventory` commands require `--fresh-output`. Public `check`
uses that same fresh plan internally without writing anything, so its destination
must also be unused and separate from the configured input trees. A successful
build consumes the destination name. Choose another unused path for the next
check or release, rather than checking into a directory already built.

The allowlist must be present, even when it is `[]`. A public reference never
expands it. Allowlisting a file means publishing its entire contents; it is not
content sanitization or automatic attachment classification.

Use `--audience public` once, with the option and value as separate arguments.
Other audience values, repeated options and `--audience=...` are rejected. This
mode is not supported by watch, serve, dev, stats or scaffold commands. A private
memory-view audience is not implemented.

## Selection and validation

- Missing visibility is excluded in this mode. This differs deliberately from
  the compatibility default, where missing visibility remains publishable.
- Invalid types, invalid strings, duplicate declarations and malformed
  frontmatter fail closed. They do not become harmless just because the source
  would otherwise be excluded.
- `draft` still means unfinished. `--drafts` may include an explicitly public
  draft, but never includes a private or unlabelled source.
- `type: private`, `publish` and organizational vault helpers do not grant or
  revoke publication. There is one source-selection field: `visibility`.
- Schema and ordinary document validation apply to selected sources. This public
  projection is not a full lint pass over excluded private notes.
- A private or unlabelled `404.md` uses a generic fallback. Its body, title,
  description and image references are not used by the public renderer.
- Parsed wikilinks, ordinary local Markdown links/image destinations and typed
  schema references are checked without needing the optional strict-link flags. A reference to an excluded note cannot be made
  valid by placing an unrelated generated page, redirect or static file at the
  same destination. Ambiguous cross-boundary names or routes can block planning.

Source-derived content and metadata come only from selected sources: page bodies,
search/content entries, aliases, redirects, graph data, feeds, tags, archives and
backlink/related-note context. Excluded sources do not create hidden graph nodes,
search excerpts or backlink counts. Public sources that are later overwritten by
another output writer can retain their existing search/index representation;
source selection is not a promise that every exported public excerpt occurs in
the final HTML.

`inventory` reports source exclusions and withheld static paths as local audit
information. Its JSON and command diagnostics can reveal private paths. Do not
publish those reports or logs with the site. Deployable output omits generated
`.lattice-cache` and `.lattice-manifest.json` metadata.

## Trusted publication inputs

The boundary prevents automatically deriving public artifacts from excluded
Markdown. It does **not** recognize private facts copied into a selected public
note or another explicitly public input.

Site configuration, collection descriptions, templates and includes, data files,
selected static files, and the complete text of selected public sources remain
trusted publication inputs. Keep private content out of them. In particular:

- Raw HTML, CSS URLs/imports, scripts, shortcode bodies, template literals and
  data slots are not covered by the ordinary parsed-Markdown reference audit.
- Explicit-scheme and protocol-relative URLs, including absolute same-origin
  links, are outside that local URL audit. Review them separately.
- A public label can itself disclose information even if its target is external.
  The builder cannot decide whether that authored information is appropriate.
- An allowlisted Markdown, HTML or binary file is copied whole. It does not
  inherit the visibility of any note that references it.
- Template includes and data loading are trusted authoring mechanisms, not an
  operating-system sandbox for an untrusted template author.

Use stable trusted trees with no symlinks, filesystem aliases or concurrent
writers. Fresh-output isolation is lexical, not a physical-filesystem sandbox.
A validation/generation failure creates no output. A publication I/O failure can
leave a partial directory that must not be deployed; retry with another new path.

This mode does not delete old outputs, withdraw a deployed private file, or deploy
a release. Replace the served file set explicitly instead of overlaying new files
onto old ones. See [fresh output](fresh-output.md) for those limits. A complete
mixed-vault safety claim still needs broader reference/resource policy and an
explicit deployment replacement workflow.

## API and implementation decision

The additive filesystem APIs accept `audience=Some(Audience::Public)` on `build`,
`check`, `inventory` and `inventory_with_fragments`. Build and inventory also need
`fresh_output=true`. Omitting the audience preserves existing behavior and keeps
`BuildConfig` unchanged. Supplied-text rendering APIs remain host-controlled.

AI-assisted implementation uses early source projection rather than changing the
draft predicate. Filtering after rendering would leave private names and text in
aliases, tags, search excerpts or other derived structures. The public 404 uses a
selected snapshot, and excluded identities are kept only for validation, never
as renderer input. Synthetic JS/native fixtures scan every emitted byte and path
for private canaries and exercise rejected references, draft policy, 404 handling,
invalid metadata, input preservation and read-only preview parity.
