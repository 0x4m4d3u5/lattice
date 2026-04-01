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
/// Canonical lookup key for wikilink targets.
pub fn lookup_key(target : String) -> String {
  @slug.filename_to_slug(target)
}

///|
/// Parse the inner text of `[[...]]` into target + optional display.
fn parse_inner(inner : String, source_file : String) -> RawWikilink {
  let n = inner.length()
  let mut pipe = -1
  let mut i = 0
  while i < n {
    if @strutil.char_at(inner, i) == '|' {
      pipe = i
      break
    }
    i = i + 1
  }
  if pipe >= 0 {
    let target = @strutil.trim(@strutil.substr(inner, 0, pipe))
    let display = @strutil.trim(@strutil.substr(inner, pipe + 1, n))
    { target, display: Some(display), source_file }
  } else {
    { target: @strutil.trim(inner), display: None, source_file }
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
              @strutil.char_at(content, probe) == ' ' ||
              @strutil.char_at(content, probe) == '\t'
            ) {
        probe = probe + 1
      }
      if probe + 2 < n &&
        @strutil.char_at(content, probe) == '`' &&
        @strutil.char_at(content, probe + 1) == '`' &&
        @strutil.char_at(content, probe + 2) == '`' {
        in_fence = !in_fence
      }
      line_start = false
    }
    if @strutil.char_at(content, i) == '\n' {
      line_start = true
      if !in_fence {
        in_inline = false
      }
      i = i + 1
    } else if !in_fence && @strutil.char_at(content, i) == '`' {
      in_inline = !in_inline
      i = i + 1
    } else if !in_fence &&
      !in_inline &&
      @strutil.char_at(content, i) == '[' &&
      @strutil.char_at(content, i + 1) == '[' {
      let inner_start = i + 2
      let mut j = inner_start
      let mut found = false
      while j + 1 < n {
        if @strutil.char_at(content, j) == ']' &&
          @strutil.char_at(content, j + 1) == ']' {
          let inner = @strutil.substr(content, inner_start, j)
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
      if !found {
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
