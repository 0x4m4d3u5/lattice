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

pub(all) struct BuildResult {
  errors : Int
  rebuilt_pages : Int
  unchanged_pages : Int
}

priv struct CollectionSources {
  definition : @collections.CollectionDef
  sources : Array[SourceFile]
}

priv struct CollectionRenderResult {
  name : String
  pages : Array[@graph.GraphPage]
}

priv struct BuildTemplates {
  page : @template.Template?
  index : @template.Template?
  tag_page : @template.Template?
  tag_index : @template.Template?
}

priv struct TemplateLoadResult {
  templates : BuildTemplates
  violations : Array[@lint.LintViolation]
}

priv struct TagCatalog {
  ordered_slugs : Array[String]
  name_by_slug : Map[String, String]
}

priv struct ProjectLayout {
  collections : Array[@collections.CollectionDef]
  data_schemas : Map[String, @data.DataSchema]
}

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
    let target = raw_links[i].target
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
  page_index : Map[String, String]
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
        let target = raw_links[k].target
        if page_index.contains(target) {
          let ref_entry : BacklinkRef = {
            url: source_url,
            title: source_title,
          }
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
/// A document that passed frontmatter/schema/wikilink validation.
priv struct ProcessedDocument {
  html : String
  title : String
  url : String
  description : String?
  date : String?
  excerpt : String
  resolved_links : Array[@wikilink.ResolvedWikilink]
  tags : Array[@tags.TagRef]
}

///|
fn char_at_builder(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

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

fn template_error_text(e : @template.TemplateError) -> String {
  match e {
    @template.UnknownSlot(name) => "unknown slot '" + name + "'"
    @template.MissingRequiredSlot(slot) => "missing required slot '" + slot.to_string() + "'"
    @template.MissingDataSlot(path) => "missing data slot '" + path + "'"
    @template.ParseError(msg) => msg
  }
}

fn templates_dir_for_build(config : BuildConfig) -> String {
  match config.site.templates_dir {
    Some(path) => path
    None => config.content_dir + "/templates"
  }
}

fn load_template_file(path : String) -> Result[@template.Template?, String] {
  if not(@fs.path_exists(path)) {
    return Ok(None)
  }
  let source = try {
    @fs.read_file_to_string(path)
  } catch {
    @fs.IOError(msg) => return Err("cannot read template " + path + ": " + msg)
  }
  match @template.parse_template(source) {
    Ok(parsed) => Ok(Some(parsed))
    Err(e) => Err("invalid template " + path + ": " + template_error_text(e))
  }
}

fn load_templates(config : BuildConfig) -> Result[BuildTemplates, String] {
  let base = templates_dir_for_build(config)
  if not(@fs.path_exists(base)) {
    return Ok({ page: None, index: None, tag_page: None, tag_index: None })
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
  Ok({ page, index, tag_page, tag_index })
}

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

fn frontmatter_field_line(source : String, field : String) -> Int? {
  let header = field + " ="
  let (line, _) = line_col_of_first(source, header)
  line
}

fn frontmatter_line_from_error(msg : String) -> Int? {
  if not(starts_with_builder(msg, "line ")) {
    return None
  }
  let n = msg.length()
  let mut i = 5
  let mut end = i
  while end < n && char_at_builder(msg, end) >= '0' && char_at_builder(msg, end) <= '9' {
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

fn template_violation(path : String, message : String) -> @lint.LintViolation {
  {
    path,
    line: None,
    column: None,
    kind: @lint.TemplateSlotError,
    message,
  }
}

fn load_templates_for_lint(config : BuildConfig) -> TemplateLoadResult {
  let violations : Array[@lint.LintViolation] = []
  let base = templates_dir_for_build(config)
  if not(@fs.path_exists(base)) {
    return {
      templates: { page: None, index: None, tag_page: None, tag_index: None },
      violations,
    }
  }

  let mut page : @template.Template? = None
  let mut index : @template.Template? = None
  let mut tag_page : @template.Template? = None
  let mut tag_index : @template.Template? = None

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
  {
    templates: { page, index, tag_page, tag_index },
    violations,
  }
}

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
  tag_count : String
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
  slots
}

fn collection_page_url(collection_name : String, slug : String) -> String {
  "/" + collection_name + "/" + slug + "/"
}

fn collection_index_url(collection_name : String) -> String {
  "/" + collection_name + "/"
}

fn collection_index_page_url(collection_name : String, page_number : Int) -> String {
  if page_number <= 1 {
    return collection_index_url(collection_name)
  }
  "/" + collection_name + "/page/" + page_number.to_string() + "/"
}

fn tags_index_page_url(page_number : Int) -> String {
  if page_number <= 1 {
    return "/tags/"
  }
  "/tags/page/" + page_number.to_string() + "/"
}

fn tag_page_url(slug : String, page_number : Int) -> String {
  if page_number <= 1 {
    return @tags.tag_url(slug)
  }
  "/tags/" + slug + "/page/" + page_number.to_string() + "/"
}

fn build_nav_links_html(collections : Array[@collections.CollectionDef]) -> String {
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

fn tags_field_name(site : @config.SiteConfig) -> String {
  match site.tags_field {
    Some(name) => name
    None => "tags"
  }
}

fn search_index_file_name(site : @config.SiteConfig) -> String {
  match site.search_index_file {
    Some(path) => path
    None => "search-index.json"
  }
}

fn static_dir_name(site : @config.SiteConfig) -> String {
  match site.static_dir {
    Some(path) => path
    None => "static"
  }
}

fn data_dir_for_build(config : BuildConfig) -> String {
  match config.site.data_dir {
    Some(path) => path
    None => config.content_dir + "/data"
  }
}

fn data_error_text(err : @data.DataError) -> String {
  @data.format_error(err)
}

fn page_size_for_site(site : @config.SiteConfig) -> Int {
  match site.page_size {
    Some(size) => size
    None => 10
  }
}

fn asset_error_text(err : @assets.AssetCopyError) -> String {
  @assets.format_error(err)
}

fn render_pagination_nav(
  page_number : Int,
  total_pages : Int,
  prev_url : String?,
  next_url : String?
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
    Some(url) => nav.write_string("<li>" + @html.anchor(url, "Previous") + "</li>\n")
    None => nav.write_string("<li><span>Previous</span></li>\n")
  }
  match next_url {
    Some(url) => nav.write_string("<li>" + @html.anchor(url, "Next") + "</li>\n")
    None => nav.write_string("<li><span>Next</span></li>\n")
  }
  nav.write_string("</ul>\n</nav>\n")
  nav.to_string()
}

fn inject_nav_before_main_close(body : String, nav : String) -> String {
  if nav.length() == 0 {
    return body
  }
  let close_tag = "</main>\n"
  if body.has_suffix(close_tag) {
    let without_close = substr_builder(body, 0, body.length() - close_tag.length())
    return without_close + nav + close_tag
  }
  body + nav
}

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

fn is_blank_builder(s : String) -> Bool {
  trim_builder(s).length() == 0
}

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

fn count_leading_hashes_builder(line : String) -> Int {
  let n = line.length()
  let mut count = 0
  while count < n && char_at_builder(line, count) == '#' {
    count = count + 1
  }
  count
}

fn is_heading_line_builder(line : String) -> Bool {
  let hashes = count_leading_hashes_builder(line)
  if hashes == 0 || hashes > 6 {
    return false
  }
  hashes < line.length() && char_at_builder(line, hashes) == ' '
}

fn is_hrule_builder(line : String) -> Bool {
  let t = trim_builder(line)
  t == "---" || t == "***" || t == "___"
}

fn is_fence_start_builder(line : String) -> Bool {
  starts_with_at_builder(line, 0, "```") || starts_with_at_builder(line, 0, "~~~")
}

fn fence_char_builder(line : String) -> Char {
  if line.length() == 0 {
    '`'
  } else {
    char_at_builder(line, 0)
  }
}

fn is_fence_end_builder(line : String, fence_char : Char) -> Bool {
  line.length() >= 3 &&
  char_at_builder(line, 0) == fence_char &&
  char_at_builder(line, 1) == fence_char &&
  char_at_builder(line, 2) == fence_char
}

fn is_unordered_item_builder(line : String) -> Bool {
  line.length() >= 2 &&
  (char_at_builder(line, 0) == '-' || char_at_builder(line, 0) == '*') &&
  char_at_builder(line, 1) == ' '
}

fn is_digit_builder(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

fn is_ordered_item_builder(line : String) -> Bool {
  let n = line.length()
  if n < 3 {
    return false
  }
  let mut i = 0
  while i < n && is_digit_builder(char_at_builder(line, i)) {
    i = i + 1
  }
  i > 0 && i + 1 < n && char_at_builder(line, i) == '.' && char_at_builder(line, i + 1) == ' '
}

fn is_blockquote_line_builder(line : String) -> Bool {
  line.length() > 0 && char_at_builder(line, 0) == '>'
}

fn is_block_starter_builder(line : String) -> Bool {
  is_heading_line_builder(line) ||
  is_hrule_builder(line) ||
  is_fence_start_builder(line) ||
  is_unordered_item_builder(line) ||
  is_ordered_item_builder(line) ||
  is_blockquote_line_builder(line)
}

fn inline_text_builder(inline : @markdown.Inline) -> String {
  match inline {
    @markdown.Text(t) => t
    @markdown.Bold(inlines) => inlines_text_builder(inlines)
    @markdown.Italic(inlines) => inlines_text_builder(inlines)
    @markdown.BoldItalic(inlines) => inlines_text_builder(inlines)
    @markdown.InlineCode(text) => text
    @markdown.Link(text, _) => text
    @markdown.WikiRef(target, display) => match display {
      Some(text) => text
      None => target
    }
    @markdown.Shortcode(call) => call.name
    @markdown.HardBreak => " "
  }
}

fn inlines_text_builder(inlines : Array[@markdown.Inline]) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  while i < inlines.length() {
    buf.write_string(inline_text_builder(inlines[i]))
    i = i + 1
  }
  buf.to_string()
}

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
        while i < lines.length() && not(is_fence_end_builder(lines[i], fence_char)) {
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
      let inlines = @markdown.parse_inlines(paragraph_text, 0, paragraph_text.length())
      let plain_text = collapse_whitespace_builder(inlines_text_builder(inlines))
      if plain_text.length() > 0 {
        return plain_text
      }
    }
  }
  ""
}

fn collect_tag_catalog(collection_sources : Array[CollectionSources], tags_field : String) -> TagCatalog {
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

fn render_tag_page_html(
  page : @tags.TagPage,
  pagination : @pagination.PaginatedIndex[@tags.TaggedPage],
  site : @config.SiteConfig,
  tag_template : @template.Template?,
  fallback_template : @template.Template?,
  nav_links_html : String,
  custom_css : String,
  data_store : @data.DataStore
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
  let full_title = page_title_builder("tag: " + page.tag + title_suffix, site.title)
  let description = "Pages tagged with '" + page.tag + "' in " + site.title + "."
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
      match @template.render_template_with_data(tpl, slots, data_store) {
        Ok(html) => Ok(html)
        Err(e) => Err("tag page template: " + template_error_text(e))
      }
    }
    None => {
      let meta : @html.PageMeta = {
        title: full_title,
        description: Some(description),
        lang: "en",
        stylesheet: Some(absolute_url_builder(site.base_url, "/style.css")),
      }
      Ok(@html.render_page(meta, body))
    }
  }
}

fn render_tags_index_html(
  index : @tags.TagIndex,
  pagination : @pagination.PaginatedIndex[@tags.TagSummary],
  site : @config.SiteConfig,
  index_template : @template.Template?,
  fallback_template : @template.Template?,
  nav_links_html : String,
  custom_css : String,
  data_store : @data.DataStore
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
      match @template.render_template_with_data(tpl, slots, data_store) {
        Ok(html) => Ok(html)
        Err(e) => Err("tags index template: " + template_error_text(e))
      }
    }
    None => {
      let meta : @html.PageMeta = {
        title: full_title,
        description: Some(description),
        lang: "en",
        stylesheet: Some(absolute_url_builder(site.base_url, "/style.css")),
      }
      Ok(@html.render_page(meta, body))
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
  data_store : @data.DataStore
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
  let full_title = page_title_builder(collection_name + " index" + title_suffix, site.title)
  let description =
    "Generated page graph for collection " + collection_name + " in " + site.title + "."
  let page_url = collection_index_page_url(collection_name, pagination.page_number)

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
      match @template.render_template_with_data(tpl, slots, data_store) {
        Ok(html) => return Ok(html)
        Err(e) => return Err("collection index template: " + template_error_text(e))
      }
    }
    None => ()
  }

  let meta : @html.PageMeta = {
    title: full_title,
    description: Some(description),
    lang: "en",
    stylesheet: Some(absolute_url_builder(site.base_url, "/style.css")),
  }
  Ok(@html.render_page(meta, body.to_string()))
}

