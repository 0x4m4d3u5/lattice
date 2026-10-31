// A conservative host policy around Lattice retrieval, not an answer generator.
export async function collectEvidence({ indexJson, query, search, validateTarget, origin }) {
  const response = await search(indexJson, query, '[]', 50);
  if (response.error) return { status: 'invalid_index', query, error: response.error, candidates: [] };
  const index = JSON.parse(indexJson);
  const candidates = [];
  for (const hit of response.results) {
    const pages = index.filter(entry => entry.url === hit.url);
    if (pages.length !== 1) return { status: 'ambiguous_index', query, candidates: [] };
    const page = pages[0];
    const section = Array.isArray(page.sections) ? page.sections[hit.section_index] : { heading: '', body: page.body };
    if (!section || typeof section.body !== 'string' || !section.body.trim()) return { status: 'invalid_evidence', query, candidates: [] };
    candidates.push({ title: hit.title, page: hit.url, section: hit.section, sectionIndex: hit.section_index,
      passage: section.body, snippet: hit.snippet, score: hit.score, fragment: hit.fragment ?? null });
  }
  if (!candidates.length) return { status: 'no_results', query, candidates };
  // Even a higher score does not establish which passage answers the question.
  if (candidates.length !== 1) return { status: 'ambiguous', query, candidates, citation: null };
  const evidence = candidates[0];
  const base = new URL(origin);
  if (!['http:', 'https:'].includes(base.protocol) || base.username || base.password) throw new Error('Use an HTTP(S) publication origin without credentials');
  if (typeof evidence.page !== 'string' || !evidence.page.startsWith('/') || evidence.page.startsWith('//') || /[\\?#\u0000-\u0020]/.test(evidence.page)) {
    return { status: 'invalid_target', query, candidates, citation: null };
  }
  const target = new URL(evidence.page, base);
  if (target.origin !== base.origin) return { status: 'invalid_target', query, candidates, citation: null };
  if (evidence.fragment) target.hash = encodeURIComponent(evidence.fragment);
  const validation = await validateTarget(target.href, evidence.fragment);
  if (!validation.ok) return { status: 'invalid_target', query, candidates, citation: null, reason: validation.reason };
  return { status: 'ready', query, candidates, citation: { title: evidence.title, url: target.href },
    limitation: 'Retrieved text is evidence to inspect, not proof of factual truth. Target validation does not establish freshness or truth of the indexed passage.' };
}

// Uses browser-parsed DOM, so comments and script text cannot masquerade as IDs.
export async function validatePublishedTarget(page, url, fragment) {
  try {
    // Force a document load even when successive candidates differ only by hash.
    await page.goto('about:blank');
    const response = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 15_000 });
    if (!response || !response.ok() || !response.headers()['content-type']?.includes('text/html')) return { ok: false, reason: 'Target is not a successful HTML response' };
    const actual = new URL(page.url()); const expected = new URL(url);
    actual.hash = ''; expected.hash = '';
    if (actual.href !== expected.href) return { ok: false, reason: 'Target redirects away from the indexed canonical page' };
    if (fragment) {
      const count = await page.evaluate(id => [...document.querySelectorAll('[id]')].filter(el => el.id === id).length, fragment);
      if (count !== 1) return { ok: false, reason: 'Fragment is missing or not unique in published HTML' };
    }
    return { ok: true };
  } catch { return { ok: false, reason: 'Target could not be loaded' }; }
}
