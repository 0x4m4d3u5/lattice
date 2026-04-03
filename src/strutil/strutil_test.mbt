///|
/// Tests for strutil utility functions.

// ── strip_html_tags ───────────────────────────────────────────────────────────

///|
test "strip_html_tags removes simple tags" {
  inspect(strip_html_tags("<p>Hello world</p>"), content="Hello world")
}

///|
test "strip_html_tags collapses whitespace from tag replacement" {
  // Each tag is replaced with a space; adjacent spaces collapse
  let result = strip_html_tags("<h1>Title</h1><p>Body</p>")
  inspect(result.contains("Title"), content="true")
  inspect(result.contains("Body"), content="true")
}

///|
test "strip_html_tags decodes amp entity" {
  inspect(strip_html_tags("a &amp; b"), content="a & b")
}

///|
test "strip_html_tags decodes lt and gt entities" {
  inspect(strip_html_tags("&lt;em&gt;"), content="<em>")
}

///|
test "strip_html_tags decodes quot entity" {
  inspect(strip_html_tags("say &quot;hello&quot;"), content="say \"hello\"")
}

///|
test "strip_html_tags decodes apos entity" {
  inspect(strip_html_tags("it&apos;s"), content="it's")
}

///|
test "strip_html_tags decodes numeric apostrophe entity" {
  inspect(strip_html_tags("it&#39;s"), content="it's")
}

///|
test "strip_html_tags empty string" {
  inspect(strip_html_tags(""), content="")
}

///|
test "strip_html_tags plain text unchanged" {
  inspect(strip_html_tags("plain text here"), content="plain text here")
}

///|
test "strip_html_tags trims leading and trailing whitespace" {
  let result = strip_html_tags("<p>  text  </p>")
  inspect(result, content="text")
}

///|
test "strip_html_tags nested tags" {
  let result = strip_html_tags("<ul><li>item one</li><li>item two</li></ul>")
  inspect(result.contains("item one"), content="true")
  inspect(result.contains("item two"), content="true")
}

///|
test "strip_html_tags preserves text between tags" {
  let result = strip_html_tags("<p>first</p><p>second</p>")
  inspect(result.contains("first"), content="true")
  inspect(result.contains("second"), content="true")
}

///|
test "strip_html_tags collapses multiple internal spaces" {
  let result = strip_html_tags("  hello   world  ")
  inspect(result, content="hello world")
}
