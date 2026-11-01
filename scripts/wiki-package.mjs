import { readFile } from 'node:fs/promises';

// Shared by the asset-only packager and the complete wiki starter. Prepare all
// inputs before either caller creates its new destination.
export async function prepareWikiAssets() {
  const sources = [
    ['index.html', '../examples/wiki_search/index.html'],
    ['shell.css', '../examples/wiki_search/shell.css'],
    ['page.css', '../examples/wiki_search/page.css'],
    ['catalogue.js', '../examples/wiki_search/catalogue.js'],
    ['boot.js', '../examples/wiki_search/boot.js'],
    ['navigation.js', '../examples/wiki_search/navigation.js'],
    ['app.js', '../examples/wiki_search/app.js'],
    ['graph.js', '../examples/wiki_search/graph.js'],
    ['graph-worker.js', '../examples/wiki_search/graph-worker.js'],
    ['graph-core.js', '../_build/js/debug/build/kurisu/lattice/examples/local_graph/local_graph.js'],
    ['worker.js', '../examples/wiki_search/worker.js'],
    ['host.js', '../examples/prepared_search/host.mjs'],
    ['renderer.wasm', '../_build/wasm-gc/debug/build/kurisu/lattice/examples/prepared_search/prepared_search.wasm'],
  ];
  const files = await Promise.all(sources.map(async ([name, source]) => [name, await readFile(new URL(source, import.meta.url))]));
  const navigation = (await readFile(new URL('../examples/wiki_search/wiki-navigation.html', import.meta.url), 'utf8'))
    .replaceAll('/static/search/', './').replace('/content-index.json', '../../content-index.json');
  files[0][1] = Buffer.from(files[0][1].toString('utf8').replace('<!-- wiki-navigation -->', navigation));
  return files;
}
