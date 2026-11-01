# Local authored-link graph

The bundled wiki reader offers **Connections around this note** when a published
note has authored incoming or outgoing wikilinks. Open the disclosure to explore
its neighborhood, or use the ordinary linked list without JavaScript.

The current note and at most 30 neighbors are shown, selected deterministically
by slug. Arrows run from the referring note to the destination. Repeated links
collapse into one edge; self-links do not add neighbors. Related-note suggestions
are not authored citations and do not enter this graph. This is a local navigation
view, not a global knowledge map, relevance score or authority ranking.

Use Zoom in/out, directional pan buttons and Reset view without gestures. Pointer
dragging moves a node or pans the background. Focus a node to select it; Enter
opens its canonical page. The full selected title appears below the diagram.
Crowded views show labels only for the current/selected note, while the linked
list retains every displayed neighbor's full title. Normal browser navigation and
back/forward update the current-note selection.

Layout is finite and deterministic rather than continuously animated. It does
not animate under reduced motion, and the separate graph worker is stopped when
the disclosure or document is hidden. Search keeps its independent worker and
unchanged WASM ABI. If the graph worker cannot load, the linked list remains usable.

## Publication and templates

The builder filters authored graph nodes and edges against final output ownership.
Hidden drafts and authored pages replaced by generated/static output are absent.
`--drafts` deliberately includes drafts; client-side hiding is not a privacy
boundary. Configured static files still follow the existing wholesale-copy policy.

The bundled page template contains `<!--lattice-local-graph-->`. Custom page
templates may opt in with that marker and the bundled graph assets. The builder
replaces it with static HTML after final ownership is known. Pages without a
neighborhood omit the control. Existing templates without the marker are unchanged.
Repackage wiki assets after updating Lattice; build both the usual search runtime
and the independent JS graph module first:

```sh
moon build examples/local_graph --target js --deny-warn
```

The local payload contains only displayed nodes/edges, not full note bodies. The
site-wide `graph.json` remains a separate authored graph export. URLs stay canonical;
root aliases do not create duplicate graph nodes. The view cannot reveal private
notes that were never published, and missing graph edges do not prove two concepts
are unrelated. Ordinary Markdown links are not included in the wikilink graph.

## Implementation boundary

`src/graph/local.mbt` owns adjacency, bounded selection, deterministic initialization
and fixed-budget repulsion/spring layout. `examples/local_graph` compiles the same
code for JS and WASM-GC; the reader currently uses JS in a separate worker with an
SVG host. The host handles browser events, drawing and accessible native controls.
It does not import a force-layout library. Global graph parsing and optimization
are outside this view; a 30-neighbor cap is intentional, not a benchmark claim.

Run `scripts/check-local-graph.mjs` after building both example targets for seeded
shape comparisons, and `tests/browser/local-graph.mjs` with the existing browser
harness for publication, navigation and fallback acceptance.
