pub(all) enum ViolationType {
  SchemaError
  MissingRequiredFrontmatter
  BrokenWikilink
  DanglingTagReference
  TemplateSlotError
  DataError
  ShortcodeError
  FrontmatterError
  CollectionsError
  DuplicateSlug
  IOError
}

pub(all) struct LintViolation {
  path : String
  line : Int?
  column : Int?
  kind : ViolationType
  message : String
}

pub(all) struct LintResult {
  violations : Array[LintViolation]
}

pub fn empty_result() -> LintResult {
  { violations: [] }
}

pub fn has_violations(result : LintResult) -> Bool {
  result.violations.length() > 0
}

pub fn violation_type_name(kind : ViolationType) -> String {
  match kind {
    SchemaError => "schema"
    MissingRequiredFrontmatter => "missing_required_field"
    BrokenWikilink => "broken_wikilink"
    DanglingTagReference => "dangling_tag"
    TemplateSlotError => "template_slot"
    DataError => "data"
    ShortcodeError => "shortcode"
    FrontmatterError => "frontmatter"
    CollectionsError => "collections"
    DuplicateSlug => "duplicate_slug"
    IOError => "io"
  }
}

pub fn format_violation(v : LintViolation) -> String {
  let pos = match v.line {
    Some(line) => {
      match v.column {
        Some(col) => ":" + line.to_string() + ":" + col.to_string()
        None => ":" + line.to_string()
      }
    }
    None => ""
  }
  v.path + pos + ": " + violation_type_name(v.kind) + ": " + v.message
}
