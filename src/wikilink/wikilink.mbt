///|
/// Wikilink resolution and validation.
///
/// Wikilinks (`[[target]]` or `[[target|display]]`) are resolved against the
/// content graph at build time. A link to a non-existent page is a build error,
/// not a 404. The resolved link carries the target page's canonical URL so
/// the render step never needs to do path arithmetic.

/// A raw wikilink extracted from markdown source.
pub struct RawWikilink {
  target : String
  display : String? // None if target is used as display text
  source_file : String
}

/// A resolved wikilink with a validated target URL.
pub struct ResolvedWikilink {
  raw : RawWikilink
  url : String
  title : String
}

/// Resolution error: the target did not match any content page.
pub struct ResolutionError {
  link : RawWikilink
  message : String
}

/// Extract all wikilinks from a markdown string.
pub fn extract(content : String) -> Array[RawWikilink] {
  // TODO: implement [[...]] extraction
  []
}

/// Resolve wikilinks against a page index (slug → url map).
/// Returns unresolvable links as errors.
pub fn resolve(
  links : Array[RawWikilink],
  index : Map[String, String]
) -> (Array[ResolvedWikilink], Array[ResolutionError]) {
  // TODO: implement
  ([], [])
}
