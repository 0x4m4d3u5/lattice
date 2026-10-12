///|
pub(all) enum Severity {
  Error
  Warning
} derive(Eq, Debug)

///|
pub impl Show for Severity with fn output(self, logger) {
  match self {
    Error => logger.write_string("Error")
    Warning => logger.write_string("Warning")
  }
}

///|
pub(all) struct Diagnostic {
  severity : Severity
  code : String?
  path : String?
  line : Int?
  column : Int?
  message : String
  note : String?
}

///|
let ansi_reset = "\u001b[0m"

///|
let ansi_bold = "\u001b[1m"

///|
let ansi_dim = "\u001b[2m"

///|
let ansi_red = "\u001b[31m"

///|
let ansi_yellow = "\u001b[33m"

///|
let ansi_underline = "\u001b[4m"

///|
pub fn error(message : String) -> Diagnostic {
  {
    severity: Error,
    code: None,
    path: None,
    line: None,
    column: None,
    message,
    note: None,
  }
}

///|
pub fn warning(message : String) -> Diagnostic {
  {
    severity: Warning,
    code: None,
    path: None,
    line: None,
    column: None,
    message,
    note: None,
  }
}

///|
pub fn count_errors(items : Array[Diagnostic]) -> Int {
  let mut total = 0
  for d in items {
    match d.severity {
      Error => total = total + 1
      Warning => ()
    }
  }
  total
}

///|
fn severity_label(severity : Severity) -> String {
  match severity {
    Error => "error"
    Warning => "warning"
  }
}

///|
fn severity_color(severity : Severity) -> String {
  match severity {
    Error => ansi_red
    Warning => ansi_yellow
  }
}

///|
fn colored_severity(severity : Severity) -> String {
  severity_color(severity) +
  ansi_bold +
  "[" +
  severity_label(severity) +
  "]" +
  ansi_reset
}

///|
fn colored_code(code : String) -> String {
  ansi_dim + "[" + code + "]" + ansi_reset
}

///|
fn colored_location(location : String) -> String {
  ansi_bold + ansi_underline + location + ansi_reset
}

///|
pub fn format_diagnostic(d : Diagnostic) -> String {
  let buf = StringBuilder()
  match d.path {
    Some(path) => {
      let location = StringBuilder()
      location.write_string(path)
      match d.line {
        Some(line) => {
          location.write_string(":")
          location.write_string(line.to_string())
          match d.column {
            Some(col) => {
              location.write_string(":")
              location.write_string(col.to_string())
            }
            None => ()
          }
        }
        None => ()
      }
      buf.write_string(colored_location(location.to_string()))
      buf.write_string(" ")
    }
    None => ()
  }
  buf.write_string(colored_severity(d.severity))
  match d.code {
    Some(code) => {
      buf.write_string(" ")
      buf.write_string(colored_code(code))
    }
    None => ()
  }
  buf.write_string(" ")
  buf.write_string(d.message)
  match d.note {
    Some(note) => {
      buf.write_string("\n  hint: ")
      buf.write_string(note)
    }
    None => ()
  }
  buf.to_string()
}

///|
fn code_for_violation(kind : @lint.ViolationType) -> String {
  match kind {
    @lint.MissingRequiredFrontmatter => "E001"
    @lint.SchemaError => "E002"
    @lint.FrontmatterError => "E003"
    @lint.BrokenWikilink => "E004"
    @lint.DanglingTagReference => "E005"
    @lint.TemplateSlotError => "E006"
    @lint.DataError => "E007"
    @lint.ShortcodeError => "E008"
    @lint.CollectionsError => "E009"
    @lint.DuplicateSlug => "E010"
    @lint.IOError => "E011"
    @lint.MissingImageAlt => "E012"
  }
}

///|
fn hint_for_violation(kind : @lint.ViolationType) -> String? {
  match kind {
    @lint.MissingRequiredFrontmatter =>
      Some(
        "add the missing field to the --- frontmatter block at the top of the file",
      )
    @lint.SchemaError => Some("check the field type in the collection schema")
    @lint.FrontmatterError =>
      Some("frontmatter must be valid TOML-like syntax between --- delimiters")
    @lint.BrokenWikilink =>
      Some(
        "check that the target file exists and its slug matches the link target",
      )
    @lint.DanglingTagReference =>
      Some("ensure the referenced tag has a corresponding tag page template")
    @lint.TemplateSlotError =>
      Some("check the template for the correct slot name")
    @lint.DataError =>
      Some(
        "verify the data file path and schema match the collection definition",
      )
    @lint.ShortcodeError => Some("check the shortcode name and argument syntax")
    @lint.CollectionsError =>
      Some("review the collections config file for syntax errors")
    @lint.DuplicateSlug =>
      Some("rename one of the conflicting files so slugs are unique")
    @lint.IOError => Some("check file permissions and that the path exists")
    @lint.MissingImageAlt =>
      Some(
        "add descriptive Markdown alt text; for decorative images use the image shortcode with explicit alt=\"\"",
      )
  }
}

