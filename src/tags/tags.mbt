///|
/// Typed tag extraction + rendering artifacts.
///
/// Tags are only extracted from typed frontmatter array fields (`Array[String]`)
/// and are normalized to URL slugs.
pub(all) struct TagRef {
  value : String
  slug : String
}

///|
pub(all) struct TaggedPage {
  title : String
  url : String
  slug : String
}

///|
pub(all) struct TagPage {
  tag : String
  slug : String
  pages : Array[TaggedPage]
}

///|
pub(all) struct TagSummary {
  tag : String
  slug : String
  count : Int
}

///|
pub(all) struct TagIndex {
  tags : Array[TagSummary]
}

///|
fn char_at_tags(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

///|
fn trim_tags(s : String) -> String {
  let n = s.length()
  let mut lo = 0
  while lo < n &&
        (
          char_at_tags(s, lo) == ' ' ||
          char_at_tags(s, lo) == '\t' ||
          char_at_tags(s, lo) == '\r' ||
          char_at_tags(s, lo) == '\n'
        ) {
    lo = lo + 1
  }
  let mut hi = n
  while hi > lo &&
        (
          char_at_tags(s, hi - 1) == ' ' ||
          char_at_tags(s, hi - 1) == '\t' ||
          char_at_tags(s, hi - 1) == '\r' ||
          char_at_tags(s, hi - 1) == '\n'
        ) {
    hi = hi - 1
  }
  let buf = StringBuilder::new()
  let mut i = lo
  while i < hi {
    buf.write_char(char_at_tags(s, i))
    i = i + 1
  }
  buf.to_string()
}

///|
fn escape_html_tags(s : String) -> String {
  let buf = StringBuilder::new()
  let n = s.length()
  let mut i = 0
  while i < n {
    let c = char_at_tags(s, i)
    if c == '&' {
      buf.write_string("&amp;")
    } else if c == '<' {
      buf.write_string("&lt;")
    } else if c == '>' {
      buf.write_string("&gt;")
    } else {
      buf.write_char(c)
    }
    i = i + 1
  }
  buf.to_string()
}

///|
pub fn tag_url(slug : String) -> String {
  "/tags/" + slug + "/"
}

///|
/// Extract tags from frontmatter field `tags_field`.
///
/// - Missing field: empty tag list.
/// - Present field must be `Array[String]`.
pub fn extract(
  fm : @frontmatter.Frontmatter,
  tags_field : String,
) -> Result[Array[TagRef], String] {
  match fm.fields.get(tags_field) {
    None => Ok([])
    Some(value) =>
      match value {
        @frontmatter.FArray(items) => {
          let seen : Map[String, Bool] = Map::new()
          let tags : Array[TagRef] = []
          let mut i = 0
          while i < items.length() {
            match items[i] {
              @frontmatter.FStr(raw) => {
                let tag_value = trim_tags(raw)
                if tag_value.length() > 0 {
                  let tag_slug = @slug.filename_to_slug(tag_value)
                  if not(seen.contains(tag_slug)) {
                    seen.set(tag_slug, true)
                    tags.push({ value: tag_value, slug: tag_slug })
                  }
                }
              }
              _ =>
                return Err("expected Array[String], found non-string element")
            }
            i = i + 1
          }
          Ok(tags)
        }
        _ => Err("expected Array[String]")
      }
  }
}

///|
pub fn render_page_tags(tags : Array[TagRef]) -> String {
  if tags.length() == 0 {
    return ""
  }
  let out = StringBuilder::new()
  out.write_string("<section>\n<h2>Tags</h2>\n<ul>\n")
  let mut i = 0
  while i < tags.length() {
    let tag = tags[i]
    out.write_string("<li>")
    out.write_string(@html.anchor(tag_url(tag.slug), tag.value))
    out.write_string("</li>\n")
    i = i + 1
  }
  out.write_string("</ul>\n</section>\n")
  out.to_string()
}

///|
pub fn render_tag_page(page : TagPage) -> String {
  let out = StringBuilder::new()
  out.write_string("<main>\n")
  out.write_string("<h1>Tag: ")
  out.write_string(escape_html_tags(page.tag))
  out.write_string("</h1>\n")
  out.write_string("<p>")
  out.write_string(page.pages.length().to_string())
  out.write_string(" page(s)</p>\n")
  out.write_string("<ul>\n")
  let mut i = 0
  while i < page.pages.length() {
    let p = page.pages[i]
    out.write_string("<li>")
    out.write_string(@html.anchor(p.url, p.title))
    out.write_string(" <code>")
    out.write_string(escape_html_tags(p.slug))
    out.write_string("</code></li>\n")
    i = i + 1
  }
  out.write_string("</ul>\n</main>\n")
  out.to_string()
}

///|
pub fn render_tag_index(index : TagIndex) -> String {
  let out = StringBuilder::new()
  out.write_string("<main>\n")
  out.write_string("<h1>Tags</h1>\n")
  if index.tags.length() == 0 {
    out.write_string("<p>No tags found.</p>\n")
    out.write_string("</main>\n")
    return out.to_string()
  }
  out.write_string("<ul>\n")
  let mut i = 0
  while i < index.tags.length() {
    let t = index.tags[i]
    out.write_string("<li>")
    out.write_string(@html.anchor(tag_url(t.slug), t.tag))
    out.write_string(" (")
    out.write_string(t.count.to_string())
    out.write_string(")</li>\n")
    i = i + 1
  }
  out.write_string("</ul>\n")
  out.write_string("</main>\n")
  out.to_string()
}
