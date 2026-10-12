///|
test "self and mutual layout cycles return typed errors before repeated resolution" {
  for mutual in [false, true] {
    let calls : Array[String] = []
    let resolver = fn(path : String) -> Result[String, String] {
      calls.push(path)
      // Bound the unfixed parser so this regression fails without overflowing.
      if calls.length() > 3 {
        return Err("resolver budget exhausted")
      }
      if path == "base.html" {
        Ok(
          if mutual {
            "{{layout: shell.html}}<main>{{body}}</main>"
          } else {
            "{{layout: base.html}}<main>{{body}}</main>"
          },
        )
      } else if path == "shell.html" {
        Ok("{{layout: base.html}}<html>{{body}}</html>")
      } else {
        Err("unexpected file: " + path)
      }
    }
    match
      @template.parse_template_with_includes(
        "{{layout: base.html}}<article>{{content}}</article>", resolver,
      ) {
      Err(@template.CycleError(message)) =>
        assert_eq(message, "layout cycle detected: base.html")
      _ => abort("layout cycle did not produce a typed cycle error")
    }
    assert_eq(
      calls,
      if mutual {
        ["base.html", "shell.html"]
      } else {
        ["base.html"]
      },
    )
  }
}

///|
test "layout directives from includes retain the active layout chain" {
  let calls : Array[String] = []
  let resolver = fn(path : String) -> Result[String, String] {
    calls.push(path)
    if calls.length() > 4 {
      return Err("resolver budget exhausted")
    }
    match path {
      "base.html" => Ok("{{include: parent.html}}<main>{{body}}</main>")
      "parent.html" => Ok("{{layout: base.html}}")
      _ => Err("unexpected file: " + path)
    }
  }
  match
    @template.parse_template_with_includes(
      "{{layout: base.html}}<article>{{content}}</article>", resolver,
    ) {
    Err(@template.CycleError(message)) =>
      assert_eq(message, "layout cycle detected: base.html")
    _ => abort("include-provided layout cycle was not rejected")
  }
  assert_eq(calls, ["base.html", "parent.html"])
}

///|
test "layout cycle tracking does not reject shared partials or later independent loads" {
  let resolver = fn(path : String) -> Result[String, String] {
    match path {
      "base.html" =>
        Ok(
          "<html>{{include: badge.html}}{{body}}{{include: badge.html}}</html>",
        )
      "badge.html" => Ok("<span>Workshop</span>")
      _ => Err("unexpected file: " + path)
    }
  }
  for _ in 0..<2 {
    let tpl = match
      @template.parse_template_with_includes(
        "{{layout: base.html}}{{include: badge.html}}<article>{{content}}</article>",
        resolver,
      ) {
      Ok(tpl) => tpl
      Err(_) => abort("valid shared-partial layout rejected")
    }
    let slots : Map[@template.TemplateSlot, String] = Map([])
    slots.set(Content, "Book a session.")
    match @template.render_template(tpl, slots, Map([])) {
      Ok(html) =>
        assert_eq(
          html, "<html><span>Workshop</span><span>Workshop</span><article>Book a session.</article><span>Workshop</span></html>",
        )
      Err(_) => abort("valid layout rendering failed")
    }
  }
}
