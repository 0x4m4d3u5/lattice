# Templates

lattice templates are plain HTML files with `{{slot_name}}` placeholders. The template parser is intentionally strict: unknown slots and missing data paths are build errors, not silent empty strings.

That strictness is the point. Templates are part of the content contract, so a typo like `{{site_title}}` should fail immediately instead of shipping a broken page.

## Template files

The builder looks for these files under `templates_dir`:

- `page.html` for individual content pages
- `index.html` for collection index pages
- `tag.html` for per-tag pages, if present
- `tags.html` for the tags index, if present

In the example site, only `page.html` and `index.html` exist:

- `example/templates/page.html`
- `example/templates/index.html`

If `tag.html` or `tags.html` are missing, lattice falls back to `index.html` for tag output.

## Available slot names

The current implementation supports these built-in slots:

- `{{title}}`
- `{{content}}`
- `{{date}}`
- `{{description}}`
- `{{url}}`
- `{{site_name}}`
- `{{nav_links}}`
- `{{custom_css}}`
- `{{tag_name}}`
- `{{tag_count}}`
- `{{backlinks}}`

It also supports data slots of the form:

- `{{data.nav.title}}`
- `{{data.nav.subtitle}}`
- `{{data.site.footer}}`

Data slots read from TOML-style files under `data_dir`.

## Page template example

The example page template is:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>{{title}} | {{site_name}}</title>
  <meta name="description" content="{{description}}" />
  <link rel="icon" href="/static/favicon.ico" />
  <link rel="stylesheet" href="/static/style.css" />
</head>
<body>
  <header>
    <h1>{{data.nav.title}}</h1>
    <p>{{data.nav.subtitle}}</p>
    <nav>{{nav_links}}</nav>
  </header>
  <main>
    <article>
      <h2>{{title}}</h2>
      <p class="meta">Published: {{date}} | URL: {{url}}</p>
      {{content}}
    </article>
  </main>
  <footer>
    <p>{{data.site.footer}}</p>
  </footer>
</body>
</html>
```

This shows the common split:

- page metadata comes from frontmatter and site config
- body HTML comes from `{{content}}`
- navigation comes from `{{nav_links}}`
- shared site copy comes from `{{data.*}}`

## Index template example

The example collection index template is:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>{{title}} | {{site_name}}</title>
  <meta name="description" content="{{description}}" />
  <link rel="icon" href="/static/favicon.ico" />
  <link rel="stylesheet" href="/static/style.css" />
</head>
<body>
  <header>
    <h1>{{data.nav.title}}</h1>
    <p>{{data.nav.subtitle}}</p>
    <nav>{{nav_links}}</nav>
  </header>
  <main>
    <section>
      <h2>{{title}}</h2>
      {{content}}
    </section>
  </main>
  <footer>
    <p>{{data.site.owner}} · {{data.site.footer}}</p>
  </footer>
</body>
</html>
```

For collection and tag indexes, lattice fills `{{content}}` with generated listing HTML and pagination links.

## What each slot is for

- `title`: page or index title
- `content`: rendered Markdown body or generated listing markup
- `date`: frontmatter date string for a page
- `description`: frontmatter description when present, otherwise site description or generated fallback
- `url`: canonical page URL like `/posts/welcome-lattice/`
- `site_name`: `title` from the site config
- `nav_links`: HTML navigation built from the available collections plus `/tags/`
- `custom_css`: built-in stylesheet text
- `tag_name`: current tag name when rendering a tag page
- `tag_count`: number of pages for a tag when rendering tag views
- `backlinks`: generated HTML for pages that link to the current page

## Data slots

Any slot starting with `data.` is resolved against loaded data files:

```html
<h1>{{data.nav.title}}</h1>
<p>{{data.nav.subtitle}}</p>
<footer>{{data.site.footer}}</footer>
```

These require:

- a matching file in `data_dir`, such as `nav.toml`
- a matching key path in that file

If `{{data.nav.title}}` is present but `nav.toml` or `title` is missing, lattice raises a template error during the build.

## Missing and unknown slots

The parser rejects:

- unknown built-in slots like `{{nav}}`
- malformed data paths like `{{data.nav}}`
- missing template placeholders at render time

This matters because template bugs are otherwise easy to miss. In lattice, they are promoted to explicit failures so you fix the contract instead of debugging the generated HTML later.

## Template overrides

Collections can optionally override the site-wide page template with a `template` key in `collections.cfg`.

Example:

```cfg
[posts]
schema = title:String, date:Date, tags:Optional[Array[String]]
dir = example/content/posts

[projects]
schema = title:String, status:String, description:Optional[String]
dir = example/content/projects
template = example/templates/project-page.html
```

In this setup:

- pages in `posts` use the site-level `page.html`
- pages in `projects` use `example/templates/project-page.html`

The `template` value is used as-is by the builder. It is not resolved relative to `templates_dir`; point it at the exact file you want to load.

If `template` is not set for a collection, lattice falls back to the site-level `page.html` under `templates_dir` (or `content_dir/templates/page.html` when `templates_dir` is not configured).

The rest of the override story is still site-wide:

- `tag.html` overrides tag-page rendering if present
- `tags.html` overrides tags-index rendering if present
- collection index pages still use the shared site-level `index.html`
