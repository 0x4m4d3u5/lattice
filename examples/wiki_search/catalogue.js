// The index describes passages, not trusted HTML. Only readable, same-origin
// canonical pages belong in the directory; generated/overwritten entries have [].
export function buildCatalogue(entries, base, overview) {
  if (!Array.isArray(entries)) return [];
  const pages = new Map();
  for (const entry of entries) {
    if (!entry || typeof entry.title !== 'string' || !entry.title.trim() || typeof entry.url !== 'string') continue;
    const readable = Array.isArray(entry.sections) ? entry.sections.length > 0 : typeof entry.body === 'string' && entry.body.trim();
    if (!readable) continue;
    try {
      const url = new URL(entry.url, base);
      if (!['http:', 'https:'].includes(url.protocol) || url.origin !== new URL(base).origin || url.username || url.password) continue;
      if (url.pathname === new URL(overview, base).pathname || url.search || url.hash) continue;
      const collection = typeof entry.collection === 'string' ? entry.collection.trim() : '';
      // These are publisher source groups, not reader-facing collection names.
      const label = !collection || collection === '_root' || collection === '_standalone' ? 'Pages' : collection;
      if (!pages.has(url.href)) pages.set(url.href, {
        title: entry.title, url: url.href,
        collection: label,
        description: typeof entry.description === 'string' ? entry.description : '',
      });
    } catch { /* Invalid index URLs never become navigation. */ }
  }
  return [...pages.values()].sort((a, b) => a.collection.localeCompare(b.collection) || a.title.localeCompare(b.title) || a.url.localeCompare(b.url));
}
