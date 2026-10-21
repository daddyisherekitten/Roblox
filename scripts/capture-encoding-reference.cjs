// Own headless Chromium process; captures decoder traces without touching user tabs.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/encoding-reference');fs.mkdirSync(out,{recursive:true});
const groups=JSON.parse(fs.readFileSync(path.join(root,'build/reference/encoding-encodings.json'),'utf8'));
const indexes=JSON.parse(fs.readFileSync(path.join(root,'build/reference/encoding-indexes.json'),'utf8'));
const encodings=groups.flatMap(g=>g.encodings).filter(e=>e.name!=='replacement');
const multi=['GBK','gb18030','Big5','EUC-JP','ISO-2022-JP','Shift_JIS','EUC-KR'];
const sources=encodings.map(e=>[e.name,`const a=[];for(let i=0;i<256;i++)a.push(i);const d=new TextDecoder(${JSON.stringify(e.name)});record(d.encoding);record(Array.from(d.decode(new Uint8Array(a)),c=>c.codePointAt(0).toString(16)).join(','));`]);
sources.push(['labels','const labels='+JSON.stringify(encodings.flatMap(e=>e.labels))+';for(const label of labels)record(new TextDecoder(label).encoding);']);
const samples=[[0x81],[0x81,0x22],[0x81,0x30],[0x81,0x30,0x81],[0x81,0x30,0x81,0x22],[0x81,0x30,0x20],[0x81,0x30,0x81,0x30],
 [0x90,0x30,0x81,0x30],[0xfe,0x39,0xfe,0x39],[0x88,0x62],[0x88,0x64],[0x88,0xa3],[0x88,0xa5],
 [0x82,0xa0],[0xf0,0x40],[0x8f,0xa2,0xaf],[0x8e,0xb1],[0xb0,0xa1],
 [27,40,74,92,126,27,40,66,65],[27,36,66,36,34,27,40,66],[27],[27,40],[27,40,99],
 [27,36,66,36,27,40,66,65],[27,40,66,27,40,66,65],[27,40,73,33,95],[27,36,66,36],
 [27,36,66,27,40],[27,36,66,36,127,65],[14,15,27,40,74,14,15]];
let seed=12345;for(let i=0;i<120;i++){const a=[];for(let j=0;j<1+i%12;j++){seed=(Math.imul(seed,1664525)+1013904223)>>>0;a.push(seed>>>24);}samples.push(a);}
for(const name of [...multi,'UTF-8','UTF-16LE','UTF-16BE'])sources.push([name+' splits and errors',`
 const samples=${JSON.stringify(samples)},hex=s=>Array.from(s,c=>c.codePointAt(0).toString(16)).join(',');
 const d=new TextDecoder(${JSON.stringify(name)});
 for(const a of samples){const b=new Uint8Array(a);record(hex(new TextDecoder(${JSON.stringify(name)}).decode(b)));for(let n=0;n<=b.length;n++){const u=new TextDecoder(${JSON.stringify(name)});record(hex(u.decode(b.slice(0,n),{stream:true})+u.decode(b.slice(n))));}
 const f=new TextDecoder(${JSON.stringify(name)},{fatal:true});try{record('ok:'+hex(f.decode(b)));}catch(e){record(e.name);}}
 const reuse=new TextDecoder(${JSON.stringify(name)});reuse.decode(new Uint8Array([27,40,74]),{stream:true});reuse.decode();record(hex(reuse.decode(new Uint8Array([92,126]))));
 `]);
