--!strict
return function(Parser,Runtime,Events,fixtures)
 for _,fixture in fixtures do
  local output={};local events=Events.new(error);local clock=0;local realm
  local prefix="<script>document.addEventListener('DOMContentLoaded',()=>console.log('dcl',document.readyState));window.addEventListener('load',()=>console.log('load',document.readyState));</script>"
  local doc=Parser.parse('<!doctype html><html><body>'..prefix..fixture.html..'</body></html>')
  realm=Runtime.new(doc,{URL='https://scripts.test/index.html',Events=events,Clock=function()return clock end,
   Schedule=function()end,ApplyChanges=function()return false end,Console=function(_,value)table.insert(output,value)end,
   LoadScript=function(url,complete)
    local resource=fixture.resources[url];local cancelled=false
    if not resource then complete(false,'Missing resource');return end
    local id=realm.EventLoop.Methods.setTimeout({function()if not cancelled then complete(true,{Source=resource.Source,MIME=resource.MIME or 'text/javascript'})end end,resource.Delay or 0})
    return function()cancelled=true;realm.EventLoop.Methods.clearTimeout({id})end
   end,
  })
  realm:Start()
  for _=1,120 do clock+=0.001;realm:PumpTasks();realm.EventLoop:Checkpoint()end
  assert(#realm.Diagnostics==0,fixture.name..': '..table.concat(realm.Diagnostics,'\n'))
  assert(#output==#fixture.expected,fixture.name..': count ['..table.concat(output,' | ')..']')
  for index,value in output do assert(value==fixture.expected[index],fixture.name..': ['..table.concat(output,' | ')..'] expected '..fixture.expected[index])end
  realm:Destroy();events:Destroy()
 end
 print('HTML script loader: '..#fixtures..' shared browser ordering cases passed')
end
