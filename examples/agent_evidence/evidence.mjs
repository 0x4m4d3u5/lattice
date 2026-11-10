import { createHash } from 'node:crypto';
// A conservative host policy around Lattice retrieval, not an answer generator.
export async function collectEvidence({ indexJson, query, search, validateTarget, origin, strictCitations = false }) {
  if (typeof strictCitations !== 'boolean') throw new TypeError('strictCitations must be a boolean');
  const response = await search(indexJson, query, '[]', 50);
  if (response.error) return { status: 'invalid_index', query, error: response.error, candidates: [] };
  const index = JSON.parse(indexJson);
  if (!validAuthoredContext(index)) return { status: 'invalid_context', query, candidates: [], citation: null, reason: 'Malformed authored evidence context' };
  const contexts = authoredContexts(index);
  const candidates = [];
  for (const hit of response.results) {
    const pages = index.filter(entry => entry.url === hit.url);
    if (pages.length !== 1) return { status: 'ambiguous_index', query, candidates: [], pairing: { status: 'invalid', reason: 'Multiple index records claim one canonical page' }, retention: { status: 'invalid', reason: 'Multiple index records claim one canonical page' } };
    const page = pages[0];
    const section = Array.isArray(page.sections) ? page.sections[hit.section_index] : { heading: '', body: page.body };
    if (!section || typeof section.body !== 'string' || !section.body.trim()) return { status: 'invalid_evidence', query, candidates: [] };
    candidates.push({ title: hit.title, page: hit.url, section: hit.section, sectionIndex: hit.section_index,
      context: contexts.get(page),
      passage: section.body, snippet: hit.snippet, score: hit.score, fragment: hit.fragment ?? null, publication: page.publication, retention: section.retention, heading: section.heading });
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
  const validation = await validateTarget(target.href, evidence.fragment, evidence.publication, { binding: evidence.retention, heading: evidence.heading, body: evidence.passage });
  const pairing = validation.pairing ?? { status: 'unknown', reason: 'Host did not compare publication bytes' };
  const retention = validation.retention ?? { status: 'unknown', reason: 'Host did not compare passage retention' };
  if (!validation.ok) return { status: 'invalid_target', query, candidates, citation: null, reason: validation.reason, pairing, retention };
  if (strictCitations) {
    const rejections = [];
    for (const [check, result] of [['pairing', pairing], ['retention', retention]]) {
      if (result.status === 'matched') continue;
      const status = ['unknown', 'mismatched', 'invalid'].includes(result.status) ? result.status : 'invalid';
      rejections.push({ check, status, reason: `${check} must be matched; received ${status}`,
        ...(typeof result.reason === 'string' ? { detail: result.reason } : {}) });
    }
    if (rejections.length) return { status: 'rejected_citation', query, candidates, pairing, retention,
      citation: null, reason: rejections.map(item => item.reason).join('; '), rejections };
  }
  return { status: 'ready', query, candidates, pairing, retention, citation: { title: evidence.title, url: target.href },
    limitation: 'Retrieved text is evidence to inspect, not proof of factual truth. Target validation does not establish freshness or truth of the indexed passage. Retention compares publisher-origin bytes, not browser visibility. Authored context is index metadata, not authenticated by pairing or retention.' };
}

// Compare the exact response bytes independently of citation-address validation.
export function comparePublication(bytes, binding) {
  if (binding === undefined) return { status: 'unknown', reason: 'Index has no publication binding' };
  if (!binding || typeof binding !== 'object' || Array.isArray(binding)
      || !Number.isSafeInteger(binding.version) || binding.version < 1 || typeof binding.algorithm !== 'string') {
    return { status: 'invalid', reason: 'Malformed publication binding' };
  }
  if (binding.version !== 1 || binding.algorithm !== 'sha256') return { status: 'unknown', reason: 'Unsupported publication binding' };
  if (Object.keys(binding).sort().join(',') !== 'algorithm,digest,version' || typeof binding.digest !== 'string' || !/^[a-f0-9]{64}$/.test(binding.digest)) {
    return { status: 'invalid', reason: 'Malformed version 1 SHA-256 binding' };
  }
  const actual = createHash('sha256').update(bytes).digest('hex');
  return { status: actual === binding.digest ? 'matched' : 'mismatched', algorithm: 'sha256', expected: binding.digest, actual };
}

// Uses browser-parsed DOM, so comments and script text cannot masquerade as IDs.
export async function validatePublishedTarget(context, url, fragment, publication, passage) {
  let page;
  try {
    // Each target gets its own document lifecycle, including repeated fragments.
    page = await context.newPage();
    const response = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 15_000 });
    if (!response || !response.ok() || !response.headers()['content-type']?.includes('text/html')) return { ok: false, reason: 'Target is not a successful HTML response' };
    const actual = new URL(page.url()); const expected = new URL(url);
    actual.hash = ''; expected.hash = '';
    if (actual.href !== expected.href) return { ok: false, reason: 'Target redirects away from the indexed canonical page' };
    const bytes = await response.body();
    const pairing = comparePublication(bytes, publication);
    const retention = compareRetention(bytes, passage);
    if (fragment) {
      const count = await page.evaluate(id => [...document.querySelectorAll('[id]')].filter(el => el.id === id).length, fragment);
      if (count !== 1) return { ok: false, reason: 'Fragment is missing or not unique in published HTML', pairing, retention };
    }
    return { ok: true, pairing, retention };
  } catch (error) { return { ok: false, reason: `Target could not be loaded: ${error.message}` }; }
  finally { await page?.close(); }
}

