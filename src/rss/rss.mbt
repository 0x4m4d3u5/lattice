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
fn char_at_rss(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

///|
fn escape_xml_text(s : String) -> String {
  let buf = StringBuilder::new()
  let n = s.length()
  let mut i = 0
  while i < n {
    let c = char_at_rss(s, i)
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
fn escape_xml_attr(s : String) -> String {
  let buf = StringBuilder::new()
  let n = s.length()
  let mut i = 0
  while i < n {
    let c = char_at_rss(s, i)
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
fn starts_with_at(s : String, pos : Int, prefix : String) -> Bool {
  let plen = prefix.length()
  if pos + plen > s.length() {
    return false
  }
  let mut j = 0
  while j < plen {
    if char_at_rss(s, pos + j) != char_at_rss(prefix, j) {
      return false
    }
    j = j + 1
  }
  true
}

///|
fn trim(s : String) -> String {
  let n = s.length()
  let mut lo = 0
  while lo < n &&
        (
          char_at_rss(s, lo) == ' ' ||
          char_at_rss(s, lo) == '\t' ||
          char_at_rss(s, lo) == '\r'
        ) {
    lo = lo + 1
  }
  let mut hi = n
  while hi > lo &&
        (
          char_at_rss(s, hi - 1) == ' ' ||
          char_at_rss(s, hi - 1) == '\t' ||
          char_at_rss(s, hi - 1) == '\r'
        ) {
    hi = hi - 1
  }
  let buf = StringBuilder::new()
  let mut i = lo
  while i < hi {
    buf.write_char(char_at_rss(s, i))
    i = i + 1
  }
  buf.to_string()
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn parse_fixed_uint(s : String, start : Int, count : Int) -> Int? {
  if start + count > s.length() {
    return None
  }
  let mut i = 0
  let mut value = 0
  while i < count {
    let c = char_at_rss(s, start + i)
    if not(is_digit(c)) {
      return None
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
    i = i + 1
  }
  Some(value)
}

///|
fn is_leap_year(year : Int) -> Bool {
  if year % 400 == 0 {
    true
  } else if year % 100 == 0 {
    false
  } else {
    year % 4 == 0
  }
}

///|
fn days_in_month(year : Int, month : Int) -> Int {
  if month == 1 ||
    month == 3 ||
    month == 5 ||
    month == 7 ||
    month == 8 ||
    month == 10 ||
    month == 12 {
    31
  } else if month == 4 || month == 6 || month == 9 || month == 11 {
    30
  } else if month == 2 {
    if is_leap_year(year) {
      29
    } else {
      28
    }
  } else {
    0
  }
}

///|
/// Parse either YYYY-MM-DD or RFC3339-like date; normalize to RFC3339 UTC.
fn normalize_feed_datetime(raw : String?) -> String? {
  match raw {
    None => None
    Some(date_text) => {
      let s = trim(date_text)
      if s.length() == 0 {
        return None
      }
      if s.length() == 10 {
        let year = parse_fixed_uint(s, 0, 4)
        let month = parse_fixed_uint(s, 5, 2)
        let day = parse_fixed_uint(s, 8, 2)
        if char_at_rss(s, 4) != '-' || char_at_rss(s, 7) != '-' {
          return None
        }
        match (year, month, day) {
          (Some(y), Some(m), Some(d)) => {
            if m < 1 || m > 12 {
              return None
            }
            let max_day = days_in_month(y, m)
            if d < 1 || d > max_day {
              return None
            }
            return Some(s + "T00:00:00Z")
          }
          _ => None
        }
      } else if starts_with_at(s, 0, "20") &&
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
fn normalize_base_url(base_url : String) -> String {
  let trimmed = trim(base_url)
  if trimmed == "/" {
    return ""
  }
  if trimmed.has_suffix("/") {
    let buf = StringBuilder::new()
    let mut i = 0
    let end_pos = trimmed.length() - 1
    while i < end_pos {
      buf.write_char(char_at_rss(trimmed, i))
      i = i + 1
    }
    return buf.to_string()
  }
  trimmed
}

///|
fn absolute_url(base_url : String, path : String) -> String {
  let base = normalize_base_url(base_url)
  if base.length() == 0 {
    return path
  }
  if path.length() == 0 {
    return base
  }
  let path_starts_slash = char_at_rss(path, 0) == '/'
  if path_starts_slash {
    base + path
  } else {
    base + "/" + path
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
  i = 1
  while i < sorted.length() {
    let mut j = i
    while j > 0 && compare_pages(sorted[j - 1], sorted[j]) > 0 {
      let tmp = sorted[j - 1]
      sorted[j - 1] = sorted[j]
      sorted[j] = tmp
      j = j - 1
    }
    i = i + 1
  }
  sorted
}

///|
fn to_feed_item(base_url : String, page : @graph.GraphPage) -> FeedItem {
  let link = absolute_url(base_url, page.url)
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

  let home_link = absolute_url(base_url, "/")
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
  buf.write_string(escape_xml_text(item.title))
  buf.write_string("</title>\n")

  buf.write_string("    <id>")
  buf.write_string(escape_xml_text(item.id))
  buf.write_string("</id>\n")

  buf.write_string("    <link href=\"")
  buf.write_string(escape_xml_attr(item.link))
  buf.write_string("\" />\n")

  buf.write_string("    <updated>")
  buf.write_string(escape_xml_text(effective_updated))
  buf.write_string("</updated>\n")

  match item.published {
    Some(v) => {
      buf.write_string("    <published>")
      buf.write_string(escape_xml_text(v))
      buf.write_string("</published>\n")
    }
    None => ()
  }

  match item.summary {
    Some(summary) => {
      buf.write_string("    <summary>")
      buf.write_string(escape_xml_text(summary))
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
  buf.write_string(escape_xml_text(channel.title))
  buf.write_string("</title>\n")

  buf.write_string("  <id>")
  buf.write_string(escape_xml_text(channel.id))
  buf.write_string("</id>\n")

  buf.write_string("  <link href=\"")
  buf.write_string(escape_xml_attr(channel.link))
  buf.write_string("\" />\n")

  buf.write_string("  <updated>")
  buf.write_string(escape_xml_text(feed_updated))
  buf.write_string("</updated>\n")

  buf.write_string("  <author><name>")
  buf.write_string(escape_xml_text(channel.author_name))
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
