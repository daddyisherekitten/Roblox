--!strict
return function(Parser,Runtime,Events,VM,fixtures)
 for _,fixture in fixtures do
  local output={};local events=Events.new(error);local clock=0
  local realm=Runtime.new(Parser.parse('<!doctype html><body></body>'),{
   URL='https://modules.test/main.js',ModuleSources=fixture.sources,ImportMap=fixture.importMap,
   Events=events,Clock=function()return clock end,Schedule=function()end,ApplyChanges=function()return false end,
   Console=function(_,value)table.insert(output,value)end,
  })
  local result=realm:RunModule('./main.js')
  local settled=false
  realm.Promises:Await(result,function()settled=true end,function(args)settled=true;table.insert(output,'error:'..VM.string(realm.VM.Get(args[1],'name')))end)
  for _=1,100 do clock+=0.01;realm:PumpTasks();realm.EventLoop:Checkpoint();if settled and realm.EventLoop.TaskCount==0 then break end end
  assert(settled,fixture.name..': module graph did not settle')
  assert(#output==#fixture.expected,fixture.name..': output count '..#output..' expected '..#fixture.expected..' ['..table.concat(output,' | ')..']')
  for index,value in output do assert(value==fixture.expected[index],fixture.name..': '..value..' expected '..fixture.expected[index])end
  assert(#realm.Diagnostics==0,fixture.name..': '..table.concat(realm.Diagnostics,'\n'))
  realm:Destroy();events:Destroy()
 end
 print('JavaScript modules: '..#fixtures..' shared native module graphs passed')
end
