///|
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
  Backlinks
  Tags
  Collection
  Year
  Month
  Day
  PrevPostUrl
  PrevPostTitle
  NextPostUrl
  NextPostTitle
  NextPage
  PrevPage
  PageNum
  IsFirstPage
  IsLastPage
  TotalPages
  PageUrl
  Body
  ReadingTime
  WordCount
  TableOfContents
} derive(Eq, Hash, Show)

///|
pub(all) enum TemplatePart {
  Text(String)
  Slot(TemplateSlot)
  DataSlot(String, Array[String]) // file name, key path
  Include(String) // filename to include, resolved at load time
  Layout(String) // layout filename, resolved at load time
}

///|
pub(all) struct Template {
  parts : Array[TemplatePart]
  required_slots : Array[TemplateSlot]
  layout : Template? // if set, this template's render output feeds into layout's Body slot
}

///|
pub enum TemplateError {
  UnknownSlot(String)
  MissingRequiredSlot(TemplateSlot)
  MissingDataSlot(String)
  ParseError(String)
  CycleError(String)
}

///|
fn char_at_template(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

///|
fn substr_template(s : String, start : Int, end_pos : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = start
  while i < end_pos {
    buf.write_char(char_at_template(s, i))
    i = i + 1
  }
  buf.to_string()
}

///|
fn is_ws_template(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
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

///|
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

///|
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

///|
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
  if name == "backlinks" {
    return Ok(Backlinks)
  }
  if name == "tags" {
    return Ok(Tags)
  }
  if name == "collection" {
    return Ok(Collection)
  }
  if name == "year" {
    return Ok(Year)
  }
  if name == "month" {
    return Ok(Month)
  }
  if name == "day" {
    return Ok(Day)
  }
  if name == "prev_post_url" {
    return Ok(PrevPostUrl)
  }
  if name == "prev_post_title" {
    return Ok(PrevPostTitle)
  }
  if name == "next_post_url" {
    return Ok(NextPostUrl)
  }
  if name == "next_post_title" {
    return Ok(NextPostTitle)
  }
  if name == "next_page" {
    return Ok(NextPage)
  }
  if name == "prev_page" {
    return Ok(PrevPage)
  }
  if name == "page_num" {
    return Ok(PageNum)
  }
  if name == "is_first_page" {
    return Ok(IsFirstPage)
  }
  if name == "is_last_page" {
    return Ok(IsLastPage)
  }
  if name == "total_pages" {
    return Ok(TotalPages)
  }
  if name == "page_url" {
    return Ok(PageUrl)
  }
  if name == "body" {
    return Ok(Body)
  }
  if name == "reading_time" {
    return Ok(ReadingTime)
  }
  if name == "word_count" {
    return Ok(WordCount)
  }
  if name == "table_of_contents" {
    return Ok(TableOfContents)
  }
  Err(UnknownSlot(name))
}

///|
fn parse_data_slot_name(
  name : String,
) -> Result[(String, Array[String]), TemplateError] {
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
        if char_at_template(input, j) == '}' &&
          char_at_template(input, j + 1) == '}' {
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
      if starts_with_template(slot_name, "include:") {
        let filename = trim_template(
          substr_template(slot_name, 8, slot_name.length()),
        )
        if filename.length() == 0 {
          return Err(ParseError("empty include filename"))
        }
        parts.push(Include(filename))
      } else if starts_with_template(slot_name, "layout:") {
        let filename = trim_template(
          substr_template(slot_name, 7, slot_name.length()),
        )
        if filename.length() == 0 {
          return Err(ParseError("empty layout filename"))
        }
        parts.push(Layout(filename))
      } else if starts_with_template(slot_name, "data.") {
        match parse_data_slot_name(slot_name) {
          Ok((file, key_path)) => parts.push(DataSlot(file, key_path))
          Err(e) => return Err(e)
        }
      } else {
        let slot = match slot_from_name(slot_name) {
          Ok(s) => s
          Err(e) => {
            // If the slot name contains dots but doesn't start with "data.",
            // it's likely an attempt to use a data slot without the proper prefix
            if slot_name.contains(".") {
              return Err(ParseError("invalid data slot '" + slot_name + "'"))
            }
            return Err(e)
          }
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
  Ok({ parts, required_slots, layout: None })
}

///|
fn render_parts(
  template : Template,
  slots : Map[TemplateSlot, String],
  data_store : @data.DataStore?,
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
      Slot(slot) =>
        match slots.get(slot) {
          Some(value) => out.write_string(value)
          None => return Err(MissingRequiredSlot(slot))
        }
      DataSlot(file, key_path) =>
        match data_store {
          Some(store) =>
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
      Include(_) =>
        return Err(ParseError("include directive not resolved at render time"))
      Layout(_) =>
        return Err(ParseError("layout directive not resolved at render time"))
    }
    i = i + 1
  }
  Ok(out.to_string())
}

///|
/// Render a parsed template by substituting non-data slots.
pub fn render_template(
  template : Template,
  slots : Map[TemplateSlot, String],
) -> Result[String, TemplateError] {
  // If template has a layout, render child first, then render layout with body
  match template.layout {
    Some(layout) => {
      // Render the child template
      let child_output = match render_parts(template, slots, None) {
        Ok(output) => output
        Err(e) => return Err(e)
      }

      // Add body to slots for layout
      let layout_slots = Map::new()
      for key, value in slots {
        layout_slots.set(key, value)
      }
      layout_slots.set(Body, child_output)

      // Render layout with all slots including body
      render_parts(layout, layout_slots, None)
    }
    None => render_parts(template, slots, None)
  }
}

///|
/// Render a parsed template with both standard slots and data slots.
pub fn render_template_with_data(
  template : Template,
  slots : Map[TemplateSlot, String],
  data_store : @data.DataStore,
) -> Result[String, TemplateError] {
  // If template has a layout, render child first, then render layout with body
  match template.layout {
    Some(layout) => {
      // Render the child template
      let child_output = match render_parts(template, slots, Some(data_store)) {
        Ok(output) => output
        Err(e) => return Err(e)
      }

      // Add body to slots for layout
      let layout_slots = Map::new()
      for key, value in slots {
        layout_slots.set(key, value)
      }
      layout_slots.set(Body, child_output)

      // Render layout with all slots including body
      render_parts(layout, layout_slots, Some(data_store))
    }
    None => render_parts(template, slots, Some(data_store))
  }
}

///|
/// Flatten includes and resolve layouts by parsing with a resolver callback.
///
/// The resolver function takes a filename and returns template source or an error.
/// Includes are resolved recursively at load time, not render time.
/// Layouts are also resolved at load time.
/// Cycles are detected and reported as errors.
pub fn parse_template_with_includes(
  source : String,
  resolver : (String) -> Result[String, String],
) -> Result[Template, TemplateError] {
  // First, parse source to get initial Template
  let base_template = match parse_template(source) {
    Ok(tpl) => tpl
    Err(e) => return Err(e)
  }

  // Track visited files for cycle detection
  let visited : Map[String, Bool] = Map::new()

  // Helper function to flatten includes recursively
  fn flatten_includes(
    parts : Array[TemplatePart],
    resolver : (String) -> Result[String, String],
    visited : Map[String, Bool],
  ) -> Result[Array[TemplatePart], TemplateError] {
    let result : Array[TemplatePart] = []
    let mut i = 0
    while i < parts.length() {
      match parts[i] {
        Text(s) => result.push(Text(s))
        Slot(slot) => result.push(Slot(slot))
        DataSlot(file, keys) => result.push(DataSlot(file, keys))
        Layout(path) => result.push(Layout(path))
        Include(filename) => {
          // Check for cycles
          if visited.contains(filename) {
            return Err(CycleError("include cycle detected: " + filename))
          }

          // Mark as visited
          let new_visited = Map::new()
          new_visited.set(filename, true)
          for key, _ in visited {
            new_visited.set(key, true)
          }

          // Resolve include
          match resolver(filename) {
            Ok(included_source) =>
              // Parse included template
              match parse_template(included_source) {
                Ok(included_template) =>
                  // Recursively flatten its includes
                  match
                    flatten_includes(
                      included_template.parts,
                      resolver,
                      new_visited,
                    ) {
                    Ok(flattened_parts) => {
                      // Splice flattened parts into result
                      let mut j = 0
                      while j < flattened_parts.length() {
                        result.push(flattened_parts[j])
                        j = j + 1
                      }
                    }
                    Err(e) => return Err(e)
                  }
                Err(e) => return Err(e)
              }
            Err(msg) =>
              return Err(
                ParseError("cannot resolve include '" + filename + "': " + msg),
              )
          }
        }
      }
      i = i + 1
    }
    Ok(result)
  }

  // Flatten all includes
  let flattened_parts = match
    flatten_includes(base_template.parts, resolver, visited) {
    Ok(parts) => parts
    Err(e) => return Err(e)
  }

  // Find layout directive in parts (must be first non-whitespace)
  let mut layout_path : String? = None
  let mut layout_idx : Int? = None
  let mut i = 0
  while i < flattened_parts.length() {
    match flattened_parts[i] {
      Layout(path) => {
        layout_path = Some(path)
        layout_idx = Some(i)
        break
      }
      Text(s) => {
        let trimmed = trim_template(s)
        if trimmed.length() > 0 {
          // Found non-whitespace text before layout directive
          break
        }
      }
      _ =>
        // Found slot or data slot before layout directive
        break
    }
    i = i + 1
  }

  // Remove layout directive from parts if found
  let final_parts : Array[TemplatePart] = []
  i = 0
  while i < flattened_parts.length() {
    match layout_idx {
      Some(idx) => if i != idx { final_parts.push(flattened_parts[i]) }
      None => final_parts.push(flattened_parts[i])
    }
    i = i + 1
  }

  // Collect required slots from final parts
  let required_slots : Array[TemplateSlot] = []
  i = 0
  while i < final_parts.length() {
    match final_parts[i] {
      Slot(slot) =>
        if not(required_slots.contains(slot)) {
          required_slots.push(slot)
        }
      _ => ()
    }
    i = i + 1
  }

  // Resolve layout if found
  let resolved_layout : Template? = match layout_path {
    Some(path) =>
      match resolver(path) {
        Ok(layout_source) =>
          // Parse layout template (includes are flattened for layout too)
          match parse_template_with_includes(layout_source, resolver) {
            Ok(layout_tpl) => Some(layout_tpl)
            Err(e) => return Err(e)
          }
        Err(msg) =>
          return Err(ParseError("cannot resolve layout '" + path + "': " + msg))
      }
    None => None
  }

  Ok({ parts: final_parts, required_slots, layout: resolved_layout })
}
