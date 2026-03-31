///|
/// Typed collections configuration for lattice.
///
/// Supported sections:
/// - `[collection_name]` for content collections
/// - `[data.file_name]` for data-file schemas
///
/// Example:
/// [posts]
/// schema = "title:String,date:Date"
/// dir = "./content/posts"
///
/// [data.nav]
/// required = "title,links"
pub(all) enum SortOrder {
  DateDesc // default: newest first
  DateAsc // oldest first
  TitleAsc // alphabetical
  TitleDesc // reverse alphabetical
}

///|
pub(all) struct CollectionDef {
  name : String
  schema : @schema.Schema
  content_dir : String
  template : String?
  page_size : Int?
  sort_order : SortOrder
}

///|
pub(all) struct DataSchemaDef {
  name : String
  required_keys : Array[String]
}

///|
pub struct CollectionsConfig {
  definitions : Array[CollectionDef]
  data_schemas : Map[String, DataSchemaDef]
  data_schema_list : Array[DataSchemaDef]
}

///|
pub enum CollectionsError {
  InvalidLine(Int, String)
  MissingRequiredField(String, String)
  DuplicateCollection(String)
  DuplicateDataSchema(String)
  InvalidSchema(String, String)
  EmptyConfig
}

///|
priv enum SectionKind {
  CollectionSection(String)
  DataSection(String)
}

///|
fn next_newline_collections(s : String, from : Int) -> Int {
  let n = s.length()
  let mut i = from
  while i < n && @strutil.char_at(s, i) != '\n' {
    i = i + 1
  }
  i
}

///|
fn split_lines_collections(s : String) -> Array[String] {
  let lines : Array[String] = []
  let n = s.length()
  let mut i = 0
  while i <= n {
    let end = next_newline_collections(s, i)
    lines.push(@strutil.substr(s, i, end))
    if end >= n {
      break
    }
    i = end + 1
  }
  lines
}

