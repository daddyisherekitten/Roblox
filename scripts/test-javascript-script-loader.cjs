// Deterministic local HTTP resources compare native HTML script scheduling.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),cp=require('node:child_process'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),fixtures=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-script-loader.json'),'utf8'));
(async()=>{
 const server=http.createServer((req,res)=>{
  const parsed=new URL(req.url,'http://127.0.0.1'),route=parsed.pathname.match(/^\/case\/(\d+)(\/.*)$/),index=Number(route?.[1]||0),pathname=route?.[2]||parsed.pathname,fixture=fixtures[index];
  if(parsed.pathname==='/'){
   res.writeHead(200,{'Content-Type':'text/html;charset=utf-8'});
   res.end(`<!doctype html><title>Native script loader fixtures</title><pre id="results">Running</pre><script>
    const fixtures=${JSON.stringify(fixtures).replace(/</g,'\\u003c')},outcomes=[];
    (async()=>{for(let index=0;index<fixtures.length;index++){const frame=document.createElement('iframe');document.body.append(frame);await new Promise(resolve=>{frame.onload=resolve;frame.src='/case/'+index+'/fixture'});await new Promise(resolve=>setTimeout(resolve,70));const values=frame.contentWindow.values;outcomes.push({name:fixtures[index].name,values,expected:fixtures[index].expected,pass:JSON.stringify(values)===JSON.stringify(fixtures[index].expected)});frame.remove()}document.getElementById('results').textContent=JSON.stringify(outcomes);document.body.dataset.complete='true'})();
   </script>`);return;
  }
  if(pathname==='/fixture'){
   const prefix=`<script>window.values=[];console.log=(...args)=>values.push(args.map(String).join(' '));document.addEventListener('DOMContentLoaded',()=>console.log('dcl',document.readyState));window.addEventListener('load',()=>console.log('load',document.readyState));</script>`;
   // Separate base paths also isolate imports inside modules and import maps.
   res.writeHead(200,{'Content-Type':'text/html;charset=utf-8'});res.end('<!doctype html><html><body>'+prefix+fixture.html+'</body></html>');return;
  }
  const resource=fixture.resources['https://scripts.test'+pathname];
  if(!resource){res.writeHead(404);res.end();return}
  setTimeout(()=>{res.writeHead(200,{'Content-Type':(resource.MIME||'text/javascript')+';charset=utf-8'});res.end(resource.Source)},resource.Delay||0);
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 if(process.argv.includes('--serve')){console.log('Native script loader fixtures: http://127.0.0.1:'+server.address().port+'/');return}
 const browser=process.env.CHROME_BIN||'C:/Program Files/Google/Chrome/Application/chrome.exe';
 const profile=path.join(root,'build','chrome-script-loader-'+process.pid);
 const native=cp.spawn(browser,['--headless','--disable-gpu','--no-first-run','--no-default-browser-check','--user-data-dir='+profile,'--dump-dom','--timeout=10000','--virtual-time-budget=2000','http://127.0.0.1:'+server.address().port+'/'],{stdio:['ignore','pipe','pipe'],windowsHide:true});
 let output='',errors='';native.stdout.on('data',data=>output+=data);native.stderr.on('data',data=>errors+=data);
 const code=await new Promise(resolve=>native.on('close',resolve));await new Promise(resolve=>server.close(resolve));
 assert.equal(code,0,errors);const data=output.match(/<pre id="results">([\s\S]*?)<\/pre>/);assert.ok(data,'No browser results: '+output.slice(-1200));
 const outcomes=JSON.parse(data[1].replace(/&quot;/g,'"').replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&amp;/g,'&'));
 for(const outcome of outcomes)assert.deepEqual(outcome.values,outcome.expected,'Chromium HTML: '+outcome.name);
 console.log('Chromium HTML scripts: '+outcomes.length+' shared ordering cases passed.');
 if(!process.argv.includes('--native-only')){const result=cp.spawnSync(process.execPath,[path.join(root,'scripts/run-html-tests.cjs'),'JavaScriptScriptLoader'],{stdio:'inherit'});process.exitCode=result.status??1}
})().catch(error=>{console.error(error);process.exitCode=1});
