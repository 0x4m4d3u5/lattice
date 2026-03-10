pub(all) struct CacheEntry {
  slug : String
  fingerprint : String
}

pub(all) struct CacheFile {
  version : Int
  entries : Array[CacheEntry]
}

pub(all) struct CacheStore {
  output_dir : String
  entries : Array[CacheEntry]
  index_by_slug : Map[String, Int]
}

pub(all) suberror CacheParseError {
  ParseFailure(String)
}

pub(all) suberror CacheError {
  ReadError(String)
  ParseError(String)
  WriteError(String)
}

const CACHE_VERSION : Int = 1

fn char_at_cache(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

fn write_json_hex_digit_cache(n : Int) -> Char {
  if n < 10 {
    ('0'.to_int() + n).unsafe_to_char()
  } else {
    ('a'.to_int() + (n - 10)).unsafe_to_char()
  }
}

fn write_json_string_cache(buf : StringBuilder, s : String) -> Unit {
  buf.write_char('"')
  let mut i = 0
  while i < s.length() {
    let c = char_at_cache(s, i)
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
        buf.write_char(write_json_hex_digit_cache((code >> 4) & 0xF))
        buf.write_char(write_json_hex_digit_cache(code & 0xF))
      } else {
        buf.write_char(c)
      }
    }
    i = i + 1
  }
  buf.write_char('"')
}

fn skip_ws_cache(source : String, idx : Int) -> Int {
  let mut i = idx
  while i < source.length() &&
    (char_at_cache(source, i) == ' ' ||
      char_at_cache(source, i) == '\n' ||
      char_at_cache(source, i) == '\r' ||
      char_at_cache(source, i) == '\t') {
    i = i + 1
  }
  i
}

fn expect_char_cache(source : String, idx : Int, expected : Char) -> Int raise CacheParseError {
  let i = skip_ws_cache(source, idx)
  if i >= source.length() || char_at_cache(source, i) != expected {
    raise ParseFailure("expected '" + expected.to_string() + "'")
  }
  i + 1
}

fn parse_json_string_cache(source : String, idx : Int) -> (String, Int) raise CacheParseError {
  let mut i = skip_ws_cache(source, idx)
  if i >= source.length() || char_at_cache(source, i) != '"' {
    raise ParseFailure("expected string")
  }
  i = i + 1
  let buf = StringBuilder::new()
  while i < source.length() {
    let c = char_at_cache(source, i)
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
      raise ParseFailure("unterminated escape")
    }
    let escaped = char_at_cache(source, i)
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
      raise ParseFailure("unicode escapes are not supported")
    } else {
      raise ParseFailure("invalid escape")
    }
    i = i + 1
  }
  raise ParseFailure("unterminated string")
}

fn parse_int_cache(source : String, idx : Int) -> (Int, Int) raise CacheParseError {
  let mut i = skip_ws_cache(source, idx)
  if i >= source.length() || char_at_cache(source, i) < '0' || char_at_cache(source, i) > '9' {
    raise ParseFailure("expected integer")
  }
  let mut value = 0
  while i < source.length() &&
    char_at_cache(source, i) >= '0' &&
    char_at_cache(source, i) <= '9' {
    value = value * 10 + (char_at_cache(source, i).to_int() - '0'.to_int())
    i = i + 1
  }
  (value, i)
}

fn parse_entry_cache(source : String, idx : Int) -> (CacheEntry, Int) raise CacheParseError {
  let mut i = expect_char_cache(source, idx, '{')
  let mut slug = ""
  let mut fingerprint = ""
  let mut seen_slug = false
  let mut seen_fingerprint = false
  while true {
    i = skip_ws_cache(source, i)
    if i >= source.length() {
      raise ParseFailure("unterminated entry object")
    }
    if char_at_cache(source, i) == '}' {
      if not(seen_slug) || not(seen_fingerprint) {
        raise ParseFailure("entry missing required field")
      }
      return ({ slug, fingerprint }, i + 1)
    }
    let (key, next_after_key) = parse_json_string_cache(source, i)
    i = expect_char_cache(source, next_after_key, ':')
    if key == "slug" {
      let (value, next) = parse_json_string_cache(source, i)
      slug = value
      seen_slug = true
      i = next
    } else if key == "fingerprint" {
      let (value, next) = parse_json_string_cache(source, i)
      fingerprint = value
      seen_fingerprint = true
      i = next
    } else {
      raise ParseFailure("unknown entry field '" + key + "'")
    }
    i = skip_ws_cache(source, i)
    if i >= source.length() {
      raise ParseFailure("unterminated entry object")
    }
    if char_at_cache(source, i) == '}' {
      if not(seen_slug) || not(seen_fingerprint) {
        raise ParseFailure("entry missing required field")
      }
      return ({ slug, fingerprint }, i + 1)
    }
    if char_at_cache(source, i) != ',' {
      raise ParseFailure("expected ',' or '}' in entry object")
    }
    i = i + 1
  }
  raise ParseFailure("unterminated entry object")
}

fn parse_entries_cache(source : String, idx : Int) -> (Array[CacheEntry], Int) raise CacheParseError {
  let mut i = expect_char_cache(source, idx, '[')
  let entries : Array[CacheEntry] = []
  i = skip_ws_cache(source, i)
  if i < source.length() && char_at_cache(source, i) == ']' {
    return (entries, i + 1)
  }
  while true {
    let (entry, next_after_entry) = parse_entry_cache(source, i)
    entries.push(entry)
    i = skip_ws_cache(source, next_after_entry)
    if i >= source.length() {
      raise ParseFailure("unterminated entries array")
    }
    let c = char_at_cache(source, i)
    if c == ']' {
      return (entries, i + 1)
    }
    if c != ',' {
      raise ParseFailure("expected ',' or ']' in entries array")
    }
    i = i + 1
  }
  raise ParseFailure("unterminated entries array")
}

