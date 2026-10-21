// Isolated deterministic intrinsic-size references. The same source is run by
// JavaScriptAnimationLayout over the retained renderer; no live user tab opens.
const fs = require('node:fs'), path = require('node:path');
const { openBrowser } = require('./native-browser.cjs');
const root = path.resolve(__dirname, '..');
const prefix = "const box=document.getElementById('box');const child=document.createElement('div');child.style.cssText='display:block;width:20px;height:120px;margin:0;padding:0';box.appendChild(child);function hold(frames,options,time){const a=box.animate(frames,options);a.finished.catch(()=>{});a.ready.catch(()=>{});a.pause();a.currentTime=time;return a;}function height(){record(Math.round(box.getBoundingClientRect().height*1000)/1000);}";
const cases = [
  ['height auto linear samples', '#box{interpolate-size:allow-keywords}', "const a=hold({height:['0px','auto']},{duration:100,fill:'both'},0);height();a.currentTime=25;height();a.currentTime=50;height();a.currentTime=100;height();"],
  ['height auto reverse endpoint', '#box{interpolate-size:allow-keywords}', "const a=hold({height:['auto','20px']},{duration:100,fill:'both'},0);height();a.currentTime=25;height();a.currentTime=50;height();a.currentTime=100;height();"],
  ['height auto numeric-only remains discrete', '#box{interpolate-size:numeric-only}', "const a=hold({height:['0px','auto']},{duration:100,fill:'both'},49);height();a.currentTime=50;height();a.currentTime=100;height();"],
  ['height auto implicit endpoint', '#box{height:auto;interpolate-size:allow-keywords}', "const a=hold([{height:'0px',offset:0}],{duration:100,fill:'both'},25);height();a.currentTime=75;height();a.currentTime=100;height();"],
  ['height auto inherited allowance', '#parent{interpolate-size:allow-keywords}', "hold({height:['0px','auto']},{duration:100,fill:'both'},50);height();"],
  ['height auto live child size', '#box{interpolate-size:allow-keywords}', "const a=hold({height:['0px','auto']},{duration:100,fill:'both'},50);height();child.style.height='200px';height();a.currentTime=75;height();"],
  ['height auto cancellation restores author', '#box{height:80px;interpolate-size:allow-keywords}', "const a=hold({height:['0px','auto']},{duration:100,fill:'both'},50);height();a.cancel();height();box.style.height='150px';height();"],
  ['height auto border-box', '#box{box-sizing:border-box;padding:10px;border:2px solid black;interpolate-size:allow-keywords}', "const a=hold({height:['24px','auto']},{duration:100,fill:'both'},50);height();a.currentTime=100;height();"],
  ['height auto content-box', '#box{box-sizing:content-box;padding:10px;border:2px solid black;interpolate-size:allow-keywords}', "const a=hold({height:['0px','auto']},{duration:100,fill:'both'},50);height();a.currentTime=100;height();"],
  ['block-size auto horizontal', '#box{writing-mode:horizontal-tb;interpolate-size:allow-keywords}', "const a=hold({blockSize:['0px','auto']},{duration:100,fill:'both'},25);height();a.currentTime=75;height();"],
  ['height auto mixed percentages', '#parent{height:200px}#box{interpolate-size:allow-keywords}', "const a=hold({height:['20%','auto']},{duration:100,fill:'both'},50);height();a.currentTime=75;height();"],
  ['height auto allow-keywords live change', '#box{interpolate-size:numeric-only}', "const a=hold({height:['0px','auto']},{duration:100,fill:'both'},25);height();box.style.interpolateSize='allow-keywords';height();box.style.interpolateSize='numeric-only';height();"],
  ['height auto add with numeric author', '#box{height:80px;interpolate-size:allow-keywords}', "const a=hold({height:['0px','auto']},{duration:100,fill:'both',composite:'add'},0);height();a.currentTime=50;height();a.currentTime=100;height();"],
  ['height auto accumulate with numeric author', '#box{height:80px;interpolate-size:allow-keywords}', "const a=hold({height:['0px','auto']},{duration:100,fill:'both',composite:'accumulate'},0);height();a.currentTime=50;height();a.currentTime=100;height();"],
  ['height auto add with auto author', '#box{height:auto;interpolate-size:allow-keywords}', "const a=hold({height:['0px','40px']},{duration:100,fill:'both',composite:'add'},0);height();a.currentTime=50;height();a.currentTime=100;height();"],
  ['height auto stacked numeric effect', '#box{height:80px;interpolate-size:allow-keywords}', "hold({height:['0px','auto']},{duration:100,fill:'both'},50);hold({height:['10px','30px']},{duration:100,fill:'both',composite:'add'},50);height();"],
  ['height auto easing overshoot', '#box{interpolate-size:allow-keywords}', "hold({height:['0px','auto']},{duration:100,fill:'both',easing:'linear(0,1.5,1)'},50);height();"],
  ['height auto easing negative progress', '#box{interpolate-size:allow-keywords}', "hold({height:['auto','20px']},{duration:100,fill:'both',easing:'linear(0,-0.5,1)'},50);height();"],
  ['height auto add identical keywords', '#box{height:auto;interpolate-size:allow-keywords}', "hold({height:['auto','auto']},{duration:100,fill:'both',composite:'add'},50);height();"],
  ['height auto add numeric-only author', '#box{height:auto;interpolate-size:numeric-only}', "hold({height:['0px','40px']},{duration:100,fill:'both',composite:'add'},50);height();"],
  ['integer order retained flex movement', '#parent{display:flex;align-items:flex-start}#box{width:40px;height:10px;flex-shrink:0}', "child.style.cssText='display:block;width:20px;height:10px;flex-shrink:0;order:1';box.removeChild(child);document.getElementById('parent').appendChild(child);const other=document.createElement('div');other.style.cssText='width:30px;height:10px;flex-shrink:0;order:3';document.getElementById('parent').appendChild(other);const a=hold({order:['0','4']},{duration:100,fill:'both'},0);record(getComputedStyle(box).order);record(box.getBoundingClientRect().x);a.currentTime=25;record(getComputedStyle(box).order);record(box.getBoundingClientRect().x);a.currentTime=50;record(getComputedStyle(box).order);record(box.getBoundingClientRect().x);a.currentTime=100;record(getComputedStyle(box).order);record(box.getBoundingClientRect().x);a.cancel();record(getComputedStyle(box).order);record(box.getBoundingClientRect().x);"],
  ['integer order negative half rounding', '#box{order:0}', "const a=hold({order:['-3','0']},{duration:100,fill:'both'},50);record(getComputedStyle(box).order);a.currentTime=25;record(getComputedStyle(box).order);a.commitStyles();a.cancel();record(box.style.order);record(getComputedStyle(box).order);"],
  ['integer order additive live base', '#box{order:2}', "const a=hold({order:['0','3']},{duration:100,fill:'both',composite:'add'},50);record(getComputedStyle(box).order);box.style.order='4';record(getComputedStyle(box).order);a.cancel();record(getComputedStyle(box).order);"],
  ['integer column-count midpoint and auto', '#box{column-count:1}', "const a=hold({columnCount:['1','4']},{duration:100,fill:'both'},50);record(getComputedStyle(box).columnCount);a.commitStyles();a.cancel();record(box.style.columnCount);record(getComputedStyle(box).columnCount);"],
  ['column-width numeric midpoint', '#box{column-width:40px}', "const a=hold({columnWidth:['40px','80px']},{duration:100,fill:'both'},50);record(getComputedStyle(box).columnWidth);a.cancel();record(getComputedStyle(box).columnWidth);"],
  ['numeric author equal to current sample', '#box{width:100px}', "const a=hold({width:['0px','60px']},{duration:100,fill:'both',composite:'add'},50);record(box.getBoundingClientRect().width);box.style.width='130px';record(box.getBoundingClientRect().width);a.cancel();record(box.getBoundingClientRect().width);"],
  ['width intrinsic numeric-only is discrete', '#box{interpolate-size:numeric-only}', "const a=hold({width:['0px','min-content']},{duration:100,fill:'both'},49);record(box.getBoundingClientRect().width);a.currentTime=50;record(box.getBoundingClientRect().width);a.currentTime=100;record(box.getBoundingClientRect().width);"],
].map(([name, css, source]) => ({name:'intrinsic '+name, css, source:prefix+source, layout:true}));
const cssCases = [
  ['CSS height auto linear', '0px', 'auto', 'linear', 'replace', '80px', 60],
  ['CSS height auto reverse', 'auto', '20px', 'linear', 'replace', '80px', 70],
  ['CSS height auto add', '0px', 'auto', 'linear', 'add', '80px', 140],
  ['CSS height auto accumulate', '0px', 'auto', 'linear', 'accumulate', '80px', 140],
  ['CSS height auto overshoot', '0px', 'auto', 'linear(0,1.5,1)', 'replace', '80px', 180],
  ['CSS height auto negative progress', 'auto', '20px', 'linear(0,-0.5,1)', 'replace', '80px', 170],
].map(([name,from,to,easing,composite,underlying])=>({name,css:'@keyframes intrinsic{from{height:'+from+'}to{height:'+to+'}}#box{width:200px;height:'+underlying+';interpolate-size:allow-keywords;animation:intrinsic 100s '+easing+' -50s both paused;animation-composition:'+composite+'}#field{position:absolute;visibility:hidden}'}));
async function main() {
  const browser = await openBrowser(path.join(root, 'build', 'animation-intrinsic-reference'));
  try {
    for (const item of cases) {
      await browser.load('<!doctype html><html><head><style>html,body{margin:0;padding:0}#box{width:200px;height:100px;background:white}'+item.css+'</style></head><body><div id="parent"><div id="box"></div></div><div id="outside">Unchanged</div></body></html>');
      item.expected = await browser.evaluate('(()=>{const output=[];function record(value){output.push(String(value));}'+item.source+'return output;})()');
    }
    for (const item of cssCases) {
      await browser.load('<!doctype html><html><head><style>html,body{margin:0;padding:0}'+item.css+'</style></head><body><div id="box"><input id="field"><div style="display:block;width:20px;height:120px;margin:0;padding:0"></div></div></body></html>');
      item.expected=await browser.evaluate('document.getElementById("box").getBoundingClientRect().height');
    }
    fs.writeFileSync(path.join(root, 'tests/fixtures/animation-intrinsic-native.json'), JSON.stringify({source:'CSS Values and Units Level 5, 4 September 2026; isolated Chromium',cases,cssCases}, null, 2)+'\n');
    const fixturePath = path.join(root, 'tests/fixtures/javascript-animation-layout.json');
    const previous = JSON.parse(fs.readFileSync(fixturePath, 'utf8')).filter(item => !item.name.startsWith('intrinsic '));
    fs.writeFileSync(fixturePath, JSON.stringify([...previous,...cases],null,2)+'\n');
    process.stdout.write(JSON.stringify([...cases,...cssCases].map(item=>({name:item.name,expected:item.expected})),null,2)+'\n');
  } finally { await browser.close(); }
}
main().catch(error=>{process.stderr.write(String(error.stack||error)+'\n');process.exitCode=1;});
