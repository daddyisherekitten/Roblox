const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),file=path.join(root,'tests/fixtures/selector-names-browser.json'),cases=[];
const H='http://www.w3.org/1999/xhtml',S='http://www.w3.org/2000/svg';
const prelude=`const H=${JSON.stringify(H)},S=${JSON.stringify(S)},make=(d,u,n)=>d.createElementNS(u,n),probe=(e,s)=>{try{return e.matches(s)}catch(x){return x.name}};`;
function add(name,body){cases.push({name,html:'<!doctype html><body></body>',action:'(()=>{'+prelude+body+'})()'});}
for(const kind of ['html','xml'])for(const [uri,name]of [[H,'div'],[H,'p:div'],[H,'DIV'],[H,'p:DIV'],[S,'linearGradient'],[S,'p:linearGradient'],['urn:x','div'],['urn:x','p:div'],['','div']]){
 const selectors=['div','DIV','DiV','*|div','|div','linearGradient','lineargradient','LINEARGRADIENT',':is(div,DIV)',':not(div)','[title]','[TITLE]','[tItLe]','[p|title]','[*|title]','[*|TITLE]'];
 add(kind+' expanded name '+uri+' '+name,`const d=${kind==='html'?"document.implementation.createHTMLDocument('')":"document.implementation.createDocument('urn:root','root')"},e=make(d,${JSON.stringify(uri)},${JSON.stringify(name)});e.setAttribute('title','one');e.setAttributeNS('urn:a','p:TITLE','two');return JSON.stringify(${JSON.stringify(selectors)}.map(s=>probe(e,s)));`);
}
for(const kind of ['html','xml'])for(const uri of [H,S,'urn:x','']){
 add(kind+' of-type grouping '+uri,`const d=${kind==='html'?"document.implementation.createHTMLDocument('')":"document.implementation.createDocument('urn:root','root')"},r=make(d,'urn:root','root'),a=make(d,${JSON.stringify(uri)},${JSON.stringify(uri?'a:item':'item')}),b=make(d,${JSON.stringify(uri)},${JSON.stringify(uri?'b:item':'item')}),c=make(d,${JSON.stringify(uri)},'ITEM'),f=make(d,'urn:other','item');r.append(a,f,b,c);const selectors=['item:first-of-type','item:last-of-type','item:nth-of-type(2)','item:nth-last-of-type(1)',':only-of-type','ITEM:nth-of-type(1)','*|item:nth-child(2 of item)',':is(item):nth-of-type(2)'];const out=[a,b,c,f].map(e=>selectors.map(s=>probe(e,s)));r.prepend(b);out.push([a,b].map(e=>probe(e,':first-of-type')));f.remove();out.push([a,b].map(e=>probe(e,':nth-of-type(2)')));return JSON.stringify(out);`);
}
add('adoption changes type and attribute folding immediately',"const h=document.implementation.createHTMLDocument(''),x=document.implementation.createDocument('urn:r','r'),e=make(h,H,'p:div');e.setAttribute('title','one');const read=()=>['div','DIV','[title]','[TITLE]'].map(s=>probe(e,s));const out=[read()];x.adoptNode(e);out.push(read());h.adoptNode(e);out.push(read());return JSON.stringify(out);");
add('root in document detached fragment and shadow trees',"const d=document.implementation.createHTMLDocument(''),e=d.createElement('div'),out=[],read=n=>out.push([':root',':scope',':is(:root)',':not(:root)'].map(s=>probe(n,s)));read(d.documentElement);read(e);const f=d.createDocumentFragment();f.append(e);read(e);d.body.append(e);read(e);const host=d.createElement('div');d.body.append(host);const shadow=host.attachShadow({mode:'open'});shadow.append(e);read(e);const replacement=document.implementation.createHTMLDocument('');replacement.replaceChild(e,replacement.documentElement);read(e);e.remove();read(e);return JSON.stringify(out);");
add('XML roots use the document parent rather than owner document',"const d=document.implementation.createDocument(S,'s:svg'),e=d.documentElement,out=[],read=()=>out.push([':root',':scope',':is(:root)',':not(:root)'].map(s=>probe(e,s)));read();e.remove();read();const f=d.createDocumentFragment();f.append(e);read();d.append(e);read();return JSON.stringify(out);");
const insensitive=['accept','accept-charset','align','alink','axis','bgcolor','charset','checked','clear','codetype','color','compact','declare','defer','dir','direction','disabled','enctype','face','frame','hreflang','http-equiv','lang','language','link','media','method','multiple','nohref','noresize','noshade','nowrap','readonly','rel','rev','rules','scope','scrolling','selected','shape','target','text','type','valign','valuetype','vlink'];
for(const [uri,name]of [[H,'a'],[H,'p:a'],[H,'area'],[S,'a'],[S,'s:a'],[S,'area'],['urn:foreign','a'],['','a']]){
 add('expanded link states '+uri+' '+name,
  'const e=make(document,'+JSON.stringify(uri)+','+JSON.stringify(name)+'),out=[],read=()=>out.push([":any-link",":link",":visited"].map(s=>probe(e,s)));document.body.append(e);read();e.setAttribute("href","");read();e.removeAttribute("href");e.setAttributeNS("http://www.w3.org/1999/xlink","alternate:href","");read();e.removeAttributeNS("http://www.w3.org/1999/xlink","href");e.setAttributeNS("http://www.w3.org/1999/xlink","href","");read();e.removeAttributeNS("http://www.w3.org/1999/xlink","href");e.setAttribute("xlink:href","");read();e.setAttributeNS("urn:foreign","f:href","");read();e.setAttribute("href","http://[invalid");read();return JSON.stringify(out);');
}
const sensitive=['title','class','id','data-case','role','aria-label','unknown'];
for(const kind of ['html','xml'])for(const uri of [H,S])for(const ns of ['', 'urn:a']){
 const names=[...insensitive,...sensitive],selectors=names.map(n=>`[${ns?'*|':''}${n}="mixed"]`);
 add(kind+' attribute value folding '+uri+' '+ns,`const d=${kind==='html'?"document.implementation.createHTMLDocument('')":"document.implementation.createDocument('urn:r','r')"},e=make(d,${JSON.stringify(uri)},'div');for(const n of ${JSON.stringify(names)})e.setAttributeNS(${JSON.stringify(ns)},${ns?"'p:'+n":"n"},'MiXeD');return JSON.stringify(${JSON.stringify(selectors)}.map(s=>probe(e,s)));`);
}
for(const kind of ['html','xml'])for(const uri of [H,S]){
 const probes=['[rel="mixed"]','[rel="mixed" i]','[rel="MiXeD" s]','[rel="mixed" s]','[rel^="mi"]','[rel$="ED"]','[rel*="IX"]','[rel~="mixed"]','[rel|="mixed"]','[title="mixed"]','[title="mixed" i]','[title="MiXeD" s]','[title="mixed" s]','[title="ärger" i]'];
 add(kind+' value operators and flags '+uri,`const d=${kind==='html'?"document.implementation.createHTMLDocument('')":"document.implementation.createDocument('urn:r','r')"},e=make(d,${JSON.stringify(uri)},'div');e.setAttribute('rel','MiXeD');e.setAttribute('title','MiXeD');const out=${JSON.stringify(probes)}.map(s=>probe(e,s));e.setAttribute('title','ÄRGER');out.push(probe(e,'[title="ärger" i]'));return JSON.stringify(out);`);
 const c=cases[cases.length-1];c.flagIndexes=[2,3,11,12];
}
// Pass CSS strings directly to matches(): never normalize stored DOM data.
function grammar(name,selectors,setup="e.setAttribute('title','abc');e.lang='de-DE';"){
 add('grammar '+name,"const e=document.createElement('div');"+setup+'return JSON.stringify('+JSON.stringify(selectors)+'.map(s=>probe(e,s)));');
}
for(const [name,w]of [['space',' '],['tab','\t'],['lf','\n'],['cr','\r'],['crlf','\r\n'],['ff','\f'],['vt','\v'],['nbsp','\u00a0'],['em-space','\u2003']]){
 grammar('whitespace '+name,[w+'div','div'+w,'div'+w+'[title]','[title'+w+'='+w+'"abc"'+w+']','[title="ABC"'+w+'i]',':lang('+w+'"de"'+w+')','div:nth-child('+w+'1'+w+')']);
}
for(const [name,n]of [['lf','\n'],['cr','\r'],['crlf','\r\n'],['ff','\f'],['vt','\v'],['nbsp','\u00a0']]){
 grammar('quoted newline '+name,['[title="a'+n+'bc"]',':lang("d'+n+'e")','[title="a\\'+n+'bc"]',':lang("d\\'+n+'e")'],"e.setAttribute('title','abc');e.lang='de';");
}
grammar('quoted token boundaries',['[title="abc""abc"]','[title="abc" "abc"]','[title="ABC"i]','[title="ABC"I]','[title="ABC"\\69]','[title=ABC \\69]','[title="abc" j]','[title="abc" ii]','[title="abc" i i]',':lang("de""de")',':lang("de" "de")','[title="ab\\"c"]','[title="ab\\\\c"]','[title="abc"\\\n]']);
for(const [name,source,stored]of [['nul','\0','\ufffd'],['high-surrogate','\ud800','\ufffd'],['low-surrogate','\udfff','\ufffd'],['supplementary','\ud83c\udf1f','\ud83c\udf1f'],['cjk','한','한']]){
 grammar('preprocess '+name,['.'+source,'[title="'+source+'"]','[title='+source+']',':is(.'+source+',.missing)'],'e.className='+JSON.stringify(stored)+";e.setAttribute('title',"+JSON.stringify(stored)+');');
 grammar('stored data '+name,['.'+source,'[title="'+source+'"]','[title='+source+']'],'e.className='+JSON.stringify(source)+";e.setAttribute('title',"+JSON.stringify(source)+');');
}
for(const [name,source,stored]of [['zero','\\0','\ufffd'],['surrogate','\\d800','\ufffd'],['outside','\\110000','\ufffd'],['six-digit','\\000061b','ab'],['terminating-space','\\61 bc','abc'],['terminating-crlf','\\61\r\nbc','abc'],['terminating-vt','\\61\vbc','a\vbc'],['terminating-nbsp','\\61\u00a0bc','a\u00a0bc'],['non-ascii','\\🌟','🌟'],['punctuation','\\+','+'],['dash','\\-','-'],['digit','\\31','1']]){
 grammar('escape '+name,['.'+source,'[title="'+source+'"]','[title='+source+']'],'e.className='+JSON.stringify(stored)+";e.setAttribute('title',"+JSON.stringify(stored)+');');
}
const formulas=['1','+1','-1','1.0','1e0','01','odd','oDd','even','n','N','+n','-n','2n','+2n','-2n','2n+1','2n +1','2n+ 1','2n + 1','2 n+1','+ n','- n','n 1','n -1','n - 1','n +1','n + 1','n + +1','n - -1','n-1','n- 1','n--1','n-01','2n-01','2n- 01','\\6e +1','\\6f dd','\\32 n+1','2\\6e +1','n/**/+1','2/**/n+1','2n/**/+1','n\\\n+1','1 of .yes','n of :is(.yes,.no)','2n OF .yes','1 of .yes, .no','n of ','n of .yes,','1of .yes','1 of.yes'];
for(const formula of formulas)add('grammar An+B '+formula,"const r=document.createElement('div'),nodes=[];for(let i=0;i<6;i++){const e=document.createElement('p');e.className=i%2?'no':'yes';r.append(e);nodes.push(e);}return JSON.stringify(nodes.map(e=>probe(e,"+JSON.stringify(':nth-child('+formula+')')+")));");
for(const formula of ['2n of .yes','n/**/of .yes','n /**/of/**/ .yes','n \\6f f .yes','+/**/n','+/**/ n','-n/**/ +1','-2n-/**/1'])add('grammar An+B '+formula,"const r=document.createElement('div'),nodes=[];for(let i=0;i<6;i++){const e=document.createElement('p');e.className=i%2?'no':'yes';r.append(e);nodes.push(e);}return JSON.stringify(nodes.map(e=>probe(e,"+JSON.stringify(':nth-child('+formula+')')+")));");
grammar('attribute comment flag boundaries',['[title=ABC/**/i]','[title=ABC/**/ i]','[title="ABC"/**/i/**/]','[title="abc"/**/j]','[title="abc"/**/ii]']);
const directionSelectors=[':dir(ltr)',':dir(rtl)',':DIR(LTR)',':dir(LtR)',':\\64 ir(\\6c tr)',':dir(\\6c tr)',':dir(/**/ltr/**/)',':dir( ltr )',':dir(l/**/tr)',':dir(ltr/**/rtl)',':dir(ltr,rtl)',':dir("ltr")',":dir('ltr')",':dir()',':dir(auto)',':dir(inherit)',':dir(1)',':dir(\\31)',':dir(+ltr)',':dir(-ltr)',':dir(ltr\\\n)',':dir(\vltr)',':dir(ltr\v)',':dir(\u00a0ltr)',':dir(ltr\u00a0)'];
grammar('direction argument tokens',directionSelectors,"e.dir='ltr';");
grammar('comment token boundaries',['div/**/[title]','di/**/v','div/**/div','div/* x */ [title]','[title/**/="abc"]','[title="ABC"/**/i]','[title=AB/**/C]',':lang(d/**/e)',':lang(/**/de/**/)',' :is(div/**/.x,div)','div/**/>[title]']);
const stateSelectors=[':state(edited)',':STATE(edited)',':state(EDITED)',':state(\\65 dited)',':state(--ready)',':state(-ready)',':state(éclair)',':state(\\e9 clair)',':state(한글)',':state(🚀)',':state(\\31 )',':state(a\\ b)',':state(a\\:b)',':state(true)',':state(inherit)',':state(default)',':state(/**/edited/**/)',':state(e/**/dited)',':state(edited )',':state("edited")',':state()',':state(-)',':state(+ready)',':state(1)',':state(edited,ready)',':state(edited ready)',':state(edited\\\n)',':is(:state(\\65 dited),.missing)',':not(:state(\\65 dited))'];
stateSelectors.push(':state( 1)',':state(/**/1)',':state( -ready )',':state(/**/-ready/**/)',':state(\u00a0edited)',':state(edited\u00a0)');
for(const state of ['edited','EDITED','--ready','-ready','éclair','한글','🚀','1','a b','a:b','true','inherit','default']){
 add('custom state CSS identifier '+state,"class StateProbe extends HTMLElement{constructor(){super();this.i=this.attachInternals();}}customElements.define('x-state-probe',StateProbe);const e=document.createElement('x-state-probe');e.i.states.add("+JSON.stringify(state)+');const out='+JSON.stringify(stateSelectors)+".map(s=>probe(e,s));e.i.states.delete("+JSON.stringify(state)+');out.push(...'+JSON.stringify(stateSelectors.slice(0,10))+".map(s=>probe(e,s)));return JSON.stringify(out);");
}
const styles=[];
function style(name,setup,selector,namespaces){styles.push({name,setup,selector,namespaces,css:(namespaces||'')+selector+'{color:rgb(17, 53, 91)}'});}
style('scope without explicit scope uses document element',"const e=document.documentElement;e.id='e';",':scope','');
style('scope anchors ordinary stylesheet descendants',"const e=document.createElement('p');e.id='e';document.body.append(e);",':scope > body > p','');
style('scope does not match an ordinary descendant',"const e=document.createElement('p');e.id='e';document.body.append(e);",':scope','');
for(const selector of [':dir(\\6c tr)',':DIR(LTR)',':dir(LtR)',':dir(/**/ltr/**/)',':dir(l/**/tr)',':dir("ltr")',':dir(\vltr)',':dir(\u00a0ltr)']){
 style('direction paint '+selector,"const e=document.createElement('p');e.id='e';e.dir='ltr';document.body.append(e);",selector,'');
 styles[styles.length-1].grammar=true;
}
for(const selector of [':state(\\65 dited)',':state(/**/edited/**/)',':state(éclair)',':state(\\e9 clair)',':state(\\31 )',':state(a\\ b)',':state(e/**/dited)',':state("edited")']){
 style('custom state paint '+selector,"class StatePaint extends HTMLElement{constructor(){super();this.i=this.attachInternals();}}customElements.define('x-state-paint',StatePaint);const e=document.createElement('x-state-paint');e.id='e';for(const value of ['edited','éclair','1','a b'])e.i.states.add(value);document.body.append(e);",selector,'');styles[styles.length-1].grammar=true;
}
for(const [uri,name]of [[H,'p:div'],[S,'p:linearGradient'],['','div']])for(const selector of ['DIV','div','linearGradient','lineargradient','h|div','s|linearGradient','|div','*|div','[TITLE]','[title]'])style('paint '+name+' '+selector,`const e=document.createElementNS(${JSON.stringify(uri)},${JSON.stringify(name)});e.id='e';e.setAttribute('title','one');document.body.append(e);`,selector,`@namespace h url(${H});@namespace s url(${S});`);
for(const selector of ['h|*','*','*:is(div)','*:is(*|div)','div','|div'])style('default namespace '+selector,"const e=document.createElement('div');e.id='e';document.body.append(e);",selector,`@namespace url(${S});@namespace h url(${H});`);
for(const [start,end,def,inside]of [['h|div.outer','',false,false],['s|div.outer','',false,false],['missing|div.outer','',false,false],['h|div.outer','h|section.stop',false,true],['h|div.outer','s|section.stop',false,true],['div.outer','',true,false],['h|div.outer','',true,false],[':is(h|div.outer,s|g)','h|section.stop',false,true],['h|div.outer','h|section.stop',false,false],['*|div.outer','',true,false]]){
 const name='scope namespace '+[start,end,def,inside].join('/'),html='<div class="outer">'+(inside?'<section class="stop">':'')+'<p id="e">Scope</p>'+(inside?'</section>':'')+'</div>';
 const c={name,setup:`document.body.innerHTML=${JSON.stringify(html)};const e=document.getElementById('e');`,selector:start,namespaces:`${def?'@namespace url('+S+');':''}@namespace h url(${H});@namespace s url(${S});`,scope:true};
 c.css=c.namespaces+'@scope ('+start+')'+(end?' to ('+end+')':'')+'{h|p{color:rgb(17, 53, 91)}}';styles.push(c);
}
const paintGrammar=['\v#e','#e\v','[title="a\nbc"]','[title="a\\\nbc"]','[title="abc""abc"]','[title="ABC"i]','[title="ABC"\\69]','#e:nth-child(2 n+1)','#e:nth-child(+ n)','#e:nth-child(1.0)','#e:nth-child(\\31)','#e:nth-child(\\6e +1)','div/**/[title]','di/**/v','div/**/div'];
for(const selector of paintGrammar){
 const setup=selector==='di/**/v'?"const p=document.createElement('di');const e=document.createElement('v');e.id='e';p.append(e);document.body.append(p);":"const p=document.createElement('div');const e=document.createElement('div');e.id='e';e.setAttribute('title','abc');p.append(e);document.body.append(p);";
 style('grammar paint '+JSON.stringify(selector),setup,selector,'');styles[styles.length-1].grammar=true;
}
for(const [name,boundary]of [['vt-root','(\vdiv.outer)'],['vt-outer','\v(div.outer)'],['ff-root','(\fdiv.outer)'],['space-root','( div.outer)'],['vt-limit','(div.outer) to\v(.stop)'],['space-limit','(div.outer) to (.stop)']]){
 const c={name:'grammar scope '+name,setup:"document.body.innerHTML='<div class=\"outer\"><p id=\"e\">Scope</p></div>';const e=document.getElementById('e');",selector:'div.outer',namespaces:'',grammar:true};
 c.css='@scope '+boundary+'{p{color:rgb(17, 53, 91)}}';styles.push(c);
}
function differences(){
 // Native omissions/deviations are retained, never rewritten as raw results.
 const grammarOverrides=new Map();
 for(const name of ['space','tab','lf','cr','crlf','ff'])grammarOverrides.set('grammar whitespace '+name,{5:true});
 for(const name of ['lf','cr','crlf','ff'])grammarOverrides.set('grammar quoted newline '+name,{3:true});
 for(const name of ['vt','nbsp'])grammarOverrides.set('grammar quoted newline '+name,{1:false,3:false});
 for(const name of ['high-surrogate','low-surrogate']){
  grammarOverrides.set('grammar preprocess '+name,{1:true});
  grammarOverrides.set('grammar stored data '+name,{1:false});
 }
 grammarOverrides.set('grammar An+B 2n OF .yes',{0:false,1:false,2:true,3:false,4:false,5:false});
 for(const c of cases)if(grammarOverrides.has(c.name)){
  const out=JSON.parse(c.expected);for(const [i,value]of Object.entries(grammarOverrides.get(c.name)))out[i]=value;
  c.specExpected=JSON.stringify(out);
  c.difference=c.name.includes('surrogate')?'CSS Syntax preprocessing replaces lone surrogates even within strings; Chromium preserves them in quoted attribute values. DOM data is unchanged.':c.name.includes('An+B')?'Selectors syntax keywords are ASCII case-insensitive; Chromium rejects uppercase OF in nth-child filters. The lowercase native control yields the same filtered second sibling.':'Selectors Level 4 permits quoted :lang() ranges; Chromium rejects this syntax. Bad string newlines still invalidate selectors and valid escaped newlines disappear.';
 }
 const difference='Chromium folds type/attribute selector names for foreign elements in HTML documents too. HTML case-sensitivity rules require exact original names outside the HTML namespace, and exact names for namespaced attributes; raw browser records stay preserved.';
 for(const c of cases){
  if(c.name.startsWith('html expanded name ')&&!c.name.includes(H))c.specExpected=cases.find(x=>x.name==='xml'+c.name.slice(4)).expected;
  if(c.name.startsWith('html of-type grouping ')&&!c.name.includes(H))c.specExpected=cases.find(x=>x.name==='xml'+c.name.slice(4)).expected;
  if(c.name==='html of-type grouping '+H){const out=JSON.parse(c.expected);out[3][5]=false;c.specExpected=JSON.stringify(out);}
  if(c.flagIndexes){const out=JSON.parse(c.expected);for(const i of c.flagIndexes)out[i]=i===2||i===11;c.specExpected=JSON.stringify(out);delete c.flagIndexes;c.difference='Chromium does not implement the Selectors Level 4 s value flag. Standard expectations preserve explicit case-sensitive matching, with unsupported native SyntaxError results retained separately.';}
  if(c.specExpected===c.expected)delete c.specExpected;
  if(c.specExpected&&!c.difference)c.difference=difference;
 }
 for(const c of styles){
  const foreign=c.name.startsWith('paint p:linearGradient ')||c.name.startsWith('paint div ');
  if(foreign&&((c.selector==='DIV')||(c.selector==='lineargradient')||(c.selector==='[TITLE]'))&&c.expected!=='rgb(3, 7, 11)'){
   c.specExpected='rgb(3, 7, 11)';c.difference=difference;
  }
 }
}
(async()=>{const browser=await openBrowser(path.join(root,'build'));try{const version=await browser.send('Browser.getVersion');for(const c of cases){await browser.load(c.html);c.expected=await browser.evaluate(c.action);}for(const c of styles){await browser.load('<!doctype html><style>body{color:rgb(3, 7, 11)}</style><body></body>');c.expected=await browser.evaluate(`(()=>{${c.setup}const style=document.createElement('style');style.textContent=${JSON.stringify(c.css)};document.head.append(style);return getComputedStyle(e).color})()`);if(c.scope)c.rulesExpected=await browser.evaluate(`(()=>{const sheet=new CSSStyleSheet();sheet.replaceSync(${JSON.stringify(c.css)});const r=sheet.cssRules[sheet.cssRules.length-1];return JSON.stringify([sheet.cssRules.length,r.constructor.name,r.start,r.end,r.cssRules?r.cssRules.length:null])})()`);if(c.grammar)c.grammarRulesExpected=await browser.evaluate("(()=>{const sheet=new CSSStyleSheet();sheet.replaceSync("+JSON.stringify(c.css)+");const r=sheet.cssRules[sheet.cssRules.length-1];return JSON.stringify([sheet.cssRules.length,r?r.constructor.name:null,r?r.selectorText||null:null])})()");}differences();const fixture={browser:version.product,captured:'2026-10-10',standards:['https://drafts.csswg.org/selectors-4/#type-selectors','https://drafts.csswg.org/selectors-4/#the-nth-of-type-pseudo','https://html.spec.whatwg.org/multipage/semantics-other.html#case-sensitivity-of-selectors','https://drafts.csswg.org/css-cascade-6/#scope-atrule','https://drafts.csswg.org/selectors-4/#the-dir-pseudo','https://drafts.csswg.org/selectors-4/#root-pseudo','https://www.w3.org/TR/SVG2/linking.html#AElement'],cases,styles};if(process.argv.includes('--update'))fs.writeFileSync(file,JSON.stringify(fixture,null,2)+'\n');else assert.deepEqual(fixture,JSON.parse(fs.readFileSync(file,'utf8')));console.log('Selector names: '+cases.length+' native query sequences and '+styles.length+' stylesheet paint records captured.');}finally{await browser.close();}})().catch(error=>{console.error(error);process.exitCode=1});
