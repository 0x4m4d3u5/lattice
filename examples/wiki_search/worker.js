import { createContentSearcher } from './host.js';

let indexJson;
let search;
self.addEventListener('message', async ({ data }) => {
  try {
    if (data.type === 'load') {
      const index = await fetch(data.indexUrl, { cache: 'no-store' });
      if (!index.ok) throw new Error('Index unavailable');
      indexJson = await index.text();
      const entries = JSON.parse(indexJson);
      if (!Array.isArray(entries)) throw new Error('Invalid index');
      self.postMessage({ id: data.id, type: 'catalogue', entries: entries.map(entry => ({
        title: entry?.title, url: entry?.url, collection: entry?.collection,
        description: entry?.description,
        sections: Array.isArray(entry?.sections) ? entry.sections.slice(0, 1).map(() => ({})) : undefined,
        body: typeof entry?.body === 'string' && entry.body.trim() ? 'present' : '',
      })) });
      const wasm = await fetch(new URL('./renderer.wasm', import.meta.url), { cache: 'no-store' });
      if (!wasm.ok) throw new Error('Search runtime unavailable');
      search = await createContentSearcher(await wasm.arrayBuffer());
      // Validate with the MoonBit decoder, including explicit empty sections.
      if (search(indexJson, '', '[]', 0).error !== null) throw new Error('Invalid content index');
      const names = new Map();
      // Explicitly empty sections never participate in retrieval. Missing sections
      // are legacy page-sized passages, even when only their title can match.
      for (const tag of entries.flatMap(entry => entry.sections?.length === 0 ? [] : entry.tags)) {
        // Match MoonBit's ASCII-only folding; preserve the first display spelling.
        const key = tag.replace(/[A-Z]/g, letter => letter.toLowerCase());
        if (!names.has(key)) names.set(key, tag);
      }
      const tags = [...names.values()].sort();
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
