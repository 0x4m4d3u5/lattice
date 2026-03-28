///|
/// Lattice — command-line entry point.
///
/// Subcommands:
///   lattice build [content-dir] [output-dir] [--config <path>] [--collections <path>] [--drafts] [--watch]
///   lattice check [content-dir] [output-dir] [--config <path>] [--collections <path>]
///   lattice serve [content-dir] [output-dir] [--port <N>] [--config <path>] [--collections <path>] [--drafts]
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

///|
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
  serve_mode : Bool
  serve_port : Int
}

///|
priv struct CliState {
  build_config : @builder.BuildConfig
  watch_roots : Array[String]
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
    @config.MissingCollectionField(collection, field) =>
      with_path(
        cli_error(
          "missing required field '" +
          field +
          "' in collection '" +
          collection +
          "'",
        ),
        Some(path),
        None,
        None,
      )
  }
}

///|
/// Build the clap parser with build/check/serve subcommands.
fn build_parser() -> @clap.Parser {
  @clap.Parser::new(
    prog="lattice",
    description="A static site generator where structural violations are type errors.",
    args={},
    subcmds={
      "build": @clap.SubCommand::new(
        args={
          "content-dir": @clap.Arg::positional(
            defaults=["./content"],
            help="Content directory",
          ),
          "output-dir": @clap.Arg::named(
            short='o',
            nargs=One,
            defaults=[""],
            help="Output directory (default: config.output_dir or ./dist)",
          ),
          "config": @clap.Arg::named(
            short='c',
            nargs=One,
            defaults=[""],
            help="Override site config file",
          ),
          "collections": @clap.Arg::named(
            nargs=One,
            defaults=[""],
            help="Override collections config file",
          ),
          "drafts": @clap.Arg::flag(help="Include draft posts in the build"),
          "force": @clap.Arg::flag(
            help="Ignore incremental cache and rebuild everything",
          ),
          "watch": @clap.Arg::flag(help="Rebuild on file changes with polling"),
          "watch-interval": @clap.Arg::named(
            short='i',
            nargs=One,
            defaults=["500"],
            help="Polling interval in milliseconds (default: 500)",
          ),
        },
        help="Build the site",
      ),
      "check": @clap.SubCommand::new(
        args={
          "content-dir": @clap.Arg::positional(
            defaults=["./content"],
            help="Content directory",
          ),
          "output-dir": @clap.Arg::named(
            short='o',
            nargs=One,
            defaults=[""],
            help="Output directory (default: config.output_dir or ./dist)",
          ),
          "config": @clap.Arg::named(
            short='c',
            nargs=One,
            defaults=[""],
            help="Override site config file",
          ),
          "collections": @clap.Arg::named(
            nargs=One,
            defaults=[""],
            help="Override collections config file",
          ),
        },
        help="Run validation/lint pipeline only",
      ),
      "serve": @clap.SubCommand::new(
        args={
          "content-dir": @clap.Arg::positional(
            defaults=["./content"],
            help="Content directory",
          ),
          "output-dir": @clap.Arg::named(
            short='o',
            nargs=One,
            defaults=[""],
            help="Output directory (default: config.output_dir or ./dist)",
          ),
          "config": @clap.Arg::named(
            short='c',
            nargs=One,
            defaults=[""],
            help="Override site config file",
          ),
          "collections": @clap.Arg::named(
            nargs=One,
            defaults=[""],
            help="Override collections config file",
          ),
          "port": @clap.Arg::named(
            short='p',
            nargs=One,
            defaults=["4321"],
            help="HTTP port for dev server (default: 4321)",
          ),
          "drafts": @clap.Arg::flag(help="Include draft posts in the build"),
        },
        help="Start dev server with live reload",
      ),
      "init": @clap.SubCommand::new(
        args={
          "name": @clap.Arg::positional(
            defaults=["my-site"],
            help="Site directory name (default: my-site)",
          ),
        },
        help="Scaffold a new Lattice site",
      ),
    },
  )
}

