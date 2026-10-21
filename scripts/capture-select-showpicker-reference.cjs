const fs=require('node:fs'),path=require('node:path');const {openBrowser}=require('./native-browser.cjs');
const cases=[];
const expression='(()=>{let error="",exception=false,result;const before=navigator.userActivation.isActive;const events=[];for(const type of ["click","input","change","focus"])target.addEventListener(type,()=>events.push(type));try{result=target.showPicker()}catch(e){error=e.name;exception=e instanceof DOMException}return {error,exception,resultUndefined:result===undefined,before,activeAfter:navigator.userActivation.isActive,open:target.matches(":open"),activeElement:document.activeElement.localName,events}})()';
for(const appearance of ['auto','base-select'])for(const [name,markup,prepare,activation]of [
 ['normal','<select id=s><option>A</option><option>B</option></select>','',true],
 ['no-activation','<select id=s><option>A</option></select>','',false],
 ['disabled','<select id=s disabled><option>A</option></select>','',true],
 ['disabled-no-activation','<select id=s disabled><option>A</option></select>','',false],
 ['fieldset-disabled','<fieldset disabled><select id=s><option>A</option></select></fieldset>','',true],
 ['first-legend','<fieldset disabled><legend><select id=s><option>A</option></select></legend></fieldset>','',true],
 ['hidden','<select id=s hidden><option>A</option></select>','',true],
 ['parent-hidden','<div hidden><select id=s><option>A</option></select></div>','',true],
 ['hidden-no-activation','<select id=s hidden><option>A</option></select>','',false],
 ['visibility-hidden','<select id=s style="visibility:hidden"><option>A</option></select>','',true],
 ['contents','<select id=s style="display:contents"><option>A</option></select>','',true],
 ['detached','<select id=s><option>A</option></select>','s.remove()',true],
 ['readonly','<select id=s readonly><option>A</option></select>','',true],
 ['multiple','<select id=s multiple><option>A</option><option>B</option></select>','',true],
 ['size-two','<select id=s size=2><option>A</option><option>B</option></select>','',true],
 ['empty','<select id=s></select>','',true],
 ['inert','<div inert><select id=s><option>A</option></select></div>','',true],
 ['zero','<select id=s style="width:0;height:0;padding:0;border:0"><option>A</option></select>','',true],
])cases.push({name:appearance+'/'+name,html:'<!doctype html><style>select{appearance:'+appearance+'}select::picker(select){appearance:'+appearance+'}</style>'+markup,prepare,activation});
async function main(){const folder=path.resolve(__dirname,'../build/select-showpicker-reference');fs.mkdirSync(folder,{recursive:true});const browser=await openBrowser(folder);const fixture={captured:'2026-10-10',standard:'https://html.spec.whatwg.org/multipage/input.html#show-the-picker-if-applicable',cases};
 try{fixture.browser=await browser.evaluate('navigator.userAgent');for(const c of cases){await browser.load(c.html);await browser.evaluate('window.target=document.getElementById("s");'+c.prepare.replaceAll('s.','target.'));
  const r=await browser.send('Runtime.evaluate',{userGesture:c.activation,returnByValue:true,expression});if(r.exceptionDetails)throw new Error(c.name+': '+r.exceptionDetails.text);c.expected=r.result.value;
 }
 fixture.descriptors=await browser.evaluate('(()=>{const d=Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype,"showPicker");let borrowed="";try{d.value.call(document.createElement("input"))}catch(e){borrowed=e.name}return {name:d.value.name,length:d.value.length,writable:d.writable,enumerable:d.enumerable,configurable:d.configurable,borrowed,same:target.showPicker===d.value}})()');
 fixture.frames=[];
 for(const kind of ['srcdoc','sandbox-srcdoc','data'])for(const activation of [false,true])for(const disabled of [false,true]){
  const child='<select id=s'+(disabled?' disabled':'')+'><option>A</option></select>';
  const markup=kind==='data'?'<iframe src="data:text/html,'+encodeURIComponent(child)+'"></iframe>':'<iframe '+(kind==='sandbox-srcdoc'?'sandbox="allow-scripts" ':'')+'srcdoc="'+child.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;')+'"></iframe>';
  await browser.load(markup);let frame,sessionId;
  for(let attempt=0;attempt<20&&!frame;attempt++){
   const tree=await browser.send('Page.getFrameTree');frame=tree.frameTree.childFrames?.[0]?.frame;
   if(!frame){const targets=await browser.send('Target.getTargets');const child=targets.targetInfos.find(t=>t.type==='iframe');if(child){({sessionId}=await browser.send('Target.attachToTarget',{targetId:child.targetId,flatten:true}));const tree=await browser.send('Page.getFrameTree',{},sessionId);frame=tree.frameTree.frame} else await new Promise(r=>setTimeout(r,25))}
  }
  if(!frame)throw new Error('Missing native child frame: '+kind);
  const world=await browser.send('Page.createIsolatedWorld',{frameId:frame.id,worldName:'select-showpicker-reference'},sessionId);
  const c={name:kind+'/'+activation+'/'+disabled,kind,activation,disabled};
  const actual=await browser.send('Runtime.evaluate',{contextId:world.executionContextId,returnByValue:true,expression:'({disabled:document.querySelector("select")?.disabled,html:document.body?.innerHTML})'},sessionId);
  if(actual.result.value.disabled!==disabled)throw new Error(c.name+' captured a stale child: '+JSON.stringify(actual.result.value));
  const r=await browser.send('Runtime.evaluate',{contextId:world.executionContextId,userGesture:activation,returnByValue:true,expression:'window.target=document.getElementById("s");'+expression},sessionId);
  if(r.exceptionDetails)throw new Error(c.name+': '+r.exceptionDetails.text);c.expected=r.result.value;fixture.frames.push(c);
  if(kind!=='srcdoc'&&disabled)c.specExpected={...c.expected,error:'InvalidStateError'};
  if(sessionId)await browser.send('Target.detachFromTarget',{sessionId});
 }
 fixture.interactions=[];
 for(const appearance of ['auto','base-select'])for(const action of ['escape','commit','repeat']){
  await browser.load('<style>select,select::picker(select){appearance:'+appearance+'}</style><button id=launch onclick="s.showPicker()">Start</button><select id=s><option value=a>A</option><option value=b>B</option></select>');
  const rect=await browser.evaluate('window.target=s;window.pickerEvents=[];for(let type of ["focus","blur","input","change"])document.addEventListener(type,e=>{if(e.target.localName!=="button")pickerEvents.push(type+":"+e.target.localName)},true);(()=>{let r=launch.getBoundingClientRect();return{x:r.x+r.width/2,y:r.y+r.height/2}})()');
  await browser.send('Input.dispatchMouseEvent',{type:'mousePressed',x:rect.x,y:rect.y,button:'left',clickCount:1});await browser.send('Input.dispatchMouseEvent',{type:'mouseReleased',x:rect.x,y:rect.y,button:'left',clickCount:1});
  const snapshot=()=>browser.evaluate('({open:target.matches(":open"),focus:document.activeElement.localName,value:target.value,events:pickerEvents.slice()})');
  const c={name:appearance+'/'+action,appearance,action,states:[await snapshot()]};
  async function key(key,code){await browser.send('Input.dispatchKeyEvent',{type:'keyDown',key,code:key,windowsVirtualKeyCode:code});await browser.send('Input.dispatchKeyEvent',{type:'keyUp',key,code:key,windowsVirtualKeyCode:code});}
  if(action==='commit'){await key('ArrowDown',40);c.states.push(await snapshot());await key('Enter',13)}
  else if(action==='escape')await key('Escape',27);
  else await browser.send('Runtime.evaluate',{userGesture:true,expression:'target.showPicker()'});
  c.states.push(await snapshot());fixture.interactions.push(c);
 }
 }finally{await browser.close()}
 fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/select-showpicker-browser.json'),JSON.stringify(fixture,null,2)+'\n');console.log('Select showPicker: '+cases.length+' native mutability/activation/render/list/no-op cases and native descriptor captured.');
}
main().catch(error=>{console.error(error);process.exitCode=1});
