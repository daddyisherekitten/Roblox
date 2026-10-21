const fs = require('node:fs'), path = require('node:path');
const {openBrowser} = require('./native-browser.cjs');
const root = path.resolve(__dirname, '..');
(async () => {
  const browser = await openBrowser(path.join(root, 'build'));
  try {
    await browser.load('<!doctype html><title>Template reference</title><body></body>');
    const source = fs.readFileSync(path.join(root, 'tests/fixtures/template-document-cases.js'), 'utf8');
    const records = await browser.evaluate(source + '\ntemplateDocumentChecks()');
    for (const record of records) record.json = JSON.stringify(record.value);
    const userAgent = await browser.evaluate('navigator.userAgent');
    fs.writeFileSync(path.join(root, 'tests/fixtures/template-document-browser.json'), JSON.stringify({
      source, records, userAgent,
      references: ['https://html.spec.whatwg.org/multipage/scripting.html#the-template-element',
        'https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-element-innerhtml',
        'https://dom.spec.whatwg.org/#concept-node-adopt'],
    }, null, 2) + '\n');
    console.log(records.length + ' native template ownership/namespace/clone/adoption/fragment/descriptor references');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
