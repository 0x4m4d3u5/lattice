///|
/// Syntax highlighting tokenization and HTML rendering for fenced code blocks.

pub(all) enum TokenKind {
  Keyword
  Type
  StringLit
  CharLit
  Number
  Comment
  Operator
  Punct
  Identifier
  Builtin
  Whitespace
  Unknown
}

pub(all) struct Token {
  kind : TokenKind
  text : String
}

fn char_at(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

fn starts_with_at(s : String, pos : Int, prefix : String) -> Bool {
  let plen = prefix.length()
  if pos + plen > s.length() {
    return false
  }
  let mut j = 0
  while j < plen {
    if char_at(s, pos + j) != char_at(prefix, j) {
      return false
    }
    j = j + 1
  }
  true
}

fn is_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

fn is_hex_digit(c : Char) -> Bool {
  (c >= '0' && c <= '9') ||
  (c >= 'a' && c <= 'f') ||
  (c >= 'A' && c <= 'F')
}

fn is_alpha(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

fn is_ident_start(c : Char) -> Bool {
  is_alpha(c) || c == '_'
}

fn is_ident_part(c : Char) -> Bool {
  is_ident_start(c) || is_digit(c)
}

fn is_pascal_case_ident(s : String) -> Bool {
  if s.length() == 0 {
    return false
  }
  let first = char_at(s, 0)
  first >= 'A' && first <= 'Z'
}

fn is_member(word : String, items : Array[String]) -> Bool {
  let mut i = 0
  while i < items.length() {
    if items[i] == word {
      return true
    }
    i = i + 1
  }
  false
}

fn push_token(tokens : Array[Token], kind : TokenKind, text : StringBuilder) -> Unit {
  let t = text.to_string()
  if t.length() > 0 {
    tokens.push({ kind, text: t })
  }
}

fn read_while(
  source : String,
  start : Int,
  pred : (Char) -> Bool,
  buf : StringBuilder
) -> Int {
  let n = source.length()
  let mut i = start
  while i < n && pred(char_at(source, i)) {
    buf.write_char(char_at(source, i))
    i = i + 1
  }
  i
}

fn escape_html(s : String) -> String {
  let out = StringBuilder::new()
  let n = s.length()
  let mut i = 0
  while i < n {
    let c = char_at(s, i)
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

fn token_kind_class(kind : TokenKind) -> String {
  match kind {
    Keyword => "keyword"
    Type => "type"
    StringLit => "string"
    CharLit => "char"
    Number => "number"
    Comment => "comment"
    Operator => "operator"
    Punct => "punct"
    Identifier => "identifier"
    Builtin => "builtin"
    Whitespace => "whitespace"
    Unknown => "unknown"
  }
}

pub fn render_highlighted(tokens : Array[Token]) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < tokens.length() {
    let t = tokens[i]
    match t.kind {
      Whitespace => out.write_string(escape_html(t.text))
      _ => {
        out.write_string("<span class=\"hl-")
        out.write_string(token_kind_class(t.kind))
        out.write_string("\">")
        out.write_string(escape_html(t.text))
        out.write_string("</span>")
      }
    }
    i = i + 1
  }
  out.to_string()
}

pub fn css_classes() -> String {
  "/* lattice highlight defaults */\n" +
  "pre.highlight { background: #0f172a; color: #e2e8f0; }\n" +
  ".hl-keyword { color: #93c5fd; font-weight: 600; }\n" +
  ".hl-type { color: #fca5a5; }\n" +
  ".hl-string { color: #86efac; }\n" +
  ".hl-char { color: #bef264; }\n" +
  ".hl-number { color: #fcd34d; }\n" +
  ".hl-comment { color: #94a3b8; font-style: italic; }\n" +
  ".hl-operator { color: #c4b5fd; }\n" +
  ".hl-punct { color: #e2e8f0; }\n" +
  ".hl-identifier { color: #e2e8f0; }\n" +
  ".hl-builtin { color: #67e8f9; }\n" +
  ".hl-unknown { color: #fda4af; }\n"
}

fn is_operator_char(c : Char) -> Bool {
  c == '+' ||
  c == '-' ||
  c == '*' ||
  c == '/' ||
  c == '%' ||
  c == '=' ||
  c == '!' ||
  c == '<' ||
  c == '>' ||
  c == '&' ||
  c == '|' ||
  c == '^' ||
  c == '~' ||
  c == '?'
}

fn is_punct_char(c : Char) -> Bool {
  c == '(' ||
  c == ')' ||
  c == '{' ||
  c == '}' ||
  c == '[' ||
  c == ']' ||
  c == ';' ||
  c == ',' ||
  c == '.' ||
  c == ':'
}

fn tokenize_with_rules(
  source : String,
  keywords : Array[String],
  builtins : Array[String],
  line_comment_1 : String?,
  block_comment_start : String?,
  block_comment_end : String?,
  allow_decorator : Bool,
  allow_dollar_var : Bool,
  allow_hash_comment : Bool,
  allow_single_quote_string : Bool,
  allow_double_quote_string : Bool,
  allow_backtick_string : Bool,
  allow_triple_quote : Bool,
  type_pascal_case : Bool
) -> Array[Token] {
  let tokens : Array[Token] = []
  let n = source.length()
  let mut i = 0
  while i < n {
    let c = char_at(source, i)

    if is_whitespace(c) {
      let buf = StringBuilder::new()
      i = read_while(source, i, fn(ch) { is_whitespace(ch) }, buf)
      push_token(tokens, TokenKind::Whitespace, buf)
      continue
    }

    if allow_hash_comment && c == '#' {
      let buf = StringBuilder::new()
      while i < n && char_at(source, i) != '\n' {
        buf.write_char(char_at(source, i))
        i = i + 1
      }
      push_token(tokens, TokenKind::Comment, buf)
      continue
    }

    match line_comment_1 {
      Some(prefix) => {
        if starts_with_at(source, i, prefix) {
          let buf = StringBuilder::new()
          while i < n && char_at(source, i) != '\n' {
            buf.write_char(char_at(source, i))
            i = i + 1
          }
          push_token(tokens, TokenKind::Comment, buf)
          continue
        }
      }
      None => ()
    }

    match block_comment_start {
      Some(open) => {
        match block_comment_end {
          Some(close) => {
            if starts_with_at(source, i, open) {
              let buf = StringBuilder::new()
              let mut done = false
              while i < n {
                if starts_with_at(source, i, close) {
                  let mut j = 0
                  while j < close.length() {
                    buf.write_char(char_at(source, i + j))
                    j = j + 1
                  }
                  i = i + close.length()
                  done = true
                  break
                }
                buf.write_char(char_at(source, i))
                i = i + 1
              }
              if not(done) {
                i = n
              }
              push_token(tokens, TokenKind::Comment, buf)
              continue
            }
          }
          None => ()
        }
      }
      None => ()
    }

    if allow_dollar_var && c == '$' {
      let buf = StringBuilder::new()
      buf.write_char(c)
      i = i + 1
      if i < n && char_at(source, i) == '{' {
        buf.write_char('{')
        i = i + 1
        while i < n {
          let ch = char_at(source, i)
          buf.write_char(ch)
          i = i + 1
          if ch == '}' {
            break
          }
        }
      } else {
        i = read_while(source, i, fn(ch) { is_ident_part(ch) }, buf)
      }
      push_token(tokens, TokenKind::Builtin, buf)
      continue
    }

    if allow_decorator && c == '@' {
      let buf = StringBuilder::new()
      buf.write_char(c)
      i = i + 1
      i = read_while(source, i, fn(ch) { is_ident_part(ch) }, buf)
      push_token(tokens, TokenKind::Builtin, buf)
      continue
    }

    if allow_triple_quote && i + 2 < n {
      if starts_with_at(source, i, "\"\"\"") || starts_with_at(source, i, "'''") {
        let quote = char_at(source, i)
        let buf = StringBuilder::new()
        buf.write_char(quote)
        buf.write_char(quote)
        buf.write_char(quote)
        i = i + 3
        while i < n {
          if i + 2 < n &&
            char_at(source, i) == quote &&
            char_at(source, i + 1) == quote &&
            char_at(source, i + 2) == quote {
            buf.write_char(quote)
            buf.write_char(quote)
            buf.write_char(quote)
            i = i + 3
            break
          }
          let ch = char_at(source, i)
          buf.write_char(ch)
          i = i + 1
          if ch == '\\' && i < n {
            buf.write_char(char_at(source, i))
            i = i + 1
          }
        }
        push_token(tokens, TokenKind::StringLit, buf)
        continue
      }
    }

    if (allow_single_quote_string && c == '\'') ||
      (allow_double_quote_string && c == '"') ||
      (allow_backtick_string && c == '`') {
      let quote = c
      let buf = StringBuilder::new()
      buf.write_char(quote)
      i = i + 1
      while i < n {
        let ch = char_at(source, i)
        buf.write_char(ch)
        i = i + 1
        if ch == '\\' && i < n {
          buf.write_char(char_at(source, i))
          i = i + 1
        } else if ch == quote {
          break
        }
      }
      let kind = if quote == '\'' { TokenKind::CharLit } else { TokenKind::StringLit }
      push_token(tokens, kind, buf)
      continue
    }

    if is_digit(c) {
      let buf = StringBuilder::new()
      if c == '0' && i + 1 < n && (char_at(source, i + 1) == 'x' || char_at(source, i + 1) == 'X') {
        buf.write_char('0')
        buf.write_char(char_at(source, i + 1))
        i = i + 2
        i = read_while(source, i, fn(ch) { is_hex_digit(ch) || ch == '_' }, buf)
      } else {
        i = read_while(source, i, fn(ch) { is_digit(ch) || ch == '_' }, buf)
        if i < n && char_at(source, i) == '.' {
          buf.write_char('.')
          i = i + 1
          i = read_while(source, i, fn(ch) { is_digit(ch) || ch == '_' }, buf)
        }
      }
      push_token(tokens, TokenKind::Number, buf)
      continue
    }

    if is_ident_start(c) {
      let buf = StringBuilder::new()
      i = read_while(source, i, fn(ch) { is_ident_part(ch) }, buf)
      let word = buf.to_string()
      if is_member(word, keywords) {
        tokens.push({ kind: TokenKind::Keyword, text: word })
      } else if is_member(word, builtins) {
        tokens.push({ kind: TokenKind::Builtin, text: word })
      } else if type_pascal_case && is_pascal_case_ident(word) {
        tokens.push({ kind: TokenKind::Type, text: word })
      } else {
        tokens.push({ kind: TokenKind::Identifier, text: word })
      }
      continue
    }

    if is_operator_char(c) {
      let buf = StringBuilder::new()
      i = read_while(source, i, fn(ch) { is_operator_char(ch) }, buf)
      push_token(tokens, TokenKind::Operator, buf)
      continue
    }

    if is_punct_char(c) {
      let buf = StringBuilder::new()
      buf.write_char(c)
      i = i + 1
      push_token(tokens, TokenKind::Punct, buf)
      continue
    }

    let buf = StringBuilder::new()
    buf.write_char(c)
    i = i + 1
    push_token(tokens, TokenKind::Unknown, buf)
  }
  tokens
}

pub fn tokenize_moonbit(source : String) -> Array[Token] {
  let keywords = [
    "fn",
    "let",
    "pub",
    "priv",
    "struct",
    "enum",
    "type",
    "impl",
    "trait",
    "if",
    "else",
    "match",
    "return",
    "for",
    "while",
    "break",
    "continue",
    "true",
    "false",
    "is",
    "as",
    "in",
    "raise",
    "try",
    "catch",
    "throw",
  ]
  tokenize_with_rules(
    source,
    keywords,
    [],
    Some("//"),
    Some("/*"),
    Some("*/"),
    false,
    false,
    false,
    true,
    true,
    false,
    false,
    true
  )
}

pub fn tokenize_typescript(source : String) -> Array[Token] {
  let keywords = [
    "function",
    "const",
    "let",
    "var",
    "class",
    "interface",
    "type",
    "import",
    "export",
    "from",
    "return",
    "if",
    "else",
    "for",
    "while",
    "switch",
    "case",
    "break",
    "continue",
    "new",
    "this",
    "null",
    "undefined",
    "true",
    "false",
    "async",
    "await",
    "extends",
    "implements",
  ]
  tokenize_with_rules(
    source,
    keywords,
    [],
    Some("//"),
    Some("/*"),
    Some("*/"),
    true,
    false,
    false,
    true,
    true,
    true,
    false,
    false
  )
}

pub fn tokenize_python(source : String) -> Array[Token] {
  let keywords = [
    "def",
    "class",
    "import",
    "from",
    "return",
    "if",
    "elif",
    "else",
    "for",
    "while",
    "break",
    "continue",
    "pass",
    "True",
    "False",
    "None",
    "and",
    "or",
    "not",
    "in",
    "is",
    "lambda",
    "with",
    "as",
    "yield",
    "raise",
    "try",
    "except",
    "finally",
  ]
  tokenize_with_rules(
    source,
    keywords,
    [],
    None,
    None,
    None,
    false,
    false,
    true,
    true,
    true,
    false,
    true,
    false
  )
}

pub fn tokenize_bash(source : String) -> Array[Token] {
  let keywords = [
    "if",
    "then",
    "fi",
    "else",
    "elif",
    "for",
    "while",
    "do",
    "done",
    "case",
    "esac",
    "function",
    "return",
    "in",
    "echo",
    "export",
    "source",
  ]
  let builtins = [
    "cd",
    "ls",
    "mkdir",
    "rm",
    "cp",
    "mv",
    "cat",
    "grep",
    "awk",
    "sed",
    "find",
    "chmod",
    "chown",
  ]
  tokenize_with_rules(
    source,
    keywords,
    builtins,
    None,
    None,
    None,
    false,
    true,
    true,
    true,
    true,
    false,
    false,
    false
  )
}

pub fn tokenize_plain(source : String) -> Array[Token] {
  let tokens : Array[Token] = []
  let mut i = 0
  while i < source.length() {
    let c = char_at(source, i)
    let text = StringBuilder::new()
    text.write_char(c)
    tokens.push({ kind: TokenKind::Unknown, text: text.to_string() })
    i = i + 1
  }
  tokens
}

fn normalize_lang(lang : String) -> String {
  let l = lang
  if l == "js" {
    return "typescript"
  }
  if l == "ts" {
    return "typescript"
  }
  if l == "py" {
    return "python"
  }
  if l == "sh" || l == "shell" || l == "zsh" {
    return "bash"
  }
  l
}

pub fn highlight(lang : String, source : String) -> Array[Token] {
  match normalize_lang(lang) {
    "moonbit" => tokenize_moonbit(source)
    "mbt" => tokenize_moonbit(source)
    "typescript" => tokenize_typescript(source)
    "python" => tokenize_python(source)
    "bash" => tokenize_bash(source)
    _ => tokenize_plain(source)
  }
}

pub fn language_supported(lang : String) -> Bool {
  match normalize_lang(lang) {
    "moonbit" => true
    "mbt" => true
    "typescript" => true
    "python" => true
    "bash" => true
    _ => false
  }
}
