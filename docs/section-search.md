# Local section search

For a ready-to-publish interface, use the [wiki search page](wiki-search-page.md).
For an executable agent-host example, see [retrieval, evidence and published citations](agent-evidence.md).

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
Duplicate headings retain separate positions. A section may also have a
`fragment` string when its originating Markdown heading survives publication
with a unique HTML ID. Preambles and generated footnotes have no fragment.
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
    "fragment": "recovery-drills",
    "snippet": "Restore a backup into an isolated cluster.",
    "score": 12
  }],
  "error": null
}
```

`section_index` is zero-based within that page. `url` remains the canonical
**page URL**, preserving existing consumers and ranking. Results optionally
include `fragment` copied from the matching indexed section. The bundled reader
appends a URL-encoded fragment to the title link; without it, navigation remains
page-only. A heading label or TOC position is never used to guess a target.

The publisher tracks top-level heading offsets in the Markdown rendering pass
and carries them through verbatim template slots, includes and layouts. It checks
actual HTML start tags and ID uniqueness, then applies final output ownership.
Removed leading H1s, omitted/transformed content, comments, raw-text/inert template
content, duplicate/uncertain IDs and generated/static replacements do not acquire targets.
Nested headings still consume duplicate-ID numbers without becoming sections.
Fresh, cached and forced builds use the same provenance. No marker attributes are
added to published HTML and no cache format changes are needed.

Old indexes, absent/empty/non-string fragments, and ambiguous duplicate URL records
retain page-only results. Caller-supplied indexes must supply valid published
URLs and fragment IDs; retrieval does not verify them online.

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

All distinct query terms must occur in the page title, section heading, that
section's body or an enabled alternate name. Matching uses ASCII case folding
and splits on ASCII punctuation,
whitespace and control characters. Other Unicode text stays intact; there is no
stemming, accent folding or language-specific segmentation. Each term scores 12
for a heading match, 6 for a title match, and 1 plus body frequency capped at 3
for a body match. Scores add across fields; repeated query terms do not add
weight. Equal scores sort by URL, then section order. Required tags are exact
ASCII case-insensitive AND filters, with surrounding filter whitespace ignored.

With `wikilink_aliases = true`, retained authored pages also carry an optional
`aliases` array in the content index. The bundled search and portable engine use
these names while displaying canonical titles and URLs. Alias-only term matches
score 3; an alias never boosts a term already found in the title, heading or body.
A query fully satisfied by alternate names and the title adds at most one fallback
hit at the first section, and only when no ordinary passage matches. Queries that
combine an alternate name with passage text can return multiple relevant sections.
Duplicate declarations do not create duplicate documents or increase scores.

Aliases remain absent when the option is disabled, for hidden drafts, generated
pages, overwritten sources and entries without searchable sections. Existing
indexes and typed `SearchDocument` constructors remain compatible; typed callers
can supply the optional `aliases` map keyed by canonical URL to `retrieve_sections`.
Malformed alias arrays fail the JSON request, and ambiguous duplicate URL records
ignore alias metadata. Matching follows the same lexical rules as ordinary text,
not the wikilink resolver's filename normalization. The excerpt-only
`search-index.json` format is unchanged.

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

## Repeated queries with one prepared index

The bundled reader uses a separate prepared-search WASM runtime. It parses the
index and computes term frequencies once, then reuses them for queries. Ranking,
filters, snippets and citation addresses match stateless search. This trades
initial preparation and retained memory proportional to the supplied index for
less repeated work; it does not keep query or result history.

MoonBit consumers can call `@search.prepare_search(index_json)` and, on success,
`prepared.search(query, tags_json, limit)`. A prepared value owns its decoded
strings and private frequency maps. Drop it when the index is no longer needed.
The existing `search_content` function and note-renderer exports remain unchanged.

After `bash scripts/check-wasm-note.sh`, JavaScript hosts can instantiate
`examples/prepared_search/host.mjs` with the separately built
`examples/prepared_search/prepared_search.wasm` artifact. Its
`createPreparedSearcher(bytes)` returns `replace(index_json)`,
`search(query, tags_json, limit)` and `clear()`. Each instance owns one index.
Replacement clears the old index **before** validating the new one; malformed
replacement leaves queries unavailable, never silently using stale content.
`clear()` is idempotent. Discard the runtime (or terminate its worker) to release
all instance state. There is no fixed byte quota: hosts handling untrusted or
very large indexes should enforce their own input-size limit before preparation.

The reader invalidates its current runtime when loading another index and ignores
superseded asynchronous loads. A new page/worker must prepare again. This is not
an across-page cache, and preparation does not verify indexed claims against
published HTML or establish factual truth.
