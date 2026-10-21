--!strict
local T=require(script.Parent.Parent.Controls.TemporalValue)
local Edit=require(script.Parent.Parent.Controls.TemporalEdit)
local Popup={}
local BLUE=Color3.fromRGB(0,117,255)
function Popup.new(page: any,choose: any,factory: any?): any
	local self={Control=nil};local host;local panel;local entries={};local connections={};local down
	local year,month,day,mode=1970,1,0,"days";local columns={};local highlighted;local keyboardEntry
	local function active()return page.Alive and self.Control and not self.Control.Disabled and not self.Control.ReadOnly end
	function self:Close()
		local previous=self.Control
		for _,connection in connections do connection:Disconnect() end;table.clear(connections)
		self.Control=nil;down=nil;highlighted=nil;keyboardEntry=nil;table.clear(entries);table.clear(columns)
		if host then host:Destroy();host=nil;panel=nil end
		if previous and page.SetControlPickerOpen then page:SetControlPickerOpen(previous,false)end
	end
	local function label(parent,text,x,y,w,h,color)
		return factory.create("TextLabel",parent,{Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),TextSize=14,FontFace=self.Control.Item.FontFace or Font.fromEnum(Enum.Font.Arial),TextColor3=color or Color3.fromRGB(32,33,36),TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center})
	end
	local function button(parent,text,x,y,w,h,action,enabled,selected)
		local gui=label(parent,text,x,y,w,h,if enabled==false then Color3.fromRGB(180,180,180) elseif selected then Color3.new(1,1,1) else nil)
		gui.BackgroundColor3=if selected then BLUE else Color3.fromRGB(235,241,250);gui.BackgroundTransparency=if selected then 0 else 1
		factory.modifier("UICorner",gui,{CornerRadius=UDim.new(0,3)})
		table.insert(entries,{Gui=gui,Action=action,Enabled=enabled~=false,Selected=selected})
		return gui
	end
	local draw
	local function setDate(n)
		local c=self.Control;if not active() then return end
		if c.Type=="datetime-local" then n+= (T.number(c.Type,c.Value) or c.Temporal.Min or 0)%T.Day end
		local test={Type=c.Type,Value=T.format(c.Type,n),Temporal=c.Temporal};local under,over=T.flags(test)
		if under or over then return end
		local value=T.format(c.Type,n)
		choose(c,value)
		if not active() then return end
		if c.Type=="datetime-local" then day=math.floor(n/T.Day);draw() else self:Close() end
	end
	local function inRange(n,span)
		local c=self.Control;local r=c.Temporal
		if c.Type=="time" and r.Min and r.Max and r.Min>r.Max then return n<=r.Max or n+span>=r.Min end
		return (not r.Min or n+span>=r.Min) and (not r.Max or n<=r.Max)
	end
	local function navigate(delta)
		local total=year*12+month-1+delta;year=math.clamp(math.floor(total/12),1,275760);month=total%12+1;draw()
	end
	local function timeColumns(x,y,totalWidth,height)
		local c=self.Control;local n=T.number(c.Type,c.Value) or c.Temporal.Min or 0;local time=n%T.Day
		local specs={{Name="Stunden",Count=24,Unit=3600000,Selected=math.floor(time/3600000)},{Name="Minuten",Count=60,Unit=60000,Selected=math.floor(time/60000)%60}}
		if (c.Temporal.Step and c.Temporal.Step%60000~=0) or time%60000~=0 then table.insert(specs,{Name="Sekunden",Count=60,Unit=1000,Selected=math.floor(time/1000)%60}) end
		local width=if totalWidth then totalWidth/#specs else 64
		for index,spec in specs do
			label(panel,spec.Name,x+(index-1)*width,y,width,23,Color3.fromRGB(105,105,105))
			local scroll=factory.create("ScrollingFrame",panel,{Name=spec.Name,Position=UDim2.fromOffset(x+(index-1)*width,y+24),Size=UDim2.fromOffset(width-3,height),CanvasSize=UDim2.fromOffset(0,spec.Count*28),CanvasPosition=Vector2.new(0,math.clamp(spec.Selected*28-56,0,spec.Count*28-height)),ScrollBarThickness=4,ScrollingDirection=Enum.ScrollingDirection.Y})
			table.insert(columns,scroll)
			for value=0,spec.Count-1 do
				local candidate=n-spec.Selected*spec.Unit+value*spec.Unit
				local test={Type=c.Type,Value=T.format(c.Type,candidate),Temporal=c.Temporal};local under,over,mismatch=T.flags(test)
				-- Hours must remain reachable if a valid minute exists in that hour.
				local enabled=if index==1 then inRange(candidate-time%3600000,3599999) else not under and not over and not mismatch
				button(scroll,string.format("%02d",value),0,value*28,width-7,28,function()
					if not active() then return end
					local current=T.number(c.Type,c.Value) or c.Temporal.Min or 0
					local old=math.floor((current%T.Day)/spec.Unit)%(if spec.Unit==3600000 then 24 else 60)
					choose(c,T.format(c.Type,current-old*spec.Unit+value*spec.Unit));if active() then draw() end
				end,enabled,value==spec.Selected)
				entries[#entries].Choice=true
			end
		end
		return x+width*#specs
	end
	draw=function()
		if not host or not active() then self:Close();return end
		local previousScroll=if panel then panel.CanvasPosition else Vector2.new(0,0)
		if panel then panel:Destroy() end;table.clear(entries);table.clear(columns);highlighted=nil;down=nil
		keyboardEntry=nil
		panel=factory.create("ScrollingFrame",host,{Name="PickerContent",Size=UDim2.fromScale(1,1),BackgroundTransparency=0,BackgroundColor3=Color3.new(1,1,1),ScrollBarThickness=5,ScrollingDirection=Enum.ScrollingDirection.Y})
		local c=self.Control
		local title=if mode=="years" then tostring(year-5).." – "..tostring(year+6) elseif mode=="months" or c.Type=="month" then tostring(year) else Edit.Months[month].." "..year
		if c.Type~="time" then
			button(panel,title,12,8,177,30,function()mode=if mode=="days" then "months" elseif mode=="months" then "years" else "days";draw()end,true,false)
			button(panel,"‹",194,8,30,30,function()navigate(if mode=="years" then -144 elseif mode=="months" or c.Type=="month" then -12 else -1)end,year>1 or month>1,false)
			button(panel,"›",228,8,30,30,function()navigate(if mode=="years" then 144 elseif mode=="months" or c.Type=="month" then 12 else 1)end,year<275760,false)
		end
		local contentBottom=40
		if c.Type~="time" and (mode=="months" or mode=="years") then
			for index=1,12 do
				local yy=if mode=="years" then year-6+index else year;local mm=if mode=="years" then month else index
				local n=if c.Type=="month" then (yy-1970)*12+mm-1 else T.dayNumber(yy,mm,1)*T.Day
				local enabled=yy>0 and yy<=275760 and inRange(n,if c.Type=="month" then 0 else T.days(yy,mm)*T.Day-1)
				button(panel,if mode=="years" then tostring(yy) else Edit.Months[index]:sub(1,3),12+(index-1)%3*83,48+math.floor((index-1)/3)*42,77,36,function()
					if mode=="years" then year=yy;mode="months";draw()
					elseif c.Type=="month" then choose(c,T.format("month",n));self:Close()
					else month=mm;mode="days";draw() end
				end,enabled,(if mode=="years" then yy==year else mm==month))
				entries[#entries].Choice=true
			end
			contentBottom=224
		elseif c.Type~="time" then
			local week=c.Type=="week";local cell=if week then 31 else 35;local left=if week then 46 else 12
			for index,name in {"Mo","Di","Mi","Do","Fr","Sa","So"} do label(panel,name,left+(index-1)*cell,43,cell,24,Color3.fromRGB(105,105,105)) end
			local first=T.dayNumber(year,month,1);local start=first-(first+3)%7
			for row=0,5 do
				local monday=start+row*7
				if week then local _,w=T.isoWeek(monday);label(panel,tostring(w),10,70+row*29,30,28,Color3.fromRGB(105,105,105)) end
				for col=0,6 do
					local current=monday+col;local _,mm,dd=T.civil(current)
					local value=if week then monday*T.Day else current*T.Day
					local enabled=inRange(value,if week then T.Week-1 elseif c.Type=="datetime-local" then T.Day-1 else 0)
					local selected=if week then day>=monday and day<monday+7 else day==current
					local gui=button(panel,tostring(dd),left+col*cell,70+row*29,cell-2,27,function()setDate(value)end,enabled,selected)
					entries[#entries].Choice=true
					if mm~=month and not selected and enabled then gui.TextColor3=Color3.fromRGB(145,145,145) end
				end
			end
			contentBottom=248
		end
		local contentWidth=272
		if c.Type=="datetime-local" then
			-- The native desktop chooser places time beside the calendar, including
			-- its month/year views. Independent lists retain their own scrolling.
			contentBottom=math.max(contentBottom,248)
			factory.create("Frame",panel,{Name="CalendarTimeDivider",Position=UDim2.fromOffset(272,8),Size=UDim2.fromOffset(1,contentBottom-8),BackgroundTransparency=0,BackgroundColor3=Color3.fromRGB(225,225,225)})
			contentWidth=timeColumns(280,8,nil,contentBottom-32)+12
		elseif c.Type=="time" then
			timeColumns(10,8,248,154);contentBottom=188
		end
		button(panel,"Löschen",12,contentBottom+2,100,30,function()choose(c,"");self:Close()end,true,false)
		button(panel,if c.Type=="time" then "Fertig" else "Heute",166,contentBottom+2,92,30,function()
			if c.Type=="time" then self:Close();return end
			local now=os.date("*t");local n=if c.Type=="month" then (now.year-1970)*12+now.month-1 else T.dayNumber(now.year,now.month,now.day)*T.Day
			if inRange(n,0) then setDate(n) end
		end,true,false)
		local root=page.Root;local p,size=root.AbsolutePosition,root.AbsoluteSize;local box=c.Item.BoxGui;local bp,bs=box.AbsolutePosition,box.AbsoluteSize
		local parent=host.Parent;local h=math.min(contentBottom+38,math.max(1,size.Y));local w=math.min(contentWidth,math.max(1,size.X))
		host.Size=UDim2.fromOffset(w,h);panel.CanvasSize=UDim2.fromOffset(if contentWidth>w then contentWidth else 0,contentBottom+38)
		panel.ScrollingDirection=if contentWidth>w then Enum.ScrollingDirection.XY else Enum.ScrollingDirection.Y
		panel.CanvasPosition=Vector2.new(math.clamp(previousScroll.X,0,contentWidth-w),math.clamp(previousScroll.Y,0,contentBottom+38-h))
		local x=math.clamp(bp.X,p.X,math.max(p.X,p.X+size.X-w))
		local below=p.Y+size.Y-bp.Y-bs.Y;local y=if below>=h or below>=bp.Y-p.Y then bp.Y+bs.Y else bp.Y-h
		y=math.clamp(y,p.Y,math.max(p.Y,p.Y+size.Y-h))
		host.Position=UDim2.fromOffset(x-parent.AbsolutePosition.X,y-parent.AbsolutePosition.Y)
	end
	function self:Open(c: any)
		self:Close();if not page.Alive or c.Disabled or c.ReadOnly or not T.applies(c.Type) or not c.Item then return false end
		factory=factory or require(script.Parent.Parent.Rendering.GuiFactory)
		local n=T.number(c.Type,c.Value) or c.Temporal.Min
		if not n then local now=os.date("*t");n=if c.Type=="month" then (now.year-1970)*12+now.month-1 else T.dayNumber(now.year,now.month,now.day)*T.Day end
		if c.Type=="month" then year=1970+math.floor(n/12);month=n%12+1;day=T.dayNumber(year,month,1) else day=math.floor(n/T.Day);year,month=T.civil(day) end
		mode=if c.Type=="month" then "months" else "days";self.Control=c
		local parent=page.Root.Parent;if not parent then self.Control=nil;return false end
		host=factory.create("Frame",parent,{Name="TemporalPicker",ZIndex=1000000,ClipsDescendants=false})
		factory.modifier("UIStroke",host,{Thickness=1,Color=Color3.fromRGB(195,195,195),ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
		factory.modifier("UICorner",host,{CornerRadius=UDim.new(0,4)})
		draw()
		for _,entry in {{c.Item.BoxGui,"AbsolutePosition"},{c.Item.BoxGui,"AbsoluteSize"},{page.Root,"AbsoluteSize"}} do table.insert(connections,entry[1]:GetPropertyChangedSignal(entry[2]):Connect(function()self:Close()end)) end
		if page.SetControlPickerOpen then page:SetControlPickerOpen(c,true)end
		return true
	end
	local function inside(gui,p)
		local pos,size=gui.AbsolutePosition,gui.AbsoluteSize
		return p.X>=pos.X and p.X<pos.X+size.X and p.Y>=pos.Y and p.Y<pos.Y+size.Y
	end
	function self:Hit(position: any): any
		if not host or not inside(host,position) then return nil end
		for _,entry in entries do
			local visible=true;local parent=entry.Gui.Parent
			for _,scroll in columns do if parent==scroll and not inside(scroll,position) then visible=false end end
			if visible and inside(entry.Gui,position) then return entry end
		end
		return false
	end
	function self:Begin(event: any): boolean
		if not self.Control then return false end
		local hit=self:Hit(event.Position);if hit==nil then self:Close();return false end
		down=if hit and hit.Enabled then hit else nil;return true
	end
	function self:Move(event: any)
		if not host then return end
		local hit=self:Hit(event.Position)
		local nextHighlight=if hit and hit.Enabled then hit else nil
		if nextHighlight==highlighted then return end
		if highlighted and not highlighted.Selected then highlighted.Gui.BackgroundTransparency=1 end
		highlighted=nextHighlight
		if highlighted and not highlighted.Selected then highlighted.Gui.BackgroundTransparency=0 end
	end
	function self:Finish(event: any): boolean
		if not self.Control then return false end
		local hit=self:Hit(event.Position);local selected=down;down=nil
		if selected and hit==selected and active() then selected.Action() end
		return hit~=nil
	end
	function self:Key(key: string): boolean
		if not active() then return false end
		if key=="Escape" or key=="Tab" then self:Close();return key=="Escape" end
		if key=="Return" or key=="Space" then
			if keyboardEntry and keyboardEntry.Enabled then keyboardEntry.Action();return true end
			if mode=="days" and self.Control.Type~="time" then setDate(day*T.Day)
			elseif self.Control.Type=="month" then setDate((year-1970)*12+month-1)
			elseif mode=="months" then mode="days";draw()
			elseif mode=="years" then mode="months";draw()
			else self:Close() end;return true
		end
		if key=="PageUp" or key=="PageDown" then navigate((if mode=="months" then 12 elseif mode=="years" then 144 else 1)*(if key=="PageUp" then -1 else 1));return true end
		if mode=="months" or mode=="years" then
			local delta=if key=="Left" then -1 elseif key=="Right" then 1 elseif key=="Up" then -3 elseif key=="Down" then 3 else nil
			if delta then navigate(delta*(if mode=="years" then 12 else 1));return true end
		elseif self.Control.Type=="time" then
			local c=self.Control
			if key=="Left" or key=="Right" then c.TemporalSegment=math.clamp((c.TemporalSegment or 1)+(if key=="Left" then -1 else 1),1,#Edit.fields(c));return true end
			if key=="Up" or key=="Down" then
				local field=Edit.fields(c)[c.TemporalSegment or 1];local n=T.number(c.Type,c.Value) or c.Temporal.Min or 0
				local unit=if field.Key=="hour" then 3600000 elseif field.Key=="minute" then 60000 elseif field.Key=="millisecond" then 1 else 1000
				n=(n+(if key=="Up" then -1 else 1)*math.max(unit,c.Temporal.Step or unit))%T.Day
				local candidate={Type=c.Type,Value=T.format(c.Type,n),Temporal=c.Temporal};local under,over=T.flags(candidate)
				if not under and not over then choose(c,candidate.Value);if active() then draw() end end;return true
			end
		end
		if mode=="days" and self.Control.Type~="time" then
			local delta=if key=="Left" then -1 elseif key=="Right" then 1 elseif key=="Up" then -7 elseif key=="Down" then 7 else nil
			if delta then day+=delta;year,month=T.civil(day);if year<1 then day=T.dayNumber(1,1,1);year,month=1,1 end;draw();return true end
		end
		return false
	end
	function self:Tab(reverse: boolean): boolean
		if not active() then return false end
		local candidates={};local selected
		for _,entry in entries do if entry.Enabled and (not entry.Choice or entry.Selected) then table.insert(candidates,entry);if entry==keyboardEntry then selected=#candidates end end end
		if #candidates==0 then return true end
		if keyboardEntry and keyboardEntry.FocusStroke then keyboardEntry.FocusStroke.Enabled=false end
		local index=if selected then (selected-1+(if reverse then -1 else 1))%#candidates+1 else (if reverse then #candidates else 1)
		keyboardEntry=candidates[index]
		if not keyboardEntry.FocusStroke then keyboardEntry.FocusStroke=factory.modifier("UIStroke",keyboardEntry.Gui,{Thickness=2,Color=BLUE,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}) end
		keyboardEntry.FocusStroke.Enabled=true
		-- Scroll the clipped popup/column to its keyboard target without page layout.
		for _,scroll in columns do
			if keyboardEntry.Gui.Parent==scroll then local p=keyboardEntry.Gui.Position;local top=if p.Y then p.Y.Offset else p[2];local h=scroll.AbsoluteSize.Y;scroll.CanvasPosition=Vector2.new(0,math.max(0,math.min(top,top+28-h))) end
		end
		local pos,size=keyboardEntry.Gui.AbsolutePosition,keyboardEntry.Gui.AbsoluteSize
		local origin,viewport=panel.AbsolutePosition,host.AbsoluteSize;local current=panel.CanvasPosition
		local left,top=pos.X-origin.X+current.X,pos.Y-origin.Y+current.Y
		local x=if left<current.X then left else math.max(current.X,left+size.X-viewport.X)
		local y=if top<current.Y then top else math.max(current.Y,top+size.Y-viewport.Y)
		local canvas=panel.CanvasSize
		local cw,ch=if canvas.X then canvas.X.Offset else canvas[1],if canvas.Y then canvas.Y.Offset else canvas[2]
		panel.CanvasPosition=Vector2.new(math.clamp(x,0,math.max(0,cw-viewport.X)),math.clamp(y,0,math.max(0,ch-viewport.Y)))
		return true
	end
	return self
end
return Popup
