# Publish a browsable wiki reader

The reusable reader in `examples/wiki_search` runs the MoonBit retrieval
core in a dedicated WASM GC worker. It searches the full `content-index.json`,
with section snippets, canonical page citations and exact AND tag filters.
There is no remote search service or dependency on a UI framework.

## Start a new wiki

The repository's wiki starter assembles the existing reader, shared templates,
a typed Guides collection, a welcome page and two linked sample notes. It enables
the content index and uses relative project paths, so the generated project can
be moved without rewriting its configuration.

From the repository root, with the [pinned toolchain](reliability-baseline.md#reproduce)
on your PATH:

```sh
export LATTICE_REPO="$PWD"
bash scripts/check-wasm-note.sh
moon build cmd/main --target js --deny-warn
node scripts/create-wiki.mjs ../my-wiki
cd ../my-wiki
export LATTICE_CLI="$LATTICE_REPO/_build/js/debug/build/kurisu/lattice/cmd/main/main.js"
node "$LATTICE_CLI" check --format json
node "$LATTICE_CLI" build
python3 -m http.server 8000 --directory dist
```

Visit `http://localhost:8000/` for the welcome note, or
`http://localhost:8000/static/search/` for the library and search. Stop the local
server with Ctrl+C. Generation does not start a server or deploy anything.

For automatic rebuild and browser reload while editing, replace the Python
server command with `node "$LATTICE_CLI" serve` and visit
`http://127.0.0.1:4321/` (or `/static/search/`). The Node preview is loopback-only
and keeps the previous output after validation failures; see
[the editing workflow](getting-started.md#rebuild-while-editing).

The destination must not exist, even as an empty directory; its parent must
already exist. All reader inputs, including the built WASM runtime, are read
before the destination is created. The command does not download or compile
dependencies. A filesystem write failure can leave a partial new directory;
there is no automatic cleanup or replacement of existing files.

Edit `content/guides/`, `collections.cfg`, and `content/lattice.conf` to grow the
wiki. Each sample guide requires a title and description, and the linked examples
demonstrate strict wikilink checking. Set `base_url` to the intended site address
before publishing. The generated README includes check/build and local-preview
instructions. To add the reader to an existing site, use the asset-only workflow
below; `lattice init` retains its existing general-site scaffold.

## Add your first note

From the wiki directory, create a file using the collection's schema. Use another
terminal if the local HTTP server is still running:

```sh
lattice new Guides --name field-journal
```

With the repository's JavaScript CLI, use
`node "$LATTICE_CLI" new Guides --name field-journal` instead.
`Guides` is the collection name in `collections.cfg`; `field-journal` is the
filename without `.md`. The command refuses to overwrite an existing note.

Open `content/guides/field-journal.md` and replace the generated placeholders
with your title, description and writing. For example:

```md
---
title: Field journal
description: Observations from a walk in the garden.
tags: [Journal]
toc: true
---
## First observation

A copperleaf plant caught the afternoon light.

Return to [[getting-started|Getting started]].
```

The template displays the frontmatter title, so start body sections at `##`.
`toc: true` adds contents navigation; tags make the note filterable in search.
Add `[[field-journal|Field journal]]` to `content/guides/getting-started.md`
to connect the new note to the tour. Wikilinks use the filename, not the title.

Check before building, stopping if validation fails:

```sh
lattice check && lattice build
```

Or use `node "$LATTICE_CLI" check && node "$LATTICE_CLI" build`.
The build updates the directory and search index automatically. With the local
server running, reload the overview, open **Field journal** under **Guides**,
or search for **copperleaf**. Follow the note's link back to **Getting started**.
Repeat check and build after editing; the plain HTTP server does not rebuild.

## Retrieve evidence from your wiki

The reader search above runs locally in a compatible browser. To exercise the
same retrieval from an agent host, follow the browser-harness prerequisites in
[the evidence example](agent-evidence.md#run-it-against-a-publication), then,
from the repository root while your wiki's HTTP server is running:

```sh
node examples/agent_evidence/run.mjs \
  ../my-wiki/dist/content-index.json http://127.0.0.1:8000 "copperleaf"
```

After adding the Field journal example, this returns its full indexed passage
and a validated citation ending in `#first-observation`. It is retrieval, not
proof that the observation is true. No matches or multiple matching passages
produce an abstention rather than an invented or arbitrarily chosen citation.

Change `copperleaf` to `silverfern` in the note, run check and build again from
the wiki directory, then repeat the query with `silverfern`. The new index and
HTML should agree; the old query should no longer find that passage. Keep the
index and output from the same build. The HTTP server alone does not rebuild.

## Publish a clickable image

Put a thumbnail and its larger image under `content/static/`, then use an inline
image as the complete link label in your note:

```md
[![Garden map showing the walking paths](/static/map.png)](/static/map-large.png)
```

This thumbnail form supports one inline image as the whole label. Mixed
text/image labels and reference-style images are outside this support.

Check and build as usual. Readers can activate the image with a pointer or
keyboard, including without JavaScript. The image alt text names the link; use a
useful description. With `require_image_alt = true`, blank alt text in linked
images fails the same [editorial check](editorial-checks.md) as ordinary images.
The source and destination files still need to exist; this syntax does not copy
images from arbitrary source locations or check remote image availability.

## Add the reader to an existing site

Enable `content_index_file = content-index.json` in your site's configuration.
Using the repository's pinned toolchain, build the portable application and
package the page into a **new** directory under your content's static directory:

```sh
bash scripts/check-wasm-note.sh
mkdir -p path/to/content/static
node scripts/package-search.mjs path/to/content/static/search
```

Run the site's normal Lattice build. Its existing static publisher copies the
package into `dist/static/search/`; link to `/static/search/` from your navigation.
Serve the output over HTTP or HTTPS rather than opening the HTML with `file:`.
Search requires WASM GC and JavaScript string builtins, as described in
[the portable runtime documentation](wasm-note.md).

The package contains the landing page, shared styles, app and catalogue modules,
worker, paired host adapter and WASM binary. Generated binaries are not checked
into the repository. The packager
refuses an existing destination; use a fresh staging directory when updating,
then replace the complete package together using your normal publishing process.
It does not replace files in an existing site or deploy anything.

The page defaults to `../../content-index.json`, relative to its own URL. This
loads the index at `/static/search/` and when both are hosted under a path
prefix. Citations remain exactly as stored in the index. If the index name or page location differs, edit the form's `data-index`
attribute in the packaged `index.html`. You can also edit the page title there
and the styles in `shell.css`. Keep the worker, adapter and binary together at
their packaged relative paths. Load only an index you intend to make available to visitors;
this page inherits the index's publication and draft rules.

Submit a query with Enter or Search. Check tags to require every selected tag.
The filter summary shows the selected count even when collapsed or restored
after navigation. **Clear tag filters** removes all selected tags and immediately
reruns the current query, returning keyboard focus to the search field.
Tags belonging only to entries with explicitly empty sections are omitted from
the picker, since those entries cannot produce search results. Legacy indexes
without sections keep their tag filters.
ASCII case variants share one checkbox, using the first indexed display spelling;
non-ASCII case variants remain distinct, matching the retrieval core.
Selected filters survive ASCII capitalization changes in a reloaded index,
including when retrying search.
Only the latest submitted query can update the results; submitting an empty
query clears them. Search initially shows ten sections; **Show more results**
reveals the next ten in the same ranked order and moves keyboard focus to the
first newly shown result. At most fifty sections are available per query, matching
the retrieval core limit. When fifty are returned, the status asks you to refine
the query or tags; it does not claim that fifty is the total number of matches.
Submitting another query, clearing it, or retrying search resets the visible batch.
Snippets and titles are
inserted as text. HTTP and HTTPS title links use the returned page URL plus an
encoded publisher-verified fragment when available, opening the matching passage
at its published HTML target. Older indexes and uncertain targets keep the
page-only link; heading labels are never converted into guessed slugs. A same-page
passage link closes mobile navigation before the browser scrolls to the target. Other or
malformed URLs remain non-navigable text.

Published article headings also gain a small **#** section link when JavaScript
is available, including in notes without a table of contents. Activate it with
the keyboard or pointer, or use the browser's copy-link/open-in-new-tab action
to share that passage. These links use the actual published IDs on headings
H2–H6; they do not guess IDs from heading text. A small trailing gutter keeps
the link beside the first line of wrapped headings rather than on an isolated
line. No-JavaScript and printed headings retain their full reading width. Ambiguous duplicate IDs, encoded
fragments shadowed by another ID or named anchor, empty targets and existing
heading self-links are left alone. The links work even if
search fails, are hidden in print, and do not change no-JavaScript reading or
existing table-of-contents links. Renaming or removing a heading can still change
its URL; these links do not create redirects or persistent anchor aliases.

Published code blocks gain a **Copy code** button when the browser exposes its
clipboard write API (normally on HTTPS or local preview). Activating it copies
the displayed code text, including indentation and line breaks, without executing
it. Inline feedback reports success or asks you to select and copy manually if
the browser refuses access. The controls work independently of search, stay out
of printed pages, and do not alter the code itself. Without JavaScript or clipboard
support, ordinary text selection remains available.

Explicit `sections: []` entries stay excluded. An unavailable or malformed index,
unsupported runtime or worker failure shows a retry control. Loading/searching
messages appear only after half a second, so fast responses skip transient text.
The status region reserves space; disabled controls and busy state update immediately,
and errors are announced without that delay. Retry reloads the
index and starts a fresh worker; queries reuse that worker until failure or
full-page navigation. Shared-reader note navigation keeps the same worker. An operation taking over 30 seconds also offers retry.
Retry stays focusable while loading and ignores duplicate activation. On success,
focus returns to the search field only if it is still on Retry; moving elsewhere
or closing mobile navigation keeps the reader's chosen focus.

See [section search](section-search.md) for lexical matching, ranking and older
content-index compatibility. The excerpt-only `search-index.json` is not a
substitute for the content index.

## Landing page and collection navigation

The landing page lists readable published notes by the index's `collection`
metadata, with their titles and descriptions. Root and standalone pages share a
Pages group; internal publisher group names are not shown to readers.
The sidebar offers the same directory without requiring a search. It excludes
external/invalid URLs, duplicate canonical URLs and explicit `sections: []`
entries, including generated indexes and overwritten source pages. Legacy
entries with nonempty `body` text remain browsable. The directory does not infer
collection routes or heading targets.

The directory loads before the search runtime. If the runtime is unavailable,
browsing still works once the index has loaded. An unavailable index shows a
retry message; an empty directory explains that no readable pages are listed.
Titles and descriptions are inserted as text, never as index-supplied HTML.

## Shared reading layout

The shared styles keep Lattice's warm palette and serif article text, using a
small set of semantic CSS variables in `shell.css` for reading text, navigation,
metadata, surfaces, selection and focus. `page.css` uses those same roles. The
default type hierarchy uses 18px article text, 14px navigation and at least 12px
metadata, with relative units that follow the browser's default text size.
This selectively applies Fluent 2's guidance on
[semantic tokens](https://fluent2.microsoft.design/design-tokens),
[manuscript layouts and spacing](https://fluent2.microsoft.design/layout), and
[typographic hierarchy](https://fluent2.microsoft.design/typography), without a
framework dependency or a replacement for Lattice's reading layout.

To use the same navigation on published notes, copy both
`examples/wiki_search/page.html` and `examples/wiki_search/wiki-navigation.html`
into your site's templates directory. The page template uses Lattice's existing
include mechanism. The packager uses that same navigation fragment to assemble
the static landing page; it does not add a runtime template engine.

The supplied templates default to `/static/search/` for assets and the overview,
and `/content-index.json` for the index. Adjust these paths in **both** template
files for your deployment prefix or chosen directory. The packaged landing page
uses relative asset/index URLs. Keep its `data-index` equivalent to the published
template's index URL so tab-local search state stays shared.

All page links point to published HTML. With the current shared templates, ordinary
same-site clicks load that HTML into the reading pane while keeping search, tag
filters and the sidebar in place. The previous article stays readable while the
next one loads; a later click supersedes a pending request. There is no embedded
preview or second Markdown renderer. Wiki links, fragment links, contents and
backlinks use the generator's existing URLs; native browser history and new-tab
navigation work normally. Notes using the shared template retain the sidebar,
current-page indication and collection label as you follow links. Completed visits
focus the main content and update the title and page metadata; Back/Forward restore
the article and reading position. Failed requests, unknown pages and mismatched
shells fall back to full-page navigation. Modified clicks and same-page fragments
retain native browser behavior. Custom templates opt in with
`data-lattice-reader="1"` on their main content and matching search-index,
stylesheet and executable-script URLs; pages requiring custom script execution
should keep ordinary full-page navigation instead.
At the end of a collection note, previous/next links let readers continue through
the collection without returning to the sidebar. They use the publisher's existing
collection order and URLs, include the neighboring note titles, and work without
JavaScript. Missing neighbors are omitted; pages without either neighbor have no
visible reading-order footer.
The current-page marker remains visible in forced-colors mode, separately from
the keyboard focus outline.
Existing site themes remain unchanged unless you opt into the template. Other
templates still open normally, but need the shared navigation include, styles
and app module to participate in this layout.

Queries, selected tags, tag-filter disclosure and collection disclosure state are retained for the tab
using optional session storage, scoped to the index URL. Storage failure does not
prevent reading or searching. On mobile, **Browse & search** opens the directory.
The mobile masthead wraps the brand and button onto separate rows when enlarged
text needs more space; mobile fragment links reserve extra clearance below it. Escape closes the directory and restores focus to the
button. **Skip to content** closes the mobile directory and moves focus to the page. Crossing between mobile and desktop
resets the mobile menu and moves focus only when its navigation control becomes
hidden. Normal links and published content
remain usable without JavaScript, while the directory/search need JavaScript.
Printing shows the main content without the navigation panel, including when
the mobile menu is open. Returning from print preserves the screen's menu state.

On narrow screens, reading gutters and nested indentation are bounded by the
viewport so enlarged text keeps useful line width. Long URLs and identifiers
still wrap when necessary; code blocks retain whitespace and horizontal scrolling.

Contents and backlinks appear only when supplied by Lattice. Enable `toc: true`
in a note's frontmatter for contents navigation. The browser fixture in
`tests/browser/fixtures/wiki` builds a fictional six-note library with three
collections and checks desktop/mobile browsing, keyboard controls, wiki/fragment
links, history, runtime failures and no-JavaScript reading. CI retains its landing,
reading and mobile-navigation screenshots. No external fonts or UI framework are
needed.

### Authored reader metadata

The article header shows available publication/revision dates, tag links and a
shortcut to the existing backlinks section. Everything is published HTML: it is
available without JavaScript and stays the same during reader navigation. Empty
metadata and unavailable backlink shortcuts are omitted.

`date` remains the publication date. Optional `updated: YYYY-MM-DD` declares the
last meaningful revision chosen by the author; it is not a build timestamp or a
claim that the note was automatically reviewed. Collection schemas should declare
`date:Optional[Date],updated:Optional[Date]`; newly initialized wikis include these
fields. Standalone/root notes accept the optional update date too.

An update without a publication date is allowed and displays only Updated. Equal
calendar days display Published once. An update before the publication day, an
impossible date, or a non-date value fails `check` and `build`; publication with an
update also requires a valid `date` if that field is supplied. `updated` accepts
calendar dates, not timestamps. Existing publication timestamps keep their values;
the header displays their calendar day. Missing dates stay absent from the header.

The authored update is exported as optional `updated` in the content index,
`dateModified` on BlogPosting JSON-LD, feed modification time, and sitemap
`lastmod`. Publication dates and feed ordering remain unchanged. Without an
explicit update, existing feed/sitemap publication-date fallbacks remain; these
are not editing-history evidence. Builds never derive dates from the clock, file
mtime or Git. Rebuilding an unchanged note does not advance its dates.
