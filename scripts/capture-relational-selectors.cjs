const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),file=path.join(root,'tests/fixtures/relational-selectors-browser.json');
const grammarHTML='<!doctype html><body><div id=e class=hit><section id=branch><p class=leaf></p></section><p class=other></p></div><p class=other></p></body>';
const domHTML='<!doctype html><body><div class=host><div id=e class="host hit other"><section><p class=leaf></p></section><p class=other></p></div></div></body>';
const grammar=[
 ':is(.hit,#no:unsupported())',':where(.hit,#no:unsupported())',':not(.hit,:unsupported())',':has(.leaf,:unsupported())',
 ':has()',':has( )',':has(/**/)',':has(,.leaf)',':has(.leaf,)',':has(.leaf,,.other)',':has(:is(.leaf,))',
 ':has(:has(.leaf))',':has(section:has(.leaf))',':is(.hit,:has(section:has(.leaf)))',':where(.hit,:has(section:has(.leaf)))',
 ':has(:is(.leaf,:has(.leaf)))',':has(:where(:has(.leaf),section))',':has(:not(:has(.leaf)))',':has(:nth-child(1 of :has(.leaf)))',
 ':is(.hit,> .other)',':where(.hit,::before)',':not(:is(.hit,:unsupported()))',':has(:is(.leaf,::before))',
 ':nth-child(1 of .hit,:unsupported())',':nth-child(1 of :is(.hit,:unsupported()))',':nth-child(1 of .hit,)',
 ':is(.hit,.other])',':is(.hit,[title="bad\nvalue"])',':is(.hit,#no:has( ))',':has([title="bad\nvalue"],.leaf)',
 ':is(.hit,:not(.other,))',':is(.hit,:nth-child(1 of .hit,))',':is(.hit,[title="abc""abc"])',
 ':has(> .leaf + .other)',':has(> section > .leaf)',':has(> section + .other)',':has(+ .other)',
 ':nth-child(1 of #no,.hit)',':is(.hit,#no)',':not(.other,#no)',':where(#no,.hit)',
];
const dom=[
 ':is(.hit,#no:unsupported())',':where(.hit,#no:unsupported())',':not(.hit,:unsupported())',':has(.leaf,:unsupported())',
 ':has( )',':has(,.leaf)',':has(.leaf,)',':has(.leaf,,.other)',':has(:has(.leaf))',':has(section:has(.leaf))',
 ':is(.hit,:has(section:has(.leaf)))',':is(.hit,#no:has( ))',':has(:is(.leaf,:has(.leaf)))',
 ':has(:not(:has(.leaf)))',':has(:nth-child(1 of :has(.leaf)))',':nth-child(1 of .hit,:unsupported())',
 ':nth-child(1 of :is(.hit,:unsupported()))',':nth-child(1 of .hit,)',':is(.hit',':is(.hit,[title="bad\nvalue"])','*|/**/div',
];
const winners=[
 {name:'is valid maximum ID',selector:':is(.hit,#no)',competitor:'.hit',specificity:[1,0,0]},
 {name:'not valid maximum ID',selector:':not(.missing,#no)',competitor:'.hit',specificity:[1,0,0]},
 {name:'where zero',selector:':where(.hit,#no)',competitor:'div',specificity:[0,0,0]},
 {name:'nth filter adds pseudo specificity',selector:':nth-child(1 of #no,.hit)',competitor:'#e',specificity:[1,1,0]},
 {name:'is invalid nested has branch contributes zero',selector:':is(.hit,:has(section:has(.leaf)))',competitor:'.hit',specificity:[0,1,0]},
 {name:'is invalid empty has branch contributes zero',selector:':is(.hit,#no:has( ))',competitor:'.hit.other',specificity:[0,1,0]},
];
for(const c of winners)c.css=c.selector+'{color:rgb(17,53,91)}'+c.competitor+'{color:rgb(101,23,7)}';
const nesting=[
 {name:'nesting parent maximum',parent:'.host,#no',child:'& .hit',specificity:[1,1,0],css:'.host,#no{& .hit{color:rgb(17,53,91)}}.host .hit{color:rgb(101,23,7)}'},
 {name:'nesting invalid has branch specificity',parent:'.host',child:'&:is(.hit,:has(section:has(.leaf)))',specificity:[0,2,0],css:'.host{&:is(.hit,:has(section:has(.leaf))){color:rgb(17,53,91)}}.host.hit{color:rgb(101,23,7)}'},
];
const retainedHTML='<!doctype html><html><head><style id=sheet>.host:is(.hit,:has(section:has(.leaf))){color:rgb(17,53,91)}.host.hit{color:rgb(101,23,7)}</style></head><body><div id=target class="host hit other">Surface<section class=branch><p id=leaf class=leaf>Leaf</p></section><input id=kept value=kept></div><p id=outside>Outside</p><script>globalThis.relationalReady=true;</script></body></html>';
const retained=[
 {name:'initial invalid nested branch loses specificity tie',code:''},
 {name:'valid forgiving rest branch',code:"document.getElementById('kept').value='edited';document.getElementById('kept').setSelectionRange(1,3,'backward');document.getElementById('sheet').sheet.cssRules[0].selectorText='.host.other:has(:is(.leaf,:has(.leaf)))';"},
 {name:'descendant class removal updates retained paint',code:"document.getElementById('leaf').className='missing';"},
 {name:'descendant class restoration updates retained paint',code:"document.getElementById('leaf').className='leaf';"},
 {name:'forbidden branch cannot supply a match',code:"document.getElementById('sheet').sheet.cssRules[0].selectorText='.host.other:has(:is(.missing,:has(.leaf)))';"},
 {name:'invalid selectorText leaves existing rule intact',code:"document.getElementById('sheet').sheet.cssRules[0].selectorText='.host.other:has( )';"},
 {name:'invalid relative insertRule throws without inserting',code:"const sheet=document.getElementById('sheet').sheet;sheet.deleteRule(0);globalThis.relativeInsertError='';try{sheet.insertRule('.host.other:has( ){color:rgb(17,53,91)}',0);}catch(error){relativeInsertError=error.name;}"},
 {name:'valid relative combinator inserts and paints',code:"document.getElementById('sheet').sheet.insertRule('.host.other:has(> section > .leaf){color:rgb(17,53,91)}',0);"},
 {name:'valid relational CSSOM color edit only repaints',code:"document.getElementById('sheet').sheet.cssRules[0].style.color='rgb(41,67,89)';",paintOnly:true},
];
const badString=':is(.hit,[title="bad\nvalue"])';
function annotate(records){
 for(const c of records){
  if(c.source===badString){c.specExpected='SyntaxError';c.difference='CSS Syntax <any-value> excludes bad-string tokens before forgiving selector-list recovery; native DOM matching accepts this input, while its stylesheet parser rejects it.';}
  if(c.source===':is(.hit'){c.profileExpected='SyntaxError';c.difference='Native DOM auto-closes a function at EOF under CSS Syntax. This existing engine DOM parser gap is outside the relational-selector slice; the native result is preserved, not reclassified as a standard error.';}
 }
}
(async()=>{
 const browser=await openBrowser(path.join(root,'build/relational-selectors-native'));
 try{
  const version=await browser.send('Browser.getVersion');
  const probe=selectors=>'(()=>{const e=document.getElementById("e");return '+JSON.stringify(selectors)+'.map(source=>{let expected;try{expected=e.matches(source);}catch(error){expected=error.name;}const sheet=new CSSStyleSheet();sheet.replaceSync(source+"{color:rgb(17,53,91)}");return{source,expected,count:sheet.cssRules.length,selectorText:sheet.cssRules.length?sheet.cssRules[0].selectorText:null};});})()';
  await browser.load(grammarHTML);const grammarRecords=await browser.evaluate(probe(grammar));annotate(grammarRecords);
  await browser.load(domHTML);const domRecords=await browser.evaluate(probe(dom));annotate(domRecords);
  for(const c of [...winners,...nesting]){
   const result=await browser.evaluate('(()=>{const style=document.createElement("style");style.textContent='+JSON.stringify(c.css)+';document.head.append(style);const sheet=style.sheet;const result={color:getComputedStyle(document.getElementById("e")).color,count:sheet.cssRules.length,selectorText:sheet.cssRules[0].selectorText,nestedCount:sheet.cssRules[0].cssRules?.length??null,nestedSelectorText:sheet.cssRules[0].cssRules?.[0]?.selectorText??null};style.remove();return result;})()');Object.assign(c,result);
  }
  await browser.load(retainedHTML);
  for(const c of retained){
   await browser.evaluate('(()=>{'+c.code+'})()');
   c.expected=await browser.evaluate('(()=>{const e=document.getElementById("target"),input=document.getElementById("kept"),sheet=document.getElementById("sheet").sheet;return{color:getComputedStyle(e).color,count:sheet.cssRules.length,selectorText:sheet.cssRules[0].selectorText,value:input.value,selectionStart:input.selectionStart,selectionEnd:input.selectionEnd,selectionDirection:input.selectionDirection,insertError:globalThis.relativeInsertError??null};})()');
  }
  const fixture={browser:version.product,captured:'2026-10-10',standards:['https://www.w3.org/TR/2026/WD-selectors-4-20260122/#relational','https://www.w3.org/TR/2026/WD-selectors-4-20260122/#forgiving-selector','https://www.w3.org/TR/css-syntax-3/#any-value'],
   boundaries:{namespaces:'Default namespace subject exceptions and synthetic relative-anchor namespaces remain a separate unresolved slice. These captures do not redefine their standard expectations.',serialization:'Native selectorText strings are raw observations. Forgiving branch serialization differs from the engine and remains unresolved in CSSWG issue 3676; rule counts and actual cascade behavior are asserted independently. https://github.com/w3c/csswg-drafts/issues/3676'},
   grammarHTML,grammar:grammarRecords,domHTML,dom:domRecords,winners,nesting,retainedHTML,retained};
  if(process.argv.includes('--update'))fs.writeFileSync(file,JSON.stringify(fixture,null,2)+'\n');else assert.deepEqual(fixture,JSON.parse(fs.readFileSync(file,'utf8')));
  console.log('Relational selectors: '+grammar.length+' grammar cases, '+dom.length+' DOM/CSSOM cases, '+(winners.length+nesting.length)+' cascade winners and '+retained.length+' retained paint states captured.');
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
