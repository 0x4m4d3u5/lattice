///|
/// Publication is public-only today. Keep this typed declaration separate from
/// draft readiness and vault organization; neither grants publication consent.
priv enum PublicationVisibility {
  Public
  Private
}

///|
fn publication_visibility(
  fm : @frontmatter.Frontmatter,
) -> Result[PublicationVisibility, String] {
  match fm.fields.get("visibility") {
    None | Some(@frontmatter.FStr("public")) => Ok(Public)
    Some(@frontmatter.FStr("private")) => Ok(Private)
    _ => Err("visibility: expected exactly public or private (a string)")
  }
}

///|
fn publication_visibility_violation(
  path : String,
  source : String,
) -> @lint.LintViolation? {
  let (line, message) = match @frontmatter.parse(source) {
    Err(msg) => {
      // Preserve the existing diagnostics for unrelated parse failures. They
      // still block publication in the ordinary document validation pipeline.
      if !msg.has_suffix(": duplicate visibility field") { return None }
      frontmatter_document_error(msg)
    }
    Ok(fm) => {
      let message = match publication_visibility(fm) {
        Ok(Public) => return None
        Ok(Private) =>
          "visibility: private cannot be published: private-audience builds are not supported; use a curated public source tree and attachments (drafts are not a privacy boundary)"
        Err(message) => message
      }
      (frontmatter_field_line(source, "visibility"), message)
    }
  }
  Some({
    path,
    line,
    column: None,
    kind: @lint.PublicationVisibilityError,
    message,
  })
}

///|
/// Guard every collected Markdown source before deriving indexes or considering
/// cache hits. Private output is not implemented: reject the whole preparation,
/// including hidden drafts, rather than filtering pages while copying assets.
fn publication_visibility_violations(
  config : BuildConfig,
  collections : Array[CollectionSources],
) -> Array[@lint.LintViolation] {
  let violations : Array[@lint.LintViolation] = []
  let seen : Map[String, Bool] = Map([])
  for collection in collections {
    for source in collection.sources {
      seen.set(source.path, true)
      if publication_visibility_violation(source.path, source.content) is Some(violation) {
        violations.push(violation)
      }
    }
  }
  // Root 404.md is deliberately not part of ordinary collected sources.
  let path = config.content_dir + "/404.md"
  if !seen.contains(path) && @fs.path_exists(path) {
    try {
      let source = @fs.read_file_to_string(path)
      if publication_visibility_violation(path, source) is Some(violation) {
        violations.push(violation)
      }
    } catch {
      @fs.IOError(message) => violations.push({
        path,
        line: None,
        column: None,
        kind: @lint.IOError,
        message: "cannot read 404.md: " + message,
      })
    }
  }
  violations
}
