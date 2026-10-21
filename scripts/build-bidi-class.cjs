// Reproducible public Unicode data, separate from renderer/selection algorithms.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const url = 'https://www.unicode.org/Public/17.0.0/ucd/extracted/DerivedBidiClass.txt';
(async () => {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Unicode data: ${response.status}`);
  const source = await response.text();
  if (!source.startsWith('# DerivedBidiClass-17.0.0.txt')) throw new Error('Unexpected Unicode version');
  const values = new Array(0x110000).fill('L');
  const missing = {Left_To_Right:'L', Right_To_Left:'R', Arabic_Letter:'AL', European_Terminator:'ET'};
  for (const match of source.matchAll(/# @missing:\s*([0-9A-F]+)(?:\.\.([0-9A-F]+))?;\s*(\w+)/g)) {
    if (!missing[match[3]]) throw new Error('Unrecognized Bidi default');
    values.fill(missing[match[3]], parseInt(match[1],16), parseInt(match[2]||match[1],16)+1);
  }
  for (const match of source.matchAll(/^([0-9A-F]+)(?:\.\.([0-9A-F]+))?\s*;\s*(\w+)/gm)) {
    values.fill(match[3], parseInt(match[1],16), parseInt(match[2]||match[1],16)+1);
  }
  const ranges = [];
  for (let start = 0; start < values.length;) {
    let end = start; while (end+1 < values.length && values[end+1]===values[start]) end++;
    ranges.push(` {${start},${end},${JSON.stringify(values[start])}}`); start=end+1;
  }
  const hash = crypto.createHash('sha256').update(source).digest('hex');
  const output = `--!strict\n-- Generated Unicode 17.0.0 Bidi_Class data; ${url}\n-- Source SHA-256: ${hash}\n-- Unicode license: ../JavaScript/Unicode.LICENSE.txt\n-- Classification only; this is not a complete UAX #9 layout algorithm.\nlocal ranges={\n${ranges.join(',\n')}\n}\nlocal BidiClass={Version='17.0.0'}\nfunction BidiClass.get(code: number): string\n local first,last=1,#ranges\n while first<=last do local at=math.floor((first+last)/2);local r=ranges[at]\n  if code<r[1]then last=at-1 elseif code>r[2]then first=at+1 else return r[3]end\n end\n return 'L'\nend\nreturn BidiClass\n`;
  fs.writeFileSync(path.join(root,'src/HTMLEngine/Layout/BidiClass.luau'), output);
  console.log(`Unicode Bidi_Class: ${ranges.length} ranges, SHA-256 ${hash}`);
})().catch(error => { console.error(error); process.exitCode=1; });
