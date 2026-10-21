--!strict
return function(VM,Promises,AsyncFunctions,EventLoop,HostEvents,NetworkData,Parser,DOM,CustomElements)
 local function fresh(worker)
  local result={Values={},Reports={},Time=0,Requests={},Canceled=0};local vm,loop,promises
  local globals={record=function(args)table.insert(result.Values,VM.string(args[1]));return VM.Undefined end}
  local document=Parser.parseDocument('<!doctype html><body></body>')
  local bridge=DOM.new(document,{Window={},URL='https://example.test/base/',ReadyState='complete',Step=function()vm.Step()end,Changed=function()end})
  globals.document=bridge.Document
  loop=EventLoop.new({Clock=function()return result.Time end,Report=function(message)table.insert(result.Reports,tostring(message))end,
   Invoke=function(fn,args)vm:Call(fn,args);loop:Checkpoint();return vm.Steps end,AfterCheckpoint=function()if promises then promises:AfterCheckpoint()end end})
  for key,value in loop.Methods do globals[key]=value end
  promises=Promises.new({Enqueue=function(fn)loop:QueueMicrotask(fn)end,Report=function(message)table.insert(result.Reports,VM.string(message))end,
   Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,Get=function(value,key,receiver)return vm.Get(value,key,receiver)end,
   Construct=function(fn,args)return vm:Construct(fn,args)end,Iterator=function(value)return vm.Iterator(value)end,Array=function(items)return vm.Array(items)end,Object=function(values)return vm.Object(values)end})
  globals.Promise=promises.Constructor
  local async=AsyncFunctions.new({Create=function()return promises:CreateCapability()end,Wait=function(value,yes,no)promises:Await(value,yes,no)end,Resume=function(record,rejected,value)return vm:ResumeAsync(record,rejected,value)end})
  vm=VM.new(globals,{Async=async,MaxSteps=200000});promises:Attach(vm);bridge.AttachVM(vm)
  local host=HostEvents.install(vm,globals,{Report=function(message)table.insert(result.Reports,VM.string(message))end,Clock=function()return result.Time*1000 end,
   SetTimeout=function(fn,ms)return loop.Methods.setTimeout({fn,ms})end,ClearTimeout=function(id)loop.Methods.clearTimeout({id})end})
  local network=NetworkData.install(vm,globals,{HostEvents=host,IsWorker=worker,BaseURL='https://example.test/base/',RequestNow=function()return result.Time*1000 end,
   CreatePromise=function()return promises:CreateCapability()end,Await=function(value,yes,no)promises:Await(value,function(args)yes(args[1])end,function(args)no(args[1])end)end,
   Enqueue=function(fn)loop:QueueMicrotask(fn)end,EnqueueTask=function(fn,delay)return loop:QueueTask(fn,delay)end,CancelTask=function(id)loop:CancelTask(id)end,
   Fetch=function(snapshot,complete,signal)local request={Snapshot=snapshot,Complete=complete,Signal=signal};table.insert(result.Requests,request);return function()request.Canceled=true;result.Canceled+=1;if result.CancelHook then result.CancelHook()end end end})
  local context=bridge.CustomContext();context.Events=host;context.Network=network;context.Report=error;context.CreatePromise=function()return promises:CreateCapability()end
  local custom=CustomElements.install(vm,globals,context);bridge.AttachCustomElements(custom);bridge.InstallInterfaces(vm,globals)
  network.XMLHttpRequest:AttachDocumentIntrinsics(globals.DOMParser,globals.XMLSerializer)
  result.VM,result.Loop,result.Network,result.Globals=vm,loop,network,globals
  function result:Run(source)vm:Run(source);loop:Checkpoint()end
  function result:Pump()for _=1,12 do loop:PumpTasks();loop:Checkpoint()end end
  function result:Reply(data,index)local req=self.Requests[index or #self.Requests];assert(req,'Transport request exists');req.Complete(true,data);self:Pump()end
  function result:Value(name)return vm.Global.Bindings[name].Value end
  function result:Destroy()network:Destroy();custom:Destroy();host:Destroy();bridge:Destroy();async:Destroy();promises:Destroy();loop:Destroy();vm:Destroy()end
  return result
 end
 do
  local r=fresh();r:Run([=[
function check(value,message){if(!value)throw new Error(message);}
var x=new XMLHttpRequest();check(x.readyState===0&&x.status===0&&x.responseText==='','initial text response');
check(x.response===''&&x.responseXML===null&&x.upload===x.upload,'initial/same-object values');
check(x instanceof XMLHttpRequest&&x instanceof XMLHttpRequestEventTarget&&x instanceof EventTarget&&x.upload instanceof XMLHttpRequestUpload,'prototype chains');
check(XMLHttpRequest.DONE===4&&x.OPENED===1&&Object.prototype.toString.call(x)==='[object XMLHttpRequest]','constants and tag');
function errorName(fn){try{fn();}catch(e){return e.name;}return 'none';}
check(errorName(function(){XMLHttpRequest();})==='TypeError'&&errorName(function(){new XMLHttpRequestUpload();})==='TypeError','constructors');
check(errorName(function(){x.send();})==='InvalidStateError'&&errorName(function(){x.open('GET');})==='TypeError','state and arguments');
check(errorName(function(){x.open('bad method','/');})==='SyntaxError'&&errorName(function(){x.open('TRACE','/');})==='SecurityError','method errors');
check(errorName(function(){x.open('GET','/',false);})==='NotSupportedError','explicit blocking transport boundary');
x.responseType='invalid';check(x.responseType==='','unknown enum ignored');x.responseType='arraybuffer';check(x.response===null&&errorName(function(){return x.responseText;})==='InvalidStateError','nontext guards');
x.responseType='';x.open('get','../text#hash');x.setRequestHeader('X-Test','one');x.setRequestHeader('X-Test','two');x.setRequestHeader('Cookie','blocked');
check(errorName(function(){x.setRequestHeader('x','value\r\n');})==='SyntaxError','invalid header bytes rejected before trim');
check(errorName(function(){x.send(Symbol('bad'));})==='TypeError','BodyInit conversion happens for ignored GET body too');
var conversions=0;x.withCredentials=true;x.send({toString:function(){conversions++;return 'ignored GET body';}});check(conversions===1,'one BodyInit string conversion');
check(errorName(function(){x.withCredentials=false;})==='InvalidStateError'&&errorName(function(){x.setRequestHeader('x','y');})==='InvalidStateError'&&errorName(function(){x.send();})==='InvalidStateError','sending state guards');
]=])
  assert(#r.Requests==1 and r.Requests[1].Snapshot.url=='https://example.test/text#hash' and r.Requests[1].Snapshot.method=='GET'and r.Requests[1].Snapshot.bodyBytes==nil)
  assert(r.Requests[1].Snapshot.credentials=='include')
  local values={};for _,pair in r.Requests[1].Snapshot.headerPairs do assert(pair[1]~='cookie');if pair[1]=='x-test'then table.insert(values,pair[2])end end;assert(table.concat(values,', ')=='one, two')
  r:Destroy();assert(r.Canceled==1,'Destroy cancels the real pending fetch operation')
 end
 do
  local r=fresh();r:Run([=[
var states=[],events=[],x=new XMLHttpRequest();x.onreadystatechange=function(){states.push(x.readyState+':'+x.responseText);};
['loadstart','progress','load','loadend'].forEach(function(name){x.addEventListener(name,function(e){events.push(name+':'+x.readyState+':'+e.loaded+':'+e.total+':'+e.lengthComputable+':'+(e instanceof ProgressEvent)+':'+e.isTrusted);});});
x.open('GET','/text');x.send();var sync=states.join('|')+' / '+events.join('|');
]=])
  assert(r:Value('sync')=='1: / loadstart:1:0:0:false:true:true','open/readystatechange and loadstart are synchronous, response is deferred')
  local req=r.Requests[1];req.Complete(true,{status=201,statusText='Created',url='https://example.test/final#ignored',bodyBytes='hello',headerPairs={{'content-type','text/plain;charset=UTF-8'},{'content-length','5'},{'x-z','last'},{'x-a','first'},{'set-cookie','hidden'}}})
  assert(r:Value('states').Length==1,'Host completion never runs JS inline');r:Pump()
  r:Run("record(states.join('|'));record(events.join('|'));record(x.status+'|'+x.statusText+'|'+x.response+'|'+x.responseURL);record(x.getResponseHeader('set-cookie')===null);record(x.getAllResponseHeaders());")
  assert(r.Values[1]=='1:|2:|3:hello|4:hello')
  assert(r.Values[2]=='loadstart:1:0:0:false:true:true|progress:3:5:5:true:true:true|load:4:5:5:true:true:true|loadend:4:5:5:true:true:true')
  assert(r.Values[3]=='201|Created|hello|https://example.test/final'and r.Values[4]=='true')
  assert(r.Values[5]=='content-length: 5\r\ncontent-type: text/plain;charset=UTF-8\r\nx-a: first\r\nx-z: last\r\n')
  assert(#r.Reports==0,table.concat(r.Reports,' | '));r:Destroy()
 end
 for _,case in {{'json','{"value":7}',"x.response.value===7&&x.response===x.response"},{'json','broken',"x.response===null"},{'arraybuffer','\0\255A',"new Uint8Array(x.response).join(',')==='0,255,65'&&x.response===x.response"},{'blob','abc',"x.response.size===3&&x.response.type==='text/plain'&&x.response===x.response"},{'document','<root><value>ok</value></root>',"x.response.documentElement.tagName==='root'&&x.response===x.responseXML"},{'document','<broken>',"x.response===null&&x.responseXML===null"}}do
  local r=fresh();r:Run("var x=new XMLHttpRequest();x.open('GET','/data');x.responseType='"..case[1].."';x.send();")
  r:Reply({status=200,bodyBytes=case[2],headerPairs={{'content-type',if case[1]=='document'then'application/xml'else'text/plain'}}})
  r:Run('var good='..case[3]..';');assert(r:Value('good'),'Response type '..case[1]);assert(#r.Reports==0,table.concat(r.Reports,' | '));r:Destroy()
 end
 do
  local r=fresh();r:Run("var x=new XMLHttpRequest();x.responseType='json';x.open('GET','/one');x.send();")
  r:Reply({status=200,bodyBytes='{"one":1}'});r:Run("var first=x.response;var good=first.one===1;x.open('GET','/two');x.send();")
  assert(r:Value('good'));r:Reply({status=200,bodyBytes='{"two":2}'});r:Run("var reset=x.response.two===2&&x.response!==first;");assert(r:Value('reset'),'open clears typed response cache before next response');r:Destroy()
 end
 do
  local r=fresh();r:Run("var x=new XMLHttpRequest();x.open('GET','/bom');x.send();")
  r:Reply({status=200,bodyBytes='\255\254A\0',headerPairs={{'content-type','text/plain;charset=UTF-8'}}});r:Run("var good=x.responseText==='A';");assert(r:Value('good'),'Text decoding honors UTF-16 BOM before MIME fallback');r:Destroy()
 end
 do
  local r=fresh();r:Run("var x=new XMLHttpRequest();x.open('POST','/document');x.send(document);")
  local request=r.Requests[1].Snapshot;assert(request.bodyBytes=='<!DOCTYPE html><html><head></head><body></body></html>','HTML document request uses HTML serialization')
  local mime;for _,pair in request.headerPairs do if pair[1]=='content-type'then mime=pair[2]end end;assert(mime=='text/html;charset=UTF-8');r:Destroy()
 end
 do
  local r=fresh();r:Run("var x=new XMLHttpRequest();x.open('GET','/encoding');x.overrideMimeType('text/plain;charset=windows-1252');x.send();")
  r:Reply({status=200,bodyBytes='\128',headerPairs={{'content-type','text/plain;charset=UTF-8'}}});r:Run("var good=x.responseText==='€';");assert(r:Value('good'),'Override MIME charset uses actual decoder');r:Destroy()
 end
 do
  local r=fresh();r:Run([=[
var trace=[],x=new XMLHttpRequest();x.onreadystatechange=function(){trace.push('s'+x.readyState);};x.onabort=function(){trace.push('abort'+x.readyState);};x.onloadend=function(){trace.push('end'+x.readyState);};x.open('GET','/pending');x.send();x.abort();trace.push('after'+x.readyState);record(trace.join('|'));
]=])
  assert(r.Values[1]=='s1|s4|abort4|end4|after0'and r.Canceled==1,'Abort events observe DONE before reset to UNSENT')
  r.Requests[1].Complete(true,{status=200,bodyBytes='late'});r:Pump();assert(#r.Values==1,'Late aborted completion ignored');r:Destroy()
 end
 do
  local r=fresh();r:Run("var trace=[],x=new XMLHttpRequest();x.onerror=function(){trace.push('error'+x.readyState+':'+x.status);};x.onloadend=function(){trace.push('end');};x.open('GET','/error');x.send();")
  r.Requests[1].Complete(false,'network failed');r:Pump();r:Run("record(trace.join('|'));");assert(r.Values[1]=='error4:0|end','Network rejection dispatches error/loadend');r:Destroy()
 end
 do
  local r=fresh();r:Run("var trace=[],x=new XMLHttpRequest();x.timeout=100;x.ontimeout=function(){trace.push('timeout'+x.readyState);};x.onloadend=function(){trace.push('end');};x.open('GET','/slow');x.send();")
  r.Time=.04;r:Pump();r:Run('x.timeout=20;');r:Pump();r:Run("record(trace.join('|'));");assert(r.Values[1]=='timeout4|end'and r.Canceled==1,'Changing timeout uses the original send deadline, cancels transport')
  assert(r.Loop.TaskCount==0,'Terminal timeout releases scheduled timer ownership');r:Destroy()
 end
 do
  local r=fresh();r:Run("var loads=[],x=new XMLHttpRequest();x.onload=function(){loads.push(x.responseText);};x.open('GET','/first');x.send();x.open('GET','/second');x.send();")
  assert(r.Canceled==1 and #r.Requests==2);r.Requests[1].Complete(true,{status=200,bodyBytes='old'});r:Reply({status=200,bodyBytes='new'},2)
  r:Run("record(loads.join('|'));");assert(r.Values[1]=='new','Reopening cancels old transport and invalidates its completion');r:Destroy()
 end
 do
  local r=fresh();r:Run([=[
var trace=[],x=new XMLHttpRequest();['loadstart','progress','load','loadend'].forEach(function(name){x.upload.addEventListener(name,function(e){trace.push(name+':'+e.loaded+':'+e.total);});});
x.open('POST','/upload');x.send('fö');
]=])
  assert(r.Requests[1].Snapshot.bodyBytes=='fö');r:Reply({status=200,bodyBytes='ok'})
  r:Run("record(trace.join('|'));");assert(r.Values[1]=='loadstart:0:0|progress:3:3|load:3:3|loadend:3:3','Upload terminal batch counts exact extracted UTF-8 bytes; timing remains buffered')
  r:Destroy()
 end
 do
  local r=fresh(true);r:Run("var x=new XMLHttpRequest();x.responseType='document';var workerProfile=x.responseType===''&&typeof x.responseXML==='undefined';")
  assert(r:Value('workerProfile'),'Worker profile ignores document response type and omits responseXML');r:Destroy()
 end
 do
  local r=fresh();r:Run("var x=new XMLHttpRequest();x.timeout=50;x.open('GET','/pending');x.send();x.timeout=0;")
  assert(r.Loop.TaskCount==0,'Disabling timeout cancels pending deadline');r.Time=1;r:Pump();r:Reply({status=200,bodyBytes='still active'});r:Run("var good=x.status===200&&x.responseText==='still active';");assert(r:Value('good'));r:Destroy()
 end
 do
  local r=fresh();r:Run("var x=new XMLHttpRequest();x.onloadstart=function(){x.abort();};x.open('GET','/never');x.send();")
  assert(#r.Requests==0,'loadstart abort prevents host request');r:Destroy()
 end
 do
  local r=fresh();r:Run("var trace=[],x=new XMLHttpRequest();x.onload=function(){trace.push('load'+x.readyState);x.open('GET','/next');};x.onloadend=function(e){trace.push('end'+x.readyState+':'+e.loaded+':'+e.total);};x.open('GET','/text');x.send();")
  r:Reply({status=200,bodyBytes='hello',headerPairs={{'content-length','5'}}});r:Run("record(trace.join('|'));")
  assert(r.Values[1]=='load4|end1:5:5','loadend still fires after onload reopens, preserving old loaded/total');r:Destroy()
 end
 for _,kind in {'abort','error','timeout'}do
  local r=fresh();r:Run("var trace=[],x=new XMLHttpRequest();x.on"..kind.."=function(){trace.push('"..kind.."'+x.readyState);x.open('GET','/next');};x.onloadend=function(){trace.push('end'+x.readyState);};x.open('GET','/pending');x.timeout="..(if kind=='timeout'then'10'else'0')..";x.send();")
  if kind=='abort'then r:Run('x.abort();')elseif kind=='error'then r.Requests[1].Complete(false,'error');r:Pump()else r.Time=.02;r:Pump()end
  r:Run("record(trace.join('|'));");assert(r.Values[1]==kind..'4|end1','Terminal '..kind..' continues loadend after handler reopens');r:Destroy()
 end
 do
  local r=fresh();r:Run("var conversions=0,params=new URLSearchParams('a=b');params.toString=function(){conversions++;return 'overridden';};var x=new XMLHttpRequest();x.open('POST','/params');x.send(params);")
  assert(r:Value('conversions')==0 and r.Requests[1].Snapshot.bodyBytes=='a=b','XHR URLSearchParams extraction uses captured serialization intrinsic')
  r:Run("fetch('/params',{method:'POST',body:params});");assert(r:Value('conversions')==0 and r.Requests[2].Snapshot.bodyBytes=='a=b','Fetch shares intrinsic URLSearchParams extraction');r:Destroy()
 end
 for _,complete in {false,true}do
  local r=fresh();r:Run("var x=new XMLHttpRequest();x.open('GET','/initial');x.send();var cancelHook=function(){cancelHook=null;x.open('GET','/fromcancel');x.send();};")
  r.CancelHook=function()local callback=r:Value('cancelHook');if VM.callable(callback)then r.VM:Call(callback,{})end end
  r:Run('x.abort();');assert(#r.Requests==2 and r.Canceled==1)
  r:Run('var preserved=x.readyState===1;');assert(r:Value('preserved'),'Reentrant host cancel replacement remains opened/sending')
  if complete then r:Reply({status=200,bodyBytes='replacement'},2);r:Run("var received=x.readyState===4&&x.responseText==='replacement';");assert(r:Value('received'),'Replacement response survives outer abort')end
  r:Destroy();assert(r.Canceled==(if complete then 1 else 2),'Disposal still owns/cancels a pending reentrant replacement')
 end
 do
  local r=fresh();r:Run("var x=new XMLHttpRequest();x.onreadystatechange=function(){if(x.readyState===2)x.open('GET','/replacement');};x.open('GET','/initial');x.send();")
  r:Reply({status=200,bodyBytes='obsolete'});r:Run("var good=x.readyState===1&&x.responseText==='';");assert(r:Value('good'),'Reentrant open during headers prevents stale body/progress/terminal publication');r:Destroy()
 end
 print('XMLHttpRequest buffered async: real VM/DOM/Fetch events, headers/body/types, parser/encoding, abort/timeout/reopen/reentrancy and disposal passed')
end
