// Iterator helper traces use native ECMAScript where the feature is present,
// plus an independent Luau bundle. --serve exposes the same authored fixtures.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),assert=require('node:assert/strict'),native=require('node:vm');
const root=path.resolve(__dirname,'..');
const filter=process.argv.find(x=>x.startsWith('--case='))?.slice(7);
const fixtures=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-iterator-helpers.json'),'utf8')).filter(f=>!filter||f.name.includes(filter));assert.ok(fixtures.length);
function supported(context,fixture){return(fixture.requires||[]).every(feature=>native.runInContext('typeof '+feature,context)==='function')}
if(process.argv.includes('--serve')){
 const data=JSON.stringify(fixtures).replaceAll('<','\\u003c');
 const html=`<!doctype html><meta charset="utf-8"><title>Iterator helper fixtures</title><h1>Iterator helper fixtures</h1><pre id="result">Running</pre><script>const fixtures=${data};const results=[];for(const f of fixtures){const frame=document.createElement('iframe');frame.hidden=true;document.body.append(frame);const values=[];let error;const supported=(f.requires||[]).every(p=>{let v=frame.contentWindow;for(const k of p.split('.'))v=v?.[k];return typeof v==='function'});if(supported){try{frame.contentWindow.Function('record',f.source)(v=>values.push(String(v)))}catch(e){error=e.name+': '+e.message}}const expected=f.browserExpected||f.expected;const standard=f.standardExpected||expected;results.push({name:f.name,values,expected,pass:supported&&!error&&JSON.stringify(values)===JSON.stringify(expected),matchesStandard:supported&&!error&&JSON.stringify(values)===JSON.stringify(standard),difference:f.difference,unavailable:!supported,error});frame.remove()}document.getElementById('result').textContent=JSON.stringify(results)</script>`;
 require('node:http').createServer((req,res)=>{res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'});res.end(html)}).listen(9162,'127.0.0.1',()=>console.log('Native browser iterators: http://127.0.0.1:9162/'));return;
}
let nativeCount=0,unavailable=[];
for(const f of fixtures){const values=[];const context=native.createContext({record:v=>values.push(String(v)),URL,URLSearchParams});if(!supported(context,f)){unavailable.push(f.name);continue}native.runInContext(f.source,context);assert.deepEqual(values,f.expected,'Native: '+f.name);nativeCount++}
console.log(`Native iterators: ${nativeCount} cases passed; ${unavailable.length} unavailable${unavailable.length?' ('+unavailable.join(', ')+')':''}.`);
if(process.argv.includes('--native-only'))process.exit(0);
function literal(v){let e='===';while(v.includes(']'+e+']'))e+='=';return'['+e+'['+v+']'+e+']'}
function lua(v){if(typeof v==='string')return literal(v);if(typeof v==='number'||typeof v==='boolean')return String(v);if(Array.isArray(v))return'{'+v.map(lua).join(',')+'}';return'{'+Object.entries(v).map(([k,x])=>'[ '+literal(k)+' ]='+lua(x)).join(',')+'}'}
const sources=new Map();function read(id){if(sources.has(id))return;sources.set(id,'');let source=fs.readFileSync(path.join(root,'src/HTMLEngine',id+'.luau'),'utf8');source=source.replace(/require\(script((?:\.[A-Za-z_][A-Za-z_0-9]*)+)\)/g,(_,chain)=>{const parts=id.split('/');for(const item of chain.slice(1).split('.'))item==='Parent'?parts.pop():parts.push(item);const next=parts.join('/');read(next);return'require('+JSON.stringify(next)+')'});sources.set(id,source)}
for(const id of ['JavaScript/VM','JavaScript/IteratorHelpers'])read(id);
let out='local modules,loaded={},{}\nlocal function require(id)if loaded[id]~=nil then return loaded[id]end;local v=assert(modules[id],id)();loaded[id]=v;return v end\n';
for(const[id,source]of sources)out+=`modules[${JSON.stringify(id)}]=function()\n${source}\nend\n`;
out+='local test=(function()\n'+fs.readFileSync(path.join(root,'tests/JavaScriptIteratorHelpers.luau'),'utf8')+'\nend)()\ntest(require("JavaScript/VM"),require("JavaScript/IteratorHelpers"),'+lua(fixtures)+')\n';
const file=path.join(root,`build/javascript-iterator-helper-tests-${process.pid}.luau`);fs.writeFileSync(file,out);
const r=cp.spawnSync(process.env.LUAU_BIN||path.join(root,'build/tools/luau/luau.exe'),[file],{stdio:'inherit'});if(r.error)throw r.error;process.exitCode=r.status??1;
