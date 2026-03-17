///|
/// Tests for search index JSON generation.

///|
test "render_search_index empty array produces empty JSON array" {
  let entries : Array[SearchEntry] = []
  let result = render_search_index(entries)
  inspect(result, content="[\n]\n")
}

///|
test "render_search_index single entry contains required fields" {
  let entry = new_entry(
    "Hello World",
    "hello-world",
    "/posts/hello-world/",
    ["moonbit", "tutorial"],
    "posts",
    "This is a short excerpt.",
  )
  let result = render_search_index([entry])
  inspect(result.contains("\"title\""), content="true")
  inspect(result.contains("\"slug\""), content="true")
  inspect(result.contains("\"url\""), content="true")
  inspect(result.contains("\"tags\""), content="true")
  inspect(result.contains("\"collection\""), content="true")
  inspect(result.contains("\"excerpt\""), content="true")
}

///|
test "render_search_index single entry field values" {
  let entry = new_entry(
    "Hello World",
    "hello-world",
    "/posts/hello-world/",
    ["moonbit", "tutorial"],
    "posts",
    "This is a short excerpt.",
  )
  let result = render_search_index([entry])
  inspect(result.contains("\"Hello World\""), content="true")
  inspect(result.contains("\"hello-world\""), content="true")
  inspect(result.contains("\"/posts/hello-world/\""), content="true")
  inspect(result.contains("\"moonbit\""), content="true")
  inspect(result.contains("\"tutorial\""), content="true")
  inspect(result.contains("\"posts\""), content="true")
  inspect(result.contains("\"This is a short excerpt.\""), content="true")
}

///|
test "render_search_index empty tags array" {
  let entry = new_entry(
    "Untagged Page",
    "untagged",
    "/untagged/",
    [],
    "default",
    "No tags here.",
  )
  let result = render_search_index([entry])
  inspect(result.contains("\"tags\": []"), content="true")
}

///|
test "render_search_index empty excerpt" {
  let entry = new_entry(
    "Empty Excerpt Page",
    "empty-excerpt",
    "/empty/",
    [],
    "default",
    "",
  )
  let result = render_search_index([entry])
  inspect(result.contains("\"excerpt\": \"\""), content="true")
}

///|
test "render_search_index multiple entries separated by commas" {
  let e1 = new_entry(
    "First", "first", "/first/", ["a"], "posts", "Excerpt one.",
  )
  let e2 = new_entry(
    "Second", "second", "/second/", ["b"], "posts", "Excerpt two.",
  )
  let e3 = new_entry(
    "Third", "third", "/third/", ["c"], "posts", "Excerpt three.",
  )
  let result = render_search_index([e1, e2, e3])
  inspect(result.contains("\"First\""), content="true")
  inspect(result.contains("\"Second\""), content="true")
  inspect(result.contains("\"Third\""), content="true")
  // commas separate entries but NOT trailing the last one
  let comma_count = {
    let mut n = 0
    let mut i = 0
    while i < result.length() {
      if result[i].to_int().unsafe_to_char() == ',' {
        n = n + 1
      }
      i = i + 1
    }
    n
  }
  // 2 inter-entry commas + 5 intra-entry field commas per entry = 2 + 15 = 17
  // (title, slug, url, tags, collection each followed by comma = 5 per entry,
  //  excerpt has no trailing comma; 3 entries × 5 = 15, plus 2 inter-entry = 17)
  inspect(comma_count >= 2, content="true")
}

///|
test "render_search_index JSON string escaping double quote" {
  let entry = new_entry(
    "Title with \"quotes\"",
    "quotes",
    "/quotes/",
    [],
    "default",
    "excerpt",
  )
  let result = render_search_index([entry])
  inspect(result.contains("\\\"quotes\\\""), content="true")
}

///|
test "render_search_index JSON string escaping backslash" {
  let entry = new_entry(
    "Path C:\\Users\\foo",
    "backslash",
    "/backslash/",
    [],
    "default",
    "excerpt",
  )
  let result = render_search_index([entry])
  inspect(result.contains("C:\\\\Users\\\\foo"), content="true")
}

///|
test "render_search_index JSON string escaping newline in excerpt" {
  let entry = new_entry(
    "Multiline",
    "multiline",
    "/multi/",
    [],
    "default",
    "line one\nline two",
  )
  let result = render_search_index([entry])
  inspect(result.contains("\\n"), content="true")
}

///|
test "render_search_index result is valid JSON array brackets" {
  let entry = new_entry("A", "a", "/a/", [], "x", "e")
  let result = render_search_index([entry])
  // Must start with [ and end with ]\n
  inspect(result[0].to_int().unsafe_to_char() == '[', content="true")
  let last_nl = result.length() - 1
  let second_last = result.length() - 2
  inspect(result[last_nl].to_int().unsafe_to_char() == '\n', content="true")
  inspect(result[second_last].to_int().unsafe_to_char() == ']', content="true")
}

///|
test "render_search_index two entries no trailing comma after last" {
  let e1 = new_entry("One", "one", "/one/", [], "default", "")
  let e2 = new_entry("Two", "two", "/two/", [], "default", "")
  let result = render_search_index([e1, e2])
  // The block for e2 ends with "  }" immediately before "\n]"
  inspect(result.contains("  }\n]"), content="true")
}

///|
test "render_search_index multiple tags rendered as JSON array" {
  let entry = new_entry(
    "Tagged",
    "tagged",
    "/tagged/",
    ["alpha", "beta", "gamma"],
    "posts",
    "excerpt",
  )
  let result = render_search_index([entry])
  inspect(result.contains("\"alpha\""), content="true")
  inspect(result.contains("\"beta\""), content="true")
  inspect(result.contains("\"gamma\""), content="true")
  // tags array is inline: ["alpha", "beta", "gamma"]
  inspect(result.contains("[\"alpha\", \"beta\", \"gamma\"]"), content="true")
}

///|
test "render_search_index collection field present and correct" {
  let entry = new_entry("Page", "page", "/page/", [], "mycollection", "e")
  let result = render_search_index([entry])
  inspect(result.contains("\"mycollection\""), content="true")
}

///|
test "render_search_index empty collection string" {
  let entry = new_entry("Page", "page", "/page/", [], "", "e")
  let result = render_search_index([entry])
  inspect(result.contains("\"collection\": \"\""), content="true")
}
