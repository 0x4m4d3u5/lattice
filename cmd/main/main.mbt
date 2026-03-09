///|
/// Lattice — command-line entry point.
///
/// Usage:
///   lattice [content-dir] [output-dir] [--config path] [--collections path]
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

fn char_at_main(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

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

fn substr_main(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = start
  while i < end {
    buf.write_char(char_at_main(s, i))
    i = i + 1
  }
  buf.to_string()
}

fn main {
  let args = @sys.get_cli_args()

  // args[0] is the program name
  let positionals : Array[String] = []
  let mut config_path : String? = None
  let mut collections_path : String? = None
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "--config" {
      if i + 1 >= args.length() {
        println("[error] missing value for --config")
        @sys.exit(1)
      }
      config_path = Some(args[i + 1])
      i = i + 2
    } else if starts_with_main(arg, "--config=") {
      let value = substr_main(arg, 9, arg.length())
      if value.length() == 0 {
        println("[error] missing value for --config")
        @sys.exit(1)
      }
      config_path = Some(value)
      i = i + 1
    } else if arg == "--collections" {
      if i + 1 >= args.length() {
        println("[error] missing value for --collections")
        @sys.exit(1)
      }
      collections_path = Some(args[i + 1])
      i = i + 2
    } else if starts_with_main(arg, "--collections=") {
      let value = substr_main(arg, 14, arg.length())
      if value.length() == 0 {
        println("[error] missing value for --collections")
        @sys.exit(1)
      }
      collections_path = Some(value)
      i = i + 1
    } else {
      positionals.push(arg)
      i = i + 1
    }
  }

  let content_dir = if positionals.length() > 0 {
    positionals[0]
  } else {
    "./content"
  }
  let effective_config_path = match config_path {
    Some(path) => path
    None => content_dir + "/lattice.conf"
  }

  let config_source = try {
    @fs.read_file_to_string(effective_config_path)
  } catch {
    @fs.IOError(msg) => {
      println("[error] cannot read config file " + effective_config_path + ": " + msg)
      @sys.exit(1)
      return
    }
  }

  let site = match @config.parse(config_source) {
    Ok(c) => c
    Err(@config.InvalidLine(line, msg)) => {
      println(
        "[error] config parse error " +
        effective_config_path +
        ":" +
        line.to_string() +
        ": " +
        msg,
      )
      @sys.exit(1)
      return
    }
    Err(@config.MissingRequiredField(field)) => {
      println("[error] config missing required field: " + field)
      @sys.exit(1)
      return
    }
    Err(@config.InvalidValue(field, msg)) => {
      println("[error] invalid config value for " + field + ": " + msg)
      @sys.exit(1)
      return
    }
  }

  let output_dir = if positionals.length() > 1 {
    positionals[1]
  } else {
    match site.output_dir {
      Some(path) => path
      None => "./dist"
    }
  }

  let build_config : @builder.BuildConfig = {
    content_dir,
    output_dir,
    site,
    collections_path: match collections_path {
      Some(path) => Some(path)
      None => site.collections_file
    },
  }
  let error_count = @builder.build(build_config)
  if error_count > 0 {
    @sys.exit(1)
  }
}
