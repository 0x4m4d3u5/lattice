///|
/// Sitemap XML rendering for lattice.
///
/// The renderer is pure: it accepts typed page graph input and returns XML.

///|
fn sitemap_priority_for(slug : String) -> String {
  if slug == "index" {
    "0.8"
  } else {
    "0.6"
  }
}

///|
/// Normalize a raw date string to a W3C Datetime value suitable for lastmod.
///
/// Accepts YYYY-MM-DD (returned as-is) or a structurally validated RFC3339
/// timestamp. Returns None for empty, missing, or malformed input.
///
/// Structural decision: RFC3339 timestamps are validated structurally
/// (digit-by-digit, range-checked) rather than accepted by heuristic suffix
/// matching ("ends with Z"). This prevents garbage strings like
/// "20garbage1234567890Z" from leaking into the sitemap.
fn normalize_lastmod(raw : String?) -> String? {
  match raw {
    None => None
    Some(date_text) => {
      let s = @strutil.trim_h(date_text)
      if s.length() == 0 {
        return None
      }
      // YYYY-MM-DD
      if s.length() == 10 {
        if @strutil.is_valid_iso8601_date(s) {
          Some(s)
        } else {
          None
        }
      } else if @strutil.is_rfc3339_datetime(s) {
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
    let loc = @strutil.absolute_url(base_url, page.url)
    buf.write_string("  <url>\n")
    buf.write_string("    <loc>")
    buf.write_string(@strutil.escape_html_body(loc))
    buf.write_string("</loc>\n")
    match normalize_lastmod(page.date) {
      Some(lastmod) => {
        buf.write_string("    <lastmod>")
        buf.write_string(@strutil.escape_html_body(lastmod))
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
