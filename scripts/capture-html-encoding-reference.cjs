// Fresh owned browser navigations to real HTTP byte sources, never DOMParser strings.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),http=require('node:http');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/html-encoding-reference');fs.mkdirSync(out,{recursive:true});
const cases=[];
function add(name,source,options={},actualBytes){cases.push({name,bytes:Array.from(actualBytes||Buffer.from(source,'latin1')),options});}
const start='<!doctype html>',box=s=>'<div id="probe">'+s+'</div>';
add('Default single-byte document',start+box('\x80\xe4'));
add('UTF-8 meta',start+'<meta charset=utf-8>'+box(''),{},Buffer.from(start+'<meta charset=utf-8>'+box('ä 😀')));
add('Transport beats meta',start+'<meta charset=utf-8>'+box('\x80\xe4'),{TransportEncoding:'iso-8859-1'});
add('BOM beats transport', '',{TransportEncoding:'windows-1252'},Buffer.concat([Buffer.from([239,187,191]),Buffer.from(start+box('ä 😀'))]));
add('UTF-16LE BOM', '',{TransportEncoding:'utf-8'},Buffer.concat([Buffer.from([255,254]),Buffer.from(start+'<meta charset=windows-1252>'+box('ä 😀'),'utf16le')]));
const bigEndian=Buffer.from(start+box('ä 😀'),'utf16le');bigEndian.swap16();add('UTF-16BE BOM','',{},Buffer.concat([Buffer.from([254,255]),bigEndian]));
add('Content pragma order',start+'<META CONTENT="text/html; CHARSET=windows-1251" HTTP-EQUIV="Content-Type">'+box('\xc0\xff'));
add('Content without pragma',start+'<meta content="text/html; charset=utf-8">'+box('\x80\xe4'));
add('First duplicate charset',start+'<meta charset=windows-1251 charset=utf-8>'+box('\xc0\xff'));
add('Direct charset beats content',start+'<meta content="text/html;charset=windows-1251" charset=windows-1252 http-equiv=content-type>'+box('\x80\xe4'));
add('Invalid charset then real declaration',start+'<meta charset=invalid><meta charset=windows-1251>'+box('\xc0\xff'));
add('Comment declaration ignored',start+'<!-- <meta charset=utf-8> --><meta charset=windows-1251>'+box('\xc0\xff'));
add('Quoted fake declaration ignored',start+'<div title="<meta charset=utf-8>"></div><meta charset=windows-1251>'+box('\xc0\xff'));
add('X-user-defined meta becomes windows-1252',start+'<meta charset=x-user-defined>'+box('\x80\xe4'));
add('UTF-16 meta becomes UTF-8',start+'<meta charset=utf-16le>'+box(''),{},Buffer.from(start+'<meta charset=utf-16le>'+box('ä 😀')));
add('Late meta restarts',start+'<!--'+'.'.repeat(1100)+'--><meta charset=windows-1251>'+box('\xc0\xff'));
add('Late raw script is not meta',start+'<!--'+'.'.repeat(1100)+'--><script type="text/plain">"<meta charset=utf-8>"</script>'+box('\x80\xe4'));
add('Late SVG meta uses current HTML breakout rule',start+'<!--'+'.'.repeat(1100)+'--><svg><meta charset=utf-8></meta></svg>'+box('\x80\xe4'));
add('Late entity label uses parser',start+'<!--'+'.'.repeat(1100)+'--><meta charset="windows-125&#49;">'+box('\xc0\xff'));
add('Partial declaration at prescan boundary',start+'<!--'+'.'.repeat(990)+'--><meta charset="windows-1251">'+box('\xc0\xff'));
add('XML declaration legacy fallback','<?xml version="1.0" encoding="windows-1251"?>'+start+box('\xc0\xff'));
add('UTF-16 XML prefix without BOM','',{},Buffer.from('<?xml version="1.0"?>'+start+box('ä 😀'),'utf16le'));
for(const [name,label,content]of [['Shift_JIS','shift_jis',[130,160]],['EUC-JP','euc-jp',[164,162]],['GBK','gbk',[214,208]],['GB18030','gb18030',[144,48,129,48]],['Big5','big5',[164,64]],['EUC-KR','euc-kr',[176,161]],['ISO-2022-JP','iso-2022-jp',[27,36,66,36,34,27,40,66]]]){
 add(name+' HTML', '',{},Buffer.concat([Buffer.from(start+'<meta charset='+label+'><div id="probe">'),Buffer.from(content),Buffer.from('</div>')]));
}
add('Invalid UTF-8 becomes replacement', '',{TransportEncoding:'utf-8'},Buffer.concat([Buffer.from(start+'<div id="probe">'),Buffer.from([237,160,128,34]),Buffer.from('</div>')]));
const server=http.createServer((req,res)=>{const item=cases[Number(req.url.slice(1))];if(!item){res.writeHead(404);res.end();return;}res.setHeader('Content-Type','text/html'+(item.options.TransportEncoding?'; charset='+item.options.TransportEncoding:''));res.end(Buffer.from(item.bytes));});
const profile=path.join(out,'chrome-'+Date.now());fs.mkdirSync(profile,{recursive:true});
(async()=>{await new Promise(r=>server.listen(0,'127.0.0.1',r));let socket,child;try{
 child=cp.spawn(process.env.CHROME_BIN||'C:/Program Files/Google/Chrome/Application/chrome.exe',['--headless=new','--disable-gpu','--no-first-run','--disable-background-networking','--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'],{stdio:'ignore',windowsHide:true});
 const file=path.join(profile,'DevToolsActivePort');for(let i=0;i<100&&!fs.existsSync(file);i++)await new Promise(r=>setTimeout(r,100));const port=Number(fs.readFileSync(file,'utf8').split('\n')[0]);const tabs=await(await fetch('http://127.0.0.1:'+port+'/json/list')).json();socket=new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);await new Promise((r,j)=>{socket.onopen=r;socket.onerror=j;});
 let id=0;const pending=new Map(),loads=[];socket.onmessage=e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);if(p)m.error?p.reject(new Error(JSON.stringify(m.error))):p.resolve(m.result);}else if(m.method==='Page.loadEventFired'){const next=loads.shift();if(next)next();}};
 const send=(method,params={})=>new Promise((resolve,reject)=>{const n=++id,t=setTimeout(()=>reject(new Error('CDP timeout '+method)),10000);pending.set(n,{resolve:v=>{clearTimeout(t);resolve(v);},reject:e=>{clearTimeout(t);reject(e);}});socket.send(JSON.stringify({id:n,method,params}));});
 await send('Page.enable');const version=await send('Browser.getVersion');
 for(let i=0;i<cases.length;i++){
  let timer;const loaded=new Promise((resolve,reject)=>{timer=setTimeout(()=>reject(new Error('Page load timeout: '+cases[i].name)),10000);loads.push(resolve);});
  try{await Promise.all([send('Page.navigate',{url:'http://127.0.0.1:'+server.address().port+'/'+i}),loaded]);}finally{clearTimeout(timer);}
  const result=await send('Runtime.evaluate',{expression:'({encoding:document.characterSet,text:(document.getElementById("probe")||document.body).textContent})',returnByValue:true});cases[i].expected=result.result.value;console.log(cases[i].name+': '+JSON.stringify(cases[i].expected));
 }
 const duplicate=cases.find(c=>c.name==='First duplicate charset');duplicate.standardExpected={encoding:'windows-1251',text:'Ая'};
 duplicate.difference='The normative prescan ignores duplicate attribute names after their first occurrence; this Chromium prescan chose the second charset.';
 const foreign=cases.find(c=>c.name==='Late SVG meta uses current HTML breakout rule');foreign.standardExpected={encoding:'UTF-8',text:'��'};
 foreign.difference='The current HTML foreign-content breakout list includes meta. This Chromium keeps the late node in SVG instead of reprocessing it as HTML.';
 fs.writeFileSync(path.join(root,'tests/fixtures/html-encoding-browser.json'),JSON.stringify({browser:version.product,captured:'2026-10-09',standard:'https://html.spec.whatwg.org/multipage/parsing.html#determining-the-character-encoding',cases},null,2)+'\n');
 }finally{if(socket)socket.close();if(child)child.kill();await new Promise(r=>server.close(r));}})().catch(e=>{console.error(e);process.exitCode=1;});
