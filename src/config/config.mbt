///|
/// Typed site configuration parser for lattice.
///
/// Config format:
/// - One `key=value` pair per line.
/// - Lines beginning with `#` are comments.
/// - Unknown keys are ignored.
pub struct SiteConfig {
  title : String
  base_url : String
  output_dir : String?
  page_size : Int?
  description : String?
  collections_file : String?
  templates_dir : String?
  tags_field : String?
  search_index_file : String?
  static_dir : String?
  data_dir : String?
  root_page : String?
}

///|
pub enum ConfigError {
  InvalidLine(Int, String)
  MissingRequiredField(String)
  InvalidValue(String, String)
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
/// - `collections_file`
/// - `templates_dir`
/// - `tags_field`
/// - `search_index_file`
/// - `static_dir`
/// - `data_dir`
/// - `root_page`
pub fn parse(input : String) -> Result[SiteConfig, ConfigError] {
  let mut title : String? = None
  let mut base_url : String? = None
  let mut output_dir : String? = None
  let mut page_size : Int? = None
  let mut description : String? = None
  let mut collections_file : String? = None
  let mut templates_dir : String? = None
  let mut tags_field : String? = None
  let mut search_index_file : String? = None
  let mut static_dir : String? = None
  let mut data_dir : String? = None
  let mut root_page : String? = None

  let lines = split_lines_config(input)
  let mut i = 0
  while i < lines.length() {
    let line_no = i + 1
    let raw = trim_config(lines[i])
    if raw.length() == 0 || char_at_config(raw, 0) == '#' {
      i = i + 1
      continue
    }

    match parse_assignment(raw, line_no) {
      Err(e) => return Err(e)
      Ok((key, value)) => {
        let string_value = parse_string_value_config(value)
        if key == "title" {
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
        } else {
          // Unknown keys are ignored.
          ()
        }
      }
    }
    i = i + 1
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
    collections_file,
    templates_dir,
    tags_field,
    search_index_file,
    static_dir,
    data_dir,
    root_page,
  })
}
