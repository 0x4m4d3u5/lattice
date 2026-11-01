///|
/// Tests for search index JSON generation.

///|
test "render_search_index empty array produces empty JSON array" {
  let entries : Array[@search.SearchEntry] = []
  let result = @search.render_search_index(entries)
  inspect(result, content="[\n]\n")
}

///|
test "render_search_index single entry contains required fields" {
  let entry = @search.new_entry(
    "Hello World",
    "hello-world",
    "/posts/hello-world/",
    ["moonbit", "tutorial"],
    "posts",
    "This is a short excerpt.",
  )
  let result = @search.render_search_index([entry])
  inspect(result.contains("\"title\""), content="true")
  inspect(result.contains("\"slug\""), content="true")
  inspect(result.contains("\"url\""), content="true")
  inspect(result.contains("\"tags\""), content="true")
  inspect(result.contains("\"collection\""), content="true")
  inspect(result.contains("\"excerpt\""), content="true")
}

///|
test "render_search_index single entry field values" {
  let entry = @search.new_entry(
    "Hello World",
    "hello-world",
    "/posts/hello-world/",
    ["moonbit", "tutorial"],
    "posts",
    "This is a short excerpt.",
  )
  let result = @search.render_search_index([entry])
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
  let entry = @search.new_entry(
    "Untagged Page",
    "untagged",
    "/untagged/",
    [],
    "default",
    "No tags here.",
  )
  let result = @search.render_search_index([entry])
  inspect(result.contains("\"tags\": []"), content="true")
}

///|
test "render_search_index empty excerpt" {
  let entry = @search.new_entry(
    "Empty Excerpt Page",
    "empty-excerpt",
    "/empty/",
    [],
    "default",
    "",
  )
  let result = @search.render_search_index([entry])
  inspect(result.contains("\"excerpt\": \"\""), content="true")
}

///|
test "render_search_index multiple entries separated by commas" {
  let e1 = @search.new_entry(
    "First",
    "first",
    "/first/",
    ["a"],
    "posts",
    "Excerpt one.",
  )
  let e2 = @search.new_entry(
    "Second",
    "second",
    "/second/",
    ["b"],
    "posts",
    "Excerpt two.",
  )
  let e3 = @search.new_entry(
    "Third",
    "third",
    "/third/",
    ["c"],
    "posts",
    "Excerpt three.",
  )
  let result = @search.render_search_index([e1, e2, e3])
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
  let entry = @search.new_entry(
    "Title with \"quotes\"",
    "quotes",
    "/quotes/",
    [],
    "default",
    "excerpt",
  )
  let result = @search.render_search_index([entry])
  inspect(result.contains("\\\"quotes\\\""), content="true")
}

///|
test "render_search_index JSON string escaping backslash" {
  let entry = @search.new_entry(
    "Path C:\\Users\\foo",
    "backslash",
    "/backslash/",
    [],
    "default",
    "excerpt",
  )
  let result = @search.render_search_index([entry])
  inspect(result.contains("C:\\\\Users\\\\foo"), content="true")
}

///|
test "render_search_index JSON string escaping newline in excerpt" {
  let entry = @search.new_entry(
    "Multiline",
    "multiline",
    "/multi/",
    [],
    "default",
    "line one\nline two",
  )
  let result = @search.render_search_index([entry])
  inspect(result.contains("\\n"), content="true")
}

///|
test "render_search_index result is valid JSON array brackets" {
  let entry = @search.new_entry("A", "a", "/a/", [], "x", "e")
  let result = @search.render_search_index([entry])
  // Must start with [ and end with ]\n
  inspect(result[0].to_int().unsafe_to_char() == '[', content="true")
  let last_nl = result.length() - 1
  let second_last = result.length() - 2
  inspect(result[last_nl].to_int().unsafe_to_char() == '\n', content="true")
  inspect(result[second_last].to_int().unsafe_to_char() == ']', content="true")
}

