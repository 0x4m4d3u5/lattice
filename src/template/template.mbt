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
  Author
  Excerpt
} derive(Eq, Hash, Show)

///|
pub(all) enum TemplatePart {
  Text(String)
  Slot(TemplateSlot)
  DataSlot(String, Array[String]) // file name, key path
  FrontmatterSlot(String) // {{page.field_name}} — key into validated frontmatter
  Include(String) // filename to include, resolved at load time
  Layout(String) // layout filename, resolved at load time
  ConditionalBlock(TemplateSlot, Array[TemplatePart]) // {{?slot}} body {{/?slot}}
  FrontmatterConditionalBlock(String, Array[TemplatePart]) // {{?page.field}} body {{/?page.field}} — conditional on frontmatter field presence and non-empty value
  DataEachBlock(String, Array[String], Array[TemplatePart]) // {{#each data.file.key.path}} body {{/each}} — loop over data array
  LoopItemSlot(Array[String]) // {{item}} or {{item.field}} inside {{#each}} block
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
  if name == "author" {
    return Ok(Author)
  }
  if name == "excerpt" {
    return Ok(Excerpt)
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
  // Use recursive helper to parse with conditional block support
  match parse_template_recursive(input, 0, input.length()) {
    Ok((parts, end)) => {
      // Verify we consumed all input
      if end != input.length() {
        return Err(ParseError("unexpected content at end of template"))
      }

      // Collect required slots from non-conditional parts only
      let required_slots : Array[TemplateSlot] = []
      let mut i = 0
      while i < parts.length() {
      match parts[i] {
        Slot(slot) =>
          if not(required_slots.contains(slot)) {
            required_slots.push(slot)
          }
        _ => () // ConditionalBlock, DataEachBlock, LoopItemSlot are NOT required
      }
        i = i + 1
      }

      Ok({ parts, required_slots, layout: None })
    }
    Err(e) => Err(e)
  }
}

///|
/// Recursive helper to parse template with conditional block support.
/// Returns (parts, end_position) where end_position is the index after parsing.
fn parse_template_recursive(
  input : String,
  start : Int,
  end : Int,
) -> Result[(Array[TemplatePart], Int), TemplateError] {
  let parts : Array[TemplatePart] = []
  let mut i = start
  let mut text_start = start
  while i < end {
    let c = char_at_template(input, i)
    if c == '{' && i + 1 < end && char_at_template(input, i + 1) == '{' {
      if i > text_start {
        parts.push(Text(substr_template(input, text_start, i)))
      }
      let mut j = i + 2
      let mut close = -1
      while j + 1 < end {
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

      // Check if this is a loop block opening {{#each data.file.key.path}}
      if starts_with_template(slot_name, "#each data.") {
        // Parse each loop block
        let each_name = trim_template(
          substr_template(slot_name, 11, slot_name.length()),
        ) // Remove "#each data." prefix (11 characters: #each data.)
        
        // Parse file name and key path from remaining name
        let each_parts = split_dot_template(each_name)
        if each_parts.length() < 1 {
          return Err(ParseError("invalid each block '" + slot_name + "'"))
        }
        
        let file = each_parts[0]
        let key_path : Array[String] = []
        let mut k = 1
        while k < each_parts.length() {
          key_path.push(each_parts[k])
          k = k + 1
        }
        
        if file.length() == 0 {
          return Err(ParseError("invalid each block '" + slot_name + "'"))
        }
        
        // Parse body until closing tag {{/each}}
        let body_start = close + 2
        let closing_prefix = "{{/each}}"
        let closing_len = closing_prefix.length()
        
        // Find closing tag
        let mut body_end = -1
        let mut k = body_start
        while k <= end - closing_len {
          let mut found = true
          let mut l = 0
          while l < closing_len {
            if char_at_template(input, k + l) != char_at_template(closing_prefix, l) {
              found = false
              break
            }
            l = l + 1
          }
          if found {
            body_end = k
            break
          }
          k = k + 1
        }
        
        if body_end < 0 {
          return Err(
            ParseError("missing closing tag for each block: {{/each}}"),
          )
        }
        
        // Parse body parts recursively (to handle nested loops)
        match parse_template_recursive(input, body_start, body_end) {
          Ok((body_parts, _)) =>
            parts.push(DataEachBlock(file, key_path, body_parts))
          Err(e) => return Err(e)
        }
        
        i = body_end + closing_len
        text_start = i
        continue
      }
      
      // Check if this is a loop item slot {{item}} or {{item.field}}
      if slot_name == "item" || starts_with_template(slot_name, "item.") {
        if starts_with_template(slot_name, "item.") {
          let field = trim_template(
            substr_template(slot_name, 5, slot_name.length()),
          )
          let item_fields = split_dot_template(field)
          parts.push(LoopItemSlot(item_fields))
        } else {
          parts.push(LoopItemSlot([]))
        }
        i = close + 2
        text_start = i
        continue
      }
      
      // Check if this is a conditional block opening {{?slot}}
      if char_at_template(slot_name, 0) == '?' {
        // Parse conditional block
        let cond_slot_name = trim_template(
          substr_template(slot_name, 1, slot_name.length()),
        )

        // Check if this is a page.field conditional
        if starts_with_template(cond_slot_name, "page.") {
          let field = trim_template(
            substr_template(cond_slot_name, 5, cond_slot_name.length()),
          )
          if field.length() == 0 {
            return Err(
              ParseError("invalid page conditional slot '" + slot_name + "'"),
            )
          }

          // Parse body until closing tag {{/?page.field}}
          let body_start = close + 2
          let closing_prefix = "{{/?" + cond_slot_name + "}}"
          let closing_len = closing_prefix.length()

          // Find closing tag
          let mut body_end = -1
          let mut k = body_start
          while k <= end - closing_len {
            let mut found = true
            let mut l = 0
            while l < closing_len {
              if char_at_template(input, k + l) !=
                char_at_template(closing_prefix, l) {
                found = false
                break
              }
              l = l + 1
            }
            if found {
              body_end = k
              break
            }
            k = k + 1
          }

          if body_end < 0 {
            return Err(
              ParseError(
                "missing closing tag for conditional block: {{/?" +
                cond_slot_name +
                "}}",
              ),
            )
          }

          // Parse body parts recursively (to handle nested conditionals)
          match parse_template_recursive(input, body_start, body_end) {
            Ok((body_parts, _)) =>
              parts.push(FrontmatterConditionalBlock(field, body_parts))
            Err(e) => return Err(e)
          }

          i = body_end + closing_len
          text_start = i
          continue
        }

        let cond_slot = match slot_from_name(cond_slot_name) {
          Ok(s) => s
          Err(e) => return Err(e)
        }

        // Parse body until closing tag {{/?slot_name}}
        let body_start = close + 2
        let closing_prefix = "{{/?" + cond_slot_name + "}}"
        let closing_len = closing_prefix.length()

        // Find closing tag
        let mut body_end = -1
        let mut k = body_start
        while k <= end - closing_len {
          let mut found = true
          let mut l = 0
          while l < closing_len {
            if char_at_template(input, k + l) !=
              char_at_template(closing_prefix, l) {
              found = false
              break
            }
            l = l + 1
          }
          if found {
            body_end = k
            break
          }
          k = k + 1
        }

        if body_end < 0 {
          return Err(
            ParseError(
              "missing closing tag for conditional block: {{/?" +
              cond_slot_name +
              "}}",
            ),
          )
        }

        // Parse body parts recursively (to handle nested conditionals)
        match parse_template_recursive(input, body_start, body_end) {
          Ok((body_parts, _)) =>
            parts.push(ConditionalBlock(cond_slot, body_parts))
          Err(e) => return Err(e)
        }

        i = body_end + closing_len
        text_start = i
        continue
      }

      // Check if this is a closing tag (shouldn't appear here)
      if char_at_template(slot_name, 0) == '/' &&
        char_at_template(slot_name, 1) == '?' {
        return Err(ParseError("unexpected closing tag"))
      }

      // Normal slot, include, layout, or data slot
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
      } else if starts_with_template(slot_name, "page.") {
        let field = trim_template(
          substr_template(slot_name, 5, slot_name.length()),
        )
        if field.length() == 0 {
          return Err(ParseError("invalid page slot '" + slot_name + "'"))
        }
        parts.push(FrontmatterSlot(field))
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
      }
      i = close + 2
      text_start = i
      continue
    }
    if c == '}' && i + 1 < end && char_at_template(input, i + 1) == '}' {
      return Err(ParseError("unexpected '}}'"))
    }
    i = i + 1
  }
  if text_start < end {
    parts.push(Text(substr_template(input, text_start, end)))
  }
  Ok((parts, i))
}

///|
/// Resolve a field path from a loop item value.
/// Returns Some(string) if path can be resolved, None otherwise.
fn resolve_loop_item_field(
  item : @frontmatter.FrontmatterValue,
  field_path : Array[String],
) -> String? {
  if field_path.length() == 0 {
    // {{item}} without field path - convert entire item to string
    return Some(@data.value_to_string(item))
  }
  
  // Navigate through nested maps
  let mut current : @frontmatter.FrontmatterValue? = Some(item)
  let mut idx = 0
  while idx < field_path.length() {
    match current {
      None => return None
      Some(v) =>
        match v {
          @frontmatter.FMap(map) =>
            match map.get(field_path[idx]) {
              Some(next_v) => {
                if idx + 1 == field_path.length() {
                  // Final field reached - convert to string
                  return Some(@data.value_to_string(next_v))
                } else {
                  current = Some(next_v)
                }
              }
              None => return None
            }
          _ => return None // Not a map, can't navigate further
        }
    }
    idx = idx + 1
  }
  
  None
}

///|
fn render_parts(
  template : Template,
  slots : Map[TemplateSlot, String],
  data_store : @data.DataStore?,
  page_fields : Map[String, String],
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
      FrontmatterSlot(field) =>
        match page_fields.get(field) {
          Some(value) => out.write_string(value)
          None => () // Missing frontmatter field renders as empty string
        }
      ConditionalBlock(slot, body_parts) =>
        // Render body only if slot is non-empty
        match slots.get(slot) {
          Some(value) =>
            if value.length() > 0 {
              // Render body parts
              let mut j = 0
              while j < body_parts.length() {
                match body_parts[j] {
                  Text(t) => out.write_string(t)
                  Slot(s) =>
                    match slots.get(s) {
                      Some(v) => out.write_string(v)
                      None => () // Missing slot renders as empty in conditional
                    }
                  DataSlot(file, key_path) =>
                    match data_store {
                      Some(store) =>
                        match @data.resolve_string(store, file, key_path) {
                          Ok(v) => out.write_string(v)
                          Err(_) => () // Missing data slot renders as empty in conditional
                        }
                      None => () // Missing data store renders as empty in conditional
                    }
                  FrontmatterSlot(field) =>
                    match page_fields.get(field) {
                      Some(v) => out.write_string(v)
                      None => () // Missing frontmatter field renders as empty in conditional
                    }
                  FrontmatterConditionalBlock(field, inner_parts) =>
                    // Handle nested frontmatter conditional inside regular conditional
                    match page_fields.get(field) {
                      Some(value) =>
                        if value.length() > 0 {
                          // Render inner parts recursively
                          let mut k = 0
                          while k < inner_parts.length() {
                            match inner_parts[k] {
                              Text(t) => out.write_string(t)
                              Slot(s) =>
                                match slots.get(s) {
                                  Some(v) => out.write_string(v)
                                  None => ()
                                }
                              DataSlot(file, key_path) =>
                                match data_store {
                                  Some(store) =>
                                    match
                                      @data.resolve_string(
                                        store, file, key_path,
                                      ) {
                                      Ok(v) => out.write_string(v)
                                      Err(_) => ()
                                    }
                                  None => ()
                                }
                              FrontmatterSlot(f) =>
                                match page_fields.get(f) {
                                  Some(v) => out.write_string(v)
                                  None => ()
                                }
                              _ =>
                                // Include and Layout should not appear in conditional bodies
                                return Err(
                                  ParseError(
                                    "include/layout not allowed in conditional",
                                  ),
                                )
                            }
                            k = k + 1
                          }
                        }
                      None => ()
                    }
                  _ =>
                    // Include and Layout should not appear in conditional bodies
                    return Err(
                      ParseError("include/layout not allowed in conditional"),
                    )
                }
                j = j + 1
              }
            }
          None => () // Slot not in map, treat as empty
        }
      FrontmatterConditionalBlock(field, body_parts) =>
        // Render body only if frontmatter field is present and non-empty
        match page_fields.get(field) {
          Some(value) =>
            if value.length() > 0 {
              // Render body parts (reuse same logic as ConditionalBlock)
              let mut j = 0
              while j < body_parts.length() {
                match body_parts[j] {
                  Text(t) => out.write_string(t)
                  Slot(s) =>
                    match slots.get(s) {
                      Some(v) => out.write_string(v)
                      None => () // Missing slot renders as empty in conditional
                    }
                  DataSlot(file, key_path) =>
                    match data_store {
                      Some(store) =>
                        match @data.resolve_string(store, file, key_path) {
                          Ok(v) => out.write_string(v)
                          Err(_) => () // Missing data slot renders as empty in conditional
                        }
                      None => () // Missing data store renders as empty in conditional
                    }
                  FrontmatterSlot(f) =>
                    match page_fields.get(f) {
                      Some(v) => out.write_string(v)
                      None => () // Missing frontmatter field renders as empty in conditional
                    }
                  ConditionalBlock(slot, inner_parts) =>
                    // Handle nested regular conditional inside frontmatter conditional
                    match slots.get(slot) {
                      Some(value) =>
                        if value.length() > 0 {
                          // Render inner parts recursively
                          let mut k = 0
                          while k < inner_parts.length() {
                            match inner_parts[k] {
                              Text(t) => out.write_string(t)
                              Slot(s) =>
                                match slots.get(s) {
                                  Some(v) => out.write_string(v)
                                  None => ()
                                }
                              DataSlot(file, key_path) =>
                                match data_store {
                                  Some(store) =>
                                    match
                                      @data.resolve_string(
                                        store, file, key_path,
                                      ) {
                                      Ok(v) => out.write_string(v)
                                      Err(_) => ()
                                    }
                                  None => ()
                                }
                              FrontmatterSlot(f) =>
                                match page_fields.get(f) {
                                  Some(v) => out.write_string(v)
                                  None => ()
                                }
                              _ =>
                                // Include and Layout should not appear in conditional bodies
                                return Err(
                                  ParseError(
                                    "include/layout not allowed in conditional",
                                  ),
                                )
                            }
                            k = k + 1
                          }
                        }
                      None => ()
                    }
                  _ =>
                    // Include and Layout should not appear in conditional bodies
                    return Err(
                      ParseError("include/layout not allowed in conditional"),
                    )
                }
                j = j + 1
              }
            }
          None => () // Frontmatter field not in map, treat as empty
        }
      DataEachBlock(file, key_path, body_parts) =>
        // Render each block - loop over array items
        match data_store {
          Some(store) =>
            match @data.resolve(store, file, key_path) {
              Ok(v) =>
                match v {
                  @frontmatter.FArray(items) => {
                    // For each item in the array, render body with loop item context
                    let mut item_idx = 0
                    while item_idx < items.length() {
                      let item_value = items[item_idx]
                      // Render body parts with loop item context
                      let mut j = 0
                      while j < body_parts.length() {
                        match body_parts[j] {
                          Text(t) => out.write_string(t)
                          Slot(s) =>
                            match slots.get(s) {
                              Some(v) => out.write_string(v)
                              None => ()
                            }
                          DataSlot(df, dk) =>
                            match data_store {
                              Some(store) =>
                                match @data.resolve_string(store, df, dk) {
                                  Ok(v) => out.write_string(v)
                                  Err(_) => ()
                                }
                              None => ()
                            }
                          FrontmatterSlot(f) =>
                            match page_fields.get(f) {
                              Some(v) => out.write_string(v)
                              None => ()
                            }
                          LoopItemSlot(field_path) =>
                            // Resolve field path from current loop item
                            match resolve_loop_item_field(item_value, field_path) {
                              Some(v) => out.write_string(v)
                              None => ()
                            }
                          _ =>
                            // DataEachBlock and other blocks shouldn't appear in loop bodies
                            return Err(ParseError("nested loops not supported"))
                        }
                        j = j + 1
                      }
                      item_idx = item_idx + 1
                    }
                  }
                  _ => () // Not an array, render nothing
                }
              Err(_) => () // Resolution error, render nothing
            }
          None => () // No data store, render nothing
        }
      LoopItemSlot(_) =>
        // LoopItemSlot outside DataEachBlock is treated as empty
        ()
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

///|
/// Render a parsed template by substituting non-data slots.
pub fn render_template(
  template : Template,
  slots : Map[TemplateSlot, String],
  page_fields : Map[String, String],
) -> Result[String, TemplateError] {
  // If template has a layout, render child first, then render layout with body
  match template.layout {
    Some(layout) => {
      // Render the child template
      let child_output = match
        render_parts(template, slots, None, page_fields) {
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
      render_parts(layout, layout_slots, None, page_fields)
    }
    None => render_parts(template, slots, None, page_fields)
  }
}

///|
/// Render a parsed template with both standard slots and data slots.
pub fn render_template_with_data(
  template : Template,
  slots : Map[TemplateSlot, String],
  data_store : @data.DataStore,
  page_fields : Map[String, String],
) -> Result[String, TemplateError] {
  // If template has a layout, render child first, then render layout with body
  match template.layout {
    Some(layout) => {
      // Render the child template
      let child_output = match
        render_parts(template, slots, Some(data_store), page_fields) {
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
      render_parts(layout, layout_slots, Some(data_store), page_fields)
    }
    None => render_parts(template, slots, Some(data_store), page_fields)
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
        FrontmatterSlot(field) => result.push(FrontmatterSlot(field))
        Layout(path) => result.push(Layout(path))
        ConditionalBlock(slot, body_parts) =>
          // Recursively flatten body parts
          match flatten_includes(body_parts, resolver, visited) {
            Ok(flattened_body) =>
              result.push(ConditionalBlock(slot, flattened_body))
            Err(e) => return Err(e)
          }
        FrontmatterConditionalBlock(field, body_parts) =>
          // Recursively flatten body parts
          match flatten_includes(body_parts, resolver, visited) {
            Ok(flattened_body) =>
              result.push(FrontmatterConditionalBlock(field, flattened_body))
            Err(e) => return Err(e)
          }
        DataEachBlock(file, key_path, body_parts) =>
          // Recursively flatten body parts
          match flatten_includes(body_parts, resolver, visited) {
            Ok(flattened_body) =>
              result.push(DataEachBlock(file, key_path, flattened_body))
            Err(e) => return Err(e)
          }
        LoopItemSlot(field_path) => result.push(LoopItemSlot(field_path))
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
      _ => () // ConditionalBlock slots are NOT required
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
