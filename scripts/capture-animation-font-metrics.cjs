// Browser-derived inherited font metrics. Each capture replaces this family
// in the shared fixture; native evidence does not mark all of C08 complete.
const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..');
const prefix="const box=document.getElementById('box');function hold(frames,options,time){const a=box.animate(frames,options);a.finished.catch(()=>{});a.ready.catch(()=>{});a.pause();a.currentTime=time;return a;}function value(node,name){record(getComputedStyle(node).getPropertyValue(name));}function child(id,css){const n=document.createElement('div');n.id=id;n.style.cssText=css;box.appendChild(n);return n;}function extent(node){const r=node.getBoundingClientRect();record(r.width);record(r.height);} ";
const base='#box{font-size:20px;line-height:1.2;height:auto}';
const cases=[
 ['font size retained em',base,"const leaf=child('leaf','width:3em;height:1em');const a=hold({fontSize:['10px','30px']},{duration:100,fill:'both'},50);value(box,'font-size');value(leaf,'font-size');extent(leaf);a.cancel();value(box,'font-size');extent(leaf);"],
 ['font size add',base,"const leaf=child('leaf','width:3em;height:1em');const a=hold({fontSize:['2px','10px']},{duration:100,fill:'both',composite:'add'},50);value(box,'font-size');extent(leaf);a.commitStyles();a.cancel();record(box.style.fontSize);value(box,'font-size');extent(leaf);"],
 ['font size accumulate',base,"const leaf=child('leaf','width:3em;height:1em');hold({fontSize:['2px','10px']},{duration:100,fill:'both',composite:'accumulate'},50);value(box,'font-size');extent(leaf);"],
 ['font size relative child',base,"const inherited=child('relative','font-size:1.5em;width:2em;height:1em');const fixed=child('fixed','font-size:12px;width:2em;height:1em');const a=hold({fontSize:['20px','40px']},{duration:100,fill:'both'},50);value(inherited,'font-size');extent(inherited);value(fixed,'font-size');extent(fixed);a.cancel();value(inherited,'font-size');extent(inherited);"],
 ['font size relative target dimensions','#box{font-size:20px;line-height:1.2;width:5em;height:2em;padding:1em;border:0}',"const a=hold({fontSize:['20px','40px']},{duration:100,fill:'both'},50);value(box,'font-size');value(box,'width');value(box,'height');value(box,'padding-top');extent(box);a.cancel();extent(box);"],
 ['font size live author equal sample',base,"const a=hold({fontSize:['2px','10px']},{duration:100,fill:'both',composite:'add'},50);value(box,'font-size');box.style.fontSize='26px';value(box,'font-size');a.cancel();value(box,'font-size');"],
 ['font size independent importance',base+'#box{font-size:24px!important}',"hold({fontSize:['10px','30px'],lineHeight:['1','2']},{duration:100,fill:'both'},50);value(box,'font-size');value(box,'line-height');"],
 ['line height unitless inheritance',base,"const leaf=child('leaf','font-size:10px');leaf.textContent='M';const a=hold({lineHeight:['1','2']},{duration:100,fill:'both'},50);value(box,'line-height');value(leaf,'line-height');extent(leaf);a.commitStyles();a.cancel();record(box.style.lineHeight);value(leaf,'line-height');"],
 ['line height length inheritance',base,"const leaf=child('leaf','font-size:10px');leaf.textContent='M';const a=hold({lineHeight:['20px','40px']},{duration:100,fill:'both'},50);value(box,'line-height');value(leaf,'line-height');extent(leaf);a.cancel();value(leaf,'line-height');"],
 ['line height add',base,"const a=hold({lineHeight:['1','2']},{duration:100,fill:'both',composite:'add'},50);value(box,'line-height');a.commitStyles();a.cancel();record(box.style.lineHeight);value(box,'line-height');"],
 ['line height mixed value types',base,"const a=hold({lineHeight:['1','40px']},{duration:100,fill:'both'},25);value(box,'line-height');a.currentTime=50;value(box,'line-height');a.commitStyles();a.cancel();record(box.style.lineHeight);"],
 ['line height normal is discrete',base,"const a=hold({lineHeight:['normal','40px']},{duration:100,fill:'both'},25);value(box,'line-height');a.currentTime=50;value(box,'line-height');"],
 ['coupled font and percentage line height',base,"const a=hold({fontSize:['20px','40px'],lineHeight:['100%','200%']},{duration:100,fill:'both'},50);value(box,'font-size');value(box,'line-height');a.commitStyles();a.cancel();record(box.style.fontSize);record(box.style.lineHeight);"],
 ['coupled font and em line height',base,"hold({fontSize:['20px','40px'],lineHeight:['1em','2em']},{duration:100,fill:'both'},50);value(box,'font-size');value(box,'line-height');"],
 ['line height live author equal sample',base,"const a=hold({lineHeight:['.5','1.5']},{duration:100,fill:'both',composite:'add'},50);value(box,'line-height');box.style.lineHeight='2.2';value(box,'line-height');a.cancel();value(box,'line-height');"],
 ['root font rem descendants','html{font-size:16px}'+base,"const leaf=child('leaf','font-size:1rem;width:3rem;height:1rem');const root=document.documentElement;const a=root.animate({fontSize:['16px','32px']},{duration:100,fill:'both'});a.finished.catch(()=>{});a.ready.catch(()=>{});a.pause();a.currentTime=50;value(root,'font-size');value(leaf,'font-size');extent(leaf);a.cancel();extent(leaf);"],
 ['CSS font metric inheritance',base+'#box{animation:reference 100s linear -50s both paused}@keyframes reference{from{font-size:20px;line-height:1}to{font-size:40px;line-height:2}}',"const leaf=child('leaf','width:3em;height:1em');value(box,'font-size');value(box,'line-height');value(leaf,'font-size');extent(leaf);"],
 ['CSS and JS font stack',base+'#box{animation:reference 100s linear -50s both paused}@keyframes reference{from{font-size:20px}to{font-size:40px}}',"const leaf=child('leaf','width:3em;height:1em');hold({fontSize:['2px','10px']},{duration:100,fill:'both',composite:'add'},50);value(box,'font-size');extent(leaf);"],
 ['nested active font effects',base,"const leaf=child('leaf','font-size:1.5em;width:2em;height:1em');const a=hold({fontSize:['20px','40px']},{duration:100,fill:'both'},50);const b=leaf.animate({fontSize:['1em','2em']},{duration:100,fill:'both'});b.finished.catch(()=>{});b.ready.catch(()=>{});b.pause();b.currentTime=50;value(leaf,'font-size');extent(leaf);a.currentTime=75;value(leaf,'font-size');extent(leaf);a.cancel();value(leaf,'font-size');extent(leaf);b.cancel();value(leaf,'font-size');extent(leaf);"],
 ['font size uses parent em',base,"const leaf=child('leaf','width:3em;height:1em');hold({fontSize:['1em','2em']},{duration:100,fill:'both'},50);value(box,'font-size');extent(leaf);"],
 ['coupled font and calc line height',base,"const a=hold({fontSize:['20px','40px'],lineHeight:['calc(10px + 1em)','calc(20px + 2em)']},{duration:100,fill:'both'},50);value(box,'font-size');value(box,'line-height');a.commitStyles();a.cancel();record(box.style.lineHeight);"],
 ['font shorthand importance',base+'#box{font:24px/2 serif!important}',"hold({fontSize:['10px','30px'],lineHeight:['1','2']},{duration:100,fill:'both'},50);value(box,'font-size');value(box,'line-height');"],
 ['coupled font and em width',base,"hold({fontSize:['20px','40px'],width:['2em','4em']},{duration:100,fill:'both'},50);value(box,'font-size');value(box,'width');extent(box);"],
 ['coupled font and relative width add',base+'#box{width:5em}',"hold({fontSize:['20px','40px']},{duration:100,fill:'both'},50);hold({width:['1em','3em']},{duration:100,fill:'both',composite:'add'},50);value(box,'font-size');value(box,'width');extent(box);"],
 ['font metric target custom property',base+'#box{--small:10px;--large:30px}',"hold({fontSize:['var(--small)','var(--large)']},{duration:100,fill:'both'},50);value(box,'font-size');box.style.setProperty('--large','50px');value(box,'font-size');"],
 ['root font uses initial em','html{font-size:20px}'+base,"const root=document.documentElement;const a=root.animate({fontSize:['1em','2em']},{duration:100,fill:'both'});a.finished.catch(()=>{});a.ready.catch(()=>{});a.pause();a.currentTime=50;value(root,'font-size');a.cancel();value(root,'font-size');"],
 ['coupled font and percentage line height add',base+'#box{line-height:100%}',"hold({fontSize:['20px','40px']},{duration:100,fill:'both'},50);const a=hold({lineHeight:['100%','200%']},{duration:100,fill:'both',composite:'add'},50);value(box,'font-size');value(box,'line-height');a.commitStyles();a.cancel();record(box.style.lineHeight);value(box,'line-height');"],
 ['line height wide inherit',base+'#parent{line-height:2}',"hold({fontSize:['20px','40px'],lineHeight:['inherit','inherit']},{duration:100,fill:'both'},50);const leaf=child('leaf','font-size:10px');value(box,'line-height');value(leaf,'line-height');"],
 ['CSS additive line height extrapolation',base+'#box{line-height:3;animation:reference 100s cubic-bezier(0,-3,1,-3) -50s both paused;animation-composition:add}@keyframes reference{from{line-height:1}to{line-height:2}}',"value(box,'line-height');"],
 ['CSS font size extrapolation',base+'#box{animation:reference 100s cubic-bezier(0,-3,1,-3) -50s both paused}@keyframes reference{from{font-size:10px}to{font-size:20px}}',"const leaf=child('leaf','width:3em;height:1em');value(box,'font-size');extent(leaf);"],
 ['coupled font and nonlinear line height',base,"hold({fontSize:['20px','40px'],lineHeight:['min(100%, 20px)','max(200%, 30px)']},{duration:100,fill:'both'},50);value(box,'font-size');value(box,'line-height');"],
 ['line height invalid variable inherits',base+'#parent{line-height:2}#box{--line:inherit}',"hold({fontSize:['20px','40px'],lineHeight:['var(--line)','var(--line)']},{duration:100,fill:'both'},50);value(box,'line-height');"],
 ['coupled font and clamped line height',base,"hold({fontSize:['20px','40px'],lineHeight:['clamp(10px,100%,20px)','clamp(30px,200%,80px)']},{duration:100,fill:'both'},50);value(box,'font-size');value(box,'line-height');"],
 ['line height variable fallback inherit',base+'#parent{line-height:2}',"hold({fontSize:['20px','40px'],lineHeight:['var(--missing,inherit)','var(--missing,inherit)']},{duration:100,fill:'both'},50);value(box,'line-height');"],
 ['nested active line height bases',base,"const leaf=child('leaf','font-size:10px');const a=hold({lineHeight:['1','2']},{duration:100,fill:'both'},50);const b=leaf.animate({lineHeight:['.5','1.5']},{duration:100,fill:'both',composite:'add'});b.finished.catch(()=>{});b.ready.catch(()=>{});b.pause();b.currentTime=50;value(leaf,'line-height');a.currentTime=75;value(leaf,'line-height');a.cancel();value(leaf,'line-height');b.cancel();value(leaf,'line-height');"],
].map(([name,css,source])=>({name:'font metric '+name,css,source:prefix+source,expected:[],layout:true,cssMotion:name.startsWith('CSS ')}));
async function main(){
 const browser=await openBrowser(path.join(root,'build','animation-font-metrics-reference'));
 try{
  await browser.send('Emulation.setDeviceMetricsOverride',{width:600,height:800,deviceScaleFactor:1,mobile:false});
  for(const item of cases){
   await browser.load('<!doctype html><html><head><style>html,body{margin:0;padding:0}#box{width:200px;height:100px;background:white}'+item.css+'</style></head><body><div id="parent"><div id="box"></div></div><div id="outside">Unchanged</div></body></html>');
   item.expected=await browser.evaluate('(()=>{const output=[];function record(value){output.push(String(value));}'+item.source+'return output;})()');
  }
  const file=path.join(root,'tests/fixtures/javascript-animation-layout.json');
  const prior=JSON.parse(fs.readFileSync(file,'utf8')).filter(item=>!item.name.startsWith('font metric '));
  fs.writeFileSync(file,JSON.stringify([...prior,...cases],null,2)+'\n');
  console.log(JSON.stringify(cases.map(({name,expected})=>({name,expected})),null,2));
 }finally{await browser.close();}
}
main().catch(error=>{console.error(error.stack||error);process.exitCode=1;});
