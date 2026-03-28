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
  config_path : String
  site : @config.SiteConfig
  collections_path : String?
  force_rebuild : Bool
  include_drafts : Bool
}

///|
/// A source file loaded from the content directory.
pub(all) struct SourceFile {
  path : String
  filename : String
  slug : String
  content : String
  fingerprint : String
  stamp : Int64
  link_targets : Array[String]
}

///|
pub(all) struct BuildResult {
  errors : Int
  diagnostics : Array[@diagnostic.Diagnostic]
  rebuilt_pages : Int
  unchanged_pages : Int
  skipped_drafts : Int
  redirect_count : Int
}

///|
priv struct CollectionSources {
  definition : @collections.CollectionDef
  sources : Array[SourceFile]
}

///|
priv struct CollectionRenderResult {
  name : String
  pages : Array[@graph.GraphPage]
  page_size : Int?
}

///|
priv struct BuildTemplates {
  page : @template.Template?
  index : @template.Template?
  tag_page : @template.Template?
  tag_index : @template.Template?
  archive : @template.Template?
}

///|
priv struct TemplateLoadResult {
  templates : BuildTemplates
  violations : Array[@lint.LintViolation]
}

///|
priv struct TagCatalog {
  ordered_slugs : Array[String]
  name_by_slug : Map[String, String]
}

///|
priv struct ProjectLayout {
  collections : Array[@collections.CollectionDef]
  data_schemas : Map[String, @data.DataSchema]
}

///|
priv struct IncrementalState {
  force_full_rebuild : Bool
  previous_entries : Map[String, @manifest.ManifestEntry]
  changed_sources : Map[String, Bool]
}

