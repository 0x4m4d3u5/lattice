// Knowledge-note expectations are authored independently of the ranking code.
// Shared by Node JS, WASM GC and the real browser worker.
export function runSearchCases(search, assert) {
  let count = 0;
  const equal = (actual, expected) => { assert.deepEqual(actual, expected); count++; };
  const pages = [
    { title: 'Operations handbook', url: '/wiki/ops/', tags: ['Reliability', 'Database'], sections: [
      { heading: 'Backups', body: 'Snapshot the volume nightly. Keep encrypted copies offsite.' },
      { heading: 'Recovery drills', body: 'Restore a backup into an isolated cluster. Verify checksums before promotion.' },
      { heading: 'Recovery drills', body: 'Record elapsed time after each exercise.' },
    ] },
    { title: 'Recovery checklist', url: '/wiki/recovery/', tags: ['Reliability'], sections: [
      { heading: 'Before an incident', body: 'Assign a commander. Check database backups.' },
    ] },
    { title: 'Incident journal', url: '/wiki/incidents/', tags: ['Reliability'], sections: [
      { heading: 'Monday', body: 'The recovery recovery recovery recovery recovery took an hour.' },
    ] },
    { title: 'References', url: '/wiki/references/', tags: ['Database'], sections: [
      { heading: 'Footnotes', body: 'Restore encrypted snapshots. ↩' },
    ] },
    { title: 'Vocabulary', url: '/wiki/words/', tags: ['Language'], sections: [
      { heading: 'Terms', body: 'Recoveryplan is a single token. café soil 🌱.' },
    ] },
  ];
  const run = (query, tags = [], limit = 10, index = pages) => search(JSON.stringify(index), query, JSON.stringify(tags), limit);
  const recovery = run('RECOVERY');
  equal(recovery.error, null);
  equal(recovery.results.map(hit => [hit.url, hit.section_index]), [
    ['/wiki/ops/', 1], ['/wiki/ops/', 2], ['/wiki/recovery/', 0], ['/wiki/incidents/', 0],
  ]);
  equal(recovery.results[0].snippet, 'Restore a backup into an isolated cluster. Verify checksums before promotion.');
  equal(recovery.results[0].section, 'Recovery drills');
  equal(recovery.results[0].tags, ['Reliability', 'Database']);
  equal(run('recovery recovery').results, recovery.results);
  equal(run('recovery', [' database ', 'RELIABILITY']).results.map(hit => hit.url), ['/wiki/ops/', '/wiki/ops/']);
  equal(run('recovery', ['data']).results, []);
  equal(run('recovery', ['Language']).results, []);
  equal(run('restore checksums').results.map(hit => hit.section_index), [1]);
  equal(run('encrypted').results.map(hit => [hit.url, hit.section]), [['/wiki/ops/', 'Backups'], ['/wiki/references/', 'Footnotes']]);
  equal(run('encrypted snapshots', ['Reliability']).results, []);
  equal(run('snapshot promotion').results, []); // Terms in different sections do not combine.
  equal(run('recovery', [], 2).results.map(hit => hit.section_index), [1, 2]);
  equal(run('recovery', [], 0).results, []);
  equal(run('recovery', [], -1).results, []);
  equal(run(' --?! ').results, []);
  equal(run('no-such-term').results, []);
  equal(run('café').results.map(hit => hit.url), ['/wiki/words/']);
  equal(run('CAFÉ').results, []); // ASCII folding only, same across runtimes.
  equal(run('🌱').results.map(hit => hit.url), ['/wiki/words/']);
  equal(run('recovery', [], 10, [...pages].reverse()), recovery);
  const tied = ['z', 'a'].map(name => ({ title: 'Notebook', url: `/${name}/`, tags: [], sections: [{ heading: 'Soil', body: 'Clay.' }] }));
  equal(run('soil', [], 10, tied).results.map(hit => hit.url), ['/a/', '/z/']);
  const legacy = [{ title: 'Legacy', url: '/legacy/', tags: [], body: 'Archive recovery notes.' }];
  equal(run('recovery', [], 10, legacy).results.map(hit => [hit.url, hit.section, hit.snippet]), [['/legacy/', '', 'Archive recovery notes.']]);
  equal(run('recovery', [], 10, [{ ...legacy[0], sections: [] }]).results, []);
  const late = '🌱 '.repeat(180) + 'recovery procedure ' + '🌱 '.repeat(180);
  const snippet = run('recovery', [], 10, [{ ...legacy[0], body: late }]).results[0].snippet;
  equal(snippet.includes('recovery procedure'), true);
  equal([...snippet].length <= 242, true);
  equal(snippet.includes('\uFFFD'), false);
  const prefixed = 'recoveryplan '.repeat(50) + 'restore recovery procedure';
  equal(run('recovery', [], 10, [{ ...legacy[0], body: prefixed }]).results[0].snippet.includes('restore recovery procedure'), true);
  const many = Array.from({ length: 70 }, (_, i) => ({ ...legacy[0], url: `/page-${i}/` }));
  equal(run('recovery', [], 1000, many).results.length, 50);
  const invalid = [
    ['{', '[]', 'invalid content-index JSON'],
    ['{}', '[]', 'expected a content-index array'],
    ['[]', '{', 'invalid tag-filter JSON'],
    ['[]', '[1]', 'expected an array of strings'],
    ['[{}]', '[]', 'each page requires title, nonempty url and tags'],
    [JSON.stringify([{ ...legacy[0], tags: [1] }]), '[]', 'expected an array of strings'],
    [JSON.stringify([{ ...legacy[0], sections: null }]), '[]', 'sections must be an array'],
    [JSON.stringify([{ ...legacy[0], sections: [{}] }]), '[]', 'each section requires heading and body strings'],
    [JSON.stringify([{ title: 'Missing', url: '/missing/', tags: [] }]), '[]', 'a page without sections requires body text'],
    [JSON.stringify([legacy[0], {}]), '[]', 'each page requires title, nonempty url and tags'],
  ];
  for (const [index, tags, error] of invalid) equal(search(index, 'recovery', tags, 10), { results: [], error });
  // Repeat diverse requests against one instance to catch retained state.
  for (let i = 0; i < 40; i++) {
    equal(run('recovery'), recovery);
    equal(run('snapshot', ['Language']).results, []);
  }
  return count;
}
