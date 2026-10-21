// Native at-keyword/URL/import grammar, captured without using the user's tab.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),file=path.join(root,'tests/fixtures/css-preludes-browser.json');
const inputs=[
 ['escaped grouping',String.raw`@\6d edia (min-width:1px){#probe{color:rgb(1,2,3)}} @\73 upports (display:block){#probe{height:27px}}`],
 ['comment boundary',String.raw`@media/**/(min-width:1px){#probe{color:rgb(4,5,6)}} @mediafoo (min-width:1px){#probe{height:99px}}`],
 ['Unicode layer',String.raw`@\6c ayer café, \62 ase; @layer café{#probe{color:red}} @layer base{#probe{color:blue}}`],
 ['escaped layer delimiter',String.raw`@layer a\.b, a.b; @layer a\.b{#probe{color:red}} @layer a.b{#probe{color:blue}}`],
 ['escaped namespace',String.raw`@\6e amespace s\76 g u\72 l("http://www.w3.org/2000/svg"); @namespace "https://example.test/\66 oo"; svg|text{color:red}`],
 ['plain import','@import "data:text/css,%23probe%7Bcolor:red%7D";'],
 ['escaped import',String.raw`@\69 mport u\72 l("data:text/css,%23probe%7Bcolor:red%7D") l\61 yer(café) s\75 pports(display: block) screen;`],
 ['anonymous layer import','@import "data:text/css,%23probe%7Bcolor:red%7D" layer supports(display: block) screen;'],
 ['continued string',String.raw`@import "data:text/css,%23probe%7Bcolor:\
red%7D";`],
 ['invalid empty layer','@import "data:text/css,a" layer(); #probe{color:blue}'],
 ['invalid newline string','@import "data:text/css,a\nb"; #probe{color:blue}'],
 ['layer statement before import','@layer base; @import "data:text/css,%23probe%7Bcolor:red%7D" layer(base);'],
 ['misplaced import','@namespace "http://www.w3.org/1999/xhtml"; @import "data:text/css,a"; #probe{color:blue}'],
 ['unknown before import','@unknown; @import "data:text/css,%23probe%7Bcolor:red%7D";'],
 ['unknown block before import','@unknown {p{color:blue}} @import "data:text/css,%23probe%7Bcolor:red%7D";'],
 ['invalid selector before import','. {color:blue} @import "data:text/css,%23probe%7Bcolor:red%7D";'],
 ['invalid layer before import','@layer a b {p{color:blue}} @import "data:text/css,%23probe%7Bcolor:red%7D";'],
 ['invalid supports before import','@supports nonsense {p{color:blue}} @import "data:text/css,%23probe%7Bcolor:red%7D";'],
 ['empty import','@import ; #probe{color:blue}'],
];
const mutations=[
 ['index before syntax','',"try{s.insertRule('nonsense',1)}catch(e){record(e.name)}"],
 ['constructed import index','',"try{new CSSStyleSheet().insertRule('@import \"a.css\";',1)}catch(e){record(e.name)}"],
 ['import after style','p{}',"try{s.insertRule('@import \"a.css\";',1)}catch(e){record(e.name)}"],
 ['style before import','@import "a.css";',"try{s.insertRule('p{}',0)}catch(e){record(e.name)}"],
 ['import before layer statement','@layer first;',"record(s.insertRule('@import \"a.css\";',0))"],
 ['import after layer statement','@layer first;',"record(s.insertRule('@import \"a.css\";',1))"],
 ['layer statement before import','@import "a.css";',"record(s.insertRule('@layer first;',0))"],
 ['layer block before import','@import "a.css";',"try{s.insertRule('@layer first{}',0)}catch(e){record(e.name)}"],
 ['import after namespace','@namespace svg "http://www.w3.org/2000/svg";',"try{s.insertRule('@import \"a.css\";',1)}catch(e){record(e.name)}"],
 ['namespace before import','@import "a.css";',"try{s.insertRule('@namespace svg \"http://www.w3.org/2000/svg\";',0)}catch(e){record(e.name)}"],
 ['namespace after import','@import "a.css";',"record(s.insertRule('@namespace svg \"http://www.w3.org/2000/svg\";',1))"],
 ['namespace before style','p{}',"try{s.insertRule('@namespace svg \"http://www.w3.org/2000/svg\";',0)}catch(e){record(e.name)}"],
 ['namespace after style','p{}',"try{s.insertRule('@namespace svg \"http://www.w3.org/2000/svg\";',1)}catch(e){record(e.name)}"],
 ['style before namespace','@namespace svg "http://www.w3.org/2000/svg";',"try{s.insertRule('p{}',0)}catch(e){record(e.name)}"],
 ['delete namespace with style','@namespace svg "http://www.w3.org/2000/svg"; svg|text{}',"try{s.deleteRule(0);record('deleted')}catch(e){record(e.name)}"],
 ['delete namespace alone','@namespace svg "http://www.w3.org/2000/svg";',"const r=s.cssRules[0];s.deleteRule(0);record(r.parentStyleSheet===null)"],
 ['insert selector with namespace','@namespace svg "http://www.w3.org/2000/svg";',"s.insertRule('svg|text{}',1);record(s.cssRules[1].selectorText)"],
 ['selector setter with namespace','@namespace svg "http://www.w3.org/2000/svg"; svg|text{}',"s.cssRules[1].selectorText='svg|rect';record(s.cssRules[1].selectorText);s.cssRules[1].selectorText='bad|circle';record(s.cssRules[1].selectorText)"],
 ['namespace inherited in grouping','@namespace svg "http://www.w3.org/2000/svg"; @media all{}',"s.cssRules[1].insertRule('svg|text{}',0);record(s.cssRules[1].cssRules[0].selectorText)"],
 ['bad namespace rejected','@namespace svg "http://www.w3.org/2000/svg";',"try{s.insertRule('bad|text{}',1)}catch(e){record(e.name)}"],
 ['nested import rejected','@media all{}',"try{s.cssRules[0].insertRule('@import \"a.css\";',0)}catch(e){record(e.name)}"],
 ['layer before namespace','@namespace svg "http://www.w3.org/2000/svg";',"try{record(s.insertRule('@layer first;',0))}catch(e){record(e.name)}"],
 ['namespace beside layer','@layer first;',"try{record(s.insertRule('@namespace svg \"http://www.w3.org/2000/svg\";',1))}catch(e){record(e.name)}"],
];
const snapshot=String.raw`function snapshot(){function rule(r){let v={type:r.type};for(let k of ['name','layerName','supportsText','href','namespaceURI','prefix'])if(k in r)v[k]=r[k];if('media' in r)v.media=r.media.mediaText;if('cssRules' in r)v.children=Array.from(r.cssRules,rule);return v;}return Array.from(document.getElementById('style').sheet.cssRules,rule);}`;
(async()=>{const browser=await openBrowser(path.join(root,'build'));try{
 const fixtures=[];
 for(const [name,css]of inputs){
  await browser.evaluate(`document.open();document.write('<!doctype html><html><head><style id=style></style></head><body><p id=probe>Probe</p></body></html>');document.close();document.getElementById('style').textContent=${JSON.stringify(css)};`);
  await browser.evaluate(snapshot);
  const expected=await browser.evaluate('JSON.stringify(snapshot())');
  fixtures.push({name,css,expected});
 }
 const mutationFixtures=[];
 for(const [name,css,source]of mutations){
  const expected=await browser.evaluate(`(()=>{document.open();document.write('<!doctype html><style id=style></style>');document.close();document.getElementById('style').textContent=${JSON.stringify(css)};const s=document.getElementById('style').sheet,output=[];function record(value){output.push(String(value));} try{${source}}catch(e){record('uncaught '+e.name)};record(Array.from(s.cssRules,r=>r.type).join(','));return output;})()`);
  const fixture={name,css,source,expected};
  if(name==='import after layer statement'){
   fixture.standardExpected=['1','0,3'];fixture.difference='CSS Cascade 5 permits import rules between layer statements; Chromium insertRule applies its older strict prelude ordering here.';
  }else if(name==='namespace before import'||name==='namespace after style'){
   fixture.standardExpected=['HierarchyRequestError',expected[1]];fixture.difference='CSSOM first checks CSS rule ordering, which requires imports before namespaces and namespaces before body rules; Chromium reports InvalidStateError for this ordering violation.';
  }
  mutationFixtures.push(fixture);
 }
 if(process.argv.includes('--update'))fs.writeFileSync(file,JSON.stringify({snapshot,fixtures,mutationFixtures},null,2)+'\n');else assert.deepEqual({snapshot,fixtures,mutationFixtures},JSON.parse(fs.readFileSync(file,'utf8')));
 console.log('CSS preludes: '+fixtures.length+' native rule trees captured.');
}finally{await browser.close();}})().catch(error=>{console.error(error);process.exitCode=1;});
