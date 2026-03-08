///|
/// Lattice builder — file I/O layer and two-pass build orchestration.
///
/// Two-pass design:
///   Pass 1: Collect all .md source files; compute slugs; build the complete
///           page index (slug → canonical URL).
///   Pass 2: For each source, run the full pipeline and write HTML output.
///
/// Structural property: the page index is complete before any wikilink is
/// resolved. Every [[link]] target is known at render time — no forward-
/// reference problem, no deferred 404s.

///|
/// Configuration for a single lattice build.
pub(all) struct BuildConfig {
  content_dir : String
  output_dir : String
  site_title : String
  base_url : String
}

///|
/// A source file loaded from the content directory.
pub(all) struct SourceFile {
  path : String
  filename : String
  slug : String
  content : String
}

// ── schema ────────────────────────────────────────────────────────────────────

///|
/// The schema for the default "post" content collection.
///
/// Required: title (String), date (String).
/// Optional: description (String), tags (Array[String]), draft (Bool).
///
/// Structural design note: the schema is declared in MoonBit code, not in a
/// config file. Schema changes are tracked in version control and violations
/// are caught at build time, not at deploy time.
fn post_schema() -> @schema.Schema {
  {
    name: "post",
    fields: [
      { name: "title", field_type: @schema.TString, required: true },
      { name: "date", field_type: @schema.TString, required: true },
      {
        name: "description",
        field_type: @schema.TOptional(@schema.TString),
        required: false,
      },
      {
        name: "tags",
        field_type: @schema.TOptional(@schema.TArray(@schema.TString)),
        required: false,
      },
      {
        name: "draft",
        field_type: @schema.TOptional(@schema.TBool),
        required: false,
      },
    ],
  }
}

// ── pipeline helpers ──────────────────────────────────────────────────────────

///|
fn extract_title(fm : @frontmatter.Frontmatter) -> String {
  match fm.fields.get("title") {
    Some(@frontmatter.FStr(t)) => t
    _ => "Untitled"
  }
}

///|
fn extract_description(fm : @frontmatter.Frontmatter) -> String? {
  match fm.fields.get("description") {
    Some(@frontmatter.FStr(d)) => Some(d)
    _ => None
  }
}

///|
fn build_wikilink_map(
  resolved : Array[@wikilink.ResolvedWikilink]
) -> Map[String, String] {
  let m : Map[String, String] = Map::new()
  let mut i = 0
  while i < resolved.length() {
    m.set(resolved[i].raw.target, resolved[i].url)
    i = i + 1
  }
  m
}

///|
/// Process one markdown document through the full lattice pipeline.
///
/// Returns the rendered HTML5 page on success, or None if validation fails.
/// All errors are printed to stdout with the slug as context.
fn process_document(
  source : String,
  slug : String,
  page_index : Map[String, String],
  schema : @schema.Schema
) -> String? {
  // Step 1: parse frontmatter
  let fm = match @frontmatter.parse(source) {
    Err(e) => {
      println("[error] " + slug + ": frontmatter: " + e)
      return None
    }
    Ok(fm) => fm
  }
  // Step 2: validate against schema — collect all errors before aborting
  let schema_errors = @schema.validate(fm, schema)
  if schema_errors.length() > 0 {
    let mut i = 0
    while i < schema_errors.length() {
      println(
        "[error] " + slug + ": schema: " + schema_errors[i].field + ": " + schema_errors[i].message,
      )
      i = i + 1
    }
    return None
  }
  // Step 3: extract wikilinks; resolve against page index
  let raw_links = @wikilink.extract(fm.body, slug)
  let (resolved, link_errors) = @wikilink.resolve(raw_links, page_index)
  if link_errors.length() > 0 {
    let mut i = 0
    while i < link_errors.length() {
      println(
        "[error] " +
        slug +
        ": broken wikilink [[" +
        link_errors[i].link.target +
        "]]: " +
        link_errors[i].message,
      )
      i = i + 1
    }
    return None
  }
  // Step 4: build wikilink map for the renderer
  let wl_map = build_wikilink_map(resolved)
  // Step 5: render markdown body to HTML fragment
  let body_html = @markdown.render(fm.body, wl_map)
  // Step 6: emit the complete HTML5 page
  let meta : @html.PageMeta = {
    title: extract_title(fm),
    description: extract_description(fm),
    lang: "en",
    stylesheet: Some("/style.css"),
  }
  Some(@html.render_page(meta, body_html))
}

// ── file I/O layer ────────────────────────────────────────────────────────────

///|
/// Collect all .md files from `content_dir`.
///
/// Each SourceFile is loaded eagerly: the full content is read in pass 1 so
/// pass 2 can focus on transformation without additional I/O interleaved with
/// the render loop.
pub fn collect_sources(content_dir : String) -> Array[SourceFile] raise @fs.IOError {
  let entries = @fs.read_dir(content_dir)
  let sources : Array[SourceFile] = []
  let mut i = 0
  while i < entries.length() {
    let filename = entries[i]
    if filename.has_suffix(".md") {
      let path = content_dir + "/" + filename
      let content = @fs.read_file_to_string(path)
      let file_slug = @slug.filename_to_slug(filename)
      sources.push({ path, filename, slug: file_slug, content })
    }
    i = i + 1
  }
  sources
}

