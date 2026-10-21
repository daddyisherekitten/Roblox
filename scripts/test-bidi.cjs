// Runs full actual Unicode17 conformance bytes independently from GUI rendering.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),sources=new Map();
function read(id){
  if(sources.has(id))return;sources.set(id,'');
  if(id==='WorkContext'){sources.set(id,'return {checkpoint=function()end}');return;}
  const file=path.join(root,'src/HTMLEngine',id+'.luau');
  const source=fs.readFileSync(file,'utf8').replace(/require\(script((?:\.[A-Za-z_][A-Za-z_0-9]*)+)\)/g,(_,chain)=>{
    const parts=id.split('/');for(const item of chain.slice(1).split('.'))item==='Parent'?parts.pop():parts.push(item);
    const dependency=parts.join('/');read(dependency);return 'require('+JSON.stringify(dependency)+')';
  });sources.set(id,source);
}
read('Layout/Bidi');let bundle='local modules,loaded={},{}\nlocal function require(id)if loaded[id]then return loaded[id]end;local value=modules[id]();loaded[id]=value;return value end\n';
for(const[id,source]of sources)bundle+='modules['+JSON.stringify(id)+']=function()\n'+source+'\nend\n';
bundle+='local test=(function()\n'+fs.readFileSync(path.join(root,'tests/Bidi.luau'),'utf8')+'\nend)()\ntest(require("Layout/Bidi")';
for(const name of ['BidiTest.txt','BidiCharacterTest.txt']){
  const source=fs.readFileSync(path.join(root,'scripts/data/unicode-bidi-17.0.0',name),'utf8');
  if(source.includes(']=====]'))throw new Error('Corpus string delimiter collision');bundle+=',[=====['+source+']=====]';
}bundle+=')\n';
const file=path.join(root,'build/bidi-conformance-'+process.pid+'.luau');fs.writeFileSync(file,bundle);
const result=cp.spawnSync(path.join(root,'build/tools/luau/luau.exe'),[file],{stdio:'inherit'});
if(result.error)throw result.error;process.exitCode=result.status??1;
