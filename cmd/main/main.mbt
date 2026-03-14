///|
/// Lattice — command-line entry point.
///
/// Usage:
///   lattice [content-dir] [output-dir] [--config path] [--collections path] [--check]
///           [--force] [--watch] [--watch-interval ms] [--drafts] [--help]
///
/// Defaults:
///   content-dir → ./content
///   config file → <content-dir>/lattice.conf
///   output-dir  → config.output_dir or ./dist
///
/// The build is two-pass:
///   1. Collect all .md files from content-dir, compute slugs, build page index.
///   2. Render each page through the full pipeline; write HTML to output-dir.
///
/// Exit codes: 0 = clean build, 1 = one or more errors.
pub(all) struct CliOptions {
  content_dir : String
  output_dir : String?
  config_path : String?
  collections_path : String?
  check_mode : Bool
  force_rebuild : Bool
  watch_mode : Bool
  watch_interval_ms : Int
  include_drafts : Bool
}

///|
priv struct CliState {
  build_config : @builder.BuildConfig
  watch_roots : Array[String]
}

///|
fn char_at_main(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

///|
fn starts_with_main(s : String, prefix : String) -> Bool {
  let n = s.length()
  let plen = prefix.length()
  if plen > n {
    return false
  }
  let mut i = 0
  while i < plen {
    if char_at_main(s, i) != char_at_main(prefix, i) {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn substr_main(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = start
  while i < end {
    buf.write_char(char_at_main(s, i))
    i = i + 1
  }
  buf.to_string()
}

///|
fn print_diagnostic_main(d : @diagnostic.Diagnostic) -> Unit {
  println(@diagnostic.format_diagnostic(d))
}

///|
fn cli_error(message : String) -> @diagnostic.Diagnostic {
  @diagnostic.error(message)
}

///|
fn cli_warning(message : String) -> @diagnostic.Diagnostic {
  @diagnostic.warning(message)
}

///|
fn with_path(
  d : @diagnostic.Diagnostic,
  path : String?,
  line : Int?,
  column : Int?,
) -> @diagnostic.Diagnostic {
  {
    severity: d.severity,
    code: d.code,
    path,
    line,
    column,
    message: d.message,
    note: d.note,
  }
}

///|
fn collections_error_diagnostic(
  path : String,
  err : @collections.CollectionsError,
) -> @diagnostic.Diagnostic {
  match err {
    @collections.InvalidLine(line, msg) =>
      with_path(cli_error(msg), Some(path), Some(line), None)
    @collections.MissingRequiredField(collection_name, field) =>
      {
        severity: @diagnostic.Error,
        code: None,
        path: Some(path),
        line: None,
        column: None,
        message: "missing required field '" +
        field +
        "' in collection '" +
        collection_name +
        "'",
        note: None,
      }
    @collections.DuplicateCollection(name) =>
      with_path(
        cli_error("duplicate collection '" + name + "'"),
        Some(path),
        None,
        None,
      )
    @collections.DuplicateDataSchema(name) =>
      with_path(
        cli_error("duplicate data schema '" + name + "'"),
        Some(path),
        None,
        None,
      )
    @collections.InvalidSchema(name, msg) =>
      with_path(
        cli_error("invalid schema for collection '" + name + "': " + msg),
        Some(path),
        None,
        None,
      )
    @collections.EmptyConfig =>
      with_path(cli_error("no collections defined"), Some(path), None, None)
  }
}

///|
fn config_error_diagnostic(
  path : String,
  err : @config.ConfigError,
) -> @diagnostic.Diagnostic {
  match err {
    @config.InvalidLine(line, msg) =>
      with_path(cli_error(msg), Some(path), Some(line), None)
    @config.MissingRequiredField(field) =>
      with_path(
        cli_error("missing required field '" + field + "'"),
        Some(path),
        None,
        None,
      )
    @config.InvalidValue(field, msg) =>
      with_path(
        cli_error("invalid value for '" + field + "': " + msg),
        Some(path),
        None,
        None,
      )
  }
}

///|
fn parse_positive_int_main(value : String) -> Int? {
  if value.length() == 0 {
    return None
  }
  let mut parsed = 0
  let mut i = 0
  while i < value.length() {
    let c = char_at_main(value, i)
    if c < '0' || c > '9' {
      return None
    }
    parsed = parsed * 10 + (c.to_int() - '0'.to_int())
    i = i + 1
  }
  if parsed <= 0 {
    return None
  }
  Some(parsed)
}

///|
fn print_help() -> Unit {
  println("Usage:")
  println(
    "  lattice [content-dir] [output-dir] [--config path] [--collections path] [--check]",
  )
  println(
    "          [--force] [--watch] [--watch-interval ms] [--drafts] [--help]",
  )
  println("")
  println("Defaults:")
  println("  content-dir         ./content")
  println("  config file         <content-dir>/lattice.conf")
  println("  output-dir          config.output_dir or ./dist")
  println("")
  println("Flags:")
  println("  --config <path>         Override site config file")
  println("  --collections <path>    Override collections config file")
  println("  --check                 Run validation/lint pipeline only")
  println(
    "  --force                 Ignore incremental cache and rebuild everything",
  )
  println("  --watch                 Rebuild on file changes with polling")
  println(
    "  --watch-interval <ms>   Polling interval in milliseconds (default: 500)",
  )
  println("  --drafts                Include draft posts in the build")
  println("  --help                  Show this help text")
  println("")
  println("Local dev:")
  println(
    "  Pair --watch with a static file server such as simple-http-server.",
  )
}

///|
fn parse_cli_options(args : Array[String]) -> CliOptions {

  // args[0] is the program name
  let positionals : Array[String] = []
  let mut config_path : String? = None
  let mut collections_path : String? = None
  let mut check_mode = false
  let mut force_rebuild = false
  let mut watch_mode = false
  let mut watch_interval_ms = 500
  let mut include_drafts = false
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "--help" || arg == "-h" {
      print_help()
      @sys.exit(0)
      return {
        content_dir: "./content",
        output_dir: None,
        config_path: None,
        collections_path: None,
        check_mode: false,
        force_rebuild: false,
        watch_mode: false,
        watch_interval_ms: 500,
        include_drafts: false,
      }
    } else if arg == "--config" {
      if i + 1 >= args.length() {
        print_diagnostic_main(cli_error("missing value for --config"))
        @sys.exit(1)
      }
      config_path = Some(args[i + 1])
      i = i + 2
    } else if starts_with_main(arg, "--config=") {
      let value = substr_main(arg, 9, arg.length())
      if value.length() == 0 {
        print_diagnostic_main(cli_error("missing value for --config"))
        @sys.exit(1)
      }
      config_path = Some(value)
      i = i + 1
    } else if arg == "--collections" {
      if i + 1 >= args.length() {
        print_diagnostic_main(cli_error("missing value for --collections"))
        @sys.exit(1)
      }
      collections_path = Some(args[i + 1])
      i = i + 2
    } else if starts_with_main(arg, "--collections=") {
      let value = substr_main(arg, 14, arg.length())
      if value.length() == 0 {
        print_diagnostic_main(cli_error("missing value for --collections"))
        @sys.exit(1)
      }
      collections_path = Some(value)
      i = i + 1
    } else if arg == "--check" {
      check_mode = true
      i = i + 1
    } else if arg == "--force" {
      force_rebuild = true
      i = i + 1
    } else if arg == "--watch" {
      watch_mode = true
      i = i + 1
    } else if arg == "--watch-interval" {
      if i + 1 >= args.length() {
        print_diagnostic_main(cli_error("missing value for --watch-interval"))
        @sys.exit(1)
      }
      match parse_positive_int_main(args[i + 1]) {
        Some(parsed) => watch_interval_ms = parsed
        None => {
          print_diagnostic_main(
            cli_error(
              "invalid value for --watch-interval: must be a positive integer",
            ),
          )
          @sys.exit(1)
        }
      }
      i = i + 2
    } else if starts_with_main(arg, "--watch-interval=") {
      let value = substr_main(arg, 17, arg.length())
      match parse_positive_int_main(value) {
        Some(parsed) => watch_interval_ms = parsed
        None => {
          print_diagnostic_main(
            cli_error(
              "invalid value for --watch-interval: must be a positive integer",
            ),
          )
          @sys.exit(1)
        }
      }
      i = i + 1
    } else if arg == "--drafts" {
      include_drafts = true
      i = i + 1
    } else if starts_with_main(arg, "--") {
      print_diagnostic_main({
        severity: @diagnostic.Error,
        code: None,
        path: None,
        line: None,
        column: None,
        message: "unknown option: " + arg,
        note: Some("run with --help to see supported flags"),
      })
      @sys.exit(1)
    } else {
      positionals.push(arg)
      i = i + 1
    }
  }

  {
    content_dir: if positionals.length() > 0 {
      positionals[0]
    } else {
      "./content"
    },
    output_dir: if positionals.length() > 1 {
      Some(positionals[1])
    } else {
      None
    },
    config_path,
    collections_path,
    check_mode,
    force_rebuild,
    watch_mode,
    watch_interval_ms,
    include_drafts,
  }
}

///|
fn load_collections_for_watch(
  content_dir : String,
  collections_path : String?,
) -> Result[Array[@collections.CollectionDef], @diagnostic.Diagnostic] {
  match collections_path {
    None => Ok([@collections.default_posts_collection(content_dir)])
    Some(path) => {
      let source = @fs.read_file_to_string(path) catch {
        @fs.IOError(msg) =>
          return Err(
            with_path(
              cli_error("cannot read collections file: " + msg),
              Some(path),
              None,
              None,
            ),
          )
      }
      match @collections.parse(source) {
        Ok(parsed) => Ok(parsed.definitions)
        Err(err) => Err(collections_error_diagnostic(path, err))
      }
    }
  }
}

///|
fn load_cli_state(options : CliOptions) -> Result[CliState, Int] {
  let effective_config_path = match options.config_path {
    Some(path) => path
    None => options.content_dir + "/lattice.conf"
  }

  let config_source = @fs.read_file_to_string(effective_config_path) catch {
    @fs.IOError(msg) => {
      print_diagnostic_main(
        with_path(
          cli_error("cannot read config file: " + msg),
          Some(effective_config_path),
          None,
          None,
        ),
      )
      return Err(1)
    }
  }

  let site = match @config.parse(config_source) {
    Ok(c) => c
    Err(err) => {
      print_diagnostic_main(config_error_diagnostic(effective_config_path, err))
      return Err(1)
    }
  }

  let output_dir = match options.output_dir {
    Some(path) => path
    None =>
      match site.output_dir {
        Some(path) => path
        None => "./dist"
      }
  }

  let build_config : @builder.BuildConfig = {
    content_dir: options.content_dir,
    output_dir,
    config_path: effective_config_path,
    site,
    collections_path: match options.collections_path {
      Some(path) => Some(path)
      None => site.collections_file
    },
    force_rebuild: options.force_rebuild,
    include_drafts: options.include_drafts,
  }
  let collections = match
    load_collections_for_watch(
      options.content_dir,
      build_config.collections_path,
    ) {
    Ok(defs) => defs
    Err(diagnostic) => {
      print_diagnostic_main(diagnostic)
      return Err(1)
    }
  }
  let watch_roots : Array[String] = []
  watch_roots.push(effective_config_path)
  match build_config.collections_path {
    Some(path) => watch_roots.push(path)
    None => ()
  }
  match site.templates_dir {
    Some(path) => watch_roots.push(path)
    None => watch_roots.push(options.content_dir + "/templates")
  }
  match site.static_dir {
    Some(path) => watch_roots.push(options.content_dir + "/" + path)
    None => watch_roots.push(options.content_dir + "/static")
  }
  match site.data_dir {
    Some(path) => watch_roots.push(path)
    None => watch_roots.push(options.content_dir + "/data")
  }
  let mut i = 0
  while i < collections.length() {
    watch_roots.push(collections[i].content_dir)
    i = i + 1
  }
  Ok({ build_config, watch_roots })
}

///|
fn run_once(build_config : @builder.BuildConfig, check_mode : Bool) -> Int {
  if check_mode {
    let lint_result = @builder.check(build_config)
    let mut i = 0
    while i < lint_result.violations.length() {
      print_diagnostic_main(
        @diagnostic.of_lint_violation(lint_result.violations[i]),
      )
      i = i + 1
    }
    if @lint.has_violations(lint_result) {
      println(
        "[lattice] check failed: " +
        lint_result.violations.length().to_string() +
        " violation(s)",
      )
      return 1
    }
    println("[lattice] check passed: no violations")
    0
  } else {
    let cache_store = match @cache.load(build_config.output_dir) {
      Ok(store) => store
      Err(err) => {
        print_diagnostic_main(
          with_path(
            cli_warning("cache: " + @cache.error_text(err)),
            Some(build_config.output_dir),
            None,
            None,
          ),
        )
        @cache.empty(build_config.output_dir)
      }
    }
    let result = @builder.build(build_config, cache_store)
    let mut i = 0
    while i < result.diagnostics.length() {
      print_diagnostic_main(result.diagnostics[i])
      i = i + 1
    }
    result.errors
  }
}

///|
fn watch_timestamp() -> String {
  try {
    let dt = @time.PlainDateTime::from_unix_second(
      @watch.current_unix_second(),
      0,
      @time.utc_offset,
    )
    "[" + dt.to_string() + "Z]"
  } catch {
    _ => "[watch]"
  } noraise {
    value => value
  }
}

///|
fn run_watch(options : CliOptions, initial_state : CliState) -> Unit {
  @watch.clear_interrupt()
  @watch.install_sigint_handler()

  let initial_result = run_once(initial_state.build_config, options.check_mode)
  if initial_result > 0 {
    println(
      "[lattice] initial build finished with errors; watching for changes",
    )
  }

  let mut current_roots = initial_state.watch_roots
  let mut snapshot = @watch.take_snapshot(current_roots) catch {
    @watch.IOError(msg) => {
      print_diagnostic_main(cli_error("watch snapshot failed: " + msg))
      @sys.exit(1)
      return
    }
  }

  while true {
    @watch.sleep_ms(options.watch_interval_ms)
    if @watch.interrupted() {
      println("[lattice] watch stopped")
      return
    }
    let next_snapshot = @watch.take_snapshot(current_roots) catch {
      @watch.IOError(msg) => {
        print_diagnostic_main(cli_warning("watch snapshot failed: " + msg))
        continue
      }
    }
    let changed_paths = @watch.diff_paths(snapshot, next_snapshot)
    if changed_paths.length() == 0 {
      snapshot = next_snapshot
      continue
    }
    println(
      "[lattice] " +
      watch_timestamp() +
      " change detected in " +
      changed_paths.length().to_string() +
      " path(s); rebuilding",
    )
    match load_cli_state(options) {
      Ok(state) => {
        let _ = run_once(state.build_config, options.check_mode)
        current_roots = state.watch_roots
      }
      Err(_) => ()
    }
    snapshot = @watch.take_snapshot(current_roots) catch {
      @watch.IOError(msg) => {
        print_diagnostic_main(
          cli_warning("watch snapshot failed after rebuild: " + msg),
        )
        next_snapshot
      }
    }
    if @watch.interrupted() {
      println("[lattice] watch stopped")
      return
    }
  }
}

///|
fn main {
  let options = parse_cli_options(@sys.get_cli_args())
  let state = match load_cli_state(options) {
    Ok(state) => state
    Err(code) => {
      @sys.exit(code)
      return
    }
  }
  if options.watch_mode {
    run_watch(options, state)
    return
  }
  let exit_code = run_once(state.build_config, options.check_mode)
  if exit_code > 0 {
    @sys.exit(1)
  }
}
