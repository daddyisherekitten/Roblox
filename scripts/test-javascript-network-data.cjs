// Independent functional runner. Does not rewrite the shared HTML test bundle.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),assert=require('node:assert/strict'),nodeVM=require('node:vm');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build','javascript-network-data');
fs.mkdirSync(out,{recursive:true});
const fixtures=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-network-data.json'),'utf8'));
function lua(value){if(value===null)return 'nil';if(typeof value==='string')return JSON.stringify(value).replace(/(\\+)u([0-9a-f]{4})/gi,(_,slashes,n)=>slashes.length%2?slashes+'u{'+n+'}':slashes+'u'+n);if(typeof value==='number'||typeof value==='boolean')return String(value);if(Array.isArray(value))return '{'+value.map(lua).join(',')+'}';return '{'+Object.entries(value).map(([k,v])=>'['+lua(k)+']='+lua(v)).join(',')+'}';}
function bundle(){
 const sources=new Map();
 function add(id){if(sources.has(id))return;sources.set(id,'');const source=fs.readFileSync(path.join(root,'src/HTMLEngine',id+'.luau'),'utf8').replace(/require\(script((?:\.[\w]+)+)\)/g,(_,chain)=>{const parts=id.split('/');for(const item of chain.slice(1).split('.'))item==='Parent'?parts.pop():parts.push(item);const dep=parts.join('/');add(dep);return 'require('+JSON.stringify(dep)+')';});sources.set(id,source);}
 for(const id of ['JavaScript/VM','JavaScript/Promises','JavaScript/AsyncFunctions','JavaScript/EventLoop','JavaScript/HostEvents','JavaScript/NetworkData'])add(id);
 let text='local loaders,loaded={},{}\nlocal function require(id)if loaded[id]==nil then loaded[id]=loaders[id]()end;return loaded[id]end\n';
 for(const [id,source]of sources)text+='loaders['+JSON.stringify(id)+']=function()\n'+source+'\nend\n';
 text+='local run=(function()\n'+fs.readFileSync(path.join(root,'tests/JavaScriptNetworkData.luau'),'utf8')+'\nend)()\nrun(require("JavaScript/VM"),require("JavaScript/Promises"),require("JavaScript/AsyncFunctions"),require("JavaScript/EventLoop"),require("JavaScript/HostEvents"),require("JavaScript/NetworkData"),'+lua(fixtures)+')\n';
 const target=path.join(out,'tests.luau');fs.writeFileSync(target,text);return target;
}
async function nativePromises(){for(const fixture of fixtures.filter(f=>f.group==='promise')){const values=[];const context=nodeVM.createContext({record:v=>values.push(String(v))});nodeVM.runInContext(fixture.source,context);await new Promise(setImmediate);assert.deepEqual(values,fixture.nodeExpected||fixture.expected,fixture.name);}console.log('Native ECMAScript Promise.try/withResolvers traces passed.');}
async function nativeBrowser(){
 const chrome=process.env.CHROME_BIN||'C:/Program Files/Google/Chrome/Application/chrome.exe';if(!fs.existsSync(chrome))throw Error('Set CHROME_BIN to run browser DOM reference cases.');
 const cases=JSON.stringify(fixtures).replace(/</g,'\\u003c');
 const html='<!doctype html><meta charset="utf-8"><body><script>(async()=>{const results=[];for(const fixture of '+cases+'){const frame=document.createElement("iframe");document.body.append(frame);const w=frame.contentWindow;const values=[];w.record=v=>values.push(String(v));w.makeFileList=files=>{const transfer=new w.DataTransfer();for(const file of files)transfer.items.add(file);return transfer.files;};try{const pending=w.eval(fixture.source);if(fixture.wait)await pending;for(let i=0;i<4;i++)await new Promise(resolve=>setTimeout(resolve,0));await fetch("/flush",{cache:"no-store"});results.push({name:fixture.name,values});}catch(e){results.push({name:fixture.name,error:String(e),values});}frame.remove();}document.body.textContent="ASYNC_RESULTS "+JSON.stringify(results);})();</script>';
 const file=path.join(out,'reference.html');fs.writeFileSync(file,html);
 const profile=path.join(out,'chrome-'+Date.now());
 const server=require('node:http').createServer((req,res)=>{if(req.url==='/flush'){setTimeout(()=>res.end('ready'),30);return;}res.setHeader('Content-Type','text/html; charset=utf-8');res.end(html);});await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 let result;try{result=await new Promise((resolve,reject)=>cp.execFile(chrome,['--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check','--disable-background-networking','--disable-extensions','--user-data-dir='+profile,'--virtual-time-budget=10000','--dump-dom','http://127.0.0.1:'+server.address().port+'/reference.html'],{encoding:'utf8',windowsHide:true,timeout:30000,maxBuffer:4*1024*1024},(error,stdout,stderr)=>error?reject(error):resolve({stdout,stderr})));}finally{await new Promise(resolve=>server.close(resolve));}
 fs.writeFileSync(path.join(out,'browser-output.html'),result.stdout||'');
 if(result.error)throw result.error;
 const match=(result.stdout||'').match(/<body>ASYNC_RESULTS ([\s\S]*?)<\/body>/);assert(match,'Chromium did not return the reference result: '+(result.stderr||''));
 const values=JSON.parse(match[1].replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>'));
 fs.writeFileSync(path.join(out,'browser-results.json'),JSON.stringify(values,null,2));
 for(let i=0;i<fixtures.length;i++){assert.equal(values[i].error,undefined,fixtures[i].name);assert.deepEqual(values[i].values,fixtures[i].browserExpected||fixtures[i].expected,fixtures[i].name);}
 console.log('Chromium DOM/ECMAScript reference: '+fixtures.length+' reference traces passed ('+fixtures.filter(f=>f.browserExpected).length+' documented standard divergences).' );
}
async function main(){const args=new Set(process.argv.slice(2));if(!args.has('--luau-only')){await nativeBrowser();}if(!args.has('--native-only')){const target=bundle();const result=cp.spawnSync(process.env.LUAU_BIN||path.join(root,'build/tools/luau/luau.exe'),[target],{encoding:'utf8',timeout:30000,maxBuffer:4*1024*1024});fs.writeFileSync(path.join(out,'luau.log'),(result.stdout||'')+(result.stderr||''));process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');if(result.error)throw result.error;process.exitCode=result.status||0;}}
main().catch(error=>{console.error(error);process.exitCode=1;});
