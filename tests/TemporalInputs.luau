--!strict
return function(T,Edit,Popup,Parser,Node,State,FormModel,Events,Runtime,loadRenderTree,loadWordLayout,loadBlockLayout,html,app,Controller)
	assert(T.number("date","1970-01-01")==0)
	assert(T.number("date","2024-02-29") and not T.number("date","2023-02-29") and not T.number("date","1900-02-29") and T.number("date","2000-02-29"))
	assert(not T.number("date","2026-10-1") and not T.number("date","0000-01-01"))
	assert(T.number("month","1970-01")==0 and T.number("month","1969-12")==-1)
	assert(T.number("week","1970-W01")==T.WeekBase and not T.number("week","2021-W53") and T.number("week","2020-W53"))
	assert(T.format("week",T.number("date","2021-01-01"))=="2020-W53")
	assert(T.number("time","23:59:59.999")==T.Day-1 and not T.number("time","24:00") and not T.number("time","12:00:60"))
	assert(T.sanitize("datetime-local","2026-10-12 14:30:00.000")=="2026-10-12T14:30")
	for y=1,2400,17 do for m=1,12 do
		local n=T.dayNumber(y,m,T.days(y,m));local yy,mm,dd=T.civil(n);assert(yy==y and mm==m and dd==T.days(y,m))
		local wy,w=T.isoWeek(n);assert(n>=T.weekStart(wy)+(w-1)*7 and n<T.weekStart(wy)+w*7)
	end end
	local c=State.create(Node.element("input",{type="date",value="2026-10-12",min="2026-10-01",max="2026-10-31"}))
	assert(c.Type=="date" and c.Value=="2026-10-12" and T.step(c,1)=="2026-10-13")
	c.Value="2026-10-31";assert(T.step(c,1)==c.Value);c.Value="2026-11-03";assert(T.step(c,1)==nil)
	local overnight=State.create(Node.element("input",{type="time",min="22:00",max="02:00",value="23:30"}))
	local under,over=T.flags(overnight);assert(not under and not over);overnight.Value="12:00";under,over=T.flags(overnight);assert(under and over)
	local date=Parser.parseDocument('<form><input id="d" type="date" value="2026-10-12" min="2026-10-01" max="2026-10-31"><input id="m" type="month" value="2026-10"><input id="w" type="week" value="2026-W42"><input id="t" type="time" value="14:30" step="900"><input id="dt" type="datetime-local" value="2026-10-12T14:30" step="1800"><input id="f" type="file" value="forbidden"><input id="image" type="image" name="picture" src="request.svg" width="480" height="200"></form>')
	local objects={};local function signal()
		local callbacks={};return {Connect=function(_,callback)local connection={Connected=true};function connection:Disconnect()self.Connected=false end;table.insert(callbacks,{connection,callback});return connection end,Fire=function(_,...)for _,pair in callbacks do if pair[1].Connected then pair[2](...)end end end}
	end
	local function create(class,parent,props)
		local values={Parent=parent,ClassName=class,Visible=true,CanvasPosition=Vector2.new(0,0)};for k,v in props do values[k]=v end
		local gui;gui=setmetatable({}, {__index=function(_,key)
			if key=="AbsolutePosition" then
				if values.AbsolutePosition then return values.AbsolutePosition end
				local p=values.Parent and values.Parent.AbsolutePosition or Vector2.new(0,0);local sz=values.Parent and values.Parent.AbsoluteSize or Vector2.new(0,0);local position=values.Position or {0,0}
				local scroll=values.Parent and values.Parent.ClassName=="ScrollingFrame" and values.Parent.CanvasPosition or Vector2.new(0,0)
				return Vector2.new(p.X+position[1]+(position.XScale or 0)*sz.X-scroll.X,p.Y+position[2]+(position.YScale or 0)*sz.Y-scroll.Y)
			elseif key=="AbsoluteSize" then if values.AbsoluteSize then return values.AbsoluteSize end;local sz=values.Parent and values.Parent.AbsoluteSize or Vector2.new(0,0);local size=values.Size or {0,0};return Vector2.new(size[1]+(size.XScale or 0)*sz.X,size[2]+(size.YScale or 0)*sz.Y) end
			return values[key]
		end,__newindex=function(_,key,value)values[key]=value end})
		function values:GetPropertyChangedSignal()return signal()end
		function values:Destroy()values.Destroyed=true end
		function values:IsA(kind)return class==kind end
		table.insert(objects,gui);return gui
	end
	local factory={create=create,modifier=create};local parent=create("Frame",nil,{AbsoluteSize=Vector2.new(480,300),AbsolutePosition=Vector2.new(10,20)})
	local root=create("Frame",parent,{AbsoluteSize=Vector2.new(480,300),AbsolutePosition=Vector2.new(10,20)})
	local tree=loadRenderTree(factory).build(date,root,error,function(font)return font end,nil,nil,nil,"input{display:block}")
	local overrides={["Layout/TextMeasure"]={measure=function(text,_,size)return Vector2.new(#text*7,size)end},["Layout/FontProfiles"]={face=function(font)return font end}}
	local words=loadWordLayout(overrides);overrides["Layout/WordLayout"]=words;loadBlockLayout(overrides).arrange(tree,480,0,0,function()return true end)
	local byId={};for _,control in tree.Controls do byId[control.Node.Attributes.id]=control end
	assert(byId.d.Item.TemporalIcon and not byId.d.Item.Editor and byId.f.Item.FileButton and byId.f.Value=="")
	assert(byId.image.Item.ImageGui==nil and byId.image.Item.ErrorGui and byId.image.Item.BoxWidth==480 and byId.image.Item.BoxHeight==200)
	local events=Events.new(error);local layoutChanges,inputs,changes=0,0,0
	local model=FormModel.new(date,tree.Controls,events,function(_,layout)if layout then layoutChanges+=1 end end)
	events:On(byId.d.Node,"input",function()inputs+=1 end);events:On(byId.d.Node,"change",function()changes+=1 end)
	local popup=Popup.new({Alive=true,Root=root},function(control,value)local before=control.Value;model:SetValue(control,value,true);if before~=control.Value then model:Emit(control,"change")end end,factory)
	local original=byId.d.Item.Gui;assert(popup:Open(byId.d));assert(popup.Control==byId.d)
	local function clickText(text)
		for i=#objects,1,-1 do local gui=objects[i]
			if gui.Text==text and gui.Parent and gui.Parent.Name=="PickerContent" and not gui.Parent.Destroyed then
				local p=gui.AbsolutePosition;local event={Position=Vector2.new(p.X+4,p.Y+4)};assert(popup:Begin(event));assert(popup:Finish(event));return
			end
		end;error("Picker button missing: "..text)
	end
	local function currentPopupParts()
		for i=#objects,1,-1 do local gui=objects[i];if gui.Name=="Stunden" and gui.Parent and not gui.Parent.Destroyed then return gui.Parent.Parent,gui.Parent,gui end end
		error("Time column missing")
	end
	-- Datetime is one horizontal chooser; selecting a time preserves its date.
	popup:Close();assert(popup:Open(byId.dt))
	local chooser,pickerContent,hours=currentPopupParts()
	assert(chooser.AbsoluteSize.X==420 and chooser.AbsoluteSize.Y==286)
	assert(hours.AbsolutePosition.X-pickerContent.AbsolutePosition.X==280 and hours.AbsolutePosition.Y-pickerContent.AbsolutePosition.Y==32)
	local originalDateTimeGui=byId.dt.Item.Gui
	for i=#objects,1,-1 do local gui=objects[i];if gui.Text=="15" and gui.Parent==hours then local pos=gui.AbsolutePosition;local event={Position=Vector2.new(pos.X+4,pos.Y+4)};assert(popup:Begin(event));assert(popup:Finish(event));break end end
	assert(byId.dt.Value=="2026-10-12T15:30" and byId.dt.Item.Gui==originalDateTimeGui and layoutChanges==0)
	chooser,pickerContent,hours=currentPopupParts();assert(hours.AbsolutePosition.Y-pickerContent.AbsolutePosition.Y==32)
	clickText("Oktober 2026");chooser,pickerContent,hours=currentPopupParts();assert(chooser.AbsoluteSize.X==420 and hours.AbsolutePosition.X-pickerContent.AbsolutePosition.X==280,"Month navigation must retain time beside the calendar")
	clickText("Nov");assert(byId.dt.Value=="2026-10-12T15:30","Browsing months must not commit a new date")
	root.AbsoluteSize=Vector2.new(320,300);assert(popup:Open(byId.dt));chooser,pickerContent,hours=currentPopupParts()
	assert(chooser.AbsoluteSize.X==320 and pickerContent.CanvasSize[1]==420 and pickerContent.ScrollingDirection==Enum.ScrollingDirection.XY)
	pickerContent.CanvasPosition=Vector2.new(100,0)
	assert(hours.AbsolutePosition.X-pickerContent.AbsolutePosition.X==180,"Narrow chooser must scroll to time columns without stacking")
	for i=#objects,1,-1 do local gui=objects[i];if gui.Text=="16" and gui.Parent==hours then local pos=gui.AbsolutePosition;local event={Position=Vector2.new(pos.X+4,pos.Y+4)};assert(popup:Begin(event));assert(popup:Finish(event));break end end
	chooser,pickerContent,hours=currentPopupParts();assert(byId.dt.Value=="2026-10-12T16:30" and pickerContent.CanvasPosition.X==100,"Time selection must preserve horizontal scrolling")
	pickerContent.CanvasPosition=Vector2.new(0,0);for _=1,5 do assert(popup:Tab(false)) end
	assert(pickerContent.CanvasPosition.X>0,"Keyboard focus must reveal the clipped time column")
	popup:Close();root.AbsoluteSize=Vector2.new(480,300);assert(popup:Open(byId.d))
	clickText("13");assert(byId.d.Value=="2026-10-13" and inputs==1 and changes==1 and layoutChanges==0 and byId.d.Item.Gui==original)
	assert(popup:Open(byId.d));assert(popup:Key("Right"));assert(popup:Key("Return"));assert(byId.d.Value=="2026-10-14" and popup.Control==nil)
	assert(popup:Open(byId.m));clickText("Nov");assert(byId.m.Value=="2026-11" and popup.Control==nil)
	assert(popup:Open(byId.w));assert(popup:Key("Down"));assert(popup:Key("Return"));assert(byId.w.Value=="2026-W43")
	assert(popup:Open(byId.t));assert(popup:Key("Escape") and popup.Control==nil)
	assert(popup:Open(byId.m));assert(popup:Key("Right"));assert(popup:Key("Return"));assert(byId.m.Value=="2026-12")
	assert(popup:Open(byId.d));assert(popup:Tab(false));assert(popup:Key("Escape") and popup.Control==nil)
	byId.d.ReadOnly=true;assert(not popup:Open(byId.d));byId.d.ReadOnly=false
	byId.d.TemporalSegment=1;assert(Edit.change(byId.d,"Delete",model));assert(byId.d.Value=="" and byId.d.BadInput)
	model:Reset(byId.d.Form);assert(byId.d.Value=="2026-10-12" and not byId.d.BadInput and not byId.d.TemporalParts)
	byId.t.Node.Attributes.step="0.001";byId.t.Temporal=T.read("time",byId.t.Node.Attributes);model:SetValue(byId.t,"14:30:10.123")
	assert(#Edit.fields(byId.t)==4 and Edit.parts(byId.t).millisecond==123)
	byId.t.TemporalSegment=4;assert(Edit.change(byId.t,"Up",model));assert(byId.t.Value=="14:30:10.124")
	byId.t.Node.Attributes.min="22:00";byId.t.Node.Attributes.max="02:00";byId.t.Temporal=T.read("time",byId.t.Node.Attributes);model:SetValue(byId.t,"23:00")
	assert(popup:Open(byId.t));local allowedHour=false
	for i=#objects,1,-1 do local gui=objects[i];if gui.Text=="00" and gui.Parent and gui.Parent.Name=="Stunden" and not gui.Parent.Destroyed then gui.Parent.CanvasPosition=Vector2.new(0,0);local pos=gui.AbsolutePosition;local event={Position=Vector2.new(pos.X+4,pos.Y+4)};local hit=popup:Hit(event.Position);if hit and hit.Gui==gui then popup:Begin(event);popup:Finish(event);allowedHour=byId.t.Value=="00:00";break end end end
	assert(allowedHour,"Overnight time picker must allow the midnight hour");popup:Close()
	local data
	events:On(byId.image.Form,"submit",function(event)data=event.Data.Entries end)
	local image=byId.image.Item.BoxGui;local p=image.AbsolutePosition
	model:Activate(byId.image,nil,false,{screenX=p.X+23,screenY=p.Y+17});assert(data[#data-1].Value=="23" and data[#data].Value=="17")
	model:Destroy();popup:Close()
	-- Route real native movement through Controller: the temporal picker must
	-- receive hover even while the unrelated select popup is closed.
	local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox()return nil end;function input:IsKeyDown()return false end
	local page={Document=date,Root=root,Alive=true};function page:AddCleanup(fn)self.Cleanup=fn end
	local cleanup=Controller.start(page,tree,function()error("Popup hover must not request page layout")end,error,{Input=input,Factory=factory,PlayerGui={GetGuiObjectsAtPosition=function()return {}end}})
	page.FormModel:OpenTemporal(byId.dt)
	local hovered
	for i=#objects,1,-1 do local gui=objects[i];if gui.Text=="13" and gui.Parent and gui.Parent.Name=="PickerContent" and not gui.Parent.Destroyed then hovered=gui;break end end
	assert(hovered and hovered.BackgroundTransparency==1)
	local pageMoves=0;page:On("mousemove",function()pageMoves+=1 end)
	local pos=hovered.AbsolutePosition;input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position=Vector2.new(pos.X+4,pos.Y+4)})
	assert(hovered.BackgroundTransparency==0 and pageMoves==0,"Native calendar hover must paint locally")
	input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position=Vector2.new(-10,-10)})
	assert(hovered.BackgroundTransparency==1,"Leaving calendar cell must restore its appearance")
	cleanup()
	-- Execute the actual page script, rather than a second imitation of its logic.
	local document=Parser.parseDocument(html);local controls,byNode={},{}
	local function visit(node)if node.Name=="input" or node.Name=="button" or node.Name=="select" or node.Name=="textarea" or node.Name=="output" then local state=State.create(node);table.insert(controls,state);byNode[node]=state end;for _,child in node.Children do visit(child)end end;visit(document)
	local pageEvents=Events.new(error);local pageModel=FormModel.new(document,controls,pageEvents,function()end)
	local time=100;local diagnostics={}
	local runtime=Runtime.new(document,{Clock=function()return time end,Events=pageEvents,URL="http://localhost:8000/input-types/index.html",ScriptSources={["http://localhost:8000/input-types/app.js"]=app},ControlAdapter={Events=pageEvents,ResolveControl=function(node)return byNode[node]end,SetControlValue=function(node,value)pageModel:SetValue(byNode[node],value)end,ActivateControl=function(node)pageModel:Activate(byNode[node],nil,true)end,ResetForm=function(form)return pageModel:Reset(form)end,RequestSubmit=function(form,submitter)pageModel:Submit(form,byNode[submitter],true)end},Schedule=function()end,ApplyChanges=function()return false end,Diagnostic=function(message)table.insert(diagnostics,message)end})
	runtime:Start();runtime:PumpTasks();runtime:Flush();assert(#diagnostics==0,table.concat(diagnostics," | "))
	local function run(source)local ok,err=runtime:Run(source);assert(ok,tostring(err));runtime:Flush();assert(#diagnostics==0,table.concat(diagnostics," | "))end
	run([==[const d=document.getElementById('arrival');if(d.type!=='date'||d.valueAsDate.toISOString()!=='2026-10-12T00:00:00.000Z')throw Error('Date');d.stepUp();if(d.value!=='2026-10-13')throw Error('Step');d.valueAsNumber=Date.UTC(2024,1,29);if(d.value!=='2024-02-29'||!d.validity.rangeUnderflow)throw Error('Limits');d.valueAsDate=new Date('2026-10-12T18:00:00Z');if(d.value!=='2026-10-12')throw Error('UTC');d.value='bad';if(d.value!==''||!d.validity.valueMissing)throw Error('Sanitize');d.form.reset();]==])
	run([==[for(const [id,expected] of [['arrival','2026-10-13'],['appointment','2026-10-12T15:00'],['travel-month','2026-11'],['travel-week','2026-W43'],['meeting-time','14:45']]){const field=document.getElementById(id);field.form.querySelector('[data-step="1"]').click();if(field.value!==expected)throw Error(id+': '+field.value);field.form.reset();}if(document.getElementById('document-file').files.length!==0)throw Error('Files');]==])
	run([==[let caught=false;try{document.getElementById('document-file').value='secret.txt'}catch(e){caught=e.name==='InvalidStateError'}if(!caught)throw Error('File assignment');const t=document.getElementById('meeting-time');t.value='14:31';if(!t.validity.stepMismatch)throw Error('Step mismatch');t.value='14:30';const dt=document.getElementById('appointment');if(dt.valueAsDate!==null)throw Error('Local Date');caught=false;try{dt.valueAsDate=new Date()}catch(e){caught=e.name==='InvalidStateError'}if(!caught)throw Error('Local Date setter');]==])
	run([==[const fileInput=document.getElementById('document-file');const emptyFile=new FormData(fileInput.form).get(fileInput.name);if(!(emptyFile instanceof File)||emptyFile.size!==0||emptyFile.name!=='')throw Error('Empty file');const changed=document.createElement('input');changed.value='secret';changed.type='file';if(changed.value!==''||changed.files.length!==0)throw Error('Type switch');changed.required=true;changed.readOnly=true;if(changed.willValidate||!changed.validity.valueMissing)throw Error('File readonly');const imageSubmit=document.querySelector('input[type="image"]');const imageData=new FormData(imageSubmit.form,imageSubmit);if(imageData.get('anfrage.x')!=='0'||imageData.get('anfrage.y')!=='0')throw Error('Image FormData');]==])
	runtime:Destroy();pageModel:Destroy();pageEvents:Destroy();events:Destroy()
end
