///|
pub(all) struct ManifestEntry {
  src : String
  mtime : Int64
  out : String
  targets : Array[String]
}

///|
pub(all) struct ManifestFile {
  version : Int
  entries : Array[ManifestEntry]
}

///|
pub(all) suberror ManifestError {
  ParseError(String)
}

///|
fn char_at_manifest(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

///|
fn write_json_hex_digit_manifest(n : Int) -> Char {
  if n < 10 {
    ('0'.to_int() + n).unsafe_to_char()
  } else {
    ('a'.to_int() + (n - 10)).unsafe_to_char()
  }
}

///|
fn write_json_string_manifest(buf : StringBuilder, s : String) -> Unit {
  buf.write_char('"')
  let mut i = 0
  while i < s.length() {
    let c = char_at_manifest(s, i)
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
        buf.write_char(write_json_hex_digit_manifest((code >> 4) & 0xF))
        buf.write_char(write_json_hex_digit_manifest(code & 0xF))
      } else {
        buf.write_char(c)
      }
    }
    i = i + 1
  }
  buf.write_char('"')
}

///|
fn skip_ws_manifest(source : String, idx : Int) -> Int {
  let mut i = idx
  while i < source.length() &&
        (
          char_at_manifest(source, i) == ' ' ||
          char_at_manifest(source, i) == '\n' ||
          char_at_manifest(source, i) == '\r' ||
          char_at_manifest(source, i) == '\t'
        ) {
    i = i + 1
  }
  i
}

///|
fn expect_char_manifest(
  source : String,
  idx : Int,
  expected : Char,
) -> Int raise ManifestError {
  let i = skip_ws_manifest(source, idx)
  if i >= source.length() || char_at_manifest(source, i) != expected {
    raise ParseError("expected '" + expected.to_string() + "'")
  }
  i + 1
}

///|
fn parse_json_string_manifest(
  source : String,
  idx : Int,
) -> (String, Int) raise ManifestError {
  let mut i = skip_ws_manifest(source, idx)
  if i >= source.length() || char_at_manifest(source, i) != '"' {
    raise ParseError("expected string")
  }
  i = i + 1
  let buf = StringBuilder::new()
  while i < source.length() {
    let c = char_at_manifest(source, i)
    if c == '"' {
      return (buf.to_string(), i + 1)
    }
    if c != '\\' {
      buf.write_char(c)
      i = i + 1
      continue
    }
    i = i + 1
    if i >= source.length() {
      raise ParseError("unterminated escape")
    }
    let escaped = char_at_manifest(source, i)
    if escaped == '"' {
      buf.write_char('"')
    } else if escaped == '\\' {
      buf.write_char('\\')
    } else if escaped == '/' {
      buf.write_char('/')
    } else if escaped == 'b' {
      buf.write_char('\b')
    } else if escaped == 'f' {
      buf.write_char('\u000c')
    } else if escaped == 'n' {
      buf.write_char('\n')
    } else if escaped == 'r' {
      buf.write_char('\r')
    } else if escaped == 't' {
      buf.write_char('\t')
    } else if escaped == 'u' {
      raise ParseError("unicode escapes are not supported")
    } else {
      raise ParseError("invalid escape")
    }
    i = i + 1
  }
  raise ParseError("unterminated string")
}

///|
fn parse_int64_manifest(
  source : String,
  idx : Int,
) -> (Int64, Int) raise ManifestError {
  let mut i = skip_ws_manifest(source, idx)
  if i >= source.length() {
    raise ParseError("expected integer")
  }
  let mut negative = false
  if char_at_manifest(source, i) == '-' {
    negative = true
    i = i + 1
  }
  if i >= source.length() ||
    char_at_manifest(source, i) < '0' ||
    char_at_manifest(source, i) > '9' {
    raise ParseError("expected integer")
  }
  let mut value = 0L
  while i < source.length() &&
        char_at_manifest(source, i) >= '0' &&
        char_at_manifest(source, i) <= '9' {
    value = value * 10L +
      (char_at_manifest(source, i).to_int() - '0'.to_int()).to_int64()
    i = i + 1
  }
  if negative {
    (-value, i)
  } else {
    (value, i)
  }
}

///|
fn parse_int_manifest(
  source : String,
  idx : Int,
) -> (Int, Int) raise ManifestError {
  let (value, next) = parse_int64_manifest(source, idx)
  (value.to_int(), next)
}

///|
fn parse_targets_manifest(
  source : String,
  idx : Int,
) -> (Array[String], Int) raise ManifestError {
  let mut i = expect_char_manifest(source, idx, '[')
  let targets : Array[String] = []
  i = skip_ws_manifest(source, i)
  if i < source.length() && char_at_manifest(source, i) == ']' {
    return (targets, i + 1)
  }
  while true {
    let (target, next_after_target) = parse_json_string_manifest(source, i)
    targets.push(target)
    i = skip_ws_manifest(source, next_after_target)
    if i >= source.length() {
      raise ParseError("unterminated targets array")
    }
    let c = char_at_manifest(source, i)
    if c == ']' {
      return (targets, i + 1)
    }
    if c != ',' {
      raise ParseError("expected ',' or ']' in targets array")
    }
    i = i + 1
  }
  raise ParseError("unterminated targets array")
}

