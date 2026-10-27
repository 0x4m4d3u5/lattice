# Build safety

`build` prepares output before publishing it. A validation or generation error
leaves the previous output directory, including cache and manifest, unchanged.
A failed first build does not create the output directory.

## Preparation and publication

1. Read sources and dependencies, build the page index, and run the existing
   build validation/rendering pipeline. Incremental cache hits still render for
   validation, although unchanged page HTML does not need to be rewritten.
2. Accumulate generated text, binary static asset snapshots, the manifest, and
   serialized cache in memory. Archive, redirect, index, feed, search, graph,
   custom 404, and asset failures participate in the same publication gate.
3. If any error diagnostics exist, discard the plan without filesystem mutation.
   An aborted build reports zero rebuilt pages/redirects and no successful-write
   messages. Fixing the inputs then permits a normal build with the previous cache.
4. Before creating directories or writing files, preflight all destination types
   and file-versus-directory conflicts within the plan. Normalize paths with
   `moonbitlang/x/path`; reject output file paths that escape the output directory.
5. Publish prepared files in order, with manifest and cache last. No source-file
   reads or template generation remain in this phase.

Warnings keep their existing policy: optional default CSS write failures warn,
and broken wikilinks still render as text in
`build`, missing per-page templates fall back, and duplicate redirects retain
ordered overwrite behavior. `check` remains stricter about wikilinks. This change
does not add new content-discovery, draft-filtering, or URL-collision policies.

## What this does not guarantee

This is a preparation gate, **not an atomic filesystem transaction**. The pinned
`moonbitlang/x/fs` API has no portable directory rename, exclusive temporary
directory creation, or symlink inspection. Staging and copying files back would
still allow partial publication while adding unsafe cleanup responsibilities.

- Disk-full errors, permission changes, or interruption during publication can
  leave partially updated output. Metadata is written last, but there is no
  rollback or crash-recovery protocol
- Filesystem-specific aliases such as newly planned case-only path differences
  on case-insensitive volumes are not detected by lexical preflight
- Concurrent writers, symlinked output paths, and filesystem changes between
  preflight and publication are outside the guarantee. Use a dedicated output
  directory with stable inputs and a single build process
- Existing stale files are not removed. This milestone neither owns nor deletes
  arbitrary files in the output directory
- Buffering uses memory proportional to the prepared generated output and static
  assets. Incremental builds still avoid rewriting unchanged page HTML, but run
  rendering to validate it

