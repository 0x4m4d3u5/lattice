///|
/// Markdown renderer for lattice.
///
/// Converts a markdown body string to HTML. The renderer is pure — it takes
/// a resolved wikilink index (target slug → url) rather than resolving links
/// itself. Structural guarantee: broken wikilinks are surfaced as build errors
/// before this function runs; the renderer only sees resolved targets.
///
/// Supported inline elements:
///   **bold**, *italic*, ***bold+italic***, `inline code`,
///   [rich text](url) — link text is parsed as inline markdown,
///   [[wikilink]], [[wikilink|display]]
///
/// Supported block elements:
///   # Headings (h1–h6), paragraphs, ```fenced code```,
///   > blockquotes, - unordered lists, 1. ordered lists, --- hrule

///|
/// An inline element in the markdown AST.
pub enum Inline {
  Text(String)
  Bold(Array[Inline])
  Italic(Array[Inline])
  BoldItalic(Array[Inline])
  Strikethrough(Array[Inline])
  InlineCode(String)
  Link(Array[Inline], String) // display inlines, url
  Image(String, String) // alt text, url
  WikiRef(String, String?) // target slug, optional display text
  FootnoteRef(String) // footnote label
  Shortcode(@shortcode.ShortcodeCall)
  Math(String) // inline math: $...$, content is LaTeX source
  InlineHtml(String) // raw inline HTML tag — emitted verbatim, not escaped
  HardBreak
}

///|
/// A footnote definition collected during parsing.
pub struct FootnoteDef {
  label : String
  text : String
}

///|
/// Column alignment for a GFM table column.
pub enum ColAlign {
  AlignLeft
  AlignCenter
  AlignRight
  AlignDefault
}

///|
/// A block element in the markdown AST.

///|
/// A list item that can contain inline content and nested blocks.
pub(all) struct ListItem {
  inlines : Array[Inline]
  children : Array[Block]
}

///|
/// A block element in the markdown AST.
pub enum Block {
  Heading(Int, Array[Inline])
  Paragraph(Array[Inline])
  FencedCode(String?, String) // optional language tag, code text
  BlockQuote(Array[Block])
  UnorderedList(Array[ListItem]) // each item can have nested blocks
  OrderedList(Array[ListItem]) // each item can have nested blocks
  HRule
  // GFM table: column alignments, header cells, data rows.
  // Each cell is an Array[Inline] so inline formatting works inside cells.
  Table(Array[ColAlign], Array[Array[Inline]], Array[Array[Array[Inline]]])
  // Definition list: each entry is (term inlines, list of definition inlines).
  // Using Array[Inline] for both term and definitions ensures inline formatting
  // (**bold**, `code`, links) is fully supported — consistent with Heading,
  // Paragraph, ListItem, and Table, all of which already use Array[Inline].
  DefinitionList(Array[(Array[Inline], Array[Array[Inline]])])
  MathBlock(String) // display math: $$...$$, content is LaTeX source
  HtmlBlock(String) // raw HTML block — emitted verbatim, not escaped
}

///|
pub struct TocEntry {
  level : Int
  anchor : String
  text : String
}

///|
pub fn parse_blocks(ls : Array[String]) -> Array[Block] {
  let (blocks, _footnotes) = parse_blocks_with_footnotes(ls)
  blocks
}

///|
pub struct ShortcodeIssue {
  call : @shortcode.ShortcodeCall?
  error : @shortcode.ShortcodeError
}

///|
pub struct RenderResult {
  html : String
  shortcode_errors : Array[ShortcodeIssue]
  toc : Array[TocEntry]
  footnotes : Array[FootnoteDef]
}

// ── character helpers ─────────────────────────────────────────────────────────

// MoonBit: s[i] returns UInt16 (UTF-16 code unit), not Char.
// Use this helper for all character access so comparisons against char
// literals type-check correctly.

///|
pub fn is_blank(s : String) -> Bool {
  @strutil.trim(s).length() == 0
}
// ── line splitting ────────────────────────────────────────────────────────────

///|
fn lines_of(s : String) -> Array[String] {
  let result : Array[String] = []
  let n = s.length()
  let mut i = 0
  while i <= n {
    let mut end = i
    while end < n && @strutil.char_at(s, end) != '\n' {
      end = end + 1
    }
    result.push(@strutil.substr(s, i, end))
    if end >= n {
      break
    }
    i = end + 1
  }
  result
}
// ── HTML escaping ─────────────────────────────────────────────────────────────

///|
fn is_ascii_alnum(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')
}

///|
fn slugify_heading_text(text : String) -> String {
  let trimmed = @strutil.trim(text)
  if trimmed.length() == 0 {
    return "section"
  }
  let buf = StringBuilder::new()
  let mut wrote_dash = false
  let mut wrote_any = false
  let mut i = 0
  while i < trimmed.length() {
    let lower = @strutil.ascii_lower_char(@strutil.char_at(trimmed, i))
    if is_ascii_alnum(lower) {
      buf.write_char(lower)
      wrote_any = true
      wrote_dash = false
    } else if wrote_any && !wrote_dash {
      buf.write_char('-')
      wrote_dash = true
    }
    i = i + 1
  }
  let slug = buf.to_string()
  if slug.length() == 0 {
    return "section"
  }
  if @strutil.char_at(slug, slug.length() - 1) == '-' {
    @strutil.substr(slug, 0, slug.length() - 1)
  } else {
    slug
  }
}

///|
pub fn plain_text_inline(inline : Inline) -> String {
  match inline {
    Text(t) => t
    Bold(inner) => plain_text_inlines(inner)
    Italic(inner) => plain_text_inlines(inner)
    BoldItalic(inner) => plain_text_inlines(inner)
    Strikethrough(inner) => plain_text_inlines(inner)
    InlineCode(code) => code
    Link(inlines, _) => plain_text_inlines(inlines)
    Image(alt, _) => alt
    WikiRef(target, display) =>
      match display {
        Some(text) => text
        None => target
      }
    FootnoteRef(_) => ""
    Shortcode(_) => ""
    Math(_) => "" // math is opaque, not meaningful as plain text
    InlineHtml(_) => "" // raw HTML tags are opaque to plain-text consumers
    HardBreak => " "
  }
}

///|
pub fn plain_text_inlines(inlines : Array[Inline]) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  while i < inlines.length() {
    buf.write_string(plain_text_inline(inlines[i]))
    i = i + 1
  }
  @strutil.trim(buf.to_string())
}

///|
fn next_heading_anchor(text : String, counts : Map[String, Int]) -> String {
  let base = slugify_heading_text(text)
  let next = match counts.get(base) {
    Some(n) => n + 1
    None => 1
  }
  counts.set(base, next)
  if next == 1 {
    base
  } else {
    base + "-" + next.to_string()
  }
}

// ── inline parsing helpers ────────────────────────────────────────────────────

///|
/// Count consecutive occurrences of `c` starting at `pos`.
fn count_char(s : String, pos : Int, c : Char) -> Int {
  let n = s.length()
  let mut count = 0
  while pos + count < n && @strutil.char_at(s, pos + count) == c {
    count = count + 1
  }
  count
}

///|
/// Find the first occurrence of `needle` in s[from..limit]. Returns -1 if absent.

///|
/// Find the first occurrence of `c` in s[from..limit]. Returns -1 if absent.

///|
/// Find the first occurrence of `c` in string `s` starting at position 0.
fn find_char_in_str(s : String, c : Char) -> Int {
  @strutil.find_char(s, 0, c, s.length())
}

///|
fn split_shortcode_params_raw(raw : String) -> String {
  @strutil.trim(raw)
}

///|
fn is_full_shortcode_line(line : String) -> Bool {
  let t = @strutil.trim(line)
  t.length() >= 7 &&
  @strutil.starts_with_at(t, 0, "{{<") &&
  @strutil.starts_with_at(t, t.length() - 3, ">}}")
}

///|
fn shortcode_inner_text_from_line(line : String) -> String {
  let t = @strutil.trim(line)
  @strutil.trim(@strutil.substr(t, 3, t.length() - 3))
}

