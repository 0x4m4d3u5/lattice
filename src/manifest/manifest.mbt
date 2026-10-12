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
fn parse_entry_manifest(
  reader : @wire.Reader,
) -> ManifestEntry raise @wire.WireError {
  let mut src : String? = None
  let mut out : String? = None
  let mut mtime : Int64? = None
  let mut targets : Array[String] = []
  reader.fields(key => {
    match key {
      "src" => src = Some(reader.string())
      "out" => out = Some(reader.string())
      "mtime" => mtime = Some(reader.integer(signed=true))
      "targets" => targets = reader.array(() => reader.string())
      _ => raise @wire.WireError("unknown entry field '" + key + "'")
    }
  })
  guard src is Some(src) && out is Some(out) && mtime is Some(mtime) else {
    raise @wire.WireError("entry missing required field")
  }
  { src, mtime, out, targets, }
}

///|
pub fn parse(source : String) -> ManifestFile raise ManifestError {
  let reader = @wire.Reader(source)
  try {
    reader.expect('{')
    reader.key("version")
    let version = reader.integer(signed=true).to_int()
    reader.expect(',')
    reader.key("entries")
    let entries = reader.array(() => parse_entry_manifest(reader))
    reader.expect('}')
    reader.finish()
    { version, entries, }
  } catch {
    @wire.WireError(msg) => raise ParseError(msg)
  }
}

///|
pub fn render(file : ManifestFile) -> String {
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
    buf.write_string("{\"src\":")
    @strutil.write_json_string(buf, entry.src)
    buf.write_string(",\"mtime\":")
    buf.write_string(entry.mtime.to_string())
    buf.write_string(",\"out\":")
    @strutil.write_json_string(buf, entry.out)
    if entry.targets.length() > 0 {
      buf.write_string(",\"targets\":[")
      let mut j = 0
      while j < entry.targets.length() {
        if j > 0 {
          buf.write_char(',')
        }
        @strutil.write_json_string(buf, entry.targets[j])
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