fn build_data_schema_map(
  schema_defs : Array[@collections.DataSchemaDef]
) -> Map[String, @data.DataSchema] {
  let data_schemas : Map[String, @data.DataSchema] = Map::new()
  let mut i = 0
  while i < schema_defs.length() {
    let schema = schema_defs[i]
    data_schemas.set(schema.name, @data.new_schema(schema.name, schema.required_keys))
    i = i + 1
  }
  data_schemas
}

fn load_project_layout(config : BuildConfig) -> Result[ProjectLayout, String] {
  match config.collections_path {
    None => {
      Ok({
        collections: [@collections.default_posts_collection(config.content_dir)],
        data_schemas: Map::new(),
      })
    }
    Some(path) => {
      let source = try {
        @fs.read_file_to_string(path)
      } catch {
        @fs.IOError(msg) => return Err("cannot read collections file " + path + ": " + msg)
      }
      match @collections.parse(source) {
        Ok(parsed) => {
          Ok({
            collections: parsed.definitions,
            data_schemas: build_data_schema_map(parsed.data_schema_list),
          })
        }
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
        Err(@collections.DuplicateDataSchema(name)) => {
          Err(path + ": duplicate data schema '" + name + "'")
        }
        Err(@collections.InvalidSchema(name, msg)) => {
          Err(path + ": invalid schema for collection '" + name + "': " + msg)
        }
        Err(@collections.EmptyConfig) => Err(path + ": no collections defined")
      }
    }
  }
}