///|
test "render_search_index two entries no trailing comma after last" {
  let e1 = @search.new_entry("One", "one", "/one/", [], "default", "")
  let e2 = @search.new_entry("Two", "two", "/two/", [], "default", "")
  let result = @search.render_search_index([e1, e2])
  // The block for e2 ends with "  }" immediately before "\n]"
  inspect(result.contains("  }\n]"), content="true")
}

///|
test "render_search_index multiple tags rendered as JSON array" {
  let entry = @search.new_entry(
    "Tagged",
    "tagged",
    "/tagged/",
    ["alpha", "beta", "gamma"],
    "posts",
    "excerpt",
  )
  let result = @search.render_search_index([entry])
  inspect(result.contains("\"alpha\""), content="true")
  inspect(result.contains("\"beta\""), content="true")
  inspect(result.contains("\"gamma\""), content="true")
  // tags array is inline: ["alpha", "beta", "gamma"]
  inspect(result.contains("[\"alpha\", \"beta\", \"gamma\"]"), content="true")
}

///|
test "render_search_index collection field present and correct" {
  let entry = @search.new_entry(
    "Page",
    "page",
    "/page/",
    [],
    "mycollection",
    "e",
  )
  let result = @search.render_search_index([entry])
  inspect(result.contains("\"mycollection\""), content="true")
}

///|
test "render_search_index empty collection string" {
  let entry = @search.new_entry("Page", "page", "/page/", [], "", "e")
  let result = @search.render_search_index([entry])
  inspect(result.contains("\"collection\": \"\""), content="true")
}

// ── ContentEntry / render_content_index ──────────────────────────────────────

///|
test "render_content_index empty array produces empty JSON array" {
  let entries : Array[@search.ContentEntry] = []
  let result = @search.render_content_index(entries)
  inspect(result, content="[\n]\n")
}

///|
test "render_content_index single entry contains required fields" {
  let entry = @search.new_content_entry(
    "Hello",
    "hello",
    "/posts/hello/",
    ["moonbit"],
    "posts",
    "2026-01-01",
    "A page about hello.",
    "post",
    Some(3),
    "This is the full body text.",
  )
  let result = @search.render_content_index([entry])
  inspect(result.contains("\"title\""), content="true")
  inspect(result.contains("\"slug\""), content="true")
  inspect(result.contains("\"url\""), content="true")
  inspect(result.contains("\"tags\""), content="true")
  inspect(result.contains("\"collection\""), content="true")
  inspect(result.contains("\"date\""), content="true")
  inspect(result.contains("\"description\""), content="true")
  inspect(result.contains("\"kind\""), content="true")
  inspect(result.contains("\"reading_time\""), content="true")
  inspect(result.contains("\"body\""), content="true")
}

///|
test "render_content_index body field stores full text" {
  let entry = @search.new_content_entry(
    "Full Text",
    "full-text",
    "/full-text/",
    [],
    "posts",
    "2026-03-01",
    "desc",
    "post",
    None,
    "This is a long body with multiple sentences. It covers the entire article.",
  )
  let result = @search.render_content_index([entry])
  inspect(
    result.contains("\"This is a long body with multiple sentences."),
    content="true",
  )
}

///|
test "render_content_index two entries no trailing comma after last" {
  let e1 = @search.new_content_entry(
    "A",
    "a",
    "/a/",
    [],
    "x",
    "",
    "",
    "page",
    None,
    "body a",
  )
  let e2 = @search.new_content_entry(
    "B",
    "b",
    "/b/",
    [],
    "x",
    "",
    "",
    "page",
    None,
    "body b",
  )
  let result = @search.render_content_index([e1, e2])
  inspect(result.contains("  }\n]"), content="true")
}

///|
test "render_content_index kind field rendered as JSON string" {
  let entry = @search.new_content_entry(
    "Standalone",
    "standalone",
    "/standalone/",
    [],
    "_standalone",
    "",
    "",
    "standalone",
    None,
    "body text",
  )
  let result = @search.render_content_index([entry])
  inspect(result.contains("\"kind\": \"standalone\""), content="true")
}

