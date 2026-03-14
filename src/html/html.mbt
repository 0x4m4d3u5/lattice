///|
/// HTML page emitter for lattice.
///
/// Wraps a rendered HTML body fragment in a complete HTML5 document.
/// The emitter is pure — it takes pre-rendered body HTML and page metadata.
/// No markdown parsing or wikilink resolution happens here.

///|
/// Metadata for a rendered page.
pub(all) struct PageMeta {
  title : String
  description : String? // rendered into <meta name="description">
  lang : String // HTML lang attribute; defaults to "en" if empty
  stylesheet : String? // optional <link rel="stylesheet"> href
}

// ── helpers ───────────────────────────────────────────────────────────────────

///|
fn char_at_html(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

///|
/// Escape text for HTML body context (&, <, >).
fn escape_html_body(s : String) -> String {
  let buf = StringBuilder::new()
  let n = s.length()
  let mut i = 0
  while i < n {
    let c = char_at_html(s, i)
    if c == '&' {
      buf.write_string("&amp;")
    } else if c == '<' {
      buf.write_string("&lt;")
    } else if c == '>' {
      buf.write_string("&gt;")
    } else {
      buf.write_char(c)
    }
    i = i + 1
  }
  buf.to_string()
}

///|
/// Escape text for HTML attribute context (&, <, >, ").
fn escape_html_attr(s : String) -> String {
  let buf = StringBuilder::new()
  let n = s.length()
  let mut i = 0
  while i < n {
    let c = char_at_html(s, i)
    if c == '&' {
      buf.write_string("&amp;")
    } else if c == '<' {
      buf.write_string("&lt;")
    } else if c == '>' {
      buf.write_string("&gt;")
    } else if c == '"' {
      buf.write_string("&quot;")
    } else {
      buf.write_char(c)
    }
    i = i + 1
  }
  buf.to_string()
}

// ── public API ────────────────────────────────────────────────────────────────

///|
/// Render a full HTML5 page document.
///
/// `meta.lang` defaults to "en" when empty.
/// `meta.description` renders as a `<meta name="description">` tag.
/// `meta.stylesheet` renders as a `<link rel="stylesheet">` tag.
/// `body_html` is injected verbatim between `<body>` and `</body>`.
pub fn render_page(meta : PageMeta, body_html : String) -> String {
  let lang = if meta.lang.length() > 0 { meta.lang } else { "en" }
  let desc_tag = match meta.description {
    Some(d) =>
      "  <meta name=\"description\" content=\"" +
      escape_html_attr(d) +
      "\" />\n"
    None => ""
  }
  let style_tag = match meta.stylesheet {
    Some(href) =>
      "  <link rel=\"stylesheet\" href=\"" + escape_html_attr(href) + "\" />\n"
    None => ""
  }
  "<!doctype html>\n" +
  "<html lang=\"" +
  escape_html_attr(lang) +
  "\">\n" +
  "<head>\n" +
  "  <meta charset=\"utf-8\" />\n" +
  "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />\n" +
  "  <title>" +
  escape_html_body(meta.title) +
  "</title>\n" +
  desc_tag +
  style_tag +
  "</head>\n" +
  "<body>\n" +
  body_html +
  "</body>\n" +
  "</html>\n"
}

///|
/// Render an HTML anchor tag.
pub fn anchor(href : String, text : String) -> String {
  "<a href=\"" +
  escape_html_attr(href) +
  "\">" +
  escape_html_body(text) +
  "</a>"
}

///|
/// Render a nav element wrapping a list of (href, label) pairs.
pub fn nav_links(links : Array[(String, String)]) -> String {
  if links.length() == 0 {
    return ""
  }
  let buf = StringBuilder::new()
  buf.write_string("<nav>\n<ul>\n")
  let mut i = 0
  while i < links.length() {
    let (href, label) = links[i]
    buf.write_string("<li>")
    buf.write_string(anchor(href, label))
    buf.write_string("</li>\n")
    i = i + 1
  }
  buf.write_string("</ul>\n</nav>\n")
  buf.to_string()
}
