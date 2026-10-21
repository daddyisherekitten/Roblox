// Keep held-native weak ownership tests in a small, independent official Luau
// process. All exercised engine modules come from current production sources.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const cp = require('node:child_process');
const root = path.resolve(__dirname, '..');
const base = path.join(root, 'src/HTMLEngine');
const modules = new Map();
function load(id) {
  if (modules.has(id)) return;
  modules.set(id, '');
  // Font tests inject ResolveFont and never call this Roblox-only constructor.
  if (id === 'Layout/FontProfiles') {
    modules.set(id, "return {face=function()error('Lifetime test must use injected ResolveFont')end}");
    return;
  }
  let file = path.join(base, id + '.luau');
  if (!fs.existsSync(file)) file = path.join(base, id, 'init.luau');
  let source = fs.readFileSync(file, 'utf8');
  source = source.replace(/require\(script((?:\.[A-Za-z_][A-Za-z0-9_]*)+)\)/g, (_, chain) => {
    const parts = id.split('/');
    for (const name of chain.slice(1).split('.')) name === 'Parent' ? parts.pop() : parts.push(name);
    const dependency = parts.join('/');
    load(dependency);
    return 'require(' + JSON.stringify(dependency) + ')';
  });
  modules.set(id, source);
}
load('Rendering/ResourceLoadHost');
let bundle = 'local Enum={Font=setmetatable({},{__index=function(_,k)return k end})}\n' +
  'local Content={fromUri=function(s)return s end}\nlocal definitions,cache={},{}\nlocal require\n' +
  'require=function(id)if cache[id]~=nil then return cache[id]end;local value=assert(definitions[id],id)();cache[id]=value;return value end\n';
for (const [id, source] of modules) bundle += 'definitions[' + JSON.stringify(id) + ']=function()\n' + source + '\nend\n';
const test = fs.readFileSync(path.join(root, 'tests/ResourceLoadHostLifetime.luau'));
bundle += 'local run=(function()\n' + test.toString('utf8') + '\nend)()\nrun(require("Rendering/ResourceLoadHost"))\n';
const output = path.join(root, 'build', 'resource-load-host-lifetime-' + process.pid);
fs.mkdirSync(path.dirname(output), {recursive: true});
fs.writeFileSync(output + '.luau', bundle);
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
fs.writeFileSync(output + '.json', JSON.stringify({
  productionSourceSHA256: hash(fs.readFileSync(path.join(base, 'Rendering/ResourceLoadHost.luau'))),
  testSHA256: hash(test),
  bundledModules: [...modules.keys()],
  unusedProfileStub: 'Layout/FontProfiles only; font tests use injected ResolveFont',
  bundleBytes: Buffer.byteLength(bundle),
}, null, 2) + '\n');
const executable = process.env.LUAU_BIN || path.join(root, 'build/tools/luau/luau.exe');
if (!fs.existsSync(executable)) throw new Error('Set LUAU_BIN to the official Luau CLI executable.');
const result = cp.spawnSync(executable, [output + '.luau'], {stdio: 'inherit'});
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
if (!process.exitCode) console.log('ResourceLoadHostLifetime: compact production bundle passed.');
