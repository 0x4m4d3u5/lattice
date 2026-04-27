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

///|
test "highlight rust tokenization covers keywords strings lifetimes comments and types" {
  let src = "fn main() {\n" +
    "  let mut count: i32 = 42;\n" +
    "  let name: String = String::from(\"hello\");\n" +
    "  let lifetime: &'static str = \"static\";\n" +
    "  // line comment\n" +
    "  /* block comment */\n" +
    "  #[derive(Debug)]\n" +
    "  let ch = 'x';\n" +
    "  if true { return; }\n" +
    "}\n"
  let tokens = tokenize_rust(src)
  inspect(
    tokens,
    content=(
      #|[{kind: Keyword, text: "fn"}, {kind: Whitespace, text: " "}, {kind: Identifier, text: "main"}, {kind: Punct, text: "("}, {kind: Punct, text: ")"}, {kind: Whitespace, text: " "}, {kind: Punct, text: "{"}, {kind: Whitespace, text: "\n  "}, {kind: Keyword, text: "let"}, {kind: Whitespace, text: " "}, {kind: Keyword, text: "mut"}, {kind: Whitespace, text: " "}, {kind: Identifier, text: "count"}, {kind: Punct, text: ":"}, {kind: Whitespace, text: " "}, {kind: Identifier, text: "i32"}, {kind: Whitespace, text: " "}, {kind: Operator, text: "="}, {kind: Whitespace, text: " "}, {kind: Number, text: "42"}, {kind: Punct, text: ";"}, {kind: Whitespace, text: "\n  "}, {kind: Keyword, text: "let"}, {kind: Whitespace, text: " "}, {kind: Identifier, text: "name"}, {kind: Punct, text: ":"}, {kind: Whitespace, text: " "}, {kind: Type, text: "String"}, {kind: Whitespace, text: " "}, {kind: Operator, text: "="}, {kind: Whitespace, text: " "}, {kind: Type, text: "String"}, {kind: Punct, text: ":"}, {kind: Punct, text: ":"}, {kind: Identifier, text: "from"}, {kind: Punct, text: "("}, {kind: StringLit, text: "\"hello\""}, {kind: Punct, text: ")"}, {kind: Punct, text: ";"}, {kind: Whitespace, text: "\n  "}, {kind: Keyword, text: "let"}, {kind: Whitespace, text: " "}, {kind: Identifier, text: "lifetime"}, {kind: Punct, text: ":"}, {kind: Whitespace, text: " "}, {kind: Operator, text: "&"}, {kind: Keyword, text: "'static"}, {kind: Whitespace, text: " "}, {kind: Identifier, text: "str"}, {kind: Whitespace, text: " "}, {kind: Operator, text: "="}, {kind: Whitespace, text: " "}, {kind: StringLit, text: "\"static\""}, {kind: Punct, text: ";"}, {kind: Whitespace, text: "\n  "}, {kind: Comment, text: "// line comment"}, {kind: Whitespace, text: "\n  "}, {kind: Comment, text: "/* block comment */"}, {kind: Whitespace, text: "\n  "}, {kind: Comment, text: "#[derive(Debug)]"}, {kind: Whitespace, text: "\n  "}, {kind: Keyword, text: "let"}, {kind: Whitespace, text: " "}, {kind: Identifier, text: "ch"}, {kind: Whitespace, text: " "}, {kind: Operator, text: "="}, {kind: Whitespace, text: " "}, {kind: CharLit, text: "'x'"}, {kind: Punct, text: ";"}, {kind: Whitespace, text: "\n  "}, {kind: Keyword, text: "if"}, {kind: Whitespace, text: " "}, {kind: Keyword, text: "true"}, {kind: Whitespace, text: " "}, {kind: Punct, text: "{"}, {kind: Whitespace, text: " "}, {kind: Keyword, text: "return"}, {kind: Punct, text: ";"}, {kind: Whitespace, text: " "}, {kind: Punct, text: "}"}, {kind: Whitespace, text: "\n"}, {kind: Punct, text: "}"}, {kind: Whitespace, text: "\n"}]
    ),
  )
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "fn", Keyword))
  assert_true(has_token(tokens, "let", Keyword))
  assert_true(has_token(tokens, "mut", Keyword))
  assert_true(has_token(tokens, "if", Keyword))
  assert_true(has_token(tokens, "true", Keyword))
  assert_true(has_token(tokens, "return", Keyword))
  assert_true(has_token(tokens, "String", Type))
  assert_true(has_token(tokens, "\"hello\"", StringLit))
  assert_true(has_token(tokens, "'static", Keyword))
  assert_true(has_token(tokens, "// line comment", Comment))
  assert_true(has_token(tokens, "/* block comment */", Comment))
  assert_true(has_token(tokens, "#[derive(Debug)]", Comment))
  assert_true(has_token(tokens, "'x'", CharLit))
  assert_true(has_token(tokens, "42", Number))
}

