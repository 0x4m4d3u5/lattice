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
  trim_end(trim_start(s))
}

///|
/// Trim leading whitespace (space, tab, CR, LF).
pub fn trim_start(s : String) -> String {
  let n = s.length()
  let mut lo = 0
  while lo < n &&
        (
          char_at(s, lo) == ' ' ||
          char_at(s, lo) == '\t' ||
          char_at(s, lo) == '\r' ||
          char_at(s, lo) == '\n'
        ) {
    lo = lo + 1
  }
  if lo == 0 {
    return s
  }
  substr(s, lo, n)
}

///|
/// Trim trailing whitespace (space, tab, CR, LF).
pub fn trim_end(s : String) -> String {
  let n = s.length()
  let mut hi = n
  while hi > 0 &&
        (
          char_at(s, hi - 1) == ' ' ||
          char_at(s, hi - 1) == '\t' ||
          char_at(s, hi - 1) == '\r' ||
          char_at(s, hi - 1) == '\n'
        ) {
    hi = hi - 1
  }
  if hi == n {
    return s
  }
  substr(s, 0, hi)
}

///|
/// Trim horizontal whitespace only (space, tab, CR — no LF).
pub fn trim_h(s : String) -> String {
  let n = s.length()
  if n == 0 {
    return s
  }
  let mut lo = 0
  while lo < n &&
        (
          char_at(s, lo) == ' ' ||
          char_at(s, lo) == '\t' ||
          char_at(s, lo) == '\r'
        ) {
    lo = lo + 1
  }
  let mut hi = n
  while hi > lo &&
        (
          char_at(s, hi - 1) == ' ' ||
          char_at(s, hi - 1) == '\t' ||
          char_at(s, hi - 1) == '\r'
        ) {
    hi = hi - 1
  }
  if lo == 0 && hi == n {
    return s
  }
  substr(s, lo, hi)
}

// ── substring ─────────────────────────────────────────────────────────────────

///|
/// Extract substring `s[start..end)`.
pub fn substr(s : String, start : Int, end_pos : Int) -> String {
  let buf = StringBuilder::new()
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
  let lines : Array[String] = []
  let n = s.length()
  let mut i = 0
  while i <= n {
    let mut end = i
    while end < n && char_at(s, end) != '\n' {
      end = end + 1
    }
    lines.push(substr(s, i, end))
    if end >= n {
      break
    }
    i = end + 1
  }
  lines
}

///|
/// Join an array of strings with newline separator.
pub fn join_lines(lines : Array[String]) -> String {
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

// ── character classification ──────────────────────────────────────────────────

///|
/// Check if character is an ASCII digit (0-9).
pub fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
/// Check if character is an ASCII alphabetic letter.
pub fn is_alpha(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
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
  is_digit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

///|
/// Check if character is an octal digit (0-7).
pub fn is_octal_digit(c : Char) -> Bool {
  c >= '0' && c <= '7'
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
  starts_with_at(s, 0, prefix)
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
  let buf = StringBuilder::new()
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
  let buf = StringBuilder::new()
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
  let trimmed = trim_h(base_url)
  if trimmed == "/" {
    return ""
  }
  if trimmed.has_suffix("/") {
    return substr(trimmed, 0, trimmed.length() - 1)
  }
  trimmed
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
  let buf = StringBuilder::new()
  for c in s {
    if c >= 'A' && c <= 'Z' {
      buf.write_char((c.to_int() + 32).unsafe_to_char())
    } else {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
/// Convert a single ASCII character to lowercase if it's uppercase.
pub fn ascii_lower_char(c : Char) -> Char {
  if c >= 'A' && c <= 'Z' {
    (c.to_int() + 32).unsafe_to_char()
  } else {
    c
  }
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
  let mut value = 0
  while i < n {
    let c = char_at(s, i)
    if !is_digit(c) {
      return None
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
    i = i + 1
  }
  if neg {
    Some(-value)
  } else {
    Some(value)
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
    parsed = parsed * 10 + (c.to_int() - '0'.to_int())
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
  let buf = StringBuilder::new()
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
