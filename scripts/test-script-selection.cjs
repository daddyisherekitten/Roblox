const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),sources=new Map();
function toLua(value){
 if(value===null)return 'nil';
 if(Array.isArray(value))return '{'+value.map(toLua).join(',')+'}';
 if(typeof value==='object')return '{'+Object.entries(value).map(([key,item])=>'['+toLua(key)+']='+toLua(item)).join(',')+'}';
 if(typeof value==='string')return '"'+value.replace(/\\/g,'\\\\').replace(/"/g,'\\"').replace(/[\x00-\x1f\x7f]/g,c=>'\\'+String(c.charCodeAt(0)).padStart(3,'0'))+'"';
 return String(value);
}
const whitespace=toLua(JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/whitespace-browser.json'),'utf8')));
const overrides={
 'Rendering/GuiFactory':"return {create=function(kind,parent,props)local o=table.clone(props);o.Parent=parent;o.Kind=kind;o.Destroy=function(self)self.Destroyed=true end;return o end}",
 'Layout/TextMeasure':"return {measure=function(text,font,size)local count=0;for _ in utf8.graphemes(text)do count+=1 end;return Vector2.new(count*size/2,size)end}",
};
function read(id){
 if(sources.has(id))return;sources.set(id,'');
 if(overrides[id]){sources.set(id,overrides[id]);return;}
 const base=path.join(root,'src/HTMLEngine',id),file=fs.existsSync(base+'.luau')?base+'.luau':path.join(base,'init.luau');
 const source=fs.readFileSync(file,'utf8').replace(/require\(script((?:\.[A-Za-z_][A-Za-z_0-9]*)+)\)/g,(_,chain)=>{
  const parts=id.split('/');for(const item of chain.slice(1).split('.'))item==='Parent'?parts.pop():parts.push(item);
  const dep=parts.join('/');read(dep);return 'require('+JSON.stringify(dep)+')';
 });sources.set(id,source);
}
const ids=['HTML/Parser','DOM/Node','CSS/InlineStyle','CSS/Stylesheet','Input/TextSelection','Layout/InlineWords','Layout/OverflowWrap','Rendering/ScriptSelection','Layout/TextOverflow'];
ids.forEach(read);
const clusters=['A😀B','ÄB','ß','😀'],seg=new Intl.Segmenter('de',{granularity:'grapheme'});
for(const text of [...clusters])for(const {segment}of seg.segment(text))if(!clusters.includes(segment))clusters.push(segment);
const ranges=clusters.map(s=>'['+JSON.stringify(s)+']={'+[...seg.segment(s)].map(({segment,index})=>'{'+[Buffer.byteLength(s.slice(0,index))+1,Buffer.byteLength(s.slice(0,index))+Buffer.byteLength(segment)].join(',')+'}').join(',')+'}').join(',');
let bundle=`local nativeUtf8=utf8
local ranges={${ranges}}
local utf8=setmetatable({graphemes=function(text)
 local list=ranges[text];if not list then list={};for first in nativeUtf8.codes(text)do local after=nativeUtf8.offset(text,2,first)or #text+1;table.insert(list,{first,after-1})end end
 local i=0;return function()i+=1;if list[i]then return list[i][1],list[i][2]end end
end},{__index=utf8})
local colors={__eq=function(a,b)return a.R==b.R and a.G==b.G and a.B==b.B end}
local Color3={new=function(r,g,b)return setmetatable({R=r,G=g,B=b},colors)end,fromRGB=function(r,g,b)return setmetatable({R=r/255,G=g/255,B=b/255},colors)end}
local Enum={Font={Arial='Arial',SourceSans='SourceSans',Ubuntu='Ubuntu'},TextXAlignment={Left='Left'},TextYAlignment={Top='Top'}}
local Vector2={new=function(x,y)return {X=x,Y=y}end}
local UDim2={fromOffset=function(x,y)return {x,y,X={Scale=0,Offset=x},Y={Scale=0,Offset=y}}end}
local modules,loaded={},{}
local function require(id)if loaded[id]~=nil then return loaded[id]end;local v=assert(modules[id],id)();loaded[id]=v;return v end
`;
for(const[id,source]of sources)bundle+='modules['+JSON.stringify(id)+']=function()\n'+source+'\nend\n';
for(const[name,args]of [['TextSelection',ids.slice(0,5)],['ScriptSelection',ids]]){
 bundle+='local test=(function()\n'+fs.readFileSync(path.join(root,'tests',name+'.luau'),'utf8')+'\nend)()\ntest('+args.map(id=>'require('+JSON.stringify(id)+')').join(',')+(name==='ScriptSelection'?','+whitespace:'')+')\n';
}
const file=path.join(root,'build','script-selection-'+process.pid+'.luau');fs.writeFileSync(file,bundle);
const result=cp.spawnSync(path.join(root,'build/tools/luau/luau.exe'),[file],{stdio:'inherit'});
if(result.error)throw result.error;process.exitCode=result.status??1;