///|
fn safe_get_one(sv : @clap.SimpleValue, name : String) -> String? {
  let result : Result[String, _] = try? sv.get_one(name)
  match result {
    Ok(v) => Some(v)
    Err(_) => None
  }
}

///|
/// Extract CliOptions from the parsed clap SimpleValue.
/// `subcmd_name` is "build", "check", or "serve".
fn cli_options_from_clap(
  sv : @clap.SimpleValue,
  subcmd_name : String,
) -> CliOptions {
  let content_dir = if sv.positional_args.length() > 0 {
    sv.positional_args[0]
  } else {
    "./content"
  }
  let output_dir_raw = safe_get_one(sv, "output-dir").unwrap_or("")
  let output_dir : String? = if output_dir_raw.length() == 0 {
    None
  } else {
    Some(output_dir_raw)
  }
  let config_raw = safe_get_one(sv, "config").unwrap_or("")
  let config_path : String? = if config_raw.length() == 0 {
    None
  } else {
    Some(config_raw)
  }
  let collections_raw = safe_get_one(sv, "collections").unwrap_or("")
  let collections_path : String? = if collections_raw.length() == 0 {
    None
  } else {
    Some(collections_raw)
  }
  let include_drafts = sv.get_flag("drafts").unwrap_or(false)

  match subcmd_name {
    "build" => {
      let watch_mode = sv.get_flag("watch").unwrap_or(false)
      let force_rebuild = sv.get_flag("force").unwrap_or(false)
      let watch_interval_str = safe_get_one(sv, "watch-interval").unwrap_or(
        "500",
      )
      let watch_interval_ms = match parse_positive_int(watch_interval_str) {
        Some(n) => n
        None => 500
      }
      {
        content_dir,
        output_dir,
        config_path,
        collections_path,
        check_mode: false,
        force_rebuild,
        watch_mode,
        watch_interval_ms,
        include_drafts,
        serve_mode: false,
        serve_port: @serve.default_port(),
      }
    }
    "check" =>
      {
        content_dir,
        output_dir,
        config_path,
        collections_path,
        check_mode: true,
        force_rebuild: false,
        watch_mode: false,
        watch_interval_ms: 500,
        include_drafts: false,
        serve_mode: false,
        serve_port: @serve.default_port(),
      }
    "serve" => {
      let port_str = safe_get_one(sv, "port").unwrap_or("4321")
      let serve_port = match parse_positive_int(port_str) {
        Some(n) =>
          if @serve.is_valid_port(n) {
            n
          } else {
            @serve.default_port()
          }
        None => @serve.default_port()
      }
      {
        content_dir,
        output_dir,
        config_path,
        collections_path,
        check_mode: false,
        force_rebuild: false,
        watch_mode: true,
        watch_interval_ms: 500,
        include_drafts,
        serve_mode: true,
        serve_port,
      }
    }
    _ =>
      {
        content_dir,
        output_dir,
        config_path,
        collections_path,
        check_mode: false,
        force_rebuild: false,
        watch_mode: false,
        watch_interval_ms: 500,
        include_drafts: false,
        serve_mode: false,
        serve_port: @serve.default_port(),
      }
  }
}