Synthetic regressions compare complete output snapshots, including binary assets,
cache, and manifest; cover initial failure, late generation failure, destination
conflicts, and recovery; and retain warning-only and incremental-build coverage.
See [the pinned baseline instructions](reliability-baseline.md#reproduce) to run
check, all tests, build, and the vendored parser tests.

## Incremental backlink removal — 2026-10-10

An unchanged collection page must be rebuilt when a referring collection source
disappears. Previously, backlink invalidation only visited current sources, so a
deleted page's old backlink remained in its target's cached HTML. Compare the
previous manifest with the current source set and invalidate the removed source's
recorded link targets. Dependency entries have no output path and are excluded.
This also handles a source renamed away from its original path. It does not remove
the old generated page or change the stale-output policy above.

AI-assisted inspection identified this missing invalidation case. A synthetic
regression verifies an initial backlink, cache hits before deletion, removal of
the backlink after deletion, an unrelated page's cache hit, and restored cache
hits on the following build. Review regressions also cover a renamed referrer
with different old/new targets and deletion of a draft with either draft
publication flag. They directly verify removal of the old manifest source entry
and subsequent cache reuse. The later draft-visibility fix below makes backlink
indexing follow the publication flag.

Linux validation with the pinned WASM compiler `0.10.14+7d59c7ec9`, Moon
`760759ca`, and the JavaScript target: the new regression fails before the fix
because the old backlink remains, then passes after it. `check-baseline.sh`
passes check, all 1,283 project tests, build, and all 15 vendored parser tests.
Existing compiler warnings remain. `git diff --check` and shell syntax checks
pass. The optional builder formatter check reports existing differences outside
the edited function; the edited function and regression file match formatter
output. No Mac run, output cleanup, or atomic disk-failure guarantee is added.

## Dedicated 404 template selection — 2026-10-11

The 404 renderer documented `404.html` → `page.html` → built-in HTML priority,
but selected only the generic page template. AI-assisted inspection noticed the
disagreement, and synthetic builds confirmed that a dedicated error template was
ignored, including malformed templates that should have failed the build.

Load `templates/404.html` through the existing template loader during 404
preparation. This preserves include/layout resolution and the configured template
directory. Only a missing dedicated file falls back to the generic template;
read, parse, and render errors participate in the existing publication gate.
No template subsystem redesign or cleanup policy is introduced.

Repository review identified that `check` also needs to validate this selected
template. When a dedicated 404 template exists, lint now invokes the same loader
and renderer, reporting template violations at that file without publishing any
output. Regression assertions reject parse errors and missing data in both
commands and verify that valid authored/default templates pass read-only checks.
The check regression fails before this validation is added and passes afterward.

Regressions cover dedicated-template priority with authored and default error
content, include resolution, unchanged ordinary page rendering, both missing-file
fallbacks, and full output/cache/manifest preservation after selected-template
parse or render errors. Before the fix, two regressions fail and the fallback
regression passes; after the fix all three pass.

The pinned Linux JavaScript baseline passes check, all 1,286 project tests, build,
and all 15 vendored parser tests. Shell syntax and `git diff --check` pass. The
edited function and regression file match the pinned formatter output; unrelated
existing builder formatting differences and compiler warnings remain.

## Draft visibility

By default, `draft: true` excludes collection, standalone, and root pages from
new page writes, redirects, backlinks, previous/next navigation, and generated
indexes. Tags found only on hidden drafts do not create tag pages or tag-index
entries. A draft `content/404.md` uses the usual default error content.
`--drafts` includes these pages and their derived entries.

Source validation and slug ownership still cover all discovered sources. Tags
unique to hidden drafts remain valid during validation, and authored wikilinks
still resolve against the complete source catalog. Cache and manifest metadata
can contain draft sources; static files are copied wholesale. Existing output
files are retained, so switching off `--drafts` in an existing output directory
does not remove previously emitted draft pages, aliases, redirects, or tag pages.
Use a fresh output directory when you need to verify what a build emits.

AI-assisted inspection traced the inconsistent behavior to full-source catalogs
used by publication derivations. The fix keeps those validation catalogs and
uses a separate visible URL/tag selection for publication. Literal synthetic
fixtures cover page kinds, redirect paths, backlinks, navigation, tags, feeds,
sitemap, graph, root aliases, and the `--drafts` control. Cache regressions toggle
both frontmatter and the flag and compare rendered output with forced builds,
while explicitly checking retained old files. Existing rendered-HTML
fingerprints invalidate affected pages without a cache-format change.

## Unique referring-note backlinks

A backlink lists each visible referring note once per destination page. Repeated
citations, aliases, filename/case variants and different heading fragments in
the same destination do not repeat the referring note. Distinct referring notes
remain separate even when their titles match. Outgoing links in the source HTML
and collection-index graph remain unchanged.

AI-assisted inspection reproduced two identical Garden backlinks from two
heading links to Beta in the existing CLI fixture. The backlink index now
records canonical destination keys already seen within each source, preserving
first-seen ordering and the existing visible-source/target filter. A literal
rendered-section regression covers distinct same-title notes, and the real CLI
fixture asserts exactly one backlink for its two heading citations. Both fail
before the fix. Existing incremental and forced-build comparisons still verify
removal of backlinks when the referring note stops linking to the destination.
