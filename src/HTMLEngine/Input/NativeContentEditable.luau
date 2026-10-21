--!strict
-- A retained transparent native TextBox supplies keyboard, paste and committed
-- IME text. The renderer continues to paint the actual editable DOM.
local Editing=require(script.Parent.Parent.JavaScript.Editing)
local ControlSelection=require(script.Parent.Parent.Controls.TextSelection)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local Native={}
function Native.new(page: any,tree: any,services: any?,lost: any): any
	local factory=services and services.Factory
	local taskAPI=services and services.Task or task
	local api={Alive=true,Host=nil,Editor=nil};local runtime,writing,pending=false,false,false
	local hint,blocked,connections=nil,nil,{}
	local surfaceConnections={};local surfaceGui,lastSnapshot,blinkTicket,blinkGeneration,blinkSignature=nil,nil,nil,0,nil
	local blinkOn,caretShown=true,false
	local function connect(signal,fn)if signal then table.insert(connections,signal:Connect(fn))end end
	local function stopBlink()
		blinkGeneration+=1
		if blinkTicket and taskAPI and taskAPI.cancel then taskAPI.cancel(blinkTicket)end;blinkTicket=nil
	end
	local function startBlink(style)
		stopBlink();blinkOn=true
		if not taskAPI or not taskAPI.delay or(style and style.CaretAnimation=="manual")then return end
		local generation=blinkGeneration
		local function tick()
			if generation~=blinkGeneration or not api.Alive or not api.Host or not api.Editor or not api.Editor:IsFocused()then return end
			blinkOn=not blinkOn;if api.Caret then api.Caret.Visible=caretShown and blinkOn end
			blinkTicket=taskAPI.delay(.5,tick)
		end
		blinkTicket=taskAPI.delay(.5,tick)
	end
	local function offsets(editor,text)
		local cursor=ControlSelection.fromByte(text,math.max(1,editor.CursorPosition))
		local anchor=if editor.SelectionStart and editor.SelectionStart>=1 then ControlSelection.fromByte(text,editor.SelectionStart)else cursor
		return cursor,anchor
	end
	local function place()
		local editor,host=api.Editor,api.Host;if not editor or not host then return end
		local box=tree.NodeBoxes and tree.NodeBoxes[host];local gui=box and box.Gui
		local parent=editor.Parent;if not gui or not parent then return end
		local point=gui.AbsolutePosition;local parentPoint=if parent:IsA("GuiObject")then parent.AbsolutePosition else {X=0,Y=0}
		local selection=lastSnapshot and lastSnapshot.Selection;local rect
		if selection and runtime and runtime.SelectionAdapter and not tree.LayoutInProgress then
			local node,offset=selection.FocusNode,selection.FocusOffset
			local ok,result=pcall(function()return runtime.SelectionAdapter:RangeRects(node,offset,node,offset)end)
			if ok and result[1]then rect=result[1];point={X=page.Root.AbsolutePosition.X+rect.X,Y=page.Root.AbsolutePosition.Y+rect.Y}end
		end
		editor.Position=UDim2.fromOffset(point.X-parentPoint.X,point.Y-parentPoint.Y)
		editor.Size=UDim2.fromOffset(1,1)
		local style=tree.NodeStyles and tree.NodeStyles[if selection then selection.FocusNode.Parent or host else host]or tree.NodeStyles and tree.NodeStyles[host]
		if style then
			if style.FontFace then editor.FontFace=style.FontFace end
			if style.FontSize then editor.TextSize=style.FontSize end
		end
		local collapsed=selection and selection.AnchorNode==selection.FocusNode and selection.AnchorOffset==selection.FocusOffset
		local rootPoint,rootSize=page.Root.AbsolutePosition,page.Root.AbsoluteSize
		caretShown=collapsed==true and editor:IsFocused()and(style==nil or style.Visibility~="hidden")and point.X>=rootPoint.X and point.X<rootPoint.X+rootSize.X and point.Y>=rootPoint.Y and point.Y<rootPoint.Y+rootSize.Y
		local ancestor=gui
		while ancestor do
			if ancestor:IsA("GuiObject")then
				if ancestor.Visible==false then caretShown=false end
				if ancestor.ClipsDescendants then
					local origin,size=ancestor.AbsolutePosition,ancestor.AbsoluteSize
					if ancestor:IsA("ScrollingFrame")then size=ancestor.AbsoluteWindowSize end
					if point.X<origin.X or point.Y<origin.Y or point.X>=origin.X+size.X or point.Y>=origin.Y+size.Y then caretShown=false end
				end
			end;ancestor=ancestor.Parent
		end
		if api.Caret then
			local height=math.max(1,rect and rect.Height or style and style.FontSize or 16);local width=1;local y=point.Y
			if style and style.CaretShape=="block"then width=math.max(2,height*.55)
			elseif style and style.CaretShape=="underscore"then width=math.max(2,height*.55);y+=height-2;height=2 end
			api.Caret.Position=UDim2.fromOffset(point.X-parentPoint.X,y-parentPoint.Y);api.Caret.Size=UDim2.fromOffset(width,height)
			api.Caret.BackgroundColor3=style and(style.CaretColor or style.Color)or Color3.new(0,0,0)
			api.Caret.BackgroundTransparency=1-(style and(style.CaretColorAlpha or style.ColorAlpha)or 1)
			api.Caret.Visible=caretShown and blinkOn
		end
		local previous=blinkSignature
		if not previous or previous.Host~=host or previous.Node~=(selection and selection.FocusNode)or previous.Offset~=(selection and selection.FocusOffset)or previous.Collapsed~=collapsed or previous.Text~=(lastSnapshot and lastSnapshot.Text)or previous.Animation~=(style and style.CaretAnimation)then
			blinkSignature={Host=host,Node=selection and selection.FocusNode,Offset=selection and selection.FocusOffset,Collapsed=collapsed,Text=lastSnapshot and lastSnapshot.Text,Animation=style and style.CaretAnimation}
			if collapsed then startBlink(style)else stopBlink()end
			if api.Caret then api.Caret.Visible=caretShown end
		end
	end
	local function bindSurface()
		local host=api.Host;local box=host and tree.NodeBoxes and tree.NodeBoxes[host];local gui=box and box.Gui
		if surfaceGui==gui then return end
		for _,connection in surfaceConnections do connection:Disconnect()end;table.clear(surfaceConnections);surfaceGui=gui
		while gui do
			-- ScreenGui/LayerCollector parents have no GuiObject geometry signals.
			if gui:IsA("GuiObject")then
				for _,key in {"AbsolutePosition","AbsoluteSize","Visible"}do table.insert(surfaceConnections,gui:GetPropertyChangedSignal(key):Connect(place))end
				if gui:IsA("ScrollingFrame")then table.insert(surfaceConnections,gui:GetPropertyChangedSignal("CanvasPosition"):Connect(place))end
			end;gui=gui.Parent
		end
	end
	local function hidden(host)
		local style=tree.NodeStyles and tree.NodeStyles[host]
		if style and(style.Visibility=="hidden"or style.Visibility=="collapse")then return true end
		local node=host
		while node do
			if node.Kind=="Element"and node.Attributes.inert~=nil then return true end
			style=tree.NodeStyles and tree.NodeStyles[node];if style and style.Hidden then return true end
			node=ShadowTree.FlatParent(node)
		end;return false
	end
	function api:Sync()
		if not self.Alive or not self.Host or not runtime or not runtime.Alive then return end
		if not ShadowTree.Connected(self.Host,page.Document)or Editing.host(self.Host)~=self.Host or hidden(self.Host)then
			local host=self.Host;self:Blur();if lost then lost(host)end;return
		end
		local snapshot=runtime:EditingSnapshot(self.Host);if not snapshot then return end
		lastSnapshot=snapshot
		local editor=self.Editor;if not editor then return end
		writing=true;local text=ControlSelection.nativeText(snapshot.Text)
		if editor.Text~=text then editor.Text=text end
		if editor:IsFocused()then
			editor.CursorPosition=ControlSelection.toByte(text,snapshot.Cursor or snapshot.Length)
			editor.SelectionStart=if snapshot.Anchor~=nil and snapshot.Anchor~=snapshot.Cursor then ControlSelection.toByte(text,snapshot.Anchor)else -1
		end
		writing=false;bindSurface();place()
	end
	local function ensure()
		if api.Editor then return api.Editor end
		factory=factory or require(script.Parent.Parent.Rendering.GuiFactory)
		local editor=factory.create("TextBox",page.Root.Parent or page.Root,{Name="ContentEditableInput",Active=false,Selectable=false,
			Text="",TextTransparency=1,BackgroundTransparency=1,ClearTextOnFocus=false,MultiLine=true,TextWrapped=false,
			Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(1,1),ZIndex=0})
		api.Editor=editor
		editor:SetAttribute("HTMLPaintOnlyOverlay",true)
		api.Caret=factory.create("Frame",editor.Parent,{Name="ContentEditableCaret",Active=false,Selectable=false,Visible=false,
			BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0,Size=UDim2.fromOffset(1,16),ZIndex=1000000})
		api.Caret:SetAttribute("HTMLPaintOnlyOverlay",true)
		connect(editor:GetPropertyChangedSignal("Text"),function()
			if writing or not api.Alive or not api.Host or not runtime or not runtime.Alive then return end
			if blocked then api:Sync();return end
			local text=editor.Text;local cursor,anchor=offsets(editor,text)
			runtime:CommitEditing(api.Host,text,hint,cursor,anchor);hint=nil;api:Sync()
		end)
		local function readSelection()
			if writing or pending or not api.Alive or not api.Host or not editor:IsFocused()then return end;pending=true
			local function settle()
				pending=false;if writing or not api.Alive or not api.Host or not runtime or not runtime.Alive or not editor:IsFocused()then return end
				if blocked then api:Sync();return end
				local cursor,anchor=offsets(editor,editor.Text);runtime:SelectEditing(api.Host,cursor,anchor)
			end
			if taskAPI and taskAPI.defer then taskAPI.defer(settle)else settle()end
		end
		connect(editor:GetPropertyChangedSignal("CursorPosition"),readSelection)
		connect(editor:GetPropertyChangedSignal("SelectionStart"),readSelection)
		connect(editor.FocusLost,function()
			if writing or not api.Alive or not api.Host then return end
			local host=api.Host;api:Blur();if lost then lost(host)end
		end)
		return editor
	end
	function api:Bind(realm)runtime=realm end
	function api:EditingChanged()if page.RefreshDOMFocus then page:RefreshDOMFocus()end;self:Sync()end
	function api:Focus(host)
		if not self.Alive or not page.Alive or not runtime or not runtime.Alive or not ShadowTree.Connected(host,page.Document)or Editing.host(host)~=host or hidden(host)then return false end
		local snapshot=runtime:EditingSnapshot(host);if not snapshot then return false end
		if snapshot.Cursor==nil or snapshot.Anchor==nil then runtime:SelectEditing(host,0,0)end
		self.Host=host;hint,blocked=nil,nil;local editor=ensure();self:Sync();if self.Host~=host then return false end
		writing=true;if not editor:IsFocused()then editor:CaptureFocus()end;writing=false;self:Sync();return true
	end
	function api:Blur()
		self.Host=nil;hint,blocked=nil,nil;lastSnapshot,blinkSignature=nil,nil;stopBlink()
		for _,connection in surfaceConnections do connection:Disconnect()end;table.clear(surfaceConnections);surfaceGui=nil
		if self.Caret then self.Caret.Visible=false end
		if self.Editor and self.Editor:IsFocused()then writing=true;self.Editor:ReleaseFocus();writing=false end
	end
	function api:IsEditor(editor)return editor~=nil and editor==self.Editor and self.Host~=nil end
	function api:Hint(key,shift,shortcut)
		if not self.Host then return end
		if key==Enum.KeyCode.Backspace then hint="deleteContentBackward"
		elseif key==Enum.KeyCode.Delete then hint="deleteContentForward"
		elseif key==Enum.KeyCode.Return then local _,mode=Editing.host(self.Host);hint=if shift or mode=="plaintext-only"then"insertLineBreak"else"insertParagraph"
		elseif shortcut then hint=nil else hint="insertText"end
	end
	function api:Navigate(key,shift,shortcut)
		if not self.Host or not runtime or not runtime.Alive then return false end
		local direction,granularity
		if key==Enum.KeyCode.Left then direction,granularity="left",if shortcut then "word"else "character"
		elseif key==Enum.KeyCode.Right then direction,granularity="right",if shortcut then "word"else "character"
		elseif key==Enum.KeyCode.Up then direction,granularity="backward",if shortcut then "paragraph"else "line"
		elseif key==Enum.KeyCode.Down then direction,granularity="forward",if shortcut then "paragraph"else "line"
		elseif key==Enum.KeyCode.Home then direction,granularity="backward",if shortcut then "documentboundary"else "lineboundary"
		elseif key==Enum.KeyCode.End then direction,granularity="forward",if shortcut then "documentboundary"else "lineboundary"
		else return false end
		blocked=key;hint=nil;runtime:NavigateEditing(self.Host,shift,direction,granularity);self:Sync();return true
	end
	function api:Block(key)blocked=key;hint=nil end
	function api:EndKey(key)if blocked==key then blocked=nil end;hint=nil end
	function api:AfterLayout()self:Sync()end
	function api:Destroy()
		if not self.Alive then return end;self:Blur();self.Alive=false;runtime=nil
		for _,connection in connections do connection:Disconnect()end;table.clear(connections)
		if self.Editor then self.Editor:Destroy();self.Editor=nil end
		if self.Caret then self.Caret:Destroy();self.Caret=nil end
	end
	return api
end
return Native
