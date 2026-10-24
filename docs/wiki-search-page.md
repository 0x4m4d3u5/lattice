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
query clears them. Search returns up to ten sections. Snippets and titles are
inserted as text. HTTP and HTTPS citations use the exact returned URL, without
adding heading fragments; other or malformed URLs remain non-navigable text.
Explicit `sections: []` entries stay excluded. An unavailable or malformed index,
unsupported runtime or worker failure shows a retry control. Retry reloads the
index and starts a fresh worker; queries reuse that worker until failure or
navigation. An operation taking over 30 seconds also offers retry.
Retry stays focusable while loading and ignores duplicate activation. On success,
focus returns to the search field only if it is still on Retry; moving elsewhere
or closing mobile navigation keeps the reader's chosen focus.

See [section search](section-search.md) for lexical matching, ranking and older
content-index compatibility. The excerpt-only `search-index.json` is not a
substitute for the content index.

## Landing page and collection navigation

The landing page lists readable published notes by the index's `collection`
metadata, with their titles and descriptions. Standalone pages use a Pages group.
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

All page links use normal navigation to the published HTML. There is no embedded
preview or second Markdown renderer. Wiki links, fragment links, contents and
backlinks use the generator's existing URLs; native browser history and new-tab
navigation work normally. Notes using the shared template retain the sidebar,
current-page indication and collection label as you follow links.
The current-page marker remains visible in forced-colors mode, separately from
the keyboard focus outline.
Existing site themes remain unchanged unless you opt into the template. Other
templates still open normally, but need the shared navigation include, styles
and app module to participate in this layout.

Queries, selected tags and collection disclosure state are retained for the tab
using optional session storage, scoped to the index URL. Storage failure does not
prevent reading or searching. On mobile, **Browse & search** opens the directory;
Escape closes it and restores focus to the button. **Skip to content** closes the
mobile directory and moves focus to the page. Crossing between mobile and desktop
resets the mobile menu and moves focus only when its navigation control becomes
hidden. Normal links and published content
remain usable without JavaScript, while the directory/search need JavaScript.
Printing shows the main content without the navigation panel, including when
the mobile menu is open. Returning from print preserves the screen's menu state.

Contents and backlinks appear only when supplied by Lattice. Enable `toc: true`
in a note's frontmatter for contents navigation. The browser fixture in
`tests/browser/fixtures/wiki` builds a fictional six-note library with three
collections and checks desktop/mobile browsing, keyboard controls, wiki/fragment
links, history, runtime failures and no-JavaScript reading. CI retains its landing,
reading and mobile-navigation screenshots. No external fonts or UI framework are
needed.
