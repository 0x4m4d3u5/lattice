import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { prepareWikiAssets } from './wiki-package.mjs';

if (process.argv.length !== 3) throw new Error('Usage: node scripts/create-wiki.mjs NEW_DIRECTORY');
const destination = resolve(process.argv[2]);
const [assets, page, navigation] = await Promise.all([
  prepareWikiAssets(),
  readFile(new URL('../examples/wiki_search/page.html', import.meta.url), 'utf8'),
  readFile(new URL('../examples/wiki_search/wiki-navigation.html', import.meta.url), 'utf8'),
]);
const files = [
  ...assets.map(([name, bytes]) => [`content/static/search/${name}`, bytes]),
  ['templates/page.html', page],
  ['templates/index.html', page.replace('{{body_no_h1}}', '{{content}}')],
  ['templates/wiki-navigation.html', navigation],
  ['content/lattice.conf', `title = My wiki
base_url = https://example.test
description = A small connected library
templates_dir = templates
data_dir = data
collections_file = collections.cfg
content_index_file = content-index.json
output_dir = dist
`],
  ['collections.cfg', `[Guides]
dir = content/guides
schema = title:String,description:String,date:Optional[Date],updated:Optional[Date],tags:Optional[Array[String]]
`],
  ['content/index.md', `---
title: Welcome to your wiki
description: Read, connect, and publish your notes.
toc: true
---
## Start reading

Follow [[getting-started|Getting started]] for a tour of this wiki.

## Find a passage

[Browse the library and search](/static/search/) by words or tags.
The same navigation stays available as you move between notes.
`],
  ['content/guides/getting-started.md', `---
title: Getting started
description: A short tour of your connected library.
tags: [Orientation]
toc: true
---
## A small typed wiki

This starter combines Markdown notes, a typed collection, and local section search.
Edit these sample notes or add another file in content/guides.
Each guide needs a title and description; tags are optional.

## Follow a connection

Use wikilinks to connect your ideas. Read the [[publishing#Check before publishing|publishing checklist]] next.
`],
  ['content/guides/publishing.md', `---
title: Publishing notes
description: Check your content before creating published output.
tags: [Publishing]
toc: true
---
## Check before publishing

A reproducible publishing workflow starts with lattice check.
It reports schema violations and broken wikilinks without writing output.
Fix reported problems before building; build treats broken wikilinks as warnings.

## Build your wiki

Run lattice build to prepare the dist directory, then serve it over HTTP.
Open / for the welcome note or /static/search/ for the library overview.
Set base_url in content/lattice.conf to your site's real address before publishing.

Return to [[getting-started|Getting started]].
`],
  ['.gitignore', 'dist/\n'],
  ['README.md', `# Your Lattice wiki

Run commands from this directory. With an installed lattice CLI:

\`\`\`sh
lattice check
lattice build
\`\`\`

For the repository's pinned JavaScript build, set LATTICE_CLI to the absolute
path to _build/js/debug/build/kurisu/lattice/cmd/main/main.js in your Lattice
checkout, then use:

\`\`\`sh
node "$LATTICE_CLI" check --format json
node "$LATTICE_CLI" build
python3 -m http.server 8000 --directory dist
\`\`\`

Visit http://localhost:8000/ for the welcome note and
http://localhost:8000/static/search/ for the library and section search.
Serving is optional and separate from generation; this starter does not deploy.
For automatic rebuild and browser reload on Node, use
\`node "$LATTICE_CLI" serve\` instead of Python and visit http://127.0.0.1:4321/.
This preview binds loopback only. Validation failures keep the last good output;
fix the source to resume successful rebuilds. Stop with Ctrl+C.

## Add your first note

From the wiki directory, create a file using the collection's schema. Use another
terminal if the local HTTP server is still running:

\`\`\`sh
lattice new Guides --name field-journal
\`\`\`

With the repository's JavaScript CLI, use
\`node "$LATTICE_CLI" new Guides --name field-journal\` instead.
\`Guides\` is the collection name in \`collections.cfg\`; \`field-journal\` is the
filename without \`.md\`. The command refuses to overwrite an existing note.

Open \`content/guides/field-journal.md\` and replace the generated placeholders
with your title, description and writing. For example:

\`\`\`md
---
title: Field journal
description: Observations from a walk in the garden.
tags: [Journal]
toc: true
---
## First observation

A copperleaf plant caught the afternoon light.

Return to [[getting-started|Getting started]].
\`\`\`

The template displays the frontmatter title, so start body sections at \`##\`.
\`toc: true\` adds contents navigation; tags make the note filterable in search.
Add \`[[field-journal|Field journal]]\` to \`content/guides/getting-started.md\`
to connect the new note to the tour. Wikilinks use the filename, not the title.

Check before building, stopping if validation fails:

\`\`\`sh
lattice check && lattice build
\`\`\`

Or use \`node "$LATTICE_CLI" check && node "$LATTICE_CLI" build\`.
The build updates the directory and search index automatically. With the local
server running, reload the overview, open **Field journal** under **Guides**,
or search for **copperleaf**. Follow the note's link back to **Getting started**.
Repeat check and build after editing; the plain HTTP server does not rebuild.

Edit content/guides and collections.cfg to grow the library. The starter includes
only fictional sample notes. Set base_url in content/lattice.conf before publishing.
Reader styles and assets live in content/static/search; shared templates live in
templates. The included WASM runtime requires a browser with WASM GC support.
The existing asset packager can prepare a fresh replacement bundle when upgrading.
`],
];
// Exclusive root creation rejects even empty existing directories. All source
// assets have already been read; no toolchain download or build happens here.
await mkdir(destination);
await mkdir(join(destination, 'data'));
for (const [name, bytes] of files) {
  const path = join(destination, name);
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, bytes, { flag: 'wx' });
}
console.log(`Created wiki in ${destination}. See README.md for check, build and local preview commands.`);
