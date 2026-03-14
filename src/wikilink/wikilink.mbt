///|
/// Wikilink resolution and validation.
///
/// Wikilinks (`[[target]]` or `[[target|display]]`) are resolved against the
/// content graph at build time. A link to a non-existent page is a build error,
/// not a 404. The resolved link carries the target page's canonical URL so
/// the render step never needs to do path arithmetic.

///|
/// A raw wikilink extracted from markdown source.
pub struct RawWikilink {
  target : String
  display : String? // None means use target as display text
  source_file : String
}

///|
/// A resolved wikilink with a validated target URL.
pub struct ResolvedWikilink {
  raw : RawWikilink
  url : String
  title : String
}

///|
/// Resolution error: the target did not match any content page.
pub struct ResolutionError {
  link : RawWikilink
  message : String
}

// ── helpers ───────────────────────────────────────────────────────────────────

///|
fn char_at_wl(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

///|
fn slugify_lookup_key_wl(s : String, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  while i < end {
    let c = char_at_wl(s, i)
    if c == ' ' || c == '_' {
      buf.write_char('-')
    } else if c >= 'A' && c <= 'Z' {
      buf.write_char((c.to_int() + 32).unsafe_to_char())
    } else {
      buf.write_char(c)
    }
    i = i + 1
  }
  buf.to_string()
}

///|
/// Canonical lookup key for wikilink targets.
pub fn lookup_key(target : String) -> String {
  let end = if target.has_suffix(".md") {
    target.length() - 3
  } else {
    target.length()
  }
  slugify_lookup_key_wl(target, end)
}

///|
fn substr_wl(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = start
  while i < end {
    buf.write_char(char_at_wl(s, i))
    i = i + 1
  }
  buf.to_string()
}

///|
fn trim_wl(s : String) -> String {
  let n = s.length()
  if n == 0 {
    return s
  }
  let mut lo = 0
  while lo < n && (char_at_wl(s, lo) == ' ' || char_at_wl(s, lo) == '\t') {
    lo = lo + 1
  }
  let mut hi = n
  while hi > lo &&
        (char_at_wl(s, hi - 1) == ' ' || char_at_wl(s, hi - 1) == '\t') {
    hi = hi - 1
  }
  substr_wl(s, lo, hi)
}

///|
/// Parse the inner text of `[[...]]` into target + optional display.
fn parse_inner(inner : String, source_file : String) -> RawWikilink {
  let n = inner.length()
  let mut pipe = -1
  let mut i = 0
  while i < n {
    if char_at_wl(inner, i) == '|' {
      pipe = i
      break
    }
    i = i + 1
  }
  if pipe >= 0 {
    let target = trim_wl(substr_wl(inner, 0, pipe))
    let display = trim_wl(substr_wl(inner, pipe + 1, n))
    { target, display: Some(display), source_file }
  } else {
    { target: trim_wl(inner), display: None, source_file }
  }
}

// ── public API ────────────────────────────────────────────────────────────────

///|
/// Extract all wikilinks from a markdown string.
/// `source_file` is the path of the containing file, embedded in each link
/// for error reporting during resolution.
pub fn extract(content : String, source_file : String) -> Array[RawWikilink] {
  let links : Array[RawWikilink] = []
  let n = content.length()
  let mut i = 0
  let mut in_fence = false
  let mut in_inline = false
  let mut line_start = true
  while i + 1 < n {
    if line_start {
      let mut probe = i
      while probe < n &&
            (
              char_at_wl(content, probe) == ' ' ||
              char_at_wl(content, probe) == '\t'
            ) {
        probe = probe + 1
      }
      if probe + 2 < n &&
        char_at_wl(content, probe) == '`' &&
        char_at_wl(content, probe + 1) == '`' &&
        char_at_wl(content, probe + 2) == '`' {
        in_fence = not(in_fence)
      }
      line_start = false
    }
    if char_at_wl(content, i) == '\n' {
      line_start = true
      if not(in_fence) {
        in_inline = false
      }
      i = i + 1
    } else if not(in_fence) && char_at_wl(content, i) == '`' {
      in_inline = not(in_inline)
      i = i + 1
    } else if not(in_fence) &&
      not(in_inline) &&
      char_at_wl(content, i) == '[' &&
      char_at_wl(content, i + 1) == '[' {
      let inner_start = i + 2
      let mut j = inner_start
      let mut found = false
      while j + 1 < n {
        if char_at_wl(content, j) == ']' && char_at_wl(content, j + 1) == ']' {
          let inner = substr_wl(content, inner_start, j)
          let link = parse_inner(inner, source_file)
          if link.target.length() > 0 {
            links.push(link)
          }
          i = j + 2
          found = true
          break
        }
        j = j + 1
      }
      if not(found) {
        i = i + 1
      }
    } else {
      i = i + 1
    }
  }
  links
}

///|
/// Resolve wikilinks against a page index (slug → url map).
/// Returns resolved links and any links whose targets are not in the index.
///
/// Structural guarantee: unresolved links are returned as hard errors, not
/// silently converted to dead hrefs. The caller decides whether to abort
/// the build or collect them for reporting.
pub fn resolve(
  links : Array[RawWikilink],
  index : Map[String, String],
) -> (Array[ResolvedWikilink], Array[ResolutionError]) {
  let resolved : Array[ResolvedWikilink] = []
  let errors : Array[ResolutionError] = []
  let mut i = 0
  while i < links.length() {
    let link = links[i]
    match index.get(lookup_key(link.target)) {
      Some(url) => {
        let title = match link.display {
          Some(d) => d
          None => link.target
        }
        resolved.push({ raw: link, url, title })
      }
      None =>
        errors.push({
          link,
          message: "target '" + link.target + "' not found in page index",
        })
    }
    i = i + 1
  }
  (resolved, errors)
}
