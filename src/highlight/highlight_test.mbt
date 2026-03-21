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
  inspect(tokens, content=(
    #|[{kind: Keyword, text: "fn"}, {kind: Whitespace, text: " "}, {kind: Identifier, text: "main"}, {kind: Punct, text: "("}, {kind: Punct, text: ")"}, {kind: Whitespace, text: " "}, {kind: Punct, text: "{"}, {kind: Whitespace, text: "\n  "}, {kind: Keyword, text: "let"}, {kind: Whitespace, text: " "}, {kind: Keyword, text: "mut"}, {kind: Whitespace, text: " "}, {kind: Identifier, text: "count"}, {kind: Punct, text: ":"}, {kind: Whitespace, text: " "}, {kind: Identifier, text: "i32"}, {kind: Whitespace, text: " "}, {kind: Operator, text: "="}, {kind: Whitespace, text: " "}, {kind: Number, text: "42"}, {kind: Punct, text: ";"}, {kind: Whitespace, text: "\n  "}, {kind: Keyword, text: "let"}, {kind: Whitespace, text: " "}, {kind: Identifier, text: "name"}, {kind: Punct, text: ":"}, {kind: Whitespace, text: " "}, {kind: Type, text: "String"}, {kind: Whitespace, text: " "}, {kind: Operator, text: "="}, {kind: Whitespace, text: " "}, {kind: Type, text: "String"}, {kind: Punct, text: ":"}, {kind: Punct, text: ":"}, {kind: Identifier, text: "from"}, {kind: Punct, text: "("}, {kind: StringLit, text: "\"hello\""}, {kind: Punct, text: ")"}, {kind: Punct, text: ";"}, {kind: Whitespace, text: "\n  "}, {kind: Keyword, text: "let"}, {kind: Whitespace, text: " "}, {kind: Identifier, text: "lifetime"}, {kind: Punct, text: ":"}, {kind: Whitespace, text: " "}, {kind: Operator, text: "&"}, {kind: Keyword, text: "'static"}, {kind: Whitespace, text: " "}, {kind: Identifier, text: "str"}, {kind: Whitespace, text: " "}, {kind: Operator, text: "="}, {kind: Whitespace, text: " "}, {kind: StringLit, text: "\"static\""}, {kind: Punct, text: ";"}, {kind: Whitespace, text: "\n  "}, {kind: Comment, text: "// line comment"}, {kind: Whitespace, text: "\n  "}, {kind: Comment, text: "/* block comment */"}, {kind: Whitespace, text: "\n  "}, {kind: Comment, text: "#[derive(Debug)]"}, {kind: Whitespace, text: "\n  "}, {kind: Keyword, text: "let"}, {kind: Whitespace, text: " "}, {kind: Identifier, text: "ch"}, {kind: Whitespace, text: " "}, {kind: Operator, text: "="}, {kind: Whitespace, text: " "}, {kind: CharLit, text: "'x'"}, {kind: Punct, text: ";"}, {kind: Whitespace, text: "\n  "}, {kind: Keyword, text: "if"}, {kind: Whitespace, text: " "}, {kind: Keyword, text: "true"}, {kind: Whitespace, text: " "}, {kind: Punct, text: "{"}, {kind: Whitespace, text: " "}, {kind: Keyword, text: "return"}, {kind: Punct, text: ";"}, {kind: Whitespace, text: " "}, {kind: Punct, text: "}"}, {kind: Whitespace, text: "\n"}, {kind: Punct, text: "}"}, {kind: Whitespace, text: "\n"}]

  ))
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
