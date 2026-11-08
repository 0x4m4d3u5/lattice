///|
/// Explicit publication selection. Private-audience output is not supported.
#derive(Eq)
pub(all) enum Audience {
  Public
}

///|
pub extend Audience with Eq::{equal, not_equal}

///|
/// Diagnostic-only identities. Never expose these maps to renderers or exports.
priv struct PublicProjection {
  denied_names : Map[String, Bool]
  denied_paths : Map[String, Bool]
  selected_404 : Array[SourceFile]
}

///|
fn PublicProjection::new() -> PublicProjection {
  { denied_names: Map([]), denied_paths: Map([]), selected_404: [] }
}

///|
fn public_url_output_path(url : String) -> String {
  if url == "/404.html" { url } else { url + "index.html" }
}

///|
fn public_route_key(url : String) -> String {
  let directory = url.has_suffix("/")
  let url = url.trim_end(chars="/").to_owned()
  if directory { url + "/index.html" } else if url.has_suffix("/index.html") { url } else if url.has_suffix(".html") || url.has_suffix(".htm") { url } else { url + "/index.html" }
}

///|
fn project_public_sources(
  sources : Array[SourceFile],
  collection : String,
  config : BuildConfig,
  output : OutputPlan,
  diagnostics : Array[@diagnostic.Diagnostic],
) -> Array[SourceFile] {
  guard output.public_projection is Some(projection) else { return sources }
  let selected : Array[SourceFile] = []
  for source in sources {
    let fm = match @frontmatter.parse(source.content) {
      Ok(fm) => fm
      Err(message) => {
        let (line, message) = frontmatter_document_error(message)
        diagnostics.push(@diagnostic.of_lint_violation({ path: source.path, line, column: None, kind: @lint.PublicationVisibilityError, message: "public audience: cannot classify frontmatter: " + message }))
        continue
      }
    }
    let reason = match fm.fields.get("visibility") {
      Some(@frontmatter.FStr("public")) => { selected.push(source); continue }
      Some(@frontmatter.FStr("private")) => "visibility: private excluded from public audience"
      None => "visibility: missing; explicit public visibility required"
      _ => {
        diagnostics.push(@diagnostic.of_lint_violation({ path: source.path, line: frontmatter_field_line(source.content, "visibility"), column: None, kind: @lint.PublicationVisibilityError, message: "visibility: expected exactly public or private (a string)" }))
        continue
      }
    }
    let url = if collection == "_404" { "/404.html" } else { authored_source_url(collection, source.slug) }
    output.exclude_page(source.path, config.output_dir + public_url_output_path(url), reason)
    projection.denied_names.set(@wikilink.lookup_key(source.slug), true)
    projection.denied_paths.set(public_route_key(url), true)
    // Local Markdown source spellings are identities too, even when an
    // explicitly copied asset would otherwise satisfy the same URL.
    let relative = @path.Path(source.path).relative(base=@path.Path(config.content_dir)).to_string()
    if relative != ".." && !relative.has_prefix("../") && !@path.Path(relative).is_absolute() {
      if local_link_path("/" + relative) is Ok(route) {
        projection.denied_paths.set(public_route_key(route), true)
        projection.denied_paths.set(route, true)
      }
    }
    let canonical_source = url.trim_end(chars="/").to_owned() + ".md"
    projection.denied_paths.set(public_route_key(canonical_source), true)
    // Home-page copies and aliases can otherwise mask an excluded source.
    if is_root_page_for_site(config.site, source.slug) {
      projection.denied_paths.set("/index.html", true)
    }
    if fm.fields.get("aliases") is Some(@frontmatter.FArray(aliases)) {
      for alternate in aliases {
        if alternate is @frontmatter.FStr(name) {
          projection.denied_names.set(@wikilink.lookup_key(name.trim().to_owned()), true)
        }
      }
    }
    for route in extract_redirect_paths(source.content) {
      let route = "/" + redirect_url_to_output_path(route)
      if local_link_path(route) is Ok(route) {
        projection.denied_paths.set(public_route_key(route), true)
      }
    }
  }
  selected
}

///|
/// Classify once before rendering, including excluded 404 metadata. Only selected
/// bytes survive the snapshot; render and embed checks never reread this file.
fn snapshot_public_404(
  config : BuildConfig,
  output : OutputPlan,
  diagnostics : Array[@diagnostic.Diagnostic],
) -> Unit {
  guard output.public_projection is Some(projection) else { return }
  let path = config.content_dir + "/404.md"
  if !@fs.path_exists(path) { return }
  let content = @fs.read_file_to_string(path) catch {
    @fs.IOError(message) => {
      diagnostics.push(build_error(Some(path), None, None, "cannot read 404.md: " + message))
      return
    }
  }
  let source : SourceFile = { path, filename: "404.md", slug: "404", content, fingerprint: "", stamp: 0L, link_targets: [] }
  for source in project_public_sources([source], "_404", config, output, diagnostics) {
    projection.selected_404.push(source)
  }
}

