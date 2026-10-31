///|
fn alias_test_sources(
  names : Array[(String, String)],
) -> Array[CollectionSources] {
  [
    {
      definition: {
        name: "notes",
        schema: { name: "notes", fields: [], },
        content_dir: "notes",
        template: None,
        page_size: None,
        sort_order: @collections.DateDesc,
        description: None,
      },
      sources: names.map(fn(pair) {
        let (slug, aliases) = pair
        {
          path: slug + ".md",
          filename: slug + ".md",
          stamp: 0L,
          slug,
          content: "---\ntitle: Note\naliases: " + aliases + "\n---\nBody",
          fingerprint: "",
          link_targets: [],
        }
      }),
    },
  ]
}

///|
test "note aliases normalize and reject ambiguous ownership independently of enumeration" {
  let sources = alias_test_sources([
    ("research", "[\"Field Guide\", \"FIELD GUIDE\", \"research.md\"]"),
  ])
  let index = Map([("research", "/notes/research/")])
  assert_eq(register_note_aliases(sources, index).length(), 0)
  assert_eq(index.get("field-guide"), Some("/notes/research/"))
  for
    names in [
      [("a", "[\"Shared\"]"), ("b", "[\"SHARED\"]")],
      [("b", "[\"SHARED\"]"), ("a", "[\"Shared\"]")],
    ] {
    let index = Map([("a", "/a/"), ("b", "/b/")])
    let errors = register_note_aliases(alias_test_sources(names), index)
    assert_eq(errors.length(), 1)
    assert_eq(errors[0].path, "b.md")
    assert_eq(errors[0].line, Some(3))
    assert_eq(index.get("shared"), None)
  }
}

///|
test "note aliases preserve canonical keys and validate typed metadata" {
  for
    value in [
      "[\"Other\"]", "[\"\"]", "[42]", "true", "[\"Name#Part\"]", "[\"Name|Label\"]",
    ] {
    let index = Map([("research", "/research/"), ("other", "/other/")])
    let errors = register_note_aliases(
      alias_test_sources([("research", value)]),
      index,
    )
    assert_eq(errors.length(), 1)
    assert_eq(index.get("other"), Some("/other/"))
  }
}

///|
test "alias metadata schema extension is opt in and preserves declared constraints" {
  let schema : @schema.Schema = { name: "notes", fields: [], }
  let fm = @frontmatter.parse("---\naliases: [Guide]\n---\n").unwrap()
  assert_eq(@schema.validate(fm, note_alias_schema(schema, false)).length(), 1)
  assert_eq(@schema.validate(fm, note_alias_schema(schema, true)).length(), 0)
  let declared : @schema.Schema = {
    name: "notes",
    fields: [
      {
        name: "aliases",
        required: true,
        field_type: @schema.TString(None, None),
      },
    ],
  }
  assert_eq(@schema.validate(fm, note_alias_schema(declared, true)).length(), 1)
}
