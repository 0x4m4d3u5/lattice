import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';

if (process.argv.length !== 3) throw new Error('Usage: node scripts/package-search.mjs NEW_DIRECTORY');
const destination = resolve(process.argv[2]);
const sources = [
  ['index.html', '../examples/wiki_search/index.html'],
  ['shell.css', '../examples/wiki_search/shell.css'],
  ['page.css', '../examples/wiki_search/page.css'],
  ['catalogue.js', '../examples/wiki_search/catalogue.js'],
  ['app.js', '../examples/wiki_search/app.js'],
  ['worker.js', '../examples/wiki_search/worker.js'],
  ['host.js', '../examples/wasm_note/host.mjs'],
  ['renderer.wasm', '../_build/wasm-gc/debug/build/kurisu/lattice/examples/wasm_note/wasm_note.wasm'],
];
// Read every input before creating output; never replace an existing directory.
const files = await Promise.all(sources.map(async ([name, source]) => [name, await readFile(new URL(source, import.meta.url))]));
const navigation = (await readFile(new URL('../examples/wiki_search/wiki-navigation.html', import.meta.url), 'utf8'))
  .replaceAll('/static/search/', './').replace('/content-index.json', '../../content-index.json');
files[0][1] = Buffer.from(files[0][1].toString('utf8').replace('<!-- wiki-navigation -->', navigation));
await mkdir(destination);
await Promise.all(files.map(([name, bytes]) => writeFile(join(destination, name), bytes, { flag: 'wx' })));
console.log(`Packaged wiki search in ${destination}`);
