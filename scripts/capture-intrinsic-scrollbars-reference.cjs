const fs=require('node:fs'),path=require('node:path'),{openBrowser}=require('./native-browser.cjs');
const caption='ALPHA BETA GAMMA DELTA EPSILON';
const cases=[];
function add(name,style,parentStyle='',widths=['min-content','max-content','fit-content']){cases.push({name,style,parentStyle,widths});}
for(const metric of ['auto','thin','none'])for(const overflow of ['auto','scroll','hidden'])
 for(const gutter of ['auto','stable','stable both-edges'])
  add(`${metric}/${overflow}/${gutter}`,`height:30px;overflow:${overflow};scrollbar-width:${metric};scrollbar-gutter:${gutter}`);
for(const direction of ['ltr','rtl'])for(const mode of ['horizontal-tb','vertical-rl','vertical-lr','sideways-rl','sideways-lr'])
 add(`axes/${mode}/${direction}`,`height:30px;overflow:auto;writing-mode:${mode};direction:${direction}`);
for(const [name,style,parent]of[
 ['auto-height','overflow:auto',''],['auto-height-stable','overflow:hidden;scrollbar-gutter:stable both-edges',''],
 ['percent-definite','height:30%;overflow:auto','height:100px'],['percent-indefinite','height:30%;overflow:auto',''],
 ['max-height','max-height:30px;overflow:auto',''],['min-height','min-height:30px;overflow:auto',''],
 ['edges','height:30px;padding:4px;border:2px solid;overflow:auto',''],
 ['border-box','height:30px;padding:4px;border:2px solid;box-sizing:border-box;overflow:auto',''],
 ['mixed-y','height:30px;overflow-x:hidden;overflow-y:auto',''],['mixed-x','height:30px;overflow-x:auto;overflow-y:hidden',''],
 ['clip-stable','height:30px;overflow:clip;scrollbar-gutter:stable both-edges',''],
 ['visible-stable','height:30px;overflow:visible;scrollbar-gutter:stable both-edges',''],
 ['fixed-width','height:30px;width:100px;overflow:auto',''],
 ['fixed-width-min','height:30px;width:20px;min-width:min-content;overflow:auto',''],
 ['fixed-width-max','height:30px;width:200px;max-width:min-content;overflow:auto',''],
 ['no-bar-start','max-height:80px;overflow:auto;font-size:16px;line-height:16px','']])add(name,style,parent);
const nestedAtomic=[];
for(const display of ['inline-block','inline-flex','inline-grid'])for(const gutter of ['auto','stable both-edges'])
 nestedAtomic.push({name:`nested/${display}/${gutter}`,style:`height:50%;min-height:20px;max-height:35px;padding:4px;border:1px solid;overflow:auto;scrollbar-gutter:${gutter}`,parentStyle:'',atomicStyle:'height:60px',
  content:`<span id=nested style="display:${display};width:60px;height:40px;margin:2px;padding:4px;border:2px solid;vertical-align:top"><span id=percent style="display:inline-block;min-width:0;width:50%;height:50%">ALPHA</span></span>`,widths:['min-content','max-content','fit-content']});
