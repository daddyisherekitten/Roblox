// Native Chromium geometry only. No game text, image data or screenshots are recorded.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { openBrowser } = require('./native-browser.cjs');
const root = path.resolve(__dirname, '..');
const cases = [
  { name: 'inline block before right float', body: '<div id="left" class="atom"></div> <div id="float" class="floater"></div>' },
  { name: 'ordinary block before inline block and float', body: '<div id="before"></div><div id="left" class="atom"></div> <div id="float" class="floater"></div>' },
  { name: 'short text before right float', body: '<span id="text">Short</span><div id="float" class="floater"></div>' },
  { name: 'wrapped text before right float', body: '<span id="text">one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty</span><div id="float" class="floater"></div>' },
  { name: 'float too wide for preceding inline block', css: '.atom{width:60%}.floater{width:60%;margin-right:0}', body: '<div id="left" class="atom"></div><div id="float" class="floater"></div>' },
  { name: 'left float after inline block', css: '.floater{float:left;margin-right:0;margin-left:1%}', body: '<div id="left" class="atom"></div><div id="float" class="floater"></div>' },
  { name: 'clear both after inline block and earlier float', css: '#earlier{float:left;width:10%;height:220px}.floater{clear:both}', body: '<div id="earlier"></div><div id="left" class="atom"></div><div id="float" class="floater"></div>' },
  { name: 'float between inline atoms', css: '.atom{width:20%}.floater{width:50%;margin-right:0}#after{height:50px}', body: '<div id="left" class="atom"></div><div id="float" class="floater"></div><div id="after" class="atom"></div>' },
];
const baseCSS = '*{box-sizing:border-box}html,body{margin:0;padding:0}body{font:20px/20px monospace}#container{width:100%;display:flow-root}.atom{display:inline-block;width:30%;height:160px}.floater{float:right;width:68%;margin-right:1%;padding:10px;border:2px solid;height:90px}#before{height:30px;margin-bottom:10px}';
const geometry = `(() => { const result={}; for(const id of ['container','before','earlier','left','float','after','text']) { const e=document.getElementById(id);if(!e)continue;const r=e.getBoundingClientRect();const s=getComputedStyle(e);result[id]={x:r.x,y:r.y,width:r.width,height:r.height,display:s.display,float:s.cssFloat,marginLeft:s.marginLeft,marginRight:s.marginRight,lineBoxes:[...e.getClientRects()].map(q=>({x:q.x,y:q.y,width:q.width,height:q.height}))};} return result; })()`;
async function main() {
  const browser = await openBrowser(path.join(root, 'build/float-inline-reference'));
  try {
    const result={captured:new Date().toISOString(),userAgent:await browser.evaluate('navigator.userAgent'),scope:'Isolated native Chromium layout measurements; production engine not used.',baseCSS,cases:[],gamePage:[]};
    await browser.load('<!doctype html><style>'+baseCSS+'</style><span id="probe"></span><span id="baseline" style="display:inline-block;width:0;height:0;vertical-align:baseline"></span>');
    const words=[' ',...new Set(cases.map(test=>test.body.replace(/<[^>]*>/g,' ')).join(' ').split(/\s+/).filter(Boolean))];
    result.textMetrics=await browser.evaluate(`(()=>{const probe=document.getElementById('probe');const widths={};probe.style.whiteSpace='pre';for(const word of ${JSON.stringify(words)}){probe.textContent=word;widths[word]=probe.getBoundingClientRect().width;}return {font:getComputedStyle(document.body).font,fontSize:20,lineHeight:20,baseline:document.getElementById('baseline').getBoundingClientRect().y,widths};})()`);
    for(const width of [300,600,1100]) {
      await browser.send('Emulation.setDeviceMetricsOverride',{width,height:1000,deviceScaleFactor:1,mobile:false});
      for(const test of cases) {
        await browser.load('<!doctype html><style>'+baseCSS+(test.css||'')+'</style><div id="container">'+test.body+'</div>');
        result.cases.push({...test,width,geometry:await browser.evaluate(geometry)});
      }
    }
    for(const width of [1100,800]) {
      await browser.send('Emulation.setDeviceMetricsOverride',{width,height:1000,deviceScaleFactor:1,mobile:false});
      await browser.send('Page.navigate',{url:'http://localhost:8000/thebombmaker/index.html'});
      const ready=await browser.evaluate(`(async()=>{for(let i=0;i<100&&document.readyState!=='complete';i++)await new Promise(r=>setTimeout(r,50));await Promise.all([...document.images].map(i=>i.complete?null:new Promise(r=>{i.addEventListener('load',r,{once:true});i.addEventListener('error',r,{once:true});})));await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));return location.href;})()`);
      assert.equal(ready,'http://localhost:8000/thebombmaker/index.html');
      result.gamePage.push({width,geometry:await browser.evaluate(`(()=>{const out={};for(const id of ['top','container','left','right']){const e=document.getElementById(id);const r=e.getBoundingClientRect();const c=getComputedStyle(e);out[id]={x:r.x,y:r.y,width:r.width,height:r.height,display:c.display,float:c.cssFloat};}return {elements:out,images:[...document.images].map(i=>({complete:i.complete,naturalWidth:i.naturalWidth,naturalHeight:i.naturalHeight,renderedWidth:i.width,renderedHeight:i.height}))};})()`)});
    }
    const target=path.join(root,'tests/fixtures/float-inline-browser.json');
    fs.writeFileSync(target,JSON.stringify(result,null,2)+'\n');
    console.log(JSON.stringify({target,cases:result.cases.map(c=>({name:c.name,width:c.width,inlineY:c.geometry.left?.y,floatY:c.geometry.float.y,floatX:c.geometry.float.x})),gamePage:result.gamePage},null,2));
  } finally { await browser.close(); }
}
main().catch(error=>{console.error(error);process.exitCode=1;});
