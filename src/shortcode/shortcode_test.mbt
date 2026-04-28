///|
test "shortcode parse image params" {
  match parse("image src=\"/img.png\" alt=\"hero\" width=640") {
    Ok(call) => {
      assert_eq(call.name, "image")
      match call.params.get("src") {
        Some(StringParam(v)) => assert_eq(v, "/img.png")
        _ => assert_true(false)
      }
      match call.params.get("alt") {
        Some(StringParam(v)) => assert_eq(v, "hero")
        _ => assert_true(false)
      }
      match call.params.get("width") {
        Some(IntParam(v)) => assert_eq(v, 640)
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "shortcode render image" {
  let params : Map[String, ShortcodeParam] = Map::new()
  params.set("src", StringParam("/img/a.png"))
  params.set("alt", StringParam("alpha"))
  params.set("caption", StringParam("Caption text"))
  params.set("width", IntParam(320))
  let call : ShortcodeCall = { name: "image", params }
  match render(call) {
    Ok(html) => {
      assert_true(html.contains("<img"))
      assert_true(html.contains("figcaption"))
      assert_true(html.contains("width=\"320\""))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "shortcode render video" {
  let params : Map[String, ShortcodeParam] = Map::new()
  params.set("src", StringParam("/vid/a.mp4"))
  params.set("poster", StringParam("/vid/a.jpg"))
  let call : ShortcodeCall = { name: "video", params }
  match render(call) {
    Ok(html) => {
      assert_true(html.contains("<video"))
      assert_true(html.contains("controls"))
      assert_true(html.contains("poster=\"/vid/a.jpg\""))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "shortcode render figure" {
  let params : Map[String, ShortcodeParam] = Map::new()
  params.set("src", StringParam("/img/f.png"))
  params.set("alt", StringParam("figure"))
  params.set("caption", StringParam("Figure caption"))
  params.set("link", StringParam("/detail"))
  let call : ShortcodeCall = { name: "figure", params }
  match render(call) {
    Ok(html) => {
      assert_true(html.contains("<figure"))
      assert_true(html.contains("<a href=\"/detail\""))
      assert_true(html.contains("<figcaption>Figure caption</figcaption>"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "shortcode unknown name" {
  let params : Map[String, ShortcodeParam] = Map::new()
  let call : ShortcodeCall = { name: "fancy", params }
  match render(call) {
    Ok(_) => assert_true(false)
    Err(UnknownShortcode(name)) => assert_eq(name, "fancy")
    Err(_) => assert_true(false)
  }
}

///|
test "shortcode missing required param" {
  let params : Map[String, ShortcodeParam] = Map::new()
  params.set("alt", StringParam("missing src"))
  let call : ShortcodeCall = { name: "image", params }
  match render(call) {
    Ok(_) => assert_true(false)
    Err(MissingParam(shortcode, param)) => {
      assert_eq(shortcode, "image")
      assert_eq(param, "src")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "shortcode image InvalidParamType when width is a string" {
  let params : Map[String, ShortcodeParam] = Map::new()
  params.set("src", StringParam("/img.png"))
  params.set("alt", StringParam("a photo"))
  params.set("width", StringParam("800"))
  let call : ShortcodeCall = { name: "image", params }
  match render(call) {
    Ok(_) => assert_true(false)
    Err(InvalidParamType(shortcode, param, expected)) => {
      assert_eq(shortcode, "image")
      assert_eq(param, "width")
      assert_eq(expected, "Int")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "shortcode parse bool params" {
  match parse("callout type=\"note\" collapse=true") {
    Ok(call) => {
      match call.params.get("collapse") {
        Some(BoolParam(v)) => assert_eq(v, true)
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "shortcode render callout note" {
  let params : Map[String, ShortcodeParam] = Map::new()
  params.set("type", StringParam("note"))
  params.set("title", StringParam("Note Title"))
  params.set("body", StringParam("Body text"))
  let call : ShortcodeCall = { name: "callout", params }
  match render(call) {
    Ok(html) => {
      assert_true(html.contains("callout-note"))
      assert_true(html.contains("Note Title"))
      assert_true(html.contains("Body text"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "shortcode callout invalid type produces InvalidParamType" {
  let params : Map[String, ShortcodeParam] = Map::new()
  params.set("type", StringParam("invalid"))
  let call : ShortcodeCall = { name: "callout", params }
  match render(call) {
    Ok(_) => assert_true(false)
    Err(InvalidParamType(shortcode, param, expected)) => {
      assert_eq(shortcode, "callout")
      assert_eq(param, "type")
      assert_eq(expected, "note|warning|tip|danger")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "shortcode error_text formats all 4 variants" {
  assert_eq(
    error_text(UnknownShortcode("fancy")),
    "unknown shortcode 'fancy'",
  )
  assert_eq(
    error_text(MissingParam("image", "src")),
    "shortcode 'image' missing param 'src'",
  )
  assert_eq(
    error_text(InvalidParamType("image", "width", "Int")),
    "shortcode 'image' param 'width' expected Int",
  )
  assert_eq(
    error_text(InvalidSyntax("unexpected EOF")),
    "shortcode syntax: unexpected EOF",
  )
}

// ============================================================
// parse_open_close_tag — coverage gaps
// ============================================================

///|
test "shortcode parse_open_close_tag empty string" {
  let (name, is_close) = parse_open_close_tag("")
  assert_eq(name, None)
  assert_eq(is_close, false)
}

///|
test "shortcode parse_open_close_tag whitespace only" {
  let (name, is_close) = parse_open_close_tag("   ")
  assert_eq(name, None)
  assert_eq(is_close, false)
}

///|
test "shortcode parse_open_close_tag valid name" {
  let (name, is_close) = parse_open_close_tag("image")
  assert_eq(name, Some("image"))
  assert_eq(is_close, false)
}

///|
test "shortcode parse_open_close_tag name with leading whitespace" {
  let (name, is_close) = parse_open_close_tag("  video  ")
  assert_eq(name, Some("video"))
  assert_eq(is_close, false)
}

///|
test "shortcode parse_open_close_tag slash prefix non-ident yields None" {
  // parse_name_shortcode stops at '/' (not an ident char), so name is ""
  // and the function returns (None, false) before reaching the slash check.
  let (name, is_close) = parse_open_close_tag("/foo")
  assert_eq(name, None)
  assert_eq(is_close, false)
}

///|
test "shortcode parse_open_close_tag bare slash yields None" {
  let (name, is_close) = parse_open_close_tag("/")
  assert_eq(name, None)
  assert_eq(is_close, false)
}

///|
test "shortcode parse_open_close_tag non-ident start yields None" {
  // '+' is not an ident char (not alpha, digit, or underscore)
  let (name, is_close) = parse_open_close_tag("+bad")
  assert_eq(name, None)
  assert_eq(is_close, false)
}

///|
test "shortcode parse_open_close_tag digits are valid ident parts" {
  // Digits are valid ident continuations, so "123" is a valid name.
  let (name, is_close) = parse_open_close_tag("123")
  assert_eq(name, Some("123"))
  assert_eq(is_close, false)
}

///|
test "shortcode parse_open_close_tag name with trailing content" {
  // parse_name_shortcode stops at whitespace, so only "image" is the name
  let (name, is_close) = parse_open_close_tag("image src=\"x\"")
  assert_eq(name, Some("image"))
  assert_eq(is_close, false)
}

// ============================================================
// Escape sequences in quoted params
// ============================================================

///|
test "shortcode parse escape newline" {
  match parse("image src=\"line1\\nline2\" alt=\"test\"") {
    Ok(call) => {
      match call.params.get("src") {
        Some(StringParam(v)) => assert_eq(v, "line1\nline2")
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "shortcode parse escape tab" {
  match parse("image src=\"col1\\tcol2\" alt=\"test\"") {
    Ok(call) => {
      match call.params.get("src") {
        Some(StringParam(v)) => assert_eq(v, "col1\tcol2")
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "shortcode parse escape quote" {
  match parse("image src=\"say \\\"hello\\\"\" alt=\"test\"") {
    Ok(call) => {
      match call.params.get("src") {
        Some(StringParam(v)) => assert_eq(v, "say \"hello\"")
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "shortcode parse escape backslash" {
  match parse("image src=\"path\\\\file\" alt=\"test\"") {
    Ok(call) => {
      match call.params.get("src") {
        Some(StringParam(v)) => assert_eq(v, "path\\file")
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "shortcode parse escape fallthrough passes char through" {
  // \x is not a recognized escape, so 'x' is passed through literally
  match parse("image src=\"hello\\xworld\" alt=\"test\"") {
    Ok(call) => {
      match call.params.get("src") {
        Some(StringParam(v)) => assert_eq(v, "helloxworld")
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================
// parse_quoted_shortcode error paths (surface via parse())
// ============================================================

///|
test "shortcode parse unterminated escape" {
  // Real unterminated escape: backslash at end of input inside an open quote
  match parse("image src=\"\\") {
    Err(InvalidSyntax(msg)) => {
      assert_true(msg.contains("unterminated escape"))
    }
    _ => assert_true(false)
  }
}

///|
test "shortcode parse unterminated quoted value" {
  // Opening quote with no closing quote before end of input
  match parse("image src=\"no_end") {
    Err(InvalidSyntax(msg)) => {
      assert_true(msg.contains("unterminated quoted value"))
    }
    _ => assert_true(false)
  }
}

///|
test "shortcode parse expected value at end of input" {
  // key= at the very end of input with no value
  match parse("image src=") {
    Err(InvalidSyntax(msg)) => {
      assert_true(msg.contains("expected value"))
    }
    _ => assert_true(false)
  }
}

// ============================================================
// parse() error paths
// ============================================================

///|
test "shortcode parse empty string" {
  match parse("") {
    Err(InvalidSyntax(msg)) => assert_eq(msg, "empty shortcode")
    _ => assert_true(false)
  }
}

///|
test "shortcode parse missing shortcode name" {
  // parse_name_shortcode reads ident chars; '/' is not ident, so name is "".
  // The "closing shortcode is not a call" branch is dead code because
  // parse_name_shortcode never produces a name starting with '/'.
  // Instead, "/foo" produces name="" → "missing shortcode name".
  match parse("/foo") {
    Err(InvalidSyntax(msg)) => {
      assert_eq(msg, "missing shortcode name")
    }
    _ => assert_true(false)
  }
}

///|
test "shortcode parse missing equals after key" {
  match parse("image src") {
    Err(InvalidSyntax(msg)) => {
      assert_true(msg.contains("expected '=' after parameter 'src'"))
    }
    _ => assert_true(false)
  }
}

///|
test "shortcode parse all-whitespace input" {
  match parse("   ") {
    Err(InvalidSyntax(msg)) => assert_eq(msg, "empty shortcode")
    _ => assert_true(false)
  }
}

///|
test "shortcode parse invalid parameter key" {
  // After parsing the name, if the next non-ws char is not an ident start
  // (e.g. '='), parse_name_shortcode returns "", triggering invalid key
  match parse("image =bad") {
    Err(InvalidSyntax(msg)) => {
      assert_eq(msg, "invalid parameter key")
    }
    _ => assert_true(false)
  }
}

// ============================================================
// Remaining callout types: warning, tip, danger
// ============================================================

///|
test "shortcode render callout warning" {
  let params : Map[String, ShortcodeParam] = Map::new()
  params.set("type", StringParam("warning"))
  params.set("title", StringParam("Warning Title"))
  params.set("body", StringParam("Warning body"))
  let call : ShortcodeCall = { name: "callout", params }
  match render(call) {
    Ok(html) => {
      assert_true(html.contains("callout-warning"))
      assert_true(html.contains("Warning Title"))
      assert_true(html.contains("Warning body"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "shortcode render callout tip" {
  let params : Map[String, ShortcodeParam] = Map::new()
  params.set("type", StringParam("tip"))
  params.set("title", StringParam("Tip Title"))
  params.set("body", StringParam("Tip body"))
  let call : ShortcodeCall = { name: "callout", params }
  match render(call) {
    Ok(html) => {
      assert_true(html.contains("callout-tip"))
      assert_true(html.contains("Tip Title"))
      assert_true(html.contains("Tip body"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "shortcode render callout danger" {
  let params : Map[String, ShortcodeParam] = Map::new()
  params.set("type", StringParam("danger"))
  params.set("title", StringParam("Danger Title"))
  params.set("body", StringParam("Danger body"))
  let call : ShortcodeCall = { name: "callout", params }
  match render(call) {
    Ok(html) => {
      assert_true(html.contains("callout-danger"))
      assert_true(html.contains("Danger Title"))
      assert_true(html.contains("Danger body"))
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================
// Optional param omission paths
// ============================================================

///|
test "shortcode render video without poster" {
  let params : Map[String, ShortcodeParam] = Map::new()
  params.set("src", StringParam("/vid/a.mp4"))
  let call : ShortcodeCall = { name: "video", params }
  match render(call) {
    Ok(html) => {
      assert_true(html.contains("<video"))
      assert_true(html.contains("controls"))
      assert_true(!html.contains("poster="))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "shortcode render figure without link" {
  let params : Map[String, ShortcodeParam] = Map::new()
  params.set("src", StringParam("/img/f.png"))
  params.set("alt", StringParam("figure"))
  params.set("caption", StringParam("A caption"))
  let call : ShortcodeCall = { name: "figure", params }
  match render(call) {
    Ok(html) => {
      assert_true(html.contains("<figure"))
      assert_true(!html.contains("<a href="))
      assert_true(html.contains("<figcaption>A caption</figcaption>"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "shortcode render figure without caption" {
  let params : Map[String, ShortcodeParam] = Map::new()
  params.set("src", StringParam("/img/f.png"))
  params.set("alt", StringParam("figure"))
  params.set("link", StringParam("/detail"))
  let call : ShortcodeCall = { name: "figure", params }
  match render(call) {
    Ok(html) => {
      assert_true(html.contains("<figure"))
      assert_true(html.contains("<a href=\"/detail\""))
      assert_true(!html.contains("figcaption"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "shortcode render figure without link or caption" {
  let params : Map[String, ShortcodeParam] = Map::new()
  params.set("src", StringParam("/img/f.png"))
  params.set("alt", StringParam("figure"))
  let call : ShortcodeCall = { name: "figure", params }
  match render(call) {
    Ok(html) => {
      assert_true(html.contains("<figure"))
      assert_true(!html.contains("<a href="))
      assert_true(!html.contains("figcaption"))
      assert_true(html.contains("</figure>"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "shortcode render image without caption or width" {
  let params : Map[String, ShortcodeParam] = Map::new()
  params.set("src", StringParam("/img/a.png"))
  params.set("alt", StringParam("simple"))
  let call : ShortcodeCall = { name: "image", params }
  match render(call) {
    Ok(html) => {
      assert_true(html.contains("<img"))
      assert_true(!html.contains("figcaption"))
      assert_true(!html.contains("width="))
      assert_true(!html.contains("<figure"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "shortcode render image with caption but no width" {
  let params : Map[String, ShortcodeParam] = Map::new()
  params.set("src", StringParam("/img/a.png"))
  params.set("alt", StringParam("captioned"))
  params.set("caption", StringParam("Photo caption"))
  let call : ShortcodeCall = { name: "image", params }
  match render(call) {
    Ok(html) => {
      assert_true(html.contains("<figure class=\"sc-image\">"))
      assert_true(html.contains("figcaption"))
      assert_true(!html.contains("width="))
    }
    Err(_) => assert_true(false)
  }
}