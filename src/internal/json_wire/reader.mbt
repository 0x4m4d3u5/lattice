///|
/// Compatibility reader for the versioned cache/manifest wire format.
/// Core JSON owns string decoding. The framing adapter retains the existing
/// ordered root fields, decimal integer tokens, restricted escapes, and entry
/// object trailing commas; a whole-document JSON decoder would change those.
pub struct Reader {
  source : String
  mut pos : Int
}

///|
pub(all) suberror WireError {
  WireError(String)
}

///|
pub fn Reader::Reader(source : String) -> Reader {
  { source, pos: 0, }
}

///|
fn Reader::peek(self : Reader) -> Char? {
  self.pos = @strutil.skip_ws(self.source, self.pos)
  if self.pos < self.source.length() {
    Some(@strutil.char_at(self.source, self.pos))
  } else {
    None
  }
}

///|
pub fn Reader::expect(self : Reader, expected : Char) -> Unit raise WireError {
  if self.peek() != Some(expected) {
    raise WireError("expected '" + expected.to_string() + "'")
  }
  self.pos += 1
}

///|
pub fn Reader::string(self : Reader) -> String raise WireError {
  if self.peek() != Some('"') {
    raise WireError("expected string")
  }
  self.pos += 1
  let token = StringBuilder()
  token.write_char('"')
  while self.pos < self.source.length() {
    let c = @strutil.char_at(self.source, self.pos)
    self.pos += 1
    if c == '"' {
      token.write_char('"')
      let decoded = @json.parse(token.to_string()[:]) catch {
        _ => raise WireError("invalid string")
      }
      guard decoded is String(value) else { raise WireError("expected string") }
      return value
    }
    if c == '\\' {
      if self.pos == self.source.length() {
        raise WireError("unterminated escape")
      }
      let escaped = @strutil.char_at(self.source, self.pos)
      self.pos += 1
      if escaped == 'u' {
        raise WireError("unicode escapes are not supported")
      }
      if !"\"\\/bfnrt".contains(escaped.to_string()) {
        raise WireError("invalid escape")
      }
      token.write_char('\\')
      token.write_char(escaped)
    } else if c.to_int() < 0x20 {
      // The legacy reader accepts raw controls. Normalize them for core's
      // strict decoder, using its stringifier rather than another escape table.
      let quoted = Json::string(c.to_string()).stringify()
      token.write_string(quoted[1:quoted.length() - 1].to_owned())
    } else {
      // Code-unit traversal preserves the wire reader's UTF-16 behavior.
      token.write_char(c)
    }
  }
  raise WireError("unterminated string")
}

///|
pub fn Reader::key(self : Reader, expected : String) -> Unit raise WireError {
  if self.string() != expected {
    raise WireError("expected '" + expected + "' field")
  }
  self.expect(':')
}

///|
pub fn Reader::integer(self : Reader, signed~ : Bool) -> Int64 raise WireError {
  ignore(self.peek())
  let start = self.pos
  if signed &&
    self.pos < self.source.length() &&
    @strutil.char_at(self.source, self.pos) == '-' {
    self.pos += 1
  }
  let digits = self.pos
  while self.pos < self.source.length() &&
        @strutil.is_digit(@strutil.char_at(self.source, self.pos)) {
    self.pos += 1
  }
  if self.pos == digits {
    raise WireError("expected integer")
  }
  let text = self.source[start:self.pos]
  @string.parse_int64(text, base=10) catch {
    _ => {
      // Preserve legacy wrapping for out-of-range persisted tokens. Normal
      // Int64 values are parsed directly from decimal text, never via Double.
      let mut value = 0L
      for i in digits..<self.pos {
        value = value * 10L +
          (@strutil.char_at(self.source, i).to_int() - '0'.to_int()).to_int64()
      }
      if digits != start {
        -value
      } else {
        value
      }
    }
  }
}

///|
pub fn Reader::fields(
  self : Reader,
  visit : (String) -> Unit raise WireError,
) -> Unit raise WireError {
  self.expect('{')
  while true {
    match self.peek() {
      None => raise WireError("unterminated entry object")
      Some('}') => {
        self.pos += 1
        return
      }
      _ => ()
    }
    let key = self.string()
    self.expect(':')
    visit(key)
    match self.peek() {
      None => raise WireError("unterminated entry object")
      Some('}') => {
        self.pos += 1
        return
      }
      Some(',') => self.pos += 1
      _ => raise WireError("expected ',' or '}' in entry object")
    }
  }
}

///|
pub fn[T] Reader::array(
  self : Reader,
  item : () -> T raise WireError,
) -> Array[T] raise WireError {
  self.expect('[')
  let values : Array[T] = []
  if self.peek() == Some(']') {
    self.pos += 1
    return values
  }
  while true {
    values.push(item())
    match self.peek() {
      Some(']') => {
        self.pos += 1
        return values
      }
      None => raise WireError("unterminated array")
      Some(',') => self.pos += 1
      _ => raise WireError("expected ',' or ']' in array")
    }
  }
  raise WireError("unterminated array")
}

///|
pub fn Reader::finish(self : Reader) -> Unit raise WireError {
  if self.peek() is Some(_) {
    raise WireError("unexpected trailing content")
  }
}
