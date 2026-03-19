///|
/// robots.txt rendering for lattice.
///
/// Generates a robots.txt file that allows all crawlers and optionally
/// includes a Sitemap directive pointing to the site's sitemap.xml.

///|
/// Render a robots.txt document from site configuration.
///
/// # Arguments
///
/// * `base_url` - The site's base URL (e.g., "https://example.com")
/// * `robots_txt_enabled` - Whether to generate robots.txt (config field)
///
/// # Returns
///
/// A robots.txt string with the following format:
/// ```text
/// User-agent: *
/// Allow: /
/// Sitemap: https://example.com/sitemap.xml
/// ```
///
/// The Sitemap directive is only included when `base_url` is non-empty.
/// If `robots_txt_enabled` is false, returns an empty string.
pub fn render_robots_txt(
  base_url : String,
  robots_txt_enabled : Bool,
) -> String {
  if not(robots_txt_enabled) {
    return ""
  }

  let buf = StringBuilder::new()
  
  // Standard robots.txt header - allow all crawlers
  buf.write_string("User-agent: *\n")
  buf.write_string("Allow: /\n")
  
  // Add Sitemap directive only if base_url is present and non-trivial
  if base_url.length() > 0 {
    let normalized = normalize_base_url_robots(base_url)
    if normalized.length() > 0 {
      buf.write_string("Sitemap: ")
      buf.write_string(normalized)
      buf.write_string("/sitemap.xml\n")
    }
  }
  
  buf.to_string()
}

///|
/// Normalize base URL by removing trailing slashes.
///
/// This ensures the Sitemap URL is always in the form:
/// "https://example.com/sitemap.xml"
/// not "https://example.com//sitemap.xml"
fn normalize_base_url_robots(base_url : String) -> String {
  let trimmed = trim_robots(base_url)
  if trimmed == "/" {
    return ""
  }
  if trimmed.has_suffix("/") {
    let buf = StringBuilder::new()
    let mut i = 0
    let end_pos = trimmed.length() - 1
    while i < end_pos {
      buf.write_char(char_at_robots(trimmed, i))
      i = i + 1
    }
    return buf.to_string()
  }
  trimmed
}

///|
/// Trim whitespace from a string.
fn trim_robots(s : String) -> String {
  let n = s.length()
  let mut lo = 0
  while lo < n &&
        (
          char_at_robots(s, lo) == ' ' ||
          char_at_robots(s, lo) == '\t' ||
          char_at_robots(s, lo) == '\r'
        ) {
    lo = lo + 1
  }
  let mut hi = n
  while hi > lo &&
        (
          char_at_robots(s, hi - 1) == ' ' ||
          char_at_robots(s, hi - 1) == '\t' ||
          char_at_robots(s, hi - 1) == '\r'
        ) {
    hi = hi - 1
  }
  let buf = StringBuilder::new()
  let mut i = lo
  while i < hi {
    buf.write_char(char_at_robots(s, i))
    i = i + 1
  }
  buf.to_string()
}

///|
/// Get character at position (for string manipulation).
fn char_at_robots(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}
