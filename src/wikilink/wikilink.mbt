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
/// Canonical lookup key for wikilink targets.
pub fn lookup_key(target : String) -> String {
  @slug.filename_to_slug(target)
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
