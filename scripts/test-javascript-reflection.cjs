// Shared deterministic fixtures run in native ECMAScript and the official Luau
// CLI. This runner is independent of the engine's browser/layout test bundle.
const fs=require('node:fs');
const path=require('node:path');
const cp=require('node:child_process');
const assert=require('node:assert/strict');
const nodeVM=require('node:vm');
const root=path.resolve(__dirname,'..');
const filter=process.argv.find(arg=>arg.startsWith('--case='))?.slice(7);
const fixtures=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-reflection.json'),'utf8')).filter(item=>!filter||item.name.includes(filter));
assert.ok(fixtures.length,'No matching reflection fixture');
for(const fixture of fixtures){
 const values=[];
 const context=nodeVM.createContext({record:value=>values.push(String(value)),URL,URLSearchParams});
 nodeVM.runInContext(fixture.source,context);
 assert.deepEqual(values,fixture.expected,`Native ECMAScript: ${fixture.name}`);
}
if(process.argv.includes('--native-only')){
 console.log(`Native ECMAScript reflection: ${fixtures.length} shared cases passed.`);
 process.exit(0);
}
const sources=new Map();
function readModule(id){
 if(sources.has(id))return;
 sources.set(id,'');
 let source=fs.readFileSync(path.join(root,'src/HTMLEngine',id+'.luau'),'utf8');
 source=source.replace(/require\(script((?:\.[A-Za-z_][A-Za-z_0-9]*)+)\)/g,(_,chain)=>{
  const parts=id.split('/');
  for(const item of chain.slice(1).split('.'))item==='Parent'?parts.pop():parts.push(item);
  const target=parts.join('/');readModule(target);return `require(${JSON.stringify(target)})`;
 });
 sources.set(id,source);
}
readModule('JavaScript/VM');readModule('JavaScript/Reflection');
function literal(value){let eq='===';while(value.includes(']'+eq+']'))eq+='=';return '['+eq+'['+value+']'+eq+']';}
function toLua(value){
 if(typeof value==='string')return literal(value);
 if(typeof value==='number')return String(value);
 if(typeof value==='boolean')return String(value);
 if(Array.isArray(value))return '{'+value.map(toLua).join(',')+'}';
 return '{'+Object.entries(value).map(([key,item])=>'[ '+literal(key)+' ]='+toLua(item)).join(',')+'}';
}
let bundle='local modules={}\nlocal loaded={}\nlocal function require(id)\nif loaded[id]~=nil then return loaded[id] end\nassert(modules[id],"Missing module "..id)\nlocal result=modules[id]()\nloaded[id]=result\nreturn result\nend\n';
for(const [id,source]of sources)bundle+=`modules[${JSON.stringify(id)}]=function()\n${source}\nend\n`;
bundle+='local test=(function()\n'+fs.readFileSync(path.join(root,'tests/JavaScriptReflection.luau'),'utf8')+'\nend)()\n';
bundle+='test(require("JavaScript/VM"),require("JavaScript/Reflection"),'+toLua(fixtures)+')\n';
bundle+='print("Luau reflection: '+fixtures.length+' shared cases passed.")\n';
const output=path.join(root,`build/javascript-reflection-tests-${process.pid}.luau`);fs.writeFileSync(output,bundle);
const executable=process.env.LUAU_BIN||path.join(root,'build/tools/luau/luau.exe');
const result=cp.spawnSync(executable,[output],{stdio:'inherit'});
if(result.error)throw result.error;
process.exit(result.status??1);
