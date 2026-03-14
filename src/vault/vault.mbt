///|
/// Vault-specific workflow helpers for lattice.
///
/// Provides utilities for PARA-method note organization and vault-specific
/// metadata extraction. This layer exists on top of standard collections
/// system to support note-taking workflows (e.g., Obsidian vaults) that
/// use type/status/purpose/goal fields and cross-reference patterns.

///|
/// Vault-specific frontmatter fields used in PARA workflows.
pub(all) struct VaultMetadata {
  note_type : String?
  status : String?
  purpose : String?
  goal : String?
  source : String?
  created : String?
}

///|
/// Extract vault-specific metadata from parsed frontmatter.
///
/// Returns None if no vault fields are present, making it safe to call on
/// any frontmatter without assuming it follows vault conventions.
pub fn extract_vault_metadata(fm : @frontmatter.Frontmatter) -> VaultMetadata? {
  let mut note_type : String? = None
  let mut status : String? = None
  let mut purpose : String? = None
  let mut goal : String? = None
  let mut source : String? = None
  let mut created : String? = None

  match fm.fields.get("type") {
    Some(@frontmatter.FStr(t)) => note_type = Some(t)
    _ => ()
  }

  match fm.fields.get("status") {
    Some(@frontmatter.FStr(s)) => status = Some(s)
    _ => ()
  }

  match fm.fields.get("purpose") {
    Some(@frontmatter.FStr(p)) => purpose = Some(p)
    _ => ()
  }

  match fm.fields.get("goal") {
    Some(@frontmatter.FStr(g)) => goal = Some(g)
    _ => ()
  }

  match fm.fields.get("source") {
    Some(@frontmatter.FStr(s)) => source = Some(s)
    _ => ()
  }

  match fm.fields.get("created") {
    Some(@frontmatter.FStr(c)) => created = Some(c)
    Some(@frontmatter.FDate(c)) => created = Some(c)
    _ => ()
  }

  if note_type == None &&
    status == None &&
    purpose == None &&
    goal == None &&
    source == None &&
    created == None {
    return None
  }

  Some({ note_type, status, purpose, goal, source, created })
}

///|
/// Check if a note represents an active project based on status.
///
/// Common project statuses: "active", "in-progress", "doing", "ongoing"
/// Returns false for "completed", "archived", "on-hold", or no status.
pub fn is_active_project(meta : VaultMetadata?) -> Bool {
  match meta {
    None => false
    Some(m) =>
      match m.status {
        None => false
        Some(s) => {
          let lower = to_lowercase(s)
          lower == "active" ||
          lower == "in-progress" ||
          lower == "doing" ||
          lower == "ongoing" ||
          lower == "in progress"
        }
      }
  }
}

///|
/// Check if a note should be considered archived.
///
/// Archive statuses include: "archived", "completed", "done", "finished"
pub fn is_archived(meta : VaultMetadata?) -> Bool {
  match meta {
    None => false
    Some(m) =>
      match m.status {
        None => false
        Some(s) => {
          let lower = to_lowercase(s)
          lower == "archived" ||
          lower == "completed" ||
          lower == "done" ||
          lower == "finished"
        }
      }
  }
}

///|
/// Categorize a note by type field for navigation and filtering.
///
/// Returns a stable category name even if type field uses different
/// capitalization or terminology.
pub fn categorize_note(meta : VaultMetadata?) -> String {
  match meta {
    None => "uncategorized"
    Some(m) =>
      match m.note_type {
        None => "uncategorized"
        Some(t) => normalize_type(t)
      }
  }
}

///|
/// Normalize type field values to canonical categories.
///
/// Handles common variations like "Project"/"project"/"PROJECT",
/// "Area"/"Area of Focus"/"Domain", etc.
fn normalize_type(raw_type : String) -> String {
  let lower = to_lowercase(raw_type)
  if lower == "project" || lower == "projects" {
    return "project"
  }
  if lower == "area" ||
    lower == "areas" ||
    lower == "area of focus" ||
    lower == "domain" ||
    lower == "domains" {
    return "area"
  }
  if lower == "resource" || lower == "resources" || lower == "reference" {
    return "resource"
  }
  if lower == "archive" || lower == "archived" {
    return "archive"
  }
  if lower == "inbox" || lower == "inbox item" || lower == "capture" {
    return "inbox"
  }
  if lower == "template" || lower == "templates" {
    return "template"
  }
  lower
}

