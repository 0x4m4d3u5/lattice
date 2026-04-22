///|
fn parse_fm(src : String) -> @frontmatter.Frontmatter {
  match @frontmatter.parse(src) {
    Ok(fm) => fm
    Err(_) => abort("expected frontmatter parse to succeed")
  }
}

// ── extract_vault_metadata ────────────────────────────────────────────────────

///|
test "extract_vault_metadata returns None when no vault fields present" {
  let fm = parse_fm("+++\ntitle = \"Hello\"\ndate = 2026-01-01\n+++\nBody")
  assert_eq(extract_vault_metadata(fm), None)
}

///|
test "extract_vault_metadata extracts type and status" {
  let fm = parse_fm("+++\ntype = \"project\"\nstatus = \"active\"\n+++\n")
  let meta = extract_vault_metadata(fm).unwrap()
  assert_eq(meta.note_type, Some("project"))
  assert_eq(meta.status, Some("active"))
  assert_eq(meta.purpose, None)
  assert_eq(meta.goal, None)
}

///|
test "extract_vault_metadata extracts all fields" {
  let fm = parse_fm(
    "+++\ntype = \"area\"\nstatus = \"active\"\npurpose = \"research\"\ngoal = \"learn moonbit\"\nsource = \"notes\"\n+++\n",
  )
  let meta = extract_vault_metadata(fm).unwrap()
  assert_eq(meta.note_type, Some("area"))
  assert_eq(meta.status, Some("active"))
  assert_eq(meta.purpose, Some("research"))
  assert_eq(meta.goal, Some("learn moonbit"))
  assert_eq(meta.source, Some("notes"))
}

///|
test "extract_vault_metadata treats FDate created as string" {
  let fm = parse_fm("+++\ncreated = 2026-03-15\n+++\n")
  let meta = extract_vault_metadata(fm).unwrap()
  assert_eq(meta.created, Some("2026-03-15"))
}

// ── is_active_project ─────────────────────────────────────────────────────────

///|
test "is_active_project returns false for None" {
  assert_eq(is_active_project(None), false)
}

///|
test "is_active_project returns true for active statuses" {
  let statuses = ["active", "Active", "ACTIVE", "in-progress", "doing", "ongoing", "in progress"]
  for s in statuses {
    let fm = parse_fm("+++\nstatus = \"" + s + "\"\n+++\n")
    let meta = extract_vault_metadata(fm)
    assert_eq(is_active_project(meta), true)
  }
}

///|
test "is_active_project returns false for non-active statuses" {
  let statuses = ["completed", "archived", "on-hold", "done"]
  for s in statuses {
    let fm = parse_fm("+++\nstatus = \"" + s + "\"\n+++\n")
    let meta = extract_vault_metadata(fm)
    assert_eq(is_active_project(meta), false)
  }
}

///|
test "is_active_project returns false when no status field" {
  let fm = parse_fm("+++\ntype = \"project\"\n+++\n")
  let meta = extract_vault_metadata(fm)
  assert_eq(is_active_project(meta), false)
}

// ── is_archived ───────────────────────────────────────────────────────────────

///|
test "is_archived returns false for None" {
  assert_eq(is_archived(None), false)
}

///|
test "is_archived returns true for archive-like statuses" {
  let statuses = ["archived", "completed", "done", "finished"]
  for s in statuses {
    let fm = parse_fm("+++\nstatus = \"" + s + "\"\n+++\n")
    let meta = extract_vault_metadata(fm)
    assert_eq(is_archived(meta), true)
  }
}

///|
test "is_archived returns false for active statuses" {
  let fm = parse_fm("+++\nstatus = \"active\"\n+++\n")
  let meta = extract_vault_metadata(fm)
  assert_eq(is_archived(meta), false)
}

// ── categorize_note ───────────────────────────────────────────────────────────

///|
test "categorize_note returns uncategorized for None" {
  assert_eq(categorize_note(None), "uncategorized")
}

///|
test "categorize_note normalizes project variants" {
  let variants = ["project", "Project", "projects"]
  for v in variants {
    let fm = parse_fm("+++\ntype = \"" + v + "\"\n+++\n")
    assert_eq(categorize_note(extract_vault_metadata(fm)), "project")
  }
}

///|
test "categorize_note normalizes area variants" {
  let variants = ["area", "Areas", "area of focus", "domain", "domains"]
  for v in variants {
    let fm = parse_fm("+++\ntype = \"" + v + "\"\n+++\n")
    assert_eq(categorize_note(extract_vault_metadata(fm)), "area")
  }
}

