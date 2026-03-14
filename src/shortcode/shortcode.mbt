///|
/// Shortcode parser + typed renderer.
///
/// Syntax:
///   {{< shortcode_name key=value key2="value" >}}
///
/// Parsed representation is strongly typed and validated by built-in
/// renderers so failures become explicit structural errors.
pub(all) enum ShortcodeParam {
  StringParam(String)
  IntParam(Int)
  BoolParam(Bool)
}

///|
pub(all) struct ShortcodeCall {
  name : String
  params : Map[String, ShortcodeParam]
}

///|
pub enum ShortcodeError {
  UnknownShortcode(String)
  MissingParam(String, String)
  InvalidParamType(String, String, String)
  InvalidSyntax(String)
}

///|
fn char_at_shortcode(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

///|
fn substr_shortcode(s : String, start : Int, end_pos : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = start
  while i < end_pos {
    buf.write_char(char_at_shortcode(s, i))
    i = i + 1
  }
  buf.to_string()
}

///|
fn trim_shortcode(s : String) -> String {
  let n = s.length()
  let mut lo = 0
  while lo < n &&
        (
          char_at_shortcode(s, lo) == ' ' ||
          char_at_shortcode(s, lo) == '\t' ||
          char_at_shortcode(s, lo) == '\n' ||
          char_at_shortcode(s, lo) == '\r'
        ) {
    lo = lo + 1
  }
  let mut hi = n
  while hi > lo &&
        (
          char_at_shortcode(s, hi - 1) == ' ' ||
          char_at_shortcode(s, hi - 1) == '\t' ||
          char_at_shortcode(s, hi - 1) == '\n' ||
          char_at_shortcode(s, hi - 1) == '\r'
        ) {
    hi = hi - 1
  }
  substr_shortcode(s, lo, hi)
}

///|
fn is_digit_shortcode(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_name_char_shortcode(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '_' ||
  c == '-' ||
  c == '/'
}

///|
fn starts_with_shortcode(s : String, prefix : String) -> Bool {
  let plen = prefix.length()
  if plen > s.length() {
    return false
  }
  let mut i = 0
  while i < plen {
    if char_at_shortcode(s, i) != char_at_shortcode(prefix, i) {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn parse_int_shortcode(s : String) -> Int? {
  if s.length() == 0 {
    return None
  }
  let mut i = 0
  let mut neg = false
  if char_at_shortcode(s, 0) == '-' {
    neg = true
    i = 1
  }
  if i >= s.length() {
    return None
  }
  let mut value = 0
  while i < s.length() {
    let c = char_at_shortcode(s, i)
    if not(is_digit_shortcode(c)) {
      return None
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
    i = i + 1
  }
  if neg {
    Some(-value)
  } else {
    Some(value)
  }
}

///|
fn skip_ws_shortcode(s : String, pos : Int) -> Int {
  let mut i = pos
  while i < s.length() &&
        (
          char_at_shortcode(s, i) == ' ' ||
          char_at_shortcode(s, i) == '\t' ||
          char_at_shortcode(s, i) == '\n' ||
          char_at_shortcode(s, i) == '\r'
        ) {
    i = i + 1
  }
  i
}

///|
fn parse_name_shortcode(s : String, pos : Int) -> (String, Int) {
  let mut i = pos
  while i < s.length() && is_name_char_shortcode(char_at_shortcode(s, i)) {
    i = i + 1
  }
  (substr_shortcode(s, pos, i), i)
}

///|
fn parse_quoted_shortcode(
  s : String,
  pos : Int,
) -> Result[(String, Int), String] {
  if pos >= s.length() || char_at_shortcode(s, pos) != '"' {
    return Err("expected quote")
  }
  let buf = StringBuilder::new()
  let mut i = pos + 1
  while i < s.length() {
    let c = char_at_shortcode(s, i)
    if c == '\\' {
      if i + 1 >= s.length() {
        return Err("unterminated escape")
      }
      let esc = char_at_shortcode(s, i + 1)
      if esc == 'n' {
        buf.write_char('\n')
      } else if esc == 't' {
        buf.write_char('\t')
      } else if esc == '"' {
        buf.write_char('"')
      } else if esc == '\\' {
        buf.write_char('\\')
      } else {
        buf.write_char(esc)
      }
      i = i + 2
    } else if c == '"' {
      return Ok((buf.to_string(), i + 1))
    } else {
      buf.write_char(c)
      i = i + 1
    }
  }
  Err("unterminated quoted value")
}

///|
fn parse_value_shortcode(
  s : String,
  pos : Int,
) -> Result[(ShortcodeParam, Int), String] {
  if pos >= s.length() {
    return Err("expected value")
  }
  let c = char_at_shortcode(s, pos)
  if c == '"' {
    match parse_quoted_shortcode(s, pos) {
      Ok((v, next)) => Ok((StringParam(v), next))
      Err(msg) => Err(msg)
    }
  } else {
    let mut i = pos
    while i < s.length() &&
          char_at_shortcode(s, i) != ' ' &&
          char_at_shortcode(s, i) != '\t' &&
          char_at_shortcode(s, i) != '\n' &&
          char_at_shortcode(s, i) != '\r' {
      i = i + 1
    }
    let raw = trim_shortcode(substr_shortcode(s, pos, i))
    if raw == "true" {
      return Ok((BoolParam(true), i))
    }
    if raw == "false" {
      return Ok((BoolParam(false), i))
    }
    match parse_int_shortcode(raw) {
      Some(v) => Ok((IntParam(v), i))
      None => Ok((StringParam(raw), i))
    }
  }
}

///|
pub fn parse(raw : String) -> Result[ShortcodeCall, ShortcodeError] {
  let s = trim_shortcode(raw)
  if s.length() == 0 {
    return Err(InvalidSyntax("empty shortcode"))
  }
  let i0 = skip_ws_shortcode(s, 0)
  let (name, next_name) = parse_name_shortcode(s, i0)
  if name.length() == 0 {
    return Err(InvalidSyntax("missing shortcode name"))
  }
  if starts_with_shortcode(name, "/") {
    return Err(InvalidSyntax("closing shortcode is not a call"))
  }

  let params : Map[String, ShortcodeParam] = Map::new()
  let mut i = skip_ws_shortcode(s, next_name)
  while i < s.length() {
    let (key, key_end) = parse_name_shortcode(s, i)
    if key.length() == 0 {
      return Err(InvalidSyntax("invalid parameter key"))
    }
    let eq_pos = skip_ws_shortcode(s, key_end)
    if eq_pos >= s.length() || char_at_shortcode(s, eq_pos) != '=' {
      return Err(InvalidSyntax("expected '=' after parameter '" + key + "'"))
    }
    let value_pos = skip_ws_shortcode(s, eq_pos + 1)
    match parse_value_shortcode(s, value_pos) {
      Ok((value, next)) => {
        params.set(key, value)
        i = skip_ws_shortcode(s, next)
      }
      Err(msg) => return Err(InvalidSyntax("param '" + key + "': " + msg))
    }
  }

  Ok({ name, params })
}

///|
pub fn parse_open_close_tag(raw : String) -> (String?, Bool) {
  let s = trim_shortcode(raw)
  if s.length() == 0 {
    return (None, false)
  }
  let i0 = skip_ws_shortcode(s, 0)
  let (name, _) = parse_name_shortcode(s, i0)
  if name.length() == 0 {
    return (None, false)
  }
  if starts_with_shortcode(name, "/") {
    if name.length() <= 1 {
      return (None, true)
    }
    return (Some(substr_shortcode(name, 1, name.length())), true)
  }
  (Some(name), false)
}

///|
fn escape_html_shortcode(s : String) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < s.length() {
    let c = char_at_shortcode(s, i)
    if c == '&' {
      out.write_string("&amp;")
    } else if c == '<' {
      out.write_string("&lt;")
    } else if c == '>' {
      out.write_string("&gt;")
    } else if c == '"' {
      out.write_string("&quot;")
    } else {
      out.write_char(c)
    }
    i = i + 1
  }
  out.to_string()
}

///|
fn require_string_param(
  call : ShortcodeCall,
  key : String,
) -> Result[String, ShortcodeError] {
  match call.params.get(key) {
    Some(StringParam(v)) => Ok(v)
    Some(_) => Err(InvalidParamType(call.name, key, "String"))
    None => Err(MissingParam(call.name, key))
  }
}

///|
fn optional_string_param(
  call : ShortcodeCall,
  key : String,
) -> Result[String?, ShortcodeError] {
  match call.params.get(key) {
    Some(StringParam(v)) => Ok(Some(v))
    Some(_) => Err(InvalidParamType(call.name, key, "String"))
    None => Ok(None)
  }
}

///|
fn optional_int_param(
  call : ShortcodeCall,
  key : String,
) -> Result[Int?, ShortcodeError] {
  match call.params.get(key) {
    Some(IntParam(v)) => Ok(Some(v))
    Some(_) => Err(InvalidParamType(call.name, key, "Int"))
    None => Ok(None)
  }
}

///|
fn render_image(call : ShortcodeCall) -> Result[String, ShortcodeError] {
  let src = match require_string_param(call, "src") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let alt = match require_string_param(call, "alt") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let caption = match optional_string_param(call, "caption") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let width = match optional_int_param(call, "width") {
    Ok(v) => v
    Err(e) => return Err(e)
  }

  let out = StringBuilder::new()
  if caption != None {
    out.write_string("<figure class=\"sc-image\">")
  }
  out.write_string("<img src=\"")
  out.write_string(escape_html_shortcode(src))
  out.write_string("\" alt=\"")
  out.write_string(escape_html_shortcode(alt))
  out.write_string("\"")
  match width {
    Some(w) => {
      out.write_string(" width=\"")
      out.write_string(w.to_string())
      out.write_string("\"")
    }
    None => ()
  }
  out.write_string(" />")
  match caption {
    Some(text) => {
      out.write_string("<figcaption>")
      out.write_string(escape_html_shortcode(text))
      out.write_string("</figcaption></figure>")
    }
    None => ()
  }
  Ok(out.to_string())
}

///|
fn render_video(call : ShortcodeCall) -> Result[String, ShortcodeError] {
  let src = match require_string_param(call, "src") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let poster = match optional_string_param(call, "poster") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let out = StringBuilder::new()
  out.write_string("<video controls src=\"")
  out.write_string(escape_html_shortcode(src))
  out.write_string("\"")
  match poster {
    Some(p) => {
      out.write_string(" poster=\"")
      out.write_string(escape_html_shortcode(p))
      out.write_string("\"")
    }
    None => ()
  }
  out.write_string("></video>")
  Ok(out.to_string())
}

///|
fn render_figure(call : ShortcodeCall) -> Result[String, ShortcodeError] {
  let src = match require_string_param(call, "src") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let alt = match require_string_param(call, "alt") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let caption = match optional_string_param(call, "caption") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let link = match optional_string_param(call, "link") {
    Ok(v) => v
    Err(e) => return Err(e)
  }

  let out = StringBuilder::new()
  out.write_string("<figure class=\"sc-figure\">")
  match link {
    Some(href) => {
      out.write_string("<a href=\"")
      out.write_string(escape_html_shortcode(href))
      out.write_string("\">")
      out.write_string("<img src=\"")
      out.write_string(escape_html_shortcode(src))
      out.write_string("\" alt=\"")
      out.write_string(escape_html_shortcode(alt))
      out.write_string("\" />")
      out.write_string("</a>")
    }
    None => {
      out.write_string("<img src=\"")
      out.write_string(escape_html_shortcode(src))
      out.write_string("\" alt=\"")
      out.write_string(escape_html_shortcode(alt))
      out.write_string("\" />")
    }
  }
  match caption {
    Some(text) => {
      out.write_string("<figcaption>")
      out.write_string(escape_html_shortcode(text))
      out.write_string("</figcaption>")
    }
    None => ()
  }
  out.write_string("</figure>")
  Ok(out.to_string())
}

///|
fn render_callout(call : ShortcodeCall) -> Result[String, ShortcodeError] {
  let callout_type = match require_string_param(call, "type") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if not(
      callout_type == "note" ||
      callout_type == "warning" ||
      callout_type == "tip" ||
      callout_type == "danger",
    ) {
    return Err(InvalidParamType(call.name, "type", "note|warning|tip|danger"))
  }
  let title = match optional_string_param(call, "title") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let body = match optional_string_param(call, "body") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let out = StringBuilder::new()
  out.write_string("<aside class=\"callout callout-")
  out.write_string(escape_html_shortcode(callout_type))
  out.write_string("\">")
  match title {
    Some(t) => {
      out.write_string("<p class=\"callout-title\">")
      out.write_string(escape_html_shortcode(t))
      out.write_string("</p>")
    }
    None => ()
  }
  match body {
    Some(text) => {
      out.write_string("<p>")
      out.write_string(escape_html_shortcode(text))
      out.write_string("</p>")
    }
    None => ()
  }
  out.write_string("</aside>")
  Ok(out.to_string())
}

///|
pub fn render(call : ShortcodeCall) -> Result[String, ShortcodeError] {
  if call.name == "image" {
    return render_image(call)
  }
  if call.name == "callout" {
    return render_callout(call)
  }
  if call.name == "video" {
    return render_video(call)
  }
  if call.name == "figure" {
    return render_figure(call)
  }
  Err(UnknownShortcode(call.name))
}

///|
pub fn error_text(err : ShortcodeError) -> String {
  match err {
    UnknownShortcode(name) => "unknown shortcode '" + name + "'"
    MissingParam(shortcode, param) =>
      "shortcode '" + shortcode + "' missing param '" + param + "'"
    InvalidParamType(shortcode, param, expected) =>
      "shortcode '" + shortcode + "' param '" + param + "' expected " + expected
    InvalidSyntax(msg) => "shortcode syntax: " + msg
  }
}
