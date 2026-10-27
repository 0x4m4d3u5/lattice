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
  let buf = StringBuilder()
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
  let buf = StringBuilder()
  let mut i = 0
  while i < inlines.length() {
    buf.write_string(plain_text_inline(inlines[i]))
    i = i + 1
  }
  @strutil.trim(buf.to_string())
}

///|
/// Base ID for a heading's plain text. Duplicate headings use numbered suffixes.
/// Shared by heading emission and cross-note heading wikilinks.
pub fn heading_anchor(text : String) -> String {
  slugify_heading_text(text)
}

///|
fn next_heading_anchor(text : String, counts : Map[String, Int]) -> String {
  let base = heading_anchor(text)
  let mut next = match counts.get(base) {
    Some(n) => n + 1
    None => 1
  }
  let mut anchor = if next == 1 { base } else { base + "-" + next.to_string() }
  // A numbered heading may already own a duplicate's generated suffix.
  // Reserve complete emitted anchors as well as each base's suffix counter.
  while counts.contains(anchor) {
    next = next + 1
    anchor = base + "-" + next.to_string()
  }
  counts.set(base, next)
  if anchor != base {
    counts.set(anchor, 1)
  }
  anchor
}

// ── inline parsing helpers ────────────────────────────────────────────────────

///|
/// Match only the bounded scheme prefix; preserve the original URL for output.
fn has_autolink_scheme(s : String, start : Int, limit : Int) -> Bool {
  if start >= limit { return false }
  let end = if limit - start > 8 { start + 8 } else { limit }
  let prefix = @strutil.to_ascii_lower(@strutil.substr(s, start, end))
  prefix.has_prefix("https://") ||
  prefix.has_prefix("http://") ||
  prefix.has_prefix("mailto:")
}

///|
fn backtick_run_end(s : String, pos : Int, limit : Int) -> Int {
  pos + s[pos:limit].iter().take_while(c => c == '`').count()
}

///|
fn find_code_span_close(s : String, from : Int, limit : Int, width : Int) -> Int {
  let mut pos = from
  while pos < limit {
    let candidate = @strutil.find_char(s, pos, '`', limit)
    if candidate < 0 { return -1 }
    let end = backtick_run_end(s, candidate, limit)
    if end - candidate == width { return candidate }
    pos = end
  }
  -1
}

///|
/// Shared with label matching so math cannot introduce active image candidates.
fn inline_math_close(s : String, start : Int, to : Int) -> Int? {
  let from = start + 1
  if from >= to ||
    @strutil.char_at(s, from) == ' ' ||
    @strutil.char_at(s, from) == '$' {
    return None
  }
  let mut close = from
  while close < to {
    let c = @strutil.char_at(s, close)
    if c == '\n' {
      return None
    }
    if c == '$' && close > from && @strutil.char_at(s, close - 1) != '\\' {
      return Some(close)
    }
    close = close + 1
  }
  None
}

///|
/// Return the exclusive end of the angle-delimited opaque forms recognized by
/// the inline parser. Quoted tag attributes use its precomputed tag matcher.
fn inline_opaque_angle_end(
  s : String,
  start : Int,
  to : Int,
  tags : Map[Int, Int],
) -> Int? {
  let next = start + 1
  if next >= to {
    return None
  }
  if has_autolink_scheme(s, next, to) {
    let close = s[next:to]
      .find_by(c => c == '>' || c == '<' || c == ' ' || c.is_ascii_control())
      .map(n => next + n)
      .unwrap_or(-1)
    return if close > next && @strutil.char_at(s, close) == '>' {
      Some(close + 1)
    } else {
      None
    }
  }
  if @strutil.starts_with_at(s, start, "<!--") {
    let close = @strutil.find_str(s, start + 4, "-->", to)
    return if close >= 0 { Some(close + 3) } else { None }
  }
  let name = if @strutil.char_at(s, next) == '/' { next + 1 } else { next }
  if name < to {
    let c = @strutil.char_at(s, name)
    if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') {
      if tags.get(start) is Some(end) && end > start {
        return Some(end + 1)
      }
    }
  }
  None
}

///|
/// Pair destination delimiters once per inline slice, including unmatched opens.
/// A failed candidate then needs only a lookup, not another suffix scan.
fn link_destination_closes(s : String, from : Int, to : Int) -> Map[Int, Int] {
  let closes : Map[Int, Int] = Map([])
  let opens : Array[Int] = []
  let mut i = from
  while i < to {
    let c = @strutil.char_at(s, i)
    if c == '\\' &&
      i + 1 < to &&
      @strutil.char_at(s, i + 1).is_ascii_punctuation() {
      i = i + 2
    } else {
      if c == '(' {
        opens.push(i)
      }
      if c == ')' {
        match opens.pop() {
          Some(open) => closes.set(open, i)
          None => ()
        }
      }
      i = i + 1
    }
  }
  closes
}

