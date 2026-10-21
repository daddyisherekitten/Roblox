// Parser-script insertion points in real HTTP byte documents with certain encoding.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),file=path.join(root,'tests/fixtures/live-byte-documents-browser.json');
const prefix='<!doctype html><html><head><script>console.log("head",document.characterSet,document.body===null,document.getElementById("future")===null);document.write("<meta name=written content=yes>");console.log("written",document.querySelector("meta[name=written]").content);</script><meta charset=windows-1251></head><body><p id=probe>';
const suffix='</p><script>console.log("body",document.characterSet,document.getElementById("probe").textContent,document.getElementById("future")===null);document.write("<p id=dynamic>Written</p>");console.log("dynamic",document.getElementById("dynamic").textContent);</script><p id=future>Future</p><script>console.log("tail",document.getElementById("future").textContent,document.readyState);</script></body></html>';
const cases=[];const add=(name,body,options,bytes)=>cases.push({name,bytes:Array.from(bytes||Buffer.concat([Buffer.from(prefix),Buffer.from(body),Buffer.from(suffix)])),options});
add('UTF-8 transport','ä 😀',{TransportEncoding:'utf-8'});
add('Single-byte transport',[128,228],{TransportEncoding:'windows-1252'});
add('UTF-8 BOM beats transport',null,{TransportEncoding:'windows-1252'},Buffer.concat([Buffer.from([239,187,191]),Buffer.from(prefix+'ä 😀'+suffix)]));
add('UTF-16LE BOM beats transport',null,{TransportEncoding:'utf-8'},Buffer.concat([Buffer.from([255,254]),Buffer.from(prefix+'ä 😀'+suffix,'utf16le')]));
const be=Buffer.from(prefix+'ä 😀'+suffix,'utf16le');be.swap16();add('UTF-16BE BOM',null,{},Buffer.concat([Buffer.from([254,255]),be]));
for(const [name,label,body]of [['Shift_JIS','shift_jis',[130,160]],['EUC-JP','euc-jp',[164,162]],['GBK','gbk',[214,208]],['GB18030','gb18030',[144,48,129,48]],['Big5','big5',[164,64]],['EUC-KR','euc-kr',[176,161]],['ISO-2022-JP','iso-2022-jp',[27,36,66,36,34,27,40,66]]])add(name+' transport',body,{TransportEncoding:label});
add('Malformed UTF-8 becomes replacement',[237,160,128,34],{TransportEncoding:'utf-8'});
add('CRLF and repeated CR across transport chunks','A\r\nB\rC\r\r\nD',{TransportEncoding:'utf-8'});
add('Internal UTF-8 BOM remains source text','A\ufeffB',{TransportEncoding:'utf-8'});
(async()=>{
 const server=http.createServer((req,res)=>{const item=cases[Number(new URL(req.url,'http://local').pathname.slice(1))];if(!item){res.writeHead(404);res.end();return;}res.setHeader('Content-Type','text/html'+(item.options.TransportEncoding?';charset='+item.options.TransportEncoding:''));res.end(Buffer.from(item.bytes));});
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));const origin='http://127.0.0.1:'+server.address().port,browser=await openBrowser(path.join(root,'build'));
 try{
  const version=await browser.send('Browser.getVersion');await browser.send('Page.addScriptToEvaluateOnNewDocument',{source:'globalThis.__out=[];console.log=(...args)=>__out.push(args.map(String).join(" "));'});
  for(let index=0;index<cases.length;index++){
   await browser.send('Page.navigate',{url:origin+'/'+index});let result;
   for(let tries=0;tries<200;tries++){await new Promise(resolve=>setTimeout(resolve,10));result=await browser.evaluate(`location.pathname==='/${index}'&&document.readyState==='complete'?globalThis.__out:null`);if(result)break;}assert.ok(result,cases[index].name);cases[index].expected=result;
  }
  const fixture={browser:version.product,captured:'2026-10-10',standard:'https://html.spec.whatwg.org/multipage/parsing.html#parsing-with-a-known-character-encoding',cases};
  if(process.argv.includes('--update'))fs.writeFileSync(file,JSON.stringify(fixture,null,2)+'\n');else assert.deepEqual(fixture,JSON.parse(fs.readFileSync(file,'utf8')));
  console.log('Live byte documents: '+cases.length+' native certain-encoding/script/write cases captured.');
 }finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(error=>{console.error(error);process.exitCode=1;});
