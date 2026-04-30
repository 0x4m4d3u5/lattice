///|
test "stub_for_field_type - TString unbounded" {
  let result = stub_for_field_type(@schema.TString(None, None), "2026-04-01")
  assert_eq(result, "placeholder")
}

///|
test "stub_for_field_type - TString with minlen" {
  let result = stub_for_field_type(@schema.TString(Some(5), None), "2026-04-01")
  assert_eq(result, "placeholder")
}

///|
test "stub_for_field_type - TString with maxlen shorter than placeholder" {
  let result = stub_for_field_type(@schema.TString(None, Some(5)), "2026-04-01")
  assert_eq(result, "place")
}

///|
test "stub_for_field_type - TString with minlen requiring padding" {
  let result = stub_for_field_type(
    @schema.TString(Some(20), None),
    "2026-04-01",
  )
  assert_eq(result.length(), 20)
  assert_eq(@strutil.substr(result, 0, 11), "placeholder")
}

///|
test "stub_for_field_type - TDate" {
  let result = stub_for_field_type(@schema.TDate(None, None), "2026-04-01")
  assert_eq(result, "2026-04-01")
}

///|
test "stub_for_field_type - TInt unbounded" {
  let result = stub_for_field_type(@schema.TInt(None, None), "2026-04-01")
  assert_eq(result, "0")
}

///|
test "stub_for_field_type - TInt with min" {
  let result = stub_for_field_type(@schema.TInt(Some(10), None), "2026-04-01")
  assert_eq(result, "10")
}

///|
test "stub_for_field_type - TFloat unbounded" {
  let result = stub_for_field_type(@schema.TFloat(None, None), "2026-04-01")
  assert_eq(result, "0.0")
}

///|
test "stub_for_field_type - TFloat with min" {
  let result = stub_for_field_type(
    @schema.TFloat(Some(1.5), None),
    "2026-04-01",
  )
  assert_eq(result, "1.5")
}

///|
test "stub_for_field_type - TBool" {
  let result = stub_for_field_type(@schema.TBool, "2026-04-01")
  assert_eq(result, "false")
}

///|
test "stub_for_field_type - TEnum" {
  let result = stub_for_field_type(
    @schema.TEnum(["draft", "published"]),
    "2026-04-01",
  )
  assert_eq(result, "draft")
}

///|
test "stub_for_field_type - TEnum empty" {
  let result = stub_for_field_type(@schema.TEnum([]), "2026-04-01")
  assert_eq(result, "")
}

///|
test "stub_for_field_type - TUrl" {
  let result = stub_for_field_type(@schema.TUrl, "2026-04-01")
  assert_eq(result, "https://example.com")
}

///|
test "stub_for_field_type - TSlug" {
  let result = stub_for_field_type(@schema.TSlug, "2026-04-01")
  assert_eq(result, "example-slug")
}

///|
test "stub_for_field_type - TRef" {
  let result = stub_for_field_type(@schema.TRef(Some("posts")), "2026-04-01")
  assert_eq(result, "example-slug")
}

///|
test "stub_for_field_type - TArray" {
  let result = stub_for_field_type(
    @schema.TArray(@schema.TString(None, None)),
    "2026-04-01",
  )
  assert_eq(result, "[]")
}

///|
test "stub_for_field_type - TOptional delegates to inner" {
  let result = stub_for_field_type(
    @schema.TOptional(@schema.TBool),
    "2026-04-01",
  )
  assert_eq(result, "false")
}

///|
test "generate_frontmatter - basic schema" {
  let schema : @schema.Schema = {
    name: "posts",
    fields: [
      { name: "title", field_type: @schema.TString(None, None), required: true },
      { name: "date", field_type: @schema.TDate(None, None), required: true },
      {
        name: "tags",
        field_type: @schema.TOptional(
          @schema.TArray(@schema.TString(None, None)),
        ),
        required: false,
      },
      {
        name: "draft",
        field_type: @schema.TOptional(@schema.TBool),
        required: false,
      },
    ],
  }
  let result = generate_frontmatter(schema, "2026-04-01")
  let lines : Array[String] = result
    .split("\n")
    .map(fn(sv) { sv.to_owned() })
    .collect()
  // Should start with ---
  assert_eq(lines[0], "---")
  // Required fields emitted as values
  inspect(lines[1], content="title: placeholder")
  inspect(lines[2], content="date: 2026-04-01")
  // Optional fields emitted as comments
  inspect(lines[3], content="# tags:")
  inspect(lines[4], content="#   - value")
  inspect(lines[5], content="# draft: ")
  // Should end with ---
  inspect(lines[6], content="---")
}

///|
test "generate_frontmatter - array field required" {
  let schema : @schema.Schema = {
    name: "test",
    fields: [
      {
        name: "items",
        field_type: @schema.TArray(@schema.TString(None, None)),
        required: true,
      },
    ],
  }
  let result = generate_frontmatter(schema, "2026-04-01")
  let lines : Array[String] = result
    .split("\n")
    .map(fn(sv) { sv.to_owned() })
    .collect()
  inspect(lines[1], content="items:")
  inspect(lines[2], content="  - placeholder")
}

