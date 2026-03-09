fn flatten_text(tokens : Array[Token]) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  while i < tokens.length() {
    buf.write_string(tokens[i].text)
    i = i + 1
  }
  buf.to_string()
}

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
test "highlight moonbit tokenization basics" {
  let src =
    "pub fn demo() {\n" +
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
  let src =
    "@sealed\n" +
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
test "highlight python supports triple quote" {
  let src =
    "def f():\n" +
    "    x = \"\"\"hello\nworld\"\"\"\n" +
    "    return x\n"
  let tokens = tokenize_python(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_kind(tokens, Keyword))
  assert_true(has_kind(tokens, StringLit))
}

///|
test "highlight bash supports variables and builtins" {
  let src =
    "export ROOT=/tmp\n" +
    "cd ${ROOT}\n" +
    "echo $ROOT\n"
  let tokens = tokenize_bash(src)
  assert_eq(flatten_text(tokens), src)
  assert_true(has_kind(tokens, Keyword))
  assert_true(has_kind(tokens, Builtin))
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
  assert_true(has_kind(ts, Keyword))
  assert_true(has_kind(py, Keyword))
  assert_true(has_kind(sh, Keyword))
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
