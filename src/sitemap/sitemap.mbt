///|
/// Sitemap XML rendering for lattice.
///
/// The renderer is pure: it accepts typed page graph input and returns XML.

fn char_at_sitemap(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

fn escape_xml_text(s : String) -> String {
  let buf = StringBuilder::new()
  let n = s.length()
  let mut i = 0
  while i < n {
    let c = char_at_sitemap(s, i)
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

fn trim_sitemap(s : String) -> String {
  let n = s.length()
  let mut lo = 0
  while lo < n &&
    (char_at_sitemap(s, lo) == ' ' ||
      char_at_sitemap(s, lo) == '\t' ||
      char_at_sitemap(s, lo) == '\r') {
    lo = lo + 1
  }
  let mut hi = n
  while hi > lo &&
    (char_at_sitemap(s, hi - 1) == ' ' ||
      char_at_sitemap(s, hi - 1) == '\t' ||
      char_at_sitemap(s, hi - 1) == '\r') {
    hi = hi - 1
  }
  let buf = StringBuilder::new()
  let mut i = lo
  while i < hi {
    buf.write_char(char_at_sitemap(s, i))
    i = i + 1
  }
  buf.to_string()
}

fn normalize_base_url_sitemap(base_url : String) -> String {
  let trimmed = trim_sitemap(base_url)
  if trimmed == "/" {
    return ""
  }
  if trimmed.has_suffix("/") {
    let buf = StringBuilder::new()
    let mut i = 0
    let end_pos = trimmed.length() - 1
    while i < end_pos {
      buf.write_char(char_at_sitemap(trimmed, i))
      i = i + 1
    }
    return buf.to_string()
  }
  trimmed
}

fn absolute_url_sitemap(base_url : String, path : String) -> String {
  let base = normalize_base_url_sitemap(base_url)
  if base.length() == 0 {
    return path
  }
  if path.length() == 0 {
    return base
  }
  if char_at_sitemap(path, 0) == '/' {
    base + path
  } else {
    base + "/" + path
  }
}

fn sitemap_priority_for(slug : String) -> String {
  if slug == "index" {
    "0.8"
  } else {
    "0.6"
  }
}

///|
/// Render a sitemap.xml document from typed graph pages.
pub fn render_sitemap(base_url : String, pages : Array[@graph.GraphPage]) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
  buf.write_string("<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n")

  let mut i = 0
  while i < pages.length() {
    let page = pages[i]
    let loc = absolute_url_sitemap(base_url, page.url)
    buf.write_string("  <url>\n")
    buf.write_string("    <loc>")
    buf.write_string(escape_xml_text(loc))
    buf.write_string("</loc>\n")
    buf.write_string("    <changefreq>weekly</changefreq>\n")
    buf.write_string("    <priority>")
    buf.write_string(sitemap_priority_for(page.slug))
    buf.write_string("</priority>\n")
    buf.write_string("  </url>\n")
    i = i + 1
  }

  buf.write_string("</urlset>\n")
  buf.to_string()
}
