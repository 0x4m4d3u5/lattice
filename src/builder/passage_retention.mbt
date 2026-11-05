///|
/// Complete renderer-owned UTF-16 ranges. Invalid origins remain in the list so
/// a later edit cannot turn a duplicate emission into a unique verified origin.
fn passage_slot_ranges(
  ranges : Array[(Int32, Int32)],
  cut : Int32,
) -> Map[@template.TemplateSlot, Array[(Int32, Int32, Int32)]] {
  let slots = Map([])
  for slot in [@template.Content, @template.Body, @template.BodyNoH1] {
    let trim = if slot == @template.BodyNoH1 { cut } else { 0 }
    let items = []
    for i = 0; i < ranges.length(); i = i + 1 {
      let (start, end) = ranges[i]
      if start >= trim {
        items.push((i, start - trim, end - trim))
      } else if end > trim {
        items.push((i, -1, -1))
      }
    }
    slots.set(slot, items)
  }
  slots
}

///|
fn shift_passages(
  ranges : Array[(Int32, Int32, Int32)],
  start : Int32,
  end : Int32,
  size : Int32,
) -> Unit {
  for i = 0; i < ranges.length(); i = i + 1 {
    let (key, a, b) = ranges[i]
    if a < 0 {
      continue
    }
    if end <= a {
      let delta = size - (end - start)
      ranges[i] = (key, a + delta, b + delta)
    } else if start < b {
      ranges[i] = (key, -1, -1)
    }
  }
}

///|
/// Match the stdlib's non-overlapping literal replacement while recording edits.
fn replace_passages(
  html : String,
  old : String,
  new : String,
  ranges : Array[(Int32, Int32, Int32)],
) -> String {
  if old == "" || old == new {
    return html
  }
  let parts = html.split(old).collect()
  let mut offset = 0
  for i = 0; i + 1 < parts.length(); i = i + 1 {
    offset = offset + parts[i].length()
    shift_passages(ranges, offset, offset + old.length(), new.length())
    offset = offset + new.length()
  }
  html.replace_all(old~, new~)
}

///|
fn inject_passage_head(
  html : String,
  markup : String,
  ranges : Array[(Int32, Int32, Int32)],
) -> String {
  if markup == "" { return html }
  if html.split_once("</head>") is Some((prefix, _)) {
    shift_passages(ranges, prefix.length(), prefix.length(), markup.length())
  }
  @html.inject_head_markup(html, markup)
}

///|
fn passage_bindings(
  doc : ProcessedDocument,
  html : String,
  ranges : Array[(Int32, Int32, Int32)],
) -> Map[Int32, @search.PassageRetention] {
  let result : Map[Int32, @search.PassageRetention] = Map([])
  let counts : Map[Int32, Int32] = Map([])
  for (key, _, _) in ranges {
    counts.set(key, counts.get(key).unwrap_or(0) + 1)
  }
  // Convert ordered boundaries once; avoid re-encoding every page prefix.
  let boundaries : Array[Int32] = []
  for (_, start, end) in ranges {
    if start >= 0 && end > start && end <= html.length() {
      boundaries.push(start)
      boundaries.push(end)
    }
  }
  boundaries.sort()
  let bytes_at : Map[Int32, Int32] = Map([])
  let mut previous = 0
  let mut byte_offset = 0
  for boundary in boundaries {
    byte_offset = byte_offset +
      @utf8.encode(html[previous:boundary].to_owned()).length()
    bytes_at.set(boundary, byte_offset)
    previous = boundary
  }
  for (key, start, end) in ranges {
    if counts.get(key) != Some(1) ||
      start < 0 ||
      end <= start ||
      end > html.length() ||
      key >= doc.sections.length() {
      continue
    }
    let section = doc.sections[key]
    result.set(key, {
      start: bytes_at.get(start).unwrap(),
      end: bytes_at.get(end).unwrap(),
      digest: publication_digest(html[start:end].to_owned()),
      heading_digest: publication_digest(section.heading),
      body_digest: publication_digest(section.body),
    })
  }
  result
}
