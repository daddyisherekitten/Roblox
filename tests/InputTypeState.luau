--!strict
return function(Parser,Runtime,Events,reference)
 local checked=0
 local document=Parser.parseDocument('<!doctype html><body></body>');local events=Events.new(error);local runtime=Runtime.new(document,{Events=events,ControlAdapter={Events=events},ApplyChanges=function()return false end,Diagnostic=error})
 for _,case in reference.cases do
  local prepare='document.body.innerHTML='..string.format('%q',reference.initial)..";globalThis.s=document.getElementById('s');globalThis.peer=document.getElementById('peer');s.type="..string.format('%q',case.from)..';'
  if case.dirty then prepare..="if(s.type!=='file')s.value='7.5';s.checked=false;s.indeterminate=true;if(s.selectionStart!==null)s.setSelectionRange(1,2,'backward');"end
  assert(runtime:Run(prepare..'globalThis.beforeType='..reference.snapshot..';s.type='..string.format('%q',case.to)..';globalThis.afterType='..reference.snapshot..";document.getElementById('f').reset();globalThis.resetType="..reference.snapshot))
  local expected=case.specExpected or case.platformExpected
  for _,pair in {{'beforeType',expected.before},{'afterType',expected.changed},{'resetType',expected.reset}}do
   local actual=runtime.Window.Get(pair[1]);assert(actual==pair[2],case.from..' → '..case.to..' dirty='..tostring(case.dirty)..' '..pair[1]..': '..tostring(actual)..' != '..pair[2])
  end
  runtime:Flush();runtime:PumpTasks();checked+=1
 end
 runtime:Destroy();events:Destroy()
 assert(checked==968,'Input type native pair coverage changed')
 print('Input type state: '..checked..' native reference sequences with explicit standard/platform differences, 22×22 pristine/dirty value/checked/selection/validation/radio/reset passed')
end
