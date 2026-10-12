///|
test "nested data and page loops restore their enclosing item context" {
  let fields : Map[String, @frontmatter.FrontmatterValue] = Map([])
  fields.set(
    "locations",
    @frontmatter.FArray([@frontmatter.FStr("North"), @frontmatter.FStr("South")]),
  )
  let store = @data.new_store([@data.new_file("workshops", fields)])
  let arrays : Map[String, Array[String]] = Map([])
  arrays.set("sessions", ["Morning", "Evening"])
  for
    (source, expected) in [
      (
        "{{#each data.workshops.locations}}[{{item}}:{{#each page.sessions}}({{item}}){{/each}}:{{item}}]{{/each}}!",
        "[North:(Morning)(Evening):North][South:(Morning)(Evening):South]!",
      ),
      (
        "{{#each page.sessions}}[{{item}}:{{#each data.workshops.locations}}({{item}}){{/each}}:{{item}}]{{/each}}!",
        "[Morning:(North)(South):Morning][Evening:(North)(South):Evening]!",
      ),
    ] {
    let template = match @template.parse_template(source) {
      Ok(t) => t
      Err(_) => abort("valid nested each template rejected")
    }
    match
      @template.render_template_with_data(
        template,
        Map([]),
        store,
        Map([]),
        arrays,
      ) {
      Ok(html) => assert_eq(html, expected)
      Err(_) => abort("nested each rendering failed")
    }
  }
}

///|
test "same-kind and three-level each blocks match their own closing tags" {
  let arrays : Map[String, Array[String]] = Map([])
  arrays.set("locations", ["North", "South"])
  arrays.set("sessions", ["Morning", "Evening"])
  arrays.set("tracks", ["Lab"])
  let template = match
    @template.parse_template(
      "{{#each page.locations}}[{{item}}:{{#each page.sessions}}{{item}}/{{#each page.tracks}}{{item}}{{/each}}/{{item}};{{/each}}:{{item}}]{{/each}}{{#each page.tracks}}+{{item}}{{/each}}",
    ) {
    Ok(t) => t
    Err(_) => abort("valid three-level template rejected")
  }
  match
    @template.render_template_with_data(
      template,
      Map([]),
      @data.empty_store(),
      Map([]),
      arrays,
    ) {
    Ok(html) =>
      assert_eq(
        html, "[North:Morning/Lab/Morning;Evening/Lab/Evening;:North][South:Morning/Lab/Morning;Evening/Lab/Evening;:South]+Lab",
      )
    Err(_) => abort("three-level rendering failed")
  }
}

///|
test "nested each blocks still reject missing closes and invalid inner slots" {
  for
    source in [
      "{{#each page.locations}}{{#each page.sessions}}{{item}}{{/each}}", "{{#each data.workshops.locations}}{{#each page.sessions}}{{item}}",
    ] {
    match @template.parse_template(source) {
      Err(@template.ParseError(message)) =>
        assert_eq(message, "missing closing tag for each block: {{/each}}")
      _ => abort("unclosed each template accepted")
    }
  }
  match
    @template.parse_template(
      "{{#each page.locations}}{{#each page.sessions}}{{typo}}{{/each}}{{/each}}",
    ) {
    Err(@template.UnknownSlot(name)) => assert_eq(name, "typo")
    _ => abort("inner unknown slot was not validated")
  }
}
