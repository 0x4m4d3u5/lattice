///|
/// Lattice slug — filename-to-URL-slug conversion.
///
/// Structural property: slug generation is a pure, total function. Every
/// filename maps to exactly one slug, every slug maps to exactly one output
/// path. No ambiguity, no runtime surprises, no collision detection needed.

///|
/// Convert a markdown filename to a URL slug.
///
/// Rules:
///   - Strip the .md extension (if present, case-insensitive)
///   - Lowercase all ASCII uppercase letters
///   - Transliterate common Latin accented characters to ASCII (café → cafe)
///   - Replace spaces and underscores with hyphens
///
/// Examples:
///   "hello-world.md"   → "hello-world"
///   "My Post.md"       → "my-post"
///   "index.md"         → "index"
///   "about_me.md"      → "about-me"
///   "GUIDE.MD"         → "guide"
///   "café.md"          → "cafe"
///   "Ångström.md"      → "angstrom"
pub fn filename_to_slug(filename : String) -> String {
  // Strip .md extension (case-insensitive) by limiting the character count
  let lower = filename.to_lower()
  let end = if lower.has_suffix(".md") {
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
/// Transliterate a Latin precomposed character to ASCII equivalents.
///
/// Returns a string: single char for most mappings ("a"), multi-char for
/// æ→"ae", œ→"oe", ß→"ss". Returns the original character unchanged if
/// no transliteration is defined.
fn transliterate_latin(c : Char) -> String {
  let cp = c.to_int()
  // Lowercase Latin accented
  if cp >= 0xE0 && cp <= 0xE5 {
    // à á â ã ä å → "a"
    "a"
  } else if cp == 0xE6 {
    // æ → "ae"
    "ae"
  } else if cp == 0xE7 {
    // ç → "c"
    "c"
  } else if cp >= 0xE8 && cp <= 0xEB {
    // è é ê ë → "e"
    "e"
  } else if cp >= 0xEC && cp <= 0xEF {
    // ì í î ï → "i"
    "i"
  } else if cp == 0xF1 {
    // ñ → "n"
    "n"
  } else if cp >= 0xF2 && cp <= 0xF6 {
    // ò ó ô õ ö → "o"
    "o"
  } else if cp == 0xF8 {
    // ø → "o"
    "o"
  } else if cp >= 0xF9 && cp <= 0xFC {
    // ù ú û ü → "u"
    "u"
  } else if cp == 0xFD || cp == 0xFF {
    // ý ÿ → "y"
    "y"
  } else if cp == 0xDF {
    // ß → "ss"
    "ss"
  }
  // Uppercase Latin accented (map directly to lowercase ASCII)
  else if cp >= 0xC0 && cp <= 0xC5 {
    // À Á Â Ã Ä Å → "a"
    "a"
  } else if cp == 0xC6 {
    // Æ → "ae"
    "ae"
  } else if cp == 0xC7 {
    // Ç → "c"
    "c"
  } else if cp >= 0xC8 && cp <= 0xCB {
    // È É Ê Ë → "e"
    "e"
  } else if cp >= 0xCC && cp <= 0xCF {
    // Ì Í Î Ï → "i"
    "i"
  } else if cp == 0xD1 {
    // Ñ → "n"
    "n"
  } else if cp >= 0xD2 && cp <= 0xD6 {
    // Ò Ó Ô Õ Ö → "o"
    "o"
  } else if cp == 0xD8 {
    // Ø → "o"
    "o"
  } else if cp >= 0xD9 && cp <= 0xDC {
    // Ù Ú Û Ü → "u"
    "u"
  } else if cp == 0xDD {
    // Ý → "y"
    "y"
  }
  // Latin Extended: œ (U+0153), Œ (U+0152)
  else if cp == 0x153 {
    "oe"
  } else if cp == 0x152 {
    "oe"
  } else {
    // Not a recognized Latin accented char — return as-is
    let buf = StringBuilder::new()
    buf.write_char(c)
    buf.to_string()
  }
}

///|
fn slugify_n(s : String, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  while i < end {
    let c = @strutil.char_at(s, i)
    if c == ' ' || c == '_' {
      buf.write_char('-')
    } else if c >= 'A' && c <= 'Z' {
      // Lowercase: ASCII uppercase → lowercase offset by 32
      buf.write_char((c.to_int() + 32).unsafe_to_char())
    } else if c.to_int() > 0x7F {
      // Non-ASCII: attempt Latin transliteration
      buf.write_string(transliterate_latin(c))
    } else {
      buf.write_char(c)
    }
    i = i + 1
  }
  buf.to_string()
}
