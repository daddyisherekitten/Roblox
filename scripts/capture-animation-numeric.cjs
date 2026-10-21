// Numeric decoration/typography values, isolated native Chromium references.
const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..');
const prefix="const box=document.getElementById('box');function hold(frames,options,time){const a=box.animate(frames,options);a.finished.catch(()=>{});a.ready.catch(()=>{});a.pause();a.currentTime=time;return a;}function value(name){record(getComputedStyle(box).getPropertyValue(name));}function rect(){const r=box.getBoundingClientRect();record(r.width);record(r.height);} ";
const border='#box{border:4px solid black;outline:3px solid blue;outline-offset:2px}';
const cases=[
 ['border side interpolation',border,"const a=hold({borderTopWidth:['2px','10px'],borderRightWidth:['4px','12px'],borderBottomWidth:['6px','14px'],borderLeftWidth:['8px','16px']},{duration:100,fill:'both'},50);for(const name of ['border-top-width','border-right-width','border-bottom-width','border-left-width'])value(name);rect();a.cancel();value('border-top-width');rect();"],
 ['border width shorthand',border,"const a=hold({borderWidth:['2px 4px 6px 8px','10px 12px 14px 16px']},{duration:100,fill:'both'},50);value('border-width');rect();a.commitStyles();a.cancel();value('border-width');record(box.style.borderTopWidth);"],
 ['border add',border,"const a=hold({borderTopWidth:['2px','6px']},{duration:100,fill:'both',composite:'add'},50);value('border-top-width');rect();a.commitStyles();a.cancel();record(box.style.borderTopWidth);value('border-top-width');"],
 ['border accumulate',border,"hold({borderLeftWidth:['2px','6px']},{duration:100,fill:'both',composite:'accumulate'},50);value('border-left-width');rect();"],
 ['border fractional used and commit',border,"const a=hold({borderTopWidth:['2px','9px']},{duration:100,fill:'both'},50);value('border-top-width');rect();a.commitStyles();a.cancel();record(box.style.borderTopWidth);value('border-top-width');"],
 ['border subpixel minimum',border,"hold({borderTopWidth:['0px','1px']},{duration:100,fill:'both'},50);value('border-top-width');rect();"],
 ['border fractional stop quantization',border,"hold({borderTopWidth:['2.9px','3.9px']},{duration:100,fill:'both'},50);value('border-top-width');"],
 ['border fractional additive base','#box{border:3.7px solid black}',"const a=hold({borderTopWidth:['1.5px','1.5px']},{duration:100,fill:'both',composite:'add'},50);value('border-top-width');a.commitStyles();a.cancel();record(box.style.borderTopWidth);value('border-top-width');"],
 ['border none used width','#box{border:4px none black}',"const a=hold({borderTopWidth:['2px','10px']},{duration:100,fill:'both'},50);value('border-top-width');rect();a.commitStyles();a.cancel();record(box.style.borderTopWidth);value('border-top-width');"],
 ['border invalid negative stop',border,"hold({borderTopWidth:['-4px','10px']},{duration:100,fill:'both'},50);value('border-top-width');"],
 ['border live author equal sample',border,"const a=hold({borderTopWidth:['2px','6px']},{duration:100,fill:'both',composite:'add'},50);value('border-top-width');box.style.borderTopWidth='8px';value('border-top-width');a.cancel();value('border-top-width');"],
 ['border important side independent',border+'#box{border-top-width:5px!important}',"hold({borderTopWidth:['2px','10px'],borderRightWidth:['2px','10px']},{duration:100,fill:'both'},50);value('border-top-width');value('border-right-width');"],
 ['outline width and signed offset',border,"const a=hold({outlineWidth:['2px','10px'],outlineOffset:['-4px','8px']},{duration:100,fill:'both'},50);value('outline-width');value('outline-offset');rect();a.cancel();value('outline-width');value('outline-offset');"],
 ['outline add',border,"const a=hold({outlineWidth:['2px','6px'],outlineOffset:['-4px','8px']},{duration:100,fill:'both',composite:'add'},50);value('outline-width');value('outline-offset');rect();a.commitStyles();a.cancel();record(box.style.outlineWidth);record(box.style.outlineOffset);"],
 ['outline accumulate',border,"hold({outlineWidth:['2px','6px'],outlineOffset:['-4px','8px']},{duration:100,fill:'both',composite:'accumulate'},50);value('outline-width');value('outline-offset');rect();"],
 ['outline fractional used and commit',border,"const a=hold({outlineWidth:['2px','9px']},{duration:100,fill:'both'},50);value('outline-width');a.commitStyles();a.cancel();record(box.style.outlineWidth);value('outline-width');"],
 ['outline none computes zero','#box{outline:3px none black}',"const a=hold({outlineWidth:['2px','10px']},{duration:100,fill:'both'},50);value('outline-width');a.commitStyles();a.cancel();record(box.style.outlineWidth);value('outline-width');"],
 ['CSS border and outline',border+'#box{animation:reference 100s linear -50s both paused}@keyframes reference{from{border-top-width:2px;outline-width:2px;outline-offset:-4px}to{border-top-width:10px;outline-width:10px;outline-offset:8px}}',"value('border-top-width');value('outline-width');value('outline-offset');rect();"],
 ['CSS border independent importance',border+'#box{border-top-width:5px!important;animation:reference 100s linear -50s both paused}@keyframes reference{from{border-top-width:2px;border-right-width:2px}to{border-top-width:10px;border-right-width:10px}}',"value('border-top-width');value('border-right-width');"],
 ['radius separate ellipse','#box{border-radius:4px}',"const a=hold({borderTopLeftRadius:['2px 4px','10px 20px'],borderTopRightRadius:['6px','14px'],borderBottomRightRadius:['10% 20%','30% 40%'],borderBottomLeftRadius:['0px','20px']},{duration:100,fill:'both'},50);for(const name of ['border-top-left-radius','border-top-right-radius','border-bottom-right-radius','border-bottom-left-radius'])value(name);value('border-radius');rect();a.cancel();value('border-radius');"],
 ['radius shorthand ellipse','#box{border-radius:4px}',"const a=hold({borderRadius:['2px 4px 6px 8px / 4px 8px 12px 16px','10px 12px 14px 16px / 20px 24px 28px 32px']},{duration:100,fill:'both'},50);value('border-radius');for(const name of ['border-top-left-radius','border-top-right-radius','border-bottom-right-radius','border-bottom-left-radius'])value(name);a.commitStyles();a.cancel();value('border-radius');record(box.style.borderTopLeftRadius);"],
 ['radius percentage calc','#box{border-radius:4px}',"const a=hold({borderTopLeftRadius:['calc(10% + 2px) 20%','calc(30% + 10px) 40%']},{duration:100,fill:'both'},50);value('border-top-left-radius');a.commitStyles();a.cancel();record(box.style.borderTopLeftRadius);value('border-top-left-radius');"],
 ['radius add','#box{border-top-left-radius:4px 6px}',"const a=hold({borderTopLeftRadius:['2px 4px','10px 20px']},{duration:100,fill:'both',composite:'add'},50);value('border-top-left-radius');a.commitStyles();a.cancel();record(box.style.borderTopLeftRadius);value('border-top-left-radius');"],
 ['radius accumulate','#box{border-top-left-radius:4px 6px}',"hold({borderTopLeftRadius:['2px 4px','10px 20px']},{duration:100,fill:'both',composite:'accumulate'},50);value('border-top-left-radius');"],
 ['radius live author equal sample','#box{border-radius:4px}',"const a=hold({borderTopLeftRadius:['2px','6px']},{duration:100,fill:'both',composite:'add'},50);value('border-top-left-radius');box.style.borderTopLeftRadius='8px';value('border-top-left-radius');a.cancel();value('border-top-left-radius');"],
 ['radius importance independent','#box{border-radius:4px;border-top-left-radius:5px!important}',"hold({borderRadius:['2px','10px']},{duration:100,fill:'both'},50);value('border-top-left-radius');value('border-top-right-radius');"],
 ['radius invalid negative stop','#box{border-radius:4px}',"hold({borderTopLeftRadius:['-4px','10px']},{duration:100,fill:'both'},50);value('border-top-left-radius');"],
 ['radius extrapolated pixel range','#box{border-radius:4px}',"const a=hold({borderTopLeftRadius:['2px 12px','10px 12px']},{duration:100,fill:'both',easing:'cubic-bezier(.1,-1,.9,-1)'},50);value('border-top-left-radius');a.commitStyles();a.cancel();record(box.style.borderTopLeftRadius);value('border-top-left-radius');"],
 ['radius extrapolated percent range','#box{border-radius:4px}',"const a=hold({borderTopLeftRadius:['0% 12px','20% 12px']},{duration:100,fill:'both',easing:'cubic-bezier(.1,-1,.9,-1)'},50);value('border-top-left-radius');a.commitStyles();a.cancel();record(box.style.borderTopLeftRadius);value('border-top-left-radius');"],
 ['CSS radius shorthand','#box{border-radius:4px;animation:reference 100s linear -50s both paused}@keyframes reference{from{border-radius:2px 4px / 4px 8px}to{border-radius:10px 12px / 20px 24px}}',"value('border-radius');value('border-top-left-radius');value('border-top-right-radius');rect();"],
 ['CSS radius add','#box{border-top-left-radius:4px 6px;animation:reference 100s linear -50s both paused;animation-composition:add}@keyframes reference{from{border-top-left-radius:2px 4px}to{border-top-left-radius:10px 20px}}',"value('border-top-left-radius');"],
 ['CSS radius independent importance','#box{border-radius:4px;border-top-left-radius:5px!important;animation:reference 100s linear -50s both paused}@keyframes reference{from{border-radius:2px}to{border-radius:10px}}',"value('border-top-left-radius');value('border-top-right-radius');"],
].map(([name,css,source])=>({name:'numeric '+name,css,source:prefix+source,expected:[],layout:name.includes('border'),cssMotion:name.startsWith('CSS ')}));
async function main(){
 const browser=await openBrowser(path.join(root,'build','animation-numeric-reference'));
 try{
  await browser.send('Emulation.setDeviceMetricsOverride',{width:600,height:800,deviceScaleFactor:1,mobile:false});
  for(const item of cases){
   await browser.load('<!doctype html><html><head><style>html,body{margin:0;padding:0}#box{width:200px;height:100px;background:white}'+item.css+'</style></head><body><div id="parent"><div id="box"></div></div><div id="outside">Unchanged</div></body></html>');
   item.expected=await browser.evaluate('(()=>{const output=[];function record(value){output.push(String(value));}'+item.source+'return output;})()');
  }
  const file=path.join(root,'tests/fixtures/javascript-animation-layout.json');
  const prior=JSON.parse(fs.readFileSync(file,'utf8')).filter(item=>!item.name.startsWith('numeric '));
  fs.writeFileSync(file,JSON.stringify([...prior,...cases],null,2)+'\n');
  console.log(JSON.stringify(cases.map(({name,expected})=>({name,expected})),null,2));
 }finally{await browser.close();}
}
main().catch(error=>{console.error(error.stack||error);process.exitCode=1;});
