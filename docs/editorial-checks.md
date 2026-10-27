# Opt-in editorial checks

Frontmatter and collection schemas already enforce required metadata and field
constraints. `require_image_alt` adds one body-content convention without a new
rules language. It is disabled when omitted or explicitly false.

Add this **site-level** setting before any `[[collections]]` or `[[data]]` blocks:

```cfg
require_image_alt = true
```

`lattice check` and `lattice build` then report `E012 MissingImageAlt` for each
parsed Markdown image whose alt text is empty or consists only of whitespace:

```markdown
![](/chart.png)
![   ](/chart.png)
```

Give meaningful content images descriptive text:

```markdown
![Revenue rose steadily from January through June](/chart.png)
```

An intentionally decorative image needs empty alt text. Declare that intent
using the existing image shortcode's explicit required `alt` parameter:

```markdown
{{< image src="/ornament.png" alt="" >}}
```

This emits `alt=""` and is allowed. The shortcode's existing validation still
rejects an omitted or non-string `alt`; no new shortcode syntax is introduced.

The built-in `image` and `figure` shortcodes also participate in the opt-in check:
nonempty whitespace-only `alt` values are rejected. Use descriptive text or the
exact empty string for intentional decoration. A caption does not replace alt
text. For example, this is rejected:

```markdown
{{< figure src="/chart.png" alt="   " caption="Quarterly revenue" >}}
```

Malformed shortcode parameters retain their existing `E008 ShortcodeError` rather
than producing an alt-text violation. The policy does not trim or rewrite alt
text; valid descriptions and explicit empty decorative strings render unchanged.

## Exact scope

The check visits the same Markdown AST and footnotes used for rendering, including
images inside headings, emphasis, lists, blockquotes, tables and definition
lists. Code spans, fenced examples and math are excluded. Only image syntax
recognized by Lattice's parser (`![text](url)`), plus parsed built-in `image` and
`figure` shortcode nodes, is covered. Linked inline images such as
`[![Map](/map.png)](/full-map.png)` also participate. Reference-style image syntax is not recognized as image nodes by the
current parser.
Raw HTML, templates, other shortcode kinds and shortcode bodies, metadata images
and CSS backgrounds are outside this policy. It does not assess description quality or image availability
and is not a complete accessibility audit.

Collection documents, standalone pages and root pages use the same policy. Like
existing schema validation, it checks sources before draft publication filtering.
Repeated invalid images produce separate violations. Diagnostics identify the
source path and image URL, with JSON kind `missing_image_alt`; line and column
are absent because the current Markdown AST does not carry source spans.
`lattice explain E012` describes the policy and decorative-image convention.

A violation fails build preparation before output publication, including when
unchanged sources have cached output. Existing output, cache and manifest stay
unchanged; a failing first build creates no output directory. `check` remains
read-only. The general publication limits still apply after successful preparation:
see [build safety](build-safety.md).
