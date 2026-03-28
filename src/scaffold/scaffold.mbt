///|
/// Embedded template: base.html
let tmpl_base : String =
  #|<!doctype html>
  #|<html lang="en">
  #|<head>
  #|  {{include: head.html}}
  #|</head>
  #|<body>
  #|  <div class="page-grain"></div>
  #|  {{include: header.html}}
  #|  <main class="site-main">
  #|    {{body}}
  #|  </main>
  #|  {{include: footer.html}}
  #|</body>
  #|</html>
  #|

///|
/// Embedded template: head.html
let tmpl_head : String =
  #|<meta charset="utf-8" />
  #|<meta name="viewport" content="width=device-width, initial-scale=1" />
  #|<title>{{title}}</title>
  #|<meta name="description" content="{{description}}" />
  #|<link rel="preconnect" href="https://fonts.googleapis.com" />
  #|<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  #|<link href="https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,400;0,600;0,800;1,400;1,600&family=Source+Serif+4:ital,opsz,wght@0,8..60,300;0,8..60,400;0,8..60,600;1,8..60,300;1,8..60,400&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet" />
  #|<link rel="stylesheet" href="/static/style.css" />
  #|<style>
  #|{{custom_css}}
  #|</style>
  #|

///|
/// Embedded template: header.html
let tmpl_header : String =
  #|<header class="site-header">
  #|  <div class="site-header__inner">
  #|    <div class="site-header__brand">
  #|      <a href="/" class="site-header__title">{{site_name}}</a>
  #|    </div>
  #|    <nav class="site-nav" aria-label="Main navigation">
  #|      {{#each data.nav.links}}
  #|      <a href="/{{item}}/" class="site-nav__link">{{item}}</a>
  #|      {{/each}}
  #|    </nav>
  #|  </div>
  #|</header>
  #|

///|
/// Embedded template: footer.html
let tmpl_footer : String =
  #|<footer class="site-footer">
  #|  <div class="site-footer__inner">
  #|    <p class="site-footer__text">Built with <a href="https://github.com/brickfrog/lattice">Lattice</a> — where structural violations are type errors.</p>
  #|  </div>
  #|</footer>
  #|

///|
/// Embedded template: article.html
let tmpl_article : String =
  #|<article class="prose" itemscope itemtype="https://schema.org/BlogPosting">
  #|  <header class="prose__header">
  #|    <h1 class="prose__title" itemprop="headline">{{title}}</h1>
  #|    {{?description}}
  #|    <p class="prose__lede">{{description}}</p>
  #|    {{/?description}}
  #|    <div class="prose__meta">
  #|      {{?date}}
  #|      <time class="prose__date" itemprop="datePublished" content="{{date}}">{{date}}</time>
  #|      {{/?date}}
  #|      {{?author}}
  #|      <span class="prose__author" itemprop="author">{{author}}</span>
  #|      {{/?author}}
  #|      {{?reading_time}}
  #|      <span class="prose__reading-time">{{reading_time}} read</span>
  #|      {{/?reading_time}}
  #|      {{?word_count}}
  #|      <span class="prose__word-count">{{word_count}} words</span>
  #|      {{/?word_count}}
  #|    </div>
  #|    {{?tags}}
  #|    <div class="tag-list">{{tags}}</div>
  #|    {{/?tags}}
  #|  </header>
  #|
  #|  {{?table_of_contents}}
  #|  <aside class="toc" aria-label="Table of contents">
  #|    <details class="toc__details" open>
  #|      <summary class="toc__summary">On this page</summary>
  #|      {{table_of_contents}}
  #|    </details>
  #|  </aside>
  #|  {{/?table_of_contents}}
  #|
  #|  <div class="prose__body" itemprop="articleBody">
  #|    {{content}}
  #|  </div>
  #|
  #|  {{?backlinks}}
  #|  <aside class="backlinks" aria-label="Pages that link here">
  #|    <h2 class="backlinks__title">Linked from</h2>
  #|    {{backlinks}}
  #|  </aside>
  #|  {{/?backlinks}}
  #|
  #|  <nav class="post-nav" aria-label="Post navigation">
  #|    {{?prev_post_url}}
  #|    <a href="{{prev_post_url}}" class="post-nav__link post-nav__link--prev">
  #|      <span class="post-nav__label">Previous</span>
  #|      <span class="post-nav__title">{{prev_post_title}}</span>
  #|    </a>
  #|    {{/?prev_post_url}}
  #|    {{?next_post_url}}
  #|    <a href="{{next_post_url}}" class="post-nav__link post-nav__link--next">
  #|      <span class="post-nav__label">Next</span>
  #|      <span class="post-nav__title">{{next_post_title}}</span>
  #|    </a>
  #|    {{/?next_post_url}}
  #|  </nav>
  #|</article>
  #|

///|
/// Embedded template: page.html
let tmpl_page : String =
  #|{{layout: base.html}}
  #|{{include: article.html}}
  #|