fn load_data_store(config : BuildConfig, data_schemas : Map[String, @data.DataSchema]) -> Result[@data.DataStore, String] {
  let data_dir = data_dir_for_build(config)
  match @data.load_from_dir(data_dir, data_schemas) {
    Ok(store) => Ok(store)
    Err(err) => Err(data_error_text(err))
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
  known_tags : Map[String, String],
  tags_field : String,
  schema : @schema.Schema,
  site : @config.SiteConfig,
  data_store : @data.DataStore,
  page_template : @template.Template?,
  nav_links_html : String,
  custom_css : String,
  backlinks_html : String,
  render_page_html : Bool
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
  // Step 2b: extract validated tags from typed frontmatter.
  let page_tags = match @tags.extract(fm, tags_field) {
    Ok(values) => values
    Err(msg) => {
      println(
        "[error] " + context + ": tags field '" + tags_field + "': " + msg,
      )
      return None
    }
  }
  let mut i = 0
  while i < page_tags.length() {
    let tag = page_tags[i]
    if not(known_tags.contains(tag.slug)) {
      println(
        "[error] " +
        context +
        ": dangling tag reference '" +
        tag.value +
        "' (" +
        tag.slug +
        ") missing from tag index",
      )
      return None
    }
    i = i + 1
  }
  // Step 3: extract wikilinks; resolve against page index
  let raw_links = @wikilink.extract(fm.body, slug)
  let (resolved, link_errors) = @wikilink.resolve(raw_links, page_index)
  if link_errors.length() > 0 {
    let mut i = 0
    while i < link_errors.length() {
      println(
        "[warn] " +
        context +
        ": unresolved wikilink [[" +
        link_errors[i].link.target +
        "]] rendered as plain text",
      )
      i = i + 1
    }
  }
  // Step 4: build wikilink map for the renderer
  let excerpt = extract_excerpt_builder(fm.body)
  let title = extract_title(fm)
  let description_value = extract_description(fm)
  let date_value = extract_date(fm)
  if not(render_page_html) {
    return Some({
      html: "",
      title,
      url,
      description: description_value,
      date: date_value,
      excerpt,
      resolved_links: resolved,
      tags: page_tags,
    })
  }
  let wl_map = build_wikilink_map(resolved)
  // Step 5: render markdown body to HTML fragment
  let markdown_result = @markdown.render_with_diagnostics(fm.body, wl_map)
  if markdown_result.shortcode_errors.length() > 0 {
    let mut si = 0
    while si < markdown_result.shortcode_errors.length() {
      println(
        "[error] " +
        context +
        ": shortcode: " +
        @shortcode.error_text(markdown_result.shortcode_errors[si].error),
      )
      si = si + 1
    }
    return None
  }
  let body_html = markdown_result.html + @tags.render_page_tags(page_tags)
  // Step 6: emit the complete HTML5 page
  let full_title = page_title_builder(title, site.title)
  let description_text = match description_value {
    Some(v) => v
    None => ""
  }
  let date_text = match date_value {
    Some(v) => v
    None => ""
  }

  let page_html = match page_template {
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
      match @template.render_template_with_data(tpl, slots, data_store) {
        Ok(html) => html
        Err(e) => {
          println("[error] " + context + ": page template: " + template_error_text(e))
          return None
        }
      }
    }
    None => {
      let meta : @html.PageMeta = {
        title: full_title,
        description: description_value,
        lang: "en",
        stylesheet: Some(absolute_url_builder(site.base_url, "/style.css")),
      }
      let page_body = if backlinks_html.length() > 0 {
        body_html + backlinks_html
      } else {
        body_html
      }
      @html.render_page(meta, page_body)
    }
  }
  Some({
    html: page_html,
    title,
    url,
    description: description_value,
    date: date_value,
    excerpt,
    resolved_links: resolved,
    tags: page_tags,
  })
}

