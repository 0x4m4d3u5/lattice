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

///|
test "count_words_text empty string" {
  assert_eq(count_words_text(""), 0)
}

///|
test "count_words_text single word" {
  assert_eq(count_words_text("hello"), 1)
}

///|
test "count_words_text multiple words" {
  assert_eq(count_words_text("hello world foo bar"), 4)
}

///|
test "count_words_text tabs and newlines" {
  assert_eq(count_words_text("hello\tworld\nfoo\t\tbar\n\nbaz"), 5)
}

///|
test "count_words_text leading and trailing whitespace" {
  assert_eq(count_words_text("  hello world  "), 2)
}

///|
test "count_words_text multiple spaces between words" {
  assert_eq(count_words_text("hello   world"), 2)
}

///|
test "count_words_text only whitespace" {
  assert_eq(count_words_text("   \t\n  "), 0)
}

// ── escape_html_body ──────────────────────────────────────────────────────────

///|
test "escape_html_body encodes & < >" {
  assert_eq(escape_html_body("a & b"), "a &amp; b")
  assert_eq(escape_html_body("<em>"), "&lt;em&gt;")
  assert_eq(escape_html_body("a > b"), "a &gt; b")
}

///|
test "escape_html_body passes plain text unchanged" {
  assert_eq(escape_html_body("hello world"), "hello world")
  assert_eq(escape_html_body(""), "")
}

///|
test "escape_html_body does not encode double quotes" {
  assert_eq(escape_html_body("say \"hi\""), "say \"hi\"")
}

// ── escape_html_attr ─────────────────────────────────────────────────────────

///|
test "escape_html_attr encodes & < > and double quote" {
  assert_eq(escape_html_attr("a & b"), "a &amp; b")
  assert_eq(escape_html_attr("<em>"), "&lt;em&gt;")
  assert_eq(escape_html_attr("say \"hi\""), "say &quot;hi&quot;")
}

///|
test "escape_html_attr passes plain text unchanged" {
  assert_eq(escape_html_attr("hello"), "hello")
  assert_eq(escape_html_attr(""), "")
}

// ── normalize_base_url ────────────────────────────────────────────────────────

///|
test "normalize_base_url strips trailing slash" {
  assert_eq(normalize_base_url("https://example.com/"), "https://example.com")
  assert_eq(normalize_base_url("https://example.com"), "https://example.com")
}

///|
test "normalize_base_url treats bare slash as root-relative" {
  assert_eq(normalize_base_url("/"), "")
}

///|
test "normalize_base_url trims horizontal whitespace" {
  assert_eq(
    normalize_base_url("  https://example.com  "),
    "https://example.com",
  )
}

// ── absolute_url ──────────────────────────────────────────────────────────────

///|
test "absolute_url joins base and path" {
  assert_eq(
    absolute_url("https://example.com", "/about/"),
    "https://example.com/about/",
  )
}

///|
test "absolute_url returns path unchanged when base is empty" {
  assert_eq(absolute_url("/", "/posts/hello/"), "/posts/hello/")
}

///|
test "absolute_url adds slash between base and relative path" {
  assert_eq(
    absolute_url("https://example.com", "about/"),
    "https://example.com/about/",
  )
}

// ── join_path ─────────────────────────────────────────────────────────────────

///|
test "join_path joins two components with slash" {
  assert_eq(join_path("content", "posts"), "content/posts")
}

///|
test "join_path returns part when base is empty" {
  assert_eq(join_path("", "posts"), "posts")
}

///|
test "join_path returns base when part is empty" {
  assert_eq(join_path("content", ""), "content")
}

// ── write_json_escaped ────────────────────────────────────────────────────────

///|
test "write_json_escaped handles quotes and backslashes" {
  let buf = StringBuilder::new()
  write_json_escaped(buf, "say \"hi\"")
  assert_eq(buf.to_string(), "say \\\"hi\\\"")
  let buf2 = StringBuilder::new()
  write_json_escaped(buf2, "path\\to\\file")
  assert_eq(buf2.to_string(), "path\\\\to\\\\file")
}

///|
test "write_json_escaped handles newline and tab" {
  let buf = StringBuilder::new()
  write_json_escaped(buf, "line1\nline2\ttab")
  assert_eq(buf.to_string(), "line1\\nline2\\ttab")
}

///|
test "write_json_string wraps value in quotes" {
  let buf = StringBuilder::new()
  write_json_string(buf, "hello")
  assert_eq(buf.to_string(), "\"hello\"")
}

// ── to_ascii_lower ────────────────────────────────────────────────────────────