///|
/// Embedded template: index.html
let tmpl_index : String =
  #|{{layout: base.html}}
  #|<section class="listing">
  #|  <header class="listing__header">
  #|    <h1 class="listing__title">{{title}}</h1>
  #|    {{?description}}
  #|    <p class="listing__description">{{description}}</p>
  #|    {{/?description}}
  #|  </header>
  #|  <div class="listing__content">
  #|    {{content}}
  #|  </div>
  #|  <nav class="pagination" aria-label="Pagination">
  #|    {{?prev_page}}
  #|    <a href="{{prev_page}}" class="pagination__link pagination__link--prev">Newer posts</a>
  #|    {{/?prev_page}}
  #|    <span class="pagination__info">{{page_num}} / {{total_pages}}</span>
  #|    {{?next_page}}
  #|    <a href="{{next_page}}" class="pagination__link pagination__link--next">Older posts</a>
  #|    {{/?next_page}}
  #|  </nav>
  #|</section>
  #|

///|
/// Embedded template: tag.html
let tmpl_tag : String =
  #|{{layout: base.html}}
  #|<section class="listing listing--tag">
  #|  <header class="listing__header">
  #|    <p class="listing__eyebrow">Tag</p>
  #|    <h1 class="listing__title">#{{tag_name}}</h1>
  #|    <p class="listing__description">{{tag_count}} posts</p>
  #|  </header>
  #|  <div class="listing__content">
  #|    {{content}}
  #|  </div>
  #|</section>
  #|

///|
/// Embedded template: tags.html
let tmpl_tags : String =
  #|{{layout: base.html}}
  #|<section class="listing listing--tags">
  #|  <header class="listing__header">
  #|    <p class="listing__eyebrow">Taxonomy</p>
  #|    <h1 class="listing__title">{{title}}</h1>
  #|    {{?description}}
  #|    <p class="listing__description">{{description}}</p>
  #|    {{/?description}}
  #|  </header>
  #|  <div class="listing__content listing__content--tags">
  #|    {{content}}
  #|  </div>
  #|</section>
  #|

///|
/// Embedded template: archive.html
let tmpl_archive : String =
  #|{{layout: base.html}}
  #|<section class="listing listing--archive">
  #|  <header class="listing__header">
  #|    <p class="listing__eyebrow">Archive</p>
  #|    <h1 class="listing__title">{{title}}</h1>
  #|  </header>
  #|  <div class="listing__content listing__content--archive">
  #|    {{content}}
  #|  </div>
  #|</section>
  #|