///|
fn parse_positive_int(value : String) -> Int? {
  if value.length() == 0 {
    return None
  }
  let mut parsed = 0
  let mut i = 0
  while i < value.length() {
    let c = value[i].unsafe_to_char()
    if c < '0' || c > '9' {
      return None
    }
    parsed = parsed * 10 + (@strutil.char_at(value, i).to_int() - '0'.to_int())
    i = i + 1
  }
  if parsed <= 0 {
    return None
  }
  Some(parsed)
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
fn load_inline_collections(
  entries : Array[@config.CollectionEntry],
) -> Result[Array[@collections.CollectionDef], @diagnostic.Diagnostic] {
  let defs : Array[@collections.CollectionDef] = []
  let mut i = 0
  while i < entries.length() {
    let entry = entries[i]
    let schema = match entry.schema {
      Some(schema_text) =>
        match @collections.parse_schema_string(entry.name, schema_text) {
          Ok(s) => s
          Err(err) => return Err(collections_error_diagnostic("<inline>", err))
        }
      None =>
        return Err(
          with_path(
            cli_error("missing schema for collection '" + entry.name + "'"),
            None,
            None,
            None,
          ),
        )
    }
    defs.push({
      name: entry.name,
      schema,
      content_dir: entry.dir,
      template: entry.template,
      page_size: entry.page_size,
      sort_order: @collections.DateDesc,
    })
    i = i + 1
  }
  Ok(defs)
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

  let collections = if site.collections.length() > 0 &&
    options.collections_path == None {
    match load_inline_collections(site.collections) {
      Ok(defs) => defs
      Err(diagnostic) => {
        print_diagnostic_main(diagnostic)
        return Err(1)
      }
    }
  } else {
    match
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
      let summary = @lint.summarize(lint_result)
      println(@lint.format_summary(summary))
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
    if result.errors == 0 {
      println(
        "[lattice] built " +
        result.rebuilt_pages.to_string() +
        " page(s) [" +
        result.unchanged_pages.to_string() +
        " unchanged]",
      )
    } else {
      let summary = @diagnostic.summarize(result.diagnostics)
      println(@diagnostic.format_summary(summary))
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
  if options.serve_mode {
    @serve.broadcast_reload()
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
      if options.serve_mode {
        @serve.stop()
      }
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
        if options.serve_mode {
          @serve.broadcast_reload()
        }
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
      if options.serve_mode {
        @serve.stop()
      }
      return
    }
  }
}

///|
fn run_main() -> Unit {
  let args = @sys.get_cli_args()
  let parser = build_parser()
  let sv = @clap.SimpleValue::new("lattice")

  let parse_result : Result[String?, @clap.ParserError] = try? parser.parse(
    sv,
    args[1:].to_array(),
  )

  match parse_result {
    Ok(help_message) =>
      match help_message {
        Some(msg) => {
          println(msg)
          return
        }
        None => ()
      }
    Err(err) => {
      println(err.to_string())
      println("")
      println(parser.gen_help_message(["lattice"], {}))
      @sys.exit(1)
      return
    }
  }

  // Determine which subcommand was selected
  let subcmd_name = match sv.subcmd {
    Some(sub) => sub.name
    None => {
      // No subcommand — show help
      println(parser.gen_help_message(["lattice"], {}))
      return
    }
  }

  let subcmd_sv = sv.subcmd.unwrap()

  // Handle 'init' subcommand early — no config loading needed
  if subcmd_name == "init" {
    let name = if subcmd_sv.positional_args.length() > 0 {
      subcmd_sv.positional_args[0]
    } else {
      "my-site"
    }
    match @scaffold.scaffold_site(name) {
      Ok(_) => println("[lattice] created site in ./" + name)
      Err(msg) => {
        print_diagnostic_main(cli_error(msg))
        @sys.exit(1)
        return
      }
    }
    return
  }

  let options = cli_options_from_clap(subcmd_sv, subcmd_name)

  // Validate port for serve
  if options.serve_mode && not(@serve.is_valid_port(options.serve_port)) {
    print_diagnostic_main(
      cli_error("invalid port: " + options.serve_port.to_string()),
    )
    @sys.exit(1)
    return
  }

  let state = match load_cli_state(options) {
    Ok(state) => state
    Err(code) => {
      @sys.exit(code)
      return
    }
  }

  if options.serve_mode {
    let output_dir = state.build_config.output_dir
    if not(@serve.start(options.serve_port, output_dir)) {
      print_diagnostic_main(
        cli_error(
          "failed to start dev server on port " +
          options.serve_port.to_string() +
          " — is the port already in use?",
        ),
      )
      @sys.exit(1)
      return
    }
    println(
      "[lattice] dev server listening on http://localhost:" +
      options.serve_port.to_string() +
      "  (serving " +
      output_dir +
      ")",
    )
    println("[lattice] watching for changes — press Ctrl-C to stop")
    run_watch(options, state)
    return
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

///|
fn main {
  run_main()
}
