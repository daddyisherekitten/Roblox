// The SOURCE provenance graph has a compact, data-only weak-owner test. Run
// that unchanged test in its own official Luau process, away from layout heaps.
// Every module is current production code; no renderer/VM module is substituted.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const base = path.join(root, 'src/HTMLEngine');
const modules = new Map();
function load(id) {
  if (modules.has(id)) return;
  modules.set(id, '');
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
load('DOM/MediaSourceDocument');
assert.deepEqual([...modules.keys()].sort(), ['DOM/ElementNames', 'DOM/MediaSourceDocument'], 'Declared data-only module boundary');
let bundle = 'local definitions,cache={},{}\nlocal require\n' +
  'require=function(id)if cache[id]~=nil then return cache[id]end;local value=assert(definitions[id],id)();cache[id]=value;return value end\n';
for (const [id, source] of modules) bundle += 'definitions[' + JSON.stringify(id) + ']=function()\n' + source + '\nend\n';
const test = fs.readFileSync(path.join(root, 'tests/SourceDocumentLifetime.luau'));
bundle += 'local run=(function()\n' + test.toString('utf8') + '\nend)()\nrun(require("DOM/MediaSourceDocument"))\n';
const output = path.join(root, 'build', 'source-document-lifetime-' + process.pid);
fs.mkdirSync(path.dirname(output), {recursive: true});
fs.writeFileSync(output + '.luau', bundle);
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
fs.writeFileSync(output + '.json', JSON.stringify({
  productionModules: Object.fromEntries([...modules.keys()].map(id => [id, hash(fs.readFileSync(path.join(base, id + '.luau')))])),
  testSHA256: hash(test),
  substitutedModules: [],
  controls: 9,
  pressureBudget: {rounds: 128, array: 2048},
  bundleBytes: Buffer.byteLength(bundle),
  scope: 'Weak document/context data ownership; no Page/VM/native/GPU collection claim',
}, null, 2) + '\n');
const executable = process.env.LUAU_BIN || path.join(root, 'build/tools/luau/luau.exe');
if (!fs.existsSync(executable)) throw new Error('Set LUAU_BIN to the official Luau CLI executable.');
const result = cp.spawnSync(executable, [output + '.luau'], {stdio: 'inherit'});
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
if (!process.exitCode) console.log('SourceDocumentLifetime: compact production bundle passed.');