///|
fn preprocess_callout_next_line(body : String) -> String {
  let ls = lines_of(body)
  let out : Array[String] = []
  let mut i = 0
  while i < ls.length() {
    let line = ls[i]
    if is_full_shortcode_line(line) {
      let raw = shortcode_inner_text_from_line(line)
      match @shortcode.parse(raw) {
        Ok(call) =>
          if call.name == "callout" &&
            i + 1 < ls.length() &&
            !is_blank(ls[i + 1]) {
            let merged = @strutil.trim(line) +
              " " +
              @strutil.trim(ls[i + 1]) +
              " {{< /callout >}}"
            out.push(merged)
            i = i + 2
            continue
          }
        Err(_) => ()
      }
    }
    out.push(line)
    i = i + 1
  }
  @strutil.join_lines(out)
}

// ── inline parsing ────────────────────────────────────────────────────────────

///|
/// Parse inline elements from s[from..to]. Handles bold, italic, inline code,
/// links, wikilinks, escape sequences, and hard line breaks.
pub fn parse_inlines(s : String, from : Int, to : Int) -> Array[Inline] {
  let result : Array[Inline] = []
  let mut i = from
  let mut text_start = from
  while i < to {
    let c = @strutil.char_at(s, i)
    if c == '\\' && i + 1 < to {
      // backslash escape: emit accumulated text then the escaped char
      if text_start < i {
        result.push(Text(@strutil.substr(s, text_start, i)))
      }
      result.push(Text(@strutil.char_at(s, i + 1).to_string()))
      i = i + 2
      text_start = i
    } else if c == '`' {
      // inline code: `code`
      if text_start < i {
        result.push(Text(@strutil.substr(s, text_start, i)))
      }
      let close = @strutil.find_char(s, i + 1, '`', to)
      if close >= 0 {
        result.push(InlineCode(@strutil.substr(s, i + 1, close)))
        i = close + 1
      } else {
        // unterminated — treat backtick as literal text
        result.push(Text("`"))
        i = i + 1
      }
      text_start = i
    } else if c == '$' {
      // inline math: $...$
      // Dollar followed by space or at end of string is not a math opener
      // (prevents false positives with currency like "$5" or "$ amount").
      // Content cannot span lines (no newlines) and cannot be empty.
      let opener_end = i + 1
      let is_dollar_dollar = opener_end < to &&
        @strutil.char_at(s, opener_end) == '$'
      // $$ is handled by the block parser (MathBlock), skip here
      if is_dollar_dollar {
        i = i + 1
      } else if opener_end < to && @strutil.char_at(s, opener_end) != ' ' {
        // Look for closing $ that is not preceded by \
        let mut close = opener_end
        let mut found = false
        while close < to {
          let ch = @strutil.char_at(s, close)
          if ch == '$' {
            // Check it's not preceded by a backslash
            if close > opener_end &&
              @strutil.char_at(s, close - 1) == '\\' {
              close = close + 1
              continue
            }
            // Closing $ must not be followed immediately by alphanumeric
            // (prevents matching mid-word dollars) and content must be non-empty
            let content = @strutil.substr(s, opener_end, close)
            if content.length() > 0 && !content.contains("\n") {
              found = true
              break
            }
          }
          close = close + 1
        }
        if found {
          let content = @strutil.substr(s, opener_end, close)
          if text_start < i {
            result.push(Text(@strutil.substr(s, text_start, i)))
          }
          result.push(Math(content))
          i = close + 1
          text_start = i
        } else {
          // No closing $ found — treat as literal
          i = i + 1
        }
      } else {
        // $ followed by space or at end — literal dollar
        i = i + 1
      }
    } else if c == '*' {
      // bold (**), italic (*), or bold+italic (***)
      let star_count = count_char(s, i, '*')
      let inner_start = i + star_count
      let close_needle = if star_count >= 3 {
        "***"
      } else if star_count == 2 {
        "**"
      } else {
        "*"
      }
      let close = @strutil.find_str(s, inner_start, close_needle, to)
      if close > inner_start {
        if text_start < i {
          result.push(Text(@strutil.substr(s, text_start, i)))
        }
        let inner = parse_inlines(s, inner_start, close)
        if star_count >= 3 {
          result.push(BoldItalic(inner))
          i = close + 3
        } else if star_count == 2 {
          result.push(Bold(inner))
          i = close + 2
        } else {
          result.push(Italic(inner))
          i = close + 1
        }
        text_start = i
      } else {
        // no matching close — treat stars as literal text
        i = i + 1
      }
    } else if c == '~' && i + 1 < to && @strutil.char_at(s, i + 1) == '~' {
      // strikethrough: ~~text~~
      let inner_start = i + 2
      let close = @strutil.find_str(s, inner_start, "~~", to)
      if close > inner_start {
        if text_start < i {
          result.push(Text(@strutil.substr(s, text_start, i)))
        }
        let inner = parse_inlines(s, inner_start, close)
        result.push(Strikethrough(inner))
        i = close + 2
        text_start = i
      } else {
        // no matching close — treat tildes as literal text
        i = i + 1
      }
    } else if c == '_' {
      // underscore emphasis: _italic_, __bold__, ___bold italic___
      // Word-boundary rule: only treat _ as opener if the char before it is
      // NOT alphanumeric. This prevents snake_case identifiers from being
      // parsed as emphasis — a pragmatic compromise for SSG content.
      let prev_is_alnum = i > 0 && {
        let prev = @strutil.char_at(s, i - 1)
        @strutil.is_alpha(prev) || @strutil.is_digit(prev)
      }
      if prev_is_alnum {
        // mid-word underscore — treat as literal
        i = i + 1
      } else {
        let under_count = count_char(s, i, '_')
        let inner_start = i + under_count
        let close_needle = if under_count >= 3 {
          "___"
        } else if under_count == 2 {
          "__"
        } else {
          "_"
        }
        let close = @strutil.find_str(s, inner_start, close_needle, to)
        if close > inner_start {
          // Closing delimiter word-boundary: the char after the close must
          // NOT be alphanumeric (mirrors the opener rule).
          let close_end = close + under_count
          let next_is_alnum = close_end < to && {
            let next = @strutil.char_at(s, close_end)
            @strutil.is_alpha(next) || @strutil.is_digit(next)
          }
          if next_is_alnum {
            // Close is mid-word — skip this match and keep looking
            let next_close = @strutil.find_str(
              s, close + 1, close_needle, to,
            )
            if next_close > inner_start {
              let nc_end = next_close + under_count
              let nc_is_alnum = nc_end < to && {
                let nc = @strutil.char_at(s, nc_end)
                @strutil.is_alpha(nc) || @strutil.is_digit(nc)
              }
              if nc_is_alnum {
                // Still mid-word — give up, treat opener as literal
                i = i + 1
              } else {
                if text_start < i {
                  result.push(Text(@strutil.substr(s, text_start, i)))
                }
                let inner = parse_inlines(s, inner_start, next_close)
                if under_count >= 3 {
                  result.push(BoldItalic(inner))
                } else if under_count == 2 {
                  result.push(Bold(inner))
                } else {
                  result.push(Italic(inner))
                }
                i = next_close + under_count
                text_start = i
              }
            } else {
              // No valid close — literal underscore
              i = i + 1
            }
          } else {
            if text_start < i {
              result.push(Text(@strutil.substr(s, text_start, i)))
            }
            let inner = parse_inlines(s, inner_start, close)
            if under_count >= 3 {
              result.push(BoldItalic(inner))
            } else if under_count == 2 {
              result.push(Bold(inner))
            } else {
              result.push(Italic(inner))
            }
            i = close + under_count
            text_start = i
          }
        } else {
          // no matching close — treat underscores as literal text
          i = i + 1
        }
      }
    } else if c == '<' {
      // angle-bracket autolink or inline HTML passthrough
      let mut matched = false
      if i + 1 < to {
        let rest_start = i + 1
        let next_c = @strutil.char_at(s, rest_start)
        if @strutil.starts_with_at(s, rest_start, "https://") ||
          @strutil.starts_with_at(s, rest_start, "http://") ||
          @strutil.starts_with_at(s, rest_start, "mailto:") {
          // autolink: <https://...>, <http://...>, <mailto:...>
          let close_bracket = @strutil.find_char(s, rest_start, '>', to)
          if close_bracket > rest_start {
            let url = @strutil.substr(s, rest_start, close_bracket)
            if text_start < i {
              result.push(Text(@strutil.substr(s, text_start, i)))
            }
            result.push(Link([Text(url)], url))
            i = close_bracket + 1
            text_start = i
            matched = true
          }
        } else if (next_c >= 'a' && next_c <= 'z') ||
          (next_c >= 'A' && next_c <= 'Z') {
          // inline open tag: <tagname ...> or <br/> etc.
          let close_gt = @strutil.find_char(s, rest_start, '>', to)
          if close_gt > i {
            if text_start < i {
              result.push(Text(@strutil.substr(s, text_start, i)))
            }
            result.push(InlineHtml(@strutil.substr(s, i, close_gt + 1)))
            i = close_gt + 1
            text_start = i
            matched = true
          }
        } else if next_c == '/' && rest_start + 1 < to {
          let next2 = @strutil.char_at(s, rest_start + 1)
          if (next2 >= 'a' && next2 <= 'z') || (next2 >= 'A' && next2 <= 'Z') {
            // inline close tag: </tagname>
            let close_gt = @strutil.find_char(s, rest_start + 1, '>', to)
            if close_gt > i {
              if text_start < i {
                result.push(Text(@strutil.substr(s, text_start, i)))
              }
              result.push(InlineHtml(@strutil.substr(s, i, close_gt + 1)))
              i = close_gt + 1
              text_start = i
              matched = true
            }
          }
        } else if @strutil.starts_with_at(s, i, "<!--") {
          // inline HTML comment: <!-- ... -->
          let close_comment = @strutil.find_str(s, i + 4, "-->", to)
          if close_comment >= 0 {
            if text_start < i {
              result.push(Text(@strutil.substr(s, text_start, i)))
            }
            result.push(InlineHtml(@strutil.substr(s, i, close_comment + 3)))
            i = close_comment + 3
            text_start = i
            matched = true
          }
        }
      }
      if !matched {
        i = i + 1
      }
    } else if c == '{' &&
      i + 2 < to &&
      @strutil.char_at(s, i + 1) == '{' &&
      @strutil.char_at(s, i + 2) == '<' {
      if text_start < i {
        result.push(Text(@strutil.substr(s, text_start, i)))
      }
      let close = @strutil.find_str(s, i + 3, ">}}", to)
      if close >= 0 {
        let raw = split_shortcode_params_raw(@strutil.substr(s, i + 3, close))
        match @shortcode.parse(raw) {
          Ok(call) =>
            if call.name == "callout" {
              let closing_tag = "{{< /callout >}}"
              let body_start = close + 3
              let end_callout = @strutil.find_str(
                s, body_start, closing_tag, to,
              )
              if end_callout >= 0 {
                let copied : Map[String, @shortcode.ShortcodeParam] = Map::new()
                let param_keys = [
                  "type", "title", "src", "alt", "caption", "width", "poster", "link",
                  "body",
                ]
                let mut j = 0
                while j < param_keys.length() {
                  let key = param_keys[j]
                  match call.params.get(key) {
                    Some(value) => copied.set(key, value)
                    None => ()
                  }
                  j = j + 1
                }
                let body_text = @strutil.trim(
                  @strutil.substr(s, body_start, end_callout),
                )
                if body_text.length() > 0 {
                  copied.set("body", @shortcode.StringParam(body_text))
                }
                result.push(Shortcode({ name: call.name, params: copied }))
                i = end_callout + closing_tag.length()
              } else {
                result.push(Shortcode(call))
                i = close + 3
              }
            } else {
              result.push(Shortcode(call))
              i = close + 3
            }
          Err(_) => {
            result.push(Text(@strutil.substr(s, i, close + 3)))
            i = close + 3
          }
        }
      } else {
        result.push(Text("{{<"))
        i = i + 3
      }
      text_start = i
    } else if c == '!' && i + 1 < to && @strutil.char_at(s, i + 1) == '[' {
      // image: ![alt](url)
      let bracket_close = @strutil.find_char(s, i + 2, ']', to)
      if bracket_close >= 0 &&
        bracket_close + 1 < to &&
        @strutil.char_at(s, bracket_close + 1) == '(' {
        let paren_close = @strutil.find_char(s, bracket_close + 2, ')', to)
        if paren_close >= 0 {
          if text_start < i {
            result.push(Text(@strutil.substr(s, text_start, i)))
          }
          let alt = @strutil.substr(s, i + 2, bracket_close)
          let url = @strutil.substr(s, bracket_close + 2, paren_close)
          result.push(Image(alt, url))
          i = paren_close + 1
          text_start = i
        } else {
          i = i + 1
        }
      } else {
        i = i + 1
      }
    } else if c == '[' && i + 1 < to && @strutil.char_at(s, i + 1) == '[' {
      // wikilink: [[target]] or [[target|display]]
      if text_start < i {
        result.push(Text(@strutil.substr(s, text_start, i)))
      }
      let close_j = @strutil.find_str(s, i + 2, "]]", to)
      if close_j >= 0 {
        let inner = @strutil.substr(s, i + 2, close_j)
        let pipe = find_char_in_str(inner, '|')
        if pipe >= 0 {
          let target = @strutil.trim(@strutil.substr(inner, 0, pipe))
          let display = @strutil.trim(
            @strutil.substr(inner, pipe + 1, inner.length()),
          )
          result.push(WikiRef(target, Some(display)))
        } else {
          result.push(WikiRef(@strutil.trim(inner), None))
        }
        i = close_j + 2
      } else {
        // unterminated wikilink — emit as text
        result.push(Text("[["))
        i = i + 2
      }
      text_start = i
    } else if c == '[' {
      // Check for footnote reference: [^label]
      if i + 2 < to && @strutil.char_at(s, i + 1) == '^' {
        let bracket_close = @strutil.find_char(s, i + 2, ']', to)
        if bracket_close >= 0 {
          if text_start < i {
            result.push(Text(@strutil.substr(s, text_start, i)))
          }
          let label = @strutil.substr(s, i + 2, bracket_close)
          result.push(FootnoteRef(label))
          i = bracket_close + 1
          text_start = i
        } else {
          // Unterminated footnote ref - treat as literal
          i = i + 1
        }
      } else if i + 1 < to && @strutil.char_at(s, i + 1) == '[' {
        // wikilink: [[target]] or [[target|display]]
        if text_start < i {
          result.push(Text(@strutil.substr(s, text_start, i)))
        }
        let close_j = @strutil.find_str(s, i + 2, "]]", to)
        if close_j >= 0 {
          let inner = @strutil.substr(s, i + 2, close_j)
          let pipe = find_char_in_str(inner, '|')
          if pipe >= 0 {
            let target = @strutil.trim(@strutil.substr(inner, 0, pipe))
            let display = @strutil.trim(
              @strutil.substr(inner, pipe + 1, inner.length()),
            )
            result.push(WikiRef(target, Some(display)))
          } else {
            result.push(WikiRef(@strutil.trim(inner), None))
          }
          i = close_j + 2
        } else {
          // unterminated wikilink — emit as text
          result.push(Text("[["))
          i = i + 2
        }
        text_start = i
      } else {
        // regular link: [text](url)
        let bracket_close = @strutil.find_char(s, i + 1, ']', to)
        if bracket_close >= 0 &&
          bracket_close + 1 < to &&
          @strutil.char_at(s, bracket_close + 1) == '(' {
          let paren_close = @strutil.find_char(s, bracket_close + 2, ')', to)
          if paren_close >= 0 {
            if text_start < i {
              result.push(Text(@strutil.substr(s, text_start, i)))
            }
            let link_text = @strutil.substr(s, i + 1, bracket_close)
            let url = @strutil.substr(s, bracket_close + 2, paren_close)
            result.push(Link(parse_inlines(link_text, 0, link_text.length()), url))
            i = paren_close + 1
            text_start = i
          } else {
            i = i + 1
          }
        } else {
          i = i + 1
        }
      }
    } else if c == '\n' {
      // soft line break: two trailing spaces before newline = hard break,
      // otherwise collapse to a space (standard markdown behavior)
      if text_start < i {
        result.push(Text(@strutil.substr(s, text_start, i)))
      }
      let is_hard = i >= 2 &&
        @strutil.char_at(s, i - 1) == ' ' &&
        @strutil.char_at(s, i - 2) == ' '
      if is_hard {
        result.push(HardBreak)
      } else {
        result.push(Text(" "))
      }
      i = i + 1
      text_start = i
    } else {
      i = i + 1
    }
  }
  // flush any trailing text
  if text_start < to {
    result.push(Text(@strutil.substr(s, text_start, to)))
  }
  result
}

