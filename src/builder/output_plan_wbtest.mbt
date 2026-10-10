///|
test "output plan preflights normalized file-directory aliases without mutation" {
  let root = "./_tmp_output_plan_aliases"
  let output = OutputPlan::new(root)
  output.write_text(root + "/nested/../clash", "file")
  output.write_text(root + "//clash/child.html", "child")
  let rejected = try {
    output.preflight()
    false
  } catch {
    @fs.IOError(msg) => msg.contains("both a file and a directory")
  }
  assert_true(rejected)
  assert_false(@fs.path_exists(root))
}

///|
test "output plan rejects escaping file and empty-directory targets" {
  let root = "./_tmp_output_plan_containment"
  let output = OutputPlan::new(root)
  for path in [root + "/../escape.html", root] {
    let rejected = try {
      output.write_text(path, "file")
      false
    } catch {
      @fs.IOError(_) => true
    }
    assert_true(rejected)
  }
  let rejected = try {
    output.ensure_dir(root + "/../escape")
    false
  } catch {
    @fs.IOError(_) => true
  }
  assert_true(rejected)
  assert_false(@fs.path_exists(root))
}

///|
test "output plan retains ordered writes to the same file" {
  let root = "./_tmp_output_plan_duplicate"
  let output = OutputPlan::new(root)
  output.write_text(root + "/index.html", "first")
  output.write_text(root + "/./index.html", "second")
  output.preflight()
  assert_eq(output.files.length(), 2)
  assert_eq(output.files[0].0, output.files[1].0)
  assert_false(@fs.path_exists(root))
}

///|
test "optional output write failure warns and continues publication" {
  let prefix = "./_tmp_output_plan_optional_"
  let mut suffix = 0
  while @fs.path_exists(prefix + suffix.to_string()) {
    suffix += 1
  }
  let root = prefix + suffix.to_string()
  @fs.create_dir(root)
  // A directory makes the optional write fail without permission assumptions.
  @fs.create_dir(root + "/style.css")
  let output = OutputPlan::new(root)
  output.write_optional_text(root + "/style.css", "css")
  output.write_text(root + "/index.html", "page")
  let diagnostics : Array[@diagnostic.Diagnostic] = []
  let messages : Array[String] = []
  output.publish(diagnostics, messages)
  assert_eq(@fs.read_file_to_string(root + "/index.html"), "page")
  assert_eq(@diagnostic.count_errors(diagnostics), 0)
  assert_eq(diagnostics.length(), 1)
  assert_eq(diagnostics[0].severity, @diagnostic.Warning)
  assert_eq(messages.length(), 0)
}