///|
pub fn of_lint_violation(v : @lint.LintViolation) -> Diagnostic {
  {
    severity: Error,
    code: Some(code_for_violation(v.kind)),
    path: Some(v.path),
    line: v.line,
    column: v.column,
    message: v.message,
    note: hint_for_violation(v.kind),
  }
}

// ── build summary ────────────────────────────────────────────────────────────

///|
/// Count of diagnostics for a single error code.
pub(all) struct CodeCount {
  code : String
  count : Int
}

///|
/// Count of diagnostics for a single file path.
pub(all) struct DiagnosticFileCount {
  path : String
  count : Int
}

///|
/// Structured summary of build diagnostics, grouped by severity, code, and file.
///
/// Provides three breakdowns:
/// - **error_count / warning_count**: totals by severity
/// - **by_code**: how many diagnostics for each error code (E001–E012)
/// - **by_file**: how many diagnostics per source file
///
/// Used by the build command to emit a structured summary after the
/// individual diagnostic lines.
pub(all) struct DiagnosticSummary {
  error_count : Int
  warning_count : Int
  by_code : Array[CodeCount]
  by_file : Array[DiagnosticFileCount]
}

///|
/// Compute a structured summary from an array of diagnostics.
///
/// Groups by error code and by file path, sorted by count descending.
pub fn summarize(diagnostics : Array[Diagnostic]) -> DiagnosticSummary {
  let mut error_count = 0
  let mut warning_count = 0
  let code_counts : Map[String, Int] = Map([])
  let file_counts : Map[String, Int] = Map([])

  for d in diagnostics {
    match d.severity {
      Error => error_count = error_count + 1
      Warning => warning_count = warning_count + 1
    }
    match d.code {
      Some(code) =>
        code_counts.update(code, fn(prev) {
          match prev {
            Some(n) => Some(n + 1)
            None => Some(1)
          }
        })
      None => ()
    }
    match d.path {
      Some(path) =>
        file_counts.update(path, fn(prev) {
          match prev {
            Some(n) => Some(n + 1)
            None => Some(1)
          }
        })
      None => ()
    }
  }

  let by_code : Array[CodeCount] = []
  for code, count in code_counts {
    by_code.push({ code, count })
  }
  by_code.sort_by((a, b) => b.count.compare(a.count))

  let by_file : Array[DiagnosticFileCount] = []
  for path, count in file_counts {
    by_file.push({ path, count })
  }
  by_file.sort_by((a, b) => b.count.compare(a.count))

  { error_count, warning_count, by_code, by_file }
}

///|
/// Format a `DiagnosticSummary` as a human-readable multi-line summary.
///
/// Output format:
/// ```
/// Summary: 3 error(s), 1 warning(s)
///   By code:
///     E002: 2
///     E004: 1
///   By file:
///     content/posts/broken.md: 3
/// ```
pub fn format_summary(summary : DiagnosticSummary) -> String {
  let buf = StringBuilder()
  buf.write_string("Summary: ")
  buf.write_string(summary.error_count.to_string())
  buf.write_string(" error(s), ")
  buf.write_string(summary.warning_count.to_string())
  buf.write_string(" warning(s)")

  if summary.by_code.length() > 0 {
    buf.write_string("\n  By code:")
    for cc in summary.by_code {
      buf.write_string("\n    ")
      buf.write_string(cc.code)
      buf.write_string(": ")
      buf.write_string(cc.count.to_string())
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

  if summary.by_code.length() > 0 {
    buf.write_string(
      "\n  hint: run `lattice explain <code>` for details on any error code",
    )
  }

  buf.to_string()
}

///|
pub extend Severity with @debug.Debug::{to_repr}

///|
pub extend Severity with Eq::{not_equal, equal}

///|
pub extend Severity with Show::{to_string, output}
