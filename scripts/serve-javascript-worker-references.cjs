const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const fixtures=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../tests/fixtures/javascript-worker-realms.json'),'utf8'));
const server=http.createServer((req,res)=>{
 const url=new URL(req.url,'http://localhost');const match=url.pathname.match(/^\/(\d+)\/(.+)$/);
 if(match){const f=fixtures[+match[1]],source=f?.sources[match[2]];if(source!==undefined){res.setHeader('Content-Type','text/javascript');res.end(source);return;}res.writeHead(404);res.end();return;}
 res.setHeader('Content-Type','text/html;charset=utf-8');
 res.end('<!doctype html><html><meta charset="utf-8"><title>Worker reference</title><body><pre id="results">Running</pre><script>const fixtures='+JSON.stringify(fixtures).replace(/</g,'\\u003c')+';const results=[];(async()=>{for(let i=0;i<fixtures.length;i++){const f=fixtures[i];const values=[];await new Promise(done=>{const workerFactory=class extends Worker{constructor(url,options){super("/"+i+"/"+url.replace("./",""),options);}};new Function("Worker","console",f.source)(workerFactory,{log:(...a)=>{values.push(a.join(" "));done();}});setTimeout(done,1500);});results.push({name:f.name,values:values.join("|"),passed:values.join("|")===f.expected});document.getElementById("results").textContent=JSON.stringify(results,null,2);}})();</script></body></html>');
});server.listen(0,'127.0.0.1',()=>console.log('Worker reference: http://127.0.0.1:'+server.address().port+'/'));
