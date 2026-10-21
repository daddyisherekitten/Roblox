// Owned, hidden Chromium process: real insertion semantics and selector results.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),folder=path.join(root,'build/language-reference');fs.mkdirSync(folder,{recursive:true});
const cases=[];const add=(name,head,code)=>cases.push({name,html:'<!doctype html><head>'+head+'</head><body><p id="probe">Probe</p></body>',code});
add('Pragma token and ancestors','<meta http-equiv="CONTENT-LANGUAGE" content="  fr-CH en ">',`
const p=document.getElementById('probe');record(p.matches(':lang(fr)'),p.matches(':lang(en)'));
p.lang='';record(p.matches(':lang(fr)'));p.removeAttribute('lang');document.documentElement.lang='de';record(p.matches(':lang(de)'));
document.documentElement.removeAttribute('lang');const detached=document.createElement('p');record(detached.matches(':lang(fr)'));
`);
add('Comma and empty pragmas preserve previous default','<meta http-equiv="content-language" content="de"><meta http-equiv="content-language" content="fr,en"><meta http-equiv="content-language" content=" \t ">',`
record(document.getElementById('probe').matches(':lang(de)'));`);
add('Attributes and removals do not undo insertion','<meta id="meta" http-equiv="content-language" content="en-US">',`
const p=document.getElementById('probe'),m=document.getElementById('meta');m.content='de';record(p.matches(':lang(en)'));m.remove();record(p.matches(':lang(en)'));
document.head.append(m);record(p.matches(':lang(de)'));m.httpEquiv='none';record(p.matches(':lang(de)'));`);
add('Only a matching pragma on insertion','',`
const p=document.getElementById('probe'),m=document.createElement('meta');document.head.append(m);m.httpEquiv='content-language';m.content='it';record(p.matches(':lang(it)'),p.matches(':lang(en)'));
m.remove();document.head.append(m);record(p.matches(':lang(it)'));`);
add('Template shadow and foreign meta stay separate','<meta http-equiv="content-language" content="en"><template><meta http-equiv="content-language" content="fr"></template>',`
const p=document.getElementById('probe'),host=document.createElement('div');document.body.append(host);const shadow=host.attachShadow({mode:'open'});
shadow.innerHTML='<meta http-equiv="content-language" content="de"><p id="inside">Inside</p>';record(p.matches(':lang(en)'),shadow.querySelector('#inside').matches(':lang(en)'));
const foreign=document.createElementNS('http://www.w3.org/2000/svg','meta');foreign.setAttribute('http-equiv','content-language');foreign.setAttribute('content','fr');document.body.append(foreign);record(p.matches(':lang(en)'));
`);
add('Batch insertion runs in tree order','',`
const wrapper=document.createElement('div');wrapper.innerHTML='<meta http-equiv="content-language" content="de"><meta http-equiv="content-language" content="it">';document.body.append(wrapper);
record(document.getElementById('probe').matches(':lang(it)'));`);
add('Unknown language is preserved','<meta http-equiv="content-language" content="xyzzy">',`
record(document.getElementById('probe').matches(':lang(xyzzy)'));`);
const source=`<!doctype html><meta charset=utf-8><body><pre id="result"></pre><script>
const cases=${JSON.stringify(cases)};
(async()=>{for(const c of cases){
 try{
  const f=document.createElement('iframe');f.srcdoc=c.html;const loaded=new Promise(resolve=>f.onload=resolve);document.body.append(f);
  await loaded;c.expected=[];
  f.contentWindow.record=(...values)=>c.expected.push(values.map(String).join('|'));
  try{f.contentWindow.eval(c.code);}catch(e){c.error=e.name+': '+e.message;}
  f.remove();
 }catch(e){c.error=e.name+': '+e.message;}
}
document.getElementById('result').textContent=JSON.stringify({browser:navigator.userAgent,captured:'2026-10-09',standard:'https://html.spec.whatwg.org/multipage/semantics.html#pragma-set-default-language',cases});})();
</script>`;
const file=path.join(folder,'reference.html');fs.writeFileSync(file,source);
const result=cp.spawnSync(process.env.CHROME_BIN||'C:/Program Files/Google/Chrome/Application/chrome.exe',['--headless=new','--disable-gpu','--no-first-run','--disable-background-networking','--user-data-dir='+path.join(folder,'chrome-'+Date.now()),'--virtual-time-budget=10000','--dump-dom','file:///'+file.replaceAll('\\','/')],{encoding:'utf8',windowsHide:true,timeout:30000,maxBuffer:1024*1024});
if(result.error)throw result.error;if(result.status)throw new Error(result.stderr);
fs.writeFileSync(path.join(folder,'reference-result.html'),result.stdout);
const captured=result.stdout.match(/<pre id="result">([\s\S]*?)<\/pre>/);if(!captured||!captured[1])throw new Error('Reference page did not complete; inspect build/language-reference/reference-result.html');
const fixture=JSON.parse(captured[1].replaceAll('&amp;','&').replaceAll('&lt;','<').replaceAll('&gt;','>'));
for(const c of fixture.cases)if(c.error)throw new Error(c.name+': '+c.error);
const normative={
 'Pragma token and ancestors':[['true|false','false','true','true'],'The standard consumes the first whitespace-delimited content token; Chromium uses the entire string.'],
 'Comma and empty pragmas preserve previous default':[['true'],'The standard ignores an empty pragma; Chromium clears the previous language.'],
 'Attributes and removals do not undo insertion':[['true','true','true','true'],'The standard runs the pragma on insertion; Chromium also applies content mutations.'],
 'Only a matching pragma on insertion':[['false|false','true'],'The standard does not process later attribute edits until reinsertion; Chromium processes the changed pragma immediately.'],
};
for(const c of fixture.cases)if(normative[c.name]&&JSON.stringify(c.expected)!==JSON.stringify(normative[c.name][0])){
 [c.standardExpected,c.difference]=normative[c.name];
}
fs.writeFileSync(path.join(root,'tests/fixtures/html-language-browser.json'),JSON.stringify(fixture,null,2)+'\n');
console.log('HTML language: '+fixture.cases.length+' native insertion/selector sequences captured.');
