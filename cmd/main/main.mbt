///|
/// Lattice — command-line entry point.
///
/// Usage:
///   lattice [content-dir] [output-dir]
///
/// Defaults:
///   content-dir → ./content
///   output-dir  → ./dist
///
/// The build is two-pass:
///   1. Collect all .md files from content-dir, compute slugs, build page index.
///   2. Render each page through the full pipeline; write HTML to output-dir.
///
/// Exit codes: 0 = clean build, 1 = one or more errors.

fn main {
  let args = @sys.get_cli_args()
  // args[0] is the program name
  let content_dir = if args.length() > 1 { args[1] } else { "./content" }
  let output_dir = if args.length() > 2 { args[2] } else { "./dist" }
  let config : @builder.BuildConfig = {
    content_dir,
    output_dir,
    site_title: "My Lattice Site",
    base_url: "/",
  }
  let error_count = @builder.build(config)
  if error_count > 0 {
    @sys.exit(1)
  }
}
