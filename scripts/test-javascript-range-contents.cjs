// Author the same Range operations against Chromium and the real Luau DOM.
// Bundles and results are PID scoped; native fixtures each use a fresh realm.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const filter=process.argv.find(x=>x.startsWith('--case='))?.slice(7);
const fixtures=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-range-contents.json'),'utf8')).filter(f=>!filter||f.name.includes(filter));
assert.ok(fixtures.length,'No matching Range contents fixtures');
if(process.argv.includes('--serve')){
 const page=()=>{
 const fixtures=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-range-contents.json'),'utf8')).filter(f=>!filter||f.name.includes(filter));
 const data=JSON.stringify(fixtures).replaceAll('<','\\u003c');
 const html=`<!doctype html><meta charset="utf-8"><title>Range Contents Reference</title><h1>Range Contents Reference</h1><pre id="result">Running</pre><script>const fixtures=${data};const results=[];for(const f of fixtures){const frame=document.createElement('iframe');frame.hidden=true;document.body.append(frame);const values=[];let error;try{frame.contentWindow.Function('record',f.source)(v=>values.push(String(v)))}catch(e){error=e.name+': '+e.message}const expected=f.browserExpected||f.expected;const standard=f.standardExpected||f.expected;results.push({name:f.name,values,expected,pass:!error&&JSON.stringify(values)===JSON.stringify(expected),matchesStandard:!error&&JSON.stringify(values)===JSON.stringify(standard),difference:f.difference,error});frame.remove()}document.getElementById('result').textContent=JSON.stringify(results)</script>`;
 return html;
 };
 const server=require('node:http').createServer((req,res)=>{res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'});res.end(page())});
 const port=Number(process.argv.find(x=>x.startsWith('--port='))?.slice(7)||0);
 server.listen(port,'127.0.0.1',()=>console.log('Native Range contents reference: http://127.0.0.1:'+server.address().port+'/'));return;
}
function literal(value){let eq='===';while(value.includes(']'+eq+']'))eq+='=';return'['+eq+'['+value+']'+eq+']'}
function lua(value){if(typeof value==='string')return literal(value);if(typeof value==='number'||typeof value==='boolean')return String(value);if(Array.isArray(value))return'{'+value.map(lua).join(',')+'}';return'{'+Object.entries(value).map(([key,item])=>'[ '+literal(key)+' ]='+lua(item)).join(',')+'}'}
const modules=new Map();
function read(id){if(modules.has(id))return;modules.set(id,'');const base=path.join(root,'src/HTMLEngine',id);const file=fs.existsSync(base+'.luau')?base+'.luau':path.join(base,'init.luau');let source=fs.readFileSync(file,'utf8');source=source.replace(/require\(script((?:\.[A-Za-z_][A-Za-z_0-9]*)+)\)/g,(_,chain)=>{const parts=id.split('/');for(const item of chain.slice(1).split('.'))item==='Parent'?parts.pop():parts.push(item);const next=parts.join('/');read(next);return'require('+JSON.stringify(next)+')'});modules.set(id,source)}
for(const id of ['JavaScript/VM','JavaScript/DOM','JavaScript/DOMRanges','JavaScript/RangeContents','HTML/Parser','DOM/Node'])read(id);
let bundle='local Color3={new=function(r,g,b)return{R=r,G=g,B=b}end,fromRGB=function(r,g,b)return{R=r/255,G=g/255,B=b/255}end}\nlocal Vector2={new=function(x,y)return{X=x,Y=y}end};local UDim2={fromOffset=function(x,y)return{x,y}end}\nlocal Enum={Font={Arial="Arial",SourceSans="SourceSans",Ubuntu="Ubuntu"}}\nlocal modules,loaded={},{}\nlocal function require(id)if loaded[id]~=nil then return loaded[id]end;local value=assert(modules[id],id)();loaded[id]=value;return value end\n';
for(const[id,source]of modules)bundle+=`modules[${JSON.stringify(id)}]=function()\n${source}\nend\n`;
bundle+='local test=(function()\n'+fs.readFileSync(path.join(root,'tests/JavaScriptRangeContents.luau'),'utf8')+'\nend)()\ntest(require("JavaScript/VM"),require("JavaScript/DOM"),require("JavaScript/DOMRanges"),require("JavaScript/RangeContents"),require("HTML/Parser"),require("DOM/Node"),'+lua(fixtures)+')\n';
const file=path.join(root,`build/javascript-range-contents-${process.pid}.luau`);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bundle);
const result=cp.spawnSync(process.env.LUAU_BIN||path.join(root,'build/tools/luau/luau.exe'),[file],{encoding:'utf8',maxBuffer:4*1024*1024});
process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');if(result.error)throw result.error;process.exitCode=result.status??1;
const match=result.stdout?.match(/^RANGE_CONTENTS_RESULT (.+)$/m);if(match){const file=path.join(root,`build/javascript-range-contents-${process.pid}.json`);fs.writeFileSync(file,JSON.stringify(JSON.parse(match[1]),null,2)+'\n');console.log('Range contents engine traces:',file)}
