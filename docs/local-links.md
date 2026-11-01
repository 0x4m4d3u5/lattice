# Audit ordinary local Markdown links

```sh
lattice check --local-links
lattice check --local-links --format json
lattice build --strict-local-links
```

These opt-ins validate link destinations parsed by Lattice’s Markdown renderer against the complete
publication plan. Defaults remain unchanged. `check` writes nothing; a strict
build rejects errors before writing output, cache or manifest. Strict builds
prepare every page even with a warm cache; the option also applies to watch
rebuilds. It can be combined with `--strict-wikilinks`.

Use published URLs, not paths to Markdown source files. From `/notes/source/`,
`../target/#details` means `/notes/target/#details`; `target.md` is not rewritten
into a note route. Directory destinations map to `index.html`; explicit file
URLs must name a planned file or the explicitly retained default stylesheet.
Other pre-existing output files are not accepted as current publication. Query strings do not change the file checked.

If `base_url` is `https://example.test/wiki` or `/wiki`, relative URLs resolve from
`/wiki/notes/source/`, and a root-relative link must include `/wiki/`.
`/notes/target/` is outside that publication and produces an error. Percent-encoded
UTF-8 path segments and fragments are decoded once; dot segments are normalized.
Repeated path separators, encoded separators, backslashes, control characters and malformed escapes are
rejected rather than guessing hosting-specific behavior. Fragment-only URLs
refer to the source's canonical published page.

For `.html` and `.htm` destinations, a nonempty fragment must exist in the final HTML,
including template IDs. Draft destinations are absent unless `--drafts` includes
them. If generated output or a static asset replaces a page, the replacement
owns the destination: a heading in the hidden Markdown body is insufficient.
Replaced source pages and hidden drafts are not audited. Other published sources
are audited even when a custom template omits a referring block.

Local asset links check file existence, but fragments inside PDF, SVG or other
non-HTML assets are not interpreted. Explicit schemes (including same-origin
`https:` links), protocol-relative URLs, raw HTML links, image destinations and
shortcode-generated links are outside this audit. It does not crawl the network,
follow redirects, validate external availability, infer source renames, or check
extra aliases of a page's canonical route. Custom HTML `<base>` elements are
reported as unsupported when a page has local links.

Diagnostics use `E014` / JSON kind `broken_local_link`, with the source file and
exact destination. A line/column is supplied when that spelling has one source
location; repeated spellings conservatively omit the position. Repeated links
to the same destination within a note produce one diagnostic. Run
`lattice explain E014` for a reminder of the URL contract.

This is publication validation, not an atomic filesystem replacement guarantee.
The [build safety limits](build-safety.md) still apply to I/O failures.
