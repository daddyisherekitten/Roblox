--!strict
-- SOURCE reflection test. Full captured snapshots are used;
-- the iframe oracle is exercised with two actual Runtime realms below.
return function(Parser,Runtime,Events,fixture)
 local expectedCases={
  ["src descriptors/default/own-property"]=true,
  ["src raw content attributes"]=true,
  ["src setter conversion and mutation atomicity"]=true,
  ["src borrowed branding and conversion ordering"]=true,
  ["src namespaces and foreign expando"]=true,
  ["src missing setter argument and explicit undefined"]=true,
  ["srcset descriptors/default/own-property"]=true,
  ["srcset raw content attributes"]=true,
  ["srcset setter conversion and mutation atomicity"]=true,
  ["srcset borrowed branding and conversion ordering"]=true,
  ["srcset namespaces and foreign expando"]=true,
  ["srcset missing setter argument and explicit undefined"]=true,
  ["type descriptors/default/own-property"]=true,
  ["type raw content attributes"]=true,
  ["type setter conversion and mutation atomicity"]=true,
  ["type borrowed branding and conversion ordering"]=true,
  ["type namespaces and foreign expando"]=true,
  ["type missing setter argument and explicit undefined"]=true,
  ["sizes descriptors/default/own-property"]=true,
  ["sizes raw content attributes"]=true,
  ["sizes setter conversion and mutation atomicity"]=true,
  ["sizes borrowed branding and conversion ordering"]=true,
  ["sizes namespaces and foreign expando"]=true,
  ["sizes missing setter argument and explicit undefined"]=true,
  ["media descriptors/default/own-property"]=true,
  ["media raw content attributes"]=true,
  ["media setter conversion and mutation atomicity"]=true,
  ["media borrowed branding and conversion ordering"]=true,
  ["media namespaces and foreign expando"]=true,
  ["media missing setter argument and explicit undefined"]=true,
  ["width descriptors/default/own-property"]=true,
  ["width raw content attributes"]=true,
  ["width setter conversion and mutation atomicity"]=true,
  ["width borrowed branding and conversion ordering"]=true,
  ["width namespaces and foreign expando"]=true,
  ["width missing setter argument and explicit undefined"]=true,
  ["height descriptors/default/own-property"]=true,
  ["height raw content attributes"]=true,
  ["height setter conversion and mutation atomicity"]=true,
  ["height borrowed branding and conversion ordering"]=true,
  ["height namespaces and foreign expando"]=true,
  ["height missing setter argument and explicit undefined"]=true,
  ["src live owner base and detached adoption"]=true,
  ["src opaque owner and URL failure scalarization"]=true,
  ["source ordinary/HTML-prefixed/foreign reflected defaults"]=true,
  ["source inherited accessors ignore extra getter arguments"]=true,
  ["source customized builtin CE reactions and conversion ordering"]=true,
  ["source same-origin borrowed getters after realm adoption"]=true,
  ["source mutation observer retains raw attributes and seven keys"]=true,
 }
 local projections={
  ['src raw content attributes']={4,5,7},['srcset raw content attributes']={4,5,7},
  ['sizes missing setter argument and explicit undefined']={0},['media missing setter argument and explicit undefined']={0},
  ['src opaque owner and URL failure scalarization']={2,4},
 }
 local checks,seen,rows,deltas,projectionRows=0,{},0,0,0
 local rawTotals={content=0,setters=0,brands=0,missing=0}
 local function check(value,label)checks+=1;assert(value,label)end
 check(fixture.sources.html.sha256=='49641dedf6fd316141e44a8f0596fab586e455c7cb5946c54b5e19df88ea0a4f','Frozen HTML primary pin')
 check(fixture.sources.webidl.sha256=='473fc33b1fa42562ada39bff6565de914be834e571f9b4459f7532fa86ba01c7','Frozen WebIDL primary pin')
 check(fixture.sources.url.sha256=='0aa47891131f0c2837698caf53453e857256ce156eda02ad6bb4207812943cb5','Frozen URL primary pin')
 local function realm(html,url)
  local events=Events.new(error);local adapter={Alive=true,Calls=0}
  function adapter:Open()self.Calls+=1;error('Standalone SOURCE reflection opened audio IO')end
  function adapter:Destroy()self.Alive=false end
  local runtime=Runtime.new(Parser.parseDocument(html),{URL=url or'https://source.test/root/index.html',Events=events,AudioAdapter=adapter,Schedule=function()end,ControlAdapter={}})
  local function run(action)local ok,message=runtime:Run(action);check(ok,tostring(message));for _=1,16 do runtime:PumpTasks();runtime.EventLoop:Checkpoint()end;check(#runtime.Diagnostics==0,table.concat(runtime.Diagnostics,' | '));check(adapter.Calls==0,'SOURCE reflection starts no audio adapter work')end
  local function finish()runtime:Destroy();events:Destroy();check(not runtime.Alive and not runtime.EventLoop.Alive and not adapter.Alive,'Real DOM realm/adapter cleanup')end
  return runtime,run,finish
 end
 local cross='source same-origin borrowed getters after realm adoption'
 local function audit(runtime,run,case)
  local length,category,key
  key=case.name:match('^(%w+) raw content attributes$');if key then length=if key=='width'or key=='height'then 18 else 9;category='content'end
  key=case.name:match('^(%w+) setter conversion and mutation atomicity$');if key then length=if key=='width'or key=='height'then 20 else 14;category='setters'end
  if case.name:match('^%w+ borrowed branding and conversion ordering$')then length=7;category='brands'end
  if case.name:match('^%w+ missing setter argument and explicit undefined$')then length=3;category='missing'end
  if length then
   run('window.sourceRawRowCount=JSON.parse('..string.format('%q',case.expected)..').length')
   check(runtime.Window.Get('sourceRawRowCount')==length,'Original inner native row count '..case.name);rawTotals[category]+=length
  end
  local allowed=projections[case.name]
  if allowed then
   run('var raw=JSON.parse('..string.format('%q',case.expected)..'),target=JSON.parse('..string.format('%q',case.targetExpected)..');window.sourceRowsSameSize=raw.length===target.length;window.sourceChangedRows=JSON.stringify(raw.map((row,i)=>JSON.stringify(row)!==JSON.stringify(target[i])?i:null).filter(i=>i!==null))')
   check(runtime.Window.Get('sourceRowsSameSize')==true,'Projection preserves complete native row inventory '..case.name)
   check(runtime.Window.Get('sourceChangedRows')=='['..table.concat(allowed,',')..']','Exactly named changed raw/frozen rows '..case.name);projectionRows+=#allowed
  end
 end
 for _,case in fixture.cases do
  check(expectedCases[case.name]and not seen[case.name],'Unexpected/duplicate SOURCE case '..case.name);seen[case.name]=true
  local expected=case.targetExpected or case.expected
  if case.targetExpected then deltas+=1;check(projections[case.name]~=nil and case.targetExpected~=case.expected,'Only five named complete frozen projections')else check(projections[case.name]==nil,'Required frozen projection missing '..case.name)end
  if case.name~=cross then
   local runtime,run,finish=realm(case.html)
   audit(runtime,run,case)
   run('window.sourceError=null;Promise.resolve('..case.action..').then(value=>window.sourceResult=value,error=>window.sourceError=error.name)')
   check(runtime.Window.Get('sourceError')==runtime.VM.Model.Null,'SOURCE action rejection '..case.name)
   local actual=runtime.Window.Get('sourceResult')
   if actual~=expected then print('SOURCE expected',expected);print('SOURCE actual',actual)end
   check(actual==expected,case.name);finish()
  else
   local source,runSource,finishSource=realm(case.html)
   local destination,runDestination,finishDestination=realm('<!doctype html><base href="https://source.test/destination/"><body></body>')
   runSource('window.e=document.createElement("source");window.d=Object.getOwnPropertyDescriptor(HTMLSourceElement.prototype,"src");e.src="clip.webm";window.rows=[{stage:"source",direct:e.src,borrowed:d.get.call(e)}];window.SourceInterface=HTMLSourceElement;')
   for _,key in {'e','d','rows','SourceInterface'}do destination.VM.Global.Bindings[key]={Value=source.Window.Get(key)}end
   runDestination('document.adoptNode(e);rows.push({stage:"adopted",direct:e.src,borrowed:d.get.call(e),parentPrototype:e instanceof SourceInterface});document.querySelector("base").href="https://source.test/changed/";rows.push({stage:"new base",direct:e.src,borrowed:d.get.call(e)});d.set.call(e,"second.webm");rows.push({stage:"borrowed setter",direct:e.src,borrowed:d.get.call(e),raw:e.getAttribute("src")});window.sourceResult=JSON.stringify(rows);')
   local actual=destination.Window.Get('sourceResult');if actual~=expected then print('SOURCE cross expected',expected);print('SOURCE cross actual',actual)end
   check(actual==expected,case.name);finishDestination();finishSource()
  end
  rows+=1
 end
 for name in expectedCases do check(seen[name],'Required SOURCE case missing '..name)end
 check(rows==49 and deltas==5 and projectionRows==10,'Exact SOURCE full-state native/normative inventory')
 check(rawTotals.content==81 and rawTotals.setters==110 and rawTotals.brands==49 and rawTotals.missing==21,'Every original inner native row remains present')
 do
  local c=fixture.sharedOwner;check(c.name=='shared reflected URL getters follow adopted owner'and #c.pairs==6,'Exact shared owner/helper native control')
  local pairs={{'source','src','HTMLSourceElement'},{'video','poster','HTMLVideoElement'},{'img','src','HTMLImageElement'},{'a','href','HTMLAnchorElement'},{'base','href','HTMLBaseElement'},{'blockquote','cite','HTMLQuoteElement'}}
  for index,pair in pairs do check(#c.pairs[index]==3 and c.pairs[index][1]==pair[1]and c.pairs[index][2]==pair[2]and c.pairs[index][3]==pair[3],'Literal shared owner interface/key inventory '..index)end
  local source,runSource,finishSource=realm('<!doctype html><base href="https://source.test/root/"><body></body>',c.sourceURL)
  local destination,runDestination,finishDestination=realm('<!doctype html><base href="https://source.test/destination/"><body></body>',c.destinationURL)
  runSource('window.sharedRows=[];')
  runSource('window.sourceSharedInventory=JSON.stringify(JSON.parse('..string.format('%q',c.expected)..').map(row=>[row.tag,row.key,row.rows.length]))')
  check(source.Window.Get('sourceSharedInventory')=='[["source","src",4],["video","poster",4],["img","src",4],["a","href",4],["base","href",4],["blockquote","cite",4]]','Every original shared owner snapshot retains its six interfaces and four states')
  destination.VM.Global.Bindings.sharedRows={Value=source.Window.Get('sharedRows')}
  for _,pair in c.pairs do
   local tag,key,interface=pair[1],pair[2],pair[3]
   runSource('window.e=document.createElement('..string.format('%q',tag)..');window.d=Object.getOwnPropertyDescriptor('..interface..'.prototype,'..string.format('%q',key)..');window.key='..string.format('%q',key)..';window.rows=[];e[key]="first";rows.push({stage:"source",direct:e[key],borrowed:d.get.call(e)});')
   for _,name in {'e','d','rows','key'}do destination.VM.Global.Bindings[name]={Value=source.Window.Get(name)}end
   runDestination('document.adoptNode(e);rows.push({stage:"adopted",direct:e[key],borrowed:d.get.call(e)});document.querySelector("base").href="https://source.test/changed/";rows.push({stage:"new base",direct:e[key],borrowed:d.get.call(e)});d.set.call(e,"second");rows.push({stage:"borrowed setter",direct:e[key],borrowed:d.get.call(e)});sharedRows.push({tag:'..string.format('%q',tag)..',key:key,rows:rows});document.querySelector("base").href="https://source.test/destination/";window.sourceShared=JSON.stringify(sharedRows)')
  end
  local actual=destination.Window.Get('sourceShared');if actual~=c.expected then print('SOURCE shared expected',c.expected);print('SOURCE shared actual',actual)end
  check(actual==c.expected,'Six borrowed reflected URL accessors keep exact native owner/base semantics');finishDestination();finishSource()
 end
 print('SourceReflection: '..rows..' native cases / '..deltas..' explicit complete frozen projections / '..projectionRows..' changed rows / 24 shared owner states / '..checks..' assertions passed')
end
