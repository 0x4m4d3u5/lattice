import { installNavigation } from './navigation.js';
import { buildCatalogue } from './catalogue.js';

const form = document.querySelector('#lattice-search');
const controls = document.querySelector('#lattice-controls');
const query = document.querySelector('#lattice-query');
const tags = document.querySelector('#lattice-tags');
const filters = document.querySelector('#lattice-filters');
const clearTags = document.querySelector('#lattice-clear-tags');
const status = document.querySelector('#lattice-status');
const results = document.querySelector('#lattice-results');
// Create the enhancement here so asset upgrades also work with older templates.
const moreResults = document.createElement('button');
moreResults.id = 'lattice-more-results';
moreResults.type = 'button';
moreResults.textContent = 'Show more results';
moreResults.setAttribute('aria-controls', 'lattice-results');
moreResults.hidden = true;
results.after(moreResults);
const retry = document.querySelector('#lattice-retry');
const navigation = document.querySelector('#lattice-navigation');
const toggle = document.querySelector('#lattice-navigation-toggle');
const catalogueStatus = () => document.querySelector('#lattice-catalogue-status');
const overview = document.querySelector('.overview-link');
// Keep shell-relative URLs stable when the reading pane changes location.
for (const link of document.querySelectorAll('.masthead a[href], .overview-link')) link.href = link.href;
form.dataset.index = new URL(form.dataset.index, document.baseURI).href;
const stateKey = `lattice-reader:${new URL(form.dataset.index, document.baseURI).href}`;
let saved = {};
try { saved = JSON.parse(sessionStorage.getItem(stateKey)) || {}; } catch { /* Storage is optional. */ }
query.value = typeof saved.query === 'string' ? saved.query : '';
let groupState = saved.groups && typeof saved.groups === 'object' ? saved.groups : {};
let catalogueLoaded = false;
let catalogueEntries = [];
filters.open = saved.filtersOpen === true;

// Match the worker and retrieval core's ASCII-only tag identity.
const tagKey = tag => tag.replace(/[A-Z]/g, letter => letter.toLowerCase());

function updateFilters() {
  const count = tags.querySelectorAll('input:checked').length;
  filters.querySelector('summary').textContent = count ? `Filter by tags (${count} selected)` : 'Filter by tags';
  clearTags.hidden = count === 0;
}

function persist() {
  const selected = controls.disabled && !tags.children.length && Array.isArray(saved.tags)
    ? saved.tags : [...tags.querySelectorAll('input:checked')].map(input => input.value);
  try { sessionStorage.setItem(stateKey, JSON.stringify({ query: query.value, tags: selected, groups: groupState, filtersOpen: filters.open })); } catch { /* Private/restricted storage must not break reading. */ }
}
let readingPosition;
function setNavigation(open, restorePosition = true) {
  if (open && !document.body.classList.contains('navigation-open')) {
    readingPosition = { left: scrollX, top: scrollY };
  }
  document.body.classList.toggle('navigation-open', open);
  toggle.setAttribute('aria-expanded', String(open));
  if (!open) {
    // Hiding the article and focusing the menu can move the document scroll.
    if (restorePosition && readingPosition) window.scrollTo({ ...readingPosition, behavior: 'instant' });
    readingPosition = undefined;
  }
}
document.body.classList.add('js');
toggle.hidden = false;
toggle.addEventListener('click', () => {
  syncNavigationLayout();
  const open = toggle.getAttribute('aria-expanded') !== 'true';
  setNavigation(open);
  if (open) overview.focus();
});
navigation.addEventListener('keydown', event => {
  if (event.key === 'Escape' && toggle.getAttribute('aria-expanded') === 'true') {
    setNavigation(false); toggle.focus({ preventScroll: true });
  }
});
navigation.addEventListener('click', event => {
  if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
  const link = event.target.closest('a[href]');
  if (!link || link.target || link.hasAttribute('download')) return;
  const target = new URL(link.href);
  if (target.origin === location.origin && target.pathname === location.pathname && target.search === location.search && target.hash) {
    // Native same-document navigation does not reload the page/reset the menu.
    // Reveal the article before the browser scrolls to its published target.
    setNavigation(false, false);
  }
});
document.querySelector('.skip').addEventListener('click', () => setNavigation(false, false));
const mobileLayout = window.matchMedia('(max-width: 800px)');
let currentMobileLayout = mobileLayout.matches;
function keepNavigationFocusVisible(focused) {
  if (mobileLayout.matches && navigation.contains(focused)) toggle.focus({ preventScroll: true });
  else if (!mobileLayout.matches && focused === toggle) overview.focus({ preventScroll: true });
}
// Browsers may blur a newly hidden control before dispatching the media change.
for (const region of [navigation, toggle]) region.addEventListener('focusout', event => {
  if (!event.relatedTarget && !region.getClientRects().length) {
    syncNavigationLayout();
    keepNavigationFocusVisible(event.target);
  }
});
function syncNavigationLayout() {
  // Focus recovery or activation may precede a queued media-change event.
  if (currentMobileLayout === mobileLayout.matches) return;
  currentMobileLayout = mobileLayout.matches;
  const focused = document.activeElement;
  // A changed layout invalidates the mobile menu's saved scroll position.
  setNavigation(false, false);
  keepNavigationFocusVisible(focused);
}
mobileLayout.addEventListener('change', syncNavigationLayout);
if (new URL(overview.href).pathname === location.pathname) overview.setAttribute('aria-current', 'page');

