// Isolated local Chromium QA; never touches the user's browser profile.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/nightweb-20261019');
async function run(){
 fs.mkdirSync(out,{recursive:true});
 const catalog=JSON.parse(fs.readFileSync(path.join(root,'scripts/data/nightweb-catalog.json'),'utf8'));
 const routes=new Set(catalog.Modules.map(page=>new URL(page.url).pathname));
 const browser=await openBrowser(out),results=[];let probes=0,linkCount=0;
 try{
  await browser.send('Emulation.setDeviceMetricsOverride',{width:1100,height:820,deviceScaleFactor:1,mobile:false});
  await browser.send('Page.addScriptToEvaluateOnNewDocument',{source:"window.__errors=[];addEventListener('error',function(e){__errors.push(e.message||'resource: '+(e.target.src||e.target.href||''));},true);"});
  for(const page of catalog.Modules){
   await browser.send('Page.navigate',{url:page.url});let state;
   for(let i=0;i<80;i++){
    state=await browser.evaluate("({href:location.href,ready:document.readyState,errors:window.__errors||[],images:Array.from(document.images).map(x=>({src:x.getAttribute('src'),loaded:x.complete&&x.naturalWidth>0})),links:Array.from(document.querySelectorAll('a[href]')).map(x=>x.href)})");
    if(state.href===page.url&&state.ready==='complete'&&state.images.every(x=>x.loaded))break;
    await new Promise(resolve=>setTimeout(resolve,50));
   }
   assert.equal(state.href,page.url);assert.equal(state.ready,'complete');assert.deepEqual(state.errors,[],page.name+' runtime errors');assert(state.images.every(x=>x.loaded),page.name+' images');
   for(const href of state.links){const url=new URL(href);assert.equal(url.origin,catalog.origin,page.name+' external link');assert(routes.has(url.pathname),page.name+' missing route '+url.pathname);linkCount++;}
   if(page.interaction?.probe){await browser.evaluate(page.interaction.probe);probes++;}
   assert.deepEqual(await browser.evaluate('window.__errors'),[],page.name+' interaction errors');
   const screenshot=await browser.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});fs.writeFileSync(path.join(out,page.name+'.png'),Buffer.from(screenshot.data,'base64'));
   results.push({name:page.name,route:page.sourcePath,links:state.links.length,images:state.images.length,interaction:!!page.interaction?.probe});
  }
  const adjacency=new Map();for(const page of catalog.Modules){
   const html=fs.readFileSync(path.join(root,'examples/websites',page.sourcePath),'utf8');
   adjacency.set(page.sourcePath,[...html.matchAll(/<a\b[^>]*href=["']([^"']+)["']/gi)].map(m=>new URL(m[1],page.url).pathname));
  }
  const reached=new Set(),queue=[catalog.entry];while(queue.length){const route=queue.shift();if(reached.has(route))continue;reached.add(route);queue.push(...adjacency.get(route));}
  assert.equal(reached.size,routes.size,'Every subpage is reachable from the directory');
  const rootResponse=await fetch(catalog.origin+'/',{redirect:'manual'});assert.equal(rootResponse.status,302);assert.equal(rootResponse.headers.get('location'),catalog.entry);
  for(const old of ['/wiki1/index.html','/ThanksForVisiting/donttalktome.html','/fortuneCookie/index.html','/deep-index/index.html'])assert.equal((await fetch(catalog.origin+old)).status,404,'Old page still served '+old);
  assert(probes>=15,'Every original site needs a tested local interaction');
  const report={date:'2026-10-19',host:'isolated headless Chromium',sites:15,pages:results.length,probes,links:linkCount,allPagesReachable:true,oldPagesHTTP404:true,results};
  fs.writeFileSync(path.join(out,'browser-acceptance.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({pages:results.length,probes,links:linkCount,allPagesReachable:true,oldPagesHTTP404:true}));
 }finally{await browser.close();}
}
run().catch(error=>{console.error(error);process.exitCode=1;});
