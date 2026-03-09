///|
/// Typed collections configuration for lattice.
///
/// Format (toml-lite):
/// [posts]
/// schema = "title:String,date:String,description:Optional[String],tags:Optional[Array[String]],draft:Optional[Bool]"
/// dir = "./content"

pub(all) struct CollectionDef {
  name : String
  schema : @schema.Schema
  content_dir : String
}

pub struct CollectionsConfig {
  definitions : Array[CollectionDef]
}

pub enum CollectionsError {
  InvalidLine(Int, String)
  MissingRequiredField(String, String)
  DuplicateCollection(String)
  InvalidSchema(String, String)
  EmptyConfig
}

fn char_at_collections(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

fn substr_collections(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = start
  while i < end {
    buf.write_char(char_at_collections(s, i))
    i = i + 1
  }
  buf.to_string()
}

fn trim_collections(s : String) -> String {
  let n = s.length()
  if n == 0 {
    return s
  }
  let mut lo = 0
  while lo < n &&
    (char_at_collections(s, lo) == ' ' ||
      char_at_collections(s, lo) == '\t' ||
      char_at_collections(s, lo) == '\r') {
    lo = lo + 1
  }
  let mut hi = n
  while hi > lo &&
    (char_at_collections(s, hi - 1) == ' ' ||
      char_at_collections(s, hi - 1) == '\t' ||
      char_at_collections(s, hi - 1) == '\r') {
    hi = hi - 1
  }
  substr_collections(s, lo, hi)
}

fn next_newline_collections(s : String, from : Int) -> Int {
  let n = s.length()
  let mut i = from
  while i < n && char_at_collections(s, i) != '\n' {
    i = i + 1
  }
  i
}

fn split_lines_collections(s : String) -> Array[String] {
  let lines : Array[String] = []
  let n = s.length()
  let mut i = 0
  while i <= n {
    let end = next_newline_collections(s, i)
    lines.push(substr_collections(s, i, end))
    if end >= n {
      break
    }
    i = end + 1
  }
  lines
}

fn is_field_name_start(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

fn is_field_name_char(c : Char) -> Bool {
  is_field_name_start(c) || (c >= '0' && c <= '9') || c == '-'
}

fn is_valid_field_name(name : String) -> Bool {
  if name.length() == 0 {
    return false
  }
  if not(is_field_name_start(char_at_collections(name, 0))) {
    return false
  }
  let mut i = 1
  while i < name.length() {
    if not(is_field_name_char(char_at_collections(name, i))) {
      return false
    }
    i = i + 1
  }
  true
}

fn skip_ws_type(s : String, pos : Int) -> Int {
  let mut i = pos
  while i < s.length() &&
    (char_at_collections(s, i) == ' ' || char_at_collections(s, i) == '\t') {
    i = i + 1
  }
  i
}

fn parse_type_name(s : String, pos : Int) -> (String, Int) {
  let mut i = pos
  while i < s.length() {
    let c = char_at_collections(s, i)
    if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') {
      i = i + 1
    } else {
      break
    }
  }
  (substr_collections(s, pos, i), i)
}

fn parse_field_type_at(
  s : String,
  pos : Int
) -> Result[(@schema.FieldType, Int), String] {
  let start = skip_ws_type(s, pos)
  if start >= s.length() {
    return Err("expected field type")
  }

  let (name, next) = parse_type_name(s, start)
  if name == "String" {
    return Ok((@schema.TString, next))
  }
  if name == "Int" {
    return Ok((@schema.TInt, next))
  }
  if name == "Bool" {
    return Ok((@schema.TBool, next))
  }
  if name == "Array" || name == "Optional" {
    let p = skip_ws_type(s, next)
    if p >= s.length() || char_at_collections(s, p) != '[' {
      return Err("expected '[' after " + name)
    }
    match parse_field_type_at(s, p + 1) {
      Err(e) => return Err(e)
      Ok((inner, after_inner)) => {
        let q = skip_ws_type(s, after_inner)
        if q >= s.length() || char_at_collections(s, q) != ']' {
          return Err("expected ']' after " + name + " inner type")
        }
        if name == "Array" {
          return Ok((@schema.TArray(inner), q + 1))
        }
        return Ok((@schema.TOptional(inner), q + 1))
      }
    }
  }
  Err("unknown field type: " + name)
}

fn parse_field_type_text(s : String) -> Result[@schema.FieldType, String] {
  match parse_field_type_at(s, 0) {
    Err(e) => Err(e)
    Ok((ft, next)) => {
      let end = skip_ws_type(s, next)
      if end != s.length() {
        Err("unexpected trailing input in type")
      } else {
        Ok(ft)
      }
    }
  }
}

fn parse_schema_fields(
  collection_name : String,
  schema_text : String
) -> Result[Array[@schema.FieldDef], CollectionsError] {
  let fields : Array[@schema.FieldDef] = []
  let n = schema_text.length()
  let mut seg_start = 0
  let mut depth = 0
  let mut i = 0
  while i <= n {
    let at_end = i == n
    let c = if at_end { ',' } else { char_at_collections(schema_text, i) }
    if not(at_end) && c == '[' {
      depth = depth + 1
      i = i + 1
      continue
    }
    if not(at_end) && c == ']' {
      if depth > 0 {
        depth = depth - 1
      }
      i = i + 1
      continue
    }
    if c == ',' && depth == 0 {
      let entry = trim_collections(substr_collections(schema_text, seg_start, i))
      if entry.length() > 0 {
        let mut colon = -1
        let mut j = 0
        while j < entry.length() {
          if char_at_collections(entry, j) == ':' {
            colon = j
            break
          }
          j = j + 1
        }
        if colon <= 0 || colon >= entry.length() - 1 {
          return Err(InvalidSchema(collection_name, "invalid field declaration: " + entry))
        }

        let field_name = trim_collections(substr_collections(entry, 0, colon))
        if not(is_valid_field_name(field_name)) {
          return Err(InvalidSchema(collection_name, "invalid field name: " + field_name))
        }
        let type_text = trim_collections(substr_collections(entry, colon + 1, entry.length()))
        let field_type = match parse_field_type_text(type_text) {
          Ok(ft) => ft
          Err(e) => return Err(InvalidSchema(collection_name, e))
        }
        let required = match field_type {
          @schema.TOptional(_) => false
          _ => true
        }
        fields.push({ name: field_name, field_type, required })
      }
      seg_start = i + 1
    }
    i = i + 1
  }

  if fields.length() == 0 {
    return Err(InvalidSchema(collection_name, "schema must define at least one field"))
  }
  Ok(fields)
}

fn parse_value_literal(line_no : Int, raw : String) -> Result[String, CollectionsError] {
  let value = trim_collections(raw)
  if value.length() == 0 {
    return Err(InvalidLine(line_no, "empty value"))
  }
  if char_at_collections(value, 0) == '"' {
    if value.length() < 2 || char_at_collections(value, value.length() - 1) != '"' {
      return Err(InvalidLine(line_no, "unterminated quoted string"))
    }
    Ok(substr_collections(value, 1, value.length() - 1))
  } else {
    Ok(value)
  }
}

fn finalize_collection(
  defs : Array[CollectionDef],
  seen : Map[String, Bool],
  name : String,
  schema_text : String?,
  dir_text : String?
) -> Result[Unit, CollectionsError] {
  if seen.get(name) != None {
    return Err(DuplicateCollection(name))
  }
  let schema_value = match schema_text {
    Some(v) => v
    None => return Err(MissingRequiredField(name, "schema"))
  }
  let dir_value = match dir_text {
    Some(v) => v
    None => return Err(MissingRequiredField(name, "dir"))
  }
  let fields = match parse_schema_fields(name, schema_value) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let schema : @schema.Schema = { name, fields }
  defs.push({ name, schema, content_dir: dir_value })
  seen.set(name, true)
  Ok(())
}

///|
/// Parse collections config text into typed collection definitions.
pub fn parse(input : String) -> Result[CollectionsConfig, CollectionsError] {
  let lines = split_lines_collections(input)
  let defs : Array[CollectionDef] = []
  let seen : Map[String, Bool] = Map::new()

  let mut current_name : String? = None
  let mut current_schema : String? = None
  let mut current_dir : String? = None

  let mut i = 0
  while i < lines.length() {
    let line_no = i + 1
    let raw = trim_collections(lines[i])
    if raw.length() == 0 || char_at_collections(raw, 0) == '#' {
      i = i + 1
      continue
    }

    if char_at_collections(raw, 0) == '[' {
      if raw.length() < 3 || char_at_collections(raw, raw.length() - 1) != ']' {
        return Err(InvalidLine(line_no, "invalid section header"))
      }
      if char_at_collections(raw, 1) == '[' {
        return Err(InvalidLine(line_no, "invalid section header"))
      }
      let section_name = trim_collections(substr_collections(raw, 1, raw.length() - 1))
      if not(is_valid_field_name(section_name)) {
        return Err(InvalidLine(line_no, "invalid collection name"))
      }

      match current_name {
        Some(name) => {
          match finalize_collection(defs, seen, name, current_schema, current_dir) {
            Err(e) => return Err(e)
            Ok(_) => ()
          }
          current_schema = None
          current_dir = None
        }
        None => ()
      }
      current_name = Some(section_name)
      i = i + 1
      continue
    }

    let section = match current_name {
      Some(v) => v
      None => return Err(InvalidLine(line_no, "assignment outside section"))
    }

    let mut eq = -1
    let mut j = 0
    while j < raw.length() {
      if char_at_collections(raw, j) == '=' {
        eq = j
        break
      }
      j = j + 1
    }
    if eq <= 0 || eq >= raw.length() - 1 {
      return Err(InvalidLine(line_no, "expected key=value"))
    }

    let key = trim_collections(substr_collections(raw, 0, eq))
    let raw_value = substr_collections(raw, eq + 1, raw.length())
    let value = match parse_value_literal(line_no, raw_value) {
      Ok(v) => v
      Err(e) => return Err(e)
    }

    if key == "schema" {
      current_schema = Some(value)
    } else if key == "dir" {
      current_dir = Some(value)
    } else {
      return Err(InvalidLine(line_no, "unknown key in section '" + section + "': " + key))
    }

    i = i + 1
  }

  match current_name {
    Some(name) => {
      match finalize_collection(defs, seen, name, current_schema, current_dir) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    }
    None => ()
  }

  if defs.length() == 0 {
    return Err(EmptyConfig)
  }

  Ok({ definitions: defs })
}

///|
/// Default fallback collection used when no collections config is provided.
pub fn default_posts_collection(content_dir : String) -> CollectionDef {
  {
    name: "posts",
    schema: {
      name: "posts",
      fields: [
        { name: "title", field_type: @schema.TString, required: true },
        { name: "date", field_type: @schema.TString, required: true },
        {
          name: "description",
          field_type: @schema.TOptional(@schema.TString),
          required: false,
        },
        {
          name: "tags",
          field_type: @schema.TOptional(@schema.TArray(@schema.TString)),
          required: false,
        },
        {
          name: "draft",
          field_type: @schema.TOptional(@schema.TBool),
          required: false,
        },
      ],
    },
    content_dir,
  }
}
