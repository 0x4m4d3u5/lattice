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

AI-assisted inspection reproduced the single-backtick closer splitting a
multi-backtick example into empty code and an unintended missing-note link.
The fix uses bounded run counting through core iterators and scans for a closer
of the same width. Independent literal HTML/extraction regressions and the
portable renderer fail before the fix. The real CLI fixture also fails with
the original parser, then verifies a clean check, exact code HTML and unchanged
canonical graph/manifest targets after the fix. Three added supplied-note cases
run on JS, WASM GC in Node and a real browser worker.