///|
test "highlight sql tokenization covers keywords strings comments and numbers" {
  let src = "SELECT id, name FROM users\n" +
    "WHERE age > 25 AND active = true\n" +
    "ORDER BY name ASC\n" +
    "LIMIT 10;\n" +
    "-- single line comment\n" +
    "/* block comment */\n" +
    "INSERT INTO users VALUES ('Alice', 30);\n"
  let tokens = tokenize_sql(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "SELECT", Keyword))
  assert_true(has_token(tokens, "FROM", Keyword))
  assert_true(has_token(tokens, "WHERE", Keyword))
  assert_true(has_token(tokens, "AND", Keyword))
  assert_true(has_token(tokens, "ORDER", Keyword))
  assert_true(has_token(tokens, "BY", Keyword))
  assert_true(has_token(tokens, "LIMIT", Keyword))
  assert_true(has_token(tokens, "INSERT", Keyword))
  assert_true(has_token(tokens, "INTO", Keyword))
  assert_true(has_token(tokens, "VALUES", Keyword))
  assert_true(has_token(tokens, "-- single line comment", Comment))
  assert_true(has_token(tokens, "/* block comment */", Comment))
  assert_true(has_token(tokens, "'Alice'", StringLit))
  assert_true(has_token(tokens, "10", Number))
  assert_true(has_token(tokens, "30", Number))
}

///|
test "highlight dispatch includes rust and sql" {
  let rust = highlight("rust", "fn main() { let x = 1; }")
  let rs = highlight("rs", "fn main() { let x = 1; }")
  let sql = highlight("sql", "SELECT * FROM users")
  assert_true(has_kind(rust, Keyword))
  assert_true(has_kind(rs, Keyword))
  assert_true(has_kind(sql, Keyword))
}

///|
test "highlight toml tokenization covers tables keys comments and booleans" {
  let src = "# Config\n" +
    "[server]\n" +
    "host = \"localhost\"\n" +
    "port = 8080\n" +
    "debug = true\n" +
    "\n" +
    "[[items]]\n" +
    "name = 'first'\n"
  let tokens = tokenize_toml(src)
  assert_true(has_kind(tokens, Keyword))
  assert_true(has_kind(tokens, Identifier))
  assert_true(has_kind(tokens, StringLit))
  assert_true(has_kind(tokens, Number))
  assert_true(has_kind(tokens, Comment))
}

///|
test "highlight yaml tokenization covers document markers anchors and scalars" {
  let src = "---\n" +
    "name: test\n" +
    "enabled: true\n" +
    "items:\n" +
    "  - one\n" +
    "  - two\n" +
    "ref: &anchor\n" +
    "alias: *anchor\n" +
    "value: null\n"
  let tokens = tokenize_yaml(src)
  assert_true(has_kind(tokens, Keyword))
  assert_true(has_kind(tokens, Identifier))
  assert_true(has_kind(tokens, Punct))
}

