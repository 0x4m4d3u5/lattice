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
  site : @config.SiteConfig
  collections_path : String?
}

///|
/// A source file loaded from the content directory.
pub(all) struct SourceFile {
  path : String
  filename : String
  slug : String
  content : String
}

priv struct CollectionSources {
  definition : @collections.CollectionDef
  sources : Array[SourceFile]
}

priv struct CollectionRenderResult {
  name : String
  pages : Array[@graph.GraphPage]
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
fn extract_date(fm : @frontmatter.Frontmatter) -> String? {
  match fm.fields.get("date") {
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
/// A document that passed frontmatter/schema/wikilink validation.
priv struct ProcessedDocument {
  html : String
  title : String
  url : String
  description : String?
  date : String?
  resolved_links : Array[@wikilink.ResolvedWikilink]
}

///|
fn char_at_builder(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

///|
fn escape_html_builder(s : String) -> String {
  let buf = StringBuilder::new()
  let n = s.length()
  let mut i = 0
  while i < n {
    let c = char_at_builder(s, i)
    if c == '&' {
      buf.write_string("&amp;")
    } else if c == '<' {
      buf.write_string("&lt;")
    } else if c == '>' {
      buf.write_string("&gt;")
    } else if c == '"' {
      buf.write_string("&quot;")
    } else {
      buf.write_char(c)
    }
    i = i + 1
  }
  buf.to_string()
}

fn trim_builder(s : String) -> String {
  let n = s.length()
  let mut lo = 0
  while lo < n &&
    (char_at_builder(s, lo) == ' ' ||
      char_at_builder(s, lo) == '\t' ||
      char_at_builder(s, lo) == '\r') {
    lo = lo + 1
  }
  let mut hi = n
  while hi > lo &&
    (char_at_builder(s, hi - 1) == ' ' ||
      char_at_builder(s, hi - 1) == '\t' ||
      char_at_builder(s, hi - 1) == '\r') {
    hi = hi - 1
  }
  let buf = StringBuilder::new()
  let mut i = lo
  while i < hi {
    buf.write_char(char_at_builder(s, i))
    i = i + 1
  }
  buf.to_string()
}

fn normalize_base_url_builder(base_url : String) -> String {
  let trimmed = trim_builder(base_url)
  if trimmed == "/" {
    return ""
  }
  if trimmed.has_suffix("/") {
    let buf = StringBuilder::new()
    let mut i = 0
    let end_pos = trimmed.length() - 1
    while i < end_pos {
      buf.write_char(char_at_builder(trimmed, i))
      i = i + 1
    }
    return buf.to_string()
  }
  trimmed
}

fn absolute_url_builder(base_url : String, path : String) -> String {
  let base = normalize_base_url_builder(base_url)
  if base.length() == 0 {
    return path
  }
  if path.length() == 0 {
    return base
  }
  if char_at_builder(path, 0) == '/' {
    base + path
  } else {
    base + "/" + path
  }
}

fn page_title_builder(page_title : String, site_title : String) -> String {
  if page_title == site_title {
    page_title
  } else {
    page_title + " | " + site_title
  }
}

fn collection_page_url(collection_name : String, slug : String) -> String {
  "/" + collection_name + "/" + slug + "/"
}

///|
/// Render a per-collection index page from successful pages + wikilinks.
fn render_collection_index(
  collection_name : String,
  pages : Array[@graph.GraphPage],
  site : @config.SiteConfig
) -> String {
  let title_by_slug : Map[String, String] = Map::new()
  let mut i = 0
  while i < pages.length() {
    let p = pages[i]
    title_by_slug.set(p.slug, p.title)
    i = i + 1
  }

  let body = StringBuilder::new()
  body.write_string("<main>\n")
  body.write_string("<h1>")
  body.write_string(escape_html_builder(collection_name))
  body.write_string(" Index</h1>\n")
  body.write_string(
    "<p>Generated from parsed pages and the validated wikilink graph for this collection.</p>\n",
  )

  body.write_string("<h2>Pages</h2>\n<ul>\n")
  i = 0
  while i < pages.length() {
    let p = pages[i]
    body.write_string("<li>")
    body.write_string(@html.anchor(p.url, p.title))
    body.write_string(" <code>")
    body.write_string(escape_html_builder(p.slug))
    body.write_string("</code></li>\n")
    i = i + 1
  }
  body.write_string("</ul>\n")

  body.write_string("<h2>Wikilink Graph</h2>\n")
  i = 0
  while i < pages.length() {
    let p = pages[i]
    body.write_string("<section>\n<h3>")
    body.write_string(@html.anchor(p.url, p.title))
    body.write_string("</h3>\n")
    body.write_string("<p>Source slug: <code>")
    body.write_string(escape_html_builder(p.slug))
    body.write_string("</code></p>\n")
    if p.outgoing.length() == 0 {
      body.write_string("<p>No outgoing wikilinks.</p>\n")
    } else {
      body.write_string("<ul>\n")
      let mut j = 0
      while j < p.outgoing.length() {
        let edge = p.outgoing[j]
        let target_title = match title_by_slug.get(edge.raw.target) {
          Some(t) => t
          None => edge.title
        }
        let display_note = match edge.raw.display {
          Some(d) => " (display: <code>" + escape_html_builder(d) + "</code>)"
          None => ""
        }
        body.write_string("<li>")
        body.write_string(@html.anchor(edge.url, target_title))
        body.write_string(" <code>")
        body.write_string(escape_html_builder(edge.raw.target))
        body.write_string("</code>")
        body.write_string(display_note)
        body.write_string("</li>\n")
        j = j + 1
      }
      body.write_string("</ul>\n")
    }
    body.write_string("</section>\n")
    i = i + 1
  }
  body.write_string("</main>\n")

  let meta : @html.PageMeta = {
    title: page_title_builder(collection_name + " index", site.title),
    description: Some(
      "Generated page graph for collection " + collection_name + " in " + site.title + ".",
    ),
    lang: "en",
    stylesheet: Some(absolute_url_builder(site.base_url, "/style.css")),
  }
  @html.render_page(meta, body.to_string())
}

fn load_collections(config : BuildConfig) -> Result[Array[@collections.CollectionDef], String] {
  match config.collections_path {
    None => {
      Ok([@collections.default_posts_collection(config.content_dir)])
    }
    Some(path) => {
      let source = try {
        @fs.read_file_to_string(path)
      } catch {
        @fs.IOError(msg) => return Err("cannot read collections file " + path + ": " + msg)
      }
      match @collections.parse(source) {
        Ok(parsed) => Ok(parsed.definitions)
        Err(@collections.InvalidLine(line, msg)) => {
          Err(path + ":" + line.to_string() + ": " + msg)
        }
        Err(@collections.MissingRequiredField(collection_name, field)) => {
          Err(
            path +
            ": missing required field '" +
            field +
            "' in collection '" +
            collection_name +
            "'",
          )
        }
        Err(@collections.DuplicateCollection(name)) => {
          Err(path + ": duplicate collection '" + name + "'")
        }
        Err(@collections.InvalidSchema(name, msg)) => {
          Err(path + ": invalid schema for collection '" + name + "': " + msg)
        }
        Err(@collections.EmptyConfig) => Err(path + ": no collections defined")
      }
    }
  }
}

///|
/// Process one markdown document through the full lattice pipeline.
///
/// Returns the rendered HTML5 page on success, or None if validation fails.
/// All errors are printed to stdout with the slug as context.
fn process_document(
  source : String,
  slug : String,
  url : String,
  context : String,
  page_index : Map[String, String],
  schema : @schema.Schema,
  site : @config.SiteConfig
) -> ProcessedDocument? {
  // Step 1: parse frontmatter
  let fm = match @frontmatter.parse(source) {
    Err(e) => {
      println("[error] " + context + ": frontmatter: " + e)
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
        "[error] " + context + ": schema: " + schema_errors[i].field + ": " + schema_errors[i].message,
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
        context +
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
  let title = extract_title(fm)
  let meta : @html.PageMeta = {
    title: page_title_builder(title, site.title),
    description: extract_description(fm),
    lang: "en",
    stylesheet: Some(absolute_url_builder(site.base_url, "/style.css")),
  }
  Some({
    html: @html.render_page(meta, body_html),
    title,
    url,
    description: extract_description(fm),
    date: extract_date(fm),
    resolved_links: resolved,
  })
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

  let collections = match load_collections(config) {
    Ok(defs) => defs
    Err(msg) => {
      println("[error] collections: " + msg)
      return 1
    }
  }
  println("[lattice] using " + collections.length().to_string() + " collections")

  // Pass 1: collect sources for each collection
  let collection_sources : Array[CollectionSources] = []
  let mut source_count = 0
  let mut i = 0
  while i < collections.length() {
    let collection_def = collections[i]
    let sources = try {
      collect_sources(collection_def.content_dir)
    } catch {
      @fs.IOError(msg) => {
        println(
          "[error] cannot read collection directory " +
          collection_def.content_dir +
          " (" +
          collection_def.name +
          "): " +
          msg,
        )
        return 1
      }
    }
    source_count = source_count + sources.length()
    collection_sources.push({ definition: collection_def, sources })
    i = i + 1
  }
  println("[lattice] found " + source_count.to_string() + " source files")

  // Build complete page index before any rendering begins.
  let page_index : Map[String, String] = Map::new()
  let slug_owner : Map[String, String] = Map::new()
  i = 0
  while i < collection_sources.length() {
    let coll = collection_sources[i]
    let mut j = 0
    while j < coll.sources.length() {
      let source = coll.sources[j]
      match slug_owner.get(source.slug) {
        Some(owner) => {
          println(
            "[error] duplicate slug '" +
            source.slug +
            "' in collections '" +
            owner +
            "' and '" +
            coll.definition.name +
            "'",
          )
          return 1
        }
        None => {
          slug_owner.set(source.slug, coll.definition.name)
          page_index.set(
            source.slug,
            collection_page_url(coll.definition.name, source.slug),
          )
        }
      }
      j = j + 1
    }
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
  let mut error_count = 0
  let mut written = 0
  let graph_pages : Array[@graph.GraphPage] = []
  let rendered_collections : Array[CollectionRenderResult] = []
  i = 0
  while i < collection_sources.length() {
    let coll = collection_sources[i]
    let coll_pages : Array[@graph.GraphPage] = []
    let collection_root = config.output_dir + "/" + coll.definition.name
    let collection_dir_ok = try {
      ensure_dir(collection_root)
      true
    } catch {
      @fs.IOError(msg) => {
        println(
          "[error] cannot create collection output directory " +
          collection_root +
          ": " +
          msg,
        )
        false
      }
    }
    if not(collection_dir_ok) {
      error_count = error_count + coll.sources.length()
      rendered_collections.push({ name: coll.definition.name, pages: coll_pages })
      i = i + 1
      continue
    }

    let mut j = 0
    while j < coll.sources.length() {
      let src = coll.sources[j]
      let page_url = collection_page_url(coll.definition.name, src.slug)
      let page_context = coll.definition.name + "/" + src.slug
      match process_document(
        src.content,
        src.slug,
        page_url,
        page_context,
        page_index,
        coll.definition.schema,
        config.site,
      ) {
        None => {
          error_count = error_count + 1
        }
        Some(doc) => {
          let page_dir = collection_root + "/" + src.slug
          let write_result = try {
            ensure_dir(page_dir)
            let out_path = page_dir + "/index.html"
            @fs.write_string_to_file(out_path, doc.html)
            Some(out_path)
          } catch {
            @fs.IOError(msg) => {
              println("[error] " + page_context + ": write failed: " + msg)
              None
            }
          }
          match write_result {
            Some(out_path) => {
              println("[lattice] wrote " + out_path)
              written = written + 1
              let page : @graph.GraphPage = {
                slug: src.slug,
                title: doc.title,
                url: doc.url,
                description: doc.description,
                date: doc.date,
                outgoing: doc.resolved_links,
              }
              coll_pages.push(page)
              graph_pages.push(page)
            }
            None => {
              error_count = error_count + 1
            }
          }
        }
      }
      j = j + 1
    }
    rendered_collections.push({ name: coll.definition.name, pages: coll_pages })
    i = i + 1
  }

  if error_count == 0 {
    i = 0
    while i < rendered_collections.length() {
      let coll = rendered_collections[i]
      let coll_dir = config.output_dir + "/" + coll.name

      let feed_write_ok = try {
        let feed_title = config.site.title + " (" + coll.name + ")"
        let feed_xml = @rss.render_feed(feed_title, config.site.base_url, coll.pages)
        let out_path = coll_dir + "/feed.xml"
        @fs.write_string_to_file(out_path, feed_xml)
        println("[lattice] wrote " + out_path)
        true
      } catch {
        @fs.IOError(msg) => {
          println("[error] " + coll.name + " feed: write failed: " + msg)
          false
        }
      }
      if not(feed_write_ok) {
        error_count = error_count + 1
      }

      let index_write_ok = try {
        let index_html = render_collection_index(coll.name, coll.pages, config.site)
        let out_path = coll_dir + "/index.html"
        @fs.write_string_to_file(out_path, index_html)
        println("[lattice] wrote " + out_path)
        true
      } catch {
        @fs.IOError(msg) => {
          println("[error] " + coll.name + " index: write failed: " + msg)
          false
        }
      }
      if not(index_write_ok) {
        error_count = error_count + 1
      }

      i = i + 1
    }

    if error_count == 0 {
      let sitemap_write_ok = try {
        let sitemap_xml = @sitemap.render_sitemap(config.site.base_url, graph_pages)
        let out_path = config.output_dir + "/sitemap.xml"
        @fs.write_string_to_file(out_path, sitemap_xml)
        println("[lattice] wrote " + out_path)
        true
      } catch {
        @fs.IOError(msg) => {
          println("[error] sitemap: write failed: " + msg)
          false
        }
      }
      if not(sitemap_write_ok) {
        error_count = error_count + 1
      }
    }
  } else {
    println("[warn] skipped collection feeds/indexes and sitemap generation due to prior build errors")
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
