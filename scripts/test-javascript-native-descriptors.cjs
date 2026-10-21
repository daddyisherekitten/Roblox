// Isolated integration bundle; does not write the shared HTML test runner.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),sources=new Map();
function read(id){
 if(sources.has(id))return;sources.set(id,'');
 const base=path.join(root,'src/HTMLEngine',id),file=fs.existsSync(base+'.luau')?base+'.luau':path.join(base,'init.luau');
 const source=fs.readFileSync(file,'utf8').replace(/require\(script((?:\.[A-Za-z_][A-Za-z_0-9]*)+)\)/g,(_,chain)=>{
  const parts=id.split('/');for(const item of chain.slice(1).split('.'))item==='Parent'?parts.pop():parts.push(item);
  const dependency=parts.join('/');read(dependency);return 'require('+JSON.stringify(dependency)+')';
 });sources.set(id,source);
}
const ids=['HTML/Parser','DOM/Node','JavaScript/Runtime','JavaScript/VM','Input/Events','JavaScript/HostEvents','JavaScript/Geometry'];
for(const id of ids)read(id);
let bundle='local Color3={new=function(r,g,b)return {R=r,G=g,B=b}end,fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end}\nlocal Enum={Font={Arial="Arial",SourceSans="SourceSans",Ubuntu="Ubuntu"}}\nlocal modules,loaded={},{}\nlocal function require(id)if loaded[id]~=nil then return loaded[id]end;local value=assert(modules[id],id)();loaded[id]=value;return value end\n';
for(const[id,source]of sources)bundle+='modules['+JSON.stringify(id)+']=function()\n'+source+'\nend\n';
bundle+='local test=(function()\n'+fs.readFileSync(path.join(root,'tests/JavaScriptNativeDescriptors.luau'),'utf8')+'\nend)()\ntest('+ids.map(id=>'require('+JSON.stringify(id)+')').join(',')+')\n';
const file=path.join(root,'build',`javascript-native-descriptors-${process.pid}.luau`);fs.writeFileSync(file,bundle);
const result=cp.spawnSync(process.env.LUAU_BIN||path.join(root,'build/tools/luau/luau.exe'),[file],{stdio:'inherit'});
if(result.error)throw result.error;process.exitCode=result.status??1;