///|
test "highlight dispatch includes toml and yaml" {
  let toml = highlight("toml", "[section]\nkey = 'value'")
  let yaml = highlight("yaml", "key: value\nflag: true")
  let yml = highlight("yml", "key: value")
  assert_true(has_kind(toml, Keyword))
  assert_true(has_kind(yaml, Identifier))
  assert_true(has_kind(yml, Identifier))
}

/// ============================================================
/// Comprehensive edge-case and boundary tests
/// ============================================================

///|
test "highlight lossless roundtrip moonbit with special characters" {
  let src = "fn demo() -> String {\n" +
    "  let s = \"hello\\nworld\\t!\"\n" +
    "  let c = '\\\\'\n" +
    "  let hex = 0xFF\n" +
    "  let bin = 0b1010\n" +
    "  // comment with <tag> & \"quotes\"\n" +
    "  /* block * comment */\n" +
    "  let n = 42\n" +
    "}\n"
  let tokens = tokenize_moonbit(src)
  assert_eq(flatten_text(tokens), src)
}

///|
test "highlight lossless roundtrip python with mixed content" {
  let src = "def f(x):\n" +
    "  # hash comment\n" +
    "  y = \"double 'quote' inside\"\n" +
    "  z = 'single \"quote\" inside'\n" +
    "  w = \"\"\"triple\nline\"\"\"\n" +
    "  return x + 1\n"
  let tokens = tokenize_python(src)
  assert_eq(flatten_text(tokens), src)
}

///|
test "highlight lossless roundtrip json with edge cases" {
  let src = "{\n" +
    "  \"escapes\": \"\\\"\\\\\\/\\b\\f\\n\\r\\t\",\n" +
    "  \"neg\": -42,\n" +
    "  \"exp\": 1.5e10,\n" +
    "  \"negexp\": -3.2E-5,\n" +
    "  \"bool\": true,\n" +
    "  \"nil\": null\n" +
    "}\n"
  let tokens = tokenize_json(src)
  assert_eq(flatten_text(tokens), src)
}

///|
test "highlight lossless roundtrip html with entities and nesting" {
  let src = "<div class=\"main\">\n" +
    "  <p>Hello &amp; world!</p>\n" +
    "  <!-- a comment -->\n" +
    "  <span id=\"x\">text</span>\n" +
    "</div>\n"
  let tokens = tokenize_html(src)
  assert_eq(flatten_text(tokens), src)
}

///|
test "highlight lossless roundtrip css with at-rules and colors" {
  let src = "@media (min-width: 768px) {\n" +
    "  .hero {\n" +
    "    background: #1a2b3c;\n" +
    "    color: #fff;\n" +
    "    font-size: 16px;\n" +
    "  }\n" +
    "  /* comment */\n" +
    "}\n"
  let tokens = tokenize_css(src)
  assert_eq(flatten_text(tokens), src)
}

///|
test "highlight lossless roundtrip sql with mixed keywords" {
  let src = "select id, name\n" +
    "from users\n" +
    "where active = true\n" +
    "  and age > 25\n" +
    "order by name asc\n" +
    "limit 10;\n" +
    "-- end\n"
  let tokens = tokenize_sql(src)
  assert_eq(flatten_text(tokens), src)
}

///|
test "highlight lossless roundtrip bash with dollar vars" {
  let src = "#!/bin/bash\n" +
    "export NAME=\"world\"\n" +
    "echo \"Hello ${NAME}!\"\n" +
    "echo $HOME\n" +
    "cd /tmp\n"
  let tokens = tokenize_bash(src)
  assert_eq(flatten_text(tokens), src)
}

///|
test "highlight lossless roundtrip rust with lifetimes and attributes" {
  let src = "fn main() {\n" +
    "  let s: &'static str = \"hi\";\n" +
    "  #[derive(Debug)]\n" +
    "  struct Foo;\n" +
    "  let c = 'x';\n" +
    "}\n"
  let tokens = tokenize_rust(src)
  assert_eq(flatten_text(tokens), src)
}

