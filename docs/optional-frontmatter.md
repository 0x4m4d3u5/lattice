# Optional frontmatter ingestion

Markdown sources require YAML (`---`) or TOML (`+++`) frontmatter by default.
For a filesystem project that deliberately accepts body-only notes, set this
site configuration key:

```ini
allow_missing_frontmatter = true
```

**This is not a privacy setting. Ordinary builds treat missing visibility as
public. Enabling this option can make unlabelled, body-only notes publishable
when their collection schema allows empty metadata.** Do not enable it on an
unreviewed vault. To export a mixed tree, use the separate `--audience public`
workflow, which requires exact `visibility: public`, fresh output and an explicit
static allowlist. Headerless notes have missing visibility and are excluded
before indexes, links, search, graphs, tags and rendering are derived. References
to their denied identities still fail, even if another route or asset could mask
them. See [public audience exports](public-audience.md).

## Parsing and schemas

The option applies consistently to filesystem `check`, `build`, `inventory`,
statistics and their scanners. A source without a recognized leading header
becomes an empty metadata map plus its original body. The existing leading BOM
normalization applies; whitespace, CRLF and line positions are otherwise retained.
Nothing is written back to sources and no title, visibility, type or draft value
is inferred from filenames, headings or body text.

A leading `---` or `+++` prefix still goes through the existing strict parser.
Malformed metadata, duplicate visibility, or a missing closing delimiter remain
errors and never fall back to body-only Markdown. Consequently a leading Markdown
thematic break using `---` remains ambiguous: it is interpreted as a frontmatter
opener, just as before. Use another thematic-break spelling such as `***` when
that is the intended body text. Opening-prefix recognition itself is unchanged.

All schemas still apply. Optional fields can be absent; required fields report
`missing_required_field` in JSON without an invented field location. Unknown-field,
type and duplicate policies are unchanged. Empty documents are subject to the
same schema checks. Collections retain the existing `Untitled` display fallback;
standalone and root pages retain their required-title schemas. Custom `404.md`
keeps its existing special renderer: accepted empty metadata uses `Untitled` and
`Page not found` description, without adding a required-title schema. An absent,
excluded or draft-hidden custom 404 keeps the generated `Page Not Found` fallback.

Changing the effective ingestion policy invalidates incremental dependencies,
including API configurations changed without editing the config file.

## API compatibility

`frontmatter.parse`, `parse_yaml` and `parse_toml` remain strict. The additive
`parse_with_policy(content, allow_missing_frontmatter=true)` API is for callers
that explicitly select this behavior. `BuildConfig` is unchanged; its typed
`SiteConfig` carries the optional setting. The portable `render_note` interface
and default are unchanged, with no new JavaScript/WASM exports.
