// Independent PID-scoped engine bundle and IAB-readable authored reference.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),assert=require('node:assert/strict'),http=require('node:http');
const root=path.resolve(__dirname,'..'),modules=new Map();
function load(id){
 if(modules.has(id))return;
 const base=path.join(root,'src/HTMLEngine',id),file=fs.existsSync(base+'.luau')?base+'.luau':path.join(base,'init.luau');
 let source=fs.readFileSync(file,'utf8');modules.set(id,'');
 source=source.replace(/require\(script((?:\.[A-Za-z_][A-Za-z_0-9]*)+)\)/g,(_,chain)=>{
  const parts=id.split('/');for(const name of chain.slice(1).split('.'))name==='Parent'?parts.pop():parts.push(name);
  const dependency=parts.join('/');load(dependency);return `require(${JSON.stringify(dependency)})`;
 });modules.set(id,source);
}
for(const id of ['HTML/Parser','DOM/Node','JavaScript/DOM','JavaScript/VM','Input/Events'])load(id);
let bundle=`local Color3={new=function(r,g,b)return {R=r,G=g,B=b}end,fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end}
local Vector2={new=function(x,y)return {X=x,Y=y}end};local UDim2={fromOffset=function(x,y)return {x,y}end}
local Enum={Font={Arial="Arial",SourceSans="SourceSans",Ubuntu="Ubuntu"}}
local loaders,loaded={},{};local function require(id)if loaded[id]==nil then loaded[id]=assert(loaders[id],id)()end;return loaded[id]end\n`;
for(const [id,source]of modules)bundle+=`loaders[${JSON.stringify(id)}]=function()\n${source}\nend\n`;
bundle+='local existing=(function()\n'+fs.readFileSync(path.join(root,'tests/JavaScriptDOMExpansion.luau'),'utf8')+'\nend)()\n';
bundle+='existing(require("HTML/Parser"),require("DOM/Node"),require("JavaScript/DOM"),require("JavaScript/VM"),require("Input/Events"))\n';
bundle+='local run=(function()\n'+fs.readFileSync(path.join(root,'tests/JavaScriptDOMQueries.luau'),'utf8')+'\nend)()\n';
const fixture=fs.readFileSync(path.join(root,'tests/fixtures/dom-queries-reference.js'),'utf8');
bundle+='run(require("HTML/Parser"),require("DOM/Node"),require("JavaScript/DOM"),require("JavaScript/VM"),[====['+fixture+']====])\n';
const target=path.join(root,'build',`dom-queries-${process.pid}.luau`);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bundle);
const executable=process.env.LUAU_BIN||path.join(root,'build/tools/luau/luau.exe');
const result=cp.spawnSync(executable,[target],{encoding:'utf8',maxBuffer:2*1024*1024});
process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');if(result.error)throw result.error;process.exitCode=result.status??1;
const marker=result.stdout.match(/^QUERY_RESULT (.+)$/m);
if(marker){
 const actual=JSON.parse(marker[1]),output=path.join(root,'build',`dom-queries-${process.pid}.json`);fs.writeFileSync(output,JSON.stringify(actual,null,2)+'\n');console.log('Query engine fixture:',output);
 const golden=path.join(root,'tests/fixtures/dom-queries-browser.json');
 if(!process.exitCode&&fs.existsSync(golden)){assert.deepEqual(actual,JSON.parse(fs.readFileSync(golden,'utf8')));console.log('Native Chromium matches every query fixture field.');}
}
if(process.argv.includes('--serve')){
 const selected=process.argv.find(value=>value.startsWith('--case='))?.slice(7);
 const server=http.createServer((request,response)=>{
  const url=new URL(request.url,'http://127.0.0.1');
  if(url.pathname==='/'||url.pathname==='/index.html'){
   const source=fs.readFileSync(path.join(root,'tests/fixtures/dom-queries-reference.js'),'utf8'),name=url.searchParams.get('case')||selected||null;
   const html='<!doctype html><html><head><meta charset="utf-8"><title>DOM Queries Reference</title></head><body><h1>DOM Queries Reference</h1><p id="status">Running</p><pre id="result"></pre><script>'+source+'\ntry{const result={};const selected='+JSON.stringify(name)+';for(const name of selected?[selected]:Object.keys(queryCases)){document.getElementById("status").textContent="Running "+name;result[name]=queryCases[name]();document.getElementById("result").textContent=JSON.stringify(result,null,2);}document.getElementById("status").textContent="Complete";}catch(error){document.getElementById("status").textContent="Error";document.getElementById("result").textContent=String(error.stack||error);}</script></body></html>';
   response.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'});response.end(html);
  }else{response.writeHead(404);response.end();}
 });server.listen(0,'127.0.0.1',()=>console.log('Query native reference: http://127.0.0.1:'+server.address().port+'/index.html'));
}
