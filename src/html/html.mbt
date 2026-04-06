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
  canonical_url : String? // absolute URL, renders as <link rel="canonical"> + og:url
  og_image : String? // absolute image URL, renders as og:image
  og_type : String? // Open Graph type; defaults to "article" when unset
  feed_url : String? // absolute Atom feed URL, renders as <link rel="alternate" type="application/atom+xml">
  structured_data : Array[StructuredData] // optional JSON-LD objects
}

///|
pub(all) struct BlogPostingData {
  headline : String
  description : String?
  url : String
  date_published : String?
  author : String?
  image : String?
}

///|
pub(all) struct BreadcrumbItemData {
  name : String
  item : String
}

///|
pub(all) struct BreadcrumbListData {
  items : Array[BreadcrumbItemData]
}

///|
pub(all) struct WebSiteData {
  name : String
  url : String
  description : String?
}

///|
pub(all) enum StructuredData {
  BlogPosting(BlogPostingData)
  BreadcrumbList(BreadcrumbListData)
  WebSite(WebSiteData)
}

// ── helpers ───────────────────────────────────────────────────────────────────

///|
/// Strip the first `<h1>...</h1>` block from an HTML string if the body
/// starts with it (after optional whitespace). Returns the body with the
/// leading H1 removed and trailing whitespace trimmed.
///
/// Used by the `body_no_h1` template slot to avoid duplicate H1 elements
/// when the template already renders the title as an H1.
pub fn strip_leading_h1(html : String) -> String {
  let n = html.length()
  // Skip leading whitespace
  let mut i = 0
  while i < n &&
        (
          @strutil.char_at(html, i) == ' ' ||
          @strutil.char_at(html, i) == '\t' ||
          @strutil.char_at(html, i) == '\n' ||
          @strutil.char_at(html, i) == '\r'
        ) {
    i = i + 1
  }
  // Check for "<h1>"
  let h1_open = "<h1>"
  let h1_open_len = h1_open.length()
  if i + h1_open_len > n {
    return html
  }
  let mut j = 0
  while j < h1_open_len {
    if @strutil.char_at(html, i + j) != @strutil.char_at(h1_open, j) {
      return html
    }
    j = j + 1
  }
  // Found "<h1>" at position i. Now find "</h1>"
  let after_open = i + h1_open_len
  let h1_close = "</h1>"
  let h1_close_len = h1_close.length()
  let mut k = after_open
  let mut found_close = -1
  while k + h1_close_len <= n {
    let mut matched = true
    let mut l = 0
    while l < h1_close_len {
      if @strutil.char_at(html, k + l) != @strutil.char_at(h1_close, l) {
        matched = false
        break
      }
      l = l + 1
    }
    if matched {
      found_close = k
      break
    }
    k = k + 1
  }
  if found_close < 0 {
    return html
  }
  // Return everything after "</h1>", trimmed of leading whitespace
  let rest_start = found_close + h1_close_len
  let mut m = rest_start
  while m < n &&
        (
          @strutil.char_at(html, m) == ' ' ||
          @strutil.char_at(html, m) == '\t' ||
          @strutil.char_at(html, m) == '\n' ||
          @strutil.char_at(html, m) == '\r'
        ) {
    m = m + 1
  }
  if m >= n {
    return ""
  }
  @strutil.substr(html, m, n)
}

///|
/// Render OG meta tags and canonical link for a page.
///
/// Generates Open Graph meta tags and a canonical `<link>` for use in `<head>`.
/// Returns the HTML fragment as a string. Used by the `head_meta` template slot.
///
/// `og_type` controls the `og:type` meta tag — use "website" for index/root
/// pages and "article" for collection/tag pages.
pub fn render_head_meta(
  title : String,
  description : String?,
  url : String,
  og_type? : String = "article",
) -> String {
  let tags = StringBuilder::new()
  tags.write_string("  <meta property=\"og:title\" content=\"")
  tags.write_string(@strutil.escape_html_attr(title))
  tags.write_string("\" />\n")
  match description {
    Some(desc) =>
      if desc.length() > 0 {
        tags.write_string("  <meta property=\"og:description\" content=\"")
        tags.write_string(@strutil.escape_html_attr(desc))
        tags.write_string("\" />\n")
      }
    None => ()
  }
  tags.write_string("  <meta property=\"og:url\" content=\"")
  tags.write_string(@strutil.escape_html_attr(url))
  tags.write_string("\" />\n")
  tags.write_string("  <meta property=\"og:type\" content=\"")
  tags.write_string(@strutil.escape_html_attr(og_type))
  tags.write_string("\" />\n")
  tags.write_string("  <link rel=\"canonical\" href=\"")
  tags.write_string(@strutil.escape_html_attr(url))
  tags.write_string("\" />\n")
  tags.to_string()
}

