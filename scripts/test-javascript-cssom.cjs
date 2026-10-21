// CSSOM fixtures run in a fresh browser realm and in the actual Luau runtime.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const fixturePath=path.join(root,'tests/fixtures/javascript-cssom.json');
const fixtures=JSON.parse(fs.readFileSync(fixturePath,'utf8'));
if(process.argv.includes('--serve')){
 const server=require('node:http').createServer((req,res)=>{
 const data=fs.readFileSync(fixturePath,'utf8').replaceAll('<','\\u003c');
 const html=`<!doctype html><meta charset="utf-8"><title>CSSOM Reference</title><h1>CSSOM Reference</h1><pre id="result">Running</pre><script>const cases=${data};const results=[];(async()=>{for(const f of cases){const frame=document.createElement('iframe');document.body.append(frame);const values=[];let error;try{const source=f.async?'return (async()=>{'+f.source+'})();':f.source;await frame.contentWindow.Function('record',source)(v=>values.push(String(v)))}catch(e){error=e.name+': '+e.message}results.push({name:f.name,values,error,pass:!error&&JSON.stringify(values)===JSON.stringify(f.browserExpected||f.expected),matchesProfile:!error&&JSON.stringify(values)===JSON.stringify(f.expected),difference:f.difference});frame.remove()}document.getElementById('result').textContent=JSON.stringify(results)})()</script>`;
 res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'});res.end(html)});
 server.listen(0,'127.0.0.1',()=>console.log('Native CSSOM reference: http://127.0.0.1:'+server.address().port+'/'));return;
}
function literal(value){let eq='===';while(value.includes(']'+eq+']'))eq+='=';return'['+eq+'['+value+']'+eq+']'}
function lua(value){if(typeof value==='string')return literal(value);if(typeof value==='number'||typeof value==='boolean')return String(value);if(Array.isArray(value))return'{'+value.map(lua).join(',')+'}';return'{'+Object.entries(value).map(([k,v])=>'[ '+literal(k)+' ]='+lua(v)).join(',')+'}'}
const modules=new Map();
function read(id){if(modules.has(id))return;modules.set(id,'');const base=path.join(root,'src/HTMLEngine',id);const file=fs.existsSync(base+'.luau')?base+'.luau':path.join(base,'init.luau');let source=fs.readFileSync(file,'utf8');source=source.replace(/require\(script((?:\.[A-Za-z_][A-Za-z_0-9]*)+)\)/g,(_,chain)=>{const parts=id.split('/');for(const item of chain.slice(1).split('.'))item==='Parent'?parts.pop():parts.push(item);const next=parts.join('/');read(next);return'require('+JSON.stringify(next)+')'});modules.set(id,source)}
for(const id of ['JavaScript/Runtime','JavaScript/VM','HTML/Parser','Input/Events'])read(id);
let bundle='local Color3={new=function(r,g,b)return{R=r,G=g,B=b}end,fromRGB=function(r,g,b)return{R=r/255,G=g/255,B=b/255}end}\nlocal Vector2={new=function(x,y)return{X=x,Y=y}end};local UDim2={fromOffset=function(x,y)return{x,y}end}\nlocal Enum={Font={Arial="Arial",SourceSans="SourceSans",Ubuntu="Ubuntu"}}\nlocal modules,loaded={},{}\nlocal function require(id)if loaded[id]~=nil then return loaded[id]end;local value=assert(modules[id],id)();loaded[id]=value;return value end\n';
for(const[id,source]of modules)bundle+=`modules[${JSON.stringify(id)}]=function()\n${source}\nend\n`;
bundle+='local test=(function()\n'+fs.readFileSync(path.join(root,'tests/JavaScriptCSSOM.luau'),'utf8')+'\nend)()\ntest(require("HTML/Parser"),require("JavaScript/Runtime"),require("JavaScript/VM"),require("Input/Events"),'+lua(fixtures.filter(x=>!x.browserOnly))+')\n';
const file=path.join(root,`build/javascript-cssom-${process.pid}.luau`);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bundle);
const result=cp.spawnSync(process.env.LUAU_BIN||path.join(root,'build/tools/luau/luau.exe'),[file],{encoding:'utf8',maxBuffer:4*1024*1024});
process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');if(result.error)throw result.error;process.exitCode=result.status??1;

