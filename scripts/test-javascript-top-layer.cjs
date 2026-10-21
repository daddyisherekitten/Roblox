const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),fixturePath=path.join(root,'tests/fixtures/javascript-top-layer.json');
if(process.argv.includes('--serve')){
 const server=require('node:http').createServer((req,res)=>{
  const fixtures=fs.readFileSync(fixturePath,'utf8').replaceAll('<','\\u003c');
  const html=`<!doctype html><meta charset="utf-8"><title>Dialog and popover reference</title><h1>Dialog and popover reference</h1><pre id="result">Running</pre><script>const cases=${fixtures};const results=[];(async()=>{for(const f of cases){const frame=document.createElement('iframe');document.body.append(frame);const d=frame.contentDocument;d.body.innerHTML='<button id="s">Source</button><dialog id="d"></dialog><div id="p" popover="auto"><button id="inside">Nested source</button></div><div id="q" popover="auto"></div><div id="m" popover="manual"></div><div id="h" popover="hint"></div>';const values=[];let error;try{frame.contentWindow.Function('record',f.source)(v=>values.push(String(v)));await new Promise(resolve=>setTimeout(resolve,20))}catch(e){error=e.name+': '+e.message}results.push({name:f.name,values,error,pass:!error&&JSON.stringify(values)===JSON.stringify(f.browserExpected||f.expected)});frame.remove()}document.getElementById('result').textContent=JSON.stringify(results)})()</script>`;
  res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'});res.end(html);
 });server.listen(0,'127.0.0.1',()=>console.log('Dialog/popover reference: http://127.0.0.1:'+server.address().port+'/'));return;
}
const result=cp.spawnSync(process.execPath,[path.join(root,'scripts/run-html-tests.cjs'),'JavaScriptTopLayer'],{encoding:'utf8',maxBuffer:4*1024*1024});
process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');if(result.error)throw result.error;process.exitCode=result.status??1;