(async()=>{const browser=await openBrowser(path.resolve('build/native-intrinsic-scrollbars'));let result;
 try{await browser.load('<!doctype html><style>body{margin:0;font:16px/20px "Courier New"}#target{display:block}</style>');
 result={captured:'2026-10-10',browser:await browser.evaluate('navigator.userAgent'),caption,references:[
 'https://www.w3.org/TR/2025/WD-css-overflow-3-20251007/#scrollbar-layout',
 'https://www.w3.org/TR/2025/WD-css-overflow-3-20251007/#scrollbar-gutter',
 'https://www.w3.org/TR/2026/WD-css-sizing-3-20260904/#cyclic-percentage-contribution'],
 metricCalibration:'Raw platform widths remain separate. The host reference sets classic scrollbar width/height to Roblox 10/6/0 with an author ::-webkit-scrollbar fixture and resets browser scrollbar-width to auto. This is a sizing calibration, not evidence of an OS overlay adapter.',
 glyphWidth:await browser.evaluate(`(()=>{const c=document.createElement('canvas').getContext('2d');c.font='16px "Courier New"';return c.measureText('A').width})()`),
 cases:await browser.evaluate(`(()=>{const cases=${JSON.stringify(cases)},caption=${JSON.stringify(caption)},out=[];const read=()=>{const e=document.getElementById('target'),a=document.getElementById('atomic'),r=e.getBoundingClientRect(),ar=a.getBoundingClientRect(),s=getComputedStyle(e);return{rect:[r.width,r.height],atomic:[ar.width,ar.height],client:[e.clientWidth,e.clientHeight],scroll:[e.scrollWidth,e.scrollHeight],computed:['width','height','overflow-x','overflow-y','scrollbar-width','scrollbar-gutter','writing-mode','direction'].map(n=>s.getPropertyValue(n))}};for(const c of cases){const states=[];for(const width of c.widths){const html='<div id=owner style="width:140px;'+c.parentStyle+'"><span id=atomic style="display:inline-block;width:'+width+';'+(c.name==='percent-definite'?'height:100px':'')+'"><div id=target style="'+c.style+'">'+(c.name==='no-bar-start'?'<div style="margin:32px">'+caption+'</div>':caption)+'</div></span></div>';document.body.innerHTML=html;const raw=read(),e=document.getElementById('target'),metric=raw.computed[4],hostThickness=metric==='none'?0:metric==='thin'?6:10;document.body.insertAdjacentHTML('beforeend','<style>#target::-webkit-scrollbar{width:'+hostThickness+'px;height:'+hostThickness+'px}</style>');e.style.scrollbarWidth='auto';const host=read();states.push({width,hostThickness,raw,host});}out.push({...c,states});}return out})()`)};
 const dynamic=[140,80,400,140].map(width=>({width,style:'width:fit-content;height:30px;overflow:auto',thickness:10}));
 for(const [width,style,thickness]of[
  [80,'overflow:hidden;scrollbar-gutter:stable both-edges;scrollbar-width:thin',6],
  [140,'overflow:hidden;scrollbar-gutter:auto;scrollbar-width:thin',6],
  [400,'overflow:auto;scrollbar-gutter:stable both-edges;scrollbar-width:none',0],
  [400,'overflow:auto;scrollbar-gutter:stable both-edges;scrollbar-width:thin',6],
  [80,'overflow:auto;scrollbar-gutter:auto;scrollbar-width:thin',6]])
  dynamic.push({width,style:'width:fit-content;height:30px;'+style,thickness});
 result.dynamic=await browser.evaluate(`(()=>{document.body.innerHTML='<div id=owner style="width:140px"><div id=target contenteditable style="width:fit-content;height:30px;overflow:auto">${caption}</div></div>';const owner=document.getElementById('owner'),e=document.getElementById('target'),text=e.firstChild,range=document.createRange(),selection=getSelection();range.setStart(text,1);range.setEnd(text,4);selection.removeAllRanges();selection.addRange(range);const states=[];for(const step of ${JSON.stringify(dynamic)}){owner.style.width=step.width+'px';e.style.cssText=step.style;const rawRect=e.getBoundingClientRect(),raw={rect:[rawRect.width,rawRect.height],client:[e.clientWidth,e.clientHeight],scroll:[e.scrollWidth,e.scrollHeight]};const container=document.createElement('div'),metric=document.createElement('style'),probe=document.createElement('div'),id='host-metric-'+states.length;container.style.width=step.width+'px';probe.id=id;probe.style.cssText=step.style;probe.style.scrollbarWidth='auto';probe.textContent=${JSON.stringify(caption)};metric.textContent='#'+id+'::-webkit-scrollbar{width:'+step.thickness+'px;height:'+step.thickness+'px}';container.append(metric,probe);document.body.append(container);const r=probe.getBoundingClientRect();states.push({...step,raw,rect:[r.width,r.height],client:[probe.clientWidth,probe.clientHeight],scroll:[probe.scrollWidth,probe.scrollHeight],sameElement:e===document.getElementById('target'),sameText:text===e.firstChild,selection:selection.toString(),hostReference:'Independent classic-metric calibration; live editor raw geometry/selection retained separately'});container.remove();}return states})()`);
 result.nestedAtomic=await browser.evaluate(`(()=>{const result=[],read=()=>{const ids=['atomic','target','nested','percent'],boxes={};for(const id of ids){const e=document.getElementById(id),r=e.getBoundingClientRect(),s=getComputedStyle(e);boxes[id]={rect:[r.width,r.height],client:[e.clientWidth,e.clientHeight],scroll:[e.scrollWidth,e.scrollHeight],computed:[s.width,s.height,s.minHeight,s.maxHeight]};}return boxes;};for(const c of ${JSON.stringify(nestedAtomic)}){const states=[];for(const width of c.widths){document.body.innerHTML='<div id=owner style="width:140px;'+c.parentStyle+'"><span id=atomic style="display:inline-block;width:'+width+';'+c.atomicStyle+'"><div id=target style="'+c.style+'">'+c.content+'</div></span></div>';const raw=read();document.body.insertAdjacentHTML('beforeend','<style>#target::-webkit-scrollbar{width:10px;height:10px}</style>');const host=read();states.push({width,raw,host});}result.push({...c,states});}return result})()`);
 }finally{await browser.close();}
 fs.writeFileSync(path.resolve('tests/fixtures/intrinsic-scrollbars-browser.json'),JSON.stringify(result,null,2)+'\n');
 console.log(result.cases.length+' scrollbar cases / '+result.cases.reduce((n,c)=>n+c.states.length,0)+' raw + calibrated states; resize/editor controls preserved');
})().catch(error=>{console.error(error);process.exitCode=1});
