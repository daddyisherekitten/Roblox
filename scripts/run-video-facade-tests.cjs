// Fresh compact production graph for facade-owned references and teardown.
// No VM/Page/decoder-wide collection claim and no source substitutions.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const modules = new Map();
const pins = {};
function load(id) {
  if (modules.has(id)) return;
  modules.set(id, '');
  const base = path.join(root, 'src/HTMLEngine', id);
  const file = fs.existsSync(base + '.luau') ? base + '.luau' : path.join(base, 'init.luau');
  const bytes = fs.readFileSync(file); pins[file] = sha(bytes);
  const source = bytes.toString().replace(/require\(script((?:\.[A-Za-z_][A-Za-z_0-9]*)+)\)/g, (_, chain) => {
    const parts = id.split('/');
    for (const name of chain.slice(1).split('.')) if (name === 'Parent') parts.pop(); else parts.push(name);
    const dependency = parts.join('/'); load(dependency); return 'require(' + JSON.stringify(dependency) + ')';
  });
  modules.set(id, source);
}
load('DOM/Node'); load('JavaScript/VideoElements'); load('HTML/VideoState');
const names = process.argv.slice(2);
assert(names.length > 0);
assert.equal(new Set(names).size, names.length);
let bundle = 'local definitions,cache={},{};local require\nrequire=function(id)if cache[id]==nil then cache[id]=assert(definitions[id],id)()end;return cache[id]end\n';
for (const [id, source] of modules) bundle += 'definitions[' + JSON.stringify(id) + ']=function()\n' + source + '\nend\n';
for (const name of names) {
  assert(['VideoFacadeLifetime', 'VideoFacadeDestroyFaults', 'VideoStateNotificationReview'].includes(name));
  const file = path.join(root, 'tests', name + '.luau');
  const bytes = fs.readFileSync(file); pins[file] = sha(bytes);
  bundle += 'do local run=(function()\n' + bytes.toString() + '\nend)()\nrun(require("DOM/Node"),require("JavaScript/VideoElements"),require("HTML/VideoState"))end\n';
}
const output = path.join(root, 'build', 'video-facade-compact-' + process.pid + '-' + crypto.randomUUID());
fs.writeFileSync(output + '.luau', bundle, {flag: 'wx'});
console.log('VIDEO_COMPACT_PRODUCTION_READS', JSON.stringify(pins));
const result = cp.spawnSync(process.env.LUAU_BIN || path.join(root, 'build/tools/luau/luau.exe'), [output + '.luau'], {stdio: 'inherit', windowsHide: true});
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
for (const [file, hash] of Object.entries(pins)) assert.equal(sha(fs.readFileSync(file)), hash, file);
fs.writeFileSync(output + '.json', JSON.stringify({sourceAndTestPins: pins, names, actualExit: process.exitCode,
  scope: 'Fresh compact facade-owned references and teardown; no whole VM/Page/native media collection proof',
  bundleSHA256: sha(Buffer.from(bundle))}, null, 2) + '\n', {flag: 'wx'});