///|
test "highlight lossless roundtrip toml with array of tables" {
  let src = "# config\n" +
    "[server]\n" +
    "host = \"localhost\"\n" +
    "port = 8080\n" +
    "debug = true\n" +
    "\n" +
    "[[items]]\n" +
    "name = 'first'\n"
  let tokens = tokenize_toml(src)
  assert_eq(flatten_text(tokens), src)
}

///|
test "highlight lossless roundtrip yaml with anchors and null" {
  let src = "---\n" +
    "name: test\n" +
    "ref: &anchor value\n" +
    "alias: *anchor\n" +
    "nil_val: null\n" +
    "bool_val: true\n" +
    "num: 3.14\n"
  let tokens = tokenize_yaml(src)
  assert_eq(flatten_text(tokens), src)
}

///|
test "highlight language_supported recognizes all aliases" {
  assert_true(language_supported("moonbit"))
  assert_true(language_supported("mbt"))
  assert_true(language_supported("typescript"))
  assert_true(language_supported("ts"))
  assert_true(language_supported("js"))
  assert_true(language_supported("python"))
  assert_true(language_supported("py"))
  assert_true(language_supported("bash"))
  assert_true(language_supported("sh"))
  assert_true(language_supported("shell"))
  assert_true(language_supported("zsh"))
  assert_true(language_supported("go"))
  assert_true(language_supported("c"))
  assert_true(language_supported("html"))
  assert_true(language_supported("css"))
  assert_true(language_supported("json"))
  assert_true(language_supported("rust"))
  assert_true(language_supported("rs"))
  assert_true(language_supported("sql"))
  assert_true(language_supported("toml"))
  assert_true(language_supported("yaml"))
  assert_true(language_supported("yml"))
}

///|
test "highlight language_supported rejects unknown languages" {
  assert_false(language_supported("ruby"))
  assert_false(language_supported("java"))
  assert_false(language_supported("cpp"))
  assert_false(language_supported("php"))
  assert_false(language_supported(""))
  assert_false(language_supported("Markdown"))
  assert_false(language_supported("unknown"))
}

///|
test "render highlighted escapes all HTML special characters" {
  let tokens : Array[Token] = [
    { kind: Identifier, text: "x<y>z" },
    { kind: Whitespace, text: " " },
    { kind: StringLit, text: "\"a&b\"" },
  ]
  let html = render_highlighted(tokens)
  assert_true(html.contains("x&lt;y&gt;z"))
  assert_true(html.contains("&amp;"))
  assert_true(html.contains("&amp;b"))
  // Whitespace should be raw, not in a span
  assert_false(html.contains("<span class=\"hl-whitespace\">"))
}

///|
test "render highlighted does not wrap whitespace in spans" {
  let tokens : Array[Token] = [
    { kind: Keyword, text: "fn" },
    { kind: Whitespace, text: "  \n\t " },
    { kind: Identifier, text: "demo" },
  ]
  let html = render_highlighted(tokens)
  assert_true(html.contains("<span class=\"hl-keyword\">fn</span>"))
  assert_true(html.contains("<span class=\"hl-identifier\">demo</span>"))
  // Whitespace should appear raw, not in a span
  assert_false(html.contains("hl-whitespace"))
}

///|
test "css_classes contains all expected class names" {
  let css = css_classes()
  assert_true(css.contains("hl-keyword"))
  assert_true(css.contains("hl-type"))
  assert_true(css.contains("hl-string"))
  assert_true(css.contains("hl-char"))
  assert_true(css.contains("hl-number"))
  assert_true(css.contains("hl-comment"))
  assert_true(css.contains("hl-operator"))
  assert_true(css.contains("hl-punct"))
  assert_true(css.contains("hl-identifier"))
  assert_true(css.contains("hl-builtin"))
  assert_true(css.contains("hl-unknown"))
  assert_true(css.contains("pre.highlight"))
}