// ── block parsing helpers ─────────────────────────────────────────────────────

///|
pub fn count_leading_hashes(line : String) -> Int {
  let n = line.length()
  let mut count = 0
  while count < n && @strutil.char_at(line, count) == '#' {
    count = count + 1
  }
  count
}

///|
pub fn is_heading_line(line : String) -> Bool {
  let hashes = count_leading_hashes(line)
  if hashes == 0 || hashes > 6 {
    return false
  }
  let n = line.length()
  hashes < n && @strutil.char_at(line, hashes) == ' '
}

///|
fn heading_level_and_text(line : String) -> (Int, String) {
  let level = count_leading_hashes(line)
  let text = @strutil.trim(@strutil.substr(line, level + 1, line.length()))
  (level, text)
}

///|
pub fn is_hrule(line : String) -> Bool {
  let t = @strutil.trim(line)
  t == "---" || t == "***" || t == "___"
}

///|
pub fn is_fence_start(line : String) -> Bool {
  @strutil.starts_with_at(line, 0, "```") ||
  @strutil.starts_with_at(line, 0, "~~~")
}

///|
fn fence_lang_tag(line : String) -> String? {
  let n = line.length()
  if n < 3 {
    return None
  }
  let lang = @strutil.trim(@strutil.substr(line, 3, n))
  if lang.length() == 0 {
    None
  } else {
    Some(lang)
  }
}

