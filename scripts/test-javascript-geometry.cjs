// Luau geometry adapter fixtures and a served native browser comparison page.
const fs=require('node:fs');
const path=require('node:path');
const cp=require('node:child_process');
const http=require('node:http');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const filter=process.argv.find(arg=>arg.startsWith('--case='))?.slice(7);
const fixtures=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-geometry.json'),'utf8')).filter(item=>!filter||item.name.includes(filter));
assert.ok(fixtures.length,'No matching geometry fixture');
const html=`<!doctype html><meta charset="utf-8"><title>Native JavaScript geometry fixtures</title><style>body{font:14px monospace}iframe{width:640px;height:480px;border:0;display:block}pre{white-space:pre-wrap}</style><h1>Native JavaScript geometry fixtures</h1><pre id="results">Running…</pre><div id="frames"></div><script>
const fixtures=${JSON.stringify(fixtures).replace(/</g,'\\u003c')};
const setup=${JSON.stringify('<!doctype html><style>html,body{margin:0;width:800px;height:1600px}*{scrollbar-width:none}#scroller{position:absolute;left:10px;top:20px;width:100px;height:80px;padding:5px;border:2px solid black;overflow:auto}#child{position:absolute;left:5px;top:6px;width:200px;height:160px}#fixed{position:fixed;left:200px;top:40px;width:20px;height:30px}#invisible{display:none;width:10px;height:10px}#inlinehost{position:absolute;left:10px;top:100px;font:10px/10px monospace}#inlinehost span.chunk{display:inline-block;vertical-align:top;height:10px}</style><div id="scroller"><div id="child"></div></div><div id="fixed"></div><div id="invisible"></div><div id="inlinehost"><span id="inline"><span class="chunk" style="width:20px"></span><br><span class="chunk" style="width:30px"></span></span></div>').replace(/</g,'\\u003c')};
const outcomes=[];
(async()=>{for(const fixture of fixtures){const frame=document.createElement('iframe');document.getElementById('frames').append(frame);await new Promise(resolve=>{frame.onload=resolve;frame.srcdoc=setup});const win=frame.contentWindow;const values=[];win.record=value=>values.push(String(value));win.resizeViewport=(width,height)=>{frame.style.width=width+'px';frame.style.height=height+'px'};win.pumpEvents=()=>new Promise(resolve=>win.requestAnimationFrame(()=>win.requestAnimationFrame(resolve)));try{await win.eval(fixture.nativeSource||fixture.source);const pass=JSON.stringify(values)===JSON.stringify(fixture.expected);outcomes.push({name:fixture.name,pass,values,expected:fixture.expected})}catch(error){outcomes.push({name:fixture.name,pass:false,error:error.name+': '+error.message,values})}frame.remove()}document.getElementById('results').textContent=JSON.stringify(outcomes,null,2);document.body.dataset.complete='true';document.body.dataset.passed=String(outcomes.every(item=>item.pass))})()
</script>`;
if(process.argv.includes('--serve')){
 const port=Number(process.env.GEOMETRY_TEST_PORT||8766);
 const server=http.createServer((_request,response)=>{response.writeHead(200,{'Content-Type':'text/html; charset=utf-8'});response.end(html)});
 server.listen(port,'127.0.0.1',()=>console.log(`Native geometry fixture page: http://127.0.0.1:${port}`));
 return;
}
const sources=new Map();
function readModule(id){
 if(sources.has(id))return;sources.set(id,'');
 let source=fs.readFileSync(path.join(root,'src/HTMLEngine',id+'.luau'),'utf8');
 source=source.replace(/require\(script((?:\.[A-Za-z_][A-Za-z_0-9]*)+)\)/g,(_,chain)=>{
  const parts=id.split('/');for(const item of chain.slice(1).split('.'))item==='Parent'?parts.pop():parts.push(item);
  const target=parts.join('/');readModule(target);return `require(${JSON.stringify(target)})`;
 });sources.set(id,source);
}
for(const id of ['JavaScript/VM','JavaScript/Geometry','JavaScript/HostEvents','JavaScript/Promises','CSS/Transform2D','CSS/LengthExpression'])readModule(id);
function literal(value){let eq='===';while(value.includes(']'+eq+']'))eq+='=';return '['+eq+'['+value+']'+eq+']';}
function toLua(value){if(typeof value==='string')return literal(value);if(typeof value==='number'||typeof value==='boolean')return String(value);if(Array.isArray(value))return '{'+value.map(toLua).join(',')+'}';return '{'+Object.entries(value).map(([key,item])=>'[ '+literal(key)+' ]='+toLua(item)).join(',')+'}';}
let bundle='local Color3={new=function(r,g,b)return {R=r,G=g,B=b}end,fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end}\nlocal modules={}\nlocal loaded={}\nlocal function require(id)\nif loaded[id]~=nil then return loaded[id] end\nassert(modules[id],"Missing module "..id)\nlocal result=modules[id]()\nloaded[id]=result\nreturn result\nend\n';
for(const [id,source]of sources)bundle+=`modules[${JSON.stringify(id)}]=function()\n${source}\nend\n`;
bundle+='local test=(function()\n'+fs.readFileSync(path.join(root,'tests/JavaScriptGeometry.luau'),'utf8')+'\nend)()\n';
bundle+='test(require("JavaScript/VM"),require("JavaScript/Geometry"),require("JavaScript/HostEvents"),'+toLua(fixtures)+',require("CSS/Transform2D"),require("CSS/LengthExpression"),require("JavaScript/Promises"))\n';
bundle+=`print("Luau geometry: ${fixtures.length} shared browser cases passed.")\n`;
const output=path.join(root,`build/javascript-geometry-tests-${process.pid}.luau`);fs.writeFileSync(output,bundle);
const result=cp.spawnSync(process.env.LUAU_BIN||path.join(root,'build/tools/luau/luau.exe'),[output],{stdio:'inherit'});if(result.error)throw result.error;process.exit(result.status??1);
