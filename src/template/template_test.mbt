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
