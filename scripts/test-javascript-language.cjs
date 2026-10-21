// Shared deterministic fixtures run in native ECMAScript and the official Luau
// CLI. This runner is independent of the engine's browser/layout test bundle.
const fs=require('node:fs');
const path=require('node:path');
const cp=require('node:child_process');
const assert=require('node:assert/strict');
const nodeVM=require('node:vm');
const root=path.resolve(__dirname,'..');
const filter=process.argv.find(arg=>arg.startsWith('--case='))?.slice(7);
const fixtureFile=process.argv.find(arg=>arg.startsWith('--fixtures='))?.slice(11)||'javascript-language.json';
assert.equal(path.basename(fixtureFile),fixtureFile,'Fixture must be a file name');
const fixtures=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures',fixtureFile),'utf8')).filter(item=>!filter||item.name.includes(filter));
assert.ok(fixtures.length,'No matching language fixture');
for(const fixture of fixtures){
 const values=[];
 const scope={record:value=>values.push(String(value)),URL,URLSearchParams};
 const context=process.argv.includes('--global-object')?nodeVM.createContext(nodeVM.constants.DONT_CONTEXTIFY):nodeVM.createContext(scope);
 if(process.argv.includes('--global-object'))Object.assign(context,scope);
 if(fixture.realmSource){
  const other=nodeVM.createContext(nodeVM.constants.DONT_CONTEXTIFY);other.record=scope.record;
  nodeVM.runInContext(fixture.realmSource,other);
  for(const key of fixture.realmExports)context[key]=other[key];
 }
 for(const step of fixture.steps||[{source:fixture.source}]){
  if(step.error)assert.throws(()=>nodeVM.runInContext(step.source,context),error=>error.name===(step.nativeError||step.error),`Native ${fixture.name}: ${step.nativeError||step.error}`);
  else nodeVM.runInContext(step.source,context);
 }
 assert.deepEqual(values,fixture.expected,`Native ECMAScript: ${fixture.name}`);
}
if(process.argv.includes('--native-only')){
 console.log(`Native ECMAScript language: ${fixtures.length} shared cases passed.`);
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
readModule('JavaScript/VM');readModule('JavaScript/StandardLibrary');readModule('JavaScript/BinaryData');
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
bundle+='local test=(function()\n'+fs.readFileSync(path.join(root,'tests/JavaScriptLanguage.luau'),'utf8')+'\nend)()\n';
bundle+='test(require("JavaScript/VM"),require("JavaScript/StandardLibrary"),'+toLua(fixtures)+',require("JavaScript/BinaryData"))\n';
bundle+='print("Luau language: '+fixtures.length+' shared cases passed.")\n';
const output=path.join(root,`build/javascript-language-tests-${process.pid}.luau`);fs.writeFileSync(output,bundle);
const executable=process.env.LUAU_BIN||path.join(root,'build/tools/luau/luau.exe');
const result=cp.spawnSync(executable,[output],{stdio:'inherit'});
if(result.error)throw result.error;
process.exit(result.status??1);
