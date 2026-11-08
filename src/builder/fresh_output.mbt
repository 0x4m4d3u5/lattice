///|
/// Lexical isolation only: callers must use stable, trusted trees without
/// symlinks or concurrent writers. Portable x/fs has no exclusive mkdir/realpath.
fn require_fresh_destination(path : String) -> Unit raise @fs.IOError {
  if @fs.path_exists(@path.Path(path).resolve().normalize().to_string()) {
    raise @fs.IOError("fresh output destination already exists: " + path)
  }
}

///|
fn fresh_path_contains(root : @path.Path, candidate : @path.Path) -> Bool {
  let relative = candidate.relative(base=root).to_string()
  relative != ".." &&
  !relative.has_prefix("../") &&
  !relative.has_prefix("..\\") &&
  !@path.Path(relative).is_absolute()
}

///|
fn validate_fresh_roots(
  config : BuildConfig,
  collections : Array[@collections.CollectionDef],
) -> Unit raise @fs.IOError {
  let destination = @path.Path(config.output_dir).resolve().normalize()
  let roots = dependency_roots_for_build(config, collections)
  roots.push(config.content_dir)
  roots.push(
    @strutil.join_path(config.content_dir, static_dir_name(config.site)),
  )
  roots.push(standalone_dir_for_build(config))
  for collection in collections {
    roots.push(collection.content_dir)
  }
  for source in roots {
    let source_path = @path.Path(source).resolve().normalize()
    if fresh_path_contains(destination, source_path) ||
      fresh_path_contains(source_path, destination) {
      raise @fs.IOError(
        "fresh output destination overlaps source or configuration: " + source,
      )
    }
  }
}

///|
fn fresh_output_failure(config : BuildConfig, message : String) -> BuildResult {
  {
    errors: 1,
    diagnostics: [build_error(Some(config.output_dir), None, None, message)],
    rebuilt_pages: 0,
    unchanged_pages: 0,
    skipped_drafts: 0,
    redirect_count: 0,
    messages: ["[lattice] build failed; no successful publication"],
  }
}
