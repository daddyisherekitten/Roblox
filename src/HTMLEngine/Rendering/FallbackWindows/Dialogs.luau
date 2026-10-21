--!nonstrict
local View=require(script.Parent.View)
local Dialogs={}
function Dialogs.Show(manager,owner,request,complete)
	assert(manager.Alive and owner,'A dialog requires a live owner')
	request=request or {};local gui=manager.Gui;local window
	for _,candidate in manager.Windows do if owner==candidate.Content or owner:IsDescendantOf(candidate.Root)then window=candidate;break end end
	local dialog={Owner=owner,Window=window,Alive=true,Kind=request.Kind or 'alert',Connections={}}
	local permission=dialog.Kind=='permission'
	local input=manager.Input.Native;local previous=input:GetFocusedTextBox()
	local saved=if previous and previous:IsDescendantOf(owner)then {Editor=previous,Cursor=previous.CursorPosition,Selection=previous.SelectionStart,Text=previous.Text}else nil
	if previous then previous:ReleaseFocus(false)end
	local root=gui:Make('Frame',owner,{Name='HTMLSimpleDialog',Size=UDim2.fromScale(1,1),BackgroundTransparency=.55,BackgroundColor3=Color3.fromRGB(255,255,255),ZIndex=2000,ClipsDescendants=true})
	dialog.Root=root;root:SetAttribute('HTMLInputBlocker',true)
	local panel=gui:Make('Frame',root,{Name='Panel',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),BackgroundTransparency=0,BackgroundColor3=Color3.fromRGB(248,248,250),ZIndex=2001})
	gui:Round(panel,10);gui:Stroke(panel)
	if permission then
		gui:Label(panel,tostring(request.Title or 'Zugriff auf Geräte'),{Name='DialogTitle',Position=UDim2.fromOffset(20,14),Size=UDim2.new(1,-40,0,24),TextSize=16,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=2002})
		gui:Label(panel,tostring(request.Origin or request.URL or ''),{Name='DialogOrigin',Position=UDim2.fromOffset(20,42),Size=UDim2.new(1,-40,0,20),TextSize=12,TextColor3=Color3.fromRGB(100,100,106),TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=2002})
	end
	dialog.Scroll=gui:Make('ScrollingFrame',panel,{Name='MessageScroll',Position=UDim2.fromOffset(20,if permission then 76 else 16),CanvasSize=UDim2.new(),ScrollBarThickness=4,ScrollingDirection=Enum.ScrollingDirection.Y,ClipsDescendants=true,ZIndex=2002})
	dialog.Scroll.ScrollingEnabled=false
	local messageText=tostring(request.Message or '')
	if permission then
		local names={};local labels={camera='Kamera',microphone='Mikrofon'}
		for _,name in request.Names or{}do table.insert(names,labels[name]or tostring(name))end
		messageText=table.concat(names,' und ')..' verwenden?'..(if messageText~=''then '\n\n'..messageText else '')
	end
	local message=gui:Label(dialog.Scroll,messageText,{Name='Message',TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,ZIndex=2002})
	message.TextSize=15
	if dialog.Kind=='prompt'then
		dialog.Field=gui:Make('TextBox',panel,{Name='Value',Position=UDim2.fromOffset(20,96),Size=UDim2.new(1,-40,0,30),Text=tostring(request.DefaultValue or ''),ClearTextOnFocus=false,TextSize=15,TextColor3=View.Colors.Text,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=0,BackgroundColor3=View.Colors.White,ZIndex=2002})
		gui:Round(dialog.Field,4);gui:Stroke(dialog.Field)
	end
	dialog.Accept=gui:Button(panel,'Accept',tostring(request.AcceptText or(if permission then 'Zulassen'else 'OK')));dialog.Accept.AnchorPoint=Vector2.new(1,1);dialog.Accept.Position=UDim2.new(1,-20,1,-16);dialog.Accept.ZIndex=2002
	if dialog.Kind~='alert'then
		dialog.Reject=gui:Button(panel,'Cancel',tostring(request.CancelText or(if permission then 'Blockieren'else 'Cancel')));dialog.Reject.AnchorPoint=Vector2.new(1,1);dialog.Reject.Position=UDim2.new(1,-112,1,-16);dialog.Reject.ZIndex=2002
	end
	local function dispose()
		if not dialog.Alive then return false end;dialog.Alive=false
		if manager.Input.Held and manager.Input.Held.Hit.Dialog==dialog then manager.Input:Cancel()end
		local index=table.find(manager.Dialogs,dialog);if index then table.remove(manager.Dialogs,index)end
		for _,connection in dialog.Connections do connection:Disconnect()end;table.clear(dialog.Connections)
		if dialog.Field and dialog.Field:IsFocused()then dialog.Field:ReleaseFocus(false)end
		root:Destroy();if manager.Alive then manager.Input:Refresh()end;return true
	end
	local function cancel()
		local disposed=dispose();if disposed and permission then complete(false,nil)end;return disposed
	end
	dialog.Cancel=cancel
	local function restore()
		if not saved or not manager.Alive or not owner.Parent or input:GetFocusedTextBox()then return end
		if manager:GetFocused()~=window or (window and not window:IsInputEnabled())then return end
		local editor=saved.Editor
		if not editor.Parent or not editor:IsDescendantOf(owner)then return end
		local p,s=editor.AbsolutePosition,editor.AbsoluteSize
		if not View.Contains(editor,Vector2.new(p.X+s.X/2,p.Y+s.Y/2))then return end
		editor:CaptureFocus()
		local function selection(value)return if saved.Text==editor.Text or value<1 then value else math.min(value,#editor.Text+1)end
		if type(saved.Cursor)=='number'then editor.CursorPosition=selection(saved.Cursor)end
		if type(saved.Selection)=='number'then editor.SelectionStart=selection(saved.Selection)end
	end
	dialog.Finish=function(accepted,reason)
		local value=if permission then(if accepted==true then 'granted'elseif reason=='denied'then 'denied'else nil)elseif dialog.Field then dialog.Field.Text else nil
		if dispose()then
			local ok,errorValue=pcall(complete,accepted==true,value);local restored,restoreError=pcall(restore)
			if not ok then error(errorValue,0)end;if not restored then error(restoreError,0)end
		end
	end
	local function layout()
		if not dialog.Alive then return end
		local size=owner.AbsoluteSize;local width=math.max(1,math.min(if permission then 320 else 420,size.X-32));local extra=if dialog.Field then 40 else 0
		local header=if permission then 60 else 0
		local textWidth=math.max(1,width-48)
		local estimated=0;local columns=math.max(1,math.floor(textWidth/7))
		for line in (message.Text..'\n'):gmatch('(.-)\n')do estimated+=math.max(1,math.ceil(#line/columns))*20 end
		local textHeight=estimated
		local textService=manager.Services.TextService or game:GetService('TextService')
		if textService then local ok,bounds=pcall(textService.GetTextSize,textService,message.Text,15,Enum.Font.SourceSans,Vector2.new(textWidth,1000000));if ok then textHeight=math.max(20,bounds.Y+4)end end
		local wantedHeight=if permission then math.min(320,78+header+textHeight)else 154+extra
		local height=math.max(1,math.min(wantedHeight,size.Y-16));panel.Size=UDim2.fromOffset(width,height)
		local messageHeight=math.max(1,height-78-extra-header)
		dialog.Scroll.Size=UDim2.fromOffset(math.max(1,width-40),messageHeight)
		message.Size=UDim2.fromOffset(textWidth,textHeight);dialog.Scroll.CanvasSize=UDim2.fromOffset(0,textHeight)
		local maxScroll=math.max(0,textHeight-messageHeight);dialog.Scroll.CanvasPosition=Vector2.new(0,math.clamp(dialog.Scroll.CanvasPosition.Y,0,maxScroll))
		if dialog.Field then dialog.Field.Position=UDim2.new(0,20,1,-98)end
	end
	table.insert(dialog.Connections,root.Destroying:Connect(cancel))
	table.insert(dialog.Connections,owner.Destroying:Connect(cancel))
	table.insert(dialog.Connections,owner:GetPropertyChangedSignal('AbsoluteSize'):Connect(layout));layout()
	if dialog.Field then table.insert(dialog.Connections,dialog.Field.FocusLost:Connect(function(entered)if entered then dialog.Finish(true)end end))end
	table.insert(manager.Dialogs,dialog);if window then window:Focus()else manager:Focus(nil)end;manager.Input:Refresh()
	if dialog.Field then dialog.Field:CaptureFocus()end
	return cancel
end
return Dialogs
