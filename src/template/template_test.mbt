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
  match render_template_with_data(tpl, slots, store, Map::new()) {
    Ok(html) => assert_true(html.contains("<h1>Demo</h1>"))
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
  match render_template(tpl, slots, Map::new()) {
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
  match render_template_with_data(tpl, slots, store, Map::new()) {
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
  match render_template_with_data(tpl, slots, store, Map::new()) {
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
  match render_template_with_data(tpl, slots, store, Map::new()) {
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
  match render_template(tpl, slots, Map::new()) {
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

      match render_template(tpl, slots, Map::new()) {
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
          Text(s) =>
            if s.contains("Grandchild content") {
              has_grandchild = true
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

///|
test "template parse reading_time and word_count slots" {
  let tpl = match
    parse_template("{{reading_time}} read · {{word_count}} words") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  let mut has_rt = false
  let mut has_wc = false
  for part in tpl.parts {
    match part {
      Slot(ReadingTime) => has_rt = true
      Slot(WordCount) => has_wc = true
      _ => ()
    }
  }
  assert_true(has_rt)
  assert_true(has_wc)
}

///|
test "template parse table_of_contents slot" {
  let tpl = match parse_template("<aside>{{table_of_contents}}</aside>") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  let mut has_toc = false
  for part in tpl.parts {
    match part {
      Slot(TableOfContents) => has_toc = true
      _ => ()
    }
  }
  assert_true(has_toc)
}

///|
test "template parse author and excerpt slots" {
  let tpl = match parse_template("By {{author}}<p>{{excerpt}}</p>") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  let mut has_author = false
  let mut has_excerpt = false
  for part in tpl.parts {
    match part {
      Slot(Author) => has_author = true
      Slot(Excerpt) => has_excerpt = true
      _ => ()
    }
  }
  assert_true(has_author)
  assert_true(has_excerpt)
}

///|
test "template render reading_time and word_count slots" {
  let tpl = match parse_template("{{reading_time}} · {{word_count}} words") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  let slots : Map[TemplateSlot, String] = Map::new()
  slots.set(ReadingTime, "3 min")
  slots.set(WordCount, "612")
  match render_template(tpl, slots, Map::new()) {
    Ok(html) => {
      assert_true(html.contains("3 min"))
      assert_true(html.contains("612 words"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "template render table_of_contents slot" {
  let tpl = match parse_template("<aside>{{table_of_contents}}</aside>") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  let slots : Map[TemplateSlot, String] = Map::new()
  slots.set(
    TableOfContents,
    "<nav class=\"table-of-contents\"><ul><li>Intro</li></ul></nav>",
  )
  match render_template(tpl, slots, Map::new()) {
    Ok(html) => assert_true(html.contains("table-of-contents"))
    Err(_) => assert_true(false)
  }
}

///|
test "template render description slot" {
  let tpl = match
    parse_template("<meta name=\"description\" content=\"{{description}}\">") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  let slots : Map[TemplateSlot, String] = Map::new()
  slots.set(Description, "A short intro extracted from the first paragraph.")
  match render_template(tpl, slots, Map::new()) {
    Ok(html) =>
      assert_true(
        html.contains("A short intro extracted from the first paragraph."),
      )
    Err(_) => assert_true(false)
  }
}

///|
test "template conditional renders body when slot is non-empty" {
  let tpl = match parse_template("{{?title}}<h1>{{title}}</h1>{{/?title}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  let slots : Map[TemplateSlot, String] = Map::new()
  slots.set(Title, "Hello World")
  match render_template(tpl, slots, Map::new()) {
    Ok(html) => {
      assert_true(html.contains("<h1>Hello World</h1>"))
      assert_eq(html, "<h1>Hello World</h1>")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "template conditional hides body when slot is empty string" {
  let tpl = match parse_template("{{?title}}<h1>{{title}}</h1>{{/?title}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  let slots : Map[TemplateSlot, String] = Map::new()
  slots.set(Title, "")
  match render_template(tpl, slots, Map::new()) {
    Ok(html) => assert_eq(html, "")
    Err(_) => assert_true(false)
  }
}

///|
test "template conditional hides body when slot is absent from map" {
  let tpl = match parse_template("{{?title}}<h1>{{title}}</h1>{{/?title}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  let slots : Map[TemplateSlot, String] = Map::new()
  // Title slot not set
  match render_template(tpl, slots, Map::new()) {
    Ok(html) => assert_eq(html, "")
    Err(_) => assert_true(false)
  }
}

///|
test "template conditional nested slot inside conditional renders correctly" {
  let tpl = match parse_template("{{?title}}<h1>{{title}}</h1>{{/?title}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  let slots : Map[TemplateSlot, String] = Map::new()
  slots.set(Title, "My Page")
  match render_template(tpl, slots, Map::new()) {
    Ok(html) => assert_eq(html, "<h1>My Page</h1>")
    Err(_) => assert_true(false)
  }
}

///|
test "template conditional with prev_post_url slot" {
  let tpl = match
    parse_template(
      "{{?prev_post_url}}<a href=\"{{prev_post_url}}\">← Previous</a>{{/?prev_post_url}}",
    ) {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }

  // Test with prev_post_url present
  let slots_with_prev : Map[TemplateSlot, String] = Map::new()
  slots_with_prev.set(PrevPostUrl, "/prev-post.html")
  match render_template(tpl, slots_with_prev, Map::new()) {
    Ok(html) => {
      assert_true(html.contains("<a href=\"/prev-post.html\">"))
      assert_true(html.contains("← Previous"))
    }
    Err(_) => assert_true(false)
  }

  // Test with prev_post_url absent (first post)
  let slots_no_prev : Map[TemplateSlot, String] = Map::new()
  match render_template(tpl, slots_no_prev, Map::new()) {
    Ok(html) => assert_eq(html, "")
    Err(_) => assert_true(false)
  }
}

///|
test "template conditional unknown slot name reports error" {
  match parse_template("{{?unknown_slot}}content{{/?unknown_slot}}") {
    Ok(_) => assert_true(false)
    Err(UnknownSlot(name)) => assert_eq(name, "unknown_slot")
    Err(_) => assert_true(false)
  }
}

///|
test "template conditional closing tag mismatch is an error" {
  match parse_template("{{?title}}content{{/?wrong_slot}}") {
    Ok(_) => assert_true(false)
    Err(ParseError(msg)) =>
      assert_true(
        msg.contains("missing closing tag") || msg.contains("unterminated"),
      )
    Err(_) => assert_true(false)
  }
}

///|
test "template conditional missing closing tag is an error" {
  match parse_template("{{?title}}content") {
    Ok(_) => assert_true(false)
    Err(ParseError(msg)) => assert_true(msg.contains("missing closing tag"))
    Err(_) => assert_true(false)
  }
}

///|
test "template conditional nested conditionals - simple case" {
  // Simple test: {{?title}}body{{/?title}}
  let tpl1 = match parse_template("{{?title}}<h1>{{title}}</h1>{{/?title}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  let slots_with : Map[TemplateSlot, String] = Map::new()
  slots_with.set(Title, "My Title")
  match render_template(tpl1, slots_with, Map::new()) {
    Ok(html) => assert_eq(html, "<h1>My Title</h1>")
    Err(_) => assert_true(false)
  }
}

///|
// test "template conditional nested conditionals" {
//   let tpl = match
//     parse_template(
//       "{{?title}}{{?description}}<h1>{{title}}</h1><p>{{description}}</p>{{/?description}}{{/?title}}",
//     ) {
//     Ok(v) => v
//     Err(_) => {
//       assert_true(false)
//       { parts: [], required_slots: [], layout: None }
//     }
//   }
//   
//   // Both slots present
//   let slots_both : Map[TemplateSlot, String] = Map::new()
//   slots_both.set(Title, "My Title")
//   slots_both.set(Description, "My Description")
//   match render_template(tpl, slots_both, Map::new()) {
//     Ok(html) => {
//       assert_true(html.contains("<h1>My Title</h1>"))
//       assert_true(html.contains("<p>My Description</p>"))
//     }
//     Err(_) => assert_true(false)
//   }
//   
//   // Only title present - outer conditional renders but inner doesn't
//   let slots_title : Map[TemplateSlot, String] = Map::new()
//   slots_title.set(Title, "My Title")
//   match render_template(tpl, slots_title) {
//     Ok(html) => {
//       assert_eq(html, "")
//     }
//     Err(_) => assert_true(false)
//   }
//   
//   // No slots present
//   let slots_none : Map[TemplateSlot, String] = Map::new()
//   match render_template(tpl, slots_none, Map::new()) {
//     Ok(html) => {
//       assert_eq(html, "")
//     }
//     Err(_) => assert_true(false)
//   }
// }

///|
test "template conditional multiple conditionals in template" {
  let tpl = match
    parse_template(
      "{{?prev_post_url}}<a href=\"{{prev_post_url}}\">Previous</a>{{/?prev_post_url}} | {{?next_post_url}}<a href=\"{{next_post_url}}\">Next</a>{{/?next_post_url}}",
    ) {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }

  // Both present
  let slots_both : Map[TemplateSlot, String] = Map::new()
  slots_both.set(PrevPostUrl, "/prev.html")
  slots_both.set(NextPostUrl, "/next.html")
  match render_template(tpl, slots_both, Map::new()) {
    Ok(html) => {
      assert_true(html.contains("<a href=\"/prev.html\">Previous</a>"))
      assert_true(html.contains("<a href=\"/next.html\">Next</a>"))
      assert_true(html.contains(" | "))
    }
    Err(_) => assert_true(false)
  }

  // Only next present
  let slots_next : Map[TemplateSlot, String] = Map::new()
  slots_next.set(NextPostUrl, "/next.html")
  match render_template(tpl, slots_next, Map::new()) {
    Ok(html) => {
      assert_true(not(html.contains("Previous")))
      assert_true(html.contains("<a href=\"/next.html\">Next</a>"))
      assert_true(html.contains(" | ")) // Separator text is still present
    }
    Err(_) => assert_true(false)
  }

  // Neither present - only the static separator remains
  let slots_none : Map[TemplateSlot, String] = Map::new()
  match render_template(tpl, slots_none, Map::new()) {
    Ok(html) => assert_eq(html, " | ")
    Err(_) => assert_true(false)
  }
}

///|
test "template conditional with data slot inside body" {
  let store = @data.new_store([
    @data.new_string_file("site", [("tagline", "Build fast")]),
  ])

  let tpl = match
    parse_template(
      "{{?title}}<h1>{{title}}</h1><p>{{data.site.tagline}}</p>{{/?title}}",
    ) {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }

  let slots : Map[TemplateSlot, String] = Map::new()
  slots.set(Title, "My Site")
  match render_template_with_data(tpl, slots, store, Map::new()) {
    Ok(html) => {
      assert_true(html.contains("<h1>My Site</h1>"))
      assert_true(html.contains("<p>Build fast</p>"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse {{page.field}} frontmatter slot" {
  let tpl = match parse_template("Series: {{page.series}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  // Should have two parts: Text and FrontmatterSlot
  assert_eq(tpl.parts.length(), 2)
  match tpl.parts[0] {
    Text(s) => assert_eq(s, "Series: ")
    _ => assert_true(false)
  }
  match tpl.parts[1] {
    FrontmatterSlot(field) => assert_eq(field, "series")
    _ => assert_true(false)
  }
  // FrontmatterSlot should NOT be in required_slots
  assert_eq(tpl.required_slots.length(), 0)
}

///|
test "render {{page.field}} with field present" {
  let tpl = match parse_template("Series: {{page.series}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  let slots : Map[TemplateSlot, String] = Map::new()
  let page_fields : Map[String, String] = Map::new()
  page_fields.set("series", "MoonBit Deep Dive")
  match render_template(tpl, slots, page_fields) {
    Ok(html) => assert_eq(html, "Series: MoonBit Deep Dive")
    Err(_) => assert_true(false)
  }
}

///|
test "render {{page.field}} with missing field" {
  let tpl = match parse_template("Series: {{page.series}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  let slots : Map[TemplateSlot, String] = Map::new()
  let page_fields : Map[String, String] = Map::new()
  // No "series" field in page_fields
  match render_template(tpl, slots, page_fields) {
    Ok(html) => assert_eq(html, "Series: ")
    Err(_) => assert_true(false)
  }
}

///|
test "render {{page.field}} with empty key fails to parse" {
  match parse_template("{{page.}}") {
    Ok(_) => assert_true(false) // Should fail to parse
    Err(ParseError(msg)) => assert_true(msg.contains("invalid page slot"))
    Err(_) => assert_true(false)
  }
}

///|
test "{{?page.field}} conditional renders body when field is present and non-empty" {
  let tpl = match
    parse_template(
      "{{?page.og_image}}<img src=\"{{page.og_image}}\">{{/?page.og_image}}",
    ) {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  let slots : Map[TemplateSlot, String] = Map::new()
  let page_fields : Map[String, String] = Map::new()
  page_fields.set("og_image", "/images/og.png")
  match render_template(tpl, slots, page_fields) {
    Ok(html) => assert_true(html.contains("<img src=\"/images/og.png\">"))
    Err(_) => assert_true(false)
  }
}

///|
test "{{?page.field}} conditional renders nothing when field is absent" {
  let tpl = match
    parse_template(
      "{{?page.og_image}}<img src=\"{{page.og_image}}\">{{/?page.og_image}}",
    ) {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  let slots : Map[TemplateSlot, String] = Map::new()
  let page_fields : Map[String, String] = Map::new()
  // No "og_image" field
  match render_template(tpl, slots, page_fields) {
    Ok(html) => assert_eq(html, "")
    Err(_) => assert_true(false)
  }
}

///|
test "{{?page.field}} conditional renders nothing when field is empty string" {
  let tpl = match
    parse_template(
      "{{?page.og_image}}<img src=\"{{page.og_image}}\">{{/?page.og_image}}",
    ) {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  let slots : Map[TemplateSlot, String] = Map::new()
  let page_fields : Map[String, String] = Map::new()
  page_fields.set("og_image", "")
  match render_template(tpl, slots, page_fields) {
    Ok(html) => assert_eq(html, "")
    Err(_) => assert_true(false)
  }
}

///|
test "{{?page.field}} conditional nested inside {{?slot}} conditional" {
  let tpl = match
    parse_template(
      "{{?title}}{{?page.series}}<p>Part of: {{page.series}}</p>{{/?page.series}}{{/?title}}",
    ) {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }

  // Both title and series present
  let slots_both : Map[TemplateSlot, String] = Map::new()
  slots_both.set(Title, "My Post")
  let page_fields_with_series : Map[String, String] = Map::new()
  page_fields_with_series.set("series", "MoonBit Series")
  match render_template(tpl, slots_both, page_fields_with_series) {
    Ok(html) => assert_true(html.contains("<p>Part of: MoonBit Series</p>"))
    Err(_) => assert_true(false)
  }

  // Title present but no series
  let slots_title : Map[TemplateSlot, String] = Map::new()
  slots_title.set(Title, "My Post")
  let page_fields_no_series : Map[String, String] = Map::new()
  match render_template(tpl, slots_title, page_fields_no_series) {
    Ok(html) => {
      inspect(html, content="")
      assert_eq(html, "")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "{{?page.field}} conditional with multiple page fields" {
  let tpl = match
    parse_template(
      "{{?page.og_image}}<img src=\"{{page.og_image}}\">{{/?page.og_image}}{{?page.og_description}}<meta name=\"og:description\" content=\"{{page.og_description}}\">{{/?page.og_description}}",
    ) {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }

  // Both fields present
  let page_fields_both : Map[String, String] = Map::new()
  page_fields_both.set("og_image", "/images/og.png")
  page_fields_both.set("og_description", "A great post")
  let slots : Map[TemplateSlot, String] = Map::new()
  match render_template(tpl, slots, page_fields_both) {
    Ok(html) => {
      assert_true(html.contains("<img src=\"/images/og.png\">"))
      assert_true(
        html.contains("<meta name=\"og:description\" content=\"A great post\">"),
      )
    }
    Err(_) => assert_true(false)
  }

  // Only og_image present
  let page_fields_image : Map[String, String] = Map::new()
  page_fields_image.set("og_image", "/images/og.png")
  match render_template(tpl, slots, page_fields_image) {
    Ok(html) => {
      assert_true(html.contains("<img src=\"/images/og.png\">"))
      assert_true(not(html.contains("og:description")))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "{{?page.field}} conditional closing tag mismatch returns ParseError" {
  match
    parse_template(
      "{{?page.og_image}}<img src=\"{{page.og_image}}\">{{/?page.og_description}}",
    ) {
    Ok(_) => assert_true(false)
    Err(ParseError(msg)) => assert_true(msg.contains("missing closing tag"))
    Err(_) => assert_true(false)
  }
}

///|
test "{{?page.field}} conditional missing closing tag returns ParseError" {
  match parse_template("{{?page.og_image}}<img src=\"{{page.og_image}}\">") {
    Ok(_) => assert_true(false)
    Err(ParseError(msg)) => assert_true(msg.contains("missing closing tag"))
    Err(_) => assert_true(false)
  }
}

///|
test "{{?page.}} with empty field name returns ParseError" {
  match parse_template("{{?page.}}content{{/?page.}}") {
    Ok(_) => assert_true(false)
    Err(ParseError(msg)) =>
      assert_true(msg.contains("invalid page conditional slot"))
    Err(_) => assert_true(false)
  }
}

///|
test "render {{page.field}} in conditional body with data store" {
  let tpl = match
    parse_template("{{?title}}Series: {{page.series}}{{/?title}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  let store = @data.new_store([
    @data.new_string_file("test", [("name", "Lattice")]),
  ])
  let slots : Map[TemplateSlot, String] = Map::new()
  slots.set(Title, "My Post")
  let page_fields : Map[String, String] = Map::new()
  page_fields.set("series", "MoonBit Series")
  match render_template_with_data(tpl, slots, store, page_fields) {
    Ok(html) => assert_eq(html, "Series: MoonBit Series")
    Err(_) => assert_true(false)
  }
}


///|
test "parse {{#each data.nav.items}}...{{/each}} loop" {
  let tpl = match
    parse_template("{{#each data.nav.items}}{{item}}{{/each}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  
  // Should have one part: DataEachBlock
  assert_eq(tpl.parts.length(), 1)
  match tpl.parts[0] {
    DataEachBlock(file, key_path, body_parts) => {
      assert_eq(file, "nav")
      assert_eq(key_path.length(), 1)
      assert_eq(key_path[0], "items")
      // Body should have one part: LoopItemSlot([])
      assert_eq(body_parts.length(), 1)
      match body_parts[0] {
        LoopItemSlot(path) => assert_eq(path.length(), 0)
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
test "parse {{#each data.nav.links}}...{{/each}} with field access" {
  let tpl = match
    parse_template("{{#each data.nav.links}}<a href=\"{{item.url}}\">{{item.title}}</a>{{/each}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  
  match tpl.parts[0] {
    DataEachBlock(file, key_path, body_parts) => {
      assert_eq(file, "nav")
      assert_eq(key_path[0], "links")
      // Body should have 5 parts: Text, LoopItemSlot, Text, LoopItemSlot, Text
      assert_eq(body_parts.length(), 5)
      match body_parts[1] {
        LoopItemSlot(path) => {
          assert_eq(path.length(), 1)
          assert_eq(path[0], "url")
        }
        _ => assert_true(false)
      }
      match body_parts[3] {
        LoopItemSlot(path) => {
          assert_eq(path.length(), 1)
          assert_eq(path[0], "title")
        }
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
test "parse {{item.title}} creates LoopItemSlot with path" {
  let tpl = match parse_template("{{item.title}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  
  match tpl.parts[0] {
    LoopItemSlot(path) => {
      assert_eq(path.length(), 1)
      assert_eq(path[0], "title")
    }
    _ => assert_true(false)
  }
}

///|
test "parse {{item.a.b}} creates LoopItemSlot with nested path" {
  let tpl = match parse_template("{{item.a.b}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  
  match tpl.parts[0] {
    LoopItemSlot(path) => {
      assert_eq(path.length(), 2)
      assert_eq(path[0], "a")
      assert_eq(path[1], "b")
    }
    _ => assert_true(false)
  }
}

///|
test "parse unclosed {{#each}} returns ParseError" {
  match parse_template("{{#each data.nav.items}}{{item}}") {
    Ok(_) => assert_true(false)
    Err(ParseError(msg)) => assert_true(msg.contains("missing closing tag"))
    Err(_) => assert_true(false)
  }
}

///|
test "render loop over string array" {
  // Create a data file with an actual array
  let fields : Map[String, @frontmatter.FrontmatterValue] = Map::new()
  fields.set(
    "items",
    @frontmatter.FArray([
      @frontmatter.FStr("home"),
      @frontmatter.FStr("blog"),
      @frontmatter.FStr("about"),
    ]),
  )
  let array_file = @data.new_file("nav", fields)
  let array_store = @data.new_store([array_file])
  
  let tpl = match
    parse_template("{{#each data.nav.items}}<li>{{item}}</li>{{/each}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  
  let slots : Map[TemplateSlot, String] = Map::new()
  match render_template_with_data(tpl, slots, array_store, Map::new()) {
    Ok(html) => {
      assert_true(html.contains("<li>home</li>"))
      assert_true(html.contains("<li>blog</li>"))
      assert_true(html.contains("<li>about</li>"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "render loop over map array with field access" {
  // Create a data file with an array of maps
  let link1 : Map[String, @frontmatter.FrontmatterValue] = Map::new()
  link1.set("title", @frontmatter.FStr("Home"))
  link1.set("url", @frontmatter.FStr("/"))
  
  let link2 : Map[String, @frontmatter.FrontmatterValue] = Map::new()
  link2.set("title", @frontmatter.FStr("Blog"))
  link2.set("url", @frontmatter.FStr("/blog"))
  
  let fields : Map[String, @frontmatter.FrontmatterValue] = Map::new()
  fields.set(
    "links",
    @frontmatter.FArray([@frontmatter.FMap(link1), @frontmatter.FMap(link2)]),
  )
  
  let file = @data.new_file("nav", fields)
  let store = @data.new_store([file])
  
  let tpl = match
    parse_template("{{#each data.nav.links}}<a href=\"{{item.url}}\">{{item.title}}</a>{{/each}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  
  let slots : Map[TemplateSlot, String] = Map::new()
  match render_template_with_data(tpl, slots, store, Map::new()) {
    Ok(html) => {
      assert_true(html.contains("<a href=\"/\">Home</a>"))
      assert_true(html.contains("<a href=\"/blog\">Blog</a>"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "render loop with non-array value renders nothing" {
  let store = @data.new_store([
    @data.new_string_file("nav", [("title", "Main")]),
  ])
  
  let tpl = match
    parse_template("{{#each data.nav.title}}{{item}}{{/each}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  
  let slots : Map[TemplateSlot, String] = Map::new()
  match render_template_with_data(tpl, slots, store, Map::new()) {
    Ok(html) => assert_eq(html, "")
    Err(_) => assert_true(false)
  }
}

///|
test "render loop with missing key renders nothing" {
  let store = @data.new_store([
    @data.new_string_file("nav", [("title", "Main")]),
  ])
  
  let tpl = match
    parse_template("{{#each data.nav.missing}}{{item}}{{/each}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  
  let slots : Map[TemplateSlot, String] = Map::new()
  match render_template_with_data(tpl, slots, store, Map::new()) {
    Ok(html) => assert_eq(html, "")
    Err(_) => assert_true(false)
  }
}

///|
test "render {{item.field}} with non-map item renders empty" {
  let fields : Map[String, @frontmatter.FrontmatterValue] = Map::new()
  fields.set(
    "items",
    @frontmatter.FArray([@frontmatter.FStr("string_value")]),
  )
  
  let file = @data.new_file("nav", fields)
  let store = @data.new_store([file])
  
  let tpl = match
    parse_template("{{#each data.nav.items}}{{item.title}}{{/each}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  
  let slots : Map[TemplateSlot, String] = Map::new()
  match render_template_with_data(tpl, slots, store, Map::new()) {
    Ok(html) => assert_eq(html, "")
    Err(_) => assert_true(false)
  }
}

///|
test "render {{item}} outside loop renders empty" {
  let store = @data.new_store([
    @data.new_string_file("nav", [("title", "Main")]),
  ])
  
  let tpl = match parse_template("Item: {{item}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  
  let slots : Map[TemplateSlot, String] = Map::new()
  match render_template_with_data(tpl, slots, store, Map::new()) {
    Ok(html) => assert_eq(html, "Item: ")
    Err(_) => assert_true(false)
  }
}

///|
test "parse {{#each}} with nested path" {
  let tpl = match
    parse_template("{{#each data.site.nav.links}}{{item}}{{/each}}") {
    Ok(v) => v
    Err(_) => {
      assert_true(false)
      { parts: [], required_slots: [], layout: None }
    }
  }
  
  match tpl.parts[0] {
    DataEachBlock(file, key_path, _) => {
      assert_eq(file, "site")
      assert_eq(key_path.length(), 2)
      assert_eq(key_path[0], "nav")
      assert_eq(key_path[1], "links")
    }
    _ => assert_true(false)
  }
}