///|
pub fn fence_char_of(line : String) -> Char {
  if line.length() > 0 {
    @strutil.char_at(line, 0)
  } else {
    '`'
  }
}

///|
pub fn is_fence_end(line : String, fence_char : Char) -> Bool {
  let n = line.length()
  n >= 3 &&
  @strutil.char_at(line, 0) == fence_char &&
  @strutil.char_at(line, 1) == fence_char &&
  @strutil.char_at(line, 2) == fence_char
}

///|

///|
pub fn is_unordered_item(line : String) -> Bool {
  let n = line.length()
  n >= 2 &&
  (@strutil.char_at(line, 0) == '-' || @strutil.char_at(line, 0) == '*') &&
  @strutil.char_at(line, 1) == ' '
}

///|
pub fn is_ordered_item(line : String) -> Bool {
  let n = line.length()
  if n < 3 {
    return false
  }
  let mut i = 0
  while i < n && @strutil.is_digit(@strutil.char_at(line, i)) {
    i = i + 1
  }
  i > 0 &&
  i + 1 < n &&
  @strutil.char_at(line, i) == '.' &&
  @strutil.char_at(line, i + 1) == ' '
}

///|
/// Count leading spaces (2 or 4 spaces indicate nested list)
fn count_leading_spaces(line : String) -> Int {
  let n = line.length()
  let mut count = 0
  while count < n && @strutil.char_at(line, count) == ' ' {
    count = count + 1
  }
  count
}

///|
/// Check if a line is indented for a nested list (2 or 4 spaces)
fn is_nested_indent(line : String) -> Bool {
  let spaces = count_leading_spaces(line)
  spaces == 2 || spaces == 4
}

///|
fn ordered_item_text(line : String) -> String {
  let n = line.length()
  let mut i = 0
  while i < n && @strutil.is_digit(@strutil.char_at(line, i)) {
    i = i + 1
  }
  // skip ". " (dot and space)
  if i + 2 <= n {
    @strutil.substr(line, i + 2, n)
  } else {
    ""
  }
}

///|
pub fn is_blockquote_line(line : String) -> Bool {
  line.length() > 0 && @strutil.char_at(line, 0) == '>'
}

///|
fn strip_blockquote_marker(line : String) -> String {
  let n = line.length()
  if n == 0 {
    return ""
  }
  // strip '>' and optional single space after it
  let start = if n > 1 && @strutil.char_at(line, 1) == ' ' { 2 } else { 1 }
  @strutil.substr(line, start, n)
}

///|
fn is_footnote_def_line(line : String) -> Bool {
  let n = line.length()
  if n < 3 {
    return false
  }
  // Footnote def starts with "[^" followed by label and ":"
  if @strutil.char_at(line, 0) == '[' && @strutil.char_at(line, 1) == '^' {
    let close_bracket = @strutil.find_char(line, 2, ']', n)
    if close_bracket >= 2 &&
      close_bracket + 1 < n &&
      @strutil.char_at(line, close_bracket + 1) == ':' {
      return true
    }
  }
  false
}

///|
fn footnote_label_from_def(line : String) -> String {
  // Extract label between "[^" and "]"
  let n = line.length()
  if n < 3 {
    return ""
  }
  let close_bracket = @strutil.find_char(line, 2, ']', n)
  if close_bracket >= 2 {
    @strutil.substr(line, 2, close_bracket)
  } else {
    ""
  }
}

///|
fn footnote_text_from_def(line : String) -> String {
  // Extract text after ": " from definition line
  let n = line.length()
  if n < 3 {
    return ""
  }
  let close_bracket = @strutil.find_char(line, 2, ']', n)
  if close_bracket >= 2 &&
    close_bracket + 1 < n &&
    @strutil.char_at(line, close_bracket + 1) == ':' {
    // Skip ": " (colon and space)
    if close_bracket + 2 <= n {
      @strutil.trim(@strutil.substr(line, close_bracket + 2, n))
    } else {
      ""
    }
  } else {
    ""
  }
}

// ── GFM table helpers ─────────────────────────────────────────────────────────

///|
/// A line qualifies as a potential table row if it contains a pipe character.
fn is_table_row_line(line : String) -> Bool {
  line.contains("|")
}

///|
/// Split a GFM table row into trimmed cell strings.
/// Handles both `| a | b |` (outer pipes) and `a | b` formats.
fn split_table_row(line : String) -> Array[String] {
  let t = @strutil.trim(line)
  let n = t.length()
  // strip leading pipe
  let start = if n > 0 && @strutil.char_at(t, 0) == '|' { 1 } else { 0 }
  // strip trailing pipe
  let end_pos = if n > 0 && @strutil.char_at(t, n - 1) == '|' {
    n - 1
  } else {
    n
  }
  let inner = @strutil.substr(t, start, end_pos)
  // split on '|'
  let cells : Array[String] = []
  let inner_n = inner.length()
  let mut i = 0
  let mut cell_start = 0
  while i <= inner_n {
    if i == inner_n || @strutil.char_at(inner, i) == '|' {
      cells.push(@strutil.trim(@strutil.substr(inner, cell_start, i)))
      cell_start = i + 1
    }
    i = i + 1
  }
  cells
}

///|
/// A separator cell contains only `-` and `:` characters with at least one `-`.
/// Examples: `---`, `:---`, `---:`, `:---:`.
fn is_separator_cell(cell : String) -> Bool {
  let t = @strutil.trim(cell)
  let n = t.length()
  if n == 0 {
    return false
  }
  let mut has_dash = false
  let mut i = 0
  while i < n {
    let c = @strutil.char_at(t, i)
    if c == '-' {
      has_dash = true
    } else if c != ':' {
      return false
    }
    i = i + 1
  }
  has_dash
}