pub fn parse(source : String) -> CacheFile raise CacheParseError {
  let mut i = expect_char_cache(source, 0, '{')
  let (version_key, next_after_version_key) = parse_json_string_cache(source, i)
  if version_key != "version" {
    raise ParseFailure("expected 'version' field")
  }
  i = expect_char_cache(source, next_after_version_key, ':')
  let (version, next_after_version) = parse_int_cache(source, i)
  i = skip_ws_cache(source, next_after_version)
  if i >= source.length() || char_at_cache(source, i) != ',' {
    raise ParseFailure("expected ',' after version")
  }
  i = i + 1
  let (entries_key, next_after_entries_key) = parse_json_string_cache(source, i)
  if entries_key != "entries" {
    raise ParseFailure("expected 'entries' field")
  }
  i = expect_char_cache(source, next_after_entries_key, ':')
  let (entries, next_after_entries) = parse_entries_cache(source, i)
  i = skip_ws_cache(source, next_after_entries)
  if i >= source.length() || char_at_cache(source, i) != '}' {
    raise ParseFailure("expected '}' at end of cache file")
  }
  i = skip_ws_cache(source, i + 1)
  if i != source.length() {
    raise ParseFailure("unexpected trailing characters")
  }
  { version, entries }
}

pub fn render(file : CacheFile) -> String {
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
    buf.write_string("{\"slug\":")
    write_json_string_cache(buf, entry.slug)
    buf.write_string(",\"fingerprint\":")
    write_json_string_cache(buf, entry.fingerprint)
    buf.write_char('}')
    i = i + 1
  }
  buf.write_string("]}")
  buf.to_string()
}

pub fn cache_path(output_dir : String) -> String {
  output_dir + "/.lattice-cache"
}

pub fn empty(output_dir : String) -> CacheStore {
  {
    output_dir,
    entries: [],
    index_by_slug: Map::new(),
  }
}

fn from_file(output_dir : String, file : CacheFile) -> CacheStore {
  let deduped : Array[CacheEntry] = []
  let index_by_slug : Map[String, Int] = Map::new()
  let mut i = 0
  while i < file.entries.length() {
    let entry = file.entries[i]
    match index_by_slug.get(entry.slug) {
      Some(at) => deduped[at] = entry
      None => {
        index_by_slug.set(entry.slug, deduped.length())
        deduped.push(entry)
      }
    }
    i = i + 1
  }
  { output_dir, entries: deduped, index_by_slug }
}

pub fn load(output_dir : String) -> Result[CacheStore, CacheError] {
  let path = cache_path(output_dir)
  if not(@fs.path_exists(path)) {
    return Ok(empty(output_dir))
  }
  let source = try {
    @fs.read_file_to_string(path)
  } catch {
    @fs.IOError(msg) => return Err(ReadError(msg))
  }
  let parsed = try {
    parse(source)
  } catch {
    ParseFailure(msg) => return Err(ParseError(msg))
  }
  if parsed.version != CACHE_VERSION {
    return Err(ParseError("unsupported cache version " + parsed.version.to_string()))
  }
  Ok(from_file(output_dir, parsed))
}

pub fn save(store : CacheStore) -> Result[Unit, CacheError] {
  let path = cache_path(store.output_dir)
  let payload = render({ version: CACHE_VERSION, entries: store.entries })
  try {
    @fs.write_string_to_file(path, payload)
    Ok(())
  } catch {
    @fs.IOError(msg) => Err(WriteError(msg))
  }
}

pub fn lookup(store : CacheStore, slug : String) -> String? {
  match store.index_by_slug.get(slug) {
    Some(at) => Some(store.entries[at].fingerprint)
    None => None
  }
}

pub fn remember(store : CacheStore, slug : String, fingerprint : String) -> Unit {
  let entry : CacheEntry = { slug, fingerprint }
  match store.index_by_slug.get(slug) {
    Some(at) => store.entries[at] = entry
    None => {
      store.index_by_slug.set(slug, store.entries.length())
      store.entries.push(entry)
    }
  }
}

pub fn should_skip(
  store : CacheStore,
  slug : String,
  fingerprint : String,
  output_path : String,
  force_rebuild : Bool
) -> Bool {
  if force_rebuild {
    return false
  }
  if not(@fs.path_exists(output_path)) {
    return false
  }
  match lookup(store, slug) {
    Some(cached) => cached == fingerprint
    None => false
  }
}

fn hash_string_cache(seed : Int64, source : String) -> Int64 {
  let mut hash = seed
  let mut i = 0
  while i < source.length() {
    hash = hash ^ char_at_cache(source, i).to_int().to_int64()
    hash = hash * 1099511628211L
    i = i + 1
  }
  hash
}

pub fn fingerprint_for_source(path : String, source : String) -> String {
  let mut hash = 1469598103934665603L
  hash = hash_string_cache(hash, path)
  hash = hash_string_cache(hash, "\n---\n")
  hash = hash_string_cache(hash, source)
  hash.to_string()
}

pub fn error_text(err : CacheError) -> String {
  match err {
    ReadError(msg) => "read failed: " + msg
    ParseError(msg) => "parse failed: " + msg
    WriteError(msg) => "write failed: " + msg
  }
}
