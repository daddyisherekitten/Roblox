// Native individual-transform references, isolated from the user's browser.
const fs = require('node:fs'), path = require('node:path');
const { openBrowser } = require('./native-browser.cjs');
const root = path.resolve(__dirname, '..');
const prefix = "const box=document.getElementById('box');function hold(frames,options,time){getComputedStyle(box).transform;const a=box.animate(frames,options);a.finished.catch(()=>{});a.ready.catch(()=>{});a.pause();a.currentTime=time;return a;}function value(name){record(getComputedStyle(box).getPropertyValue(name));}function rect(){const r=box.getBoundingClientRect();for(const n of ['x','y','width','height'])record(Math.round(r[n]*1000)/1000);}";
const cases = [
 ['translate none identity','',"const a=hold({translate:['none','40px 20px']},{duration:100,fill:'both'},0);value('translate');a.currentTime=50;value('translate');rect();a.currentTime=100;value('translate');a.cancel();value('translate');"],
 ['translate percentages computed and committed','',"const a=hold({translate:['10% 20%','30% 40%']},{duration:100,fill:'both'},50);value('translate');rect();a.commitStyles();a.cancel();record(box.style.translate);value('translate');box.style.width='400px';rect();"],
 ['translate calc interpolation','',"hold({translate:['calc(10% + 10px) 20px','calc(30% + 30px) 40px']},{duration:100,fill:'both'},50);value('translate');rect();"],
 ['translate add live base','#box{translate:10px 20px}',"const a=hold({translate:['0px 0px','40px 20px']},{duration:100,fill:'both',composite:'add'},50);value('translate');rect();box.style.translate='30px 40px';value('translate');a.cancel();value('translate');"],
 ['translate accumulate','#box{translate:10% 20%}',"hold({translate:['0% 0%','20% 40%']},{duration:100,fill:'both',composite:'accumulate'},50);value('translate');rect();"],
 ['translate partial endpoint','#box{translate:40px 20px}',"hold([{translate:'0px',offset:0}],{duration:100,fill:'both'},50);value('translate');rect();"],
 ['translate inherited relative values','#parent{translate:10px 20px}#box{font-size:20px}',"hold({translate:['inherit','2em 3em']},{duration:100,fill:'both'},50);value('translate');"],
 ['translate none both','',"hold({translate:['none','none']},{duration:100,fill:'both'},50);value('translate');rect();"],
 ['scale none identity','',"const a=hold({scale:['none','2']},{duration:100,fill:'both'},0);value('scale');a.currentTime=50;value('scale');rect();a.currentTime=100;value('scale');a.cancel();value('scale');"],
 ['scale percentage grammar','',"hold({scale:['100% 200%','300% 400%']},{duration:100,fill:'both'},50);value('scale');rect();"],
 ['scale add','#box{scale:2 3}',"const a=hold({scale:['1 1','3 3']},{duration:100,fill:'both',composite:'add'},50);value('scale');rect();a.commitStyles();a.cancel();record(box.style.scale);value('scale');"],
 ['scale accumulate','#box{scale:2 3}',"hold({scale:['1 1','3 3']},{duration:100,fill:'both',composite:'accumulate'},50);value('scale');rect();"],
 ['scale negative sign','',"hold({scale:['1','-1']},{duration:100,fill:'both'},75);value('scale');rect();"],
 ['rotate complete revolution','',"const a=hold({rotate:['0deg','360deg']},{duration:100,fill:'both'},50);value('rotate');a.currentTime=25;value('rotate');a.commitStyles();a.cancel();record(box.style.rotate);value('rotate');"],
 ['rotate none identity','',"const a=hold({rotate:['none','90deg']},{duration:100,fill:'both'},0);value('rotate');a.currentTime=50;value('rotate');rect();a.cancel();value('rotate');"],
 ['rotate add same axis','#box{rotate:30deg}',"hold({rotate:['0deg','60deg']},{duration:100,fill:'both',composite:'add'},50);value('rotate');"],
 ['rotate accumulate same axis','#box{rotate:30deg}',"hold({rotate:['0deg','60deg']},{duration:100,fill:'both',composite:'accumulate'},50);value('rotate');"],
 ['rotate normalized matching axes','',"hold({rotate:['1 1 0 30deg','2 2 0 90deg']},{duration:100,fill:'both'},50);value('rotate');"],
 ['rotate different axes slerp','',"hold({rotate:['x 90deg','y 90deg']},{duration:100,fill:'both'},50);value('rotate');"],
 ['rotate different axes add','#box{rotate:x 90deg}',"hold({rotate:['y 90deg','y 90deg']},{duration:100,fill:'both',composite:'add'},50);value('rotate');"],
 ['rotate different axes accumulate','#box{rotate:x 90deg}',"hold({rotate:['y 90deg','y 90deg']},{duration:100,fill:'both',composite:'accumulate'},50);value('rotate');"],
 ['individual and transform ordered geometry','#box{transform-origin:0 0;translate:10px 20px;rotate:90deg;scale:2;transform:translateX(5px)}',"hold({translate:['10px 20px','30px 40px'],rotate:['0deg','180deg'],scale:['1','3'],transform:['translateX(0)','translateX(10px)']},{duration:100,fill:'both'},50);value('translate');value('rotate');value('scale');value('transform');rect();"],
 ['individual stack cancel exposes lower effect','#box{translate:10px}',"const a=hold({translate:['0px','40px']},{duration:100,fill:'both',composite:'add'},50);const b=hold({translate:['5px','15px']},{duration:100,fill:'both',composite:'add'},50);value('translate');b.cancel();value('translate');a.cancel();value('translate');"],
 ['individual important author wins','#box{translate:15px!important;rotate:20deg!important;scale:2!important}',"hold({translate:['0px','40px'],rotate:['0deg','90deg'],scale:['1','3']},{duration:100,fill:'both'},50);value('translate');value('rotate');value('scale');"],
 ['individual CSS lower and script upper','#box{animation:low 100s linear -50s both paused}@keyframes low{from{translate:0px;rotate:0deg;scale:1}to{translate:40px;rotate:60deg;scale:3}}',"const a=hold({translate:['0px','20px'],rotate:['0deg','20deg'],scale:['1','2']},{duration:100,fill:'both',composite:'add'},50);value('translate');value('rotate');value('scale');a.cancel();value('translate');value('rotate');value('scale');"],
 ['individual overshooting easing','',"hold({translate:['0px','40px'],rotate:['0deg','90deg'],scale:['1','2']},{duration:100,fill:'both',easing:'linear(0,1.5,1)'},50);value('translate');value('rotate');value('scale');"],
 ['rotate angle before keyword axis','',"const a=hold({rotate:['30deg x','90deg x']},{duration:100,fill:'both'},50);value('rotate');a.commitStyles();a.cancel();record(box.style.rotate);value('rotate');"],
 ['rotate angle before vector axis','',"hold({rotate:['30deg 1 1 0','90deg 2 2 0']},{duration:100,fill:'both'},50);value('rotate');"],
 ['rotate none to x axis','',"hold({rotate:['none','x 90deg']},{duration:100,fill:'both'},50);value('rotate');"],
 ['rotate zero vector axis','',"hold({rotate:['0 0 0 90deg','0 0 0 180deg']},{duration:100,fill:'both'},50);value('rotate');rect();"],
 ['rotate zero axis to valid axis','',"hold({rotate:['0 0 0 90deg','z 90deg']},{duration:100,fill:'both'},50);value('rotate');rect();"],
 ['rotate opposite vector axes','',"hold({rotate:['0 0 -1 30deg','0 0 1 30deg']},{duration:100,fill:'both'},50);value('rotate');rect();"],
 ['translate third axis and commit','',"const a=hold({translate:['0px 10% 20px','40px 30% 60px']},{duration:100,fill:'both'},50);value('translate');a.commitStyles();a.cancel();record(box.style.translate);value('translate');"],
 ['scale third axis and commit','',"const a=hold({scale:['1 2 3','3 4 5']},{duration:100,fill:'both'},50);value('scale');a.commitStyles();a.cancel();record(box.style.scale);value('scale');"],
 ['scale none both','',"hold({scale:['none','none']},{duration:100,fill:'both'},50);value('scale');"],
 ['individual live variable and initial','#box{translate:10px;--end:40px}',"const a=hold({translate:['initial','var(--end)']},{duration:100,fill:'both'},50);value('translate');box.style.setProperty('--end','80px');value('translate');a.commitStyles();a.cancel();record(box.style.translate);value('translate');"],
 ['rotate static vector serialization','#box{rotate:1 1 0 30deg}',"value('rotate');"],
 ['opacity variable republished in same script','#box{--end:.4}',"hold({opacity:['0','var(--end)']},{duration:100,fill:'both'},50);value('opacity');box.style.setProperty('--end','.8');value('opacity');"],
 ['CSS individual replace','#box{translate:10px 20px;rotate:30deg;scale:2;animation:individual 100s linear -50s both paused}@keyframes individual{from{translate:0px 0px;rotate:0deg;scale:1}to{translate:40px 20px;rotate:60deg;scale:3}}',"value('translate');value('rotate');value('scale');rect();"],
 ['CSS individual add','#box{translate:10px 20px;rotate:30deg;scale:2;animation:individual 100s linear -50s both paused;animation-composition:add}@keyframes individual{from{translate:0px 0px;rotate:0deg;scale:1}to{translate:40px 20px;rotate:60deg;scale:3}}',"value('translate');value('rotate');value('scale');rect();"],
 ['CSS individual accumulate','#box{translate:10px 20px;rotate:30deg;scale:2;animation:individual 100s linear -50s both paused;animation-composition:accumulate}@keyframes individual{from{translate:0px 0px;rotate:0deg;scale:1}to{translate:40px 20px;rotate:60deg;scale:3}}',"value('translate');value('rotate');value('scale');rect();"],
 ['CSS percent and calc translate','#box{animation:individual 100s linear -50s both paused}@keyframes individual{from{translate:calc(10% + 10px) 10%}to{translate:calc(30% + 30px) 30%}}',"value('translate');rect();"],
 ['CSS zero rotation and 3D scale','#box{animation:individual 100s linear -50s both paused}@keyframes individual{from{rotate:0 0 0 90deg;scale:1 2 3}to{rotate:z 90deg;scale:3 4 5}}',"value('rotate');value('scale');rect();"],
 ['CSS inherited individual endpoint','#parent{translate:20px 40px}#box{animation:individual 100s linear -50s both paused}@keyframes individual{from{translate:inherit}to{translate:40px 60px}}',"value('translate');"],
 ['rotate scientific angles','',"hold({rotate:['3e1deg','9e1DEG']},{duration:100,fill:'both'},50);value('rotate');"],
 ['rotate small nonzero axis','',"hold({rotate:['1e-20 0 0 30deg','1e-30 0 0 90deg']},{duration:100,fill:'both'},50);value('rotate');"],
 ['rotate tiny angle serialization','',"hold({rotate:['0deg','2e-8deg']},{duration:100,fill:'both'},50);value('rotate');"],
].map(([name,css,source])=>({name:'individual '+name,css,source:prefix+source,expected:[],layout:/box\.style\.|commitStyles/.test(source),browserOnly:name==='individual CSS lower and script upper'||name==='rotate tiny angle serialization',cssMotion:name.startsWith('CSS ')}));
async function main(){
 const browser=await openBrowser(path.join(root,'build','animation-individual-reference'));
 try{
  for(const item of cases){
   await browser.load('<!doctype html><html><head><style>html,body{margin:0;padding:0}#box{width:200px;height:100px;background:white}'+item.css+'</style></head><body><div id="parent"><div id="box"></div></div><div id="outside">Unchanged</div></body></html>');
   item.expected=await browser.evaluate('(()=>{const output=[];function record(value){output.push(String(value));}'+item.source+'return output;})()');
  }
  const file=path.join(root,'tests/fixtures/javascript-animation-layout.json');
  const prior=JSON.parse(fs.readFileSync(file,'utf8')).filter(item=>!item.name.startsWith('individual '));
  fs.writeFileSync(file,JSON.stringify([...prior,...cases],null,2)+'\n');
  process.stdout.write(JSON.stringify(cases.map(({name,expected})=>({name,expected})),null,2)+'\n');
 }finally{await browser.close();}
}
main().catch(error=>{process.stderr.write(String(error.stack||error)+'\n');process.exitCode=1;});
