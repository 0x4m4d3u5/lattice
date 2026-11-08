///|
test "ordinary image destinations can opt into the shared parsed reference walk" {
  let source =
    #|[page](/page/) ![image](/image.png)
    #|
    #|> [!note] ![title](/title.png)
    #|> ![inside](/inside.png)
    #|
    #|- ![list](/list.png)
    #|
    #|Reference[^one].
    #|
    #|[^one]: ![footnote](/footnote.png)
    #|
    #|`![code](/code.png)` <img src="/raw.png">
    #|
    #|```md
    #|![fenced](/fenced.png)
    #|```
  assert_eq(@markdown.extract_link_destinations(source), ["/page/"])
  let targets = @markdown.extract_link_destinations(source, include_images=true)
  assert_eq(targets, [
    "/page/", "/image.png", "/title.png", "/inside.png", "/list.png", "/footnote.png",
  ])
}
