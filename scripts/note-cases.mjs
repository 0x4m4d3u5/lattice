// Expected results are authored independently of Lattice's parser/renderer.
// A host supplies its assertion library; these cases require no Node services.
export function runNoteCases(render, assert) {
  let count = 0;
  const check = (actual, expected) => { assert.deepEqual(actual, expected); count++; };
  const ok = (html) => ({ html, diagnostics: [] });
  const issue = (kind, source, message) => ({ kind, source, message });
  const yaml = (body) => `---\ntitle: Garden\n---\n${body}`;
  check(render(yaml('Hello 世界 🌱.\n'), '庭/🌱.md', '{}'), ok('<p>Hello 世界 🌱.</p>\n'));
  check(render('+++\ntitle = "庭 🌱"\n+++\n## Garden\n', 'toml.md', '{}'),
    ok('<h2 id="garden">Garden</h2>\n'));
  check(render(yaml('Read [[soil|土壌 🌱]] and `[[sample]]`.\n'), 'garden.md',
    '{"soil":"/notes/soil/?q=\\u571f&x=1"}'),
    ok('<p>Read <a href="/notes/soil/?q=土&amp;x=1">土壌 🌱</a> and <code>[[sample]]</code>.</p>\n'));
  check(render(yaml('A & B < C.\n'), 'escaping.md', '{}'),
    ok('<p>A &amp; B &lt; C.</p>\n'));
  check(render(yaml('e\u0301 \u0000 \ud800 🌱.\n'), 'units.md', '{}'),
    ok('<p>e\u0301 \u0000 \ud800 🌱.</p>\n'));
  check(render('No delimiter.', 'bad.md', '{}'), {
    html: '', diagnostics: [issue('frontmatter', 'bad.md',
      "missing opening frontmatter delimiter (expected '---' for YAML or '+++' for TOML)")],
  });
  for (const links of ['{', '[]', '{"soil":42}']) {
    check(render(yaml('Body.'), 'map.md', links), {
      html: '', diagnostics: [issue('link_map', 'map.md', 'expected a JSON object of slug-to-URL strings')],
    });
  }
  check(render(yaml('[[missing]] {{< unknown >}}\n'), 'errors/🌱.md', '{}'), {
    html: '', diagnostics: [
      issue('wikilink', 'errors/🌱.md', "target 'missing' not found in page index"),
      issue('shortcode', 'errors/🌱.md', "unknown shortcode 'unknown'"),
    ],
  });
  check(render(yaml('Text[^source].\n\n[^source]: {{< image src="/chart.png" >}}\n'), 'footnote.md', '{}'), {
    html: '', diagnostics: [issue('shortcode', 'footnote.md', "shortcode 'image' missing param 'alt'")],
  });
  check(render(yaml('## Planting & Care\n\n## Planting & Care\n'), 'beta.md', '{}'),
    ok('<h2 id="planting-care">Planting &amp; Care</h2>\n<h2 id="planting-care-2">Planting &amp; Care</h2>\n'));
  check(render(yaml('Read [[Beta.md#Planting & Care|care]] and [[Beta#planting-care-2|again]].\n'), 'garden.md',
    '{"beta":"/notes/beta/"}'),
    ok('<p>Read <a href="/notes/beta/#planting-care">care</a> and <a href="/notes/beta/#planting-care-2">again</a>.</p>\n'));
  check(render(yaml('[[Missing#Intro]]'), 'garden.md', '{}'), {
    html: '', diagnostics: [issue('wikilink', 'garden.md', "target 'Missing#Intro' not found in page index")],
  });
  check(render(yaml('Use ``[[missing]] ` literal`` and [[Beta|real]].\n'), 'code.md', '{"beta":"/notes/beta/"}'),
    ok('<p>Use <code>[[missing]] ` literal</code> and <a href="/notes/beta/">real</a>.</p>\n'));
  check(render(yaml('Example ```{{< unknown >}} `` ticks```.\n'), 'code.md', '{}'),
    ok('<p>Example <code>{{&lt; unknown &gt;}} `` ticks</code>.</p>\n'));
  check(render(yaml('Use ``open and [[missing]].\n'), 'code.md', '{}'), {
    html: '', diagnostics: [issue('wikilink', 'code.md', "target 'missing' not found in page index")],
  });
  // A new caller-supplied map must take effect; no prior note/map/error state leaks.
  for (let n = 0; n < 256; n++) {
    const text = `Synthetic note ${n} 🌱.`;
    check(render(yaml(text), `note-${n}.md`, '{}'), ok(`<p>${text}</p>\n`));
    check(render(yaml('[[soil|Guide]]'), `link-${n}.md`, JSON.stringify({ soil: `/notes/${n}/` })),
      ok(`<p><a href="/notes/${n}/">Guide</a></p>\n`));
  }
  const large = '🌱'.repeat(32768);
  check(render(yaml(large), 'large.md', '{}'), ok(`<p>${large}</p>\n`));
  check(render(yaml('Small again.'), 'small.md', '{}'), ok('<p>Small again.</p>\n'));
  return count;
}
