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
