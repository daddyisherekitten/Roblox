// Frozen CSS/WAAPI shadow-list values from an isolated native browser.
const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..');
const prefix="const box=document.getElementById('box');function hold(frames,composite='replace'){const a=box.animate(frames,{duration:1000,fill:'both',composite});a.finished.catch(()=>{});a.ready.catch(()=>{});a.pause();return a;}function sample(a,times=[0,250,500,750,1000]){for(const time of times){a.currentTime=time;record(getComputedStyle(box).boxShadow);}}function commit(a){a.currentTime=500;a.commitStyles();record(box.style.boxShadow);a.cancel();record(getComputedStyle(box).boxShadow);}";
const repeated=(value)=>`[{boxShadow:${JSON.stringify(value)}},{boxShadow:${JSON.stringify(value)}}]`;
const cases=[
 ['unequal list interpolation','',"const a=hold([{boxShadow:'2px 4px red'},{boxShadow:'6px 8px blue,10px 12px green'}]);sample(a);commit(a);"],
 ['none pads transparent shadows','',"const a=hold([{boxShadow:'none'},{boxShadow:'6px 8px 4px 2px red,-10px 12px blue'}]);sample(a);commit(a);"],
 ['add concatenates lists','#box{box-shadow:5px 10px 3px 2px red}',`const a=hold(${repeated('4px 8px 2px 1px blue')},'add');sample(a);commit(a);`],
 ['accumulate pairs components','#box{box-shadow:5px 10px 3px 2px red}',`const a=hold(${repeated('4px 8px 2px 1px blue')},'accumulate');sample(a);commit(a);`],
 ['accumulate unequal lists','#box{box-shadow:5px 10px 3px 2px red}',`const a=hold(${repeated('4px 8px 2px 1px blue,1px 2px green')},'accumulate');sample(a);commit(a);`],
 ['inset mismatch switches entire list','',"const a=hold([{boxShadow:'2px 4px red,1px 2px green'},{boxShadow:'inset 6px 8px blue,10px 12px green'}]);sample(a);commit(a);"],
 ['add preserves mixed inset lists','#box{box-shadow:5px 10px 3px 2px red}',`const a=hold(${repeated('inset 4px 8px 2px 1px blue')},'add');sample(a);commit(a);`],
 ['accumulate inset mismatch replaces','#box{box-shadow:5px 10px 3px 2px red}',`const a=hold(${repeated('inset 4px 8px 2px 1px blue')},'accumulate');sample(a);commit(a);`],
 ['currentColor interpolation','#box{color:red}',"const a=hold([{boxShadow:'1px 2px currentColor'},{boxShadow:'5px 6px blue'}]);sample(a);commit(a);"],
 ['premultiplied alpha','',"const a=hold([{boxShadow:'2px 4px rgba(255,0,0,.2)'},{boxShadow:'6px 8px rgba(0,0,255,.8)'}]);sample(a);commit(a);"],
 ['live foreground cancellation','#box{color:red;box-shadow:2px 4px currentColor}',"const a=hold([{boxShadow:'1px 2px currentColor'},{boxShadow:'5px 6px blue'}]);sample(a,[500]);box.style.color='green';sample(a,[500]);a.cancel();record(getComputedStyle(box).boxShadow);"],
 ['simultaneous foreground and inset','#box{color:black}',"const a=hold([{color:'red',boxShadow:'inset 2px 4px currentColor'},{color:'blue',boxShadow:'inset 6px 8px currentColor'}]);sample(a);commit(a);"],
 ['live additive author source','#box{box-shadow:1px 2px red}',`const a=hold(${repeated('3px 4px blue')},'add');sample(a,[500]);box.style.boxShadow='5px 6px green,7px 8px black';sample(a,[500]);a.cancel();record(getComputedStyle(box).boxShadow);`],
 ['variable source changes','#box{--shadow:2px 4px red;box-shadow:1px 2px black}',"const a=hold([{boxShadow:'var(--shadow)'},{boxShadow:'10px 12px blue'}]);sample(a,[500]);box.style.setProperty('--shadow','6px 8px green,2px 4px black');sample(a,[500]);a.cancel();record(getComputedStyle(box).boxShadow);"],
 ['invalid source keeps sparse endpoint','#box{box-shadow:2px 4px red}',"const a=hold([{boxShadow:'2px 4px -1px blue'},{boxShadow:'10px 12px blue'}]);record(a.effect.getKeyframes().length);sample(a,[500]);a.cancel();record(getComputedStyle(box).boxShadow);"],
 ['important author suppression and commit','#box{box-shadow:2px 4px red!important}',"const a=hold([{boxShadow:'6px 8px blue'},{boxShadow:'10px 12px blue'}]);sample(a,[500]);a.commitStyles();record(box.style.boxShadow);a.cancel();record(getComputedStyle(box).boxShadow);"],
 ['cancel lower independent additive layer','#box{box-shadow:1px 2px red}',`const a=hold(${repeated('3px 4px blue')},'add'),b=hold(${repeated('5px 6px green')},'add');sample(a,[500]);sample(b,[500]);a.cancel();record(getComputedStyle(box).boxShadow);b.cancel();record(getComputedStyle(box).boxShadow);`],
 ['none to inset padding','',"const a=hold([{boxShadow:'none'},{boxShadow:'inset 4px 8px 2px 1px red'}]);sample(a);commit(a);"],
 ['CSS keyframes list sampling','#box{animation:shadows 1s linear both paused}@keyframes shadows{from{box-shadow:2px 4px red}to{box-shadow:6px 8px blue,10px 12px green}}',"const a=box.getAnimations()[0];sample(a);a.cancel();record(getComputedStyle(box).boxShadow);",true],
 ['CSS additive keyframes','#box{box-shadow:1px 2px red;animation:shadows 1s linear both paused;animation-composition:add}@keyframes shadows{from{box-shadow:2px 4px blue}to{box-shadow:6px 8px green}}',"const a=box.getAnimations()[0];sample(a);a.cancel();record(getComputedStyle(box).boxShadow);",true],
 ['CSS accumulated keyframes','#box{box-shadow:1px 2px red;animation:shadows 1s linear both paused;animation-composition:accumulate}@keyframes shadows{from{box-shadow:2px 4px blue}to{box-shadow:6px 8px green}}',"const a=box.getAnimations()[0];sample(a);a.cancel();record(getComputedStyle(box).boxShadow);",true],
 ['CSS list transition commit','#box{box-shadow:2px 4px red;transition:box-shadow 1s linear}#box.active{box-shadow:6px 8px blue,10px 12px green}',"box.offsetWidth;box.className='active';box.offsetWidth;const a=box.getAnimations()[0];a.finished.catch(()=>{});a.ready.catch(()=>{});a.pause();sample(a);commit(a);for(const effect of box.getAnimations())effect.cancel();",true],
 ['CSS inset mismatch no transition','#box{box-shadow:2px 4px red;transition:box-shadow 1s linear}#box.active{box-shadow:inset 6px 8px blue}',"box.offsetWidth;box.className='active';box.offsetWidth;record(box.getAnimations().length);record(getComputedStyle(box).boxShadow);",true],
 ['CSS allowed discrete inset transition','#box{box-shadow:2px 4px red;transition:box-shadow 1s linear allow-discrete}#box.active{box-shadow:inset 6px 8px blue}',"box.offsetWidth;box.className='active';box.offsetWidth;const a=box.getAnimations()[0];a.finished.catch(()=>{});a.ready.catch(()=>{});a.pause();sample(a);a.cancel();record(getComputedStyle(box).boxShadow);",true],
 ['CSS reversal keeps interpolated lists','#box{box-shadow:2px 4px red;transition:box-shadow 1s linear}#box.active{box-shadow:6px 8px blue,10px 12px green}',"box.offsetWidth;box.className='active';box.offsetWidth;let a=box.getAnimations()[0];a.finished.catch(()=>{});a.ready.catch(()=>{});a.pause();a.currentTime=500;record(getComputedStyle(box).boxShadow);box.className='';box.offsetWidth;const b=box.getAnimations()[0];record(b.effect.getTiming().duration);b.finished.catch(()=>{});b.ready.catch(()=>{});b.pause();sample(b,[125,250,500]);b.cancel();record(getComputedStyle(box).boxShadow);",true],
].map(([name,css,source,cssMotion])=>({name:'box shadow '+name,css,source:prefix+source,expected:[],...(cssMotion?{cssMotion:true}:{})}));
async function main(){const browser=await openBrowser(path.join(root,'build','animation-shadow-reference'));try{
 await browser.send('Emulation.setDeviceMetricsOverride',{width:600,height:800,deviceScaleFactor:1,mobile:false});
 for(const item of cases){await browser.load('<!doctype html><html><head><style>html,body{margin:0;padding:0}#box{width:200px;height:100px;background:white}'+item.css+'</style></head><body><div id="parent"><div id="box"></div></div><div id="outside">Unchanged</div></body></html>');item.expected=await browser.evaluate('(()=>{const output=[];function record(value){output.push(String(value));}'+item.source+'return output;})()');}
 for(const item of cases){
  if(item.name==='box shadow CSS list transition commit'){
   item.normativeExpected=[...item.expected];item.normativeExpected[5]=item.expected[2];item.normativeExpected[6]=item.expected[2];
   item.nativeDifference='After endpoint then seek, Chromium commits the transition endpoint; this profile commits its held midpoint. Raw browser values remain unchanged.';
  }else if(item.name==='box shadow CSS reversal keeps interpolated lists'){
   item.normativeExpected=[...item.expected];item.normativeExpected[2]='rgb(160, 0, 96) 3.5px 5.5px 0px 0px, rgba(0, 128, 0, 0.375) 3.75px 4.5px 0px 0px';item.normativeExpected[3]='rgb(192, 0, 64) 3px 5px 0px 0px, rgba(0, 128, 0, 0.25) 2.5px 3px 0px 0px';
   item.nativeDifference='Chromium rounds the held before-change RGB/alpha to 8-bit channels before reversing; this profile retains float channels until serialization.';
  }
 }
 const file=path.join(root,'tests/fixtures/javascript-animation-layout.json'),prior=JSON.parse(fs.readFileSync(file,'utf8')).filter(item=>!item.name.startsWith('box shadow '));fs.writeFileSync(file,JSON.stringify([...prior,...cases],null,2)+'\n');console.log(JSON.stringify(cases.map(({name,expected})=>({name,expected})),null,2));
}finally{await browser.close();}}
main().catch(error=>{console.error(error.stack||error);process.exitCode=1;});
