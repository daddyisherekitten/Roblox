const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const cases=[];
const caption='<span id=caption>ALPHA BETA GAMMA DELTA EPSILON</span>';
const editor='<input id=editor value=retained>';
function add(name,display,content,extra=''){
 cases.push({name,html:'<!doctype html><style>body{margin:0}#owner{width:250px;font:16px/20px "Courier New"}#atomic{display:'+display+';max-width:150px;border:2px solid;padding:4px;vertical-align:top;'+extra+'}#caption{display:block}input{display:block;appearance:none;box-sizing:border-box;width:50px;height:22px;border:0;padding:0;font:inherit}#nested{display:inline-flex;max-width:90px;flex-direction:column}#nested span{display:block}</style><div id=owner>Before <span id=atomic>'+content+'</span> after</div>',styles:['','width:min-content','width:max-content','width:fit-content','min-width:100px;max-width:120px','margin:3px 7px 5px 9px']});
}
add('Inline block with live editor','inline-block',caption+editor);
add('Inline flex column with live editor','inline-flex',caption+editor,'flex-direction:column;align-items:start;');
add('Inline grid with fixed tracks and live editor','inline-grid',caption+editor,'grid-template-columns:70px 60px;gap:8px;align-items:start;');
add('Nested inline flex in an inline block','inline-block','<span id=caption>ALPHA <span id=nested><span>BETA GAMMA DELTA</span>'+editor+'</span> EPSILON</span>');
add('Nested inline grid in an inline flex','inline-flex','<span id=caption>ALPHA <span id=nested style="display:inline-grid;grid-template-columns:50px 40px;gap:4px"><span>BETA GAMMA DELTA</span>'+editor+'</span> EPSILON</span>','flex-direction:column;');
add('Explicit percentage containing inline line','inline-block',caption+editor,'width:44%;');
add('Logical fit and physical constraints','inline-block',caption+editor,'inline-size:fit-content;min-inline-size:80px;max-inline-size:130px;');
add('Block-axis fit, margins and retained scrollport','inline-block',caption.replace('id=caption','id=caption style="height:30px;overflow:auto"')+editor,'block-size:fit-content;margin:2px 5px 6px 7px;');
cases.at(-1).profileDifferences={states:{'2':['atomic','caption']},reason:'The existing min-content width does not include the native intrinsic scrollbar gutter. Scrollbar appearance/width is a separate host profile.'};
add('Tracked glyphs and bordered inline text','inline-block',caption.replace('>ALPHA',' style="letter-spacing:2px">ALPHA').replace('BETA','<span style="border:1px solid;padding:1px 3%">BETA</span>')+editor);
cases.at(-1).profileDifferences={states:{'2':['atomic','caption']},reason:'The existing independently rendered letter-spacing profile omits native trailing tracking in min-content width (2px in this capture). Full CSS Text tracking edges remain open.'};
(async()=>{
 const browser=await openBrowser(path.resolve(__dirname,'../build/layout-atomic-reference'));
 const fixture={captured:'2026-10-10',standards:['https://drafts.csswg.org/css-sizing-3/#intrinsic','https://drafts.csswg.org/css-inline-3/#atomic-inline'],cases};
 try{
  fixture.browser=await browser.evaluate('navigator.userAgent');
  fixture.glyphWidths=await browser.evaluate('(()=>{const c=document.createElement("canvas").getContext("2d");c.font="16px Courier New";return {"16":c.measureText("A").width}})()');
  for(const c of cases){
   await browser.load(c.html);c.expected=[];
   for(const style of c.styles){
    c.expected.push(await browser.evaluate(`(async()=>{const t=document.getElementById('atomic'),editor=document.getElementById('editor');t.style.cssText=${JSON.stringify(style)};editor.focus();editor.value='edited';editor.setSelectionRange(1,4,'backward');const read=()=>({boxes:['owner','atomic','caption','nested','editor'].map(id=>{const e=document.getElementById(id);if(!e)return null;const r=e.getBoundingClientRect(),s=getComputedStyle(e);return {id,rect:[r.x,r.y,r.width,r.height],client:[e.clientWidth,e.clientHeight],scroll:[e.scrollWidth,e.scrollHeight],values:['width','height','min-width','max-width','display'].map(n=>s.getPropertyValue(n))}}),editor:[editor.value,editor.selectionStart,editor.selectionEnd,editor.selectionDirection,document.activeElement.id]});const before=read();for(let i=0;i<8;i++){getComputedStyle(t).width;t.getBoundingClientRect();editor.getBoundingClientRect();await new Promise(requestAnimationFrame);if(JSON.stringify(read())!==JSON.stringify(before))throw new Error('Read-only measurements changed retained layout or editor state')}return before})()`));
   }
  }
 }finally{await browser.close()}
 fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/layout-atomic-browser.json'),JSON.stringify(fixture,null,2)+'\n');
 console.log('Atomic layout: '+cases.length+' cases, '+cases.reduce((n,c)=>n+c.styles.length,0)+' native geometry/editor states with eight unchanged read frames.');
})().catch(error=>{console.error(error);process.exitCode=1});
