///|
pub fn render_note() -> Int {
  let source = "---\ntitle: Garden\n---\n## Planting\nRead [[soil|the soil guide]].\n"
  let fm = match @frontmatter.parse(source) {
    Ok(fm) => fm
    Err(_) => return -1
  }
  let links : Map[String, String] = Map([])
  let index : Map[String, String] = Map([])
  index.set("soil", "/notes/soil/")
  let (resolved, errors) = @wikilink.resolve(
    @wikilink.extract(fm.body, "garden.md"),
    index,
  )
  if !errors.is_empty() {
    return -2
  }
  for link in resolved {
    links.set(link.raw.target, link.url)
  }
  let html = @markdown.render(fm.body, links)
  let navigation = @search.render_content_index_with_navigation(
    [@search.new_content_entry("Garden", "garden", "/garden/", [], "", "", "", "page", None, "body")],
    Map([]),
    Map([("/garden/", resolved)]),
  )
  if html ==
    "<h2 id=\"planting\">Planting</h2>\n<p>Read <a href=\"/notes/soil/\">the soil guide</a>.</p>\n" &&
    @strutil.strip_html_tags("<div title=\"a > b\">10&#176;C. <!-- 🌱 > annotation -->&#x1F331;. A&#32;&#9;B.</div>") ==
    "10°C. 🌱. A B." &&
    @strutil.strip_html_tags("<textarea><!-- visible</textarea><p>After</p>") ==
    "<!-- visible After" &&
    navigation.contains("\"links\": [{\"target\": \"soil\", \"url\": \"/notes/soil/\", \"text\": \"the soil guide\"}]") {
    1
  } else {
    0
  }
}

///|
pub fn validate_note() -> Int {
  let schema : @schema.Schema = {
    name: "notes",
    fields: [
      {
        name: "title",
        field_type: @schema.TString(None, None),
        required: true,
      },
    ],
  }
  let valid = match @frontmatter.parse("---\ntitle: Garden\n---\nA note.\n") {
    Ok(fm) => fm
    Err(_) => return -1
  }
  let invalid = match @frontmatter.parse("---\n---\nA note.\n") {
    Ok(fm) => fm
    Err(_) => return -2
  }
  let errors = @schema.validate(invalid, schema)
  if @schema.validate(valid, schema).is_empty() &&
    errors.length() == 1 &&
    errors[0].field == "title" &&
    errors[0].message == "required field missing" {
    1
  } else {
    0
  }
}

///|
pub fn validate_links() -> Int {
  let body = "Read [[soil|the soil guide]] and [[missing]]. `[[sample]]`"
  let links = @wikilink.extract(body, "garden.md")
  let index : Map[String, String] = Map([])
  index.set("soil", "/notes/soil/")
  let (resolved, errors) = @wikilink.resolve(links, index)
  if links.length() == 2 &&
    resolved.length() == 1 &&
    resolved[0].url == "/notes/soil/" &&
    resolved[0].title == "the soil guide" &&
    errors.length() == 1 &&
    errors[0].link.target == "missing" &&
    errors[0].link.source_file == "garden.md" &&
    errors[0].message == "target 'missing' not found in page index" {
    1
  } else {
    0
  }
}

///|
pub fn template_note() -> Int {
  let tpl = match
    @template.parse_template(
      "<article><h1>{{page.title}}</h1>{{?page.description}}<p>{{page.description}}</p>{{/?page.description}}{{body}}</article>",
    ) {
    Ok(tpl) => tpl
    Err(_) => return -1
  }
  let slots : Map[@template.TemplateSlot, String] = Map([])
  slots.set(@template.Body, "<p>A note.</p>")
  let fields : Map[String, String] = Map([])
  fields.set("title", "Garden & Tools")
  let absent = match @template.render_template(tpl, slots, fields) {
    Ok(html) => html
    Err(_) => return -2
  }
  fields.set("description", "Grow <well>")
  let present = match @template.render_template(tpl, slots, fields) {
    Ok(html) => html
    Err(_) => return -3
  }
  let date_tpl = match @template.parse_template(
    "{{page.stamp | date_part day | default \"Undated\"}}",
  ) {
    Ok(tpl) => tpl
    Err(_) => return -4
  }
  fields.set("stamp", "2024-02-29 12:34:56")
  let local_date = match @template.render_template(date_tpl, slots, fields) {
    Ok(html) => html
    Err(_) => return -5
  }
  fields.set("stamp", "2026-02-30")
  let invalid_date = match @template.render_template(date_tpl, slots, fields) {
    Ok(html) => html
    Err(_) => return -6
  }
  if local_date == "29" && invalid_date == "Undated" &&
    absent == "<article><h1>Garden &amp; Tools</h1><p>A note.</p></article>" &&
    present ==
    "<article><h1>Garden &amp; Tools</h1><p>Grow &lt;well&gt;</p><p>A note.</p></article>" {
    1
  } else {
    0
  }
}

///|
pub fn parse_toml_note() -> Int {
  let fm = match
    @frontmatter.parse(
      "+++\ntitle = \"Café notes\"\ntags = [\"soil\", \"café\"]\n+++\nA note.\n",
    ) {
    Ok(fm) => fm
    Err(_) => return -1
  }
  match (fm.fields.get("title"), fm.fields.get("tags")) {
    (
      Some(@frontmatter.FStr("Café notes")),
      Some(
        @frontmatter.FArray(
          [@frontmatter.FStr("soil"), @frontmatter.FStr("café")]
        )
      ),
    ) => if fm.body == "A note.\n" { 1 } else { 0 }
    _ => 0
  }
}