const boundaries=indexes['gb18030-ranges'].flatMap(([p])=>[p-1,p,p+1]).filter(p=>p>=0);
boundaries.push(39419,39420,188999,189000,1237575,1237576,7457);
sources.push(['GB18030 range boundaries',`const pointers=${JSON.stringify(boundaries)},d=new TextDecoder('gb18030');for(const p of pointers){const a=[Math.floor(p/12600)+129,Math.floor(p%12600/1260)+48,Math.floor(p%1260/10)+129,p%10+48];record(Array.from(d.decode(new Uint8Array(a)),c=>c.codePointAt(0).toString(16)).join(','));}`]);
const profile=path.join(out,'chrome-'+Date.now());fs.mkdirSync(profile,{recursive:true});
const child=cp.spawn(process.env.CHROME_BIN||'C:/Program Files/Google/Chrome/Application/chrome.exe',['--headless=new','--disable-gpu','--no-first-run','--disable-background-networking','--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'],{stdio:'ignore',windowsHide:true});
(async()=>{let socket;try{
 const file=path.join(profile,'DevToolsActivePort');for(let i=0;i<100&&!fs.existsSync(file);i++)await new Promise(r=>setTimeout(r,100));
 const port=Number(fs.readFileSync(file,'utf8').split('\n')[0]);const tabs=await(await fetch('http://127.0.0.1:'+port+'/json/list')).json();socket=new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);await new Promise((r,j)=>{socket.onopen=r;socket.onerror=j;});
 let id=0;const pending=new Map();socket.onmessage=e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);if(p)m.error?p.reject(new Error(JSON.stringify(m.error))):p.resolve(m.result);}};
 const send=(method,params={})=>new Promise((resolve,reject)=>{const n=++id,t=setTimeout(()=>reject(new Error('CDP timeout '+method)),30000);pending.set(n,{resolve:v=>{clearTimeout(t);resolve(v);},reject:e=>{clearTimeout(t);reject(e);}});socket.send(JSON.stringify({id:n,method,params}));});
 const version=await send('Browser.getVersion'),cases=[],pairs=[],differences=[];
 for(const [name,source]of sources){const r=await send('Runtime.evaluate',{expression:'(()=>{let output=[];function record(v){output.push(String(v));}try{'+source+'}catch(e){output.push("UNCAUGHT:"+e.name+":"+e.message);}return output;})()',returnByValue:true});cases.push({name,source,expected:r.result.value});console.log(name+': '+r.result.value.length+' records');}
 for(const encoding of multi){const r=await send('Runtime.evaluate',{expression:`(()=>{const d=new TextDecoder(${JSON.stringify(encoding)}),b=new Uint8Array(2);const rows=[],standardRows=[];const exceptions={98:[202,772],100:[202,780],163:[234,772],165:[234,780]};for(let lead=0;lead<256;lead++){b[0]=lead;let h=5381,s=5381;for(let trail=0;trail<256;trail++){b[1]=trail;const cps=Array.from(new TextDecoder(${JSON.stringify(encoding)}).decode(b),c=>c.codePointAt(0));for(const cp of cps)h=(h*33+cp)>>>0;h=(h*33+0x110000)>>>0;const corrected=${JSON.stringify(encoding)}==='Big5' && lead===136 && exceptions[trail] || cps;for(const cp of corrected)s=(s*33+cp)>>>0;s=(s*33+0x110000)>>>0;}rows.push(h);standardRows.push(s);}return {rows,standardRows};})()`,returnByValue:true});const result={encoding:encoding.toLowerCase(),rows:r.result.value.rows};if(JSON.stringify(result.rows)!==JSON.stringify(r.result.value.standardRows))result.standardRows=r.result.value.standardRows;pairs.push(result);console.log(encoding+': all 65536 byte pairs');}
 // WHATWG defines exactly four Big5 pointers with two output scalars.
 // Keep Chromium's raw output and record only these explicit corrections.
 for(const [trail,standard]of [[98,'ca,304'],[100,'ca,30c'],[163,'ea,304'],[165,'ea,30c']]){
  const r=await send('Runtime.evaluate',{expression:`Array.from(new TextDecoder('big5').decode(new Uint8Array([136,${trail}])),c=>c.codePointAt(0).toString(16)).join(',')`,returnByValue:true});const actual=r.result.value;
  if(actual!==standard){differences.push({encoding:'big5',bytes:[136,trail],browser:actual,standard,reason:'WHATWG Big5 decoder two-scalar pointer table'});for(const c of cases){if(!c.name.startsWith('Big5'))continue;c.standardExpected=(c.standardExpected||c.expected).map(v=>v===actual?standard:v==='ok:'+actual?'ok:'+standard:v);}}
 }
 const jp=cases.find(c=>c.name==='ISO-2022-JP splits and errors');
 const jpSample=samples.findIndex(a=>JSON.stringify(a)==='[27,36,66,27,40]');
 const jpStart=samples.slice(0,jpSample).reduce((n,a)=>n+a.length+3,0);
 jp.standardExpected=jp.expected.slice();for(let n=jpStart;n<jpStart+7;n++)jp.standardExpected[n]='fffd,fffd';
 differences.push({encoding:'iso-2022-jp',bytes:samples[jpSample],browser:jp.expected[jpStart],standard:'fffd,fffd',reason:'Escape at EOF restores the suffix into the previous JIS leading-byte state, followed by a second EOF error'});
 jp.standardExpected[jp.expected.length-1]='5c,7e';
 differences.push({encoding:'iso-2022-jp',browser:jp.expected.at(-1),standard:'5c,7e',reason:'A new decode after non-streaming completion must create a new decoder in ASCII state, not keep the previous Roman state'});
 fs.writeFileSync(path.join(root,'tests/fixtures/encoding-browser.json'),JSON.stringify({browser:version.product,captured:'2026-10-09',standard:'https://encoding.spec.whatwg.org/',cases,pairs,differences},null,2)+'\n');
 }finally{if(socket)socket.close();child.kill();}})().catch(e=>{console.error(e);process.exitCode=1;});
