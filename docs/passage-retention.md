# Passage retention

Each authored content-index section may contain an optional `retention` object:

```json
{"version":1,"algorithm":"sha256","start":120,"end":245,
 "digest":"<64 lowercase hex characters>",
 "heading_digest":"<64 lowercase hex characters>",
 "body_digest":"<64 lowercase hex characters>"}
```

`start` and `end` form a half-open byte range in the final canonical HTML's UTF-8
encoding. `digest` covers those exact bytes; the other digests cover the UTF-8
encoding of the section's indexed `heading` and `body` strings separately. The
range includes the complete renderer-owned section, including its heading when
present. Preambles and generated footnotes can have ranges without fragments.

The renderer records complete ranges in the same pass that extracts indexed
text. Unfiltered template emissions carry ranges through includes, conditionals,
loops and layouts. An omitted range, repeated emission, filtered emission or
partially removed leading H1 does not acquire a binding. A surviving copy does
not rescue a second transformed or invalidated copy. Tracking uses origins, not
a search for equal text in template output.

Head injection, backlink shortcuts, contextual backlinks, related notes and
local graph substitutions update ranges: edits wholly before a range shift it;
edits overlapping any part invalidate the whole range. An insertion at its start
shifts it and an insertion at its end leaves it unchanged. Complete origins are
converted to byte offsets only after final ownership and substitutions. Generated
or static replacements do not inherit authored bindings. Cached and forced builds
produce the same metadata. No markers are added to HTML or the cache format.

The [agent evidence host](../examples/agent_evidence/evidence.mjs) reports
`retention` independently of citation-address `status` and artifact `pairing`:

| Status | Meaning |
| --- | --- |
| `matched` | The response slice and indexed heading/body match all three bindings. |
| `mismatched` | Bytes or indexed text differ, or the response no longer supports the range. |
| `unknown` | No binding, unsupported version/algorithm, or no host comparison. |
| `invalid` | Malformed supported binding or indexed text. |

The host uses the same fetched response bytes as publication pairing, checks
bounds and UTF-8 boundaries, and compares both text digests. The example CLI
fails for mismatched/invalid retention as it does for mismatched/invalid pairing.
Existing indexes remain usable and report unknown retention. A template omitting
the body may artifact-match while its sections have unknown retention.

**This is publisher-origin byte retention, not browser visibility or truth.**
Verbatim text inside a comment, script, hidden element or inert template can
retain its bytes. Retention does not assert DOM placement, visible text,
accessibility, freshness, authenticity, factual correctness or relevance to a
question. The index is trusted to bind its text to the renderer-owned slice;
the host does not re-extract text from HTML. Changing indexed text and its matching
text digest together can still report `matched` even if HTML is unchanged. Both
the index and HTML can also be altered together. Address validation
and artifact pairing retain their separate meanings.

Run `node scripts/check-passage-retention.mjs` after building the JS CLI, or set
`LATTICE_NATIVE_CLI` to the native CLI executable. The fixture exercises exact
Unicode bytes, cache parity, layouts, duplicates, omission, transformations,
substitution overlap, final ownership, failure preservation and host outcomes.
