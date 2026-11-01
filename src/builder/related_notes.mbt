///|
/// The field's existing typed Ref contract is the opt-in, not its spelling alone.
fn related_ref_type(field_type : @schema.FieldType) -> Bool {
  match field_type {
    @schema.TOptional(inner) => related_ref_type(inner)
    @schema.TRef(_) => true
    @schema.TArray(@schema.TRef(_)) => true
    _ => false
  }
}

///|
fn authored_related_notes(fm : @frontmatter.Frontmatter, schema : @schema.Schema) -> Array[String] {
  if !schema.fields.any(field => field.name == "related" && related_ref_type(field.field_type)) { return [] }
  match fm.fields.get("related") {
    Some(@frontmatter.FStr(slug)) => [slug]
    Some(@frontmatter.FArray(items)) => items.filter_map(item => match item { @frontmatter.FStr(slug) => Some(slug); _ => None })
    _ => []
  }
}

///|
/// A private staging marker carries no draft title or destination. Resolve only
/// after final output ownership, and before any publication writes.
fn related_notes_slot(fm : @frontmatter.Frontmatter, schema : @schema.Schema) -> String {
  if authored_related_notes(fm, schema).is_empty() { "" } else { "<!--lattice-related-notes-->" }
}

///|
fn related_notes_by_source(collections : Array[CollectionSources]) -> Map[String, Array[String]] {
  let result : Map[String, Array[String]] = Map([])
  for collection in collections {
    for source in collection.sources {
      if @frontmatter.parse(source.content) is Ok(fm) {
        let refs = authored_related_notes(fm, collection.definition.schema)
        if !refs.is_empty() { result.set(source.path, refs) }
      }
    }
  }
  result
}

///|
fn related_notes_html(
  refs : Array[String],
  source_url : String,
  documents : Map[String, ProcessedDocument],
  page_index : Map[String, String],
  overwritten : Map[String, Bool],
) -> String {
  let seen : Map[String, Bool] = Map([])
  let items = StringBuilder()
  for slug in refs {
    if page_index.get(slug) is Some(url) && url != source_url &&
      !seen.contains(url) && !overwritten.contains(url) && documents.get(url) is Some(doc) {
      seen.set(url, true)
      items.write_string("<li>" + @html.anchor(url, doc.title) + "</li>\n")
    }
  }
  if seen.is_empty() { return "" }
  "<section class=\"related-notes\" aria-label=\"Related notes\">\n<h2>Related notes</h2>\n<p>Selected by the author.</p>\n<ul>\n" + items.to_string() + "</ul>\n</section>\n"
}