priv struct LintDocOutcome {
  document : ProcessedDocument?
  violations : Array[@lint.LintViolation]
}

fn process_document_for_lint(
  source : String,
  source_path : String,
  slug : String,
  url : String,
  page_index : Map[String, String],
  known_tags : Map[String, String],
  tags_field : String,
  schema : @schema.Schema,
  site : @config.SiteConfig,
  data_store : @data.DataStore,
  page_template : @template.Template?,
  nav_links_html : String,
  custom_css : String,
  backlinks_html : String
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
        message:
          "dangling tag reference '" +
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
      message: "[[" + link_errors[i].link.target + "]]: " + link_errors[i].message,
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
  let excerpt = extract_excerpt_builder(fm.body)
  let title = extract_title(fm)
  let full_title = page_title_builder(title, site.title)
  let description_value = extract_description(fm)
  let date_value = extract_date(fm)
  let description_text = match description_value {
    Some(v) => v
    None => ""
  }
  let date_text = match date_value {
    Some(v) => v
    None => ""
  }

  let page_html = match page_template {
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
      match @template.render_template_with_data(tpl, slots, data_store) {
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
      let meta : @html.PageMeta = {
        title: full_title,
        description: description_value,
        lang: "en",
        stylesheet: Some(absolute_url_builder(site.base_url, "/style.css")),
      }
      let page_body = if backlinks_html.length() > 0 {
        body_html + backlinks_html
      } else {
        body_html
      }
      @html.render_page(meta, page_body)
    }
  }
  {
    document: Some({
      html: page_html,
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

fn manifest_path_for_build(config : BuildConfig) -> String {
  config.output_dir + "/.lattice-manifest.json"
}

fn page_output_path(config : BuildConfig, collection_name : String, slug : String) -> String {
  config.output_dir + "/" + collection_name + "/" + slug + "/index.html"
}

fn dependency_roots_for_build(config : BuildConfig) -> Array[String] {
  let roots : Array[String] = [config.config_path]
  match config.collections_path {
    Some(path) => roots.push(path)
    None => ()
  }
  roots.push(templates_dir_for_build(config))
  roots.push(data_dir_for_build(config))
  roots
}

fn load_manifest(config : BuildConfig) -> @manifest.ManifestFile? {
  let path = manifest_path_for_build(config)
  if not(@fs.path_exists(path)) {
    return None
  }
  let source = try {
    @fs.read_file_to_string(path)
  } catch {
    @fs.IOError(msg) => {
      println("[warn] incremental manifest read failed: " + msg)
      return None
    }
  }
  try {
    Some(@manifest.parse(source))
  } catch {
    @manifest.ParseError(msg) => {
      println("[warn] incremental manifest parse failed: " + msg)
      None
    }
  }
}

fn dependency_manifest_entries(
  config : BuildConfig
) -> Result[Array[@manifest.ManifestEntry], String] {
  let snapshot = try {
    @watch.take_snapshot(dependency_roots_for_build(config))
  } catch {
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

fn build_incremental_state(
  config : BuildConfig,
  collection_sources : Array[CollectionSources]
) -> IncrementalState {
  let previous_entries : Map[String, @manifest.ManifestEntry] = Map::new()
  let changed_sources : Map[String, Bool] = Map::new()
  if config.force_rebuild {
    return { force_full_rebuild: true, previous_entries, changed_sources }
  }

  let manifest = match load_manifest(config) {
    Some(file) => file
    None => return { force_full_rebuild: true, previous_entries, changed_sources }
  }

  let mut i = 0
  while i < manifest.entries.length() {
    previous_entries.set(manifest.entries[i].src, manifest.entries[i])
    i = i + 1
  }

  let dependency_entries = match dependency_manifest_entries(config) {
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
      Some(previous) => {
        if previous.mtime != entry.mtime || previous.out != "" {
          return { force_full_rebuild: true, previous_entries, changed_sources }
        }
      }
      None => return { force_full_rebuild: true, previous_entries, changed_sources }
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
      let changed = match previous_entries.get(src.path) {
        Some(previous) => previous.mtime != src.stamp || previous.out != out || not(@fs.path_exists(out))
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

fn source_manifest_entries(
  config : BuildConfig,
  collection_sources : Array[CollectionSources]
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

fn write_manifest(
  config : BuildConfig,
  collection_sources : Array[CollectionSources]
) -> Result[Unit, String] {
  let dependency_entries = match dependency_manifest_entries(config) {
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

fn mark_backlink_targets_changed(
  incremental : IncrementalState,
  collection_sources : Array[CollectionSources]
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
pub fn build(config : BuildConfig, cache_store : @cache.CacheStore) -> BuildResult {
  println("[lattice] building " + config.content_dir + " → " + config.output_dir)

  let layout = match load_project_layout(config) {
    Ok(parsed) => parsed
    Err(msg) => {
      println("[error] collections: " + msg)
      return { errors: 1, rebuilt_pages: 0, unchanged_pages: 0 }
    }
  }
  let collections = layout.collections
  println("[lattice] using " + collections.length().to_string() + " collections")
  let templates = match load_templates(config) {
    Ok(t) => t
    Err(msg) => {
      println("[error] templates: " + msg)
      return { errors: 1, rebuilt_pages: 0, unchanged_pages: 0 }
    }
  }
  let nav_links_html = build_nav_links_html(collections)
  let custom_css = default_css()
  let data_store = match load_data_store(config, layout.data_schemas) {
    Ok(store) => store
    Err(msg) => {
      println("[error] data: " + msg)
      return { errors: 1, rebuilt_pages: 0, unchanged_pages: 0 }
    }
  }
  println("[lattice] loaded data files from " + data_dir_for_build(config))

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
        return { errors: 1, rebuilt_pages: 0, unchanged_pages: 0 }
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
          return { errors: 1, rebuilt_pages: 0, unchanged_pages: 0 }
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

  let tags_field = tags_field_name(config.site)
  let tag_catalog = collect_tag_catalog(collection_sources, tags_field)
  let known_tags = tag_catalog.name_by_slug
  let page_size = page_size_for_site(config.site)
  let backlink_index = build_backlink_index(collection_sources, page_index)
  let incremental = build_incremental_state(config, collection_sources)
  let backlink_affected = mark_backlink_targets_changed(incremental, collection_sources)
  let next_cache_store = @cache.empty(config.output_dir)

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
    return { errors: 1, rebuilt_pages: 0, unchanged_pages: 0 }
  }

  // Write default CSS (once, if not already present)
  let css_path = config.output_dir + "/style.css"
  if not(@fs.path_exists(css_path)) {
    let write_ok = try {
      @fs.write_string_to_file(css_path, custom_css)
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
  let mut rebuilt = 0
  let mut unchanged = 0
  let graph_pages : Array[@graph.GraphPage] = []
  let search_entries : Array[@search.SearchEntry] = []
  let tag_pages_by_slug : Map[String, Array[@tags.TaggedPage]] = Map::new()
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
      let out_path = page_output_path(config, coll.definition.name, src.slug)
      let cache_hit = @cache.should_skip(
        cache_store,
        src.slug,
        src.fingerprint,
        out_path,
        config.force_rebuild,
      )
      let should_rebuild =
        incremental.force_full_rebuild ||
        incremental.changed_sources.contains(src.path) ||
        backlink_affected.contains(src.slug) ||
        not(cache_hit)
      let page_backlinks_html = match backlink_index.get(src.slug) {
        Some(refs) => render_backlinks_html(refs)
        None => ""
      }
      match process_document(
        src.content,
        src.slug,
        page_url,
        page_context,
        page_index,
        known_tags,
        tags_field,
        coll.definition.schema,
        config.site,
        data_store,
        templates.page,
        nav_links_html,
        custom_css,
        page_backlinks_html,
        should_rebuild,
      ) {
        None => {
          error_count = error_count + 1
        }
        Some(doc) => {
          let write_result = if should_rebuild {
            let page_dir = collection_root + "/" + src.slug
            try {
              ensure_dir(page_dir)
              @fs.write_string_to_file(out_path, doc.html)
              Some(out_path)
            } catch {
              @fs.IOError(msg) => {
                println("[error] " + page_context + ": write failed: " + msg)
                None
              }
            }
          } else {
            Some(out_path)
          }
          match write_result {
            Some(_) => {
              if should_rebuild {
                println("[build] " + page_context)
                rebuilt = rebuilt + 1
              } else {
                println("[skip] " + page_context)
                unchanged = unchanged + 1
              }
              @cache.remember(next_cache_store, src.slug, src.fingerprint)
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
                    existing.push({ title: doc.title, url: doc.url, slug: src.slug })
                    tag_pages_by_slug.set(tag.slug, existing)
                  }
                  None => {
                    tag_pages_by_slug.set(
                      tag.slug,
                      [{ title: doc.title, url: doc.url, slug: src.slug }],
                    )
                  }
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

      let paginated_index_pages = @pagination.paginate(
        coll.pages,
        page_size,
        fn(page_number) { collection_index_page_url(coll.name, page_number) },
      )
      let mut page_idx = 0
      while page_idx < paginated_index_pages.length() {
        let pagination = paginated_index_pages[page_idx]
        let index_html = match render_collection_index(
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
            println("[error] " + coll.name + " index page " + pagination.page_number.to_string() + ": " + msg)
            None
          }
        }
        let index_write_ok = match index_html {
          Some(html) => {
            try {
              let out_path = if pagination.page_number == 1 {
                coll_dir + "/index.html"
              } else {
                coll_dir + "/page/" + pagination.page_number.to_string() + "/index.html"
              }
              ensure_parent_dirs_for_file(out_path)
              @fs.write_string_to_file(out_path, html)
              println("[lattice] wrote " + out_path)
              true
            } catch {
              @fs.IOError(msg) => {
                println(
                  "[error] " +
                  coll.name +
                  " index page " +
                  pagination.page_number.to_string() +
                  ": write failed: " +
                  msg,
                )
                false
              }
            }
          }
          None => false
        }
        if not(index_write_ok) {
          error_count = error_count + 1
        }
        page_idx = page_idx + 1
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
          println("[error] tags: cannot create output directory " + tags_root + ": " + msg)
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
              println("[error] tags/" + tag_slug + ": cannot create directory: " + msg)
              false
            }
          }
          if tag_dir_ok {
            let paginated_tag_pages = @pagination.paginate(
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
              let tag_html = match render_tag_page_html(
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
                  println(
                    "[error] tags/" +
                    tag_slug +
                    " page " +
                    pagination.page_number.to_string() +
                    ": " +
                    msg,
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
                      tag_dir + "/page/" + pagination.page_number.to_string() + "/index.html"
                    }
                    ensure_parent_dirs_for_file(out_path)
                    @fs.write_string_to_file(out_path, html)
                    println("[lattice] wrote " + out_path)
                    true
                  } catch {
                    @fs.IOError(msg) => {
                      println(
                        "[error] tags/" +
                        tag_slug +
                        " page " +
                        pagination.page_number.to_string() +
                        ": write failed: " +
                        msg,
                      )
                      false
                    }
                  }
                  if not(tag_write_ok) {
                    error_count = error_count + 1
                  }
                }
                None => {
                  error_count = error_count + 1
                }
              }
              page_idx = page_idx + 1
            }
          } else {
            error_count = error_count + 1
          }
          tag_summaries.push({ tag: tag_name, slug: tag_slug, count: pages.length() })
          i = i + 1
        }

        if error_count == 0 {
          let paginated_tags_index = @pagination.paginate(
            tag_summaries,
            page_size,
            fn(page_number) { tags_index_page_url(page_number) },
          )
          let mut page_idx = 0
          while page_idx < paginated_tags_index.length() {
            let pagination = paginated_tags_index[page_idx]
            let tags_index : @tags.TagIndex = { tags: pagination.documents }
            let tags_index_html = match render_tags_index_html(
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
                println(
                  "[error] tags index page " + pagination.page_number.to_string() + ": " + msg,
                )
                None
              }
            }
            let tags_index_ok = match tags_index_html {
              Some(html) => {
                try {
                  let out_path = if pagination.page_number == 1 {
                    tags_root + "/index.html"
                  } else {
                    tags_root + "/page/" + pagination.page_number.to_string() + "/index.html"
                  }
                  ensure_parent_dirs_for_file(out_path)
                  @fs.write_string_to_file(out_path, html)
                  println("[lattice] wrote " + out_path)
                  true
                } catch {
                  @fs.IOError(msg) => {
                    println(
                      "[error] tags index page " +
                      pagination.page_number.to_string() +
                      ": write failed: " +
                      msg,
                    )
                    false
                  }
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
    if error_count == 0 {
      let search_write_ok = try {
        let search_json = @search.render_search_index(search_entries)
        let out_path = config.output_dir + "/" + search_index_file_name(config.site)
        ensure_parent_dirs_for_file(out_path)
        @fs.write_string_to_file(out_path, search_json)
        println("[lattice] wrote " + out_path)
        true
      } catch {
        @fs.IOError(msg) => {
          println("[error] search index: write failed: " + msg)
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
          println("[error] graph.json: write failed: " + msg)
          false
        }
      }
      if not(graph_write_ok) {
        error_count = error_count + 1
      }
    }
    if error_count == 0 {
      match @assets.copy_static(
        config.content_dir,
        config.output_dir,
        static_dir_name(config.site),
      ) {
        Ok(copied) => {
          if copied > 0 {
            println("[lattice] copied " + copied.to_string() + " static asset files")
          }
        }
        Err(e) => {
          println("[error] static assets: " + asset_error_text(e))
          error_count = error_count + 1
        }
      }
    }
    if error_count == 0 {
      match write_manifest(config, collection_sources) {
        Ok(_) => ()
        Err(msg) => {
          println("[error] manifest: write failed: " + msg)
          error_count = error_count + 1
        }
      }
    }
    if error_count == 0 {
      match @cache.save(next_cache_store) {
        Ok(_) => ()
        Err(err) => {
          println("[error] cache: " + @cache.error_text(err))
          error_count = error_count + 1
        }
      }
    }
  } else {
    println(
      "[warn] skipped collection feeds/indexes, tags, sitemap, and search index generation due to prior build errors",
    )
  }

  println(
    "[lattice] " +
    "rebuilt " +
    rebuilt.to_string() +
    " pages (" +
    unchanged.to_string() +
    " unchanged), " +
    error_count.to_string() +
    " errors",
  )
  { errors: error_count, rebuilt_pages: rebuilt, unchanged_pages: unchanged }
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
  println("[lattice] using " + collections.length().to_string() + " collections")

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
    Err(msg) => {
      violations.push({
        path: data_dir_for_build(config),
        line: None,
        column: None,
        kind: @lint.DataError,
        message: msg,
      })
      @data.empty_store()
    }
  }

  let collection_sources : Array[CollectionSources] = []
  let mut source_count = 0
  i = 0
  while i < collections.length() {
    let collection_def = collections[i]
    let sources = try {
      collect_sources(collection_def.content_dir)
    } catch {
      @fs.IOError(msg) => {
        violations.push({
          path: collection_def.content_dir,
          line: None,
          column: None,
          kind: @lint.IOError,
          message: "cannot read collection directory " + collection_def.name + ": " + msg,
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
        Some(owner) => {
          violations.push({
            path: source.path,
            line: None,
            column: None,
            kind: @lint.DuplicateSlug,
            message:
              "duplicate slug '" +
              source.slug +
              "' in collections '" +
              owner +
              "' and '" +
              coll.definition.name +
              "'",
          })
        }
        None => {
          slug_owner.set(source.slug, coll.definition.name)
          page_index.set(source.slug, collection_page_url(coll.definition.name, source.slug))
        }
      }
      j = j + 1
    }
    i = i + 1
  }

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
    let coll_pages : Array[@graph.GraphPage] = []
    let mut j = 0
    while j < coll.sources.length() {
      let src = coll.sources[j]
      let page_url = collection_page_url(coll.definition.name, src.slug)
      let lint_backlinks_html = match backlink_index.get(src.slug) {
        Some(refs) => render_backlinks_html(refs)
        None => ""
      }
      let lint_outcome = process_document_for_lint(
        src.content,
        src.path,
        src.slug,
        page_url,
        page_index,
        known_tags,
        tags_field,
        coll.definition.schema,
        config.site,
        data_store,
        templates.page,
        nav_links_html,
        custom_css,
        lint_backlinks_html,
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
              None => {
                tag_pages_by_slug.set(
                  tag.slug,
                  [{ title: doc.title, url: doc.url, slug: src.slug }],
                )
              }
            }
            k = k + 1
          }
        }
        None => ()
      }
      j = j + 1
    }
    rendered_collections.push({ name: coll.definition.name, pages: coll_pages })
    i = i + 1
  }

  i = 0
  while i < rendered_collections.length() {
    let coll = rendered_collections[i]
    let feed_title = config.site.title + " (" + coll.name + ")"
    let _feed_xml = @rss.render_feed(feed_title, config.site.base_url, coll.pages)
    let paginated_index_pages = @pagination.paginate(
      coll.pages,
      page_size,
      fn(page_number) { collection_index_page_url(coll.name, page_number) },
    )
    let mut page_idx = 0
    while page_idx < paginated_index_pages.length() {
      let pagination = paginated_index_pages[page_idx]
      match render_collection_index(
        coll.name,
        pagination,
        config.site,
        templates.index,
        nav_links_html,
        custom_css,
        data_store,
      ) {
        Ok(_) => ()
        Err(msg) => {
          violations.push({
            path: templates_dir_for_build(config) + "/index.html",
            line: None,
            column: None,
            kind: @lint.TemplateSlotError,
            message: coll.name + " index page " + pagination.page_number.to_string() + ": " + msg,
          })
        }
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
    let paginated_tag_pages = @pagination.paginate(
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
      match render_tag_page_html(
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
        Err(msg) => {
          violations.push({
            path: templates_dir_for_build(config) + "/tag.html",
            line: None,
            column: None,
            kind: @lint.TemplateSlotError,
            message:
              "tags/" +
              tag_slug +
              " page " +
              pagination.page_number.to_string() +
              ": " +
              msg,
          })
        }
      }
      page_idx = page_idx + 1
    }
    tag_summaries.push({ tag: tag_name, slug: tag_slug, count: pages.length() })
    i = i + 1
  }

  let paginated_tags_index = @pagination.paginate(
    tag_summaries,
    page_size,
    fn(page_number) { tags_index_page_url(page_number) },
  )
  i = 0
  while i < paginated_tags_index.length() {
    let pagination = paginated_tags_index[i]
    let tags_index : @tags.TagIndex = { tags: pagination.documents }
    match render_tags_index_html(
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
      Err(msg) => {
        violations.push({
          path: templates_dir_for_build(config) + "/tags.html",
          line: None,
          column: None,
          kind: @lint.TemplateSlotError,
          message: "tags index page " + pagination.page_number.to_string() + ": " + msg,
        })
      }
    }
    i = i + 1
  }

  let _sitemap_xml = @sitemap.render_sitemap(config.site.base_url, graph_pages)
  let static_validation = @assets.check_static(config.content_dir, static_dir_name(config.site))
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
