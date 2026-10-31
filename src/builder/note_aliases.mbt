///|
fn authored_source_url(collection_name : String, slug : String) -> String {
  match collection_name {
    "_root" => root_page_url(slug)
    "_standalone" => standalone_page_url(slug)
    _ => collection_page_url(collection_name, slug)
  }
}

///|
/// Register alternate note names only after all canonical keys are known.
/// Collisions are errors, never traversal-order-dependent winners.
fn register_note_aliases(
  collections : Array[CollectionSources],
  page_index : Map[String, String],
) -> Array[@lint.LintViolation] {
  let violations : Array[@lint.LintViolation] = []
  let canonical = page_index.copy()
  let owners : Map[String, String] = Map([])
  let ambiguous : Map[String, Bool] = Map([])
  let sources : Array[(SourceFile, String)] = []
  for collection in collections {
    for source in collection.sources {
      sources.push((source, authored_source_url(collection.definition.name, source.slug)))
    }
  }
  sources.sort_by_key(fn(pair) { pair.0.path })
  for (source, url) in sources {
    let fm = match @frontmatter.parse(source.content) {
      Ok(fm) => fm
      Err(_) => continue
    }
    let value = match fm.fields.get("aliases") {
      Some(value) => value
      None => continue
    }
    fn report(message : String) -> Unit {
      violations.push({
        path: source.path,
        line: frontmatter_field_line(source.content, "aliases"),
        column: None,
        kind: @lint.FrontmatterError,
        message: "aliases: " + message,
      })
    }
    let values = match value {
      @frontmatter.FArray(values) => values
      _ => {
        report("expected an array of non-empty strings")
        continue
      }
    }
    for value in values {
      let alternate_name = match value {
        @frontmatter.FStr(text) => text.trim().to_owned()
        _ => {
          report("expected an array of non-empty strings")
          continue
        }
      }
      let key = @wikilink.lookup_key(alternate_name)
      if alternate_name.is_empty() ||
        key.is_empty() ||
        alternate_name.contains("#") ||
        alternate_name.contains("|") ||
        alternate_name.contains("[") ||
        alternate_name.contains("]") ||
        alternate_name.contains("\n") ||
        alternate_name.contains("\r") {
        report("invalid wiki page name '" + alternate_name + "'")
        continue
      }
      match canonical.get(key) {
        Some(existing) => {
          if existing != url {
            report(
              "name '" +
              alternate_name +
              "' conflicts with a canonical page or collection",
            )
          }
          continue
        }
        None => ()
      }
      if ambiguous.contains(key) {
        report("name '" + alternate_name + "' is declared by multiple pages")
        continue
      }
      match owners.get(key) {
        Some(existing) =>
          if existing != source.path {
            report(
              "name '" + alternate_name + "' is declared by multiple pages",
            )
            ambiguous.set(key, true)
            page_index.remove(key)
          }
        None => {
          owners.set(key, source.path)
          page_index.set(key, url)
        }
      }
    }
  }
  violations.sort_by_key(fn(v) { v.path + "\n" + v.message })
  violations
}

///|
/// Extend only enabled publishing schemas; preserve explicit field constraints.
fn note_alias_schema(schema : @schema.Schema, enabled : Bool) -> @schema.Schema {
  if !enabled || schema.fields.any(fn(field) { field.name == "aliases" }) {
    return schema
  }
  let fields = schema.fields.copy()
  fields.push({
    name: "aliases",
    required: false,
    field_type: @schema.TOptional(@schema.TArray(@schema.TString(None, None))),
  })
  { name: schema.name, fields, }
}

///|
/// Read names only from the source selected for publication, never a draft
/// sharing another source's URL. Final output ownership filters this metadata.
fn searchable_note_aliases(content : String) -> Array[String] {
  guard @frontmatter.parse(content) is Ok(fm) else { return [] }
  guard fm.fields.get("aliases") is Some(@frontmatter.FArray(values)) else { return [] }
  let names : Array[String] = []
  for value in values {
    if value is @frontmatter.FStr(text) {
      let name = text.trim().to_owned()
      if !name.is_empty() && !names.contains(name) { names.push(name) }
    }
  }
  names.sort()
  names
}