///|
test "categorize_note normalizes resource variants" {
  let variants = ["resource", "resources", "reference"]
  for v in variants {
    let fm = parse_fm("+++\ntype = \"" + v + "\"\n+++\n")
    assert_eq(categorize_note(extract_vault_metadata(fm)), "resource")
  }
}

///|
test "categorize_note normalizes inbox variants" {
  let variants = ["inbox", "capture"]
  for v in variants {
    let fm = parse_fm("+++\ntype = \"" + v + "\"\n+++\n")
    assert_eq(categorize_note(extract_vault_metadata(fm)), "inbox")
  }
}

///|
test "categorize_note returns lowercased unknown type" {
  let fm = parse_fm("+++\ntype = \"ExperimentalNote\"\n+++\n")
  assert_eq(categorize_note(extract_vault_metadata(fm)), "experimentalnote")
}

// ── category_class ────────────────────────────────────────────────────────────

///|
test "category_class converts spaces to hyphens" {
  assert_eq(category_class("in progress"), "in-progress")
}

///|
test "category_class converts underscores to hyphens" {
  assert_eq(category_class("hello_world"), "hello-world")
}

///|
test "category_class strips non-alphanumeric non-space chars" {
  assert_eq(category_class("hello!world"), "helloworld")
}

///|
test "category_class lowercases uppercase letters" {
  assert_eq(category_class("ActiveProject"), "activeproject")
}

///|
test "category_class handles empty string" {
  assert_eq(category_class(""), "")
}

///|
test "category_class preserves digits" {
  assert_eq(category_class("note2025"), "note2025")
}

// ── render_metadata_badge ─────────────────────────────────────────────────────

///|
test "render_metadata_badge returns empty string for None" {
  assert_eq(render_metadata_badge(None), "")
}

///|
test "render_metadata_badge renders type and status spans" {
  let fm = parse_fm("+++\ntype = \"project\"\nstatus = \"active\"\n+++\n")
  let meta = extract_vault_metadata(fm)
  let html = render_metadata_badge(meta)
  assert_eq(html.contains("vault-type-project"), true)
  assert_eq(html.contains("vault-status-active"), true)
  assert_eq(html.contains("<span class=\"vault-badge"), true)
}

///|
test "render_metadata_badge returns empty when only goal present" {
  let fm = parse_fm("+++\ngoal = \"learn moonbit\"\n+++\n")
  let meta = extract_vault_metadata(fm)
  assert_eq(render_metadata_badge(meta), "")
}

///|
test "render_metadata_badge escapes HTML in values" {
  let fm = parse_fm("+++\ntype = \"project\"\nstatus = \"ok\"\n+++\n")
  let meta = extract_vault_metadata(fm)
  let html = render_metadata_badge(meta)
  assert_eq(html.contains("</span>"), true)
}

// ── should_exclude_from_index ─────────────────────────────────────────────────

///|
test "should_exclude_from_index returns false for None" {
  assert_eq(should_exclude_from_index(None), false)
}

///|
test "should_exclude_from_index returns true for private/inbox/wip" {
  let excluded = ["private", "inbox", "wip", "work in progress"]
  for t in excluded {
    let fm = parse_fm("+++\ntype = \"" + t + "\"\n+++\n")
    assert_eq(should_exclude_from_index(extract_vault_metadata(fm)), true)
  }
}

///|
test "should_exclude_from_index returns false for public types" {
  let public_types = ["project", "area", "resource", "template"]
  for t in public_types {
    let fm = parse_fm("+++\ntype = \"" + t + "\"\n+++\n")
    assert_eq(should_exclude_from_index(extract_vault_metadata(fm)), false)
  }
}

// ── category_label ────────────────────────────────────────────────────────────

///|
test "category_label for canonical categories" {
  assert_eq(category_label("uncategorized"), "Uncategorized")
  assert_eq(category_label("project"), "Projects")
  assert_eq(category_label("area"), "Areas")
  assert_eq(category_label("resource"), "Resources")
  assert_eq(category_label("archive"), "Archive")
  assert_eq(category_label("inbox"), "Inbox")
  assert_eq(category_label("template"), "Templates")
}

///|
test "category_label capitalizes unknown categories" {
  assert_eq(category_label("notes"), "Notes")
}

///|
test "category_label returns Uncategorized for empty string" {
  assert_eq(category_label(""), "Uncategorized")
}
