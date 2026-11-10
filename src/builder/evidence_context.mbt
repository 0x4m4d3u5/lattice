///|
/// Author claims, resolved using final publication ownership, never rank or truth.
fn published_supersession_context(
  collections : Array[CollectionSources],
  source_urls : Map[String, String],
  documents : Map[String, ProcessedDocument],
  page_index : Map[String, String],
  overwritten : Map[String, Bool],
  allow_missing_frontmatter~ : Bool = false,
) -> Map[String, Array[(String, String)]] {
  let result : Map[String, Array[(String, String)]] = Map([])
  for collection in collections {
    if !collection.definition.schema.fields.any(field => {
        field.name == "supersedes" && related_ref_type(field.field_type)
      }) {
      continue
    }
    for source in collection.sources {
      guard source_urls.get(source.path) is Some(source_url) &&
        documents.contains(source_url) &&
        !overwritten.contains(source_url) else {
        continue
      }
      guard @frontmatter.parse_with_policy(
          source.content,
          allow_missing_frontmatter~,
        )
        is Ok(fm) else {
        continue
      }
      let refs = match fm.fields.get("supersedes") {
        Some(@frontmatter.FStr(slug)) => [slug]
        Some(@frontmatter.FArray(items)) =>
          items.filter_map(item => {
            match item {
              @frontmatter.FStr(slug) => Some(slug)
              _ => None
            }
          })
        _ => []
      }
      let seen : Map[String, Bool] = Map([])
      let targets : Array[(String, String)] = []
      for slug in refs {
        if page_index.get(slug) is Some(url) &&
          url != source_url &&
          !seen.contains(url) &&
          !overwritten.contains(url) &&
          documents.get(url) is Some(doc) {
          seen.set(url, true)
          targets.push((url, doc.title))
        }
      }
      if !targets.is_empty() {
        result.set(source_url, targets)
      }
    }
  }
  result
}

///|
fn evidence_datetime_type(field_type : @schema.FieldType) -> Bool {
  match field_type {
    @schema.TOptional(inner) => evidence_datetime_type(inner)
    @schema.TDateTime(_) => true
    _ => false
  }
}

///|
/// Only schema-validated DateTime fields opt in. No clock or interval comparison.
fn published_evidence_times(
  collections : Array[CollectionSources],
  source_urls : Map[String, String],
  documents : Map[String, ProcessedDocument],
  overwritten : Map[String, Bool],
  allow_missing_frontmatter~ : Bool = false,
) -> Map[String, Map[String, String]] {
  let result : Map[String, Map[String, String]] = Map([])
  for collection in collections {
    for source in collection.sources {
      guard source_urls.get(source.path) is Some(url) &&
        documents.contains(url) &&
        !overwritten.contains(url) else {
        continue
      }
      guard @frontmatter.parse_with_policy(
          source.content,
          allow_missing_frontmatter~,
        )
        is Ok(fm) else {
        continue
      }
      let times : Map[String, String] = Map([])
      for field in collection.definition.schema.fields {
        if ["observed_at", "valid_from", "valid_until"].contains(field.name) &&
          evidence_datetime_type(field.field_type) &&
          fm.fields.get(field.name) is Some(@frontmatter.FStr(value)) {
          times.set(field.name, value)
        }
      }
      if !times.is_empty() {
        result.set(url, times)
      }
    }
  }
  result
}
