///|
test "CRLF blank lines do not add words" {
  // Both source spellings contain exactly two whitespace-delimited words.
  assert_eq(@builder.count_words_markdown("Alpha\n\nBeta\n"), 2)
  assert_eq(@builder.count_words_markdown("Alpha\r\n\r\nBeta\r\n"), 2)
}

///|
test "CRLF whitespace and code fences retain word-count semantics" {
  assert_eq(@builder.count_words_markdown("\r\n \t\r\n"), 0)
  assert_eq(@builder.count_words_markdown("Alpha \t\r\nBeta\t \r\n"), 2)
  for newline in ["\n", "\r\n"] {
    let body = [
      "Alpha Beta", "", "````text", "ignored code words", "```", "still code", "````",
      "", "Gamma",
    ].join(newline)
    assert_eq(@builder.count_words_markdown(body), 3)
  }
}

///|
test "CRLF notes publish the same count and reading time as LF notes" {
  let config = publication_fixture("word_count_crlf")
  @fs.write_string_to_file(
    config.content_dir + "/../templates/page.html",
    "<p>{{word_count}} words; {{reading_time}}</p>",
  )
  // Independently constructed 225-word note, exactly the one-minute boundary.
  let words = "word ".repeat(224) + "word"
  for newline in ["\n", "\r\n"] {
    @fs.write_string_to_file(
      config.content_dir + "/posts/alpha.md",
      ["---", "title: Alpha", "date: 2026-01-02", "---", words, "", ""].join(
        newline,
      ),
    )
    let built = @builder.build(config, @cache.empty(config.output_dir))
    assert_eq(built.errors, 0)
    assert_eq(@builder.check(config).violations.length(), 0)
    assert_eq(
      @fs.read_file_to_string(config.output_dir + "/posts/alpha/index.html"),
      "<p>225 words; 1 min</p>",
    )
    let before = publication_snapshot(config.output_dir)
    let cached = @builder.build(
      publication_incremental(config),
      publication_load_cache(config),
    )
    assert_eq(cached.errors, 0)
    assert_true(cached.unchanged_pages >= 2)
    assert_eq(publication_snapshot(config.output_dir), before)
    let forced = @builder.build(config, publication_load_cache(config))
    assert_eq(forced.errors, 0)
    assert_eq(publication_snapshot(config.output_dir), before)
  }
}
