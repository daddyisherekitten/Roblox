--!strict
return function(Parser,Runtime,VM,Events,Selection,State,Strings,fixtures)
	local failures={}
	for _,fixture in fixtures do
		local values,diagnostics={},{ }
		local events=Events.new(error)
		local runtime=Runtime.new(Parser.parseDocument('<html><head></head><body></body></html>'),{Events=events,ControlAdapter={Events=events},
			Console=function(_,value)table.insert(values,value)end,Diagnostic=function(message)table.insert(diagnostics,message)end})
		runtime:Run('function record(value){console.log(String(value));}\n'..(if fixture.async then '(async()=>{ '..fixture.source..' })();'else fixture.source))
		runtime:PumpTasks()
		if #diagnostics>0 or #values~=#fixture.expected then table.insert(failures,fixture.name..': '..table.concat(diagnostics,' / ')..' actual='..table.concat(values,' | '))
		else for i,value in values do if value~=fixture.expected[i]then table.insert(failures,fixture.name..' ['..i..']: '..value..' ~= '..fixture.expected[i])end end end
		runtime:Destroy();events:Destroy()
	end
	for _,message in failures do print('Text selection mismatch: '..message)end
	assert(#failures==0,'Text selection fixture failures: '..#failures)
	-- The native editor API counts UTF-8 bytes, including multibyte text/emoji.
	local text='Aä😀Z'
	assert(Selection.toByte(text,0)==1 and Selection.toByte(text,1)==2 and Selection.toByte(text,2)==4 and Selection.toByte(text,3)==4 and Selection.toByte(text,4)==8 and Selection.toByte(text,5)==9)
	assert(Selection.fromByte(text,1)==0 and Selection.fromByte(text,2)==1 and Selection.fromByte(text,4)==2 and Selection.fromByte(text,8)==4 and Selection.fromByte(text,9)==5)
	local document=Parser.parseDocument('<html><body><input id="i" value="Aä😀Z"></body></html>')
	local node=document.Children[1].Children[2].Children[1]
	local c=State.create(node);local notifications=0
	c.SelectionChanged=function()notifications+=1 end
	c.Item={Editor={Text=text,CursorPosition=-1,SelectionStart=-1}};c.Focused=true
	Selection.set(c,1,4,'backward');Selection.paint(c)
	assert(c.Item.Editor.CursorPosition==2 and c.Item.Editor.SelectionStart==8)
	assert(not Selection.read(c) and c.SelectionDirection=='backward')
	Selection.set(c,3,3,'forward');Selection.paint(c)
	assert(c.Item.Editor.CursorPosition==4 and not Selection.read(c) and c.SelectionStart==3,'Native projection cannot erase an exact interior UTF16 offset')
	c.Item.Editor.CursorPosition,c.Item.Editor.SelectionStart=9,4
	assert(Selection.read(c) and c.SelectionStart==2 and c.SelectionEnd==5 and c.SelectionDirection=='forward')
	c.Item.Editor.CursorPosition,c.Item.Editor.SelectionStart=-1,-1
	assert(not Selection.read(c) and c.SelectionStart==2 and c.SelectionEnd==5,'Blur retains the stored DOM extent')
	c.Item.Editor.CursorPosition=4;c.SelectionWriting=true
	assert(not Selection.read(c),'Native halfway property writes never emit transient states');c.SelectionWriting=false
	local lone=Strings.fromUnits({0x41,0xd800,0x42})
	assert(Selection.nativeText(lone)=='A�B' and #Strings.units(lone)==3 and State.limit(lone,2)==lone:sub(1,4))
	-- Queued tasks on a disposed page neither notify listeners nor retain callback
	-- hooks on a native control that outlives its JavaScript realm.
	local events=Events.new(error);local diagnostics={};local native=State.create(node);local count=0
	local runtime=Runtime.new(document,{Events=events,ControlAdapter={Events=events,ResolveControl=function()return native end},Diagnostic=function(message)table.insert(diagnostics,message)end})
	events:On(node,'select',function()count+=1 end)
	runtime:Run("document.getElementById('i').setSelectionRange(1,4,'backward')")
	assert(runtime.EventLoop.TaskCount>0 and native.SelectionChanged~=nil)
	runtime:Destroy()
	assert(native.SelectionChanged==nil and count==0 and #diagnostics==0,'Disposal clears native callback hooks and pending selection tasks')
	events:Destroy()
	print('JavaScript text-control selection: '..#fixtures..' semantics fixtures, native UTF8/UTF16 mapping and disposal passed')
end