///|
/// A page that links to another page — used to build the backlinks index.
priv struct BacklinkRef {
  url : String
  title : String
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
fn extract_og_image(fm : @frontmatter.Frontmatter) -> String? {
  match fm.fields.get("og_image") {
    Some(@frontmatter.FStr(img)) => Some(img)
    _ => None
  }
}

///|
fn extract_date(fm : @frontmatter.Frontmatter) -> String? {
  match fm.fields.get("date") {
    Some(@frontmatter.FDate(d)) => Some(d)
    Some(@frontmatter.FStr(d)) => Some(d)
    _ => None
  }
}

///|
fn extract_author(fm : @frontmatter.Frontmatter) -> String? {
  match fm.fields.get("author") {
    Some(@frontmatter.FStr(author)) => Some(author)
    _ => None
  }
}

///|
fn extract_toc_enabled(fm : @frontmatter.Frontmatter) -> Bool {
  match fm.fields.get("toc") {
    Some(@frontmatter.FBool(enabled)) => enabled
    _ => true
  }
}

///|
fn extract_toc_depth(fm : @frontmatter.Frontmatter) -> Int {
  match fm.fields.get("toc_depth") {
    Some(@frontmatter.FInt(depth)) =>
      if depth < 2 {
        1
      } else if depth > 6 {
        6
      } else {
        depth
      }
    _ => 3
  }
}

///|
fn extract_template(fm : @frontmatter.Frontmatter) -> String? {
  match fm.fields.get("template") {
    Some(@frontmatter.FStr(t)) => Some(t)
    _ => None
  }
}

///|
fn is_draft(fm : @frontmatter.Frontmatter) -> Bool {
  match fm.fields.get("draft") {
    Some(@frontmatter.FBool(true)) => true
    _ => false
  }
}

///|
/// Convert frontmatter fields to a map of string values for template rendering.
/// This enables templates to access any validated frontmatter field using {{page.field}}.
pub fn frontmatter_to_strings(
  fm : @frontmatter.Frontmatter,
) -> Map[String, String] {
  let result : Map[String, String] = Map::new()
  fn convert_value(val : @frontmatter.FrontmatterValue) -> String {
    match val {
      @frontmatter.FStr(s) => s
      @frontmatter.FDate(d) => d
      @frontmatter.FInt(n) => "\{n}"
      @frontmatter.FBool(true) => "true"
      @frontmatter.FBool(false) => "false"
      @frontmatter.FArray(items) => {
        let parts : Array[String] = []
        let mut i = 0
        while i < items.length() {
          parts.push(convert_value(items[i]))
          i = i + 1
        }
        // Join with comma and space
        let buf = StringBuilder::new()
        let mut j = 0
        while j < parts.length() {
          buf.write_string(parts[j])
          if j < parts.length() - 1 {
            buf.write_string(", ")
          }
          j = j + 1
        }
        buf.to_string()
      }
      @frontmatter.FMap(_) => "" // Map values not yet supported in templates
    }
  }
  for key, value in fm.fields {
    result.set(key, convert_value(value))
  }
  result
}

///|
/// Extract frontmatter array fields for template iteration.
/// Returns a Map of field names to string arrays for use with {{#each page.field}}.
/// Only FArray fields are extracted; FMap fields are skipped.
pub fn frontmatter_to_arrays(
  fm : @frontmatter.Frontmatter,
) -> Map[String, Array[String]] {
  let result : Map[String, Array[String]] = Map::new()
  let convert_scalar_to_string = fn(
    val : @frontmatter.FrontmatterValue,
  ) -> String {
    match val {
      @frontmatter.FStr(s) => s
      @frontmatter.FDate(d) => d
      @frontmatter.FInt(n) => "\{n}"
      @frontmatter.FBool(true) => "true"
      @frontmatter.FBool(false) => "false"
      _ => "" // FMap and FArray not supported as scalar
    }
  }
  let convert_array = fn(
    val : @frontmatter.FrontmatterValue,
  ) -> Array[String] {
    match val {
      @frontmatter.FArray(items) => {
        let strings : Array[String] = []
        let mut i = 0
        while i < items.length() {
          strings.push(convert_scalar_to_string(items[i]))
          i = i + 1
        }
        strings
      }
      _ => [] // Not an array, return empty
    }
  }
  for key, value in fm.fields {
    match value {
      @frontmatter.FArray(_) => result.set(key, convert_array(value))
      _ => () // Skip non-array fields
    }
  }
  result
}

///|
/// Extract YYYY-MM-DD prefix from date string for comparison.
/// Pages without dates get empty string (sorts last/first depending on order).
fn extract_iso_date_prefix(date : String?) -> String {
  match date {
    Some(d) => if d.length() >= 10 { substr_builder(d, 0, 10) } else { "" }
    None => ""
  }
}

///|
/// Compare two pages by date (descending or ascending).
/// Returns negative if a should come before b, positive if after, 0 if equal.
/// Pages without dates sort to end (DateDesc) or beginning (DateAsc).
fn compare_pages_by_date(
  a : @graph.GraphPage,
  b : @graph.GraphPage,
  desc : Bool,
) -> Int {
  let ad = extract_iso_date_prefix(a.date)
  let bd = extract_iso_date_prefix(b.date)
  // For DateDesc: pages with dates come first (desc order), then no-date pages
  // For DateAsc: pages with dates come first (asc order), then no-date pages
  let has_date_a = ad.length() == 10
  let has_date_b = bd.length() == 10
  if has_date_a && has_date_b {
    let cmp = if ad == bd { 0 } else if ad > bd { 1 } else { -1 }
    if desc {
      -cmp
    } else {
      cmp
    }
  } else if has_date_a {
    -1 // a has date, b doesn't: a comes first
  } else if has_date_b {
    1 // b has date, a doesn't: b comes first
  } else {
    0 // neither has date: equal
  }
}

///|
/// Compare two pages by title (ascending or descending).
/// Returns negative if a should come before b, positive if after, 0 if equal.
fn compare_pages_by_title(
  a : @graph.GraphPage,
  b : @graph.GraphPage,
  desc : Bool,
) -> Int {
  let cmp = if a.title == b.title {
    0
  } else if a.title < b.title {
    -1
  } else {
    1
  }
  if desc {
    -cmp
  } else {
    cmp
  }
}

///|
/// Compare two pages according to the specified sort order.
fn compare_pages_by_order(
  a : @graph.GraphPage,
  b : @graph.GraphPage,
  order : @collections.SortOrder,
) -> Int {
  match order {
    @collections.DateDesc => compare_pages_by_date(a, b, true)
    @collections.DateAsc => compare_pages_by_date(a, b, false)
    @collections.TitleAsc => compare_pages_by_title(a, b, false)
    @collections.TitleDesc => compare_pages_by_title(a, b, true)
  }
}

///|
/// Sort collection pages in-place using insertion sort.
/// Matches the pattern used in rss.mbt's sort_pages_for_feed.
pub fn sort_collection_pages(
  pages : Array[@graph.GraphPage],
  order : @collections.SortOrder,
) -> Unit {
  let mut i = 1
  while i < pages.length() {
    let mut j = i
    while j > 0 && compare_pages_by_order(pages[j - 1], pages[j], order) > 0 {
      let tmp = pages[j - 1]
      pages[j - 1] = pages[j]
      pages[j] = tmp
      j = j - 1
    }
    i = i + 1
  }
}

///|
fn build_wikilink_map(
  resolved : Array[@wikilink.ResolvedWikilink],
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
fn extract_link_targets(source : String, slug : String) -> Array[String] {
  let unique : Map[String, Bool] = Map::new()
  let targets : Array[String] = []
  let body = match @frontmatter.parse(source) {
    Ok(fm) => fm.body
    Err(_) => source
  }
  let raw_links = @wikilink.extract(body, slug)
  let mut i = 0
  while i < raw_links.length() {
    let target = @wikilink.lookup_key(raw_links[i].target)
    if not(unique.contains(target)) {
      unique.set(target, true)
      targets.push(target)
    }
    i = i + 1
  }
  targets
}

///|
/// Pre-extract wikilink targets from every source to build an inverted index:
///   target_slug → list of pages that link to it.
///
/// This runs after the page_index is complete so target existence can be
/// checked, and before pass 2 so each page render has backlinks available.
fn build_backlink_index(
  collection_sources : Array[CollectionSources],
  page_index : Map[String, String],
) -> Map[String, Array[BacklinkRef]] {
  let index : Map[String, Array[BacklinkRef]] = Map::new()
  let mut i = 0
  while i < collection_sources.length() {
    let coll = collection_sources[i]
    let mut j = 0
    while j < coll.sources.length() {
      let src = coll.sources[j]
      let source_url = match page_index.get(src.slug) {
        Some(url) => url
        None => ""
      }
      let (source_title, body) = match @frontmatter.parse(src.content) {
        Ok(fm) => (extract_title(fm), fm.body)
        Err(_) => (src.slug, src.content)
      }
      let raw_links = @wikilink.extract(body, src.slug)
      let mut k = 0
      while k < raw_links.length() {
        let target = @wikilink.lookup_key(raw_links[k].target)
        if page_index.contains(target) {
          let ref_entry : BacklinkRef = { url: source_url, title: source_title }
          match index.get(target) {
            Some(existing) => existing.push(ref_entry)
            None => index.set(target, [ref_entry])
          }
        }
        k = k + 1
      }
      j = j + 1
    }
    i = i + 1
  }
  index
}

///|
/// Render an HTML backlinks section from a list of referring pages.
/// Returns an empty string when there are no backlinks.
fn render_backlinks_html(backlinks : Array[BacklinkRef]) -> String {
  if backlinks.length() == 0 {
    return ""
  }
  let buf = StringBuilder::new()
  buf.write_string("<section class=\"backlinks\">\n<h2>Backlinks</h2>\n<ul>\n")
  let mut i = 0
  while i < backlinks.length() {
    let bl = backlinks[i]
    buf.write_string("<li>")
    buf.write_string(@html.anchor(bl.url, bl.title))
    buf.write_string("</li>\n")
    i = i + 1
  }
  buf.write_string("</ul>\n</section>\n")
  buf.to_string()
}

///|
fn filter_toc_entries(
  entries : Array[@markdown.TocEntry],
  max_depth : Int,
) -> Array[@markdown.TocEntry] {
  let filtered : Array[@markdown.TocEntry] = []
  let mut i = 0
  while i < entries.length() {
    let entry = entries[i]
    if entry.level <= max_depth {
      filtered.push(entry)
    }
    i = i + 1
  }
  filtered
}

///|
/// A document that passed frontmatter/schema/wikilink validation.
priv struct ProcessedDocument {
  html : String
  root_html : String?
  title : String
  url : String
  description : String?
  date : String?
  excerpt : String
  resolved_links : Array[@wikilink.ResolvedWikilink]
  tags : Array[@tags.TagRef]
}

///|
/// Group of pages for archive generation.
pub(all) struct ArchiveGroup {
  year : String
  month : String
  pages : Array[@graph.GraphPage]
}

///|
/// Extract year and month from a date string (ISO format YYYY-MM-DD).
pub fn extract_year_month(date : String) -> (String, String)? {
  let n = date.length()
  // Need at least "YYYY-M" (6 chars) with a dash at position 4
  if n < 6 {
    return None
  }
  if char_at_builder(date, 4) != '-' {
    return None
  }
  let year = substr_builder(date, 0, 4)
  // Month is two digits starting at index 5; pad single-digit months
  let month = if n >= 7 {
    substr_builder(date, 5, 7)
  } else {
    "0" + substr_builder(date, 5, 6)
  }
  Some((year, month))
}

///|
/// Group pages by year and month for archive generation.
/// Returns sorted groups with newest year/month first.
pub fn group_pages_by_year_month(
  pages : Array[@graph.GraphPage],
) -> Array[ArchiveGroup] {
  let groups_map : Map[String, Array[@graph.GraphPage]] = Map::new()
  let mut i = 0
  while i < pages.length() {
    let page = pages[i]
    match page.date {
      Some(date_str) =>
        match extract_year_month(date_str) {
          Some((year, month)) => {
            let key = year + "-" + month
            match groups_map.get(key) {
              Some(existing) => {
                existing.push(page)
                groups_map.set(key, existing)
              }
              None => groups_map.set(key, [page])
            }
          }
          None => ()
        }
      None => ()
    }
    i = i + 1
  }

  let groups : Array[ArchiveGroup] = []
  for key, page_list in groups_map {
    let year = substr_builder(key, 0, 4)
    let month = substr_builder(key, 5, 7)
    groups.push({ year, month, pages: page_list })
  }

  // Sort groups by year descending, then month descending
  let mut i = 0
  while i < groups.length() {
    let mut j = i + 1
    while j < groups.length() {
      if groups[i].year < groups[j].year ||
        (groups[i].year == groups[j].year && groups[i].month < groups[j].month) {
        let temp = groups[i]
        groups[i] = groups[j]
        groups[j] = temp
      }
      j = j + 1
    }
    i = i + 1
  }

  // Sort pages within each group by date descending
  i = 0
  while i < groups.length() {
    let mut j = 0
    while j < groups[i].pages.length() {
      let mut k = j + 1
      while k < groups[i].pages.length() {
        let date_j = match groups[i].pages[j].date {
          Some(d) => d
          None => ""
        }
        let date_k = match groups[i].pages[k].date {
          Some(d) => d
          None => ""
        }
        if date_j < date_k {
          let temp = groups[i].pages[j]
          groups[i].pages[j] = groups[i].pages[k]
          groups[i].pages[k] = temp
        }
        k = k + 1
      }
      j = j + 1
    }
    i = i + 1
  }

  groups
}

///|
/// Render HTML content for an archive page - list of page links.
pub fn render_archive_page_content(pages : Array[@graph.GraphPage]) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<ul>\n")
  let mut i = 0
  while i < pages.length() {
    let page = pages[i]
    buf.write_string("<li>")
    buf.write_string(@html.anchor(page.url, page.title))
    match page.date {
      Some(date_str) => {
        buf.write_string(" <small>(")
        buf.write_string(escape_html_builder(date_str))
        buf.write_string(")</small>")
      }
      None => ()
    }
    buf.write_string("</li>\n")
    i = i + 1
  }
  buf.write_string("</ul>\n")
  buf.to_string()
}

///|
/// Render an archive page for a specific year or year+month.
fn render_archive_page(
  collection_name : String,
  year : String,
  month : String,
  pages : Array[@graph.GraphPage],
  site : @config.SiteConfig,
  archive_template : @template.Template?,
  index_template : @template.Template?,
  nav_links_html : String,
  custom_css : String,
  data_store : @data.DataStore,
) -> Result[String, String] {
  let content = render_archive_page_content(pages)
  let title = if month == "" {
    collection_name + " — " + year
  } else {
    collection_name + " — " + year + "-" + month
  }

  let slots = Map::new()
  slots.set(@template.Title, title)
  slots.set(@template.Content, content)
  slots.set(@template.SiteName, site.title)
  slots.set(@template.Url, site.base_url + "/" + collection_name)
  slots.set(@template.NavLinks, nav_links_html)
  slots.set(@template.CustomCss, custom_css)
  slots.set(@template.Collection, collection_name)
  slots.set(@template.Year, year)
  if month == "" {
    slots.set(@template.Month, "")
  } else {
    slots.set(@template.Month, month)
  }
  slots.set(@template.Day, "")

  // Collect all tags from pages
  let tags_html = ""
  slots.set(@template.Tags, tags_html)

  match archive_template {
    Some(tpl) =>
      match
        @template.render_template_with_data(
          tpl,
          slots,
          data_store,
          Map::new(),
          Map::new(),
        ) {
        Ok(html) => Ok(html)
        Err(e) => Err(template_error_text(e))
      }
    None =>
      match index_template {
        Some(tpl) =>
          match
            @template.render_template_with_data(
              tpl,
              slots,
              data_store,
              Map::new(),
              Map::new(),
            ) {
            Ok(html) => Ok(html)
            Err(e) => Err(template_error_text(e))
          }
        None => Ok(content)
      }
  }
}

///|
/// Build all archive pages for a collection.
fn build_archive_pages(
  collection_name : String,
  pages : Array[@graph.GraphPage],
  config : BuildConfig,
  archive_template : @template.Template?,
  index_template : @template.Template?,
  nav_links_html : String,
  custom_css : String,
  data_store : @data.DataStore,
) -> (Int, Int) {
  // Only build if collection has dated pages
  let has_dates = {
    let mut i = 0
    let mut found = false
    while i < pages.length() {
      match pages[i].date {
        Some(_) => {
          found = true
          break
        }
        None => ()
      }
      i = i + 1
    }
    found
  }

  if not(has_dates) {
    return (0, 0)
  }

  let groups = group_pages_by_year_month(pages)
  let mut pages_written = 0
  let mut errors = 0

  let coll_dir = config.output_dir + "/" + collection_name

  let mut i = 0
  while i < groups.length() {
    let group = groups[i]

    // Build year archive (month = "")
    let year_archive_html = match
      render_archive_page(
        collection_name,
        group.year,
        "",
        group.pages,
        config.site,
        archive_template,
        index_template,
        nav_links_html,
        custom_css,
        data_store,
      ) {
      Ok(html) => html
      Err(msg) => {
        println(
          "[error] archive page " +
          collection_name +
          "/" +
          group.year +
          ": " +
          msg,
        )
        errors = errors + 1
        i = i + 1
        continue
      }
    }

    let year_out_path = coll_dir + "/" + group.year + "/index.html"
    let year_write_ok = try {
      ensure_dir(coll_dir + "/" + group.year)
      @fs.write_string_to_file(year_out_path, year_archive_html)
      println("[lattice] wrote " + year_out_path)
      true
    } catch {
      @fs.IOError(msg) => {
        println(
          "[error] cannot write archive page " + year_out_path + ": " + msg,
        )
        false
      }
    }
    if year_write_ok {
      pages_written = pages_written + 1
    } else {
      errors = errors + 1
    }

    // Build month archive
    let month_archive_html = match
      render_archive_page(
        collection_name,
        group.year,
        group.month,
        group.pages,
        config.site,
        archive_template,
        index_template,
        nav_links_html,
        custom_css,
        data_store,
      ) {
      Ok(html) => html
      Err(msg) => {
        println(
          "[error] archive page " +
          collection_name +
          "/" +
          group.year +
          "/" +
          group.month +
          ": " +
          msg,
        )
        errors = errors + 1
        i = i + 1
        continue
      }
    }

    let month_out_path = coll_dir +
      "/" +
      group.year +
      "/" +
      group.month +
      "/index.html"
    let month_write_ok = try {
      ensure_dir(coll_dir + "/" + group.year + "/" + group.month)
      @fs.write_string_to_file(month_out_path, month_archive_html)
      println("[lattice] wrote " + month_out_path)
      true
    } catch {
      @fs.IOError(msg) => {
        println(
          "[error] cannot write archive page " + month_out_path + ": " + msg,
        )
        false
      }
    }
    if month_write_ok {
      pages_written = pages_written + 1
    } else {
      errors = errors + 1
    }

    i = i + 1
  }

  (pages_written, errors)
}

///|
fn char_at_builder(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

///|
fn substr_builder(s : String, start : Int, end_pos : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = start
  while i < end_pos {
    buf.write_char(char_at_builder(s, i))
    i = i + 1
  }
  buf.to_string()
}

///|
fn path_basename_builder(path : String) -> String {
  let mut end_pos = path.length()
  while end_pos > 0 && char_at_builder(path, end_pos - 1) == '/' {
    end_pos = end_pos - 1
  }
  if end_pos == 0 {
    return ""
  }
  let mut start = end_pos
  while start > 0 && char_at_builder(path, start - 1) != '/' {
    start = start - 1
  }
  substr_builder(path, start, end_pos)
}

///|
/// Convert a redirect URL to an output file path.
/// `/old/url/` → `old/url/index.html`
/// `/old/url.html` → `old/url.html`
pub fn redirect_url_to_output_path(url : String) -> String {
  let mut clean_url = url
  // Strip leading slash (including the root "/" case → empty string)
  if clean_url.has_prefix("/") {
    clean_url = if clean_url.length() > 1 {
      substr_builder(clean_url, 1, clean_url.length())
    } else {
      ""
    }
  }
  // If URL ends with .html, write directly; otherwise add /index.html
  if clean_url.has_suffix(".html") {
    clean_url
  } else {
    // Strip trailing slash if present
    let stripped = if clean_url.has_suffix("/") && clean_url.length() > 1 {
      substr_builder(clean_url, 0, clean_url.length() - 1)
    } else {
      clean_url
    }
    if stripped.length() == 0 {
      "index.html"
    } else {
      stripped + "/index.html"
    }
  }
}

///|
/// Render a minimal HTML redirect page.
/// Generates a page with meta-refresh pointing to the canonical URL.
pub fn render_redirect_page(canonical_url : String) -> String {
  let esc_url = escape_html_builder(canonical_url)
  "<!DOCTYPE html>\n" +
  "<html>\n" +
  "<head>\n" +
  "  <meta charset=\"utf-8\">\n" +
  "  <meta http-equiv=\"refresh\" content=\"0; url=" +
  esc_url +
  "\">\n" +
  "  <link rel=\"canonical\" href=\"" +
  esc_url +
  "\">\n" +
  "  <title>Redirecting...</title>\n" +
  "</head>\n" +
  "<body>\n" +
  "  <p>Redirecting to <a href=\"" +
  esc_url +
  "\">" +
  esc_url +
  "</a>&#8230;</p>\n" +
  "</body>\n" +
  "</html>\n"
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

///|
fn trim_builder(s : String) -> String {
  let n = s.length()
  let mut lo = 0
  while lo < n &&
        (
          char_at_builder(s, lo) == ' ' ||
          char_at_builder(s, lo) == '\t' ||
          char_at_builder(s, lo) == '\r'
        ) {
    lo = lo + 1
  }
  let mut hi = n
  while hi > lo &&
        (
          char_at_builder(s, hi - 1) == ' ' ||
          char_at_builder(s, hi - 1) == '\t' ||
          char_at_builder(s, hi - 1) == '\r'
        ) {
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

///|
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

///|
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

///|
fn page_title_builder(page_title : String, site_title : String) -> String {
  if page_title == site_title {
    page_title
  } else {
    page_title + " | " + site_title
  }
}

///|
fn blog_posting_structured_data_builder(
  title : String,
  description : String?,
  url : String,
  date : String?,
  author : String?,
  image : String?,
) -> Array[@html.StructuredData] {
  [
    @html.BlogPosting({
      headline: title,
      description,
      url,
      date_published: date,
      author,
      image,
    }),
  ]
}

///|
fn breadcrumb_item_builder(
  name : String,
  url : String,
) -> @html.BreadcrumbItemData {
  { name, item: url }
}

///|
fn collection_breadcrumb_structured_data_builder(
  site : @config.SiteConfig,
  collection_name : String,
  page_number : Int,
) -> Array[@html.StructuredData] {
  let items : Array[@html.BreadcrumbItemData] = []
  items.push(
    breadcrumb_item_builder(
      site.title,
      absolute_url_builder(site.base_url, "/"),
    ),
  )
  items.push(
    breadcrumb_item_builder(
      collection_name,
      absolute_url_builder(site.base_url, collection_index_url(collection_name)),
    ),
  )
  if page_number > 1 {
    items.push(
      breadcrumb_item_builder(
        "page " + page_number.to_string(),
        absolute_url_builder(
          site.base_url,
          collection_index_page_url(collection_name, page_number),
        ),
      ),
    )
  }
  [@html.BreadcrumbList({ items, })]
}

///|
fn content_breadcrumb_structured_data_builder(
  site : @config.SiteConfig,
  collection_name : String,
  page_title : String,
  page_url : String,
) -> Array[@html.StructuredData] {
  let items : Array[@html.BreadcrumbItemData] = []
  items.push(
    breadcrumb_item_builder(
      site.title,
      absolute_url_builder(site.base_url, "/"),
    ),
  )
  items.push(
    breadcrumb_item_builder(
      collection_name,
      absolute_url_builder(site.base_url, collection_index_url(collection_name)),
    ),
  )
  items.push(
    breadcrumb_item_builder(
      page_title,
      absolute_url_builder(site.base_url, page_url),
    ),
  )
  [@html.BreadcrumbList({ items, })]
}

///|
fn website_structured_data_builder(
  site : @config.SiteConfig,
) -> Array[@html.StructuredData] {
  [
    @html.WebSite({
      name: site.title,
      url: absolute_url_builder(site.base_url, "/"),
      description: site.description,
    }),
  ]
}

///|
fn template_error_text(e : @template.TemplateError) -> String {
  match e {
    @template.UnknownSlot(name) => "unknown slot '" + name + "'"
    @template.MissingRequiredSlot(slot) =>
      "missing required slot '" + slot.to_string() + "'"
    @template.MissingDataSlot(path) => "missing data slot '" + path + "'"
    @template.ParseError(msg) => msg
    @template.CycleError(msg) => "include cycle: " + msg
  }
}

///|
fn templates_dir_for_build(config : BuildConfig) -> String {
  match config.site.templates_dir {
    Some(path) => path
    None => config.content_dir + "/templates"
  }
}

///|
fn load_template_file(path : String) -> Result[@template.Template?, String] {
  if not(@fs.path_exists(path)) {
    return Ok(None)
  }
  let source = @fs.read_file_to_string(path) catch {
    @fs.IOError(msg) => return Err("cannot read template " + path + ": " + msg)
  }

  // Extract directory from path for resolving includes
  let base_dir = if path.contains("/") {
    let mut last_slash = 0
    let mut i = 0
    while i < path.length() {
      if char_at_builder(path, i) == '/' {
        last_slash = i
      }
      i = i + 1
    }
    substr_builder(path, 0, last_slash)
  } else {
    "."
  }

  // Create resolver that reads files relative to templates directory
  let resolver = fn(filename : String) -> Result[String, String] {
    let include_path = if filename.contains("/") || filename.has_prefix("../") {
      // Absolute path or parent directory reference - use as-is
      filename
    } else {
      // Relative path - resolve from base directory
      base_dir + "/" + filename
    }
    let result = @fs.read_file_to_string(include_path) catch {
      @fs.IOError(msg) =>
        return Err("cannot read include '" + filename + "': " + msg)
    }
    Ok(result)
  }

  match @template.parse_template_with_includes(source, resolver) {
    Ok(parsed) => Ok(Some(parsed))
    Err(e) => Err("invalid template " + path + ": " + template_error_text(e))
  }
}

///|
fn load_templates(config : BuildConfig) -> Result[BuildTemplates, String] {
  let base = templates_dir_for_build(config)
  if not(@fs.path_exists(base)) {
    return Ok({
      page: None,
      index: None,
      tag_page: None,
      tag_index: None,
      archive: None,
    })
  }
  let page = match load_template_file(base + "/page.html") {
    Ok(t) => t
    Err(msg) => return Err(msg)
  }
  let index = match load_template_file(base + "/index.html") {
    Ok(t) => t
    Err(msg) => return Err(msg)
  }
  let tag_page = match load_template_file(base + "/tag.html") {
    Ok(t) => t
    Err(msg) => return Err(msg)
  }
  let tag_index = match load_template_file(base + "/tags.html") {
    Ok(t) => t
    Err(msg) => return Err(msg)
  }
  let archive = match load_template_file(base + "/archive.html") {
    Ok(t) => t
    Err(msg) => return Err(msg)
  }
  Ok({ page, index, tag_page, tag_index, archive })
}

///|
fn load_collection_page_template(
  collection : @collections.CollectionDef,
  default_template : @template.Template?,
) -> Result[@template.Template?, String] {
  match collection.template {
    Some(path) =>
      match load_template_file(path) {
        Ok(Some(tpl)) => Ok(Some(tpl))
        Ok(None) => Err("missing template " + path)
        Err(msg) => Err(msg)
      }
    None => Ok(default_template)
  }
}

///|
fn parse_int_builder(s : String) -> Int? {
  let n = s.length()
  if n == 0 {
    return None
  }
  let mut value = 0
  let mut i = 0
  while i < n {
    let c = char_at_builder(s, i)
    if c < '0' || c > '9' {
      return None
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
    i = i + 1
  }
  Some(value)
}

///|
fn starts_with_builder(s : String, prefix : String) -> Bool {
  let n = s.length()
  let plen = prefix.length()
  if plen > n {
    return false
  }
  let mut i = 0
  while i < plen {
    if char_at_builder(s, i) != char_at_builder(prefix, i) {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn line_col_of_first(source : String, pattern : String) -> (Int?, Int?) {
  let n = source.length()
  let plen = pattern.length()
  if plen == 0 || plen > n {
    return (None, None)
  }
  let mut i = 0
  while i + plen <= n {
    let mut matched = true
    let mut j = 0
    while j < plen {
      if char_at_builder(source, i + j) != char_at_builder(pattern, j) {
        matched = false
        break
      }
      j = j + 1
    }
    if matched {
      let mut line = 1
      let mut col = 1
      let mut k = 0
      while k < i {
        if char_at_builder(source, k) == '\n' {
          line = line + 1
          col = 1
        } else {
          col = col + 1
        }
        k = k + 1
      }
      return (Some(line), Some(col))
    }
    i = i + 1
  }
  (None, None)
}

///|
fn frontmatter_field_line(source : String, field : String) -> Int? {
  let header = field + " ="
  let (line, _) = line_col_of_first(source, header)
  line
}

///|
fn frontmatter_line_from_error(msg : String) -> Int? {
  if not(starts_with_builder(msg, "line ")) {
    return None
  }
  let n = msg.length()
  let mut i = 5
  let mut end = i
  while end < n &&
        char_at_builder(msg, end) >= '0' &&
        char_at_builder(msg, end) <= '9' {
    end = end + 1
  }
  if end == i {
    return None
  }
  let buf = StringBuilder::new()
  while i < end {
    buf.write_char(char_at_builder(msg, i))
    i = i + 1
  }
  parse_int_builder(buf.to_string())
}

///|
fn build_error(
  path : String?,
  line : Int?,
  column : Int?,
  message : String,
) -> @diagnostic.Diagnostic {
  {
    severity: @diagnostic.Error,
    code: None,
    path,
    line,
    column,
    message,
    note: None,
  }
}

///|
fn build_warning(
  path : String?,
  line : Int?,
  column : Int?,
  message : String,
) -> @diagnostic.Diagnostic {
  {
    severity: @diagnostic.Warning,
    code: None,
    path,
    line,
    column,
    message,
    note: None,
  }
}

///|
fn missing_required_fields_note(schema : @schema.Schema) -> String? {
  let required : Array[String] = []
  let mut i = 0
  while i < schema.fields.length() {
    let field = schema.fields[i]
    if field.required {
      required.push(field.name)
    }
    i = i + 1
  }
  if required.length() == 0 {
    return None
  }
  let buf = StringBuilder::new()
  i = 0
  while i < required.length() {
    if i > 0 {
      buf.write_string(", ")
    }
    buf.write_string(required[i])
    i = i + 1
  }
  Some("required fields: " + buf.to_string())
}

///|
fn template_violation(path : String, message : String) -> @lint.LintViolation {
  { path, line: None, column: None, kind: @lint.TemplateSlotError, message }
}

///|
fn load_templates_for_lint(config : BuildConfig) -> TemplateLoadResult {
  let violations : Array[@lint.LintViolation] = []
  let base = templates_dir_for_build(config)
  if not(@fs.path_exists(base)) {
    return {
      templates: {
        page: None,
        index: None,
        tag_page: None,
        tag_index: None,
        archive: None,
      },
      violations,
    }
  }

  let mut page : @template.Template? = None
  let mut index : @template.Template? = None
  let mut tag_page : @template.Template? = None
  let mut tag_index : @template.Template? = None
  let mut archive : @template.Template? = None

  let page_path = base + "/page.html"
  match load_template_file(page_path) {
    Ok(t) => page = t
    Err(msg) => violations.push(template_violation(page_path, msg))
  }
  let index_path = base + "/index.html"
  match load_template_file(index_path) {
    Ok(t) => index = t
    Err(msg) => violations.push(template_violation(index_path, msg))
  }
  let tag_path = base + "/tag.html"
  match load_template_file(tag_path) {
    Ok(t) => tag_page = t
    Err(msg) => violations.push(template_violation(tag_path, msg))
  }
  let tags_path = base + "/tags.html"
  match load_template_file(tags_path) {
    Ok(t) => tag_index = t
    Err(msg) => violations.push(template_violation(tags_path, msg))
  }
  let archive_path = base + "/archive.html"
  match load_template_file(archive_path) {
    Ok(t) => archive = t
    Err(msg) => violations.push(template_violation(archive_path, msg))
  }
  { templates: { page, index, tag_page, tag_index, archive }, violations }
}

///|
fn load_collection_page_template_for_lint(
  collection : @collections.CollectionDef,
  default_template : @template.Template?,
  violations : Array[@lint.LintViolation],
) -> @template.Template? {
  match collection.template {
    Some(path) =>
      match load_template_file(path) {
        Ok(Some(tpl)) => Some(tpl)
        Ok(None) => {
          violations.push(template_violation(path, "missing template " + path))
          None
        }
        Err(msg) => {
          violations.push(template_violation(path, msg))
          None
        }
      }
    None => default_template
  }
}

///|
fn build_template_slots(
  title : String,
  content : String,
  date : String,
  description : String,
  url : String,
  site_name : String,
  nav_links : String,
  custom_css : String,
  tag_name : String,
  tag_count : String,
) -> Map[@template.TemplateSlot, String] {
  let slots : Map[@template.TemplateSlot, String] = Map::new()
  slots.set(@template.Title, title)
  slots.set(@template.Content, content)
  slots.set(@template.Date, date)
  slots.set(@template.Description, description)
  slots.set(@template.Url, url)
  slots.set(@template.SiteName, site_name)
  slots.set(@template.NavLinks, nav_links)
  slots.set(@template.CustomCss, custom_css)
  slots.set(@template.TagName, tag_name)
  slots.set(@template.TagCount, tag_count)
  slots.set(@template.ReadingTime, "")
  slots.set(@template.WordCount, "")
  slots.set(@template.TableOfContents, "")
  slots.set(@template.Author, "")
  slots.set(@template.Excerpt, "")
  slots
}

///|
/// Populate pagination-specific template slots into an existing slots map.
///
/// Sets: page_num, total_pages, prev_page, next_page, is_first_page,
/// is_last_page, page_url.
fn set_pagination_slots(
  slots : Map[@template.TemplateSlot, String],
  page_number : Int,
  total_pages : Int,
  prev_url : String?,
  next_url : String?,
  page_url : String,
) -> Unit {
  slots.set(@template.PageNum, page_number.to_string())
  slots.set(@template.TotalPages, total_pages.to_string())
  let prev = match prev_url {
    Some(u) => u
    None => ""
  }
  slots.set(@template.PrevPage, prev)
  let next = match next_url {
    Some(u) => u
    None => ""
  }
  slots.set(@template.NextPage, next)
  slots.set(@template.IsFirstPage, if page_number == 1 { "true" } else { "" })
  slots.set(
    @template.IsLastPage,
    if page_number == total_pages {
      "true"
    } else {
      ""
    },
  )
  slots.set(@template.PageUrl, page_url)
}

///|
fn collection_page_url(collection_name : String, slug : String) -> String {
  "/" + collection_name + "/" + slug + "/"
}

///|
fn collection_index_url(collection_name : String) -> String {
  "/" + collection_name + "/"
}

///|
pub fn collection_index_lookup_alias(
  collection : @collections.CollectionDef,
) -> String? {
  let dir_name = path_basename_builder(collection.content_dir)
  let lookup_key = @wikilink.lookup_key(dir_name)
  if dir_name.length() == 0 || lookup_key == collection.name {
    return None
  }
  Some(lookup_key)
}

///|
fn collection_index_page_url(
  collection_name : String,
  page_number : Int,
) -> String {
  if page_number <= 1 {
    return collection_index_url(collection_name)
  }
  "/" + collection_name + "/page/" + page_number.to_string() + "/"
}

///|
fn tags_index_page_url(page_number : Int) -> String {
  if page_number <= 1 {
    return "/tags/"
  }
  "/tags/page/" + page_number.to_string() + "/"
}

///|
fn tag_page_url(slug : String, page_number : Int) -> String {
  if page_number <= 1 {
    return @tags.tag_url(slug)
  }
  "/tags/" + slug + "/page/" + page_number.to_string() + "/"
}

///|
fn build_nav_links_html(
  collections : Array[@collections.CollectionDef],
) -> String {
  let links : Array[(String, String)] = []
  links.push(("/tags/", "tags"))
  let mut i = 0
  while i < collections.length() {
    let coll = collections[i]
    links.push((collection_index_url(coll.name), coll.name))
    i = i + 1
  }
  @html.nav_links(links)
}

///|
fn tags_field_name(site : @config.SiteConfig) -> String {
  match site.tags_field {
    Some(name) => name
    None => "tags"
  }
}

///|
fn search_index_file_name(site : @config.SiteConfig) -> String {
  match site.search_index_file {
    Some(path) => path
    None => "search-index.json"
  }
}

///|
fn static_dir_name(site : @config.SiteConfig) -> String {
  match site.static_dir {
    Some(path) => path
    None => "static"
  }
}

///|
fn data_dir_for_build(config : BuildConfig) -> String {
  match config.site.data_dir {
    Some(path) => path
    None => config.content_dir + "/data"
  }
}

///|
fn page_size_for_site(site : @config.SiteConfig) -> Int? {
  site.page_size
}

///|
fn page_size_for_collection(
  site : @config.SiteConfig,
  collection : @collections.CollectionDef,
) -> Int? {
  match collection.page_size {
    Some(size) => Some(size)
    None => page_size_for_site(site)
  }
}

///|
fn[T] paginate_with_optional_size(
  documents : Array[T],
  page_size : Int?,
  page_url_for : (Int) -> String,
) -> Array[@pagination.PaginatedIndex[T]] {
  match page_size {
    Some(size) => @pagination.paginate(documents, size, page_url_for)
    None =>
      @pagination.paginate(
        documents,
        if documents.length() > 0 {
          documents.length()
        } else {
          1
        },
        page_url_for,
      )
  }
}

///|
fn asset_error_text(err : @assets.AssetCopyError) -> String {
  @assets.format_error(err)
}

///|
fn data_error_diagnostic(err : @data.DataError) -> @diagnostic.Diagnostic {
  match err {
    @data.FileNotFound(path) =>
      build_error(Some(path), None, None, "data directory not found")
    @data.ParseError(path, line, msg) =>
      build_error(Some(path), Some(line), None, msg)
    @data.ValidationError(file, key, msg) => {
      let key_message = if key.length() == 0 {
        "data." + file
      } else {
        "data." + file + "." + key
      }
      build_error(None, None, None, key_message + ": " + msg)
    }
    @data.IOError(path, msg) => build_error(Some(path), None, None, msg)
  }
}

///|
fn asset_error_diagnostic(
  err : @assets.AssetCopyError,
) -> @diagnostic.Diagnostic {
  build_error(Some(@assets.error_path(err)), None, None, asset_error_text(err))
}

///|
fn render_pagination_nav(
  page_number : Int,
  total_pages : Int,
  prev_url : String?,
  next_url : String?,
) -> String {
  if total_pages <= 1 {
    return ""
  }
  let nav = StringBuilder::new()
  nav.write_string("<nav class=\"pagination\" aria-label=\"Pagination\">\n")
  nav.write_string("<p>Page ")
  nav.write_string(page_number.to_string())
  nav.write_string(" of ")
  nav.write_string(total_pages.to_string())
  nav.write_string("</p>\n<ul>\n")
  match prev_url {
    Some(url) =>
      nav.write_string("<li>" + @html.anchor(url, "Previous") + "</li>\n")
    None => nav.write_string("<li><span>Previous</span></li>\n")
  }
  match next_url {
    Some(url) =>
      nav.write_string("<li>" + @html.anchor(url, "Next") + "</li>\n")
    None => nav.write_string("<li><span>Next</span></li>\n")
  }
  nav.write_string("</ul>\n</nav>\n")
  nav.to_string()
}

///|
fn inject_nav_before_main_close(body : String, nav : String) -> String {
  if nav.length() == 0 {
    return body
  }
  let close_tag = "</main>\n"
  if body.has_suffix(close_tag) {
    let without_close = substr_builder(
      body,
      0,
      body.length() - close_tag.length(),
    )
    return without_close + nav + close_tag
  }
  body + nav
}

///|
fn split_lines_builder(s : String) -> Array[String] {
  let lines : Array[String] = []
  let n = s.length()
  let mut i = 0
  while i <= n {
    let mut end = i
    while end < n && char_at_builder(s, end) != '\n' {
      end = end + 1
    }
    let line = StringBuilder::new()
    let mut j = i
    while j < end {
      line.write_char(char_at_builder(s, j))
      j = j + 1
    }
    lines.push(line.to_string())
    if end >= n {
      break
    }
    i = end + 1
  }
  lines
}

///|
fn join_lines_builder(lines : Array[String]) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  while i < lines.length() {
    if i > 0 {
      buf.write_char('\n')
    }
    buf.write_string(lines[i])
    i = i + 1
  }
  buf.to_string()
}

///|
fn is_blank_builder(s : String) -> Bool {
  trim_builder(s).length() == 0
}

///|
fn starts_with_at_builder(s : String, pos : Int, prefix : String) -> Bool {
  let plen = prefix.length()
  if pos + plen > s.length() {
    return false
  }
  let mut i = 0
  while i < plen {
    if char_at_builder(s, pos + i) != char_at_builder(prefix, i) {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn count_leading_hashes_builder(line : String) -> Int {
  let n = line.length()
  let mut count = 0
  while count < n && char_at_builder(line, count) == '#' {
    count = count + 1
  }
  count
}

///|
fn is_heading_line_builder(line : String) -> Bool {
  let hashes = count_leading_hashes_builder(line)
  if hashes == 0 || hashes > 6 {
    return false
  }
  hashes < line.length() && char_at_builder(line, hashes) == ' '
}

///|
fn is_hrule_builder(line : String) -> Bool {
  let t = trim_builder(line)
  t == "---" || t == "***" || t == "___"
}

///|
fn is_fence_start_builder(line : String) -> Bool {
  starts_with_at_builder(line, 0, "```") ||
  starts_with_at_builder(line, 0, "~~~")
}

///|
fn fence_char_builder(line : String) -> Char {
  if line.length() == 0 {
    '`'
  } else {
    char_at_builder(line, 0)
  }
}

///|
fn is_fence_end_builder(line : String, fence_char : Char) -> Bool {
  line.length() >= 3 &&
  char_at_builder(line, 0) == fence_char &&
  char_at_builder(line, 1) == fence_char &&
  char_at_builder(line, 2) == fence_char
}

///|
fn is_unordered_item_builder(line : String) -> Bool {
  line.length() >= 2 &&
  (char_at_builder(line, 0) == '-' || char_at_builder(line, 0) == '*') &&
  char_at_builder(line, 1) == ' '
}

///|
fn is_digit_builder(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_ordered_item_builder(line : String) -> Bool {
  let n = line.length()
  if n < 3 {
    return false
  }
  let mut i = 0
  while i < n && is_digit_builder(char_at_builder(line, i)) {
    i = i + 1
  }
  i > 0 &&
  i + 1 < n &&
  char_at_builder(line, i) == '.' &&
  char_at_builder(line, i + 1) == ' '
}

///|
fn is_blockquote_line_builder(line : String) -> Bool {
  line.length() > 0 && char_at_builder(line, 0) == '>'
}

///|
fn is_block_starter_builder(line : String) -> Bool {
  is_heading_line_builder(line) ||
  is_hrule_builder(line) ||
  is_fence_start_builder(line) ||
  is_unordered_item_builder(line) ||
  is_ordered_item_builder(line) ||
  is_blockquote_line_builder(line)
}

///|
fn inline_text_builder(inline : @markdown.Inline) -> String {
  match inline {
    @markdown.Text(t) => t
    @markdown.Bold(inlines) => inlines_text_builder(inlines)
    @markdown.Italic(inlines) => inlines_text_builder(inlines)
    @markdown.BoldItalic(inlines) => inlines_text_builder(inlines)
    @markdown.Strikethrough(inlines) => inlines_text_builder(inlines)
    @markdown.InlineCode(text) => text
    @markdown.Link(text, _) => text
    @markdown.Image(alt, _) => alt
    @markdown.WikiRef(target, display) =>
      match display {
        Some(text) => text
        None => target
      }
    @markdown.FootnoteRef(_) => ""
    @markdown.Shortcode(call) => call.name
    @markdown.HardBreak => " "
  }
}

///|
fn inlines_text_builder(inlines : Array[@markdown.Inline]) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  while i < inlines.length() {
    buf.write_string(inline_text_builder(inlines[i]))
    i = i + 1
  }
  buf.to_string()
}

///|
fn collapse_whitespace_builder(s : String) -> String {
  let buf = StringBuilder::new()
  let mut wrote_non_space = false
  let mut prev_space = false
  let mut i = 0
  while i < s.length() {
    let c = char_at_builder(s, i)
    let is_space = c == ' ' || c == '\t' || c == '\n' || c == '\r'
    if is_space {
      if wrote_non_space && not(prev_space) {
        buf.write_char(' ')
        prev_space = true
      }
    } else {
      wrote_non_space = true
      prev_space = false
      buf.write_char(c)
    }
    i = i + 1
  }
  trim_builder(buf.to_string())
}

///|
fn extract_excerpt_builder(markdown_body : String) -> String {
  let lines = split_lines_builder(markdown_body)
  let mut i = 0
  while i < lines.length() {
    let line = lines[i]
    if is_blank_builder(line) {
      i = i + 1
    } else if is_block_starter_builder(line) {
      if is_fence_start_builder(line) {
        let fence_char = fence_char_builder(line)
        i = i + 1
        while i < lines.length() &&
              not(is_fence_end_builder(lines[i], fence_char)) {
          i = i + 1
        }
        if i < lines.length() {
          i = i + 1
        }
      } else if is_blockquote_line_builder(line) {
        while i < lines.length() && is_blockquote_line_builder(lines[i]) {
          i = i + 1
        }
      } else if is_unordered_item_builder(line) {
        while i < lines.length() && is_unordered_item_builder(lines[i]) {
          i = i + 1
        }
      } else if is_ordered_item_builder(line) {
        while i < lines.length() && is_ordered_item_builder(lines[i]) {
          i = i + 1
        }
      } else {
        i = i + 1
      }
    } else {
      let paragraph_lines : Array[String] = []
      while i < lines.length() &&
            not(is_blank_builder(lines[i])) &&
            not(is_block_starter_builder(lines[i])) {
        paragraph_lines.push(lines[i])
        i = i + 1
      }
      let paragraph_text = join_lines_builder(paragraph_lines)
      let inlines = @markdown.parse_inlines(
        paragraph_text,
        0,
        paragraph_text.length(),
      )
      let plain_text = collapse_whitespace_builder(
        inlines_text_builder(inlines),
      )
      if plain_text.length() > 0 {
        return plain_text
      }
    }
  }
  ""
}

///|
/// Count words in a markdown body, skipping fenced code blocks.
/// Words are whitespace-delimited runs of non-whitespace characters.
pub fn count_words_markdown(body : String) -> Int {
  let ls = split_lines_builder(body)
  let mut count = 0
  let mut i = 0
  while i < ls.length() {
    let line = ls[i]
    if is_fence_start_builder(line) {
      let fence_char = fence_char_builder(line)
      i = i + 1
      while i < ls.length() && not(is_fence_end_builder(ls[i], fence_char)) {
        i = i + 1
      }
      if i < ls.length() {
        i = i + 1
      }
      continue
    }
    let n = line.length()
    let mut j = 0
    while j < n {
      while j < n &&
            (
              char_at_builder(line, j) == ' ' ||
              char_at_builder(line, j) == '\t'
            ) {
        j = j + 1
      }
      if j < n {
        count = count + 1
        while j < n &&
              char_at_builder(line, j) != ' ' &&
              char_at_builder(line, j) != '\t' {
          j = j + 1
        }
      }
    }
    i = i + 1
  }
  count
}

///|
/// Return "N min" reading time from a word count at ~225 wpm (200–250 wpm midpoint).
/// Minimum result is "1 min".
pub fn reading_time_str(word_count : Int) -> String {
  let mins = if word_count <= 0 {
    1
  } else {
    let raw = (word_count + 224) / 225
    if raw < 1 {
      1
    } else {
      raw
    }
  }
  mins.to_string() + " min"
}

///|
/// Truncate a string to at most max_len characters.
pub fn truncate_to_builder(s : String, max_len : Int) -> String {
  if s.length() <= max_len {
    s
  } else {
    substr_builder(s, 0, max_len)
  }
}

///|
fn collect_tag_catalog(
  collection_sources : Array[CollectionSources],
  tags_field : String,
) -> TagCatalog {
  let ordered_slugs : Array[String] = []
  let name_by_slug : Map[String, String] = Map::new()
  let mut i = 0
  while i < collection_sources.length() {
    let coll = collection_sources[i]
    let mut j = 0
    while j < coll.sources.length() {
      let src = coll.sources[j]
      match @frontmatter.parse(src.content) {
        Ok(fm) => {
          let schema_errors = @schema.validate(fm, coll.definition.schema)
          if schema_errors.length() == 0 {
            match @tags.extract(fm, tags_field) {
              Ok(tag_refs) => {
                let mut k = 0
                while k < tag_refs.length() {
                  let tag = tag_refs[k]
                  if not(name_by_slug.contains(tag.slug)) {
                    name_by_slug.set(tag.slug, tag.value)
                    ordered_slugs.push(tag.slug)
                  }
                  k = k + 1
                }
              }
              Err(_) => ()
            }
          }
        }
        Err(_) => ()
      }
      j = j + 1
    }
    i = i + 1
  }
  { ordered_slugs, name_by_slug }
}

///|
fn render_tag_page_html(
  page : @tags.TagPage,
  pagination : @pagination.PaginatedIndex[@tags.TaggedPage],
  site : @config.SiteConfig,
  tag_template : @template.Template?,
  fallback_template : @template.Template?,
  nav_links_html : String,
  custom_css : String,
  data_store : @data.DataStore,
) -> Result[String, String] {
  let nav = render_pagination_nav(
    pagination.page_number,
    pagination.total_pages,
    pagination.prev_url,
    pagination.next_url,
  )
  let body = inject_nav_before_main_close(@tags.render_tag_page(page), nav)
  let title_suffix = if pagination.total_pages > 1 {
    " (page " + pagination.page_number.to_string() + ")"
  } else {
    ""
  }
  let full_title = page_title_builder(
    "tag: " + page.tag + title_suffix,
    site.title,
  )
  let description = "Pages tagged with '" +
    page.tag +
    "' in " +
    site.title +
    "."
  let url = tag_page_url(page.slug, pagination.page_number)
  let effective_template = match tag_template {
    Some(t) => Some(t)
    None => fallback_template
  }
  match effective_template {
    Some(tpl) => {
      let slots = build_template_slots(
        full_title,
        body,
        "",
        description,
        url,
        site.title,
        nav_links_html,
        custom_css,
        page.tag,
        page.pages.length().to_string(),
      )
      set_pagination_slots(
        slots,
        pagination.page_number,
        pagination.total_pages,
        pagination.prev_url,
        pagination.next_url,
        url,
      )
      match
        @template.render_template_with_data(
          tpl,
          slots,
          data_store,
          Map::new(),
          Map::new(),
        ) {
        Ok(html) => Ok(html)
        Err(e) => Err("tag page template: " + template_error_text(e))
      }
    }
    None => {
      let canonical = absolute_url_builder(
        site.base_url,
        tag_page_url(page.slug, pagination.page_number),
      )
      let meta : @html.PageMeta = {
        title: full_title,
        description: Some(description),
        lang: "en",
        stylesheet: Some(absolute_url_builder(site.base_url, "/style.css")),
        canonical_url: Some(canonical),
        og_image: site.og_image,
        feed_url: None,
        structured_data: [],
      }
      Ok(@html.render_page(meta, body))
    }
  }
}

///|
fn render_tags_index_html(
  index : @tags.TagIndex,
  pagination : @pagination.PaginatedIndex[@tags.TagSummary],
  site : @config.SiteConfig,
  index_template : @template.Template?,
  fallback_template : @template.Template?,
  nav_links_html : String,
  custom_css : String,
  data_store : @data.DataStore,
) -> Result[String, String] {
  let nav = render_pagination_nav(
    pagination.page_number,
    pagination.total_pages,
    pagination.prev_url,
    pagination.next_url,
  )
  let body = inject_nav_before_main_close(@tags.render_tag_index(index), nav)
  let title_suffix = if pagination.total_pages > 1 {
    " (page " + pagination.page_number.to_string() + ")"
  } else {
    ""
  }
  let full_title = page_title_builder("tags" + title_suffix, site.title)
  let description = "All tags in " + site.title + "."
  let effective_template = match index_template {
    Some(t) => Some(t)
    None => fallback_template
  }
  match effective_template {
    Some(tpl) => {
      let slots = build_template_slots(
        full_title,
        body,
        "",
        description,
        tags_index_page_url(pagination.page_number),
        site.title,
        nav_links_html,
        custom_css,
        "",
        index.tags.length().to_string(),
      )
      set_pagination_slots(
        slots,
        pagination.page_number,
        pagination.total_pages,
        pagination.prev_url,
        pagination.next_url,
        tags_index_page_url(pagination.page_number),
      )
      match
        @template.render_template_with_data(
          tpl,
          slots,
          data_store,
          Map::new(),
          Map::new(),
        ) {
        Ok(html) => Ok(html)
        Err(e) => Err("tags index template: " + template_error_text(e))
      }
    }
    None => {
      let canonical = absolute_url_builder(
        site.base_url,
        tags_index_page_url(pagination.page_number),
      )
      let meta : @html.PageMeta = {
        title: full_title,
        description: Some(description),
        lang: "en",
        stylesheet: Some(absolute_url_builder(site.base_url, "/style.css")),
        canonical_url: Some(canonical),
        og_image: site.og_image,
        feed_url: None,
        structured_data: [],
      }
      Ok(@html.render_page(meta, body))
    }
  }
}

///|
/// Render a 404 page using either a custom 404.md or a default fallback.
///
/// If 404.md exists in the content root, it's rendered through the full
/// frontmatter/markdown/template pipeline. Otherwise, a minimal default
/// 404 page is generated.
///
/// Template priority:
///   1. templates/404.html (if present)
///   2. templates/page.html (if present)
///   3. Default HTML fallback
fn render_404_page(
  config : BuildConfig,
  templates : BuildTemplates,
  nav_links_html : String,
  custom_css : String,
  data_store : @data.DataStore,
) -> Result[String, String] {
  let page_path = config.content_dir + "/404.md"
  let has_custom_404 = @fs.path_exists(page_path)
  let url = "/404.html"

  let (title, body_html, description) = if has_custom_404 {
    let source = @fs.read_file_to_string(page_path) catch {
      @fs.IOError(msg) => return Err("cannot read 404.md: " + msg)
    }
    match @frontmatter.parse(source) {
      Err(e) => return Err("404.md frontmatter: " + e)
      Ok(fm) => {
        let wl_map = build_wikilink_map([])
        let markdown_result = @markdown.render_with_diagnostics(fm.body, wl_map)
        if markdown_result.shortcode_errors.length() > 0 {
          return Err(
            "404.md shortcode error: " +
            @shortcode.error_text(markdown_result.shortcode_errors[0].error),
          )
        }
        let description = match extract_description(fm) {
          Some(d) => d
          None => "Page not found"
        }
        (extract_title(fm), markdown_result.html, description)
      }
    }
  } else {
    (
      "Page Not Found", "<h1>Page Not Found</h1>\n<p>The page you are looking for does not exist.</p>\n",
      "Page not found",
    )
  }

  let full_title = page_title_builder(title, config.site.title)

  // Template priority: 404.html → page.html → default
  match templates.page {
    Some(tpl) => {
      let slots = build_template_slots(
        full_title,
        body_html,
        "",
        description,
        url,
        config.site.title,
        nav_links_html,
        custom_css,
        "",
        "",
      )
      // 404 pages have no tags, collection, date, or prev/next components
      slots.set(@template.Tags, "")
      slots.set(@template.Collection, "")
      slots.set(@template.Year, "")
      slots.set(@template.Month, "")
      slots.set(@template.Day, "")
      slots.set(@template.PrevPostUrl, "")
      slots.set(@template.PrevPostTitle, "")
      slots.set(@template.NextPostUrl, "")
      slots.set(@template.NextPostTitle, "")
      match
        @template.render_template_with_data(
          tpl,
          slots,
          data_store,
          Map::new(),
          Map::new(),
        ) {
        Ok(html) => Ok(html)
        Err(e) => Err("404 page template: " + template_error_text(e))
      }
    }
    None => {
      let canonical = absolute_url_builder(config.site.base_url, url)
      let meta : @html.PageMeta = {
        title: full_title,
        description: Some(description),
        lang: "en",
        stylesheet: Some(
          absolute_url_builder(config.site.base_url, "/style.css"),
        ),
        canonical_url: Some(canonical),
        og_image: config.site.og_image,
        feed_url: None,
        structured_data: [],
      }
      Ok(@html.render_page(meta, body_html))
    }
  }
}

///|
/// Render a per-collection index page from successful pages + wikilinks.
fn render_collection_index(
  collection_name : String,
  pagination : @pagination.PaginatedIndex[@graph.GraphPage],
  site : @config.SiteConfig,
  index_template : @template.Template?,
  nav_links_html : String,
  custom_css : String,
  data_store : @data.DataStore,
) -> Result[String, String] {
  let pages = pagination.documents
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
  if pagination.total_pages > 1 {
    body.write_string("<p>Page ")
    body.write_string(pagination.page_number.to_string())
    body.write_string(" of ")
    body.write_string(pagination.total_pages.to_string())
    body.write_string("</p>\n")
  }
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
  body.write_string(
    render_pagination_nav(
      pagination.page_number,
      pagination.total_pages,
      pagination.prev_url,
      pagination.next_url,
    ),
  )
  body.write_string("</main>\n")

  let title_suffix = if pagination.total_pages > 1 {
    " (page " + pagination.page_number.to_string() + ")"
  } else {
    ""
  }
  let full_title = page_title_builder(
    collection_name + " index" + title_suffix,
    site.title,
  )
  let description = "Generated page graph for collection " +
    collection_name +
    " in " +
    site.title +
    "."
  let page_url = collection_index_page_url(
    collection_name,
    pagination.page_number,
  )

  match index_template {
    Some(tpl) => {
      let slots = build_template_slots(
        full_title,
        body.to_string(),
        "",
        description,
        page_url,
        site.title,
        nav_links_html,
        custom_css,
        "",
        "",
      )
      set_pagination_slots(
        slots,
        pagination.page_number,
        pagination.total_pages,
        pagination.prev_url,
        pagination.next_url,
        page_url,
      )
      match
        @template.render_template_with_data(
          tpl,
          slots,
          data_store,
          Map::new(),
          Map::new(),
        ) {
        Ok(html) => {
          let structured_data_markup = @html.render_structured_data_script(
            collection_breadcrumb_structured_data_builder(
              site,
              collection_name,
              pagination.page_number,
            ),
          )
          let feed_url = absolute_url_builder(
            site.base_url,
            collection_index_url(collection_name) + "feed.xml",
          )
          let feed_link_markup = @html.render_feed_link_tag(
            full_title, feed_url,
          )
          let combined_markup = structured_data_markup + feed_link_markup
          return Ok(@html.inject_head_markup(html, combined_markup))
        }
        Err(e) =>
          return Err("collection index template: " + template_error_text(e))
      }
    }
    None => ()
  }

  let canonical = absolute_url_builder(
    site.base_url,
    collection_index_page_url(collection_name, pagination.page_number),
  )
  let feed_url = absolute_url_builder(
    site.base_url,
    collection_index_url(collection_name) + "feed.xml",
  )
  let meta : @html.PageMeta = {
    title: full_title,
    description: Some(description),
    lang: "en",
    stylesheet: Some(absolute_url_builder(site.base_url, "/style.css")),
    canonical_url: Some(canonical),
    og_image: site.og_image,
    feed_url: Some(feed_url),
    structured_data: collection_breadcrumb_structured_data_builder(
      site,
      collection_name,
      pagination.page_number,
    ),
  }
  Ok(@html.render_page(meta, body.to_string()))
}

///|
fn build_data_schema_map(
  schema_defs : Array[@collections.DataSchemaDef],
) -> Map[String, @data.DataSchema] {
  let data_schemas : Map[String, @data.DataSchema] = Map::new()
  let mut i = 0
  while i < schema_defs.length() {
    let schema = schema_defs[i]
    data_schemas.set(
      schema.name,
      @data.new_schema(schema.name, schema.required_keys),
    )
    i = i + 1
  }
  data_schemas
}

///|
fn load_project_layout(config : BuildConfig) -> Result[ProjectLayout, String] {
  if config.site.collections.length() > 0 && config.collections_path == None {
    let defs : Array[@collections.CollectionDef] = []
    let mut i = 0
    while i < config.site.collections.length() {
      let entry = config.site.collections[i]
      let schema_text = match entry.schema {
        Some(text) => text
        None =>
          return Err("inline collection '" + entry.name + "' is missing schema")
      }
      let schema = match
        @collections.parse_schema_string(entry.name, schema_text) {
        Ok(parsed) => parsed
        Err(@collections.InvalidSchema(_, msg)) =>
          return Err(
            "invalid schema for collection '" + entry.name + "': " + msg,
          )
        Err(@collections.InvalidLine(line, msg)) =>
          return Err("<inline>:" + line.to_string() + ": " + msg)
        Err(@collections.MissingRequiredField(_, field)) =>
          return Err(
            "missing required field '" +
            field +
            "' in collection '" +
            entry.name +
            "'",
          )
        Err(@collections.DuplicateCollection(name)) =>
          return Err("duplicate collection '" + name + "'")
        Err(@collections.DuplicateDataSchema(name)) =>
          return Err("duplicate data schema '" + name + "'")
        Err(@collections.EmptyConfig) => return Err("no collections defined")
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
    return Ok({ collections: defs, data_schemas: Map::new() })
  }
  match config.collections_path {
    None =>
      Ok({
        collections: [@collections.default_posts_collection(config.content_dir)],
        data_schemas: Map::new(),
      })
    Some(path) => {
      let source = @fs.read_file_to_string(path) catch {
        @fs.IOError(msg) =>
          return Err("cannot read collections file " + path + ": " + msg)
      }
      match @collections.parse(source) {
        Ok(parsed) =>
          Ok({
            collections: parsed.definitions,
            data_schemas: build_data_schema_map(parsed.data_schema_list),
          })
        Err(@collections.InvalidLine(line, msg)) =>
          Err(path + ":" + line.to_string() + ": " + msg)
        Err(@collections.MissingRequiredField(collection_name, field)) =>
          Err(
            path +
            ": missing required field '" +
            field +
            "' in collection '" +
            collection_name +
            "'",
          )
        Err(@collections.DuplicateCollection(name)) =>
          Err(path + ": duplicate collection '" + name + "'")
        Err(@collections.DuplicateDataSchema(name)) =>
          Err(path + ": duplicate data schema '" + name + "'")
        Err(@collections.InvalidSchema(name, msg)) =>
          Err(path + ": invalid schema for collection '" + name + "': " + msg)
        Err(@collections.EmptyConfig) => Err(path + ": no collections defined")
      }
    }
  }
}

///|
fn load_data_store(
  config : BuildConfig,
  data_schemas : Map[String, @data.DataSchema],
) -> Result[@data.DataStore, @data.DataError] {
  let data_dir = data_dir_for_build(config)
  match @data.load_from_dir(data_dir, data_schemas) {
    Ok(store) => Ok(store)
    Err(err) => Err(err)
  }
}

///|
/// Process one markdown document through the full lattice pipeline.
///
/// Returns the rendered HTML5 page on success, or None if validation fails.
/// All errors are printed to stdout with the slug as context.
fn process_document(
  source : String,
  source_path : String,
  slug : String,
  collection_name : String,
  url : String,
  page_index : Map[String, String],
  known_tags : Map[String, String],
  tags_field : String,
  schema : @schema.Schema,
  site : @config.SiteConfig,
  data_store : @data.DataStore,
  page_template : @template.Template?,
  templates_dir : String,
  nav_links_html : String,
  custom_css : String,
  backlinks_html : String,
  render_page_html : Bool,
  prev_post_url : String,
  prev_post_title : String,
  next_post_url : String,
  next_post_title : String,
) -> BuildDocOutcome {
  let diagnostics : Array[@diagnostic.Diagnostic] = []
  // Step 1: parse frontmatter
  let fm = match @frontmatter.parse(source) {
    Err(e) => {
      diagnostics.push(
        build_error(
          Some(source_path),
          frontmatter_line_from_error(e),
          None,
          "frontmatter: " + e,
        ),
      )
      return { document: None, diagnostics }
    }
    Ok(fm) => fm
  }
  // Step 1b: check for per-page template override
  let custom_template = match extract_template(fm) {
    Some(template_name) => {
      let template_path = templates_dir + "/" + template_name
      match load_template_file(template_path) {
        Ok(Some(tpl)) => Some(tpl)
        Ok(None) => {
          // Template file doesn't exist, warn and fall back to default
          diagnostics.push(
            build_warning(
              Some(source_path),
              frontmatter_field_line(source, "template"),
              None,
              "template file '" +
              template_name +
              "' not found in " +
              templates_dir +
              ", using default page template",
            ),
          )
          page_template
        }
        Err(msg) => {
          // Template file exists but failed to load, warn and fall back to default
          diagnostics.push(
            build_warning(
              Some(source_path),
              frontmatter_field_line(source, "template"),
              None,
              "failed to load template '" +
              template_name +
              "': " +
              msg +
              ", using default page template",
            ),
          )
          page_template
        }
      }
    }
    None => page_template
  }
  // Step 2: validate against schema — collect all errors before aborting
  let schema_errors = @schema.validate(fm, schema)
  if schema_errors.length() > 0 {
    let mut i = 0
    let note = missing_required_fields_note(schema)
    while i < schema_errors.length() {
      let err = schema_errors[i]
      diagnostics.push({
        severity: @diagnostic.Error,
        code: None,
        path: Some(source_path),
        line: frontmatter_field_line(source, err.field),
        column: None,
        message: if err.message == "required field missing" {
          "missing required field '" + err.field + "'"
        } else {
          "schema: " + err.field + ": " + err.message
        },
        note: if err.message == "required field missing" {
          note
        } else {
          None
        },
      })
      i = i + 1
    }
    return { document: None, diagnostics }
  }
  // Step 2b: extract validated tags from typed frontmatter.
  let page_tags = match @tags.extract(fm, tags_field) {
    Ok(values) => values
    Err(msg) => {
      diagnostics.push(
        build_error(
          Some(source_path),
          frontmatter_field_line(source, tags_field),
          None,
          "tags field '" + tags_field + "': " + msg,
        ),
      )
      return { document: None, diagnostics }
    }
  }
  let mut i = 0
  while i < page_tags.length() {
    let tag = page_tags[i]
    if not(known_tags.contains(tag.slug)) {
      let (line, col) = line_col_of_first(source, tag.value)
      diagnostics.push(
        build_error(
          Some(source_path),
          line,
          col,
          "dangling tag reference '" +
          tag.value +
          "' (" +
          tag.slug +
          ") missing from tag index",
        ),
      )
      return { document: None, diagnostics }
    }
    i = i + 1
  }
  // Step 3: extract wikilinks; resolve against page index
  let raw_links = @wikilink.extract(fm.body, slug)
  let (resolved, link_errors) = @wikilink.resolve(raw_links, page_index)
  if link_errors.length() > 0 {
    let mut i = 0
    while i < link_errors.length() {
      let marker = "[[" + link_errors[i].link.target + "]]"
      let (line, col) = line_col_of_first(source, marker)
      diagnostics.push(
        build_warning(
          Some(source_path),
          line,
          col,
          "unresolved wikilink [[" +
          link_errors[i].link.target +
          "]] rendered as plain text",
        ),
      )
      i = i + 1
    }
  }
  // Step 4: build wikilink map for the renderer
  let excerpt = extract_excerpt_builder(fm.body)
  let title = extract_title(fm)
  let description_value = extract_description(fm)
  let date_value = extract_date(fm)
  let author_value = extract_author(fm)
  let og_image_value = extract_og_image(fm)
  if not(render_page_html) {
    return {
      document: Some({
        html: "",
        root_html: None,
        title,
        url,
        description: description_value,
        date: date_value,
        excerpt,
        resolved_links: resolved,
        tags: page_tags,
      }),
      diagnostics,
    }
  }
  let wl_map = build_wikilink_map(resolved)
  // Step 5: render markdown body to HTML fragment
  let markdown_result = @markdown.render_with_diagnostics(fm.body, wl_map)
  if markdown_result.shortcode_errors.length() > 0 {
    let mut si = 0
    while si < markdown_result.shortcode_errors.length() {
      diagnostics.push(
        build_error(
          Some(source_path),
          None,
          None,
          "shortcode: " +
          @shortcode.error_text(markdown_result.shortcode_errors[si].error),
        ),
      )
      si = si + 1
    }
    return { document: None, diagnostics }
  }
  let body_html = markdown_result.html + @tags.render_page_tags(page_tags)
  let toc_html = if extract_toc_enabled(fm) {
    @markdown.render_table_of_contents(
      filter_toc_entries(markdown_result.toc, extract_toc_depth(fm)),
    )
  } else {
    ""
  }
  // Step 6: emit the complete HTML5 page
  let full_title = page_title_builder(title, site.title)
  let description_text = match description_value {
    Some(v) => v
    None => truncate_to_builder(excerpt, 160)
  }
  let date_text = match date_value {
    Some(v) => v
    None => ""
  }
  let page_og_image = match og_image_value {
    Some(img) => Some(img)
    None => site.og_image
  }
  let page_body = if backlinks_html.length() > 0 {
    toc_html + body_html + backlinks_html
  } else {
    toc_html + body_html
  }
  let wc = count_words_markdown(fm.body)
  let render_variant = fn(
    render_url : String,
    canonical : String,
    structured_data : Array[@html.StructuredData],
  ) -> Result[String, String] {
    match custom_template {
      Some(tpl) => {
        let slots = build_template_slots(
          full_title,
          body_html,
          date_text,
          description_text,
          render_url,
          site.title,
          nav_links_html,
          custom_css,
          "",
          "",
        )
        slots.set(@template.Backlinks, backlinks_html)
        slots.set(@template.TableOfContents, toc_html)
        slots.set(@template.WordCount, wc.to_string())
        slots.set(@template.ReadingTime, reading_time_str(wc))
        slots.set(
          @template.Author,
          match author_value {
            Some(v) => v
            None => ""
          },
        )
        slots.set(@template.Excerpt, excerpt)
        // Populate Tags slot with space-separated tag links
        let tags_html = StringBuilder::new()
        let mut tag_idx = 0
        while tag_idx < page_tags.length() {
          let tag = page_tags[tag_idx]
          let tag_url = @tags.tag_url(tag.slug)
          tags_html.write_string(@html.anchor(tag_url, tag.value))
          if tag_idx < page_tags.length() - 1 {
            tags_html.write_string(" ")
          }
          tag_idx = tag_idx + 1
        }
        slots.set(@template.Tags, tags_html.to_string())
        // Populate Collection slot
        slots.set(@template.Collection, collection_name)
        // Populate Year/Month/Day slots from date
        let mut year_val = ""
        let mut month_val = ""
        let mut day_val = ""
        if date_text.length() > 0 {
          let date_parts = date_text.split("-").to_array()
          if date_parts.length() == 3 {
            year_val = date_parts[0].to_string()
            month_val = date_parts[1].to_string()
            day_val = date_parts[2].to_string()
          }
        }
        slots.set(@template.Year, year_val)
        slots.set(@template.Month, month_val)
        slots.set(@template.Day, day_val)
        slots.set(@template.PrevPostUrl, prev_post_url)
        slots.set(@template.PrevPostTitle, prev_post_title)
        slots.set(@template.NextPostUrl, next_post_url)
        slots.set(@template.NextPostTitle, next_post_title)
        let page_fields = frontmatter_to_strings(fm)
        let page_field_arrays = frontmatter_to_arrays(fm)
        match
          @template.render_template_with_data(
            tpl, slots, data_store, page_fields, page_field_arrays,
          ) {
          Ok(html) =>
            Ok(
              @html.inject_head_markup(
                html,
                @html.render_structured_data_script(structured_data),
              ),
            )
          Err(e) => Err("page template: " + template_error_text(e))
        }
      }
      None => {
        let meta : @html.PageMeta = {
          title: full_title,
          description: description_value,
          lang: "en",
          stylesheet: Some(absolute_url_builder(site.base_url, "/style.css")),
          canonical_url: Some(canonical),
          og_image: page_og_image,
          feed_url: None,
          structured_data,
        }
        Ok(@html.render_page(meta, page_body))
      }
    }
  }
  let page_html = match
    render_variant(
      url,
      absolute_url_builder(site.base_url, url),
      {
        let structured_data : Array[@html.StructuredData] = content_breadcrumb_structured_data_builder(
          site, collection_name, title, url,
        )
        structured_data.push(
          @html.BlogPosting({
            headline: title,
            description: description_value,
            url: absolute_url_builder(site.base_url, url),
            date_published: date_value,
            author: author_value,
            image: page_og_image,
          }),
        )
        structured_data
      },
    ) {
    Ok(html) => html
    Err(msg) => {
      diagnostics.push(build_error(Some(source_path), None, None, msg))
      return { document: None, diagnostics }
    }
  }
  let root_html = if is_root_page_for_site(site, slug) {
    match
      render_variant(
        "/",
        absolute_url_builder(site.base_url, "/"),
        website_structured_data_builder(site),
      ) {
      Ok(html) => Some(html)
      Err(msg) => {
        diagnostics.push(build_error(Some(source_path), None, None, msg))
        return { document: None, diagnostics }
      }
    }
  } else {
    None
  }
  return {
    document: Some({
      html: page_html,
      root_html,
      title,
      url,
      description: description_value,
      date: date_value,
      excerpt,
      resolved_links: resolved,
      tags: page_tags,
    }),
    diagnostics,
  }
}

///|
/// Metadata for a page in sorted order (used for prev/next navigation).
priv struct SortedCollectionPages {
  sorted_slugs : Array[String]
  slug_to_title : Map[String, String]
  slug_to_url : Map[String, String]
}

///|
/// Build a sorted index of pages in a collection for prev/next navigation.
///
/// Returns a structure mapping slugs to their titles and URLs, with slugs
/// sorted according to collection's sort order.
fn build_sorted_collection_pages(
  sources : Array[SourceFile],
  collection_name : String,
  sort_order : @collections.SortOrder,
) -> SortedCollectionPages {
  // Parse each source to get title and date for sorting
  let pages : Array[(String, String, String?)] = [] // (slug, title, date)
  let slug_to_title : Map[String, String] = Map::new()
  let slug_to_url : Map[String, String] = Map::new()
  let mut i = 0
  while i < sources.length() {
    let src = sources[i]
    let (title, date_opt) = match @frontmatter.parse(src.content) {
      Ok(fm) => (extract_title(fm), extract_date(fm))
      Err(_) => (src.slug, None)
    }
    slug_to_title.set(src.slug, title)
    slug_to_url.set(src.slug, collection_page_url(collection_name, src.slug))
    pages.push((src.slug, title, date_opt))
    i = i + 1
  }

  // Sort pages by date/title according to sort order using insertion sort
  let sorted = pages
  let mut i = 1
  while i < sorted.length() {
    let mut j = i
    while j > 0 {
      // Convert tuples to GraphPage for comparison
      let prev_slug = sorted[j - 1].0
      let prev_title = sorted[j - 1].1
      let prev_date = sorted[j - 1].2
      let curr_slug = sorted[j].0
      let curr_title = sorted[j].1
      let curr_date = sorted[j].2

      let page_a : @graph.GraphPage = {
        slug: prev_slug,
        title: prev_title,
        url: "",
        description: None,
        date: prev_date,
        outgoing: [],
      }
      let page_b : @graph.GraphPage = {
        slug: curr_slug,
        title: curr_title,
        url: "",
        description: None,
        date: curr_date,
        outgoing: [],
      }

      if compare_pages_by_order(page_a, page_b, sort_order) <= 0 {
        break
      }
      let tmp = sorted[j - 1]
      sorted[j - 1] = sorted[j]
      sorted[j] = tmp
      j = j - 1
    }
    i = i + 1
  }

  // Extract sorted slugs
  let sorted_slugs : Array[String] = []
  i = 0
  while i < sorted.length() {
    sorted_slugs.push(sorted[i].0)
    i = i + 1
  }

  { sorted_slugs, slug_to_title, slug_to_url }
}

///|
/// Get prev/next page info for a slug from sorted collection pages.
///
/// Returns (prev_url, prev_title, next_url, next_title).
/// Empty string if no prev/next exists.
fn get_adjacent_pages(
  sorted : SortedCollectionPages,
  slug : String,
) -> (String, String, String, String) {
  let mut i = 0
  let mut index : Int? = None
  while i < sorted.sorted_slugs.length() {
    if sorted.sorted_slugs[i] == slug {
      index = Some(i)
      break
    }
    i = i + 1
  }
  match index {
    Some(idx) => {
      let (prev_url, prev_title) = if idx > 0 {
        let prev_slug = sorted.sorted_slugs[idx - 1]
        (
          match sorted.slug_to_url.get(prev_slug) {
            Some(u) => u
            None => ""
          },
          match sorted.slug_to_title.get(prev_slug) {
            Some(t) => t
            None => ""
          },
        )
      } else {
        ("", "")
      }
      let (next_url, next_title) = if idx < sorted.sorted_slugs.length() - 1 {
        let next_slug = sorted.sorted_slugs[idx + 1]
        (
          match sorted.slug_to_url.get(next_slug) {
            Some(u) => u
            None => ""
          },
          match sorted.slug_to_title.get(next_slug) {
            Some(t) => t
            None => ""
          },
        )
      } else {
        ("", "")
      }
      (prev_url, prev_title, next_url, next_title)
    }
    None => ("", "", "", "")
  }
}

///|
priv struct LintDocOutcome {
  document : ProcessedDocument?
  violations : Array[@lint.LintViolation]
}

///|
priv struct BuildDocOutcome {
  document : ProcessedDocument?
  diagnostics : Array[@diagnostic.Diagnostic]
}

///|
fn process_document_for_lint(
  source : String,
  source_path : String,
  slug : String,
  collection_name : String,
  url : String,
  page_index : Map[String, String],
  known_tags : Map[String, String],
  tags_field : String,
  schema : @schema.Schema,
  site : @config.SiteConfig,
  data_store : @data.DataStore,
  page_template : @template.Template?,
  templates_dir : String,
  nav_links_html : String,
  custom_css : String,
  backlinks_html : String,
  prev_post_url : String,
  prev_post_title : String,
  next_post_url : String,
  next_post_title : String,
) -> LintDocOutcome {
  let violations : Array[@lint.LintViolation] = []
  let fm = match @frontmatter.parse(source) {
    Err(msg) => {
      let line = frontmatter_line_from_error(msg)
      violations.push({
        path: source_path,
        line,
        column: None,
        kind: @lint.FrontmatterError,
        message: msg,
      })
      return { document: None, violations }
    }
    Ok(parsed) => parsed
  }

  // Check for per-page template override
  let custom_template = match extract_template(fm) {
    Some(template_name) => {
      let template_path = templates_dir + "/" + template_name
      match load_template_file(template_path) {
        Ok(Some(tpl)) => Some(tpl)
        Ok(None) => {
          // Template file doesn't exist, warn and fall back to default
          violations.push({
            path: source_path,
            line: frontmatter_field_line(source, "template"),
            column: None,
            kind: @lint.TemplateSlotError,
            message: "template file '" +
            template_name +
            "' not found in " +
            templates_dir +
            ", using default page template",
          })
          page_template
        }
        Err(msg) => {
          // Template file exists but failed to load, warn and fall back to default
          violations.push({
            path: source_path,
            line: frontmatter_field_line(source, "template"),
            column: None,
            kind: @lint.TemplateSlotError,
            message: "failed to load template '" +
            template_name +
            "': " +
            msg +
            ", using default page template",
          })
          page_template
        }
      }
    }
    None => page_template
  }

  let schema_errors = @schema.validate(fm, schema)
  let mut i = 0
  while i < schema_errors.length() {
    let err = schema_errors[i]
    let kind = if err.message == "required field missing" {
      @lint.MissingRequiredFrontmatter
    } else {
      @lint.SchemaError
    }
    violations.push({
      path: source_path,
      line: frontmatter_field_line(source, err.field),
      column: None,
      kind,
      message: err.field + ": " + err.message,
    })
    i = i + 1
  }

  let page_tags = match @tags.extract(fm, tags_field) {
    Ok(values) => values
    Err(msg) => {
      violations.push({
        path: source_path,
        line: frontmatter_field_line(source, tags_field),
        column: None,
        kind: @lint.SchemaError,
        message: "tags field '" + tags_field + "': " + msg,
      })
      []
    }
  }

  i = 0
  while i < page_tags.length() {
    let tag = page_tags[i]
    if not(known_tags.contains(tag.slug)) {
      let (line, col) = line_col_of_first(source, tag.value)
      violations.push({
        path: source_path,
        line,
        column: col,
        kind: @lint.DanglingTagReference,
        message: "dangling tag reference '" +
        tag.value +
        "' (" +
        tag.slug +
        ") missing from tag index",
      })
    }
    i = i + 1
  }

  let raw_links = @wikilink.extract(fm.body, slug)
  let (resolved, link_errors) = @wikilink.resolve(raw_links, page_index)
  i = 0
  while i < link_errors.length() {
    let marker = "[[" + link_errors[i].link.target + "]]"
    let (line, col) = line_col_of_first(source, marker)
    violations.push({
      path: source_path,
      line,
      column: col,
      kind: @lint.BrokenWikilink,
      message: "[[" +
      link_errors[i].link.target +
      "]]: " +
      link_errors[i].message,
    })
    i = i + 1
  }

  if violations.length() > 0 {
    return { document: None, violations }
  }

  let wl_map = build_wikilink_map(resolved)
  let markdown_result = @markdown.render_with_diagnostics(fm.body, wl_map)
  i = 0
  while i < markdown_result.shortcode_errors.length() {
    violations.push({
      path: source_path,
      line: None,
      column: None,
      kind: @lint.ShortcodeError,
      message: @shortcode.error_text(markdown_result.shortcode_errors[i].error),
    })
    i = i + 1
  }

  if violations.length() > 0 {
    return { document: None, violations }
  }

  let body_html = markdown_result.html + @tags.render_page_tags(page_tags)
  let toc_html = if extract_toc_enabled(fm) {
    @markdown.render_table_of_contents(
      filter_toc_entries(markdown_result.toc, extract_toc_depth(fm)),
    )
  } else {
    ""
  }
  let excerpt = extract_excerpt_builder(fm.body)
  let title = extract_title(fm)
  let full_title = page_title_builder(title, site.title)
  let description_value = extract_description(fm)
  let date_value = extract_date(fm)
  let author_value = extract_author(fm)
  let og_image_value = extract_og_image(fm)
  let description_text = match description_value {
    Some(v) => v
    None => truncate_to_builder(excerpt, 160)
  }
  let date_text = match date_value {
    Some(v) => v
    None => ""
  }

  let page_html = match custom_template {
    Some(tpl) => {
      let slots = build_template_slots(
        full_title,
        body_html,
        date_text,
        description_text,
        url,
        site.title,
        nav_links_html,
        custom_css,
        "",
        "",
      )
      slots.set(@template.Backlinks, backlinks_html)
      slots.set(@template.TableOfContents, toc_html)
      let wc = count_words_markdown(fm.body)
      slots.set(@template.WordCount, wc.to_string())
      slots.set(@template.ReadingTime, reading_time_str(wc))
      slots.set(
        @template.Author,
        match author_value {
          Some(v) => v
          None => ""
        },
      )
      slots.set(@template.Excerpt, excerpt)
      // Populate Tags slot with space-separated tag links
      let tags_html = StringBuilder::new()
      let mut tag_idx = 0
      while tag_idx < page_tags.length() {
        let tag = page_tags[tag_idx]
        let tag_url = @tags.tag_url(tag.slug)
        tags_html.write_string(@html.anchor(tag_url, tag.value))
        if tag_idx < page_tags.length() - 1 {
          tags_html.write_string(" ")
        }
        tag_idx = tag_idx + 1
      }
      slots.set(@template.Tags, tags_html.to_string())
      // Populate Collection slot
      slots.set(@template.Collection, collection_name)
      // Populate Year/Month/Day slots from date
      let mut year_val = ""
      let mut month_val = ""
      let mut day_val = ""
      if date_text.length() > 0 {
        let date_parts = date_text.split("-").to_array()
        if date_parts.length() == 3 {
          year_val = date_parts[0].to_string()
          month_val = date_parts[1].to_string()
          day_val = date_parts[2].to_string()
        }
      }
      slots.set(@template.Year, year_val)
      slots.set(@template.Month, month_val)
      slots.set(@template.Day, day_val)
      slots.set(@template.PrevPostUrl, prev_post_url)
      slots.set(@template.PrevPostTitle, prev_post_title)
      slots.set(@template.NextPostUrl, next_post_url)
      slots.set(@template.NextPostTitle, next_post_title)
      let page_fields = frontmatter_to_strings(fm)
      let page_field_arrays = frontmatter_to_arrays(fm)
      match
        @template.render_template_with_data(
          tpl, slots, data_store, page_fields, page_field_arrays,
        ) {
        Ok(html) => html
        Err(e) => {
          violations.push({
            path: source_path,
            line: None,
            column: None,
            kind: @lint.TemplateSlotError,
            message: "page template: " + template_error_text(e),
          })
          return { document: None, violations }
        }
      }
    }
    None => {
      let canonical = absolute_url_builder(site.base_url, url)
      let page_og_image = match og_image_value {
        Some(img) => Some(img)
        None => site.og_image
      }
      let meta : @html.PageMeta = {
        title: full_title,
        description: description_value,
        lang: "en",
        stylesheet: Some(absolute_url_builder(site.base_url, "/style.css")),
        canonical_url: Some(canonical),
        og_image: page_og_image,
        feed_url: None,
        structured_data: blog_posting_structured_data_builder(
          title, description_value, canonical, date_value, author_value, page_og_image,
        ),
      }
      let page_body = if backlinks_html.length() > 0 {
        toc_html + body_html + backlinks_html
      } else {
        toc_html + body_html
      }
      @html.render_page(meta, page_body)
    }
  }
  {
    document: Some({
      html: page_html,
      root_html: None,
      title,
      url,
      description: description_value,
      date: date_value,
      excerpt,
      resolved_links: resolved,
      tags: page_tags,
    }),
    violations,
  }
}

// ── file I/O layer ────────────────────────────────────────────────────────────

///|
/// Collect all .md files from `content_dir`.
///
/// Each SourceFile is loaded eagerly: the full content is read in pass 1 so
/// pass 2 can focus on transformation without additional I/O interleaved with
/// the render loop.
pub fn collect_sources(
  content_dir : String,
) -> Array[SourceFile] raise @fs.IOError {
  let entries = @fs.read_dir(content_dir)
  let sources : Array[SourceFile] = []
  let mut i = 0
  while i < entries.length() {
    let filename = entries[i]
    if filename.has_suffix(".md") {
      let path = content_dir + "/" + filename
      let content = @fs.read_file_to_string(path)
      let file_slug = @slug.filename_to_slug(filename)
      sources.push({
        path,
        filename,
        slug: file_slug,
        content,
        fingerprint: @cache.fingerprint_for_source(path, content),
        stamp: @watch.file_stamp(path),
        link_targets: extract_link_targets(content, file_slug),
      })
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
fn ensure_parent_dirs_for_file(path : String) -> Unit raise @fs.IOError {
  let mut i = 0
  while i < path.length() {
    if char_at_builder(path, i) == '/' && i > 0 {
      let dir = substr_builder(path, 0, i)
      if not(@fs.path_exists(dir)) {
        @fs.create_dir(dir)
      }
    }
    i = i + 1
  }
}

///|
fn manifest_path_for_build(config : BuildConfig) -> String {
  config.output_dir + "/.lattice-manifest.json"
}

///|
fn page_output_path(
  config : BuildConfig,
  collection_name : String,
  slug : String,
) -> String {
  config.output_dir + "/" + collection_name + "/" + slug + "/index.html"
}

///|
fn root_page_output_path(config : BuildConfig) -> String {
  config.output_dir + "/index.html"
}

///|
fn register_collection_index_aliases(
  collection_sources : Array[CollectionSources],
  page_index : Map[String, String],
) -> Unit {
  let mut i = 0
  while i < collection_sources.length() {
    let coll = collection_sources[i]
    match collection_index_lookup_alias(coll.definition) {
      Some(lookup_key) =>
        page_index.set(lookup_key, collection_index_url(coll.definition.name))
      None => ()
    }
    i = i + 1
  }
}

///|
fn is_root_page_for_site(site : @config.SiteConfig, slug : String) -> Bool {
  match site.root_page {
    Some(root_slug) => root_slug == slug
    None => false
  }
}

///|
fn dependency_roots_for_build(
  config : BuildConfig,
  collections : Array[@collections.CollectionDef],
) -> Array[String] {
  let roots : Array[String] = [config.config_path]
  match config.collections_path {
    Some(path) => roots.push(path)
    None => ()
  }
  roots.push(templates_dir_for_build(config))
  roots.push(data_dir_for_build(config))
  let mut i = 0
  while i < collections.length() {
    match collections[i].template {
      Some(path) => roots.push(path)
      None => ()
    }
    i = i + 1
  }
  roots
}

///|
fn load_manifest(config : BuildConfig) -> @manifest.ManifestFile? {
  let path = manifest_path_for_build(config)
  if not(@fs.path_exists(path)) {
    return None
  }
  let source = @fs.read_file_to_string(path) catch {
    @fs.IOError(msg) => {
      println("[warn] incremental manifest read failed: " + msg)
      return None
    }
  }
  Some(@manifest.parse(source)) catch {
    @manifest.ParseError(msg) => {
      println("[warn] incremental manifest parse failed: " + msg)
      None
    }
  }
}

///|
fn dependency_manifest_entries(
  config : BuildConfig,
  collections : Array[@collections.CollectionDef],
) -> Result[Array[@manifest.ManifestEntry], String] {
  let snapshot = @watch.take_snapshot(
    dependency_roots_for_build(config, collections),
  ) catch {
    @watch.IOError(msg) => return Err(msg)
  }
  let entries : Array[@manifest.ManifestEntry] = []
  let mut i = 0
  while i < snapshot.length() {
    entries.push({
      src: snapshot[i].path,
      mtime: snapshot[i].stamp,
      out: "",
      targets: [],
    })
    i = i + 1
  }
  Ok(entries)
}

///|
fn build_incremental_state(
  config : BuildConfig,
  collection_sources : Array[CollectionSources],
  collections : Array[@collections.CollectionDef],
) -> IncrementalState {
  let previous_entries : Map[String, @manifest.ManifestEntry] = Map::new()
  let changed_sources : Map[String, Bool] = Map::new()
  if config.force_rebuild {
    return { force_full_rebuild: true, previous_entries, changed_sources }
  }

  let manifest = match load_manifest(config) {
    Some(file) => file
    None =>
      return { force_full_rebuild: true, previous_entries, changed_sources }
  }

  let mut i = 0
  while i < manifest.entries.length() {
    previous_entries.set(manifest.entries[i].src, manifest.entries[i])
    i = i + 1
  }

  let dependency_entries = match
    dependency_manifest_entries(config, collections) {
    Ok(entries) => entries
    Err(msg) => {
      println("[warn] incremental dependency snapshot failed: " + msg)
      return { force_full_rebuild: true, previous_entries, changed_sources }
    }
  }

  let current_dependencies : Map[String, Bool] = Map::new()
  i = 0
  while i < dependency_entries.length() {
    let entry = dependency_entries[i]
    current_dependencies.set(entry.src, true)
    match previous_entries.get(entry.src) {
      Some(previous) =>
        if previous.mtime != entry.mtime || previous.out != "" {
          return { force_full_rebuild: true, previous_entries, changed_sources }
        }
      None =>
        return { force_full_rebuild: true, previous_entries, changed_sources }
    }
    i = i + 1
  }

  let mut found_previous_dependency = false
  i = 0
  while i < manifest.entries.length() {
    let entry = manifest.entries[i]
    if entry.out == "" {
      found_previous_dependency = true
      if not(current_dependencies.contains(entry.src)) {
        return { force_full_rebuild: true, previous_entries, changed_sources }
      }
    }
    i = i + 1
  }
  if not(found_previous_dependency) {
    return { force_full_rebuild: true, previous_entries, changed_sources }
  }

  i = 0
  while i < collection_sources.length() {
    let coll = collection_sources[i]
    let mut j = 0
    while j < coll.sources.length() {
      let src = coll.sources[j]
      let out = page_output_path(config, coll.definition.name, src.slug)
      let root_out_missing = is_root_page_for_site(config.site, src.slug) &&
        not(@fs.path_exists(root_page_output_path(config)))
      let changed = match previous_entries.get(src.path) {
        Some(previous) =>
          previous.mtime != src.stamp ||
          previous.out != out ||
          not(@fs.path_exists(out)) ||
          root_out_missing
        None => true
      }
      if changed {
        changed_sources.set(src.path, true)
      }
      j = j + 1
    }
    i = i + 1
  }

  { force_full_rebuild: false, previous_entries, changed_sources }
}

///|
fn source_manifest_entries(
  config : BuildConfig,
  collection_sources : Array[CollectionSources],
) -> Array[@manifest.ManifestEntry] {
  let entries : Array[@manifest.ManifestEntry] = []
  let mut i = 0
  while i < collection_sources.length() {
    let coll = collection_sources[i]
    let mut j = 0
    while j < coll.sources.length() {
      let src = coll.sources[j]
      entries.push({
        src: src.path,
        mtime: src.stamp,
        out: page_output_path(config, coll.definition.name, src.slug),
        targets: src.link_targets,
      })
      j = j + 1
    }
    i = i + 1
  }
  entries
}

///|
fn write_manifest(
  config : BuildConfig,
  collection_sources : Array[CollectionSources],
  collections : Array[@collections.CollectionDef],
) -> Result[Unit, String] {
  let dependency_entries = match
    dependency_manifest_entries(config, collections) {
    Ok(entries) => entries
    Err(msg) => return Err(msg)
  }
  let entries = source_manifest_entries(config, collection_sources)
  let merged : Array[@manifest.ManifestEntry] = []
  let mut i = 0
  while i < dependency_entries.length() {
    merged.push(dependency_entries[i])
    i = i + 1
  }
  i = 0
  while i < entries.length() {
    merged.push(entries[i])
    i = i + 1
  }
  let manifest_path = manifest_path_for_build(config)
  try {
    ensure_parent_dirs_for_file(manifest_path)
    @fs.write_string_to_file(
      manifest_path,
      @manifest.render({ version: 1, entries: merged }),
    )
    Ok(())
  } catch {
    @fs.IOError(msg) => Err(msg)
  }
}

///|
fn mark_backlink_targets_changed(
  incremental : IncrementalState,
  collection_sources : Array[CollectionSources],
) -> Map[String, Bool] {
  let affected : Map[String, Bool] = Map::new()
  let mut i = 0
  while i < collection_sources.length() {
    let coll = collection_sources[i]
    let mut j = 0
    while j < coll.sources.length() {
      let src = coll.sources[j]
      if incremental.changed_sources.contains(src.path) {
        affected.set(src.slug, true)
        let mut k = 0
        while k < src.link_targets.length() {
          affected.set(src.link_targets[k], true)
          k = k + 1
        }
        match incremental.previous_entries.get(src.path) {
          Some(previous) => {
            k = 0
            while k < previous.targets.length() {
              affected.set(previous.targets[k], true)
              k = k + 1
            }
          }
          None => ()
        }
      }
      j = j + 1
    }
    i = i + 1
  }
  affected
}

///|
/// Build the full site.
///
/// Returns the build summary (0 errors = clean build).
///
/// Pass 1: read the content directory, compute slugs, build the page index.
/// Pass 2: run each source through the pipeline, write HTML to output_dir.
///
/// Each page is written to `output_dir/<slug>/index.html` for clean URLs.
pub fn build(
  config : BuildConfig,
  cache_store : @cache.CacheStore,
) -> BuildResult {
  println(
    "[lattice] building " + config.content_dir + " → " + config.output_dir,
  )
  let diagnostics : Array[@diagnostic.Diagnostic] = []

  let layout = match load_project_layout(config) {
    Ok(parsed) => parsed
    Err(msg) => {
      diagnostics.push(
        build_error(config.collections_path, None, None, "collections: " + msg),
      )
      return {
        errors: 1,
        diagnostics,
        rebuilt_pages: 0,
        unchanged_pages: 0,
        skipped_drafts: 0,
        redirect_count: 0,
      }
    }
  }
  let collections = layout.collections
  println(
    "[lattice] using " + collections.length().to_string() + " collections",
  )
  let templates = match load_templates(config) {
    Ok(t) => t
    Err(msg) => {
      diagnostics.push(build_error(None, None, None, "templates: " + msg))
      return {
        errors: 1,
        diagnostics,
        rebuilt_pages: 0,
        unchanged_pages: 0,
        skipped_drafts: 0,
        redirect_count: 0,
      }
    }
  }
  let nav_links_html = build_nav_links_html(collections)
  let custom_css = default_css()
  let data_store = match load_data_store(config, layout.data_schemas) {
    Ok(store) => store
    Err(err) => {
      let diag = data_error_diagnostic(err)
      diagnostics.push({
        severity: diag.severity,
        code: diag.code,
        path: diag.path,
        line: diag.line,
        column: diag.column,
        message: "data: " + diag.message,
        note: diag.note,
      })
      return {
        errors: 1,
        diagnostics,
        rebuilt_pages: 0,
        unchanged_pages: 0,
        skipped_drafts: 0,
        redirect_count: 0,
      }
    }
  }
  println("[lattice] loaded data files from " + data_dir_for_build(config))

  // Pass 1: collect sources for each collection
  let collection_sources : Array[CollectionSources] = []
  let mut source_count = 0
  let mut i = 0
  while i < collections.length() {
    let collection_def = collections[i]
    let sources = collect_sources(collection_def.content_dir) catch {
      @fs.IOError(msg) => {
        diagnostics.push(
          build_error(
            Some(collection_def.content_dir),
            None,
            None,
            "cannot read collection directory (" +
            collection_def.name +
            "): " +
            msg,
          ),
        )
        return {
          errors: 1,
          diagnostics,
          rebuilt_pages: 0,
          unchanged_pages: 0,
          skipped_drafts: 0,
          redirect_count: 0,
        }
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
          diagnostics.push(
            build_error(
              Some(source.path),
              None,
              None,
              "duplicate slug '" +
              source.slug +
              "' in collections '" +
              owner +
              "' and '" +
              coll.definition.name +
              "'",
            ),
          )
          return {
            errors: 1,
            diagnostics,
            rebuilt_pages: 0,
            unchanged_pages: 0,
            skipped_drafts: 0,
            redirect_count: 0,
          }
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
  register_collection_index_aliases(collection_sources, page_index)

  let tags_field = tags_field_name(config.site)
  let tag_catalog = collect_tag_catalog(collection_sources, tags_field)
  let known_tags = tag_catalog.name_by_slug
  let page_size = page_size_for_site(config.site)
  let backlink_index = build_backlink_index(collection_sources, page_index)
  let incremental = build_incremental_state(
    config, collection_sources, collections,
  )
  let backlink_affected = mark_backlink_targets_changed(
    incremental, collection_sources,
  )
  let next_cache_store = @cache.empty(config.output_dir)

  // Ensure output directory exists
  let dir_ok = try {
    ensure_dir(config.output_dir)
    true
  } catch {
    @fs.IOError(msg) => {
      diagnostics.push(
        build_error(
          Some(config.output_dir),
          None,
          None,
          "cannot create output directory: " + msg,
        ),
      )
      false
    }
  }
  if not(dir_ok) {
    return {
      errors: 1,
      diagnostics,
      rebuilt_pages: 0,
      unchanged_pages: 0,
      skipped_drafts: 0,
      redirect_count: 0,
    }
  }

  // Write default CSS (once, if not already present)
  let css_path = config.output_dir + "/style.css"
  if not(@fs.path_exists(css_path)) {
    let write_ok = try {
      @fs.write_string_to_file(css_path, custom_css)
      true
    } catch {
      @fs.IOError(msg) => {
        diagnostics.push(
          build_warning(
            Some(css_path),
            None,
            None,
            "could not write style.css: " + msg,
          ),
        )
        false
      }
    }
    if write_ok {
      println("[lattice] wrote " + css_path)
    }
  }

  // Pass 2: render and write each page
  let mut error_count = 0
  let mut rebuilt = 0
  let mut unchanged = 0
  let mut skipped_drafts = 0
  let mut redirect_count = 0
  let graph_pages : Array[@graph.GraphPage] = []
  let search_entries : Array[@search.SearchEntry] = []
  let tag_pages_by_slug : Map[String, Array[@tags.TaggedPage]] = Map::new()
  let rendered_collections : Array[CollectionRenderResult] = []
  i = 0
  while i < collection_sources.length() {
    let coll = collection_sources[i]
    let coll_pages : Array[@graph.GraphPage] = []
    let page_template = match
      load_collection_page_template(coll.definition, templates.page) {
      Ok(tpl) => tpl
      Err(msg) => {
        diagnostics.push(
          build_error(
            coll.definition.template,
            None,
            None,
            coll.definition.name + ": " + msg,
          ),
        )
        error_count = error_count + coll.sources.length()
        rendered_collections.push({
          name: coll.definition.name,
          pages: coll_pages,
          page_size: page_size_for_collection(config.site, coll.definition),
        })
        i = i + 1
        continue
      }
    }
    let collection_root = config.output_dir + "/" + coll.definition.name
    let collection_dir_ok = try {
      ensure_dir(collection_root)
      true
    } catch {
      @fs.IOError(msg) => {
        diagnostics.push(
          build_error(
            Some(collection_root),
            None,
            None,
            "cannot create collection output directory: " + msg,
          ),
        )
        false
      }
    }
    if not(collection_dir_ok) {
      diagnostics.push(
        build_error(
          Some(collection_root),
          None,
          None,
          "skipping collection build due to output directory error",
        ),
      )
      error_count = error_count + coll.sources.length()
      rendered_collections.push({
        name: coll.definition.name,
        pages: coll_pages,
        page_size: page_size_for_collection(config.site, coll.definition),
      })
      i = i + 1
      continue
    }

    // Build sorted pages for prev/next navigation
    let sorted_coll_pages = build_sorted_collection_pages(
      coll.sources,
      coll.definition.name,
      coll.definition.sort_order,
    )

    let mut j = 0
    while j < coll.sources.length() {
      let src = coll.sources[j]
      let page_url = collection_page_url(coll.definition.name, src.slug)
      let page_context = coll.definition.name + "/" + src.slug
      let out_path = page_output_path(config, coll.definition.name, src.slug)
      let root_out_path = root_page_output_path(config)
      let cache_hit = @cache.should_skip(
        cache_store,
        src.slug,
        src.fingerprint,
        out_path,
        config.force_rebuild,
      )
      let should_rebuild = incremental.force_full_rebuild ||
        incremental.changed_sources.contains(src.path) ||
        backlink_affected.contains(src.slug) ||
        not(cache_hit)
      let page_backlinks_html = match backlink_index.get(src.slug) {
        Some(refs) => render_backlinks_html(refs)
        None => ""
      }
      let (prev_post_url, prev_post_title, next_post_url, next_post_title) = get_adjacent_pages(
        sorted_coll_pages,
        src.slug,
      )
      let doc_outcome = process_document(
        src.content,
        src.path,
        src.slug,
        coll.definition.name,
        page_url,
        page_index,
        known_tags,
        tags_field,
        coll.definition.schema,
        config.site,
        data_store,
        page_template,
        templates_dir_for_build(config),
        nav_links_html,
        custom_css,
        page_backlinks_html,
        should_rebuild,
        prev_post_url,
        prev_post_title,
        next_post_url,
        next_post_title,
      )
      let mut diag_idx = 0
      while diag_idx < doc_outcome.diagnostics.length() {
        diagnostics.push(doc_outcome.diagnostics[diag_idx])
        diag_idx = diag_idx + 1
      }
      match doc_outcome.document {
        None => error_count = error_count + 1
        Some(doc) => {
          // Check if this is a draft post
          // We already parsed frontmatter in process_document, so we can check the result there
          // Instead of re-parsing, we'll check if document was validated and extract draft status
          // from the original source's frontmatter parse result during validation
          let is_draft_post = match @frontmatter.parse(src.content) {
            Ok(fm) => is_draft(fm)
            Err(_) => false
          }
          let should_skip_draft = is_draft_post && not(config.include_drafts)

          let write_result = if should_skip_draft || not(should_rebuild) {
            // Skip output for drafts (unless --drafts flag is set)
            if should_skip_draft {
              println("[skip draft] " + page_context)
            } else if not(should_rebuild) {
              println("[skip] " + page_context)
              unchanged = unchanged + 1
            }
            Some(out_path)
          } else {
            let page_dir = collection_root + "/" + src.slug
            try {
              ensure_dir(page_dir)
              @fs.write_string_to_file(out_path, doc.html)
              if is_root_page_for_site(config.site, src.slug) {
                match doc.root_html {
                  Some(root_html) =>
                    @fs.write_string_to_file(root_out_path, root_html)
                  None => @fs.write_string_to_file(root_out_path, doc.html)
                }
              }
              Some(out_path)
            } catch {
              @fs.IOError(msg) => {
                diagnostics.push(
                  build_error(
                    Some(out_path),
                    None,
                    None,
                    page_context + ": write failed: " + msg,
                  ),
                )
                None
              }
            }
          }
          match write_result {
            Some(_) => {
              if should_rebuild && not(should_skip_draft) {
                println("[build] " + page_context)
                rebuilt = rebuilt + 1
              } else if should_skip_draft {
                // Draft skipped, don't count as rebuilt or unchanged
                skipped_drafts = skipped_drafts + 1
                ()
              } else if not(should_rebuild) {
                println("[skip] " + page_context)
                unchanged = unchanged + 1
              }
              @cache.remember(next_cache_store, src.slug, src.fingerprint)

              // Generate redirect pages if redirect_from is specified
              let redirects_generated = match @frontmatter.parse(src.content) {
                Ok(fm) =>
                  match fm.fields.get("redirect_from") {
                    Some(@frontmatter.FArray(urls)) => {
                      let mut rd_count = 0
                      let mut k = 0
                      while k < urls.length() {
                        match urls[k] {
                          @frontmatter.FStr(redirect_url) => {
                            let canonical = absolute_url_builder(
                              config.site.base_url,
                              doc.url,
                            )
                            let redirect_html = render_redirect_page(canonical)
                            let redirect_out_path = config.output_dir +
                              "/" +
                              redirect_url_to_output_path(redirect_url)
                            try {
                              // Ensure parent directory exists
                              let redirect_dir = if redirect_out_path.contains(
                                  "/",
                                ) {
                                let mut last_slash = 0
                                let mut idx = 0
                                while idx < redirect_out_path.length() {
                                  if char_at_builder(redirect_out_path, idx) ==
                                    '/' {
                                    last_slash = idx
                                  }
                                  idx = idx + 1
                                }
                                substr_builder(redirect_out_path, 0, last_slash)
                              } else {
                                "."
                              }
                              ensure_dir(redirect_dir)
                              @fs.write_string_to_file(
                                redirect_out_path, redirect_html,
                              )
                              rd_count = rd_count + 1
                            } catch {
                              @fs.IOError(msg) =>
                                diagnostics.push(
                                  build_error(
                                    Some(redirect_out_path),
                                    None,
                                    None,
                                    "redirect write failed: " + msg,
                                  ),
                                )
                            }
                          }
                          _ => ()
                        }
                        k = k + 1
                      }
                      rd_count
                    }
                    _ => 0
                  }
                Err(_) => 0
              }
              redirect_count = redirect_count + redirects_generated

              // Only include non-draft posts in indexes
              if not(should_skip_draft) {
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
                let mut k = 0
                while k < doc.tags.length() {
                  let tag = doc.tags[k]
                  match tag_pages_by_slug.get(tag.slug) {
                    Some(existing) => {
                      existing.push({
                        title: doc.title,
                        url: doc.url,
                        slug: src.slug,
                      })
                      tag_pages_by_slug.set(tag.slug, existing)
                    }
                    None =>
                      tag_pages_by_slug.set(tag.slug, [
                        { title: doc.title, url: doc.url, slug: src.slug },
                      ])
                  }
                  k = k + 1
                }
                let search_tags : Array[String] = []
                k = 0
                while k < doc.tags.length() {
                  search_tags.push(doc.tags[k].value)
                  k = k + 1
                }
                let collection_name = if coll.definition.name.length() == 0 {
                  "default"
                } else {
                  coll.definition.name
                }
                search_entries.push(
                  @search.new_entry(
                    doc.title,
                    src.slug,
                    doc.url,
                    search_tags,
                    collection_name,
                    doc.excerpt,
                  ),
                )
              }
            }
            None => error_count = error_count + 1
          }
        }
      }
      j = j + 1
    }
    // Sort collection pages according to sort_order
    sort_collection_pages(coll_pages, coll.definition.sort_order)
    rendered_collections.push({
      name: coll.definition.name,
      pages: coll_pages,
      page_size: page_size_for_collection(config.site, coll.definition),
    })
    i = i + 1
  }

  if error_count == 0 {
    i = 0
    while i < rendered_collections.length() {
      let coll = rendered_collections[i]
      let coll_dir = config.output_dir + "/" + coll.name

      let feed_write_ok = try {
        let feed_title = config.site.title + " (" + coll.name + ")"
        let feed_xml = @rss.render_feed(
          feed_title,
          config.site.base_url,
          coll.pages,
          config.site.feed_limit,
        )
        let out_path = coll_dir + "/feed.xml"
        @fs.write_string_to_file(out_path, feed_xml)
        println("[lattice] wrote " + out_path)
        true
      } catch {
        @fs.IOError(msg) => {
          diagnostics.push(
            build_error(
              Some(coll_dir + "/feed.xml"),
              None,
              None,
              coll.name + " feed: write failed: " + msg,
            ),
          )
          false
        }
      }
      if not(feed_write_ok) {
        error_count = error_count + 1
      }

      let paginated_index_pages = paginate_with_optional_size(
        coll.pages,
        coll.page_size,
        fn(page_number) { collection_index_page_url(coll.name, page_number) },
      )
      let mut page_idx = 0
      while page_idx < paginated_index_pages.length() {
        let pagination = paginated_index_pages[page_idx]
        let index_html = match
          render_collection_index(
            coll.name,
            pagination,
            config.site,
            templates.index,
            nav_links_html,
            custom_css,
            data_store,
          ) {
          Ok(html) => Some(html)
          Err(msg) => {
            diagnostics.push(
              build_error(
                Some(coll_dir + "/index.html"),
                None,
                None,
                coll.name +
                " index page " +
                pagination.page_number.to_string() +
                ": " +
                msg,
              ),
            )
            None
          }
        }
        let index_write_ok = match index_html {
          Some(html) =>
            try {
              let out_path = if pagination.page_number == 1 {
                coll_dir + "/index.html"
              } else {
                coll_dir +
                "/page/" +
                pagination.page_number.to_string() +
                "/index.html"
              }
              ensure_parent_dirs_for_file(out_path)
              @fs.write_string_to_file(out_path, html)
              println("[lattice] wrote " + out_path)
              true
            } catch {
              @fs.IOError(msg) => {
                diagnostics.push(
                  build_error(
                    Some(
                      if pagination.page_number == 1 {
                        coll_dir + "/index.html"
                      } else {
                        coll_dir +
                        "/page/" +
                        pagination.page_number.to_string() +
                        "/index.html"
                      },
                    ),
                    None,
                    None,
                    coll.name +
                    " index page " +
                    pagination.page_number.to_string() +
                    ": write failed: " +
                    msg,
                  ),
                )
                false
              }
            }
          None => false
        }
        if not(index_write_ok) {
          error_count = error_count + 1
        }
        page_idx = page_idx + 1
      }

      // Build archive pages for this collection
      let (_, archive_errors) = build_archive_pages(
        coll.name,
        coll.pages,
        config,
        templates.archive,
        templates.index,
        nav_links_html,
        custom_css,
        data_store,
      )
      if archive_errors > 0 {
        error_count = error_count + archive_errors
      }

      i = i + 1
    }

    if error_count == 0 {
      let tags_root = config.output_dir + "/tags"
      let tags_dir_ok = try {
        ensure_dir(tags_root)
        true
      } catch {
        @fs.IOError(msg) => {
          diagnostics.push(
            build_error(
              Some(tags_root),
              None,
              None,
              "tags: cannot create output directory: " + msg,
            ),
          )
          false
        }
      }
      if tags_dir_ok {
        let tag_summaries : Array[@tags.TagSummary] = []
        i = 0
        while i < tag_catalog.ordered_slugs.length() {
          let tag_slug = tag_catalog.ordered_slugs[i]
          let tag_name = match tag_catalog.name_by_slug.get(tag_slug) {
            Some(name) => name
            None => tag_slug
          }
          let pages = match tag_pages_by_slug.get(tag_slug) {
            Some(items) => items
            None => []
          }
          let tag_dir = tags_root + "/" + tag_slug
          let tag_dir_ok = try {
            ensure_dir(tag_dir)
            true
          } catch {
            @fs.IOError(msg) => {
              diagnostics.push(
                build_error(
                  Some(tag_dir),
                  None,
                  None,
                  "tags/" + tag_slug + ": cannot create directory: " + msg,
                ),
              )
              false
            }
          }
          if tag_dir_ok {
            let paginated_tag_pages = paginate_with_optional_size(
              pages,
              page_size,
              fn(page_number) { tag_page_url(tag_slug, page_number) },
            )
            let mut page_idx = 0
            while page_idx < paginated_tag_pages.length() {
              let pagination = paginated_tag_pages[page_idx]
              let tag_page : @tags.TagPage = {
                tag: tag_name,
                slug: tag_slug,
                pages: pagination.documents,
              }
              let tag_html = match
                render_tag_page_html(
                  tag_page,
                  pagination,
                  config.site,
                  templates.tag_page,
                  templates.index,
                  nav_links_html,
                  custom_css,
                  data_store,
                ) {
                Ok(html) => Some(html)
                Err(msg) => {
                  diagnostics.push(
                    build_error(
                      Some(tag_dir + "/index.html"),
                      None,
                      None,
                      "tags/" +
                      tag_slug +
                      " page " +
                      pagination.page_number.to_string() +
                      ": " +
                      msg,
                    ),
                  )
                  None
                }
              }
              match tag_html {
                Some(html) => {
                  let tag_write_ok = try {
                    let out_path = if pagination.page_number == 1 {
                      tag_dir + "/index.html"
                    } else {
                      tag_dir +
                      "/page/" +
                      pagination.page_number.to_string() +
                      "/index.html"
                    }
                    ensure_parent_dirs_for_file(out_path)
                    @fs.write_string_to_file(out_path, html)
                    println("[lattice] wrote " + out_path)
                    true
                  } catch {
                    @fs.IOError(msg) => {
                      diagnostics.push(
                        build_error(
                          Some(
                            if pagination.page_number == 1 {
                              tag_dir + "/index.html"
                            } else {
                              tag_dir +
                              "/page/" +
                              pagination.page_number.to_string() +
                              "/index.html"
                            },
                          ),
                          None,
                          None,
                          "tags/" +
                          tag_slug +
                          " page " +
                          pagination.page_number.to_string() +
                          ": write failed: " +
                          msg,
                        ),
                      )
                      false
                    }
                  }
                  if not(tag_write_ok) {
                    error_count = error_count + 1
                  }
                }
                None => error_count = error_count + 1
              }
              page_idx = page_idx + 1
            }
          } else {
            error_count = error_count + 1
          }
          tag_summaries.push({
            tag: tag_name,
            slug: tag_slug,
            count: pages.length(),
          })
          i = i + 1
        }

        if error_count == 0 {
          let paginated_tags_index = paginate_with_optional_size(
            tag_summaries,
            page_size,
            fn(page_number) { tags_index_page_url(page_number) },
          )
          let mut page_idx = 0
          while page_idx < paginated_tags_index.length() {
            let pagination = paginated_tags_index[page_idx]
            let tags_index : @tags.TagIndex = { tags: pagination.documents }
            let tags_index_html = match
              render_tags_index_html(
                tags_index,
                pagination,
                config.site,
                templates.tag_index,
                templates.index,
                nav_links_html,
                custom_css,
                data_store,
              ) {
              Ok(html) => Some(html)
              Err(msg) => {
                diagnostics.push(
                  build_error(
                    Some(tags_root + "/index.html"),
                    None,
                    None,
                    "tags index page " +
                    pagination.page_number.to_string() +
                    ": " +
                    msg,
                  ),
                )
                None
              }
            }
            let tags_index_ok = match tags_index_html {
              Some(html) =>
                try {
                  let out_path = if pagination.page_number == 1 {
                    tags_root + "/index.html"
                  } else {
                    tags_root +
                    "/page/" +
                    pagination.page_number.to_string() +
                    "/index.html"
                  }
                  ensure_parent_dirs_for_file(out_path)
                  @fs.write_string_to_file(out_path, html)
                  println("[lattice] wrote " + out_path)
                  true
                } catch {
                  @fs.IOError(msg) => {
                    diagnostics.push(
                      build_error(
                        Some(
                          if pagination.page_number == 1 {
                            tags_root + "/index.html"
                          } else {
                            tags_root +
                            "/page/" +
                            pagination.page_number.to_string() +
                            "/index.html"
                          },
                        ),
                        None,
                        None,
                        "tags index page " +
                        pagination.page_number.to_string() +
                        ": write failed: " +
                        msg,
                      ),
                    )
                    false
                  }
                }
              None => false
            }
            if not(tags_index_ok) {
              error_count = error_count + 1
            }
            page_idx = page_idx + 1
          }
        }
      } else {
        error_count = error_count + 1
      }
    }

    if error_count == 0 {
      let sitemap_write_ok = try {
        let sitemap_xml = @sitemap.render_sitemap(
          config.site.base_url,
          graph_pages,
        )
        let out_path = config.output_dir + "/sitemap.xml"
        @fs.write_string_to_file(out_path, sitemap_xml)
        println("[lattice] wrote " + out_path)
        true
      } catch {
        @fs.IOError(msg) => {
          diagnostics.push(
            build_error(
              Some(config.output_dir + "/sitemap.xml"),
              None,
              None,
              "sitemap: write failed: " + msg,
            ),
          )
          false
        }
      }
      if not(sitemap_write_ok) {
        error_count = error_count + 1
      }
    }
    if error_count == 0 {
      let robots_txt_enabled = match config.site.robots_txt {
        Some(enabled) => enabled
        None => true
      }
      let robots_txt_content = @robots.render_robots_txt(
        config.site.base_url,
        robots_txt_enabled,
      )
      if robots_txt_content.length() > 0 {
        let robots_write_ok = try {
          let out_path = config.output_dir + "/robots.txt"
          @fs.write_string_to_file(out_path, robots_txt_content)
          println("[lattice] wrote " + out_path)
          true
        } catch {
          @fs.IOError(msg) => {
            diagnostics.push(
              build_error(
                Some(config.output_dir + "/robots.txt"),
                None,
                None,
                "robots.txt: write failed: " + msg,
              ),
            )
            false
          }
        }
        if not(robots_write_ok) {
          error_count = error_count + 1
        }
      } else {
        println("[lattice] robots.txt skipped (disabled)")
      }
    }
    if error_count == 0 {
      let search_write_ok = try {
        let search_json = @search.render_search_index(search_entries)
        let out_path = config.output_dir +
          "/" +
          search_index_file_name(config.site)
        ensure_parent_dirs_for_file(out_path)
        @fs.write_string_to_file(out_path, search_json)
        println("[lattice] wrote " + out_path)
        true
      } catch {
        @fs.IOError(msg) => {
          diagnostics.push(
            build_error(
              Some(
                config.output_dir + "/" + search_index_file_name(config.site),
              ),
              None,
              None,
              "search index: write failed: " + msg,
            ),
          )
          false
        }
      }
      if not(search_write_ok) {
        error_count = error_count + 1
      }
    }
    if error_count == 0 {
      let graph_write_ok = try {
        let graph_json = @graph.render_graph_json(graph_pages)
        let out_path = config.output_dir + "/graph.json"
        @fs.write_string_to_file(out_path, graph_json)
        println("[lattice] wrote " + out_path)
        true
      } catch {
        @fs.IOError(msg) => {
          diagnostics.push(
            build_error(
              Some(config.output_dir + "/graph.json"),
              None,
              None,
              "graph.json: write failed: " + msg,
            ),
          )
          false
        }
      }
      if not(graph_write_ok) {
        error_count = error_count + 1
      }
    }
    if error_count == 0 {
      match
        @assets.copy_static(
          config.content_dir,
          config.output_dir,
          static_dir_name(config.site),
        ) {
        Ok(copied) =>
          if copied > 0 {
            println(
              "[lattice] copied " + copied.to_string() + " static asset files",
            )
          }
        Err(e) => {
          diagnostics.push(asset_error_diagnostic(e))
          error_count = error_count + 1
        }
      }
    }
    if error_count == 0 {
      let page_path = config.content_dir + "/404.md"
      let has_custom_404 = @fs.path_exists(page_path)
      let fortyfour_html = match
        render_404_page(
          config, templates, nav_links_html, custom_css, data_store,
        ) {
        Ok(html) => Some(html)
        Err(msg) => {
          diagnostics.push(
            build_error(Some(page_path), None, None, "404 page: " + msg),
          )
          None
        }
      }
      match fortyfour_html {
        Some(html) =>
          try {
            let out_path = config.output_dir + "/404.html"
            @fs.write_string_to_file(out_path, html)
            let source_type = if has_custom_404 { "custom" } else { "default" }
            println("[lattice] wrote 404.html (" + source_type + ")")
            ()
          } catch {
            @fs.IOError(msg) => {
              diagnostics.push(
                build_error(
                  Some(config.output_dir + "/404.html"),
                  None,
                  None,
                  "404 page: write failed: " + msg,
                ),
              )
              error_count = error_count + 1
            }
          }
        None => error_count = error_count + 1
      }
    }
    if error_count == 0 {
      match write_manifest(config, collection_sources, collections) {
        Ok(_) => ()
        Err(msg) => {
          diagnostics.push(
            build_error(
              Some(config.output_dir + "/manifest.json"),
              None,
              None,
              "manifest: write failed: " + msg,
            ),
          )
          error_count = error_count + 1
        }
      }
    }
    if error_count == 0 {
      match @cache.save(next_cache_store) {
        Ok(_) => ()
        Err(err) => {
          diagnostics.push(
            build_error(
              Some(config.output_dir),
              None,
              None,
              "cache: " + @cache.error_text(err),
            ),
          )
          error_count = error_count + 1
        }
      }
    }
  } else {
    diagnostics.push(
      build_warning(
        None,
        None,
        None,
        "skipped collection feeds/indexes, tags, sitemap, and search index generation due to prior build errors",
      ),
    )
  }

  error_count = @diagnostic.count_errors(diagnostics)
  println(
    "[lattice] " +
    "rebuilt " +
    rebuilt.to_string() +
    " pages (" +
    unchanged.to_string() +
    " unchanged), " +
    redirect_count.to_string() +
    " redirects, " +
    error_count.to_string() +
    " errors",
  )
  if skipped_drafts > 0 && not(config.include_drafts) {
    println(
      "[lattice] skipped " +
      skipped_drafts.to_string() +
      " draft(s). Use --drafts to include them.",
    )
  }
  {
    errors: error_count,
    diagnostics,
    rebuilt_pages: rebuilt,
    unchanged_pages: unchanged,
    skipped_drafts,
    redirect_count,
  }
}

///|
/// Check structural integrity without writing output files.
///
/// Runs the full two-pass validation pipeline and returns every violation found.
pub fn check(config : BuildConfig) -> @lint.LintResult {
  println("[lattice] checking " + config.content_dir)
  let violations : Array[@lint.LintViolation] = []

  let layout = match load_project_layout(config) {
    Ok(parsed) => parsed
    Err(msg) => {
      violations.push({
        path: match config.collections_path {
          Some(path) => path
          None => config.content_dir + "/lattice.conf"
        },
        line: None,
        column: None,
        kind: @lint.CollectionsError,
        message: msg,
      })
      return { violations, }
    }
  }
  let collections = layout.collections
  println(
    "[lattice] using " + collections.length().to_string() + " collections",
  )

  let templates_result = load_templates_for_lint(config)
  let mut i = 0
  while i < templates_result.violations.length() {
    violations.push(templates_result.violations[i])
    i = i + 1
  }
  let templates = templates_result.templates

  let nav_links_html = build_nav_links_html(collections)
  let custom_css = default_css()
  let data_store = match load_data_store(config, layout.data_schemas) {
    Ok(store) => store
    Err(err) => {
      violations.push({
        path: data_dir_for_build(config),
        line: None,
        column: None,
        kind: @lint.DataError,
        message: @data.format_error(err),
      })
      @data.empty_store()
    }
  }

  let collection_sources : Array[CollectionSources] = []
  let mut source_count = 0
  i = 0
  while i < collections.length() {
    let collection_def = collections[i]
    let sources = collect_sources(collection_def.content_dir) catch {
      @fs.IOError(msg) => {
        violations.push({
          path: collection_def.content_dir,
          line: None,
          column: None,
          kind: @lint.IOError,
          message: "cannot read collection directory " +
          collection_def.name +
          ": " +
          msg,
        })
        []
      }
    }
    source_count = source_count + sources.length()
    collection_sources.push({ definition: collection_def, sources })
    i = i + 1
  }
  println("[lattice] found " + source_count.to_string() + " source files")

  let page_index : Map[String, String] = Map::new()
  let slug_owner : Map[String, String] = Map::new()
  i = 0
  while i < collection_sources.length() {
    let coll = collection_sources[i]
    let mut j = 0
    while j < coll.sources.length() {
      let source = coll.sources[j]
      match slug_owner.get(source.slug) {
        Some(owner) =>
          violations.push({
            path: source.path,
            line: None,
            column: None,
            kind: @lint.DuplicateSlug,
            message: "duplicate slug '" +
            source.slug +
            "' in collections '" +
            owner +
            "' and '" +
            coll.definition.name +
            "'",
          })
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
  register_collection_index_aliases(collection_sources, page_index)

  let tags_field = tags_field_name(config.site)
  let tag_catalog = collect_tag_catalog(collection_sources, tags_field)
  let known_tags = tag_catalog.name_by_slug
  let page_size = page_size_for_site(config.site)
  let backlink_index = build_backlink_index(collection_sources, page_index)

  let graph_pages : Array[@graph.GraphPage] = []
  let tag_pages_by_slug : Map[String, Array[@tags.TaggedPage]] = Map::new()
  let rendered_collections : Array[CollectionRenderResult] = []
  i = 0
  while i < collection_sources.length() {
    let coll = collection_sources[i]
    let page_template = load_collection_page_template_for_lint(
      coll.definition,
      templates.page,
      violations,
    )
    // Cross-validate template {{page.field}} references against the collection
    // schema. A reference to a field not declared in the schema is a structural
    // violation: it means the template and schema disagree about the content
    // contract, and the field will silently render as empty at build time.
    match page_template {
      Some(tpl) => {
        let tpl_path = match coll.definition.template {
          Some(path) => path
          None => templates_dir_for_build(config) + "/page.html"
        }
        let schema = coll.definition.schema
        let valid_fields : Map[String, Bool] = Map::new()
        let mut fi = 0
        while fi < schema.fields.length() {
          valid_fields.set(schema.fields[fi].name, true)
          fi = fi + 1
        }
        let fm_refs = @template.collect_frontmatter_refs(tpl)
        let mut ri = 0
        while ri < fm_refs.length() {
          let field = fm_refs[ri]
          match valid_fields.get(field) {
            None =>
              violations.push({
                path: tpl_path,
                line: None,
                column: None,
                kind: @lint.TemplateSlotError,
                message: "template references '{{page." +
                field +
                "}}' but field '" +
                field +
                "' is not declared in the '" +
                coll.definition.name +
                "' collection schema",
              })
            _ => ()
          }
          ri = ri + 1
        }
      }
      None => ()
    }
    let coll_pages : Array[@graph.GraphPage] = []
    // Build sorted pages for prev/next navigation
    let sorted_coll_pages = build_sorted_collection_pages(
      coll.sources,
      coll.definition.name,
      coll.definition.sort_order,
    )
    let mut j = 0
    while j < coll.sources.length() {
      let src = coll.sources[j]
      let page_url = collection_page_url(coll.definition.name, src.slug)
      let lint_backlinks_html = match backlink_index.get(src.slug) {
        Some(refs) => render_backlinks_html(refs)
        None => ""
      }
      let (prev_post_url, prev_post_title, next_post_url, next_post_title) = get_adjacent_pages(
        sorted_coll_pages,
        src.slug,
      )
      let lint_outcome = process_document_for_lint(
        src.content,
        src.path,
        src.slug,
        coll.definition.name,
        page_url,
        page_index,
        known_tags,
        tags_field,
        coll.definition.schema,
        config.site,
        data_store,
        page_template,
        templates_dir_for_build(config),
        nav_links_html,
        custom_css,
        lint_backlinks_html,
        prev_post_url,
        prev_post_title,
        next_post_url,
        next_post_title,
      )
      let mut k = 0
      while k < lint_outcome.violations.length() {
        violations.push(lint_outcome.violations[k])
        k = k + 1
      }
      match lint_outcome.document {
        Some(doc) => {
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
          k = 0
          while k < doc.tags.length() {
            let tag = doc.tags[k]
            match tag_pages_by_slug.get(tag.slug) {
              Some(existing) => {
                existing.push({ title: doc.title, url: doc.url, slug: src.slug })
                tag_pages_by_slug.set(tag.slug, existing)
              }
              None =>
                tag_pages_by_slug.set(tag.slug, [
                  { title: doc.title, url: doc.url, slug: src.slug },
                ])
            }
            k = k + 1
          }
        }
        None => ()
      }
      j = j + 1
    }
    rendered_collections.push({
      name: coll.definition.name,
      pages: coll_pages,
      page_size: page_size_for_collection(config.site, coll.definition),
    })
    i = i + 1
  }

  i = 0
  while i < rendered_collections.length() {
    let coll = rendered_collections[i]
    let feed_title = config.site.title + " (" + coll.name + ")"
    let _feed_xml = @rss.render_feed(
      feed_title,
      config.site.base_url,
      coll.pages,
      config.site.feed_limit,
    )
    let paginated_index_pages = paginate_with_optional_size(
      coll.pages,
      coll.page_size,
      fn(page_number) { collection_index_page_url(coll.name, page_number) },
    )
    let mut page_idx = 0
    while page_idx < paginated_index_pages.length() {
      let pagination = paginated_index_pages[page_idx]
      match
        render_collection_index(
          coll.name,
          pagination,
          config.site,
          templates.index,
          nav_links_html,
          custom_css,
          data_store,
        ) {
        Ok(_) => ()
        Err(msg) =>
          violations.push({
            path: templates_dir_for_build(config) + "/index.html",
            line: None,
            column: None,
            kind: @lint.TemplateSlotError,
            message: coll.name +
            " index page " +
            pagination.page_number.to_string() +
            ": " +
            msg,
          })
      }
      page_idx = page_idx + 1
    }
    i = i + 1
  }

  let tag_summaries : Array[@tags.TagSummary] = []
  i = 0
  while i < tag_catalog.ordered_slugs.length() {
    let tag_slug = tag_catalog.ordered_slugs[i]
    let tag_name = match tag_catalog.name_by_slug.get(tag_slug) {
      Some(name) => name
      None => tag_slug
    }
    let pages = match tag_pages_by_slug.get(tag_slug) {
      Some(items) => items
      None => []
    }
    let paginated_tag_pages = paginate_with_optional_size(pages, page_size, fn(
      page_number,
    ) {
      tag_page_url(tag_slug, page_number)
    })
    let mut page_idx = 0
    while page_idx < paginated_tag_pages.length() {
      let pagination = paginated_tag_pages[page_idx]
      let tag_page : @tags.TagPage = {
        tag: tag_name,
        slug: tag_slug,
        pages: pagination.documents,
      }
      match
        render_tag_page_html(
          tag_page,
          pagination,
          config.site,
          templates.tag_page,
          templates.index,
          nav_links_html,
          custom_css,
          data_store,
        ) {
        Ok(_) => ()
        Err(msg) =>
          violations.push({
            path: templates_dir_for_build(config) + "/tag.html",
            line: None,
            column: None,
            kind: @lint.TemplateSlotError,
            message: "tags/" +
            tag_slug +
            " page " +
            pagination.page_number.to_string() +
            ": " +
            msg,
          })
      }
      page_idx = page_idx + 1
    }
    tag_summaries.push({ tag: tag_name, slug: tag_slug, count: pages.length() })
    i = i + 1
  }

  let paginated_tags_index = paginate_with_optional_size(
    tag_summaries,
    page_size,
    fn(page_number) { tags_index_page_url(page_number) },
  )
  i = 0
  while i < paginated_tags_index.length() {
    let pagination = paginated_tags_index[i]
    let tags_index : @tags.TagIndex = { tags: pagination.documents }
    match
      render_tags_index_html(
        tags_index,
        pagination,
        config.site,
        templates.tag_index,
        templates.index,
        nav_links_html,
        custom_css,
        data_store,
      ) {
      Ok(_) => ()
      Err(msg) =>
        violations.push({
          path: templates_dir_for_build(config) + "/tags.html",
          line: None,
          column: None,
          kind: @lint.TemplateSlotError,
          message: "tags index page " +
          pagination.page_number.to_string() +
          ": " +
          msg,
        })
    }
    i = i + 1
  }

  let _sitemap_xml = @sitemap.render_sitemap(config.site.base_url, graph_pages)
  let static_validation = @assets.check_static(
    config.content_dir,
    static_dir_name(config.site),
  )
  i = 0
  while i < static_validation.errors.length() {
    let asset_err = static_validation.errors[i]
    violations.push({
      path: @assets.error_path(asset_err),
      line: None,
      column: None,
      kind: @lint.IOError,
      message: @assets.format_error(asset_err),
    })
    i = i + 1
  }
  { violations, }
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
  "nav a:hover { text-decoration: underline; }\n" +
  "\n" +
  @highlight.css_classes()
}
