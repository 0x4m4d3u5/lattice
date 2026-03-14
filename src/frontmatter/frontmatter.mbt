///|
/// Frontmatter parsing and typed schema enforcement.
///
/// Design intent: every content file has a frontmatter block delimited by `---`.
/// The parsed result is a typed `FrontmatterValue` tree. Schema validation
/// converts that tree into a user-defined struct, and mismatches are type
/// errors caught at build time, not render time.

///|
/// A raw frontmatter value parsed from TOML-style key-value pairs.
pub(all) enum FrontmatterValue {
  FStr(String)
  FDate(String)
  FInt(Int)
  FBool(Bool)
  FArray(Array[FrontmatterValue])
  FMap(Map[String, FrontmatterValue])
}

///|
/// A parsed frontmatter block: the raw map plus the remaining document body.
pub struct Frontmatter {
  fields : Map[String, FrontmatterValue]
  body : String
}

// ── helpers ───────────────────────────────────────────────────────────────────

// MoonBit: s[i] returns UInt16 (UTF-16 code unit), not Char. Use this for all
// character access so comparisons against char literals type-check correctly.

///|
fn char_at(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

///|
fn substr(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = start
  while i < end {
    buf.write_char(char_at(s, i))
    i = i + 1
  }
  buf.to_string()
}

///|
fn trim_ws(s : String) -> String {
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
  substr(s, lo, hi)
}

///|
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

///|
fn contains_char(s : String, needle : Char) -> Bool {
  let mut i = 0
  while i < s.length() {
    if char_at(s, i) == needle {
      return true
    }
    i = i + 1
  }
  false
}

///|
fn next_newline(s : String, from : Int) -> Int {
  let n = s.length()
  let mut i = from
  while i < n && char_at(s, i) != '\n' {
    i = i + 1
  }
  i
}

///|
fn split_lines(s : String) -> Array[String] {
  let lines : Array[String] = []
  let n = s.length()
  let mut i = 0
  while i <= n {
    let end = next_newline(s, i)
    lines.push(substr(s, i, end))
    if end >= n {
      break
    }
    i = end + 1
  }
  lines
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
/// Validate ISO 8601 date format with month and day range checking.
/// Returns true if the date is in YYYY-MM-DD format with valid month (1-12)
/// and day within the valid range for that month.
fn is_valid_iso8601_date(s : String) -> Bool {
  if s.length() != 10 {
    return false
  }
  // Check format: YYYY-MM-DD
  if char_at(s, 4) != '-' || char_at(s, 7) != '-' {
    return false
  }
  // Extract and validate year (YYYY) - positions 0-3
  if not(is_digit(char_at(s, 0))) ||
    not(is_digit(char_at(s, 1))) ||
    not(is_digit(char_at(s, 2))) ||
    not(is_digit(char_at(s, 3))) {
    return false
  }
  // Extract and validate month (MM) - positions 5-6
  if not(is_digit(char_at(s, 5))) || not(is_digit(char_at(s, 6))) {
    return false
  }
  let month_1 = char_at(s, 5).to_int() - '0'.to_int()
  let month_2 = char_at(s, 6).to_int() - '0'.to_int()
  let month = month_1 * 10 + month_2
  if month < 1 || month > 12 {
    return false
  }
  // Extract and validate day (DD) - positions 8-9
  if not(is_digit(char_at(s, 8))) || not(is_digit(char_at(s, 9))) {
    return false
  }
  let day_1 = char_at(s, 8).to_int() - '0'.to_int()
  let day_2 = char_at(s, 9).to_int() - '0'.to_int()
  let day = day_1 * 10 + day_2
  if day < 1 {
    return false
  }
  // Validate day is within the valid range for the specific month
  let max_day = match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31 // Months with 31 days
    4 | 6 | 9 | 11 => 30 // Months with 30 days
    2 => 29 // February: accept 29 for leap year compatibility
    _ => 31 // Should never reach here
  }
  if day > max_day {
    return false
  }
  true
}

///|
fn parse_int_str(s : String) -> Result[Int, String] {
  let n = s.length()
  if n == 0 {
    return Err("empty integer")
  }
  let mut i = 0
  let neg = char_at(s, 0) == '-'
  if neg {
    i = 1
  }
  if i >= n {
    return Err("expected digits after '-'")
  }
  let mut value = 0
  while i < n {
    let c = char_at(s, i)
    if not(is_digit(c)) {
      return Err("invalid digit in integer")
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
    i = i + 1
  }
  if neg {
    Ok(-value)
  } else {
    Ok(value)
  }
}

///|
/// Parse a `"..."` string starting at `pos`. Returns (value, next_pos).
fn parse_quoted(s : String, pos : Int) -> Result[(String, Int), String] {
  let n = s.length()
  if pos >= n || char_at(s, pos) != '"' {
    return Err("expected '\"'")
  }
  let buf = StringBuilder::new()
  let mut i = pos + 1
  while i < n {
    let c = char_at(s, i)
    if c == '\\' && i + 1 < n {
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
        buf.write_char('\\')
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

///|
/// Parse a single value at `pos` in `s`. Returns (value, next_pos).
fn parse_value_at(
  s : String,
  pos : Int,
) -> Result[(FrontmatterValue, Int), String] {
  let n = s.length()
  let mut i = pos
  while i < n && (char_at(s, i) == ' ' || char_at(s, i) == '\t') {
    i = i + 1
  }
  if i >= n {
    return Err("expected value, got end of input")
  }
  let c = char_at(s, i)
  if c == '"' {
    match parse_quoted(s, i) {
      Ok((v, next)) =>
        if is_valid_iso8601_date(v) {
          Ok((FDate(v), next))
        } else {
          Ok((FStr(v), next))
        }
      Err(e) => Err(e)
    }
  } else if c == '[' {
    parse_array_at(s, i)
  } else if starts_with_at(s, i, "true") {
    Ok((FBool(true), i + 4))
  } else if starts_with_at(s, i, "false") {
    Ok((FBool(false), i + 5))
  } else if is_digit(c) || c == '-' {
    let mut j = i
    while j < n &&
          char_at(s, j) != ' ' &&
          char_at(s, j) != '\t' &&
          char_at(s, j) != ',' &&
          char_at(s, j) != ']' {
      j = j + 1
    }
    let raw = trim_ws(substr(s, i, j))
    if is_valid_iso8601_date(raw) {
      Ok((FDate(raw), j))
    } else {
      match parse_int_str(raw) {
        Ok(v) => Ok((FInt(v), j))
        Err(_) => Ok((FStr(raw), j))
      }
    }
  } else {
    // bare string: read until comma, closing bracket, or end
    let mut j = i
    while j < n && char_at(s, j) != ',' && char_at(s, j) != ']' {
      j = j + 1
    }
    Ok((FStr(trim_ws(substr(s, i, j))), j))
  }
}

///|
fn parse_array_at(
  s : String,
  pos : Int,
) -> Result[(FrontmatterValue, Int), String] {
  let n = s.length()
  if pos >= n || char_at(s, pos) != '[' {
    return Err("expected '['")
  }
  let items : Array[FrontmatterValue] = []
  let mut i = pos + 1
  while i < n && (char_at(s, i) == ' ' || char_at(s, i) == '\t') {
    i = i + 1
  }
  if i < n && char_at(s, i) == ']' {
    return Ok((FArray(items), i + 1))
  }
  while i < n {
    match parse_value_at(s, i) {
      Err(e) => return Err(e)
      Ok((val, next)) => {
        items.push(val)
        i = next
      }
    }
    while i < n && (char_at(s, i) == ' ' || char_at(s, i) == '\t') {
      i = i + 1
    }
    if i >= n {
      return Err("unterminated array literal")
    }
    if char_at(s, i) == ']' {
      return Ok((FArray(items), i + 1))
    } else if char_at(s, i) == ',' {
      i = i + 1
    } else {
      return Err("expected ',' or ']' inside array")
    }
  }
  Err("unterminated array literal")
}

///|
fn parse_value_strict(s : String) -> Result[FrontmatterValue, String] {
  match parse_value_at(s, 0) {
    Err(e) => Err(e)
    Ok((value, next)) => {
      let mut i = next
      while i < s.length() && (char_at(s, i) == ' ' || char_at(s, i) == '\t') {
        i = i + 1
      }
      if i != s.length() {
        Err("unexpected trailing input")
      } else {
        Ok(value)
      }
    }
  }
}

///|
/// Parse one `key = value` assignment line. Caller must ensure non-empty, non-comment.
fn parse_assignment(
  line : String,
) -> Result[(String, FrontmatterValue), String] {
  let n = line.length()
  let mut eq = -1
  let mut i = 0
  while i < n {
    if char_at(line, i) == '=' {
      eq = i
      break
    }
    i = i + 1
  }
  if eq < 0 {
    return Err("no '=' found in line")
  }
  let key = trim_ws(substr(line, 0, eq))
  if key.length() == 0 {
    return Err("empty key")
  }
  let val_str = trim_ws(substr(line, eq + 1, n))
  match parse_value_strict(val_str) {
    Ok(val) => Ok((key, val))
    Err(e) => Err("value error for '" + key + "': " + e)
  }
}

///|
fn parse_yaml_value(raw : String) -> FrontmatterValue {
  let value = trim_ws(raw)
  if value.length() >= 2 &&
    char_at(value, 0) == '\'' &&
    char_at(value, value.length() - 1) == '\'' {
    let unquoted = substr(value, 1, value.length() - 1)
    if is_valid_iso8601_date(unquoted) {
      return FDate(unquoted)
    }
    return FStr(unquoted)
  }
  match parse_value_strict(value) {
    Ok(parsed) => parsed
    Err(_) => FStr(value)
  }
}

///|
fn parse_yaml_assignment(
  lines : Array[String],
  line_index : Int,
) -> Result[(String, FrontmatterValue, Int), String] {
  let line = trim_ws(lines[line_index])
  let mut colon = -1
  let mut i = 0
  while i < line.length() {
    if char_at(line, i) == ':' {
      colon = i
      break
    }
    i = i + 1
  }
  if colon < 0 {
    return Err("no '=' or ':' found in line")
  }
  let key = trim_ws(substr(line, 0, colon))
  if key.length() == 0 {
    return Err("empty key")
  }
  let value = trim_ws(substr(line, colon + 1, line.length()))
  if value.length() > 0 {
    return Ok((key, parse_yaml_value(value), line_index + 1))
  }

  let items : Array[FrontmatterValue] = []
  let mut j = line_index + 1
  while j < lines.length() {
    let raw = trim_ws(lines[j])
    if raw.length() == 0 || char_at(raw, 0) == '#' {
      j = j + 1
      continue
    }
    if char_at(raw, 0) == '-' &&
      (raw.length() == 1 || char_at(raw, 1) == ' ' || char_at(raw, 1) == '\t') {
      let item_raw = trim_ws(substr(raw, 1, raw.length()))
      items.push(parse_yaml_value(item_raw))
      j = j + 1
      continue
    }
    break
  }

  if items.length() > 0 {
    Ok((key, FArray(items), j))
  } else {
    Ok((key, FStr(""), line_index + 1))
  }
}

// ── public API ────────────────────────────────────────────────────────────────

///|
/// Parse the leading `---`-delimited block from a file's content.
/// Returns an error string if the delimiter is missing or malformed.
///
/// Format:
/// ```
/// ---
/// key = "value"
/// count = 42
/// tags = ["a", "b"]
/// ---
/// body text here
/// ```
pub fn parse(content : String) -> Result[Frontmatter, String] {
  let n = content.length()
  if not(starts_with_at(content, 0, "---")) {
    return Err("missing opening '---' delimiter")
  }
  let first_nl = next_newline(content, 3)
  if first_nl >= n {
    return Err("no content after opening '---'")
  }
  let fm_start = first_nl + 1
  let mut i = fm_start
  while i < n {
    let line_end = next_newline(content, i)
    let line = trim_ws(substr(content, i, line_end))
    if line == "---" {
      let body_start = if line_end + 1 <= n { line_end + 1 } else { n }
      let fields : Map[String, FrontmatterValue] = Map::new()
      let fm_text = substr(content, fm_start, i)
      let lines = split_lines(fm_text)
      let mut j = 0
      while j < lines.length() {
        let l = trim_ws(lines[j])
        if l.length() > 0 && char_at(l, 0) != '#' {
          if contains_char(l, '=') {
            match parse_assignment(l) {
              Ok((key, val)) => fields.set(key, val)
              Err(msg) => return Err("line " + (j + 1).to_string() + ": " + msg)
            }
            j = j + 1
          } else {
            match parse_yaml_assignment(lines, j) {
              Ok((key, val, next_j)) => {
                fields.set(key, val)
                j = next_j
              }
              Err(msg) => return Err("line " + (j + 1).to_string() + ": " + msg)
            }
          }
        } else {
          j = j + 1
        }
      }
      return Ok({ fields, body: substr(content, body_start, n) })
    }
    if line_end >= n {
      break
    }
    i = line_end + 1
  }
  Err("missing closing '---' delimiter")
}
