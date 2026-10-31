///|
/// Recognize only a blockquote's first line. Restrict identifiers to portable
/// CSS class characters; custom identifiers retain their name and neutral style.
fn parse_callout_header(line : String) -> (String, Array[Inline], Bool?)? {
  if !line.has_prefix("[!") { return None }
  let mut end = 2
  while end < line.length() && line[end] != ']' {
    let c = line[end]
    if !((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
         (c >= '0' && c <= '9') || c == '-' || c == '_') { return None }
    end = end + 1
  }
  if end == 2 || end >= line.length() { return None }
  let kind = @strutil.substr(line, 2, end).to_lower()
  let mut start = end + 1
  let expanded = if start < line.length() && (line[start] == '+' || line[start] == '-') {
    let open = line[start] == '+'
    start = start + 1
    Some(open)
  } else { None }
  let title = @strutil.trim(@strutil.substr(line, start, line.length()))
  let title = if title == "" {
    @strutil.substr(kind, 0, 1).to_upper() + @strutil.substr(kind, 1, kind.length())
  } else { title }
  Some((kind, parse_inlines(title, 0, title.length()), expanded))
}