function addSectionLinks() {
  // Link to published DOM targets, never a second heading-slug algorithm.
  // Count all IDs: a template or raw HTML element can own the same target.
  const counts = new Map();
  for (const element of document.querySelectorAll('[id]')) {
    counts.set(element.id, (counts.get(element.id) || 0) + 1);
  }
  const namedTargets = new Set([...document.querySelectorAll('a[name]')].map(anchor => anchor.getAttribute('name')));
  for (const heading of document.querySelectorAll('article h2[id], article h3[id], article h4[id], article h5[id], article h6[id]')) {
    const id = heading.id;
    const label = heading.textContent.trim();
    if (!id.trim() || !label || counts.get(id) !== 1 || heading.closest('a')) continue;
    const fragment = encodeURIComponent(id);
    // Native navigation tries the literal fragment before percent-decoding it.
    if (fragment !== id && (counts.has(fragment) || namedTargets.has(fragment))) continue;
    const hasSelfLink = [...heading.querySelectorAll('a[href]')].some(link => {
      try {
        const url = new URL(link.getAttribute('href'), document.baseURI);
        return url.origin === location.origin && url.pathname === location.pathname &&
          url.search === location.search && (url.hash.slice(1) === id || decodeURIComponent(url.hash.slice(1)) === id);
      } catch { return false; }
    });
    if (hasSelfLink) continue;
    const link = document.createElement('a');
    link.className = 'section-permalink';
    link.setAttribute('href', `#${fragment}`);
    link.setAttribute('aria-label', `Link to section: ${label}`);
    link.title = `Link to section: ${label}`;
    link.textContent = '#';
    heading.append(document.createTextNode(' '), link);
  }
}
function addCodeCopyControls() {
  // Native clipboard writes require an explicit reader action. Unsupported
  // browsers keep the original code and their normal text-selection behavior.
  if (typeof navigator.clipboard?.writeText !== 'function') return;
  for (const code of document.querySelectorAll('article pre > code')) {
    const pre = code.parentElement;
    if (pre.closest('a, button') || pre.querySelectorAll(':scope > code').length !== 1) continue;
    const toolbar = document.createElement('div');
    toolbar.className = 'code-copy-controls';
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = 'Copy code';
    const feedback = document.createElement('span');
    feedback.className = 'code-copy-status';
    feedback.setAttribute('role', 'status');
    feedback.setAttribute('aria-live', 'polite');
    let pending = false;
    button.addEventListener('click', async () => {
      if (pending) return;
      pending = true;
      // aria-disabled keeps keyboard focus on the control during the write.
      button.setAttribute('aria-disabled', 'true');
      feedback.textContent = 'Copying code…';
      try {
        await navigator.clipboard.writeText(code.textContent);
        feedback.textContent = 'Code copied.';
      } catch {
        feedback.textContent = 'Could not copy. Select the code and copy it manually.';
      } finally {
        pending = false;
        button.removeAttribute('aria-disabled');
      }
    });
    toolbar.append(button, feedback);
    // Keep the code DOM and its selectable text unchanged, including whitespace.
    pre.before(toolbar);
  }
}
// Reading enhancements do not depend on the index or search runtime.
addSectionLinks();
addCodeCopyControls();

