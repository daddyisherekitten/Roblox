// Existing native fixtures use the same package hierarchy as Rojo.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
function loaders(directory,skip,validate){
  const files=[];
  function collect(folder){for(const entry of fs.readdirSync(path.join(directory,folder),{withFileTypes:true})){
    const file=path.posix.join(folder,entry.name);if(skip.includes(file))continue;
    if(entry.isDirectory())collect(file);else if(entry.name.endsWith('.luau'))files.push(file);
  }}
  collect('');
  const segments=file=>file.replace(/(?:^|\/)init\.luau$|\.luau$/g,'').split('/').filter(Boolean);
  const id=parts=>parts.join('/')||'init',ids=new Set(files.map(file=>id(segments(file))));
  let bundle='local loaders,loaded={},{}\nlocal function require(id)if not loaded[id]then loaded[id]=assert(loaders[id],id)()end;return loaded[id]end\n';
  for(const file of files){
    const original=fs.readFileSync(path.join(directory,file),'utf8');validate(original,file);
    function resolve(base,chain){const parts=[...base];for(const name of chain.slice(1).split('.')){
      if(name==='Parent'){assert.ok(parts.length,file+': dependency leaves its package');parts.pop();}else parts.push(name);
    }return parts;}
    function reference(base,chain){const dependency=id(resolve(base,chain));assert.ok(ids.has(dependency),file+': unknown dependency '+dependency);return JSON.stringify(dependency);}
    let rootParts;
    let source=original.replace(/^local Root\s*=\s*script((?:\.[A-Za-z_]\w*)+)\r?\n/m,(_,chain)=>{rootParts=resolve(segments(file),chain);return '';});
    if(rootParts)source=source.replace(/(?<![\w.])Root((?:\.[A-Za-z_]\w*)+)/g,(_,chain)=>reference(rootParts,chain));
    source=source.replace(/\bscript((?:\.[A-Za-z_]\w*)+)/g,(_,chain)=>reference(segments(file),chain));
    bundle+=`loaders[${JSON.stringify(id(segments(file)))}]=function()\n${source}\nend\n`;
  }
  return bundle+'return require("init")\nend\n';
}
const globals='local warn=env.Warn or function()end\nlocal Color3,UDim,UDim2,Vector2,Enum=env.Color3,env.UDim,env.UDim2,env.Vector2,env.Enum\nlocal game,Instance,TweenInfo,task=env.Game,env.Instance,env.TweenInfo,env.Task\nlocal nativeTypeof=typeof\nlocal function typeof(value)return if type(value)=="table"and value.Data and value.Data.ClassName then "Instance"else nativeTypeof(value)end\n';
module.exports=function browserBundle(root){
  const directory=path.join(root,'src/Browser');
  let bundle='local function loadBrowser(env,requestedModule)\n'+globals+loaders(directory,['Integration'],(source,file)=>assert.doesNotMatch(source,/HTMLEngine|BrowserHTMLBinding|mountHTML/,file+': independent shell')).replace('return require("init")\nend\n','return require(requestedModule or "init")\nend\n');
  const scope=fs.readFileSync(path.join(directory,'Integration/HTMLBinding/InputScope.luau'),'utf8');
  const binding=fs.readFileSync(path.join(directory,'Integration/HTMLBinding/init.luau'),'utf8');
  bundle+='local function loadBrowserBinding(env)\nlocal warn=env.Warn or function()end\nlocal Color3,UDim2,Vector2=env.Color3,env.UDim2,env.Vector2\nlocal InputScope=(function()\n'+scope+'\nend)()\n'+binding.replace('local InputScope=require(script.InputScope)','')+'\nend\n';
  bundle+='local browserFixture=(function()\n'+fs.readFileSync(path.join(root,'tests/fixtures/BrowserNative.luau'),'utf8')+'\nend)()\n';
  bundle+='local function loadWindowManager(env,requestedModule)\n'+globals+loaders(path.join(root,'src/WindowManager'),[],(source,file)=>assert.doesNotMatch(source,/require\([^)]*(?:Windows10|Browser|HTMLEngine)/,file+': independent windows')).replace('return require("init")\nend\n','return require(requestedModule or "init")\nend\n');
  bundle+='local function loadBrowserWindowHost(env)\nlocal UDim2,Vector2=env.UDim2,env.Vector2\n'+fs.readFileSync(path.join(directory,'Integration/WindowHost.luau'),'utf8')+'\nend\n';
  bundle+='local function loadBrowserStore(env)\nlocal game,task=env.Game,env.Task\n'+fs.readFileSync(path.join(root,'src/BrowserServer/Store.luau'),'utf8')+'\nend\n';
  const windowDemo = JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/retired-native-window-demo-20261016.json'),'utf8'));
  assert.equal(require('node:crypto').createHash('sha256').update(windowDemo.source).digest('hex'),windowDemo.sha256,'Retired native window demo fixture changed');
  bundle+='local function loadWindowDemo(env)\nlocal Color3,UDim2,Vector2,Enum=env.Color3,env.UDim2,env.Vector2,env.Enum\n'+windowDemo.source.replace('local Common=require(script.Parent.Parent.Pages.Common)','local Common=loadBrowser(env,"Pages/Common")')+'\nend\n';
  return bundle;
};
