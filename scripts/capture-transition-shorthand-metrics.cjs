const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {openBrowser} = require('./native-browser.cjs');
const root = path.resolve(__dirname, '..');
const definitions = [
  ['outline width and color', 'outline:2px solid red', 'outline:10px solid blue', 'outline 1s linear', ['outlineWidth', 'outlineColor'], {outlineWidth:6, outlineOffset:0}],
  ['outline excludes offset', 'outline:2px solid red;outline-offset:0', 'outline:10px solid blue;outline-offset:12px', 'outline 1s linear', ['outlineWidth', 'outlineColor', 'outlineOffset'], {outlineWidth:6, outlineOffset:12}],
  ['outline last longhand duration', 'outline:2px solid red', 'outline:10px solid blue', 'outline 1s linear,outline-width 2s linear', ['outlineWidth', 'outlineColor'], {outlineWidth:4, outlineOffset:0}],
  ['outline none to solid', 'outline:2px none red', 'outline:10px solid blue', 'outline 1s linear', ['outlineWidth', 'outlineColor', 'outlineStyle'], {outlineWidth:6, outlineOffset:0}],
  ['font size and line height', 'font:16px/20px Arial', 'font:32px/40px Arial', 'font 1s linear', ['fontSize', 'lineHeight'], {fontSize:24, lineHeight:30, leafWidth:48}],
  ['font last longhand duration', 'font:16px/20px Arial', 'font:32px/40px Arial', 'font 1s linear,font-size 2s linear', ['fontSize', 'lineHeight'], {fontSize:20, lineHeight:30, leafWidth:40}],
  ['font inherited unitless metrics', 'font:16px/1.5 Arial', 'font:32px/2 Arial', 'font 1s linear', ['fontSize', 'lineHeight'], {fontSize:24, lineHeight:42, leafWidth:48}],
  ['font unchanged size', 'font:16px/20px Arial', 'font:16px/40px Arial', 'font 1s linear', ['fontSize', 'lineHeight'], {fontSize:16, lineHeight:30, leafWidth:32}],
];
const cases = definitions.map(([name, before, after, transition, fields, shorthandPaint]) => ({
  name:'transition shorthand '+name,
  css:'#box{'+before+';transition:'+transition+'}#box.active{'+after+'}#shorthandLeaf{width:2em;height:1em}#shorthandField{display:block;font-size:inherit;width:2em;height:1em;padding:0;border:0}',
  source:`const target=document.getElementById('box');target.offsetWidth;target.className='active';target.offsetWidth;const effects=target.getAnimations();for(const a of effects){a.finished.catch(()=>{});a.ready.catch(()=>{});a.pause();}record(effects.map(a=>a.transitionProperty+'|'+a.effect.getTiming().duration).sort().join(','));for(const time of [0,250,500]){for(const a of effects)a.currentTime=time;const style=getComputedStyle(target);for(const field of ${JSON.stringify(fields)})record(style[field]);record(getComputedStyle(document.getElementById('shorthandLeaf')).width);}record(effects.every(a=>target.getAnimations().includes(a)));`,
  cssMotion:true, transitionShorthand:true, layout:name.startsWith('font '), shorthandPaint,
}));
async function main() {
  const browser = await openBrowser(path.join(root, 'build', 'transition-shorthand-reference'));
  try {
    await browser.send('Emulation.setDeviceMetricsOverride', {width:600,height:800,deviceScaleFactor:1,mobile:false});
    for (const item of cases) {
      await browser.load('<!doctype html><html><head><style>html,body{margin:0;padding:0}#box{width:200px;height:100px;background:white}'+item.css+'</style></head><body><div id="parent"><div id="box"><div id="shorthandLeaf"></div><input id="shorthandField" value="kept"></div></div><div id="outside">Unchanged</div></body></html>');
      item.expected = await browser.evaluate('(()=>{const output=[];function record(value){output.push(String(value));}'+item.source+'return output;})()');
    }
    const file = path.join(root, 'tests', 'fixtures', 'javascript-animation-layout.json');
    const prior = JSON.parse(fs.readFileSync(file,'utf8'));
    if (process.argv.includes('--update')) {
      fs.writeFileSync(file, JSON.stringify([...prior.filter(item=>!item.name.startsWith('transition shorthand ')), ...cases],null,2)+'\n');
    } else {
      assert.deepEqual(prior.filter(item=>item.name.startsWith('transition shorthand ')), cases, 'Native transition shorthand references changed; inspect before updating');
    }
    console.log('Transition shorthand metrics: '+cases.length+' isolated native CSS DOM and computed-value references '+(process.argv.includes('--update')?'saved':'verified'));
  } finally { await browser.close(); }
}
main().catch(error=>{console.error(error.stack||error);process.exitCode=1;});
