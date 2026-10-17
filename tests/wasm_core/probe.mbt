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
  if @markdown.render(": orphan", Map([])) != "<p>: orphan</p>\n" {
    return -5
  }
  if @markdown.render("Context.\nTerm\n: definition", Map([])) !=
    "<p>Context.</p>\n<dl>\n<dt>Term</dt>\n<dd>definition</dd>\n</dl>\n" {
    return -6
  }
  let priority = @markdown.render_with_diagnostics(
    "Term\n: definition\n## Recovery\n: literal note", Map([]),
  )
  if priority.toc.length() != 1 || !priority.html.contains("<h2 id=\"recovery\">Recovery</h2>") {
    return -7
  }
  if @markdown.render("[Read \\] notes](/guide).", Map([])) !=
    "<p><a href=\"/guide\">Read ] notes</a>.</p>\n" {
    return -8
  }
  if @markdown.render("![Read \\] notes](/guide.png).", Map([])) !=
    "<p><img src=\"/guide.png\" alt=\"Read ] notes\" />.</p>\n" {
    return -9
  }
  if @markdown.render("Before.\n* * *\nAfter.", Map([])) !=
    "<p>Before.</p>\n<hr />\n<p>After.</p>\n" {
    return -10
  }
  if @markdown.render("~~~text title=example.txt\nhello\n~~~", Map([])) !=
    "<pre><code class=\"language-text\">hello</code></pre>\n" {
    return -11
  }
  if @markdown.render("~~~x\"\u000conmouseover=\"this.dataset.latticeProbe='executed'\nhello\n~~~", Map([])) !=
    "<pre><code class=\"language-x&quot;\u000conmouseover=&quot;this.dataset.latticeProbe='executed'\">hello</code></pre>\n" {
    return -12
  }
  if @markdown.render("_alpha_beta_gamma_delta_", Map([])) !=
    "<p><em>alpha_beta_gamma_delta</em></p>\n" {
    return -13
  }
  if @markdown.render("__alpha__beta__gamma__delta__", Map([])) !=
    "<p><strong>alpha__beta__gamma__delta</strong></p>\n" {
    return -14
  }
  if @markdown.render("<HTTPS://example.test/Guide>", Map([])) !=
    "<p><a href=\"HTTPS://example.test/Guide\">HTTPS://example.test/Guide</a></p>\n" {
    return -15
  }
  if @markdown.render("<https://example.test/a b>", Map([])) !=
    "<p>&lt;https://example.test/a b&gt;</p>\n" {
    return -16
  }
  let html = @markdown.render(fm.body, links)
  let navigation = @search.render_content_index_with_navigation(
    [@search.new_content_entry("Garden", "garden", "/garden/", [], "", "", "", "page", None, "body")],
    Map([]),
    Map([("/garden/", resolved)]),
  )
  let (_, _, hidden) = @markdown.render_with_text_sections(
    "<!--\n\n## Private heading\n\nprivate marker\n\n-->\n\n## Public\n\nvisible", Map([]),
  )
  let (_, _, references) = @markdown.render_with_text_sections(
    "## Recovery\nSee procedure[^1].\n\n[^1]: Restore encrypted snapshots.", Map([]),
  )
  if !hidden.is_empty() || references.length() != 2 { return -3 }
  if references[1].heading != "Footnotes" ||
    !references[1].body.contains("Restore encrypted snapshots.") { return -4 }
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
      {
        name: "aliases",
        field_type: @schema.TArray(@schema.TString(None, None)),
        required: false,
      },
    ],
  }
  let valid = match @frontmatter.parse("---\ntitle: 'Garden''s ''🌱'''\naliases: [3D printing, 2026 roadmap,]\n---\nA note.\n") {
    Ok(fm) => fm
    Err(_) => return -1
  }
  guard valid.fields.get("title") is Some(@frontmatter.FStr(title)) else {
    return -3
  }
  if title != "Garden's '🌱'" { return -4 }
  guard valid.fields.get("aliases") is Some(@frontmatter.FArray(aliases)) else {
    return -5
  }
  if aliases.length() != 2 { return -6 }
  guard (aliases[0], aliases[1]) is
    (@frontmatter.FStr("3D printing"), @frontmatter.FStr("2026 roadmap")) else {
    return -7
  }
  let quoted = match @frontmatter.parse("---\naliases: ['Research, notes', 'Garden''s 🌱']\n---\n") {
    Ok(fm) => fm
    Err(_) => return -8
  }
  guard quoted.fields.get("aliases") is Some(@frontmatter.FArray(items)) else {
    return -9
  }
  if items.length() != 2 { return -10 }
  guard (items[0], items[1]) is
    (@frontmatter.FStr("Research, notes"), @frontmatter.FStr("Garden's 🌱")) else {
    return -11
  }
  let commented = match @frontmatter.parse("---\nfeatured: false # explanation\ntitle: 'Keep # literal' # title\n---\n") {
    Ok(fm) => fm
    Err(_) => return -12
  }
  guard (commented.fields.get("featured"), commented.fields.get("title")) is
    (Some(@frontmatter.FBool(false)), Some(@frontmatter.FStr("Keep # literal"))) else {
    return -13
  }
  let bom = match @frontmatter.parse("\ufeff---\ntitle: Garden\n---\nBody.\n") {
    Ok(fm) => fm
    Err(_) => return -14
  }
  guard bom.fields.get("title") is Some(@frontmatter.FStr("Garden")) else {
    return -15
  }
  let capitals = match @frontmatter.parse("---\nfeatured: True\nextra: FALSE\n---\n") {
    Ok(fm) => fm
    Err(_) => return -16
  }
  guard (capitals.fields.get("featured"), capitals.fields.get("extra")) is
    (Some(@frontmatter.FBool(true)), Some(@frontmatter.FBool(false))) else {
    return -17
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
  let quoted_tpl = match @template.parse_template(
    "{{page.optional | default \"Read \\\"A|B\\\"\" | upper}}",
  ) {
    Ok(tpl) => tpl
    Err(_) => return -7
  }
  let quoted_fallback = match @template.render_template(quoted_tpl, slots, fields) {
    Ok(html) => html
    Err(_) => return -8
  }
  let unicode_tpl = match @template.parse_template("{{page.title | truncate 1}}") {
    Ok(tpl) => tpl
    Err(_) => return -9
  }
  fields.set("title", "🌱x")
  let unicode_truncated = match @template.render_template(unicode_tpl, slots, fields) {
    Ok(html) => html
    Err(_) => return -10
  }
  fields.set("title", "🌱")
  let unicode_intact = match @template.render_template(unicode_tpl, slots, fields) {
    Ok(html) => html
    Err(_) => return -11
  }
  let (rendered, boundary) = @markdown.render_with_leading_h1_boundary(
    "# 🌱 <math><mtext><title>literal </h1></title></mtext></math>\n\n# Later\n",
    Map([]),
  )
  let without_h1 = match boundary {
    Some(end) => rendered.html[end:].to_owned()
    None => rendered.html
  }
  if without_h1 == "<h1 id=\"later\">Later</h1>\n" &&
    unicode_truncated == "🌱..." && unicode_intact == "🌱" &&
    quoted_fallback == "READ \"A|B\"" &&
    local_date == "29" && invalid_date == "Undated" &&
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
