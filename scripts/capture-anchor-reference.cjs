const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),folder=path.join(root,'build/anchor-reference');fs.mkdirSync(folder,{recursive:true});
const cases=[];
const tip=(css='',id='tip')=>`<div id="${id}" style="position:absolute;left:20px;top:60px;width:30px;height:12px;${css}"></div>`;
const anchor=(css='',id='anchor')=>`<div id="${id}" style="anchor-name:--a;width:70px;height:30px;margin-left:40px;margin-top:10px;${css}"></div>`;
function add(name,markup,css='',rootStyle=''){cases.push({name,markup,css,rootStyle});}
for(const keyword of ['','width','height','inline','block','self-inline','self-block'])for(const field of ['width','height','min-width','max-width','min-height','max-height','margin-left','margin-top','left','top']){
 const initial=field.startsWith('max-')?'width:150px;height:90px;':'';
 add(`${field}:${keyword||'default'}`,anchor('padding:5px;border:2px solid;')+tip(`position-anchor:--a;${initial}${field}:anchor-size(${keyword});`));
}
for(const [name,value]of [
 ['math','calc(anchor-size(width) * 2 + 5px)'],['minimum','min(anchor-size(width),50px)'],['clamp','clamp(20px,anchor-size(height),60px)'],
 ['explicit','anchor-size(--a width)'],['reverse','anchor-size(width --a)'],['missing','anchor-size(--missing width,45px)'],
 ['empty-fallback','anchor-size(,45px)'],['percentage-fallback','anchor-size(--missing width,25%)'],['unresolved','anchor-size(--missing width)'],
 ['invalid-size','anchor-size(--a sideways,45px)'],['duplicate','anchor-size(--a --a width,45px)'],['duplicate-size','anchor-size(width height,45px)'],
 ['case-name','anchor-size(--A width,45px)'],['uppercase-function','ANCHOR-SIZE(--a WIDTH)'],['unicode-name','anchor-size(--käste width)'],
 ['escaped-name','anchor-size(--k\\e4 ste width)'],['comments','anchor-size(/*x*/--a/**/width/*y*/,45px)'],
])add('expression-'+name,anchor(name.includes('name')?'anchor-name:--käste;':'')+tip(`position-anchor:--a;width:17px;width:${value};`));
add('non-positioned-fallback',anchor()+`<div id="tip" style="width:anchor-size(--a width,45px);height:12px"></div>`);
add('non-positioned-invalid',anchor()+`<div id="tip" style="width:17px;width:anchor-size(--a width);height:12px"></div>`);
add('last-in-flow',anchor()+tip('left:anchor(--a left);top:anchor(--a bottom);')+anchor('margin-left:150px;','other'));
add('nearest-ancestor',`<div id="ancestor" style="anchor-name:--a;width:120px;height:45px">${tip('left:anchor(--a left);width:anchor-size(--a width);')}</div>`+anchor('margin-left:150px;','other'));
add('named-list',anchor('anchor-name:--a, --b;')+tip('left:anchor(--b left);width:anchor-size(--b width);'));
add('case-sensitive',anchor('anchor-name:--A;')+tip('left:anchor(--a left,13px);width:anchor-size(--A width);'));
add('earlier-absolute',anchor('position:absolute;left:85px;top:15px;margin:0;')+tip('left:anchor(--a left);top:anchor(--a bottom);width:anchor-size(--a width);'));
add('later-absolute',tip('left:anchor(--a left,13px);width:anchor-size(--a width,45px);')+anchor('position:absolute;left:85px;top:15px;margin:0;'));
add('self-cycle',tip('anchor-name:--a;left:anchor(--a left,13px);width:anchor-size(--a width,45px);'));
add('descendant-cycle',`<div id="tip" style="position:absolute;left:anchor(--a left,13px);top:60px;width:anchor-size(--a width,45px);height:40px">${anchor()}</div>`);
add('relative-anchor',anchor('position:relative;left:23px;top:7px;')+tip('left:anchor(--a left);top:anchor(--a bottom);'));
add('chained-absolute',anchor()+tip('anchor-name:--b;left:anchor(--a right);top:anchor(--a bottom);width:anchor-size(--a width);','middle')+tip('left:anchor(--b right);top:anchor(--b bottom);width:anchor-size(--b width);'));
for(const scope of ['none','all','--a','--b','--a, --b']){
 add('scope-'+scope,`<div id="first" style="anchor-scope:${scope};width:300px;height:60px">${anchor()}${tip('left:anchor(--a left,13px);width:anchor-size(--a width,45px);')}</div><div style="anchor-scope:${scope};width:300px;height:60px">${anchor('margin-left:160px;width:90px;','other')}${tip('left:anchor(--a left,13px);width:anchor-size(--a width,45px);','tip2')}</div>`);
 add('scope-outside-'+scope,`<div style="anchor-scope:${scope};width:300px;height:60px">${anchor()}</div>${tip('left:anchor(--a left,13px);width:anchor-size(--a width,45px);')}`);
 add('scope-no-inward-'+scope,anchor()+`<div style="anchor-scope:${scope};width:300px;height:60px">${tip('left:anchor(--a left,13px);width:anchor-size(--a width,45px);')}</div>`);
}
add('scope-contents',`<div style="display:contents;anchor-scope:all">${anchor()}${tip('left:anchor(--a left,13px);width:anchor-size(--a width,45px);')}</div>${anchor('margin-left:160px;width:90px;','other')}`);
add('scope-nested',`<div style="anchor-scope:all;width:300px;height:120px">${anchor()}<div style="anchor-scope:--a">${anchor('margin-left:160px;width:90px;','other')}${tip('left:anchor(--a left,13px);width:anchor-size(--a width,45px);','tip2')}</div>${tip('left:anchor(--a left,13px);width:anchor-size(--a width,45px);')}</div>`);
add('hidden-anchor',anchor('display:none;')+tip('left:anchor(--a left,13px);width:anchor-size(--a width,45px);'));
add('invisible-anchor',anchor('visibility:hidden;')+tip('left:anchor(--a left,13px);width:anchor-size(--a width,45px);'));
add('contents-anchor',`<div style="display:contents;anchor-name:--a">${anchor('anchor-name:none;')}</div>${tip('left:anchor(--a left,13px);width:anchor-size(--a width,45px);')}`);
for(const direction of ['ltr','rtl'])for(const side of ['start','end','self-start','self-end','inside','outside','25%','center'])add('side-'+direction+'-'+side,anchor()+tip(`position-anchor:--a;left:anchor(${side});top:anchor(bottom);`),'','direction:'+direction);
for(const field of ['width','height'])for(const keyword of ['inline','block','self-inline','self-block'])add('vertical-query-'+field+'-'+keyword,anchor()+tip(`writing-mode:vertical-rl;position-anchor:--a;${field}:anchor-size(${keyword});`));
const edge=anchor('position:absolute;left:350px;top:175px;width:40px;height:25px;margin:0;');
const overflowing='position-anchor:--a;left:anchor(right);top:anchor(bottom);width:80px;height:35px;';
for(const recipe of ['flip-inline','flip-block','flip-block flip-inline','flip-start','flip-x','flip-y','--left','--above','--shrink','--none','--missing, --left','--above flip-inline']){
 add('fallback-'+recipe,edge+tip(overflowing+'position-try-fallbacks:'+recipe+';'),`@position-try --left{left:auto;right:anchor(left);top:anchor(top);bottom:auto}@position-try --above{top:auto;bottom:anchor(top);left:anchor(left)}@position-try --shrink{left:anchor(left);top:anchor(top);width:30px;height:20px;margin:0}@position-try --none{width:300px;height:300px}`);
}
for(const [name,rules,base]of [
 ['cascade-last','@position-try --fit{left:10px;top:10px}@position-try --fit{left:40px;top:20px}',''],
 ['cascade-layer','@layer a,b;@layer b{@position-try --fit{left:40px;top:20px}}@layer a{@position-try --fit{left:10px;top:10px}}',''],
 ['cascade-unlayered','@position-try --fit{left:40px;top:20px}@layer a{@position-try --fit{left:10px;top:10px}}',''],
 ['media','@position-try --fit{left:10px;top:10px}@media(width>500px){@position-try --fit{left:40px;top:20px}}',''],
 ['important-ignored','@position-try --fit{left:40px;top:20px;width:5px!important;background:red;height:22px}',''],
 ['important-author','@position-try --fit{left:40px;top:20px;width:5px;height:22px}','width:60px!important;'],
 ['variables','@position-try --fit{left:var(--x);top:20px;width:calc(anchor-size(width) + 5px);margin-left:3px}','--x:40px;'],
 ['fallback-size-invalid','@position-try --fit{left:40px;top:20px;width:anchor-size(--missing width)}',''],
 ['percent-margin','@position-try --fit{left:40px;top:20px;width:20px;margin-left:5%;margin-top:2%}',''],
 ['logical-margin','@position-try --fit{inset-inline-start:40px;inset-block-start:20px;width:20px;margin-inline-start:3px}',''],
 ['different-anchor','@position-try --fit{position-anchor:--b;left:anchor(left);top:anchor(bottom);width:anchor-size(width)}',''],
 ['named-case','@position-try --Fit{left:10px;top:10px}@position-try --fit{left:40px;top:20px}',''],
])add('named-'+name,edge+anchor('anchor-name:--b;position:absolute;left:40px;top:10px;margin:0;','other')+tip(overflowing+base+'position-try-fallbacks:--fit;'),rules);
add('anchor-math-insets',anchor()+tip('left:calc(anchor(--a right) + 7px);top:calc(anchor(--a bottom) + 5px);'));
add('margin-fallback-percent',anchor()+tip('margin-left:anchor-size(--missing width,5%);margin-top:anchor-size(--missing height,2%);'));
add('two-distinct-anchor-sizes',anchor()+anchor('anchor-name:--b;width:35px;','other')+tip('width:calc(anchor-size(--a width) + anchor-size(--b width));'));
add('no-default-anchor',anchor()+tip('left:anchor(left,13px);width:anchor-size(width,45px);'));
add('named-escaped-properties',edge+tip(overflowing+'position-try-fallbacks:--fit;'),'@position-try --fit{l\\65 ft:40px;t\\6f p:20px;w\\69 dth:30px}');
add('nested-size-fallback',anchor()+tip('width:anchor-size(--missing width,calc(anchor-size(--a width) + 5px));'));
add('nested-coordinate-fallback',anchor()+tip('left:anchor(--missing right,anchor(--a right));width:30px;'));
add('nested-size-coordinate-fallback',anchor()+tip('left:calc(anchor(--missing left,anchor-size(--a width)) + 5px);'));
add('nested-invalid-fallback',anchor()+tip('width:anchor-size(--missing width,anchor-size(--also-missing width));'));
add('escaped-none',anchor('anchor-name:--a;')+tip('left:anchor(--a left,13px);width:anchor-size(--a width,45px);position-try-fallbacks:\\6e one;'),'#anchor{anchor-name:\\6e one!important}');
add('escaped-all',`<div style="anchor-scope:\\61 ll;width:300px;height:60px">${anchor()}${tip('left:anchor(--a left,13px);width:anchor-size(--a width,45px);')}</div>${anchor('margin-left:160px;width:90px;','other')}`);
add('skipped-anchor',`<div style="content-visibility:hidden;width:100px;height:40px">${anchor()}</div>${tip('left:anchor(--a left,13px);width:anchor-size(--a width,45px);')}`);
for(const order of ['inside-before','inside-after','outside-before','outside-after']){
 const content=order==='inside-before'?tip('left:anchor(--a right);top:anchor(--a bottom);width:anchor-size(--a width);')+anchor():order==='inside-after'?anchor()+tip('left:anchor(--a right);top:anchor(--a bottom);width:anchor-size(--a width);'):anchor();
 const holder=`<div id="holder" style="position:absolute;left:130px;top:50px;width:200px;height:100px">${content}</div>`;
 const query=tip('left:anchor(--a right,13px);top:anchor(--a bottom,17px);width:anchor-size(--a width,45px);');
 add('nested-'+order,order==='outside-before'?query+holder:order==='outside-after'?holder+query:holder);
}
add('dynamic-size',anchor()+tip('left:anchor(--a right);top:anchor(--a bottom);width:anchor-size(--a width);'));
cases.at(-1).mutations=[70,105,35,70].map(width=>({target:'anchor',style:`anchor-name:--a;width:${width}px;height:30px;margin-left:40px;margin-top:10px`}));
add('dynamic-scope',`<div id="scope" style="width:300px;height:60px">${anchor()}${tip('left:anchor(--a left,13px);width:anchor-size(--a width,45px);')}</div>${anchor('margin-left:160px;width:90px;','other')}`);
cases.at(-1).mutations=['all','none','--a','none'].map(scope=>({target:'scope',style:`anchor-scope:${scope};width:300px;height:60px`}));
add('dynamic-choice',edge+tip(overflowing+'position-try-fallbacks:--left, --small;'),`@position-try --left{left:auto;right:anchor(left);top:anchor(top)}@position-try --small{left:10px;right:auto;top:10px;width:25px;height:20px}`);
cases.at(-1).mutations=[350,150,50,350].map(left=>({target:'anchor',style:`anchor-name:--a;position:absolute;left:${left}px;top:175px;width:40px;height:25px;margin:0`}));
add('dynamic-rule',edge+tip(overflowing+'position-try-fallbacks:--fit;'),`@position-try --fit{left:40px;top:20px;width:30px}`);
cases.at(-1).mutations=[75,45,85].map(left=>({target:'referenceSheet',append:`@position-try --fit{left:${left}px;top:20px;width:30px}`}));
add('dynamic-contents',`<div id="scope" style="display:contents;anchor-scope:all">${anchor()}${tip('left:anchor(--a left,13px);width:anchor-size(--a width,45px);')}</div>${anchor('margin-left:160px;width:90px;','other')}`);
cases.at(-1).mutations=['none','all','none','all'].map(scope=>({target:'scope',style:`display:contents;anchor-scope:${scope}`}));
add('dynamic-query-variable',anchor()+tip('position-anchor:--a;--scale:2;width:calc(anchor-size(width) * var(--scale));'));
cases.at(-1).mutations=[1,3,2].map(scale=>({target:'tip',style:`position:absolute;left:20px;top:60px;height:12px;position-anchor:--a;--scale:${scale};width:calc(anchor-size(width) * var(--scale))`}));
const orderRules='@position-try --wide{left:10px;right:auto;top:10px;bottom:auto}@position-try --tall{left:10px;right:200px;top:5px;bottom:auto}@position-try --tie{left:10px;right:auto;top:20px;bottom:auto}@position-try --bad{left:410px;right:0px;top:10px;width:0px}';
for(const mode of ['horizontal-tb','vertical-rl','vertical-lr'])for(const order of ['normal','most-width','most-height','most-inline-size','most-block-size']){
 add('order-'+mode+'-'+order,anchor('position:absolute;left:100px;top:120px;margin:0;')+tip('left:100px;top:120px;right:30px;bottom:10px;position-try-fallbacks:--wide, --tall, --tie;position-try-order:'+order),orderRules,'writing-mode:'+mode);
 add('order-shorthand-'+mode+'-'+order,tip('left:100px;top:120px;right:30px;bottom:10px;position-try:'+order+' --wide, --tall, --tie'),orderRules,'writing-mode:'+mode);
}
add('order-negative-space',tip('left:350px;width:80px;position-try:most-width --bad, --wide;'),orderRules);
add('order-stable-tie',tip('left:350px;width:80px;position-try:most-width --tie, --wide;'),orderRules);
add('order-missing-name',tip('left:350px;width:80px;position-try:most-width --missing, --wide;'),orderRules);
add('order-anchor-insets',anchor('position:absolute;left:100px;top:120px;margin:0;')+tip('position-anchor:--a;left:anchor(right);right:auto;top:anchor(bottom);bottom:auto;position-try:most-height flip-block, --wide;'),orderRules);
add('order-invalid-too-large',tip('left:350px;width:700px;position-try:most-width --wide, --tie;'),orderRules);
add('order-persistent',tip('left:100px;top:120px;right:30px;bottom:10px;position-try:most-width --wide, --tie'),orderRules);
cases.at(-1).mutations=[80,400,90,400].map(width=>({target:'root',style:'width:'+width+'px'}));
add('order-dynamic-input',tip('left:100px;top:120px;right:30px;bottom:10px;position-try:most-width --wide, --tall'),orderRules);
cases.at(-1).mutations=['most-height','normal','most-width','most-height'].map(order=>({target:'tip',style:'position:absolute;left:100px;top:120px;right:30px;bottom:10px;width:30px;height:12px;position-try:'+order+' --wide, --tall'}));
for(const mode of ['horizontal-tb','vertical-rl','vertical-lr'])for(const direction of ['ltr','rtl'])for(const own of ['ltr','rtl'])for(const margin of ['0','auto','1px auto','auto 2px'])add('overconstraint-'+mode+'-'+direction+'-'+own+'-'+margin,tip('left:100px;right:30px;top:120px;bottom:10px;width:70px;height:50px;direction:'+own+';margin:'+margin),'','writing-mode:'+mode+';direction:'+direction);
for(const [name,source]of [
 ['inherit','position-try:inherit'],['initial','position-try:initial'],['unset','position-try:unset'],['revert','position-try:revert'],
 ['variable','--options:most-height --wide, --tall;position-try:var(--options)'],['variable-components','--order:most-width;--choices:--wide, --tall;position-try:var(--order) var(--choices)'],
 ['invalid-variable','--options:red;position-try:var(--options)'],['invalid-variable-parts','--order:red;position-try:var(--order) --wide'],
 ['reset-order','position-try-order:most-height;position-try:--wide, --tall'],['longhand-after','position-try:most-width --wide, --tall;position-try-order:most-height'],
 ['important-longhand','position-try-order:most-height!important;position-try:most-width --wide, --tall'],['missing-variable-fallback','position-try:var(--missing,most-height --wide, --tall)'],
])add('order-cascade-'+name,tip('left:100px;top:120px;right:30px;bottom:10px;'+source),orderRules+'#root{position-try:most-height --wide, --tall}#tip{position-try:most-width --wide, --tall}');
add('order-revert-layer',tip('left:100px;top:120px;right:30px;bottom:10px;'),orderRules+'@layer a,b;@layer a{#tip{position-try:most-height --wide, --tall}}@layer b{#tip{position-try:most-width --wide;position-try:revert-layer}}');
add('negative-icb-zero-box',tip('left:350px;right:100px;top:10px;width:0px;height:0px;position-try-fallbacks:--wide'),orderRules);
(async()=>{
 const browser=await openBrowser(folder);
 try{
  const userAgent=await browser.evaluate('navigator.userAgent');
  const snapshot=`(()=>{const root=document.getElementById('root').getBoundingClientRect();return Array.from(document.querySelectorAll('#root, #root [id]')).map(el=>{const r=el.getBoundingClientRect(),s=getComputedStyle(el);let at=el.parentElement,skipped=false;while(at){if(getComputedStyle(at).contentVisibility==='hidden')skipped=true;at=at.parentElement}return{id:el.id,x:r.x-root.x,y:r.y-root.y,width:r.width,height:r.height,margin:s.margin,anchorName:s.anchorName,anchorScope:s.anchorScope,display:s.display,skipGeometry:skipped}})})()`;
  for(const scene of cases){
   scene.html=`<!doctype html><html><head><style id="referenceSheet">html,body{margin:0;padding:0}#root{position:relative;display:flow-root;width:400px;height:220px;${scene.rootStyle}}${scene.css}</style></head><body><div id="root">${scene.markup}</div></body></html>`;
   await browser.load(scene.html);
   scene.expected=await browser.evaluate(snapshot);
   if(scene.name==='nearest-ancestor')Object.assign(scene.expected.find(x=>x.id==='tip'),{normative:{x:0,width:120},deviation:'The September 2026 draft selects the nearest acceptable ancestor before the last element in tree order. Chromium still selects the last element.'});
   if(scene.name==='expression-empty-fallback')Object.assign(scene.expected.find(x=>x.id==='tip'),{normative:{width:70},deviation:'The September 2026 anchor-size grammar permits an empty optional name/size before the fallback comma. Chromium rejects this spelling.'});
   scene.steps=[];
   for(const mutation of scene.mutations||[]){
    await browser.evaluate(`(()=>{const el=document.getElementById(${JSON.stringify(mutation.target)});${mutation.append?`el.textContent+=${JSON.stringify(mutation.append)}`:`el.setAttribute('style',${JSON.stringify(mutation.style)})`}})()`);
    await browser.evaluate('new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))');
    const step={mutation,expected:await browser.evaluate(snapshot)};
    if(scene.name==='dynamic-contents'||scene.name==='order-dynamic-input'){
     const document=await browser.evaluate("'<!doctype html>'+document.documentElement.outerHTML");
     await browser.load(document);
     const fresh=await browser.evaluate(snapshot);
     for(const expected of step.expected){const other=fresh.find(x=>x.id===expected.id);const normative={};for(const field of ['x','y','width','height'])if(other[field]!==expected[field])normative[field]=other[field];if(Object.keys(normative).length)Object.assign(expected,{normative,deviation:scene.name==='dynamic-contents'?'Chromium retains the old anchor after an anchor-scope change on display:contents. Reloading the identical markup resolves the new scope; both raw snapshots are retained.':'Chromium retains the old position choice after changing position-try-order. The draft requires clearing fallback-sensitive changes; an independent reload of the identical markup chooses the new order. Both raw snapshots are retained.',reloaded:other});}
    }
    scene.steps.push(step);
   }
  }
  const syntax=[];
  for(const [property,values]of Object.entries({'anchor-name':['--a','--a, --b','--a --b','a','--','--käste','--k\\e4 ste','NONE'],'anchor-scope':['none','all','--a','--a, --b','--a --b','all, --a'],'width':['anchor-size()','anchor-size(,45px)','anchor-size(width --a)','calc(anchor-size(--a width) + 5px)','anchor-size(width height)','anchor(top)','calc(anchor(top) + 5px)'],'left':['anchor(--a left)','anchor(left --a)','anchor-size()','calc(anchor(--a left) + 5px)','anchor(--a left,25%)','anchor(--a width)'],'position-try-fallbacks':['--fit','--fit flip-inline','flip-inline --fit','--Fit, --fit','--fit --other','flip-inline flip-inline','flip-start','flip-x','flip-y','--fit,','--fit,,flip-inline']}))for(const value of values)syntax.push({property,value,accepted:await browser.evaluate(`CSS.supports(${JSON.stringify(property)},${JSON.stringify(value)})`)});
  for(const [property,values]of Object.entries({'position-try-order':['normal','most-width','most-height','most-inline-size','most-block-size','MOST-WIDTH','m\\6f st-width','most-width most-height','auto'],'position-try':['--fit','normal --fit','most-width --fit, flip-inline','normal none','none','most-height none','most-width','flip-inline most-width','most-width --fit,','MOST-WIDTH --Fit'],'font-size':['anchor-size(width)'],'padding-left':['anchor-size(width)'],'text-decoration-thickness':['anchor-size(width)']}))for(const value of values)syntax.push({property,value,accepted:await browser.evaluate(`CSS.supports(${JSON.stringify(property)},${JSON.stringify(value)})`)});
  for(const probe of syntax)if(probe.value==='anchor-size(,45px)')Object.assign(probe,{normativeAccepted:true,deviation:'Optional name/size before fallback comma in the September 2026 draft.'});
  await browser.load('<!doctype html><html><head></head><body></body></html>');
  const cssomSource=fs.readFileSync(path.join(root,'tests/fixtures/anchor-cssom-reference.js'),'utf8');
  const cssom=await browser.evaluate(cssomSource+'\nlog');
  fs.writeFileSync(path.join(root,'tests/fixtures/anchor-cssom-browser.json'),JSON.stringify(cssom,null,2)+'\n');
  fs.writeFileSync(path.join(root,'tests/fixtures/anchor-browser.json'),JSON.stringify({browser:userAgent,captured:'2026-10-09',source:'https://drafts.csswg.org/css-anchor-position/',cases,syntax},null,2)+'\n');
  console.log(`Anchors: ${cases.length} native layouts and ${syntax.length} syntax outcomes captured.`);
 }finally{await browser.close()}
})().catch(error=>{console.error(error);process.exitCode=1});
