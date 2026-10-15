///|
/// Shared string and character utility functions.
///
/// Centralizes commonly-needed string primitives that were previously
/// duplicated across 15+ packages.

// ── character access ──────────────────────────────────────────────────────────

///|
/// Get character at position `i` in string `s`.
///
/// MoonBit's `s[i]` returns a `UInt16` (UTF-16 code unit), not `Char`.
/// This helper bridges the gap so comparisons against char literals work.
pub fn char_at(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

// ── whitespace trimming ──────────────────────────────────────────────────────

///|
/// Trim leading and trailing whitespace (space, tab, CR, LF).
pub fn trim(s : String) -> String {
  s.trim(chars=" \t\r\n").to_owned()
}

///|
/// Trim leading whitespace (space, tab, CR, LF).
pub fn trim_start(s : String) -> String {
  s.trim_start(chars=" \t\r\n").to_owned()
}

///|
/// Trim trailing whitespace (space, tab, CR, LF).
pub fn trim_end(s : String) -> String {
  s.trim_end(chars=" \t\r\n").to_owned()
}

///|
/// Trim horizontal whitespace only (space, tab, CR — no LF).
pub fn trim_h(s : String) -> String {
  s.trim(chars=" \t\r").to_owned()
}

// ── substring ─────────────────────────────────────────────────────────────────

///|
/// Extract substring `s[start..end)`.
pub fn substr(s : String, start : Int, end_pos : Int) -> String {
  let buf = StringBuilder()
  let mut i = start
  while i < end_pos {
    buf.write_char(char_at(s, i))
    i = i + 1
  }
  buf.to_string()
}

// ── line splitting ────────────────────────────────────────────────────────────

///|
/// Split a string into lines (on `\n`). Does not include the `\n` delimiter.
pub fn split_lines(s : String) -> Array[String] {
  s.split("\n").map(v => v.to_owned()).collect()
}

///|
/// Join an array of strings with newline separator.
pub fn join_lines(lines : Array[String]) -> String {
  lines.join("\n")
}

// ── character classification ──────────────────────────────────────────────────

///|
/// Check if character is an ASCII digit (0-9).
pub fn is_digit(c : Char) -> Bool {
  c.is_ascii_digit()
}

///|
/// Check if character is an ASCII alphabetic letter.
pub fn is_alpha(c : Char) -> Bool {
  c.is_ascii_alphabetic()
}

///|
/// Check if character can start an identifier (alpha or underscore).
pub fn is_ident_start(c : Char) -> Bool {
  is_alpha(c) || c == '_'
}

///|
/// Check if character can continue an identifier (alpha, digit, or underscore).
pub fn is_ident_part(c : Char) -> Bool {
  is_ident_start(c) || is_digit(c)
}

///|
/// Check if character is ASCII whitespace.
pub fn is_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
/// Check if character is a hex digit (0-9, a-f, A-F).
pub fn is_hex_digit(c : Char) -> Bool {
  c.is_ascii_hexdigit()
}

///|
/// Check if character is an octal digit (0-7).
pub fn is_octal_digit(c : Char) -> Bool {
  c.is_ascii_octdigit()
}

///|
/// Check if character is an operator symbol.
pub fn is_operator_char(c : Char) -> Bool {
  c == '+' ||
  c == '-' ||
  c == '*' ||
  c == '/' ||
  c == '%' ||
  c == '=' ||
  c == '!' ||
  c == '<' ||
  c == '>' ||
  c == '&' ||
  c == '|' ||
  c == '^' ||
  c == '~' ||
  c == '?'
}

///|
/// Check if character is a punctuation symbol.
pub fn is_punct_char(c : Char) -> Bool {
  c == '(' ||
  c == ')' ||
  c == '{' ||
  c == '}' ||
  c == '[' ||
  c == ']' ||
  c == ';' ||
  c == ',' ||
  c == '.' ||
  c == ':'
}

// ── prefix/suffix matching ───────────────────────────────────────────────────

///|
/// Check if string `s` has prefix `prefix` starting at position `pos`.
pub fn starts_with_at(s : String, pos : Int, prefix : String) -> Bool {
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

///|
/// Check if string `s` starts with `prefix`.
pub fn starts_with(s : String, prefix : String) -> Bool {
  s.has_prefix(prefix)
}

///|
/// Check if string `s` ends with `suffix`.
pub fn ends_with(s : String, suffix : String) -> Bool {
  s.has_suffix(suffix)
}

// ── HTML escaping ────────────────────────────────────────────────────────────

///|
/// Escape text for HTML body context (&, <, >).
pub fn escape_html_body(s : String) -> String {
  let buf = StringBuilder()
  for c in s {
    match c {
      '&' => buf.write_string("&amp;")
      '<' => buf.write_string("&lt;")
      '>' => buf.write_string("&gt;")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
/// Escape text for HTML attribute context (&, <, >, ").
pub fn escape_html_attr(s : String) -> String {
  let buf = StringBuilder()
  for c in s {
    match c {
      '&' => buf.write_string("&amp;")
      '<' => buf.write_string("&lt;")
      '>' => buf.write_string("&gt;")
      '"' => buf.write_string("&quot;")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}

// ── URL utilities ────────────────────────────────────────────────────────────

///|
/// Normalize a base URL by trimming horizontal whitespace and stripping trailing slashes.
///
/// "/" becomes "" (root-relative site).
pub fn normalize_base_url(base_url : String) -> String {
  trim_h(base_url).trim_end(chars="/").to_owned()
}

///|
/// Join a base URL and a path.
///
/// Handles leading slashes on the path component.
pub fn absolute_url(base_url : String, path : String) -> String {
  let base = normalize_base_url(base_url)
  if base.length() == 0 {
    return path
  }
  if path.length() == 0 {
    return base
  }
  if path.length() > 0 && char_at(path, 0) == '/' {
    base + path
  } else {
    base + "/" + path
  }
}

// ── path utilities ───────────────────────────────────────────────────────────

///|
/// Join two path components with a "/" separator.
///
/// Handles empty components gracefully.
pub fn join_path(base : String, part : String) -> String {
  if base.length() == 0 {
    return part
  }
  if part.length() == 0 {
    return base
  }
  base + "/" + part
}

// ── JSON helpers ─────────────────────────────────────────────────────────────

///|
/// Convert an integer 0-15 to its lowercase hex character.
pub fn hex_nibble(n : Int) -> Char {
  if n < 10 {
    ('0'.to_int() + n).unsafe_to_char()
  } else {
    ('a'.to_int() + (n - 10)).unsafe_to_char()
  }
}

///|
/// Write a JSON-escaped string into a StringBuilder (without surrounding quotes).
pub fn write_json_escaped(buf : StringBuilder, s : String) -> Unit {
  let n = s.length()
  let mut i = 0
  while i < n {
    let c = char_at(s, i)
    if c == '"' {
      buf.write_string("\\\"")
    } else if c == '\\' {
      buf.write_string("\\\\")
    } else if c == '\n' {
      buf.write_string("\\n")
    } else if c == '\r' {
      buf.write_string("\\r")
    } else if c == '\t' {
      buf.write_string("\\t")
    } else {
      let code = c.to_int()
      if code < 0x20 {
        buf.write_string("\\u00")
        buf.write_char(hex_nibble(code / 16))
        buf.write_char(hex_nibble(code % 16))
      } else {
        buf.write_char(c)
      }
    }
    i = i + 1
  }
}

///|
/// Write a JSON-escaped string with surrounding quotes into a StringBuilder.
pub fn write_json_string(buf : StringBuilder, s : String) -> Unit {
  buf.write_char('"')
  write_json_escaped(buf, s)
  buf.write_char('"')
}

// ── case conversion ──────────────────────────────────────────────────────────

///|
/// Convert ASCII uppercase letters to lowercase. Non-ASCII characters are unchanged.
pub fn to_ascii_lower(s : String) -> String {
  s.to_lower()
}

///|
/// Convert a single ASCII character to lowercase if it's uppercase.
pub fn ascii_lower_char(c : Char) -> Char {
  c.to_ascii_lowercase()
}

// ── integer parsing ──────────────────────────────────────────────────────────

///|
/// Parse a string as an integer. Returns None on failure.
pub fn parse_int(s : String) -> Int? {
  let n = s.length()
  if n == 0 {
    return None
  }
  let mut i = 0
  let neg = char_at(s, 0) == '-'
  if neg {
    i = 1
  }
  if i >= n {
    return None
  }
  while i < n {
    let c = char_at(s, i)
    if !is_digit(c) {
      return None
    }
    i = i + 1
  }
  // Keep our decimal-only grammar; core handles both signed bounds safely.
  Some(@string.parse_int(s[:], base=10)) catch {
    _ => None
  }
}

///|
/// Parse a string as a double. Returns None on failure.
/// Accepts optional leading minus, digits, optional decimal point, more digits.
pub fn parse_float(s : String) -> Double? {
  let n = s.length()
  if n == 0 {
    return None
  }
  let mut i = 0
  let neg = char_at(s, 0) == '-'
  if neg {
    i = 1
  }
  if i >= n {
    return None
  }
  let mut value = 0.0
  let mut has_digits = false
  // Integer part
  while i < n {
    let c = char_at(s, i)
    if c == '.' {
      i = i + 1
      break
    }
    if !is_digit(c) {
      return None
    }
    value = value * 10.0 + (c.to_int() - '0'.to_int()).to_double()
    has_digits = true
    i = i + 1
  }
  // Fractional part
  let mut divisor = 10.0
  while i < n {
    let c = char_at(s, i)
    if !is_digit(c) {
      return None
    }
    value = value + (c.to_int() - '0'.to_int()).to_double() / divisor
    divisor = divisor * 10.0
    has_digits = true
    i = i + 1
  }
  if !has_digits {
    return None
  }
  if neg {
    Some(0.0 - value)
  } else {
    Some(value)
  }
}

///|
/// Parse a positive integer string. Returns None if not a positive integer.
pub fn parse_positive_int(value : String) -> Int? {
  let n = value.length()
  if n == 0 {
    return None
  }
  let mut parsed = 0
  let mut i = 0
  while i < n {
    let c = char_at(value, i)
    if !is_digit(c) {
      return None
    }
    let digit = c.to_int() - '0'.to_int()
    // Reject overflow before multiplying; wrapped positives are invalid too.
    if parsed > (2147483647 - digit) / 10 {
      return None
    }
    parsed = parsed * 10 + digit
    i = i + 1
  }
  if parsed <= 0 {
    return None
  }
  Some(parsed)
}

///|
/// Parse a quoted string literal starting at position `pos`.
/// Returns `(value, next_pos)` on success.
pub fn parse_quoted(s : String, pos : Int) -> Result[(String, Int), String] {
  if pos >= s.length() || char_at(s, pos) != '"' {
    return Err("expected '\"'")
  }
  let buf = StringBuilder()
  let mut i = pos + 1
  while i < s.length() {
    let c = char_at(s, i)
    if c == '\\' {
      if i + 1 >= s.length() {
        return Err("unterminated escape")
      }
      let esc = char_at(s, i + 1)
      if esc == 'n' {
        buf.write_char('\n')
      } else if esc == 't' {
        buf.write_char('\t')
      } else if esc == '"' {
        buf.write_char('"')
      } else if esc == '\\' {
        buf.write_char('\\')
      } else {
        buf.write_char(esc)
      }
      i = i + 2
    } else if c == '"' {
      return Ok((buf.to_string(), i + 1))
    } else {
      buf.write_char(c)
      i = i + 1
    }
  }
  Err("unterminated string literal")
}

// ── date validation ──────────────────────────────────────────────────────────

///|
/// Check if a year is a leap year.
pub fn is_leap_year(year : Int) -> Bool {
  if year % 400 == 0 {
    true
  } else if year % 100 == 0 {
    false
  } else {
    year % 4 == 0
  }
}

///|
/// Get the number of days in a given month (1-indexed).
pub fn days_in_month(year : Int, month : Int) -> Int {
  if month == 1 ||
    month == 3 ||
    month == 5 ||
    month == 7 ||
    month == 8 ||
    month == 10 ||
    month == 12 {
    31
  } else if month == 4 || month == 6 || month == 9 || month == 11 {
    30
  } else if month == 2 {
    if is_leap_year(year) {
      29
    } else {
      28
    }
  } else {
    0
  }
}

///|
/// Validate ISO 8601 date format (YYYY-MM-DD) with month/day range checking.
/// Returns true if valid.
pub fn is_valid_iso8601_date(s : String) -> Bool {
  if s.length() != 10 {
    return false
  }
  if char_at(s, 4) != '-' || char_at(s, 7) != '-' {
    return false
  }
  if !is_digit(char_at(s, 0)) ||
    !is_digit(char_at(s, 1)) ||
    !is_digit(char_at(s, 2)) ||
    !is_digit(char_at(s, 3)) {
    return false
  }
  if !is_digit(char_at(s, 5)) || !is_digit(char_at(s, 6)) {
    return false
  }
  let month = (char_at(s, 5).to_int() - '0'.to_int()) * 10 +
    (char_at(s, 6).to_int() - '0'.to_int())
  if month < 1 || month > 12 {
    return false
  }
  if !is_digit(char_at(s, 8)) || !is_digit(char_at(s, 9)) {
    return false
  }
  let day = (char_at(s, 8).to_int() - '0'.to_int()) * 10 +
    (char_at(s, 9).to_int() - '0'.to_int())
  if day < 1 {
    return false
  }
  let year = (char_at(s, 0).to_int() - '0'.to_int()) * 1000 +
    (char_at(s, 1).to_int() - '0'.to_int()) * 100 +
    (char_at(s, 2).to_int() - '0'.to_int()) * 10 +
    (char_at(s, 3).to_int() - '0'.to_int())
  let max_day = days_in_month(year, month)
  if day > max_day {
    return false
  }
  true
}

// ── RFC 3339 datetime validation ────────────────────────────────────────────

///|
/// Parse a fixed-width unsigned integer from `s[start..start+count)`.
///
/// Returns `None` if the range is out of bounds or contains non-digit characters.
pub fn parse_fixed_uint(s : String, start : Int, count : Int) -> Int? {
  if start + count > s.length() {
    return None
  }
  let mut i = 0
  let mut value = 0
  while i < count {
    let c = char_at(s, start + i)
    if !is_digit(c) {
      return None
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
    i = i + 1
  }
  Some(value)
}

///|
/// Structural RFC 3339 datetime validation.
///
/// Checks that `s` matches the pattern `YYYY-MM-DDTHH:MM:SS` followed by
/// either `Z` (UTC) or `±HH:MM` (offset). Every numeric component is
/// verified to contain digits only, and the date portion is validated
/// (month 1–12, day within days-in-month, hour 0–23, minute/second 0–59,
/// timezone hour 0–23, timezone minute 0–59).
///
/// This is the canonical structural validator used by both RSS and sitemap
/// renderers — no behavioral heuristics, no suffix-based guessing.
pub fn is_rfc3339_datetime(s : String) -> Bool {
  let n = s.length()
  // Minimum: "2026-01-01T00:00:00Z" = 20 chars
  if n < 20 {
    return false
  }
  // Check date separator positions
  if char_at(s, 4) != '-' || char_at(s, 7) != '-' || char_at(s, 10) != 'T' {
    return false
  }
  // Validate date components
  let year = parse_fixed_uint(s, 0, 4)
  let month = parse_fixed_uint(s, 5, 2)
  let day = parse_fixed_uint(s, 8, 2)
  match (year, month, day) {
    (Some(y), Some(m), Some(d)) => {
      if m < 1 || m > 12 {
        return false
      }
      let max_day = days_in_month(y, m)
      if d < 1 || d > max_day {
        return false
      }
    }
    _ => return false
  }
  // Validate time components: HH:MM:SS
  if char_at(s, 13) != ':' || char_at(s, 16) != ':' {
    return false
  }
  let hour = parse_fixed_uint(s, 11, 2)
  let minute = parse_fixed_uint(s, 14, 2)
  let second = parse_fixed_uint(s, 17, 2)
  match (hour, minute, second) {
    (Some(h), Some(min_), Some(sec)) =>
      if h > 23 || min_ > 59 || sec > 59 {
        return false
      }
    _ => return false
  }
  // Check timezone: either Z or ±HH:MM
  if n == 20 {
    char_at(s, 19) == 'Z'
  } else if n == 25 {
    let sign = char_at(s, 19)
    if sign != '+' && sign != '-' {
      return false
    }
    if char_at(s, 22) != ':' {
      return false
    }
    let tz_h = parse_fixed_uint(s, 20, 2)
    let tz_m = parse_fixed_uint(s, 23, 2)
    match (tz_h, tz_m) {
      (Some(th), Some(tm)) => th <= 23 && tm <= 59
      _ => false
    }
  } else {
    false
  }
}

// ── skip whitespace ─────────────────────────────────────────────────────────

///|
/// Skip whitespace characters starting at `pos`. Returns the new position.
pub fn skip_ws(s : String, pos : Int) -> Int {
  let mut i = pos
  while i < s.length() &&
        (
          char_at(s, i) == ' ' ||
          char_at(s, i) == '\t' ||
          char_at(s, i) == '\n' ||
          char_at(s, i) == '\r'
        ) {
    i = i + 1
  }
  i
}

///|
/// Skip horizontal whitespace (space, tab) starting at `pos`.
pub fn skip_ws_h(s : String, pos : Int) -> Int {
  let mut i = pos
  while i < s.length() && (char_at(s, i) == ' ' || char_at(s, i) == '\t') {
    i = i + 1
  }
  i
}

///|
/// Find the first occurrence of `c` in `s[from..limit]`. Returns -1 if absent.
pub fn find_char(s : String, from : Int, c : Char, limit : Int) -> Int {
  let mut i = from
  while i < limit {
    if char_at(s, i) == c {
      return i
    }
    i = i + 1
  }
  -1
}

///|
/// Find the first occurrence of `needle` in `s[from..limit]`. Returns -1 if absent.
pub fn find_str(s : String, from : Int, needle : String, limit : Int) -> Int {
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

///|
/// Decode a semicolon-terminated numeric reference at `pos`, if valid.
fn numeric_reference(s : String, pos : Int) -> (Char, Int)? {
  let n = s.length()
  let mut start = pos + 2 // caller has matched "&#"
  let mut base = 10
  if start < n && (char_at(s, start) == 'x' || char_at(s, start) == 'X') {
    base = 16
    start = start + 1
  }
  let mut end = start
  while end < n && (if base == 16 { is_hex_digit(char_at(s, end)) } else { is_digit(char_at(s, end)) }) {
    end = end + 1
  }
  if end == start || end >= n || char_at(s, end) != ';' { return None }
  let value = @string.parse_int(s[start:end], base~) catch { _ => return None }
  if value == 0 { return None }
  value.to_char().map(c => (c, end + 1 - pos))
}

///|
/// Strip HTML tags from a string, decode basic named and valid numeric entities,
/// and collapse whitespace into single spaces. Returns clean
/// plaintext for content indexing. Supported inline tags preserve adjacency;
/// other tags separate text. This is not a complete HTML parser or sanitizer.
pub fn strip_html_tags(s : String) -> String {
  let (text, _) = strip_html_tags_with_boundaries(s, [])
  text
}

///|
/// Extract the same whole-document text and report safe markup boundaries.
/// Offsets must be sorted UTF-16 positions in the input. A boundary is false
/// inside a comment, tag/quoted attribute or raw/RCDATA text element. This
/// exposes the existing extractor's state; it is not an HTML visibility policy.
pub fn strip_html_tags_with_boundaries(
  s : String,
  offsets : Array[Int],
) -> (String, Array[Bool]) {
  let boundaries : Array[Bool] = []
  let mut next_boundary = 0
  // Pass 1: preserve text adjacency across supported inline tags; separate
  // blocks and unknown tags. This is a text extractor, not an HTML parser.
  let buf = StringBuilder()
  let n = s.length()
  let mut i = 0
  let mut in_tag = false
  let mut inline_tag = false
  let mut quote : Char? = None
  let mut text_element : String? = None
  while i < n {
    while next_boundary < offsets.length() && offsets[next_boundary] <= i {
      boundaries.push(
        offsets[next_boundary] == i && !in_tag && text_element is None,
      )
      next_boundary = next_boundary + 1
    }
    let c = char_at(s, i)
    if in_tag {
      if quote is Some(q) {
        if c == q { quote = None }
      } else if c == '"' || c == '\'' {
        quote = Some(c)
      } else if c == '>' {
        in_tag = false
        if !inline_tag { buf.write_char(' ') }
      }
    } else if text_element is Some(name) {
      let end = i + 2 + name.length()
      if c == '<' && end < n && starts_with_at(s, i, "</") &&
        substr(s, i + 2, end).to_lower() == name &&
        (is_whitespace(char_at(s, end)) || char_at(s, end).to_int() == 12 ||
          char_at(s, end) == '/' || char_at(s, end) == '>') {
        text_element = None
        continue // process the matching closing tag normally at the same offset
      }
      buf.write_char(c)
    } else if c == '<' && starts_with_at(s, i, "<!--") {
      // Comments do not separate adjacent visible text. An unclosed comment
      // hides the remaining suffix, without scanning it again as prose.
      match s[i + 4:n].find("-->") {
        Some(end) => { i = i + 4 + end + 3; continue }
        None => break
      }
    } else if c == '<' {
      in_tag = true
      let start = if i + 1 < n && char_at(s, i + 1) == '/' { i + 2 } else { i + 1 }
      let mut end = start
      while end < n && !char_at(s, end).is_whitespace() &&
        char_at(s, end) != '/' && char_at(s, end) != '>' {
        end = end + 1
      }
      let name = substr(s, start, end).to_lower()
      if start == i + 1 {
        match name {
          "textarea" | "title" | "script" | "style" | "xmp" | "iframe"
          | "noembed" | "noframes" => text_element = Some(name)
          _ => ()
        }
      }
      inline_tag = match name {
        "a" | "strong" | "em" | "del" | "code" | "span" | "sub" | "sup"
        | "mark" | "abbr" | "kbd" | "b" | "i" | "u" | "s" | "small"
        | "cite" | "q" | "dfn" | "data" | "time" | "var" | "samp"
        | "bdi" | "bdo" | "ruby" | "rt" | "rp" | "ins" | "label"
        | "output" | "wbr" => true
        _ => false
      }
    } else {
      buf.write_char(c)
    }
    i = i + 1
  }
  while next_boundary < offsets.length() {
    boundaries.push(
      offsets[next_boundary] == n && i == n && !in_tag && text_element is None,
    )
    next_boundary = next_boundary + 1
  }
  // Pass 2: decode entities once, then collapse runs of ASCII whitespace.
  let stripped = buf.to_string()
  let out = StringBuilder()
  let m = stripped.length()
  let mut j = 0
  let mut prev_ws = true // treat leading whitespace as already-spaced
  while j < m {
    let c = char_at(stripped, j)
    if c == '&' {
      // Attempt entity decode; fall back to literal '&' if unknown
      let mut decoded_char = '&'
      let mut skip = 1
      if starts_with_at(stripped, j, "&amp;") {
        decoded_char = '&'
        skip = 5
      } else if starts_with_at(stripped, j, "&lt;") {
        decoded_char = '<'
        skip = 4
      } else if starts_with_at(stripped, j, "&gt;") {
        decoded_char = '>'
        skip = 4
      } else if starts_with_at(stripped, j, "&quot;") {
        decoded_char = '"'
        skip = 6
      } else if starts_with_at(stripped, j, "&apos;") {
        decoded_char = '\''
        skip = 6
      } else if starts_with_at(stripped, j, "&#") {
        match numeric_reference(stripped, j) {
          Some((c, width)) => { decoded_char = c; skip = width }
          None => ()
        }
      }
      if decoded_char == ' ' || decoded_char == '\n' || decoded_char == '\t' || decoded_char == '\r' {
        if !prev_ws { out.write_char(' '); prev_ws = true }
      } else {
        out.write_char(decoded_char)
        prev_ws = false
      }
      j = j + skip
    } else if c == ' ' || c == '\n' || c == '\t' || c == '\r' {
      if !prev_ws {
        out.write_char(' ')
        prev_ws = true
      }
      j = j + 1
    } else {
      out.write_char(c)
      prev_ws = false
      j = j + 1
    }
  }
  (trim(out.to_string()), boundaries)
}

///|
/// Count words in a plain-text string by splitting on whitespace.
pub fn count_words_text(text : String) -> Int {
  if text.length() == 0 {
    return 0
  }
  let mut count = 0
  let mut in_word = false
  let n = text.length()
  let mut i = 0
  while i < n {
    let c = char_at(text, i)
    let is_ws = c == ' ' || c == '\t' || c == '\n' || c == '\r'
    if is_ws {
      if in_word {
        count = count + 1
        in_word = false
      }
    } else {
      in_word = true
    }
    i = i + 1
  }
  if in_word {
    count = count + 1
  }
  count
}

///|
/// Sort an array in place using insertion sort with the given comparator.
///
/// This is a simple O(n²) sort suitable for small arrays (e.g., feed entries).
/// Uses `<=` for stable sort semantics (preserves relative order of equal elements).
pub fn[T] insertion_sort(arr : Array[T], cmp : (T, T) -> Int) -> Unit {
  let mut i = 1
  while i < arr.length() {
    let mut j = i
    while j > 0 && cmp(arr[j - 1], arr[j]) > 0 {
      let tmp = arr[j - 1]
      arr[j - 1] = arr[j]
      arr[j] = tmp
      j = j - 1
    }
    i = i + 1
  }
}
