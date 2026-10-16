import { createContentSearcher } from './host.js';

let indexJson;
let search;
self.addEventListener('message', async ({ data }) => {
  try {
    if (data.type === 'load') {
      const [index, wasm] = await Promise.all([
        fetch(data.indexUrl, { cache: 'no-store' }),
        fetch(new URL('./renderer.wasm', import.meta.url), { cache: 'no-store' }),
      ]);
      if (!index.ok || !wasm.ok) throw new Error('Search files unavailable');
      indexJson = await index.text();
      search = await createContentSearcher(await wasm.arrayBuffer());
      // Validate with the MoonBit decoder, including explicit empty sections.
      if (search(indexJson, '', '[]', 0).error !== null) throw new Error('Invalid content index');
      const tags = [...new Set(JSON.parse(indexJson).flatMap(entry => entry.tags))].sort();
      self.postMessage({ id: data.id, type: 'ready', tags });
    } else if (data.type === 'search') {
      const response = search(indexJson, data.query, JSON.stringify(data.tags), 10);
      if (response.error !== null) throw new Error('Search failed');
      self.postMessage({ id: data.id, type: 'results', results: response.results });
    }
  } catch {
    self.postMessage({ id: data.id, type: 'error' });
  }
});
