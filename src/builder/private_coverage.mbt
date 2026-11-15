///|
/// Report discovery boundaries, not a recursively enumerated vault inventory.
/// x/fs can classify a child but cannot lstat/realpath it portably. Never read
/// an unconfigured child's directory entries or Markdown bodies here.
fn private_coverage_warnings(
  config : BuildConfig,
  collections : Array[@collections.CollectionDef],
) -> Array[@diagnostic.Diagnostic] {
  let roots : Map[String, Bool] = Map([])
  roots.set(public_source_path_key(config.content_dir), true)
  roots.set(public_source_path_key(standalone_dir_for_build(config)), true)
  for collection in collections {
    roots.set(public_source_path_key(collection.content_dir), true)
  }
  let non_source_roots : Map[String, Bool] = Map([])
  for root in [
    @strutil.join_path(config.content_dir, static_dir_name(config.site)),
    data_dir_for_build(config),
    templates_dir_for_build(config),
  ] { non_source_roots.set(public_source_path_key(root), true) }
  let diagnostics : Array[@diagnostic.Diagnostic] = []
  let seen : Map[String, Bool] = Map([])
  let ordered_roots = roots.keys().collect()
  ordered_roots.sort()
  for root in ordered_roots {
    if !@fs.path_exists(root) { continue }
    let children = @fs.read_dir(root) catch {
      @fs.IOError(_) => {
        diagnostics.push(private_coverage_warning(root, "cannot inspect configured source directory"))
        continue
      }
    }
    let children = children.to_owned()
    children.sort()
    for name in children {
      let child = public_source_path_key(@strutil.join_path(root, name))
      // A separately configured source root is inspected in its own iteration.
      // Non-source exemptions only apply at that exact boundary, not below an
      // explicit source root which happens to overlap static/data/templates.
      if roots.contains(child) || non_source_roots.contains(child) || seen.contains(child) { continue }
      seen.set(child, true)
      let directory = @fs.is_dir(child) catch {
        @fs.IOError(_) => {
          diagnostics.push(private_coverage_warning(child, "cannot classify child entry"))
          continue
        }
      }
      if directory {
        diagnostics.push(private_coverage_warning(child, "uninspected child directory"))
      }
    }
  }
  diagnostics
}

///|
fn private_coverage_warning(path : String, reason : String) -> @diagnostic.Diagnostic {
  { severity: @diagnostic.Warning, code: Some("private_source_coverage"),
    path: Some(path), line: None, column: None,
    message: "private source coverage is incomplete: " + reason + "; nested Markdown may be omitted. Source discovery is one directory level, not recursive.",
    note: Some("No child traversal or content read was performed by this coverage check. Configure intended source directories explicitly; this is not a complete vault inventory.") }
}
