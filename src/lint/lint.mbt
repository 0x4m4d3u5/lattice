///|
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
} derive(Eq, Hash, Show)

///|
pub(all) struct LintViolation {
  path : String
  line : Int?
  column : Int?
  kind : ViolationType
  message : String
}

///|
pub(all) struct LintResult {
  violations : Array[LintViolation]
}

///|
pub fn empty_result() -> LintResult {
  { violations: [] }
}

///|
pub fn has_violations(result : LintResult) -> Bool {
  result.violations.length() > 0
}

///|
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

///|
pub fn format_violation(v : LintViolation) -> String {
  let pos = match v.line {
    Some(line) =>
      match v.column {
        Some(col) => ":" + line.to_string() + ":" + col.to_string()
        None => ":" + line.to_string()
      }
    None => ""
  }
  v.path + pos + ": " + violation_type_name(v.kind) + ": " + v.message
}

// ── build summary ────────────────────────────────────────────────────────────

///|
/// Count of violations for a single violation type.
pub(all) struct TypeCount {
  kind : ViolationType
  count : Int
}

///|
/// Count of violations in a single file path.
pub(all) struct FileCount {
  path : String
  count : Int
}

///|
/// Structured summary of lint violations, grouped by type and by file.
///
/// The summary provides two useful breakdowns:
/// - **by_type**: how many violations of each kind (schema, wikilink, etc.)
/// - **by_file**: how many violations per source file
///
/// This is the structured representation behind the `--check` summary line
/// and the build error summary. Callers can format it for CLI output, JSON
/// export, or structured logging.
pub(all) struct ViolationSummary {
  total : Int
  by_type : Array[TypeCount]
  by_file : Array[FileCount]
}

///|
/// Compute a structured summary from a `LintResult`.
///
/// Groups violations by type and by file path, sorted by count descending.
/// The type grouping uses `violation_type_name` for display; the file grouping
/// uses the raw `path` field from each violation.
pub fn summarize(result : LintResult) -> ViolationSummary {
  let violations = result.violations
  let total = violations.length()

  // Group by type
  let type_counts : Map[ViolationType, Int] = Map::new()
  for v in violations {
    type_counts.update(v.kind, fn(prev) {
      match prev {
        Some(n) => Some(n + 1)
        None => Some(1)
      }
    })
  }
  let by_type : Array[TypeCount] = []
  for kind, count in type_counts {
    by_type.push({ kind, count })
  }
  by_type.sort_by((a, b) => b.count.compare(a.count))

  // Group by file
  let file_counts : Map[String, Int] = Map::new()
  for v in violations {
    file_counts.update(v.path, fn(prev) {
      match prev {
        Some(n) => Some(n + 1)
        None => Some(1)
      }
    })
  }
  let by_file : Array[FileCount] = []
  for path, count in file_counts {
    by_file.push({ path, count })
  }
  by_file.sort_by((a, b) => b.count.compare(a.count))

  { total, by_type, by_file }
}

///|
/// Format a `ViolationSummary` as a human-readable multi-line summary.
///
/// Output format:
/// ```
/// Summary: 5 violation(s)
///   By type:
///     schema: 3
///     broken_wikilink: 2
///   By file:
///     content/posts/draft.md: 3
///     content/posts/hello.md: 2
/// ```
pub fn format_summary(summary : ViolationSummary) -> String {
  let buf = StringBuilder::new()
  buf.write_string("Summary: ")
  buf.write_string(summary.total.to_string())
  buf.write_string(" violation(s)")

  if summary.by_type.length() > 0 {
    buf.write_string("\n  By type:")
    for tc in summary.by_type {
      buf.write_string("\n    ")
      buf.write_string(violation_type_name(tc.kind))
      buf.write_string(": ")
      buf.write_string(tc.count.to_string())
    }
  }

  if summary.by_file.length() > 0 {
    buf.write_string("\n  By file:")
    for fc in summary.by_file {
      buf.write_string("\n    ")
      buf.write_string(fc.path)
      buf.write_string(": ")
      buf.write_string(fc.count.to_string())
    }
  }

  buf.to_string()
}