///|
test "to_ascii_lower lowercases ASCII, preserves non-ASCII" {
  assert_eq(to_ascii_lower("Hello WORLD"), "hello world")
  assert_eq(to_ascii_lower("café"), "café")
  assert_eq(to_ascii_lower(""), "")
}

// ── parse_int ─────────────────────────────────────────────────────────────────

///|
test "parse_int handles positive, negative, and zero" {
  assert_true(parse_int("42") == Some(42))
  assert_true(parse_int("-17") == Some(-17))
  assert_true(parse_int("0") == Some(0))
}

///|
test "parse_int rejects non-numeric input" {
  assert_true(parse_int("") == None)
  assert_true(parse_int("abc") == None)
  assert_true(parse_int("-") == None)
  assert_true(parse_int("1.5") == None)
}

// ── parse_positive_int ────────────────────────────────────────────────────────

///|
test "parse_positive_int accepts positive, rejects zero and negative" {
  assert_true(parse_positive_int("5") == Some(5))
  assert_true(parse_positive_int("0") == None)
  assert_true(parse_positive_int("") == None)
  assert_true(parse_positive_int("abc") == None)
}

// ── parse_float ───────────────────────────────────────────────────────────────

///|
test "parse_float handles integer and decimal forms" {
  match parse_float("3.14") {
    Some(v) => assert_true(v > 3.13 && v < 3.15)
    None => assert_true(false)
  }
  assert_true(parse_float("42") == Some(42.0))
  assert_true(parse_float("-1.5") == Some(-1.5))
}

///|
test "parse_float rejects non-numeric input" {
  assert_true(parse_float("") == None)
  assert_true(parse_float("abc") == None)
  assert_true(parse_float(".") == None)
}

// ── is_leap_year and days_in_month ───────────────────────────────────────────

///|
test "is_leap_year handles divisibility rules" {
  assert_true(is_leap_year(2000))
  assert_true(is_leap_year(2024))
  assert_true(!is_leap_year(1900))
  assert_true(!is_leap_year(2023))
}

///|
test "days_in_month returns correct counts including February" {
  assert_eq(days_in_month(2024, 2), 29)
  assert_eq(days_in_month(2023, 2), 28)
  assert_eq(days_in_month(2024, 1), 31)
  assert_eq(days_in_month(2024, 4), 30)
}

// ── is_valid_iso8601_date ─────────────────────────────────────────────────────

///|
test "is_valid_iso8601_date accepts valid dates" {
  assert_true(is_valid_iso8601_date("2026-04-21"))
  assert_true(is_valid_iso8601_date("2024-02-29"))
  assert_true(is_valid_iso8601_date("2000-01-01"))
}

///|
test "is_valid_iso8601_date rejects invalid month, day, and format" {
  assert_true(!is_valid_iso8601_date("2026-13-01"))
  assert_true(!is_valid_iso8601_date("2023-02-29"))
  assert_true(!is_valid_iso8601_date("2026-04-00"))
  assert_true(!is_valid_iso8601_date("not-a-date"))
  assert_true(!is_valid_iso8601_date("2026/04/21"))
}

// ── split_lines and join_lines ────────────────────────────────────────────────

///|
test "split_lines splits on newline and preserves empty lines" {
  let lines = split_lines("a\nb\n\nc")
  assert_eq(lines.length(), 4)
  assert_eq(lines[0], "a")
  assert_eq(lines[1], "b")
  assert_eq(lines[2], "")
  assert_eq(lines[3], "c")
}

///|
test "split_lines on empty string gives one empty line" {
  let lines = split_lines("")
  assert_eq(lines.length(), 1)
  assert_eq(lines[0], "")
}

///|
test "join_lines is inverse of split_lines for simple input" {
  let original = "line one\nline two\nline three"
  assert_eq(join_lines(split_lines(original)), original)
}

// ── parse_quoted ──────────────────────────────────────────────────────────────