///|
test "highlight empty input returns empty array for all tokenizers" {
  assert_eq(tokenize_moonbit("").length(), 0)
  assert_eq(tokenize_typescript("").length(), 0)
  assert_eq(tokenize_python("").length(), 0)
  assert_eq(tokenize_bash("").length(), 0)
  assert_eq(tokenize_go("").length(), 0)
  assert_eq(tokenize_c("").length(), 0)
  assert_eq(tokenize_html("").length(), 0)
  assert_eq(tokenize_css("").length(), 0)
  assert_eq(tokenize_json("").length(), 0)
  assert_eq(tokenize_rust("").length(), 0)
  assert_eq(tokenize_sql("").length(), 0)
  assert_eq(tokenize_toml("").length(), 0)
  assert_eq(tokenize_yaml("").length(), 0)
  assert_eq(tokenize_plain("").length(), 0)
}

///|
test "highlight moonbit classifies all keywords" {
  let src = "fn pub priv let match enum struct trait impl type derive test if else return for while break continue true false is as in raise try catch throw"
  let tokens = tokenize_moonbit(src)
  assert_true(has_token(tokens, "fn", Keyword))
  assert_true(has_token(tokens, "pub", Keyword))
  assert_true(has_token(tokens, "priv", Keyword))
  assert_true(has_token(tokens, "let", Keyword))
  assert_true(has_token(tokens, "match", Keyword))
  assert_true(has_token(tokens, "enum", Keyword))
  assert_true(has_token(tokens, "struct", Keyword))
  assert_true(has_token(tokens, "trait", Keyword))
  assert_true(has_token(tokens, "impl", Keyword))
  assert_true(has_token(tokens, "type", Keyword))
  assert_true(has_token(tokens, "derive", Identifier))
  assert_true(has_token(tokens, "test", Identifier))
}

///|
test "highlight moonbit hex number prefix" {
  let src = "let a = 0xFF\nlet b = 0x2A\n"
  let tokens = tokenize_moonbit(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "0xFF", Number))
  assert_true(has_token(tokens, "0x2A", Number))
}

///|
test "highlight moonbit block comment is lossless" {
  let src = "/* this is a\n   multiline comment */\nlet x = 1\n"
  let tokens = tokenize_moonbit(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "/* this is a\n   multiline comment */", Comment))
}

///|
test "highlight rust lifetime annotations" {
  let src = "fn foo<'a>(x: &'a str) -> &'a str {\n  x\n}\n"
  let tokens = tokenize_rust(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "'a", Keyword))
}

///|
test "highlight rust raw string literal r#" {
  let src = "let s = r#\"raw string\"#;\n"
  let tokens = tokenize_rust(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_kind(tokens, StringLit))
}

///|
test "highlight rust attribute bracket" {
  let src = "#[cfg(test)]\nfn main() {}\n"
  let tokens = tokenize_rust(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "#[cfg(test)]", Comment))
}

///|
test "highlight json null true false as keywords" {
  let src = "{\"a\": true, \"b\": false, \"c\": null}\n"
  let tokens = tokenize_json(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "true", Keyword))
  assert_true(has_token(tokens, "false", Keyword))
  assert_true(has_token(tokens, "null", Keyword))
}

///|
test "highlight json negative number and exponent" {
  let src = "{\"a\": -1, \"b\": 2.5e10, \"c\": -3.2E-5}\n"
  let tokens = tokenize_json(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "-1", Number))
  assert_true(has_token(tokens, "2.5e10", Number))
  assert_true(has_token(tokens, "-3.2E-5", Number))
}

///|
test "highlight html text between tags is unknown" {
  let src = "<p>Hello world</p>\n"
  let tokens = tokenize_html(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "Hello world", Unknown))
  assert_true(has_token(tokens, "p", Keyword))
}

///|
test "highlight html attribute names and values" {
  let src = "<div class=\"hero\" id=\"main\"></div>\n"
  let tokens = tokenize_html(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "class", Identifier))
  assert_true(has_token(tokens, "id", Identifier))
  assert_true(has_token(tokens, "\"hero\"", StringLit))
  assert_true(has_token(tokens, "\"main\"", StringLit))
}

