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
    if not(@strutil.is_digit(c)) {
      return None
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
    i = i + 1
  }
  Some(value)
}

///|
/// Parse either YYYY-MM-DD or RFC3339-like date; normalize to RFC3339 UTC.
fn normalize_feed_datetime(raw : String?) -> String? {
  match raw {
    None => None
    Some(date_text) => {
      let s = @strutil.trim(date_text)
      if s.length() == 0 {
        return None
      }
      if s.length() == 10 {
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
      } else if @strutil.starts_with_at(s, 0, "20") &&
        s.has_suffix("Z") &&
        s.length() >= 20 {
        Some(s)
      } else {
        None
      }
    }
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
