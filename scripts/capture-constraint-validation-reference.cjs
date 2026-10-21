const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),folder=path.join(root,'build/constraint-validation-reference');fs.mkdirSync(folder,{recursive:true});
const cases=[];
const code=`const p=document.getElementById('p');
function snapshot(){const v=p.validity;record(p.willValidate,v.valid,v.valueMissing,v.rangeUnderflow,v.rangeOverflow,v.stepMismatch,v.customError,p.matches(':valid'),p.matches(':invalid'),p.checkValidity());}
snapshot();p.setCustomValidity('custom');snapshot();p.setAttribute('readonly','');snapshot();p.removeAttribute('readonly');snapshot();p.setCustomValidity('');snapshot();p.disabled=true;snapshot();`;
for(const type of ['text','search','url','tel','email','password','number','range','color','date','month','week','time','datetime-local','checkbox','radio','file','hidden','submit','reset','button','image']){
  cases.push({name:'Eligibility and custom validity: '+type,html:`<!doctype html><input id=p type="${type}" required>`,code});
}
for(const [name,html]of[
  ['Textarea','<textarea id=p required></textarea>'],
  ['Dropdown placeholder','<select id=p required><option value="">Choose</option><option value=b>B</option></select>'],
  ['Grouped empty value is a valid option','<select id=p required><optgroup label=X><option value="" selected>Empty</option></optgroup></select>'],
  ['List empty value is a valid option','<select id=p required size=3><option value="" selected>Empty</option></select>'],
  ['Multiple no selected option','<select id=p required multiple><option>A</option></select>'],
  ['Submit button','<button id=p>Submit</button>'],['Reset button','<button id=p type=reset>Reset</button>'],['Plain button','<button id=p type=button>Button</button>'],
  ['Disabled fieldset','<fieldset disabled><input id=p required></fieldset>'],
  ['First legend exemption','<fieldset disabled><legend><input id=p required></legend></fieldset>'],
  ['Datalist excludes validation','<datalist><input id=p required></datalist>'],
  ['Number underflow','<input id=p type=number min=3 max=7 value=2>'],
  ['Number step mismatch','<input id=p type=number min=3 max=7 step=2 value=4>'],
  ['Range inverted limits','<input id=p type=range min=20 max=10 value=15>'],
  ['Radio group required on a peer','<input id=p type=radio name=g><input type=radio name=g required>'],
  ['Radio group selected peer','<input id=p type=radio name=g required><input type=radio name=g checked>'],
])cases.push({name,html:'<!doctype html>'+html,code});
for(const [name,type,pattern,values,multiple]of[
  ['Whole value anchoring','text','[A-Z]{2}',['AB','ZAB','ABZ','A',''],false],
  ['Empty pattern','text','',['','A'],false],
  ['Invalid standalone pattern','text',')$|^(?:a',['a','b'],false],
  ['Invalid character class','text','[',['a','b'],false],
  ['Unicode property intersection','text','[\\p{Letter}&&\\p{ASCII}]+',['A','é','42'],false],
  ['Unicode class subtraction','text','[a-z--[aeiou]]+',['bcdf','abc','ae'],false],
  ['Unicode strings','text','[\\q{ab|cd}]+',['ab','cdab','ac'],false],
  ['Astral Unicode code point','text','\\p{Emoji}', ['😀','😀😀','A'],false],
  ['Email list checks each value','email','.+@example\\.test',['a@example.test,b@example.test','a@example.test,b@other.test',''],true],
  ['Multiple ignored for text','text','a,b',['a,b','a','b'],true],
  ['Number ignores pattern','number','[A-Z]+',['12','34',''],false],
  ['Search uses pattern','search','a+',['a','aaa','b'],false],
  ['URL uses pattern','url','https://.+',['https://example.test','http://example.test'],false],
  ['Telephone uses pattern','tel','[0-9]{3}',['123','12','abc'],false],
  ['Password uses pattern','password','.{3}',['123','12','😀A'],false],
])cases.push({name:'Pattern: '+name,html:`<!doctype html><input id=p type=${type} pattern="${pattern.replaceAll('&','&amp;').replaceAll('"','&quot;')}"${multiple?' multiple':''}>`,code:`const p=document.getElementById('p');for(const value of ${JSON.stringify(values)}){p.value=value;const v=p.validity;record(p.value,v.patternMismatch,v.typeMismatch,v.valid,p.matches(':valid'),p.matches(':invalid'),p.checkValidity());}`});
cases.push({name:'Pattern: attribute/type changes and poisoned user RegExp',html:'<!doctype html><input id=p pattern="[A-Z]+" value=AB>',code:`const p=document.getElementById('p'),oldRegExp=globalThis.RegExp,oldExec=RegExp.prototype.exec;function snapshot(){record(p.validity.patternMismatch,p.validity.valid,p.matches(':invalid'));}snapshot();p.pattern='[0-9]+';snapshot();p.pattern='[';snapshot();p.pattern='[A-Z]+';snapshot();RegExp.prototype.exec=()=>null;globalThis.RegExp=function(){throw new Error('User replacement must not be called');};snapshot();globalThis.RegExp=oldRegExp;RegExp.prototype.exec=oldExec;p.type='number';snapshot();p.type='text';p.value='AB';snapshot();p.removeAttribute('pattern');snapshot();`});
const file=path.join(folder,'reference.html');fs.writeFileSync(file,`<!doctype html><meta charset=utf-8><pre id=result></pre><script>
const cases=${JSON.stringify(cases).replaceAll('<','\\u003c')};for(const c of cases){const d=new DOMParser().parseFromString(c.html,'text/html');c.expected=[];try{new Function('document','record',c.code)(d,(...v)=>c.expected.push(v.map(String).join('|')));}catch(e){c.error=e.name+': '+e.message;}}
document.getElementById('result').textContent=JSON.stringify({browser:navigator.userAgent,captured:'2026-10-09',standard:'https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#the-constraint-validation-api',cases});</script>`);
const result=cp.spawnSync(process.env.CHROME_BIN||'C:/Program Files/Google/Chrome/Application/chrome.exe',['--headless=new','--disable-gpu','--no-first-run','--disable-background-networking','--user-data-dir='+path.join(folder,'chrome-'+Date.now()),'--virtual-time-budget=10000','--dump-dom','file:///'+file.replaceAll('\\','/')],{encoding:'utf8',windowsHide:true,timeout:30000,maxBuffer:1024*1024});
if(result.error)throw result.error;if(result.status)throw new Error(result.stderr);
fs.writeFileSync(path.join(folder,'reference-result.html'),result.stdout);
const captured=result.stdout.match(/<pre id="result">([\s\S]*?)<\/pre>/);if(!captured||!captured[1])throw new Error('Reference did not complete');
const fixture=JSON.parse(captured[1].replaceAll('&amp;','&').replaceAll('&lt;','<').replaceAll('&gt;','>'));for(const c of fixture.cases)if(c.error)throw new Error(c.name+': '+c.error);
const inverted=fixture.cases.find(c=>c.name==='Range inverted limits');
inverted.standardExpected=inverted.expected.map(record=>{
  const v=record.split('|');v[1]='false';v[4]='true';v[7]='false';v[8]=v[0]==='true'?'true':'false';v[9]=v[0]==='true'?'false':'true';return v.join('|');
});
inverted.standardDifference='The maximum remains 10 when min=20. Sanitization keeps min=20, which suffers overflow; Chromium 154 suppresses that flag. Readonly/disabled still bar validation and both CSS states.';
fs.writeFileSync(path.join(root,'tests/fixtures/constraint-validation-browser.json'),JSON.stringify(fixture,null,2)+'\n');console.log('Constraint validation: '+fixture.cases.length+' native sequences captured.');
