// Keep the queued-owner GC probe independent of the full renderer test heap.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const root = path.resolve(__dirname, '..');
const modules = new Map();

function load(id) {
  if (modules.has(id)) return;
  modules.set(id, '');
  const base = path.join(root, 'src/HTMLEngine', id);
  const file = fs.existsSync(base + '.luau') ? base + '.luau' : path.join(base, 'init.luau');
  const source = fs.readFileSync(file, 'utf8').replace(/require\(script((?:\.[A-Za-z_][A-Za-z_0-9]*)+)\)/g, (_, chain) => {
    const parts = id.split('/');
    for (const name of chain.slice(1).split('.')) {
      if (name === 'Parent') parts.pop();
      else parts.push(name);
    }
    const dependency = parts.join('/');
    load(dependency);
    return 'require(' + JSON.stringify(dependency) + ')';
  });
  modules.set(id, source);
}

load('HTML/MediaSelection');
load('DOM/Node');
load('WorkContext');
let bundle = 'local definitions,cache={},{};local require\nrequire=function(id)if cache[id]==nil then cache[id]=assert(definitions[id],id)()end;return cache[id]end\n';
for (const [id, source] of modules) {
  bundle += 'definitions[' + JSON.stringify(id) + ']=function()\n' + source + '\nend\n';
}
bundle += 'local run=(function()\n' + fs.readFileSync(path.join(root, 'tests/MediaSelection.luau'), 'utf8') + '\nend)()\nrun(require("HTML/MediaSelection"),require("DOM/Node"),require("WorkContext"))\n';
const target = path.join(root, 'build', `media-selection-tests-${process.pid}.luau`);
fs.mkdirSync(path.dirname(target), {recursive: true});
fs.writeFileSync(target, bundle);
const result = cp.spawnSync(process.env.LUAU_BIN || path.join(root, 'build/tools/luau/luau.exe'), [target], {stdio: 'inherit'});
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