///|
/// Ensure a single-level directory exists, creating it if absent.
fn ensure_dir(path : String) -> Unit raise @fs.IOError {
  if not(@fs.path_exists(path)) {
    @fs.create_dir(path)
  }
}

///|
/// Build the full site.
///
/// Returns the number of pages that failed to render (0 = clean build).
///
/// Pass 1: read the content directory, compute slugs, build the page index.
/// Pass 2: run each source through the pipeline, write HTML to output_dir.
///
/// Each page is written to `output_dir/<slug>/index.html` for clean URLs.
pub fn build(config : BuildConfig) -> Int {
  println("[lattice] building " + config.content_dir + " → " + config.output_dir)

  // Pass 1: collect sources
  let sources = try {
    collect_sources(config.content_dir)
  } catch {
    @fs.IOError(msg) => {
      println("[error] cannot read content directory: " + msg)
      return 1
    }
  }
  println("[lattice] found " + sources.length().to_string() + " source files")

  // Build complete page index before any rendering begins
  let page_index : Map[String, String] = Map::new()
  let mut i = 0
  while i < sources.length() {
    let url = @slug.slug_to_url(sources[i].slug)
    page_index.set(sources[i].slug, url)
    i = i + 1
  }

  // Ensure output directory exists
  let dir_ok = try {
    ensure_dir(config.output_dir)
    true
  } catch {
    @fs.IOError(msg) => {
      println("[error] cannot create output directory: " + msg)
      false
    }
  }
  if not(dir_ok) {
    return 1
  }

  // Write default CSS (once, if not already present)
  let css_path = config.output_dir + "/style.css"
  if not(@fs.path_exists(css_path)) {
    let write_ok = try {
      @fs.write_string_to_file(css_path, default_css())
      true
    } catch {
      @fs.IOError(msg) => {
        println("[warn] could not write style.css: " + msg)
        false
      }
    }
    if write_ok {
      println("[lattice] wrote " + css_path)
    }
  }

  // Pass 2: render and write each page
  let schema = post_schema()
  let mut error_count = 0
  let mut written = 0
  i = 0
  while i < sources.length() {
    let src = sources[i]
    match process_document(src.content, src.slug, page_index, schema) {
      None => {
        error_count = error_count + 1
      }
      Some(html) => {
        // Clean URL: /slug/index.html
        let page_dir = config.output_dir + "/" + src.slug
        let write_result = try {
          ensure_dir(page_dir)
          let out_path = page_dir + "/index.html"
          @fs.write_string_to_file(out_path, html)
          Some(out_path)
        } catch {
          @fs.IOError(msg) => {
            println("[error] " + src.slug + ": write failed: " + msg)
            None
          }
        }
        match write_result {
          Some(out_path) => {
            println("[lattice] wrote " + out_path)
            written = written + 1
          }
          None => {
            error_count = error_count + 1
          }
        }
      }
    }
    i = i + 1
  }

  println(
    "[lattice] " +
    written.to_string() +
    " pages written, " +
    error_count.to_string() +
    " errors",
  )
  error_count
}

// ── default CSS ───────────────────────────────────────────────────────────────

///|
/// Minimal default stylesheet.
fn default_css() -> String {
  "/* lattice default styles */\n" +
  "*, *::before, *::after { box-sizing: border-box; }\n" +
  "body {\n" +
  "  font-family: system-ui, -apple-system, sans-serif;\n" +
  "  max-width: 780px;\n" +
  "  margin: 0 auto;\n" +
  "  padding: 2rem 1.5rem;\n" +
  "  line-height: 1.7;\n" +
  "  color: #1a1a2e;\n" +
  "  background: #fafafa;\n" +
  "}\n" +
  "h1, h2, h3 { line-height: 1.3; margin-top: 2rem; }\n" +
  "a { color: #2563eb; text-decoration-thickness: 1px; }\n" +
  "a:hover { text-decoration-thickness: 2px; }\n" +
  "code {\n" +
  "  background: #f1f5f9;\n" +
  "  padding: 0.15em 0.35em;\n" +
  "  border-radius: 3px;\n" +
  "  font-family: ui-monospace, monospace;\n" +
  "  font-size: 0.9em;\n" +
  "}\n" +
  "pre { background: #f1f5f9; padding: 1.25rem; border-radius: 6px; overflow-x: auto; }\n" +
  "pre code { background: none; padding: 0; font-size: 1em; }\n" +
  "blockquote {\n" +
  "  border-left: 3px solid #cbd5e1;\n" +
  "  margin: 0;\n" +
  "  padding: 0.5rem 1.25rem;\n" +
  "  color: #475569;\n" +
  "}\n" +
  "nav { margin-bottom: 2.5rem; padding-bottom: 1rem; border-bottom: 1px solid #e2e8f0; }\n" +
  "nav a { margin-right: 1.25rem; font-weight: 500; text-decoration: none; }\n" +
  "nav a:hover { text-decoration: underline; }\n"
}