///|
/// Generate a CSS class name for vault categorization.
///
/// Safe to use in HTML output - only returns lowercase letters and hyphens.
pub fn category_class(category : String) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  while i < category.length() {
    let c = char_at_vault(category, i)
    if (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') {
      buf.write_char(c)
    } else if c >= 'A' && c <= 'Z' {
      buf.write_char((c.to_int() + 32).unsafe_to_char())
    } else if c == ' ' || c == '_' {
      buf.write_char('-')
    }
    i = i + 1
  }
  buf.to_string()
}

///|
/// Format vault metadata as a compact badge element for display.
///
/// Example output:
///   <span class="vault-badge vault-type-project">Project</span>
///   <span class="vault-badge vault-status-active">Active</span>
///
/// Returns empty string if metadata is empty or all fields are None.
pub fn render_metadata_badge(meta : VaultMetadata?) -> String {
  match meta {
    None => ""
    Some(m) => {
      let parts : Array[(String, String)] = []
      match m.note_type {
        Some(t) => parts.push(("type", t))
        None => ()
      }
      match m.status {
        Some(s) => parts.push(("status", s))
        None => ()
      }
      if parts.length() == 0 {
        return ""
      }
      let buf = StringBuilder::new()
      let mut i = 0
      while i < parts.length() {
        let (kind, value) = parts[i]
        let class_suffix = match kind {
          "type" => {
            let cat = normalize_type(value)
            "vault-type-" + category_class(cat)
          }
          "status" => {
            let lower = to_lowercase(value)
            "vault-status-" + category_class(lower)
          }
          _ => "vault-meta-" + category_class(kind)
        }
        buf.write_string("<span class=\"vault-badge ")
        buf.write_string(class_suffix)
        buf.write_string("\">")
        buf.write_string(escape_html_vault(value))
        buf.write_string("</span>")
        if i < parts.length() - 1 {
          buf.write_char(' ')
        }
        i = i + 1
      }
      buf.to_string()
    }
  }
}

///|
/// Check if a page should be excluded from public-facing indexes.
///
/// Useful for inbox items, private notes, or WIP content.
/// Draft pages with type "inbox", "private", or "wip" are excluded.
pub fn should_exclude_from_index(meta : VaultMetadata?) -> Bool {
  match meta {
    None => false
    Some(m) =>
      match m.note_type {
        None => false
        Some(t) => {
          let lower = to_lowercase(t)
          lower == "private" ||
          lower == "inbox" ||
          lower == "wip" ||
          lower == "work in progress"
        }
      }
  }
}

///|
/// Extract a display-friendly category label for navigation.
///
/// Pluralizes and capitalizes for better UX in nav bars and breadcrumbs.
pub fn category_label(category : String) -> String {
  match category {
    "uncategorized" => "Uncategorized"
    "project" => "Projects"
    "area" => "Areas"
    "resource" => "Resources"
    "archive" => "Archive"
    "inbox" => "Inbox"
    "template" => "Templates"
    _ => {
      let buf = StringBuilder::new()
      if category.length() == 0 {
        return "Uncategorized"
      }
      let first = char_at_vault(category, 0)
      if first >= 'a' && first <= 'z' {
        buf.write_char((first.to_int() - 32).unsafe_to_char())
      } else {
        buf.write_char(first)
      }
      let mut i = 1
      while i < category.length() {
        buf.write_char(char_at_vault(category, i))
        i = i + 1
      }
      buf.to_string()
    }
  }
}

// ── private helpers ─────────────────────────────────────────────────────────────

///|
fn char_at_vault(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

///|
fn to_lowercase(s : String) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  while i < s.length() {
    let c = char_at_vault(s, i)
    if c >= 'A' && c <= 'Z' {
      buf.write_char((c.to_int() + 32).unsafe_to_char())
    } else {
      buf.write_char(c)
    }
    i = i + 1
  }
  buf.to_string()
}

///|
fn escape_html_vault(s : String) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  while i < s.length() {
    let c = char_at_vault(s, i)
    if c == '&' {
      buf.write_string("&amp;")
    } else if c == '<' {
      buf.write_string("&lt;")
    } else if c == '>' {
      buf.write_string("&gt;")
    } else if c == '"' {
      buf.write_string("&quot;")
    } else {
      buf.write_char(c)
    }
    i = i + 1
  }
  buf.to_string()
}
