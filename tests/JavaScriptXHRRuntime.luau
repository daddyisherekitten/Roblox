--!strict
return function(Parser,Runtime,Events)
 local time=0;local output,requests={},{};local canceled=0
 local events=Events.new(error)
 local realm=Runtime.new(Parser.parseDocument('<!doctype html><body><output id="result"></output></body>'),{
  URL='https://example.test/page',Events=events,Schedule=function()end,Clock=function()return time end,
  Console=function(_,value)table.insert(output,value)end,
  Fetch=function(snapshot,complete)local request={Snapshot=snapshot,Complete=complete};table.insert(requests,request);return function()request.Canceled=true;canceled+=1 end end})
 local function run(source)realm:Run(source);assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
 local function pump()for _=1,8 do realm:PumpTasks()end;assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
 run([=[
var x=new XMLHttpRequest();x.open('GET','/document');x.responseType='document';x.onload=function(){document.getElementById('result').textContent=x.response.documentElement.textContent;console.log(x.response===x.responseXML,x.status,x.response.URL);};x.send();
]=])
 assert(#requests==1 and #output==0)
 requests[1].Complete(true,{status=200,url='https://example.test/received.xml',bodyBytes='<root>actual DOM result</root>',headerPairs={{'content-type','application/xml'}}});pump()
 assert(output[1]=='true 200 https://example.test/received.xml','Late runtime DOM intrinsics produce a genuine parsed response document with response URL')
 run("console.log(document.getElementById('result').textContent);")
 assert(output[2]=='actual DOM result','XHR handler mutates the actual main DOM')
 run("var timeout=new XMLHttpRequest();timeout.timeout=10;timeout.ontimeout=function(){console.log('timeout',timeout.readyState,timeout.status);};timeout.open('GET','/slow');timeout.send();")
 time=.02;pump();assert(output[3]=='timeout 4 0'and canceled==1,'Runtime forwards a delayed task, millisecond clock and cancellation to XHR')
 run("var pending=new XMLHttpRequest();pending.timeout=500;pending.open('GET','/pending');pending.onload=function(){console.log('late');};pending.send();")
 assert(realm.EventLoop.TaskCount>0)
 realm:Destroy();assert(canceled==2 and realm.EventLoop.TaskCount==0,'Runtime disposal cancels both pending transport and deadline')
 requests[3].Complete(true,{status=200,bodyBytes='late'});assert(#output==3,'Disposed realm cannot publish a late XHR completion')
 events:Destroy()
 print('XHR actual HTML Runtime: deferred DOM intrinsics, parsed document/URL, main-DOM mutation, delayed timeout and disposal passed')
end
