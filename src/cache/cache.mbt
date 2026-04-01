///|
pub(all) struct CacheEntry {
  slug : String
  fingerprint : String
}

///|
pub(all) struct CacheFile {
  version : Int
  entries : Array[CacheEntry]
}

///|
pub(all) struct CacheStore {
  output_dir : String
  entries : Array[CacheEntry]
  index_by_slug : Map[String, Int]
}

///|
pub(all) suberror CacheParseError {
  ParseFailure(String)
}

///|
pub(all) suberror CacheError {
  ReadError(String)
  ParseError(String)
  WriteError(String)
}

///|
const CACHE_VERSION : Int = 1

///|
fn expect_char_cache(
  source : String,
  idx : Int,
  expected : Char,
) -> Int raise CacheParseError {
  let i = @strutil.skip_ws(source, idx)
  if i >= source.length() || @strutil.char_at(source, i) != expected {
    raise ParseFailure("expected '" + expected.to_string() + "'")
  }
  i + 1
}

///|
fn parse_json_string_cache(
  source : String,
  idx : Int,
) -> (String, Int) raise CacheParseError {
  let mut i = @strutil.skip_ws(source, idx)
  if i >= source.length() || @strutil.char_at(source, i) != '"' {
    raise ParseFailure("expected string")
  }
  i = i + 1
  let buf = StringBuilder::new()
  while i < source.length() {
    let c = @strutil.char_at(source, i)
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
    let escaped = @strutil.char_at(source, i)
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

///|
fn parse_int_cache(
  source : String,
  idx : Int,
) -> (Int, Int) raise CacheParseError {
  let mut i = @strutil.skip_ws(source, idx)
  if i >= source.length() ||
    @strutil.char_at(source, i) < '0' ||
    @strutil.char_at(source, i) > '9' {
    raise ParseFailure("expected integer")
  }
  let mut value = 0
  while i < source.length() &&
        @strutil.char_at(source, i) >= '0' &&
        @strutil.char_at(source, i) <= '9' {
    value = value * 10 + (@strutil.char_at(source, i).to_int() - '0'.to_int())
    i = i + 1
  }
  (value, i)
}

///|
fn parse_entry_cache(
  source : String,
  idx : Int,
) -> (CacheEntry, Int) raise CacheParseError {
  let mut i = expect_char_cache(source, idx, '{')
  let mut slug = ""
  let mut fingerprint = ""
  let mut seen_slug = false
  let mut seen_fingerprint = false
  while true {
    i = @strutil.skip_ws(source, i)
    if i >= source.length() {
      raise ParseFailure("unterminated entry object")
    }
    if @strutil.char_at(source, i) == '}' {
      if !seen_slug || !seen_fingerprint {
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
    i = @strutil.skip_ws(source, i)
    if i >= source.length() {
      raise ParseFailure("unterminated entry object")
    }
    if @strutil.char_at(source, i) == '}' {
      if !seen_slug || !seen_fingerprint {
        raise ParseFailure("entry missing required field")
      }
      return ({ slug, fingerprint }, i + 1)
    }
    if @strutil.char_at(source, i) != ',' {
      raise ParseFailure("expected ',' or '}' in entry object")
    }
    i = i + 1
  }
  raise ParseFailure("unterminated entry object")
}

///|
fn parse_entries_cache(
  source : String,
  idx : Int,
) -> (Array[CacheEntry], Int) raise CacheParseError {
  let mut i = expect_char_cache(source, idx, '[')
  let entries : Array[CacheEntry] = []
  i = @strutil.skip_ws(source, i)
  if i < source.length() && @strutil.char_at(source, i) == ']' {
    return (entries, i + 1)
  }
  while true {
    let (entry, next_after_entry) = parse_entry_cache(source, i)
    entries.push(entry)
    i = @strutil.skip_ws(source, next_after_entry)
    if i >= source.length() {
      raise ParseFailure("unterminated entries array")
    }
    let c = @strutil.char_at(source, i)
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

///|
pub fn parse(source : String) -> CacheFile raise CacheParseError {
  let mut i = expect_char_cache(source, 0, '{')
  let (version_key, next_after_version_key) = parse_json_string_cache(source, i)
  if version_key != "version" {
    raise ParseFailure("expected 'version' field")
  }
  i = expect_char_cache(source, next_after_version_key, ':')
  let (version, next_after_version) = parse_int_cache(source, i)
  i = @strutil.skip_ws(source, next_after_version)
  if i >= source.length() || @strutil.char_at(source, i) != ',' {
    raise ParseFailure("expected ',' after version")
  }
  i = i + 1
  let (entries_key, next_after_entries_key) = parse_json_string_cache(source, i)
  if entries_key != "entries" {
    raise ParseFailure("expected 'entries' field")
  }
  i = expect_char_cache(source, next_after_entries_key, ':')
  let (entries, next_after_entries) = parse_entries_cache(source, i)
  i = @strutil.skip_ws(source, next_after_entries)
  if i >= source.length() || @strutil.char_at(source, i) != '}' {
    raise ParseFailure("expected '}' at end of cache file")
  }
  i = @strutil.skip_ws(source, i + 1)
  if i != source.length() {
    raise ParseFailure("unexpected trailing characters")
  }
  { version, entries }
}

///|
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
    @strutil.write_json_string(buf, entry.slug)
    buf.write_string(",\"fingerprint\":")
    @strutil.write_json_string(buf, entry.fingerprint)
    buf.write_char('}')
    i = i + 1
  }
  buf.write_string("]}")
  buf.to_string()
}

///|
pub fn cache_path(output_dir : String) -> String {
  output_dir + "/.lattice-cache"
}

///|
pub fn empty(output_dir : String) -> CacheStore {
  { output_dir, entries: [], index_by_slug: Map::new() }
}

///|
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

///|
pub fn load(output_dir : String) -> Result[CacheStore, CacheError] {
  let path = cache_path(output_dir)
  if !@fs.path_exists(path) {
    return Ok(empty(output_dir))
  }
  let source = @fs.read_file_to_string(path) catch {
    @fs.IOError(msg) => return Err(ReadError(msg))
  }
  let parsed = parse(source) catch {
    ParseFailure(msg) => return Err(ParseError(msg))
  }
  if parsed.version != CACHE_VERSION {
    return Err(
      ParseError("unsupported cache version " + parsed.version.to_string()),
    )
  }
  Ok(from_file(output_dir, parsed))
}

///|
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

///|
pub fn lookup(store : CacheStore, slug : String) -> String? {
  match store.index_by_slug.get(slug) {
    Some(at) => Some(store.entries[at].fingerprint)
    None => None
  }
}

///|
pub fn remember(
  store : CacheStore,
  slug : String,
  fingerprint : String,
) -> Unit {
  let entry : CacheEntry = { slug, fingerprint }
  match store.index_by_slug.get(slug) {
    Some(at) => store.entries[at] = entry
    None => {
      store.index_by_slug.set(slug, store.entries.length())
      store.entries.push(entry)
    }
  }
}

///|
pub fn should_skip(
  store : CacheStore,
  slug : String,
  fingerprint : String,
  output_path : String,
  force_rebuild : Bool,
) -> Bool {
  if force_rebuild {
    return false
  }
  if !@fs.path_exists(output_path) {
    return false
  }
  match lookup(store, slug) {
    Some(cached) => cached == fingerprint
    None => false
  }
}

///|
fn hash_string_cache(seed : Int64, source : String) -> Int64 {
  let mut hash = seed
  let mut i = 0
  while i < source.length() {
    hash = hash ^ @strutil.char_at(source, i).to_int().to_int64()
    hash = hash * 1099511628211L
    i = i + 1
  }
  hash
}

///|
pub fn fingerprint_for_source(path : String, source : String) -> String {
  let mut hash = 1469598103934665603L
  hash = hash_string_cache(hash, path)
  hash = hash_string_cache(hash, "\n---\n")
  hash = hash_string_cache(hash, source)
  hash.to_string()
}

///|
pub fn error_text(err : CacheError) -> String {
  match err {
    ReadError(msg) => "read failed: " + msg
    ParseError(msg) => "parse failed: " + msg
    WriteError(msg) => "write failed: " + msg
  }
}
