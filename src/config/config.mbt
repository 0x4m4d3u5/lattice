///|
/// Typed site configuration parser for lattice.
///
/// Config format:
/// - One `key=value` pair per line.
/// - Lines beginning with `#` are comments.
/// - Unknown keys are ignored.
/// - `[[collections]]` array-of-tables for inline collection declarations.
pub(all) struct CollectionEntry {
  name : String
  dir : String
  schema : String?
  template : String?
  page_size : Int?
}

///|
pub struct SiteConfig {
  title : String
  base_url : String
  output_dir : String?
  page_size : Int?
  description : String?
  og_image : String?
  collections_file : String?
  templates_dir : String?
  tags_field : String?
  search_index_file : String?
  static_dir : String?
  data_dir : String?
  root_page : String?
  robots_txt : Bool?
  collections : Array[CollectionEntry]
  feed_limit : Int?
}

///|
pub enum ConfigError {
  InvalidLine(Int, String)
  MissingRequiredField(String)
  InvalidValue(String, String)
  MissingCollectionField(String, String)
}

///|
fn char_at_config(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

///|
fn substr_config(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = start
  while i < end {
    buf.write_char(char_at_config(s, i))
    i = i + 1
  }
  buf.to_string()
}

///|
fn trim_config(s : String) -> String {
  let n = s.length()
  if n == 0 {
    return s
  }
  let mut lo = 0
  while lo < n &&
        (
          char_at_config(s, lo) == ' ' ||
          char_at_config(s, lo) == '\t' ||
          char_at_config(s, lo) == '\r'
        ) {
    lo = lo + 1
  }
  let mut hi = n
  while hi > lo &&
        (
          char_at_config(s, hi - 1) == ' ' ||
          char_at_config(s, hi - 1) == '\t' ||
          char_at_config(s, hi - 1) == '\r'
        ) {
    hi = hi - 1
  }
  substr_config(s, lo, hi)
}

///|
fn next_newline_config(s : String, from : Int) -> Int {
  let n = s.length()
  let mut i = from
  while i < n && char_at_config(s, i) != '\n' {
    i = i + 1
  }
  i
}

///|
fn split_lines_config(s : String) -> Array[String] {
  let lines : Array[String] = []
  let n = s.length()
  let mut i = 0
  while i <= n {
    let end = next_newline_config(s, i)
    lines.push(substr_config(s, i, end))
    if end >= n {
      break
    }
    i = end + 1
  }
  lines
}

///|
fn parse_assignment(
  line : String,
  line_no : Int,
) -> Result[(String, String), ConfigError] {
  let n = line.length()
  let mut eq = -1
  let mut i = 0
  while i < n {
    if char_at_config(line, i) == '=' {
      eq = i
      break
    }
    i = i + 1
  }
  if eq < 0 {
    return Err(InvalidLine(line_no, "expected key=value"))
  }
  let key = trim_config(substr_config(line, 0, eq))
  if key.length() == 0 {
    return Err(InvalidLine(line_no, "empty key"))
  }
  let value = trim_config(substr_config(line, eq + 1, n))
  Ok((key, value))
}

///|
fn parse_positive_int_config(value : String) -> Int? {
  let n = value.length()
  if n == 0 {
    return None
  }
  let mut parsed = 0
  let mut i = 0
  while i < n {
    let c = char_at_config(value, i)
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
fn parse_string_value_config(value : String) -> String {
  let n = value.length()
  if n >= 2 &&
    char_at_config(value, 0) == '"' &&
    char_at_config(value, n - 1) == '"' {
    return substr_config(value, 1, n - 1)
  }
  value
}

///|
fn parse_bool_config(value : String) -> Bool? {
  let v = trim_config(value).to_lower()
  if v == "true" || v == "yes" || v == "1" || v == "on" {
    Some(true)
  } else if v == "false" || v == "no" || v == "0" || v == "off" {
    Some(false)
  } else {
    None
  }
}

///|
/// Parse config text into a typed `SiteConfig`.
///
/// Required keys:
/// - `title`
/// - `base_url`
///
/// Optional keys:
/// - `output_dir`
/// - `page_size`
/// - `description`
/// - `og_image`
/// - `collections_file`
/// - `templates_dir`
/// - `tags_field`
/// - `search_index_file`
/// - `static_dir`
/// - `data_dir`
/// - `root_page`
/// - `robots_txt`
/// - `feed_limit`
///
/// Inline collections via `[[collections]]` array-of-tables:
/// - `name`: required, collection name
/// - `dir`: required, content directory path
/// - `schema`: optional, schema string (e.g., "title:String,date:Date")
/// - `template`: optional, template name
/// - `page_size`: optional, positive integer override for collection pagination
pub fn parse(input : String) -> Result[SiteConfig, ConfigError] {
  let mut title : String? = None
  let mut base_url : String? = None
  let mut output_dir : String? = None
  let mut page_size : Int? = None
  let mut description : String? = None
  let mut og_image : String? = None
  let mut collections_file : String? = None
  let mut templates_dir : String? = None
  let mut tags_field : String? = None
  let mut search_index_file : String? = None
  let mut static_dir : String? = None
  let mut data_dir : String? = None
  let mut root_page : String? = None
  let mut robots_txt : Bool? = None
  let mut feed_limit : Int? = None

  let collections : Array[CollectionEntry] = []
  let mut in_collections_block = false
  let mut current_collection_name : String? = None
  let mut current_collection_dir : String? = None
  let mut current_collection_schema : String? = None
  let mut current_collection_template : String? = None
  let mut current_collection_page_size : Int? = None

  let lines = split_lines_config(input)
  let mut i = 0
  while i < lines.length() {
    let line_no = i + 1
    let raw = trim_config(lines[i])
    if raw.length() == 0 || char_at_config(raw, 0) == '#' {
      i = i + 1
      continue
    }

    // Check for [[collections]] header
    if raw == "[[collections]]" {
      // Finalize previous collection if exists
      if in_collections_block {
        let coll_name = match current_collection_name {
          Some(n) => n
          None => return Err(MissingCollectionField("collections", "name"))
        }
        let coll_dir = match current_collection_dir {
          Some(d) => d
          None => return Err(MissingCollectionField(coll_name, "dir"))
        }
        collections.push({
          name: coll_name,
          dir: coll_dir,
          schema: current_collection_schema,
          template: current_collection_template,
          page_size: current_collection_page_size,
        })
      }
      // Start new collection
      in_collections_block = true
      current_collection_name = None
      current_collection_dir = None
      current_collection_schema = None
      current_collection_template = None
      current_collection_page_size = None
      i = i + 1
      continue
    }

    match parse_assignment(raw, line_no) {
      Err(e) => return Err(e)
      Ok((key, value)) => {
        let string_value = parse_string_value_config(value)

        if in_collections_block {
          // Inside [[collections]] block
          if key == "name" {
            if string_value.length() == 0 {
              return Err(InvalidValue("name", "must not be empty"))
            }
            current_collection_name = Some(string_value)
          } else if key == "dir" {
            if string_value.length() == 0 {
              return Err(InvalidValue("dir", "must not be empty"))
            }
            current_collection_dir = Some(string_value)
          } else if key == "schema" {
            current_collection_schema = Some(string_value)
          } else if key == "template" {
            current_collection_template = Some(string_value)
          } else if key == "page_size" {
            match parse_positive_int_config(value) {
              Some(parsed) => current_collection_page_size = Some(parsed)
              None =>
                return Err(
                  InvalidValue(
                    "collections.page_size", "must be a positive integer",
                  ),
                )
            }
          } else {
            // Unknown keys in collections block are ignored
            ()
          }
          // Top-level keys
        } else if key == "title" {
          if string_value.length() == 0 {
            return Err(InvalidValue("title", "must not be empty"))
          }
          title = Some(string_value)
        } else if key == "base_url" {
          if string_value.length() == 0 {
            return Err(InvalidValue("base_url", "must not be empty"))
          }
          base_url = Some(string_value)
        } else if key == "output_dir" {
          if string_value.length() == 0 {
            return Err(InvalidValue("output_dir", "must not be empty"))
          }
          output_dir = Some(string_value)
        } else if key == "page_size" {
          match parse_positive_int_config(value) {
            Some(parsed) => page_size = Some(parsed)
            None =>
              return Err(
                InvalidValue("page_size", "must be a positive integer"),
              )
          }
        } else if key == "description" {
          if string_value.length() == 0 {
            description = None
          } else {
            description = Some(string_value)
          }
        } else if key == "og_image" {
          if string_value.length() == 0 {
            og_image = None
          } else {
            og_image = Some(string_value)
          }
        } else if key == "collections_file" {
          if string_value.length() == 0 {
            collections_file = None
          } else {
            collections_file = Some(string_value)
          }
        } else if key == "templates_dir" {
          if string_value.length() == 0 {
            templates_dir = None
          } else {
            templates_dir = Some(string_value)
          }
        } else if key == "tags_field" {
          if string_value.length() == 0 {
            tags_field = None
          } else {
            tags_field = Some(string_value)
          }
        } else if key == "search_index_file" {
          if string_value.length() == 0 {
            search_index_file = None
          } else {
            search_index_file = Some(string_value)
          }
        } else if key == "static_dir" {
          if string_value.length() == 0 {
            static_dir = None
          } else {
            static_dir = Some(string_value)
          }
        } else if key == "data_dir" {
          if string_value.length() == 0 {
            data_dir = None
          } else {
            data_dir = Some(string_value)
          }
        } else if key == "root_page" {
          if string_value.length() == 0 {
            root_page = None
          } else {
            root_page = Some(string_value)
          }
        } else if key == "robots_txt" {
          match parse_bool_config(value) {
            Some(parsed) => robots_txt = Some(parsed)
            None =>
              return Err(
                InvalidValue(
                  "robots_txt", "must be true/false, yes/no, 1/0, or on/off",
                ),
              )
          }
        } else if key == "feed_limit" {
          match parse_positive_int_config(value) {
            Some(parsed) => feed_limit = Some(parsed)
            None =>
              return Err(
                InvalidValue("feed_limit", "must be a positive integer"),
              )
          }
        } else {
          // Unknown keys are ignored.
          ()
        }
      }
    }
    i = i + 1
  }

  // Finalize last collection if we were in a block
  if in_collections_block {
    let coll_name = match current_collection_name {
      Some(n) => n
      None => return Err(MissingCollectionField("collections", "name"))
    }
    let coll_dir = match current_collection_dir {
      Some(d) => d
      None => return Err(MissingCollectionField(coll_name, "dir"))
    }
    collections.push({
      name: coll_name,
      dir: coll_dir,
      schema: current_collection_schema,
      template: current_collection_template,
      page_size: current_collection_page_size,
    })
  }

  let title_value = match title {
    Some(v) => v
    None => return Err(MissingRequiredField("title"))
  }
  let base_url_value = match base_url {
    Some(v) => v
    None => return Err(MissingRequiredField("base_url"))
  }

  Ok({
    title: title_value,
    base_url: base_url_value,
    output_dir,
    page_size,
    description,
    og_image,
    collections_file,
    templates_dir,
    tags_field,
    search_index_file,
    static_dir,
    data_dir,
    root_page,
    robots_txt,
    collections,
    feed_limit,
  })
}
