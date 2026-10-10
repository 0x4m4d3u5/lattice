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
