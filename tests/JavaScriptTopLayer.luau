--!strict
return function(Parser,Runtime,VM,Events,fixtures)
	local failures={}
	for _,fixture in fixtures do
		local values,diagnostics={},{}
		local events=Events.new(error)
		local document=Parser.parseDocument('<html><head></head><body><button id="s">Source</button><dialog id="d"></dialog><div id="p" popover="auto"><button id="inside">Nested source</button></div><div id="q" popover="auto"></div><div id="m" popover="manual"></div><div id="h" popover="hint"></div></body></html>')
		local states={}
		local runtime=Runtime.new(document,{Events=events,States=states,
			Console=function(_,value)table.insert(values,value)end,Diagnostic=function(message)table.insert(diagnostics,message)end,
			CreateTopLayerAdapter=function()
				return {UpdateDialog=function(_,node,s)states.modal=states.modal or {};states.modal[node]=s.Open and s.Modal end,
					UpdatePopover=function(_,node,s)states['popover-open']=states['popover-open']or {};states['popover-open'][node]=s.Open end}
			end})
		runtime:Run('function record(value){console.log(String(value));}\n'..fixture.source)
		while runtime.EventLoop.TaskCount>0 do runtime:PumpTasks()end
		if #diagnostics>0 or #values~=#fixture.expected then table.insert(failures,fixture.name..': '..table.concat(diagnostics,' / ')..' actual='..table.concat(values,' | '))
		else for i,value in values do if value~=fixture.expected[i]then table.insert(failures,fixture.name..' ['..i..']: '..value..' ~= '..fixture.expected[i])end end end
		runtime:Destroy();events:Destroy()
	end
	for _,message in failures do print('Top layer mismatch: '..message)end
	assert(#failures==0,'Dialog/popover fixture failures: '..#failures)
	-- A missing id does not make every ordinary element into its invoker;
	-- pointer endpoint matching still distinguishes an inside/outside drag.
	local document=Parser.parseDocument('<html><body><div popover="auto"><button>Inside</button></div><button>Outside</button></body></html>')
	local body=document.Children[1].Children[2];local anonymous,outside=body.Children[1],body.Children[2]
	local events=Events.new(error);local diagnostics={}
	local runtime=Runtime.new(document,{Events=events,MaxSteps=200000,Diagnostic=function(value)table.insert(diagnostics,value)end,
		CreateTopLayerAdapter=function()return {ContainsPoint=function()return false end}end})
	local api=runtime.TopLayer;local position=Vector2.new(1,1)
	assert(api:NativeAction('show-popover',anonymous))
	api:PointerDown(position,outside);api:PointerUp(position,anonymous.Children[1])
	assert(api:Snapshot(anonymous).PopoverOpen,'Dragging from outside to inside does not light-dismiss')
	api:PointerDown(position,outside);api:PointerUp(position,outside)
	assert(not api:Snapshot(anonymous).PopoverOpen,'An anonymous auto popover light-dismisses on an ordinary outside click')
	runtime:Run("const p=document.querySelector('[popover]');for(let i=0;i<1100;i++){p.togglePopover();}")
	assert(#diagnostics==0 and runtime.EventLoop.TaskCount==1,'Rapid toggle coalescing retains one task instead of exhausting the task queue: '..table.concat(diagnostics,' | '))
	runtime:Run("let closingEvents=0;p.showPopover();p.addEventListener('beforetoggle',e=>{if(e.newState==='closed'){closingEvents++;p.popover=null;}});p.hidePopover();if(closingEvents!==1)throw new Error('Nested closing notification');")
	assert(#diagnostics==0 and not api:Snapshot(anonymous).PopoverOpen,'Removing the attribute in closing beforetoggle cleans up without duplicate closing callbacks')
	runtime:Destroy();events:Destroy()
	print('JavaScript top layer: '..#fixtures..' shared native-browser dialog/popover/ToggleEvent fixtures passed')
end
