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
pub(all) enum ShortcodeError {
  UnknownShortcode(String)
  MissingParam(String, String)
  InvalidParamType(String, String, String)
  InvalidSyntax(String)
} derive(Eq, Show)

///|
fn parse_int_shortcode(s : String) -> Int? {
  if s.length() == 0 {
    return None
  }
  let mut i = 0
  let mut neg = false
  if @strutil.char_at(s, 0) == '-' {
    neg = true
    i = 1
  }
  if i >= s.length() {
    return None
  }
  let mut value = 0
  while i < s.length() {
    let c = @strutil.char_at(s, i)
    if !@strutil.is_digit(c) {
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
fn parse_name_shortcode(s : String, pos : Int) -> (String, Int) {
  let mut i = pos
  while i < s.length() && @strutil.is_ident_part(@strutil.char_at(s, i)) {
    i = i + 1
  }
  (@strutil.substr(s, pos, i), i)
}

///|
fn parse_quoted_shortcode(
  s : String,
  pos : Int,
) -> Result[(String, Int), String] {
  if pos >= s.length() || @strutil.char_at(s, pos) != '"' {
    return Err("expected quote")
  }
  let buf = StringBuilder::new()
  let mut i = pos + 1
  while i < s.length() {
    let c = @strutil.char_at(s, i)
    if c == '\\' {
      if i + 1 >= s.length() {
        return Err("unterminated escape")
      }
      let esc = @strutil.char_at(s, i + 1)
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
  let c = @strutil.char_at(s, pos)
  if c == '"' {
    match parse_quoted_shortcode(s, pos) {
      Ok((v, next)) => Ok((StringParam(v), next))
      Err(msg) => Err(msg)
    }
  } else {
    let mut i = pos
    while i < s.length() && !@strutil.is_whitespace(@strutil.char_at(s, i)) {
      i = i + 1
    }
    let raw = @strutil.trim(@strutil.substr(s, pos, i))
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
  let s = @strutil.trim(raw)
  if s.length() == 0 {
    return Err(InvalidSyntax("empty shortcode"))
  }
  let i0 = @strutil.skip_ws(s, 0)
  let (name, next_name) = parse_name_shortcode(s, i0)
  if name.length() == 0 {
    return Err(InvalidSyntax("missing shortcode name"))
  }
  if @strutil.starts_with(name, "/") {
    return Err(InvalidSyntax("closing shortcode is not a call"))
  }

  let params : Map[String, ShortcodeParam] = Map::new()
  let mut i = @strutil.skip_ws(s, next_name)
  while i < s.length() {
    let (key, key_end) = parse_name_shortcode(s, i)
    if key.length() == 0 {
      return Err(InvalidSyntax("invalid parameter key"))
    }
    let eq_pos = @strutil.skip_ws(s, key_end)
    if eq_pos >= s.length() || @strutil.char_at(s, eq_pos) != '=' {
      return Err(InvalidSyntax("expected '=' after parameter '" + key + "'"))
    }
    let value_pos = @strutil.skip_ws(s, eq_pos + 1)
    match parse_value_shortcode(s, value_pos) {
      Ok((value, next)) => {
        params.set(key, value)
        i = @strutil.skip_ws(s, next)
      }
      Err(msg) => return Err(InvalidSyntax("param '" + key + "': " + msg))
    }
  }

  Ok({ name, params })
}

///|
pub fn parse_open_close_tag(raw : String) -> (String?, Bool) {
  let s = @strutil.trim(raw)
  if s.length() == 0 {
    return (None, false)
  }
  let i0 = @strutil.skip_ws(s, 0)
  let (name, _) = parse_name_shortcode(s, i0)
  if name.length() == 0 {
    return (None, false)
  }
  if @strutil.starts_with(name, "/") {
    if name.length() <= 1 {
      return (None, true)
    }
    return (Some(@strutil.substr(name, 1, name.length())), true)
  }
  (Some(name), false)
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
  out.write_string(@strutil.escape_html_attr(src))
  out.write_string("\" alt=\"")
  out.write_string(@strutil.escape_html_attr(alt))
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
      out.write_string(@strutil.escape_html_attr(text))
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
  out.write_string(@strutil.escape_html_attr(src))
  out.write_string("\"")
  match poster {
    Some(p) => {
      out.write_string(" poster=\"")
      out.write_string(@strutil.escape_html_attr(p))
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
      out.write_string(@strutil.escape_html_attr(href))
      out.write_string("\">")
      out.write_string("<img src=\"")
      out.write_string(@strutil.escape_html_attr(src))
      out.write_string("\" alt=\"")
      out.write_string(@strutil.escape_html_attr(alt))
      out.write_string("\" />")
      out.write_string("</a>")
    }
    None => {
      out.write_string("<img src=\"")
      out.write_string(@strutil.escape_html_attr(src))
      out.write_string("\" alt=\"")
      out.write_string(@strutil.escape_html_attr(alt))
      out.write_string("\" />")
    }
  }
  match caption {
    Some(text) => {
      out.write_string("<figcaption>")
      out.write_string(@strutil.escape_html_attr(text))
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
  if !(callout_type == "note" ||
    callout_type == "warning" ||
    callout_type == "tip" ||
    callout_type == "danger") {
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
  out.write_string(@strutil.escape_html_attr(callout_type))
  out.write_string("\">")
  match title {
    Some(t) => {
      out.write_string("<p class=\"callout-title\">")
      out.write_string(@strutil.escape_html_attr(t))
      out.write_string("</p>")
    }
    None => ()
  }
  match body {
    Some(text) => {
      out.write_string("<p>")
      out.write_string(@strutil.escape_html_attr(text))
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
