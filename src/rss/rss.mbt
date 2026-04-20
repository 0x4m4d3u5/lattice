///|
/// Atom 1.0 feed rendering for lattice.
///
/// The renderer is pure: it accepts typed page graph input and returns XML.
/// No file I/O happens in this module.

///|
/// A single feed entry.
///
/// Structural decision: feed entries are first represented as a typed struct
/// rather than assembled directly as string templates. This keeps optional
/// fields explicit in the type system (`String?`) and avoids sentinel values.
pub(all) struct FeedItem {
  title : String
  id : String
  link : String
  summary : String?
  updated : String?
  published : String?
}

///|
/// A complete Atom feed channel.
pub(all) struct FeedChannel {
  title : String
  id : String
  link : String
  author_name : String
  updated : String?
  items : Array[FeedItem]
}

///|
fn parse_fixed_uint(s : String, start : Int, count : Int) -> Int? {
  if start + count > s.length() {
    return None
  }
  let mut i = 0
  let mut value = 0
  while i < count {
    let c = @strutil.char_at(s, start + i)
    if !@strutil.is_digit(c) {
      return None
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
    i = i + 1
  }
  Some(value)
}

///|
/// Parse either YYYY-MM-DD or RFC3339-like date; normalize to RFC3339 UTC.
///
/// Accepted forms:
/// - `YYYY-MM-DD` → normalized to `YYYY-MM-DDT00:00:00Z`
/// - `YYYY-MM-DDTHH:MM:SSZ` (RFC 3339 UTC) → accepted as-is
/// - `YYYY-MM-DDTHH:MM:SS±HH:MM` (RFC 3339 with offset) → accepted as-is
///
/// All other forms are rejected. The previous heuristic (prefix "20" + suffix
/// "Z") has been replaced with structural validation.
pub fn normalize_feed_datetime(raw : String?) -> String? {
  match raw {
    None => None
    Some(date_text) => {
      let s = @strutil.trim(date_text)
      if s.length() == 0 {
        return None
      }
      if s.length() == 10 {
        // Plain date: YYYY-MM-DD
        let year = parse_fixed_uint(s, 0, 4)
        let month = parse_fixed_uint(s, 5, 2)
        let day = parse_fixed_uint(s, 8, 2)
        if @strutil.char_at(s, 4) != '-' || @strutil.char_at(s, 7) != '-' {
          return None
        }
        match (year, month, day) {
          (Some(y), Some(m), Some(d)) => {
            if m < 1 || m > 12 {
              return None
            }
            let max_day = @strutil.days_in_month(y, m)
            if d < 1 || d > max_day {
              return None
            }
            return Some(s + "T00:00:00Z")
          }
          _ => None
        }
      } else if is_rfc3339_datetime(s) {
        Some(s)
      } else {
        None
      }
    }
  }
}

///|
/// Structural RFC 3339 datetime validation.
///
/// Checks that `s` matches the pattern `YYYY-MM-DDTHH:MM:SS` followed by
/// either `Z` (UTC) or `±HH:MM` (offset). Every numeric component is
/// verified to contain digits only, and the date portion is validated
/// (month 1–12, day within days-in-month).
fn is_rfc3339_datetime(s : String) -> Bool {
  let n = s.length()
  // Minimum: "2026-01-01T00:00:00Z" = 20 chars
  if n < 20 {
    return false
  }
  // Check date separator positions
  if @strutil.char_at(s, 4) != '-' ||
    @strutil.char_at(s, 7) != '-' ||
    @strutil.char_at(s, 10) != 'T' {
    return false
  }
  // Validate date components
  let year = parse_fixed_uint(s, 0, 4)
  let month = parse_fixed_uint(s, 5, 2)
  let day = parse_fixed_uint(s, 8, 2)
  match (year, month, day) {
    (Some(y), Some(m), Some(d)) => {
      if m < 1 || m > 12 {
        return false
      }
      let max_day = @strutil.days_in_month(y, m)
      if d < 1 || d > max_day {
        return false
      }
    }
    _ => return false
  }
  // Validate time components: HH:MM:SS
  if @strutil.char_at(s, 13) != ':' || @strutil.char_at(s, 16) != ':' {
    return false
  }
  let hour = parse_fixed_uint(s, 11, 2)
  let minute = parse_fixed_uint(s, 14, 2)
  let second = parse_fixed_uint(s, 17, 2)
  match (hour, minute, second) {
    (Some(h), Some(min_), Some(sec)) => {
      if h > 23 || min_ > 59 || sec > 59 {
        return false
      }
    }
    _ => return false
  }
  // Check timezone: either Z or ±HH:MM
  if n == 20 {
    @strutil.char_at(s, 19) == 'Z'
  } else if n == 25 {
    let sign = @strutil.char_at(s, 19)
    if sign != '+' && sign != '-' {
      return false
    }
    if @strutil.char_at(s, 22) != ':' {
      return false
    }
    let tz_h = parse_fixed_uint(s, 20, 2)
    let tz_m = parse_fixed_uint(s, 23, 2)
    match (tz_h, tz_m) {
      (Some(th), Some(tm)) => th <= 23 && tm <= 59
      _ => false
    }
  } else {
    false
  }
}

///|
fn compare_iso_desc(a : String?, b : String?) -> Int {
  match (a, b) {
    (Some(av), Some(bv)) => if av == bv { 0 } else if av > bv { -1 } else { 1 }
    (Some(_), None) => -1
    (None, Some(_)) => 1
    (None, None) => 0
  }
}

///|
fn compare_pages(a : @graph.GraphPage, b : @graph.GraphPage) -> Int {
  let ad = normalize_feed_datetime(a.date)
  let bd = normalize_feed_datetime(b.date)
  let by_date = compare_iso_desc(ad, bd)
  if by_date != 0 {
    return by_date
  }
  if a.title == b.title {
    0
  } else if a.title < b.title {
    -1
  } else {
    1
  }
}

///|
fn sort_pages_for_feed(
  pages : Array[@graph.GraphPage],
) -> Array[@graph.GraphPage] {
  let sorted : Array[@graph.GraphPage] = []
  let mut i = 0
  while i < pages.length() {
    sorted.push(pages[i])
    i = i + 1
  }
  @strutil.insertion_sort(sorted, compare_pages)
  sorted
}

///|
fn to_feed_item(base_url : String, page : @graph.GraphPage) -> FeedItem {
  let link = @strutil.absolute_url(base_url, page.url)
  let normalized_date = normalize_feed_datetime(page.date)
  {
    title: page.title,
    id: link,
    link,
    summary: page.description,
    updated: normalized_date,
    published: normalized_date,
  }
}

///|
fn build_feed_channel(
  title : String,
  base_url : String,
  pages : Array[@graph.GraphPage],
  limit : Int?,
) -> FeedChannel {
  let sorted_pages = sort_pages_for_feed(pages)
  let items : Array[FeedItem] = []
  let count = match limit {
    Some(n) => if n < sorted_pages.length() { n } else { sorted_pages.length() }
    None => sorted_pages.length()
  }
  let mut i = 0
  while i < count {
    items.push(to_feed_item(base_url, sorted_pages[i]))
    i = i + 1
  }

  let mut latest : String? = None
  i = 0
  while i < items.length() {
    match (latest, items[i].updated) {
      (None, Some(v)) => latest = Some(v)
      (Some(cur), Some(v)) => if v > cur { latest = Some(v) }
      _ => ()
    }
    i = i + 1
  }

  let home_link = @strutil.absolute_url(base_url, "/")
  {
    title,
    id: home_link,
    link: home_link,
    author_name: title,
    updated: latest,
    items,
  }
}

///|
fn render_atom_item(
  buf : StringBuilder,
  item : FeedItem,
  fallback_updated : String,
) -> Unit {
  let effective_updated = match item.updated {
    Some(v) => v
    None => fallback_updated
  }

  buf.write_string("  <entry>\n")
  buf.write_string("    <title>")
  buf.write_string(@strutil.escape_html_body(item.title))
  buf.write_string("</title>\n")

  buf.write_string("    <id>")
  buf.write_string(@strutil.escape_html_body(item.id))
  buf.write_string("</id>\n")

  buf.write_string("    <link href=\"")
  buf.write_string(@strutil.escape_html_attr(item.link))
  buf.write_string("\" />\n")

  buf.write_string("    <updated>")
  buf.write_string(@strutil.escape_html_body(effective_updated))
  buf.write_string("</updated>\n")

  match item.published {
    Some(v) => {
      buf.write_string("    <published>")
      buf.write_string(@strutil.escape_html_body(v))
      buf.write_string("</published>\n")
    }
    None => ()
  }

  match item.summary {
    Some(summary) => {
      buf.write_string("    <summary>")
      buf.write_string(@strutil.escape_html_body(summary))
      buf.write_string("</summary>\n")
    }
    None => ()
  }

  buf.write_string("  </entry>\n")
}

///|
fn render_atom(channel : FeedChannel) -> String {
  let feed_updated = match channel.updated {
    Some(v) => v
    None => "1970-01-01T00:00:00Z"
  }

  let buf = StringBuilder::new()
  buf.write_string("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
  buf.write_string("<feed xmlns=\"http://www.w3.org/2005/Atom\">\n")

  buf.write_string("  <title>")
  buf.write_string(@strutil.escape_html_body(channel.title))
  buf.write_string("</title>\n")

  buf.write_string("  <id>")
  buf.write_string(@strutil.escape_html_body(channel.id))
  buf.write_string("</id>\n")

  buf.write_string("  <link href=\"")
  buf.write_string(@strutil.escape_html_attr(channel.link))
  buf.write_string("\" />\n")

  buf.write_string("  <updated>")
  buf.write_string(@strutil.escape_html_body(feed_updated))
  buf.write_string("</updated>\n")

  buf.write_string("  <author><name>")
  buf.write_string(@strutil.escape_html_body(channel.author_name))
  buf.write_string("</name></author>\n")

  let mut i = 0
  while i < channel.items.length() {
    render_atom_item(buf, channel.items[i], feed_updated)
    i = i + 1
  }

  buf.write_string("</feed>\n")
  buf.to_string()
}

///|
/// Render a complete Atom feed XML document from typed graph pages.
pub fn render_feed(
  title : String,
  base_url : String,
  pages : Array[@graph.GraphPage],
  limit : Int?,
) -> String {
  let channel = build_feed_channel(title, base_url, pages, limit)
  render_atom(channel)
}

///|
/// Render a JSON Feed 1.1 document from a FeedChannel.
///
/// Uses the same typed intermediate struct as the Atom renderer — new formats
/// attach at the right end of the pipeline without a new data stage.
pub fn render_json_feed(channel : FeedChannel, feed_url : String) -> String {
  let buf = StringBuilder::new()
  buf.write_string("{\n")
  buf.write_string("  \"version\": \"https://jsonfeed.org/version/1.1\",\n")
  buf.write_string("  \"title\": ")
  @strutil.write_json_string(buf, channel.title)
  buf.write_string(",\n")
  buf.write_string("  \"home_page_url\": ")
  @strutil.write_json_string(buf, channel.link)
  buf.write_string(",\n")
  buf.write_string("  \"feed_url\": ")
  @strutil.write_json_string(buf, feed_url)
  buf.write_string(",\n")
  buf.write_string("  \"authors\": [{\"name\": ")
  @strutil.write_json_string(buf, channel.author_name)
  buf.write_string("}],\n")
  buf.write_string("  \"items\": [\n")
  let mut i = 0
  while i < channel.items.length() {
    let item = channel.items[i]
    buf.write_string("    {\n")
    buf.write_string("      \"id\": ")
    @strutil.write_json_string(buf, item.id)
    buf.write_string(",\n")
    buf.write_string("      \"url\": ")
    @strutil.write_json_string(buf, item.link)
    buf.write_string(",\n")
    buf.write_string("      \"title\": ")
    @strutil.write_json_string(buf, item.title)
    match item.summary {
      Some(summary) => {
        buf.write_string(",\n      \"summary\": ")
        @strutil.write_json_string(buf, summary)
      }
      None => ()
    }
    match item.published {
      Some(v) => {
        buf.write_string(",\n      \"date_published\": ")
        @strutil.write_json_string(buf, v)
      }
      None => ()
    }
    match item.updated {
      Some(v) => {
        buf.write_string(",\n      \"date_modified\": ")
        @strutil.write_json_string(buf, v)
      }
      None => ()
    }
    buf.write_string("\n    }")
    if i + 1 < channel.items.length() {
      buf.write_string(",")
    }
    buf.write_string("\n")
    i = i + 1
  }
  buf.write_string("  ]\n")
  buf.write_string("}\n")
  buf.to_string()
}

///|
/// Render a complete JSON Feed 1.1 document from typed graph pages.
///
/// Wraps `build_feed_channel` → `render_json_feed`, mirroring `render_feed`.
pub fn render_json_feed_from_pages(
  title : String,
  base_url : String,
  pages : Array[@graph.GraphPage],
  limit : Int?,
  feed_url : String,
) -> String {
  let channel = build_feed_channel(title, base_url, pages, limit)
  render_json_feed(channel, feed_url)
}
