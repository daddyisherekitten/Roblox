const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..');
async function main(){
 const browser=await openBrowser(path.join(root,'build','animation-font-transition-reference'));
 const cases=[];
 try{
  for(const [name,from,to]of [['unitless','1','2'],['length','20px','40px'],['percentage','100%','200%']]){
   const css='#box{font-size:20px;line-height:'+from+';width:3em;transition:font-size 2s linear,line-height 2s linear}#box.active{font-size:40px;line-height:'+to+'}#leaf{width:3em;height:1em}';
   await browser.load('<!doctype html><html><head><style>html,body{margin:0;padding:0}'+css+'</style></head><body><div id="box"><div id="leaf"></div></div></body></html>');
   const values=await browser.evaluate(`(()=>{const box=document.getElementById('box'),leaf=document.getElementById('leaf');const output=[];function hold(t){for(const a of box.getAnimations()){a.pause();a.currentTime=t;}}function read(){const s=getComputedStyle(box),r=leaf.getBoundingClientRect();output.push({font:s.fontSize,line:s.lineHeight,width:r.width,height:r.height,durations:box.getAnimations().map(a=>[a.transitionProperty,a.effect.getTiming().duration])});}box.offsetWidth;box.className='active';box.offsetWidth;hold(1000);read();box.className='';box.offsetWidth;hold(500);read();return output;})()`);
   cases.push({name,css,values});
  }
  fs.writeFileSync(path.join(root,'tests/fixtures/animation-font-transition-native.json'),JSON.stringify({reference:'Isolated Chromium headless, paused native CSSTransition.currentTime; 9 October 2026',cases},null,2)+'\n');
  console.log(JSON.stringify(cases,null,2));
 }finally{await browser.close();}
}
main().catch(error=>{console.error(error.stack||error);process.exitCode=1;});