///|
/// Embedded stylesheet: style.css (Lattice Default Theme)
let style_css : String =
  #|/* ═══════════════════════════════════════════════════════════
  #|   Lattice — Default Theme
  #|   A typographic-first blog theme. Warm, editorial, precise.
  #|   ═══════════════════════════════════════════════════════════ */
  #|
  #|/* ── Tokens ── */
  #|
  #|:root {
  #|  --font-display: "Playfair Display", "Iowan Old Style", Georgia, serif;
  #|  --font-body: "Source Serif 4", "Iowan Old Style", Georgia, serif;
  #|  --font-mono: "JetBrains Mono", "Berkeley Mono", "SFMono-Regular", Consolas, monospace;
  #|
  #|  --bg: #faf6f0;
  #|  --bg-surface: #ffffff;
  #|  --bg-surface-dim: #f3ede4;
  #|  --bg-code: #f7f3ec;
  #|  --ink: #1c1917;
  #|  --ink-secondary: #57534e;
  #|  --ink-muted: #a8a29e;
  #|  --accent: #0d7377;
  #|  --accent-hover: #0a5c5f;
  #|  --accent-soft: #e0f2f1;
  #|  --border: #e7e0d5;
  #|  --border-strong: #d1c9bc;
  #|  --shadow: rgba(28, 25, 23, 0.06);
  #|  --shadow-lg: rgba(28, 25, 23, 0.1);
  #|
  #|  --measure: 65ch;
  #|  --gutter: clamp(1.25rem, 4vw, 3rem);
  #|  --max-width: 72rem;
  #|
  #|  /* Vertical rhythm base: 1.6 */
  #|  --leading: 1.65;
  #|  --space-xs: 0.25rem;
  #|  --space-sm: 0.5rem;
  #|  --space-md: 1rem;
  #|  --space-lg: 1.75rem;
  #|  --space-xl: 3rem;
  #|  --space-2xl: 5rem;
  #|
  #|  color-scheme: light dark;
  #|}
  #|
  #|@media (prefers-color-scheme: dark) {
  #|  :root {
  #|    --bg: #1a1816;
  #|    --bg-surface: #242120;
  #|    --bg-surface-dim: #1f1d1b;
  #|    --bg-code: #2a2725;
  #|    --ink: #ede8e2;
  #|    --ink-secondary: #b8b0a6;
  #|    --ink-muted: #78716c;
  #|    --accent: #5eead4;
  #|    --accent-hover: #99f6e4;
  #|    --accent-soft: rgba(94, 234, 212, 0.1);
  #|    --border: #373330;
  #|    --border-strong: #44403c;
  #|    --shadow: rgba(0, 0, 0, 0.2);
  #|    --shadow-lg: rgba(0, 0, 0, 0.35);
  #|  }
  #|}
  #|
  #|/* ── Reset ── */
  #|
  #|*,
  #|*::before,
  #|*::after {
  #|  box-sizing: border-box;
  #|  margin: 0;
  #|}
  #|
  #|html {
  #|  -webkit-font-smoothing: antialiased;
  #|  -moz-osx-font-smoothing: grayscale;
  #|  text-rendering: optimizeLegibility;
  #|  scroll-behavior: smooth;
  #|}
  #|
  #|/* ── Page Grain ── */
  #|
  #|.page-grain {
  #|  position: fixed;
  #|  inset: 0;
  #|  pointer-events: none;
  #|  z-index: 9999;
  #|  opacity: 0.025;
  #|  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='g'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.85' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23g)'/%3E%3C/svg%3E");
  #|}
  #|
  #|@media (prefers-color-scheme: dark) {
  #|  .page-grain { opacity: 0.04; }
  #|}
  #|
  #|/* ── Body ── */
  #|
  #|body {
  #|  font-family: var(--font-body);
  #|  font-size: clamp(1.05rem, 0.95rem + 0.25vw, 1.15rem);
  #|  line-height: var(--leading);
  #|  color: var(--ink);
  #|  background: var(--bg);
  #|}
  #|
  #|/* ── Site Header ── */
  #|
  #|.site-header {
  #|  border-bottom: 1px solid var(--border);
  #|}
  #|
  #|.site-header__inner {
  #|  display: flex;
  #|  align-items: baseline;
  #|  justify-content: space-between;
  #|  flex-wrap: wrap;
  #|  gap: var(--space-sm) var(--space-lg);
  #|  width: min(calc(100% - var(--gutter) * 2), var(--max-width));
  #|  margin: 0 auto;
  #|  padding: var(--space-lg) 0;
  #|}
  #|
  #|.site-header__title {
  #|  font-family: var(--font-display);
  #|  font-size: clamp(1.4rem, 1.2rem + 0.5vw, 1.8rem);
  #|  font-weight: 800;
  #|  letter-spacing: -0.02em;
  #|  color: var(--ink);
  #|  text-decoration: none;
  #|  transition: color 0.15s ease;
  #|}
  #|
  #|.site-header__title:hover {
  #|  color: var(--accent);
  #|}
  #|
  #|.site-nav {
  #|  display: flex;
  #|  gap: var(--space-lg);
  #|}
  #|
  #|.site-nav__link {
  #|  font-family: var(--font-body);
  #|  font-size: 0.92rem;
  #|  font-weight: 600;
  #|  letter-spacing: 0.03em;
  #|  text-transform: uppercase;
  #|  text-decoration: none;
  #|  color: var(--ink-secondary);
  #|  transition: color 0.15s ease;
  #|}
  #|
  #|.site-nav__link:hover {
  #|  color: var(--accent);
  #|}
  #|
  #|/* ── Site Main ── */
  #|
  #|.site-main {
  #|  width: min(calc(100% - var(--gutter) * 2), var(--max-width));
  #|  margin: 0 auto;
  #|  padding: var(--space-xl) 0 var(--space-2xl);
  #|}
  #|
  #|/* ── Prose (Article) ── */
  #|
  #|.prose {
  #|  max-width: var(--measure);
  #|}
  #|
  #|.prose__header {
  #|  margin-bottom: var(--space-xl);
  #|}
  #|
  #|.prose__title {
  #|  font-family: var(--font-display);
  #|  font-size: clamp(2rem, 1.5rem + 1.5vw, 3.2rem);
  #|  font-weight: 800;
  #|  line-height: 1.15;
  #|  letter-spacing: -0.025em;
  #|  color: var(--ink);
  #|  margin-bottom: var(--space-sm);
  #|}
  #|
  #|.prose__lede {
  #|  font-size: 1.15em;
  #|  font-style: italic;
  #|  color: var(--ink-secondary);
  #|  line-height: 1.5;
  #|  margin-top: var(--space-md);
  #|}
  #|
  #|.prose__meta {
  #|  display: flex;
  #|  flex-wrap: wrap;
  #|  gap: var(--space-sm);
  #|  align-items: center;
  #|  margin-top: var(--space-md);
  #|  font-size: 0.88rem;
  #|  color: var(--ink-muted);
  #|}
  #|
  #|.prose__meta > *:not(:last-child)::after {
  #|  content: "\00b7";
  #|  margin-left: var(--space-sm);
  #|  color: var(--border-strong);
  #|}
  #|
  #|.prose__date {
  #|  font-variant-numeric: tabular-nums;
  #|}
  #|
  #|/* ── Prose Body Typography ── */
  #|
  #|.prose__body {
  #|  margin-top: var(--space-xl);
  #|}
  #|
  #|.prose__body > * + * {
  #|  margin-top: var(--space-md);
  #|}
  #|
  #|.prose__body h2 {
  #|  font-family: var(--font-display);
  #|  font-size: 1.65em;
  #|  font-weight: 700;
  #|  line-height: 1.2;
  #|  letter-spacing: -0.02em;
  #|  margin-top: var(--space-2xl);
  #|  margin-bottom: var(--space-sm);
  #|  padding-bottom: var(--space-xs);
  #|  border-bottom: 1px solid var(--border);
  #|}
  #|
  #|.prose__body h3 {
  #|  font-family: var(--font-display);
  #|  font-size: 1.3em;
  #|  font-weight: 600;
  #|  line-height: 1.25;
  #|  margin-top: var(--space-xl);
  #|  margin-bottom: var(--space-xs);
  #|}
  #|
  #|.prose__body h4 {
  #|  font-family: var(--font-display);
  #|  font-size: 1.1em;
  #|  font-weight: 600;
  #|  line-height: 1.3;
  #|  margin-top: var(--space-lg);
  #|}
  #|
  #|.prose__body p {
  #|  max-width: var(--measure);
  #|  hanging-punctuation: first;
  #|}
  #|
  #|.prose__body strong {
  #|  font-weight: 600;
  #|  color: var(--ink);
  #|}
  #|
  #|.prose__body a {
  #|  color: var(--accent);
  #|  text-decoration-color: color-mix(in srgb, var(--accent) 40%, transparent);
  #|  text-underline-offset: 0.15em;
  #|  transition: text-decoration-color 0.15s ease;
  #|}
  #|
  #|.prose__body a:hover {
  #|  text-decoration-color: var(--accent);
  #|}
  #|
  #|.prose__body blockquote {
  #|  border-left: 3px solid var(--accent);
  #|  margin-left: 0;
  #|  padding: var(--space-sm) 0 var(--space-sm) var(--space-lg);
  #|  color: var(--ink-secondary);
  #|  font-style: italic;
  #|}
  #|
  #|.prose__body blockquote > * + * {
  #|  margin-top: var(--space-sm);
  #|}
  #|
  #|.prose__body ul,
  #|.prose__body ol {
  #|  padding-left: 1.5em;
  #|  max-width: var(--measure);
  #|}
  #|
  #|.prose__body li + li {
  #|  margin-top: var(--space-xs);
  #|}
  #|
  #|.prose__body li::marker {
  #|  color: var(--ink-muted);
  #|}
  #|
  #|.prose__body hr {
  #|  border: none;
  #|  border-top: 1px solid var(--border);
  #|  margin: var(--space-xl) 0;
  #|  max-width: 8rem;
  #|}
  #|
  #|/* ── Images ── */
  #|
  #|.prose__body img {
  #|  max-width: 100%;
  #|  height: auto;
  #|  border-radius: 0.5rem;
  #|  margin: var(--space-lg) 0;
  #|}
  #|
  #|/* ── Inline Code ── */
  #|
  #|.prose__body code {
  #|  font-family: var(--font-mono);
  #|  font-size: 0.88em;
  #|  padding: 0.15em 0.4em;
  #|  background: var(--bg-surface-dim);
  #|  border-radius: 0.25rem;
  #|}
  #|
  #|/* ── Code Blocks ── */
  #|
  #|.prose__body pre {
  #|  font-family: var(--font-mono);
  #|  font-size: 0.88rem;
  #|  line-height: 1.55;
  #|  overflow-x: auto;
  #|  padding: var(--space-lg);
  #|  background: var(--bg-code);
  #|  border: 1px solid var(--border);
  #|  border-radius: 0.75rem;
  #|  margin: var(--space-lg) 0;
  #|  -webkit-overflow-scrolling: touch;
  #|}
  #|
  #|.prose__body pre code {
  #|  padding: 0;
  #|  background: none;
  #|  border-radius: 0;
  #|  font-size: inherit;
  #|}
  #|
  #|/* Syntax highlighting tokens */
  #|.token-keyword  { color: #8b5cf6; font-weight: 500; }
  #|.token-type     { color: #0d9488; }
  #|.token-string   { color: #b45309; }
  #|.token-comment  { color: var(--ink-muted); font-style: italic; }
  #|.token-number   { color: #2563eb; }
  #|.token-operator { color: var(--ink-secondary); }
  #|.token-punct    { color: var(--ink-muted); }
  #|.token-builtin  { color: #c026d3; }
  #|.token-identifier { color: var(--ink); }
  #|
  #|@media (prefers-color-scheme: dark) {
  #|  .token-keyword  { color: #a78bfa; }
  #|  .token-type     { color: #5eead4; }
  #|  .token-string   { color: #fbbf24; }
  #|  .token-number   { color: #60a5fa; }
  #|  .token-builtin  { color: #e879f9; }
  #|}
  #|
  #|/* ── Tables ── */
  #|
  #|.prose__body table {
  #|  width: 100%;
  #|  border-collapse: collapse;
  #|  margin: var(--space-lg) 0;
  #|  font-size: 0.92em;
  #|  font-variant-numeric: tabular-nums;
  #|}
  #|
  #|.prose__body thead {
  #|  border-bottom: 2px solid var(--border-strong);
  #|}
  #|
  #|.prose__body th {
  #|  font-weight: 600;
  #|  text-align: left;
  #|  padding: var(--space-sm) var(--space-md);
  #|}
  #|
  #|.prose__body td {
  #|  padding: var(--space-sm) var(--space-md);
  #|  border-bottom: 1px solid var(--border);
  #|}
  #|
  #|/* ── Table of Contents ── */
  #|
  #|.toc {
  #|  margin: 0 0 var(--space-xl);
  #|  padding: var(--space-md) var(--space-lg);
  #|  background: var(--bg-surface-dim);
  #|  border-radius: 0.75rem;
  #|  border: 1px solid var(--border);
  #|}
  #|
  #|.toc__summary {
  #|  font-family: var(--font-display);
  #|  font-weight: 600;
  #|  font-size: 0.92rem;
  #|  letter-spacing: 0.02em;
  #|  text-transform: uppercase;
  #|  color: var(--ink-secondary);
  #|  cursor: pointer;
  #|  user-select: none;
  #|}
  #|
  #|.toc__summary::marker {
  #|  color: var(--ink-muted);
  #|}
  #|
  #|.toc .table-of-contents {
  #|  margin: var(--space-md) 0 0;
  #|  padding: 0;
  #|  list-style: none;
  #|}
  #|
  #|.toc .table-of-contents a {
  #|  color: var(--ink-secondary);
  #|  text-decoration: none;
  #|  font-size: 0.92rem;
  #|  line-height: 1.8;
  #|  transition: color 0.15s ease;
  #|}
  #|
  #|.toc .table-of-contents a:hover {
  #|  color: var(--accent);
  #|}
  #|
  #|.toc .table-of-contents ul {
  #|  list-style: none;
  #|  padding-left: 1.25em;
  #|}
  #|
  #|/* ── Footnotes ── */
  #|
  #|.footnotes {
  #|  margin-top: var(--space-2xl);
  #|  padding-top: var(--space-lg);
  #|  border-top: 1px solid var(--border);
  #|  font-size: 0.9rem;
  #|  color: var(--ink-secondary);
  #|}
  #|
  #|.footnotes ol {
  #|  padding-left: 1.5em;
  #|}
  #|
  #|.footnotes li + li {
  #|  margin-top: var(--space-sm);
  #|}
  #|
  #|.footnote-ref {
  #|  font-size: 0.8em;
  #|  vertical-align: super;
  #|  line-height: 0;
  #|}
  #|
  #|.footnote-ref a {
  #|  color: var(--accent);
  #|  text-decoration: none;
  #|  font-weight: 600;
  #|}
  #|
  #|.footnote-backref {
  #|  text-decoration: none;
  #|  margin-left: var(--space-xs);
  #|  color: var(--accent);
  #|}
  #|
  #|/* ── Task Lists ── */
  #|
  #|.prose__body .task-list {
  #|  list-style: none;
  #|  padding-left: 0;
  #|}
  #|
  #|.prose__body .task-list input[type="checkbox"] {
  #|  margin-right: var(--space-sm);
  #|  accent-color: var(--accent);
  #|}
  #|
  #|/* ── Tags ── */
  #|
  #|.tag-list {
  #|  display: flex;
  #|  flex-wrap: wrap;
  #|  gap: var(--space-sm);
  #|  margin-top: var(--space-md);
  #|}
  #|
  #|.tag-list a {
  #|  display: inline-block;
  #|  font-size: 0.82rem;
  #|  font-weight: 600;
  #|  letter-spacing: 0.02em;
  #|  text-decoration: none;
  #|  color: var(--accent);
  #|  background: var(--accent-soft);
  #|  padding: 0.25em 0.75em;
  #|  border-radius: 9999px;
  #|  transition: background 0.15s ease, color 0.15s ease;
  #|}
  #|
  #|.tag-list a:hover {
  #|  background: var(--accent);
  #|  color: var(--bg-surface);
  #|}
  #|
  #|/* ── Backlinks ── */
  #|
  #|.backlinks {
  #|  margin-top: var(--space-2xl);
  #|  padding: var(--space-lg);
  #|  background: var(--bg-surface-dim);
  #|  border-radius: 0.75rem;
  #|  border: 1px solid var(--border);
  #|}
  #|
  #|.backlinks__title {
  #|  font-family: var(--font-display);
  #|  font-size: 1rem;
  #|  font-weight: 600;
  #|  letter-spacing: 0.02em;
  #|  text-transform: uppercase;
  #|  color: var(--ink-secondary);
  #|  margin-bottom: var(--space-md);
  #|}
  #|
  #|.backlinks ul {
  #|  list-style: none;
  #|  padding: 0;
  #|}
  #|
  #|.backlinks li + li {
  #|  margin-top: var(--space-sm);
  #|}
  #|
  #|.backlinks a {
  #|  color: var(--accent);
  #|  text-decoration: none;
  #|  font-weight: 500;
  #|}
  #|
  #|.backlinks a:hover {
  #|  text-decoration: underline;
  #|  text-underline-offset: 0.15em;
  #|}
  #|
  #|/* ── Post Navigation ── */
  #|
  #|.post-nav {
  #|  display: grid;
  #|  grid-template-columns: 1fr 1fr;
  #|  gap: var(--space-md);
  #|  margin-top: var(--space-2xl);
  #|  padding-top: var(--space-xl);
  #|  border-top: 1px solid var(--border);
  #|}
  #|
  #|.post-nav__link {
  #|  display: flex;
  #|  flex-direction: column;
  #|  gap: var(--space-xs);
  #|  padding: var(--space-md) var(--space-lg);
  #|  text-decoration: none;
  #|  background: var(--bg-surface-dim);
  #|  border: 1px solid var(--border);
  #|  border-radius: 0.75rem;
  #|  transition: border-color 0.15s ease, box-shadow 0.15s ease;
  #|}
  #|
  #|.post-nav__link:hover {
  #|  border-color: var(--accent);
  #|  box-shadow: 0 2px 12px var(--shadow);
  #|}
  #|
  #|.post-nav__link--next {
  #|  text-align: right;
  #|  grid-column: 2;
  #|}
  #|
  #|.post-nav__label {
  #|  font-size: 0.78rem;
  #|  font-weight: 600;
  #|  letter-spacing: 0.05em;
  #|  text-transform: uppercase;
  #|  color: var(--ink-muted);
  #|}
  #|
  #|.post-nav__title {
  #|  font-family: var(--font-display);
  #|  font-weight: 600;
  #|  color: var(--ink);
  #|  line-height: 1.3;
  #|}
  #|
  #|/* ── Listings (Index, Tags, Archive) ── */
  #|
  #|.listing {
  #|  max-width: var(--measure);
  #|}
  #|
  #|.listing__header {
  #|  margin-bottom: var(--space-xl);
  #|}
  #|
  #|.listing__eyebrow {
  #|  font-size: 0.82rem;
  #|  font-weight: 600;
  #|  letter-spacing: 0.08em;
  #|  text-transform: uppercase;
  #|  color: var(--accent);
  #|  margin-bottom: var(--space-xs);
  #|}
  #|
  #|.listing__title {
  #|  font-family: var(--font-display);
  #|  font-size: clamp(1.8rem, 1.4rem + 1vw, 2.6rem);
  #|  font-weight: 800;
  #|  line-height: 1.15;
  #|  letter-spacing: -0.02em;
  #|}
  #|
  #|.listing__description {
  #|  margin-top: var(--space-sm);
  #|  color: var(--ink-secondary);
  #|  font-size: 1.05em;
  #|}
  #|
  #|/* Post listing items (rendered by Lattice as <ul><li><a>) */
  #|
  #|.listing__content ul {
  #|  list-style: none;
  #|  padding: 0;
  #|}
  #|
  #|.listing__content li {
  #|  padding: var(--space-md) 0;
  #|  border-bottom: 1px solid var(--border);
  #|}
  #|
  #|.listing__content li:first-child {
  #|  border-top: 1px solid var(--border);
  #|}
  #|
  #|.listing__content li a {
  #|  color: var(--ink);
  #|  text-decoration: none;
  #|  font-weight: 500;
  #|  font-size: 1.05em;
  #|  transition: color 0.15s ease;
  #|}
  #|
  #|.listing__content li a:hover {
  #|  color: var(--accent);
  #|}
  #|
  #|/* Tag cloud layout */
  #|
  #|.listing__content--tags ul {
  #|  display: flex;
  #|  flex-wrap: wrap;
  #|  gap: var(--space-sm);
  #|}
  #|
  #|.listing__content--tags li {
  #|  padding: 0;
  #|  border: none;
  #|}
  #|
  #|.listing__content--tags li:first-child {
  #|  border: none;
  #|}
  #|
  #|.listing__content--tags li a {
  #|  display: inline-block;
  #|  font-size: 0.9rem;
  #|  padding: 0.35em 0.9em;
  #|  background: var(--bg-surface-dim);
  #|  border: 1px solid var(--border);
  #|  border-radius: 9999px;
  #|  transition: background 0.15s ease, border-color 0.15s ease, color 0.15s ease;
  #|}
  #|
  #|.listing__content--tags li a:hover {
  #|  background: var(--accent-soft);
  #|  border-color: var(--accent);
  #|  color: var(--accent);
  #|}
  #|
  #|/* Archive layout */
  #|
  #|.listing__content--archive h2 {
  #|  font-family: var(--font-display);
  #|  font-size: 1.3em;
  #|  font-weight: 700;
  #|  margin-top: var(--space-xl);
  #|  margin-bottom: var(--space-sm);
  #|  color: var(--ink);
  #|}
  #|
  #|.listing__content--archive h2:first-child {
  #|  margin-top: 0;
  #|}
  #|
  #|/* ── Pagination ── */
  #|
  #|.pagination {
  #|  display: flex;
  #|  align-items: center;
  #|  justify-content: center;
  #|  gap: var(--space-lg);
  #|  margin-top: var(--space-xl);
  #|  padding-top: var(--space-lg);
  #|  border-top: 1px solid var(--border);
  #|}
  #|
  #|.pagination__link {
  #|  font-size: 0.88rem;
  #|  font-weight: 600;
  #|  color: var(--accent);
  #|  text-decoration: none;
  #|  padding: 0.5em 1em;
  #|  border: 1px solid var(--border);
  #|  border-radius: 0.5rem;
  #|  transition: background 0.15s ease, border-color 0.15s ease;
  #|}
  #|
  #|.pagination__link:hover {
  #|  background: var(--accent-soft);
  #|  border-color: var(--accent);
  #|}
  #|
  #|.pagination__info {
  #|  font-size: 0.85rem;
  #|  color: var(--ink-muted);
  #|  font-variant-numeric: tabular-nums;
  #|}
  #|
  #|/* ── Site Footer ── */
  #|
  #|.site-footer {
  #|  border-top: 1px solid var(--border);
  #|  margin-top: var(--space-2xl);
  #|}
  #|
  #|.site-footer__inner {
  #|  width: min(calc(100% - var(--gutter) * 2), var(--max-width));
  #|  margin: 0 auto;
  #|  padding: var(--space-lg) 0 var(--space-xl);
  #|}
  #|
  #|.site-footer__text {
  #|  font-size: 0.85rem;
  #|  color: var(--ink-muted);
  #|}
  #|
  #|.site-footer__text a {
  #|  color: var(--ink-secondary);
  #|  text-decoration-color: var(--border-strong);
  #|  text-underline-offset: 0.15em;
  #|  transition: color 0.15s ease;
  #|}
  #|
  #|.site-footer__text a:hover {
  #|  color: var(--accent);
  #|}
  #|
  #|/* ── Definition Lists ── */
  #|
  #|.prose__body dt {
  #|  font-weight: 600;
  #|  margin-top: var(--space-md);
  #|}
  #|
  #|.prose__body dd {
  #|  margin-left: var(--space-lg);
  #|  color: var(--ink-secondary);
  #|}
  #|
  #|/* ── Responsive ── */
  #|
  #|@media (max-width: 640px) {
  #|  .site-header__inner {
  #|    flex-direction: column;
  #|    gap: var(--space-sm);
  #|  }
  #|
  #|  .site-nav {
  #|    gap: var(--space-md);
  #|  }
  #|
  #|  .post-nav {
  #|    grid-template-columns: 1fr;
  #|  }
  #|
  #|  .post-nav__link--next {
  #|    grid-column: 1;
  #|    text-align: left;
  #|  }
  #|
  #|  .prose__body pre {
  #|    border-radius: 0;
  #|    margin-left: calc(var(--gutter) * -1);
  #|    margin-right: calc(var(--gutter) * -1);
  #|    padding-left: var(--gutter);
  #|    padding-right: var(--gutter);
  #|    border-left: none;
  #|    border-right: none;
  #|  }
  #|}
  #|
  #|/* ── Print ── */
  #|
  #|@media print {
  #|  .page-grain,
  #|  .site-nav,
  #|  .post-nav,
  #|  .pagination,
  #|  .toc {
  #|    display: none;
  #|  }
  #|
  #|  body {
  #|    background: white;
  #|    color: black;
  #|    font-size: 11pt;
  #|  }
  #|
  #|  .prose__body a {
  #|    color: inherit;
  #|    text-decoration: underline;
  #|  }
  #|
  #|  .prose__body a[href^="http"]::after {
  #|    content: " (" attr(href) ")";
  #|    font-size: 0.8em;
  #|    color: #666;
  #|  }
  #|}
  #|