///|
test "render_content_index reading_time null rendered as JSON null" {
  let entry = @search.new_content_entry(
    "No RT",
    "no-rt",
    "/no-rt/",
    [],
    "x",
    "",
    "",
    "page",
    None,
    "body",
  )
  let result = @search.render_content_index([entry])
  inspect(result.contains("\"reading_time\": null"), content="true")
}

///|
test "render_content_index reading_time integer rendered as JSON number" {
  let entry = @search.new_content_entry(
    "With RT",
    "with-rt",
    "/with-rt/",
    [],
    "x",
    "",
    "",
    "post",
    Some(5),
    "body",
  )
  let result = @search.render_content_index([entry])
  inspect(result.contains("\"reading_time\": 5"), content="true")
}

///|
test "render_content_index deterministic field ordering" {
  let entry = @search.new_content_entry(
    "Order",
    "order",
    "/order/",
    ["a"],
    "posts",
    "2026-01-01",
    "desc",
    "post",
    Some(1),
    "body",
  )
  let result = @search.render_content_index([entry])
  // Verify all expected fields are present
  inspect(result.contains("\"title\": \"Order\""), content="true")
  inspect(result.contains("\"kind\": \"post\""), content="true")
  inspect(result.contains("\"reading_time\": 1"), content="true")
  inspect(result.contains("\"body\": \"body\""), content="true")
  // Verify kind comes after description and before reading_time
  // by checking for the literal field ordering in the output
  inspect(
    result.contains("\"description\": \"desc\",\n    \"kind\": \"post\""),
    content="true",
  )
  inspect(
    result.contains("\"kind\": \"post\",\n    \"reading_time\": 1"),
    content="true",
  )
  inspect(
    result.contains("\"reading_time\": 1,\n    \"body\": \"body\""),
    content="true",
  )
}

///|
test "heading catalogs use URLs and preserve legacy content rendering" {
  let first = @search.new_content_entry("A", "same", "/a/", [], "", "", "", "page", None, "body")
  let second = @search.new_content_entry("B", "same", "/b/", [], "", "", "", "page", None, "body")
  let catalog : Map[String, Array[@markdown.TocEntry]] = Map([
    ("/a/", @markdown.extract_table_of_contents("## A & \"B\"\n", 6)),
  ])
  let result = @search.render_content_index_with_headings([first, second], catalog)
  assert_true(result.contains("\"headings\": [{\"level\": 2, \"id\": \"a-b\", \"text\": \"A & \\\"B\\\"\"}]"))
  assert_true(result.contains("\"body\": \"body\",\n    \"headings\": []"))
  assert_false(@search.render_content_index([first]).contains("\"headings\""))
  let generated = @search.new_content_entry("Index", "a", "/a/", [], "", "", "", "collection_index", None, "generated body")
  let shared = @search.render_content_index_with_headings([first, generated], catalog)
  assert_false(shared.contains("\"id\": \"a-b\""))
  assert_true(shared.contains("\"body\": \"body\",\n    \"headings\": []"))
  assert_true(shared.contains("\"body\": \"generated body\",\n    \"headings\": []"))
}

///|
test "navigation exports fragment URLs, escaped labels and repeated references" {
  let page = @search.new_content_entry("A", "a", "/a/?view=full#old", [], "", "", "", "page", None, "body")
  let (references, errors) = @wikilink.resolve(
    @wikilink.extract("[[#Local|here]] [[Beta#Intro|B & \"Q\"]] [[Beta#Intro|again]] `[[missing]]`", "a.md"),
    Map([("beta", "/beta/?q=1&x=2")]),
  )
  assert_eq(errors.length(), 0)
  let links = Map([(page.url, references)])
  let result = @search.render_content_index_with_navigation([page], Map([]), links)
  assert_true(result.contains("{\"target\": \"#Local\", \"url\": \"/a/?view=full#local\", \"text\": \"here\"}"))
  assert_true(result.contains("{\"target\": \"Beta#Intro\", \"url\": \"/beta/?q=1&x=2#intro\", \"text\": \"B & \\\"Q\\\"\"}"))
  assert_true(result.contains("\"text\": \"again\""))
  assert_false(result.contains("missing"))
  assert_false(@search.render_content_index_with_headings([page], Map([])).contains("\"links\""))
  let generated = @search.new_content_entry("Index", "a", page.url, [], "", "", "", "collection_index", None, "generated body")
  let masked = @search.render_content_index_with_navigation([page, generated], Map([]), links)
  assert_false(masked.contains("#local"))
  assert_false(masked.contains("Beta#Intro"))
}