function renderCatalogue(entries) {
  catalogueEntries = entries;
  const navigationScroll = navigation.scrollTop;
  const pages = buildCatalogue(entries, document.baseURI, overview.href);
  const groups = new Map();
  for (const page of pages) {
    if (!groups.has(page.collection)) groups.set(page.collection, []);
    groups.get(page.collection).push(page);
  }
  catalogueLoaded = true;
  const directory = document.querySelector('#lattice-page-navigation');
  const collections = document.querySelector('#lattice-collections');
  directory.replaceChildren();
  collections?.replaceChildren();
  for (const [name, pages] of groups) {
    const detail = document.createElement('details');
    detail.open = groupState[name] !== false;
    if (pages.some(page => new URL(page.url).pathname === location.pathname)) detail.open = true;
    const summary = document.createElement('summary');
    summary.textContent = `${name} · ${pages.length}`;
    detail.append(summary);
    const list = document.createElement('ul');
    const section = document.createElement('section');
    section.className = 'collection';
    const heading = document.createElement('div');
    heading.className = 'collection-heading';
    const title = document.createElement('h2'); title.textContent = name;
    const count = document.createElement('span'); count.textContent = `${pages.length} ${pages.length === 1 ? 'note' : 'notes'}`;
    heading.append(title, count); section.append(heading);
    const cards = document.createElement('ul');
    for (const page of pages) {
      const link = document.createElement('a'); link.href = page.url; link.textContent = page.title;
      const item = document.createElement('li'); item.append(link); list.append(item);
      if (new URL(page.url).pathname === location.pathname) {
        link.setAttribute('aria-current', 'page');
        const label = document.querySelector('#lattice-current-collection'); if (label) label.textContent = name;
      }
      const card = document.createElement('li'); card.append(link.cloneNode(true));
      if (page.description) { const text = document.createElement('p'); text.textContent = page.description; card.append(text); }
      cards.append(card);
    }
    detail.append(list); directory.append(detail);
    detail.addEventListener('toggle', () => { groupState[name] = detail.open; persist(); });
    section.append(cards); collections?.append(section);
  }
  navigation.scrollTop = navigationScroll;
  if (catalogueStatus()) catalogueStatus().textContent = pages.length ? `${pages.length} published notes · ${groups.size} ${groups.size === 1 ? 'collection' : 'collections'}` : 'No readable pages are listed in this wiki yet.';
}

let activeWorker;
let request = 0;
let timer;
let feedbackTimer;
function setStatus(text) {
  clearTimeout(feedbackTimer);
  status.textContent = text;
}
function pendingStatus(text) {
  // Reserve the region, but avoid announcing/painting a brief intermediate state.
  setStatus('');
  feedbackTimer = setTimeout(() => { status.textContent = text; }, 500);
}
let matchingHits = [];
let shownHits = 0;

function clearResults() {
  matchingHits = [];
  shownHits = 0;
  results.replaceChildren();
  moreResults.hidden = true;
}

function stop() {
  clearTimeout(timer);
  clearTimeout(feedbackTimer);
  activeWorker?.terminate();
  activeWorker = undefined;
}

function fail() {
  stop();
  controls.disabled = true;
  clearResults();
  results.setAttribute('aria-busy', 'false');
  setStatus('Search is unavailable. Retry loading search.');
  if (catalogueStatus() && !catalogueLoaded) catalogueStatus().textContent = 'The page directory is unavailable. Retry loading the wiki using the navigation panel.';
  retry.hidden = false;
  retry.removeAttribute('aria-disabled');
}

function send(type, payload) {
  clearTimeout(timer);
  const id = ++request;
  results.setAttribute('aria-busy', 'true');
  timer = setTimeout(fail, 30_000);
  try { activeWorker.postMessage({ id, type, ...payload }); }
  catch { fail(); }
}

function renderHits(hits) {
  clearResults();
  matchingHits = hits;
  appendHits();
}

function appendHits(focusNew = false) {
  const firstNew = shownHits;
  const end = Math.min(shownHits + 10, matchingHits.length);
  for (const hit of matchingHits.slice(shownHits, end)) {
    const item = document.createElement('li');
    const heading = document.createElement('h2');
    const title = document.createElement('a');
    // The retrieval core copies caller-supplied URLs. Only web URLs navigate.
    try {
      const url = new URL(hit.url, document.baseURI);
      if (url.protocol === 'https:' || url.protocol === 'http:') {
        title.setAttribute('href', hit.url);
        if (typeof hit.fragment === 'string' && hit.fragment && !url.hash) {
          // Only publisher-supplied targets are used; never slug section labels.
          title.setAttribute('href', `${hit.url}#${encodeURIComponent(hit.fragment)}`);
        }
      }
    } catch { /* Invalid citations remain text, without disabling other hits. */ }
    title.textContent = hit.title;
    heading.append(title);
    item.append(heading);
    for (const [name, text] of [
      ['section', hit.section || 'Introduction'],
      ['snippet', hit.snippet],
      ['citation', hit.url],
    ]) {
      const paragraph = document.createElement('p');
      paragraph.className = name;
      paragraph.textContent = text;
      item.append(paragraph);
    }
    results.append(item);
  }
  shownHits = end;
  moreResults.hidden = shownHits >= matchingHits.length;
  setStatus(!matchingHits.length ? 'No matching sections.'
    : matchingHits.length === 50 ? `Showing ${shownHits} of the first 50 matching sections. Refine your query or tags to narrow the search.`
    : `Showing ${shownHits} of ${matchingHits.length} matching sections.`);
  if (focusNew && shownHits > firstNew) {
    const item = results.children[firstNew];
    const target = item.querySelector('a[href]') || item;
    if (target === item) item.tabIndex = -1;
    target.focus();
  }
}

