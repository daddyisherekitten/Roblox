--!nonstrict
local Lifetime=require(script.Parent.Lifetime)
local Controls=require(script.Parent.Controls)
local Overlay={}
local function related(object,parent)
	while object do if object==parent then return true end;object=object.Parent end
	return false
end
function Overlay.new(gui,input,theme,parent,options)
	options=options or {};local scheduler=options.Task or task
	local lifetime=Lifetime.new()
	local self={Alive=true,Scope=lifetime,Current=nil,TooltipRoot=nil,NoticeGeneration=0,PriorFocus=nil}
	local root=gui:Make('Frame',parent,{Name='WaylineOverlays',Size=UDim2.fromScale(1,1),ZIndex=theme.Tokens.LayerPopup})
	root:SetAttribute('WaylinePassThrough',true);lifetime:Add(root);self.Root=root
	local function place(panel,anchor,width,height)
		local bounds=root.AbsoluteSize;local origin=root.AbsolutePosition
		width=math.max(100,math.min(width,math.max(100,bounds.X-24)));height=math.max(44,math.min(height,math.max(44,bounds.Y-24)))
		local x,y
		if anchor then
			x=anchor.AbsolutePosition.X-origin.X;y=anchor.AbsolutePosition.Y-origin.Y+anchor.AbsoluteSize.Y+6
			if y+height>bounds.Y-12 then y=anchor.AbsolutePosition.Y-origin.Y-height-6 end
		else x=(bounds.X-width)/2;y=(bounds.Y-height)/2 end
		x=math.clamp(x,12,math.max(12,bounds.X-width-12));y=math.clamp(y,12,math.max(12,bounds.Y-height-12))
		panel.Position=UDim2.fromOffset(math.floor(x),math.floor(y));panel.Size=UDim2.fromOffset(math.floor(width),math.floor(height))
	end
	local function dismiss(restoreFocus)
		local current=self.Current;self.Current=nil
		if current then
			input:SetModal(nil);current.Scope:Destroy()
			if current.OnDismiss then current.OnDismiss() end
		end
		self:Tooltip(nil,nil)
		local prior=self.PriorFocus;self.PriorFocus=nil
		if restoreFocus and prior and prior.Parent and input.Active and related(prior,input.Root) then input:CaptureFocus(prior) end
		if current and current.RestoreFocus then current.RestoreFocus()end
	end
	function self:Dismiss()dismiss(true)end
	function self:DismissSuggestions()if self.Current and self.Current.Kind=='Suggestions' then dismiss(false) end end
	local function watchAnchor(record,anchor)
		if not anchor then return end
		record.Scope:Add(anchor.Destroying:Connect(function()if self.Current==record then dismiss(false) end end))
		record.Scope:Add(anchor:GetPropertyChangedSignal('Visible'):Connect(function()if self.Current==record and not anchor.Visible then dismiss(false) end end))
	end
	local function begin(kind,modal,keepFocus)
		dismiss(false);if not keepFocus then input:ReleaseFocus() end;self:Tooltip(nil,nil)
		local scope=Lifetime.new();local record={Kind=kind,Scope=scope,Modal=modal};self.Current=record
		local shield=gui:Make('Frame',root,{Name='OverlayShield',Size=UDim2.fromScale(1,1),ZIndex=if modal then theme.Tokens.LayerModal else theme.Tokens.LayerPopup,BackgroundTransparency=if modal then .42 else 1},{BackgroundColor3='Scrim'})
		shield:SetAttribute('WaylineInputBlocker',true);scope:Add(shield);record.Shield=shield
		input:SetModal(shield)
		local unbindShield;unbindShield,record.ShieldEntry=input:Bind(shield,{Action=function()if not modal then dismiss(false) end end});scope:Add(unbindShield)
		local panel=gui:Make('Frame',shield,{Name=kind,BackgroundTransparency=0,ZIndex=shield.ZIndex+1},{BackgroundColor3='Surface'})
		gui:Corner(panel,theme.Tokens.Radius12);gui:Stroke(panel,'Border');record.Panel=panel
		panel.BackgroundTransparency=.18;theme:Animate(panel,{BackgroundTransparency=0},theme.Tokens.DurationMenu)
		scope:Add((input:Bind(panel,{})))
		record.Controls=Controls.new(gui,input,theme,scope,self)
		return record
	end
	-- Custom browser panels use the same input shield, placement and cleanup as
	-- ordinary menus. The HTML and window modules never own these interactions.
	function self:ScriptDialog(request,complete)
		if not self.Alive or not input.Active then scheduler.defer(function()complete(false)end);return function()end end
		local nativeInput=options.InputService or game:GetService('UserInputService')
		local prior=nativeInput:GetFocusedTextBox()or input.Focus
		local cursor,selection
		if prior and prior:IsA('TextBox')then cursor,selection=prior.CursorPosition,prior.SelectionStart end
		local began,record=pcall(begin,'ScriptDialog',true)
		self.PriorFocus=prior
		if not began then dismiss(true);error(record,0)end
		local done=false;local controls=record.Controls;local field
		local permission=request.Kind=='permission'
		if permission then record.Shield.BackgroundTransparency=1 end
		record.RestoreFocus=function()
			if prior and prior.Parent and prior:IsFocused()then
				if cursor~=nil then prior.CursorPosition=cursor end
				if selection~=nil then prior.SelectionStart=selection end
			end
		end
		local function finish(accepted,value)
			if done then return end;done=true
			if self.Current==record then dismiss(true)end
			scheduler.defer(function()complete(accepted,value)end)
		end
		record.OnDismiss=function()finish(false)end
		local built,failure=pcall(function()
		local prompt=request.Kind=='prompt';local confirmation=request.Kind~='alert'
		local width=if permission then 320 else 420;local height=if permission then 164 elseif prompt then 304 else 252
		local title=request.Title or(if permission then 'Zugriff auf Geräte'else 'This page says')
		local heading=controls:Text(record.Panel,title,{Name='DialogTitle',Position=UDim2.fromOffset(20,14),Size=UDim2.new(1,if permission then -66 else -40,0,26),TextSize=16,Font=theme.Tokens.FontBold,TextTruncate=Enum.TextTruncate.AtEnd})
		local origin=controls:Text(record.Panel,tostring(request.Origin or request.URL or ''),{Name='DialogOrigin',Position=UDim2.fromOffset(20,42),Size=UDim2.new(1,-40,0,20),TextSize=11,TextTruncate=Enum.TextTruncate.AtEnd},{TextColor3='Muted'})
		local message=controls:Scroll(record.Panel,{Name='DialogMessage',Position=UDim2.fromOffset(20,72),Size=UDim2.new(1,-40,1,if prompt then -188 else -140)})
		local messageText=request.Message or ''
		local anchor
		if permission then
			local names={};local labels={camera='Kamera',microphone='Mikrofon'}
			for _,name in request.Names or{}do table.insert(names,labels[name]or tostring(name))end
			messageText=table.concat(names,' und ')..' verwenden?'
			if request.Message and request.Message~=''then messageText..='\n\n'..request.Message end
			local chrome=parent.Parent and parent.Parent:FindFirstChild('BrowserChrome')
			if chrome and chrome.Visible then for _,object in chrome:GetDescendants()do if object.Name=='PageInformation'and object:IsA('GuiObject')then anchor=object;break end end end
			record.Anchor=anchor;watchAnchor(record,anchor)
			local close=controls:Button(record.Panel,{Name='DialogDismiss',Icon='close',IconSize=16,Width=28,Height=28,Variant='Toolbar',Cursor='default',Tooltip='Schließen',OnClick=function()finish(false)end})
			close.Root.Position=UDim2.new(1,-38,0,10)
		end
		local text=controls:Text(message.Body,messageText,{Name='Message',Size=UDim2.new(1,0,0,100),TextSize=14,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
		if prompt then
			field=controls:Field(record.Panel,{Name='DialogValue',Text=request.DefaultValue or '',OnSubmit=function()finish(true,field.Text)end})
			field.Position=UDim2.new(0,20,1,-108);field.Size=UDim2.new(1,-40,0,40)
		end
		local ok=controls:Button(record.Panel,{Name='DialogAccept',Text=request.AcceptText or(if permission then 'Zulassen'else 'OK'),Width=92,Height=36,Variant='Primary',Cursor='default',OnClick=function()finish(true,if permission then 'granted'else field and field.Text)end})
		ok.Root.Position=UDim2.new(1,-112,1,-52)
		if confirmation then
			local cancel=controls:Button(record.Panel,{Name='DialogCancel',Text=request.CancelText or(if permission then 'Blockieren'else 'Cancel'),Width=92,Height=36,Cursor='default',OnClick=function()finish(false,if permission then 'denied'else nil)end})
			cancel.Root.Position=UDim2.new(1,-216,1,-52)
		end
		record.Place=function()
			if done or self.Current~=record then return end
			place(record.Panel,anchor,width,height)
			local textWidth=math.max(40,record.Panel.AbsoluteSize.X-72)
			local measuredOK,measured=pcall(function()return game:GetService('TextService'):GetTextSize(text.Text,14,theme.Tokens.Font,Vector2.new(textWidth,1000000))end)
			if not measuredOK then finish(false);error(measured,0)end
			if done or self.Current~=record then return end
			local textHeight=math.max(24,measured.Y+4)
			if permission then
				height=math.min(320,140+textHeight);place(record.Panel,anchor,width,height)
				if not anchor then
					local bounds=root.AbsoluteSize
					record.Panel.Position=UDim2.fromOffset(12,math.min(92,math.max(12,bounds.Y-record.Panel.AbsoluteSize.Y-12)))
				end
			end
			text.Size=UDim2.new(1,0,0,textHeight);message:SetContentHeight(textHeight)
		end
		record.Place()
		if done or self.Current~=record then return end
		record.Scope:Add(nativeInput.InputBegan:Connect(function(event)
			if done or self.Current~=record or not input.Active or event.UserInputType~=Enum.UserInputType.Keyboard then return end
			if event.KeyCode==Enum.KeyCode.Escape then finish(false)
			elseif event.KeyCode==Enum.KeyCode.Return or event.KeyCode==Enum.KeyCode.KeypadEnter then finish(true,if permission then 'granted'else field and field.Text)end
		end))
		if field then input:CaptureFocus(field)end
		end)
		if not built then finish(false);error(failure,0)end
		return function()finish(false)end
	end
	function self:Popover(anchor,specification)
		if not self.Alive then return end
		specification=specification or {}
		local record=begin(specification.Name or 'Popover',false)
		record.Anchor=anchor;record.OnDismiss=specification.OnDismiss;watchAnchor(record,anchor)
		record.Place=function()place(record.Panel,anchor,specification.Width or 320,specification.Height or 480)end
		record.Place();return record
	end
	function self:Menu(anchor,items)
		if not self.Alive then return end
		local record=begin('Menu',false);record.Anchor=anchor;watchAnchor(record,anchor)
		local width=if options.MenuWidth then options.MenuWidth else 280
		local touch=options.Touch==true;local positions={};local total=0
		for index,item in items do
			local height=if item.Separator then 9 elseif item.Heading then 28 elseif touch then 44 elseif item.Detail and item.Detail~=''then 48 else 32
			positions[index]={Y=total,Height=height};total+=height
		end
		local height=math.min(total+12,math.max(44,root.AbsoluteSize.Y-24));place(record.Panel,anchor,width,height)
		local scroller=record.Controls:Scroll(record.Panel,{Position=UDim2.fromOffset(6,6),Size=UDim2.new(1,-12,1,-12)})
		local rows={}
		local function refreshRows()
			if self.Current~=record then return end
			local low=scroller:GetOffset()-48;local high=low+math.max(scroller.Root.AbsoluteSize.Y,height-12)+144
			local first=1;while first<=#items and positions[first].Y+positions[first].Height<low do first+=1 end
			local last=first;while last<#items and positions[last+1].Y<high do last+=1 end
			last=math.min(last,#items)
			for index,row in rows do if index<first or index>last then row.Scope:Destroy();rows[index]=nil end end
			for index=first,last do
				if rows[index] then continue end
				local item=items[index];local rowScope=record.Scope:Child();local controls=Controls.new(gui,input,theme,rowScope,self)
				local placement=positions[index];rows[index]={Scope=rowScope}
				if item.Separator then
					rowScope:Add(gui:Make('Frame',scroller.Body,{Name='MenuSeparator',Position=UDim2.fromOffset(8,placement.Y+4),Size=UDim2.new(1,-16,0,1),BackgroundTransparency=.45},{BackgroundColor3='Border'}));continue
				elseif item.Heading then
					rowScope:Add(controls:Text(scroller.Body,item.Text,{Name='MenuHeading',Position=UDim2.fromOffset(14,placement.Y),Size=UDim2.new(1,-28,0,placement.Height),TextSize=11},{TextColor3='Muted'}));continue
				end
				local button=controls:Button(scroller.Body,{Name='MenuItem',Text=item.Text,Icon=item.Icon,IconSize=18,TextSize=13,Tooltip=item.Tooltip,Width=width-40,Height=placement.Height,Radius=4,Variant='Quiet',Enabled=not item.Disabled,OnClick=function()
					dismiss(false);if item.Action then item.Action() end
				end})
				button.Root.Position=UDim2.fromOffset(0,placement.Y);button.Root.Size=UDim2.new(1,0,0,placement.Height);button.Label.TextXAlignment=Enum.TextXAlignment.Left
				if item.Detail and item.Detail~='' then
					button.Label.Size=UDim2.new(1,if item.Icon then -52 else -28,0,20);button.Label.Position=UDim2.fromOffset(if item.Icon then 40 else 14,3);button.Label.TextSize=13
					controls:Text(button.Root,item.Detail,{Position=UDim2.fromOffset(if item.Icon then 40 else 14,22),Size=UDim2.new(1,if item.Icon then -52 else -28,0,18),TextSize=11,TextTruncate=Enum.TextTruncate.AtEnd},{TextColor3='Muted'})
				end
			end
		end
		scroller:SetContentHeight(total);record.Scope:Add(scroller.Root:GetPropertyChangedSignal('CanvasPosition'):Connect(refreshRows));record.Scope:Add(scroller.Root:GetPropertyChangedSignal('AbsoluteSize'):Connect(refreshRows));refreshRows()
		record.Place=function()place(record.Panel,anchor,width,height);refreshRows()end
		return record
	end
	function self:Suggestions(anchor,items,onSelect)
		if not self.Alive then return end
		if #items==0 then if self.Current and self.Current.Kind=='Suggestions' then dismiss(false) end;return end
		-- Suggestions deliberately keep the address field's native edit focus.
		local prior=input.Focus
		local record=begin('Suggestions',false,true);record.Anchor=anchor;watchAnchor(record,anchor);record.Panel:SetAttribute('WaylinePreserveFocus',true)
		record.ShieldEntry.HitTest=function(position)
			local p,s=anchor.AbsolutePosition,anchor.AbsoluteSize
			return not (position.X>=p.X and position.Y>=p.Y and position.X<p.X+s.X and position.Y<p.Y+s.Y)
		end
		local width=math.max(300,anchor.AbsoluteSize.X);local count=math.min(8,#items)
		local height=math.min(count*60+12,math.max(44,root.AbsoluteSize.Y-24));place(record.Panel,anchor,width,height)
		local scroller=record.Controls:Scroll(record.Panel,{Position=UDim2.fromOffset(6,6),Size=UDim2.new(1,-12,1,-12)})
		for index=1,count do
			local item=items[index]
			local button=record.Controls:Button(scroller.Body,{Name='Suggestion',Text=item.Title or item.Text or item.Address or item.URL or '',Icon=item.Icon or 'page',IconSize=18,TextSize=13,Height=56,Variant='Quiet',OnClick=function()dismiss(false);onSelect(item)end})
			button.Root.Position=UDim2.fromOffset(0,(index-1)*60);button.Root.Size=UDim2.new(1,0,0,56)
			button.Label.Position=UDim2.fromOffset(40,5);button.Label.Size=UDim2.new(1,-52,0,22)
			record.Controls:Text(button.Root,item.Address or item.URL or item.Detail or '',{Position=UDim2.fromOffset(40,29),Size=UDim2.new(1,-52,0,18),TextSize=11,TextTruncate=Enum.TextTruncate.AtEnd},{TextColor3='Muted'})
		end
		scroller:SetContentHeight(count*60);record.Place=function()place(record.Panel,anchor,width,height)end
		input:SetModal(nil)
		if prior and prior.Parent then input.Focus=prior end
		return record
	end
	function self:Form(specification)
		if not self.Alive then return end
		local prior=input.Focus
		local record=begin('Form',true);self.PriorFocus=prior;local controls=record.Controls
		local fields=specification.Fields or {};local width=420;local wanted=150+#fields*80
		place(record.Panel,nil,width,wanted)
		controls:Text(record.Panel,specification.Title or 'Edit',{Name='DialogTitle',Position=UDim2.fromOffset(20,16),Size=UDim2.new(1,-76,0,30),TextSize=20,Font=theme.Tokens.FontBold,TextTruncate=Enum.TextTruncate.AtEnd})
		local close=controls:Button(record.Panel,{Icon='close',Tooltip='Cancel',Variant='Quiet',OnClick=function()dismiss(true)end})
		close.Root.Position=UDim2.new(1,-54,0,8)
		local scroll=controls:Scroll(record.Panel,{Name='FormFields',Position=UDim2.fromOffset(20,58),Size=UDim2.new(1,-40,1,-150)})
		local inputs={};local errorLabel=controls:Text(record.Panel,'',{Name='Validation',Position=UDim2.new(0,20,1,-85),Size=UDim2.new(1,-40,0,28),TextSize=12,TextWrapped=true},{TextColor3='Danger'})
		local function submit()
			if self.Current~=record then return end
			local values={};for id,field in inputs do values[id]=field.Text end
			local ok,success,message=pcall(specification.OnSubmit or function()return true end,values)
			if not ok then errorLabel.Text='This change could not be saved. Please try again.'
			elseif success==false or success==nil and message then errorLabel.Text=message or 'Please check the values.'
			else dismiss(false) end
		end
		for index,field in fields do
			controls:Text(scroll.Body,field.Label or field.Id,{Position=UDim2.fromOffset(0,(index-1)*80),Size=UDim2.new(1,0,0,23),TextSize=12},{TextColor3='Muted'})
			local textbox=controls:Field(scroll.Body,{Name=tostring(field.Id),Text=tostring(field.Value or ''),Placeholder=field.Placeholder,OnSubmit=submit})
			textbox.Position=UDim2.fromOffset(0,(index-1)*80+26);inputs[field.Id]=textbox
		end
		scroll:SetContentHeight(#fields*80)
		local cancel=controls:Button(record.Panel,{Text='Cancel',Width=100,OnClick=function()dismiss(true)end});cancel.Root.Position=UDim2.new(1,-236,1,-56)
		local save=controls:Button(record.Panel,{Text=specification.SubmitText or 'Save',Width=108,Variant='Primary',OnClick=submit});save.Root.Position=UDim2.new(1,-128,1,-56)
		record.Place=function()place(record.Panel,nil,width,wanted)end
		local first=fields[1] and inputs[fields[1].Id];if first then input:CaptureFocus(first) end
		return record
	end
	function self:Confirm(title,message,onConfirm)
		if not self.Alive then return end
		local prior=input.Focus
		local record=begin('Confirm',true);self.PriorFocus=prior;local controls=record.Controls;place(record.Panel,nil,420,230)
		controls:Text(record.Panel,title,{Position=UDim2.fromOffset(20,18),Size=UDim2.new(1,-40,0,30),TextSize=20,Font=theme.Tokens.FontBold,TextTruncate=Enum.TextTruncate.AtEnd})
		controls:Text(record.Panel,message,{Position=UDim2.fromOffset(20,62),Size=UDim2.new(1,-40,1,-132),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top},{TextColor3='Muted'})
		local cancel=controls:Button(record.Panel,{Text='Cancel',Width=100,OnClick=function()dismiss(true)end});cancel.Root.Position=UDim2.new(1,-236,1,-58)
		local confirm=controls:Button(record.Panel,{Text='Confirm',Width=108,Variant='Primary',OnClick=function()dismiss(false);onConfirm()end});confirm.Root.Position=UDim2.new(1,-128,1,-58)
		record.Place=function()place(record.Panel,nil,420,230)end
		return record
	end
	function self:Notice(text)
		if not self.Alive then return end
		self.NoticeGeneration+=1;local generation=self.NoticeGeneration
		if self.NoticeTask then pcall(scheduler.cancel,self.NoticeTask);self.NoticeTask=nil end
		if self.NoticeRoot then self.NoticeRoot:Destroy();self.NoticeRoot=nil end
		local notice=gui:Make('Frame',root,{Name='Notice',AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-16),Size=UDim2.new(1,-32,0,58),ZIndex=theme.Tokens.LayerTooltip,BackgroundTransparency=0},{BackgroundColor3='Elevated'})
		gui:Corner(notice,12);gui:Stroke(notice,'Border')
		gui:Text(notice,{Text=text,Position=UDim2.fromOffset(16,6),Size=UDim2.new(1,-32,1,-12),TextWrapped=true,TextSize=13,TextTruncate=Enum.TextTruncate.AtEnd})
		self.NoticeRoot=notice
		self.NoticeTask=scheduler.delay(4,function()self.NoticeTask=nil;if self.Alive and generation==self.NoticeGeneration and self.NoticeRoot==notice then self.NoticeRoot=nil;notice:Destroy() end end)
	end
	function self:Tooltip(text,target)
		if self.TooltipRoot then self.TooltipRoot:Destroy();self.TooltipRoot=nil end
		if not self.Alive or not text or not target or not target.Parent or self.Current then return end
		local width=math.clamp(#text*6.8+24,80,math.max(80,math.min(300,root.AbsoluteSize.X-24)))
		local tip=gui:Make('Frame',root,{Name='Tooltip',Size=UDim2.fromOffset(width,34),ZIndex=theme.Tokens.LayerTooltip,BackgroundTransparency=0,ClipsDescendants=true},{BackgroundColor3='Tooltip'})
		gui:Corner(tip,8);gui:Make('TextLabel',tip,{Text=text,Position=UDim2.fromOffset(10,4),Size=UDim2.new(1,-20,1,-8),TextWrapped=true,TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd},{TextColor3='TooltipText'})
		local height=math.clamp(math.ceil(#text*6.8/math.max(60,width-20))*16+12,34,108)
		place(tip,target,width,height);self.TooltipRoot=tip
	end
	input:SetTooltipHandler(function(text,target)self:Tooltip(text,target)end)
	lifetime:Add(input:OnSuspend(function()dismiss(false)end))
	lifetime:Add(input:OnPointerDown(function(entry,event)
		local current=self.Current
		if current and current.Kind=='Suggestions' and (not entry or not related(entry.Gui,current.Panel)) then dismiss(false) end
	end))
	local nativeInput=options.InputService or game:GetService('UserInputService')
	lifetime:Add(nativeInput.InputBegan:Connect(function(event)
		local current=self.Current
		if not self.Alive or not input.Active or not current or current.Kind=='ScriptDialog'then return end
		if event.UserInputType==Enum.UserInputType.Keyboard then
			if event.KeyCode==Enum.KeyCode.Escape then dismiss(true)end
		elseif not current.Modal and(event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch)then
			local entry=input:HitAt(event.Position)
			if entry and(related(entry.Gui,current.Panel)or current.Anchor and related(entry.Gui,current.Anchor))then return end
			dismiss(false)
		end
	end))
	lifetime:Add(root:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
		if self.Current and self.Current.Place then self.Current.Place() end;self:Tooltip(nil,nil)
	end))
	function self:Destroy()
		if not self.Alive then return end;dismiss(false);self.Alive=false;self.NoticeGeneration+=1
		if self.NoticeTask then pcall(scheduler.cancel,self.NoticeTask);self.NoticeTask=nil end
		if self.NoticeRoot then self.NoticeRoot:Destroy();self.NoticeRoot=nil end
		input:SetTooltipHandler(nil);lifetime:Destroy()
	end
	return self
end
return Overlay