///|
/// Sample welcome post
let welcome_post : String =
  #|---
  #|title: Welcome to Your New Site
  #|date: 2026-01-01
  #|description: Your first post on your new Lattice site. Edit or delete it, then build.
  #|tags:
  #|  - welcome
  #|author: Lattice
  #|---
  #|
  #|# Welcome to Your New Site
  #|
  #|Congratulations — you just scaffolded a brand-new Lattice site.
  #|
  #|## What next?
  #|
  #|- Edit this post in `content/posts/welcome.md`
  #|- Add new posts as `.md` files in `content/posts/`
  #|- Customise templates in `content/templates/`
  #|- Tweak the theme in `content/static/style.css`
  #|
  #|## Build
  #|
  #|```sh
  #|lattice build ./content
  #|```
  #|
  #|Your generated site will appear in `./dist`.
  #|

///|
/// Generate lattice.conf with inline [[collections]] for the given target directory.
/// Collection dir and template paths are relative to content-dir, matching how
/// the builder resolves them (content_dir + "/" + path when not absolute).
fn generate_lattice_conf(target_dir : String) -> String {
  let content = target_dir + "/content"
  "title = My Site\n" +
    "base_url = http://localhost:4321\n" +
    "description = A new site built with Lattice.\n" +
    "\n" +
    "[[collections]]\n" +
    "name = posts\n" +
    "dir = " + content + "/posts\n" +
    "schema = title:String,date:Date,description:Optional[String],tags:Optional[Array[String]],author:Optional[String],draft:Optional[Bool]\n" +
    "template = " + content + "/templates/page.html\n" +
    "page_size = 10\n"
}