///|
fn starts_with_collections(s : String, prefix : String) -> Bool {
  if prefix.length() > s.length() {
    return false
  }
  let mut i = 0
  while i < prefix.length() {
    if @strutil.char_at(s, i) != @strutil.char_at(prefix, i) {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn is_field_name_start(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

///|
fn is_field_name_char(c : Char) -> Bool {
  is_field_name_start(c) || (c >= '0' && c <= '9') || c == '-'
}

///|
fn is_valid_field_name(name : String) -> Bool {
  if name.length() == 0 {
    return false
  }
  if not(is_field_name_start(@strutil.char_at(name, 0))) {
    return false
  }
  let mut i = 1
  while i < name.length() {
    if not(is_field_name_char(@strutil.char_at(name, i))) {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn parse_section_header(
  raw : String,
  line_no : Int,
) -> Result[SectionKind, CollectionsError] {
  if raw.length() < 3 ||
    @strutil.char_at(raw, 0) != '[' ||
    @strutil.char_at(raw, raw.length() - 1) != ']' {
    return Err(InvalidLine(line_no, "invalid section header"))
  }
  let section = @strutil.trim(@strutil.substr(raw, 1, raw.length() - 1))
  if section.length() == 0 {
    return Err(InvalidLine(line_no, "empty section header"))
  }
  if starts_with_collections(section, "data.") {
    let name = @strutil.trim(@strutil.substr(section, 5, section.length()))
    if not(is_valid_field_name(name)) {
      return Err(InvalidLine(line_no, "invalid data schema name"))
    }
    return Ok(DataSection(name))
  }
  if not(is_valid_field_name(section)) {
    return Err(InvalidLine(line_no, "invalid collection name"))
  }
  Ok(CollectionSection(section))
}

///|
fn skip_ws_type(s : String, pos : Int) -> Int {
  let mut i = pos
  while i < s.length() &&
        (@strutil.char_at(s, i) == ' ' || @strutil.char_at(s, i) == '\t') {
    i = i + 1
  }
  i
}

///|
fn parse_type_name(s : String, pos : Int) -> (String, Int) {
  let mut i = pos
  while i < s.length() {
    let c = @strutil.char_at(s, i)
    if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') {
      i = i + 1
    } else {
      break
    }
  }
  (@strutil.substr(s, pos, i), i)
}

///|
fn parse_string_array_at(
  s : String,
  pos : Int,
) -> Result[(Array[String], Int), String] {
  let start = skip_ws_type(s, pos)
  if start >= s.length() || @strutil.char_at(s, start) != '[' {
    return Err("expected '[' for enum values")
  }
  let values : Array[String] = []
  let mut i = start + 1
  while i < s.length() {
    let p = skip_ws_type(s, i)
    if p >= s.length() {
      return Err("unexpected end of input in enum")
    }
    let c = @strutil.char_at(s, p)
    if c == ']' {
      return Ok((values, p + 1))
    }
    if c == '"' {
      let mut j = p + 1
      while j < s.length() {
        let ch = @strutil.char_at(s, j)
        if ch == '"' {
          values.push(@strutil.substr(s, p + 1, j))
          i = j + 1
          break
        }
        if ch == '\\' && j + 1 < s.length() {
          j = j + 2
        } else {
          j = j + 1
        }
      }
      if j >= s.length() {
        return Err("unterminated string in enum values")
      }
    } else {
      return Err("expected quoted string in enum values")
    }
    let q = skip_ws_type(s, i)
    if q < s.length() {
      let comma = @strutil.char_at(s, q)
      if comma == ',' {
        i = q + 1
      } else if comma != ']' {
        return Err("expected ',' or ']' after enum value")
      }
    }
  }
  Err("expected ']' to close enum values")
}

///|
/// Parse a float literal (with optional minus sign and decimal point) starting at position.
/// Returns the literal string and the position after the last digit.
fn parse_float_literal_at(s : String, pos : Int) -> (String, Int) {
  let mut i = pos
  if i < s.length() && @strutil.char_at(s, i) == '-' {
    i = i + 1
  }
  while i < s.length() {
    let c = @strutil.char_at(s, i)
    if c < '0' || c > '9' {
      break
    }
    i = i + 1
  }
  // Optional decimal point and fractional digits
  if i < s.length() && @strutil.char_at(s, i) == '.' {
    i = i + 1
    while i < s.length() {
      let c = @strutil.char_at(s, i)
      if c < '0' || c > '9' {
        break
      }
      i = i + 1
    }
  }
  (@strutil.substr(s, pos, i), i)
}

///|
/// Parse a string as a double, supporting negative values and decimal points.
fn parse_positive_or_negative_float(s : String) -> Double? {
  @strutil.parse_float(s)
}

///|
/// Parse an integer literal (with optional minus sign) starting at position.
/// Returns the literal string and the position after the last digit.
fn parse_int_literal_at(s : String, pos : Int) -> (String, Int) {
  let mut i = pos
  if i < s.length() && @strutil.char_at(s, i) == '-' {
    i = i + 1
  }
  while i < s.length() {
    let c = @strutil.char_at(s, i)
    if c < '0' || c > '9' {
      break
    }
    i = i + 1
  }
  (@strutil.substr(s, pos, i), i)
}

///|
/// Parse a date literal (YYYY-MM-DD) starting at position.
/// Returns the literal string and the position after the last digit.
/// This is a simple scan: digits and hyphens in the expected positions.
fn parse_date_literal_at(s : String, pos : Int) -> (String, Int) {
  let mut i = pos
  while i < s.length() {
    let c = @strutil.char_at(s, i)
    if (c >= '0' && c <= '9') || c == '-' {
      i = i + 1
    } else {
      break
    }
  }
  (@strutil.substr(s, pos, i), i)
}

///|
/// Parse a string as an integer, supporting negative values.
fn parse_positive_or_negative_int(s : String) -> Int? {
  if s.length() == 0 {
    return None
  }
  let mut i = 0
  let mut neg = false
  if @strutil.char_at(s, 0) == '-' {
    neg = true
    i = 1
    if i >= s.length() {
      return None
    }
  }
  let mut parsed = 0
  while i < s.length() {
    let c = @strutil.char_at(s, i)
    if c < '0' || c > '9' {
      return None
    }
    parsed = parsed * 10 + (c.to_int() - '0'.to_int())
    i = i + 1
  }
  if neg {
    Some(0 - parsed)
  } else {
    Some(parsed)
  }
}

///|
fn parse_field_type_at(
  s : String,
  pos : Int,
) -> Result[(@schema.FieldType, Int), String] {
  let start = skip_ws_type(s, pos)
  if start >= s.length() {
    return Err("expected field type")
  }

  let (name, next) = parse_type_name(s, start)
  if name == "String" {
    // Check for String(minlen=...,maxlen=...) syntax
    let p = skip_ws_type(s, next)
    if p < s.length() && @strutil.char_at(s, p) == '(' {
      // Parse String(minlen=N,maxlen=M) or String(minlen=N) or String(maxlen=M)
      let mut minlen_val : Int? = None
      let mut maxlen_val : Int? = None
      let mut j = p + 1
      let mut done = false
      while j < s.length() && not(done) {
        let q = skip_ws_type(s, j)
        if q < s.length() && @strutil.char_at(s, q) == ')' {
          j = q + 1
          done = true
        } else if starts_with_collections(
            @strutil.substr(s, q, s.length()),
            "minlen=",
          ) {
          j = q + 7 // skip "minlen="
          let (num_str, after_num) = parse_int_literal_at(s, j)
          match parse_positive_or_negative_int(num_str) {
            Some(v) => minlen_val = Some(v)
            None => return Err("invalid minlen value in String bounds")
          }
          j = skip_ws_type(s, after_num)
          if j < s.length() && @strutil.char_at(s, j) == ',' {
            j = j + 1
          }
        } else if starts_with_collections(
            @strutil.substr(s, q, s.length()),
            "maxlen=",
          ) {
          j = q + 7 // skip "maxlen="
          let (num_str, after_num) = parse_int_literal_at(s, j)
          match parse_positive_or_negative_int(num_str) {
            Some(v) => maxlen_val = Some(v)
            None => return Err("invalid maxlen value in String bounds")
          }
          j = skip_ws_type(s, after_num)
          if j < s.length() && @strutil.char_at(s, j) == ',' {
            j = j + 1
          }
        } else {
          return Err("unexpected content in String() bounds")
        }
      }
      if not(done) {
        return Err("expected ')' to close String bounds")
      }
      return Ok((@schema.TString(minlen_val, maxlen_val), j))
    }
    return Ok((@schema.TString(None, None), next))
  }
  if name == "Date" {
    let p = skip_ws_type(s, next)
    if p < s.length() && @strutil.char_at(s, p) == '(' {
      // Parse Date(after=YYYY-MM-DD,before=YYYY-MM-DD) syntax
      let mut after_val : String? = None
      let mut before_val : String? = None
      let mut j = p + 1
      let mut done = false
      while j < s.length() && not(done) {
        let q = skip_ws_type(s, j)
        if q < s.length() && @strutil.char_at(s, q) == ')' {
          j = q + 1
          done = true
        } else if starts_with_collections(
            @strutil.substr(s, q, s.length()),
            "after=",
          ) {
          j = q + 6 // skip "after="
          let (date_str, after_date) = parse_date_literal_at(s, j)
          if date_str.length() == 0 {
            return Err("invalid after value in Date bounds")
          }
          after_val = Some(date_str)
          j = skip_ws_type(s, after_date)
          if j < s.length() && @strutil.char_at(s, j) == ',' {
            j = j + 1
          }
        } else if starts_with_collections(
            @strutil.substr(s, q, s.length()),
            "before=",
          ) {
          j = q + 7 // skip "before="
          let (date_str, after_date) = parse_date_literal_at(s, j)
          if date_str.length() == 0 {
            return Err("invalid before value in Date bounds")
          }
          before_val = Some(date_str)
          j = skip_ws_type(s, after_date)
          if j < s.length() && @strutil.char_at(s, j) == ',' {
            j = j + 1
          }
        } else {
          return Err("unexpected content in Date() bounds")
        }
      }
      if not(done) {
        return Err("expected ')' to close Date bounds")
      }
      return Ok((@schema.TDate(after_val, before_val), j))
    }
    return Ok((@schema.TDate(None, None), next))
  }
  if name == "Int" {
    let p = skip_ws_type(s, next)
    if p < s.length() && @strutil.char_at(s, p) == '(' {
      // Parse Int(min=N,max=M) or Int(min=N) or Int(max=M)
      let mut min_val : Int? = None
      let mut max_val : Int? = None
      let mut j = p + 1
      // Parse key=value pairs separated by commas
      let mut done = false
      while j < s.length() && not(done) {
        let q = skip_ws_type(s, j)
        if q < s.length() && @strutil.char_at(s, q) == ')' {
          j = q + 1
          done = true
        } else if starts_with_collections(
            @strutil.substr(s, q, s.length()),
            "min=",
          ) {
          j = q + 4 // skip "min="
          let (num_str, after_num) = parse_int_literal_at(s, j)
          match parse_positive_or_negative_int(num_str) {
            Some(v) => min_val = Some(v)
            None => return Err("invalid min value in Int bounds")
          }
          j = skip_ws_type(s, after_num)
          if j < s.length() && @strutil.char_at(s, j) == ',' {
            j = j + 1
          }
        } else if starts_with_collections(
            @strutil.substr(s, q, s.length()),
            "max=",
          ) {
          j = q + 4 // skip "max="
          let (num_str, after_num) = parse_int_literal_at(s, j)
          match parse_positive_or_negative_int(num_str) {
            Some(v) => max_val = Some(v)
            None => return Err("invalid max value in Int bounds")
          }
          j = skip_ws_type(s, after_num)
          if j < s.length() && @strutil.char_at(s, j) == ',' {
            j = j + 1
          }
        } else {
          return Err("unexpected content in Int() bounds")
        }
      }
      if not(done) {
        return Err("expected ')' to close Int bounds")
      }
      return Ok((@schema.TInt(min_val, max_val), j))
    }
    return Ok((@schema.TInt(None, None), next))
  }
  if name == "Float" {
    let p = skip_ws_type(s, next)
    if p < s.length() && @strutil.char_at(s, p) == '(' {
      // Parse Float(min=N,max=M) or Float(min=N) or Float(max=M)
      let mut min_val : Double? = None
      let mut max_val : Double? = None
      let mut j = p + 1
      let mut done = false
      while j < s.length() && not(done) {
        let q = skip_ws_type(s, j)
        if q < s.length() && @strutil.char_at(s, q) == ')' {
          j = q + 1
          done = true
        } else if starts_with_collections(
            @strutil.substr(s, q, s.length()),
            "min=",
          ) {
          j = q + 4 // skip "min="
          let (num_str, after_num) = parse_float_literal_at(s, j)
          match parse_positive_or_negative_float(num_str) {
            Some(v) => min_val = Some(v)
            None => return Err("invalid min value in Float bounds")
          }
          j = skip_ws_type(s, after_num)
          if j < s.length() && @strutil.char_at(s, j) == ',' {
            j = j + 1
          }
        } else if starts_with_collections(
            @strutil.substr(s, q, s.length()),
            "max=",
          ) {
          j = q + 4 // skip "max="
          let (num_str, after_num) = parse_float_literal_at(s, j)
          match parse_positive_or_negative_float(num_str) {
            Some(v) => max_val = Some(v)
            None => return Err("invalid max value in Float bounds")
          }
          j = skip_ws_type(s, after_num)
          if j < s.length() && @strutil.char_at(s, j) == ',' {
            j = j + 1
          }
        } else {
          return Err("unexpected content in Float() bounds")
        }
      }
      if not(done) {
        return Err("expected ')' to close Float bounds")
      }
      return Ok((@schema.TFloat(min_val, max_val), j))
    }
    return Ok((@schema.TFloat(None, None), next))
  }
  if name == "Bool" {
    return Ok((@schema.TBool, next))
  }
  if name == "Url" {
    return Ok((@schema.TUrl, next))
  }
  if name == "Slug" {
    return Ok((@schema.TSlug, next))
  }
  if name == "Array" || name == "Optional" {
    let p = skip_ws_type(s, next)
    if p >= s.length() || @strutil.char_at(s, p) != '[' {
      return Err("expected '[' after " + name)
    }
    match parse_field_type_at(s, p + 1) {
      Err(e) => return Err(e)
      Ok((inner, after_inner)) => {
        let q = skip_ws_type(s, after_inner)
        if q >= s.length() || @strutil.char_at(s, q) != ']' {
          return Err("expected ']' after " + name + " inner type")
        }
        if name == "Array" {
          return Ok((@schema.TArray(inner), q + 1))
        }
        return Ok((@schema.TOptional(inner), q + 1))
      }
    }
  }
  if name == "Enum" {
    let p = skip_ws_type(s, next)
    match parse_string_array_at(s, p) {
      Err(e) => return Err(e)
      Ok((allowed, after_enum)) =>
        return Ok((@schema.TEnum(allowed), after_enum))
    }
  }
  if name == "Ref" {
    let p = skip_ws_type(s, next)
    if p >= s.length() || @strutil.char_at(s, p) != '[' {
      // Ref without collection constraint — matches any slug
      return Ok((@schema.TRef(None), next))
    }
    // Ref[collection-name] — parse the collection name inside brackets
    let mut j = p + 1
    while j < s.length() {
      let c = @strutil.char_at(s, j)
      if c == ']' {
        let coll_name = @strutil.trim(@strutil.substr(s, p + 1, j))
        if coll_name.length() == 0 {
          return Err("expected collection name inside Ref[]")
        }
        return Ok((@schema.TRef(Some(coll_name)), j + 1))
      }
      j = j + 1
    }
    return Err("expected ']' after Ref collection name")
  }
  Err("unknown field type: " + name)
}

///|
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

///|
fn parse_schema_fields(
  collection_name : String,
  schema_text : String,
) -> Result[Array[@schema.FieldDef], CollectionsError] {
  let fields : Array[@schema.FieldDef] = []
  let n = schema_text.length()
  let mut seg_start = 0
  let mut depth = 0
  let mut i = 0
  while i <= n {
    let at_end = i == n
    let c = if at_end { ',' } else { @strutil.char_at(schema_text, i) }
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
    if not(at_end) && c == '(' {
      depth = depth + 1
      i = i + 1
      continue
    }
    if not(at_end) && c == ')' {
      if depth > 0 {
        depth = depth - 1
      }
      i = i + 1
      continue
    }
    if c == ',' && depth == 0 {
      let entry = @strutil.trim(@strutil.substr(schema_text, seg_start, i))
      if entry.length() > 0 {
        let mut colon = -1
        let mut j = 0
        while j < entry.length() {
          if @strutil.char_at(entry, j) == ':' {
            colon = j
            break
          }
          j = j + 1
        }
        if colon <= 0 || colon >= entry.length() - 1 {
          return Err(
            InvalidSchema(
              collection_name,
              "invalid field declaration: " + entry,
            ),
          )
        }

        let field_name = @strutil.trim(@strutil.substr(entry, 0, colon))
        if not(is_valid_field_name(field_name)) {
          return Err(
            InvalidSchema(collection_name, "invalid field name: " + field_name),
          )
        }
        let type_text = @strutil.trim(
          @strutil.substr(entry, colon + 1, entry.length()),
        )
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
    return Err(
      InvalidSchema(collection_name, "schema must define at least one field"),
    )
  }
  Ok(fields)
}

///|
fn parse_value_literal(
  line_no : Int,
  raw : String,
) -> Result[String, CollectionsError] {
  let value = @strutil.trim(raw)
  if value.length() == 0 {
    return Err(InvalidLine(line_no, "empty value"))
  }
  if @strutil.char_at(value, 0) == '"' {
    if value.length() < 2 || @strutil.char_at(value, value.length() - 1) != '"' {
      return Err(InvalidLine(line_no, "unterminated quoted string"))
    }
    Ok(@strutil.substr(value, 1, value.length() - 1))
  } else {
    Ok(value)
  }
}

///|
fn parse_required_keys_data(s : String) -> Array[String] {
  let keys : Array[String] = []
  let mut start = 0
  let mut i = 0
  while i <= s.length() {
    if i == s.length() || @strutil.char_at(s, i) == ',' {
      let key = @strutil.trim(@strutil.substr(s, start, i))
      if key.length() > 0 {
        keys.push(key)
      }
      start = i + 1
    }
    i = i + 1
  }
  keys
}

///|
fn parse_positive_int_collections(value : String) -> Int? {
  if value.length() == 0 {
    return None
  }
  let mut parsed = 0
  let mut i = 0
  while i < value.length() {
    let c = @strutil.char_at(value, i)
    if c < '0' || c > '9' {
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
fn finalize_collection(
  defs : Array[CollectionDef],
  seen : Map[String, Bool],
  name : String,
  schema_text : String?,
  dir_text : String?,
  template_text : String?,
  page_size : Int?,
  sort_order : SortOrder,
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
  defs.push({
    name,
    schema,
    content_dir: dir_value,
    template: template_text,
    page_size,
    sort_order,
  })
  seen.set(name, true)
  Ok(())
}

///|
fn finalize_data_schema(
  schemas : Map[String, DataSchemaDef],
  schema_list : Array[DataSchemaDef],
  seen : Map[String, Bool],
  name : String,
  required : String?,
) -> Result[Unit, CollectionsError] {
  if seen.get(name) != None {
    return Err(DuplicateDataSchema(name))
  }
  let required_text = match required {
    Some(v) => v
    None => return Err(MissingRequiredField("data." + name, "required"))
  }
  let required_keys = parse_required_keys_data(required_text)
  let schema = { name, required_keys }
  schemas.set(name, schema)
  schema_list.push(schema)
  seen.set(name, true)
  Ok(())
}

///|
/// Parse collections config text into typed collection + data definitions.
pub fn parse(input : String) -> Result[CollectionsConfig, CollectionsError] {
  let lines = split_lines_collections(input)
  let defs : Array[CollectionDef] = []
  let seen_collections : Map[String, Bool] = Map::new()
  let data_schemas : Map[String, DataSchemaDef] = Map::new()
  let data_schema_list : Array[DataSchemaDef] = []
  let seen_data : Map[String, Bool] = Map::new()

  let mut current_section : SectionKind? = None
  let mut current_schema : String? = None
  let mut current_dir : String? = None
  let mut current_template : String? = None
  let mut current_page_size : Int? = None
  let mut current_sort_order : SortOrder = DateDesc
  let mut current_required : String? = None

  let mut i = 0
  while i < lines.length() {
    let line_no = i + 1
    let raw = @strutil.trim(lines[i])
    if raw.length() == 0 || @strutil.char_at(raw, 0) == '#' {
      i = i + 1
      continue
    }

    if @strutil.char_at(raw, 0) == '[' {
      match current_section {
        Some(CollectionSection(name)) =>
          match
            finalize_collection(
              defs, seen_collections, name, current_schema, current_dir, current_template,
              current_page_size, current_sort_order,
            ) {
            Err(e) => return Err(e)
            Ok(_) => ()
          }
        Some(DataSection(name)) =>
          match
            finalize_data_schema(
              data_schemas, data_schema_list, seen_data, name, current_required,
            ) {
            Err(e) => return Err(e)
            Ok(_) => ()
          }
        None => ()
      }
      current_schema = None
      current_dir = None
      current_template = None
      current_page_size = None
      current_sort_order = DateDesc
      current_required = None
      match parse_section_header(raw, line_no) {
        Ok(section) => current_section = Some(section)
        Err(e) => return Err(e)
      }
      i = i + 1
      continue
    }

    let section = match current_section {
      Some(v) => v
      None => return Err(InvalidLine(line_no, "assignment outside section"))
    }

    let mut eq = -1
    let mut j = 0
    while j < raw.length() {
      if @strutil.char_at(raw, j) == '=' {
        eq = j
        break
      }
      j = j + 1
    }
    if eq <= 0 || eq >= raw.length() - 1 {
      return Err(InvalidLine(line_no, "expected key=value"))
    }

    let key = @strutil.trim(@strutil.substr(raw, 0, eq))
    let raw_value = @strutil.substr(raw, eq + 1, raw.length())
    let value = match parse_value_literal(line_no, raw_value) {
      Ok(v) => v
      Err(e) => return Err(e)
    }

    match section {
      CollectionSection(name) =>
        if key == "schema" {
          current_schema = Some(value)
        } else if key == "dir" {
          current_dir = Some(value)
        } else if key == "template" {
          current_template = Some(value)
        } else if key == "page_size" {
          match parse_positive_int_collections(value) {
            Some(parsed) => current_page_size = Some(parsed)
            None =>
              return Err(
                InvalidLine(line_no, "page_size must be a positive integer"),
              )
          }
        } else if key == "sort" {
          match parse_sort_order(value) {
            Some(order) => current_sort_order = order
            None =>
              return Err(
                InvalidLine(
                  line_no,
                  "invalid sort value: '" +
                  value +
                  "' (expected: date:desc, date:asc, title:asc, title:desc)",
                ),
              )
          }
        } else {
          return Err(
            InvalidLine(
              line_no,
              "unknown key in section '" + name + "': " + key,
            ),
          )
        }
      DataSection(name) =>
        if key == "required" {
          current_required = Some(value)
        } else {
          return Err(
            InvalidLine(
              line_no,
              "unknown key in section 'data." + name + "': " + key,
            ),
          )
        }
    }

    i = i + 1
  }

  match current_section {
    Some(CollectionSection(name)) =>
      match
        finalize_collection(
          defs, seen_collections, name, current_schema, current_dir, current_template,
          current_page_size, current_sort_order,
        ) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    Some(DataSection(name)) =>
      match
        finalize_data_schema(
          data_schemas, data_schema_list, seen_data, name, current_required,
        ) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    None => ()
  }

  if defs.length() == 0 {
    return Err(EmptyConfig)
  }

  Ok({ definitions: defs, data_schemas, data_schema_list })
}

///|
/// Parse sort order from config string (e.g., "date:desc").
/// Returns None for invalid values.
fn parse_sort_order(value : String) -> SortOrder? {
  if value == "date:desc" {
    Some(DateDesc)
  } else if value == "date:asc" {
    Some(DateAsc)
  } else if value == "title:asc" {
    Some(TitleAsc)
  } else if value == "title:desc" {
    Some(TitleDesc)
  } else {
    None
  }
}

///|
/// Default fallback collection used when no collections config is provided.
pub fn default_posts_collection(content_dir : String) -> CollectionDef {
  {
    name: "posts",
    schema: {
      name: "posts",
      fields: [
        {
          name: "title",
          field_type: @schema.TString(None, None),
          required: true,
        },
        { name: "date", field_type: @schema.TDate(None, None), required: true },
        {
          name: "description",
          field_type: @schema.TOptional(@schema.TString(None, None)),
          required: false,
        },
        {
          name: "tags",
          field_type: @schema.TOptional(
            @schema.TArray(@schema.TString(None, None)),
          ),
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
    template: None,
    page_size: None,
    sort_order: DateDesc,
  }
}

///|
/// Parse a schema string (e.g., "title:String,date:Date") into a Schema struct.
/// Used for parsing inline collection schemas from config.
pub fn parse_schema_string(
  collection_name : String,
  schema_text : String,
) -> Result[@schema.Schema, CollectionsError] {
  let fields = match parse_schema_fields(collection_name, schema_text) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  Ok({ name: collection_name, fields })
}
