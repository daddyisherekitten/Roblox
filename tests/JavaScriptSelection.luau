--!strict
return function(Parser,Runtime,VM,Events,fixtures)
 local failures={}
 for _,fixture in fixtures do
  local document=Parser.parseDocument('<html><body></body></html>');local values,diagnostics={},{}
  local runtime=Runtime.new(document,{Events=Events.new(error),URL='https://example.test/selection',
   Console=function(_,message)table.insert(values,message)end,Diagnostic=function(message)table.insert(diagnostics,message)end})
  runtime:Run('function record(value){console.log(String(value));}\n'..fixture.source)
  if #diagnostics>0 or #values~=#fixture.expected then table.insert(failures,fixture.name..': '..table.concat(diagnostics,' / ')..' actual='..table.concat(values,' | '))
  else for i,item in values do if item~=fixture.expected[i]then table.insert(failures,fixture.name..' ['..i..']: '..item..' ~= '..fixture.expected[i])end end end
  runtime:Destroy()
 end
 for _,failure in failures do print('Selection mismatch: '..failure)end
 assert(#failures==0,'Selection reference failures: '..#failures)
 print('JavaScript Selection: '..#fixtures..' browser-authored profile fixtures passed (explicit standard/renderer differences recorded)')
 local diagnostics,output,paints,dirty={}, {}, {},0
 local adapter={}
 function adapter:Apply(a,ao,f,fo)table.insert(paints,{a,ao,f,fo})end
 function adapter:Clear()table.insert(paints,{})end
 function adapter:SetNativeChange(callback)self.NativeChange=callback end
 local nativeRects={{X=10,Y=20,Width=0,Height=12},{X=20,Y=25,Width=30,Height=12}}
 function adapter:RangeRects()return nativeRects end
 function adapter:Destroy()self.Destroyed=true;self.NativeChange=nil end
 local runtime=Runtime.new(Parser.parseDocument('<html><body><p id="p">abcdef</p></body></html>'),{
  URL='https://example.test/selection-tasks',Events=Events.new(error),SelectionAdapter=adapter,
  ApplyChanges=function()dirty+=1;return false end,Console=function(_,s)table.insert(output,s)end,
  Diagnostic=function(s)table.insert(diagnostics,s)end})
 runtime:Run([=[
const p=document.getElementById('p'),t=p.firstChild,s=getSelection();let changes=0,starts=0;
document.addEventListener('selectionchange',e=>{if(e.target!==document||e.bubbles||e.cancelable||!e.isTrusted)throw new Error('event flags');changes++});
document.addEventListener('selectstart',e=>{if(e.target!==t||!e.bubbles||!e.cancelable||!e.isTrusted)throw new Error('selectstart flags');starts++});
s.collapse(t,0);s.extend(t,2);s.extend(t,3);console.log(changes);
]=])
 assert(output[1]=='0'and #paints==0 and not runtime:HasPending(),'Selection events and paint wait for tasks and do not dirty DOM')
 runtime:PumpTasks();runtime:Run('console.log(changes);');assert(output[2]=='1'and #paints==1 and dirty==0,'One task coalesces a selection batch without layout')
 runtime:Run('s.getRangeAt(0).setEnd(t,4);');runtime:PumpTasks();runtime:Run('console.log(changes);');assert(output[3]=='2')
 runtime:Run("t.replaceData(1,1,'Z');");runtime:PumpTasks();runtime:Flush();runtime:Run('console.log(changes);');assert(output[4]=='2','Text replacement with stable boundaries repaints but does not dispatch selectionchange')
 local raw=runtime.VM.Global.Bindings.t.Value.DOMNode
 assert(adapter.NativeChange(raw,0,raw,3),'Native selection forwards raw source positions through the realm entry')
 runtime:PumpTasks();runtime:Run('console.log(starts);');assert(output[5]=='0','Extending an existing noncollapsed selection does not restart selection')
 runtime:Run('s.empty();');runtime:PumpTasks()
 assert(adapter.NativeChange(raw,0,raw,2));runtime:PumpTasks();runtime:Run('console.log(starts);');assert(output[6]=='1','Native empty-to-range selection dispatches selectstart')
 runtime:Run('s.empty();document.onselectstart=e=>e.preventDefault();');runtime:PumpTasks()
 assert(not adapter.NativeChange(raw,0,raw,3));runtime:PumpTasks();runtime:Run('console.log(s.rangeCount);');assert(output[7]=='0','Canceled selectstart retains the existing association and repaints native state')
 runtime:Run([=[
const held=s,range=document.createRange();range.selectNodeContents(t);
for(const value of [range,new StaticRange({startContainer:t,startOffset:0,endContainer:t,endOffset:1}),s]){
let rejected=false;try{structuredClone(value)}catch(e){rejected=e.name==='DataCloneError'}if(!rejected)throw new Error('host clone');}
]=])
 runtime:Run('s.collapse(t,0);s.extend(t,3);');runtime:PumpTasks()
 assert(not adapter.NativeChange(nil,0,nil,0),'A native click on a nonselectable surface cannot empty a nonempty document selection')
 runtime:PumpTasks();runtime:Run('if(getSelection().rangeCount!==1)throw new Error("native clear lost selection");')
 runtime:Run([=[
const rects=range.getClientRects(),bounds=range.getBoundingClientRect();
if(!(rects instanceof DOMRectList)||!(bounds instanceof DOMRect)||rects.length!==2||rects.item(2)!==null)throw new Error('range rectangle types');
if(bounds.x!==10||bounds.y!==20||bounds.width!==40||bounds.height!==17)throw new Error('range union');
rects[0].x=99;if(range.getClientRects()[0].x!==10)throw new Error('rect snapshot');
]=])
 nativeRects={{X=10,Y=20,Width=0,Height=12},{X=30,Y=80,Width=10,Height=0}}
 runtime:Run('const caretBounds=range.getBoundingClientRect();if(caretBounds.x!==10||caretBounds.y!==20||caretBounds.width!==0||caretBounds.height!==12)throw new Error("degenerate range bounds");')
 nativeRects={}
 runtime:Run('const emptyBounds=range.getBoundingClientRect();if(emptyBounds.x||emptyBounds.y||emptyBounds.width||emptyBounds.height)throw new Error("empty range bounds");')
 assert(#diagnostics==0,table.concat(diagnostics,'\n'))
 local held=runtime.VM.Global.Bindings.held.Value;local method=runtime.VM.Get(held,'collapse');local vm=runtime.VM
 runtime:Destroy();assert(adapter.Destroyed and not runtime.Selection.Alive and not runtime.Ranges.Alive)
 assert(not pcall(function()vm:Call(method,{},held)end),'Held Selection methods reject a destroyed realm')
 print('Selection tasks: coalescing, trusted events, canceled native actions, stable-boundary paint, no layout, clone rejection and disposal passed')
end
