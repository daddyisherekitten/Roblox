// Keep held/queued native-preload lifetime checks in a fresh official Luau
// process. The engine and test are read from current production sources.
// Only MediaBox.paint is a controlled boundary here; the main runner also
// exercises the same test's separate behavior inventory with real MediaBox.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const hostPath = path.join(root, 'src/HTMLEngine/Rendering/AudioHost.luau');
const testPath = path.join(root, 'tests/AudioHostLifetime.luau');
const host = fs.readFileSync(hostPath);
const test = fs.readFileSync(testPath);
const paintImport = 'local MediaBox=require(script.Parent.MediaBox)';
const source = host.toString('utf8');
assert.equal(source.split(paintImport).length, 2, 'Exactly one declared paint boundary');
const compactHost = source.replace(paintImport,
  'local MediaBox={paint=function(item)if item.HarnessCounts then item.HarnessCounts.Paints+=1 end end}');
assert.equal(compactHost.match(/\brequire\s*\(/g), null, 'Unexpected additional engine dependency');
const bundle = 'local AudioHost=(function()\n' + compactHost +
  '\nend)()\nlocal run=(function()\n' + test.toString('utf8') + '\nend)()\nrun(AudioHost)\n';
const output = path.join(root, 'build', 'audio-host-lifetime-' + process.pid);
fs.mkdirSync(path.dirname(output), {recursive: true});
fs.writeFileSync(output + '.luau', bundle);
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
fs.writeFileSync(output + '.json', JSON.stringify({
  productionSourceSHA256: hash(host),
  testSHA256: hash(test),
  controlledBoundary: 'MediaBox.paint only; real MediaBox behavior runs separately in the main runner',
  compactControls: 27,
  compactAssertions: 282,
  pressureBudget: {rounds: 128, array: 2048},
  bundleBytes: Buffer.byteLength(bundle),
  scope: 'AudioHost-owned references before native resume; no whole Page/Realm/WorkContext/GPU collection claim',
}, null, 2) + '\n');
const executable = process.env.LUAU_BIN || path.join(root, 'build/tools/luau/luau.exe');
if (!fs.existsSync(executable)) throw new Error('Set LUAU_BIN to the official Luau CLI executable.');
const result = cp.spawnSync(executable, [output + '.luau'], {stdio: 'inherit'});
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
if (!process.exitCode) console.log('AudioHostLifetime: compact production bundle passed.');
