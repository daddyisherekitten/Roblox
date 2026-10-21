// Fixed boxes isolate position alignment from font shaping and intrinsic sizing.
// Capture raw Chromium results; do not replace native geometry with projections.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..');
const keywords=['start','end','self-start','self-end','flex-start','flex-end'];
const names=['align-items','align-self','justify-items','justify-self','justify-content','direction','writing-mode'];
function html(owner,a='',b='',extra=''){
 return '<!doctype html><style>body{margin:0;font:16px/20px Arial}#owner{width:200px;height:140px;gap:7px}#a,#b{box-sizing:border-box;flex:none;min-width:0;min-height:0;width:44px;height:26px;grid-area:1/1}#b{width:32px;height:18px}#editor{display:block;appearance:none;box-sizing:border-box;width:55px;height:22px;border:0;padding:0;margin:0;font:inherit}'+extra+'</style><div id="stage" style="padding:200px 0 0 240px"><div id="owner" style="'+owner+'"><div id="a" style="'+a+'"></div><div id="b" style="'+b+'"></div></div><input id="editor" value="A🙂BC"><div id="guard" style="width:17px;height:8px"></div></div><script></script>';
}
const cases=[];
function itemCase(name,owner,a,b,field,values=keywords){
 cases.push({name,html:html(owner,a,b),sequence:values.map(v=>'alignmentOwner.style.'+field+'Items='+JSON.stringify(v)+';alignmentB.style.'+field+'Self='+JSON.stringify(v))});
}
for(const flow of ['row','row-reverse','column','column-reverse'])for(const direction of ['ltr','rtl'])for(const childDirection of ['ltr','rtl']){
 itemCase('flex '+flow+' '+direction+'/'+childDirection,'display:flex;flex-direction:'+flow+';direction:'+direction,'direction:'+childDirection,'direction:'+childDirection,'align');
}
for(const flow of ['row','column'])for(const direction of ['ltr','rtl'])for(const childDirection of ['ltr','rtl']){
 itemCase('flex wrap-reverse '+flow+' '+direction+'/'+childDirection,'display:flex;flex-direction:'+flow+';flex-wrap:wrap-reverse;direction:'+direction,'direction:'+childDirection,'direction:'+childDirection,'align');
}
const grid='display:grid;grid-template-columns:120px;grid-template-rows:90px;';
for(const direction of ['ltr','rtl'])for(const childDirection of ['ltr','rtl'])for(const axis of ['align','justify']){
 itemCase('grid '+axis+' '+direction+'/'+childDirection,grid+'direction:'+direction+';align-items:center;justify-items:center','direction:'+childDirection,'direction:'+childDirection,axis,axis==='justify'?[...keywords,'left','right']:keywords);
}
for(const mode of ['vertical-rl','vertical-lr','sideways-rl','sideways-lr'])for(const childDirection of ['ltr','rtl'])for(const direction of ['ltr','rtl']){
 const child='writing-mode:'+mode+';direction:'+childDirection;
 for(const flow of ['row','column'])itemCase('orthogonal flex '+flow+' '+direction+'/'+mode+'/'+childDirection,'display:flex;flex-direction:'+flow+';direction:'+direction,child,child,'align',['self-start','self-end']);
 for(const axis of ['align','justify'])itemCase('orthogonal grid '+axis+' '+direction+'/'+mode+'/'+childDirection,grid+'direction:'+direction+';align-items:center;justify-items:center',child,child,axis,['self-start','self-end']);
}
for(const model of ['flex','grid'])for(const direction of ['ltr','rtl'])for(const axis of ['x','y'])for(const margin of ['before','after','both'])for(const oversized of [false,true]){
 const horizontal=axis==='x';const auto=(horizontal?['left','right']:['top','bottom']).filter((_,i)=>margin==='both'||i===(margin==='before'?0:1)).map(n=>'margin-'+n+':auto').join(';');
 const owner=model==='grid'?grid+'direction:'+direction+';place-items:end':
  'display:flex;flex-direction:'+(horizontal?'column':'row')+';direction:'+direction+';align-items:end';
 const size=oversized?(horizontal?'width:230px':'height:170px'):'';
 const child=auto+';'+size+';direction:'+(direction==='ltr'?'rtl':'ltr');
 const name=model+' auto '+axis+' '+margin+' '+direction+(oversized?' oversized':'');
 cases.push({name,html:html(owner,child,'display:none'),sequence:['']});
 if(model==='grid'&&oversized){
  // Grid2 §11.2 requires overflowing auto margins to become zero, then
  // normal box alignment. Chromium currently retains a start-side fallback.
  // Keep that raw result and capture the specified zero-margin equivalent.
  const zero=child.replace(/margin-(left|right|top|bottom):auto/g,'margin-$1:0');
  cases.push({name:'grid zero-margin normative control '+axis+' '+margin+' '+direction,normativeFor:name,html:html(owner,zero,'display:none'),sequence:['']});
 }
}
for(const model of ['flex','grid'])for(const direction of ['ltr','rtl'])for(const flow of model==='flex'?['row','row-reverse','column','column-reverse']:['grid'])for(const negative of [false,true]){
 const owner=model==='grid'?'display:grid;grid-template-columns:40px 30px;grid-template-rows:50px;direction:'+direction:
  'display:flex;flex-direction:'+flow+';direction:'+direction;
 cases.push({name:model+' content '+flow+' '+direction+(negative?' negative':''),html:html(owner+(negative?';width:50px;height:35px':''),'grid-area:1/1','grid-area:1/2'),sequence:['start','end','flex-start','flex-end','left','right','center'].map(v=>'alignmentOwner.style.justifyContent='+JSON.stringify(v))});
}
cases.push({name:'grid physical margins and two tracks rtl',html:html('display:grid;direction:rtl;grid-template-columns:60px 80px;grid-template-rows:90px;justify-content:start;align-items:start','margin:3px 9px 5px 7px;grid-area:1/1','grid-area:1/2'),sequence:['left','right','self-start','self-end'].map(v=>'alignmentOwner.style.justifyItems='+JSON.stringify(v))});
const setup='globalThis.alignmentOwner=document.getElementById("owner");globalThis.alignmentA=document.getElementById("a");globalThis.alignmentB=document.getElementById("b");globalThis.alignmentEditor=document.getElementById("editor");alignmentEditor.value="A🙂BC";alignmentEditor.focus();alignmentEditor.setSelectionRange(1,3,"backward")';
const read='(()=>{return{boxes:["owner","a","b","editor","guard"].map(id=>{const e=document.getElementById(id),s=getComputedStyle(e),r=e.getBoundingClientRect();return{id,rect:[r.x,r.y,r.width,r.height],values:'+JSON.stringify(names)+'.map(n=>s.getPropertyValue(n)),style:e.getAttribute("style")||"",className:e.className}}),tracks:[getComputedStyle(alignmentOwner).gridTemplateColumns,getComputedStyle(alignmentOwner).gridTemplateRows],editor:[alignmentEditor===document.getElementById("editor"),alignmentEditor.value,alignmentEditor.selectionStart,alignmentEditor.selectionEnd,alignmentEditor.selectionDirection,document.activeElement===alignmentEditor]}})()';
const dynamic={name:'retained class variable direction and layout context',html:html('flex-direction:column;align-items:var(--side)','direction:rtl','align-self:auto','\n#owner{display:flex;--side:self-start}#owner.turn{--side:self-end}#owner.grid{display:grid;grid-template-columns:120px;grid-template-rows:90px;justify-items:var(--side)}'),sequence:[
 '', 'alignmentOwner.className="turn"', 'alignmentOwner.style.setProperty("--side","self-start")', 'alignmentA.style.direction="ltr"',
 'alignmentOwner.style.direction="rtl"', 'alignmentOwner.style.removeProperty("--side")', 'alignmentOwner.className="grid"',
 'alignmentOwner.style.setProperty("--side","self-end")', 'alignmentA.style.direction="rtl"', 'alignmentOwner.style.width="260px"',
 'alignmentOwner.className="";alignmentOwner.style.direction="ltr";alignmentOwner.style.width="200px";alignmentOwner.style.removeProperty("--side")',
 'alignmentOwner.style.flexDirection="row-reverse";alignmentOwner.style.flexWrap="wrap-reverse";alignmentA.style.writingMode="vertical-rl"',
 'alignmentA.style.direction="ltr"', 'alignmentA.style.direction="rtl"',
 'alignmentOwner.style.flexDirection="column";alignmentOwner.style.flexWrap="nowrap";alignmentA.style.writingMode="horizontal-tb"',
 'alignmentEditor.value="B🙂CD";alignmentEditor.setSelectionRange(1,3,"backward")'
]};
const dynamicContent={name:'retained content class variable CSSOM direction and free space',html:html('flex-direction:row','grid-area:1/1','grid-area:1/2','\n#owner{display:flex;--content:start;justify-content:var(--content)}#owner.turn{--content:end}#owner.grid{display:grid;grid-template-columns:40px 30px;grid-template-rows:50px}'),sequence:[
 '', 'alignmentOwner.className="turn"', 'alignmentOwner.style.setProperty("--content","left")',
 'alignmentOwner.style.direction="rtl"', 'alignmentOwner.style.setProperty("--content","right")',
 'alignmentOwner.style.width="50px";alignmentOwner.style.height="35px"',
 'alignmentOwner.className="grid turn";alignmentOwner.style.removeProperty("--content")',
 'alignmentOwner.style.justifyContent="start"', 'alignmentOwner.style.removeProperty("justify-content")',
 'alignmentOwner.style.setProperty("--content","left")', 'alignmentOwner.style.direction="ltr"',
 'alignmentOwner.style.width="200px";alignmentOwner.style.height="140px"',
 'alignmentOwner.className="";alignmentOwner.style.removeProperty("--content")',
 'alignmentOwner.style.flexDirection="column-reverse";alignmentOwner.style.setProperty("--content","right")',
 'alignmentOwner.style.direction="rtl"', 'alignmentEditor.value="B🙂CD";alignmentEditor.setSelectionRange(1,3,"backward")'
]};
const dynamicSelf={name:'retained own self class variable direction and layout context',html:html('flex-direction:column;align-items:center;justify-items:center','align-self:auto;justify-self:auto','align-self:var(--side);justify-self:var(--side);direction:rtl','\n#owner{display:flex;--side:self-start}#owner.turn{--side:self-end}#owner.grid{display:grid;grid-template-columns:120px;grid-template-rows:90px}'),sequence:[
 '', 'alignmentOwner.className="turn"', 'alignmentB.style.setProperty("--side","self-start")', 'alignmentB.style.direction="ltr"',
 'alignmentOwner.style.direction="rtl"', 'alignmentB.style.removeProperty("--side")', 'alignmentOwner.className="grid"',
 'alignmentB.style.setProperty("--side","self-end")', 'alignmentB.style.direction="rtl"', 'alignmentOwner.style.width="260px"',
 'alignmentOwner.className="";alignmentOwner.style.direction="ltr";alignmentOwner.style.width="200px";alignmentB.style.removeProperty("--side")',
 'alignmentOwner.style.flexDirection="row-reverse";alignmentOwner.style.flexWrap="wrap-reverse";alignmentB.style.writingMode="vertical-rl"',
 'alignmentB.style.direction="ltr"', 'alignmentB.style.direction="rtl"',
 'alignmentOwner.style.flexDirection="column";alignmentOwner.style.flexWrap="nowrap";alignmentB.style.writingMode="horizontal-tb"',
 'alignmentEditor.value="B🙂CD";alignmentEditor.setSelectionRange(1,3,"backward")'
]};
(async()=>{
 const browser=await openBrowser(path.join(root,'build/position-alignment-native'));
 const fixture={captured:'2026-10-11',scope:'Horizontal containers; physical fixed orthogonal item boxes. Padded stage keeps overflow away from inaccessible root scroll edges. No vertical container sizing, safe/unsafe, glyph shaping or full shorthand grammar claim.',standards:['https://www.w3.org/TR/2026/WD-css-align-3-20260130/','https://www.w3.org/TR/2025/CRD-css-flexbox-1-20251014/#cross-alignment','https://www.w3.org/TR/2025/CRD-css-grid-2-20250326/#auto-margins'],names,setup,cases,dynamic,dynamicContent,dynamicSelf};
 try{
  fixture.browser=await browser.evaluate('navigator.userAgent');
  for(const item of [...cases,dynamic,dynamicContent,dynamicSelf]){
   await browser.load(item.html);await browser.evaluate(setup);item.states=[];
   for(const code of item.sequence){if(code)await browser.evaluate(code);item.states.push({code,expected:await browser.evaluate(read)});}delete item.sequence;
  }
 }finally{await browser.close()}
 const target=path.join(root,'tests/fixtures/position-alignment-browser.json');
 if(fs.existsSync(target)){
  const previous=JSON.parse(fs.readFileSync(target,'utf8'));
  // New controls can be appended; recorded raw states cannot silently drift.
  for(const old of [...previous.cases,previous.dynamic,previous.dynamicContent,previous.dynamicSelf].filter(Boolean)){
   const current=[...cases,dynamic,dynamicContent,dynamicSelf].find(c=>c.name===old.name);
   assert.ok(current,'Removed native control '+old.name);assert.deepEqual(current.states,old.states,'Changed preserved raw native states '+old.name);
  }
 }
 fs.writeFileSync(target,JSON.stringify(fixture,null,2)+'\n');
 console.log('Position alignment: '+cases.length+' cases / '+cases.reduce((n,c)=>n+c.states.length,0)+' raw native states plus '+(dynamic.states.length+dynamicContent.states.length+dynamicSelf.states.length)+' retained mutation states.');
})().catch(e=>{console.error(e);process.exitCode=1});
