# Content index for knowledge retrieval

Enable the full-text JSON output in `site.cfg`:

```cfg
content_index_file = content-index.json
```

After `lattice build`, the output directory contains an array of entries with
`title`, `slug`, `url`, `tags`, `collection`, `date`, `description`, `kind`,
`reading_time` and `body`. Use `url` to link a retrieved result back to its page.
The body covers the rendered content, while `search-index.json` carries an
excerpt. These files supply data for a retrieval tool; they do not implement a
search engine or embeddings.

The `tags` arrays in both JSON indexes include validated frontmatter tags for
collection members, root pages and standalone pages. The configured
`tags_field` applies to all of them. Values follow the existing tag extractor's
trimming and deduplication rules, preserving display spelling and order. A
retrieval tool can filter either index by those values. Generated tag pages include
published collection members, root pages and standalone pages.

Built content entries also include `headings`, an array of Markdown section
headings (levels 2–6) in document order. Each object contains `level`, `id` and plain `text`. Form a
Markdown-body citation by appending `#` and `id` to the entry's `url`, but only
when the template preserves that heading. For verified published passage targets,
use the optional `sections[].fragment` described in [section search](section-search.md).
Do not regenerate IDs from text: duplicate headings receive numbered IDs. The catalog includes nested list and blockquote headings and is
independent of the page's `toc` and `toc_depth` settings.

These headings describe the Markdown body, including on cache-hit rebuilds.
Level-1 headings reserve IDs but are omitted, matching the renderer's TOC.
Raw HTML headings and template-generated headings are outside the catalog;
templates may omit body headings from the final page. Generated collection
indexes have an empty catalog. Authored entries sharing a generated index's URL
also have an empty catalog, because the index overwrites that page's HTML.
This suppresses heading metadata only; duplicate entries and the existing
collision policy remain unchanged. This metadata does not validate heading links.
Library consumers can opt into the same field using
`render_content_index_with_headings(entries, headings_by_url)`; the ordinary
`render_content_index` function and `ContentEntry` constructor stay unchanged.

Built entries include `links`, resolved outgoing wikilinks in parser traversal
order: body links (including nested blocks) first, then links in parsed footnote
definitions in definition order, regardless of where those definitions occur
in source. Repeated references are retained. Each record has the authored `target`, the
resolved `url` (including heading fragments) and rendered label `text`.
Same-note links include the owning page's URL, so a retrieval tool can follow
them without the original page as its browser context. Code examples and
unresolved references are excluded. Generated indexes and entries overwritten
at their URLs have empty link arrays, matching heading-catalog suppression.
Built indexes also suppress both catalogs when later prepared output replaces
an authored page, including tag pages, archive pages and copied assets. Source
body text and duplicate records remain present; only navigation is suppressed.
An overwritten collection page is republished if the generator disappears,
so restored catalogs describe the restored authored HTML. Routing and existing
overwrite policy stay unchanged.

These records describe authored wikilinks, not ordinary Markdown links, raw
HTML anchors or template navigation. Resolution checks the existing page index;
it does not validate heading existence or guarantee the target is published
(for example, a link may resolve to a hidden draft). Existing publication and
trust policies remain unchanged. Library consumers can opt into both catalogs
with `render_content_index_with_navigation(entries, headings_by_url, links_by_url)`.

Body extraction removes tags, decodes basic entities and collapses whitespace.
Tag boundaries respect single- and double-quoted attributes, so an attribute's
`>` does not introduce metadata into body text. Outside text elements,
standard `<!-- ... -->` comments are omitted without separating adjacent words.
An unclosed comment
omits the remaining text; an unclosed quoted tag also omits its remaining text.
Escaped comment markup stays literal because entity decoding follows stripping.
Inside `textarea`, `title`, `script`, `style`, `xmp`, `iframe`, `noembed` and
`noframes`, markup and comment markers stay literal until a matching closing
tag. Closing names are case-insensitive and require a tag-name boundary, so
`</stylex>` does not close `style`. Following page text resumes after the close.
Basic entity decoding still applies to all collected text; this is not full
HTML tokenizer or script parsing behavior. Script/style text remains indexed.

Decimal and hexadecimal numeric references in raw HTML text decode to Unicode:
`<div>10&#176;C and &#x1F331;</div>` contributes `10°C and 🌱`. References require
a semicolon and a nonzero Unicode scalar value. Malformed, zero, surrogate,
out-of-range and overflowing references remain literal. Decoding happens once:
`&amp;#176;` contributes the literal text `&#176;`. Decoded angle brackets remain
text, and decoded ASCII spaces, tabs and line breaks collapse like authored
whitespace. Named decoding is limited to `amp`, `lt`, `gt`, `quot` and `apos`;
this does not implement the full HTML entity table or browser error recovery.

Text-bearing phrasing tags preserve adjacency: `a`, `strong`, `em`, `del`,
`code`, `span`, `sub`, `sup`, `mark`, `abbr`, `kbd`, `b`, `i`, `u`, `s`, `small`,
`cite`, `q`, `dfn`, `data`, `time`, `var`, `samp`, `bdi`, `bdo`, `ruby`, `rt`,
`rp`, `ins`, `label` and `output`. The optional word-break tag `wbr` also
preserves adjacency. For example, `photo**syn**thesis` becomes `photosynthesis`,
`H<sub>2</sub>O` becomes `H2O`, and `<kbd>Ctrl</kbd>+<kbd>C</kbd>` becomes
`Ctrl+C`. Other tags create separators, including paragraph, list, table and
line-break boundaries. Authored spaces around inline markup remain spaces.
The same extraction applies when a page is reused from cache.

This is a simple text extractor, not a complete HTML parser or sanitizer.
Unknown tags create separators, image attributes are not body text, and raw
script/style text is not filtered. The index is generated site content;
draft filtering and vault metadata are not access controls or a privacy boundary.

Run `bash scripts/check-baseline.sh` with the repository-pinned toolchain to
check the CLI's content index alongside rendered pages and link metadata.
