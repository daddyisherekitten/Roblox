const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),crypto=require('node:crypto'),assert=require('node:assert/strict');
// Exercise the published page modules without the original game installation.
// Graphic acquisition and navigation are explicit test boundaries; the HTML,
// scripts, CSS, parser, JavaScript runtime and event handlers remain real.
const root=path.resolve(__dirname,'..'),base='http://localhost:8000';
const args={};for(let i=2;i<process.argv.length;i+=2){assert.ok(process.argv[i].startsWith('--')&&process.argv[i+1],'Expected --name value');args[process.argv[i].slice(2)]=process.argv[i+1];}
const outputRoot=path.resolve(args.output||path.join(root,'build/wttg2-runtime-tests'));fs.mkdirSync(outputRoot,{recursive:true});
const catalog=JSON.parse(fs.readFileSync(path.resolve(args.catalog||path.join(root,'scripts/data/wttg2-full-catalog.json')),'utf8'));
const browserRoot=path.resolve(args.websites||path.join(root,'examples/websites')),modulesRoot=path.resolve(args.modules||path.join(root,'src/HTMLEngine/Websites'));
const configText=fs.readFileSync(path.join(browserRoot,'wttg2-config.js'),'utf8');
const config=JSON.parse(configText.replace(/^window\.WTTG2_PORT\s*=\s*/,'').replace(/;\s*$/,''));
const pages=config.pages,sites=config.sites;
const full=catalog.selectedCounts.realSites===60;
assert.equal(catalog.selectedCounts.realSites,full?60:15);assert.equal(catalog.selectedCounts.deadLinks,full?30:10);assert.equal(catalog.Modules.length,full?175:35);
const wikiCases=config.wikis.map(w=>{const members=w.siteNames.map(name=>sites.find(s=>s.name===name));return{path:w.path,sites:members,labelsJSON:JSON.stringify(members.map(s=>s.title))};});
if(full){assert.equal(wikiCases.length,3);assert.ok(wikiCases.every(w=>w.sites.length===32));assert.equal(new Set(wikiCases.flatMap(w=>w.sites.filter(s=>!s.dead&&!s.directory).map(s=>s.name))).size,60);assert.equal(new Set(wikiCases.flatMap(w=>w.sites.filter(s=>s.dead).map(s=>s.name))).size,30);}
assert.deepEqual(sites.map(s=>s.title),sites.map(s=>s.title).sort((a,b)=>a.localeCompare(b,'en',{sensitivity:'variant'})),'Wiki entries stay alphabetically sorted');
const hostSource=fs.readFileSync(path.join(root,'scripts/wttg2-host-bridge.js'),'utf8'),compatSource=fs.readFileSync(path.join(root,'scripts/wttg2-jquery-compat.js'),'utf8');
for(const[source,label]of[[hostSource,'host'],[compatSource,'compat']])assert.ok(Buffer.byteLength(source)<65536,label+' fits script budget');
const cases=catalog.Modules.map(mod=>{const html=fs.readFileSync(path.join(browserRoot,mod.sourcePath),'utf8');const links=[...html.matchAll(/\b(onclick)\s*=\s*"LinkClick\('([^']+)'\)"/gi)].map(m=>m[2]);return{path:mod.sourcePath,links:[...new Set(links)]};});
const productionFiles=[];
for(const item of [...catalog.Modules,{files:catalog.supportFiles||[]}])for(const file of item.files){const bytes=fs.readFileSync(path.join(root,file.path));assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),file.sha256,'Published file hash '+file.path);productionFiles.push(file);}
const files=new Map();
function read(id){if(files.has(id))return;files.set(id,'');const base=path.join(root,'src/HTMLEngine',id);const file=fs.existsSync(base+'.luau')?base+'.luau':path.join(base,'init.luau');let source=fs.readFileSync(file,'utf8');source=source.replace(/require\(script((?:\.[A-Za-z_][A-Za-z_0-9]*)+)\)/g,(_,chain)=>{const parts=id.split('/');for(const item of chain.slice(1).split('.'))item==='Parent'?parts.pop():parts.push(item);const next=parts.join('/');read(next);return'require('+JSON.stringify(next)+')'});files.set(id,source);}
for(const id of ['HTML/Parser','JavaScript/Runtime','Input/Events','DOM/Node','Controls/State','Controls/FormModel'])read(id);
function literal(value){let eq='====';while(value.includes(']'+eq+']'))eq+='=';return'['+eq+'['+value+']'+eq+']';}
function lua(value){if(value===null)return'nil';if(typeof value==='string')return literal(value);if(typeof value==='boolean'||typeof value==='number')return String(value);if(Array.isArray(value))return'{'+value.map(lua).join(',')+'}';return'{'+Object.entries(value).map(([key,value])=>'[ '+literal(key)+' ]='+lua(value)).join(',')+'}';}
const sharedHost=fs.readFileSync(path.join(modulesRoot,'Assets/HostScripts.luau'),'utf8');
const casesLua='{'+cases.map(item=>{
 const mod=catalog.Modules.find(m=>m.sourcePath===item.path);assert.ok(mod,item.path);
 const modulePath=path.join(modulesRoot,mod.name);
 const moduleSource=fs.readFileSync(path.join(modulePath,'init.luau'),'utf8');
 const htmlSource=fs.readFileSync(path.join(modulePath,'HTML.luau'),'utf8');
 const cssSource=fs.readFileSync(path.join(modulePath,'CSS.luau'),'utf8');
 return'{path='+lua(item.path)+',links='+lua(item.links)+',Website=(function()\nlocal script={HTML="HTML",CSS="CSS",Parent={Assets={ImageCatalog="ImageCatalog",HostScripts="HostScripts"}}}\nlocal function require(child)if child=="HTML"then return(function()\n'+htmlSource+'\nend)()elseif child=="CSS"then return(function()\n'+cssSource+'\nend)()elseif child=="HostScripts"then return SharedHostScripts elseif child=="ImageCatalog"then return{forPage=function()return{}end}else error("Unexpected page dependency "..tostring(child))end end\n'+moduleSource+'\nend)()}';
}).join(',')+'}';
const runner=fs.readFileSync(path.join(root,'scripts/run-html-tests.cjs'),'utf8');const types=runner.slice(runner.indexOf('local colorMeta ='),runner.indexOf('local loaders, loaded = {}, {}'));
let code='local utf8=setmetatable({graphemes=function(s)local i=0;return function()i+=1;if i<=#s then return i,i end end end},{__index=utf8})\n'+types;
code+='local loaders,loaded={},{}\nlocal function require(id)if loaded[id]~=nil then return loaded[id]end;local value=assert(loaders[id],id)();loaded[id]=value;return value end\n';
for(const[id,source]of files)code+='loaders[ '+literal(id)+' ]=function()\n'+source+'\nend\n';
code+=`local Parser,Runtime,Events,Node=require('HTML/Parser'),require('JavaScript/Runtime'),require('Input/Events'),require('DOM/Node')
local State,FormModel=require('Controls/State'),require('Controls/FormModel')
local SharedHostScripts=(function()
${sharedHost}
end)()
local cases=${casesLua}
local expectedPaths=${lua(pages)}
local wikiCases=${lua(wikiCases)}
local pageCount,linkCount,hookCount,wikiCount,puzzleCount,serviceCount=0,0,0,0,0,0
local function expected(target,from)
 local full=target
 if full:sub(1,1)~='/'then full=assert(from:match('^(.*)/'))..'/'..full end
 for _,path in expectedPaths do if path:lower()==full:lower()then return 'http://localhost:8000'..path end end
 error('Unregistered expected path '..full)
end
for _,case in cases do
 local clock=0;local moves={};local messages={};local events=Events.new(error)
 local website=case.Website
 local doc=Parser.parseDocument(website.HTML)
 local controls,byNode={},{};local pending={doc}
 while #pending>0 do local node=table.remove(pending);if node.Kind=='Element'and(node.Name=='input'or node.Name=='textarea'or node.Name=='select'or node.Name=='button')then local c=State.create(node);table.insert(controls,c);byNode[node]=c end;for _,child in node.Children or{}do table.insert(pending,child)end end
 local model=FormModel.new(doc,controls,events,function()end)
 local adapter={Events=events,ResolveControl=function(node)return byNode[node]end,SetControlValue=function(node,value)model:SetValue(assert(byNode[node]),value,false)end,SetControlChecked=function(node,value)model:SetChecked(assert(byNode[node]),value,false)end,FocusControl=function()end}
 local scriptSources=website.Options.JavaScriptServices.ScriptSources
 assert(scriptSources['http://localhost:8000/wttg2-host-bridge.js']==${literal(hostSource)},'Stale published host bridge')
 assert(scriptSources['http://localhost:8000/jQuery.min.js']==nil or scriptSources['http://localhost:8000/jQuery.min.js']==${literal(compatSource)},'Stale published jQuery compatibility adapter')
 local realm=Runtime.new(doc,{URL='http://localhost:8000'..case.path,Events=events,Clock=function()return clock end,Schedule=function()end,
  ScriptSources=scriptSources,Stylesheets=website.Stylesheets,Console=function(_,message)table.insert(messages,message)end,
  Navigate=function(request)table.insert(moves,request.URL)end,ControlAdapter=adapter,
  GetControl=function(node,key)local c=byNode[node];return c and(if key=='checked'then c.Checked else c.Value)end,
  SetControl=function(node,key,value)local c=assert(byNode[node]);if key=='checked'then model:SetChecked(c,value)else model:SetValue(c,value)end end,
  Click=function(node)events:Emit(node,'click')end})
 realm:Start();for _=1,100 do clock+=0.01;realm:PumpTasks();realm.EventLoop:Checkpoint()end
 if case.path=='/wiki1/index.html'then print('WIKI_STEPS '..realm.VM.Steps)end
 if #realm.Diagnostics>0 then print('FAILED '..case.path..' ScriptsRun='..realm.ScriptsRun..' Steps='..realm.VM.Steps)end
 assert(#realm.Diagnostics==0,case.path..': '..table.concat(realm.Diagnostics,'\\n'))
 local function run(source)realm:Run(source);assert(#realm.Diagnostics==0,case.path..': '..table.concat(realm.Diagnostics,'\\n'))end
 run([[var before=document.documentElement.getAttribute('style');LinkHover();LinkOut();if(document.documentElement.getAttribute('style')!==before)throw new Error('cursor hooks mutated document styles');]])
 for _,href in case.links do
  local clickable=Node.findElement(doc,function(node)return node.Attributes and node.Attributes.onclick=="LinkClick('"..href.."')"end)
  assert(clickable,case.path..' original onclick source missing: '..href)
  local before=#moves;events:Emit(clickable,'click')
  assert(#realm.Diagnostics==0,case.path..': '..table.concat(realm.Diagnostics,'\\n'))
  assert(#moves==before+1,case.path..' link does not navigate: '..href)
  assert(moves[#moves]==expected(href,case.path),case.path..' route mismatch: '..href..' -> '..tostring(moves[#moves]));linkCount+=1
 end
 local before=#moves
 run([[SiteClick('https://unregistered.invalid/');LinkClick('missing-page.html');SiteClick('javascript:alert(1)');]])
 assert(#moves==before,'Unknown/external targets must stay blocked')
 local wikiCase;for _,item in wikiCases do if item.path==case.path then wikiCase=item end end
 if wikiCase then
  run([[var wiki=document.getElementById('wikiLinks');console.log(JSON.stringify({wiki:wiki.querySelectorAll('li').length,links:wiki.querySelectorAll('a').length}));WTTG2Host.buildWiki();console.log(JSON.stringify({again:wiki.querySelectorAll('li').length}));]])
  local count=#wikiCase.sites
  assert(messages[1]=='{"wiki":'..count..',"links":'..count..'}',table.concat(messages,' | '));assert(messages[2]=='{"again":'..count..'}','Wiki building is idempotent')
  run([[var labels=[];var anchors=wiki.querySelectorAll('a');for(var i=0;i<anchors.length;i++)labels.push(anchors[i].textContent);console.log(JSON.stringify(labels));]])
  assert(messages[3]==wikiCase.labelsJSON,'Visible Wiki titles follow the original alphabetically sorted list')
  for _,site in wikiCase.sites do
   local clickable=Node.findElement(doc,function(node)return node.Attributes and node.Attributes.onclick=="SiteClick('http://"..site.host.."')"end)
   assert(clickable,'Wiki onclick source missing: '..site.host)
   local before=#moves;events:Emit(clickable,'click')
   assert(#realm.Diagnostics==0,case.path..': '..table.concat(realm.Diagnostics,'\\n'))
   assert(#moves==before+1,'Wiki entry must navigate: '..site.host)
   if site.dead then assert(moves[#moves]:find(${lua(base+config.unavailablePath+'?site=')},1,true)==1,'Dead link must navigate to the original error page')
   else assert(moves[#moves]=='http://localhost:8000'..site.path,'Real Wiki alias route')end
   linkCount+=1
  end
  wikiCount+=1
 end
 if case.path=='/wiki1/index.html'then
  run([[var hooks=[];document.addEventListener('wttg2:hook',function(event){hooks.push(event.detail.name)});PlainKeyShow();FileKeyShow();HotSpotHit();console.log(hooks.join(','));]])
  assert(messages[#messages]=='PlainKeyShow,FileKeyShow,HotSpotHit','Original hook entrypoints dispatch notifications without fictional keys');hookCount+=3
  run([[var markers=document.createElement('div');markers.innerHTML='<span class="PTAG"></span><span class="CPTAG"></span><span class="CFTAG"></span><span class="hotZone"></span>';document.body.appendChild(markers);PickPTag(1,'probe');PickCPTag();PickCFTag();PickHotSpot();if(document.querySelector('.CPTAG').getAttribute('onclick')!=='PlainKeyShow()')throw new Error('CPTAG');if(document.querySelector('.CFTAG').getAttribute('onclick')!=='FileKeyShow()')throw new Error('CFTAG');if(document.querySelector('.hotZone').getAttribute('onclick')!=='HotSpotHit()')throw new Error('hotspot');]])
 end
 if case.path=='/ForgiveMe/index.html'then
  assert(Node.textContent(assert(Node.findById(doc,'confession'))):find('unavailable in this local archive',1,true),'Offline original confession GET response')
  run([[document.getElementById('doForward').click();document.getElementById('doBack').click();]])
  serviceCount+=1
 elseif case.path=='/ForgiveMe/confess.html'then
  run([[document.getElementById('conf').value='local test';document.getElementById('add').click();]])
  for _=1,10 do clock+=0.01;realm:PumpTasks();realm.EventLoop:Checkpoint()end
  assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))
  assert(Node.textContent(assert(Node.findById(doc,'returnMessage'))):find('does not submit confessions',1,true),'Offline POST must answer without sending visitor content')
  serviceCount+=1
 elseif case.path=='/thethree/index.html'then
  run([[var puzzleEvents=[];document.addEventListener('wttg2:hook',function(event){puzzleEvents.push(event.detail.name)});var wrong=data[0].order[0]%3+1;SolvePuzzle(document.querySelector('.puzzle-spot[data-step="1"][data-pick="'+wrong+'"]'));if(data.some(function(step){return step.current!==0}))throw new Error('puzzle reset');]])
  for step=0,5 do for pick=0,2 do
   run(string.format([[SolvePuzzle(document.querySelector('.puzzle-spot[data-step="%d"][data-pick="'+data[%d].order[%d]+'"]'));]],step+1,step,pick))
  end end
  run([[if(!puzzleEvents.includes('puzzleClickedWrong')||!puzzleEvents.includes('puzzleSolved'))throw new Error('missing puzzle hook');var result=document.getElementById('wiki3');if(result.textContent.indexOf('/wiki3/index.html')<0)throw new Error('wiki3 result');result.click();]])
  assert(moves[#moves]=='http://localhost:8000/wiki3/index.html','Original puzzle must reveal a navigable WikiIII route');puzzleCount+=1
 end
 realm:Destroy();events:Destroy();pageCount+=1
end
print('BRIDGE_RESULT pages='..pageCount..' routes='..linkCount..' hooks='..hookCount..' wikis='..wikiCount..' puzzles='..puzzleCount..' offlineServices='..serviceCount..' diagnostics=0')
`;
const bundlePath=path.join(outputRoot,'runtime-tests.luau');fs.writeFileSync(bundlePath,code);
const result=cp.spawnSync(process.env.LUAU_BIN||path.join(root,'build/tools/luau/luau.exe'),[bundlePath],{cwd:root,encoding:'utf8',timeout:120000,windowsHide:true,maxBuffer:2*1024*1024});
const report={scope:'Actual published module init/HTML/Stylesheets/ScriptSources with Parser/Runtime/ScriptLoader and actual onclick event handlers; only nonvisual ImageCatalog.forPage acquisition stubbed, mock navigation capture, no network/game/desktop host.',defaultBudget:true,productionFiles,pages:cases.length,engineModules:files.size,adapterHashes:{host:crypto.createHash('sha256').update(hostSource).digest('hex'),compat:crypto.createHash('sha256').update(compatSource).digest('hex')},status:result.status,error:result.error?String(result.error):null,stdout:result.stdout,stderr:result.stderr};
fs.writeFileSync(path.join(outputRoot,'results.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({...report,productionFiles:report.productionFiles.length},null,2));assert.equal(result.status,0);