///|
/// Default nav data
let nav_toml : String =
  #|title = "My Site"
  #|links = ["posts"]
  #|

///|
/// Get character at position as Char.
fn char_at(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

///|
/// Substring returning owned String.
fn substring(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = start
  while i < end {
    buf.write_char(char_at(s, i))
    i = i + 1
  }
  buf.to_string()
}

///|
/// Ensure a directory exists, creating parent dirs as needed.
fn ensure_dir(path : String) -> Result[Unit, String] {
  if @fs.path_exists(path) {
    return Ok(())
  }
  // Create parent dirs first
  let mut i = 0
  while i < path.length() {
    if char_at(path, i) == '/' && i > 0 {
      let dir = substring(path, 0, i)
      if not(@fs.path_exists(dir)) {
        @fs.create_dir(dir) catch {
          @fs.IOError(msg) =>
            return Err("cannot create directory '" + dir + "': " + msg)
        }
      }
    }
    i = i + 1
  }
  // Create the final directory
  if not(@fs.path_exists(path)) {
    @fs.create_dir(path) catch {
      @fs.IOError(msg) =>
        return Err("cannot create directory '" + path + "': " + msg)
    }
  }
  Ok(())
}

///|
/// Write content to a file, ensuring parent directories exist.
fn write_file(path : String, content : String) -> Result[Unit, String] {
  // Find last '/' to get parent directory
  let mut last_slash = -1
  let mut i = 0
  while i < path.length() {
    if char_at(path, i) == '/' {
      last_slash = i
    }
    i = i + 1
  }
  if last_slash > 0 {
    let parent = substring(path, 0, last_slash)
    match ensure_dir(parent) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  }
  @fs.write_string_to_file(path, content) catch {
    @fs.IOError(msg) => return Err("cannot write file '" + path + "': " + msg)
  }
  Ok(())
}

///|
/// Scaffold a complete Lattice site inside `target_dir/content/`.
///
/// Creates:
/// - content/lattice.conf
/// - content/templates/*.html (base, head, header, footer, article, page, index, tag, tags, archive)
/// - content/posts/welcome.md
/// - content/static/style.css
/// - content/data/nav.toml
pub fn scaffold_site(target_dir : String) -> Result[Unit, String] {
  let content = target_dir + "/content"
  let templates = content + "/templates"
  let posts = content + "/posts"
  let static_dir = content + "/static"
  let data_dir = content + "/data"

  // Fail fast if target already has a lattice.conf to avoid overwriting
  if @fs.path_exists(content + "/lattice.conf") {
    return Err(
      "directory '" +
      target_dir +
      "' already contains content/lattice.conf — refusing to overwrite",
    )
  }

  // Create directories
  match ensure_dir(templates) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match ensure_dir(posts) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match ensure_dir(static_dir) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match ensure_dir(data_dir) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }

  // Write templates
  match write_file(templates + "/base.html", tmpl_base) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match write_file(templates + "/head.html", tmpl_head) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match write_file(templates + "/header.html", tmpl_header) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match write_file(templates + "/footer.html", tmpl_footer) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match write_file(templates + "/article.html", tmpl_article) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match write_file(templates + "/page.html", tmpl_page) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match write_file(templates + "/index.html", tmpl_index) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match write_file(templates + "/tag.html", tmpl_tag) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match write_file(templates + "/tags.html", tmpl_tags) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match write_file(templates + "/archive.html", tmpl_archive) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }

  // Write content files
  match write_file(posts + "/welcome.md", welcome_post) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match write_file(static_dir + "/style.css", style_css) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match write_file(data_dir + "/nav.toml", nav_toml) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match write_file(content + "/lattice.conf", generate_lattice_conf(target_dir)) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }

  Ok(())
}
