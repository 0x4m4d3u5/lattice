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
  description : String?
  collections_file : String?
  templates_dir : String?
}

pub enum ConfigError {
  InvalidLine(Int, String)
  MissingRequiredField(String)
  InvalidValue(String, String)
}

fn char_at_config(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

fn substr_config(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = start
  while i < end {
    buf.write_char(char_at_config(s, i))
    i = i + 1
  }
  buf.to_string()
}

fn trim_config(s : String) -> String {
  let n = s.length()
  if n == 0 {
    return s
  }
  let mut lo = 0
  while lo < n &&
    (char_at_config(s, lo) == ' ' ||
      char_at_config(s, lo) == '\t' ||
      char_at_config(s, lo) == '\r') {
    lo = lo + 1
  }
  let mut hi = n
  while hi > lo &&
    (char_at_config(s, hi - 1) == ' ' ||
      char_at_config(s, hi - 1) == '\t' ||
      char_at_config(s, hi - 1) == '\r') {
    hi = hi - 1
  }
  substr_config(s, lo, hi)
}

fn next_newline_config(s : String, from : Int) -> Int {
  let n = s.length()
  let mut i = from
  while i < n && char_at_config(s, i) != '\n' {
    i = i + 1
  }
  i
}

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

fn parse_assignment(line : String, line_no : Int) -> Result[(String, String), ConfigError] {
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
/// Parse config text into a typed `SiteConfig`.
///
/// Required keys:
/// - `title`
/// - `base_url`
///
/// Optional keys:
/// - `output_dir`
/// - `description`
/// - `collections_file`
/// - `templates_dir`
pub fn parse(input : String) -> Result[SiteConfig, ConfigError] {
  let mut title : String? = None
  let mut base_url : String? = None
  let mut output_dir : String? = None
  let mut description : String? = None
  let mut collections_file : String? = None
  let mut templates_dir : String? = None

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
        if key == "title" {
          if value.length() == 0 {
            return Err(InvalidValue("title", "must not be empty"))
          }
          title = Some(value)
        } else if key == "base_url" {
          if value.length() == 0 {
            return Err(InvalidValue("base_url", "must not be empty"))
          }
          base_url = Some(value)
        } else if key == "output_dir" {
          if value.length() == 0 {
            return Err(InvalidValue("output_dir", "must not be empty"))
          }
          output_dir = Some(value)
        } else if key == "description" {
          if value.length() == 0 {
            description = None
          } else {
            description = Some(value)
          }
        } else if key == "collections_file" {
          if value.length() == 0 {
            collections_file = None
          } else {
            collections_file = Some(value)
          }
        } else if key == "templates_dir" {
          if value.length() == 0 {
            templates_dir = None
          } else {
            templates_dir = Some(value)
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
    description,
    collections_file,
    templates_dir,
  })
}
