import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { collectEvidence, comparePublication, compareRetention } from './evidence.mjs';

const page = { title: 'Guide', url: '/guide/', sections: [{ heading: 'Restore', body: 'Verify checksums.', fragment: 'restore' }] };
const hit = { title: 'Guide', url: '/guide/', section_index: 0, section: 'Restore', fragment: 'restore' };
const request = {
  indexJson: JSON.stringify([page]), query: 'checksums', origin: 'https://example.test',
  search: async () => ({ results: [hit], error: null }),
};
const states = ['matched', 'unknown', 'mismatched', 'invalid'];
for (const pairing of states) for (const retention of states) {
  test(`strict policy: pairing=${pairing}, retention=${retention}; default unchanged`, async () => {
    const validation = { ok: true, pairing: { status: pairing }, retention: { status: retention } };
    const options = { ...request, validateTarget: async () => validation };
    const legacy = await collectEvidence(options);
    assert.equal(legacy.status, 'ready');
    assert.equal(legacy.citation.url, 'https://example.test/guide/#restore');
    assert.deepEqual(await collectEvidence({ ...options, strictCitations: false }), legacy);
    const result = await collectEvidence({ ...options, strictCitations: true });
    if (pairing === 'matched' && retention === 'matched') {
      assert.deepEqual(result, legacy);
      assert.match(result.limitation, /not browser visibility/);
    } else {
      assert.equal(result.status, 'rejected_citation');
      assert.equal(result.citation, null);
      assert.deepEqual(result.rejections.map(({ check, status }) => ({ check, status })),
        Object.entries({ pairing, retention }).filter(([, state]) => state !== 'matched').map(([check, status]) => ({ check, status })));
      for (const rejection of result.rejections) assert.match(result.reason, new RegExp(`${rejection.check} must be matched; received ${rejection.status}`));
      assert.equal(result.pairing.status, pairing);
      assert.equal(result.retention.status, retention);
      assert.ok(result.candidates.every(candidate => !candidate.citation), 'diagnostic candidates must not contain issued citations');
    }
  });
}

test('strict rejects absent host comparisons and preserves explanations', async () => {
  const result = await collectEvidence({ ...request, strictCitations: true, validateTarget: async () => ({ ok: true }) });
  assert.equal(result.citation, null);
  assert.deepEqual(result.rejections.map(r => r.status), ['unknown', 'unknown']);
  assert.equal(result.rejections[0].detail, 'Host did not compare publication bytes');
  assert.equal(result.rejections[1].detail, 'Host did not compare passage retention');
  for (const status of [undefined, 'verified', true]) {
    const malformed = await collectEvidence({ ...request, strictCitations: true,
      validateTarget: async () => ({ ok: true, pairing: { status }, retention: { status: 'matched' } }) });
    assert.equal(malformed.status, 'rejected_citation');
    assert.equal(malformed.citation, null);
    assert.equal(malformed.rejections[0].status, 'invalid');
  }
});

test('strict does not override address failures or retrieval abstention', async () => {
  const validateTarget = async () => ({ ok: false, reason: 'Missing fragment', pairing: { status: 'matched' }, retention: { status: 'matched' } });
  const result = await collectEvidence({ ...request, strictCitations: true, validateTarget });
  assert.equal(result.status, 'invalid_target'); assert.equal(result.citation, null); assert.equal(result.reason, 'Missing fragment');
  for (const [response, status] of [
    [{ results: [], error: null }, 'no_results'],
    [{ results: [hit, hit], error: null }, 'ambiguous'],
    [{ results: [], error: 'Bad index' }, 'invalid_index'],
  ]) {
    const options = { ...request, search: async () => response, validateTarget: async () => assert.fail('must abstain before validation') };
    const legacy = await collectEvidence(options);
    const strict = await collectEvidence({ ...options, strictCitations: true });
    assert.deepEqual(strict, legacy); assert.equal(strict.status, status); assert.ok(!strict.citation);
  }
});

