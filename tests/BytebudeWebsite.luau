--!strict
-- The actual delivered script, persistent local state and responsive engine layout.
return function(Parser,Node,Runtime,Events,Storage,loadRenderTree,loadWordLayout,loadBlockLayout,html,css,app)
	local document=Parser.parseDocument(html);assert(#document.Diagnostics==0)
	local function node(id)return assert(Node.findById(document,id),id)end
	local function text(id)return Node.textContent(node(id))end
	local messages={};local events=Events.new(function(value)table.insert(messages,value)end)
	local controls={};for _,id in {'guest-name','guest-message'}do table.insert(controls,require('Controls/State').create(node(id)))end
	local function visit(current)
		if current.Name=='input'and current.Attributes.type=='radio'then table.insert(controls,require('Controls/State').create(current))end
		for _,child in current.Children or {}do visit(child)end
	end;visit(document)
	local model=require('Controls/FormModel').new(document,controls,events,function()end)
	local function control(current)for _,item in controls do if item.Node==current then return item end end end
	local area=Storage.createArea()
	local runtime=Runtime.new(document,{Events=events,URL='http://localhost:8000/bytebude/index.html',
		ScriptSources={['http://localhost:8000/bytebude/app.js']=app},GetStorageArea=function()return area end,
		ControlAdapter={Events=events,FocusControl=function()end,ResolveControl=control,
			SetControlValue=function(n,value)model:SetValue(assert(control(n)),value)end,
			SetControlChecked=function(n,value)model:SetChecked(assert(control(n)),value)end,
			ResetForm=function(form)return model:Reset(form)end},
		GetControl=function(n,key)local c=control(n);if c then return if key=='checked'then c.Checked else c.Value end end,
		SetControl=function(n,key,value)local c=assert(control(n));if key=='checked'then model:SetChecked(c,value)else model:SetValue(c,value)end end,
		Click=function(n)events:Emit(n,'click')end,Schedule=function()end,ApplyChanges=function()return false end,
		Diagnostic=function(value)table.insert(messages,value)end})
	local function run(source)
		local ok,message=runtime:Run(source);assert(ok,tostring(message))
		for _=1,20 do runtime:Flush();if runtime:PumpTasks()==0 then break end end
		runtime:Flush();assert(#messages==0,table.concat(messages,' | '))
	end
	local function click(id)run("document.getElementById('"..id.."').click();")end
	runtime:Start();run('')
	assert(runtime.ScriptsRun==1 and text('visit-count')=='000001'and text('guest-count')=='2 Einträge')
	assert(runtime.EventLoop.TimerCount==0,'The retro homepage does not need a running animation or clock loop')
	click('theme-toggle');assert(node('theme-toggle').Attributes['aria-pressed']=='true'and text('theme-toggle')=='Tagmodus')
	click('theme-toggle');assert(node('theme-toggle').Attributes['aria-pressed']=='false')
	click('tab-links');assert(node('panel-links').Attributes.hidden==nil and node('panel-news').Attributes.hidden~=nil)
	run("document.getElementById('tab-links').dispatchEvent(new KeyboardEvent('keydown',{key:'ArrowRight'}));")
	assert(node('tab-about').Attributes['aria-selected']=='true'and node('panel-about').Attributes.hidden==nil)
	click('tab-news');assert(node('panel-about').Attributes.hidden~=nil)
	for _=1,5 do click('next-find')end;assert(text('find-number')=='DISKETTE 01 / 05')
	click('next-find');assert(text('find-number')=='DISKETTE 02 / 05'and text('find-title')=='Das Geräusch einer neuen Nachricht.')
	run("document.getElementById('poll-form').dispatchEvent(new Event('submit',{bubbles:true,cancelable:true}));")
	assert(text('poll-result')=='Bitte wähle erst eine Antwort.')
	run("document.querySelector('input[value=\"games\"]').checked=true;document.getElementById('poll-form').dispatchEvent(new Event('submit',{bubbles:true,cancelable:true}));")
	assert(text('poll-result'):find('Noch eine Runde',1,true))
	run("document.getElementById('guest-name').value='   ';document.getElementById('guest-message').value='  ';document.getElementById('guest-form').dispatchEvent(new Event('submit',{cancelable:true}));")
	assert(text('guest-count')=='2 Einträge'and text('guest-status'):find('Bitte',1,true))
	run("document.getElementById('guest-name').value='pixeltester';document.getElementById('guest-message').value='<img src=x> Hallo!';document.getElementById('guest-message').dispatchEvent(new Event('input'));document.getElementById('guest-form').dispatchEvent(new Event('submit',{cancelable:true}));")
	assert(text('guest-count')=='3 Einträge'and text('guest-status'):find('gespeichert',1,true))
	assert(control(node('guest-name')).Value==''and control(node('guest-message')).Value=='','The form reset clears native control values')
	local firstEntry=Node.findElement(node('guest-entries'),function(n)return n.Name=='article'end)
	assert(Node.textContent(firstEntry):find('<img src=x> Hallo!',1,true),'Guest text is textContent, never HTML')
	for i=1,13 do
		run("document.getElementById('guest-name').value='Gast';document.getElementById('guest-message').value='Gruß "..i.."';document.getElementById('guest-form').dispatchEvent(new Event('submit',{cancelable:true}));")
		if i==1 then local entries={};for _,n in node('guest-entries').Children do if n.Kind=='Element'then table.insert(entries,n)end end;assert(entries[2]==firstEntry,'An unchanged guest entry retains its DOM identity')end
	end
	local entryCount=0;for _,n in node('guest-entries').Children do if n.Kind=='Element'then entryCount+=1 end end
	assert(text('guest-count')=='14 Einträge'and entryCount==14,'The local guestbook is bounded to 12 personal and two archived entries')
	run("window.savedGuests=JSON.parse(localStorage.getItem('bytebude.v1.guests')).length;window.savedPoll=JSON.parse(localStorage.getItem('bytebude.v1.poll'));")
	assert(runtime.Window.Get('savedGuests')==12 and runtime.Window.Get('savedPoll')=='games')
	local factory={create=function(class,parent,properties)
		local gui=table.clone(properties);gui.Parent=parent;gui.ClassName=class;gui.Visible=gui.Visible~=false;gui.Destroy=function()end
		gui.Position=gui.Position or UDim2.fromOffset(0,0);gui.AnchorPoint=gui.AnchorPoint or Vector2.new(0,0)
		gui.BackgroundColor3=gui.BackgroundColor3 or Color3.new(1,1,1);gui.BackgroundTransparency=gui.BackgroundTransparency or 1;gui.ZIndex=gui.ZIndex or 1
		local attributes={};function gui:SetAttribute(name,value)attributes[name]=value end;function gui:GetAttribute(name)return attributes[name]end
		function gui:IsA(kind)return kind==class or kind=='GuiObject'end;return gui
	end}
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(value,_,size)return{X=(utf8.len(value)or 0)*size*.45,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	for _,width in {360,800,1120}do
		local warnings={};local tree=renderer.build(document,factory.create('Frame',nil,{AbsoluteSize=Vector2.new(width,900)}),function(value)table.insert(warnings,value)end,nil,nil,nil,function()return 'rbxassetid://1'end,nil,nil,nil,nil,nil,{['styles.css']=css},'http://localhost:8000/bytebude/index.html')
		assert(#warnings==0,table.concat(warnings,' | '));tree:SetMediaEnvironment(width,900);layout.arrange(tree,width,0,0,function()return true end)
		assert(tree.OuterHeight>900 and tree.OuterHeight<15000,'The document has a finite usable height at '..width)
		assert(tree.NodeBoxes[node('inhalt')].OuterWidth<=width+.01,'The main column fits the viewport at '..width)
		for _,id in {'theme-toggle','next-find','guest-name','guest-message','poll-form'}do
			local found=tree.NodeBoxes[node(id)]~=nil;for _,c in tree.Controls do if c.Node==node(id)then found=true end end
			assert(found,'Usable content remains mounted: '..id)
		end
		if tree.VisualEffects then tree.VisualEffects:Destroy()end
	end
	runtime:Destroy();model:Destroy();events:Destroy()
	print('Bytebude: actual defer script, tabs/keyboard, theme, bounded safe local guestbook, poll, finds, controls and three responsive engine layouts passed')
end