// Publisher-origin byte retention only. This does not evaluate DOM visibility,
// authenticate the publisher, or establish that indexed claims are true.
export function compareRetention(bytes, passage) {
  const binding = passage?.binding;
  if (binding === undefined) return { status: 'unknown', reason: 'Section has no retention binding' };
  if (!binding || typeof binding !== 'object' || Array.isArray(binding)
      || !Number.isSafeInteger(binding.version) || binding.version < 1 || typeof binding.algorithm !== 'string') {
    return { status: 'invalid', reason: 'Malformed retention binding' };
  }
  if (binding.version !== 1 || binding.algorithm !== 'sha256') return { status: 'unknown', reason: 'Unsupported retention binding' };
  if (Object.keys(binding).sort().join(',') !== 'algorithm,body_digest,digest,end,heading_digest,start,version'
      || !Number.isSafeInteger(binding.start) || !Number.isSafeInteger(binding.end)
      || binding.start < 0 || binding.end <= binding.start
      || !['digest', 'heading_digest', 'body_digest'].every(key => typeof binding[key] === 'string' && /^[a-f0-9]{64}$/.test(binding[key]))
      || typeof passage.heading !== 'string' || typeof passage.body !== 'string') {
    return { status: 'invalid', reason: 'Malformed version 1 retention binding' };
  }
  const hash = value => createHash('sha256').update(value).digest('hex');
  if (binding.end > bytes.length) return { status: 'mismatched', reason: 'Range exceeds response bytes' };
  const slice = bytes.subarray(binding.start, binding.end);
  try {
    new TextDecoder('utf-8', { fatal: true }).decode(bytes.subarray(0, binding.start));
    new TextDecoder('utf-8', { fatal: true }).decode(slice);
  } catch { return { status: 'mismatched', reason: 'Range is not on UTF-8 boundaries' }; }
  const matches = hash(slice) === binding.digest && hash(passage.heading) === binding.heading_digest && hash(passage.body) === binding.body_digest;
  return { status: matches ? 'matched' : 'mismatched', algorithm: 'sha256' };
}

// Page-scoped author assertions, not passage bindings or validity intervals.
// Resolve relationships back to unique indexed pages; never echo dangling names.
function authoredContexts(index) {
  const pages = new Map();
  for (const page of index) pages.set(page.url, pages.has(page.url) ? null : page);
  const uniquePage = url => {
    if (typeof url !== 'string' || !url.startsWith('/') || url.startsWith('//') || /[\\?#\u0000-\u0020]/.test(url)) return null;
    const page = pages.get(url);
    return page && page.kind !== 'collection_index' ? page : null;
  };
  const contexts = new Map(index.map(page => [page, {
    scope: 'page', basis: 'author_asserted_index_metadata',
    date: typeof page.date === 'string' && page.date ? page.date : null,
    updated: typeof page.updated === 'string' && page.updated ? page.updated : null,
    observed_at: page.observed_at ?? null, valid_from: page.valid_from ?? null,
    valid_until: page.valid_until ?? null, supersedes: [], superseded_by: [],
  }]));
  for (const page of index) {
    if (uniquePage(page.url) !== page || typeof page.title !== 'string') continue;
    const seen = new Set();
    for (const ref of page.supersedes ?? []) {
      const target = uniquePage(ref.url);
      if (!target || target === page || seen.has(target.url) || typeof target.title !== 'string') continue;
      seen.add(target.url);
      contexts.get(page).supersedes.push({ title: target.title, url: target.url });
      contexts.get(target).superseded_by.push({ title: page.title, url: page.url });
    }
  }
  return contexts;
}

function validAuthoredContext(index) {
  // DateTime has the publisher's calendar shape, including optional timezone.
  // Do not coerce dates or evaluate their relationship to the current clock.
  const datetime = value => {
    if (typeof value !== 'string') return false;
    const match = /^(\d{4}-\d{2}-\d{2})[T ](\d{2}):(\d{2}):(\d{2})(?:Z|([+-])(\d{2}):(\d{2}))?$/.exec(value);
    if (!match || !date(match[1])) return false;
    return Number(match[2]) < 24 && Number(match[3]) < 60 && Number(match[4]) < 60 && (!match[5] || (Number(match[6]) < 24 && Number(match[7]) < 60));
  };
  const date = value => {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
    const [y, m, d] = value.split('-').map(Number);
    const leap = y % 4 === 0 && (y % 100 !== 0 || y % 400 === 0);
    return m >= 1 && m <= 12 && d >= 1 && d <= [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1];
  };
  return index.every(page => {
    for (const field of ['date', 'updated']) {
      if (page[field] !== undefined && typeof page[field] !== 'string') return false;
    }
    for (const field of ['observed_at', 'valid_from', 'valid_until']) {
      if (page[field] !== undefined && !datetime(page[field])) return false;
    }
    return page.supersedes === undefined || (Array.isArray(page.supersedes) && page.supersedes.every(ref => ref && typeof ref === 'object' && !Array.isArray(ref) && Object.keys(ref).sort().join(',') === 'title,url' && typeof ref.title === 'string' && typeof ref.url === 'string'));
  });
}
