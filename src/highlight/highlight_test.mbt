///|
fn flatten_text(tokens : Array[Token]) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  while i < tokens.length() {
    buf.write_string(tokens[i].text)
    i = i + 1
  }
  buf.to_string()
}

///|
fn has_kind(tokens : Array[Token], kind : TokenKind) -> Bool {
  let mut i = 0
  while i < tokens.length() {
    match (tokens[i].kind, kind) {
      (Keyword, Keyword) => return true
      (Type, Type) => return true
      (StringLit, StringLit) => return true
      (CharLit, CharLit) => return true
      (Number, Number) => return true
      (Comment, Comment) => return true
      (Operator, Operator) => return true
      (Punct, Punct) => return true
      (Identifier, Identifier) => return true
      (Builtin, Builtin) => return true
      (Whitespace, Whitespace) => return true
      (Unknown, Unknown) => return true
      _ => ()
    }
    i = i + 1
  }
  false
}

///|
fn token_text(tokens : Array[Token], idx : Int) -> String {
  tokens[idx].text
}

///|
fn token_kind_is(tokens : Array[Token], idx : Int, kind : TokenKind) -> Bool {
  match (tokens[idx].kind, kind) {
    (Keyword, Keyword) => true
    (Type, Type) => true
    (StringLit, StringLit) => true
    (CharLit, CharLit) => true
    (Number, Number) => true
    (Comment, Comment) => true
    (Operator, Operator) => true
    (Punct, Punct) => true
    (Identifier, Identifier) => true
    (Builtin, Builtin) => true
    (Whitespace, Whitespace) => true
    (Unknown, Unknown) => true
    _ => false
  }
}

///|
fn find_token_index(tokens : Array[Token], text : String) -> Int {
  let mut i = 0
  while i < tokens.length() {
    if tokens[i].text == text {
      return i
    }
    i = i + 1
  }
  -1
}

///|
fn has_token(tokens : Array[Token], text : String, kind : TokenKind) -> Bool {
  let idx = find_token_index(tokens, text)
  idx >= 0 && token_kind_is(tokens, idx, kind)
}

///|
test "highlight moonbit tokenization basics" {
  let src = "pub fn demo() {\n" +
    "  let n = 42\n" +
    "  let t : Result = \"ok\"\n" +
    "  // line\n" +
    "  /* block */\n" +
    "}\n"
  let tokens = tokenize_moonbit(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_kind(tokens, Keyword))
  assert_true(has_kind(tokens, Type))
  assert_true(has_kind(tokens, Number))
  assert_true(has_kind(tokens, StringLit))
  assert_true(has_kind(tokens, Comment))
}

///|
test "highlight typescript supports decorators and template strings" {
  let src = "@sealed\n" +
    "export class User {\n" +
    "  name: string = `hi`\n" +
    "}\n"
  let tokens = tokenize_typescript(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_kind(tokens, Builtin))
  assert_true(has_kind(tokens, Keyword))
  assert_true(has_kind(tokens, StringLit))
}

///|
test "highlight moonbit keeps token boundaries around chars and numbers" {
  let src = "let c = 'x'\nlet hex = 0x2A\n"
  let tokens = tokenize_moonbit(src)
  assert_eq(flatten_text(tokens), src)
  assert_eq(token_text(tokens, 0), "let")
  assert_true(token_kind_is(tokens, 0, Keyword))
  assert_eq(token_text(tokens, 6), "'x'")
  assert_true(token_kind_is(tokens, 6, CharLit))
  assert_eq(token_text(tokens, 14), "0x2A")
  assert_true(token_kind_is(tokens, 14, Number))
}

///|
test "highlight typescript keeps decorators and dotted names separate" {
  let src = "@sealed\nconst value = user.name\n"
  let tokens = tokenize_typescript(src)
  assert_eq(flatten_text(tokens), src)
  assert_eq(token_text(tokens, 0), "@sealed")
  assert_true(token_kind_is(tokens, 0, Builtin))
  assert_eq(token_text(tokens, 2), "const")
  assert_true(token_kind_is(tokens, 2, Keyword))
  assert_eq(token_text(tokens, 8), "user")
  assert_true(token_kind_is(tokens, 8, Identifier))
  assert_eq(token_text(tokens, 9), ".")
  assert_true(token_kind_is(tokens, 9, Punct))
  assert_eq(token_text(tokens, 10), "name")
  assert_true(token_kind_is(tokens, 10, Identifier))
}

///|
test "highlight python supports triple quote" {
  let src = "def f():\n" +
    "    x = \"\"\"hello\nworld\"\"\"\n" +
    "    return x\n"
  let tokens = tokenize_python(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_kind(tokens, Keyword))
  assert_true(has_kind(tokens, StringLit))
}

///|
test "highlight bash supports variables and builtins" {
  let src = "export ROOT=/tmp\n" + "cd ${ROOT}\n" + "echo $ROOT\n"
  let tokens = tokenize_bash(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_kind(tokens, Keyword))
  assert_true(has_kind(tokens, Builtin))
}

