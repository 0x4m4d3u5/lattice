pub(all) enum Severity {
  Error
  Warning
}

pub(all) struct Diagnostic {
  severity : Severity
  code : String?
  path : String?
  line : Int?
  column : Int?
  message : String
  note : String?
}

let ansi_reset = "\u001b[0m"
let ansi_bold = "\u001b[1m"
let ansi_dim = "\u001b[2m"
let ansi_red = "\u001b[31m"
let ansi_yellow = "\u001b[33m"
let ansi_cyan = "\u001b[36m"
let ansi_underline = "\u001b[4m"
let ansi_white = "\u001b[37m"

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

pub fn count_errors(items : Array[Diagnostic]) -> Int {
  let mut total = 0
  let mut i = 0
  while i < items.length() {
    match items[i].severity {
      Error => total = total + 1
      Warning => ()
    }
    i = i + 1
  }
  total
}

fn severity_label(severity : Severity) -> String {
  match severity {
    Error => "error"
    Warning => "warning"
  }
}

fn severity_color(severity : Severity) -> String {
  match severity {
    Error => ansi_red
    Warning => ansi_yellow
  }
}

fn colored_severity(severity : Severity) -> String {
  severity_color(severity) + ansi_bold + severity_label(severity) + ansi_reset
}

fn colored_code(code : String) -> String {
  ansi_bold + "[" + code + "]" + ansi_reset
}

fn colored_path(path : String) -> String {
  ansi_cyan + ansi_underline + path + ansi_reset
}

fn colored_number(value : Int) -> String {
  ansi_white + ansi_dim + value.to_string() + ansi_reset
}

pub fn format_diagnostic(d : Diagnostic) -> String {
  let buf = StringBuilder::new()
  buf.write_string(colored_severity(d.severity))
  match d.code {
    Some(code) => buf.write_string(colored_code(code))
    None => ()
  }
  buf.write_string(": ")
  buf.write_string(d.message)
  match d.path {
    Some(path) => {
      buf.write_string("\n  --> ")
      buf.write_string(colored_path(path))
      match d.line {
        Some(line) => {
          buf.write_string(":")
          buf.write_string(colored_number(line))
          match d.column {
            Some(col) => {
              buf.write_string(":")
              buf.write_string(colored_number(col))
            }
            None => ()
          }
        }
        None => ()
      }
    }
    None => ()
  }
  match d.note {
    Some(note) => {
      buf.write_string("\n  = note: ")
      buf.write_string(note)
    }
    None => ()
  }
  buf.to_string()
}

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
  }
}

pub fn of_lint_violation(v : @lint.LintViolation) -> Diagnostic {
  {
    severity: Error,
    code: Some(code_for_violation(v.kind)),
    path: Some(v.path),
    line: v.line,
    column: v.column,
    message: v.message,
    note: None,
  }
}