///|
fn parse_entry_manifest(
  source : String,
  idx : Int,
) -> (ManifestEntry, Int) raise ManifestError {
  let mut i = expect_char_manifest(source, idx, '{')
  let mut src = ""
  let mut out = ""
  let mut mtime = 0L
  let mut targets : Array[String] = []
  let mut seen_src = false
  let mut seen_mtime = false
  let mut seen_out = false
  let mut seen_targets = false
  while true {
    i = skip_ws_manifest(source, i)
    if i >= source.length() {
      raise ParseError("unterminated entry object")
    }
    if char_at_manifest(source, i) == '}' {
      if not(seen_src) || not(seen_mtime) || not(seen_out) {
        raise ParseError("entry missing required field")
      }
      return ({ src, mtime, out, targets }, i + 1)
    }
    let (key, next_after_key) = parse_json_string_manifest(source, i)
    i = expect_char_manifest(source, next_after_key, ':')
    if key == "src" {
      let (value, next) = parse_json_string_manifest(source, i)
      src = value
      seen_src = true
      i = next
    } else if key == "mtime" {
      let (value, next) = parse_int64_manifest(source, i)
      mtime = value
      seen_mtime = true
      i = next
    } else if key == "out" {
      let (value, next) = parse_json_string_manifest(source, i)
      out = value
      seen_out = true
      i = next
    } else if key == "targets" {
      let (value, next) = parse_targets_manifest(source, i)
      targets = value
      seen_targets = true
      i = next
    } else {
      raise ParseError("unknown entry field '" + key + "'")
    }
    i = skip_ws_manifest(source, i)
    if i >= source.length() {
      raise ParseError("unterminated entry object")
    }
    if char_at_manifest(source, i) == '}' {
      if not(seen_src) || not(seen_mtime) || not(seen_out) {
        raise ParseError("entry missing required field")
      }
      if not(seen_targets) {
        targets = []
      }
      return ({ src, mtime, out, targets }, i + 1)
    }
    if char_at_manifest(source, i) != ',' {
      raise ParseError("expected ',' or '}' in entry object")
    }
    i = i + 1
  }
  raise ParseError("unterminated entry object")
}

///|
pub fn parse(source : String) -> ManifestFile raise ManifestError {
  let mut i = expect_char_manifest(source, 0, '{')
  let (version_key, next_after_version_key) = parse_json_string_manifest(
    source, i,
  )
  if version_key != "version" {
    raise ParseError("expected 'version' field")
  }
  i = expect_char_manifest(source, next_after_version_key, ':')
  let (version, next_after_version) = parse_int_manifest(source, i)
  i = skip_ws_manifest(source, next_after_version)
  if i >= source.length() || char_at_manifest(source, i) != ',' {
    raise ParseError("expected ',' after version")
  }
  i = i + 1
  let (entries_key, next_after_entries_key) = parse_json_string_manifest(
    source, i,
  )
  if entries_key != "entries" {
    raise ParseError("expected 'entries' field")
  }
  i = expect_char_manifest(source, next_after_entries_key, ':')
  i = expect_char_manifest(source, i, '[')
  let entries : Array[ManifestEntry] = []
  i = skip_ws_manifest(source, i)
  if i < source.length() && char_at_manifest(source, i) == ']' {
    i = i + 1
  } else {
    while true {
      let (entry, next_after_entry) = parse_entry_manifest(source, i)
      entries.push(entry)
      i = skip_ws_manifest(source, next_after_entry)
      if i >= source.length() {
        raise ParseError("unterminated entries array")
      }
      let c = char_at_manifest(source, i)
      if c == ']' {
        i = i + 1
        break
      }
      if c != ',' {
        raise ParseError("expected ',' or ']' in entries array")
      }
      i = i + 1
    }
  }
  i = expect_char_manifest(source, i, '}')
  i = skip_ws_manifest(source, i)
  if i != source.length() {
    raise ParseError("unexpected trailing content")
  }
  { version, entries }
}

///|
pub fn render(file : ManifestFile) -> String {
  let buf = StringBuilder::new()
  buf.write_string("{\"version\":")
  buf.write_string(file.version.to_string())
  buf.write_string(",\"entries\":[")
  let mut i = 0
  while i < file.entries.length() {
    if i > 0 {
      buf.write_char(',')
    }
    let entry = file.entries[i]
    buf.write_string("{\"src\":")
    write_json_string_manifest(buf, entry.src)
    buf.write_string(",\"mtime\":")
    buf.write_string(entry.mtime.to_string())
    buf.write_string(",\"out\":")
    write_json_string_manifest(buf, entry.out)
    if entry.targets.length() > 0 {
      buf.write_string(",\"targets\":[")
      let mut j = 0
      while j < entry.targets.length() {
        if j > 0 {
          buf.write_char(',')
        }
        write_json_string_manifest(buf, entry.targets[j])
        j = j + 1
      }
      buf.write_char(']')
    }
    buf.write_char('}')
    i = i + 1
  }
  buf.write_string("]}")
  buf.to_string()
}
