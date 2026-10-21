--!strict
return function(Parser,Runtime,VM,Events,URLRecord,Origin,fixture)
 local outputs={};local events=Events.new(error)
 local document=Parser.parseDocument(fixture.html)
 local realm=Runtime.new(document,{URL=fixture.records[1].documentURL,Events=events,Schedule=function()end,Console=function(_,value)outputs[#outputs+1]=value end})
 local count,maxSteps,standardDeltas=0,0,0
 for _,record in fixture.records do
  local active=realm;local ownEvents
  if record.html then
   ownEvents=Events.new(error);active=Runtime.new(Parser.parseDocument(record.html),{URL=record.documentURL,Events=ownEvents,Schedule=function()end,Console=function(_,value)outputs[#outputs+1]=value end})
  end
  local prior=#outputs
  assert(active:Run('console.log('..record.source..');'),record.name..': '..table.concat(active.Diagnostics,' | '))
  local wanted=record.standardExpected or record.expected
  if record.standardExpected then
   assert(record.name=='DOM href/src/base mutation'and #record.standardDeltas==1 and record.standardDeltas[1].index==11 and record.standardDeltas[1].native=='about:blank'and record.standardDeltas[1].standard==record.documentURL,'Only the captured, documented frozen-base browser delta is normalized')
   standardDeltas+=1
  end
  assert(#outputs==prior+1 and outputs[#outputs]==wanted,record.name..': '..tostring(outputs[#outputs])..' versus '..wanted)
  maxSteps=math.max(maxSteps,active.VM.Steps);assert(active.VM.Steps<=30000,'Existing Runtime step limit retained')
  if record.parse then
   local parsed=record.parse;local ok,address,data=pcall(URLRecord.resolve,parsed.input,parsed.base)
   assert(ok==parsed.ok,record.name..': shared record parse success')
   if ok then assert(address==parsed.href and data.Hostname==parsed.hostname,record.name..': shared HTML/metadata parser result')end
  end
  if ownEvents then active:Destroy();ownEvents:Destroy()end
  count+=1
 end
 assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '));realm:Destroy();events:Destroy()
 local firstOrigin=Origin.fromURL('foo://UPPER.example/a');local secondOrigin=Origin.fromURL('foo://UPPER.example/a')
 assert(type(firstOrigin)=='table'and type(secondOrigin)=='table'and firstOrigin~=secondOrigin,'Identical opaque host strings never merge distinct document origins')
 local fixed={};assert(Origin.ensure(fixed,'foo://Faß.example/a')==Origin.ensure(fixed,'https://changed.example/'),'Document origin stays fixed after URL metadata changes')
 assert(Origin.fromURL('https://UPPER.example:443/a')=='https://upper.example','Special tuple origins still canonicalize case and default port')
 -- Native event entries retain the normal 30k ceiling and reset between clicks.
 local eventDocument=Parser.parseDocument('<!doctype html><button id="click">URL</button>');local eventBus=Events.new(error);local eventOutput={}
 local eventRealm;local eventPeakSteps=0
 eventRealm=Runtime.new(eventDocument,{URL='https://example.test/url',Events=eventBus,Schedule=function()end,Console=function(_,value)eventOutput[#eventOutput+1]=value;eventPeakSteps=math.max(eventPeakSteps,eventRealm.VM.Steps);assert(eventRealm.VM.Steps<=30000,'Native click work stays in its existing owning entry budget')end})
 assert(eventRealm:Run([=[document.getElementById('click').addEventListener('click',()=>{for(let n=0;n<15;n++){const u=new URL('foo://Faß.example:123/a?x=1');u.hostname='a\u007fb';u.searchParams.append('ä','a b');if(u.href!=='foo://a%7Fb:123/a?x=1&%C3%A4=a+b')throw new Error('event opaque parse');}console.log('done');});]=]))
 local node
 -- Locate the native node without depending on parser child indexes.
 local pending={eventDocument};while #pending>0 do local current=table.remove(pending);if current.Attributes and current.Attributes.id=='click'then node=current;break end;for _,child in current.Children or{}do pending[#pending+1]=child end end
 for _=1,5 do eventBus:Emit(node,'click');assert(eventRealm.VM.Steps<30000 and eventOutput[#eventOutput]=='done','Fresh native click URL budget');maxSteps=math.max(maxSteps,eventRealm.VM.Steps)end
 assert(#eventOutput==5 and #eventRealm.Diagnostics==0 and eventPeakSteps>0 and eventPeakSteps<30000,'All native events completed without increasing or accumulating the budget');maxSteps=math.max(maxSteps,eventPeakSteps)
 eventRealm:Destroy();eventBus:Destroy()
 -- Output overflow is still catchable; an instruction abort still ends its
 -- entry and the next ordinary entry can parse the same opaque host again.
 local budgetVM=VM.new({}, {MaxSteps=30000})
 budgetVM:Run([=[try{new URL('foo://'+'ä'.repeat(14000)+'/');throw new Error('missing string bound');}catch(e){if(e.name!=='RangeError')throw e;}]=])
 local budgetOK,budgetError=pcall(budgetVM.Run,budgetVM,[=[for(let i=0;i<10000;i++)new URL('foo://UPPER.example/a');]=])
 assert(not budgetOK and tostring(budgetError):find('instruction budget exceeded',1,true)and budgetVM.Steps==30001,'Repeated URL work must hit the unchanged instruction limit')
 assert(pcall(budgetVM.Run,budgetVM,[=[if(new URL('foo://UPPER.example/a').hostname!=='UPPER.example')throw new Error('budget recovery');]=]),'A new entry recovers after budget abort')
 budgetVM:Destroy()
 -- URL -> query pairs -> owner closures stay alive with a held view, and
 -- disappear once no author/native wrapper owns them. The parser cache is
 -- data-only and must never root a VM or a disposed document.
 local discarded=setmetatable({},{__mode='k'});local plain=setmetatable({},{__mode='k'});local held,heldOwner
 local frame=coroutine.create(function()
  plain[{}]=true
  local vm=VM.new({});vm:Run("var url=new URL('foo://UPPER.example/a?x=1');var params=url.searchParams;")
  local owner=vm.Global.Bindings.url.Value;local params=vm.Global.Bindings.params.Value
  discarded[vm]=true;discarded[owner]=true;discarded[params]=true;vm:Destroy()
  local ev=Events.new(error);local page=Runtime.new(Parser.parseDocument('<!doctype html><body>URL</body>'),{URL='foo://UPPER.example/a',Events=ev,Schedule=function()end})
  assert(page:Run("window.url=new URL('foo://Faß.example/a');window.params=url.searchParams;"));discarded[page]=true;discarded[page.VM]=true;discarded[page.Window.Get('url')]=true;discarded[page.Window.Get('params')]=true
  page:Destroy();ev:Destroy()
  local live=VM.new({});live:Run("var url=new URL('foo://UPPER.example/a?x=1');var params=url.searchParams;")
  held=live.Global.Bindings.params.Value;heldOwner=live.Global.Bindings.url.Value
 end)
 assert(coroutine.resume(frame));assert(coroutine.status(frame)=='dead');frame=nil
 local function pressure()
  for batch=1,2048 do if next(discarded)==nil and next(plain)==nil then return end;local garbage=table.create(2048);for index=1,2048 do garbage[index]={batch,index}end end
 end
 pressure();assert(next(plain)==nil,'URL lifetime proof reached GC within the original bounded pressure allowance')
 assert(next(discarded)==nil,'Shared URL parser and query-owner closures release discarded wrappers/pages/VMs')
 local ownerVM=heldOwner.VMOwner
 ownerVM:Call(ownerVM.Get(held,'append'),{'ä','a b'},held)
 assert(ownerVM.Get(heldOwner,'href')=='foo://UPPER.example/a?x=1&%C3%A4=a+b','Held searchParams keeps original owner/realm and mutation identity')
 local release=coroutine.create(function()discarded[ownerVM]=true;discarded[held]=true;discarded[heldOwner]=true;plain[{}]=true;ownerVM=nil;held=nil;heldOwner=nil end)
 assert(coroutine.resume(release));release=nil;pressure()
 assert(next(plain)==nil and next(discarded)==nil,'Releasing the final URL/searchParams wrappers releases their realm')
 print('URL records: '..(count-standardDeltas)..' exact native + '..standardDeltas..' explicitly documented frozen-base standard delta; opaque-host/ASCII/Unicode/setter/DOM/history/URI, shared parser, 30k event budgets/abort recovery and bounded lifetime checks passed (peak '..maxSteps..' steps)')
end
