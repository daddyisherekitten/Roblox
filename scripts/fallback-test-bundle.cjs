// Execute the engine's optional native host with explicit native-service doubles.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

function modules(root, folder) {
  const base = path.join(root, 'src/HTMLEngine', folder);
  const files = [];
  function walk(directory) {
    if (!fs.existsSync(directory)) return;
    for (const entry of fs.readdirSync(directory, {withFileTypes: true})) {
      const file = path.join(directory, entry.name);
      if (entry.isDirectory()) walk(file);
      else if (entry.name.endsWith('.luau')) files.push(file);
    }
  }
  walk(base);
  return files.map(file => {
    const id = path.relative(path.join(root, 'src/HTMLEngine'), file).replaceAll('\\', '/').replace(/\/init\.luau$|\.luau$/g, '');
    const original = fs.readFileSync(file, 'utf8');
    assert.doesNotMatch(original, /require\([^)]*(?:Browser|WindowManager|Windows10)/, id + ': engine-owned fallback dependency');
    const source = original.replace(/require\(script((?:\.[A-Za-z_][A-Za-z_0-9]*)+)\)/g, (_, chain) => {
      const parts = id.split('/');
      for (const name of chain.slice(1).split('.')) {
        if (name === 'Parent') {assert(parts.length, id + ': dependency leaves HTMLEngine'); parts.pop();}
        else parts.push(name);
      }
      return 'require(' + JSON.stringify(parts.join('/')) + ')';
    });
    return 'loaders[' + JSON.stringify(id) + ']=function()\n' + source + '\nend\n';
  }).join('');
}

const globals = 'local Color3,UDim,UDim2,Vector2,Enum=env.Color3,env.UDim,env.UDim2,env.Vector2,env.Enum\nlocal game,task=env.Game,env.Task\nlocal warn=env.Warn or function()end\n';

module.exports = function fallbackBundle(root) {
  let result = 'local function loadFallbackWindows(env,requestedModule)\n' + globals;
  result += 'local nativeRequire=require\nlocal factory=loadGuiFactory(env.Instance,env.Enum,Font)\nlocal loaders,loaded={},{}\nlocal function require(id)\nif id=="Rendering/GuiFactory" then return factory end\nif not loaders[id]then return nativeRequire(id)end\nif loaded[id]==nil then loaded[id]=loaders[id]()end;return loaded[id]\nend\n';
  result += modules(root, 'Rendering/FallbackWindows');
  result += 'return require(requestedModule or "Rendering/FallbackWindows")\nend\n';
  result += 'local function loadStandaloneHost(env)\n' + globals;
  result += 'local nativeRequire=require\nlocal factory=loadGuiFactory(env.Instance,env.Enum,Font)\nlocal loaders,loaded={},{}\nlocal function require(id)\nif id=="Rendering/FallbackWindows" then return loadFallbackWindows(env)elseif id=="Rendering/GuiFactory"then return factory end\nif not loaders[id]then return nativeRequire(id)end\nif loaded[id]==nil then loaded[id]=loaders[id]()end;return loaded[id]\nend\n';
  result += modules(root, 'Rendering/StandaloneHost');
  result += 'return require("Rendering/StandaloneHost")\nend\n';
  return result;
};
