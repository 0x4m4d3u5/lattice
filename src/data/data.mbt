///|
/// Typed data-file loader for lattice.
///
/// Data files are TOML-style `key = value` assignments loaded from `data_dir`.
/// Each file becomes a named `DataFile` exposed to templates as:
///
///   {{data.<file>.<key>}}
///
/// Structural guarantees:
/// - Parse errors are surfaced as typed `DataError::ParseError`.
/// - Missing required keys (schema-driven) are surfaced as
///   `DataError::ValidationError` before rendering.
pub struct DataSchema {
  name : String
  required_keys : Array[String]
}

///|
pub struct DataFile {
  name : String
  fields : Map[String, @frontmatter.FrontmatterValue]
}

///|
pub struct DataStore {
  files : Map[String, DataFile]
}

///|
pub enum DataError {
  FileNotFound(String) // data directory path
  ParseError(String, Int, String) // file path, line, message
  ValidationError(String, String, String) // file name, key, message
  IOError(String, String) // path, message
}

///|
fn char_at_data(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

///|
fn substr_data(s : String, start : Int, end_pos : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = start
  while i < end_pos {
    buf.write_char(char_at_data(s, i))
    i = i + 1
  }
  buf.to_string()
}

///|
fn trim_data(s : String) -> String {
  let n = s.length()
  let mut lo = 0
  while lo < n &&
        (
          char_at_data(s, lo) == ' ' ||
          char_at_data(s, lo) == '\t' ||
          char_at_data(s, lo) == '\r' ||
          char_at_data(s, lo) == '\n'
        ) {
    lo = lo + 1
  }
  let mut hi = n
  while hi > lo &&
        (
          char_at_data(s, hi - 1) == ' ' ||
          char_at_data(s, hi - 1) == '\t' ||
          char_at_data(s, hi - 1) == '\r' ||
          char_at_data(s, hi - 1) == '\n'
        ) {
    hi = hi - 1
  }
  substr_data(s, lo, hi)
}

///|
fn starts_with_data(s : String, prefix : String) -> Bool {
  let plen = prefix.length()
  if plen > s.length() {
    return false
  }
  let mut i = 0
  while i < plen {
    if char_at_data(s, i) != char_at_data(prefix, i) {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn ends_with_data(s : String, suffix : String) -> Bool {
  let slen = suffix.length()
  let n = s.length()
  if slen > n {
    return false
  }
  let start = n - slen
  let mut i = 0
  while i < slen {
    if char_at_data(s, start + i) != char_at_data(suffix, i) {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn split_lines_data(s : String) -> Array[String] {
  let lines : Array[String] = []
  let n = s.length()
  let mut i = 0
  while i <= n {
    let mut end = i
    while end < n && char_at_data(s, end) != '\n' {
      end = end + 1
    }
    lines.push(substr_data(s, i, end))
    if end >= n {
      break
    }
    i = end + 1
  }
  lines
}

///|
fn is_digit_data(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn parse_int_data(s : String) -> Int? {
  if s.length() == 0 {
    return None
  }
  let mut i = 0
  let mut neg = false
  if char_at_data(s, 0) == '-' {
    neg = true
    i = 1
  }
  if i >= s.length() {
    return None
  }
  let mut value = 0
  while i < s.length() {
    let c = char_at_data(s, i)
    if not(is_digit_data(c)) {
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
fn parse_quoted_data(s : String, pos : Int) -> Result[(String, Int), String] {
  if pos >= s.length() || char_at_data(s, pos) != '"' {
    return Err("expected quote")
  }
  let buf = StringBuilder::new()
  let mut i = pos + 1
  while i < s.length() {
    let c = char_at_data(s, i)
    if c == '\\' {
      if i + 1 >= s.length() {
        return Err("unterminated escape")
      }
      let esc = char_at_data(s, i + 1)
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

///|
fn skip_ws_data(s : String, pos : Int) -> Int {
  let mut i = pos
  while i < s.length() &&
        (char_at_data(s, i) == ' ' || char_at_data(s, i) == '\t') {
    i = i + 1
  }
  i
}

///|
fn parse_value_at_data(
  s : String,
  pos : Int,
) -> Result[(@frontmatter.FrontmatterValue, Int), String] {
  let i = skip_ws_data(s, pos)
  if i >= s.length() {
    return Err("expected value")
  }
  let c = char_at_data(s, i)
  if c == '"' {
    match parse_quoted_data(s, i) {
      Ok((v, next)) => Ok((@frontmatter.FStr(v), next))
      Err(msg) => Err(msg)
    }
  } else if c == '[' {
    parse_array_at_data(s, i)
  } else if starts_with_data(substr_data(s, i, s.length()), "true") {
    Ok((@frontmatter.FBool(true), i + 4))
  } else if starts_with_data(substr_data(s, i, s.length()), "false") {
    Ok((@frontmatter.FBool(false), i + 5))
  } else {
    let mut j = i
    while j < s.length() &&
          char_at_data(s, j) != ',' &&
          char_at_data(s, j) != ']' {
      j = j + 1
    }
    let raw = trim_data(substr_data(s, i, j))
    match parse_int_data(raw) {
      Some(v) => Ok((@frontmatter.FInt(v), j))
      None => Ok((@frontmatter.FStr(raw), j))
    }
  }
}

///|
fn parse_array_at_data(
  s : String,
  pos : Int,
) -> Result[(@frontmatter.FrontmatterValue, Int), String] {
  if pos >= s.length() || char_at_data(s, pos) != '[' {
    return Err("expected '['")
  }
  let items : Array[@frontmatter.FrontmatterValue] = []
  let mut i = pos + 1
  i = skip_ws_data(s, i)
  if i < s.length() && char_at_data(s, i) == ']' {
    return Ok((@frontmatter.FArray(items), i + 1))
  }
  while i < s.length() {
    match parse_value_at_data(s, i) {
      Ok((v, next)) => {
        items.push(v)
        i = skip_ws_data(s, next)
      }
      Err(msg) => return Err(msg)
    }
    if i >= s.length() {
      return Err("unterminated array")
    }
    let c = char_at_data(s, i)
    if c == ',' {
      i = skip_ws_data(s, i + 1)
    } else if c == ']' {
      return Ok((@frontmatter.FArray(items), i + 1))
    } else {
      return Err("expected ',' or ']' in array")
    }
  }
  Err("unterminated array")
}

///|
fn parse_assignment_data(
  line : String,
) -> Result[(String, @frontmatter.FrontmatterValue), String] {
  let mut eq = -1
  let mut i = 0
  while i < line.length() {
    if char_at_data(line, i) == '=' {
      eq = i
      break
    }
    i = i + 1
  }
  if eq <= 0 {
    return Err("expected key=value")
  }
  let key = trim_data(substr_data(line, 0, eq))
  if key.length() == 0 {
    return Err("empty key")
  }
  let raw = trim_data(substr_data(line, eq + 1, line.length()))
  match parse_value_at_data(raw, 0) {
    Ok((v, _)) => Ok((key, v))
    Err(msg) => Err(msg)
  }
}

///|
fn split_key_path(key : String) -> Array[String] {
  let parts : Array[String] = []
  let mut start = 0
  let mut i = 0
  while i <= key.length() {
    if i == key.length() || char_at_data(key, i) == '.' {
      let part = trim_data(substr_data(key, start, i))
      if part.length() > 0 {
        parts.push(part)
      }
      start = i + 1
    }
    i = i + 1
  }
  parts
}

///|
fn insert_key_path(
  root : Map[String, @frontmatter.FrontmatterValue],
  path : Array[String],
  value : @frontmatter.FrontmatterValue,
) -> Result[Unit, String] {
  if path.length() == 0 {
    return Err("empty key path")
  }
  insert_key_path_at(root, path, 0, value)
}

///|
fn insert_key_path_at(
  cursor : Map[String, @frontmatter.FrontmatterValue],
  path : Array[String],
  idx : Int,
  value : @frontmatter.FrontmatterValue,
) -> Result[Unit, String] {
  let key = path[idx]
  if idx + 1 == path.length() {
    cursor.set(key, value)
    return Ok(())
  }

  let next_map = match cursor.get(key) {
    Some(@frontmatter.FMap(existing)) => existing
    Some(_) => return Err("key path collision at '" + key + "'")
    None => {
      let created : Map[String, @frontmatter.FrontmatterValue] = Map::new()
      cursor.set(key, @frontmatter.FMap(created))
      created
    }
  }
  insert_key_path_at(next_map, path, idx + 1, value)
}

///|
fn file_stem_data(filename : String) -> String {
  if ends_with_data(filename, ".toml") {
    substr_data(filename, 0, filename.length() - 5)
  } else {
    filename
  }
}

///|
fn parse_data_file(
  path : String,
  content : String,
  name : String,
) -> Result[DataFile, DataError] {
  let fields : Map[String, @frontmatter.FrontmatterValue] = Map::new()
  let lines = split_lines_data(content)
  let mut i = 0
  while i < lines.length() {
    let line_no = i + 1
    let raw = trim_data(lines[i])
    if raw.length() == 0 || char_at_data(raw, 0) == '#' {
      i = i + 1
      continue
    }
    match parse_assignment_data(raw) {
      Ok((key, value)) =>
        match insert_key_path(fields, split_key_path(key), value) {
          Ok(_) => ()
          Err(msg) => return Err(ParseError(path, line_no, msg))
        }
      Err(msg) => return Err(ParseError(path, line_no, msg))
    }
    i = i + 1
  }
  Ok({ name, fields })
}

///|
fn validate_file(file : DataFile, schema : DataSchema) -> DataError? {
  let mut i = 0
  while i < schema.required_keys.length() {
    let key = schema.required_keys[i]
    let parts = split_key_path(key)
    match resolve_in_file(file, parts) {
      Some(_) => ()
      None =>
        return Some(ValidationError(file.name, key, "required key missing"))
    }
    i = i + 1
  }
  None
}

///|
fn resolve_in_map(
  map : Map[String, @frontmatter.FrontmatterValue],
  path : Array[String],
  idx : Int,
) -> @frontmatter.FrontmatterValue? {
  if idx >= path.length() {
    return None
  }
  let key = path[idx]
  match map.get(key) {
    None => None
    Some(v) =>
      if idx + 1 == path.length() {
        Some(v)
      } else {
        match v {
          @frontmatter.FMap(inner) => resolve_in_map(inner, path, idx + 1)
          _ => None
        }
      }
  }
}

///|
fn resolve_in_file(
  file : DataFile,
  path : Array[String],
) -> @frontmatter.FrontmatterValue? {
  resolve_in_map(file.fields, path, 0)
}

///|
/// Create an empty data store with no files.
pub fn empty_store() -> DataStore {
  { files: Map::new() }
}

///|
/// Create a data file with typed frontmatter fields.
///
/// Use this for creating test fixtures or data files with complex
/// nested structures. For simple string key-value pairs, use
/// `new_string_file` instead.
pub fn new_file(
  name : String,
  fields : Map[String, @frontmatter.FrontmatterValue],
) -> DataFile {
  { name, fields }
}

///|
/// Create a data store from an array of data files.
pub fn new_store(files : Array[DataFile]) -> DataStore {
  let map : Map[String, DataFile] = Map::new()
  let mut i = 0
  while i < files.length() {
    let file = files[i]
    map.set(file.name, file)
    i = i + 1
  }
  { files: map }
}

///|
/// Create a data file from simple string key-value pairs.
///
/// A convenience helper for test files and simple data files.
/// All values are stored as `FStr` strings. For typed values
/// (integers, booleans, nested maps), use `new_file` instead.
pub fn new_string_file(
  name : String,
  fields : Array[(String, String)],
) -> DataFile {
  let map : Map[String, @frontmatter.FrontmatterValue] = Map::new()
  let mut i = 0
  while i < fields.length() {
    let (key, value) = fields[i]
    map.set(key, @frontmatter.FStr(value))
    i = i + 1
  }
  { name, fields: map }
}

///|
/// Create a data schema for validating data files.
///
/// The schema enforces which keys must be present in a data file.
/// Validation is performed when loading from a directory.
pub fn new_schema(name : String, required_keys : Array[String]) -> DataSchema {
  { name, required_keys }
}

///|
pub fn load_from_dir(
  data_dir : String,
  schemas : Map[String, DataSchema],
) -> Result[DataStore, DataError] {
  if not(@fs.path_exists(data_dir)) {
    return Err(FileNotFound(data_dir))
  }
  let entries = @fs.read_dir(data_dir) catch {
    @fs.IOError(msg) => return Err(IOError(data_dir, msg))
  }

  let files : Map[String, DataFile] = Map::new()
  let mut i = 0
  while i < entries.length() {
    let filename = entries[i]
    if ends_with_data(filename, ".toml") {
      let path = data_dir + "/" + filename
      let content = @fs.read_file_to_string(path) catch {
        @fs.IOError(msg) => return Err(IOError(path, msg))
      }
      let name = file_stem_data(filename)
      let file = match parse_data_file(path, content, name) {
        Ok(parsed) => parsed
        Err(err) => return Err(err)
      }
      match schemas.get(name) {
        Some(schema) =>
          match validate_file(file, schema) {
            Some(err) => return Err(err)
            None => ()
          }
        None => ()
      }
      files.set(name, file)
    }
    i = i + 1
  }
  Ok({ files, })
}

///|
pub fn get_file(store : DataStore, name : String) -> DataFile? {
  store.files.get(name)
}

///|
pub fn resolve(
  store : DataStore,
  file_name : String,
  key_path : Array[String],
) -> Result[@frontmatter.FrontmatterValue, DataError] {
  let file = match store.files.get(file_name) {
    Some(v) => v
    None => return Err(ValidationError(file_name, "", "data file not found"))
  }
  match resolve_in_file(file, key_path) {
    Some(v) => Ok(v)
    None => {
      let path = StringBuilder::new()
      let mut i = 0
      while i < key_path.length() {
        if i > 0 {
          path.write_char('.')
        }
        path.write_string(key_path[i])
        i = i + 1
      }
      Err(ValidationError(file_name, path.to_string(), "key not found"))
    }
  }
}

///|
fn value_to_string_inner(v : @frontmatter.FrontmatterValue) -> String {
  match v {
    @frontmatter.FStr(s) => s
    @frontmatter.FDate(s) => s
    @frontmatter.FInt(i) => i.to_string()
    @frontmatter.FBool(b) => if b { "true" } else { "false" }
    @frontmatter.FArray(items) => {
      let out = StringBuilder::new()
      let mut i = 0
      while i < items.length() {
        if i > 0 {
          out.write_string(", ")
        }
        out.write_string(value_to_string_inner(items[i]))
        i = i + 1
      }
      out.to_string()
    }
    @frontmatter.FMap(map) => {
      let _ = map
      "[object]"
    }
  }
}

///|
pub fn value_to_string(v : @frontmatter.FrontmatterValue) -> String {
  value_to_string_inner(v)
}

///|
pub fn resolve_string(
  store : DataStore,
  file_name : String,
  key_path : Array[String],
) -> Result[String, DataError] {
  match resolve(store, file_name, key_path) {
    Ok(v) => Ok(value_to_string(v))
    Err(e) => Err(e)
  }
}

///|
pub fn format_error(err : DataError) -> String {
  match err {
    FileNotFound(path) => "data directory not found: " + path
    ParseError(path, line, msg) => path + ":" + line.to_string() + ": " + msg
    ValidationError(file, key, msg) =>
      if key.length() == 0 {
        "data." + file + ": " + msg
      } else {
        "data." + file + "." + key + ": " + msg
      }
    IOError(path, msg) => "data I/O error " + path + ": " + msg
  }
}