///|

///|
/// Escape text for HTML body context (&, <, >).
pub fn escape_html_body(s : String) -> String {
  @strutil.escape_html_body(s)
}

///|
/// Escape text for HTML attribute context (&, <, >, ").
pub fn escape_html_attr(s : String) -> String {
  @strutil.escape_html_attr(s)
}

///|
/// JSON-LD style string writer: escapes `<`, `>`, `&` as `\uXXXX` sequences
/// in addition to standard JSON escaping. Required for safe embedding in
/// HTML `<script type="application/ld+json">` blocks.
fn write_json_string_ld(buf : StringBuilder, s : String) -> Unit {
  buf.write_char('"')
  let n = s.length()
  let mut i = 0
  while i < n {
    let c = @strutil.char_at(s, i)
    if c == '\\' {
      buf.write_string("\\\\")
    } else if c == '"' {
      buf.write_string("\\\"")
    } else if c == '\n' {
      buf.write_string("\\n")
    } else if c == '\r' {
      buf.write_string("\\r")
    } else if c == '\t' {
      buf.write_string("\\t")
    } else if c == '<' {
      buf.write_string("\\u003c")
    } else if c == '>' {
      buf.write_string("\\u003e")
    } else if c == '&' {
      buf.write_string("\\u0026")
    } else if c.to_int() < 0x20 {
      buf.write_string("\\u00")
      buf.write_char(@strutil.hex_nibble(c.to_int() / 16))
      buf.write_char(@strutil.hex_nibble(c.to_int() % 16))
    } else {
      buf.write_char(c)
    }
    i = i + 1
  }
  buf.write_char('"')
}

///|
fn write_json_field_html(
  buf : StringBuilder,
  wrote_field : Bool,
  indent : String,
  key : String,
  value : String,
) -> Bool {
  if wrote_field {
    buf.write_string(",\n")
  } else {
    buf.write_char('\n')
  }
  buf.write_string(indent)
  write_json_string_ld(buf, key)
  buf.write_string(": ")
  write_json_string_ld(buf, value)
  true
}

///|
fn begin_json_object_field_html(
  buf : StringBuilder,
  wrote_field : Bool,
  indent : String,
  key : String,
) -> Bool {
  if wrote_field {
    buf.write_string(",\n")
  } else {
    buf.write_char('\n')
  }
  buf.write_string(indent)
  write_json_string_ld(buf, key)
  buf.write_string(": ")
  true
}

///|
fn write_json_int_field_html(
  buf : StringBuilder,
  wrote_field : Bool,
  indent : String,
  key : String,
  value : Int,
) -> Bool {
  if wrote_field {
    buf.write_string(",\n")
  } else {
    buf.write_char('\n')
  }
  buf.write_string(indent)
  write_json_string_ld(buf, key)
  buf.write_string(": ")
  buf.write_string(value.to_string())
  true
}

///|
fn render_blog_posting_json_ld(data : BlogPostingData) -> String {
  let buf = StringBuilder::new()
  buf.write_string("{")
  let mut wrote_field = false
  wrote_field = write_json_field_html(
    buf, wrote_field, "  ", "@context", "https://schema.org",
  )
  wrote_field = write_json_field_html(
    buf, wrote_field, "  ", "@type", "BlogPosting",
  )
  wrote_field = write_json_field_html(
    buf,
    wrote_field,
    "  ",
    "headline",
    data.headline,
  )
  wrote_field = write_json_field_html(buf, wrote_field, "  ", "url", data.url)
  wrote_field = begin_json_object_field_html(
    buf, wrote_field, "  ", "mainEntityOfPage",
  )
  buf.write_string("{\n    ")
  write_json_string_ld(buf, "@type")
  buf.write_string(": ")
  write_json_string_ld(buf, "WebPage")
  buf.write_string(",\n    ")
  write_json_string_ld(buf, "@id")
  buf.write_string(": ")
  write_json_string_ld(buf, data.url)
  buf.write_string("\n  }")
  match data.description {
    Some(description) =>
      wrote_field = write_json_field_html(
        buf, true, "  ", "description", description,
      )
    None => ()
  }
  match data.date_published {
    Some(date) =>
      wrote_field = write_json_field_html(
        buf, true, "  ", "datePublished", date,
      )
    None => ()
  }
  match data.image {
    Some(image) =>
      wrote_field = write_json_field_html(buf, true, "  ", "image", image)
    None => ()
  }
  match data.author {
    Some(author) => {
      if wrote_field {
        buf.write_string(",\n")
      } else {
        buf.write_char('\n')
      }
      buf.write_string("  ")
      write_json_string_ld(buf, "author")
      buf.write_string(": {\n    ")
      write_json_string_ld(buf, "@type")
      buf.write_string(": ")
      write_json_string_ld(buf, "Person")
      buf.write_string(",\n    ")
      write_json_string_ld(buf, "name")
      buf.write_string(": ")
      write_json_string_ld(buf, author)
      buf.write_string("\n  }")
      wrote_field = true
    }
    None => ()
  }
  if wrote_field {
    buf.write_char('\n')
  }
  buf.write_string("}")
  buf.to_string()
}