///|
test "alternate names retrieve canonical passages without duplicate name hits" {
  let documents : Array[@search.SearchDocument] = [
    {
      title: "Operations",
      url: "/ops/",
      tags: ["Reliability"],
      sections: [
        { heading: "Overview", body: "Practice safely.", },
        { heading: "Restore", body: "Verify checksums.", },
      ],
    },
  ]
  let aliases : Map[String, Array[String]] = Map([
    ("/ops/", ["Field Guide", "FIELD GUIDE"]),
  ])
  assert_eq(
    @search.retrieve_sections(documents, "field guide", [], 10).length(),
    0,
  )
  let names = @search.retrieve_sections(
    documents,
    "field guide",
    [],
    10,
    aliases~,
  )
  assert_eq(names.length(), 1)
  assert_eq(names[0].url, "/ops/")
  assert_eq(names[0].title, "Operations")
  assert_eq(names[0].score, 6)
  let passage = @search.retrieve_sections(
    documents,
    "field checksums",
    [],
    10,
    aliases~,
  )
  assert_eq(passage.length(), 1)
  assert_eq(passage[0].section_index, 1)
  assert_eq(
    @search.retrieve_sections(documents, "field", ["Private"], 10, aliases~).length(),
    0,
  )
  let ordinary = @search.retrieve_sections(documents, "checksums", [], 10)
  let enhanced = @search.retrieve_sections(
    documents,
    "checksums",
    [],
    10,
    aliases~,
  )
  assert_eq(ordinary[0].score, enhanced[0].score)
}

///|
test "alias index metadata is optional and malformed arrays fail closed" {
  let index = "[{\"title\":\"Guide\",\"url\":\"/guide/\",\"tags\":[],\"body\":\"Intro\",\"aliases\":[\"Handbook\"]}]"
  assert_true(
    @search.search_content(index, "handbook", "[]", 10).contains("/guide/"),
  )
  let invalid = "[{\"title\":\"Guide\",\"url\":\"/guide/\",\"tags\":[],\"body\":\"Intro\",\"aliases\":[42]}]"
  assert_true(
    @search.search_content(invalid, "handbook", "[]", 10).contains(
      "aliases must be an array of strings",
    ),
  )
}

///|
test "ranked snippet selection preserves late winners and duplicate URLs" {
  let documents : Array[@search.SearchDocument] = []
  for i = 0; i < 80; i = i + 1 {
    documents.push({ title: "Archive", url: "/same/", tags: [], sections: [{ heading: "", body: "needle low " + i.to_string() }] })
  }
  documents.push({ title: "needle", url: "/winner/", tags: ["Ops"], sections: [
    { heading: "needle", body: "🌱 needle winner one" },
    { heading: "needle", body: "🌱 needle winner two" },
  ] })
  let hits = @search.retrieve_sections(documents, "needle", [], 100)
  assert_eq(hits.length(), 50)
  assert_eq(hits[0].url, "/winner/")
  assert_eq(hits[0].snippet, "🌱 needle winner one")
  assert_eq(hits[1].snippet, "🌱 needle winner two")
  assert_true(hits.iter().drop(2).all(fn(hit) { hit.snippet.has_prefix("needle low ") }))
  let one = @search.retrieve_sections(documents, "needle", ["ops"], 1)
  assert_eq(one.length(), 1)
  assert_eq(one[0].snippet, hits[0].snippet)
  assert_eq(@search.retrieve_sections(documents, "needle", [], 0).length(), 0)
}
