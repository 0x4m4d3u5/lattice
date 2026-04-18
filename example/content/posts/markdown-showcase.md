---
title: Markdown Feature Showcase
date: 2026-04-18
description: Demonstrates math equations, definition lists, rich link text, autolinks, underscore emphasis, inline HTML passthrough, and more — every inline and block feature in the markdown engine.
tags:
  - demo
  - markdown
author: Lattice Team
---

# Markdown Feature Showcase

This post demonstrates every major markdown feature the lattice renderer supports, from syntax
highlighting to math equations. The typed AST approach means each construct maps to a distinct
`Inline` or `Block` variant — rendering is exhaustive by construction.

For the template and schema features, see [[typed-content-tour]] and [[rich-content-demo]].

## Math Equations

Inline math uses single dollar delimiters: the quadratic formula is $x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$.
Euler's identity $e^{i\pi} + 1 = 0$ is another classic.

Block math uses double dollar fences:

$$
\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}
$$

A matrix example:

$$
\mathbf{A} = \begin{pmatrix} a & b \\ c & d \end{pmatrix}, \quad \det(\mathbf{A}) = ad - bc
$$

Dollar signs in prose — like \$5 or \$USD — are not treated as math delimiters because the
parser checks for a closing `$` on the same line and rejects a `$` followed by a space.

## Definition Lists

Definition lists use the `: ` prefix syntax. Terms and definitions support full inline formatting.

TypeScript
: A typed superset of JavaScript that compiles to plain JS. Uses **structural typing** and
  supports `interface`, `type`, and `enum` declarations.

MoonBit
: A statically-typed functional language targeting WebAssembly and native. Key features:
  _pattern matching_, _algebraic data types_, and zero-cost `derive` traits.

