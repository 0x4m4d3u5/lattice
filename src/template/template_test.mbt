///|
test "template render with data" {
  let store = @data.new_store([
    @data.new_string_file("nav", [("title", "Demo")]),
  ])

  let tpl = match parse_template("<h1>{{data.nav.title}}</h1>") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
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
      { parts: [], required_slots: [], layout: None }
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
      { parts: [], required_slots: [], layout: None }
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
      { parts: [], required_slots: [], layout: None }
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
      { parts: [], required_slots: [], layout: None }
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
      { parts: [], required_slots: [], layout: None }
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
      { parts: [], required_slots: [], layout: None }
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
      { parts: [], required_slots: [], layout: None }
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
      { parts: [], required_slots: [], layout: None }
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
      { parts: [], required_slots: [], layout: None }
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
      { parts: [], required_slots: [], layout: None }
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
      { parts: [], required_slots: [], layout: None }
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
      { parts: [], required_slots: [], layout: None }
    }
  }
  match tpl.parts {
    [Slot(Year), Text("-"), Slot(Month), Text("-"), Slot(Day)] => ()
    _ => assert_true(false)
  }
}

///|
test "template parse content metadata slots" {
  let tpl = match
    parse_template(
      "<h1>{{title}}</h1><p>{{collection}}</p><div>{{body}}</div><ul>{{tags}}</ul>",
    ) {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
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
      { parts: [], required_slots: [], layout: None }
    }
  }
  let slots : Map[TemplateSlot, String] = Map::new()
  match render_template(tpl, slots) {
    Ok(_) => assert_true(false)
    Err(MissingRequiredSlot(Tags)) => ()
    Err(_) => assert_true(false)
  }
}
//   }
// }

///|
test "template include cycle detection" {
  // Mock resolver that creates a cycle
  let resolver = fn(filename : String) -> Result[String, String] {
    if filename == "a.html" {
      Ok("{{include: b.html}}")
    } else if filename == "b.html" {
      Ok("{{include: a.html}}")
    } else {
      Err("file not found: " + filename)
    }
  }

  let source = "{{include: a.html}}"
  match parse_template_with_includes(source, resolver) {
    Ok(_) => assert_true(false)
    Err(CycleError(msg)) => assert_true(msg.contains("cycle detected"))
    Err(_) => assert_true(false)
  }
}

///|
test "template layout extension" {
  // Mock resolver that returns layout source
  let resolver = fn(filename : String) -> Result[String, String] {
    if filename == "base.html" {
      Ok("<html><body>{{body}}</body></html>")
    } else {
      Err("file not found: " + filename)
    }
  }

  let source = "{{layout: base.html}}\n<article>{{content}}</article>"
  match parse_template_with_includes(source, resolver) {
    Ok(tpl) => {
      // Verify layout is resolved and stored
      match tpl.layout {
        Some(layout) =>
          // Layout should have a Body slot
          assert_true(layout.required_slots.contains(Body))
        None => assert_true(false)
      }
      // Verify layout directive is removed from parts
      let mut has_layout_directive = false
      let mut i = 0
      while i < tpl.parts.length() {
        match tpl.parts[i] {
          Layout(_) => has_layout_directive = true
          _ => ()
        }
        i = i + 1
      }
      assert_true(not(has_layout_directive))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "template render with layout" {
  // Mock resolver for layout
  let resolver = fn(filename : String) -> Result[String, String] {
    if filename == "base.html" {
      Ok(
        "<html><head><title>{{title}}</title></head><body>{{body}}</body></html>",
      )
    } else {
      Err("file not found: " + filename)
    }
  }

  let source = "{{layout: base.html}}\n<h1>{{title}}</h1><p>{{content}}</p>"
  match parse_template_with_includes(source, resolver) {
    Ok(tpl) => {
      let slots : Map[TemplateSlot, String] = Map::new()
      slots.set(Title, "My Page")
      slots.set(Content, "Page content")

      match render_template(tpl, slots) {
        Ok(html) => {
          // Verify child is rendered and injected into layout's body slot
          assert_true(html.contains("<html>"))
          assert_true(html.contains("<head><title>My Page</title></head>"))
          assert_true(html.contains("<body>"))
          assert_true(html.contains("<h1>My Page</h1>"))
          assert_true(html.contains("<p>Page content</p>"))
          assert_true(html.contains("</body>"))
          assert_true(html.contains("</html>"))
        }
        Err(_) => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "template nested includes" {
  // Mock resolver with nested includes
  let resolver = fn(filename : String) -> Result[String, String] {
    if filename == "parent.html" {
      Ok("{{include: child1.html}}\n{{include: child2.html}}")
    } else if filename == "child1.html" {
      Ok("Child 1: {{include: grandchild.html}}")
    } else if filename == "child2.html" {
      Ok("Child 2: {{content}}")
    } else if filename == "grandchild.html" {
      Ok("Grandchild content")
    } else {
      Err("file not found: " + filename)
    }
  }

  let source = "{{include: parent.html}}"
  match parse_template_with_includes(source, resolver) {
    Ok(tpl) => {
      // Verify all nested includes are flattened and contain expected content
      let mut has_grandchild = false
      let mut has_content_slot = false
      for part in tpl.parts {
        match part {
          Text(s) => {
            if s.contains("Grandchild content") {
              has_grandchild = true
            }
          }
          Slot(Content) => has_content_slot = true
          _ => ()
        }
      }
      assert_true(has_grandchild)
      assert_true(has_content_slot)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "template include in layout file" {
  // Mock resolver where layout itself has includes
  let resolver = fn(filename : String) -> Result[String, String] {
    if filename == "layout.html" {
      Ok("{{include: header.html}}\n{{body}}\n{{include: footer.html}}")
    } else if filename == "header.html" {
      Ok("<header>Header</header>")
    } else if filename == "footer.html" {
      Ok("<footer>Footer</footer>")
    } else {
      Err("file not found: " + filename)
    }
  }

  let source = "{{layout: layout.html}}\n<main>{{content}}</main>"
  match parse_template_with_includes(source, resolver) {
    Ok(tpl) =>
      // Verify layout has includes flattened
      match tpl.layout {
        Some(layout) => {
          // Layout should have header, body, footer with includes flattened
          let mut has_header = false
          let mut has_footer = false
          let mut has_body_slot = false
          for part in layout.parts {
            match part {
              Text(s) => {
                if s.contains("<header>Header</header>") {
                  has_header = true
                }
                if s.contains("<footer>Footer</footer>") {
                  has_footer = true
                }
              }
              Slot(Body) => has_body_slot = true
              _ => ()
            }
          }
          assert_true(has_header)
          assert_true(has_body_slot)
          assert_true(has_footer)
        }
        None => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}
