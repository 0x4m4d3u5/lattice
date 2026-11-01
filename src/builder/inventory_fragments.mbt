///|
fn inventory_is_html(path : String) -> Bool {
  let lower = path.to_lower()
  lower.has_suffix(".html") || lower.has_suffix(".htm")
}

///|
/// Actual emitted IDs/legacy anchor names, not inferred heading slugs. Reuse the
/// fragment scanner and uniqueness checks; unsupported parse contexts are unknown.
fn inventory_html_fragments(html : String) -> Array[String]? {
  let candidates : Map[Int, String] = Map([])
  let mut uncertain = false
  let _ = published_html_fragments(html, on_tag=fn(_, tag, id, name) {
    if ["select", "noscript", "plaintext"].contains(tag) { uncertain = true }
    for value in [id, name] {
      if value is Some(value) {
        // The shared text decoder collapses attribute whitespace. Do not
        // advertise its normalized spelling as an actual browser target.
        if value.contains("&") || value.iter().any(c => c.is_whitespace() || c.is_ascii_control()) { uncertain = true }
        if value != "" && !value.iter().any(c => c.is_ascii_control()) {
          candidates.set(candidates.length(), value)
        }
      }
    }
  })
  if uncertain { return None }
  let unique = unique_section_fragments(html, candidates)
  let seen : Map[String, Bool] = Map([])
  for (_, id) in unique { seen.set(id, true) }
  let result = seen.keys().collect()
  result.sort_by((a, b) => a.lexical_compare(b))
  Some(result)
}
