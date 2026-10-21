// Frozen regression sources from the removed visual SVG laboratory.
// Read entries in memory; the archive never recreates active demos or pages.
const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
let bytes, entries, manifest;
function load() {
  if (entries) return;
  bytes = fs.readFileSync(path.join(root, 'tests/fixtures/svg-regressions.zip'));
  let end = bytes.length - 22;
  const boundary = Math.max(0, bytes.length - 65557);
  while (end >= boundary && bytes.readUInt32LE(end) !== 0x06054b50) end--;
  assert.ok(end >= boundary, 'Missing SVG fixture ZIP directory');
  assert.equal(bytes.readUInt16LE(end + 4), 0, 'Multi-disk fixtures are unsupported');
  const count = bytes.readUInt16LE(end + 10);
  let at = bytes.readUInt32LE(end + 16);
  entries = new Map();
  for (let index = 0; index < count; index++) {
    assert.equal(bytes.readUInt32LE(at), 0x02014b50, 'Invalid fixture directory entry');
    const nameLength = bytes.readUInt16LE(at + 28), extra = bytes.readUInt16LE(at + 30), comment = bytes.readUInt16LE(at + 32);
    const name = bytes.subarray(at + 46, at + 46 + nameLength).toString('utf8');
    assert.ok(!entries.has(name), 'Duplicate SVG fixture ' + name);
    entries.set(name, {method: bytes.readUInt16LE(at + 10), size: bytes.readUInt32LE(at + 24), compressed: bytes.readUInt32LE(at + 20), offset: bytes.readUInt32LE(at + 42)});
    at += 46 + nameLength + extra + comment;
  }
  manifest = JSON.parse(unpack('manifest.json').toString('utf8'));
  assert.equal(manifest.schema, 'retired-svg-lab/v1');
}
function unpack(name) {
  const entry = entries.get(name);
  assert.ok(entry, 'Missing archived SVG fixture ' + name);
  const at = entry.offset;
  assert.equal(bytes.readUInt32LE(at), 0x04034b50, 'Invalid local fixture header');
  const begin = at + 30 + bytes.readUInt16LE(at + 26) + bytes.readUInt16LE(at + 28);
  const data = bytes.subarray(begin, begin + entry.compressed);
  assert.ok(entry.method === 0 || entry.method === 8, 'Unsupported fixture compression');
  const raw = entry.method === 0 ? data : zlib.inflateRawSync(data, {maxOutputLength:entry.size});
  assert.equal(raw.length, entry.size, 'Fixture size mismatch: ' + name);
  return raw;
}
function key(name) {
  return (path.isAbsolute(name) ? path.relative(root, name) : name).replaceAll('\\', '/');
}
function read(name) {
  load(); name = key(name);
  assert.ok(manifest.files[name], 'Unregistered SVG fixture ' + name);
  const raw = unpack(name);
  assert.equal(crypto.createHash('sha256').update(raw).digest('hex'), manifest.files[name].sha256, 'SVG fixture changed: ' + name);
  return raw.toString('utf8');
}
read.has = name => {load();return Object.hasOwn(manifest.files, key(name));};
read.verify = () => {load();for(const name of Object.keys(manifest.files))read(name);return Object.keys(manifest.files).length;};
module.exports = read;
