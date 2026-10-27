///|
test "nearby wikilinks normalize through resolver and sort all ties" {
  let index = Map([("plum", "/plum/"), ("plan", "/plan/")])
  let pages = Map([("plum", ""), ("plan", "")])
  assert_eq(
    nearby_wikilinks(
      { target: "PLAM.md", display: Some("read"), source_file: "a.md", },
      index,
      pages,
    ),
    ["[[plan|read]]", "[[plum|read]]"],
  )
}

///|
test "nearby wikilinks refuse broad ambiguous or unsafe corrections" {
  let index = Map([
    ("cake", "/cake/"),
    ("lake", "/lake/"),
    ("make", "/make/"),
    ("take", "/take/"),
  ])
  let pages = Map([("cake", ""), ("lake", ""), ("make", ""), ("take", "")])
  for target in ["bake", "ab", "unrelated", "#bake"] {
    assert_eq(
      nearby_wikilinks(
        { target, display: None, source_file: "a.md", },
        index,
        pages,
      ),
      [],
    )
  }
  assert_eq(
    nearby_wikilinks(
      { target: "guid", display: None, source_file: "a.md", },
      Map([]),
      Map([("guide", "")]),
    ),
    [],
  )
  assert_eq(
    nearby_wikilinks(
      { target: "guid", display: None, source_file: "a.md", },
      Map([("guid|", "/x/")]),
      Map([("guid|", "")]),
    ),
    [],
  )
}

///|
test "nearby wikilinks require unique real published fragments" {
  let index = Map([("guide", "/guide/")])
  for
    html in [
      "<!-- <h2 id='setup'> -->", "<script>\"<h2 id='setup'>\"</script>", "<h2 id='setup'></h2><p id='setup'></p>",
      "<template><h2 id='setup'></h2></template>",
    ] {
    assert_eq(
      nearby_wikilinks(
        { target: "guid#Setup", display: None, source_file: "a.md", },
        index,
        Map([("guide", html)]),
      ),
      [],
    )
  }
  assert_eq(
    nearby_wikilinks(
      { target: "guid#Setup", display: None, source_file: "a.md", },
      index,
      Map([("guide", "<h2 id='setup'>Setup</h2>")]),
    ),
    ["[[guide#Setup]]"],
  )
}

///|
test "nearby wikilinks retain normalized accents and bound long queries" {
  let index = Map([("cafe", "/cafe/")])
  let pages = Map([("cafe", "")])
  assert_eq(
    nearby_wikilinks(
      { target: "Cafée.md", display: None, source_file: "a.md", },
      index,
      pages,
    ),
    ["[[cafe]]"],
  )
  let long = "a".repeat(81)
  assert_eq(
    nearby_wikilinks(
      { target: long, display: None, source_file: "a.md", },
      Map([(long + "b", "/long/")]),
      Map([(long + "b", "")]),
    ),
    [],
  )
}
