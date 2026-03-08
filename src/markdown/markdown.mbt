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
///   [text](url), [[wikilink]], [[wikilink|display]]
///
/// Supported block elements:
///   # Headings (h1–h6), paragraphs, ```fenced code```,
///   > blockquotes, - unordered lists, 1. ordered lists, --- hrule

/// An inline element in the markdown AST.
pub enum Inline {
  Text(String)
  Bold(Array[Inline])
  Italic(Array[Inline])
  BoldItalic(Array[Inline])
  InlineCode(String)
  Link(String, String)      // display text, url
  WikiRef(String, String?)  // target slug, optional display text
  HardBreak
}

/// A block element in the markdown AST.
pub enum Block {
  Heading(Int, Array[Inline])
  Paragraph(Array[Inline])
  FencedCode(String?, String)            // optional language tag, code text
  BlockQuote(Array[Block])
  UnorderedList(Array[Array[Inline]])    // each item is inline content
  OrderedList(Array[Array[Inline]])      // each item is inline content
  HRule
}

// ── character helpers ─────────────────────────────────────────────────────────

// MoonBit: s[i] returns UInt16 (UTF-16 code unit), not Char.
// Use this helper for all character access so comparisons against char
// literals type-check correctly.
fn char_at(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

fn substr(s : String, start : Int, end_pos : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = start
  while i < end_pos {
    buf.write_char(char_at(s, i))
    i = i + 1
  }
  buf.to_string()
}

fn starts_with_at(s : String, pos : Int, prefix : String) -> Bool {
  let plen = prefix.length()
  if pos + plen > s.length() {
    return false
  }
  let mut j = 0
  while j < plen {
    if char_at(s, pos + j) != char_at(prefix, j) {
      return false
    }
    j = j + 1
  }
  true
}

fn trim_start(s : String) -> String {
  let n = s.length()
  let mut i = 0
  while i < n && (char_at(s, i) == ' ' || char_at(s, i) == '\t') {
    i = i + 1
  }
  substr(s, i, n)
}

fn trim_end(s : String) -> String {
  let n = s.length()
  let mut j = n
  while j > 0 &&
    (char_at(s, j - 1) == ' ' ||
      char_at(s, j - 1) == '\t' ||
      char_at(s, j - 1) == '\r') {
    j = j - 1
  }
  substr(s, 0, j)
}

fn trim(s : String) -> String {
  trim_end(trim_start(s))
}

fn is_blank(s : String) -> Bool {
  trim(s).length() == 0
}

fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

// ── line splitting ────────────────────────────────────────────────────────────

fn lines_of(s : String) -> Array[String] {
  let result : Array[String] = []
  let n = s.length()
  let mut i = 0
  while i <= n {
    let mut end = i
    while end < n && char_at(s, end) != '\n' {
      end = end + 1
    }
    result.push(substr(s, i, end))
    if end >= n {
      break
    }
    i = end + 1
  }
  result
}

fn join_lines(lines : Array[String]) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  while i < lines.length() {
    if i > 0 {
      buf.write_char('\n')
    }
    buf.write_string(lines[i])
    i = i + 1
  }
  buf.to_string()
}

// ── HTML escaping ─────────────────────────────────────────────────────────────

fn escape_html(s : String) -> String {
  let buf = StringBuilder::new()
  let n = s.length()
  let mut i = 0
  while i < n {
    let c = char_at(s, i)
    if c == '&' {
      buf.write_string("&amp;")
    } else if c == '<' {
      buf.write_string("&lt;")
    } else if c == '>' {
      buf.write_string("&gt;")
    } else if c == '"' {
      buf.write_string("&quot;")
    } else {
      buf.write_char(c)
    }
    i = i + 1
  }
  buf.to_string()
}

// ── inline parsing helpers ────────────────────────────────────────────────────

/// Count consecutive occurrences of `c` starting at `pos`.
fn count_char(s : String, pos : Int, c : Char) -> Int {
  let n = s.length()
  let mut count = 0
  while pos + count < n && char_at(s, pos + count) == c {
    count = count + 1
  }
  count
}

/// Find the first occurrence of `needle` in s[from..limit]. Returns -1 if absent.
fn find_str(s : String, from : Int, needle : String, limit : Int) -> Int {
  let nlen = needle.length()
  let mut i = from
  while i + nlen <= limit {
    if starts_with_at(s, i, needle) {
      return i
    }
    i = i + 1
  }
  -1
}