///|
/// Cache label closers within this inline slice. A complete inline image
/// consumes its own label/destination without closing an enclosing link label.
/// Other labels retain the existing first-unescaped-closer behavior.
fn link_label_closes(s : String, from : Int, to : Int) -> Map[Int, Int] {
  let closes : Map[Int, Int] = Map([])
  let pending : Array[Int] = []
  let image_openers : Map[Int, Bool] = Map([])
  let html_ends = inline_html_tag_ends(s, from, to)
  let destinations = link_destination_closes(s, from, to)
  let mut i = from
  while i < to {
    let c = @strutil.char_at(s, i)
    if c == '\\' &&
      i + 1 < to &&
      @strutil.char_at(s, i + 1).is_ascii_punctuation() {
      i = i + 2
    } else if c == '`' {
      // Code is opaque: image-looking text must not skip active Markdown
      // after the span. Use exactly the parser's delimiter-run rules.
      let start = backtick_run_end(s, i, to)
      let width = start - i
      let close = find_code_span_close(s, start, to, width)
      i = if close >= 0 { close + width } else { start }
    } else if c == '$' && inline_math_close(s, i, to) is Some(close) {
      i = close + 1
    } else if c == '<' &&
      inline_opaque_angle_end(s, i, to, html_ends) is Some(end) {
      i = end
    } else {
      if c == '!' && i + 1 < to && @strutil.char_at(s, i + 1) == '[' {
        image_openers.set(i + 1, true)
      }
      if c == '[' {
        pending.push(i)
      }
      if c == ']' {
        if pending.length() > 0 &&
          image_openers.contains(pending[pending.length() - 1]) &&
          i + 1 < to &&
          @strutil.char_at(s, i + 1) == '(' &&
          destinations.get(i + 1) is Some(end) {
          let open = pending.pop().unwrap()
          closes.set(open, i)
          i = end + 1
          continue
        }
        for open in pending {
          closes.set(open, i)
        }
        pending.clear()
      }
      i = i + 1
    }
  }
  closes
}

///|
/// Decode escaped punctuation only after matching a complete destination or label.
fn decode_link_punctuation(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder()
  let mut i = start
  let mut text_start = start
  while i < end {
    if @strutil.char_at(s, i) == '\\' &&
      i + 1 < end &&
      @strutil.char_at(s, i + 1).is_ascii_punctuation() {
      buf.write_string(s[text_start:i].to_owned())
      buf.write_char(@strutil.char_at(s, i + 1))
      i = i + 2
      text_start = i
    } else {
      i = i + 1
    }
  }
  buf.write_string(s[text_start:end].to_owned())
  buf.to_string()
}

///|
/// Compute quote-aware tag ends once per inline slice. Reverse scanning keeps
/// the next end for unquoted, single-quoted and double-quoted suffixes, so even
/// malformed candidates need only a lookup rather than another suffix scan.
fn inline_html_tag_ends(s : String, from : Int, to : Int) -> Map[Int, Int] {
  let ends : Map[Int, Int] = Map([])
  let mut unquoted = -1
  let mut single_quoted = -1
  let mut double_quoted = -1
  let mut i = to
  while i > from {
    i = i - 1
    let c = @strutil.char_at(s, i)
    let next_unquoted = unquoted
    unquoted = if c == '>' {
      i
    } else if c == '\'' {
      single_quoted
    } else if c == '"' {
      double_quoted
    } else {
      unquoted
    }
    if c == '\'' {
      single_quoted = next_unquoted
    }
    if c == '"' {
      double_quoted = next_unquoted
    }
    if c == '<' {
      ends.set(i, unquoted)
    }
  }
  ends
}

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
fn mark_code_callout_restores(
  planned : Array[String],
  origins : Array[Int],
  expanded : Array[Bool],
  source : Array[String],
  restore : Map[Int, Bool],
) -> Unit {
  ignore(parse_blocks_with_code_lines(planned, Some(fn(start, end, prefix) {
    let mut row = start + 1
    while row <= end && row < planned.length() {
      if expanded[row] {
        let next = source[origins[row] + 1]
        if next.length() >= prefix && next[0:prefix].iter().all(c => c == ' ') &&
          !is_block_starter(next[prefix:next.length()].to_owned()) {
          restore.set(origins[row], true)
        }
      }
      row = row + 1
    }
  })))
}

///|
fn preprocess_callout_next_line(body : String) -> String {
  let ls = lines_of(body)
  let planned : Array[String] = []
  let indented : Array[String] = []
  let origins : Array[Int] = []
  let expanded : Array[Bool] = []
  let mut has_expansions = false
  let mut has_indented_expansions = false
  let mut i = 0
  while i < ls.length() {
    let line = ls[i]
    if is_full_shortcode_line(line) {
      let raw = shortcode_inner_text_from_line(line)
      match @shortcode.parse(raw) {
        Ok(call) =>
          if call.name == "callout" && i + 1 < ls.length() && !is_blank(ls[i + 1]) {
            let merged = @strutil.trim(line) + " " + @strutil.trim(ls[i + 1]) + " {{< /callout >}}"
            let indent = line.iter().take_while(c => c.is_whitespace()).count()
            planned.push(merged)
            indented.push(@strutil.substr(line, 0, indent) + merged)
            if indent > 0 { has_indented_expansions = true }
            origins.push(i)
            expanded.push(true)
            has_expansions = true
            i = i + 2
            continue
          }
        Err(_) => ()
      }
    }
    planned.push(line)
    indented.push(line)
    origins.push(i)
    expanded.push(false)
    i = i + 1
  }
  if !has_expansions || !body.contains("`") {
    return @strutil.join_lines(planned)
  }
  // Preserve nesting while identifying literal spans. Active expansions still
  // retain their legacy output; a second bounded pass accounts for that context.
  let mut restore : Map[Int, Bool] = Map([])
  mark_code_callout_restores(indented, origins, expanded, ls, restore)
  if has_indented_expansions {
    let adjusted : Array[String] = []
    let adjusted_origins : Array[Int] = []
    let adjusted_expanded : Array[Bool] = []
    i = 0
    while i < planned.length() {
      let origin = origins[i]
      if restore.contains(origin) {
        adjusted.push(ls[origin])
        adjusted_origins.push(origin)
        adjusted_expanded.push(true)
        adjusted.push(ls[origin + 1])
        adjusted_origins.push(origin + 1)
        adjusted_expanded.push(false)
      } else {
        adjusted.push(planned[i])
        adjusted_origins.push(origin)
        adjusted_expanded.push(expanded[i])
      }
      i = i + 1
    }
    // Reassess restored openings too: a retained legacy expansion can dedent
    // the paragraph and invalidate a code span from the indentation-only plan.
    let reassessed : Map[Int, Bool] = Map([])
    mark_code_callout_restores(adjusted, adjusted_origins, adjusted_expanded, ls, reassessed)
    restore = reassessed
  }
  let out : Array[String] = []
  i = 0
  while i < planned.length() {
    if restore.contains(origins[i]) {
      out.push(ls[origins[i]])
      out.push(ls[origins[i] + 1])
    } else {
      out.push(planned[i])
    }
    i = i + 1
  }
  @strutil.join_lines(out)
}

