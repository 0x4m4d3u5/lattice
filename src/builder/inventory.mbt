///|
priv enum OutputOrigin {
  Page(String)
  StaticAsset(String)
  Generated
  BuildMetadata
}

///|
/// One final file or explicitly excluded candidate. Paths are output-relative;
/// sources are authored paths, never rendered content. Status is planned/excluded.
pub(all) struct InventoryEntry {
  path : String
  source : String?
  kind : String
  status : String
  reason : String
}

///|
/// A forced-build preview. Blocked preparation/preflight returns no partial list.
pub(all) struct PublicationInventory {
  output_dir : String?
  ready : Bool
  entries : Array[InventoryEntry]
  diagnostics : Array[@diagnostic.Diagnostic]
}

///|
fn inventory_entry(
  root : String,
  path : String,
  origin : OutputOrigin,
  status : String,
  reason : String,
) -> InventoryEntry {
  let (kind, source) = match origin {
    Page(source) => ("page", Some(source))
    StaticAsset(source) => ("static_asset", Some(source))
    Generated => ("generated", None)
    BuildMetadata => ("build_metadata", None)
  }
  {
    path: @path.Path(output_path_key(path))
    .relative(base=@path.Path(root))
    .to_string(),
    source,
    kind,
    status,
    reason,
  }
}

///|
fn OutputPlan::exclude_page(
  self : OutputPlan,
  source : String,
  path : String,
  reason : String,
) -> Unit {
  self.excluded.push(
    inventory_entry(self.root, path, Page(source), "excluded", reason),
  )
}

///|
/// Uses build's full preparation and destination preflight, never publish.
/// A fresh cache deliberately lists all intended files, not incremental writes.
/// Warnings (including broken wikilinks) retain build's policy; use check strictly.
pub fn inventory(config : BuildConfig) -> PublicationInventory {
  let output = OutputPlan::new(config.output_dir)
  let prepared = prepare_output(
    { ..config, force_rebuild: true, },
    @cache.empty(config.output_dir),
    output,
  )
  if prepared.errors == 0 {
    output.preflight() catch {
      @fs.IOError(msg) =>
        prepared.diagnostics.push(
          build_error(
            Some(config.output_dir),
            None,
            None,
            "output preflight failed: " + msg,
          ),
        )
    }
  }
  let ready = prepared.errors == 0 &&
    @diagnostic.count_errors(prepared.diagnostics) == 0
  let entries : Array[InventoryEntry] = []
  if ready {
    let final_slots : Map[String, Int] = Map([])
    for index, (path, _) in output.files {
      final_slots.set(path, index)
    }
    for index, (path, content) in output.files {
      let included = final_slots.get(path) == Some(index)
      let reason = if !included {
        "superseded by later output at the same path"
      } else {
        match content {
          OptionalText(_) => "optional output; write failure warns"
          _ => "final planned output"
        }
      }
      entries.push(
        inventory_entry(
          output.root,
          path,
          output.origins[index],
          if included {
            "planned"
          } else {
            "excluded"
          },
          reason,
        ),
      )
    }
    for entry in output.excluded {
      entries.push(entry)
    }
    entries.sort_by(fn(a, b) {
      let keys_a = [a.path, a.status, a.kind, a.source.unwrap_or(""), a.reason]
      let keys_b = [b.path, b.status, b.kind, b.source.unwrap_or(""), b.reason]
      for i = 0; i < keys_a.length(); i = i + 1 {
        let compared = keys_a[i].compare(keys_b[i])
        if compared != 0 {
          return compared
        }
      }
      0
    })
  }
  prepared.diagnostics.sort_by(fn(a, b) {
    let path_order = a.path.unwrap_or("").compare(b.path.unwrap_or(""))
    if path_order != 0 {
      return path_order
    }
    let line_order = a.line.unwrap_or(0).compare(b.line.unwrap_or(0))
    if line_order != 0 {
      return line_order
    }
    let column_order = a.column.unwrap_or(0).compare(b.column.unwrap_or(0))
    if column_order != 0 {
      return column_order
    }
    @diagnostic.format_diagnostic(a).compare(@diagnostic.format_diagnostic(b))
  })
  {
    output_dir: Some(output.root),
    ready,
    entries,
    diagnostics: prepared.diagnostics,
  }
}

///|
fn inventory_string(value : String?) -> Json {
  match value {
    Some(value) => Json::string(value)
    None => Json::null()
  }
}

///|
fn inventory_integer(value : Int?) -> Json {
  match value {
    Some(value) => Json::number(value.to_double())
    None => Json::null()
  }
}

///|
let inventory_notice : String = "Forced-build preview only: no output, cache or manifest writes. Not a filesystem-success or privacy guarantee. Vault types do not filter publication; configured static assets are copied wholesale. Existing stale files are not removed or inventoried."

///|
pub fn format_inventory_json(result : PublicationInventory) -> String {
  let entries = result.entries.map(fn(entry) {
    Json::object(
      Map([
        ("path", Json::string(entry.path)),
        ("source", inventory_string(entry.source)),
        ("kind", Json::string(entry.kind)),
        ("status", Json::string(entry.status)),
        ("reason", Json::string(entry.reason)),
      ]),
    )
  })
  let diagnostics = result.diagnostics.map(fn(d) {
    Json::object(
      Map([
        (
          "severity",
          Json::string(
            if d.severity == @diagnostic.Error {
              "error"
            } else {
              "warning"
            },
          ),
        ),
        ("code", inventory_string(d.code)),
        ("path", inventory_string(d.path)),
        ("line", inventory_integer(d.line)),
        ("column", inventory_integer(d.column)),
        ("message", Json::string(d.message)),
        ("note", inventory_string(d.note)),
      ]),
    )
  })
  Json::object(
    Map([
      ("version", Json::number(1)),
      ("output_dir", inventory_string(result.output_dir)),
      ("ready", Json::boolean(result.ready)),
      ("notice", Json::string(inventory_notice)),
      ("entries", Json::array(entries)),
      ("diagnostics", Json::array(diagnostics)),
    ]),
  ).stringify()
}

///|
pub fn format_inventory(result : PublicationInventory) -> String {
  let lines = [
    "Publication inventory: " +
    (if result.ready { "prepared" } else { "blocked" }),
    inventory_notice,
  ]
  if result.output_dir is Some(root) {
    lines.push("Output: " + root)
  }
  for entry in result.entries {
    lines.push(
      entry.status +
      " " +
      entry.kind +
      " " +
      Json::string(entry.path).stringify() +
      (match entry.source {
        Some(source) => " <- " + Json::string(source).stringify()
        None => ""
      }) +
      " — " +
      entry.reason,
    )
  }
  for d in result.diagnostics {
    lines.push(@diagnostic.format_diagnostic(d))
  }
  lines.iter().join("\n")
}
