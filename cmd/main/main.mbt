///|
/// Lattice — structural SSG entry point.
///
/// Demonstrates the full build pipeline on a sample document:
///   1. Parse frontmatter (TOML-style key-value pairs in --- block)
///   2. Validate frontmatter against a content collection schema
///   3. Extract and resolve wikilinks against the page index
///   4. Render markdown body to an HTML fragment
///   5. Emit a complete HTML5 page
///
/// Structural guarantee: schema violations and broken wikilinks are reported
/// as build errors before any HTML is rendered. The render step only runs on
/// structurally valid input.
///
/// Run with: moon run cmd/main

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

fn print_schema_errors(errors : Array[@schema.ValidationError]) -> Unit {
  let mut i = 0
  while i < errors.length() {
    println("[schema error] " + errors[i].field + ": " + errors[i].message)
    i = i + 1
  }
}

fn print_link_errors(errors : Array[@wikilink.ResolutionError]) -> Unit {
  let mut i = 0
  while i < errors.length() {
    println(
      "[wikilink error] " +
      errors[i].link.source_file +
      ": target '" +
      errors[i].link.target +
      "' not found — " +
      errors[i].message,
    )
    i = i + 1
  }
}

/// The schema for a blog post content collection.
///
/// Required fields: title (String), date (String).
/// Optional fields: description (String), tags (Array[String]), draft (Bool).
///
/// Structural design note: the schema is declared in MoonBit code, not in a
/// configuration file. This means schema changes are tracked in version control
/// and violations are caught at build time, not at deploy time.
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

/// Extract the title string from a validated frontmatter map.
/// Falls back to "Untitled" if the field is absent or not a string.
fn extract_title(fm : @frontmatter.Frontmatter) -> String {
  match fm.fields.get("title") {
    Some(@frontmatter.FStr(t)) => t
    _ => "Untitled"
  }
}

/// Extract the description string from a validated frontmatter map.
fn extract_description(fm : @frontmatter.Frontmatter) -> String? {
  match fm.fields.get("description") {
    Some(@frontmatter.FStr(d)) => Some(d)
    _ => None
  }
}

/// Process one markdown document through the full lattice pipeline.
///
/// `source` is the raw file content (frontmatter + body).
/// `slug` is the page slug used as the source_file identifier for wikilinks.
/// `page_index` maps wikilink target slugs to their resolved page URLs.
///
/// Returns the rendered HTML5 page string, or prints errors and returns None.
fn process_document(
  source : String,
  slug : String,
  page_index : Map[String, String]
) -> String? {
  // Step 1: parse frontmatter
  let fm = match @frontmatter.parse(source) {
    Err(e) => {
      println("[frontmatter error] " + slug + ": " + e)
      return None
    }
    Ok(fm) => fm
  }
  // Step 2: validate against schema — collect all errors before aborting
  let schema_errors = @schema.validate(fm, post_schema())
  if schema_errors.length() > 0 {
    print_schema_errors(schema_errors)
    return None
  }
  // Step 3: extract wikilinks from body; resolve against page index
  let raw_links = @wikilink.extract(fm.body, slug)
  let (resolved, link_errors) = @wikilink.resolve(raw_links, page_index)
  // Broken wikilinks are hard build errors — report all then abort
  if link_errors.length() > 0 {
    print_link_errors(link_errors)
    return None
  }
  // Step 4: build the resolved wikilink map for the renderer
  let wl_map = build_wikilink_map(resolved)
  // Step 5: render markdown body to HTML fragment
  let body_html = @markdown.render(fm.body, wl_map)
  // Step 6: emit complete HTML5 page
  let meta : @html.PageMeta = {
    title: extract_title(fm),
    description: extract_description(fm),
    lang: "en",
    stylesheet: Some("/style.css"),
  }
  Some(@html.render_page(meta, body_html))
}

fn main {
  // Sample document exercising the full pipeline.
  // In a complete build, this content would be read from .md files in the
  // content directory, and the page_index would be built from all pages first.
  let sample_source =
    "---\ntitle = \"Hello, Lattice\"\ndate = \"2026-03-08\"\ndescription = \"A demo of the lattice SSG pipeline.\"\ntags = [\"moonbit\", \"ssg\", \"demo\"]\n---\n# Hello, Lattice\n\nWelcome to **lattice** — a static site generator where structural violations\nare *type errors*, not runtime surprises.\n\n## What this demonstrates\n\n- Frontmatter parsed from TOML-style key-value pairs\n- Schema validation: missing required fields are build errors\n- Wikilinks to other pages are validated at build time, not at page load\n- Markdown rendered to HTML: **bold**, *italic*, `inline code`\n\n## Code example\n\n```moonbit\nfn main {\n  println(\"structural integrity, not just types\")\n}\n```\n\n> The opposite of a runtime error isn't no error — it's a build error.\n> Build errors are caught before deployment. Runtime errors are caught by users.\n\n## A working link\n\nSee [MoonBit](https://www.moonbitlang.com) for the language reference.\n"
  let slug = "hello-lattice"
  // Page index: in a real build this maps every page slug to its output URL.
  // Here it's empty because the sample has no wikilinks pointing to other pages.
  let page_index : Map[String, String] = Map::new()
  match process_document(sample_source, slug, page_index) {
    Some(html) => println(html)
    None => println("[build] pipeline aborted due to errors above")
  }
}
