# Backtick-run inline code

Inline code opens and closes with matching complete runs of backticks. A writer
can use two or more backticks to include shorter runs as literal code content:

~~~md
Use ``[[missing]] ` literal`` and [[Beta|real]].
~~~

Only the real Beta reference is resolved or recorded in graph/backlink/cache
metadata. Wikilinks, shortcodes and other Markdown inside the code span stay
literal. Shorter or longer runs do not prematurely close a span. An unmatched
opening run stays text, and following Markdown still gets parsed. Code-content
whitespace retains the existing behavior; public AST and renderer signatures,
block-fence parsing and HTML/URL trust policies are unchanged.

Standalone callout openers inside multiline code spans retain their literal
source lines. Callouts outside a recognized code span keep their next-line
expansion behavior. Nested indentation and block boundaries determine whether
backticks form a span; an active callout whose body starts a heading can end
that nested context.

Callout preprocessing uses at most two parser passes to reconcile literal code
with active expansions. It does not reparse the document per callout, and
ordinary parsing keeps code-range collection disabled.

A manual scaling probe is available after building the JS note renderer:

```sh
node scripts/measure-callout-scaling.mjs \
  _build/js/debug/build/kurisu/lattice/examples/wasm_note/wasm_note.js
```

The probe measures synthetic notes with separated and adjacent active callouts,
code-containing bodies and a literal code footer. It reports median timings;
there are no timing thresholds in CI.
