// Native evidence for mounted hidden/visible reversals; auto/offscreen is separate.
const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..');
const applicability={url:'https://drafts.csswg.org/css-contain-2/#content-visibility',version:'CSSWG source 2026-06-23, before the frozen target 2026-10-06; checked 2026-10-11',commit:'9b290faedc95e9f93648fb5f5c675c75508c2d14',source:'https://raw.githubusercontent.com/w3c/csswg-drafts/9b290faedc95e9f93648fb5f5c675c75508c2d14/css-contain-2/Overview.bs',sha256:'5a8dbbd4c6a8bccd661c5bb7b66275da9cfb5a93b206f2124cc6f60cfd6ccc4d',applicabilityChange:'https://github.com/w3c/csswg-drafts/commit/5cf431ca4d20bab1496da8bb55e9d05446d31015'};
const source=`<!doctype html><style>
body{margin:0;font:16px/20px Arial}#owner{width:240px;height:140px;background:#fcdddd}
#inside{width:90px;height:20px}#editor{display:block;appearance:none;box-sizing:border-box;width:130px;height:24px;border:0;padding:0;margin:0;font:inherit}
#group{height:20px}#nested{height:20px}#nestedChild{width:25px;height:12px;background:blue}
#fixed{position:fixed;top:170px;left:15px;width:24px;height:18px;background:green}
#abs{position:absolute;top:80px;left:10px;width:15px;height:10px;background:orange}
#details{margin:0}summary{height:20px}#detailChild{height:10px}
#after{height:8px;width:17px;background:red}</style>
<div id=owner tabindex=0><div id=inside>AB CD</div><input id=editor value="A🙂BC"><img id=image src="asset:picture" width=20 height=15 alt="">
<div id=group><span style="opacity:.5">EF <em>GH</em></span></div>
<div id=nested><div id=nestedChild></div></div><details id=details open><summary>Title</summary><div id=detailChild>IJ</div></details>
<div id=fixed></div><div id=abs></div></div><div id=after></div><script></script>`;
const operations=[
 ['focus','window.savedEditor=document.getElementById("editor");savedEditor.focus();savedEditor.setSelectionRange(1,4)'],
 ['hidden','document.getElementById("owner").style.contentVisibility="hidden"'],
 ['hidden-focus','savedEditor.focus();document.getElementById("inside").style.background="blue"'],
 ['visible','document.getElementById("owner").style.contentVisibility="visible"'],
 ['refocus','savedEditor.focus();savedEditor.setSelectionRange(1,4)'],
 ['hidden-mutation','document.getElementById("owner").style.contentVisibility="hidden";document.getElementById("inside").textContent="KL MN";const cvNew=document.createElement("div");cvNew.id="inserted";cvNew.style.cssText="height:11px;width:19px";document.getElementById("owner").appendChild(cvNew)'],
 ['reveal-mutation','document.getElementById("owner").style.contentVisibility="visible"'],
 ['nested-hidden','document.getElementById("nested").style.contentVisibility="hidden"'],
 ['outer-hidden','document.getElementById("owner").style.contentVisibility="hidden"'],
 ['nested-visible-under-hidden','document.getElementById("nested").style.contentVisibility="visible";document.getElementById("details").open=false'],
 ['outer-visible','document.getElementById("owner").style.contentVisibility="visible"'],
 ['details-open','document.getElementById("details").open=true'],
 ['select','savedEditor.blur();window.cvRange=document.createRange();cvRange.selectNodeContents(document.getElementById("inside"));getSelection().removeAllRanges();getSelection().addRange(cvRange)'],
 ['selection-hidden','document.getElementById("owner").style.contentVisibility="hidden"'],
 ['selection-restored','document.getElementById("owner").style.contentVisibility="visible"'],
];
(async()=>{
 const specResponse=await fetch(applicability.source);if(!specResponse.ok)throw Error('Pinned Contain source: '+specResponse.status);const spec=await specResponse.text();require('node:assert/strict').equal(require('node:crypto').createHash('sha256').update(spec).digest('hex'),applicability.sha256);require('node:assert/strict').ok(spec.includes('Applies to: elements for which [=size containment=] can apply'));
 const browser=await openBrowser(path.join(root,'build'));const result={standard:'https://www.w3.org/TR/2022/WD-css-contain-2-20220917/#content-visibility',applicability,source,states:[],deferred:[],extra:[],normativeDeltas:[{case:'table-cell',states:['initial','hide'],nativeHeight:20,normativeHeight:35,nativeInsideHit:'owner',normativeInsideHit:'inside',reason:'The pinned applicability supplement excludes internal table boxes; Chromium still skips a table-cell subtree. Visible cell controls supply the unskipped geometry.'}],hostDeltas:[{case:'link',state:'tab-hidden',nativeActive:'body',engineActive:'editor',reason:'Tab after the last focusable page element exits into browser chrome. Roblox currently cycles within the page. A separate next-control case proves hidden-link exclusion without that host boundary.'}]};
 try{
  result.browser=await browser.send('Browser.getVersion');await browser.send('Emulation.setDeviceMetricsOverride',{width:800,height:600,deviceScaleFactor:1,mobile:false});
  async function snapshot(name,operation){
   await browser.evaluate('new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))');
   return browser.evaluate(`(()=>{const editor=document.getElementById('editor'),out={name:${JSON.stringify(name)},operation:${JSON.stringify(operation)},active:document.activeElement.id||document.activeElement.localName,editor:{same:!window.savedEditor||editor===savedEditor,value:editor.value,start:editor.selectionStart,end:editor.selectionEnd},selection:getSelection().toString(),items:{}};for(const id of ['owner','inside','nested','nestedChild','fixed','abs','details','detailChild','inserted','after']){const e=document.getElementById(id);if(!e)continue;const r=e.getBoundingClientRect();out.items[id]={rect:[r.x,r.y,r.width,r.height],visibility:getComputedStyle(e).contentVisibility}}const h=document.elementFromPoint(20,175);out.fixedHit=h&&h.id;return out})()`);
  }
  await browser.load(source);for(const [name,operation]of operations){await browser.evaluate(operation);result.states.push(await snapshot(name,operation))}
  await browser.load(source.replace('<div id=owner tabindex=0>','<div id=owner tabindex=0 style="content-visibility:hidden">'));
  for(const [name,operation]of [['initial','void 0'],['mutate-hidden','document.getElementById("inside").textContent="OP QR";const cvDeferred=document.createElement("div");cvDeferred.id="inserted";cvDeferred.style.cssText="height:11px;width:19px";document.getElementById("owner").appendChild(cvDeferred)'],['first-reveal','document.getElementById("owner").style.contentVisibility="visible"'],['hide-again','document.getElementById("owner").style.contentVisibility="hidden"'],['remove-hidden','document.getElementById("inserted").remove()'],['second-reveal','document.getElementById("owner").style.contentVisibility="visible"']]){await browser.evaluate(operation);result.deferred.push(await snapshot(name,operation))}
  const common='<style>body{margin:0;font:16px/20px Arial}#owner{width:120px;content-visibility:hidden;border:0;padding:0;margin:0;border-collapse:collapse;border-spacing:0}td{padding:0;border:0;height:20px;width:60px}summary{height:20px}#detailChild{height:10px}</style><input id=editor value="A🙂BC">';
  for(const [name,markup]of [
   ['table','<table id=owner><tbody><tr><td id=inside>AA</td><td>BB</td></tr></tbody></table>'],
   ['anonymous-table','<div id=owner style="display:table"><span id=inside style="display:table-cell;width:60px;height:20px">AA</span><span style="display:table-cell;width:60px;height:20px">BB</span></div>'],
   ['table-cell','<table style="border-collapse:collapse"><tbody><tr><td id=owner><div id=inside style="height:35px">AA</div></td><td>BB</td></tr></tbody></table>'],
   ['table-row','<table style="border-collapse:collapse"><tbody><tr id=owner><td id=inside>AA</td><td>BB</td></tr></tbody></table>'],
   ['table-group','<table style="border-collapse:collapse"><tbody id=owner><tr><td id=inside>AA</td><td>BB</td></tr></tbody></table>'],
   ['table-role-transition','<div id=owner style="display:table"><span id=inside style="display:table-cell;width:60px;height:20px">AA</span><span style="display:table-cell;width:60px;height:20px">BB</span></div>'],
   ['deferred-to-table','<div id=owner style="display:block"><span id=inside style="display:table-cell;width:60px;height:20px">AA</span><span style="display:table-cell;width:60px;height:20px">BB</span></div>'],
   ['fieldset','<fieldset id=owner style="min-width:0"><legend id=inside style="height:20px;padding:0">Title</legend><div id=detailChild>IJ</div></fieldset>'],
   ['link','<div id=owner><a id=inside href="#after" style="display:block;height:20px">Go</a></div><div id=after></div>'],
   ['link-with-next-control','<div id=owner><a id=inside href="#after" style="display:block;height:20px">Go</a></div><div id=after></div><input id=tail value="Next">'],
   ['details','<details id=owner><summary id=inside>Title</summary><div id=detailChild>IJ</div></details>'],
  ]){
   const record={name,source:'<!doctype html>'+common+markup+'<script></script>',states:[]};await browser.load(record.source);
   const sequence=name==='table-role-transition'||name==='deferred-to-table'?[['initial','void 0'],['block-hidden','document.getElementById("owner").style.display="block"'],['table-again','document.getElementById("owner").style.display="table"'],['second-block-hidden','document.getElementById("owner").style.display="block"'],['second-table','document.getElementById("owner").style.display="table"']]:[['initial','void 0'],['reveal','document.getElementById("owner").style.contentVisibility="visible"'],['hide','document.getElementById("owner").style.contentVisibility="hidden"'],['second-reveal','document.getElementById("owner").style.contentVisibility="visible"']];
   if(name==='details')sequence.push(['open','document.getElementById("owner").open=true'],['hide-open','document.getElementById("owner").style.contentVisibility="hidden"'],['reveal-open','document.getElementById("owner").style.contentVisibility="visible"']);
   if(name==='link'||name==='link-with-next-control')sequence.push(['tab','document.getElementById("editor").focus()','Tab'],['hide-focused','document.getElementById("owner").style.contentVisibility="hidden"'],['hidden-focus','document.getElementById("inside").focus()'],['tab-hidden','document.getElementById("editor").focus()','Tab'],['last-reveal','document.getElementById("owner").style.contentVisibility="visible"'],['last-tab','document.getElementById("editor").focus()','Tab']);
   for(const [label,operation,key]of sequence){await browser.evaluate(operation);if(key){await browser.send('Input.dispatchKeyEvent',{type:'keyDown',key,code:key,windowsVirtualKeyCode:9});await browser.send('Input.dispatchKeyEvent',{type:'keyUp',key,code:key,windowsVirtualKeyCode:9})}const state=await snapshot(label,operation);if(key)state.key=key;state.insideHit=await browser.evaluate(`(()=>{const r=document.getElementById('inside').getBoundingClientRect(),e=document.elementFromPoint(r.x+r.width/2,r.y+r.height/2);return e&&e.id})()`);record.states.push(state)}result.extra.push(record);
  }
 }finally{await browser.close()}
 const fixture=path.join(root,'tests/fixtures/content-visibility-browser.json');if(fs.existsSync(fixture)){const previous=JSON.parse(fs.readFileSync(fixture,'utf8')),assert=require('node:assert/strict');assert.deepEqual(result.states,previous.states);assert.deepEqual(result.deferred,previous.deferred);for(const old of previous.extra||[]){const current=result.extra.find(c=>c.name===old.name);assert.ok(current);assert.deepEqual(current.source,old.source);assert.deepEqual(current.states.map(({insideHit,...s})=>s),old.states.map(({insideHit,...s})=>s))}}
 fs.writeFileSync(fixture,JSON.stringify(result,null,2)+'\n');console.log('Content visibility native reference: '+result.states.length+' retained + '+result.deferred.length+' deferred + '+result.extra.reduce((n,c)=>n+c.states.length,0)+' table/details states.');
})().catch(error=>{console.error(error);process.exitCode=1});
