// The same authored scripts run in native iframe realms and our Luau renderer.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),fixturePath=path.join(root,'tests/fixtures/javascript-animation-commit.json');
if(process.argv.includes('--serve')){
 const server=require('node:http').createServer((req,res)=>{
  const fixtures=fs.readFileSync(fixturePath,'utf8').replaceAll('<','\\u003c');
  const html=`<!doctype html><meta charset="utf-8"><title>Animation commit reference</title><h1>Animation commit reference</h1><pre id="result">Running</pre><script>const cases=${fixtures};const results=[];(async()=>{for(const f of cases){const frame=document.createElement('iframe');document.body.append(frame);const d=frame.contentDocument;d.body.innerHTML='<div id="parent"><div id="box"></div></div><div id="outside">Unchanged</div>';const style=d.createElement('style');style.textContent='html,body{margin:0;padding:0}#box{width:200px;height:100px;background:white}'+(f.css||'');d.head.append(style);const values=[];let error;try{await frame.contentWindow.Function('record',f.source)(v=>values.push(String(v)))}catch(e){error=e.name+': '+e.message}results.push({name:f.name,values,error,pass:!error&&JSON.stringify(values)===JSON.stringify(f.browserExpected||f.expected)});frame.remove()}document.getElementById('result').textContent=JSON.stringify(results)})()</script>`;
  res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'});res.end(html);
 });
 server.listen(0,'127.0.0.1',()=>console.log('Animation commit reference: http://127.0.0.1:'+server.address().port+'/'));return;
}
const result=cp.spawnSync(process.execPath,[path.join(root,'scripts/run-html-tests.cjs'),'JavaScriptAnimationCommit'],{encoding:'utf8',maxBuffer:4*1024*1024});
process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');if(result.error)throw result.error;process.exitCode=result.status??1;
