///|
test "repeated built-in and frontmatter predicates match enclosing conditional closes" {
  for predicate in ["title", "page.organizer"] {
    let source = "before{{?" +
      predicate +
      "}}<section>{{?" +
      predicate +
      "}}<b>{{" +
      predicate +
      "}}</b>{{/?" +
      predicate +
      "}}after</section>{{/?" +
      predicate +
      "}}end"
    let tpl = match @template.parse_template(source) {
      Ok(tpl) => tpl
      Err(_) => abort("valid repeated conditional rejected")
    }
    let slots : Map[@template.TemplateSlot, String] = Map([])
    slots.set(Title, "Workshop")
    let fields : Map[String, String] = Map([])
    fields.set("organizer", "Workshop")
    for value in ["Workshop", ""] {
      slots.set(Title, value)
      fields.set("organizer", value)
      let expected = if value == "" {
        "beforeend"
      } else {
        "before<section><b>Workshop</b>after</section>end"
      }
      match @template.render_template(tpl, slots, fields) {
        Ok(html) => assert_eq(html, expected)
        Err(_) => abort("repeated conditional rendering failed")
      }
      match
        @template.render_template_with_data(
          tpl,
          slots,
          @data.empty_store(),
          fields,
          Map([]),
        ) {
        Ok(html) => assert_eq(html, expected)
        Err(_) => abort("data-aware conditional rendering failed")
      }
    }
    match @template.render_template(tpl, Map([]), Map([])) {
      Ok(html) => assert_eq(html, "beforeend")
      Err(_) => abort("absent predicate rendering failed")
    }
  }
}

///|
test "repeated predicates balance through other predicates and each bodies" {
  let tpl = match
    @template.parse_template(
      "{{?title}}A{{?page.organizer}}B{{#each page.sessions}}{{ ? title }}[{{item}}]{{/?title}}{{/each}}C{{/?page.organizer}}D{{/?title}}{{?title}}E{{/?title}}",
    ) {
    Ok(tpl) => tpl
    Err(_) => abort("valid mixed nested conditional rejected")
  }
  let slots : Map[@template.TemplateSlot, String] = Map([])
  slots.set(Title, "Workshop")
  let fields : Map[String, String] = Map([])
  fields.set("organizer", "Host")
  let arrays : Map[String, Array[String]] = Map([])
  arrays.set("sessions", ["Morning", "Evening"])
  match
    @template.render_template_with_data(
      tpl,
      slots,
      @data.empty_store(),
      fields,
      arrays,
    ) {
    Ok(html) => assert_eq(html, "AB[Morning][Evening]CDE")
    Err(_) => abort("mixed nested rendering failed")
  }
  match
    @template.render_template_with_data(
      tpl,
      slots,
      @data.empty_store(),
      Map([]),
      arrays,
    ) {
    Ok(html) => assert_eq(html, "ADE")
    Err(_) => abort("missing inner predicate rendering failed")
  }
}

///|
test "repeated conditionals preserve missing-close mismatch and inner-slot errors" {
  for predicate in ["title", "page.organizer"] {
    match
      @template.parse_template(
        "{{?" +
        predicate +
        "}}{{?" +
        predicate +
        "}}body{{/?" +
        predicate +
        "}}",
      ) {
      Err(@template.ParseError(message)) =>
        assert_eq(
          message,
          "missing closing tag for conditional block: {{/?" + predicate + "}}",
        )
      _ => abort("missing enclosing conditional close accepted")
    }
    match
      @template.parse_template(
        "{{?" +
        predicate +
        "}}{{?" +
        predicate +
        "}}{{typo}}{{/?" +
        predicate +
        "}}{{/?" +
        predicate +
        "}}",
      ) {
      Err(@template.UnknownSlot(name)) => assert_eq(name, "typo")
      _ => abort("inner unknown slot was not validated")
    }
  }
  match
    @template.parse_template(
      "{{?title}}{{?description}}body{{/?title}}{{/?description}}",
    ) {
    Err(@template.ParseError(_)) => ()
    _ => abort("crossed conditional closes accepted")
  }
}
