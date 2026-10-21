// Execute the real, generated-in-part Luau catalogs instead of regex-extracting keys.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const root = path.resolve(__dirname, '..');
const modules = new Map();
function add(file) {
  file = path.resolve(file);
  if (modules.has(file)) return modules.get(file).id;
  const entry = {id: modules.size + 1, source: ''};
  modules.set(file, entry);
  entry.source = fs.readFileSync(file, 'utf8').replace(/require\(script((?:\.[A-Za-z_][A-Za-z_0-9]*)+)\)/g, (_, chain) => {
    let base = file.endsWith(path.sep + 'init.luau') ? path.dirname(file) : file.slice(0, -5);
    for (const part of chain.slice(1).split('.')) base = part === 'Parent' ? path.dirname(base) : path.join(base, part);
    return `loadModule(${add(fs.existsSync(base + '.luau') ? base + '.luau' : path.join(base, 'init.luau'))})`;
  });
  return entry.id;
}
const properties = add(path.join(root, 'src/HTMLEngine/CSS/Properties.luau'));
const elements = add(path.join(root, 'src/HTMLEngine/HTML/Elements.luau'));
const probeInput=process.argv[3]?JSON.parse(fs.readFileSync(path.resolve(process.argv[3]),'utf8')):null;
const probeModules=probeInput?Object.fromEntries(['CSS/Stylesheet','CSS/InlineStyle','CSS/LengthExpression','CSS/MediaQueries','DOM/Node'].map(name=>[name,add(path.join(root,'src/HTMLEngine',name+'.luau'))])):null;
let bundle = `local Color3={new=function(r,g,b)return {R=r,G=g,B=b}end,fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end}
local Enum=setmetatable({},{__index=function(t,group)local values=setmetatable({},{__index=function(v,name)local item={Name=name};v[name]=item;return item end});t[group]=values;return values end})
local factories,loaded={},{}
local function loadModule(id) if loaded[id]==nil then loaded[id]=factories[id]() end return loaded[id] end
`;
for (const entry of modules.values()) bundle += `factories[${entry.id}]=function()\n${entry.source}\nend\n`;
bundle += String.raw`
local function quote(value)
 return '"'..tostring(value):gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',string.byte(c))end)..'"'
end
local function emit(catalog,fields)
 local names={}; for name in catalog do table.insert(names,name)end;table.sort(names)
 local entries={}
 for _,name in names do
  local parts={};for _,field in fields do if catalog[name][field]~=nil then table.insert(parts,quote(field)..':'..quote(catalog[name][field]))end end
  table.insert(entries,quote(name)..':{'..table.concat(parts,',')..'}')
 end
 return '{'..table.concat(entries,',')..'}'
end
`;
bundle += `local result='{"properties":'..emit(loadModule(${properties}),{'Kind','Field','Support','Values','Limitations'})..',"elements":'..emit(loadModule(${elements}),{'Render','Support','Description','Limitations'})\n`;
if(probeInput){
  function lua(value){if(typeof value==='string')return JSON.stringify(value);if(Array.isArray(value))return '{'+value.map(lua).join(',')+'}';return '{'+Object.entries(value).map(([k,v])=>'['+lua(k)+']='+lua(v)).join(',')+'}';}
  bundle+=`local inputs=${lua(probeInput)}\nlocal stylesheet=loadModule(${probeModules['CSS/Stylesheet']})\nlocal Node=loadModule(${probeModules['DOM/Node']})\n`;
  bundle+=String.raw`
local output={}
for _,kind in {'selectors','lengthUnits','mediaFeatures','propertyAliases','functions'}do
 local parts={}
 for _,entry in inputs[kind]or{}do
  local accepted=false;local messages={};local examples={};local rejected=false
  if kind=='selectors'then
   local doc=Node.document();Node.append(doc,Node.element('div',{}))
   local rules=stylesheet.collect(doc,function(message)table.insert(messages,message)end,entry.source..'{color:red}')
   accepted=#rules>0
  elseif kind=='lengthUnits'then accepted=loadModule(__LENGTH__).parse(entry.source,{FontSize=16,RootFontSize=16,ViewportWidth=800,ViewportHeight=600})~=nil
  elseif kind=='mediaFeatures'then
   local query=loadModule(__MEDIA__).compileCondition(entry.source)
   local function known(term)
    if not term or term.Unknown then return false end
    for _,child in term.Terms or{}do if not known(child)then return false end end
    return true
   end
   accepted=known(query)
  else
   for _,source in entry.sources or {entry.source}do
    local compiled=loadModule(__STYLE__).compile(source);local valid=#compiled.Normal+#compiled.Important>0
    for _,list in {compiled.Normal,compiled.Important}do for _,part in list do if part.Error then valid=false end end end
    if kind=='propertyAliases'and entry.name=='-webkit-box-orient'then valid=#compiled.Normal+#compiled.Important==0 end
    accepted=accepted or valid;rejected=rejected or not valid
    table.insert(examples,'{"source":'..quote(source)..',"accepted":'..tostring(valid)..'}')
   end
  end
  table.insert(parts,quote(entry.name)..':{"accepted":'..tostring(accepted)..',"source":'..quote(entry.source or entry.sources[1])..',"rejectedExample":'..tostring(rejected)..',"examples":['..table.concat(examples,',')..']}')
 end
 table.insert(output,quote(kind)..':{'..table.concat(parts,',')..'}')
end
result..=',"probes":{'..table.concat(output,',')..'}'
`.replaceAll('__LENGTH__',String(probeModules['CSS/LengthExpression'])).replaceAll('__MEDIA__',String(probeModules['CSS/MediaQueries'])).replaceAll('__STYLE__',String(probeModules['CSS/InlineStyle']));
}
bundle += `print(result..'}')\n`;
const output = path.resolve(process.argv[2] || path.join(root, 'build/engine-catalog.json'));
fs.mkdirSync(path.join(root, 'build'), {recursive: true});
const script = path.join(root, 'build/export-catalog.luau');
fs.writeFileSync(script, bundle);
const run = cp.spawnSync(process.env.LUAU_BIN || path.join(root, 'build/tools/luau/luau.exe'), [script], {encoding: 'utf8', maxBuffer: 8 * 1024 * 1024});
if (run.error) throw run.error;
if (run.status !== 0) throw new Error(run.stderr);
const catalog = JSON.parse(run.stdout);
fs.mkdirSync(path.dirname(output), {recursive: true});
fs.writeFileSync(output, JSON.stringify(catalog, null, 2) + '\n');
console.log(`Exported ${Object.keys(catalog.properties).length} properties and ${Object.keys(catalog.elements).length} elements to ${output}`);
