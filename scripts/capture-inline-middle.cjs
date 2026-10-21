// Isolated Chromium geometry only: no game text, image data, or screenshots.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { openBrowser } = require('./native-browser.cjs');
const root = path.resolve(__dirname, '..');
const folder = path.join(root, 'build/middle-columns-20261019');
const css = '*{box-sizing:border-box}html,body{margin:0;padding:0}body{font:16px/16px Arial}#container{width:100%;padding-bottom:25px}.column{display:inline-block;vertical-align:middle;width:30%;padding:10px}.left{float:left;width:48%}.right{float:right;width:48%}.clear{clear:both;height:25px}.row{padding-bottom:25px;margin-bottom:40px}';
const fixed = heights => heights.map((height, i) => '<div class="column" id="column' + (i + 1) + '" style="height:' + height + 'px"></div>').join(' ');
const floatedRows = (index, rows, leftHeight, rightHeight) => '<div class="column" id="column' + index + '">' + Array.from({length:rows}, (_, row) => '<div class="row" id="row' + index + '_' + row + '"><div class="left" style="height:' + leftHeight + 'px"></div><div class="right" style="height:' + rightHeight + 'px"></div><div class="clear"></div></div>').join('') + '</div>';
const cases = [
  {name:'three middle blocks 80 160 240', body:fixed([80,160,240])},
  {name:'three middle blocks 240 80 160', body:fixed([240,80,160])},
  {name:'middle with one top block', body:fixed([80,160,240]), css:'#column1{vertical-align:top}'},
  {name:'middle with one bottom block', body:fixed([80,160,240]), css:'#column3{vertical-align:bottom}'},
  {name:'text top blocks', body:fixed([80,160,240]), css:'.column{vertical-align:text-top}'},
  {name:'text bottom blocks', body:fixed([80,160,240]), css:'.column{vertical-align:text-bottom}'},
  {name:'positive length blocks', body:fixed([80,160,240]), css:'.column{vertical-align:12px}'},
  {name:'negative length blocks', body:fixed([80,160,240]), css:'.column{vertical-align:-8px}'},
  {name:'nested floats and clear rows', body:floatedRows(1,1,40,40)+' '+floatedRows(2,2,80,160)+' '+floatedRows(3,2,160,80)},
  {name:'nested wrapping floats and clear rows', body:floatedRows(1,1,40,40)+' '+floatedRows(2,2,80,160)+' '+floatedRows(3,2,160,80), css:'.left,.right{width:80px}'},
  {name:'wrapped middle blocks', body:fixed([80,160,240]), css:'.column{width:42%}'},
  {name:'baseline blocks contrast', body:fixed([80,160,240]), css:'.column{vertical-align:baseline}'},
];
const geometry = `(() => {
  const rect=e=>{const r=e.getBoundingClientRect();return{x:r.x,y:r.y,width:r.width,height:r.height}};
  const measure=e=>{const s=getComputedStyle(e);return{...rect(e),display:s.display,float:s.cssFloat,verticalAlign:s.verticalAlign,lineHeight:s.lineHeight,paddingTop:s.paddingTop,paddingBottom:s.paddingBottom,marginTop:s.marginTop,marginBottom:s.marginBottom}};
  return{viewport:{width:innerWidth,height:innerHeight},document:{scrollWidth:document.documentElement.scrollWidth,scrollHeight:document.documentElement.scrollHeight},container:measure(document.getElementById('container')),columns:[...document.querySelectorAll('.column')].map((e,index)=>({index:index+1,...measure(e),children:[...e.children].map((c,childIndex)=>({index:childIndex+1,...measure(c),children:[...c.children].map((d,n)=>({index:n+1,...measure(d)}))}))}))};
})()`;
const gameGeometry = `(() => {
  const rect=e=>{const r=e.getBoundingClientRect();return{x:r.x,y:r.y,width:r.width,height:r.height}};
  const measure=e=>{if(!e)return null;const s=getComputedStyle(e);return{...rect(e),display:s.display,float:s.cssFloat,verticalAlign:s.verticalAlign,lineHeight:s.lineHeight,paddingTop:s.paddingTop,paddingBottom:s.paddingBottom,marginTop:s.marginTop,marginBottom:s.marginBottom}};
  return{viewport:{width:innerWidth,height:innerHeight},document:{scrollWidth:document.documentElement.scrollWidth,scrollHeight:document.documentElement.scrollHeight},nav:measure(document.getElementById('nav')),container:measure(document.getElementById('container')),columns:[...document.querySelectorAll('#container>.w33')].map((e,index)=>({index:index+1,...measure(e),children:[...e.children].map((c,childIndex)=>({index:childIndex+1,tag:c.localName,...measure(c),children:[...c.children].filter(d=>d.localName==='div'||d.localName==='img'||d.localName==='a').map((d,n)=>({index:n+1,tag:d.localName,...measure(d)}))}))})),images:[...document.images].map((e,index)=>({index:index+1,complete:e.complete,naturalWidth:e.naturalWidth,naturalHeight:e.naturalHeight,...rect(e)}))};
})()`;
async function main() {
  fs.mkdirSync(folder,{recursive:true});
  const browser=await openBrowser(folder);
  try {
    const userAgent=await browser.evaluate('navigator.userAgent');
    await browser.load('<!doctype html><style>'+css+'</style><span id="font-text">Hg</span><i id="font-baseline" style="display:inline-block;width:0;height:0;vertical-align:baseline"></i><i id="font-ex" style="position:absolute;width:1ex;height:1ex"></i>');
    const textMetrics=await browser.evaluate(`(()=>{const canvas=document.createElement('canvas'),ctx=canvas.getContext('2d');ctx.font='16px Arial';const m=ctx.measureText('Hg'),b=document.getElementById('font-baseline').getBoundingClientRect(),t=document.getElementById('font-text').getBoundingClientRect(),ex=document.getElementById('font-ex').getBoundingClientRect();return{font:'16px Arial',fontSize:16,lineHeight:16,baseline:b.y,inlineTextTop:t.y,inlineTextHeight:t.height,xHeight:ex.height,spaceWidth:ctx.measureText(' ').width,fontBoundingBoxAscent:m.fontBoundingBoxAscent,fontBoundingBoxDescent:m.fontBoundingBoxDescent,actualBoundingBoxAscent:m.actualBoundingBoxAscent,actualBoundingBoxDescent:m.actualBoundingBoxDescent}})()`);
    const fixture={captured:new Date().toISOString(),userAgent,scope:'Isolated native Chromium neutral geometry reference.',baseCSS:css,textMetrics,cases:[]};
    for(const width of [320,600,1100]) {
      await browser.send('Emulation.setDeviceMetricsOverride',{width,height:1000,deviceScaleFactor:1,mobile:false});
      for(const test of cases) {
        await browser.load('<!doctype html><style>'+css+(test.css||'')+'</style><div id="container">'+test.body+'</div>');
        fixture.cases.push({...test,width,geometry:await browser.evaluate(geometry)});
      }
    }
    const result={captured:fixture.captured,userAgent,scope:'Structural geometry and image dimensions only; no image pixels or game body text.',route:'/mutilation/index.html',cases:[]};
    for(const width of [800,1100,1600]) {
      await browser.send('Emulation.setDeviceMetricsOverride',{width,height:1000,deviceScaleFactor:1,mobile:false});
      await browser.send('Page.navigate',{url:'http://localhost:8000/mutilation/index.html'});
      const ready=await browser.evaluate(`(async()=>{for(let n=0;n<100&&(location.pathname!=='/mutilation/index.html'||document.readyState!=='complete');n++)await new Promise(r=>setTimeout(r,50));await Promise.all([...document.images].map(e=>e.complete?null:new Promise(r=>{e.addEventListener('load',r,{once:true});e.addEventListener('error',r,{once:true});})));await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));return location.pathname})()`);
      assert.equal(ready,'/mutilation/index.html');
      result.cases.push({width,geometry:await browser.evaluate(gameGeometry)});
    }
    fs.writeFileSync(path.join(root,'tests/fixtures/inline-middle-browser.json'),JSON.stringify(fixture,null,2)+'\n');
    fs.writeFileSync(path.join(folder,'browser-geometry.json'),JSON.stringify(result,null,2)+'\n');
    console.log(JSON.stringify({fixtureCases:fixture.cases.length,game:result.cases.map(test=>({width:test.width,container:test.geometry.container,columns:test.geometry.columns.map(c=>({index:c.index,x:c.x,y:c.y,width:c.width,height:c.height})),imagesLoaded:test.geometry.images.every(e=>e.complete&&e.naturalWidth>0)}))},null,2));
  } finally { await browser.close(); }
}
main().catch(error=>{console.error(error);process.exitCode=1});
