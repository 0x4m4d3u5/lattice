`example/` is the smallest site in-repo that still exercises the main lattice feature set.

Key files:

- `site.cfg`: inline collections, pagination, root page, feed/search/sitemap-related config, and comments on what each setting demonstrates.
- `content/pages/home.md`: root page, internal links, second collection.
- `content/pages/about.md`: standalone page in the `pages` collection.
- `content/posts/typed-content-tour.md`: YAML frontmatter, TOC, footnotes, syntax highlighting, tags, JSON-LD-ready metadata.
- `content/posts/template-composition.md`: internal links plus the custom layout/partial template story.
- `content/posts/release-checkpoint.md`: shared tags for tag indexes and RSS content.
- `content/posts/future-work.md`: draft post, only emitted with `--drafts`.
- `content/404.md`: custom 404 page.
- `templates/base.html`, `templates/head.html`, `templates/header.html`, `templates/footer.html`: layout + partial composition.
- `templates/page.html`: content page template that composes through `base.html`.
- `templates/index.html`, `templates/tag.html`, `templates/tags.html`: collection and tag pages.
- `content/static/style.css`: site styling plus space for injected syntax highlight CSS.

Build it with:

```bash
moon run cmd/main -- ./example/content ./example/dist --config ./example/site.cfg
```
