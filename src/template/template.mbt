pub(all) enum TemplateSlot {
  Title
  Content
  Date
  Description
  Url
  SiteName
  NavLinks
  CustomCss
  TagName
  TagCount
} derive(Eq, Hash, Show)

pub(all) enum TemplatePart {
  Text(String)
  Slot(TemplateSlot)
  DataSlot(String, Array[String]) // file name, key path
}

pub(all) struct Template {
  parts : Array[TemplatePart]
  required_slots : Array[TemplateSlot]
}

pub enum TemplateError {
  UnknownSlot(String)
  MissingRequiredSlot(TemplateSlot)
  MissingDataSlot(String)
  ParseError(String)
}

fn char_at_template(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

fn substr_template(s : String, start : Int, end_pos : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = start
  while i < end_pos {
    buf.write_char(char_at_template(s, i))
    i = i + 1
  }
  buf.to_string()
}

fn is_ws_template(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

fn trim_template(s : String) -> String {
  let n = s.length()
  if n == 0 {
    return s
  }
  let mut lo = 0
  while lo < n && is_ws_template(char_at_template(s, lo)) {
    lo = lo + 1
  }
  let mut hi = n
  while hi > lo && is_ws_template(char_at_template(s, hi - 1)) {
    hi = hi - 1
  }
  substr_template(s, lo, hi)
}

fn starts_with_template(s : String, prefix : String) -> Bool {
  if prefix.length() > s.length() {
    return false
  }
  let mut i = 0
  while i < prefix.length() {
    if char_at_template(s, i) != char_at_template(prefix, i) {
      return false
    }
    i = i + 1
  }
  true
}

fn split_dot_template(s : String) -> Array[String] {
  let parts : Array[String] = []
  let mut start = 0
  let mut i = 0
  while i <= s.length() {
    if i == s.length() || char_at_template(s, i) == '.' {
      let part = trim_template(substr_template(s, start, i))
      if part.length() > 0 {
        parts.push(part)
      }
      start = i + 1
    }
    i = i + 1
  }
  parts
}

fn slot_from_name(name : String) -> Result[TemplateSlot, TemplateError] {
  if name == "title" {
    return Ok(Title)
  }
  if name == "content" {
    return Ok(Content)
  }
  if name == "date" {
    return Ok(Date)
  }
  if name == "description" {
    return Ok(Description)
  }
  if name == "url" {
    return Ok(Url)
  }
  if name == "site_name" {
    return Ok(SiteName)
  }
  if name == "nav_links" {
    return Ok(NavLinks)
  }
  if name == "custom_css" {
    return Ok(CustomCss)
  }
  if name == "tag_name" {
    return Ok(TagName)
  }
  if name == "tag_count" {
    return Ok(TagCount)
  }
  Err(UnknownSlot(name))
}

fn parse_data_slot_name(name : String) -> Result[(String, Array[String]), TemplateError] {
  let parts = split_dot_template(name)
  if parts.length() < 3 || parts[0] != "data" {
    return Err(ParseError("invalid data slot '" + name + "'"))
  }
  let file = parts[1]
  let keys : Array[String] = []
  let mut i = 2
  while i < parts.length() {
    keys.push(parts[i])
    i = i + 1
  }
  if file.length() == 0 || keys.length() == 0 {
    return Err(ParseError("invalid data slot '" + name + "'"))
  }
  Ok((file, keys))
}

///|
/// Parse an HTML template with `{{slot_name}}` placeholders.
pub fn parse_template(input : String) -> Result[Template, TemplateError] {
  let parts : Array[TemplatePart] = []
  let required_slots : Array[TemplateSlot] = []

  let n = input.length()
  let mut i = 0
  let mut text_start = 0
  while i < n {
    let c = char_at_template(input, i)
    if c == '{' && i + 1 < n && char_at_template(input, i + 1) == '{' {
      if i > text_start {
        parts.push(Text(substr_template(input, text_start, i)))
      }
      let mut j = i + 2
      let mut close = -1
      while j + 1 < n {
        if char_at_template(input, j) == '}' && char_at_template(input, j + 1) == '}' {
          close = j
          break
        }
        j = j + 1
      }
      if close < 0 {
        return Err(ParseError("unterminated template slot"))
      }
      let raw_name = substr_template(input, i + 2, close)
      let slot_name = trim_template(raw_name)
      if slot_name.length() == 0 {
        return Err(ParseError("empty template slot"))
      }
      if starts_with_template(slot_name, "data.") {
        match parse_data_slot_name(slot_name) {
          Ok((file, key_path)) => parts.push(DataSlot(file, key_path))
          Err(e) => return Err(e)
        }
      } else {
        let slot = match slot_from_name(slot_name) {
          Ok(s) => s
          Err(e) => return Err(e)
        }
        parts.push(Slot(slot))
        if not(required_slots.contains(slot)) {
          required_slots.push(slot)
        }
      }
      i = close + 2
      text_start = i
      continue
    }
    if c == '}' && i + 1 < n && char_at_template(input, i + 1) == '}' {
      return Err(ParseError("unexpected '}}'"))
    }
    i = i + 1
  }
  if text_start < n {
    parts.push(Text(substr_template(input, text_start, n)))
  }
  Ok({ parts, required_slots })
}

fn render_parts(
  template : Template,
  slots : Map[TemplateSlot, String],
  data_store : @data.DataStore?
) -> Result[String, TemplateError] {
  let mut i = 0
  while i < template.required_slots.length() {
    let slot = template.required_slots[i]
    match slots.get(slot) {
      Some(_) => ()
      None => return Err(MissingRequiredSlot(slot))
    }
    i = i + 1
  }

  let out = StringBuilder::new()
  i = 0
  while i < template.parts.length() {
    match template.parts[i] {
      Text(t) => out.write_string(t)
      Slot(slot) => match slots.get(slot) {
        Some(value) => out.write_string(value)
        None => return Err(MissingRequiredSlot(slot))
      }
      DataSlot(file, key_path) => {
        match data_store {
          Some(store) => {
            match @data.resolve_string(store, file, key_path) {
              Ok(value) => out.write_string(value)
              Err(_) => {
                let path = StringBuilder::new()
                path.write_string("data.")
                path.write_string(file)
                let mut j = 0
                while j < key_path.length() {
                  path.write_char('.')
                  path.write_string(key_path[j])
                  j = j + 1
                }
                return Err(MissingDataSlot(path.to_string()))
              }
            }
          }
          None => {
            let path = StringBuilder::new()
            path.write_string("data.")
            path.write_string(file)
            let mut j = 0
            while j < key_path.length() {
              path.write_char('.')
              path.write_string(key_path[j])
              j = j + 1
            }
            return Err(MissingDataSlot(path.to_string()))
          }
        }
      }
    }
    i = i + 1
  }
  Ok(out.to_string())
}

///|
/// Render a parsed template by substituting non-data slots.
pub fn render_template(
  template : Template,
  slots : Map[TemplateSlot, String]
) -> Result[String, TemplateError] {
  render_parts(template, slots, None)
}

///|
/// Render a parsed template with both standard slots and data slots.
pub fn render_template_with_data(
  template : Template,
  slots : Map[TemplateSlot, String],
  data_store : @data.DataStore
) -> Result[String, TemplateError] {
  render_parts(template, slots, Some(data_store))
}
