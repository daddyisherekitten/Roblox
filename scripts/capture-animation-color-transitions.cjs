const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');const root=path.resolve(__dirname,'..');
const keys=['color','background-color','border-top-color','border-right-color','border-bottom-color','border-left-color','outline-color','text-decoration-color'];
async function main(){const browser=await openBrowser(path.join(root,'build','animation-color-transition-reference'));const cases=[];try{
 for(const [name,css,waapi]of [
  ['foreground inheritance','#box{color:rgb(40,60,80);border:2px solid currentColor;outline:2px solid currentColor;text-decoration:underline;transition:color 2s linear}#box.active{color:rgb(100,120,140)}',false],
  ['independent colors','#box{color:rgb(40,60,80);background:rgb(10,30,50);border:2px solid rgb(20,40,60);outline:2px solid rgb(30,50,70);text-decoration:underline rgb(40,60,80);transition:background-color 2s linear,border-color 2s linear,outline-color 2s linear,text-decoration-color 2s linear}#box.active{background:rgb(110,130,150);border-color:rgb(120,140,160);outline-color:rgb(130,150,170);text-decoration-color:rgb(140,160,180)}',false],
  ['WAAPI over held transition','#box{color:rgb(40,60,80);border:2px solid currentColor;outline:2px solid currentColor;text-decoration:underline;transition:color 2s linear}#box.active{color:rgb(100,120,140)}',true],
 ]){await browser.load('<!doctype html><html><head><style>'+css+'</style></head><body><div id="box"><div id="leaf" style="color:inherit">Color</div></div></body></html>');
  const values=await browser.evaluate(`(()=>{const box=document.getElementById('box'),leaf=document.getElementById('leaf');const output=[];function hold(t){for(const a of box.getAnimations()){if(a.transitionProperty){a.pause();a.currentTime=t;}}}function read(){const s=getComputedStyle(box);output.push({colors:Object.fromEntries(${JSON.stringify(keys)}.map(k=>[k,s.getPropertyValue(k)])),leaf:getComputedStyle(leaf).color,durations:box.getAnimations().filter(a=>a.transitionProperty).map(a=>[a.transitionProperty,a.effect.getTiming().duration])});}box.offsetWidth;box.className='active';box.offsetWidth;hold(1000);${waapi?"const a=box.animate({color:['rgb(10,20,30)','rgb(30,40,50)']},{duration:100,fill:'both'});a.finished.catch(()=>{});a.ready.catch(()=>{});a.pause();a.currentTime=50;":""}read();${waapi?"a.commitStyles();output.push({committed:box.style.color});a.cancel();":""}box.className='';box.offsetWidth;hold(500);read();return output;})()`);
  cases.push({name,css,waapi,values});
 }
 fs.writeFileSync(path.join(root,'tests/fixtures/animation-color-transition-native.json'),JSON.stringify({reference:'Isolated Chromium headless, held native CSSTransition samples; 10 October 2026',cases},null,2)+'\n');console.log(JSON.stringify(cases,null,2));
}finally{await browser.close();}}
main().catch(error=>{console.error(error.stack||error);process.exitCode=1;});
