///|
/// An authored calendar day, never a filesystem or build timestamp.
fn authored_updated(fm : @frontmatter.Frontmatter) -> String? {
  match fm.fields.get("updated") {
    Some(@frontmatter.FDate(value)) | Some(@frontmatter.FStr(value)) =>
      Some(value)
    _ => None
  }
}

///|
fn publication_day(value : String) -> String? {
  if @strutil.is_valid_iso8601_date(value) {
    Some(value)
  } else if @strutil.is_rfc3339_datetime(value) {
    Some(value[0:10].to_owned())
  } else {
    None
  }
}

///|
fn updated_date_errors(
  fm : @frontmatter.Frontmatter,
) -> Array[(String, String)] {
  if !fm.fields.contains("updated") {
    return []
  }
  let updated = match authored_updated(fm) {
    Some(value) if @strutil.is_valid_iso8601_date(value) => value
    _ => return [("updated", "expected an authored date in YYYY-MM-DD format")]
  }
  match extract_date(fm) {
    Some(value) =>
      match publication_day(value) {
        Some(day) if updated < day =>
          [("updated", "must not precede the publication date")]
        Some(_) => []
        None =>
          [
            (
              "date", "must be a valid publication date when updated is supplied",
            ),
          ]
      }
    None =>
      if fm.fields.contains("date") {
        [("date", "must be a valid publication date when updated is supplied")]
      } else {
        []
      }
  }
}

///|
fn backlink_shortcut(count : Int32) -> String {
  "<a data-lattice-backlink-shortcut href=\"#lattice-backlinks\">Backlinks (" +
  count.to_string() +
  ")</a>"
}

///|
fn reader_metadata_html(
  date : String?,
  updated : String?,
  tags : Array[@tags.TagRef],
  backlink_count : Int32,
) -> String {
  let parts : Array[String] = []
  let day = match date {
    Some(value) => publication_day(value)
    None => None
  }
  if day is Some(value) {
    parts.push(
      "<span>Published <time datetime=\"" +
      @strutil.escape_html_attr(date.unwrap()) +
      "\">" +
      value +
      "</time></span>",
    )
  }
  if updated is Some(value) && day != Some(value) {
    parts.push(
      "<span>Updated <time datetime=\"" +
      @strutil.escape_html_attr(value) +
      "\">" +
      @html.escape_html_body(value) +
      "</time></span>",
    )
  }
  if !tags.is_empty() {
    let links = tags.map(fn(tag) {
      @html.anchor(@tags.tag_url(tag.slug), tag.value)
    })
    parts.push(
      "<span class=\"reader-tags\"><span>Tags:</span> " +
      links.join(" ") +
      "</span>",
    )
  }
  if backlink_count > 0 {
    parts.push(backlink_shortcut(backlink_count))
  }
  if parts.is_empty() {
    ""
  } else {
    "<div class=\"reader-metadata\">" + parts.join("\n") + "</div>"
  }
}

///|
/// Bind only our rendered backlink section, avoiding authored/template IDs.
/// If a custom template omits or repeats it, omit the shortcut instead.
fn bind_backlink_shortcut(html : String, count : Int32) -> String {
  if count <= 0 {
    return html
  }
  let marker = "<section class=\"backlinks\" data-lattice-backlinks>"
  let link = backlink_shortcut(count)
  if html.split(marker).count() != 2 {
    return html
      .replace_all(old=link, new="")
      .replace_all(old="<div class=\"reader-metadata\"></div>", new="")
  }
  let ids = published_html_fragments(html)
  let mut id = "lattice-backlinks"
  let mut suffix = 2
  while ids.contains(id) {
    id = "lattice-backlinks-" + suffix.to_string()
    suffix = suffix + 1
  }
  html
  .replace_all(
    old=marker,
    new="<section class=\"backlinks\" id=\"" + id + "\" tabindex=\"-1\">",
  )
  .replace_all(
    old=link,
    new="<a href=\"#" + id + "\">Backlinks (" + count.to_string() + ")</a>",
  )
}

///|
fn backlink_count_for(
  index : Map[String, Array[BacklinkRef]],
  slug : String,
) -> Int32 {
  index.get(slug).map(fn(refs) { refs.length() }).unwrap_or(0)
}