// ── inline parsing ────────────────────────────────────────────────────────────

///|
/// Parse inline elements from s[from..to]. Handles bold, italic, inline code,
/// links, wikilinks, escape sequences, and hard line breaks.
pub fn parse_inlines(s : String, from : Int, to : Int) -> Array[Inline] {
  parse_inlines_with_code_ranges(s, from, to, None)
}

///|
fn parse_inlines_with_code_ranges(
  s : String,
  from : Int,
  to : Int,
  on_code : ((Int, Int) -> Unit)?,
) -> Array[Inline] {
  let result : Array[Inline] = []
  let exhausted_underscore_closers : Map[Int, Bool] = Map([])
  let mut html_tag_ends : Map[Int, Int]? = None
  fn opaque_angle_end_at(start : Int) -> Int? {
    let ends = match html_tag_ends {
      Some(ends) => ends
      None => {
        let ends = inline_html_tag_ends(s, from, to)
        html_tag_ends = Some(ends)
        ends
      }
    }
    inline_opaque_angle_end(s, start, to, ends)
  }
  let mut label_closes : Map[Int, Int]? = None
  fn label_close_at(open : Int) -> Int {
    let closes = match label_closes {
      Some(closes) => closes
      None => {
        let closes = link_label_closes(s, from, to)
        label_closes = Some(closes)
        closes
      }
    }
    closes.get(open).unwrap_or(-1)
  }
  let mut destination_closes : Map[Int, Int]? = None
  fn destination_at(open : Int) -> (String, Int)? {
    let closes = match destination_closes {
      Some(closes) => closes
      None => {
        let closes = link_destination_closes(s, from, to)
        destination_closes = Some(closes)
        closes
      }
    }
    match closes.get(open) {
      Some(end) => Some((decode_link_punctuation(s, open + 1, end), end))
      None => None
    }
  }
  let mut i = from
  let mut text_start = from
  while i < to {
    let c = @strutil.char_at(s, i)
    if c == '\\' && i + 1 < to &&
      (@strutil.char_at(s, i + 1).is_ascii_punctuation() ||
        @strutil.char_at(s, i + 1) == '\n' ||
        @strutil.char_at(s, i + 1) == '\r') {
      // Only ASCII punctuation can be escaped; other backslashes stay literal.
      if text_start < i {
        result.push(Text(@strutil.substr(s, text_start, i)))
      }
      let next = @strutil.char_at(s, i + 1)
      if next == '\n' || next == '\r' {
        result.push(HardBreak)
      } else {
        result.push(Text(next.to_string()))
      }
      i = i + 2
      // CRLF is one line ending; do not consume LF outside the current slice.
      if next == '\r' && i < to && @strutil.char_at(s, i) == '\n' {
        i = i + 1
      }
      text_start = i
    } else if c == '`' {
      // Match the complete delimiter run; shorter/longer runs stay code text.
      if text_start < i {
        result.push(Text(@strutil.substr(s, text_start, i)))
      }
      let content_start = backtick_run_end(s, i, to)
      let width = content_start - i
      let close = find_code_span_close(s, content_start, to, width)
      if close >= 0 {
        match on_code {
          Some(report) => report(i, close + width)
          None => ()
        }
        result.push(InlineCode(@strutil.substr(s, content_start, close)))
        i = close + width
      } else {
        // An unmatched run is literal; following Markdown still gets parsed.
        result.push(Text(@strutil.substr(s, i, content_start)))
        i = content_start
      }
      text_start = i
    } else if c == '$' {
      match inline_math_close(s, i, to) {
        Some(close) => {
          if text_start < i {
            result.push(Text(@strutil.substr(s, text_start, i)))
          }
          result.push(Math(@strutil.substr(s, i + 1, close)))
          i = close + 1
          text_start = i
        }
        None => i = i + 1
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
        let inner = parse_inlines_with_code_ranges(s, inner_start, close, on_code)
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
        let inner = parse_inlines_with_code_ranges(s, inner_start, close, on_code)
        result.push(Strikethrough(inner))
        i = close + 2
        text_start = i
      } else {
        // no matching close — treat tildes as literal text
        i = i + 1
      }
    } else if c == '_' {
      let under_count = count_char(s, i, '_')
      // underscore emphasis: _italic_, __bold__, ___bold italic___
      // Word-boundary rule: only treat _ as opener if the char before it is
      // NOT alphanumeric. This prevents snake_case identifiers from being
      // parsed as emphasis — a pragmatic compromise for SSG content.
      let prev_is_alnum = i > 0 &&
        ({
          let prev = @strutil.char_at(s, i - 1)
          @strutil.is_alpha(prev) || @strutil.is_digit(prev)
        })
      if prev_is_alnum {
        // Keep the whole intraword delimiter run literal.
        i = i + under_count
      } else {
        let inner_start = i + under_count
        let close_needle = if under_count >= 3 {
          "___"
        } else if under_count == 2 {
          "__"
        } else {
          "_"
        }
        let mut close = if exhausted_underscore_closers.get(under_count).unwrap_or(false) {
          -1
        } else {
          @strutil.find_str(s, inner_start, close_needle, to)
        }
        while close > inner_start {
          // Skip every intraword candidate, not just the first two.
          let close_end = close + under_count
          let next_is_alnum = close_end < to &&
            ({
              let next = @strutil.char_at(s, close_end)
              @strutil.is_alpha(next) || @strutil.is_digit(next)
            })
          if !next_is_alnum { break }
          close = @strutil.find_str(s, close + 1, close_needle, to)
        }
        if close < 0 {
          // No later opener of this width can find a closer in this slice.
          exhausted_underscore_closers.set(under_count, true)
        }
        if close > inner_start {
          if text_start < i {
            result.push(Text(@strutil.substr(s, text_start, i)))
          }
          let inner = parse_inlines_with_code_ranges(s, inner_start, close, on_code)
          if under_count >= 3 {
            result.push(BoldItalic(inner))
          } else if under_count == 2 {
            result.push(Bold(inner))
          } else {
            result.push(Italic(inner))
          }
          i = close + under_count
          text_start = i
        } else {
          // no matching close — treat underscores as literal text
          i = i + 1
        }
      }
    } else if c == '<' {
      match opaque_angle_end_at(i) {
        Some(end) => {
          if text_start < i {
            result.push(Text(@strutil.substr(s, text_start, i)))
          }
          if has_autolink_scheme(s, i + 1, to) {
            let url = @strutil.substr(s, i + 1, end - 1)
            result.push(Link([Text(url)], url))
          } else {
            result.push(InlineHtml(@strutil.substr(s, i, end)))
          }
          i = end
          text_start = i
        }
        None => i = i + 1
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
                let copied : Map[String, @shortcode.ShortcodeParam] = Map([])
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
      let bracket_close = label_close_at(i + 1)
      if bracket_close >= 0 &&
        bracket_close + 1 < to &&
        @strutil.char_at(s, bracket_close + 1) == '(' {
        if destination_at(bracket_close + 1) is Some((url, paren_close)) {
          if text_start < i {
            result.push(Text(@strutil.substr(s, text_start, i)))
          }
          let alt = decode_link_punctuation(s, i + 2, bracket_close)
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
        let bracket_close = label_close_at(i)
        if bracket_close >= 0 &&
          bracket_close + 1 < to &&
          @strutil.char_at(s, bracket_close + 1) == '(' {
          if destination_at(bracket_close + 1) is Some((url, paren_close)) {
            if text_start < i {
              result.push(Text(@strutil.substr(s, text_start, i)))
            }
            let link_text = @strutil.substr(s, i + 1, bracket_close)
            let link_start = i + 1
            result.push(
              Link(parse_inlines_with_code_ranges(link_text, 0, link_text.length(),
                on_code.map(fn(report) { fn(start, end) { report(start + link_start, end + link_start) } }),
              ), url),
            )
            i = paren_close + 1
            text_start = i
          } else {
            i = i + 1
          }
        } else {
          i = i + 1
        }
      }
    } else if c == '\n' || c == '\r' {
      // Treat CRLF as one ending. Two or more trailing spaces are the hard
      // break delimiter; keep lookbehind inside the current inline slice.
      let is_hard = i - from >= 2 &&
        @strutil.char_at(s, i - 1) == ' ' &&
        @strutil.char_at(s, i - 2) == ' '
      let mut text_end = i
      if is_hard {
        while text_end > text_start && @strutil.char_at(s, text_end - 1) == ' ' {
          text_end = text_end - 1
        }
      }
      if text_start < text_end {
        result.push(Text(@strutil.substr(s, text_start, text_end)))
      }
      if is_hard {
        result.push(HardBreak)
      } else {
        result.push(Text(" "))
      }
      i = i + 1
      if c == '\r' && i < to && @strutil.char_at(s, i) == '\n' {
        i = i + 1
      }
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
  hashes == n ||
  (hashes + 1 == n && @strutil.char_at(line, hashes) == '\r') ||
  @strutil.char_at(line, hashes) == ' ' ||
  @strutil.char_at(line, hashes) == '\t'
}

///|
fn heading_level_and_text(line : String) -> (Int, String) {
  let level = count_leading_hashes(line)
  let raw = line[level:].trim_end(chars=" \t\r").to_owned()
  let mut end = raw.length()
  while end > 0 && raw[end - 1] == '#' {
    end = end - 1
  }
  // Closing hashes are syntax only when preceded by horizontal whitespace.
  // Keep that whitespace until this check so escaped/attached hashes stay text.
  let text = if end < raw.length() &&
    end > 0 &&
    (raw[end - 1] == ' ' || raw[end - 1] == '\t') {
    raw[:end].to_owned()
  } else {
    raw
  }
  (level, @strutil.trim(text))
}

///|
pub fn is_hrule(line : String) -> Bool {
  let t = @strutil.trim(line)
  if t.is_empty() { return false }
  let marker = @strutil.char_at(t, 0)
  if marker != '-' && marker != '*' && marker != '_' { return false }
  let mut count = 0
  for c in t.iter() {
    if c == marker {
      count = count + 1
    } else if c != ' ' && c != '\t' {
      return false
    }
  }
  count >= 3
}

///|
pub fn is_fence_start(line : String) -> Bool {
  if @strutil.starts_with_at(line, 0, "~~~") { return true }
  if !@strutil.starts_with_at(line, 0, "```") { return false }
  // A backtick fence's info string cannot contain backticks, even escaped ones.
  let width = line.iter().take_while(c => c == '`').count()
  line[width:].find("`") is None
}

///|
fn fence_lang_tag(line : String, width : Int) -> String? {
  let n = line.length()
  if n < 3 {
    return None
  }
  let lang = @strutil.trim(@strutil.substr(line, width, n))
  if lang.length() == 0 {
    None
  } else {
    let end = lang.find_by(c => c == ' ' || c == '\t').unwrap_or(lang.length())
    Some(lang[:end].to_owned())
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
  is_fence_end_with_width(line, fence_char, 3)
}

///|
/// Check a candidate using the character and width cached from its opener.
pub fn is_fence_end_with_width(
  line : String,
  fence_char : Char,
  minimum_width : Int,
) -> Bool {
  let n = line.length()
  if n < 3 || n < minimum_width ||
    @strutil.char_at(line, 0) != fence_char ||
    @strutil.char_at(line, 1) != fence_char ||
    @strutil.char_at(line, 2) != fence_char {
    return false
  }
  let end = line.iter().take_while(c => c == fence_char).count()
  end >= minimum_width && line[end:].trim(chars=" \t\r").is_empty()
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
  // Split only unescaped pipes. Decode \| at the table layer so code spans
  // and wikilink aliases receive the literal pipe before inline parsing.
  let cells : Array[String] = []
  let mut cell = StringBuilder()
  let mut i = start
  let mut trailing_separator = false
  while i < n {
    let c = @strutil.char_at(t, i)
    if c == '\\' {
      let run_start = i
      while i < n && @strutil.char_at(t, i) == '\\' {
        i = i + 1
      }
      // GFM treats any backslash run before a pipe as cell content. Remove
      // exactly one backslash; preserve the rest for subsequent inline parsing.
      let escaped_pipe = i < n && @strutil.char_at(t, i) == '|'
      let run_end = if escaped_pipe { i - 1 } else { i }
      for _ in run_start..<run_end {
        cell.write_char('\\')
      }
      if escaped_pipe {
        cell.write_char('|')
        i = i + 1
      }
      trailing_separator = false
    } else if c == '|' {
      cells.push(@strutil.trim(cell.to_string()))
      cell = StringBuilder()
      trailing_separator = true
      i = i + 1
    } else {
      cell.write_char(c)
      trailing_separator = false
      i = i + 1
    }
  }
  if !trailing_separator || cells.is_empty() {
    cells.push(@strutil.trim(cell.to_string()))
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
  if has_autolink_scheme(line, 1, n) {
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

///|
fn is_block_starter(line : String) -> Bool {
  is_heading_line(line) ||
  is_hrule(line) ||
  is_fence_start(line) ||
  is_unordered_item(line) ||
  is_ordered_item(line) ||
  is_blockquote_line(line) ||
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
  let (blocks, footnotes) = parse_blocks_with_code_lines(ls, None)
  // Keep the first definition in source order, including nested definitions.
  let labels : @hashset.HashSet[String] = @hashset.HashSet([])
  (blocks, footnotes.filter(fn(note) { labels.add_and_check(note.label) }))
}

///|
fn parse_blocks_with_code_lines(
  ls : Array[String],
  on_code : ((Int, Int, Int) -> Unit)?,
) -> (Array[Block], Array[FootnoteDef]) {
  let result : Array[Block] = []
  let footnotes : Array[FootnoteDef] = []
  let mut i = 0
  let n = ls.length()
  // A failed scan proves no math closer remains in this block context.
  let mut math_closers_exhausted = false
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
      let width = line.iter().take_while(c => c == fence_char).count()
      let lang = fence_lang_tag(line, width)
      let code_lines : Array[String] = []
      i = i + 1
      while i < n && !is_fence_end_with_width(ls[i], fence_char, width) {
        code_lines.push(ls[i])
        i = i + 1
      }
      if i < n {
        i = i + 1 // skip closing fence
      }
      result.push(FencedCode(lang, @strutil.join_lines(code_lines)))
    } else if is_blockquote_line(line) {
      let bq_lines : Array[String] = []
      let bq_start = i
      while i < n && is_blockquote_line(ls[i]) {
        bq_lines.push(strip_blockquote_marker(ls[i]))
        i = i + 1
      }
      // blockquotes recurse: the stripped lines form their own block structure
      let (bq_blocks, nested_footnotes) = parse_blocks_with_code_lines(bq_lines,
        on_code.map(fn(report) { fn(start, end, prefix) { report(start + bq_start, end + bq_start, prefix + 2) } }),
      )
      for note in nested_footnotes {
        footnotes.push(note)
      }
      result.push(BlockQuote(bq_blocks))
    } else if is_unordered_item(line) {
      let items : Array[ListItem] = []
      // Single-pass: consume each item line then immediately consume its
      // indented continuation lines before moving to the next item.
      while i < n && is_unordered_item(ls[i]) && !is_hrule(ls[i]) {
        let text = @strutil.trim_end(@strutil.substr(ls[i], 2, ls[i].length()))
        i = i + 1
        // Collect indented continuation lines belonging to this item.
        let nested_lines : Array[String] = []
        let nested_start = i
        while i < n && is_nested_indent(ls[i]) {
          nested_lines.push(@strutil.substr(ls[i], 2, ls[i].length()))
          i = i + 1
        }
        let children : Array[Block] = if nested_lines.length() > 0 {
          let (nested_blocks, nested_footnotes) = parse_blocks_with_code_lines(nested_lines,
            on_code.map(fn(report) { fn(start, end, prefix) { report(start + nested_start, end + nested_start, prefix + 2) } }),
          )
          for note in nested_footnotes {
            footnotes.push(note)
          }
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
        let text = @strutil.trim_end(ordered_item_text(ls[i]))
        i = i + 1
        // Collect indented continuation lines belonging to this item.
        let nested_lines : Array[String] = []
        let nested_start = i
        while i < n && is_nested_indent(ls[i]) {
          nested_lines.push(@strutil.substr(ls[i], 2, ls[i].length()))
          i = i + 1
        }
        let children : Array[Block] = if nested_lines.length() > 0 {
          let (nested_blocks, nested_footnotes) = parse_blocks_with_code_lines(nested_lines,
            on_code.map(fn(report) { fn(start, end, prefix) { report(start + nested_start, end + nested_start, prefix + 2) } }),
          )
          for note in nested_footnotes {
            footnotes.push(note)
          }
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
      // Continuations must honor the same earlier block branches as the outer
      // parser. Keep the shared paragraph-boundary predicate unchanged.
      while i < n && is_definition_term_start(ls, i) &&
        !is_footnote_def_line(ls[i]) &&
        !is_heading_line(ls[i]) &&
        !is_hrule(ls[i]) &&
        !is_fence_start(ls[i]) &&
        !is_blockquote_line(ls[i]) &&
        !is_unordered_item(ls[i]) &&
        !is_ordered_item(ls[i]) {
        let term_str = @strutil.trim_end(ls[i])
        let term_inlines = parse_inlines(term_str, 0, term_str.length())
        i = i + 1
        // Collect all : definition lines for this term
        let defs : Array[Array[Inline]] = []
        while i < n && is_definition_line(ls[i]) {
          // Strip ": " prefix and any extra leading whitespace (e.g. ":   ")
          let def_text = @strutil.trim(
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
      is_separator_row(ls[i + 1]) &&
      split_table_row(line).length() == split_table_row(ls[i + 1]).length() {
      // GFM tables require matching header and separator column counts.
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
      let math_start = i
      // Display math block: $$...$$
      let t = @strutil.trim(line)
      let math_lines : Array[String] = []
      // If the opening line has content after $$, include it
      if t.length() > 2 {
        math_lines.push(@strutil.trim(@strutil.substr(t, 2, t.length())))
      }
      i = i + 1
      let mut found_close = false
      while !math_closers_exhausted && i < n {
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
        // Resume after the literal opener; failed lookahead must not eat prose.
        math_closers_exhausted = true
        i = math_start + 1
        let text = @strutil.trim_end(line)
        result.push(Paragraph(parse_inlines(text, 0, text.length())))
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
      let para_start = i
      // A definition marker alone is prose; only a term/definition pair starts
      // a block. Stop before its term so the outer parser can consume the pair.
      while i < n && !is_blank(ls[i]) && !is_block_starter(ls[i]) &&
        !is_definition_term_start(ls, i) {
        para_lines.push(ls[i])
        i = i + 1
      }
      // Discard paragraph-final whitespace, including the CR retained when
      // lines_of consumes a CRLF boundary. Internal code-span text stays intact.
      let para_text = @strutil.join_lines(para_lines).trim_end(chars=" \t\r").to_owned()
      // Code ranges arrive in source order. Count newlines only in the newly
      // visited slices rather than rescanning each range's paragraph prefix.
      let code_ranges = on_code.map(fn(report) {
        let mut scanned = 0
        let mut row = para_start
        fn(start, end) {
          row = row + @strutil.substr(para_text, scanned, start).split("\n").count() - 1
          let first = row
          row = row + @strutil.substr(para_text, start, end).split("\n").count() - 1
          scanned = end
          report(first, row, 0)
        }
      })
      let inlines = parse_inlines_with_code_ranges(para_text, 0, para_text.length(), code_ranges)
      result.push(Paragraph(inlines))
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
      UnorderedList(items) | OrderedList(items) =>
        for item in items {
          // Match rendering order, including headings excluded by depth,
          // so later duplicate headings keep their actual rendered anchors.
          collect_toc_entries_into(item.children, max_depth, counts, entries)
        }
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
  let counts : Map[String, Int] = Map([])
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
  let buf = StringBuilder()
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
  on_leading_h1 : ((Int) -> Unit)?,
  on_block : ((Block, String) -> Unit)?,
) -> RenderResult {
  let buf = StringBuilder()
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
        if on_block is Some(record) { record(OrderedList(merged), rendered.html) }
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
        if on_block is Some(record) { record(blocks[i], rendered.html) }
        buf.write_string(rendered.html)
        merge_shortcode_errors(issues, rendered.shortcode_errors)
        if i == 0 {
          match (blocks[i], on_leading_h1) {
            (Heading(1, _), Some(record)) => record(rendered.html.length())
            _ => ()
          }
        }
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
        @strutil.escape_html_attr(l) +
        "\"><code>" +
        highlighted +
        "</code></pre>\n"
      } else {
        "<pre><code class=\"language-" +
        @strutil.escape_html_attr(l) +
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
) -> RenderResult {
  let buf = StringBuilder()
  let issues : Array[ShortcodeIssue] = []
  buf.write_string("\n<section class=\"footnotes\">\n<ol>\n")
  let mut i = 0
  while i < footnotes.length() {
    let footnote = footnotes[i]
    buf.write_string("<li id=\"fn-")
    buf.write_string(@strutil.escape_html_body(footnote.label))
    buf.write_string("\">")
    // Render inline markdown in footnote text (e.g. **bold**, `code`)
    let inlines = parse_inlines(footnote.text, 0, footnote.text.length())
    let rendered_text = render_inlines_with_issues(inlines, wl, fn_map)
    merge_shortcode_errors(issues, rendered_text.shortcode_errors)
    buf.write_string(rendered_text.html)
    buf.write_string(" <a href=\"#fnref-")
    buf.write_string(@strutil.escape_html_body(footnote.label))
    buf.write_string("\" class=\"footnote-backref\">↩</a>")
    buf.write_string("</li>\n")
    i = i + 1
  }
  buf.write_string("</ol>\n</section>\n")
  { html: buf.to_string(), shortcode_errors: issues, toc: [], footnotes: [], }
}

///|
/// Render a single inline element to an HTML string.
///
/// Wikilinks are resolved against `wl` (target slug → url). A wikilink whose
/// target is absent from `wl` renders as a broken-link anchor — this is a
/// defensive path; the build pipeline should have already aborted on missing
/// targets.
pub fn render_inline(inline : Inline, wl : Map[String, String]) -> String {
  let fn_map : Map[String, Int] = Map([])
  render_inline_with_issues(inline, wl, fn_map).html
}

///|
/// Normalize literal URI quotes before HTML attribute escaping. Preserve existing
/// percent escapes, URI delimiters and the renderer's Unicode URL spelling.
fn escape_destination_attr(url : String) -> String {
  @strutil.escape_html_attr(url.replace_all(old="\"", new="%22"))
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
        escape_destination_attr(url) +
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
        escape_destination_attr(url) +
        "\" alt=\"" +
        @strutil.escape_html_attr(alt) +
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
            escape_destination_attr(url) +
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
  let counts : Map[String, Int] = Map([])
  let fn_map : Map[String, Int] = Map([])
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
        inner_blocks, wl, heading_counts, fn_map, None, None,
      )
      {
        html: "<blockquote>\n" + rendered.html + "</blockquote>\n",
        shortcode_errors: rendered.shortcode_errors,
        toc: [],
        footnotes: [],
      }
    }
    UnorderedList(items) => {
      let buf = StringBuilder()
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
                let stripped = t[4:].to_owned()
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
                let stripped = t[4:].to_owned()
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
            None,
            None,
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
      let buf = StringBuilder()
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
            None,
            None,
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
      let buf = StringBuilder()
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
      let buf = StringBuilder()
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
            def_groups[k],
            wl,
            fn_map,
          )
          merge_shortcode_errors(issues, rendered_def.shortcode_errors)
          buf.write_string("<dd>" + rendered_def.html + "</dd>\n")
          k = k + 1
        }
        j = j + 1
      }
      buf.write_string("</dl>\n")
      {
        html: buf.to_string(),
        shortcode_errors: issues,
        toc: [],
        footnotes: [],
      }
    }
    HtmlBlock(raw) =>
      // Emit raw HTML verbatim — no escaping.  The author controls content in
      // an SSG, so passthrough is the expected and correct behavior.
      { html: raw + "\n", shortcode_errors: [], toc: [], footnotes: [] }
    MathBlock(src) =>
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

///|
pub fn render_table_of_contents(entries : Array[TocEntry]) -> String {
  if entries.length() == 0 {
    return ""
  }
  let buf = StringBuilder()
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
fn visit_inlines(
  inlines : Array[Inline],
  visit : (Inline) -> Unit,
) -> Unit {
  for inline in inlines {
    visit(inline)
    match inline {
      Bold(inner)
      | Italic(inner)
      | BoldItalic(inner)
      | Strikethrough(inner)
      | Link(inner, _) => visit_inlines(inner, visit)
      Text(_) | InlineCode(_) | Image(_, _) | WikiRef(_, _) | FootnoteRef(_) |
      Shortcode(_) | Math(_) | InlineHtml(_) | HardBreak => ()
    }
  }
}

///|
fn visit_blocks(
  blocks : Array[Block],
  visit : (Inline) -> Unit,
) -> Unit {
  for block in blocks {
    match block {
      Heading(_, inlines) | Paragraph(inlines) =>
        visit_inlines(inlines, visit)
      BlockQuote(children) => visit_blocks(children, visit)
      UnorderedList(items) | OrderedList(items) =>
        for item in items {
          visit_inlines(item.inlines, visit)
          visit_blocks(item.children, visit)
        }
      Table(_, headers, rows) => {
        for cell in headers {
          visit_inlines(cell, visit)
        }
        for row in rows {
          for cell in row {
            visit_inlines(cell, visit)
          }
        }
      }
      DefinitionList(items) =>
        for (term, definitions) in items {
          visit_inlines(term, visit)
          for definition in definitions {
            visit_inlines(definition, visit)
          }
        }
      FencedCode(_, _) | HRule | MathBlock(_) | HtmlBlock(_) => ()
    }
  }
}

///|
/// Visit the same parsed body and footnotes as rendering. This private AST walk
/// excludes code, math, raw HTML and shortcode bodies; it does not scan text.
fn visit_body_inlines(body : String, visit : (Inline) -> Unit) -> Unit {
  let (blocks, footnotes) = parse_blocks_with_footnotes(
    lines_of(preprocess_callout_next_line(body)),
  )
  visit_blocks(blocks, visit)
  for footnote in footnotes {
    visit_inlines(
      parse_inlines(footnote.text, 0, footnote.text.length()), visit,
    )
  }
}

///|
/// Collect only references parsed as rendered wikilinks.
pub fn extract_wikilink_targets(body : String) -> Array[(String, String?)] {
  let targets : Array[(String, String?)] = []
  visit_body_inlines(body, fn(inline) {
    match inline {
      WikiRef(target, display) =>
        if target != "" { targets.push((target, display)) }
      _ => ()
    }
  })
  targets
}

///|
/// One URL per parsed Markdown image with empty or whitespace-only alt text.
/// Image/figure shortcodes also reject nonempty whitespace-only alt values.
/// Their explicit alt="" remains decorative. Malformed shortcodes keep their
/// native errors; raw HTML and other shortcode bodies are outside this scope.
pub fn missing_image_alt_urls(body : String) -> Array[String] {
  let urls : Array[String] = []
  visit_body_inlines(body, fn(inline) {
    match inline {
      Image(alt, url) =>
        if alt.iter().all(c => c.is_whitespace()) { urls.push(url) }
      Shortcode(call) =>
        if call.name == "image" || call.name == "figure" {
          match (call.params.get("alt"), call.params.get("src")) {
            (Some(@shortcode.StringParam(alt)), Some(@shortcode.StringParam(url))) =>
              if alt.length() > 0 && alt.iter().all(c => c.is_whitespace()) {
                // Diagnose only images the shortcode renderer can emit. Invalid
                // params retain E008 instead of being masked by this policy.
                match @shortcode.render(call) {
                  Ok(_) => urls.push(url)
                  Err(_) => ()
                }
              }
            _ => ()
          }
        }
      _ => ()
    }
  })
  urls
}

///|
pub fn render_with_diagnostics(
  body : String,
  wikilinks : Map[String, String],
) -> RenderResult {
  let (result, _) = render_with_leading_h1_boundary(body, wikilinks)
  result
}

///|
/// Render once and report the exclusive end of the first block when it is H1.
/// The optional offset uses String's UTF-16 code units and indexes result.html.
/// IDs, diagnostics, TOC entries, and footnotes include the entire document.
pub fn render_with_leading_h1_boundary(
  body : String,
  wikilinks : Map[String, String],
) -> (RenderResult, Int?) {
  render_document(body, wikilinks, None)
}

///|
/// Plain text grouped by top-level Markdown headings. Nested headings stay in
/// their enclosing section; heading labels are separate from section bodies.
pub(all) struct TextSection {
  heading : String
  body : String
}

///|
/// Collect sections in the same rendering pass, preserving normal HTML and IDs.
/// Optional section_offsets receives one UTF-16 heading start per section;
/// preambles and generated footnotes have None. Offsets describe renderer origin,
/// not a guarantee that a template publishes that heading.
pub fn render_with_text_sections(
  body : String,
  wikilinks : Map[String, String],
  section_offsets? : Array[Int?] = [],
) -> (RenderResult, Int?, Array[TextSection]) {
  let sections : Array[TextSection] = []
  let (rendered, boundary) = render_document(
    body,
    wikilinks,
    Some(sections),
    section_offsets~,
  )
  (rendered, boundary, sections)
}

///|
fn render_document(
  body : String,
  wikilinks : Map[String, String],
  sections : Array[TextSection]?,
  section_offsets? : Array[Int?] = [],
) -> (RenderResult, Int?) {
  let preprocessed = preprocess_callout_next_line(body)
  let ls = lines_of(preprocessed)
  let (blocks, footnotes) = parse_blocks_with_footnotes(ls)
  let heading_counts : Map[String, Int] = Map([])

  // Build footnote label -> ordinal map
  let fn_map : Map[String, Int] = Map([])
  let mut i = 0
  while i < footnotes.length() {
    fn_map.set(footnotes[i].label, i + 1)
    i = i + 1
  }

  let mut leading_h1_end : Int? = None
  let heading_ranges : Array[(Int, Int)] = []
  let mut html_offset = 0
  let on_block = match sections {
    None => None
    Some(_) => Some(fn(block : Block, html : String) {
      let end = html_offset + html.length()
      if block is Heading(_, _) { heading_ranges.push((html_offset, end)) }
      html_offset = end
    })
  }
  let rendered = render_blocks_with_issues(
    blocks, wikilinks, heading_counts, fn_map,
    Some(fn(end) { leading_h1_end = Some(end) }),
    on_block,
  )
  let html_with_footnotes = if footnotes.length() > 0 {
    let rendered_footnotes = render_footnotes_section(
      footnotes, wikilinks, fn_map,
    )
    merge_shortcode_errors(
      rendered.shortcode_errors,
      rendered_footnotes.shortcode_errors,
    )
    // A zero-width heading range labels the renderer's appended reference list.
    heading_ranges.push((rendered.html.length(), rendered.html.length()))
    rendered.html + rendered_footnotes.html
  } else {
    rendered.html
  }
  if sections is Some(items) {
    collect_text_sections(
      html_with_footnotes, heading_ranges, items, section_offsets,
    )
  }
  (
    {
      html: html_with_footnotes,
      shortcode_errors: rendered.shortcode_errors,
      toc: collect_toc_entries(blocks, 6),
      footnotes,
    },
    leading_h1_end,
  )
}

///|
// Split only at headings that the whole-document extractor sees as markup.
// Keeping hidden or raw-text headings inside their enclosing slice preserves
// comment, quoted-tag and text-element state across apparent Markdown sections.
fn collect_text_sections(
  html : String,
  ranges : Array[(Int, Int)],
  sections : Array[TextSection],
  section_offsets : Array[Int?],
) -> Unit {
  let offsets : Array[Int] = []
  for (start, end) in ranges {
    offsets.push(start)
    offsets.push(end)
  }
  let (whole_text, boundaries) = @strutil.strip_html_tags_with_boundaries(
    html, offsets,
  )
  let visible : Array[(Int, Int)] = []
  for i = 0; i < ranges.length(); i = i + 1 {
    if boundaries[2 * i] && boundaries[2 * i + 1] {
      visible.push(ranges[i])
    }
  }
  if visible.is_empty() {
    if whole_text != "" {
      sections.push({ heading: "", body: whole_text, })
      section_offsets.push(None)
    }
    return
  }
  let preamble = @strutil.strip_html_tags(html[:visible[0].0].to_owned())
  if preamble != "" {
    sections.push({ heading: "", body: preamble, })
    section_offsets.push(None)
  }
  for i = 0; i < visible.length(); i = i + 1 {
    let (start, heading_end) = visible[i]
    let end = if i + 1 < visible.length() {
      visible[i + 1].0
    } else {
      html.length()
    }
    let text = @strutil.strip_html_tags(html[start:end].to_owned())
    let generated = start == heading_end
    let heading = if generated {
      "Footnotes"
    } else {
      @strutil.strip_html_tags(html[start:heading_end].to_owned())
    }
    let body = if !generated && text.has_prefix(heading) {
      text[heading.length():].trim().to_owned()
    } else {
      text
    }
    if heading != "" || body != "" {
      sections.push({ heading, body, })
      section_offsets.push(if generated { None } else { Some(start) })
    }
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
