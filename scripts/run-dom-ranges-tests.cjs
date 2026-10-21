// PID-scoped actual engine bundle and IAB-readable authored Range reference.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),assert=require('node:assert/strict'),http=require('node:http');
const root=path.resolve(__dirname,'..'),modules=new Map();
function load(id){
 if(modules.has(id))return;
 const base=path.join(root,'src/HTMLEngine',id),file=fs.existsSync(base+'.luau')?base+'.luau':path.join(base,'init.luau');
 let source=fs.readFileSync(file,'utf8');modules.set(id,'');
 source=source.replace(/require\(script((?:\.[A-Za-z_][A-Za-z_0-9]*)+)\)/g,(_,chain)=>{
  const parts=id.split('/');for(const name of chain.slice(1).split('.'))name==='Parent'?parts.pop():parts.push(name);
  const dependency=parts.join('/');load(dependency);return `require(${JSON.stringify(dependency)})`;
 });modules.set(id,source);
}
for(const id of ['HTML/Parser','DOM/Node','JavaScript/DOM','JavaScript/VM','JavaScript/DOMRanges','JavaScript/RangeContents'])load(id);
let bundle=`local Color3={new=function(r,g,b)return {R=r,G=g,B=b}end,fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end}
local Vector2={new=function(x,y)return {X=x,Y=y}end};local UDim2={fromOffset=function(x,y)return {x,y}end}
local Enum={Font={Arial="Arial",SourceSans="SourceSans",Ubuntu="Ubuntu"}}
local loaders,loaded={},{};local function require(id)if loaded[id]==nil then loaded[id]=assert(loaders[id],id)()end;return loaded[id]end\n`;
for(const [id,source]of modules)bundle+=`loaders[${JSON.stringify(id)}]=function()\n${source}\nend\n`;
const fixture=fs.readFileSync(path.join(root,'tests/fixtures/dom-ranges-reference.js'),'utf8');
bundle+='local run=(function()\n'+fs.readFileSync(path.join(root,'tests/JavaScriptDOMRanges.luau'),'utf8')+'\nend)()\n';
bundle+='run(require("HTML/Parser"),require("DOM/Node"),require("JavaScript/DOM"),require("JavaScript/VM"),require("JavaScript/DOMRanges"),require("JavaScript/RangeContents"),[====['+fixture+']====])\n';
const target=path.join(root,'build',`dom-ranges-${process.pid}.luau`);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bundle);
const result=cp.spawnSync(process.env.LUAU_BIN||path.join(root,'build/tools/luau/luau.exe'),[target],{encoding:'utf8',maxBuffer:4*1024*1024});
process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');if(result.error)throw result.error;process.exitCode=result.status??1;
const marker=result.stdout.match(/^RANGE_RESULT (.+)$/m);
if(marker){
 const actual=JSON.parse(marker[1]),output=path.join(root,'build',`dom-ranges-${process.pid}.json`);fs.writeFileSync(output,JSON.stringify(actual,null,2)+'\n');console.log('Range engine fixture:',output);
 const golden=path.join(root,'tests/fixtures/dom-ranges-browser.json');
 if(!process.exitCode&&fs.existsSync(golden)){
  const expected=JSON.parse(fs.readFileSync(golden,'utf8'));
  // Keep the IAB-captured file unchanged. These six exact fields expose
  // Chromium deviations from the current standards, independently of all
  // other boundary, conversion, descriptor, mutation and identity results.
  const differences=[
   // normalize transfers every contiguous Text's boundary into the retained
   // Text, including an empty trailing node, before removing that node.
   // https://dom.spec.whatwg.org/#dom-node-normalize
   ['normalize','trailing',[['#text:word',4],['#text:word',4],true],[['range-root',1],['range-root',1],true]],
   ['normalize','trailingIdentity',true,false],
   // Interface constructor arguments are converted before internally creating
   // the object (and consulting newTarget.prototype). A primitive prototype
   // falls back to that interface's prototype in the newTarget realm.
   // https://webidl.spec.whatwg.org/#interface-object
   // https://webidl.spec.whatwg.org/#internally-create-a-new-object-implementing-the-interface
   ['constructorTargets','order',['endContainer','endOffset','startContainer','startOffset','prototype'],['prototype','endContainer','endOffset','startContainer','startOffset']],
   ['constructorTargets','fallback',true,false],
   // Range and StaticRange inherit AbstractRange. Web IDL links the inherited
   // interface prototype objects and the corresponding interface objects.
   // https://dom.spec.whatwg.org/#interface-range
   // https://dom.spec.whatwg.org/#interface-staticrange
   // https://webidl.spec.whatwg.org/#interface-prototype-object
   ['conversionsAndBrand','prototype',true,false],
   ['conversionsAndBrand','constructorInheritance',true,false]
  ];
  let corrected=0;
  for(const [group,key,standard,browser]of differences){
   if(JSON.stringify(actual[group][key])===JSON.stringify(expected[group][key]))continue;
   assert.deepEqual(actual[group][key],standard,`Unexpected engine difference at ${group}.${key}`);
   assert.deepEqual(expected[group][key],browser,`Unrecorded native difference at ${group}.${key}`);
   expected[group][key]=standard;corrected++;
  }
  assert.deepEqual(actual,expected);
  console.log(corrected?`Native Chromium matches every other Range field; ${corrected} exact documented standard divergences pass their normative outcomes.`:'Native Chromium matches every Range core fixture field.');
 }
}
if(process.argv.includes('--serve')){
 const selected=process.argv.find(value=>value.startsWith('--case='))?.slice(7);
 const server=http.createServer((request,response)=>{
  const url=new URL(request.url,'http://127.0.0.1');
  if(url.pathname==='/'||url.pathname==='/index.html'){
   const source=fs.readFileSync(path.join(root,'tests/fixtures/dom-ranges-reference.js'),'utf8'),name=url.searchParams.get('case')||selected||null;
   const html='<!doctype html><html><head><meta charset="utf-8"><title>DOM Range Core Reference</title></head><body><h1>DOM Range Core Reference</h1><p id="status">Running</p><pre id="result"></pre><script>'+source+'\ntry{const result={};const selected='+JSON.stringify(name)+';for(const name of selected?[selected]:Object.keys(rangeCases)){document.getElementById("status").textContent="Running "+name;result[name]=rangeCases[name]();document.getElementById("result").textContent=JSON.stringify(result,null,2);}document.getElementById("status").textContent="Complete";}catch(error){document.getElementById("status").textContent="Error";document.getElementById("result").textContent=String(error.stack||error);}</script></body></html>';
   response.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'});response.end(html);
  }else{response.writeHead(404);response.end();}
 });server.listen(0,'127.0.0.1',()=>console.log('Range native reference: http://127.0.0.1:'+server.address().port+'/index.html'));
}