///|
fn render_breadcrumb_list_json_ld(data : BreadcrumbListData) -> String {
  let buf = StringBuilder::new()
  buf.write_string("{")
  let mut wrote_field = false
  wrote_field = write_json_field_html(
    buf, wrote_field, "  ", "@context", "https://schema.org",
  )
  wrote_field = write_json_field_html(
    buf, wrote_field, "  ", "@type", "BreadcrumbList",
  )
  wrote_field = begin_json_object_field_html(
    buf, wrote_field, "  ", "itemListElement",
  )
  if data.items.length() == 0 {
    buf.write_string("[]")
  } else {
    buf.write_string("[\n")
    let mut i = 0
    while i < data.items.length() {
      if i > 0 {
        buf.write_string(",\n")
      }
      let item = data.items[i]
      buf.write_string("    {\n")
      let mut wrote_item_field = false
      wrote_item_field = write_json_field_html(
        buf, wrote_item_field, "      ", "@type", "ListItem",
      )
      wrote_item_field = write_json_int_field_html(
        buf,
        wrote_item_field,
        "      ",
        "position",
        i + 1,
      )
      wrote_item_field = write_json_field_html(
        buf,
        wrote_item_field,
        "      ",
        "name",
        item.name,
      )
      wrote_item_field = write_json_field_html(
        buf,
        wrote_item_field,
        "      ",
        "item",
        item.item,
      )
      if wrote_item_field {
        buf.write_char('\n')
      }
      buf.write_string("    }")
      i = i + 1
    }
    buf.write_string("\n  ]")
  }
  if wrote_field {
    buf.write_char('\n')
  }
  buf.write_string("}")
  buf.to_string()
}

///|
fn render_website_json_ld(data : WebSiteData) -> String {
  let buf = StringBuilder::new()
  buf.write_string("{")
  let mut wrote_field = false
  wrote_field = write_json_field_html(
    buf, wrote_field, "  ", "@context", "https://schema.org",
  )
  wrote_field = write_json_field_html(
    buf, wrote_field, "  ", "@type", "WebSite",
  )
  wrote_field = write_json_field_html(buf, wrote_field, "  ", "name", data.name)
  wrote_field = write_json_field_html(buf, wrote_field, "  ", "url", data.url)
  match data.description {
    Some(description) =>
      wrote_field = write_json_field_html(
        buf, wrote_field, "  ", "description", description,
      )
    None => ()
  }
  if wrote_field {
    buf.write_char('\n')
  }
  buf.write_string("}")
  buf.to_string()
}

///|
fn render_structured_data_json(data : StructuredData) -> String {
  match data {
    BlogPosting(v) => render_blog_posting_json_ld(v)
    BreadcrumbList(v) => render_breadcrumb_list_json_ld(v)
    WebSite(v) => render_website_json_ld(v)
  }
}

///|
pub fn render_structured_data_script(items : Array[StructuredData]) -> String {
  if items.length() == 0 {
    return ""
  }
  let buf = StringBuilder::new()
  buf.write_string("  <script type=\"application/ld+json\">\n")
  if items.length() == 1 {
    buf.write_string(render_structured_data_json(items[0]))
  } else {
    buf.write_string("[\n")
    let mut i = 0
    while i < items.length() {
      if i > 0 {
        buf.write_string(",\n")
      }
      let json = render_structured_data_json(items[i])
      let mut j = 0
      while j < json.length() {
        if j == 0 || @strutil.char_at(json, j - 1) == '\n' {
          buf.write_string("  ")
        }
        buf.write_char(@strutil.char_at(json, j))
        j = j + 1
      }
      i = i + 1
    }
    buf.write_string("\n]")
  }
  buf.write_string("\n  </script>\n")
  buf.to_string()
}

