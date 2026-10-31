///|
fn image_embed_target_supported(target : String) -> Bool {
  if target.is_empty() ||
    target.has_prefix("/") ||
    target.contains("\\") ||
    target.contains(":") ||
    target.contains("|") ||
    target.contains("#") ||
    target.contains("?") ||
    target.iter().any(fn(c) { c.is_control() }) {
    return false
  }
  if target
    .split("/")
    .any(fn(part) { part == ".." || part == "." || part.is_empty() }) {
    return false
  }
  let lower = target.to_lower()
  [".png", ".jpg", ".jpeg", ".gif", ".webp", ".avif", ".bmp"].any(fn(ext) {
    lower.has_suffix(ext)
  })
}

///|
fn image_asset_url(relative_path : String) -> String {
  "/" +
  relative_path.split("/").map(fn(part) { @percent.encode(part) }).join("/")
}

///|
/// Use only the existing static snapshot: no vault-wide discovery or new copy
/// policy. A blank destination records ambiguity instead of choosing by order.
fn register_image_assets(
  config : BuildConfig,
  index : Map[String, String],
  collections : Array[CollectionSources],
) -> Unit {
  if !image_embed_sources(collections, config).any(fn(source) {
      match @frontmatter.parse(source.content) {
        Ok(fm) => !@markdown.extract_image_embeds(fm.body).is_empty()
        Err(_) => false
      }
    }) {
    return
  }
  let static_dir = static_dir_name(config.site)
  guard @assets.read_static(config.content_dir, static_dir) is Ok(assets) else {
    return
  }
  let qualified_prefix = output_path_key(static_dir) + "/"
  for asset in assets {
    let path = output_path_key(static_dir + "/" + asset.relative_path)
    if !image_embed_target_supported(path) {
      continue
    }
    let url = image_asset_url(path)
    let parts = asset.relative_path.split("/").to_array()
    let basename = parts[parts.length() - 1].to_owned()
    for target in [asset.relative_path, basename] {
      if target.has_prefix(qualified_prefix) { continue }
      let key = @markdown.image_embed_key(target)
      match index.get(key) {
        None => index.set(key, url)
        Some(previous) => if previous != url { index.set(key, "") }
      }
    }
  }
  // Fully qualified published paths win over coincidentally identical
  // static-relative names, so every ambiguous basename has an escape hatch.
  for asset in assets {
    let path = output_path_key(static_dir + "/" + asset.relative_path)
    if image_embed_target_supported(path) {
      index.set(@markdown.image_embed_key(path), image_asset_url(path))
    }
  }
}

///|
fn image_embed_location(source : String, target : String) -> (Int32?, Int32?) {
  let mut cursor = 0
  while cursor < source.length() {
    let start = @strutil.find_str(source, cursor, "![[", source.length())
    if start < 0 {
      break
    }
    let end = @strutil.find_str(source, start + 3, "]]", source.length())
    if end < 0 {
      break
    }
    let newline = @strutil.find_str(source, end + 2, "\n", source.length())
    let line_end = if newline < 0 { source.length() } else { newline }
    let prefix = source[:line_end].to_owned()
    let masked = source[:start].to_owned() +
      " " +
      source[start + 1:line_end].to_owned()
    fn count(text : String) -> Int32 {
      let body = match @frontmatter.parse(text) {
        Ok(fm) => fm.body
        Err(_) => text
      }
      @markdown.extract_image_embeds(body)
      .filter(fn(item) { item == target })
      .length()
    }
    // Include the whole line so a closing backtick remains visible. Masking
    // just this bang tests whether this candidate actually contributed a node.
    if count(prefix) > count(masked) {
      let lines = source[:start].split("\n").to_array()
      return (
        Some(lines.length()),
        Some(lines[lines.length() - 1].length() + 1),
      )
    }
    cursor = end + 2
  }
  (None, None)
}

///|
fn check_image_embeds(
  collections : Array[CollectionSources],
  config : BuildConfig,
  index : Map[String, String],
  output : OutputPlan,
  violations : Array[@lint.LintViolation],
) -> Unit {
  let final_assets : Map[String, Bool] = Map([])
  for i = 0; i < output.files.length(); i = i + 1 {
    let (path, contents) = output.files[i]
    let relative = @path.Path(path)
      .relative(base=@path.Path(output.root))
      .to_string()
    let is_asset = match (output.origins[i], contents) {
      (StaticAsset(_), Binary(_)) => true
      _ => false
    }
    final_assets.set(image_asset_url(relative), is_asset)
  }
  for source in image_embed_sources(collections, config) {
    if !source_is_visible(source, config.include_drafts) {
      continue
    }
    guard @frontmatter.parse(source.content) is Ok(fm) else { continue }
    for target in @markdown.extract_image_embeds(fm.body) {
      let key = @markdown.image_embed_key(target)
      let message = if !image_embed_target_supported(target) {
        Some(
          "unsupported target; use a local PNG, JPEG, GIF, WebP, AVIF or BMP path without sizing or fragment syntax",
        )
      } else {
        match index.get(key) {
          None =>
            Some("attachment not found in the configured static directory")
          Some("") =>
            Some("ambiguous attachment name; use a static-root-qualified path")
          Some(url) =>
            if final_assets.get(url) == Some(true) {
              None
            } else {
              Some(
                "destination is not a retained static asset in the publication plan",
              )
            }
        }
      }
      if message is Some(message) {
        let (line, column) = image_embed_location(source.content, target)
        violations.push({
          path: source.path,
          line,
          column,
          kind: @lint.BrokenWikilink,
          message: "image embed " + key + ": " + message,
        })
      }
    }
  }
}

///|
fn image_embed_sources(
  collections : Array[CollectionSources],
  config : BuildConfig,
) -> Array[SourceFile] {
  let sources : Array[SourceFile] = []
  for collection in collections {
    for source in collection.sources {
      sources.push(source)
    }
  }
  let path = config.content_dir + "/404.md"
  if @fs.path_exists(path) {
    let content = @fs.read_file_to_string(path) catch { _ => return sources }
    sources.push({
      path,
      filename: "404.md",
      slug: "404",
      content,
      fingerprint: "",
      stamp: 0L,
      link_targets: [],
    })
  }
  sources
}