Lattice
: A MoonBit SSG where structural violations are [type errors](https://www.moonbitlang.com/docs),
  not runtime surprises. Typed frontmatter + wikilink validation + schema-enforced collections.

## Rich Link Text

Link text is `Array[Inline]` in the AST — arbitrary inline formatting inside `[...]` renders
correctly rather than appearing as literal syntax characters.

- [**Bold link text** to the MoonBit docs](https://www.moonbitlang.com/docs)
- [_Italic link_ — template composition guide](https://www.moonbitlang.com)
- [Link with `inline code` in the text](https://mooncakes.io/docs/moonbitlang/core)
- [Mixed **bold** and _italic_ link text](https://www.moonbitlang.com/2026-scc)

## Underscore Emphasis

Underscore delimiters follow CommonMark word-boundary rules: `_foo_` is emphasis, but
`snake_case_ident` and `path/to_file.md` are treated as literals.

_Single underscore italic_ and __double underscore bold__ work as expected. Combined:
___triple underscore bold italic___ also works. Mid-word usage like
`result_type` and `is_valid_slug` pass through unchanged.

## Autolinks

Angle-bracket autolinks produce links where the display text equals the URL:

- <https://www.moonbitlang.com/2026-scc>
- <https://mooncakes.io/docs/moonbitlang/core>
- <mailto:hello@example.com>

These are distinct from both `[text](url)` links (explicit display text) and plain text
URLs, which are not automatically linked.

## Syntax Highlighting

The `@highlight` module tokenizes 15 languages. Each tokenizer is hand-written MoonBit — no
external parser library, no C FFI for this feature.

```moonbit
pub fn validate[T : Schema](value : FrontmatterValue, schema : T) -> Result[T, ValidationError] {
  match value {
    FStr(s) => schema.validate_string(s)
    FInt(n) => schema.validate_int(n)
    FDate(d) => schema.validate_date(d)
    _ => Err(TypeMismatch("unexpected variant"))
  }
}
```

```python
def count_words(text: str) -> int:
    """Count non-code words in a markdown body."""
    words = 0
    in_fence = False
    for line in text.splitlines():
        if line.startswith("```"):
            in_fence = not in_fence
        elif not in_fence:
            words += len(line.split())
    return words
```

```sql
SELECT p.title, p.date, COUNT(t.name) AS tag_count
FROM posts p
LEFT JOIN post_tags t ON t.post_id = p.id
WHERE p.draft = false
GROUP BY p.id
ORDER BY p.date DESC
LIMIT 10;
```

## HTML Block Passthrough

Author-controlled HTML passes through verbatim. Blank line terminates the block and normal
markdown resumes.

<details>
<summary>How the passthrough decision was made</summary>
In an SSG, the content directory belongs to the author — there is no untrusted input path.
Escaping author-written HTML defeats the purpose. The parser detects block-level tag openers
(<code>&lt;div&gt;</code>, <code>&lt;details&gt;</code>, <code>&lt;section&gt;</code>,
<code>&lt;!--</code>) and passes the block through to the output without modification.
</details>

Normal markdown resumes here, because the `<details>` block ended at the blank line above.

## Inline HTML Passthrough

Inline HTML tags within paragraph text pass through verbatim as `InlineHtml` AST nodes —
the same author-trust argument as HTML block passthrough, but for inline context.

Keyboard shortcuts use `<kbd>`: press <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>I</kbd> to open devtools.

Chemical formulas with `<sub>` and `<sup>`: water is H<sub>2</sub>O, and Einstein's mass-energy
equivalence is E = mc<sup>2</sup>.

<mark>Highlighted text</mark> uses the `<mark>` tag. <abbr title="Static Site Generator">SSG</abbr>
is an abbreviation with a tooltip via `<abbr title="...">`.

The `<span class="...">` tag lets authors apply custom CSS classes inline: a
<span style="font-variant: small-caps">small caps</span> style, for example.

Unlike the `HtmlBlock` case, `InlineHtml` fires mid-paragraph — when the line doesn't start
with a tag opener. A line starting with `<div>` is still an HTML block; a `<kbd>` appearing
mid-sentence is `InlineHtml`. The distinction is structural, not a configuration choice.

## Strikethrough and Task Lists

~~Strikethrough text~~ uses the GFM `~~` delimiter. Task list items render checkboxes:

- [x] Typed frontmatter schema (TString, TInt, TFloat, TDate, TEnum, TUrl, TSlug, TRef)
- [x] Wikilink resolution with backlink index
- [x] Syntax highlighting for 15 languages
- [x] Math rendering (inline $...$ and block $$...$$)
- [x] Definition lists with inline formatting
- [x] Inline HTML passthrough in paragraph context (<kbd>, <mark>, <sub>, <sup>, <abbr>)
- [ ] Reference-style link definitions (future work)

## Tables

Tables use GitHub Flavored Markdown syntax. Cell content supports inline formatting.

| Feature | AST Node | Added |
|:--------|:--------:|------:|
| Heading | `Heading(Int, Array[Inline])` | initial |
| Bold / Italic | `Bold`, `Italic`, `BoldItalic` | initial |
| Inline code | `InlineCode(String)` | initial |
| Image | `Image(String, String)` | March 16 |
| Footnote | `FootnoteRef(String)` | March 18 |
| Strikethrough | `Strikethrough(Array[Inline])` | March 17 |
| Task checkbox | `TaskCheckbox(Bool)` | March 17 |
| Math | `Math(String)`, `MathBlock(String)` | April 18 |
| Definition list | `DefinitionList(...)` | April 18 |
| Inline HTML | `InlineHtml(String)` | April 18 |

## Blockquotes

> The core design decision in lattice is that `FrontmatterValue` is an **enum**, not a raw
> string map. When we parse frontmatter from a content file, we build a typed tree. Any
> mismatch — missing required fields, type incompatibility — is caught at the schema
> validation step, before any HTML rendering begins.

Nested blockquotes:

> First level — describes the problem.
>
> > Second level — describes the solution. _Indented quoting_ mirrors how writers cite nested
> > sources in prose.

## Footnotes

Footnotes render at the bottom of the page with back-links.[^1] Multiple footnotes are supported
and they render in definition-list style.[^2]

[^1]: The renderer produces `<section class="footnotes">` with `<ol>` entries, each linking back to the in-text reference via `href="#fnref-label"`.
[^2]: Footnote definitions can contain inline formatting — **bold**, _italic_, `code`, and links all work inside footnote text.
