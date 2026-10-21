--!strict
return function(Parser,Runtime,Events,Node,reference,candidate)
 local checks,failures,cases=0,{},0
 local function check(value,label,actual)
  checks+=1;if not value then table.insert(failures,label..' actual='..tostring(actual))end
 end
 local function fixture(html,url,hold,extra)
  local requests,handles={},{};local adapter={Alive=true};local runtime;local events=Events.new(error)
  function adapter:Open(node,notify)
   local h={Alive=true,Notify=notify,Position=0,Settings={}}
   function h:Set(key,value)self.Settings[key]=value;if key=='currentTime'then self.Position=value end end
   function h:Select()end;function h:Reset()end;function h:Pause()end;function h:Play(intent)self.Notify({Kind='playing',Generation=self.Generation,Intent=intent})end
   function h:Snapshot()return {Position=self.Position}end
   function h:Load(address,raw,generation)self.Generation=generation;table.insert(requests,{URL=address,Raw=raw,Handle=self,Generation=generation});if not hold then self.Notify({Kind='loaded',Generation=generation,Duration=20})end end
   function h:Destroy()assert(self.Alive);self.Alive=false end
   table.insert(handles,h);return h
  end
  function adapter:Destroy()self.Alive=false;for _,h in handles do if h.Alive then h:Destroy()end end end
  local options={URL=url or 'https://history.test/B/index.html',Events=events,AudioAdapter=adapter,Schedule=function()end,ApplyChanges=function()return false end}
  for key,value in extra or{}do options[key]=value end
  runtime=Runtime.new(Parser.parseDocument(html or '<audio id=m></audio>'),options)
  local function pump()for _=1,16 do runtime:PumpTasks();runtime.EventLoop:Checkpoint()end end
  local function run(code)local ok,message=runtime:Run(code);assert(ok,tostring(message));pump();assert(#runtime.Diagnostics==0,table.concat(runtime.Diagnostics,' | '))end
  local function finish()runtime:Destroy();events:Destroy();assert(not adapter.Alive)end
  runtime:Start();pump()
  return {Runtime=runtime,Run=run,Pump=pump,Finish=finish,Requests=requests,Handles=handles,Complete=function(index,kind)local request=requests[index];request.Handle.Notify({Kind=kind,Generation=request.Generation,Duration=20,Code=4});pump()end}
 end
 local setup=[=[
 var aDoc=document.implementation.createHTMLDocument('A');aDoc.head.innerHTML='<base href="https://history.test/A/">';
 var m=document.getElementById('m');var s=aDoc.createElement('source');s.src='one.wav';
 document.adoptNode(s);m.append(s);window.getter=s.src;
 ]=]
 local function current(h)return h.Runtime.Window.Get('chosen')end
 local function history(node)return node.MediaSourceDocument and node.MediaSourceDocument.Document[1]end
 local function record(h,variable)return h.Runtime.DOM.Unwrap(h.Runtime.Window.Get(variable))end
 do
  local h=fixture();h.Run(setup);h.Run('window.chosen=m.currentSrc;')
  check(current(h)=='https://history.test/A/one.wav','Detached SOURCE selection uses its last-write document',current(h))
  check(h.Runtime.Window.Get('getter')=='https://history.test/B/one.wav','SOURCE getter keeps current owner')
  check(#h.Requests==1 and h.Requests[1].URL=='https://history.test/A/one.wav','Actual adapter URL uses historical SOURCE document')
  check(history(record(h,'s'))==record(h,'aDoc'),'SOURCE data provenance survives adoption')
  h.Finish();cases+=1
 end
 do
  local h=fixture();h.Run([=[var aDoc=document.implementation.createHTMLDocument('A');aDoc.head.innerHTML='<base href="https://history.test/A/">';var m=aDoc.createElement('audio');m.src='one.wav';document.adoptNode(m);document.body.append(m);window.getter=m.src;]=])
  h.Run('window.chosen=m.currentSrc;')
  check(current(h)=='https://history.test/A/one.wav','Direct AUDIO same-task adoption preserves src-write document',current(h))
  check(h.Runtime.Window.Get('getter')=='https://history.test/B/one.wav','AUDIO getter follows current owner')
  h.Finish();cases+=1
 end
 for _,write in {'s.src="one.wav"','s.setAttribute("src","one.wav")'}do
  local h=fixture();h.Run(setup);h.Run(write..';m.load();window.chosen=m.currentSrc;')
  check(#h.Requests==2 and h.Requests[1].URL=='https://history.test/A/one.wav'and h.Requests[2].URL=='https://history.test/B/one.wav','Successful same-value write resets provenance: '..write)
  check(history(record(h,'s'))==h.Runtime.DOM.Unwrap(h.Runtime.DOM.Document),'Same-value provenance is committed to destination document')
  h.Finish();cases+=1
 end
 do
  local h=fixture();h.Run(setup);h.Run('aDoc.querySelector("base").href="https://history.test/A/updated/";m.load();window.chosen=m.currentSrc;')
  check(h.Requests[#h.Requests].URL=='https://history.test/A/updated/one.wav','Historical live document uses canonical current base',h.Requests[#h.Requests].URL)
  check(h.Runtime.Window.Get('getter')=='https://history.test/B/one.wav','Old document base update does not change current-owner getter')
  h.Finish();cases+=1
 end
 do
  local h=fixture();h.Run(setup);h.Run('s.setAttributeNS("urn:foreign","p:src","two.wav");m.load();window.chosen=m.currentSrc;')
  check(h.Requests[#h.Requests].URL=='https://history.test/A/one.wav','Namespaced src cannot replace semantic provenance',h.Requests[#h.Requests].URL)
  check(history(record(h,'s'))==record(h,'aDoc'),'Namespaced src leaves old document record')
  h.Finish();cases+=1
 end
 do
  local h=fixture();h.Run([=[var aDoc=document.implementation.createHTMLDocument('A');aDoc.head.innerHTML='<base href="https://history.test/A/">';var m=aDoc.createElement('audio');m.src='one.wav';try{m.src={toString(){document.adoptNode(m);throw new Error('conversion failed')}}}catch(e){}document.body.append(m);window.getter=m.src;]=]);h.Run('window.chosen=m.currentSrc;')
  check(current(h)=='https://history.test/A/one.wav','Throwing conversion after adoption cannot overwrite historical write',current(h))
  check(h.Runtime.Window.Get('getter')=='https://history.test/B/one.wav','Failed conversion still leaves current-owner getter')
  h.Finish();cases+=1
 end
 do
  local h=fixture();h.Run([=[var aDoc=document.implementation.createHTMLDocument('A');aDoc.head.innerHTML='<base href="https://history.test/A/">';var m=aDoc.createElement('audio');m.src={toString(){document.adoptNode(m);return 'one.wav'}};document.body.append(m);]=]);h.Run('window.chosen=m.currentSrc;')
  check(current(h)=='https://history.test/B/one.wav','Successful conversion adopts before committing src')
  check(history(record(h,'m'))==h.Runtime.DOM.Unwrap(h.Runtime.DOM.Document),'Provenance observes actual commit owner after conversion')
  h.Finish();cases+=1
 end
 do
  local h=fixture('<audio id=m preload=none></audio>');h.Run(setup)
  check(#h.Requests==0,'None makes no adapter request')
  h.Run('aDoc.querySelector("base").href="https://history.test/A/late/";s.src="two.wav";m.preload="metadata";window.chosen=m.currentSrc;')
  check(#h.Requests==1 and h.Requests[1].URL=='https://history.test/A/one.wav'and h.Requests[1].Raw=='one.wav','Hint resumes retained URL/raw instead of resolving updated SOURCE history')
  h.Run('m.load();');check(h.Requests[#h.Requests].URL=='https://history.test/B/two.wav','Explicit load reads new successful write provenance')
  h.Finish();cases+=1
 end
 do
  local h=fixture();h.Run(setup);local s=record(h,'s');h.Run('s.removeAttribute("src");')
  check(s.MediaSourceDocument==nil,'Removal releases unused historical attribute record')
  check(#h.Requests==1,'SOURCE removal does not implicitly reselect')
  h.Run('s.src="two.wav";m.load();');check(h.Requests[#h.Requests].URL=='https://history.test/B/two.wav','Re-add records destination document')
  h.Finish();cases+=1
 end
 do
  local h=fixture();h.Run([=[var aDoc=document.implementation.createHTMLDocument('A');aDoc.head.innerHTML='<base href="https://history.test/A/">';aDoc.body.innerHTML='<source id="parsed" src="one.wav"><template id="t"><source src="two.wav"></template>';var parsed=aDoc.getElementById('parsed');var imported=document.importNode(parsed,true);document.adoptNode(parsed);var cloned=parsed.cloneNode(true);var tpl=aDoc.getElementById('t');var ts=tpl.content.firstChild;var fragment=aDoc.createElement('div');fragment.innerHTML='<source src="three.wav">';var fs=fragment.firstChild;var foreign=aDoc.createElementNS('urn:foreign','source');foreign.setAttribute('src','four.wav');var m=document.getElementById('m');m.append(parsed);]=])
  check(history(record(h,'parsed'))==record(h,'aDoc'),'Fragment initial attrs use effective owner rather than temporary parser document')
  check(history(record(h,'imported'))==h.Runtime.DOM.Unwrap(h.Runtime.DOM.Document),'Import new attributes use import owner')
  check(history(record(h,'cloned'))==h.Runtime.DOM.Unwrap(h.Runtime.DOM.Document),'Clone uses current creation owner rather than original historical document')
  check(history(record(h,'ts'))==record(h,'ts').OwnerDocument and record(h,'ts').OwnerDocument.InertTemplateDocument,'Template attributes use effective inert content document')
  check(history(record(h,'fs'))==record(h,'aDoc'),'Detached fragment attributes use its effective creation owner')
  check(record(h,'foreign').MediaSourceDocument==nil,'Foreign expanded-name SOURCE has no media provenance')
  h.Finish();cases+=1
 end
 do
  local enabled=false;local sentinel={Reason='Validation rejected before src commit'}
  local h=fixture(nil,nil,nil,{ValidateDataAttribute=function(_,name)if enabled and name=='src'then error(sentinel,0)end end})
  h.Run(setup);local s=record(h,'s');local original=s.MediaSourceDocument;enabled=true
  local accepted,message=pcall(h.Runtime.DOM.Attribute,s,'src','two.wav')
  check(not accepted and message==sentinel and s.Attributes.src=='one.wav'and s.MediaSourceDocument==original,'Validation failure preserves raw attribute and exact historical record')
  check(history(s)==record(h,'aDoc'),'Rejected write cannot assign current owner as historical document')
  enabled=false;h.Finish();cases+=1
 end
 do
  local enabled,entered=false,false;local observed;local h
  h=fixture(nil,nil,nil,{AttributeChanged=function(node,key,_,_,namespace)
   if enabled and not entered and key=='src'and namespace==nil then
    entered=true;observed=history(node)
    local bridge=h.Runtime.DOM;bridge.Remove(node.Parent,node);bridge.Adopt(node,record(h,'cDoc'));bridge.Attribute(node,'src','third.wav');bridge.Mutate(record(h,'m'),{node},nil,{})
   end
  end})
  h.Run(setup..[=[var cDoc=document.implementation.createHTMLDocument('C');cDoc.head.innerHTML='<base href="https://history.test/C/">';]=]);enabled=true
  h.Run('s.src="one.wav";m.load();')
  check(observed==h.Runtime.DOM.Unwrap(h.Runtime.DOM.Document),'Same-value commit assigns provenance before observable attribute callback')
  check(history(record(h,'s'))==record(h,'cDoc')and record(h,'s').Attributes.src=='third.wav','Reentrant inner write retains its newer committed document')
  check(h.Requests[#h.Requests].URL=='https://history.test/C/third.wav','Resource resolver consumes final reentrant provenance',h.Requests[#h.Requests].URL)
  h.Finish();cases+=1
 end
 do
  local h=fixture(nil,nil,true)
  h.Run([=[var aDoc=document.implementation.createHTMLDocument('A');aDoc.head.innerHTML='<base href="https://history.test/A/">';var cDoc=document.implementation.createHTMLDocument('C');cDoc.head.innerHTML='<base href="https://history.test/C/">';var m=document.getElementById('m'),s1=aDoc.createElement('source'),s2=aDoc.createElement('source');s1.src='bad.wav';s2.src='two.wav';m.append(s1,s2);window.sourceErrors=0;s1.addEventListener('error',()=>sourceErrors++);m.currentTime=5;m.playbackRate=1.5;window.outcome='pending';m.play().then(()=>outcome='played');]=])
  check(#h.Requests==1 and h.Requests[1].URL=='https://history.test/A/bad.wav','First held child request uses its own historical document')
  h.Run('cDoc.adoptNode(s2);s2.src="second.wav";m.append(s2);')
  check(#h.Requests==1,'SOURCE metadata/move does not automatically restart selected request')
  h.Complete(1,'error');check(#h.Requests==2 and h.Requests[2].URL=='https://history.test/C/second.wav','Next candidate uses its own latest successful write document')
  h.Run('window.pending=outcome;window.rate=m.playbackRate;window.time=m.currentTime;')
  check(h.Runtime.Window.Get('pending')=='pending'and h.Runtime.Window.Get('rate')==1.5 and h.Runtime.Window.Get('time')==5,'Historical retry preserves Play/default cursor/rate')
  h.Complete(2,'loaded');h.Run('window.done=outcome;window.errors=sourceErrors;')
  check(h.Runtime.Window.Get('done')=='played'and h.Runtime.Window.Get('errors')==1,'Historical child retry fulfills retained promise after one SOURCE error')
  h.Finish();cases+=1
 end
 do
  local h=fixture('<audio id=m src=one.wav></audio>','https://history.test/A/index.html')
  h.Run([=[var m=document.getElementById('m'),bDoc=document.implementation.createHTMLDocument('B');bDoc.head.innerHTML='<base href="https://history.test/B/">';bDoc.adoptNode(m);bDoc.body.append(m);m.load();window.getter=m.src;]=])
  check(history(record(h,'m'))==h.Runtime.DOM.Unwrap(h.Runtime.DOM.Document),'Full parsed src uses its actual creation document')
  check(h.Requests[#h.Requests].URL=='https://history.test/A/one.wav'and h.Runtime.Window.Get('getter')=='https://history.test/B/one.wav','Full parsed media separates selection history from adopted getter')
  h.Finish();cases+=1
 end
 -- Consume the five previously archived cases without rewriting their raw
 -- action/snapshot/request arrays. Only the fifth gets a named document rule.
 local names={'direct set then base mutation','direct selected then base then load','child set then base mutation','child selected then base then load','detached source created old doc adopted'}
 local snapshots=0
 for index,case in reference.bases do
  check(case.name==names[index],'Pinned native historical inventory order')
  local base=case.settled.currentSrc:gsub('later/one.wav$',''):gsub('one.wav$','')
  local h=fixture('<base href="'..base..'"><audio id=m></audio>',base..'index.html')
  h.Run('var m=document.getElementById("m"),base='..string.format('%q',base)..';function make(id,src){const s=document.createElement("source");s.id=id;s.src=src;return s}window.snap=function(){return JSON.stringify([m.getAttribute("src"),m.currentSrc,m.paused,m.readyState,m.networkState,m.currentTime,m.playbackRate])};'..case.action..';window.immediate=snap();')
  local function expected(value,current)return '['..(if value.src==nil then'null'else string.format('%q',value.src))..','..string.format('%q',current)..','..tostring(value.paused)..','..value.ready..','..value.network..','..value.time..','..value.rate..']'end
  check(h.Runtime.Window.Get('immediate')==expected(case.immediate,case.immediate.currentSrc),'Archived immediate native snapshot '..case.name,h.Runtime.Window.Get('immediate'));snapshots+=1
  local historical=if index==5 then base..'original/one.wav'else case.settled.currentSrc
  h.Run('window.actual=snap();');check(h.Runtime.Window.Get('actual')==expected(case.settled,historical),'Archived settled/native counterpart '..case.name,h.Runtime.Window.Get('actual'));snapshots+=1
  if case.load then
   h.Run(case.load.action..';window.immediate=snap();');check(h.Runtime.Window.Get('immediate')==expected(case.load.immediate,case.load.immediate.currentSrc),'Archived load immediate '..case.name,h.Runtime.Window.Get('immediate'));snapshots+=1
   h.Run('window.actual=snap();');check(h.Runtime.Window.Get('actual')==expected(case.load.settled,case.load.settled.currentSrc),'Archived load settled '..case.name,h.Runtime.Window.Get('actual'));snapshots+=1
  end
  check(h.Requests[1]and h.Requests[1].URL==historical,'Exact original native request or historical-doc counterpart '..case.name,h.Requests[1]and h.Requests[1].URL)
  h.Finish();cases+=1
 end
 check(snapshots==14,'All fourteen archived native snapshots are consumed')
 for _,failure in failures do print('HISTORICAL_SOURCE_MISMATCH',failure)end
 print('HISTORICAL_SOURCE_SUMMARY','candidate='..tostring(candidate),'cases='..cases,'archivedSnapshots='..snapshots,'checks='..checks,'failures='..#failures)
 assert(#failures==0,'Historical src-write document selection controls require frozen normative counterpart')
end
