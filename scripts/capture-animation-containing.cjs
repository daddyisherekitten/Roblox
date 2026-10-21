// Animation-created containing blocks, shared with the retained renderer.
const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..');
const css='#parent{margin:40px 30px}#box{margin-left:50px}#absolute,#fixed{width:20px;height:10px;left:10px;top:15px}#absolute{position:absolute}#fixed{position:fixed}';
const prefix="const box=document.getElementById('box');const absolute=document.createElement('div');absolute.id='absolute';box.appendChild(absolute);const fixed=document.createElement('div');fixed.id='fixed';box.appendChild(fixed);function hold(frames,options,time){const a=box.animate(frames,options);a.finished.catch(()=>{});a.ready.catch(()=>{});a.pause();a.currentTime=time;return a;}function rect(node){const r=node.getBoundingClientRect();for(const key of ['x','y','width','height'])record(Math.round(r[key]*1000)/1000);}function children(){rect(absolute);rect(fixed);} ";
const cases=[
 ['translate creates and releases','',"children();const a=hold({translate:['none','40px']},{duration:100,fill:'both'},0);children();a.currentTime=50;children();a.cancel();children();"],
 ['transform identity creates and releases','',"children();const a=hold({transform:['translateX(0)','translateX(40px)']},{duration:100,fill:'both'},0);children();a.currentTime=50;children();a.cancel();children();"],
 ['none to none implicit will-change','',"children();const a=hold({translate:['none','none'],transform:['none','none']},{duration:100,fill:'both'},50);children();a.cancel();children();"],
 ['rotate none implicit will-change','',"children();const a=hold({rotate:['none','none']},{duration:100,fill:'both'},50);children();a.cancel();children();"],
 ['scale none implicit will-change','',"children();const a=hold({scale:['none','none']},{duration:100,fill:'both'},50);children();a.cancel();children();"],
 ['suppressed author translate','#box{translate:40px}',"children();const a=hold({translate:['none','none']},{duration:100,fill:'both'},50);children();a.cancel();children();"],
 ['suppressed author transform','#box{transform:translateX(40px)}',"children();const a=hold({transform:['none','none']},{duration:100,fill:'both'},50);children();a.cancel();children();"],
 ['remaining author rotate','#box{translate:40px;rotate:0deg}',"children();const a=hold({translate:['none','none']},{duration:100,fill:'both'},50);children();a.cancel();children();"],
 ['important none still targeted','#box{translate:none!important}',"children();const a=hold({translate:['0px','40px']},{duration:100,fill:'both'},50);children();a.cancel();children();"],
 ['delayed no fill','',"const a=hold({translate:['0px','40px']},{duration:100,delay:100},50);children();a.currentTime=100;children();a.currentTime=150;children();a.currentTime=200;children();a.cancel();children();"],
 ['reversed after phase current','',"const a=hold({translate:['0px','40px']},{duration:100},150);children();a.playbackRate=-1;children();a.currentTime=-50;children();a.cancel();children();"],
 ['delay backwards and completion forwards','',"const a=hold({translate:['0px','40px']},{duration:100,delay:100,fill:'both'},50);children();a.currentTime=200;children();a.cancel();children();"],
 ['percentage descendants','#box{padding:10px;border:5px solid black}#absolute,#fixed{width:50%;height:50%;left:10%;top:10%}',"children();const a=hold({translate:['0px','40px']},{duration:100,fill:'both'},50);children();a.cancel();children();"],
 ['nested retained relative parent','',"const middle=document.createElement('div');middle.style.cssText='position:relative;margin-left:20px;width:100px;height:30px';box.appendChild(middle);middle.appendChild(absolute);middle.appendChild(fixed);children();const a=hold({translate:['0px','40px']},{duration:100,fill:'both'},50);children();a.cancel();children();"],
 ['lower effect restored when upper cancelled','',"const lower=hold({translate:['0px','40px']},{duration:100,fill:'both'},50);children();const upper=hold({translate:['none','none']},{duration:100,fill:'both'},50);children();upper.cancel();children();lower.cancel();children();"],
 ['contain layout retained','#box{contain:layout}',"children();const a=hold({translate:['none','40px']},{duration:100,fill:'both'},50);children();a.cancel();children();"],
 ['CSS identity and removal','#box{animation:reference 100s linear -50s both paused}@keyframes reference{from{translate:0px}to{translate:40px}}',"children();box.style.animation='none';children();"],
 ['CSS none stops and removal','#box{animation:reference 100s linear -50s both paused}@keyframes reference{from{translate:none}to{translate:none}}',"children();box.style.animation='none';children();"],
 ['CSS important none still targeted','#box{translate:none!important;animation:reference 100s linear -50s both paused}@keyframes reference{from{translate:0px}to{translate:40px}}',"children();box.style.animation='none';children();"],
 ['CSS before delay no fill','#box{animation:reference 100s linear 100s paused}@keyframes reference{from{translate:0px}to{translate:40px}}',"children();box.style.animation='none';children();"],
 ['CSS paused after phase no fill','#box{animation:reference 100s linear -200s paused}@keyframes reference{from{translate:0px}to{translate:40px}}',"children();box.style.animation='none';children();"],
 ['CSS lower and script suppression','#box{animation:reference 100s linear -50s both paused}@keyframes reference{from{translate:0px}to{translate:40px}}',"children();const a=hold({translate:['none','none']},{duration:100,fill:'both'},50);children();a.cancel();children();box.style.animation='none';children();"],
].map(([name,extra,source])=>({name:'containing '+name,css:css+extra,source:prefix+source,expected:[],layout:true,cssMotion:name.startsWith('CSS '),browserOnly:name==='reversed after phase current'}));
async function main(){
 const browser=await openBrowser(path.join(root,'build','animation-containing-reference'));
 try{
  await browser.send('Emulation.setDeviceMetricsOverride',{width:600,height:800,deviceScaleFactor:1,mobile:false});
  for(const item of cases){
   await browser.load('<!doctype html><html><head><style>html,body{margin:0;padding:0}#box{width:200px;height:100px;background:white}'+item.css+'</style></head><body><div id="parent"><div id="box"></div></div><div id="outside">Unchanged</div></body></html>');
   item.expected=await browser.evaluate('(()=>{const output=[];function record(value){output.push(String(value));}'+item.source+'return output;})()');
  }
  const file=path.join(root,'tests/fixtures/javascript-animation-layout.json');
  const prior=JSON.parse(fs.readFileSync(file,'utf8')).filter(item=>!item.name.startsWith('containing '));
  fs.writeFileSync(file,JSON.stringify([...prior,...cases],null,2)+'\n');
  console.log(JSON.stringify(cases.map(({name,expected})=>({name,expected})),null,2));
 }finally{await browser.close();}
}
main().catch(error=>{console.error(error.stack||error);process.exitCode=1;});
