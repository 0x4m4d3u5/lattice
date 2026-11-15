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

///|
/// A deliberately narrow local/origin-free spelling, not a network policy.
/// Core/x have no portable public URL parser; do not approximate arbitrary URLs.
fn private_base_url_allowed(base : String) -> Bool {
  if base == "/" { return true }
  let base = base.strip_suffix("/").unwrap_or(base[:])
  let authority = match base.split_once("://") {
    Some(("http" | "https", authority)) => authority
    _ => return false
  }
  for host in ["127.0.0.1", "[::1]"] {
    if authority == host { return true }
    if authority.strip_prefix(host + ":") is Some(port) {
      if port.is_empty() || !port.iter().all(c => c >= '0' && c <= '9') { return false }
      return match @strutil.parse_int(port.to_owned()) {
        Some(port) => port > 0 && port <= 65535
        None => false
      }
    }
  }
  false
}

///|
/// Reject the known publication root, not every server/sync root on the machine.
fn validate_private_destination(config : BuildConfig) -> Unit raise @fs.IOError {
  let public_root = config.site.output_dir.unwrap_or("./dist")
  if fresh_path_contains(@path.Path(public_root).resolve().normalize(),
    @path.Path(config.output_dir).resolve().normalize()) {
    raise @fs.IOError("private output must be outside the configured publication output_dir (default ./dist): " + public_root)
  }
  if !private_base_url_allowed(config.site.base_url) {
    raise @fs.IOError("private audience requires base_url = / or an http(s) loopback origin using 127.0.0.1 or [::1], with an optional port 1-65535 and no path")
  }
}
