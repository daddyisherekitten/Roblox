// Native ECMAScript/Luau construction traces plus an authored Chromium page.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..');
if(!process.argv.includes('--serve')){
 const result=cp.spawnSync(process.execPath,[path.join(__dirname,'test-javascript-language.cjs'),'--fixtures=javascript-class-builtins.json',...process.argv.slice(2)],{stdio:'inherit'});
 if(result.error)throw result.error;process.exit(result.status??1);
}
const fixtures=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-class-builtins.json'),'utf8'));
const data=JSON.stringify(fixtures).replaceAll('<','\\u003c');
const html=`<!doctype html><meta charset="utf-8"><title>Built-in subclass fixtures</title><h1>Built-in subclass fixtures</h1><pre id="result">Running</pre><script>const fixtures=${data};const results=[];for(const f of fixtures){const frame=document.createElement('iframe');frame.hidden=true;document.body.append(frame);const values=[];let error;try{frame.contentWindow.Function('record',f.source)(v=>values.push(String(v)))}catch(e){error=e.name+': '+e.message}results.push({name:f.name,values,expected:f.expected,pass:!error&&JSON.stringify(values)===JSON.stringify(f.expected),error});frame.remove()}document.getElementById('result').textContent=JSON.stringify(results)</script>`;
require('node:http').createServer((req,res)=>{res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'});res.end(html)}).listen(9159,'127.0.0.1',()=>console.log('Native browser built-in subclass fixtures: http://127.0.0.1:9159/'));
