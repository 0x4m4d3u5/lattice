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
} derive(Show, Eq, ToJson)

///|
pub(all) struct Token {
  kind : TokenKind
  text : String
} derive(Show, Eq, ToJson)

///|
fn is_pascal_case_ident(s : String) -> Bool {
  if s.length() == 0 {
    return false
  }
  let first = @strutil.char_at(s, 0)
  first >= 'A' && first <= 'Z'
}

///|
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

///|
fn equals_case_insensitive(a : String, b : String) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let mut i = 0
  while i < a.length() {
    let ca = @strutil.char_at(a, i)
    let cb = @strutil.char_at(b, i)
    let ca_lower = if ca >= 'A' && ca <= 'Z' {
      ca.to_int() + 32
    } else {
      ca.to_int()
    }
    let cb_lower = if cb >= 'A' && cb <= 'Z' {
      cb.to_int() + 32
    } else {
      cb.to_int()
    }
    if ca_lower != cb_lower {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn read_while(
  source : String,
  start : Int,
  pred : (Char) -> Bool,
  buf : StringBuilder,
) -> Int {
  let n = source.length()
  let mut i = start
  while i < n && pred(@strutil.char_at(source, i)) {
    buf.write_char(@strutil.char_at(source, i))
    i = i + 1
  }
  i
}

///|
fn push_token(
  tokens : Array[Token],
  kind : TokenKind,
  text : StringBuilder,
) -> Unit {
  let t = text.to_string()
  if t.length() > 0 {
    tokens.push({ kind, text: t })
  }
}

///|
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

///|
pub fn render_highlighted(tokens : Array[Token]) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < tokens.length() {
    let t = tokens[i]
    match t.kind {
      Whitespace => out.write_string(@strutil.escape_html_body(t.text))
      _ => {
        out.write_string("<span class=\"hl-")
        out.write_string(token_kind_class(t.kind))
        out.write_string("\">")
        out.write_string(@strutil.escape_html_body(t.text))
        out.write_string("</span>")
      }
    }
    i = i + 1
  }
  out.to_string()
}

///|
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

///|
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
  type_pascal_case : Bool,
) -> Array[Token] {
  let tokens : Array[Token] = []
  let n = source.length()
  let mut i = 0
  while i < n {
    let c = @strutil.char_at(source, i)

    if @strutil.is_whitespace(c) {
      let buf = StringBuilder::new()
      i = read_while(source, i, fn(ch) { @strutil.is_whitespace(ch) }, buf)
      push_token(tokens, TokenKind::Whitespace, buf)
      continue
    }

    if allow_hash_comment && c == '#' {
      let buf = StringBuilder::new()
      while i < n && @strutil.char_at(source, i) != '\n' {
        buf.write_char(@strutil.char_at(source, i))
        i = i + 1
      }
      push_token(tokens, TokenKind::Comment, buf)
      continue
    }

    match line_comment_1 {
      Some(prefix) =>
        if @strutil.starts_with_at(source, i, prefix) {
          let buf = StringBuilder::new()
          while i < n && @strutil.char_at(source, i) != '\n' {
            buf.write_char(@strutil.char_at(source, i))
            i = i + 1
          }
          push_token(tokens, TokenKind::Comment, buf)
          continue
        }
      None => ()
    }

    match block_comment_start {
      Some(open) =>
        match block_comment_end {
          Some(close) =>
            if @strutil.starts_with_at(source, i, open) {
              let buf = StringBuilder::new()
              let mut done = false
              while i < n {
                if @strutil.starts_with_at(source, i, close) {
                  let mut j = 0
                  while j < close.length() {
                    buf.write_char(@strutil.char_at(source, i + j))
                    j = j + 1
                  }
                  i = i + close.length()
                  done = true
                  break
                }
                buf.write_char(@strutil.char_at(source, i))
                i = i + 1
              }
              if !done {
                i = n
              }
              push_token(tokens, TokenKind::Comment, buf)
              continue
            }
          None => ()
        }
      None => ()
    }

    if allow_dollar_var && c == '$' {
      let buf = StringBuilder::new()
      buf.write_char(c)
      i = i + 1
      if i < n && @strutil.char_at(source, i) == '{' {
        buf.write_char('{')
        i = i + 1
        while i < n {
          let ch = @strutil.char_at(source, i)
          buf.write_char(ch)
          i = i + 1
          if ch == '}' {
            break
          }
        }
      } else {
        i = read_while(source, i, fn(ch) { @strutil.is_ident_part(ch) }, buf)
      }
      push_token(tokens, TokenKind::Builtin, buf)
      continue
    }

    if allow_decorator && c == '@' {
      let buf = StringBuilder::new()
      buf.write_char(c)
      i = i + 1
      i = read_while(source, i, fn(ch) { @strutil.is_ident_part(ch) }, buf)
      push_token(tokens, TokenKind::Builtin, buf)
      continue
    }

    if allow_triple_quote && i + 2 < n {
      if @strutil.starts_with_at(source, i, "\"\"\"") ||
        @strutil.starts_with_at(source, i, "'''") {
        let quote = @strutil.char_at(source, i)
        let buf = StringBuilder::new()
        buf.write_char(quote)
        buf.write_char(quote)
        buf.write_char(quote)
        i = i + 3
        while i < n {
          if i + 2 < n &&
            @strutil.char_at(source, i) == quote &&
            @strutil.char_at(source, i + 1) == quote &&
            @strutil.char_at(source, i + 2) == quote {
            buf.write_char(quote)
            buf.write_char(quote)
            buf.write_char(quote)
            i = i + 3
            break
          }
          let ch = @strutil.char_at(source, i)
          buf.write_char(ch)
          i = i + 1
          if ch == '\\' && i < n {
            buf.write_char(@strutil.char_at(source, i))
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
        let ch = @strutil.char_at(source, i)
        buf.write_char(ch)
        i = i + 1
        if ch == '\\' && i < n {
          buf.write_char(@strutil.char_at(source, i))
          i = i + 1
        } else if ch == quote {
          break
        }
      }
      let kind = if quote == '\'' {
        TokenKind::CharLit
      } else {
        TokenKind::StringLit
      }
      push_token(tokens, kind, buf)
      continue
    }

    if @strutil.is_digit(c) {
      let buf = StringBuilder::new()
      if c == '0' &&
        i + 1 < n &&
        (
          @strutil.char_at(source, i + 1) == 'x' ||
          @strutil.char_at(source, i + 1) == 'X'
        ) {
        buf.write_char('0')
        buf.write_char(@strutil.char_at(source, i + 1))
        i = i + 2
        i = read_while(
          source,
          i,
          fn(ch) { @strutil.is_hex_digit(ch) || ch == '_' },
          buf,
        )
      } else {
        i = read_while(
          source,
          i,
          fn(ch) { @strutil.is_digit(ch) || ch == '_' },
          buf,
        )
        if i < n && @strutil.char_at(source, i) == '.' {
          buf.write_char('.')
          i = i + 1
          i = read_while(
            source,
            i,
            fn(ch) { @strutil.is_digit(ch) || ch == '_' },
            buf,
          )
        }
      }
      push_token(tokens, TokenKind::Number, buf)
      continue
    }

    if @strutil.is_ident_start(c) {
      let buf = StringBuilder::new()
      i = read_while(source, i, fn(ch) { @strutil.is_ident_part(ch) }, buf)
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

    if @strutil.is_operator_char(c) {
      let buf = StringBuilder::new()
      i = read_while(source, i, fn(ch) { @strutil.is_operator_char(ch) }, buf)
      push_token(tokens, TokenKind::Operator, buf)
      continue
    }

    if @strutil.is_punct_char(c) {
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

///|
fn tokenize_number_general(
  source : String,
  start : Int,
  allow_octal_prefix : Bool,
  allow_exponent : Bool,
  allow_unit_suffix : Bool,
) -> (Token, Int) {
  let buf = StringBuilder::new()
  let n = source.length()
  let mut i = start
  if @strutil.char_at(source, i) == '-' {
    buf.write_char('-')
    i = i + 1
  }
  if i < n &&
    @strutil.char_at(source, i) == '0' &&
    i + 1 < n &&
    (
      @strutil.char_at(source, i + 1) == 'x' ||
      @strutil.char_at(source, i + 1) == 'X'
    ) {
    buf.write_char('0')
    buf.write_char(@strutil.char_at(source, i + 1))
    i = i + 2
    i = read_while(
      source,
      i,
      fn(ch) { @strutil.is_hex_digit(ch) || ch == '_' },
      buf,
    )
    return ({ kind: TokenKind::Number, text: buf.to_string() }, i)
  }
  if allow_octal_prefix &&
    i < n &&
    @strutil.char_at(source, i) == '0' &&
    i + 1 < n &&
    (
      @strutil.char_at(source, i + 1) == 'o' ||
      @strutil.char_at(source, i + 1) == 'O'
    ) {
    buf.write_char('0')
    buf.write_char(@strutil.char_at(source, i + 1))
    i = i + 2
    i = read_while(
      source,
      i,
      fn(ch) { @strutil.is_octal_digit(ch) || ch == '_' },
      buf,
    )
    return ({ kind: TokenKind::Number, text: buf.to_string() }, i)
  }
  i = read_while(source, i, fn(ch) { @strutil.is_digit(ch) || ch == '_' }, buf)
  if i < n &&
    @strutil.char_at(source, i) == '.' &&
    i + 1 < n &&
    @strutil.is_digit(@strutil.char_at(source, i + 1)) {
    buf.write_char('.')
    i = i + 1
    i = read_while(
      source,
      i,
      fn(ch) { @strutil.is_digit(ch) || ch == '_' },
      buf,
    )
  }
  if allow_exponent &&
    i < n &&
    (@strutil.char_at(source, i) == 'e' || @strutil.char_at(source, i) == 'E') {
    buf.write_char(@strutil.char_at(source, i))
    i = i + 1
    if i < n &&
      (@strutil.char_at(source, i) == '+' || @strutil.char_at(source, i) == '-') {
      buf.write_char(@strutil.char_at(source, i))
      i = i + 1
    }
    i = read_while(
      source,
      i,
      fn(ch) { @strutil.is_digit(ch) || ch == '_' },
      buf,
    )
  }
  if allow_unit_suffix {
    i = read_while(
      source,
      i,
      fn(ch) { @strutil.is_alpha(ch) || ch == '%' },
      buf,
    )
  }
  ({ kind: TokenKind::Number, text: buf.to_string() }, i)
}

///|
pub fn tokenize_moonbit(source : String) -> Array[Token] {
  let keywords = [
    "fn", "let", "pub", "priv", "struct", "enum", "type", "impl", "trait", "if",
    "else", "match", "return", "for", "while", "break", "continue", "true", "false",
    "is", "as", "in", "raise", "try", "catch", "throw",
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
    true,
  )
}

///|
pub fn tokenize_typescript(source : String) -> Array[Token] {
  let keywords = [
    "function", "const", "let", "var", "class", "interface", "type", "import", "export",
    "from", "return", "if", "else", "for", "while", "switch", "case", "break", "continue",
    "new", "this", "null", "undefined", "true", "false", "async", "await", "extends",
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
    false,
  )
}

///|
pub fn tokenize_python(source : String) -> Array[Token] {
  let keywords = [
    "def", "class", "import", "from", "return", "if", "elif", "else", "for", "while",
    "break", "continue", "pass", "True", "False", "None", "and", "or", "not", "in",
    "is", "lambda", "with", "as", "yield", "raise", "try", "except", "finally",
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
    false,
  )
}

///|
pub fn tokenize_bash(source : String) -> Array[Token] {
  let keywords = [
    "if", "then", "fi", "else", "elif", "for", "while", "do", "done", "case", "esac",
    "function", "return", "in", "echo", "export", "source",
  ]
  let builtins = [
    "cd", "ls", "mkdir", "rm", "cp", "mv", "cat", "grep", "awk", "sed", "find", "chmod",
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
    false,
  )
}

///|
pub fn tokenize_go(source : String) -> Array[Token] {
  let keywords = [
    "package", "import", "func", "var", "const", "type", "struct", "interface", "map",
    "chan", "go", "defer", "select", "case", "default", "if", "else", "for", "range",
    "switch", "return", "break", "continue", "fallthrough", "goto", "nil", "true",
    "false", "iota",
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
    true,
    false,
    true,
  )
}

///|
pub fn tokenize_c(source : String) -> Array[Token] {
  let tokens : Array[Token] = []
  let keywords = [
    "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue",
    "return", "goto", "typedef", "struct", "union", "enum", "void", "int", "char",
    "float", "double", "long", "short", "unsigned", "signed", "const", "static",
    "extern", "auto", "register", "volatile", "sizeof", "NULL",
  ]
  let n = source.length()
  let mut i = 0
  while i < n {
    let c = @strutil.char_at(source, i)
    if @strutil.is_whitespace(c) {
      let buf = StringBuilder::new()
      i = read_while(source, i, fn(ch) { @strutil.is_whitespace(ch) }, buf)
      push_token(tokens, TokenKind::Whitespace, buf)
      continue
    }
    if c == '#' {
      let buf = StringBuilder::new()
      while i < n && @strutil.char_at(source, i) != '\n' {
        buf.write_char(@strutil.char_at(source, i))
        i = i + 1
      }
      push_token(tokens, TokenKind::Comment, buf)
      continue
    }
    if @strutil.starts_with_at(source, i, "//") {
      let buf = StringBuilder::new()
      while i < n && @strutil.char_at(source, i) != '\n' {
        buf.write_char(@strutil.char_at(source, i))
        i = i + 1
      }
      push_token(tokens, TokenKind::Comment, buf)
      continue
    }
    if @strutil.starts_with_at(source, i, "/*") {
      let buf = StringBuilder::new()
      while i < n {
        if @strutil.starts_with_at(source, i, "*/") {
          buf.write_string("*/")
          i = i + 2
          break
        }
        buf.write_char(@strutil.char_at(source, i))
        i = i + 1
      }
      push_token(tokens, TokenKind::Comment, buf)
      continue
    }
    if c == '"' || c == '\'' {
      let quote = c
      let buf = StringBuilder::new()
      buf.write_char(quote)
      i = i + 1
      while i < n {
        let ch = @strutil.char_at(source, i)
        buf.write_char(ch)
        i = i + 1
        if ch == '\\' && i < n {
          buf.write_char(@strutil.char_at(source, i))
          i = i + 1
        } else if ch == quote {
          break
        }
      }
      let kind = if quote == '\'' {
        TokenKind::CharLit
      } else {
        TokenKind::StringLit
      }
      push_token(tokens, kind, buf)
      continue
    }
    if @strutil.is_digit(c) {
      let (token, next_i) = tokenize_number_general(
        source, i, false, true, false,
      )
      tokens.push(token)
      i = next_i
      continue
    }
    if @strutil.is_ident_start(c) {
      let buf = StringBuilder::new()
      i = read_while(source, i, fn(ch) { @strutil.is_ident_part(ch) }, buf)
      let word = buf.to_string()
      if is_member(word, keywords) {
        tokens.push({ kind: TokenKind::Keyword, text: word })
      } else {
        tokens.push({ kind: TokenKind::Identifier, text: word })
      }
      continue
    }
    if @strutil.is_operator_char(c) {
      let buf = StringBuilder::new()
      i = read_while(source, i, fn(ch) { @strutil.is_operator_char(ch) }, buf)
      push_token(tokens, TokenKind::Operator, buf)
      continue
    }
    if @strutil.is_punct_char(c) {
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

///|
pub fn tokenize_html(source : String) -> Array[Token] {
  let tokens : Array[Token] = []
  let n = source.length()
  let mut i = 0
  while i < n {
    if @strutil.starts_with_at(source, i, "<!--") {
      let buf = StringBuilder::new()
      while i < n {
        if @strutil.starts_with_at(source, i, "-->") {
          buf.write_string("-->")
          i = i + 3
          break
        }
        buf.write_char(@strutil.char_at(source, i))
        i = i + 1
      }
      push_token(tokens, TokenKind::Comment, buf)
      continue
    }
    if @strutil.starts_with_at(source, i, "<!DOCTYPE") ||
      @strutil.starts_with_at(source, i, "<!doctype") {
      let buf = StringBuilder::new()
      while i < n {
        let ch = @strutil.char_at(source, i)
        buf.write_char(ch)
        i = i + 1
        if ch == '>' {
          break
        }
      }
      push_token(tokens, TokenKind::Comment, buf)
      continue
    }
    let c = @strutil.char_at(source, i)
    if c == '<' {
      let open = StringBuilder::new()
      open.write_char('<')
      i = i + 1
      push_token(tokens, TokenKind::Punct, open)
      if i < n && @strutil.char_at(source, i) == '/' {
        let slash = StringBuilder::new()
        slash.write_char('/')
        i = i + 1
        push_token(tokens, TokenKind::Punct, slash)
      }
      if i < n && @strutil.is_ident_start(@strutil.char_at(source, i)) {
        let name = StringBuilder::new()
        i = read_while(
          source,
          i,
          fn(ch) { @strutil.is_ident_part(ch) || ch == '-' },
          name,
        )
        push_token(tokens, TokenKind::Keyword, name)
      }
      while i < n {
        let ch = @strutil.char_at(source, i)
        if @strutil.is_whitespace(ch) {
          let buf = StringBuilder::new()
          i = read_while(
            source,
            i,
            fn(inner) { @strutil.is_whitespace(inner) },
            buf,
          )
          push_token(tokens, TokenKind::Whitespace, buf)
          continue
        }
        if @strutil.starts_with_at(source, i, "/>") {
          let buf = StringBuilder::new()
          buf.write_string("/>")
          i = i + 2
          push_token(tokens, TokenKind::Punct, buf)
          break
        }
        if ch == '>' {
          let buf = StringBuilder::new()
          buf.write_char('>')
          i = i + 1
          push_token(tokens, TokenKind::Punct, buf)
          break
        }
        if @strutil.is_ident_start(ch) {
          let name = StringBuilder::new()
          i = read_while(
            source,
            i,
            fn(inner) { @strutil.is_ident_part(inner) || inner == '-' },
            name,
          )
          push_token(tokens, TokenKind::Identifier, name)
          continue
        }
        if ch == '=' {
          let buf = StringBuilder::new()
          buf.write_char('=')
          i = i + 1
          push_token(tokens, TokenKind::Operator, buf)
          continue
        }
        if ch == '"' {
          let buf = StringBuilder::new()
          buf.write_char('"')
          i = i + 1
          while i < n {
            let inner = @strutil.char_at(source, i)
            buf.write_char(inner)
            i = i + 1
            if inner == '"' {
              break
            }
          }
          push_token(tokens, TokenKind::StringLit, buf)
          continue
        }
        let buf = StringBuilder::new()
        buf.write_char(ch)
        i = i + 1
        push_token(tokens, TokenKind::Unknown, buf)
      }
      continue
    }
    let buf = StringBuilder::new()
    while i < n && @strutil.char_at(source, i) != '<' {
      buf.write_char(@strutil.char_at(source, i))
      i = i + 1
    }
    push_token(tokens, TokenKind::Unknown, buf)
  }
  tokens
}

///|
pub fn tokenize_css(source : String) -> Array[Token] {
  let tokens : Array[Token] = []
  let n = source.length()
  let mut i = 0
  let mut in_block = false
  let mut expect_value = false
  while i < n {
    if @strutil.starts_with_at(source, i, "/*") {
      let buf = StringBuilder::new()
      while i < n {
        if @strutil.starts_with_at(source, i, "*/") {
          buf.write_string("*/")
          i = i + 2
          break
        }
        buf.write_char(@strutil.char_at(source, i))
        i = i + 1
      }
      push_token(tokens, TokenKind::Comment, buf)
      continue
    }
    let c = @strutil.char_at(source, i)
    if @strutil.is_whitespace(c) {
      let buf = StringBuilder::new()
      i = read_while(source, i, fn(ch) { @strutil.is_whitespace(ch) }, buf)
      push_token(tokens, TokenKind::Whitespace, buf)
      continue
    }
    if c == '@' {
      let buf = StringBuilder::new()
      buf.write_char('@')
      i = i + 1
      i = read_while(
        source,
        i,
        fn(ch) { @strutil.is_ident_part(ch) || ch == '-' },
        buf,
      )
      push_token(tokens, TokenKind::Keyword, buf)
      continue
    }
    if c == '{' || c == '}' || c == ':' || c == ';' {
      let buf = StringBuilder::new()
      buf.write_char(c)
      i = i + 1
      push_token(tokens, TokenKind::Punct, buf)
      if c == '{' {
        in_block = true
        expect_value = false
      } else if c == '}' {
        in_block = false
        expect_value = false
      } else if c == ':' {
        expect_value = true
      } else {
        expect_value = false
      }
      continue
    }
    if c == '#' {
      let buf = StringBuilder::new()
      buf.write_char('#')
      i = i + 1
      i = read_while(source, i, fn(ch) { @strutil.is_hex_digit(ch) }, buf)
      push_token(tokens, TokenKind::Number, buf)
      continue
    }
    if c == '"' || c == '\'' {
      let quote = c
      let buf = StringBuilder::new()
      buf.write_char(quote)
      i = i + 1
      while i < n {
        let inner = @strutil.char_at(source, i)
        buf.write_char(inner)
        i = i + 1
        if inner == '\\' && i < n {
          buf.write_char(@strutil.char_at(source, i))
          i = i + 1
        } else if inner == quote {
          break
        }
      }
      push_token(tokens, TokenKind::StringLit, buf)
      continue
    }
    if @strutil.is_digit(c) ||
      (
        c == '-' &&
        i + 1 < n &&
        @strutil.is_digit(@strutil.char_at(source, i + 1))
      ) {
      let (token, next_i) = tokenize_number_general(
        source, i, false, true, true,
      )
      tokens.push(token)
      i = next_i
      continue
    }
    let buf = StringBuilder::new()
    while i < n {
      let inner = @strutil.char_at(source, i)
      if inner == '{' ||
        inner == '}' ||
        inner == ':' ||
        inner == ';' ||
        @strutil.is_whitespace(inner) {
        break
      }
      if @strutil.starts_with_at(source, i, "/*") {
        break
      }
      buf.write_char(inner)
      i = i + 1
    }
    let text = buf.to_string()
    if text.length() > 0 {
      if in_block && !expect_value {
        tokens.push({ kind: TokenKind::Keyword, text })
      } else if expect_value {
        tokens.push({ kind: TokenKind::StringLit, text })
      } else {
        tokens.push({ kind: TokenKind::Identifier, text })
      }
      continue
    }
    let unknown = StringBuilder::new()
    unknown.write_char(c)
    i = i + 1
    push_token(tokens, TokenKind::Unknown, unknown)
  }
  tokens
}

///|
pub fn tokenize_json(source : String) -> Array[Token] {
  let tokens : Array[Token] = []
  let n = source.length()
  let mut i = 0
  while i < n {
    let c = @strutil.char_at(source, i)
    if @strutil.is_whitespace(c) {
      let buf = StringBuilder::new()
      i = read_while(source, i, fn(ch) { @strutil.is_whitespace(ch) }, buf)
      push_token(tokens, TokenKind::Whitespace, buf)
      continue
    }
    if c == '"' {
      let buf = StringBuilder::new()
      buf.write_char('"')
      i = i + 1
      while i < n {
        let inner = @strutil.char_at(source, i)
        buf.write_char(inner)
        i = i + 1
        if inner == '\\' && i < n {
          buf.write_char(@strutil.char_at(source, i))
          i = i + 1
        } else if inner == '"' {
          break
        }
      }
      push_token(tokens, TokenKind::StringLit, buf)
      continue
    }
    if c == '{' || c == '}' || c == '[' || c == ']' || c == ',' || c == ':' {
      let buf = StringBuilder::new()
      buf.write_char(c)
      i = i + 1
      push_token(tokens, TokenKind::Punct, buf)
      continue
    }
    if @strutil.is_digit(c) ||
      (
        c == '-' &&
        i + 1 < n &&
        @strutil.is_digit(@strutil.char_at(source, i + 1))
      ) {
      let (token, next_i) = tokenize_number_general(
        source, i, false, true, false,
      )
      tokens.push(token)
      i = next_i
      continue
    }
    if @strutil.is_ident_start(c) {
      let buf = StringBuilder::new()
      i = read_while(source, i, fn(ch) { @strutil.is_ident_part(ch) }, buf)
      let word = buf.to_string()
      if word == "true" || word == "false" || word == "null" {
        tokens.push({ kind: TokenKind::Keyword, text: word })
      } else {
        tokens.push({ kind: TokenKind::Unknown, text: word })
      }
      continue
    }
    let buf = StringBuilder::new()
    buf.write_char(c)
    i = i + 1
    push_token(tokens, TokenKind::Unknown, buf)
  }
  tokens
}

///|
pub fn tokenize_rust(source : String) -> Array[Token] {
  let tokens : Array[Token] = []
  let keywords = [
    "if", "else", "while", "for", "loop", "break", "continue", "return", "match",
    "fn", "let", "mut", "const", "static", "struct", "enum", "trait", "impl", "type",
    "use", "mod", "pub", "crate", "super", "self", "Self", "async", "await", "move",
    "where", "in", "ref", "box", "dyn", "unsafe", "extern", "as", "true", "false",
  ]
  let n = source.length()
  let mut i = 0
  while i < n {
    let c = @strutil.char_at(source, i)
    if @strutil.is_whitespace(c) {
      let buf = StringBuilder::new()
      i = read_while(source, i, fn(ch) { @strutil.is_whitespace(ch) }, buf)
      push_token(tokens, TokenKind::Whitespace, buf)
      continue
    }
    if @strutil.starts_with_at(source, i, "//") {
      let buf = StringBuilder::new()
      while i < n && @strutil.char_at(source, i) != '\n' {
        buf.write_char(@strutil.char_at(source, i))
        i = i + 1
      }
      push_token(tokens, TokenKind::Comment, buf)
      continue
    }
    if @strutil.starts_with_at(source, i, "/*") {
      let buf = StringBuilder::new()
      while i < n {
        if @strutil.starts_with_at(source, i, "*/") {
          buf.write_string("*/")
          i = i + 2
          break
        }
        buf.write_char(@strutil.char_at(source, i))
        i = i + 1
      }
      push_token(tokens, TokenKind::Comment, buf)
      continue
    }
    if @strutil.starts_with_at(source, i, "#[") {
      let buf = StringBuilder::new()
      while i < n {
        buf.write_char(@strutil.char_at(source, i))
        i = i + 1
        if @strutil.char_at(source, i - 1) == ']' {
          break
        }
      }
      push_token(tokens, TokenKind::Comment, buf)
      continue
    }
    if @strutil.starts_with_at(source, i, "r#") {
      let buf = StringBuilder::new()
      let mut hash_count = 0
      buf.write_char('r')
      buf.write_char('#')
      i = i + 2
      while i < n && @strutil.char_at(source, i) == '#' {
        buf.write_char('#')
        hash_count = hash_count + 1
        i = i + 1
      }
      if i < n && @strutil.char_at(source, i) == '"' {
        buf.write_char('"')
        i = i + 1
        while i < n {
          let ch = @strutil.char_at(source, i)
          buf.write_char(ch)
          i = i + 1
          if ch == '"' {
            let mut found_end = true
            let mut j = 0
            while j < hash_count {
              if i + j >= n || @strutil.char_at(source, i + j) != '#' {
                found_end = false
                break
              }
              j = j + 1
            }
            if found_end {
              let mut k = 0
              while k < hash_count {
                buf.write_char('#')
                k = k + 1
              }
              i = i + hash_count
              break
            }
          }
        }
        push_token(tokens, TokenKind::StringLit, buf)
        continue
      }
    }
    if c == '"' {
      let buf = StringBuilder::new()
      buf.write_char('"')
      i = i + 1
      while i < n {
        let ch = @strutil.char_at(source, i)
        buf.write_char(ch)
        i = i + 1
        if ch == '\\' && i < n {
          buf.write_char(@strutil.char_at(source, i))
          i = i + 1
        } else if ch == '"' {
          break
        }
      }
      push_token(tokens, TokenKind::StringLit, buf)
      continue
    }
    if c == '\'' &&
      i + 1 < n &&
      @strutil.is_ident_start(@strutil.char_at(source, i + 1)) {
      let ident_start = i + 1
      let mut j = ident_start
      while j < n && @strutil.is_ident_part(@strutil.char_at(source, j)) {
        j = j + 1
      }
      if j >= n || @strutil.char_at(source, j) != '\'' {
        let buf = StringBuilder::new()
        buf.write_char('\'')
        i = read_while(
          source,
          i + 1,
          fn(ch) { @strutil.is_ident_part(ch) },
          buf,
        )
        push_token(tokens, TokenKind::Keyword, buf)
        continue
      }
    }
    if c == '\'' {
      let buf = StringBuilder::new()
      buf.write_char('\'')
      i = i + 1
      if i < n && @strutil.char_at(source, i) != '\'' {
        let ch = @strutil.char_at(source, i)
        buf.write_char(ch)
        i = i + 1
        if ch == '\\' && i < n {
          buf.write_char(@strutil.char_at(source, i))
          i = i + 1
        }
      }
      if i < n && @strutil.char_at(source, i) == '\'' {
        buf.write_char('\'')
        i = i + 1
      }
      push_token(tokens, TokenKind::CharLit, buf)
      continue
    }
    if @strutil.is_digit(c) {
      let (token, next_i) = tokenize_number_general(source, i, true, true, true)
      tokens.push(token)
      i = next_i
      continue
    }
    if @strutil.is_ident_start(c) {
      let buf = StringBuilder::new()
      i = read_while(source, i, fn(ch) { @strutil.is_ident_part(ch) }, buf)
      let word = buf.to_string()
      if is_member(word, keywords) {
        tokens.push({ kind: TokenKind::Keyword, text: word })
      } else if is_pascal_case_ident(word) {
        tokens.push({ kind: TokenKind::Type, text: word })
      } else {
        tokens.push({ kind: TokenKind::Identifier, text: word })
      }
      continue
    }
    if @strutil.is_operator_char(c) {
      let buf = StringBuilder::new()
      i = read_while(source, i, fn(ch) { @strutil.is_operator_char(ch) }, buf)
      push_token(tokens, TokenKind::Operator, buf)
      continue
    }
    if @strutil.is_punct_char(c) {
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

///|
pub fn tokenize_sql(source : String) -> Array[Token] {
  let tokens : Array[Token] = []
  let keywords = [
    "SELECT", "FROM", "WHERE", "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE",
    "MERGE", "CREATE", "ALTER", "DROP", "TABLE", "INDEX", "VIEW", "DATABASE", "SCHEMA",
    "JOIN", "INNER", "LEFT", "RIGHT", "FULL", "OUTER", "CROSS", "ON", "USING", "AND",
    "OR", "NOT", "IN", "LIKE", "BETWEEN", "IS", "NULL", "EXISTS", "GROUP", "BY",
    "ORDER", "HAVING", "LIMIT", "OFFSET", "DISTINCT", "BEGIN", "COMMIT", "ROLLBACK",
    "TRANSACTION", "COUNT", "SUM", "AVG", "MIN", "MAX", "COALESCE", "CASE", "WHEN",
    "THEN", "ELSE", "END",
  ]
  let n = source.length()
  let mut i = 0
  while i < n {
    let c = @strutil.char_at(source, i)
    if @strutil.is_whitespace(c) {
      let buf = StringBuilder::new()
      i = read_while(source, i, fn(ch) { @strutil.is_whitespace(ch) }, buf)
      push_token(tokens, TokenKind::Whitespace, buf)
      continue
    }
    if @strutil.starts_with_at(source, i, "--") {
      let buf = StringBuilder::new()
      while i < n && @strutil.char_at(source, i) != '\n' {
        buf.write_char(@strutil.char_at(source, i))
        i = i + 1
      }
      push_token(tokens, TokenKind::Comment, buf)
      continue
    }
    if @strutil.starts_with_at(source, i, "/*") {
      let buf = StringBuilder::new()
      while i < n {
        if @strutil.starts_with_at(source, i, "*/") {
          buf.write_string("*/")
          i = i + 2
          break
        }
        buf.write_char(@strutil.char_at(source, i))
        i = i + 1
      }
      push_token(tokens, TokenKind::Comment, buf)
      continue
    }
    if c == '\'' {
      let buf = StringBuilder::new()
      buf.write_char('\'')
      i = i + 1
      while i < n {
        let ch = @strutil.char_at(source, i)
        buf.write_char(ch)
        i = i + 1
        if ch == '\\' && i < n {
          buf.write_char(@strutil.char_at(source, i))
          i = i + 1
        } else if ch == '\'' {
          break
        }
      }
      push_token(tokens, TokenKind::StringLit, buf)
      continue
    }
    if c == '`' || c == '"' {
      let quote = c
      let buf = StringBuilder::new()
      buf.write_char(quote)
      i = i + 1
      while i < n {
        let ch = @strutil.char_at(source, i)
        buf.write_char(ch)
        i = i + 1
        if ch == '\\' && i < n {
          buf.write_char(@strutil.char_at(source, i))
          i = i + 1
        } else if ch == quote {
          break
        }
      }
      push_token(tokens, TokenKind::StringLit, buf)
      continue
    }
    if @strutil.is_digit(c) {
      let buf = StringBuilder::new()
      i = read_while(source, i, fn(ch) { @strutil.is_digit(ch) }, buf)
      if i < n && @strutil.char_at(source, i) == '.' {
        buf.write_char('.')
        i = i + 1
        i = read_while(source, i, fn(ch) { @strutil.is_digit(ch) }, buf)
      }
      push_token(tokens, TokenKind::Number, buf)
      continue
    }
    if @strutil.is_ident_start(c) {
      let buf = StringBuilder::new()
      i = read_while(source, i, fn(ch) { @strutil.is_ident_part(ch) }, buf)
      let word = buf.to_string()
      let mut found_keyword = false
      let mut j = 0
      while j < keywords.length() {
        if equals_case_insensitive(word, keywords[j]) {
          found_keyword = true
          break
        }
        j = j + 1
      }
      if found_keyword {
        tokens.push({ kind: TokenKind::Keyword, text: word })
      } else {
        tokens.push({ kind: TokenKind::Identifier, text: word })
      }
      continue
    }
    if @strutil.is_operator_char(c) {
      let buf = StringBuilder::new()
      i = read_while(source, i, fn(ch) { @strutil.is_operator_char(ch) }, buf)
      push_token(tokens, TokenKind::Operator, buf)
      continue
    }
    if @strutil.is_punct_char(c) {
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

///|
pub fn tokenize_toml(source : String) -> Array[Token] {
  let tokens : Array[Token] = []
  let keywords = ["true", "false"]
  let n = source.length()
  let mut i = 0
  while i < n {
    let c = @strutil.char_at(source, i)
    if @strutil.is_whitespace(c) {
      let buf = StringBuilder::new()
      i = read_while(source, i, fn(ch) { @strutil.is_whitespace(ch) }, buf)
      push_token(tokens, TokenKind::Whitespace, buf)
      continue
    }
    if c == '#' {
      let buf = StringBuilder::new()
      while i < n && @strutil.char_at(source, i) != '\n' {
        buf.write_char(@strutil.char_at(source, i))
        i = i + 1
      }
      push_token(tokens, TokenKind::Comment, buf)
      continue
    }
    if c == '\'' || c == '"' {
      let quote = c
      let buf = StringBuilder::new()
      buf.write_char(quote)
      i = i + 1
      while i < n {
        let ch = @strutil.char_at(source, i)
        buf.write_char(ch)
        i = i + 1
        if ch == '\\' && i < n {
          buf.write_char(@strutil.char_at(source, i))
          i = i + 1
        } else if ch == quote {
          break
        }
      }
      push_token(tokens, TokenKind::StringLit, buf)
      continue
    }
    if @strutil.is_digit(c) ||
      (
        c == '-' &&
        i + 1 < n &&
        @strutil.is_digit(@strutil.char_at(source, i + 1))
      ) {
      let buf = StringBuilder::new()
      i = read_while(
        source,
        i,
        fn(ch) { @strutil.is_digit(ch) || ch == '_' },
        buf,
      )
      if i < n && @strutil.char_at(source, i) == '.' {
        buf.write_char('.')
        i = i + 1
        i = read_while(
          source,
          i,
          fn(ch) { @strutil.is_digit(ch) || ch == '_' },
          buf,
        )
      }
      if i < n &&
        (
          @strutil.char_at(source, i) == 'e' ||
          @strutil.char_at(source, i) == 'E'
        ) {
        buf.write_char(@strutil.char_at(source, i))
        i = i + 1
        if i < n &&
          (
            @strutil.char_at(source, i) == '+' ||
            @strutil.char_at(source, i) == '-'
          ) {
          buf.write_char(@strutil.char_at(source, i))
          i = i + 1
        }
        i = read_while(
          source,
          i,
          fn(ch) { @strutil.is_digit(ch) || ch == '_' },
          buf,
        )
      }
      let text = buf.to_string()
      if text.contains("-") &&
        (
          text.contains("T") ||
          text.contains(" ") ||
          text.contains("Z") ||
          (text.contains("+") && text.length() > 3)
        ) {
        push_token(tokens, TokenKind::StringLit, buf)
      } else {
        push_token(tokens, TokenKind::Number, buf)
      }
      continue
    }
    if c == '[' {
      let buf = StringBuilder::new()
      buf.write_char('[')
      i = i + 1
      if i < n && @strutil.char_at(source, i) == '[' {
        buf.write_char('[')
        i = i + 1
        while i < n && @strutil.char_at(source, i) != ']' {
          buf.write_char(@strutil.char_at(source, i))
          i = i + 1
        }
        if i < n {
          buf.write_char(']')
          i = i + 1
        }
        if i < n && @strutil.char_at(source, i) == ']' {
          buf.write_char(']')
          i = i + 1
        }
      } else {
        while i < n && @strutil.char_at(source, i) != ']' {
          buf.write_char(@strutil.char_at(source, i))
          i = i + 1
        }
        if i < n {
          buf.write_char(']')
          i = i + 1
        }
      }
      push_token(tokens, TokenKind::Keyword, buf)
      continue
    }
    if @strutil.is_ident_start(c) {
      let buf = StringBuilder::new()
      i = read_while(
        source,
        i,
        fn(ch) { @strutil.is_ident_part(ch) || ch == '-' || ch == '_' },
        buf,
      )
      let word = buf.to_string()
      if is_member(word, keywords) {
        tokens.push({ kind: TokenKind::Keyword, text: word })
      } else {
        tokens.push({ kind: TokenKind::Identifier, text: word })
      }
      continue
    }
    if c == '=' || c == '.' {
      let buf = StringBuilder::new()
      buf.write_char(c)
      i = i + 1
      push_token(tokens, TokenKind::Operator, buf)
      continue
    }
    if c == '{' || c == '}' || c == ',' {
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

///|
pub fn tokenize_yaml(source : String) -> Array[Token] {
  let tokens : Array[Token] = []
  let keywords = ["true", "false", "yes", "no", "on", "off", "null", "~"]
  let n = source.length()
  let mut i = 0
  while i < n {
    let c = @strutil.char_at(source, i)
    if @strutil.is_whitespace(c) {
      let buf = StringBuilder::new()
      i = read_while(source, i, fn(ch) { @strutil.is_whitespace(ch) }, buf)
      push_token(tokens, TokenKind::Whitespace, buf)
      continue
    }
    if c == '#' {
      let buf = StringBuilder::new()
      while i < n && @strutil.char_at(source, i) != '\n' {
        buf.write_char(@strutil.char_at(source, i))
        i = i + 1
      }
      push_token(tokens, TokenKind::Comment, buf)
      continue
    }
    if @strutil.starts_with_at(source, i, "---") {
      let buf = StringBuilder::new()
      buf.write_string("---")
      i = i + 3
      push_token(tokens, TokenKind::Keyword, buf)
      continue
    }
    if @strutil.starts_with_at(source, i, "...") {
      let buf = StringBuilder::new()
      buf.write_string("...")
      i = i + 3
      push_token(tokens, TokenKind::Keyword, buf)
      continue
    }
    if c == '\'' || c == '"' {
      let quote = c
      let buf = StringBuilder::new()
      buf.write_char(quote)
      i = i + 1
      while i < n {
        let ch = @strutil.char_at(source, i)
        buf.write_char(ch)
        i = i + 1
        if ch == '\\' && i < n {
          buf.write_char(@strutil.char_at(source, i))
          i = i + 1
        } else if ch == quote {
          break
        }
      }
      push_token(tokens, TokenKind::StringLit, buf)
      continue
    }
    if c == '-' &&
      i + 1 < n &&
      @strutil.is_whitespace(@strutil.char_at(source, i + 1)) {
      let buf = StringBuilder::new()
      buf.write_char('-')
      i = i + 1
      push_token(tokens, TokenKind::Punct, buf)
      continue
    }
    if c == '|' || c == '>' {
      let buf = StringBuilder::new()
      buf.write_char(c)
      i = i + 1
      push_token(tokens, TokenKind::Punct, buf)
      continue
    }
    if c == '&' || c == '*' {
      let buf = StringBuilder::new()
      buf.write_char(c)
      i = i + 1
      i = read_while(source, i, fn(ch) { @strutil.is_ident_part(ch) }, buf)
      push_token(tokens, TokenKind::Identifier, buf)
      continue
    }
    if @strutil.is_digit(c) ||
      (
        c == '-' &&
        i + 1 < n &&
        @strutil.is_digit(@strutil.char_at(source, i + 1))
      ) {
      let buf = StringBuilder::new()
      if c == '-' {
        buf.write_char('-')
        i = i + 1
      }
      i = read_while(
        source,
        i,
        fn(ch) { @strutil.is_digit(ch) || ch == '_' },
        buf,
      )
      if i < n && @strutil.char_at(source, i) == '.' {
        buf.write_char('.')
        i = i + 1
        i = read_while(
          source,
          i,
          fn(ch) { @strutil.is_digit(ch) || ch == '_' },
          buf,
        )
      }
      if i < n &&
        (
          @strutil.char_at(source, i) == 'e' ||
          @strutil.char_at(source, i) == 'E'
        ) {
        buf.write_char(@strutil.char_at(source, i))
        i = i + 1
        if i < n &&
          (
            @strutil.char_at(source, i) == '+' ||
            @strutil.char_at(source, i) == '-'
          ) {
          buf.write_char(@strutil.char_at(source, i))
          i = i + 1
        }
        i = read_while(
          source,
          i,
          fn(ch) { @strutil.is_digit(ch) || ch == '_' },
          buf,
        )
      }
      push_token(tokens, TokenKind::Number, buf)
      continue
    }
    if @strutil.is_ident_start(c) {
      let buf = StringBuilder::new()
      i = read_while(
        source,
        i,
        fn(ch) { @strutil.is_ident_part(ch) || ch == '-' || ch == '_' },
        buf,
      )
      let word = buf.to_string()
      if is_member(word, keywords) {
        tokens.push({ kind: TokenKind::Keyword, text: word })
      } else {
        tokens.push({ kind: TokenKind::Identifier, text: word })
      }
      continue
    }
    if c == ':' {
      let buf = StringBuilder::new()
      buf.write_char(':')
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

///|
pub fn tokenize_plain(source : String) -> Array[Token] {
  let tokens : Array[Token] = []
  let mut i = 0
  while i < source.length() {
    let c = @strutil.char_at(source, i)
    let text = StringBuilder::new()
    text.write_char(c)
    tokens.push({ kind: TokenKind::Unknown, text: text.to_string() })
    i = i + 1
  }
  tokens
}

///|
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
  if l == "rs" {
    return "rust"
  }
  l
}

///|
pub fn highlight(lang : String, source : String) -> Array[Token] {
  match normalize_lang(lang) {
    "moonbit" => tokenize_moonbit(source)
    "mbt" => tokenize_moonbit(source)
    "typescript" => tokenize_typescript(source)
    "python" => tokenize_python(source)
    "bash" => tokenize_bash(source)
    "go" => tokenize_go(source)
    "c" => tokenize_c(source)
    "html" => tokenize_html(source)
    "css" => tokenize_css(source)
    "json" => tokenize_json(source)
    "rust" => tokenize_rust(source)
    "sql" => tokenize_sql(source)
    "toml" => tokenize_toml(source)
    "yaml" => tokenize_yaml(source)
    "yml" => tokenize_yaml(source)
    _ => tokenize_plain(source)
  }
}

///|
pub fn language_supported(lang : String) -> Bool {
  match normalize_lang(lang) {
    "moonbit" => true
    "mbt" => true
    "typescript" => true
    "python" => true
    "bash" => true
    "go" => true
    "c" => true
    "html" => true
    "css" => true
    "json" => true
    "rust" => true
    "sql" => true
    "toml" => true
    "yaml" => true
    "yml" => true
    _ => false
  }
}
