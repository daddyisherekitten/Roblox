const fs = require('node:fs'), path = require('node:path');
const { openBrowser } = require('./native-browser.cjs');
const root = path.resolve(__dirname, '..'), folder = path.join(root, 'build/quirks-hover-reference');
fs.mkdirSync(folder, { recursive: true });
const selectors = [
  ':hover', '*:hover', ':active', '*:hover:active', ':hover:not(:active)',
  '[id]:hover', '#target:hover', '.qual:hover', ':empty:hover', ':is(:hover)',
  ':where(:hover)', ':not(:not(:hover))', ':has(> :hover)', ':nth-child(1 of :hover)',
  ':hover > .child', ':is(:hover) > .child', '*:active > .child',
];
const css = 'body{margin:0}#target{display:block;width:200px;height:100px}#child{display:block;width:80px;height:40px}'+
  '*::before,*::after{position:absolute;pointer-events:none}'+
  ':hover::before{content:"hover"}:active::after{content:"active"}:hover > :hover::before{content:"ancestor"}';
(async () => {
  const browser = await openBrowser(folder), cases = [];
  try {
    const userAgent = await browser.evaluate('navigator.userAgent');
    for (const [mode, doctype] of [['no-quirks','<!doctype html>'],['limited-quirks','<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">'],['quirks','']]) {
      for (const [tag, attribute, name] of [['div','','div'],['a','href="#stay"','link'],['a','','anchor without href']]) {
        const html = doctype + '<html><head><style>' + css + '</style></head><body><' + tag + ' id="target" class="qual" ' + attribute + '><span id="child" class="child">Point</span></' + tag + '></body></html>';
        await browser.load(html);
        const point = await browser.evaluate('(()=>{const r=document.getElementById("child").getBoundingClientRect();return {x:r.x+10,y:r.y+10}})()');
        await browser.send('Input.dispatchMouseEvent', { type: 'mouseMoved', ...point });
        for (const active of [false, true]) {
          if (active) await browser.send('Input.dispatchMouseEvent', { type: 'mousePressed', button: 'left', clickCount: 1, ...point });
          const probes = [...selectors, tag + ':hover'].flatMap(selector => ['target','child'].map(node => ({ selector, node })));
          const expected = await browser.evaluate('(' + function(probes) {
            return { matches: probes.map(p => ({ ...p, expected: document.getElementById(p.node).matches(p.selector) })), pseudos: ['target','child'].flatMap(node => ['before','after'].map(pseudo => ({node,pseudo,content:getComputedStyle(document.getElementById(node),'::'+pseudo).content}))) };
          } + ')(' + JSON.stringify(probes) + ')');
          if (!expected.matches.find(p => p.selector === '.qual:hover' && p.node === 'target').expected) throw new Error('Pointer left target: '+mode+' '+name);
          // Keep Chromium's raw result. WHATWG exempts every functional
          // argument, while this Chromium build still applies the restriction
          // inside the bare relative :hover compound of :has().
          for (const probe of expected.matches) {
            if (mode === 'quirks' && probe.node === 'target' && probe.selector === ':has(> :hover)' && !probe.expected) {
              probe.standardExpected = true;
              probe.divergence = 'WHATWG Quirks 4.1 exempts arguments of functional pseudo-classes, including :has().';
            }
          }
          cases.push({ name: mode + ' ' + name + (active ? ' pressed' : ' hover'), mode, html, active, ...expected });
        }
        await browser.send('Input.dispatchMouseEvent', { type: 'mouseReleased', button: 'left', clickCount: 1, ...point });
      }
    }
    const fixture = { browser: userAgent, captured: '2026-10-09', standards: ['https://quirks.spec.whatwg.org/#the-active-and-hover-quirk'], cases };
    fs.writeFileSync(path.join(root, 'tests/fixtures/quirks-hover-browser.json'), JSON.stringify(fixture, null, 2) + '\n');
    console.log('Quirks hover: ' + cases.length + ' trusted mouse sequences captured.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
