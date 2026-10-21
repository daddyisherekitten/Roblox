const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),folder=path.join(root,'build/form-selectors-reference');fs.mkdirSync(folder,{recursive:true});
const cases=[];const add=(name,html,code)=>cases.push({name,html:'<!doctype html><body>'+html+'</body>',code});
const rangeChecks=`const p=document.getElementById('probe');record(p.matches(':in-range'),p.matches(':out-of-range'),p.value);p.value='';record(p.matches(':in-range'),p.matches(':out-of-range'),p.value);`;
for(const [type,min,max,inside,outside]of[
 ['number','3','7','4','9'],['range','3','7','4','9'],
 ['date','2026-10-09','2026-10-12','2026-10-10','2026-10-13'],
 ['datetime-local','2026-10-09T08:00','2026-10-09T16:00','2026-10-09T12:00','2026-10-09T20:00'],
 ['month','2026-03','2026-07','2026-04','2026-09'],
 ['week','2026-W03','2026-W07','2026-W04','2026-W09'],
 ['time','08:00','16:00','12:00','20:00'],
])for(const [variant,attrs]of[
 ['unbounded',`value="${inside}"`],['inside',`min="${min}" max="${max}" value="${inside}"`],
 ['outside',`min="${min}" max="${max}" value="${outside}"`],['disabled',`min="${min}" value="${outside}" disabled`],
 ['readonly',`min="${min}" value="${outside}" readonly`],['invalid limits',`min="bad" max="bad" value="${outside}"`],
])add(type+' '+variant,`<input id="probe" type="${type}" ${attrs}>`,rangeChecks);
for(const [name,html]of[
 ['Time crosses midnight','<input id="probe" type=time min="22:00" max="02:00" value="00:30">'],
 ['Time excluded midday','<input id="probe" type=time min="22:00" max="02:00" value="12:30">'],
 ['Number inverted range','<input id="probe" type=number min=20 max=10 value=15>'],
 ['Range inverted limits','<input id="probe" type=range min=20 max=10 value=15>'],
 ['Number step mismatch is in range','<input id="probe" type=number min=3 max=7 step=10 value=4>'],
 ['Disabled fieldset','<fieldset disabled><input id="probe" type=number min=3 max=7 value=4></fieldset>'],
 ['First legend exception','<fieldset disabled><legend><input id="probe" type=number min=3 max=7 value=4></legend></fieldset>'],
 ['Datalist descendant','<datalist><input id="probe" type=number min=3 max=7 value=4></datalist>'],
 ['Text does not have range','<input id="probe" type=text min=3 max=7 value=4>'],
])add(name,html,rangeChecks);
add('Range mutations','<input id="probe" type=number min=3 max=7 value=4>',`
const p=document.getElementById('probe');function snapshot(){record(p.matches(':in-range'),p.matches(':out-of-range'));}
snapshot();p.value='9';snapshot();p.max='10';snapshot();p.removeAttribute('min');p.removeAttribute('max');snapshot();p.type='range';snapshot();p.disabled=true;snapshot();p.disabled=false;p.readOnly=true;snapshot();p.readOnly=false;snapshot();`);
add('Defaults follow attributes, not current value','<input id=c type=checkbox checked><input id=r type=radio checked><select id=s><option id=a selected>A<option id=b selected>B</select>',`
const c=document.getElementById('c'),r=document.getElementById('r'),s=document.getElementById('s');
function snapshot(){record(Array.from(document.querySelectorAll(':default')).map(n=>n.id).join(','));}snapshot();c.checked=false;r.checked=false;s.value='A';snapshot();c.defaultChecked=false;document.getElementById('b').defaultSelected=false;snapshot();`);
add('Checked uses live selectedness','<input id=c type=checkbox checked><select id=s><option id=a selected>A<option id=b>B</select>',`
const c=document.getElementById('c'),s=document.getElementById('s');function snapshot(){record(Array.from(document.querySelectorAll(':checked')).map(n=>n.id).join(','));}snapshot();c.checked=false;s.value='B';snapshot();c.checked=true;s.selectedIndex=-1;snapshot();`);
add('First submit in tree order including external and disabled','<button id=external form=f disabled>External</button><form id=f><button id=reset type=reset>Reset</button><button id=first>First</button><input id=image type=image><input id=submit type=submit><button id=last>Last</button></form>',`
function snapshot(){record(Array.from(document.querySelectorAll(':default')).map(n=>n.id).join(','));}snapshot();document.getElementById('external').remove();snapshot();document.getElementById('first').type='button';snapshot();document.getElementById('image').setAttribute('form','missing');snapshot();document.getElementById('f').prepend(document.getElementById('last'));snapshot();`);
add('Detached form and false external owner','<form id=f><button id=first>First</button><button id=wrong form=missing>Wrong</button></form><button id=loose>Loose</button>',`
const f=document.getElementById('f'),b=document.getElementById('first'),w=document.getElementById('wrong'),loose=document.getElementById('loose');record(b.matches(':default'),w.matches(':default'),loose.matches(':default'));f.remove();record(b.matches(':default'),w.matches(':default'));`);
add('Auto button with command is not a submit','<form><button id=command command=--test>Command</button><button id=commandfor commandfor=target>Command for</button><button id=invalid type=unknown>Auto</button><button id=explicit type=submit command=--test>Submit</button></form>',`record(Array.from(document.querySelectorAll(':default')).map(n=>n.id).join(','));`);
const source=`<!doctype html><meta charset=utf-8><pre id="result"></pre><script>
const cases=${JSON.stringify(cases)};for(const c of cases){const d=new DOMParser().parseFromString(c.html,'text/html');c.expected=[];try{new Function('document','record',c.code)(d,(...values)=>c.expected.push(values.map(String).join('|')));}catch(e){c.error=e.name+': '+e.message;}}
document.getElementById('result').textContent=JSON.stringify({browser:navigator.userAgent,captured:'2026-10-09',standard:'https://html.spec.whatwg.org/multipage/semantics-other.html#pseudo-classes',cases});
</script>`;
const file=path.join(folder,'reference.html');fs.writeFileSync(file,source);
const result=cp.spawnSync(process.env.CHROME_BIN||'C:/Program Files/Google/Chrome/Application/chrome.exe',['--headless=new','--disable-gpu','--no-first-run','--disable-background-networking','--user-data-dir='+path.join(folder,'chrome-'+Date.now()),'--virtual-time-budget=10000','--dump-dom','file:///'+file.replaceAll('\\','/')],{encoding:'utf8',windowsHide:true,timeout:30000,maxBuffer:1024*1024});
if(result.error)throw result.error;if(result.status)throw new Error(result.stderr);
fs.writeFileSync(path.join(folder,'reference-result.html'),result.stdout);
const captured=result.stdout.match(/<pre id="result">([\s\S]*?)<\/pre>/);if(!captured||!captured[1])throw new Error('Reference page did not complete');
const fixture=JSON.parse(captured[1].replaceAll('&amp;','&').replaceAll('&lt;','<').replaceAll('&gt;','>'));for(const c of fixture.cases)if(c.error)throw new Error(c.name+': '+c.error);
// Keep the raw browser observations. These exact cases differ from the HTML
// minimum/maximum algorithm; never replace a whole family with engine output.
for(const c of fixture.cases){
 if(/^(number|date|datetime-local|month|week|time) (unbounded|invalid limits)$/.test(c.name)){
  const expected=[c.expected[0],'false|false|'];
  if(JSON.stringify(expected)!==JSON.stringify(c.expected)){c.standardExpected=expected;c.difference='A control without a defined minimum or maximum has no range limitations, even when empty. Chromium matches its empty value as :in-range.';}
 }else if(c.name==='Range inverted limits'){
  c.standardExpected=['false|true|20','false|true|20'];c.difference='The HTML maximum remains 10 when min is 20. Sanitization retains min=20 and the input suffers overflow; Chromium suppresses this overflow.';
 }
}
fs.writeFileSync(path.join(root,'tests/fixtures/form-selectors-browser.json'),JSON.stringify(fixture,null,2)+'\n');console.log('Form selectors: '+fixture.cases.length+' native sequences captured.');
