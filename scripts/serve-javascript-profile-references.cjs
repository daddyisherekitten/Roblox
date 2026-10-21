// Serve authored conformance fixtures in the in-app browser; no headless browser.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const root=path.resolve(__dirname,'..');
const profiles=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-canvas-paths.json'),'utf8'));
const html='<!doctype html><html lang="en"><meta charset="utf-8"><title>Canvas reference</title><body><pre id="results">Running</pre><script>const fixtures='+JSON.stringify(profiles).replace(/</g,'\\u003c')+';const results=[];for(const f of fixtures){const c=document.createElement("canvas");c.width=64;c.height=64;const ctx=c.getContext("2d");const values=[];try{new Function("c","ctx","console",f.source)(c,ctx,{log:(...a)=>values.push(a.join(" "))});results.push({name:f.name,values:values.join("|"),passed:values.join("|")===f.expected});}catch(e){results.push({name:f.name,error:e.name+": "+e.message});}}document.getElementById("results").textContent=JSON.stringify(results,null,2);</script></body></html>';
const server=http.createServer((req,res)=>{res.setHeader('Content-Type','text/html;charset=utf-8');res.end(html);});
server.listen(0,'127.0.0.1',()=>console.log('Canvas references: http://127.0.0.1:'+server.address().port+'/'));
