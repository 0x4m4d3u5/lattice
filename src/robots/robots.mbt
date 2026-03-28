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
    let normalized = @strutil.normalize_base_url(base_url)
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

///|
/// Trim whitespace from a string.

///|
/// Get character at position (for string manipulation).