test('strict policy consumes real byte checks independently', async () => {
  const bytes = Buffer.from('<h2>Restore</h2><p>Verify checksums.</p>');
  const hash = value => createHash('sha256').update(value).digest('hex');
  const publication = { version: 1, algorithm: 'sha256', digest: hash(bytes) };
  const retention = { version: 1, algorithm: 'sha256', start: 0, end: bytes.length, digest: hash(bytes),
    heading_digest: hash('Restore'), body_digest: hash('Verify checksums.') };
  for (const check of ['pairing', 'retention']) for (const state of states) {
    const entry = { ...page, publication, sections: [{ ...page.sections[0], retention }] };
    const binding = state === 'unknown' ? undefined : state === 'invalid' ? null
      : state === 'mismatched' ? { ...(check === 'pairing' ? publication : retention), digest: '0'.repeat(64) }
      : check === 'pairing' ? publication : retention;
    if (check === 'pairing') entry.publication = binding;
    else entry.sections[0].retention = binding;
    const result = await collectEvidence({ ...request, indexJson: JSON.stringify([entry]), strictCitations: true,
      validateTarget: async (_url, _fragment, p, passage) => ({ ok: true, pairing: comparePublication(bytes, p), retention: compareRetention(bytes, passage) }) });
    assert.equal(result[check].status, state);
    assert.equal(result[check === 'pairing' ? 'retention' : 'pairing'].status, 'matched');
    assert.equal(result.status, state === 'matched' ? 'ready' : 'rejected_citation');
    if (state !== 'matched') assert.equal(result.citation, null);
  }
});

test('policy configuration and CLI flags fail clearly on invalid input', async () => {
  for (const strictCitations of ['false', null, 1]) {
    await assert.rejects(collectEvidence({ ...request, strictCitations }), /strictCitations must be a boolean/);
  }
  for (const args of [[], ['--strict-citations'], ['--strict-citation', 'index.json', 'https://example.test', 'query']]) {
    const run = spawnSync(process.execPath, [new URL('./run.mjs', import.meta.url).pathname, ...args], { encoding: 'utf8' });
    assert.notEqual(run.status, 0); assert.match(run.stderr, /Usage:.*\[--strict-citations\]/);
    assert.equal(run.stdout, '');
  }
});

test('legacy body-only indexes remain usable by default but cannot pass strict mode', async () => {
  const options = { ...request, indexJson: JSON.stringify([{ title: 'Guide', url: '/guide/', body: 'Verify checksums.' }]),
    search: async () => ({ results: [{ ...hit, fragment: undefined }], error: null }),
    validateTarget: async (_url, _fragment, publication, passage) => ({ ok: true,
      pairing: comparePublication(Buffer.from('Legacy page'), publication), retention: compareRetention(Buffer.from('Legacy page'), passage) }) };
  const compatible = await collectEvidence(options);
  assert.equal(compatible.status, 'ready'); assert.equal(compatible.citation.url, 'https://example.test/guide/');
  const strict = await collectEvidence({ ...options, strictCitations: true });
  assert.equal(strict.status, 'rejected_citation'); assert.equal(strict.citation, null);
  assert.deepEqual(strict.rejections.map(({ check, status }) => ({ check, status })), [
    { check: 'pairing', status: 'unknown' }, { check: 'retention', status: 'unknown' },
  ]);
});