///|
/// A separator row has at least one cell and every cell is a separator cell.
fn is_separator_row(line : String) -> Bool {
  if !line.contains("|") && !line.contains("-") {
    return false
  }
  let cells = split_table_row(line)
  if cells.length() == 0 {
    return false
  }
  let mut i = 0
  while i < cells.length() {
    if !is_separator_cell(cells[i]) {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// Derive column alignment from a separator cell string.
fn parse_col_align(cell : String) -> ColAlign {
  let t = @strutil.trim(cell)
  let n = t.length()
  if n == 0 {
    return AlignDefault
  }
  let starts_colon = @strutil.char_at(t, 0) == ':'
  let ends_colon = @strutil.char_at(t, n - 1) == ':'
  if starts_colon && ends_colon {
    AlignCenter
  } else if starts_colon {
    AlignLeft
  } else if ends_colon {
    AlignRight
  } else {
    AlignDefault
  }
}

///|

///|
/// Check if a line starts with ": " (definition prefix)
fn is_definition_line(line : String) -> Bool {
  let n = line.length()
  n >= 2 && @strutil.char_at(line, 0) == ':' && @strutil.char_at(line, 1) == ' '
}

///|
/// Check if this position starts a definition list term
/// (a non-blank line followed by a definition line)
fn is_definition_term_start(ls : Array[String], i : Int) -> Bool {
  i < ls.length() &&
  !is_blank(ls[i]) &&
  i + 1 < ls.length() &&
  is_definition_line(ls[i + 1])
}

///|
///|
/// Detect the start of a raw HTML block.
/// A block HTML line starts with `<` followed by a letter (opening tag),
/// `/` (closing tag), `!` (comment/DOCTYPE), or `?` (processing instruction).
/// This covers the common authoring cases: <div>, </div>, <!-- ... -->, <!DOCTYPE>.
///
/// Exception: angle-bracket autolinks like <https://...> are NOT HTML blocks —
/// they are inline elements that should be parsed within a paragraph.
fn is_html_block_start(line : String) -> Bool {
  let n = line.length()
  if n < 2 {
    return false
  }
  if line[0] != '<' {
    return false
  }
  // Exclude autolinks: <http://...>, <https://...>, <mailto:...>
  if @strutil.starts_with_at(line, 1, "https://") ||
    @strutil.starts_with_at(line, 1, "http://") ||
    @strutil.starts_with_at(line, 1, "mailto:") {
    return false
  }
  let c = line[1]
  // letter → opening tag; / → closing tag; ! → comment/DOCTYPE; ? → PI
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  c == '/' ||
  c == '!' ||
  c == '?'
}

///|
fn is_math_block_start(line : String) -> Bool {
  // A line that starts with $$ (possibly after whitespace) opens a math block.
  // The trimmed line must start with exactly $$ and have content after it (or
  // be exactly $$ for a closing delimiter).
  let t = @strutil.trim(line)
  t.length() >= 2 &&
  @strutil.char_at(t, 0) == '$' &&
  @strutil.char_at(t, 1) == '$'
}

fn is_block_starter(line : String) -> Bool {
  is_heading_line(line) ||
  is_hrule(line) ||
  is_fence_start(line) ||
  is_unordered_item(line) ||
  is_ordered_item(line) ||
  is_blockquote_line(line) ||
  is_definition_line(line) ||
  is_html_block_start(line) ||
  is_math_block_start(line)
}

// ── block parsing ─────────────────────────────────────────────────────────────

///|
/// Parse blocks and return both the block structure and collected footnote
/// definitions.
pub fn parse_blocks_with_footnotes(
  ls : Array[String],
) -> (Array[Block], Array[FootnoteDef]) {
  let result : Array[Block] = []
  let footnotes : Array[FootnoteDef] = []
  let mut i = 0
  let n = ls.length()
  while i < n {
    let line = ls[i]
    if is_blank(line) {
      // skip blank lines between blocks
      i = i + 1
    } else if is_footnote_def_line(line) {
      // Collect footnote definition - exclude from flow
      let label = footnote_label_from_def(line)
      let text = footnote_text_from_def(line)
      footnotes.push({ label, text })
      i = i + 1
    } else if is_heading_line(line) {
      let (level, text) = heading_level_and_text(line)
      result.push(Heading(level, parse_inlines(text, 0, text.length())))
      i = i + 1
    } else if is_hrule(line) {
      result.push(HRule)
      i = i + 1
    } else if is_fence_start(line) {
      let fence_char = fence_char_of(line)
      let lang = fence_lang_tag(line)
      let code_lines : Array[String] = []
      i = i + 1
      while i < n && !is_fence_end(ls[i], fence_char) {
        code_lines.push(ls[i])
        i = i + 1
      }
      if i < n {
        i = i + 1 // skip closing fence
      }
      result.push(FencedCode(lang, @strutil.join_lines(code_lines)))
    } else if is_blockquote_line(line) {
      let bq_lines : Array[String] = []
      while i < n && is_blockquote_line(ls[i]) {
        bq_lines.push(strip_blockquote_marker(ls[i]))
        i = i + 1
      }
      // blockquotes recurse: the stripped lines form their own block structure
      result.push(BlockQuote(parse_blocks(bq_lines)))
    } else if is_unordered_item(line) {
      let items : Array[ListItem] = []
      // Single-pass: consume each item line then immediately consume its
      // indented continuation lines before moving to the next item.
      while i < n && is_unordered_item(ls[i]) {
        let text = @strutil.substr(ls[i], 2, ls[i].length())
        i = i + 1
        // Collect indented continuation lines belonging to this item.
        let nested_lines : Array[String] = []
        while i < n && is_nested_indent(ls[i]) {
          nested_lines.push(@strutil.substr(ls[i], 2, ls[i].length()))
          i = i + 1
        }
        let children : Array[Block] = if nested_lines.length() > 0 {
          let (nested_blocks, _) = parse_blocks_with_footnotes(nested_lines)
          nested_blocks
        } else {
          []
        }
        items.push({ inlines: parse_inlines(text, 0, text.length()), children })
      }
      result.push(UnorderedList(items))
    } else if is_ordered_item(line) {
      let items : Array[ListItem] = []
      // Single-pass: consume each item line then immediately consume its
      // indented continuation lines before moving to the next item.
      while i < n && is_ordered_item(ls[i]) {
        let text = ordered_item_text(ls[i])
        i = i + 1
        // Collect indented continuation lines belonging to this item.
        let nested_lines : Array[String] = []
        while i < n && is_nested_indent(ls[i]) {
          nested_lines.push(@strutil.substr(ls[i], 2, ls[i].length()))
          i = i + 1
        }
        let children : Array[Block] = if nested_lines.length() > 0 {
          let (nested_blocks, _) = parse_blocks_with_footnotes(nested_lines)
          nested_blocks
        } else {
          []
        }
        items.push({ inlines: parse_inlines(text, 0, text.length()), children })
      }
      result.push(OrderedList(items))
    } else if is_definition_term_start(ls, i) {
      // Definition list: term followed by one or more : definition lines.
      // Both terms and definition values are parsed as inline content so
      // **bold**, `code`, [links](url), etc. work as expected.
      let items : Array[(Array[Inline], Array[Array[Inline]])] = []
      while i < n && is_definition_term_start(ls, i) {
        let term_str = ls[i]
        let term_inlines = parse_inlines(term_str, 0, term_str.length())
        i = i + 1
        // Collect all : definition lines for this term
        let defs : Array[Array[Inline]] = []
        while i < n && is_definition_line(ls[i]) {
          // Strip ": " prefix and any extra leading whitespace (e.g. ":   ")
          let def_text = @strutil.trim_start(
            @strutil.substr(ls[i], 2, ls[i].length()),
          )
          defs.push(parse_inlines(def_text, 0, def_text.length()))
          i = i + 1
        }
        items.push((term_inlines, defs))
      }
      result.push(DefinitionList(items))
    } else if is_table_row_line(line) &&
      i + 1 < n &&
      is_separator_row(ls[i + 1]) {
      // GFM table: header row followed by a separator row.
      let header_cells = split_table_row(line)
      let sep_cells = split_table_row(ls[i + 1])
      let num_cols = header_cells.length()
      // build alignment array from the separator row
      let aligns : Array[ColAlign] = []
      let mut k = 0
      while k < num_cols {
        let al = if k < sep_cells.length() {
          parse_col_align(sep_cells[k])
        } else {
          AlignDefault
        }
        aligns.push(al)
        k = k + 1
      }
      // parse header cells as inline content
      let header_inlines : Array[Array[Inline]] = []
      k = 0
      while k < num_cols {
        let ct = header_cells[k]
        header_inlines.push(parse_inlines(ct, 0, ct.length()))
        k = k + 1
      }
      i = i + 2 // consume header + separator
      // parse data rows until a non-table line or blank line
      let rows : Array[Array[Array[Inline]]] = []
      while i < n && is_table_row_line(ls[i]) && !is_blank(ls[i]) {
        let row_cells = split_table_row(ls[i])
        let row_inlines : Array[Array[Inline]] = []
        k = 0
        while k < num_cols {
          let ct = if k < row_cells.length() { row_cells[k] } else { "" }
          row_inlines.push(parse_inlines(ct, 0, ct.length()))
          k = k + 1
        }
        rows.push(row_inlines)
        i = i + 1
      }
      result.push(Table(aligns, header_inlines, rows))
    } else if is_math_block_start(line) {
      // Display math block: $$...$$
      let t = @strutil.trim(line)
      let math_lines : Array[String] = []
      // If the opening line has content after $$, include it
      if t.length() > 2 {
        math_lines.push(@strutil.trim(@strutil.substr(t, 2, t.length())))
      }
      i = i + 1
      let mut found_close = false
      while i < n {
        let cur = @strutil.trim(ls[i])
        if cur == "$$" {
          found_close = true
          i = i + 1
          break
        }
        math_lines.push(ls[i])
        i = i + 1
      }
      if found_close {
        result.push(MathBlock(@strutil.join_lines(math_lines)))
      } else {
        // No closing $$ — treat opening line as a paragraph
        result.push(Paragraph(parse_inlines(line, 0, line.length())))
      }
    } else if is_html_block_start(line) {
      // Raw HTML block — accumulate until first blank line and emit verbatim.
      // The author controls content in an SSG context, so passthrough is safe.
      let html_lines : Array[String] = []
      while i < n && !is_blank(ls[i]) {
        html_lines.push(ls[i])
        i = i + 1
      }
      result.push(HtmlBlock(@strutil.join_lines(html_lines)))
    } else {
      // paragraph: accumulate non-blank, non-block-starter lines
      let para_lines : Array[String] = []
      while i < n && !is_blank(ls[i]) && !is_block_starter(ls[i]) {
        para_lines.push(ls[i])
        i = i + 1
      }
      let para_text = @strutil.join_lines(para_lines)
      result.push(Paragraph(parse_inlines(para_text, 0, para_text.length())))
    }
  }
  (result, footnotes)
}

// ── rendering ─────────────────────────────────────────────────────────────────

///|
fn merge_shortcode_errors(
  target : Array[ShortcodeIssue],
  from : Array[ShortcodeIssue],
) -> Unit {
  let mut i = 0
  while i < from.length() {
    target.push(from[i])
    i = i + 1
  }
}

///|
fn collect_toc_entries_into(
  blocks : Array[Block],
  max_depth : Int,
  counts : Map[String, Int],
  entries : Array[TocEntry],
) -> Unit {
  let mut i = 0
  while i < blocks.length() {
    match blocks[i] {
      Heading(level, inlines) => {
        let text = plain_text_inlines(inlines)
        let anchor = next_heading_anchor(text, counts)
        if level >= 2 && level <= max_depth {
          entries.push({ level, anchor, text })
        }
      }
      BlockQuote(inner) =>
        collect_toc_entries_into(inner, max_depth, counts, entries)
      _ => ()
    }
    i = i + 1
  }
}

///|
fn collect_toc_entries(
  blocks : Array[Block],
  max_depth : Int,
) -> Array[TocEntry] {
  let counts : Map[String, Int] = Map::new()
  let entries : Array[TocEntry] = []
  collect_toc_entries_into(blocks, max_depth, counts, entries)
  entries
}

///|
fn render_inlines_with_issues(
  inlines : Array[Inline],
  wl : Map[String, String],
  fn_map : Map[String, Int],
) -> RenderResult {
  let buf = StringBuilder::new()
  let issues : Array[ShortcodeIssue] = []
  let mut i = 0
  while i < inlines.length() {
    let rendered = render_inline_with_issues(inlines[i], wl, fn_map)
    buf.write_string(rendered.html)
    merge_shortcode_errors(issues, rendered.shortcode_errors)
    i = i + 1
  }
  { html: buf.to_string(), shortcode_errors: issues, toc: [], footnotes: [] }
}

///|
fn shortcode_is_block(call : @shortcode.ShortcodeCall) -> Bool {
  call.name == "image" ||
  call.name == "figure" ||
  call.name == "callout" ||
  call.name == "video"
}

///|
fn render_blocks_with_issues(
  blocks : Array[Block],
  wl : Map[String, String],
  heading_counts : Map[String, Int],
  fn_map : Map[String, Int],
) -> RenderResult {
  let buf = StringBuilder::new()
  let issues : Array[ShortcodeIssue] = []
  let mut i = 0
  while i < blocks.length() {
    match blocks[i] {
      OrderedList(items) => {
        let merged : Array[ListItem] = []
        let mut k = 0
        while k < items.length() {
          merged.push(items[k])
          k = k + 1
        }
        i = i + 1
        while i < blocks.length() {
          match blocks[i] {
            OrderedList(next_items) => {
              let mut j = 0
              while j < next_items.length() {
                merged.push(next_items[j])
                j = j + 1
              }
              i = i + 1
            }
            _ => break
          }
        }
        let rendered = render_block_with_issues(
          OrderedList(merged),
          wl,
          heading_counts,
          fn_map,
        )
        buf.write_string(rendered.html)
        merge_shortcode_errors(issues, rendered.shortcode_errors)
      }
      _ => {
        let rendered = render_block_with_issues(
          blocks[i],
          wl,
          heading_counts,
          fn_map,
        )
        buf.write_string(rendered.html)
        merge_shortcode_errors(issues, rendered.shortcode_errors)
        i = i + 1
      }
    }
  }
  { html: buf.to_string(), shortcode_errors: issues, toc: [], footnotes: [] }
}

///|
fn render_fenced_code(lang : String?, code : String) -> String {
  match lang {
    Some(l) =>
      if @highlight.language_supported(l) {
        let tokens = @highlight.highlight(l, code)
        let highlighted = @highlight.render_highlighted(tokens)
        "<pre class=\"highlight language-" +
        @strutil.escape_html_body(l) +
        "\"><code>" +
        highlighted +
        "</code></pre>\n"
      } else {
        "<pre><code class=\"language-" +
        @strutil.escape_html_body(l) +
        "\">" +
        @strutil.escape_html_body(code) +
        "</code></pre>\n"
      }
    None => "<pre><code>" + @strutil.escape_html_body(code) + "</code></pre>\n"
  }
}

///|
/// Build the footnotes section HTML for the end of the page.
fn render_footnotes_section(
  footnotes : Array[FootnoteDef],
  wl : Map[String, String],
  fn_map : Map[String, Int],
) -> String {
  let buf = StringBuilder::new()
  buf.write_string("\n<section class=\"footnotes\">\n<ol>\n")
  let mut i = 0
  while i < footnotes.length() {
    let footnote = footnotes[i]
    buf.write_string("<li id=\"fn-")
    buf.write_string(@strutil.escape_html_body(footnote.label))
    buf.write_string("\">")
    // Render inline markdown in footnote text (e.g. **bold**, `code`)
    let inlines = parse_inlines(footnote.text, 0, footnote.text.length())
    let rendered_text = render_inlines_with_issues(inlines, wl, fn_map).html
    buf.write_string(rendered_text)
    buf.write_string(" <a href=\"#fnref-")
    buf.write_string(@strutil.escape_html_body(footnote.label))
    buf.write_string("\" class=\"footnote-backref\">↩</a>")
    buf.write_string("</li>\n")
    i = i + 1
  }
  buf.write_string("</ol>\n</section>\n")
  buf.to_string()
}

///|
/// Render a single inline element to an HTML string.
///
/// Wikilinks are resolved against `wl` (target slug → url). A wikilink whose
/// target is absent from `wl` renders as a broken-link anchor — this is a
/// defensive path; the build pipeline should have already aborted on missing
/// targets.
pub fn render_inline(inline : Inline, wl : Map[String, String]) -> String {
  let fn_map : Map[String, Int] = Map::new()
  render_inline_with_issues(inline, wl, fn_map).html
}

///|
fn render_inline_with_issues(
  inline : Inline,
  wl : Map[String, String],
  fn_map : Map[String, Int],
) -> RenderResult {
  match inline {
    Text(t) =>
      {
        html: @strutil.escape_html_body(t),
        shortcode_errors: [],
        toc: [],
        footnotes: [],
      }
    Bold(inner) => {
      let rendered = render_inlines_with_issues(inner, wl, fn_map)
      {
        html: "<strong>" + rendered.html + "</strong>",
        shortcode_errors: rendered.shortcode_errors,
        toc: [],
        footnotes: [],
      }
    }
    Italic(inner) => {
      let rendered = render_inlines_with_issues(inner, wl, fn_map)
      {
        html: "<em>" + rendered.html + "</em>",
        shortcode_errors: rendered.shortcode_errors,
        toc: [],
        footnotes: [],
      }
    }
    BoldItalic(inner) => {
      let rendered = render_inlines_with_issues(inner, wl, fn_map)
      {
        html: "<strong><em>" + rendered.html + "</em></strong>",
        shortcode_errors: rendered.shortcode_errors,
        toc: [],
        footnotes: [],
      }
    }
    Strikethrough(inner) => {
      let rendered = render_inlines_with_issues(inner, wl, fn_map)
      {
        html: "<del>" + rendered.html + "</del>",
        shortcode_errors: rendered.shortcode_errors,
        toc: [],
        footnotes: [],
      }
    }
    InlineCode(code) =>
      {
        html: "<code>" + @strutil.escape_html_body(code) + "</code>",
        shortcode_errors: [],
        toc: [],
        footnotes: [],
      }
    Link(inlines, url) => {
      let rendered = render_inlines_with_issues(inlines, wl, fn_map)
      {
        html: "<a href=\"" +
        @strutil.escape_html_body(url) +
        "\">" +
        rendered.html +
        "</a>",
        shortcode_errors: rendered.shortcode_errors,
        toc: [],
        footnotes: [],
      }
    }
    Image(alt, url) =>
      {
        html: "<img src=\"" +
        @strutil.escape_html_body(url) +
        "\" alt=\"" +
        @strutil.escape_html_body(alt) +
        "\" />",
        shortcode_errors: [],
        toc: [],
        footnotes: [],
      }
    WikiRef(target, display) => {
      let text = match display {
        Some(d) => d
        None => target
      }
      match wl.get(target) {
        Some(url) =>
          {
            html: "<a href=\"" +
            @strutil.escape_html_body(url) +
            "\">" +
            @strutil.escape_html_body(text) +
            "</a>",
            shortcode_errors: [],
            toc: [],
            footnotes: [],
          }
        None =>
          {
            html: "<a class=\"wl-broken\" href=\"#\">" +
            @strutil.escape_html_body(text) +
            "</a>",
            shortcode_errors: [],
            toc: [],
            footnotes: [],
          }
      }
    }
    FootnoteRef(label) =>
      match fn_map.get(label) {
        Some(ordinal) =>
          {
            html: "<sup><a href=\"#fn-" +
            @strutil.escape_html_body(label) +
            "\" id=\"fnref-" +
            @strutil.escape_html_body(label) +
            "\">[" +
            ordinal.to_string() +
            "]</a></sup>",
            shortcode_errors: [],
            toc: [],
            footnotes: [],
          }
        None =>
          {
            // Unresolved footnote reference - render as plain text
            html: "[^" + @strutil.escape_html_body(label) + "]",
            shortcode_errors: [],
            toc: [],
            footnotes: [],
          }
      }
    Shortcode(call) =>
      match @shortcode.render(call) {
        Ok(html) => { html, shortcode_errors: [], toc: [], footnotes: [] }
        Err(err) =>
          {
            html: "",
            shortcode_errors: [{ call: Some(call), error: err }],
            toc: [],
            footnotes: [],
          }
      }
    HardBreak =>
      { html: "<br />\n", shortcode_errors: [], toc: [], footnotes: [] }
    InlineHtml(raw) =>
      { html: raw, shortcode_errors: [], toc: [], footnotes: [] }
    Math(src) =>
      {
        html: "<span class=\"math-inline\">\\(" +
        @strutil.escape_html_body(src) +
        "\\)</span>",
        shortcode_errors: [],
        toc: [],
        footnotes: [],
      }
  }
}

///|
/// Render a single block element to an HTML string.
pub fn render_block(block : Block, wl : Map[String, String]) -> String {
  let counts : Map[String, Int] = Map::new()
  let fn_map : Map[String, Int] = Map::new()
  render_block_with_issues(block, wl, counts, fn_map).html
}

///|
fn render_block_with_issues(
  block : Block,
  wl : Map[String, String],
  heading_counts : Map[String, Int],
  fn_map : Map[String, Int],
) -> RenderResult {
  match block {
    Heading(level, inlines) => {
      let rendered = render_inlines_with_issues(inlines, wl, fn_map)
      let tag = "h" + level.to_string()
      let anchor = next_heading_anchor(
        plain_text_inlines(inlines),
        heading_counts,
      )
      {
        html: "<" +
        tag +
        " id=\"" +
        @strutil.escape_html_body(anchor) +
        "\">" +
        rendered.html +
        "</" +
        tag +
        ">\n",
        shortcode_errors: rendered.shortcode_errors,
        toc: [],
        footnotes: [],
      }
    }
    Paragraph(inlines) => {
      if inlines.length() == 1 {
        match inlines[0] {
          Shortcode(call) =>
            if shortcode_is_block(call) {
              let rendered_inline = render_inline_with_issues(
                inlines[0],
                wl,
                fn_map,
              )
              return {
                html: rendered_inline.html + "\n",
                shortcode_errors: rendered_inline.shortcode_errors,
                toc: [],
                footnotes: [],
              }
            }
          _ => ()
        }
      }
      let rendered = render_inlines_with_issues(inlines, wl, fn_map)
      {
        html: "<p>" + rendered.html + "</p>\n",
        shortcode_errors: rendered.shortcode_errors,
        toc: [],
        footnotes: [],
      }
    }
    FencedCode(lang, code) =>
      {
        html: render_fenced_code(lang, code),
        shortcode_errors: [],
        toc: [],
        footnotes: [],
      }
    BlockQuote(inner_blocks) => {
      let rendered = render_blocks_with_issues(
        inner_blocks, wl, heading_counts, fn_map,
      )
      {
        html: "<blockquote>\n" + rendered.html + "</blockquote>\n",
        shortcode_errors: rendered.shortcode_errors,
        toc: [],
        footnotes: [],
      }
    }
    UnorderedList(items) => {
      let buf = StringBuilder::new()
      let issues : Array[ShortcodeIssue] = []
      buf.write_string("<ul>\n")
      let mut i = 0
      while i < items.length() {
        let item = items[i]
        // Check if this is a task list item
        let mut is_task_list = item.inlines.length() > 0
        let mut task_checked = false
        let mut task_prefix_stripped : Array[Inline] = item.inlines
        if is_task_list {
          match item.inlines[0] {
            Text(t) =>
              if t.has_prefix("[ ] ") {
                task_checked = false
                let stripped = t[4:].to_string()
                // Build new array with stripped text and remaining inlines
                let new_inlines : Array[Inline] = [Text(stripped)]
                let mut j = 1
                while j < item.inlines.length() {
                  new_inlines.push(item.inlines[j])
                  j = j + 1
                }
                task_prefix_stripped = new_inlines
              } else if t.has_prefix("[x] ") || t.has_prefix("[X] ") {
                task_checked = true
                let stripped = t[4:].to_string()
                // Build new array with stripped text and remaining inlines
                let new_inlines : Array[Inline] = [Text(stripped)]
                let mut j = 1
                while j < item.inlines.length() {
                  new_inlines.push(item.inlines[j])
                  j = j + 1
                }
                task_prefix_stripped = new_inlines
              } else {
                is_task_list = false
              }
            _ => is_task_list = false
          }
        }
        let rendered_item = render_inlines_with_issues(
          task_prefix_stripped, wl, fn_map,
        )
        merge_shortcode_errors(issues, rendered_item.shortcode_errors)
        buf.write_string("<li>")
        if is_task_list {
          if task_checked {
            buf.write_string("<input type=\"checkbox\" checked disabled> ")
          } else {
            buf.write_string("<input type=\"checkbox\" disabled> ")
          }
        }
        buf.write_string(rendered_item.html)
        // Render nested blocks (lists, paragraphs, etc.)
        if item.children.length() > 0 {
          let rendered_children = render_blocks_with_issues(
            item.children,
            wl,
            heading_counts,
            fn_map,
          )
          merge_shortcode_errors(issues, rendered_children.shortcode_errors)
          buf.write_string(rendered_children.html)
        }
        buf.write_string("</li>\n")
        i = i + 1
      }
      buf.write_string("</ul>\n")
      {
        html: buf.to_string(),
        shortcode_errors: issues,
        toc: [],
        footnotes: [],
      }
    }
    OrderedList(items) => {
      let buf = StringBuilder::new()
      let issues : Array[ShortcodeIssue] = []
      buf.write_string("<ol>\n")
      let mut i = 0
      while i < items.length() {
        let item = items[i]
        let rendered_item = render_inlines_with_issues(item.inlines, wl, fn_map)
        merge_shortcode_errors(issues, rendered_item.shortcode_errors)
        buf.write_string("<li>")
        buf.write_string(rendered_item.html)
        // Render nested blocks (lists, paragraphs, etc.)
        if item.children.length() > 0 {
          let rendered_children = render_blocks_with_issues(
            item.children,
            wl,
            heading_counts,
            fn_map,
          )
          merge_shortcode_errors(issues, rendered_children.shortcode_errors)
          buf.write_string(rendered_children.html)
        }
        buf.write_string("</li>\n")
        i = i + 1
      }
      buf.write_string("</ol>\n")
      {
        html: buf.to_string(),
        shortcode_errors: issues,
        toc: [],
        footnotes: [],
      }
    }
    HRule => { html: "<hr />\n", shortcode_errors: [], toc: [], footnotes: [] }
    Table(aligns, headers, rows) => {
      let buf = StringBuilder::new()
      let issues : Array[ShortcodeIssue] = []
      buf.write_string("<table>\n<thead>\n<tr>\n")
      let mut c = 0
      while c < headers.length() {
        let align_attr = if c < aligns.length() {
          match aligns[c] {
            AlignLeft => " style=\"text-align:left\""
            AlignCenter => " style=\"text-align:center\""
            AlignRight => " style=\"text-align:right\""
            AlignDefault => ""
          }
        } else {
          ""
        }
        buf.write_string("<th" + align_attr + ">")
        let rendered = render_inlines_with_issues(headers[c], wl, fn_map)
        buf.write_string(rendered.html)
        merge_shortcode_errors(issues, rendered.shortcode_errors)
        buf.write_string("</th>\n")
        c = c + 1
      }
      buf.write_string("</tr>\n</thead>\n<tbody>\n")
      let mut r = 0
      while r < rows.length() {
        buf.write_string("<tr>\n")
        c = 0
        while c < rows[r].length() {
          let align_attr = if c < aligns.length() {
            match aligns[c] {
              AlignLeft => " style=\"text-align:left\""
              AlignCenter => " style=\"text-align:center\""
              AlignRight => " style=\"text-align:right\""
              AlignDefault => ""
            }
          } else {
            ""
          }
          buf.write_string("<td" + align_attr + ">")
          let rendered = render_inlines_with_issues(rows[r][c], wl, fn_map)
          buf.write_string(rendered.html)
          merge_shortcode_errors(issues, rendered.shortcode_errors)
          buf.write_string("</td>\n")
          c = c + 1
        }
        buf.write_string("</tr>\n")
        r = r + 1
      }
      buf.write_string("</tbody>\n</table>\n")
      {
        html: buf.to_string(),
        shortcode_errors: issues,
        toc: [],
        footnotes: [],
      }
    }
    DefinitionList(items) => {
      let buf = StringBuilder::new()
      let issues : Array[ShortcodeIssue] = []
      buf.write_string("<dl>\n")
      let mut j = 0
      while j < items.length() {
        let (term_inlines, def_groups) = items[j]
        let rendered_term = render_inlines_with_issues(term_inlines, wl, fn_map)
        merge_shortcode_errors(issues, rendered_term.shortcode_errors)
        buf.write_string("<dt>" + rendered_term.html + "</dt>\n")
        let mut k = 0
        while k < def_groups.length() {
          let rendered_def = render_inlines_with_issues(
            def_groups[k], wl, fn_map,
          )
          merge_shortcode_errors(issues, rendered_def.shortcode_errors)
          buf.write_string("<dd>" + rendered_def.html + "</dd>\n")
          k = k + 1
        }
        j = j + 1
      }
      buf.write_string("</dl>\n")
      { html: buf.to_string(), shortcode_errors: issues, toc: [], footnotes: [] }
    }
    HtmlBlock(raw) => {
      // Emit raw HTML verbatim — no escaping.  The author controls content in
      // an SSG, so passthrough is the expected and correct behavior.
      { html: raw + "\n", shortcode_errors: [], toc: [], footnotes: [] }
    }
    MathBlock(src) => {
      {
        html: "<div class=\"math-block\">\\[" +
        @strutil.escape_html_body(src) +
        "\\]</div>\n",
        shortcode_errors: [],
        toc: [],
        footnotes: [],
      }
    }
  }
}

///|
pub fn render_table_of_contents(entries : Array[TocEntry]) -> String {
  if entries.length() == 0 {
    return ""
  }
  let buf = StringBuilder::new()
  buf.write_string("<nav class=\"table-of-contents\">\n<ul>\n")
  let mut i = 0
  while i < entries.length() {
    let entry = entries[i]
    buf.write_string("<li class=\"toc-level-")
    buf.write_string(entry.level.to_string())
    buf.write_string("\"><a href=\"#")
    buf.write_string(@strutil.escape_html_body(entry.anchor))
    buf.write_string("\">")
    buf.write_string(@strutil.escape_html_body(entry.text))
    buf.write_string("</a></li>\n")
    i = i + 1
  }
  buf.write_string("</ul>\n</nav>\n")
  buf.to_string()
}

///|
pub fn extract_table_of_contents(
  body : String,
  max_depth : Int,
) -> Array[TocEntry] {
  let preprocessed = preprocess_callout_next_line(body)
  let ls = lines_of(preprocessed)
  let (blocks, _footnotes) = parse_blocks_with_footnotes(ls)
  collect_toc_entries(blocks, max_depth)
}

///|
pub fn render_with_diagnostics(
  body : String,
  wikilinks : Map[String, String],
) -> RenderResult {
  let preprocessed = preprocess_callout_next_line(body)
  let ls = lines_of(preprocessed)
  let (blocks, footnotes) = parse_blocks_with_footnotes(ls)
  let heading_counts : Map[String, Int] = Map::new()

  // Build footnote label -> ordinal map
  let fn_map : Map[String, Int] = Map::new()
  let mut i = 0
  while i < footnotes.length() {
    fn_map.set(footnotes[i].label, i + 1)
    i = i + 1
  }

  let rendered = render_blocks_with_issues(
    blocks, wikilinks, heading_counts, fn_map,
  )
  let html_with_footnotes = if footnotes.length() > 0 {
    rendered.html + render_footnotes_section(footnotes, wikilinks, fn_map)
  } else {
    rendered.html
  }
  {
    html: html_with_footnotes,
    shortcode_errors: rendered.shortcode_errors,
    toc: collect_toc_entries(blocks, 6),
    footnotes,
  }
}

///|
/// Parse and render a markdown body to an HTML fragment.
///
/// `wikilinks` maps wikilink target slugs to their resolved page URLs.
/// This map should be built from the resolved wikilinks returned by
/// `@wikilink.resolve` before calling this function.
pub fn render(body : String, wikilinks : Map[String, String]) -> String {
  render_with_diagnostics(body, wikilinks).html
}
