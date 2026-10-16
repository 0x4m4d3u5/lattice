# Local section search

For a ready-to-publish interface, use the [wiki search page](wiki-search-page.md).

Enable `content_index_file = content-index.json` in `site.cfg`. Builds add a
`sections` array to each content-index entry alongside the existing body,
headings and links. Each section has `heading` and rendered plaintext `body`.
Top-level Markdown headings start sections; prose before the first heading has
an empty heading. Nested headings stay with their enclosing section, and fenced
examples do not split sections. Boundaries must start and end outside the
whole-document extractor's comment, quoted-tag and raw-text states; headings
inside those states stay within their enclosing passage rather than becoming
section labels. This preserves existing whole-body extraction semantics and
is not a browser visibility policy or sanitizer. Visible appended footnote
definitions form a generated passage labeled `Footnotes`, cited at the page URL.
Duplicate headings retain separate positions.
Generated navigation pages and sources superseded by generated output have an
empty sections array and are excluded from retrieval.

MoonBit consumers can call `@search.retrieve_sections` with typed
`SearchDocument` values, or `@search.search_content(index_json, query, tags_json,
limit)` directly with an emitted index. The latter returns JSON:

```json
{
  "results": [{
    "title": "Operations handbook",
    "url": "/wiki/ops/",
    "tags": ["Reliability", "Database"],
    "section": "Recovery drills",
    "section_index": 2,
    "snippet": "Restore a backup into an isolated cluster.",
    "score": 12
  }],
  "error": null
}
```

`section_index` is zero-based within that page. Citations use the canonical
**page URL**, without inventing heading fragments: templates can omit headings
or their IDs. The section name and snippet identify the passage. Caller-supplied
indexes must supply valid published URLs; retrieval does not verify URLs online.

The portable example exports `search_content` alongside `render_note` on JS and
WASM GC. After `bash scripts/check-wasm-note.sh`, a JS host can use:

```js
import { search_content } from '../_build/js/debug/build/kurisu/lattice/examples/wasm_note/wasm_note.js';
const answer = JSON.parse(search_content(indexJson, 'restore checksums', '["Database"]', 10));
```

For WASM, `createContentSearcher(bytes)` in `examples/wasm_note/host.mjs` returns
`search(indexJson, query, tagsJson = '[]', limit = 10)`. Use
`createNoteRuntime(bytes)` to share one instance between `renderNote` and
`searchContent`. The existing `createNoteRenderer` interface remains callable.
The WASM host validates string arguments and a signed 32-bit integer limit.

All distinct query terms must occur in the page title, section heading or that
section's body. Matching uses ASCII case folding and splits on ASCII punctuation,
whitespace and control characters. Other Unicode text stays intact; there is no
stemming, accent folding or language-specific segmentation. Each term scores 12
for a heading match, 6 for a title match, and 1 plus body frequency capped at 3
for a body match. Scores add across fields; repeated query terms do not add
weight. Equal scores sort by URL, then section order. Required tags are exact
ASCII case-insensitive AND filters, with surrounding filter whitespace ignored.

Results include plaintext snippets of up to 240 Unicode scalars plus ellipses,
starting near the earliest body query occurrence when possible. Empty queries
and nonpositive limits return no results. Limits cap at 50. Invalid JSON or
malformed entries return no results and a non-null `error`. Older content indexes
without `sections` fall back to one body-sized section per page; explicit empty
sections never fall back. Search scans the supplied text locally, without a
network service, embeddings or persistent state.

The content index follows existing draft inclusion (`--drafts`) and publishing
rules. This is not a private-vault export filter: review what you publish,
including templates, copied assets and previously generated output. Treat
snippets as text when displaying them in a browser.
