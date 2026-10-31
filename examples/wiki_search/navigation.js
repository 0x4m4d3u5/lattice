// Progressive navigation for the bundled reader only. Native links remain the
// fallback for unknown pages, modified clicks, failed fetches and other shells.
export function installNavigation({ urls, enhance, readPosition }) {
  if (!document.querySelector('main[data-lattice-reader="1"]')) return;
  for (const link of document.querySelectorAll('link[rel="stylesheet"]')) link.href = link.href;
  const scripts = (doc, base) => [...doc.scripts].filter(script => script.type !== 'application/ld+json').map(script => [script.type, script.hasAttribute('src') ? new URL(script.getAttribute('src'), base).href : script.textContent]);
  const initialScripts = JSON.stringify(scripts(document, location.href));
  const key = 'latticeReader';
  let rendered = location.href;
  let pending;
  let frame;
  let sequence = 0;
  let fragmentNavigation = false;
  const positions = new Map();
  const position = () => { const point = readPosition(); return { url: location.href, x: point.left, y: point.top }; };
  const cancel = () => { const active = pending; pending = undefined; active?.abort(); };
  const remember = (persist = false) => {
    if (new URL(rendered).pathname !== location.pathname) return;
    const point = position();
    const previous = history.state?.[key];
    const known = previous?.url === point.url && typeof previous.id === 'string';
    const entry = { ...point, id: known ? previous.id : `${Date.now()}-${++sequence}` };
    positions.set(entry.id, entry);
    if (!known || persist) history.replaceState({ ...history.state, [key]: entry }, '');
  };
  const initial = history.state?.[key];
  if (initial?.url === location.href && typeof initial.id === 'string' && Number.isFinite(initial.x) && Number.isFinite(initial.y)) {
    // A recreated history document must not overwrite its saved position with
    // startup coordinates before the browser has had a chance to restore it.
    positions.set(initial.id, initial);
    window.scrollTo({ left: initial.x, top: initial.y, behavior: 'instant' });
  } else remember();
  history.scrollRestoration = 'manual';
  window.addEventListener('scroll', () => {
    cancelAnimationFrame(frame);
    frame = requestAnimationFrame(() => { if (!pending) remember(); });
  }, { passive: true });
  window.addEventListener('hashchange', () => {
    if (fragmentNavigation) { fragmentNavigation = false; return; }
    if (new URL(rendered).pathname !== location.pathname) return;
    cancel(); rendered = location.href; remember();
  });
  window.addEventListener('pagehide', () => { cancelAnimationFrame(frame); remember(true); cancel(); history.scrollRestoration = 'auto'; });
  window.addEventListener('pageshow', () => { history.scrollRestoration = 'manual'; });

  const fragment = hash => {
    if (!hash) return null;
    const raw = hash.slice(1);
    let decoded = raw;
    try { decoded = decodeURIComponent(raw); } catch { /* Literal malformed fragment. */ }
    return document.getElementById(raw) || document.getElementById(decoded) ||
      [...document.getElementsByName(decoded)].find(element => element.tagName === 'A');
  };
  async function navigate(url, restore) {
    pending?.abort();
    const controller = new AbortController(); pending = controller;
    const timeout = setTimeout(() => controller.abort(), 15000);
    const oldMain = document.querySelector('main[data-lattice-reader="1"]');
    oldMain.setAttribute('aria-busy', 'true');
    try {
      const response = await fetch(url.href, { signal: controller.signal });
      if (!response.ok || response.redirected || !response.headers.get('content-type')?.includes('text/html')) throw new Error('Not a reader page');
      const next = new DOMParser().parseFromString(await response.text(), 'text/html');
      const main = next.querySelector('main[data-lattice-reader="1"]');
      const index = next.querySelector('#lattice-search')?.dataset.index;
      const currentIndex = document.querySelector('#lattice-search').dataset.index;
      if (next.querySelector('base') || JSON.stringify(scripts(next, url)) !== initialScripts || !main || main.querySelector('script') || !index || new URL(index, url).href !== new URL(currentIndex, location.href).href) throw new Error('Different reader shell');
      const styles = doc => [...doc.querySelectorAll('link[rel="stylesheet"]')].map(link => new URL(link.getAttribute('href'), doc === document ? location.href : url).href).sort().join('\n');
      if (styles(next) !== styles(document)) throw new Error('Different reader styles');
      if (pending !== controller || controller.signal.aborted) return;
      if (!restore) {
        remember(true);
        history.pushState({ ...history.state, [key]: { url: url.href, x: 0, y: 0 } }, '', url.href);
      }
      oldMain.replaceWith(document.importNode(main, true));
      document.title = next.title;
      const metadata = 'link[rel="canonical"], meta[name="description"], meta[property^="og:"], meta[name^="twitter:"], script[type="application/ld+json"]';
      for (const element of document.head.querySelectorAll(metadata)) element.remove();
      for (const element of next.head.querySelectorAll(metadata)) document.head.append(document.importNode(element, true));
      rendered = url.href;
      enhance();
      const current = document.querySelector('main[data-lattice-reader="1"]');
      current.focus({ preventScroll: true });
      if (url.hash) {
        // pushState alone does not update the native :target or fragment focus.
        // Replace this entry's fragment through native navigation, preserving
        // both its history state and the single entry created for this visit.
        const state = history.state;
        const bare = new URL(url); bare.hash = '';
        fragmentNavigation = true;
        history.replaceState(state, '', bare.href);
        location.replace(url.href);
        history.replaceState(state, '', url.href);
      }
      if (restore) window.scrollTo({ left: restore.x, top: restore.y, behavior: 'instant' });
      else if (!url.hash) window.scrollTo({ left: 0, top: 0, behavior: 'instant' });
      pending = undefined;
      remember();
    } catch {
      if (pending !== controller) return;
      // A failed enhancement must never strand a working published link.
      if (restore) location.replace(url.href); else location.assign(url.href);
    } finally {
      clearTimeout(timeout);
      if (!pending || pending === controller) oldMain.removeAttribute('aria-busy');
      if (pending === controller) pending = undefined;
    }
  }
  document.addEventListener('click', event => {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    const link = event.target.closest('a[href]');
    if (!link || link.target || link.hasAttribute('download')) return;
    // During a history fetch the address bar can precede the rendered article.
    const url = new URL(link.getAttribute('href'), link.closest('main') ? rendered : document.baseURI);
    if (url.origin !== location.origin || url.username || url.password || url.search || !urls().has(url.origin + url.pathname)) return;
    if (url.pathname === location.pathname && url.pathname === new URL(rendered).pathname) { cancel(); return; }
    event.preventDefault();
    navigate(url);
  });
  window.addEventListener('popstate', event => {
    if (fragmentNavigation) return;
    const url = new URL(location.href);
    if (url.pathname === new URL(rendered).pathname) {
      cancel();
      rendered = url.href;
      const stored = event.state?.[key];
      const saved = positions.get(stored?.id) || stored;
      if (saved?.url === url.href) window.scrollTo({ left: saved.x, top: saved.y, behavior: 'instant' });
      else fragment(url.hash)?.scrollIntoView();
      return;
    }
    const stored = event.state?.[key];
    const saved = positions.get(stored?.id) || stored;
    if (!urls().has(url.origin + url.pathname) || saved?.url !== url.href) { location.reload(); return; }
    navigate(url, saved);
  });
}
