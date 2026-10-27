///|
/// Conservative check-only advice from a complete final plan. Never alter the
/// resolver or infer a destination from a filename that is not published.
fn add_link_suggestions(
  collections : Array[CollectionSources],
  collection_sources : Array[CollectionSources],
  page_index : Map[String, String],
  config : BuildConfig,
  output : OutputPlan,
  violations : Array[@lint.LintViolation],
) -> Unit {
  if !violations.any(v => v.kind == @lint.BrokenWikilink) ||
    violations.any(v => v.kind == @lint.DuplicateSlug) {
    return
  }
  let final_slots : Map[String, Int] = Map([])
  for index, (path, _) in output.files {
    final_slots.set(path, index)
  }
  let source_paths : Map[String, String] = Map([])
  for collection in collections {
    for source in collection.sources {
      if source_is_visible(source, config.include_drafts) {
        source_paths.set(source.slug, source.path)
      }
    }
  }
  let candidates : Map[String, String] = Map([])
  for (key, url) in page_index {
    let path = output_path_key(config.output_dir + url + "index.html")
    guard final_slots.get(path) is Some(slot) else { continue }
    // Static replacements have different ownership; do not recommend them as
    // the authored note even if the old slug still resolves to that route.
    match output.origins[slot] {
      Page(source) => if source_paths.get(key) != Some(source) { continue }
      Generated =>
        if !collection_sources.any(c => {
            collection_index_lookup_alias(c.definition) == Some(key) &&
            collection_index_url(c.definition.name) == url
          }) {
          continue
        }
      _ => continue
    }
    match output.files[slot].1 {
      Text(html) => candidates.set(key, html)
      _ => ()
    }
  }
  for collection in collections {
    for source in collection.sources {
      if !source_is_visible(source, config.include_drafts) {
        continue
      }
      let body = match @frontmatter.parse(source.content) {
        Ok(fm) => fm.body
        Err(_) => continue
      }
      let (_, errors) = @wikilink.resolve(
        @wikilink.extract(body, source.path),
        page_index,
      )
      for error in errors {
        let choices = nearby_wikilinks(error.link, page_index, candidates)
        if choices.is_empty() {
          continue
        }
        let (line, column) = fragment_link_location(source.content, error.link)
        if line is None || column is None {
          continue
        }
        let original = "[[" + error.link.target + "]]: " + error.message
        for index, violation in violations {
          if violation.kind == @lint.BrokenWikilink &&
            violation.path == source.path &&
            violation.line == line &&
            violation.column == column &&
            violation.message == original {
            violations[index] = {
              ..violation,
              message: original +
              "; Nearby valid targets (choose the intended page): " +
              choices.iter().join(", "),
            }
          }
        }
      }
    }
  }
}

///|
/// One insertion/deletion/substitution after the resolver's normalization, not
/// general fuzzy search. Keep all ties, or none if there are more than three.
fn nearby_wikilinks(
  link : @wikilink.RawWikilink,
  page_index : Map[String, String],
  candidates : Map[String, String],
) -> Array[String] {
  let key = @wikilink.lookup_key(link.target)
  if key.length() < 4 || key.length() > 80 || link.target.has_prefix("#") {
    return []
  }
  let suffix = match link.target.split_once("#") {
    Some((_, fragment)) => "#" + fragment.to_owned()
    None => ""
  }
  let choices : Array[String] = []
  for (candidate, html) in candidates {
    if @wikilink.lookup_key(candidate) != candidate ||
      candidate.length() > 80 ||
      @diff.edit_distance_str_within(key[:], candidate[:], max_distance=1) !=
      Some(1) {
      continue
    }
    let target = candidate + suffix
    let raw = { ..link, target, }
    let syntax = "[[" +
      target +
      (match link.display {
        Some(label) => "|" + label
        None => ""
      }) +
      "]]"
    // Only emit spellings that round-trip through the actual reference parser.
    let parsed = @wikilink.extract(syntax, link.source_file)
    if parsed.length() != 1 ||
      parsed[0].target != target ||
      parsed[0].display != link.display {
      continue
    }
    let (resolved, errors) = @wikilink.resolve([raw], page_index)
    if !errors.is_empty() || resolved.length() != 1 {
      continue
    }
    if resolved[0].url.split_once("#") is Some((_, fragment)) {
      if !unique_section_fragments(html, Map([(0, fragment.to_owned())])).contains(
          0,
        ) {
        continue
      }
    }
    choices.push(syntax)
    if choices.length() > 3 {
      return []
    }
  }
  choices.sort()
  choices
}
