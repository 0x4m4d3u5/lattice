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
