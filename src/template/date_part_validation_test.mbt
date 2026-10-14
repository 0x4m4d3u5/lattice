///|
test "date parts reject malformed calendar values before default filters" {
  let tpl = match
    @template.parse_template(
      "{{date | date_part year | default \"Undated\"}}/{{date | date_part month | default \"none\"}}/{{date | date_part day | default \"none\"}}",
    ) {
    Ok(tpl) => tpl
    Err(_) => abort("invalid fixture template")
  }
  // Python date/datetime.fromisoformat independently rejects these values.
  for
    value in ["not-a-date", "2026-02-30", "2026-13-01", "2026-01-01T25:00:00Z"] {
    let slots : Map[@template.TemplateSlot, String] = Map([
      (@template.Date, value),
    ])
    let html = match @template.render_template(tpl, slots, Map([])) {
      Ok(html) => html
      Err(_) => abort("render failed")
    }
    assert_eq(html, "Undated/none/none")
  }
}

///|
test "date parts preserve valid date local datetime and offset forms" {
  let tpl = match
    @template.parse_template(
      "{{date | date_part year}}/{{date | date_part month}}/{{date | date_part day}}",
    ) {
    Ok(tpl) => tpl
    Err(_) => abort("invalid fixture template")
  }
  for
    value in [
      "2024-02-29", "2024-02-29T12:34:56", "2024-02-29 12:34:56", "2024-02-29T12:34:56Z",
      "2024-02-29T23:34:56-05:00", "2024-02-29 00:34:56+05:30",
    ] {
    let slots : Map[@template.TemplateSlot, String] = Map([
      (@template.Date, value),
    ])
    let html = match @template.render_template(tpl, slots, Map([])) {
      Ok(html) => html
      Err(_) => abort("render failed")
    }
    assert_eq(html, "2024/02/29")
  }
}
