///|
/// Sitemap XML rendering for lattice.
///
/// The renderer is pure: it accepts typed page graph input and returns XML.
fn char_at_sitemap(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

///|
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

///|
fn trim_sitemap(s : String) -> String {
  let n = s.length()
  let mut lo = 0
  while lo < n &&
        (
          char_at_sitemap(s, lo) == ' ' ||
          char_at_sitemap(s, lo) == '\t' ||
          char_at_sitemap(s, lo) == '\r'
        ) {
    lo = lo + 1
  }
  let mut hi = n
  while hi > lo &&
        (
          char_at_sitemap(s, hi - 1) == ' ' ||
          char_at_sitemap(s, hi - 1) == '\t' ||
          char_at_sitemap(s, hi - 1) == '\r'
        ) {
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

///|
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

///|
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

///|
fn sitemap_priority_for(slug : String) -> String {
  if slug == "index" {
    "0.8"
  } else {
    "0.6"
  }
}

///|
fn is_digit_sitemap(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
/// Normalize a raw date string to a W3C Datetime value suitable for lastmod.
///
/// Accepts YYYY-MM-DD (returned as-is) or a RFC3339 timestamp ending in Z
/// (returned as-is). Returns None for empty, missing, or malformed input.
fn normalize_lastmod(raw : String?) -> String? {
  match raw {
    None => None
    Some(date_text) => {
      let s = trim_sitemap(date_text)
      if s.length() == 0 {
        return None
      }
      // YYYY-MM-DD
      if s.length() == 10 {
        if char_at_sitemap(s, 4) != '-' || char_at_sitemap(s, 7) != '-' {
          return None
        }
        let mut all_digits = true
        let mut k = 0
        while k < 10 {
          if k != 4 && k != 7 {
            if not(is_digit_sitemap(char_at_sitemap(s, k))) {
              all_digits = false
            }
          }
          k = k + 1
        }
        if all_digits {
          Some(s)
        } else {
          None
        }
      } else if s.length() >= 20 && s.has_suffix("Z") {
        // RFC3339 / ISO 8601 with Z suffix
        Some(s)
      } else {
        None
      }
    }
  }
}

///|
/// Render a sitemap.xml document from typed graph pages.
pub fn render_sitemap(
  base_url : String,
  pages : Array[@graph.GraphPage],
) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
  buf.write_string(
    "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n",
  )

  let mut i = 0
  while i < pages.length() {
    let page = pages[i]
    let loc = absolute_url_sitemap(base_url, page.url)
    buf.write_string("  <url>\n")
    buf.write_string("    <loc>")
    buf.write_string(escape_xml_text(loc))
    buf.write_string("</loc>\n")
    match normalize_lastmod(page.date) {
      Some(lastmod) => {
        buf.write_string("    <lastmod>")
        buf.write_string(escape_xml_text(lastmod))
        buf.write_string("</lastmod>\n")
      }
      None => ()
    }
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
