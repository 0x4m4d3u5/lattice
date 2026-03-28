# Schema Syntax

Schemas define which frontmatter fields a collection accepts and what types those fields must have. lattice validates that contract before rendering, so schema mistakes fail the build instead of appearing later as broken templates, missing metadata, or malformed search entries.

## Where schemas are declared

Schemas are defined inline in `collections.cfg`:

```cfg
[posts]
schema = title:String, date:Date, tags:Optional[Array[String]], draft:Optional[Bool]
dir = example/content/posts
```

Each `name:Type` pair becomes one field in the collection schema.

## Supported field types

The current implementation supports:

- `String`
- `Date`
- `Int`
- `Bool`
- `Array[Type]`
- `Optional[Type]`
- `Enum["v1","v2","v3"]`
- `Url`
- `Slug`

Examples:

```cfg
schema = title:String, count:Int, published:Bool
schema = title:String, published_at:Date
schema = tags:Array[String]
schema = draft:Optional[Bool], published_at:Optional[Date], description:Optional[String]
schema = status:Enum["draft","published","archived"]
schema = canonical_url:Url, og_url:Optional[Url]
schema = category:Slug, subsection:Optional[Slug]
```

## Required vs optional

A field is required unless it is wrapped in `Optional[...]`.

Required:

```cfg
schema = title:String, status:String
```

Optional:

```cfg
schema = title:String, description:Optional[String]
```

That means:

- `title` must exist
- `description` may be absent

This is why schema validation is useful: your templates and downstream build stages can assume required fields are present because the build would have already failed otherwise.

## Enum fields

The `Enum["v1","v2","v3"]` type constrains a string field to a specific set of allowed values. Values in the schema are quoted strings, comma-separated.

Example declaration:

```cfg
schema = status:Enum["draft","published","archived"]
```

Valid frontmatter:

```md
---
title = My Post
status = published
---
```

Invalid frontmatter (build error):

```md
---
title = My Post
status = pubished  # typo: missing 'l'
---
```

Why it fails:

- `status` is declared as `Enum["draft","published","archived"]`
- `"pubished"` is not in the allowed values list
- the build emits a diagnostic with the field name, rejected value, and full list of allowed values

This catches typos and domain violations at build time, not at template render time or in the final site output.

## URL fields

The `Url` type constrains a string field to URL-shaped values. A valid URL must start with `http://`, `https://`, or `/` (relative path). Empty strings are rejected.

Example declaration:

```cfg
schema = canonical_url:Url, og_url:Optional[Url]
```

Valid frontmatter:

```md
---
title = My Post
canonical_url = https://example.com/posts/my-post
---
```

Also valid (relative URL):

```md
---
title = My Post
canonical_url = /posts/my-post
---
```

Invalid frontmatter (build error):

```md
---
title = My Post
canonical_url = not-a-url
---
```

Why it fails:

- `canonical_url` is declared as `Url`
- `"not-a-url"` does not start with `http://`, `https://`, or `/`
- the build emits a diagnostic with the field name and expected type

This catches malformed canonical URLs, Open Graph URLs, and other URL-shaped metadata at build time instead of emitting `<link rel="canonical" href="not-a-url">` into the HTML output.

## Slug fields

The `Slug` type constrains a string field to URL-slug-shaped values. A valid slug is non-empty and contains only ASCII lowercase letters (`a-z`), digits (`0-9`), and hyphens (`-`). Spaces, uppercase letters, underscores, and special characters are all rejected.

Example declaration:

```cfg
schema = category:Slug, subsection:Optional[Slug]
```

Valid frontmatter:

```md
---
title = My Post
category = getting-started
---
```

Also valid:

```md
---
title = My Post
category = tutorial-2026
---
```

Invalid frontmatter (build error):

```md
---
title = My Post
category = Getting Started
---
```

Why it fails:

- `category` is declared as `Slug`
- `"Getting Started"` contains uppercase letters and a space
- the build emits a diagnostic: `expected a URL slug (lowercase alphanumeric and hyphens), got: "Getting Started"`

This catches malformed category slugs, tag identifiers, and other URL-segment fields at build time instead of producing broken URLs or inconsistent navigation.

## Frontmatter syntax

Content files start with a `---` block. In the example site:

```md
---
title = Welcome to the Example Site
date = 2024-01-15
tags = [intro, lattice, demo]
---
# Welcome
```

The current frontmatter parser supports:

- strings: `title = "Hello"` or `title = Hello`
- integers: `count = 3`
- booleans: `draft = true`
- arrays: `tags = [intro, lattice, demo]`

It also accepts YAML-style `key: value` lines, but the repo examples use `key = value`, and that is the clearest form to document.

## Valid examples

A valid `posts` frontmatter block for the example schema:

```md
---
title = Typed Frontmatter
date = 2024-02-02
tags = [schemas, moonbit]
draft = false
---
```

A valid `projects` frontmatter block for the example projects schema:

```md
---
title = Docs Portal
status = active
description = Documentation site showcasing templates, tags, and navigation.
---
```

## Invalid examples

Missing a required field:

```md
---
title = Missing Date
tags = [intro]
---
```

Why it fails:

- the `posts` schema requires `date:Date`

Wrong type:

```md
---
title = Wrong Tags
date = 2024-03-01
tags = intro
---
```

Why it fails:

- `tags` is declared as `Optional[Array[String]]`
- a single bare string does not satisfy `Array[String]`

Wrong scalar type:

```md
---
title = Wrong Draft
date = 2024-03-01
draft = "false"
---
```

Why it fails:

- `draft` must be `Bool` when present
- `"false"` is a string, not a boolean

## What validation failures look like

Schema validation happens during the build pipeline, after frontmatter parsing and before template rendering. The builder attaches source locations where it can, especially for frontmatter fields.

In practice, that means you get build-time diagnostics tied to the content file instead of a broken HTML page later. Typical failures include:

- required field missing
- expected `Date` but got incompatible value
- expected `String` but got incompatible value
- expected `Array[String]` but got incompatible value

Frontmatter parse failures also include line information, and the builder threads that into diagnostics. That keeps schema mistakes close to the authoring surface: the content file and the field that violated the contract.

## Design reason

The benefit of schema syntax is not just nicer metadata. It turns content modeling into a checked interface.

Without schemas, a typo in frontmatter can quietly flow into:

- empty template output
- missing dates in indexes and feeds
- malformed search metadata

With schemas, lattice stops at the first structurally invalid page. That is the project thesis in practice: content integrity should be enforced by the build, not left to runtime behavior.
