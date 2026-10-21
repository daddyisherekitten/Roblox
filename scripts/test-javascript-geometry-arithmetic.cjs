// The same Geometry arithmetic cases run in the official Luau CLI and Chromium.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),http=require('node:http');
const root=path.resolve(__dirname,'..');
const filter=process.argv.find(a=>a.startsWith('--case='))?.slice(7);
const fixtures=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-geometry-arithmetic.json'),'utf8')).filter(f=>!filter||f.name.includes(filter));
if(!fixtures.length)throw new Error('No matching Geometry arithmetic fixture');
if(process.argv.includes('--serve')){
 const data=JSON.stringify(fixtures).replaceAll('<','\\u003c');
 const html=`<!doctype html><meta charset="utf-8"><title>Geometry arithmetic comparison</title><h1>Geometry arithmetic</h1><pre id="result">Running</pre><script>const fixtures=${data};const results=[];for(const f of fixtures){const frame=document.createElement('iframe');frame.hidden=true;document.body.append(frame);const values=[];let error;try{frame.contentWindow.Function('record',f.source)(v=>values.push(String(v)))}catch(e){error=e.name+': '+e.message}results.push({name:f.name,values,expected:f.nativeExpected||f.expected,engineExpected:f.expected,nativeDifference:f.nativeDifference,pass:!error&&JSON.stringify(values)===JSON.stringify(f.nativeExpected||f.expected),matchesEngine:!error&&JSON.stringify(values)===JSON.stringify(f.expected),error});frame.remove()}document.getElementById('result').textContent=JSON.stringify(results)</script>`;
 http.createServer((req,res)=>{res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'});res.end(html)}).listen(Number(process.env.GEOMETRY_ARITHMETIC_TEST_PORT||9164),'127.0.0.1',()=>console.log('Native Geometry arithmetic: http://127.0.0.1:'+(process.env.GEOMETRY_ARITHMETIC_TEST_PORT||9164)+'/'));
 return;
}
const sources=new Map();
function readModule(id){if(sources.has(id))return;sources.set(id,'');let source=fs.readFileSync(path.join(root,'src/HTMLEngine',id+'.luau'),'utf8');source=source.replace(/require\(script((?:\.[A-Za-z_][A-Za-z_0-9]*)+)\)/g,(_,chain)=>{const parts=id.split('/');for(const item of chain.slice(1).split('.'))item==='Parent'?parts.pop():parts.push(item);const target=parts.join('/');readModule(target);return `require(${JSON.stringify(target)})`;});sources.set(id,source);}
for(const id of ['JavaScript/VM','JavaScript/Geometry','JavaScript/HostEvents','JavaScript/BinaryData','JavaScript/StructuredClone'])readModule(id);
function literal(value){let eq='===';while(value.includes(']'+eq+']'))eq+='=';return '['+eq+'['+value+']'+eq+']';}
function lua(value){if(typeof value==='string')return literal(value);if(typeof value==='number'||typeof value==='boolean')return String(value);if(Array.isArray(value))return '{'+value.map(lua).join(',')+'}';return '{'+Object.entries(value).map(([k,v])=>'[ '+literal(k)+' ]='+lua(v)).join(',')+'}';}
let bundle='local Color3={new=function(r,g,b)return {R=r,G=g,B=b}end,fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end}\nlocal modules={}\nlocal loaded={}\nlocal function require(id)\nif loaded[id]~=nil then return loaded[id]end\nlocal value=assert(modules[id],id)()\nloaded[id]=value\nreturn value\nend\n';
for(const [id,source]of sources)bundle+=`modules[${JSON.stringify(id)}]=function()\n${source}\nend\n`;
bundle+='local test=(function()\n'+fs.readFileSync(path.join(root,'tests/JavaScriptGeometryMath.luau'),'utf8')+'\nend)()\ntest(require("JavaScript/VM"),require("JavaScript/Geometry"),require("JavaScript/HostEvents"),require("JavaScript/BinaryData"),'+lua(fixtures)+',require("JavaScript/StructuredClone"))\n';
bundle+=`print("Geometry arithmetic: ${fixtures.length} shared cases passed.")\n`;
const output=path.join(root,`build/javascript-geometry-arithmetic-${process.pid}.luau`);fs.writeFileSync(output,bundle);
const result=cp.spawnSync(process.env.LUAU_BIN||path.join(root,'build/tools/luau/luau.exe'),[output],{stdio:'inherit'});if(result.error)throw result.error;process.exit(result.status??1);
