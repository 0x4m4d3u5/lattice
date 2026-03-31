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
- `Date` or `Date(after=2020-01-01)` or `Date(before=2030-01-01)` or `Date(after=2020-01-01,before=2030-01-01)`
- `Int` or `Int(min=1)` or `Int(max=100)` or `Int(min=1,max=100)`
- `Float` or `Float(min=0.0)` or `Float(max=5.0)` or `Float(min=0.0,max=5.0)`
- `Bool`
- `Array[Type]`
- `Optional[Type]`
- `Enum["v1","v2","v3"]`
- `Url`
- `Slug`
- `Ref` or `Ref[collection-name]`

Examples:

```cfg
schema = title:String, count:Int, published:Bool
schema = title:String, published_at:Date
schema = tags:Array[String]
schema = draft:Optional[Bool], published_at:Optional[Date], description:Optional[String]
schema = status:Enum["draft","published","archived"]
schema = canonical_url:Url, og_url:Optional[Url]
schema = category:Slug, subsection:Optional[Slug]
schema = related_post:Ref[posts], featured:Optional[Ref]
schema = related_posts:Array[Ref[posts]]
schema = title:String, rating:Float(min=0.0,max=5.0), weight:Optional[Float]
schema = title:String, published_at:Date(after=2020-01-01,before=2030-01-01)
schema = title:String(minlen=5), excerpt:String(maxlen=160)
schema = title:String(minlen=5), excerpt:String(maxlen=160), slug:String(minlen=3,maxlen=60)
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

## Cross-reference fields

Cross-reference fields declare that a frontmatter value must reference an existing page slug. This turns broken internal links from runtime 404s into build-time errors.

The `Ref` type comes in four forms:

- `Ref` — a slug that must exist in any collection
- `Ref[collection-name]` — a slug that must exist in a specific named collection
- `Array[Ref[collection-name]]` — an array of cross-reference slugs, each validated
- `Optional[Ref[collection-name]]` — an optional cross-reference

Example declarations:

```cfg
schema = title:String, related_post:Ref[posts], featured:Ref
schema = title:String, related_posts:Array[Ref[posts]]
schema = title:String, see_also:Optional[Ref[posts]]
```

Valid frontmatter:

```md
---
title = My Post
related_post = getting-started
---
```

Also valid (array of refs):

```md
---
title = My Post
related_posts = [intro, advanced-guide, faq]
---
```

Invalid frontmatter (build error):

```md
---
title = My Post
related_post = non-existent-page
---
```

Why it fails:

- `related_post` is declared as `Ref[posts]`
- `"non-existent-page"` is not a known slug in the `posts` collection
- the build emits a diagnostic: `TRef: references unknown slug 'non-existent-page'`

### Two-pass validation

Cross-reference validation requires a two-pass build:

1. **Pass 1 (structural check):** `validate()` checks that the field value is a valid slug format (non-empty, lowercase alphanumeric and hyphens). This runs before the page index is built.
2. **Pass 2 (existence check):** `validate_refs()` checks that the slug exists in the page index (and belongs to the specified collection, if constrained). This runs after all pages have been collected and their slugs computed.

The two-pass design means forward references work naturally — page A can reference page B even if B's source file comes after A in the file system, because pass 1 has already processed both.

## Int bounds fields

The `Int` type can optionally declare minimum and maximum bounds. Without bounds, any integer is accepted (backwards compatible with plain `Int`). With bounds, values outside the range produce a build error.

The syntax is:

- `Int` — any integer (equivalent to `Int(min=-∞, max=∞)`)
- `Int(min=1)` — 1 and above
- `Int(max=100)` — 100 and below
- `Int(min=1,max=100)` — between 1 and 100 inclusive

Example declarations:

```cfg
schema = title:String, priority:Int(min=1), score:Int(max=100), percent:Int(min=0,max=100)
```

Valid frontmatter:

```md
---
title = My Post
priority = 3
score = 85
percent = 50
---
```

Invalid frontmatter (build error):

```md
---
title = My Post
priority = 0
---
```

Why it fails:

- `priority` is declared as `Int(min=1)`
- `0` is below the minimum bound of `1`
- the build emits a diagnostic: `expected Int in range [1, ∞), got: 0`

This catches out-of-range metadata — priorities, percentages, ratings — at build time instead of producing pages with nonsensical values that templates might render without checking.

## Float bounds fields

The `Float` type accepts any floating-point value. `Float(min=0.0,max=5.0)` constrains to a range. The decimal point is the discriminant between Int and Float in frontmatter: `count: 42` parses as Int, `rating: 4.5` parses as Float.

The syntax is:

- `Float` — any float (equivalent to `Float(min=-∞, max=∞)`)
- `Float(min=0.0)` — 0.0 and above
- `Float(max=5.0)` — 5.0 and below
- `Float(min=0.0,max=5.0)` — between 0.0 and 5.0 inclusive

Example declarations:

```cfg
schema = title:String, rating:Float(min=0.0,max=5.0), weight:Optional[Float]
```

Valid frontmatter:

```md
---
title = My Post
rating = 4.5
---
```

Invalid frontmatter (build error):

```md
---
title = My Post
rating = -1.0
---
```

Why it fails:

- `rating` is declared as `Float(min=0.0,max=5.0)`
- `-1.0` is below the minimum bound of `0.0`
- the build emits a diagnostic: `expected Float in range [0.0, 5.0], got: -1.0`

This catches out-of-range continuous values — ratings, weights, scores — at build time instead of producing pages with nonsensical floating-point metadata.

## Date bounds fields

The `Date` type validates `YYYY-MM-DD` format. `Date(after=2020-01-01)` adds an exclusive lower bound. ISO 8601 strings compare lexicographically (`"2020-01-02" > "2020-01-01"`), so no date parsing is needed for the comparison — the bounds check is a string comparison, which is both correct and fast.

The syntax is:

- `Date` — any valid date (equivalent to `Date(after=..., before=...)` with no bounds)
- `Date(after=2020-01-01)` — after 2020-01-01 (exclusive)
- `Date(before=2030-01-01)` — before 2030-01-01 (exclusive)
- `Date(after=2020-01-01,before=2030-01-01)` — within range (both bounds exclusive)

Example declarations:

```cfg
schema = title:String, published_at:Date(after=2020-01-01,before=2030-01-01)
```

Valid frontmatter:

```md
---
title = My Post
published_at = 2025-06-15
---
```

Invalid frontmatter (build error):

```md
---
title = My Post
published_at = 2019-12-31
---
```

Why it fails:

- `published_at` is declared as `Date(after=2020-01-01,before=2030-01-01)`
- `2019-12-31` is not after `2020-01-01` (the bound is exclusive)
- the build emits a diagnostic: `expected Date after 2020-01-01 and before 2030-01-01, got: 2019-12-31`

This catches temporal violations — archived content dated in the future, legacy content predating a migration cutoff — at build time. The lexicographic comparison trick works because ISO 8601 dates sort correctly as strings: year digits come first, then month, then day.

## String length bounds fields

The `String` type can optionally declare minimum and maximum length bounds. Without bounds, any string is accepted (backwards compatible with plain `String`). With bounds, strings whose length falls outside the range produce a build error.

The syntax is:

- `String` — any string (no length constraint)
- `String(minlen=5)` — 5 characters or more
- `String(maxlen=160)` — 160 characters or fewer
- `String(minlen=5,maxlen=160)` — between 5 and 160 characters inclusive

Example declarations:

```cfg
schema = title:String(minlen=5), excerpt:String(maxlen=160), subtitle:String(minlen=5,maxlen=100)
```

Valid frontmatter:

```md
---
title = My First Post
excerpt = A short introduction to the blog
---
```

Invalid frontmatter (build error):

```md
---
title = Hi
---
```

Why it fails:

- `title` is declared as `String(minlen=5)`
- `"Hi"` has length 2, which is below the minimum of 5
- the build emits a diagnostic: `expected String with minlen=5, got length 2: "Hi"`

This catches common authoring constraints at build time — titles too short to be meaningful, SEO meta descriptions exceeding recommended lengths, excerpts that are too long or too short. String length is a particularly common constraint in content-driven sites, and the `String(minlen,maxlen)` syntax completes the "domain constraints as type parameters" pattern. All four bounded types (`Int`, `Float`, `Date`, `String`) now follow the same parameterization syntax, handled identically by the collections parser.

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
