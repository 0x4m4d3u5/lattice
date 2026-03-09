pub(all) enum TemplateSlot {
  Title
  Content
  Date
  Description
  Url
  SiteName
  NavLinks
  CustomCss
} derive(Eq, Hash, Show)

pub(all) enum TemplatePart {
  Text(String)
  Slot(TemplateSlot)
}

pub(all) struct Template {
  parts : Array[TemplatePart]
  required_slots : Array[TemplateSlot]
}

pub enum TemplateError {
  UnknownSlot(String)
  MissingRequiredSlot(TemplateSlot)
  ParseError(String)
}

fn char_at_template(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

fn substr_template(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = start
  while i < end {
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
  Err(UnknownSlot(name))
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
      let slot = match slot_from_name(slot_name) {
        Ok(s) => s
        Err(e) => return Err(e)
      }
      parts.push(Slot(slot))
      if not(required_slots.contains(slot)) {
        required_slots.push(slot)
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

///|
/// Render a parsed template by substituting all required slots.
pub fn render_template(
  template : Template,
  slots : Map[TemplateSlot, String]
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
    }
    i = i + 1
  }
  Ok(out.to_string())
}
