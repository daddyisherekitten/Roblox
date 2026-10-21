const fs=require('node:fs'),path=require('node:path');const{openBrowser}=require('./native-browser.cjs');
const types=['hidden','text','search','tel','url','email','password','date','month','week','time','datetime-local','number','range','color','checkbox','radio','file','submit','image','reset','button'];
const initial='<form id=f><input id=s name=field value="42" checked min=1 max=10 step=2 minlength=2 maxlength=4><input id=peer type=radio name=field checked></form><button id=next>Next</button>';
const snapshot=`[s.type,s.value,s.defaultValue,s.getAttribute('value'),s.checked,s.defaultChecked,s.indeterminate,s.selectionStart,s.selectionEnd,s.selectionDirection,s.validity.badInput,s.validity.rangeUnderflow,s.validity.rangeOverflow,s.validity.stepMismatch,s.willValidate,peer.checked].map(String).join('|')`;
function platformDirection(value){const parts=value.split('|');if(parts[9]==='forward')parts[9]='none';return parts.join('|')}
async function main(){const browser=await openBrowser(path.resolve(__dirname,'../build/input-type-reference'));const fixture={captured:'2026-10-10',standard:'https://html.spec.whatwg.org/multipage/input.html#attr-input-type',types,initial,snapshot,cases:[],focus:[],badInput:[]};
 try{fixture.browser=await browser.evaluate('navigator.userAgent');await browser.load('<!doctype html>');
 fixture.cases=await browser.evaluate(`(()=>{const types=${JSON.stringify(types)},html=${JSON.stringify(initial)},cases=[];for(const from of types)for(const to of types)for(const dirty of [false,true]){
  document.body.innerHTML=html;const s=document.getElementById('s'),peer=document.getElementById('peer');s.type=from;
  if(dirty){if(from!=='file')s.value='7.5';s.checked=false;s.indeterminate=true;if(s.selectionStart!==null)s.setSelectionRange(1,2,'backward')}
  const before=${snapshot};s.type=to;const changed=${snapshot};document.getElementById('f').reset();const reset=${snapshot};cases.push({from,to,dirty,before,changed,reset});
 }return cases})()`);
 for(const [from,to]of [['text','password'],['password','text'],['text','number'],['number','text'],['text','checkbox'],['checkbox','text'],['text','hidden'],['hidden','text'],['date','text'],['text','date'],['text','file'],['file','text'],['range','text'],['text','range'],['text','image'],['image','text']]){
  await browser.load('<!doctype html>'+initial);
  await browser.evaluate(`(async()=>{globalThis.s=document.getElementById('s');globalThis.peer=document.getElementById('peer');s.type=${JSON.stringify(from)};globalThis.events=[];for(const type of ['focus','blur','input','change','select'])s.addEventListener(type,()=>events.push(type));s.focus();if(s.selectionStart!==null)s.setSelectionRange(1,2,'backward');await new Promise(resolve=>requestAnimationFrame(resolve));events=[]})()`);
  const code=`s.type=${JSON.stringify(to)};JSON.stringify({active:document.activeElement.id,snapshot:${snapshot},events})`;
  const expected=JSON.parse(await browser.evaluate(code));
  const afterFlush=JSON.parse(await browser.evaluate(`(async()=>{void s.offsetWidth;await new Promise(resolve=>requestAnimationFrame(resolve));return JSON.stringify({active:document.activeElement.id,snapshot:${snapshot},events})})()`));
 fixture.focus.push({from,to,expected,afterFlush});
 }
 for(const to of types){
  await browser.load('<!doctype html>'+initial);
  await browser.evaluate("globalThis.s=document.getElementById('s');globalThis.peer=document.getElementById('peer');s.type='number';s.value='';s.focus()");
  await browser.send('Input.insertText',{text:'-'});
  const before=await browser.evaluate(snapshot);
  const changed=await browser.evaluate(`s.type=${JSON.stringify(to)};${snapshot}`);
  fixture.badInput.push({to,before,changed,platformExpected:{before:platformDirection(before),changed:platformDirection(changed)}});
 }
 }finally{await browser.close()}
 fixture.engineSelectionProfile={defaultDirection:'none',nativePlatformDirection:'forward',standard:'https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#concept-textarea/input-selection-direction'};
 const defaultModes=new Set(['hidden','submit','reset','button','image','checkbox','radio']);
 for(const c of fixture.cases){c.platformExpected={before:platformDirection(c.before),changed:platformDirection(c.changed),reset:platformDirection(c.reset)};
  const prior=c.before.split('|'),actual=c.changed.split('|');
  if(!defaultModes.has(c.from)&&c.from!=='file'&&defaultModes.has(c.to)&&prior[1]!==''&&actual[3]!==prior[1]){
   c.specExpected={...c.platformExpected};for(const state of ['changed','reset']){const parts=c.specExpected[state].split('|');parts[1]=parts[2]=parts[3]=prior[1];c.specExpected[state]=parts.join('|')}
  }
  const changed=(c.specExpected||c.platformExpected).changed.split('|'),reset=(c.specExpected||c.platformExpected).reset.split('|');
  if(changed[7]!=='null'&&changed[1]!==reset[1]){
   const standardReset=reset.slice();standardReset[7]=String(Math.min(Number(changed[7]),reset[1].length));standardReset[8]=String(Math.min(Number(changed[8]),reset[1].length));standardReset[9]=changed[9];
   if(standardReset.join('|')!==reset.join('|')){c.resetSelectionDifference=true;c.specExpected={...(c.specExpected||c.platformExpected),reset:standardReset.join('|')};}
  }
 }
 fixture.nativeTypeDifference='Chromium preserves unsanitized pristine value attributes when range/color switch to default/default-on mode. HTML type-change step1 instead copies the current nonempty value, irrespective of the dirty flag.';
 for(const c of fixture.focus){c.platformExpected={...c.afterFlush,snapshot:platformDirection(c.afterFlush.snapshot)};
  if(c.from==='text'&&c.to==='hidden'&&!c.afterFlush.events.includes('blur'))c.specExpected={...c.platformExpected,events:['blur']};
 }
 fixture.nativeFocusDifference='Chromium clears the focused input when type becomes hidden without blur. HTML update-the-rendering instead runs focusing steps when the focused area ceases to be focusable; the retained element receives blur.';
 fixture.focusStandard='https://html.spec.whatwg.org/multipage/webappapis.html#update-the-rendering';
 fixture.nativeResetDifference='Chromium connected controls collapse selection to the end on value-changing reset. The HTML input reset algorithm changes the value; the relevant-value-change algorithm preserves its previous range and direction, clamping only positions beyond the new end. Detached native controls already follow this clamp behavior.';
 fixture.selectionResetStandard='https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#concept-textarea/input-relevant-value';
 fs.writeFileSync(path.resolve(__dirname,'../tests/fixtures/input-type-browser.json'),JSON.stringify(fixture,null,2)+'\n');console.log('Input type: '+fixture.cases.length+' native pair/dirty/reset, '+fixture.focus.length+' focus and '+fixture.badInput.length+' real invalid numeric input sequences captured.');
}main().catch(e=>{console.error(e);process.exitCode=1});
