///|
/// Wikilink resolution and validation.
///
/// Wikilinks (`[[target]]` or `[[target|display]]`) are resolved against the
/// content graph at build time. A link to a non-existent page is a build error,
/// not a 404. The resolved link carries the target page's canonical URL so
/// the render step never needs to do path arithmetic.

///|
/// A raw wikilink extracted from markdown source.
pub(all) struct RawWikilink {
  target : String
  display : String? // None means use target as display text
  source_file : String
}

///|
/// A resolved wikilink with a validated target URL.
pub(all) struct ResolvedWikilink {
  raw : RawWikilink
  url : String
  title : String
}

///|
/// Resolution error: the target did not match any content page.
pub(all) struct ResolutionError {
  link : RawWikilink
  message : String
}

// ── helpers ───────────────────────────────────────────────────────────────────

///|
/// Canonical page key; heading fragments do not change page ownership.
pub fn lookup_key(target : String) -> String {
  let page = match target.split_once("#") {
    Some((page, _)) => page.to_owned()
    None => target
  }
  @slug.filename_to_slug(page)
}

///|
fn with_heading_fragment(url : String, target : String) -> String {
  match target.split_once("#") {
    None => url
    Some((_, heading)) => {
      // A supplied heading replaces an existing URL fragment, retaining queries.
      let base = match url.split_once("#") {
        Some((base, _)) => base.to_owned()
        None => url
      }
      if heading.trim().is_empty() {
        base
      } else {
        base + "#" + @markdown.heading_anchor(heading.to_owned())
      }
    }
  }
}

// ── public API ────────────────────────────────────────────────────────────────

///|
/// Extract rendered wikilinks using the same parsed syntax as Markdown output.
/// `source_file` is embedded in each link for resolution diagnostics.
pub fn extract(content : String, source_file : String) -> Array[RawWikilink] {
  @markdown.extract_wikilink_targets(content).map(fn(pair) {
    let (target, display) = pair
    { target, display, source_file, }
  })
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
    // Same-note fragments need no page lookup; heading existence is not checked.
    let destination = if link.target.has_prefix("#") {
      if link.target[1:].trim().is_empty() { None } else { Some("") }
    } else {
      index.get(lookup_key(link.target))
    }
    match destination {
      Some(url) => {
        let title = match link.display {
          Some(d) => d
          None => link.target
        }
        resolved.push({
          raw: link,
          url: with_heading_fragment(url, link.target),
          title,
        })
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
