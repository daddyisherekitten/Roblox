// Run real SVG modules in the Luau CLI, without Studio or the visual test hosts.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const modules = new Map();
function resolveModule(base) {
  for (const p of [base + '.luau', path.join(base, 'init.luau')]) {
    if (fs.existsSync(p)) return p;
  }
  throw new Error('Missing module: ' + base);
}
function add(file) {
  file = path.resolve(file);
  if (modules.has(file)) return modules.get(file).id;
  const entry = {id: modules.size + 1, text: ''};
  modules.set(file, entry);
  entry.text = fs.readFileSync(file, 'utf8').replace(/require\(script((?:\.[A-Za-z_][A-Za-z_0-9]*)+)\)/g, (_, chain) => {
    let base = file.endsWith(path.sep + 'init.luau') ? path.dirname(file) : file.slice(0, -5);
    for (const segment of chain.slice(1).split('.')) base = segment === 'Parent' ? path.dirname(base) : path.join(base, segment);
    return `loadModule(${add(resolveModule(base))})`;
  });
  return entry.id;
}
const embedded = add(path.join(root, 'src/HTMLEngine/SVG/Embedded.luau'));
const html = add(path.join(root, 'src/HTMLEngine/HTML/Parser.luau'));
const raster = add(path.join(root, 'src/HTMLEngine/SVG/Raster.luau'));
const hit = add(path.join(root, 'src/HTMLEngine/SVG/HitTest.luau'));
const queue = add(path.join(root, 'src/HTMLEngine/SVG/RenderQueue.luau'));
const fixture = require('./svg-fixtures.cjs')('examples/svg-tests/supported-svg-stress-3.html').trim();
let source = `local Vector2={new=function(x,y)return {X=x,Y=y}end}
local Color3={new=function(r,g,b)return {R=r,G=g,B=b}end,fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end}
local factories,loaded={},{}
local function loadModule(id) if loaded[id]==nil then loaded[id]=factories[id]() end;return loaded[id] end
`;
for (const entry of modules.values()) source += `factories[${entry.id}]=function()\n${entry.text}\nend\n`;
source += `local benchmark=(function()\n${fs.readFileSync(path.join(root, 'tests/SVGBenchmark.luau'), 'utf8')}\nend)()\nbenchmark(loadModule(${embedded}),loadModule(${html}),loadModule(${raster}),loadModule(${hit}),[====[${fixture}]====],loadModule(${queue}))\n`;
const baseline = process.argv.includes('--baseline');
const name = baseline ? 'svg-benchmark-before' : 'svg-benchmark-after';
fs.mkdirSync(path.join(root, 'build'), {recursive: true});
const bundle = path.join(root, 'build', name + '.luau');
fs.writeFileSync(bundle, source);
function execute(file, dumpPixels = false) {
  let target = file;
  if (dumpPixels) {
    // The saved baseline contains the original modules and identical fixture.
    // Add readback only; never replace its implementations with current code.
    const original = fs.readFileSync(file, 'utf8');
    const marker = "return string.format('%08x',b*65536+a)";
    if (!original.includes(marker)) throw new Error('Baseline lacks benchmark checksum marker');
    target = file.replace('.luau', '-readback.luau');
    const dump = "local hex={};for at=0,buffer.len(bytes)-1 do hex[at+1]=string.format('%02x',buffer.readu8(bytes,at)) end;print('SVG_BENCH_PIXELS',table.concat(hex))\n";
    fs.writeFileSync(target, original.replace(marker, dump + marker));
  }
  const run = cp.spawnSync(path.join(root, 'build/tools/luau/luau.exe'), [target], {encoding: 'utf8', maxBuffer: 32 * 1024 * 1024});
  if (run.error) throw run.error;
  if (run.status !== 0) throw new Error((run.stderr || '') + (run.stdout || ''));
  const pixels = [];
  const log = (run.stdout || '').split(/\r?\n/).filter(line => {
    if (!line.startsWith('SVG_BENCH_PIXELS\t')) return true;
    pixels.push(Buffer.from(line.split('\t')[1], 'hex'));return false;
  }).join('\n');
  return {pixels, log};
}
const compare = process.argv.includes('--compare-baseline');
const baselineArgument = process.argv.find(argument => argument.startsWith('--baseline-file='));
const comparisonBaseline = baselineArgument
  ? path.resolve(baselineArgument.slice('--baseline-file='.length))
  : path.join(root, 'build/svg-benchmark-before.luau');
const result = execute(bundle, compare);
let log = result.log;
if (compare) {
  const before = execute(comparisonBaseline, true);
  // Each logged state must have exactly one readback; the fixture may grow.
  const states = log => [...log.matchAll(/SVG_BENCH state=(\d+)/g)].map(match => Number(match[1]));
  const beforeStates = states(before.log), afterStates = states(result.log);
  if (!afterStates.length || new Set(afterStates).size !== afterStates.length ||
      before.pixels.length !== beforeStates.length || result.pixels.length !== afterStates.length ||
      JSON.stringify(beforeStates) !== JSON.stringify(afterStates)) {
    throw new Error(`Incompatible benchmark states or missing readbacks: baseline=${beforeStates.length}/${before.pixels.length}, current=${afterStates.length}/${result.pixels.length}. Use an unchanged fixture and --baseline-file=PATH.`);
  }
  for (let i = 0; i < result.pixels.length; i++) {
    if (!before.pixels[i].equals(result.pixels[i])) throw new Error('Pixel regression in state ' + i);
    log += `SVG_PIXEL_EQUAL state=${i} bytes=${result.pixels[i].length} sha256=${crypto.createHash('sha256').update(result.pixels[i]).digest('hex')}\n`;
  }
}
fs.writeFileSync(path.join(root, 'build', name + '.log'), log);
process.stdout.write(log);