const contextRequest = entries => ({ ...request, indexJson: JSON.stringify(entries), validateTarget: async () => ({ ok: true, pairing: { status: 'matched' }, retention: { status: 'matched' } }) });
test('page context distinguishes observation, validity and existing dates without choosing truth', async () => {
  const old = { ...page, date: '2026-01-01', updated: '2026-02-01', observed_at: '2026-02-01T01:02:03Z', valid_from: '2025-01-01 01:02:03', valid_until: '2025-12-31T00:00:00+05:30' };
  const correction = { ...page, title: 'Correction', url: '/correction/', supersedes: [{ title: 'Do not trust duplicated metadata', url: old.url }], observed_at: '2099-01-01T00:00:00' };
  const result = await collectEvidence({ ...contextRequest([old, correction]), strictCitations: true });
  assert.equal(result.status, 'ready');
  assert.deepEqual(result.candidates[0].context, { scope: 'page', basis: 'author_asserted_index_metadata', date: old.date, updated: old.updated, observed_at: old.observed_at, valid_from: old.valid_from, valid_until: old.valid_until, supersedes: [], superseded_by: [{ title: 'Correction', url: correction.url }] });
  const ambiguous = await collectEvidence({ ...contextRequest([old, correction]), search: async () => ({ results: [{ ...hit, score: 90 }, { ...hit, title: correction.title, url: correction.url, score: 1 }] }) });
  assert.equal(ambiguous.status, 'ambiguous');
  assert.equal(ambiguous.citation, null);
  assert.deepEqual(ambiguous.candidates.map(c => c.score), [90, 1]);
  assert.deepEqual(ambiguous.candidates[1].context.supersedes, [{ title: old.title, url: old.url }]);
  assert.equal(ambiguous.candidates[0].passage, old.sections[0].body);
});
test('legacy missing context remains explicitly absent', async () => {
  const result = await collectEvidence(contextRequest([page]));
  assert.deepEqual(result.candidates[0].context, { scope: 'page', basis: 'author_asserted_index_metadata', date: null, updated: null, observed_at: null, valid_from: null, valid_until: null, supersedes: [], superseded_by: [] });
});
test('malformed authored context is rejected without returning names or dates', async () => {
  for (const patch of [{ date: {} }, { updated: {} }, { observed_at: '2026-02-29T01:02:03Z' }, { observed_at: '2026-01-01T24:00:00' }, { valid_from: null }, { valid_until: '2026-01-01' }, { supersedes: {} }, { supersedes: [{ title: 'private', url: '/secret/', extra: true }] }]) {
    const result = await collectEvidence(contextRequest([{ ...page, ...patch }]));
    assert.equal(result.status, 'invalid_context', JSON.stringify(patch));
    assert.deepEqual(result.candidates, []);
    assert.equal(result.citation, null);
  }
});
test('relationships never echo unresolved, duplicate, generated or unsafe destinations', async () => {
  const source = { ...page, supersedes: ['/missing/', '/duplicate/', '/generated/', '//outside.test/', '/bad?x', page.url].map(url => ({ title: 'secret sentinel', url })) };
  const entries = [source, { title: 'dup', url: '/duplicate/' }, { title: 'dup', url: '/duplicate/' }, { title: 'generated', url: '/generated/', kind: 'collection_index' }];
  const result = await collectEvidence(contextRequest(entries));
  assert.equal(result.status, 'ready');
  assert.deepEqual(result.candidates[0].context.supersedes, []);
  assert.ok(!JSON.stringify(result).includes('secret sentinel'));
});
test('cycles are authored claims, not automatic deletion or current-fact selection', async () => {
  const a = { ...page, supersedes: [{ title: 'B', url: '/b/' }] };
  const b = { ...page, title: 'B', url: '/b/', supersedes: [{ title: page.title, url: page.url }] };
  const result = await collectEvidence(contextRequest([a, b]));
  assert.equal(result.status, 'ready');
  assert.deepEqual(result.candidates[0].context.supersedes, [{ title: 'B', url: '/b/' }]);
  assert.deepEqual(result.candidates[0].context.superseded_by, [{ title: 'B', url: '/b/' }]);
});

test('existing authored date strings are preserved without assigning time semantics', async () => {
  const result = await collectEvidence(contextRequest([{ ...page, date: 'Spring 2026', updated: '2026-02-03T01:02:03Z' }]));
  assert.equal(result.status, 'ready');
  assert.equal(result.candidates[0].context.date, 'Spring 2026');
  assert.equal(result.candidates[0].context.updated, '2026-02-03T01:02:03Z');
});
test('DateTime context mirrors schema calendar shapes without interval selection', async () => {
  for (const value of ['2024-02-29T23:59:59Z', '0000-02-29 00:00:00', '2026-01-01 01:02:03+23:59', '2026-01-01T01:02:03-05:30']) {
    const result = await collectEvidence(contextRequest([{ ...page, observed_at: value, valid_from: '2099-01-01T00:00:00Z', valid_until: '2000-01-01T00:00:00Z' }]));
    assert.equal(result.status, 'ready', value);
    assert.equal(result.candidates[0].context.observed_at, value);
  }
  for (const value of ['1900-02-29T00:00:00Z', '2026-01-01T01:60:00Z', '2026-01-01T00:00:60Z', '2026-01-01T00:00:00+24:00', '2026-01-01T00:00:00.123Z']) {
    assert.equal((await collectEvidence(contextRequest([{ ...page, observed_at: value }]))).status, 'invalid_context', value);
  }
});
