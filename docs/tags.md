# Tags in Lattice

Lattice provides first-class support for tagging content through typed frontmatter. Tags enable users to browse and discover content by topic.

## Frontmatter Configuration

Tags are defined in collection schemas as `Array[String]`:

```toml
[collections/posts]
schema = "title:String, date:Date, tags:Optional[Array[String]]"
dir = "./content/posts"
```

```toml
---
title = "Understanding Lattice Architecture"
date = "2024-03-15"
tags = [lattice, architecture, ssg]
---
```

### Tag Field Name

The default field name is `tags`, but this can be configured in `site.cfg`:

```toml
tags_field = "tags"
```

## Tag Pages

Lattice automatically generates tag pages for each tag used across your content.

### Per-Tag Pages

For each tag, Lattice generates:
- `/tags/{tag-slug}/index.html` — lists all pages with that tag
- Pagination support when many pages share a tag

Example: For tag `lattice`, the URL is `/tags/lattice/`.

### Tags Index Page

A top-level index page listing all tags:
- `/tags/index.html` — shows all tags with post counts
- Pagination support when many tags exist

## Tag Page Templates

Lattice looks for templates in your templates directory:

### `tag.html`

Template for individual tag pages (e.g., `/tags/lattice/`):

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>Tag: {{tag_name}} | {{site_name}}</title>
  <meta name="description" content="Pages tagged with '{{tag_name}}' in {{site_name}}." />
  <link rel="stylesheet" href="/static/style.css" />
</head>
<body>
  <header>
    <h1>{{data.nav.title}}</h1>
    <nav>{{nav_links}}</nav>
  </header>
  <main>
    <section>
      <h2>Tag: {{tag_name}}</h2>
      <p>{{tag_count}} page(s) tagged with '{{tag_name}}'</p>
      <ul>
        {{content}}
      </ul>
    </section>
  </main>
  <footer>
    <p>{{data.site.footer}}</p>
  </footer>
</body>
</html>
```

**Available slots:**
- `{{tag_name}}` — the tag display name
- `{{tag_count}}` — number of pages with this tag
- `{{content}}` — generated HTML listing pages (includes links and slugs)
- `{{page_num}}` — current page number (for pagination)
- `{{is_first_page}}` — true if page 1
- `{{is_last_page}}` — true if last page

### `tags.html`

Template for the tags index page (`/tags/`):

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>Tags | {{site_name}}</title>
  <meta name="description" content="All tags in {{site_name}}." />
  <link rel="stylesheet" href="/static/style.css" />
</head>
<body>
  <header>
    <h1>{{data.nav.title}}</h1>
    <nav>{{nav_links}}</nav>
  </header>
  <main>
    <section>
      <h2>Tags</h2>
      <p>{{tag_count}} tags found</p>
      <ul>
        {{content}}
      </ul>
    </section>
  </main>
  <footer>
    <p>{{data.site.footer}}</p>
  </footer>
</body>
</html>
```

**Available slots:**
- `{{tag_count}}` — total number of tags
- `{{content}}` — generated HTML listing all tags with links and counts
- `{{page_num}}` — current page number (for pagination)
- `{{is_first_page}}` — true if page 1
- `{{is_last_page}}` — true if last page

### Fallback Behavior

If `tag.html` or `tags.html` templates are not found, Lattice falls back to:
1. Using `index.html` template with tag-specific slots filled
2. If no templates exist, generates plain HTML with minimal styling

## Displaying Tags on Pages

Pages automatically include a tags section when they have tags. The generated HTML includes:

```html
<section>
<h2>Tags</h2>
<ul>
  <li><a href="/tags/lattice/">lattice</a></li>
  <li><a href="/tags/architecture/">architecture</a></li>
  <li><a href="/tags/ssg/">ssg</a></li>
</ul>
</section>
```

This is automatically appended to the page content and rendered through your page template.

## Tag Validation

Lattice enforces structural guarantees for tags:

### Type Safety

- Tags must be an `Array[String]` in frontmatter
- Non-array values cause build errors
- Non-string array elements cause build errors

### Deduplication

- Duplicate tags are automatically removed within a single post
- Tags are trimmed of leading/trailing whitespace

### Empty Tag Handling

- Empty strings in tag arrays are automatically skipped
- Posts with no `tags` field have no tags section

### Dangling Tag Detection

When building, Lattice validates that all referenced tags exist in the tag catalog:

```
error: dangling tag reference 'unknown-tag' (unknown-tag) missing from tag index
```

This prevents orphaned tag references from generating 404s.

## Tag URLs

Tags are converted to URL-safe slugs using the same normalization as page slugs:
- Lowercased
- Special characters removed or replaced
- Hyphens for word separation

Example mappings:
- `C#` → `/tags/csharp/`
- `WebAssembly` → `/tags/webassembly/`
- `test & demo` → `/tags/test-demo/`

## Navigation

The tags link is automatically added to the site navigation:

```html
<nav>
  <a href="/tags/">tags</a>
  <a href="/posts/">posts</a>
  <a href="/projects/">projects</a>
</nav>
```

This is rendered through the `{{nav_links}}` template slot.

## Pagination

Both tag pages and the tags index support pagination based on `page_size` in `site.cfg`:

```toml
page_size = 10
```

Pagination includes:
- Previous/next page links
- Page number display
- Clean URLs (`/tags/page/2/`, `/tags/my-tag/page/3/`)

## Examples

See the example site for a working tag implementation:
- `example/content/posts/` — posts with various tags
- `example/templates/tag.html` — individual tag page template
- `example/templates/tags.html` — tags index template
- `example/collections.cfg` — tag field schema definition

Build the example site to see generated tag pages:

```bash
cd example
moon run ../cmd/main/main build
```

Generated output:
- `_build/tags/index.html` — tags index
- `_build/tags/lattice/index.html` — lattice tag page
- `_build/tags/architecture/index.html` — architecture tag page
- etc.