///|
test "parse_quoted extracts simple string" {
  match parse_quoted("\"hello\" rest", 0) {
    Ok((s, pos)) => {
      assert_eq(s, "hello")
      assert_eq(pos, 7)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse_quoted handles escape sequences" {
  match parse_quoted("\"say \\\"hi\\\"\"", 0) {
    Ok((s, _)) => assert_eq(s, "say \"hi\"")
    Err(_) => assert_true(false)
  }
}

///|
test "parse_quoted returns error for unterminated string" {
  match parse_quoted("\"unterminated", 0) {
    Ok(_) => assert_true(false)
    Err(msg) => assert_true(msg.length() > 0)
  }
}

///|
test "parse_quoted returns error when not starting with quote" {
  match parse_quoted("no-quote", 0) {
    Ok(_) => assert_true(false)
    Err(_) => ()
  }
}

// ── substr ────────────────────────────────────────────────────────────────────

///|
test "substr extracts expected range" {
  assert_eq(substr("hello world", 6, 11), "world")
  assert_eq(substr("abc", 0, 3), "abc")
  assert_eq(substr("abc", 1, 2), "b")
}

// ── char_at ───────────────────────────────────────────────────────────────────

///|
test "char_at returns correct character" {
  assert_eq(char_at("hello", 0), 'h')
  assert_eq(char_at("hello", 4), 'o')
}

///|
test "char_at last index" {
  assert_eq(char_at("abc", 2), 'c')
}

// ── trim variants ─────────────────────────────────────────────────────────────

///|
test "trim removes all whitespace" {
  assert_eq(trim("  hello  "), "hello")
  assert_eq(trim("\t\nhello\r\n"), "hello")
  assert_eq(trim("hello"), "hello")
  assert_eq(trim(""), "")
}

///|
test "trim_start removes leading whitespace" {
  assert_eq(trim_start("  hello  "), "hello  ")
  assert_eq(trim_start("\n\thello"), "hello")
  assert_eq(trim_start("hello"), "hello")
}

///|
test "trim_end removes trailing whitespace" {
  assert_eq(trim_end("  hello  "), "  hello")
  assert_eq(trim_end("hello\r\n"), "hello")
  assert_eq(trim_end("hello"), "hello")
}

///|
test "trim_h horizontal only preserves newlines" {
  assert_eq(trim_h("  hello  "), "hello")
  assert_eq(trim_h("\n  hello  \n"), "\n  hello  \n")
  assert_eq(trim_h("hello"), "hello")
  assert_eq(trim_h(""), "")
}

// ── character classifiers ─────────────────────────────────────────────────────

///|
test "is_digit true and false boundaries" {
  assert_true(is_digit('0'))
  assert_true(is_digit('5'))
  assert_true(is_digit('9'))
  assert_true(!is_digit('/'))
  assert_true(!is_digit(':'))
  assert_true(!is_digit('a'))
}

///|
test "is_alpha true and false boundaries" {
  assert_true(is_alpha('a'))
  assert_true(is_alpha('z'))
  assert_true(is_alpha('A'))
  assert_true(is_alpha('Z'))
  assert_true(!is_alpha('`'))
  assert_true(!is_alpha('{'))
  assert_true(!is_alpha('0'))
}

///|
test "is_ident_start accepts alpha and underscore only" {
  assert_true(is_ident_start('a'))
  assert_true(is_ident_start('Z'))
  assert_true(is_ident_start('_'))
  assert_true(!is_ident_start('0'))
  assert_true(!is_ident_start('-'))
}

///|
test "is_ident_part accepts alpha digit and underscore" {
  assert_true(is_ident_part('a'))
  assert_true(is_ident_part('0'))
  assert_true(is_ident_part('_'))
  assert_true(!is_ident_part('-'))
  assert_true(!is_ident_part(' '))
}

///|
test "is_whitespace recognizes space tab cr lf" {
  assert_true(is_whitespace(' '))
  assert_true(is_whitespace('\t'))
  assert_true(is_whitespace('\n'))
  assert_true(is_whitespace('\r'))
  assert_true(!is_whitespace('a'))
  assert_true(!is_whitespace('.'))
}

///|
test "is_hex_digit covers 0-9 a-f A-F" {
  assert_true(is_hex_digit('0'))
  assert_true(is_hex_digit('9'))
  assert_true(is_hex_digit('a'))
  assert_true(is_hex_digit('f'))
  assert_true(is_hex_digit('A'))
  assert_true(is_hex_digit('F'))
  assert_true(!is_hex_digit('g'))
  assert_true(!is_hex_digit('G'))
}

///|
test "is_octal_digit 0-7 true 8-9 false" {
  assert_true(is_octal_digit('0'))
  assert_true(is_octal_digit('7'))
  assert_true(!is_octal_digit('8'))
  assert_true(!is_octal_digit('9'))
  assert_true(!is_octal_digit('a'))
}

///|
test "is_operator_char covers arithmetic and comparison" {
  assert_true(is_operator_char('+'))
  assert_true(is_operator_char('-'))
  assert_true(is_operator_char('*'))
  assert_true(is_operator_char('/'))
  assert_true(is_operator_char('='))
  assert_true(is_operator_char('!'))
  assert_true(is_operator_char('<'))
  assert_true(is_operator_char('>'))
  assert_true(!is_operator_char('a'))
  assert_true(!is_operator_char(' '))
}

///|
test "is_punct_char covers brackets and separators" {
  assert_true(is_punct_char('('))
  assert_true(is_punct_char(')'))
  assert_true(is_punct_char('{'))
  assert_true(is_punct_char('}'))
  assert_true(is_punct_char(';'))
  assert_true(is_punct_char(','))
  assert_true(is_punct_char('.'))
  assert_true(is_punct_char(':'))
  assert_true(!is_punct_char('a'))
  assert_true(!is_punct_char('+'))
}

// ── starts_with / ends_with / starts_with_at ─────────────────────────────────

///|
test "starts_with basic and empty prefix" {
  assert_true(starts_with("hello", "hel"))
  assert_true(starts_with("hello", ""))
  assert_true(!starts_with("hello", "world"))
  assert_true(starts_with("", ""))
  assert_true(!starts_with("", "a"))
}

///|
test "ends_with basic and empty suffix" {
  assert_true(ends_with("hello", "llo"))
  assert_true(ends_with("hello", ""))
  assert_true(!ends_with("hello", "hel"))
  assert_true(ends_with("", ""))
  assert_true(!ends_with("", "a"))
}

///|
test "starts_with_at position-based matching" {
  assert_true(starts_with_at("hello world", 0, "hello"))
  assert_true(starts_with_at("hello world", 6, "world"))
  assert_true(!starts_with_at("hello world", 0, "world"))
  assert_true(!starts_with_at("short", 3, "rtx"))
  assert_true(starts_with_at("abc", 0, ""))
}

// ── hex_nibble ────────────────────────────────────────────────────────────────

///|
test "hex_nibble maps 0-15 to hex chars" {
  assert_eq(hex_nibble(0), '0')
  assert_eq(hex_nibble(9), '9')
  assert_eq(hex_nibble(10), 'a')
  assert_eq(hex_nibble(15), 'f')
}

// ── ascii_lower_char ─────────────────────────────────────────────────────────

///|
test "ascii_lower_char converts uppercase leaves rest unchanged" {
  assert_eq(ascii_lower_char('A'), 'a')
  assert_eq(ascii_lower_char('Z'), 'z')
  assert_eq(ascii_lower_char('a'), 'a')
  assert_eq(ascii_lower_char('0'), '0')
  assert_eq(ascii_lower_char(' '), ' ')
}

// ── skip_ws / skip_ws_h ──────────────────────────────────────────────────────

///|
test "skip_ws skips all whitespace including newlines" {
  assert_eq(skip_ws("  \n\t  hello", 0), 6)
  assert_eq(skip_ws("hello", 0), 0)
  assert_eq(skip_ws("  hello", 0), 2)
}

///|
test "skip_ws_h skips horizontal whitespace only" {
  assert_eq(skip_ws_h("  \thello", 0), 3)
  assert_eq(skip_ws_h("\nhello", 0), 0)
  assert_eq(skip_ws_h("hello", 0), 0)
}

// ── find_char / find_str ─────────────────────────────────────────────────────

///|
test "find_char found and not-found cases" {
  assert_eq(find_char("hello world", 0, 'o', 11), 4)
  assert_eq(find_char("hello world", 6, 'o', 11), 7)
  assert_eq(find_char("hello", 0, 'z', 5), -1)
  assert_eq(find_char("abc", 5, 'a', 3), -1)
}

///|
test "find_str found and not-found cases" {
  assert_eq(find_str("hello world", 0, "world", 11), 6)
  assert_eq(find_str("hello world", 0, "xyz", 11), -1)
  assert_eq(find_str("abc abc", 0, "abc", 7), 0)
  assert_eq(find_str("abc abc", 1, "abc", 7), 4)
  assert_eq(find_str("ab", 0, "abc", 2), -1)
}

// ── insertion_sort ────────────────────────────────────────────────────────────

///|
test "insertion_sort empty single sorted reversed duplicates" {
  let empty : Array[Int] = []
  insertion_sort(empty, (a, b) => a.compare(b))
  assert_eq(empty.length(), 0)

  let single = [42]
  insertion_sort(single, (a, b) => a.compare(b))
  assert_eq(single[0], 42)

  let sorted = [1, 2, 3]
  insertion_sort(sorted, (a, b) => a.compare(b))
  assert_eq(sorted[0], 1)
  assert_eq(sorted[1], 2)
  assert_eq(sorted[2], 3)

  let reversed = [3, 2, 1]
  insertion_sort(reversed, (a, b) => a.compare(b))
  assert_eq(reversed[0], 1)
  assert_eq(reversed[1], 2)
  assert_eq(reversed[2], 3)

  let dups = [2, 1, 2, 1]
  insertion_sort(dups, (a, b) => a.compare(b))
  assert_eq(dups[0], 1)
  assert_eq(dups[1], 1)
  assert_eq(dups[2], 2)
  assert_eq(dups[3], 2)
}
