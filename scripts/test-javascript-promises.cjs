// Execute the same bounded-language cases in a real ECMAScript runtime.
// This is a functional trace comparison, not an FPS or timing benchmark.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const cases = JSON.parse(fs.readFileSync(path.join(__dirname, '../tests/fixtures/javascript-promises.json'), 'utf8'));
async function main() {
  for (const fixture of cases) {
    const values = [], timers = [];
    const context = vm.createContext({record: value => values.push(String(value)), queueMicrotask,
      setTimeout: fn => {timers.push(fn); return timers.length;}});
    vm.runInContext('globalThis.window = globalThis;', context);
    vm.runInContext(fixture.source, context);
    await new Promise(resolve => setImmediate(resolve));
    while (timers.length) {
      timers.shift()();
      await new Promise(resolve => setImmediate(resolve));
    }
    assert.deepEqual(values, fixture.expected, fixture.name);
  }
  console.log(`Native ECMAScript Promise traces: ${cases.length} shared cases passed.`);
}
main().catch(error => { console.error(error); process.exitCode = 1; });
