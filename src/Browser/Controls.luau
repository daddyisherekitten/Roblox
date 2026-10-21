--!nonstrict
local Icons=require(script.Parent.Icons)
local Controls={}
function Controls.new(gui,input,theme,scope,overlays)
	local self={Gui=gui,Input=input,Theme=theme,Scope=scope,Overlays=overlays}
	function self:Text(parent,text,props,bindings)
		local properties=table.clone(props or {});properties.Text=text or ''
		return gui:Make('TextLabel',parent,properties,bindings or {TextColor3='Text'})
	end
	function self:Button(parent,options)
		options=options or {};local own=scope:Child()
		local variant=options.Variant;local iconSize=options.IconSize or theme.Tokens.IconSize
		local width=options.Width or (if options.Text and options.Text~='' then 140 else theme.Tokens.Target)
		local height=options.Height or theme.Tokens.Target
		local root=gui:Make('Frame',parent,{Name=options.Name or 'Action',Size=UDim2.fromOffset(width,height),BackgroundTransparency=0,ZIndex=options.ZIndex})
		own:Add(root);local surface=root
		local corner=gui:Corner(root,options.Radius or (if variant=='Toolbar' then height/2 elseif variant=='Shortcut' then 8 else theme.Tokens.Radius8))
		if variant=='Toolbar' and options.Radius==nil then corner.CornerRadius=UDim.new(.5,0) end
		local icon;local iconName=options.Icon
		if options.Icon then icon=Icons.draw(gui,root,options.Icon,iconSize,'Text');icon.AnchorPoint=Vector2.new(.5,.5);icon.Position=if options.Text and options.Text~='' then UDim2.new(0,22,.5,0) else UDim2.fromScale(.5,.5) end
		local label=self:Text(root,options.Text or '',{Name='Label',Position=UDim2.fromOffset(if icon then 40 else 14,0),Size=UDim2.new(1,if icon then -52 else -28,1,0),TextSize=options.TextSize or theme.Tokens.TextBody,TextTruncate=Enum.TextTruncate.AtEnd,Font=theme.Tokens.Font})
		if not icon then label.TextXAlignment=Enum.TextXAlignment.Center end
		local result={Root=root,Label=label,Icon=icon,Alive=true,Enabled=options.Enabled~=false,Selected=false,Hovered=false,Pressed=false}
		local function repaint()
			if not result.Alive then return end
			local quiet=variant=='Toolbar' or variant=='Shortcut' or variant=='Quiet'
			local base=if variant=='Primary' then 'Accent' elseif variant=='Danger' then 'Surface' elseif result.Selected and variant~='Toolbar' then 'AccentSoft' else 'Elevated'
			local text=if variant=='Primary' then 'OnAccent' elseif variant=='Danger' then 'Danger' elseif result.Selected then 'Accent' else 'Text'
			local transparency=if quiet and (not result.Selected or variant=='Toolbar') then 1 else 0
			if not result.Enabled then text='Disabled';if not quiet then base='SurfaceInset' end
			elseif result.Pressed then base=if variant=='Toolbar' then 'ToolbarPressed' else 'Pressed';transparency=0
			elseif result.Hovered then base=if variant=='Toolbar' then 'ToolbarHover' else 'Hover';transparency=0 end
			local background=theme.Tokens[base]
			if variant=='Primary' and result.Enabled then
				background=theme.Tokens.Accent:Lerp(theme.Tokens.Text,if result.Pressed then .16 elseif result.Hovered then .08 else 0)
			end
			if result.VisualReady then
				theme:Animate(surface,{BackgroundColor3=background,BackgroundTransparency=transparency},theme.Tokens.DurationHover)
				theme:Animate(label,{TextColor3=theme.Tokens[text],TextTransparency=0},theme.Tokens.DurationHover)
			else
				surface.BackgroundColor3=background;surface.BackgroundTransparency=transparency
				label.TextColor3=theme.Tokens[text];label.TextTransparency=0;result.VisualReady=true
			end
			if icon then Icons.SetColor(icon,gui,text) end
		end
		-- Nested close/menu controls can keep the containing row's hover surface.
		function result:SetHovered(value)
			value=value==true;if not self.Alive or self.Hovered==value then return end
			self.Hovered=value;repaint()
		end
		local unbind,entry=input:Bind(root,{Enabled=result.Enabled,Tooltip=options.Tooltip,PreserveFocus=options.PreserveFocus,Action=options.OnClick,
			Cursor=options.Cursor or(if variant=='Toolbar'then 'default'else nil),
			HitTest=options.HitTest,
			Begin=options.Begin,Move=options.Move,Finish=options.Finish,Cancel=function()result.Pressed=false;repaint();if options.Cancel then options.Cancel() end end,
			DragBegin=options.DragBegin,Drag=options.Drag,DragEnd=options.DragEnd,
			Hover=function(value)result:SetHovered(value);if options.Hover then options.Hover(value) end end,
			Press=function(value)result.Pressed=value;repaint();if options.Press then options.Press(value) end end})
		result.Entry=entry;own:Add(unbind);own:Add(theme.Changed:Connect(repaint))
		function result:SetEnabled(value)
			value=value==true;if not self.Alive or self.Enabled==value then return end
			self.Enabled=value;entry.Enabled=value;if not value then self.Pressed=false;self.Hovered=false end;repaint();input:RefreshCursor()
		end
		function result:SetSelected(value)value=value==true;if not self.Alive or self.Selected==value then return end;self.Selected=value;repaint()end
		function result:SetText(text)text=text or '';if self.Alive and label.Text~=text then label.Text=text end end
		function result:SetIcon(name)
			if not self.Alive or iconName==name then return end
			local hadIcon=icon~=nil
			if icon then icon:Destroy();icon=nil end
			iconName=name
			if name then
				icon=Icons.draw(gui,root,name,iconSize,'Text');icon.AnchorPoint=Vector2.new(.5,.5)
				icon.Position=if label.Text~='' then UDim2.new(0,22,.5,0) else UDim2.fromScale(.5,.5)
			end
			self.Icon=icon
			if hadIcon~=(icon~=nil) then
				local delta=if icon then 26 else -26
				label.Position=UDim2.new(label.Position.X.Scale,label.Position.X.Offset+delta,label.Position.Y.Scale,label.Position.Y.Offset)
				label.Size=UDim2.new(label.Size.X.Scale,label.Size.X.Offset-delta,label.Size.Y.Scale,label.Size.Y.Offset)
				label.TextXAlignment=if icon then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
			end
			repaint()
		end
		function result:Destroy()if not self.Alive then return end;self.Alive=false;own:Destroy()end
		own:Add(function()result.Alive=false end);repaint();return result
	end
	function self:Field(parent,options)
		options=options or {}
		local own=scope:Child()
		local transparent=options.Transparent==true or options.Variant=='Omnibox'
		local field=gui:Make('TextBox',parent,{Name=options.Name or 'TextField',Size=UDim2.new(1,0,0,theme.Tokens.ControlHeight),Text=options.Text or '',PlaceholderText=options.Placeholder or '',ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=if transparent then 1 else 0,TextSize=options.TextSize or theme.Tokens.TextBody,TextTruncate=Enum.TextTruncate.AtEnd},{BackgroundColor3='SurfaceInset',TextColor3='Text',PlaceholderColor3='Muted'})
		own:Add(field);local stroke
		if not transparent then
			gui:Corner(field,options.Radius or theme.Tokens.Radius8);stroke=gui:Stroke(field,'Border')
			gui:Make('UIPadding',field,{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)})
		end
		own:Add((input:Bind(field,{Begin=function()input:CaptureFocus(field)end,Hover=options.Hover})))
		local focused=false
		local function repaint()if stroke then theme:Animate(stroke,{Color=theme.Tokens[if focused then 'Accent' else 'Border']}) end end
		own:Add(field.Focused:Connect(function()focused=true;repaint()end))
		own:Add(field.FocusLost:Connect(function(enter,event)
			focused=false;repaint()
			if enter and options.OnSubmit then options.OnSubmit(field.Text,event) end
		end))
		own:Add(field:GetPropertyChangedSignal('Text'):Connect(function()if options.OnChanged then options.OnChanged(field.Text) end end))
		own:Add(theme.Changed:Connect(repaint));return field
	end
	function self:Scroll(parent,props)
		local own=scope:Child()
		local properties=table.clone(props or {});properties.Name=properties.Name or 'Scroll';properties.Size=properties.Size or UDim2.fromScale(1,1)
		properties.CanvasSize=UDim2.new();properties.ScrollingEnabled=false;properties.ScrollBarThickness=0;properties.ClipsDescendants=true
		local root=gui:Make('ScrollingFrame',parent,properties);own:Add(root)
		local body=gui:Make('Frame',root,{Name='Body',Size=UDim2.new(1,-16,0,0)})
		local track=gui:Make('Frame',parent,{Name='ScrollTrack',Size=UDim2.fromOffset(6,0),ZIndex=root.ZIndex+2})
		own:Add(track)
		local function arrangeTrack()
			local parentPosition=if parent:IsA('GuiObject') then parent.AbsolutePosition else Vector2.new(0,0)
			local relative=root.AbsolutePosition-parentPosition
			track.Position=UDim2.fromOffset(relative.X+root.AbsoluteSize.X-9,relative.Y+4)
			track.Size=UDim2.fromOffset(6,math.max(0,root.AbsoluteSize.Y-8));track.Visible=root.Visible
		end
		for _,property in {'AbsoluteSize','AbsolutePosition','Visible'} do own:Add(root:GetPropertyChangedSignal(property):Connect(arrangeTrack)) end
		arrangeTrack()
		local thumb=gui:Make('Frame',track,{Name='Thumb',Size=UDim2.fromOffset(6,28),BackgroundTransparency=.25},{BackgroundColor3='Muted'});gui:Corner(thumb,3)
		local remove,registration=input:RegisterScroll(root,thumb,'Y');own:Add(remove)
		local hovered,pressed=false,false
		local function repaintThumb()theme:Animate(thumb,{BackgroundColor3=theme.Tokens.Muted,BackgroundTransparency=if pressed then 0 elseif hovered then .08 else .25})end
		registration.OnHover=function(value)hovered=value;repaintThumb()end
		registration.OnPress=function(value)pressed=value;repaintThumb()end
		own:Add(theme.Changed:Connect(repaintThumb))
		local result={Root=root,Body=body,Alive=true}
		function result:SetContentHeight(value)
			if not self.Alive then return end;value=math.max(0,tonumber(value) or 0)
			body.Size=UDim2.new(1,-16,0,value);root.CanvasSize=UDim2.fromOffset(0,value)
			registration:Set(root.CanvasPosition.Y)
		end
		function result:ScrollTo(value)if self.Alive then registration:Set(tonumber(value) or 0) end end
		function result:GetOffset()return if self.Alive then root.CanvasPosition.Y else 0 end
		function result:Destroy()if not self.Alive then return end;self.Alive=false;own:Destroy()end
		own:Add(function()result.Alive=false end);return result
	end
	return self
end
return Controls
