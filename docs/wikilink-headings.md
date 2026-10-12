# Cross-note heading wikilinks

A wiki reference can point to a heading in another note:

```md
Read [[Beta.md#Planting & Care|care]].
```

With `beta` mapped to `/posts/beta/`, this emits
`<a href="/posts/beta/#planting-care">care</a>`. The page portion uses the existing
filename normalization, including case and optional `.md`. The heading portion
uses the same base-ID rules as rendered heading text. Supply its plain text,
or an emitted ID such as `planting-care-2` to select a numbered duplicate.
Ordinary links keep their existing URL and display behavior. A heading target
replaces any existing URL fragment while preserving a query; an empty fragment
links to the page URL without a fragment.

Graph edges, backlinks and cached reference targets use the canonical page key,
so different headings in one note still refer to that same page. Missing pages
retain the authored target and source in diagnostics: `[[Missing#Intro]]` fails
`check`, warns in `build`, and suppresses portable-renderer HTML with a wikilink
diagnostic. The change leaves those existing publication policies intact.

This resolves cross-note heading URLs using the caller's existing page index.
It does not validate whether a heading exists, introduce a heading catalog, or
infer a local page for `[[#Heading]]`. `#` denotes a fragment in wikilink syntax;
filename-to-slug conversion itself is unchanged. Frontmatter requirements and
HTML/URL trust policies are unchanged.

AI-assisted inspection reproduced the whole heading target being used as a
page key. The fix uses core `String.split_once` and shares the existing Markdown
heading-ID normalizer without changing emitted IDs. Independent fixtures prove
exact source links and target IDs, missing-page diagnostics, graph ownership,
backlinks, and incremental/full parity after removing a reference. The real CLI
fixture runs in `check-baseline.sh`; three new supplied-note comparisons run on
JavaScript, WASM GC in Node, and a real browser worker. Resolver and portable
regressions fail on the original code, and restoring the original resolver also
makes the CLI fixture fail before the fix.
