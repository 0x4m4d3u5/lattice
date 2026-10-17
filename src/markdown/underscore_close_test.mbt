///|
test "underscore emphasis searches past multiple intraword closers" {
  // Literal HTML independently checked with cmark-gfm --unsafe.
  for
    (source, expected) in [
      ("_alpha_beta_gamma_delta_", "<p><em>alpha_beta_gamma_delta</em></p>\n"),
      (
        "__alpha__beta__gamma__delta__", "<p><strong>alpha__beta__gamma__delta</strong></p>\n",
      ),
      (
        "_alpha_beta_gamma_delta_ and _later_.", "<p><em>alpha_beta_gamma_delta</em> and <em>later</em>.</p>\n",
      ),
      ("_alpha_beta_gamma_delta", "<p>_alpha_beta_gamma_delta</p>\n"),
      ("alpha__beta__gamma", "<p>alpha__beta__gamma</p>\n"),
    ] {
    assert_eq(@markdown.render(source, Map([])), expected)
  }
  let source = "_" + "alpha_".repeat(4000) + "omega_"
  assert_eq(
    @markdown.render(source, Map([])),
    "<p><em>" + "alpha_".repeat(4000) + "omega</em></p>\n",
  )
  let unmatched = "_x_1 ".repeat(4000)
  assert_eq(
    @markdown.render(unmatched, Map([])),
    "<p>" + unmatched.trim_end().to_owned() + "</p>\n",
  )
}
