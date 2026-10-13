# Heading wikilinks

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

For navigation within the same note, omit the page portion:

```md
Jump to [[#Planting & Care|here]] or [[#planting-care-2]].
```

These emit `#planting-care` and `#planting-care-2` fragment URLs without a page
index entry. Use the emitted ID for numbered duplicate headings. Without a
custom display label, the original target (including `#`) remains the label.
An empty local heading such as `[[#]]` is unresolved. Local references do not
add cross-note graph edges, backlinks or cached page dependencies. When listed
on a collection index, their URLs include the owning note's path.

Graph edges, backlinks and cached reference targets use the canonical page key,
so different headings in one note still refer to that same page. Missing pages
retain the authored target and source in diagnostics: `[[Missing#Intro]]` fails
`check`, warns in `build`, and suppresses portable-renderer HTML with a wikilink
diagnostic. The change leaves those existing publication policies intact.

Cross-note heading URLs use the caller's existing page index; local headings
use a fragment URL in the current document. Resolution does not validate
whether a heading exists or introduce a heading catalog. `#` denotes a fragment
in wikilink syntax; filename-to-slug conversion itself is unchanged.
Frontmatter requirements and
HTML/URL trust policies are unchanged.
