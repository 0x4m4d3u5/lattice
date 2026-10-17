///|
test "fenced language quotes stay within their class attribute" {
  let source = "~~~x\"\u000conmouseover=\"this.dataset.latticeProbe='executed'\nhello\n~~~"
  assert_eq(
    @markdown.render(source, Map([])),
    "<pre><code class=\"language-x&quot;\u000conmouseover=&quot;this.dataset.latticeProbe='executed'\">hello</code></pre>\n",
  )
  assert_eq(
    @markdown.render("~~~🌱\"&<\nhello\n~~~", Map([])),
    "<pre><code class=\"language-🌱&quot;&amp;&lt;\">hello</code></pre>\n",
  )
  let highlighted = @markdown.render("~~~python\nreturn 42\n~~~", Map([]))
  assert_true(highlighted.contains("class=\"highlight language-python\""))
  assert_true(highlighted.contains("class=\"hl-keyword\">return</span>"))
}