///|
fn public_audit_sources(
  collections : Array[CollectionSources],
  output : OutputPlan,
) -> Array[CollectionSources] {
  guard output.public_projection is Some(projection) else { return collections }
  let result = collections.copy()
  if !projection.selected_404.is_empty() {
    result.push({ definition: { name: "_404", schema: standalone_default_schema(), content_dir: "", template: None, page_size: None, sort_order: @collections.DateDesc, description: None }, sources: projection.selected_404 })
  }
  result
}

///|
/// Run before considering final ownership: superseded public prose can still be
/// present in search. Denials deliberately win over public/static/alias collisions.
fn check_public_boundary(
  collections : Array[CollectionSources],
  page_index : Map[String, String],
  config : BuildConfig,
  output : OutputPlan,
  diagnostics : Array[@diagnostic.Diagnostic],
) -> Unit {
  guard output.public_projection is Some(projection) else { return }
  let base = local_link_base_path(config.site.base_url)
  for collection in collections {
    for source in collection.sources {
      if !source_is_visible(source, config.include_drafts) { continue }
      guard @frontmatter.parse(source.content) is Ok(fm) else { continue }
      let url = if collection.definition.name == "_404" { "/404.html" } else { authored_source_url(collection.definition.name, source.slug) }
      for field in collection.definition.schema.fields {
        if fm.fields.get(field.name) is Some(value) {
          for target in public_typed_refs(field.field_type, value) {
            let key = @wikilink.lookup_key(target)
            let denied_route = match page_index.get(key) {
              Some(route) => public_route_denied(projection, route)
              None => false
            }
            if projection.denied_names.contains(key) || denied_route {
              diagnostics.push(@diagnostic.of_lint_violation({ path: source.path, line: frontmatter_field_line(source.content, field.name), column: None, kind: @lint.PublicationVisibilityError, message: field.name + ": reference '" + target + "' crosses the public audience boundary" }))
            }
          }
        }
      }
      for link in @wikilink.extract(fm.body, source.path) {
        let key = @wikilink.lookup_key(link.target)
        let denied_route = match page_index.get(key) {
          Some(route) => public_route_denied(projection, route)
          None => false
        }
        if projection.denied_names.contains(key) || denied_route {
          diagnostics.push(@diagnostic.of_lint_violation({ path: source.path, line: None, column: None, kind: @lint.PublicationVisibilityError, message: "[[" + link.target + "]]: reference crosses the public audience boundary" }))
        }
      }
      for target in @markdown.extract_link_destinations(fm.body, include_images=true) {
        if local_link_destination(target, url, base) is Ok(Some((route, _))) && public_route_denied(projection, route) {
          diagnostics.push(@diagnostic.of_lint_violation({ path: source.path, line: None, column: None, kind: @lint.PublicationVisibilityError, message: "local link '" + target + "': reference crosses the public audience boundary" }))
        }
      }
    }
  }
}

///|
fn public_typed_refs(field_type : @schema.FieldType, value : @frontmatter.FrontmatterValue) -> Array[String] {
  match (field_type, value) {
    (@schema.TOptional(inner), value) => public_typed_refs(inner, value)
    (@schema.TArray(inner), @frontmatter.FArray(values)) => values.iter().flat_map(value => public_typed_refs(inner, value).iter()).collect()
    (@schema.TRef(_), @frontmatter.FStr(target)) => [target]
    _ => []
  }
}

///|
fn public_diagnostic_kind(diagnostic : @diagnostic.Diagnostic) -> @lint.ViolationType {
  match diagnostic.code {
    Some("E001") => @lint.MissingRequiredFrontmatter
    Some("E002") => @lint.SchemaError
    Some("E003") => @lint.FrontmatterError
    Some("E004") => @lint.BrokenWikilink
    Some("E005") => @lint.DanglingTagReference
    Some("E006") => @lint.TemplateSlotError
    Some("E007") => @lint.DataError
    Some("E008") => @lint.ShortcodeError
    Some("E009") => @lint.CollectionsError
    Some("E010") => @lint.DuplicateSlug
    Some("E012") => @lint.MissingImageAlt
    Some("E013") => @lint.ConfigError
    Some("E014") => @lint.BrokenLocalLink
    Some("E015") => @lint.PublicationVisibilityError
    _ => @lint.IOError
  }
}

///|
/// Local links may resolve to either an exact file or a directory index. Deny
/// both candidates, independently of later static/redirect ownership.
fn public_route_denied(projection : PublicProjection, route : String) -> Bool {
  let exact = route.trim_end(chars="/").to_owned()
  projection.denied_paths.contains(exact) ||
  projection.denied_paths.contains(exact + "/index.html") ||
  projection.denied_paths.contains(public_route_key(route))
}

///|
/// Lexical identity only; symlinks and concurrent writers are outside this mode.
fn public_source_path_key(path : String) -> String {
  @path.Path(path).resolve().normalize().to_string()
}