///|
test "highlight go tokenization covers comments raw strings and numbers" {
  let src = "package main\n" +
    "func demo() {\n" +
    "  var msg = `hi`\n" +
    "  var r = 'x'\n" +
    "  var n = 0x2A\n" +
    "  // note\n" +
    "}\n"
  let tokens = tokenize_go(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "package", Keyword))
  assert_true(has_token(tokens, "func", Keyword))
  assert_true(has_token(tokens, "`hi`", StringLit))
  assert_true(has_token(tokens, "'x'", CharLit))
  assert_true(has_token(tokens, "0x2A", Number))
  assert_true(has_token(tokens, "// note", Comment))
}

///|
test "highlight c tokenization covers preprocessor chars and floats" {
  let src = "#include <stdio.h>\n" +
    "static int main() {\n" +
    "  char c = 'x';\n" +
    "  double n = 3.14;\n" +
    "  return 0;\n" +
    "}\n"
  let tokens = tokenize_c(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "#include <stdio.h>", Comment))
  assert_true(has_token(tokens, "static", Keyword))
  assert_true(has_token(tokens, "char", Keyword))
  assert_true(has_token(tokens, "'x'", CharLit))
  assert_true(has_token(tokens, "3.14", Number))
}

///|
test "highlight html tokenization covers tags attributes and comments" {
  let src = "<!DOCTYPE html>\n" +
    "<div class=\"hero\">Hello<span>!</span><!-- note --></div>\n"
  let tokens = tokenize_html(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "<!DOCTYPE html>", Comment))
  assert_true(has_token(tokens, "div", Keyword))
  assert_true(has_token(tokens, "class", Identifier))
  assert_true(has_token(tokens, "\"hero\"", StringLit))
  assert_true(has_token(tokens, "Hello", Unknown))
  assert_true(has_token(tokens, "<!-- note -->", Comment))
}

///|
test "highlight css tokenization covers selectors properties and values" {
  let src = "@media screen {\n" +
    "  .card {\n" +
    "    color: #abc123;\n" +
    "    margin: 12px;\n" +
    "  }\n" +
    "}\n"
  let tokens = tokenize_css(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "@media", Keyword))
  assert_true(has_token(tokens, "screen", Identifier))
  assert_true(has_token(tokens, "color", Keyword))
  assert_true(has_token(tokens, "#abc123", Number))
  assert_true(has_token(tokens, "12px", Number))
}

///|
test "highlight json tokenization covers strings literals and punctuation" {
  let src = "{\n  \"ok\": true,\n  \"n\": -1.2e3,\n  \"none\": null\n}\n"
  let tokens = tokenize_json(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "{", Punct))
  assert_true(has_token(tokens, "\"ok\"", StringLit))
  assert_true(has_token(tokens, ":", Punct))
  assert_true(has_token(tokens, "true", Keyword))
  assert_true(has_token(tokens, "-1.2e3", Number))
  assert_true(has_token(tokens, "null", Keyword))
}

///|
test "highlight plain emits unknown tokens" {
  let src = "a b\n"
  let tokens = tokenize_plain(src)
  assert_eq(tokens.length(), src.length())
  assert_eq(flatten_text(tokens), src)
  assert_true(has_kind(tokens, Unknown))
}

///|
test "highlight dispatch aliases" {
  let ts = highlight("ts", "const x = 1")
  let py = highlight("py", "def x():\n    return 1")
  let sh = highlight("sh", "echo hi")
  let go = highlight("go", "package main")
  let c = highlight("c", "int main() { return 0; }")
  let html = highlight("html", "<div></div>")
  let css = highlight("css", ".x { color: red; }")
  let json = highlight("json", "{\"ok\": true}")
  assert_true(has_kind(ts, Keyword))
  assert_true(has_kind(py, Keyword))
  assert_true(has_kind(sh, Keyword))
  assert_true(has_kind(go, Keyword))
  assert_true(has_kind(c, Keyword))
  assert_true(has_kind(html, Keyword))
  assert_true(has_kind(css, Keyword))
  assert_true(has_kind(json, Keyword))
}

///|
test "highlight unsupported language falls back plain" {
  let src = "weird syntax"
  let tokens = highlight("unknownlang", src)
  assert_eq(tokens.length(), src.length())
  assert_true(has_kind(tokens, Unknown))
}

///|
test "render highlighted keeps whitespace raw and escapes html" {
  let tokens : Array[Token] = [
    { kind: Keyword, text: "fn" },
    { kind: Whitespace, text: " " },
    { kind: Identifier, text: "x" },
    { kind: Whitespace, text: "\n" },
    { kind: StringLit, text: "\"<tag>\"" },
  ]
  let html = render_highlighted(tokens)
  assert_true(html.contains("<span class=\"hl-keyword\">fn</span>"))
  assert_true(html.contains("<span class=\"hl-identifier\">x</span>"))
  assert_true(html.contains("&lt;tag&gt;"))
}

///|
test "css classes include keyword rule" {
  let css = css_classes()
  assert_true(css.contains("hl-keyword"))
  assert_true(css.contains("hl-string"))
  assert_true(css.contains("pre.highlight"))
}
