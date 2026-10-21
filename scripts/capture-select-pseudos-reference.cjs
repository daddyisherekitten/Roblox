const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),folder=path.join(root,'build/select-pseudos-reference');fs.mkdirSync(folder,{recursive:true});
const base='select{appearance:base-select}select::picker(select){appearance:base-select}';
const cases=[{
  name:'Author picker icon and reversible content/style changes',
  html:'<!doctype html><style>'+base+'#pseudoSelect::picker-icon{content:"v";color:red;width:18px;height:20px}#pseudoSelect.changed::picker-icon{content:"up";color:blue;width:30px}</style><select id=pseudoSelect><button><selectedcontent></selectedcontent></button><option>A</option><option>B</option></select>',
  code:`const s=document.getElementById('pseudoSelect');const snapshot=()=>{const p=getComputedStyle(s,'::picker-icon');record(p.content,p.color,p.width,p.height,p.display);};snapshot();s.className='changed';snapshot();s.className='';snapshot();`,
},{
  name:'Checkmark inherits option styling and follows live selectedness',
  html:'<!doctype html><style>'+base+'option{color:green}option::checkmark{content:"+"}option:checked::checkmark{color:red}</style><select id=pseudoSelect><button><selectedcontent></selectedcontent></button><option value=a>A</option><option value=b>B</option></select>',
  code:`const s=document.getElementById('pseudoSelect');const snapshot=()=>{for(const o of s.options){const p=getComputedStyle(o,'::checkmark');record(o.value,o.selected,p.content,p.color,p.visibility);}};snapshot();s.value='b';snapshot();s.value='a';snapshot();`,
},{
  name:'Pseudo variables and layer rollback',
  html:'<!doctype html><style>'+base+'@layer low,high;@layer low{#pseudoSelect::picker-icon{content:"v";color:var(--icon,red)}}@layer high{#pseudoSelect::picker-icon{content:revert-layer;color:revert-layer}}#pseudoSelect{--icon:blue}#pseudoSelect.changed{--icon:green}</style><select id=pseudoSelect><button><selectedcontent></selectedcontent></button><option>A</option></select>',
  code:`const s=document.getElementById('pseudoSelect');const snapshot=()=>{const p=getComputedStyle(s,'::picker-icon');record(p.content,p.color);};snapshot();s.className='changed';snapshot();s.className='';snapshot();`,
}];
const file=path.join(folder,'reference.html');fs.writeFileSync(file,`<!doctype html><meta charset=utf-8><pre id=result></pre><script>
const cases=${JSON.stringify(cases).replaceAll('<','\\u003c')};for(const c of cases){const frame=document.createElement('iframe');document.body.append(frame);const d=frame.contentDocument;d.open();d.write(c.html);d.close();c.expected=[];try{new Function('document','getComputedStyle','record',c.code)(d,frame.contentWindow.getComputedStyle.bind(frame.contentWindow),(...v)=>c.expected.push(v.map(String).join('|')));}catch(e){c.error=e.name+': '+e.message;}frame.remove();}
document.getElementById('result').textContent=JSON.stringify({browser:navigator.userAgent,captured:'2026-10-09',standard:'https://html.spec.whatwg.org/multipage/rendering.html#the-select-element-2',cases});</script>`);
const result=cp.spawnSync(process.env.CHROME_BIN||'C:/Program Files/Google/Chrome/Application/chrome.exe',['--headless=new','--disable-gpu','--no-first-run','--disable-background-networking','--user-data-dir='+path.join(folder,'chrome-'+Date.now()),'--virtual-time-budget=10000','--dump-dom','file:///'+file.replaceAll('\\','/')],{encoding:'utf8',windowsHide:true,timeout:30000,maxBuffer:1024*1024});
if(result.error)throw result.error;if(result.status)throw new Error(result.stderr);
fs.writeFileSync(path.join(folder,'reference-result.html'),result.stdout);
const captured=result.stdout.match(/<pre id="result">([\s\S]*?)<\/pre>/);if(!captured||!captured[1])throw new Error('Reference did not complete');
const fixture=JSON.parse(captured[1].replaceAll('&amp;','&').replaceAll('&lt;','<').replaceAll('&gt;','>'));for(const c of fixture.cases)if(c.error)throw new Error(c.name+': '+c.error);
fs.writeFileSync(path.join(root,'tests/fixtures/select-pseudos-browser.json'),JSON.stringify(fixture,null,2)+'\n');console.log('Select pseudos: '+fixture.cases.length+' native sequences captured.');
