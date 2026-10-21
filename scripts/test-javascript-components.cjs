// Shared authored probes execute unchanged in a fresh native browser realm.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),fixturePath=path.join(root,'tests/fixtures/javascript-components.json');
if(process.argv.includes('--serve')){
 const server=require('node:http').createServer((req,res)=>{
  const fixtures=fs.readFileSync(fixturePath,'utf8').replaceAll('<','\\u003c');
  const html=`<!doctype html><meta charset="utf-8"><title>Shadow DOM and custom elements reference</title><h1>Components reference</h1><pre id="result">Running</pre><script>const cases=${fixtures};const results=[];(async()=>{for(const f of cases){const frame=document.createElement('iframe');document.body.append(frame);const values=[];let error;try{frame.contentWindow.Function('record',f.source)(v=>values.push(String(v)));await new Promise(resolve=>setTimeout(resolve,20))}catch(e){error=e.name+': '+e.message}results.push({name:f.name,values,error,pass:!error&&JSON.stringify(values)===JSON.stringify(f.browserExpected||f.expected)});frame.remove()}document.getElementById('result').textContent=JSON.stringify(results)})()</script>`;
  res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'});res.end(html);
 });server.listen(0,'127.0.0.1',()=>console.log('Components reference: http://127.0.0.1:'+server.address().port+'/'));return;
}
const result=cp.spawnSync(process.execPath,[path.join(root,'scripts/run-html-tests.cjs'),'JavaScriptComponents'],{stdio:'inherit'});
if(result.error)throw result.error;process.exitCode=result.status??1;
