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
  // Catches: optional_int_param returning Err(InvalidParamType) when the
  // param exists but is StringParam rather than IntParam.
  // width="800" parses as StringParam; width=800 parses as IntParam.
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