function start() {
  stop();
  // Keep an activated retry focusable while loading; native disabled would blur it.
  retry.setAttribute('aria-disabled', 'true');
  controls.disabled = true;
  clearResults();
  pendingStatus('Loading search…');
  try {
    const worker = new Worker(new URL('./worker.js', import.meta.url), { type: 'module' });
    activeWorker = worker;
    for (const type of ['error', 'messageerror']) {
      worker.addEventListener(type, event => {
        event.preventDefault();
        if (worker === activeWorker) fail();
      });
    }
    worker.addEventListener('message', ({ data }) => {
      if (worker !== activeWorker || data.id !== request) return;
      if (data.type === 'catalogue') { renderCatalogue(data.entries); return; }
      clearTimeout(timer);
      results.setAttribute('aria-busy', 'false');
      try {
        if (data.type === 'ready') {
          const selectedValues = tags.children.length ? [...tags.querySelectorAll('input:checked')].map(input => input.value) : Array.isArray(saved.tags) ? saved.tags : [];
          const selected = new Set(selectedValues.filter(tag => typeof tag === 'string').map(tagKey));
          tags.replaceChildren();
          for (const tag of data.tags) {
            const label = document.createElement('label');
            const input = document.createElement('input');
            input.type = 'checkbox';
            input.value = tag;
            input.checked = selected.has(tagKey(tag));
            label.append(input, document.createTextNode(` ${tag}`));
            tags.append(label);
          }
          filters.hidden = !data.tags.length;
          updateFilters();
          controls.disabled = false;
          if (document.activeElement === retry) query.focus({ preventScroll: true });
          retry.hidden = true;
          retry.removeAttribute('aria-disabled');
          if (query.value.trim()) form.requestSubmit();
          else setStatus('Enter a query to search this wiki.');
        } else if (data.type === 'results') {
          renderHits(data.results);
        } else {
          fail();
        }
      } catch { fail(); }
    });
    send('load', { indexUrl: new URL(form.dataset.index, document.baseURI).href });
  } catch { fail(); }
}

form.addEventListener('submit', event => {
  event.preventDefault();
  if (controls.disabled) return;
  clearResults();
  if (!query.value.trim()) {
    ++request; // Clearing invalidates any pending result, too.
    clearTimeout(timer);
    results.setAttribute('aria-busy', 'false');
    setStatus('Enter a query to search this wiki.');
    return;
  }
  persist();
  pendingStatus('Searching…');
  send('search', { query: query.value, tags: [...tags.querySelectorAll('input:checked')].map(input => input.value) });
});
moreResults.addEventListener('click', () => appendHits(true));
retry.addEventListener('click', () => {
  if (retry.getAttribute('aria-disabled') !== 'true') start();
});
filters.addEventListener('toggle', persist);
tags.addEventListener('change', () => { updateFilters(); persist(); });
clearTags.addEventListener('click', () => {
  for (const input of tags.querySelectorAll('input:checked')) input.checked = false;
  updateFilters();
  persist();
  query.focus();
  form.requestSubmit();
});
window.addEventListener('pagehide', () => { persist(); stop(); });
window.addEventListener('pageshow', event => { if (event.persisted) start(); });
start();

installNavigation({
  readPosition: () => readingPosition || { left: scrollX, top: scrollY },
  urls: () => new Set([new URL(overview.href).href, ...buildCatalogue(catalogueEntries, document.baseURI, overview.href).map(page => page.url)]),
  enhance: () => {
    setNavigation(false, false);
    overview.toggleAttribute('aria-current', new URL(overview.href).pathname === location.pathname);
    if (overview.hasAttribute('aria-current')) overview.setAttribute('aria-current', 'page');
    renderCatalogue(catalogueEntries);
    addSectionLinks(); addCodeCopyControls();
  },
});
