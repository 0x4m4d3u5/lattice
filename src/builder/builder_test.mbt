///|
test "collection index lookup alias uses numeric prefix directory basename" {
  let collection : @collections.CollectionDef = {
    name: "projects",
    schema: { name: "projects", fields: [] },
    content_dir: "/vault/10 - Projects",
  }
  match @builder.collection_index_lookup_alias(collection) {
    Some(lookup_key) => assert_eq(lookup_key, "10 - Projects")
    None => assert_true(false)
  }
}

///|
test "collection index lookup alias skips matching directory names" {
  let collection : @collections.CollectionDef = {
    name: "posts",
    schema: { name: "posts", fields: [] },
    content_dir: "/vault/posts",
  }
  match @builder.collection_index_lookup_alias(collection) {
    Some(_) => assert_true(false)
    None => ()
  }
}
