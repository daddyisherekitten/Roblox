const fs=require('node:fs'),path=require('node:path');const {openBrowser}=require('./native-browser.cjs');
const fields=['display','content-visibility','visibility'];const cases=[];
const controls=[['div','<div id=s><span id=child>Content</span></div>'],['span','<span id=s>Content</span>'],['select','<select id=s><option>A</option></select>'],['embed','<embed id=s>'],['input-hidden','<input id=s type=hidden>'],['table','<table id=s><tbody><tr><td>Cell</td></tr></tbody></table>'],['col','<table><colgroup><col id=s></colgroup><tbody><tr><td>Cell</td></tr></tbody></table>'],['colgroup','<table><colgroup id=s><col></colgroup><tbody><tr><td>Cell</td></tr></tbody></table>'],['tbody','<table><tbody id=s><tr><td>Cell</td></tr></tbody></table>'],['tr','<table><tbody><tr id=s><td>Cell</td></tr></tbody></table>'],['svg','<svg><rect id=s width=40 height=20></rect></svg>']];
for(const [tag,markup]of controls)for(const value of ['', 'UnTiL-FoUnD'])cases.push({name:tag+'/'+value,html:'<!doctype html>'+markup,value});
for(const value of ['false','until-found ',' until-found','unknown'])cases.push({name:'div/invalid-token/'+value,html:'<!doctype html><div id=s>Content</div>',value});
cases.push({name:'div/namespaced-hidden',html:'<!doctype html><div id=s>Content</div>',value:'',namespace:'urn:other'});
async function main(){const browser=await openBrowser(path.resolve(__dirname,'../build/hidden-reference'));const fixture={captured:'2026-10-10',standard:'https://html.spec.whatwg.org/multipage/rendering.html#hidden-elements',nativeDifference:'Chromium implements hidden as an author presentational hint; the HTML rendering UA rules instead survive author revert and collapse hidden table columns/groups/rows.',nativeImplementation:'https://raw.githubusercontent.com/chromium/chromium/main/third_party/blink/renderer/core/html/html_element.cc',fields,cases};
 try{fixture.browser=await browser.evaluate('navigator.userAgent');for(const c of cases){await browser.load(c.html);c.states=[];
  const states=[['hidden',`target.setAttributeNS(${JSON.stringify(c.namespace||null)},'hidden',${JSON.stringify(c.value)})`],['author-override',`target.style.cssText='display:block;content-visibility:visible;visibility:visible'`],['revert',`target.style.cssText='display:revert;content-visibility:revert;visibility:revert'`],['remove',`target.removeAttributeNS(${JSON.stringify(c.namespace||null)},'hidden')`]];
  for(const [action,script]of states){const expected=await browser.evaluate(`window.target=document.getElementById('s');${script};Object.fromEntries(${JSON.stringify(fields)}.map(k=>[k,getComputedStyle(target).getPropertyValue(k)]))`);c.states.push({action,script,expected})}
  if(!c.namespace&&!c.name.startsWith('svg/'))for(const state of c.states){
   if(state.action!=='hidden'&&state.action!=='revert')continue;
   const normative={...state.expected},tag=c.name.split('/')[0],until=c.value.toLowerCase()==='until-found';
   if(state.action==='revert'&&tag!=='embed'){if(until)normative['content-visibility']='hidden';else normative.display='none'}
   if(['col','colgroup','tbody','tr'].includes(tag)){normative.display=c.states.find(s=>s.action==='remove').expected.display;normative.visibility='collapse'}
   if(JSON.stringify(normative)!==JSON.stringify(state.expected))state.specExpected=normative;
  }
 }
 }finally{await browser.close()}
 fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/hidden-browser.json'),JSON.stringify(fixture,null,2)+'\n');console.log('Hidden UA: '+cases.length*4+' native HTML/namespace/table/override/revert/mutation states captured.');
}main().catch(e=>{console.error(e);process.exitCode=1});
