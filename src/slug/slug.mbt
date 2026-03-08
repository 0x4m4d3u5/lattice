///|
/// Lattice slug — filename-to-URL-slug conversion.
///
/// Structural property: slug generation is a pure, total function. Every
/// filename maps to exactly one slug, every slug maps to exactly one output
/// path. No ambiguity, no runtime surprises, no collision detection needed.

///|
fn char_at(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

///|
/// Convert a markdown filename to a URL slug.
///
/// Rules:
///   - Strip the .md extension (if present)
///   - Lowercase all ASCII uppercase letters
///   - Replace spaces and underscores with hyphens
///
/// Examples:
///   "hello-world.md"   → "hello-world"
///   "My Post.md"       → "my-post"
///   "index.md"         → "index"
///   "about_me.md"      → "about-me"
pub fn filename_to_slug(filename : String) -> String {
  // Strip .md extension by limiting the character count we pass to slugify.
  let end = if filename.has_suffix(".md") {
    filename.length() - 3
  } else {
    filename.length()
  }
  slugify_n(filename, end)
}

///|
/// Convert a slug to a root-relative URL path with trailing slash.
///
/// "hello-world" → "/hello-world/"
/// "index"       → "/index/"
pub fn slug_to_url(slug : String) -> String {
  "/" + slug + "/"
}

///|
fn slugify_n(s : String, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  while i < end {
    let c = char_at(s, i)
    if c == ' ' || c == '_' {
      buf.write_char('-')
    } else if c >= 'A' && c <= 'Z' {
      // Lowercase: ASCII uppercase → lowercase offset by 32
      buf.write_char((c.to_int() + 32).unsafe_to_char())
    } else {
      buf.write_char(c)
    }
    i = i + 1
  }
  buf.to_string()
}
