///|
test "template render with data" {
  let store = @data.new_store([
    @data.new_string_file("nav", [("title", "Demo")]),
  ])

  let tpl = match parse_template("<h1>{{data.nav.title}}</h1>") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [] }
    }
  }
  let slots : Map[TemplateSlot, String] = Map::new()
  match render_template_with_data(tpl, slots, store) {
    Ok(html) => assert_true(html.contains("<h1>Demo</h1>"))
    Err(_) => assert_true(false)
  }
}

///|
test "template missing data" {
  let tpl = match parse_template("{{data.nav.title}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [] }
    }
  }
  let slots : Map[TemplateSlot, String] = Map::new()
  match render_template_with_data(tpl, slots, @data.empty_store()) {
    Ok(_) => assert_true(false)
    Err(MissingDataSlot(path)) => assert_eq(path, "data.nav.title")
    Err(_) => assert_true(false)
  }
}

///|
test "template empty string" {
  match parse_template("") {
    Ok(tpl) => {
      assert_eq(tpl.parts.length(), 0)
      assert_eq(tpl.required_slots.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "template only text no slots" {
  match parse_template("<html><body>Hello World</body></html>") {
    Ok(tpl) => {
      assert_eq(tpl.parts.length(), 1)
      match tpl.parts[0] {
        Text(s) => assert_eq(s, "<html><body>Hello World</body></html>")
        _ => assert_true(false)
      }
      assert_eq(tpl.required_slots.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "template parse unknown slot error" {
  match parse_template("{{unknown_slot}}") {
    Ok(_) => assert_true(false)
    Err(UnknownSlot(name)) => assert_eq(name, "unknown_slot")
    Err(_) => assert_true(false)
  }
}

///|
test "template empty slot name error" {
  match parse_template("{{}}") {
    Ok(_) => assert_true(false)
    Err(ParseError(msg)) => assert_eq(msg, "empty template slot")
    Err(_) => assert_true(false)
  }
}

///|
test "template unterminated slot error" {
  match parse_template("{{title") {
    Ok(_) => assert_true(false)
    Err(ParseError(msg)) => assert_eq(msg, "unterminated template slot")
    Err(_) => assert_true(false)
  }
}

///|
test "template unexpected closing delimiter error" {
  match parse_template("text}}") {
    Ok(_) => assert_true(false)
    Err(ParseError(msg)) => assert_eq(msg, "unexpected '}}'")
    Err(_) => assert_true(false)
  }
}

///|
test "template missing required slot at render" {
  let tpl = match parse_template("{{title}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [] }
    }
  }
  let slots : Map[TemplateSlot, String] = Map::new()
  match render_template(tpl, slots) {
    Ok(_) => assert_true(false)
    Err(MissingRequiredSlot(Title)) => ()
    Err(_) => assert_true(false)
  }
}

///|
test "template multiple data slots" {
  let store = @data.new_store([
    @data.new_string_file("site", [
      ("name", "My Blog"),
      ("url", "https://example.com"),
    ]),
    @data.new_string_file("author", [("name", "John Doe")]),
  ])

  let tpl = match
    parse_template(
      "<h1>{{data.site.name}}</h1><p>{{data.author.name}}</p><a href=\"{{data.site.url}}\">Link</a>",
    ) {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [] }
    }
  }
  let slots : Map[TemplateSlot, String] = Map::new()
  match render_template_with_data(tpl, slots, store) {
    Ok(html) => {
      assert_true(html.contains("<h1>My Blog</h1>"))
      assert_true(html.contains("<p>John Doe</p>"))
      assert_true(html.contains("https://example.com"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "template nested data path" {
  let store = @data.new_store([
    @data.new_string_file("config", [("theme", "dark")]),
  ])

  let tpl = match parse_template("Theme: {{data.config.theme}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [] }
    }
  }
  let slots : Map[TemplateSlot, String] = Map::new()
  match render_template_with_data(tpl, slots, store) {
    Ok(html) => assert_eq(html, "Theme: dark")
    Err(_) => assert_true(false)
  }
}

///|
test "template mixed data and standard slots" {
  let store = @data.new_store([
    @data.new_string_file("site", [("tagline", "Build fast")]),
  ])

  let tpl = match
    parse_template(
      "<title>{{title}} - {{data.site.tagline}}</title><h1>{{title}}</h1>",
    ) {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [] }
    }
  }
  let slots : Map[TemplateSlot, String] = Map::new()
  slots.set(Title, "My Site")
  match render_template_with_data(tpl, slots, store) {
    Ok(html) => {
      assert_true(html.contains("<title>My Site - Build fast</title>"))
      assert_true(html.contains("<h1>My Site</h1>"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "template invalid data slot format error" {
  // Missing 'data.' prefix
  match parse_template("{{site.title}}") {
    Ok(_) => assert_true(false)
    Err(ParseError(msg)) => assert_true(msg.contains("invalid data slot"))
    Err(_) => assert_true(false)
  }

  // Only 'data.' prefix without file name
  match parse_template("{{data.}}") {
    Ok(_) => assert_true(false)
    Err(ParseError(msg)) => assert_true(msg.contains("invalid data slot"))
    Err(_) => assert_true(false)
  }
}

///|
test "template parse new pagination slots" {
  // Next/Prev page links
  let tpl_next = match parse_template("{{next_page}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [] }
    }
  }
  match tpl_next.parts[0] {
    Slot(NextPage) => ()
    _ => assert_true(false)
  }

  let tpl_prev = match parse_template("{{prev_page}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [] }
    }
  }
  match tpl_prev.parts[0] {
    Slot(PrevPage) => ()
    _ => assert_true(false)
  }

  // Page number and flags
  let tpl_page = match parse_template("Page {{page_num}} of 5") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [] }
    }
  }
  match tpl_page.parts {
    [Text("Page "), Slot(PageNum), Text(" of 5")] => ()
    _ => assert_true(false)
  }

  let tpl_first = match parse_template("{{is_first_page}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [] }
    }
  }
  match tpl_first.parts[0] {
    Slot(IsFirstPage) => ()
    _ => assert_true(false)
  }

  let tpl_last = match parse_template("{{is_last_page}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [] }
    }
  }
  match tpl_last.parts[0] {
    Slot(IsLastPage) => ()
    _ => assert_true(false)
  }

  let tpl_page_url = match parse_template("{{page_url}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [] }
    }
  }
  match tpl_page_url.parts[0] {
    Slot(PageUrl) => ()
    _ => assert_true(false)
  }
}

///|
test "template parse date component slots" {
  let tpl = match parse_template("{{year}}-{{month}}-{{day}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [] }
    }
  }
  match tpl.parts {
    [Slot(Year), Text("-"), Slot(Month), Text("-"), Slot(Day)] => ()
    _ => assert_true(false)
  }
}

///|
test "template parse content metadata slots" {
  let tpl = match parse_template("<h1>{{title}}</h1><p>{{collection}}</p><div>{{body}}</div><ul>{{tags}}</ul>") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [] }
    }
  }
  
  let mut has_title = false
  let mut has_collection = false
  let mut has_body = false
  let mut has_tags = false
  for part in tpl.parts {
    match part {
      Slot(Title) => has_title = true
      Slot(Collection) => has_collection = true
      Slot(Body) => has_body = true
      Slot(Tags) => has_tags = true
      _ => ()
    }
  }
  
  assert_true(has_title)
  assert_true(has_collection)
  assert_true(has_body)
  assert_true(has_tags)
}

///|
test "template render missing new slot" {
  let tpl = match parse_template("{{tags}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [] }
    }
  }
  let slots : Map[TemplateSlot, String] = Map::new()
  match render_template(tpl, slots) {
    Ok(_) => assert_true(false)
    Err(MissingRequiredSlot(Tags)) => ()
    Err(_) => assert_true(false)
  }
}
