// Expected results are authored independently of Lattice's parser/renderer.
// A host supplies its assertion library; these cases require no Node services.
export function runNoteCases(render, assert) {
  let count = 0;
  const check = (actual, expected) => { assert.deepEqual(actual, expected); count++; };
  const ok = (html) => ({ html, diagnostics: [] });
  const issue = (kind, source, message) => ({ kind, source, message });
  const yaml = (body) => `---\ntitle: Garden\n---\n${body}`;
  check(render(yaml('## Planting & Care\n\n## Planting & Care\n\nJump [[#Planting & Care|here]] or [[#planting-care-2]]. `[[#sample]]`.\n'), 'local.md', '{}'),
    ok('<h2 id="planting-care">Planting &amp; Care</h2>\n<h2 id="planting-care-2">Planting &amp; Care</h2>\n<p>Jump <a href="#planting-care">here</a> or <a href="#planting-care-2">#planting-care-2</a>. <code>[[#sample]]</code>.</p>\n'));
  check(render(yaml('[[#]]\n'), 'local.md', '{}'), {
    html: '', diagnostics: [issue('wikilink', 'local.md', "target '#' not found in page index")],
  });
  check(render(yaml('Hello 世界 🌱.\n'), '庭/🌱.md', '{}'), ok('<p>Hello 世界 🌱.</p>\n'));
  check(render('+++\ntitle = "庭 🌱"\n+++\n## Garden\n', 'toml.md', '{}'),
    ok('<h2 id="garden">Garden</h2>\n'));
  check(render(yaml('Read [[soil|土壌 🌱]] and `[[sample]]`.\n'), 'garden.md',
    '{"soil":"/notes/soil/?q=\\u571f&x=1"}'),
    ok('<p>Read <a href="/notes/soil/?q=土&amp;x=1">土壌 🌱</a> and <code>[[sample]]</code>.</p>\n'));
  check(render(yaml('| Note | Detail |\n| --- | --- |\n| [[soil\\|Soil guide]] | `a\\|b` |\n| a\\\\|b | `a\\\\\\\\|b` |\n'), 'table.md',
    '{"soil":"/notes/soil/"}'),
    ok('<table>\n<thead>\n<tr>\n<th>Note</th>\n<th>Detail</th>\n</tr>\n</thead>\n<tbody>\n<tr>\n<td><a href="/notes/soil/">Soil guide</a></td>\n<td><code>a|b</code></td>\n</tr>\n<tr>\n<td>a|b</td>\n<td><code>a\\\\\\|b</code></td>\n</tr>\n</tbody>\n</table>\n'));
  check(render(yaml('Paths C:\\Users\\notes and \\🌱.\n\nFirst\\\nSecond.\n'), 'backslashes.md', '{}'),
    ok('<p>Paths C:\\Users\\notes and \\🌱.</p>\n<p>First<br />\nSecond.</p>\n'));
  check(render(yaml('First\\\r\nSecond.\n\nThird\\\rFourth.\n\n`Literal\\\r\ncode`\n'), 'crlf.md', '{}'),
    ok('<p>First<br />\nSecond.</p>\n<p>Third<br />\nFourth.</p>\n<p><code>Literal\\\r\ncode</code></p>\n'));
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
  check(render(yaml('Example ``\n{{< callout type="note" >}}\nLiteral body.\n``.\n\n{{< callout type="note" >}}\nLive body.\n'), 'callout-code.md', '{}'),
    ok('<p>Example <code>\n{{&lt; callout type="note" &gt;}}\nLiteral body.\n</code>.</p>\n<aside class="callout callout-note"><p>Live body.</p></aside>\n'));
  check(render(yaml('**Example ``\n{{< callout type="note" >}}\nLiteral body.\n``**.\n'), 'callout-code.md', '{}'),
    ok('<p><strong>Example <code>\n{{&lt; callout type="note" &gt;}}\nLiteral body.\n</code></strong>.</p>\n'));
  check(render(yaml('Unmatched `` opener.\n\n{{< callout type="note" >}}\nLive body.\n'), 'callout-code.md', '{}'),
    ok('<p>Unmatched `` opener.</p>\n<aside class="callout callout-note"><p>Live body.</p></aside>\n'));
  check(render(yaml('- Item\n  Example ``\n  {{< callout type="note" >}}\n  # Heading\n  {{< callout type="note" >}}\n  Live body.\n  ``.\n'), 'callout-code.md', '{}'),
    ok('<ul>\n<li>Item<p>Example ``</p>\n</li>\n</ul>\n<p><aside class="callout callout-note"><p># Heading</p></aside> <aside class="callout callout-note"><p>Live body.</p></aside>   ``.</p>\n'));
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