///|
pub fn inject_head_markup(document_html : String, markup : String) -> String {
  if markup.length() == 0 {
    return document_html
  }
  let needle = "</head>"
  let mut i = 0
  while i + needle.length() <= document_html.length() {
    let mut matched = true
    let mut j = 0
    while j < needle.length() {
      if @strutil.char_at(document_html, i + j) != @strutil.char_at(needle, j) {
        matched = false
        j = needle.length()
      } else {
        j = j + 1
      }
    }
    if matched {
      return @strutil.substr(document_html, 0, i) +
        markup +
        @strutil.substr(document_html, i, document_html.length())
    }
    i = i + 1
  }
  document_html
}

///|
/// Render an Atom feed autodiscovery link tag.
pub fn render_feed_link_tag(title : String, feed_url : String) -> String {
  "  <link rel=\"alternate\" type=\"application/atom+xml\" title=\"" +
  @strutil.escape_html_attr(title) +
  "\" href=\"" +
  @strutil.escape_html_attr(feed_url) +
  "\" />\n"
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
      @strutil.escape_html_attr(d) +
      "\" />\n"
    None => ""
  }
  let style_tag = match meta.stylesheet {
    Some(href) =>
      "  <link rel=\"stylesheet\" href=\"" +
      @strutil.escape_html_attr(href) +
      "\" />\n"
    None => ""
  }
  let effective_og_type = match meta.og_type {
    Some(t) if t.length() > 0 => t
    _ => "article"
  }
  let social_tags = match meta.canonical_url {
    Some(url) => {
      let og_desc = match meta.description {
        Some(d) =>
          "  <meta property=\"og:description\" content=\"" +
          @strutil.escape_html_attr(d) +
          "\" />\n"
        None => ""
      }
      let og_img = match meta.og_image {
        Some(img) =>
          "  <meta property=\"og:image\" content=\"" +
          @strutil.escape_html_attr(img) +
          "\" />\n"
        None => ""
      }
      let feed_tag = match meta.feed_url {
        Some(feed) =>
          "  <link rel=\"alternate\" type=\"application/atom+xml\" title=\"" +
          @strutil.escape_html_attr(meta.title) +
          "\" href=\"" +
          @strutil.escape_html_attr(feed) +
          "\" />\n"
        None => ""
      }
      let tw_desc = match meta.description {
        Some(d) =>
          "  <meta name=\"twitter:description\" content=\"" +
          @strutil.escape_html_attr(d) +
          "\" />\n"
        None => ""
      }
      let tw_img = match meta.og_image {
        Some(img) =>
          "  <meta name=\"twitter:image\" content=\"" +
          @strutil.escape_html_attr(img) +
          "\" />\n"
        None => ""
      }
      let tw_card = match meta.og_image {
        Some(_) => "summary_large_image"
        None => "summary"
      }
      "  <link rel=\"canonical\" href=\"" +
      @strutil.escape_html_attr(url) +
      "\" />\n" +
      "  <meta property=\"og:type\" content=\"" +
      @strutil.escape_html_attr(effective_og_type) +
      "\" />\n" +
      "  <meta property=\"og:title\" content=\"" +
      @strutil.escape_html_attr(meta.title) +
      "\" />\n" +
      og_desc +
      "  <meta property=\"og:url\" content=\"" +
      @strutil.escape_html_attr(url) +
      "\" />\n" +
      og_img +
      feed_tag +
      "  <meta name=\"twitter:card\" content=\"" +
      tw_card +
      "\" />\n" +
      "  <meta name=\"twitter:title\" content=\"" +
      @strutil.escape_html_attr(meta.title) +
      "\" />\n" +
      tw_desc +
      tw_img
    }
    None => ""
  }
  let structured_data_script = render_structured_data_script(
    meta.structured_data,
  )
  "<!doctype html>\n" +
  "<html lang=\"" +
  @strutil.escape_html_attr(lang) +
  "\">\n" +
  "<head>\n" +
  "  <meta charset=\"utf-8\" />\n" +
  "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />\n" +
  "  <title>" +
  @strutil.escape_html_body(meta.title) +
  "</title>\n" +
  desc_tag +
  social_tags +
  structured_data_script +
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
  @strutil.escape_html_attr(href) +
  "\">" +
  @strutil.escape_html_body(text) +
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
