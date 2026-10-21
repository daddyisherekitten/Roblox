// Executes the real lazy Luau lookup against the unmodified pinned UCD file.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),sources=new Map();
function read(id){
 if(sources.has(id))return;sources.set(id,'');
 if(id==='WorkContext'){sources.set(id,'return {checkpoint=function()end}');return;}
 const source=fs.readFileSync(path.join(root,'src/HTMLEngine',id+'.luau'),'utf8').replace(/require\(script((?:\.[A-Za-z_][A-Za-z_0-9]*)+)\)/g,(_,chain)=>{
  const parts=id.split('/');for(const item of chain.slice(1).split('.'))item==='Parent'?parts.pop():parts.push(item);
  const dependency=parts.join('/');read(dependency);return 'require('+JSON.stringify(dependency)+')';
 });sources.set(id,source);
}
read('Layout/VerticalOrientation');
let bundle='local modules,loaded={},{}\nlocal function require(id)if loaded[id]then return loaded[id]end;local value=modules[id]();loaded[id]=value;return value end\n';
for(const[id,source]of sources)bundle+='modules['+JSON.stringify(id)+']=function()\n'+source+'\nend\n';
const corpus=fs.readFileSync(path.join(root,'scripts/data/unicode-vertical-17.0.0/VerticalOrientation.txt'),'utf8');
if(!corpus.startsWith('# VerticalOrientation-17.0.0.txt')||corpus.includes(']=====]'))throw new Error('Unexpected pinned UCD file');
const enclosing=fs.readFileSync(path.join(root,'scripts/data/unicode-17.0.0/UnicodeData.txt'),'utf8').split(/\r?\n/).filter(line=>line.split(';')[2]==='Me').map(line=>parseInt(line.split(';')[0],16));
bundle+='local orientation=require("Layout/VerticalOrientation")\nassert(loaded["Layout/VerticalOrientationData"]==nil,"Horizontal pages must not load orientation resources")\n';
bundle+='local test=(function()\n'+fs.readFileSync(path.join(root,'tests/VerticalOrientation.luau'),'utf8')+'\nend)()\ntest(orientation,[=====['+corpus+']=====],{'+enclosing.join(',')+'})\n';
const file=path.join(root,'build/vertical-orientation-'+process.pid+'.luau');fs.writeFileSync(file,bundle);
const result=cp.spawnSync(process.env.LUAU_BIN||path.join(root,'build/tools/luau/luau.exe'),[file],{stdio:'inherit'});
if(result.error)throw result.error;process.exitCode=result.status??1;
