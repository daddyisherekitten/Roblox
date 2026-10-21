/* Shared author scripts for R03; this script only writes reference fixtures. */
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const fixtures=[
 {name:'form-associated value snapshots and disabled ownership',source:`
const calls=[];
class R03Field extends HTMLElement {
 static formAssociated=true;
 constructor(){super();this.internals=this.attachInternals();const r=this.attachShadow({mode:'closed'});r.innerHTML='<span><input value=seed></span><slot></slot>';this.editor=r.querySelector('input');this.internals.setFormValue('initial');}
 formAssociatedCallback(f){calls.push('form:'+String(f&&f.id));}
 formDisabledCallback(v){calls.push('disabled:'+v);this.editor.disabled=v;}
 formResetCallback(){calls.push('reset');this.editor.value='seed';this.internals.setFormValue('initial');}
}
customElements.define('r03-field',R03Field);
document.body.innerHTML='<form id=f><fieldset id=fs><label for=c>Note</label><r03-field id=c name=note></r03-field></fieldset></form>';
const c=document.getElementById('c'),f=document.getElementById('f'),fs=document.getElementById('fs'),i=c.internals;
record([i.form===f,f.elements.length,f.elements[1]===c,i.labels.length,i.labels[0].textContent,i.shadowRoot!==null,c.shadowRoot===null].join('|'));
record(new FormData(f).get('note'));
const data=new FormData();data.append('one','A');data.append('two','B');i.setFormValue(data,'saved');data.set('one','changed');
record([...new FormData(f)].map(v=>v.join('=')).join('|'));
fs.disabled=true;record([i.willValidate,new FormData(f).has('one'),c.editor.disabled].join('|'));fs.disabled=false;
c.editor.value='edited';f.reset();record([c.editor.value,new FormData(f).get('note')].join('|'));
c.remove();record(i.form===null);record(calls.join('|'));
`,expected:['true|2|true|1|Note|true|true','initial','one=A|two=B','false|false|true','seed|initial','true','form:f|disabled:true|disabled:false|reset|form:null']},
 {name:'live internals validity invalid events and validation anchors',source:`
class R03Valid extends HTMLElement{static formAssociated=true;constructor(){super();this.i=this.attachInternals();this.attachShadow({mode:'open'}).innerHTML='<input>'}}
customElements.define('r03-valid',R03Valid);document.body.innerHTML='<form id=f><r03-valid id=c></r03-valid></form>';const f=document.getElementById('f'),c=document.getElementById('c'),i=c.i,v=i.validity;let invalid=0;c.addEventListener('invalid',e=>{invalid++;record([e.target===c,e.bubbles,e.cancelable].join('|'));e.preventDefault()});
record([v.valid,i.willValidate,i.validationMessage,i.validity===v].join('|'));try{i.setValidity({customError:true})}catch(e){record(e.name)};record(v.valid);
i.setValidity({customError:true},'wrong\\r\\nline',c.shadowRoot.firstChild);record([v.valid,v.customError,i.validationMessage==='wrong\\nline',c.matches(':invalid')].join('|'));record(f.checkValidity());record(invalid);
try{i.setValidity({valueMissing:true},'missing',document.body)}catch(e){record(e.name)};record([v.valueMissing,v.customError,i.validationMessage].join('|'));i.setValidity({});record([v.valid,c.matches(':valid'),f.checkValidity()].join('|'));c.setAttribute('readonly','');record([i.willValidate,c.matches(':valid'),c.matches(':invalid')].join('|'));
`,expected:['true|true||true','TypeError','true','false|true|true|true','true|false|true','false','1','NotFoundError','false|true|wrong\nline','true|true|true','false|true|false']},
 {name:'internals attachment brands default aria and custom states',source:`
class R03Plain extends HTMLElement{constructor(){super();this.i=this.attachInternals()}}customElements.define('r03-plain',R03Plain);const c=new R03Plain(),i=c.i,s=i.states;record([i instanceof ElementInternals,s instanceof CustomStateSet,i.shadowRoot===null,s===i.states].join('|'));for(const fn of [()=>c.attachInternals(),()=>document.createElement('div').attachInternals(),()=>i.setFormValue('x'),()=>i.checkValidity(),()=>ElementInternals.prototype.checkValidity.call({})]){try{fn();record('none')}catch(e){record(e.name)}}
i.role='checkbox';i.ariaChecked='false';record([i.role,i.ariaChecked,c.hasAttribute('role'),c.hasAttribute('aria-checked')].join('|'));record(s.add('busy')===undefined);s.add('other');s.add('busy');record([s.size,c.matches(':state(busy)'),[...s].join(','),[...s.entries()].map(v=>v.join(':')).join('|')].join(';'));record(s.delete('busy'));record(c.matches(':state(busy)'));s.clear();record(s.size);
`,expected:['true|true|true|true','NotSupportedError','NotSupportedError','NotSupportedError','NotSupportedError','TypeError','checkbox|false|false|false','true','2;true;busy,other;busy:busy|other:other','true','false','0']},
 {name:'scoped registry isolation null initialization and constructor stacks',source:`
const a=new CustomElementRegistry(),b=new CustomElementRegistry();class R03A extends HTMLElement{constructor(){super();this.mark='A'}}class R03B extends HTMLElement{constructor(){super();this.mark='B'}}a.define('r03-scope',R03A);b.define('r03-scope',R03B);const h=document.createElement('div');document.body.append(h);const r=h.attachShadow({mode:'open',customElementRegistry:a});r.innerHTML='<r03-scope></r03-scope>';record([r.firstChild instanceof R03A,r.firstChild.mark,customElements.get('r03-scope')===undefined].join('|'));const cb=document.createElement('r03-scope',{customElementRegistry:b});r.append(cb);record([cb instanceof R03B,cb.mark].join('|'));try{new R03A();record('none')}catch(e){record(e.name)};try{a.define('r03-button',class extends HTMLButtonElement{},{extends:'button'});record('none')}catch(e){record(e.name)};
const deferred=document.createElement('r03-scope',{customElementRegistry:null});record(!(deferred instanceof R03A));a.initialize(deferred);record(deferred instanceof R03A);b.initialize(deferred);record(deferred instanceof R03A);
const nullHost=document.createElement('div'),nullRoot=nullHost.attachShadow({mode:'open',customElementRegistry:null});nullRoot.innerHTML='<r03-scope></r03-scope>';record(!(nullRoot.firstChild instanceof R03A));a.initialize(nullRoot);record(nullRoot.firstChild instanceof R03A);
`,expected:['true|A|true','true|B','TypeError','none','true','true','true','true','true']},
 {name:'registry definition snapshots disabled internals and unicode names',source:`
class R03Off extends HTMLElement{static disabledFeatures=['internals'];}customElements.define('r03-off',R03Off);try{new R03Off().attachInternals()}catch(e){record(e.name)};for(const name of ['r03-a?b','r03-a@b','r03-a\\b','r03-A','r03-ä']){try{customElements.define(name,class extends HTMLElement{});record('ok')}catch(e){record(e.name)}};const calls=[];class R03Snapshot extends HTMLElement{static formAssociated=true;formResetCallback(){calls.push('initial')}}customElements.define('r03-snapshot',R03Snapshot);R03Snapshot.formAssociated=false;R03Snapshot.prototype.formResetCallback=function(){calls.push('changed')};document.body.innerHTML='<form><r03-snapshot></r03-snapshot></form>';document.body.firstChild.reset();record(calls.join('|'));
`,expected:['NotSupportedError','ok','ok','ok','SyntaxError','ok','initial']},
 {name:'custom element adoption state preserving moves and ownership reactions',source:`
const calls=[];class R03Moved extends HTMLElement{static formAssociated=true;constructor(){super();this.i=this.attachInternals();this.i.setFormValue('kept');}connectedCallback(){calls.push('connected')}disconnectedCallback(){calls.push('disconnected')}connectedMoveCallback(){calls.push('moved')}adoptedCallback(oldDoc,newDoc){calls.push('adopted:'+String(oldDoc===document)+':'+String(newDoc===other))}formAssociatedCallback(f){calls.push('form:'+String(f&&f.id))}}
customElements.define('r03-moved',R03Moved);document.body.innerHTML='<form id=f><div id=one></div><div id=two></div></form>';const c=document.createElement('r03-moved');c.setAttribute('name','note');document.getElementById('one').append(c);calls.length=0;document.getElementById('two').moveBefore(c,null);record(calls.join('|'));record([new FormData(document.getElementById('f')).get('note'),c.i.form.id].join('|'));
const other=document.implementation.createHTMLDocument('Other');calls.length=0;other.adoptNode(c);record([c.ownerDocument===other,c.i.form===null,c.isConnected].join('|'));record(calls.join('|'));other.body.append(c);record(c.ownerDocument===other&&c.isConnected);document.adoptNode(c);document.getElementById('f').append(c);record(new FormData(document.getElementById('f')).get('note'));
`,expected:['form:null|moved|form:f','kept|f','true|true|false','disconnected|form:null|adopted:true:true','true','kept']},
 {name:'direct form component construction barred validity and live state iteration',source:`
class R03Direct extends HTMLElement{static formAssociated=true;constructor(){super();this.i=this.attachInternals();this.i.setFormValue('fresh')}}customElements.define('r03-direct',R03Direct);const c=new R03Direct();c.name='ignored';c.setAttribute('name','note');const f=document.createElement('form');document.body.append(f);f.append(c);record([c.i.form===f,new FormData(f).get('note'),f.matches(':valid'),f.matches(':invalid')].join('|'));c.i.setValidity({customError:true},'wrong');record([c.matches(':valid'),c.matches(':invalid'),f.matches(':valid'),f.matches(':invalid')].join('|'));c.setAttribute('readonly','');record([c.i.willValidate,c.i.validity.valid,c.matches(':valid'),c.matches(':invalid'),f.matches(':valid'),f.matches(':invalid')].join('|'));c.setAttribute('disabled','');record([c.i.willValidate,c.matches(':valid'),c.matches(':invalid'),c.matches(':disabled')].join('|'));c.removeAttribute('readonly');c.removeAttribute('disabled');const s=c.i.states;s.add('one');s.add('two');const it=s.values();record(it.next().value);s.delete('two');s.add('three');record(it.next().value);record(it.next().done);s.add('later');record(it.next().done);const visited=[];s.forEach(v=>{visited.push(v);if(v==='one')s.add('last')});record(visited.join('|'));
`,expected:['true|fresh|true|false','false|true|false|true','false|false|true|false|true|false','false|true|false|true','one','three','true','false','one|three|later|last']},
 {name:'custom clone observed attributes roots and fresh internals',source:`
const calls=[];let built=0;class R03Clone extends HTMLElement{static formAssociated=true;static observedAttributes=['data-v'];constructor(){super();built++;this.i=this.attachInternals();this.i.setFormValue('default');if(!this.i.shadowRoot)this.attachShadow({mode:'closed',clonable:true}).innerHTML='<span>Constructor</span>'}attributeChangedCallback(n,o,v){calls.push(n+':'+String(o)+':'+v)}}customElements.define('r03-clone',R03Clone);const c=document.createElement('r03-clone');c.setAttribute('data-v','copied');c.setAttribute('name','note');c.append(document.createTextNode('Light'));c.i.shadowRoot.innerHTML='<slot></slot><strong>Source</strong>';c.i.setFormValue('edited');c.i.states.add('source');calls.length=0;const copy=c.cloneNode(true);record([built,copy instanceof R03Clone,copy!==c,copy.i!==c.i,copy.textContent,copy.i.shadowRoot.textContent,copy.i.shadowRoot!==c.i.shadowRoot,copy.shadowRoot===null].join('|'));record(calls.join('|'));const f=document.createElement('form');document.body.append(f);f.append(copy);record([new FormData(f).get('note'),copy.i.states.size].join('|'));
`,expected:['2|true|true|true|Light|Source|true|true','data-v:null:copied','default|0']}
];
const file=path.join(root,'tests/fixtures/javascript-components.json');
const old=JSON.parse(fs.readFileSync(file,'utf8')).filter(v=>!fixtures.some(f=>f.name===v.name));
fs.writeFileSync(file,JSON.stringify([...old,...fixtures],null,2)+'\n');
const escaped=JSON.stringify(fixtures).replaceAll('</','<\\/');
const html=`<!doctype html><meta charset="utf-8"><title>R03 component reference</title><style>body{font:16px sans-serif;max-width:900px;margin:24px auto}iframe{display:none}pre{white-space:pre-wrap;background:#eef2e8;padding:16px}</style><h1>R03 component reference</h1><button id=run>Run reference cases</button><pre id=result>Ready</pre><script>
const fixtures=${escaped};const results=[];let count=0;
document.getElementById('run').onclick=()=>{results.length=0;count=0;document.getElementById('result').textContent='Running';for(const fixture of fixtures){const iframe=document.createElement('iframe');iframe.srcdoc='<!doctype html><html><head></head><body><script>const values=[];function record(v){values.push(String(v))}try{'+fixture.source+'}catch(e){values.push("UNCAUGHT: "+e.name+": "+e.message)}setTimeout(()=>parent.postMessage({fixture:'+JSON.stringify(fixture.name)+',values},"*"),0);<'+ '/script></body></html>';document.body.append(iframe)}};
window.addEventListener('message',e=>{if(!e.data||!e.data.fixture)return;const expected=fixtures.find(f=>f.name===e.data.fixture).expected;results.push({name:e.data.fixture,pass:JSON.stringify(e.data.values)===JSON.stringify(expected),values:e.data.values,expected});count++;document.getElementById('result').textContent=JSON.stringify({done:count===fixtures.length,userAgent:navigator.userAgent,results},null,2)});
</script>`;
fs.writeFileSync(path.join(root,'build/r03-components-reference.html'),html);
console.log('R03 shared component fixtures/reference written');