///|
test "highlight python line comment with hash" {
  let src = "# this is a comment\nx = 1\n"
  let tokens = tokenize_python(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "# this is a comment", Comment))
}

///|
test "highlight python triple single quote string" {
  let src = "x = '''hello\nworld'''\n"
  let tokens = tokenize_python(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "'''hello\nworld'''", StringLit))
}

///|
test "highlight bash dollar brace variable expansion" {
  let src = "echo ${HOME}/path\n"
  let tokens = tokenize_bash(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "${HOME}", Builtin))
}

///|
test "highlight bash dollar variable without braces" {
  let src = "echo $HOME\n"
  let tokens = tokenize_bash(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "$HOME", Builtin))
}

///|
test "highlight go raw string backtick" {
  let src = "var s = `raw string`\n"
  let tokens = tokenize_go(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "`raw string`", StringLit))
}

///|
test "highlight css hex color values" {
  let src = ".x { color: #abc; background: #123456; }\n"
  let tokens = tokenize_css(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "#abc", Number))
  assert_true(has_token(tokens, "#123456", Number))
}

///|
test "highlight css at-keyword rules" {
  let src = "@media screen {}\n@keyframes fade {}\n"
  let tokens = tokenize_css(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "@media", Keyword))
  assert_true(has_token(tokens, "@keyframes", Keyword))
}

///|
test "highlight sql case insensitive keywords" {
  let src = "select * from users\n"
  let tokens = tokenize_sql(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "select", Keyword))
  assert_true(has_token(tokens, "from", Keyword))
}

///|
test "highlight sql single quoted strings" {
  let src = "SELECT * FROM users WHERE name = 'Alice'\n"
  let tokens = tokenize_sql(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "'Alice'", StringLit))
}

///|
test "highlight sql double dash comment" {
  let src = "-- this is a comment\nSELECT 1\n"
  let tokens = tokenize_sql(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "-- this is a comment", Comment))
}

///|
test "highlight toml array of tables" {
  let src = "[[items]]\nname = 'first'\n"
  let tokens = tokenize_toml(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "[[items]]", Keyword))
}

///|
test "highlight toml true false keywords" {
  let src = "a = true\nb = false\n"
  let tokens = tokenize_toml(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "true", Keyword))
  assert_true(has_token(tokens, "false", Keyword))
}

///|
test "highlight yaml document marker" {
  let src = "---\ntitle: test\n...\n"
  let tokens = tokenize_yaml(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "---", Keyword))
  assert_true(has_token(tokens, "...", Keyword))
}

///|
test "highlight yaml anchor and alias" {
  let src = "base: &default value\nref: *default\n"
  let tokens = tokenize_yaml(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "&default", Identifier))
  assert_true(has_token(tokens, "*default", Identifier))
}

///|
test "highlight yaml null scalar keyword" {
  let src = "x: null\ny: ~\n"
  let tokens = tokenize_yaml(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "null", Keyword))
  // ~ is not an ident-start character, so it is tokenized as Unknown
  assert_true(has_token(tokens, "~", Unknown))
}

///|
test "highlight typescript template literal backtick" {
  let src = "const s = `hello ${name}`\n"
  let tokens = tokenize_typescript(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_kind(tokens, StringLit))
}

///|
test "highlight typescript decorator annotation" {
  let src = "@injectable\n"
  let tokens = tokenize_typescript(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_token(tokens, "@injectable", Builtin))
}

///|
test "highlight render highlighted escapes ampersand in token text" {
  let tokens : Array[Token] = [
    { kind: Operator, text: "&&" },
    { kind: Whitespace, text: " " },
    { kind: StringLit, text: "\"<b>&</b>\"" },
  ]
  let html = render_highlighted(tokens)
  assert_true(html.contains("&amp;&amp;"))
  assert_true(html.contains("&lt;b&gt;"))
  assert_true(html.contains("&amp;"))
}
