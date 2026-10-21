// Native CSS Text reference, isolated from the user's browser and page.
const fs = require('node:fs'), path = require('node:path');
const { openBrowser } = require('./native-browser.cjs');
const root = path.resolve(__dirname, '..');
async function capture() {
  const browser = await openBrowser(path.join(root, 'build', 'hyphenation-reference'));
  try {
    await browser.load('<!doctype html><meta charset="utf-8"><div id="sample"></div>');
    const value = await browser.evaluate(`(() => {
      const sample = document.getElementById('sample');
      const records = [];
      const words = ['hy\\u00adphen\\u00adation', 'representation', 'hyphenation', 'Silbentrennung', 'Gestaltungsidee'];
      for (const word of words) for (const hyphens of ['none', 'manual', 'auto']) for (const columns of [3,4,5,6,8,20]) {
        sample.lang = word.startsWith('Sil') || word.startsWith('Ges') ? 'de' : 'en-US';
        sample.style.cssText = 'font:10px/20px monospace;hyphens:' + hyphens;
        sample.textContent = 'X';
        const range = document.createRange(); range.selectNodeContents(sample);
        const advance = range.getBoundingClientRect().width;
        sample.style.width = (advance * columns + .01) + 'px';
        sample.textContent = word;
        const lines = [];
        for (let i=0; i<word.length; i++) {
          range.setStart(sample.firstChild,i);range.setEnd(sample.firstChild,i+1);
          const rect = Array.from(range.getClientRects()).filter(rect => rect.width > 0).at(-1) || range.getBoundingClientRect();
          const line = Math.round((rect.top-sample.getBoundingClientRect().top)/20);
          if (word[i] !== '\\u00ad') (lines[line] ||= []).push(i);
        }
        const selection = window.getSelection(); selection.removeAllRanges();
        range.selectNodeContents(sample); selection.addRange(range);
        records.push({word,hyphens,language:sample.lang,columns,advance,lines:lines.filter(Boolean),copied:selection.toString()});
      }
      const strings = ['', '~', '~~'];
      const copied = strings.map(hyphen => {
        sample.lang='en';sample.style.cssText='font:10px/20px monospace;width:25px;hyphens:manual;hyphenate-character:' + JSON.stringify(hyphen);
        sample.textContent='ab\\u00adcde';
        const range=document.createRange();range.selectNodeContents(sample);
        const selection=window.getSelection();selection.removeAllRanges();selection.addRange(range);
        return {hyphen,copied:selection.toString(),innerText:sample.innerText};
      });
      const limits = ['auto','0','0 0 0','100','auto 3','3 auto 2'];
      const limitResults = limits.map(limit => {
        sample.lang='en';sample.style.cssText='font:10px/20px monospace;width:20px;hyphens:manual;hyphenate-limit-chars:'+limit;
        sample.textContent='ab\\u00adcde';
        const range=document.createRange();range.setStart(sample.firstChild,3);range.setEnd(sample.firstChild,4);
        return {limit,supported:CSS.supports('hyphenate-limit-chars',limit),specified:sample.style.hyphenateLimitChars,top:range.getClientRects()[range.getClientRects().length-1].top-sample.getBoundingClientRect().top};
      });
      return {records,copied,limitResults};
    })()`);
    const target = path.join(root, 'tests', 'fixtures', 'hyphenation-browser.json');
    fs.writeFileSync(target, JSON.stringify(value, null, 2) + '\n');
    console.log('Hyphenation native reference:', value.records.length, 'layouts,', value.copied.length, 'custom strings');
  } finally { await browser.close(); }
}
capture().catch(error => { console.error(error); process.exitCode = 1; });