///|
test "generate_frontmatter - TInt with min" {
  let schema : @schema.Schema = {
    name: "test",
    fields: [
      {
        name: "priority",
        field_type: @schema.TInt(Some(1), Some(10)),
        required: true,
      },
    ],
  }
  let result = generate_frontmatter(schema, "2026-04-01")
  let lines : Array[String] = result
    .split("\n")
    .map(fn(sv) { sv.to_owned() })
    .collect()
  inspect(lines[1], content="priority: 1")
}

///|
test "new_content_file - empty slug rejected" {
  let schema : @schema.Schema = {
    name: "test",
    fields: [
      { name: "title", field_type: @schema.TString(None, None), required: true },
    ],
  }
  let result = new_content_file(
    "/tmp/lattice-test-new", schema, "", "2026-04-01",
  )
  match result {
    Err(msg) => assert_eq(msg, "slug must not be empty")
    Ok(_) => fail("expected error for empty slug")
  }
}

///|
test "new_content_file - refuses to overwrite existing file" {
  let test_dir = "/tmp/lattice-test-new-overwrite"
  let schema : @schema.Schema = {
    name: "test",
    fields: [
      { name: "title", field_type: @schema.TString(None, None), required: true },
    ],
  }
  @fs.create_dir(test_dir) catch {
    _ => ()
  }
  let path = test_dir + "/existing.md"
  // Create the file first
  @fs.write_string_to_file(path, "existing") catch {
    _ => ()
  }
  let result = new_content_file(test_dir, schema, "existing", "2026-04-01")
  match result {
    Err(msg) =>
      assert_eq(@strutil.starts_with(msg, "file already exists"), true)
    Ok(_) => fail("expected error for existing file")
  }
  // Clean up
  ignore(@fs.remove_file(path))
}

///|
test "new_content_file - schema with required and optional fields includes field guide" {
  let test_dir = "/tmp/lattice-test-field-guide"
  let schema : @schema.Schema = {
    name: "test",
    fields: [
      { name: "title", field_type: @schema.TString(None, None), required: true },
      { name: "date", field_type: @schema.TDate(None, None), required: true },
      {
        name: "tags",
        field_type: @schema.TOptional(
          @schema.TArray(@schema.TString(None, None)),
        ),
        required: false,
      },
      {
        name: "draft",
        field_type: @schema.TOptional(@schema.TBool),
        required: false,
      },
    ],
  }
  @fs.create_dir(test_dir) catch {
    _ => ()
  }
  let file_path = new_content_file(
    test_dir, schema, "field-guide-test", "2026-04-29",
  )
  match file_path {
    Err(msg) => fail("expected success, got: " + msg)
    Ok(path) => {
      let content = @fs.read_file_to_string(path) catch {
        @fs.IOError(msg) => fail("cannot read file: " + msg)
      }
      // The HTML comment block should list required and optional fields
      assert_true(content.contains("<!--"))
      assert_true(content.contains("-->"))
      assert_true(content.contains("Required fields: title, date"))
      assert_true(content.contains("Optional fields: tags, draft"))
      // Clean up
      ignore(@fs.remove_file(path))
    }
  }
}

///|
test "new_content_file - schema with only required fields omits optional line" {
  let test_dir = "/tmp/lattice-test-field-guide-required-only"
  let schema : @schema.Schema = {
    name: "test",
    fields: [
      { name: "title", field_type: @schema.TString(None, None), required: true },
      { name: "date", field_type: @schema.TDate(None, None), required: true },
    ],
  }
  @fs.create_dir(test_dir) catch {
    _ => ()
  }
  let file_path = new_content_file(
    test_dir, schema, "required-only-test", "2026-04-29",
  )
  match file_path {
    Err(msg) => fail("expected success, got: " + msg)
    Ok(path) => {
      let content = @fs.read_file_to_string(path) catch {
        @fs.IOError(msg) => fail("cannot read file: " + msg)
      }
      // Should have the HTML comment block with required fields
      assert_true(content.contains("Required fields: title, date"))
      // Should NOT have "Optional fields:" line since no optional fields exist
      assert_true(!content.contains("Optional fields:"))
      // Clean up
      ignore(@fs.remove_file(path))
    }
  }
}

///|
test "new_content_file - happy path creates file with frontmatter and body stub" {
  let test_dir = "/tmp/lattice-test-happy-path"
  let schema : @schema.Schema = {
    name: "test",
    fields: [
      { name: "title", field_type: @schema.TString(None, None), required: true },
      { name: "date", field_type: @schema.TDate(None, None), required: true },
    ],
  }
  @fs.create_dir(test_dir) catch {
    _ => ()
  }
  let file_path = new_content_file(
    test_dir, schema, "happy-path-test", "2026-04-29",
  )
  match file_path {
    Err(msg) => fail("expected success, got: " + msg)
    Ok(path) => {
      // File should exist
      assert_true(@fs.path_exists(path))
      let content = @fs.read_file_to_string(path) catch {
        @fs.IOError(msg) => fail("cannot read file: " + msg)
      }
      // Should contain frontmatter delimiters
      assert_true(content.contains("---"))
      // Should contain a heading stub
      assert_true(content.contains("# Title"))
      // Should contain the body stub text
      assert_true(content.contains("Write your content here."))
      // Clean up
      ignore(@fs.remove_file(path))
    }
  }
}
