// Isolated native geometry for automatic column-flex cross sizes. Font advances
// are measured independently; Roblox glyph raster equality is not asserted.
const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..');
const words='ALPHA BETA GAMMA DELTA EPSILON';
function html(owner,child='',text=words){return '<!doctype html><style>body{margin:0;font:16px/20px monospace;font-kerning:none}#caption{display:block}input{display:block;appearance:none;box-sizing:border-box;width:50px;height:22px;border:0;padding:0;font:inherit}</style><div id=owner style="display:flex;flex-direction:column;align-items:start;width:120px;'+owner+'"><div id=caption style="'+child+'">'+text+'</div><input id=editor value=retained></div><script></script>';}
const cases=[];
for(const align of ['start','end','center','stretch','flex-start'])cases.push({name:'column '+align,html:html('align-items:'+align)});
for(const child of ['margin-left:auto','margin:3px 7px 5px 9px;border:2px solid;padding:4px','min-width:130px;max-width:170px','width:90px','width:max-content','width:min-content','width:fit-content','min-width:min-content','min-width:0;max-width:90px','min-width:170px;max-width:90px','min-width:20%;max-width:50%','padding:5%;margin:2%;border:2px solid','inline-size:auto;min-inline-size:30px;max-inline-size:90px','width:75px;--auto:auto;width:var(--auto)','width:90px;width:var(--missing)'])cases.push({name:child,html:html('',child)});
cases.push({name:'column-reverse center',html:html('flex-direction:column-reverse;align-items:center')});
cases.push({name:'column wrap declaration without line break',wrapWithoutLineBreak:true,html:html('flex-wrap:wrap;height:150px')});
cases.push({name:'unbreakable minimum',html:html('','','ABCDEFGHIJKLMNOPQRSTUV')});
cases.push({name:'anonymous column text',anonymous:true,html:html('').replace('<div id=caption style="">'+words+'</div>',words)});
const sequence=[
 'flexOwner.style.width="40px"','flexOwner.style.width="120px"','flexOwner.style.width="400px"','flexOwner.style.width="80px"',
 'flexOwner.style.width="120px";flexCaption.style.width="90px"','flexCaption.style.width="auto"','flexCaption.style.width="min-content"','flexCaption.style.width="max-content"','flexCaption.style.width="fit-content"',
 'flexCaption.style.cssText="width:90px;width:var(--missing)"','flexCaption.style.cssText="width:90px;--auto:auto;width:var(--auto)"',
 'flexCaption.style.cssText="min-width:130px;max-width:170px"','flexOwner.style.width="40px"','flexCaption.style.cssText="min-width:170px;max-width:90px"',
 'flexOwner.style.width="120px";flexCaption.style.cssText="margin:3px 7px 5px 9px;border:2px solid;padding:4px"',
 'flexCaption.style.cssText="padding:5%;margin:2%;border:2px solid"','flexOwner.style.width="400px"','flexCaption.style.cssText=""',
 'flexOwner.style.fontFamily="Arial"','flexOwner.style.width="80px";flexOwner.style.fontSize="20px";flexOwner.style.lineHeight="25px"','flexOwner.style.width="120px"',
 'flexOwner.style.fontFamily="monospace";flexOwner.style.fontSize="16px";flexOwner.style.lineHeight="20px"',
];
const setup='globalThis.flexOwner=document.getElementById("owner");globalThis.flexCaption=document.getElementById("caption");globalThis.flexEditor=document.getElementById("editor");flexEditor.value="edited";flexEditor.focus();flexEditor.setSelectionRange(1,4,"backward")';
const read='(()=>{const rect=e=>{const r=e.getBoundingClientRect();return[r.x,r.y,r.width,r.height]};return{boxes:["owner","caption","editor"].map(id=>{const e=document.getElementById(id);if(!e)return null;const s=getComputedStyle(e);return{id,rect:rect(e),values:["width","height","min-width","max-width","font-family","font-size","line-height","font-kerning"].map(n=>s.getPropertyValue(n)),author:["width","min-width","max-width","inline-size","min-inline-size","max-inline-size"].map(n=>e.style.getPropertyValue(n))}}),editor:[flexEditor===document.getElementById("editor"),flexEditor.value,flexEditor.selectionStart,flexEditor.selectionEnd,flexEditor.selectionDirection,document.activeElement===flexEditor]}})()';
(async()=>{
 const browser=await openBrowser(path.join(root,'build/flex-auto-cross-native'));const fixture={captured:'2026-10-10',standards:['https://drafts.csswg.org/css-flexbox-1/#cross-sizing','https://drafts.csswg.org/css-sizing-3/#fit-content-size'],cases,sequence,setup};
 try{
  fixture.browser=await browser.evaluate('navigator.userAgent');
  await browser.load(html(''));
  fixture.metricProfile={fontKerning:'none',measurement:'Native unwrapped DOM advance for individual words/space; geometry calibration, not Roblox glyph/shaping parity.'};
  fixture.bounds=await browser.evaluate(`(()=>{const out={};for(const family of ['monospace','Arial']){out[family]={};for(const size of [16,17,20,21]){const measured={};for(const text of ${JSON.stringify([...words.split(' '),' ','0','ABCDEFGHIJKLMNOPQRSTUV'])}){const e=document.createElement('span');e.style.cssText='display:inline-block;white-space:pre;font:'+size+'px '+family+';font-kerning:none';e.textContent=text;document.body.appendChild(e);measured[text]=e.getBoundingClientRect().width;e.remove()}out[family][size]=measured;}}return out})()`);
  for(const item of cases){await browser.load(item.html);await browser.evaluate(setup);item.states=[];for(const width of [40,120,400,80]){await browser.evaluate('flexOwner.style.width='+JSON.stringify(width+'px'));item.states.push({width,expected:await browser.evaluate(read)});}}
  fixture.dynamic={html:html(''),states:[]};await browser.load(fixture.dynamic.html);await browser.evaluate(setup);
  for(const code of sequence){await browser.evaluate(code);fixture.dynamic.states.push({code,expected:await browser.evaluate(read)});}
  const alignmentControl={name:'column self-start (parser/alignment outside this bounded fit-content suite)',html:html('align-items:self-start'),states:[]};await browser.load(alignmentControl.html);await browser.evaluate(setup);for(const width of [40,120,400,80]){await browser.evaluate('flexOwner.style.width='+JSON.stringify(width+'px'));alignmentControl.states.push({width,expected:await browser.evaluate(read)});}fixture.openControls=[alignmentControl];
  const shapingControl={name:'Arial shared word/space shaping (C04, outside fit-content geometry calibration)',html:html('width:400px;font-family:Arial').replace('font-kerning:none','')};await browser.load(shapingControl.html);await browser.evaluate(setup);shapingControl.expected=await browser.evaluate(read);shapingControl.advances=await browser.evaluate(`(()=>{const e=document.getElementById('caption'),out={};for(const text of ${JSON.stringify([...words.split(' '),' ',words])}){const q=document.createElement('span');q.style.cssText='display:inline-block;white-space:pre;font:inherit';q.textContent=text;e.appendChild(q);out[text]=q.getBoundingClientRect().width;q.remove()}return out})()`);fixture.openControls.push(shapingControl);
 }finally{await browser.close()}
 fs.writeFileSync(path.join(root,'tests/fixtures/flex-auto-cross-browser.json'),JSON.stringify(fixture,null,2)+'\n');
 console.log('Column flex auto cross: '+cases.length+' cases / '+cases.reduce((n,c)=>n+c.states.length,0)+' native resize states plus '+sequence.length+' retained CSSOM/font/editor states.');
})().catch(e=>{console.error(e);process.exitCode=1});
