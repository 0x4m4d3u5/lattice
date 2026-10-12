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
fn parse_entry_cache(reader : @wire.Reader) -> CacheEntry raise @wire.WireError {
  let mut slug : String? = None
  let mut fingerprint : String? = None
  reader.fields(key => {
    match key {
      "slug" => slug = Some(reader.string())
      "fingerprint" => fingerprint = Some(reader.string())
      _ => raise @wire.WireError("unknown entry field '" + key + "'")
    }
  })
  guard slug is Some(slug) && fingerprint is Some(fingerprint) else {
    raise @wire.WireError("entry missing required field")
  }
  { slug, fingerprint, }
}

///|
pub fn parse(source : String) -> CacheFile raise CacheParseError {
  let reader = @wire.Reader(source)
  try {
    reader.expect('{')
    reader.key("version")
    let version = reader.integer(signed=false).to_int()
    reader.expect(',')
    reader.key("entries")
    let entries = reader.array(() => parse_entry_cache(reader))
    reader.expect('}')
    reader.finish()
    { version, entries, }
  } catch {
    @wire.WireError(msg) => raise ParseFailure(msg)
  }
}

///|
pub fn render(file : CacheFile) -> String {
  let buf = StringBuilder()
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
  { output_dir, entries: [], index_by_slug: Map([]), }
}

///|
fn from_file(output_dir : String, file : CacheFile) -> CacheStore {
  let deduped : Array[CacheEntry] = []
  let index_by_slug : Map[String, Int] = Map([])
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
/// Render a store using the same versioned payload as `save`, without writing.
pub fn render_store(store : CacheStore) -> String {
  render({ version: CACHE_VERSION, entries: store.entries })
}

///|
pub fn save(store : CacheStore) -> Result[Unit, CacheError] {
  let path = cache_path(store.output_dir)
  let payload = render_store(store)
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
