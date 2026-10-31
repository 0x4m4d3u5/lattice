import assert from 'node:assert/strict';

// Check resolved, visible styles rather than token names or a screenshot hash.
export async function checkReaderStyle(page) {
  const samples = await page.evaluate(() => {
    const background = element => {
      for (let node = element; node; node = node.parentElement) {
        const value = getComputedStyle(node).backgroundColor;
        if (value !== 'rgba(0, 0, 0, 0)' && value !== 'transparent') return value;
      }
      return 'rgb(255, 255, 255)';
    };
    const selectors = ['.brand', '.edition', '.eyebrow', '.lede', '.intro', '.document-bar', '.collection-heading span', '.collection p', '.collection a', '#lattice-catalogue-status', '#lattice-status', '#lattice-page-navigation a', '#lattice-navigation summary', '#lattice-navigation label', '#lattice-navigation legend', '#lattice-navigation button:not([hidden])', '#lattice-results a', '.section', '.snippet', '.citation', 'article p', 'article a', '.contents summary'];
    return selectors.flatMap(selector => [...document.querySelectorAll(selector)]
      .filter(element => element.checkVisibility() && !element.matches(':disabled'))
      .map(element => {
        const style = getComputedStyle(element);
        return { selector, color: style.color, background: background(element), size: parseFloat(style.fontSize) };
      }));
  });
  const luminance = color => color.match(/[\d.]+/g).slice(0, 3).map(Number)
    .map(value => value / 255).map(value => value <= .04045 ? value / 12.92 : ((value + .055) / 1.055) ** 2.4)
    .reduce((sum, value, index) => sum + value * [.2126, .7152, .0722][index], 0);
  const contrast = (a, b) => {
    const values = [luminance(a), luminance(b)].sort((a, b) => b - a);
    return (values[0] + .05) / (values[1] + .05);
  };
  const focus = await page.locator(':is(a, button, input, summary):focus-visible').evaluateAll(elements => elements.map(element => {
    const style = getComputedStyle(element);
    let parent = element.parentElement;
    while (parent && getComputedStyle(parent).backgroundColor === 'rgba(0, 0, 0, 0)') parent = parent.parentElement;
    return { color: style.outlineColor, width: parseFloat(style.outlineWidth), background: parent ? getComputedStyle(parent).backgroundColor : 'rgb(255, 255, 255)' };
  }));
  for (const ring of focus) {
    assert.ok(ring.width >= 2 && contrast(ring.color, ring.background) >= 3, 'Keyboard focus must remain visible against its surrounding surface');
  }
  for (const sample of samples) {
    assert.ok(sample.size >= 12, `${sample.selector}: text below 12px (${sample.size})`);
    assert.ok(contrast(sample.color, sample.background) >= 4.5, `${sample.selector}: insufficient text contrast`);
  }
  if (await page.locator('article').isVisible()) {
    assert.ok(await page.locator('article').evaluate(article => parseFloat(getComputedStyle(article).fontSize)) >= 18);
  }
  if (await page.getByRole('searchbox').isVisible()) {
    const input = await page.getByRole('searchbox').evaluate(element => {
      const style = getComputedStyle(element);
      return { border: style.borderColor, background: style.backgroundColor, placeholder: getComputedStyle(element, '::placeholder').color };
    });
    assert.ok(contrast(input.border, input.background) >= 3, 'Search field boundary needs contrast');
    assert.ok(contrast(input.placeholder, input.background) >= 4.5, 'Search placeholder needs text contrast');
  }
  if (await page.locator('#lattice-navigation-toggle').isVisible()) {
    const brand = await page.locator('.brand').boundingBox();
    const toggle = await page.locator('#lattice-navigation-toggle').boundingBox();
    assert.ok(brand.x + brand.width + 8 <= toggle.x || brand.y + brand.height + 8 <= toggle.y, 'Mobile brand and menu control need separation');
  }
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true, 'Page must reflow without horizontal scrolling');
}
