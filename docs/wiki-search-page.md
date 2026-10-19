# Publish a wiki search page

The reusable search page in `examples/wiki_search` runs the MoonBit retrieval
core in a dedicated WASM GC worker. It searches the full `content-index.json`,
with section snippets, canonical page citations and exact AND tag filters.
There is no remote search service or dependency on a UI framework.

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
The browser must support WASM GC and JavaScript string builtins, as described in
[the portable runtime documentation](wasm-note.md).

The package contains the page, app module, worker, paired host adapter and WASM
binary. Generated binaries are not checked into the repository. The packager
refuses an existing destination; use a fresh staging directory when updating,
then replace the complete package together using your normal publishing process.
It does not replace files in an existing site or deploy anything.

The page defaults to `../../content-index.json`, relative to its own URL. This
loads the index at `/static/search/` and when both are hosted under a path
prefix. Citations remain exactly as stored in the index. If the index name or page location differs, edit the form's `data-index`
attribute in the packaged `index.html`. You can also edit the title and page
styles there. Keep the worker, adapter and binary together at their packaged
relative paths. Load only an index you intend to make available to visitors;
this page inherits the index's publication and draft rules.

Submit a query with Enter or Search. Check tags to require every selected tag.
ASCII case variants share one checkbox, using the first indexed display spelling;
non-ASCII case variants remain distinct, matching the retrieval core.
Only the latest submitted query can update the results; submitting an empty
query clears them. Search returns up to ten sections. Snippets and titles are
inserted as text. HTTP and HTTPS citations use the exact returned URL, without
adding heading fragments; other or malformed URLs remain non-navigable text.
Explicit `sections: []` entries stay excluded. An unavailable or malformed index,
unsupported runtime or worker failure shows a retry control. Retry reloads the
index and starts a fresh worker; queries reuse that worker until failure or
navigation. An operation taking over 30 seconds also offers retry.

See [section search](section-search.md) for lexical matching, ranking and older
content-index compatibility. The excerpt-only `search-index.json` is not a
substitute for the content index.

## Reader workspace

The search rail keeps the query, tag filters and matching passages together. Use
**Read note** to open a same-origin published page alongside the results; the
selected result stays highlighted. On mobile the note takes the available screen,
with **Back to results** restoring the previous search and keyboard focus. Escape
also returns to results while focus is in the reader toolbar. Keyboard events
inside the embedded page stay there. A new search closes the current note.

The reader loads existing HTML in a sandboxed iframe. It does not render Markdown
again, invent heading links from index metadata, or execute embedded scripts and
forms. **Open full page** is available for interactive content or sites that block
embedding. External citations remain normal links. Existing page themes continue
to control their typography and layout.

For an integrated wiki style, copy `examples/wiki_search/page.html` into your
site's templates directory as the page template. The packager includes its
`page.css` stylesheet. Adjust `/static/search/page.css` in the template to your
chosen static directory and site prefix. This is opt-in: it does not replace
existing templates. It uses the existing title, description, body, TOC and
backlink variables; contents and backlinks appear only when Lattice supplies them.
Enable `toc: true` in a note's frontmatter to publish its contents navigation.

The browser fixture builds realistic synthetic runbook notes with this template,
then checks desktop/mobile layout, keyboard navigation, published contents and
backlinks. CI retains screenshots for review. No external fonts or UI frameworks
are needed.
