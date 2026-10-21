// DOMParser creates genuine quirks/limited/no-quirks documents. An iframe's
// srcdoc forces no-quirks and would therefore be an invalid comparison here.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),folder=path.join(root,'build/quirks-reference');fs.mkdirSync(folder,{recursive:true});
const cases=[];
const body='<div id="MiXeD" class="ToNe ÜBER X&#11;Y"><span class="ToNe">Child</span></div><p id="next">Next</p><svg><rect id="Shape" class="ToNe"></rect></svg>';
const checks=`
const p=document.getElementById('MiXeD'),n=document.getElementById('next');
record(document.compatMode,p.matches('#mixed.tone'),p.matches('[id="mixed"]'),p.matches('[class~="tone"]'),p.matches('[id="mixed" i]'));
record(document.querySelectorAll('.tone').length,document.getElementsByClassName('tone').length,document.getElementById('mixed')===null,p.classList.contains('tone'));
record(p.matches('.über'),p.matches('.ÜBER'),p.matches('.X'),p.matches('.X\\\\b Y'));
record(n.matches('.tone + p'),p.matches(':has(> .tone)'),p.firstChild.matches(':nth-child(1 of .tone)'));
record(document.querySelector('svg rect').matches('#shape.tone'));
const live=p.getElementsByClassName('tone');record(live.length);p.firstChild.className='TONE';record(live.length);
p.remove();record(p.matches('#mixed.tone'),live.length);
const other=new DOMParser().parseFromString(document.compatMode==='BackCompat'?'<!doctype html><body></body>':'<body></body>','text/html');
other.adoptNode(p);record(p.matches('#mixed.tone'),live.length);other.body.append(p);record(other.querySelectorAll('.tone').length);
`;
for(const [name,doctype]of[
 ['Standards','<!doctype html>'],
 ['Almost Standards','<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">'],
 ['Quirks',''],
])cases.push({name,html:doctype+'<html><head></head><body>'+body+'</body></html>',code:checks});
cases.push({name:'XML remains case-sensitive',html:'<root><item id="MiXeD" class="ToNe"/></root>',mime:'application/xml',code:`const p=document.documentElement.firstChild;record(document.compatMode,p.matches('#mixed.tone'),p.matches('#MiXeD.ToNe'),document.getElementsByClassName('tone').length);`});
const source=`<!doctype html><meta charset=utf-8><pre id="result"></pre><script>
const cases=${JSON.stringify(cases)};
for(const c of cases){
 const d=new DOMParser().parseFromString(c.html,c.mime||'text/html');c.expected=[];
 try{new Function('document','record',c.code)(d,(...values)=>c.expected.push(values.map(String).join('|')));}catch(e){c.error=e.name+': '+e.message;}
}
document.getElementById('result').textContent=JSON.stringify({browser:navigator.userAgent,captured:'2026-10-09',standards:['https://www.w3.org/TR/selectors-4/#id-selectors','https://dom.spec.whatwg.org/#concept-getelementsbyclassname'],cases});
</script>`;
const file=path.join(folder,'reference.html');fs.writeFileSync(file,source);
const result=cp.spawnSync(process.env.CHROME_BIN||'C:/Program Files/Google/Chrome/Application/chrome.exe',['--headless=new','--disable-gpu','--no-first-run','--disable-background-networking','--user-data-dir='+path.join(folder,'chrome-'+Date.now()),'--virtual-time-budget=10000','--dump-dom','file:///'+file.replaceAll('\\','/')],{encoding:'utf8',windowsHide:true,timeout:30000,maxBuffer:1024*1024});
if(result.error)throw result.error;if(result.status)throw new Error(result.stderr);
fs.writeFileSync(path.join(folder,'reference-result.html'),result.stdout);
const captured=result.stdout.match(/<pre id="result">([\s\S]*?)<\/pre>/);if(!captured||!captured[1])throw new Error('Reference page did not complete');
const fixture=JSON.parse(captured[1].replaceAll('&amp;','&').replaceAll('&lt;','<').replaceAll('&gt;','>'));
for(const c of fixture.cases)if(c.error)throw new Error(c.name+': '+c.error);
fs.writeFileSync(path.join(root,'tests/fixtures/html-quirks-browser.json'),JSON.stringify(fixture,null,2)+'\n');
console.log('HTML quirks: '+fixture.cases.length+' native selector/live collection/adoption sequences captured.');
