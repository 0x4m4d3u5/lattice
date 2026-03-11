# Getting Started

This guide walks through the smallest useful lattice site using the same syntax and file layout as the checked-in `example/` site.

The core idea is simple: define site metadata, declare at least one collection with a schema, add Markdown files that satisfy that schema, then render everything through HTML templates. If a page violates the schema, lattice fails the build before it writes HTML.

## Directory layout

For a minimal site, create a layout like this:

```text
my-site/
├── content/
│   └── posts/
│       └── welcome-lattice.md
├── data/
│   ├── nav.toml
│   └── site.toml
├── templates/
│   ├── index.html
│   └── page.html
├── collections.cfg
└── lattice.toml
```

The repo's `example/` site uses the same shape:

- site config: `example/site.cfg`
- collections config: `example/collections.cfg`
- content: `example/content/`
- templates: `example/templates/`
- data files: `example/data/`

## 1. Write the site config

The current lattice config format is a simple `key = value` file, not full TOML. You can still name the file `lattice.toml` if you want; the filename is arbitrary, the syntax is not.

The example site uses:

```cfg
title = Lattice Example Site
base_url = https://example.lattice.local
description = Demo site exercising collections, wikilinks, templates, pagination, and static assets
author = Lattice Team
page_size = 5
search_index_file = search-index.json
templates_dir = example/templates
static_dir = static
data_dir = example/data
```

For a new site outside this repo, point the directories at your own files:

```cfg
title = My Lattice Site
base_url = https://example.com
description = Small typed-content demo
page_size = 5
collections_file = ./collections.cfg
templates_dir = ./templates
static_dir = static
data_dir = ./data
```

`title` and `base_url` are required. Everything else is optional.

## 2. Define a collection and its schema

Collections are declared in a separate config file. The example repo has two collections:

```cfg
[posts]
schema = title:String, date:String, tags:Optional[Array[String]], draft:Optional[Bool]
dir = example/content/posts

[projects]
schema = title:String, status:String, description:Optional[String]
dir = example/content/projects

[data.nav]
required = title,subtitle,cta

[data.site]
required = owner,footer
```

For the minimal walkthrough, one collection is enough:

```cfg
[posts]
schema = title:String, date:String, tags:Optional[Array[String]]
dir = ./content/posts

[data.nav]
required = title,subtitle,cta

[data.site]
required = owner,footer
```

This schema is the structural contract for every file in `content/posts`. If `date` is missing, or `tags` is not an array of strings, the build stops before rendering.

## 3. Add the data files used by the templates

The example templates read from `data.nav.*` and `data.site.*`, so create matching files:

`data/nav.toml`

```toml
title = "Lattice Example"
subtitle = "Structural integrity demo"
cta = "Read the roadmap"
```

`data/site.toml`

```toml
owner = "Lattice Team"
footer = "Built with typed content contracts"
```

The `[data.nav]` and `[data.site]` sections in `collections.cfg` make these requirements explicit. If `footer` is missing from `site.toml`, lattice reports that as a build error instead of rendering an empty footer.

## 4. Add a Markdown document

This frontmatter matches `example/content/posts/welcome-lattice.md`:

```md
---
title = Welcome to the Example Site
date = "2024-01-15"
tags = [intro, lattice, demo]
---
# Welcome

This demo site exists to exercise the full lattice pipeline in one place.
```

Place it at `content/posts/welcome-lattice.md`.

Frontmatter is fenced with `---` and uses TOML-style `key = value` assignments. In the current implementation, dates are plain strings, so `"2024-01-15"` is validated as `String`.

## 5. Add templates

The example site has one page template and one index template.

`templates/page.html`

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>{{title}} | {{site_name}}</title>
  <meta name="description" content="{{description}}" />
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

`templates/index.html`

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>{{title}} | {{site_name}}</title>
  <meta name="description" content="{{description}}" />
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

## 6. Run the build

From repo root, the example site builds with:

```bash
moon run cmd/main -- ./example/content ./dist --config ./example/site.cfg --collections ./example/collections.cfg
```

For your own site, if `collections_file = ./collections.cfg` is set in `lattice.toml`, you can build with:

```bash
moon run cmd/main -- --config ./lattice.toml
```

That works because the CLI defaults to:

- content directory: `./content`
- output directory: `./dist`
- collections file: `collections_file` from the site config

If you prefer not to set `collections_file` in the config, pass it explicitly:

```bash
moon run cmd/main -- ./content ./dist --config ./lattice.toml --collections ./collections.cfg
```

## What the output looks like

For a `posts` collection with one page, lattice writes clean URLs under `dist/`:

```text
dist/
├── posts/
│   ├── index.html
│   ├── feed.xml
│   └── welcome-lattice/
│       └── index.html
├── tags/
│   ├── index.html
│   └── intro/
│       └── index.html
├── graph.json
├── search-index.json
├── sitemap.xml
└── style.css
```

If `static_dir` exists, lattice also copies those files into `dist/static/`.

The important constraint is that output only happens after the structural checks pass: frontmatter, schema, data slots, template slots, and wikilinks are validated first. That keeps bad content from silently leaking into generated pages.
