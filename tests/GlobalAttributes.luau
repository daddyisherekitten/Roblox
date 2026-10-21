--!strict
return function(Parser,Runtime,VM,Events,fixture)
	local raw,form,tree,types,descriptors,reactions=0,0,0,0,0,0
	for _,case in fixture.cases do
		local document=Parser.parseDocument(case.html);local events=Events.new(error)
		local runtime=Runtime.new(document,{Events=events,ControlAdapter={},Schedule=function()end})
		local ok,message=runtime:Run('globalThis.attributeResult='..case.action)
		assert(ok,case.name..': '..tostring(message))
		local actual=runtime.Window.Get('attributeResult')
		if case.await then
			local settled=false
			runtime.Promises:Await(actual,function(args)actual=args[1];settled=true end,function(args)error(case.name..': '..VM.string(args[1]))end)
			for _=1,100 do runtime:PumpTasks();runtime.EventLoop:Checkpoint();if settled then break end end
			assert(settled,case.name..': microtasks did not settle')
		end
		local expected=case.specExpected or case.expected
		assert(actual==expected,case.name..'\nexpected '..expected..'\nactual '..tostring(actual))
		assert(#runtime.Diagnostics==0,case.name..': '..table.concat(runtime.Diagnostics,' | '))
		runtime:Destroy();events:Destroy()
		if case.name:find('raw/set',1,true)then raw+=1
		elseif case.name:find('form inheritance',1,true)then form+=1
		elseif case.name:find('tree and shadow',1,true)then tree+=1
		elseif case.name:find('input type',1,true)then types+=1
		elseif case.name:find('descriptors and receiver',1,true)then descriptors+=1
		elseif case.name=='global attribute reactions and mutation order'then reactions+=1 end
	end
	assert(raw==21,'Global editing hints raw getter/setter conversions')
	assert(form==27,'Form-associated editing hints live defaults and overrides')
	assert(tree==3,'Global editing hints parent and shadow inheritance')
	assert(types==8,'Autocorrect input type restrictions and transitions')
	assert(descriptors==3,'HTMLElement descriptors and receiver branding')
	assert(reactions==1,'Global editing hints custom reactions and mutation ordering')
	print('Global editing attributes: '..#fixture.cases..' native cases (two explicit normative differences); IDL, defaults, form ownership, inheritance, branding and reactions passed')
end