/// Find the first occurrence of `c` in s[from..limit]. Returns -1 if absent.
fn find_char(s : String, from : Int, c : Char, limit : Int) -> Int {
  let mut i = from
  while i < limit {
    if char_at(s, i) == c {
      return i
    }
    i = i + 1
  }
  -1
}

/// Find the first occurrence of `c` in string `s` starting at position 0.
fn find_char_in_str(s : String, c : Char) -> Int {
  find_char(s, 0, c, s.length())
}

// ── inline parsing ────────────────────────────────────────────────────────────

/// Parse inline elements from s[from..to]. Handles bold, italic, inline code,
/// links, wikilinks, escape sequences, and hard line breaks.
pub fn parse_inlines(s : String, from : Int, to : Int) -> Array[Inline] {
  let result : Array[Inline] = []
  let mut i = from
  let mut text_start = from
  while i < to {
    let c = char_at(s, i)
    if c == '\\' && i + 1 < to {
      // backslash escape: emit accumulated text then the escaped char
      if text_start < i {
        result.push(Text(substr(s, text_start, i)))
      }
      result.push(Text(char_at(s, i + 1).to_string()))
      i = i + 2
      text_start = i
    } else if c == '`' {
      // inline code: `code`
      if text_start < i {
        result.push(Text(substr(s, text_start, i)))
      }
      let close = find_char(s, i + 1, '`', to)
      if close >= 0 {
        result.push(InlineCode(substr(s, i + 1, close)))
        i = close + 1
      } else {
        // unterminated — treat backtick as literal text
        result.push(Text("`"))
        i = i + 1
      }
      text_start = i
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
      let close = find_str(s, inner_start, close_needle, to)
      if close > inner_start {
        if text_start < i {
          result.push(Text(substr(s, text_start, i)))
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
    } else if c == '[' && i + 1 < to && char_at(s, i + 1) == '[' {
      // wikilink: [[target]] or [[target|display]]
      if text_start < i {
        result.push(Text(substr(s, text_start, i)))
      }
      let close_j = find_str(s, i + 2, "]]", to)
      if close_j >= 0 {
        let inner = substr(s, i + 2, close_j)
        let pipe = find_char_in_str(inner, '|')
        if pipe >= 0 {
          let target = trim(substr(inner, 0, pipe))
          let display = trim(substr(inner, pipe + 1, inner.length()))
          result.push(WikiRef(target, Some(display)))
        } else {
          result.push(WikiRef(trim(inner), None))
        }
        i = close_j + 2
      } else {
        // unterminated wikilink — emit as text
        result.push(Text("[["))
        i = i + 2
      }
      text_start = i
    } else if c == '[' {
      // regular link: [text](url)
      let bracket_close = find_char(s, i + 1, ']', to)
      if bracket_close >= 0 &&
        bracket_close + 1 < to &&
        char_at(s, bracket_close + 1) == '(' {
        let paren_close = find_char(s, bracket_close + 2, ')', to)
        if paren_close >= 0 {
          if text_start < i {
            result.push(Text(substr(s, text_start, i)))
          }
          let link_text = substr(s, i + 1, bracket_close)
          let url = substr(s, bracket_close + 2, paren_close)
          result.push(Link(link_text, url))
          i = paren_close + 1
          text_start = i
        } else {
          i = i + 1
        }
      } else {
        i = i + 1
      }
    } else if c == '\n' {
      // soft line break: two trailing spaces before newline = hard break,
      // otherwise collapse to a space (standard markdown behavior)
      if text_start < i {
        result.push(Text(substr(s, text_start, i)))
      }
      let is_hard = i >= 2 &&
        char_at(s, i - 1) == ' ' &&
        char_at(s, i - 2) == ' '
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
    result.push(Text(substr(s, text_start, to)))
  }
  result
}

// ── block parsing helpers ─────────────────────────────────────────────────────

fn count_leading_hashes(line : String) -> Int {
  let n = line.length()
  let mut count = 0
  while count < n && char_at(line, count) == '#' {
    count = count + 1
  }
  count
}

fn is_heading_line(line : String) -> Bool {
  let hashes = count_leading_hashes(line)
  if hashes == 0 || hashes > 6 {
    return false
  }
  let n = line.length()
  hashes < n && char_at(line, hashes) == ' '
}

fn heading_level_and_text(line : String) -> (Int, String) {
  let level = count_leading_hashes(line)
  let text = trim(substr(line, level + 1, line.length()))
  (level, text)
}

fn is_hrule(line : String) -> Bool {
  let t = trim(line)
  t == "---" || t == "***" || t == "___"
}

fn is_fence_start(line : String) -> Bool {
  starts_with_at(line, 0, "```") || starts_with_at(line, 0, "~~~")
}

fn fence_lang_tag(line : String) -> String? {
  let n = line.length()
  if n < 3 {
    return None
  }
  let lang = trim(substr(line, 3, n))
  if lang.length() == 0 {
    None
  } else {
    Some(lang)
  }
}

fn fence_char_of(line : String) -> Char {
  if line.length() > 0 {
    char_at(line, 0)
  } else {
    '`'
  }
}

fn is_fence_end(line : String, fence_char : Char) -> Bool {
  let n = line.length()
  n >= 3 &&
  char_at(line, 0) == fence_char &&
  char_at(line, 1) == fence_char &&
  char_at(line, 2) == fence_char
}

fn is_unordered_item(line : String) -> Bool {
  let n = line.length()
  n >= 2 &&
  (char_at(line, 0) == '-' || char_at(line, 0) == '*') &&
  char_at(line, 1) == ' '
}

fn is_ordered_item(line : String) -> Bool {
  let n = line.length()
  if n < 3 {
    return false
  }
  let mut i = 0
  while i < n && is_digit(char_at(line, i)) {
    i = i + 1
  }
  i > 0 && i + 1 < n && char_at(line, i) == '.' && char_at(line, i + 1) == ' '
}

fn ordered_item_text(line : String) -> String {
  let n = line.length()
  let mut i = 0
  while i < n && is_digit(char_at(line, i)) {
    i = i + 1
  }
  // skip ". " (dot and space)
  if i + 2 <= n {
    substr(line, i + 2, n)
  } else {
    ""
  }
}

fn is_blockquote_line(line : String) -> Bool {
  line.length() > 0 && char_at(line, 0) == '>'
}

fn strip_blockquote_marker(line : String) -> String {
  let n = line.length()
  if n == 0 {
    return ""
  }
  // strip '>' and optional single space after it
  let start = if n > 1 && char_at(line, 1) == ' ' { 2 } else { 1 }
  substr(line, start, n)
}

fn is_block_starter(line : String) -> Bool {
  is_heading_line(line) ||
  is_hrule(line) ||
  is_fence_start(line) ||
  is_unordered_item(line) ||
  is_ordered_item(line) ||
  is_blockquote_line(line)
}

// ── block parsing ─────────────────────────────────────────────────────────────

/// Parse an array of line strings into block AST nodes.
///
/// Block types are identified by leading characters on the first line of
/// each block. Paragraphs accumulate lines until a blank line or a block
/// starter is encountered.
pub fn parse_blocks(ls : Array[String]) -> Array[Block] {
  let result : Array[Block] = []
  let mut i = 0
  let n = ls.length()
  while i < n {
    let line = ls[i]
    if is_blank(line) {
      // skip blank lines between blocks
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
      while i < n && not(is_fence_end(ls[i], fence_char)) {
        code_lines.push(ls[i])
        i = i + 1
      }
      if i < n {
        i = i + 1 // skip closing fence
      }
      result.push(FencedCode(lang, join_lines(code_lines)))
    } else if is_blockquote_line(line) {
      let bq_lines : Array[String] = []
      while i < n && is_blockquote_line(ls[i]) {
        bq_lines.push(strip_blockquote_marker(ls[i]))
        i = i + 1
      }
      // blockquotes recurse: the stripped lines form their own block structure
      result.push(BlockQuote(parse_blocks(bq_lines)))
    } else if is_unordered_item(line) {
      let items : Array[Array[Inline]] = []
      while i < n && is_unordered_item(ls[i]) {
        let text = substr(ls[i], 2, ls[i].length())
        items.push(parse_inlines(text, 0, text.length()))
        i = i + 1
      }
      result.push(UnorderedList(items))
    } else if is_ordered_item(line) {
      let items : Array[Array[Inline]] = []
      while i < n && is_ordered_item(ls[i]) {
        let text = ordered_item_text(ls[i])
        items.push(parse_inlines(text, 0, text.length()))
        i = i + 1
      }
      result.push(OrderedList(items))
    } else {
      // paragraph: accumulate non-blank, non-block-starter lines
      let para_lines : Array[String] = []
      while i < n && not(is_blank(ls[i])) && not(is_block_starter(ls[i])) {
        para_lines.push(ls[i])
        i = i + 1
      }
      let para_text = join_lines(para_lines)
      result.push(Paragraph(parse_inlines(para_text, 0, para_text.length())))
    }
  }
  result
}

// ── rendering ─────────────────────────────────────────────────────────────────

fn render_inlines(inlines : Array[Inline], wl : Map[String, String]) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  while i < inlines.length() {
    buf.write_string(render_inline(inlines[i], wl))
    i = i + 1
  }
  buf.to_string()
}

fn render_blocks(blocks : Array[Block], wl : Map[String, String]) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  while i < blocks.length() {
    match blocks[i] {
      OrderedList(items) => {
        // Coalesce consecutive ordered-list blocks into one <ol>.
        let merged : Array[Array[Inline]] = []
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
        buf.write_string(render_block(OrderedList(merged), wl))
      }
      _ => {
        buf.write_string(render_block(blocks[i], wl))
        i = i + 1
      }
    }
  }
  buf.to_string()
}

/// Render a single inline element to an HTML string.
///
/// Wikilinks are resolved against `wl` (target slug → url). A wikilink whose
/// target is absent from `wl` renders as a broken-link anchor — this is a
/// defensive path; the build pipeline should have already aborted on missing
/// targets.
pub fn render_inline(inline : Inline, wl : Map[String, String]) -> String {
  match inline {
    Text(t) => escape_html(t)
    Bold(inner) => "<strong>" + render_inlines(inner, wl) + "</strong>"
    Italic(inner) => "<em>" + render_inlines(inner, wl) + "</em>"
    BoldItalic(inner) =>
      "<strong><em>" + render_inlines(inner, wl) + "</em></strong>"
    InlineCode(code) => "<code>" + escape_html(code) + "</code>"
    Link(text, url) =>
      "<a href=\"" + escape_html(url) + "\">" + escape_html(text) + "</a>"
    WikiRef(target, display) => {
      let text = match display {
        Some(d) => d
        None => target
      }
      match wl.get(target) {
        Some(url) =>
          "<a href=\"" + escape_html(url) + "\">" + escape_html(text) + "</a>"
        // Broken wikilink: should have been caught at build time. Render
        // visually as broken so the problem is discoverable at review.
        None =>
          "<a class=\"wl-broken\" href=\"#\">" + escape_html(text) + "</a>"
      }
    }
    HardBreak => "<br />\n"
  }
}

/// Render a single block element to an HTML string.
pub fn render_block(block : Block, wl : Map[String, String]) -> String {
  match block {
    Heading(level, inlines) => {
      let tag = "h" + level.to_string()
      "<" + tag + ">" + render_inlines(inlines, wl) + "</" + tag + ">\n"
    }
    Paragraph(inlines) => "<p>" + render_inlines(inlines, wl) + "</p>\n"
    FencedCode(lang, code) => {
      let class_attr = match lang {
        Some(l) => " class=\"language-" + escape_html(l) + "\""
        None => ""
      }
      "<pre><code" + class_attr + ">" + escape_html(code) + "</code></pre>\n"
    }
    BlockQuote(inner_blocks) => {
      "<blockquote>\n" + render_blocks(inner_blocks, wl) + "</blockquote>\n"
    }
    UnorderedList(items) => {
      let buf = StringBuilder::new()
      buf.write_string("<ul>\n")
      let mut i = 0
      while i < items.length() {
        buf.write_string("<li>")
        buf.write_string(render_inlines(items[i], wl))
        buf.write_string("</li>\n")
        i = i + 1
      }
      buf.write_string("</ul>\n")
      buf.to_string()
    }
    OrderedList(items) => {
      let buf = StringBuilder::new()
      buf.write_string("<ol>\n")
      let mut i = 0
      while i < items.length() {
        buf.write_string("<li>")
        buf.write_string(render_inlines(items[i], wl))
        buf.write_string("</li>\n")
        i = i + 1
      }
      buf.write_string("</ol>\n")
      buf.to_string()
    }
    HRule => "<hr />\n"
  }
}

/// Parse and render a markdown body to an HTML fragment.
///
/// `wikilinks` maps wikilink target slugs to their resolved page URLs.
/// This map should be built from the resolved wikilinks returned by
/// `@wikilink.resolve` before calling this function.
pub fn render(body : String, wikilinks : Map[String, String]) -> String {
  let ls = lines_of(body)
  let blocks = parse_blocks(ls)
  render_blocks(blocks, wikilinks)
}
