const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),folder=path.join(root,'build/select-text-reference');fs.mkdirSync(folder,{recursive:true});
const cases=[];
for(const [name,contents,attrs]of[
 ['ASCII whitespace and non-ASCII spaces',' \n A  <b>B</b>\tC &#160; D &#160; ',''],
 ['Images do not enter text or value','A <img alt="picture"> B',''],
 ['An empty label reflects empty but text supplies the value','A <img alt="picture"> B','label=""'],
 ['A specified label and value remain uncollapsed','Text','label="  L   M  " value="  V   W  "'],
 ['HTML and SVG scripts are excluded','A<script>ignored()</script><svg><script>ignoredSvg()</script><text>S</text></svg> B',''],
 ['Style text is retained; templates have no DOM child text','A<style>visible-as-text</style><template>ignored-template</template> B',''],
])cases.push({name,html:'<!doctype html><select id=s style="appearance:base-select"><option id=o '+attrs+'>'+contents+'</option></select>',code:`const s=document.getElementById('s'),o=document.getElementById('o');record(o.text,o.value,o.label,s.value);o.label='';record(o.text,o.value,o.label);o.removeAttribute('label');record(o.label);o.text=' Changed  text ';record(o.text,o.value,o.label,o.textContent);`});
const source=`<!doctype html><meta charset=utf-8><pre id="result"></pre><script>
const cases=${JSON.stringify(cases).replaceAll('<','\\u003c')};
for(const c of cases){const d=new DOMParser().parseFromString(c.html,'text/html');c.expected=[];try{new Function('document','record',c.code)(d,(...v)=>c.expected.push(v.map(String).join('|')));}catch(e){c.error=e.name+': '+e.message;}}
document.getElementById('result').textContent=JSON.stringify({browser:navigator.userAgent,captured:'2026-10-09',standard:'https://html.spec.whatwg.org/multipage/form-elements.html#get-html-aware-text-content',cases}).replaceAll(String.fromCharCode(160),String.fromCharCode(92)+'u00a0');
</script>`;
const file=path.join(folder,'reference.html');fs.writeFileSync(file,source);
const result=cp.spawnSync(process.env.CHROME_BIN||'C:/Program Files/Google/Chrome/Application/chrome.exe',['--headless=new','--disable-gpu','--no-first-run','--disable-background-networking','--user-data-dir='+path.join(folder,'chrome-'+Date.now()),'--virtual-time-budget=10000','--dump-dom','file:///'+file.replaceAll('\\','/')],{encoding:'utf8',windowsHide:true,timeout:30000,maxBuffer:1024*1024});
if(result.error)throw result.error;if(result.status)throw new Error(result.stderr);
fs.writeFileSync(path.join(folder,'reference-result.html'),result.stdout);
const captured=result.stdout.match(/<pre id="result">([\s\S]*?)<\/pre>/);if(!captured||!captured[1])throw new Error('Reference did not complete');
const fixture=JSON.parse(captured[1].replaceAll('&amp;','&').replaceAll('&lt;','<').replaceAll('&gt;','>'));for(const c of fixture.cases)if(c.error)throw new Error(c.name+': '+c.error);
fs.writeFileSync(path.join(root,'tests/fixtures/select-text-browser.json'),JSON.stringify(fixture,null,2)+'\n');console.log('Select text: '+fixture.cases.length+' native sequences captured.');
