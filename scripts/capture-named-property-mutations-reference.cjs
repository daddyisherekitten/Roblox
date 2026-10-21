const fs=require('node:fs'),path=require('node:path'),{openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..');
(async()=>{const browser=await openBrowser(path.join(root,'build'));try{
  const html='<!doctype html><html><head><title>Named mutation boundaries</title></head><body></body></html>';
  const source=fs.readFileSync(path.join(root,'tests/fixtures/named-property-mutations-cases.js'),'utf8');
  const records=[];await browser.load(html);const cases=await browser.evaluate(source+'\nnamedPropertyMutationCases');
  for(const record of cases){await browser.load(html);const json=await browser.evaluate(record.source);records.push({...record,json});}
  await browser.load(html);const minimalSource=await browser.evaluate(source+'\nnamedDetachedMinimalSource');const detachedMinimal={source:minimalSource,records:await browser.evaluate(minimalSource)};
  fs.writeFileSync(path.join(root,'tests/fixtures/named-property-mutations-browser.json'),JSON.stringify({html,source,records,detachedMinimal,userAgent:await browser.evaluate('navigator.userAgent'),references:['https://html.spec.whatwg.org/multipage/dom.html#dom-document-nameditem','https://html.spec.whatwg.org/multipage/nav-history-apis.html#named-access-on-the-window-object']},null,2)+'\n');
  console.log(records.length+' native named-property mutation records');
}finally{await browser.close();}})().catch(error=>{console.error(error);process.exitCode=1;});
