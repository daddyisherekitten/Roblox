const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const profile = process.argv[2] || 'Arial';
assert.ok(['Arial', 'Ubuntu', 'Roboto', 'Inter', 'OpenSans', 'RobotoMono', 'PTSerif', 'Lato', 'Lora', 'Merriweather', 'Montserrat', 'NotoSans', 'NunitoSans', 'PlayfairDisplay', 'Poppins', 'WorkSans'].includes(profile), 'Choose a measured font profile, including Lato');
const slug = { OpenSans: 'open-sans', NotoSans: 'noto-sans', NunitoSans: 'nunito-sans', PlayfairDisplay: 'playfair-display', WorkSans: 'work-sans', RobotoMono: 'roboto-mono', PTSerif: 'pt-serif' }[profile] || profile.toLowerCase();
const data = JSON.parse(fs.readFileSync(path.join(root, `measurements/${slug}-guide-fit.json`), 'utf8'));
const source = fs.readFileSync(path.join(root, `src/HTMLEngine/Layout/FontProfiles/${profile}.luau`), 'utf8');
const model = {};
for (const match of source.matchAll(/(Top|XHeight|Baseline|Bottom) = \{ Slope = ([-\d.]+), Intercept = ([-\d.]+) \}/g)) {
  model[match[1]] = [Number(match[2]), Number(match[3])];
}
assert.equal(Object.keys(model).length, 4);
assert.equal(source.includes('GuideSizeRounding = "ceil"'), data.textSizeRounding === 'ceil');
function modelSize(htmlSize) {
  const size = htmlSize * data.scale;
  return data.textSizeRounding === 'ceil' ? Math.ceil(size) : size;
}
if (data.textSizeRounding === 'ceil') {
  for (const row of data.training) assert.equal(modelSize(row.htmlSize), row.robloxTextSize);
}
function predict(key, size) {
  const keys = ['Top','XHeight','Baseline','Bottom'];
  let ordered = 0;
  for (const current of keys) {
    const [a,b] = model[current];
    ordered = Math.max(ordered, Math.floor(a * modelSize(size) + b + 0.5));
    if (current === key) return ordered;
  }
}
for (const key of Object.keys(model)) {
  const xs = data.training.map(row => modelSize(row.htmlSize));
  const ys = data.training.map(row => row[key]);
  const n = xs.length, sx = xs.reduce((a,b) => a+b), sy = ys.reduce((a,b) => a+b);
  const a = (n * xs.reduce((sum,x,i) => sum+x*ys[i],0)-sx*sy) /
    (n * xs.reduce((sum,x) => sum+x*x,0)-sx*sx);
  const b = (sy-a*sx)/n;
  assert.ok(Math.abs(a-model[key][0]) < 1e-12 && Math.abs(b-model[key][1]) < 1e-12, 'Coefficients must match the recorded observations');
  const error = Math.max(...data.training.map(row => Math.abs(predict(key,row.htmlSize)-row[key])));
  assert.ok(error <= (profile === 'Arial' && key === 'Top' ? 2 : 1));
  console.log(`${key}: maximum training error ${error} px`);
}
for (const row of data.heldOut) assert.ok(Math.abs(predict('XHeight',row.htmlSize)-row.XHeight) <= 1);
for (let size=1; size<=100; size+=0.25) {
  const p = ['Top','XHeight','Baseline','Bottom'].map(key => predict(key,size));
  assert.ok(p[0] <= p[1] && p[1] <= p[2] && p[2] <= p[3]);
}
console.log(`${profile}: ${data.heldOut.length} held-out x measurements checked (at most 1 px error). Guide ordering passed. This does not run Roblox.`);
