# Collections

Collections are lattice's typed content groups. Each collection says two things:

1. where to find a set of Markdown files
2. which frontmatter fields every file in that set must satisfy

That is the main structural guarantee in the build: a page is not just "some Markdown in a folder." It belongs to a named collection with a declared schema.

## Config shape

Collections live in a separate config file. In this repo, the example is `example/collections.cfg`:

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

The current parser supports two section kinds:

- `[collection_name]` for content collections
- `[data.file_name]` for required keys in template data files

## Per-collection fields

Each collection currently supports exactly two keys:

- `schema`: a comma-separated list of `name:Type` declarations
- `dir`: the directory containing that collection's Markdown files

Example:

```cfg
[projects]
schema = title:String, status:String, description:Optional[String]
dir = example/content/projects
```

The implementation does not currently support per-collection `template`, `index_template`, or `output_dir` keys. Templates are loaded site-wide from `templates_dir`, and output paths are derived from the collection name.

## Multiple collections

The example site has both `posts` and `projects`:

- `posts` reads from `example/content/posts`
- `projects` reads from `example/content/projects`

They coexist cleanly because each collection has:

- its own schema
- its own source directory
- its own output root under `dist/<collection>/`

That gives you separate URLs like:

- `/posts/welcome-lattice/`
- `/projects/docs-portal/`

and separate collection index pages like:

- `/posts/`
- `/projects/`

## Schema differences across collections

The two example collections deliberately model different content:

```cfg
[posts]
schema = title:String, date:String, tags:Optional[Array[String]], draft:Optional[Bool]
dir = example/content/posts

[projects]
schema = title:String, status:String, description:Optional[String]
dir = example/content/projects
```

That means:

- posts must have `title` and `date`
- posts may have `tags` and `draft`
- projects must have `title` and `status`
- projects may have `description`

This is why lattice can treat content integrity as a build-time property. A project page cannot accidentally look like a blog post, because the collection schema rejects that mismatch before rendering.

## Data schemas in the same file

The `[data.*]` sections are related but separate from content collections:

```cfg
[data.nav]
required = title,subtitle,cta

[data.site]
required = owner,footer
```

These sections validate TOML-style files loaded from `data_dir`. They matter because templates can reference values like `{{data.nav.title}}` and `{{data.site.footer}}`. If a required data key is missing, the build fails instead of rendering a broken template.

## Output layout

Collection output is generated from the collection name, not from a custom `output_dir` setting.

For the example site:

- `posts` pages render under `dist/posts/<slug>/index.html`
- `projects` pages render under `dist/projects/<slug>/index.html`
- each collection also gets `dist/<collection>/index.html`
- each collection gets `dist/<collection>/feed.xml`

If `page_size` forces pagination, lattice adds:

- `dist/<collection>/page/2/index.html`
- `dist/<collection>/page/3/index.html`

## Defaults and fallbacks

If you do not pass a collections file, lattice falls back to a default `posts` collection rooted at the content directory. That is useful for experiments, but real sites should define collections explicitly so the schema is obvious and versioned.

## Example workflow

To build the checked-in example collections:

```bash
moon run cmd/main -- ./example/content ./dist --config ./example/site.cfg --collections ./example/collections.cfg
```

To add another collection, create a new section with a unique name and directory. As long as the source files satisfy the schema, it becomes another first-class content type in the build, navigation, feeds, and search index.
