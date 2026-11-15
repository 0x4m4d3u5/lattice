///|
/// Private is a local export policy, not a public projection or access boundary.
/// Validate all configured sources, including hidden drafts, before derivation.
fn private_visibility_violations(
  config : BuildConfig,
  collections : Array[CollectionSources],
  output : OutputPlan,
) -> Array[@lint.LintViolation] {
  let violations : Array[@lint.LintViolation] = []
  for collection in collections {
    for source in collection.sources {
      if publication_visibility_violation(source.path, source.content,
        allow_missing_frontmatter=config.site.allow_missing_frontmatter == Some(true),
        private_export=true) is Some(violation) { violations.push(violation) }
    }
  }
  let path = config.content_dir + "/404.md"
  if @fs.path_exists(path) {
    try {
      let content = @fs.read_file_to_string(path)
      if publication_visibility_violation(path, content,
        allow_missing_frontmatter=config.site.allow_missing_frontmatter == Some(true),
        private_export=true) is Some(violation) {
        violations.push(violation)
      } else {
        output.private_404.push({ path, filename: "404.md", slug: "404", content,
          fingerprint: "", stamp: 0L, link_targets: [] })
      }
    } catch {
      @fs.IOError(message) => violations.push({ path, line: None, column: None,
        kind: @lint.IOError, message: "cannot read 404.md: " + message })
    }
  }
  violations
}

///|
fn private_audit_sources(collections : Array[CollectionSources], output : OutputPlan) -> Array[CollectionSources] {
  let result = collections.copy()
  if !output.private_404.is_empty() {
    result.push({ definition: { name: "_404", schema: standalone_default_schema(),
      content_dir: "", template: None, page_size: None, sort_order: @collections.DateDesc,
      description: None }, sources: output.private_404 })
  }
  result
}
