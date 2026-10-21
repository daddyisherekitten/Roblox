--!strict
-- Pointer selection for rendered page words. Highlights are created only for
-- the active range; editable TextBoxes retain their native selection behavior.
local GuiFactory=require(script.Parent.Parent.Rendering.GuiFactory)
local Stylesheet=require(script.Parent.Parent.CSS.Stylesheet)
local Style=require(script.Parent.Parent.CSS.InlineStyle)
local TextMeasure=require(script.Parent.Parent.Layout.TextMeasure)
local TextDirection=require(script.Parent.TextDirection)
local BidiPaint=require(script.Parent.Parent.Layout.BidiPaint)
local Upright=require(script.Parent.UprightSelection)
local TextSelection={}
TextSelection.__index=TextSelection
local MAX_HIGHLIGHTS=4096
local MAX_PAINT_OBJECTS=16384

local function label(item: any): any?
	local gui=item.TextGui or item.Gui
	return if gui and gui:IsA('TextLabel') then gui else nil
end

local function selectable(item: any,custom: boolean?): boolean
	if item.Style and ((not custom and item.Style.UserSelect == 'none') or item.Style.Hidden
		or item.Style.Visibility == 'hidden' or item.Style.Visibility == 'collapse') then return false end
	if item.Gui and item.Gui.Visible == false then return false end
	local ancestor=item.Gui and item.Gui.Parent
	while ancestor do
		if ancestor.IsA then
			if ancestor:IsA('GuiObject') and ancestor.Visible==false
				or ancestor:IsA('LayerCollector') and ancestor.Enabled==false then return false end
		elseif type(ancestor)=='table' and ancestor.Visible==false then return false end
		ancestor=ancestor.Parent
	end
	return label(item)~=nil or (item.Gui~=nil and (item.Kind=='Space' or (item.Glyphs~=nil and #item.Glyphs>0)))
end

local function dimensions(item: any,gui: any): (number,number,number,number)
	local size=gui.Size
	local width=if size and size.X and size.X.Scale==0 then size.X.Offset else item.Width or gui.AbsoluteSize.X
	local height=if size and size.Y and size.Y.Scale==0 then size.Y.Offset else item.Height or gui.AbsoluteSize.Y
	return width,height,if width>0 then gui.AbsoluteSize.X/width else 1,if height>0 then gui.AbsoluteSize.Y/height else 1
end
local function screenRect(gui: any,left: number,top: number,extent: number,cross: number): any
	local angle=math.rad(gui.AbsoluteRotation or gui.Rotation or 0);local cosine,sine=math.cos(angle),math.sin(angle)
	local width,height=gui.AbsoluteSize.X,gui.AbsoluteSize.Y
	local x0,y0,x1,y1=math.huge,math.huge,-math.huge,-math.huge
	for _,p in {{left,top},{left+extent,top},{left+extent,top+cross},{left,top+cross}}do
		local dx,dy=p[1]-width/2,p[2]-height/2
		local x,y=gui.AbsolutePosition.X+width/2+dx*cosine-dy*sine,gui.AbsolutePosition.Y+height/2+dx*sine+dy*cosine
		x0,y0,x1,y1=math.min(x0,x),math.min(y0,y),math.max(x1,x),math.max(y1,y)
	end
	return {X=x0,Y=y0,Width=x1-x0,Height=y1-y0}
end

local function graphemes(item: any): {number}
	if item.SelectionGraphemes and item.SelectionGraphemeText==item.Text then return item.SelectionGraphemes end
	local ends={}
	for _,last in utf8.graphemes(item.Text or '') do table.insert(ends,last) end
	item.SelectionGraphemes,item.SelectionGraphemeText=ends,item.Text
	item.SelectionWidths={}
	return ends
end

local function widthAt(item: any,offset: number): number
	if offset<=0 then return 0 end
	if item.VerticalAdvance then return Upright.width(item,offset)end
	local gui=label(item)or item.Gui;if not gui then return 0 end
	local full=math.max(0,(dimensions(item,gui)))
	if item.Kind=='Space'then
		if offset>=#item.Text then return full end
		local start=item.X or 0;local cursor=start+(item.StartTracking or 0)
		for i=1,offset do
			if item.Text:sub(i,i)=='\t'then
				local step=item.TabWidth or 0
				if step>0 then local remaining=step-cursor%step;if remaining<(item.TabMinimum or 0)then remaining+=step end;cursor+=remaining end
			else cursor+=item.SpaceUnit or full/#item.Text end
		end
		return math.clamp(cursor-start,0,full)
	end
	if item.Glyphs then
		if offset>=#item.Glyphs then return full end
		return item.Glyphs[offset+1].X or 0
	end
	local textLabel=label(item)
	if not textLabel then return 0 end
	local ends=graphemes(item)
	-- Prefix widths belong to this word's current measured font and geometry.
	-- Reusing them after responsive typography changes moves selection boundaries.
	local key=item.SelectionWidthContext
	if not key or key.Font~=item.FontFace or key.Size~=item.TextSize or key.Width~=full or key.BidiText~=item.MeasuredBidiText or key.Direction~=item.BidiDirection then
		item.SelectionWidths={}
		item.SelectionWidthContext={Font=item.FontFace,Size=item.TextSize,Width=full,BidiText=item.MeasuredBidiText,Direction=item.BidiDirection}
	end
	if offset>=#ends then return full end
	local cached=item.SelectionWidths[offset]
	if cached then return cached end
	local prefix=item.Text:sub(1,ends[offset])
	local measured
	if item.FontFace and item.TextSize then
		local ok,result=pcall(TextMeasure.measure,BidiPaint.text(item,prefix),item.FontFace,item.TextSize,0)
		if ok and result then measured=result.X end
	end
	local value=math.clamp(measured or full*offset/#ends,0,full)
	item.SelectionWidths[offset]=value
	return value
end

local function offsetAt(item: any,position: any): number
	if item.VerticalAdvance then return Upright.offset(item,position)end
	local gui=label(item) or item.Gui
	if not gui then return 0 end
	local rotation=math.rad(gui.AbsoluteRotation or gui.Rotation or 0)
	local dx,dy=position.X-gui.AbsolutePosition.X-gui.AbsoluteSize.X/2,position.Y-gui.AbsolutePosition.Y-gui.AbsoluteSize.Y/2
	local _,_,scale=dimensions(item,gui)
	local x=math.clamp(dx*math.cos(rotation)+dy*math.sin(rotation)+gui.AbsoluteSize.X/2,0,gui.AbsoluteSize.X)/scale
	if TextDirection.of(item)=='rtl'then x=(dimensions(item,gui))-x end
	local count=#graphemes(item)
	local low,high=0,count
	while low<high do
		local middle=math.floor((low+high)/2)
		if widthAt(item,middle)<x then low=middle+1 else high=middle end
	end
	if low>0 and math.abs(x-widthAt(item,low-1))<math.abs(widthAt(item,low)-x) then return low-1 end
	return low
end

local function selectedStyle(tree: any,item: any,custom: any?): any
	if custom then return custom(item)end
	local node=item.Style.Node
	while node do
		if node.Kind=='Element' then
			local declarations=Stylesheet.matchPseudo(tree.CSSRules,node,'selection',tree.CSSStates)
			if #declarations.Normal>0 or #declarations.Important>0 then
				local fake={Kind='Element',Name='span',Attributes={},Children={},Parent=node}
				local style=Style.resolve(fake,item.Style,function() end,false,declarations)
				return {Color=style.Color,Background=style.Background or Color3.fromRGB(51,144,255),Alpha=style.BackgroundAlpha or 1}
			end
		end
		node=node.Parent
	end
	return {Color=Color3.new(1,1,1),Background=Color3.fromRGB(51,144,255),Alpha=1}
end

local function clearOverlay(self: any,item: any)
	local overlay=self.Overlays[item]
	if not overlay then return end
	self.Tree.TextItemsByGui[overlay.Frame]=nil
	if overlay.Text then self.Tree.TextItemsByGui[overlay.Text]=nil end
	for _,glyph in overlay.Glyphs or {} do self.Tree.TextItemsByGui[glyph]=nil end
	overlay.Frame:Destroy()
	self.Overlays[item]=nil
end

local function clearGap(self: any,item: any)
	local gap=self.Gaps[item]
	if not gap then return end
	self.Tree.TextItemsByGui[gap]=nil
	gap:Destroy()
	self.Gaps[item]=nil
end

local function paint(self: any,item: any,first: number,last: number)
	local textLabel=label(item)
	local gui=textLabel or item.Gui
	if not selectable(item,self.CustomStyle~=nil) or first>=last then clearOverlay(self,item);return end
	if item.VerticalAdvance then Upright.paint(self,item,first,last,selectedStyle(self.Tree,item,self.CustomStyle),GuiFactory.create);return end
	if self.Overlays[item]and self.Overlays[item].Upright then clearOverlay(self,item)end
	local left,right=widthAt(item,first),widthAt(item,last)
	if TextDirection.of(item)=='rtl'then local width=dimensions(item,gui);left,right=width-right,width-left end
	if right<=left then clearOverlay(self,item);return end
	local overlay=self.Overlays[item]
	if not overlay then
		local color=selectedStyle(self.Tree,item,self.CustomStyle)
		local frame=GuiFactory.create('Frame',gui,{Name='HTMLSelection',ClipsDescendants=true,
			BackgroundColor3=color.Background,BackgroundTransparency=1-color.Alpha,ZIndex=(gui.ZIndex or 1)+(self.ZOffset or 4096)})
		overlay={Frame=frame,Glyphs={}}
		if textLabel then
			overlay.Text=GuiFactory.create('TextLabel',frame,{Name='SelectedText',Text=BidiPaint.text(item),
				FontFace=textLabel.FontFace,OpenTypeFeatures=textLabel.OpenTypeFeatures,TextSize=textLabel.TextSize,
				TextDirection=textLabel.TextDirection,
				TextColor3=color.Color,TextXAlignment=textLabel.TextXAlignment,TextYAlignment=textLabel.TextYAlignment,
				LineHeight=textLabel.LineHeight,ZIndex=frame.ZIndex+1})
			self.Tree.TextItemsByGui[overlay.Text]=item
		elseif item.Glyphs then
			for index,glyph in item.Glyphs do
				local source=glyph.Gui
				local copy=GuiFactory.create('TextLabel',frame,{Name='SelectedGlyph_'..index,Text=glyph.Text,
					FontFace=source.FontFace,OpenTypeFeatures=source.OpenTypeFeatures,TextSize=source.TextSize,
					TextColor3=color.Color,TextXAlignment=source.TextXAlignment,TextYAlignment=source.TextYAlignment,
					LineHeight=source.LineHeight,ZIndex=frame.ZIndex+1})
				table.insert(overlay.Glyphs,copy)
				self.Tree.TextItemsByGui[copy]=item
			end
		end
		self.Overlays[item]=overlay
		self.Tree.TextItemsByGui[frame]=item
	end
	if overlay.StyleDirty then
		local color=selectedStyle(self.Tree,item,self.CustomStyle);overlay.StyleDirty=nil
		overlay.Frame.BackgroundColor3=color.Background;overlay.Frame.BackgroundTransparency=1-color.Alpha
		if overlay.Text then overlay.Text.TextColor3=color.Color end
		for _,copy in overlay.Glyphs do copy.TextColor3=color.Color end
	end
	local width,height=dimensions(item,gui)
	overlay.Frame.ZIndex=(gui.ZIndex or 1)+(self.ZOffset or 4096)
	if overlay.Text then overlay.Text.ZIndex=overlay.Frame.ZIndex+1 end
	for _,copy in overlay.Glyphs do copy.ZIndex=overlay.Frame.ZIndex+1 end
	overlay.Frame.Position=UDim2.fromOffset(left,0)
	overlay.Frame.Size=UDim2.fromOffset(right-left,height)
	if overlay.Text then
		overlay.Text.Text=BidiPaint.text(item)
		overlay.Text.FontFace=textLabel.FontFace
		overlay.Text.TextSize=textLabel.TextSize
		overlay.Text.OpenTypeFeatures=textLabel.OpenTypeFeatures
		overlay.Text.LineHeight=textLabel.LineHeight
		overlay.Text.TextDirection=textLabel.TextDirection
		overlay.Text.Position=UDim2.fromOffset(-left,0)
		overlay.Text.Size=UDim2.fromOffset(width,height)
	else
		for index,copy in overlay.Glyphs do
			local glyph=item.Glyphs[index]
			copy.Text=BidiPaint.text(item,glyph.Text)
			copy.FontFace=glyph.Gui.FontFace
			copy.TextSize=glyph.Gui.TextSize
			copy.OpenTypeFeatures=glyph.Gui.OpenTypeFeatures
			copy.LineHeight=glyph.Gui.LineHeight
			copy.TextDirection=glyph.Gui.TextDirection
			copy.Visible=index>first and index<=last
			copy.Position=UDim2.fromOffset(BidiPaint.glyphX(item,glyph)-left,0)
			local glyphWidth,glyphHeight=dimensions(glyph,glyph.Gui)
			copy.Size=UDim2.fromOffset(glyphWidth,glyphHeight)
		end
	end
end

local function gapRect(item: any,following: any): any?
	local leftGui=label(item) or item.Gui
	local rightGui=label(following) or following.Gui
	if not leftGui or not rightGui or leftGui.Parent~=rightGui.Parent then return nil end
	local logical=following.BidiGapRect
	if not logical and item.LineIndex and item.LineIndex==following.LineIndex and item.X and following.X then
		local start=item.X+item.Width;logical={X=start,Width=following.X-start}
	end
	if logical then
		if logical.Width<=0 then return nil end
		if following.VerticalAdvance then
			local scale=if following.Width>0 then rightGui.AbsoluteSize.Y/following.Width else 1
			local scaleX=if following.Height>0 then rightGui.AbsoluteSize.X/following.Height else 1
			local cross=math.max(following.TextSize or 0,following.MeasuredSpaceHeight or following.NativeHeight or following.Height)
			return screenRect(rightGui,(following.Height-cross)/2*scaleX,(logical.X-following.X)*scale,cross*scaleX,logical.Width*scale)
		end
		local _,height,scale,scaleY=dimensions(following,rightGui)
		return screenRect(rightGui,(logical.X-following.X)*scale,0,logical.Width*scale,height*scaleY)
	end
	-- Without logical line geometry only unrotated horizontal screen positions
	-- determine a gap. Never infer a vertical/rotated gap from screen X alone.
	if item.VerticalAdvance or following.VerticalAdvance or(leftGui.AbsoluteRotation or leftGui.Rotation or 0)~=0 or(rightGui.AbsoluteRotation or rightGui.Rotation or 0)~=0 then return nil end
	local left=leftGui.AbsolutePosition.X+leftGui.AbsoluteSize.X
	local width=rightGui.AbsolutePosition.X-left
	local height=math.min(leftGui.AbsoluteSize.Y,rightGui.AbsoluteSize.Y)
	if width<=0 or height<=0 or math.abs(leftGui.AbsolutePosition.Y-rightGui.AbsolutePosition.Y)>height/2 then return nil end
	return {X=left,Y=leftGui.AbsolutePosition.Y,Width=width,Height=height}
end

local function paintGap(self: any,item: any,following: any)
	local rect=gapRect(item,following);if not rect then clearGap(self,item);return false end
	local leftGui=label(item)or item.Gui
	local gap=self.Gaps[item]
	if not gap then
		local color=selectedStyle(self.Tree,following,self.CustomStyle)
		gap=GuiFactory.create('Frame',leftGui,{Name='HTMLSelectionSpace',
			BackgroundColor3=color.Background,BackgroundTransparency=1-color.Alpha,ZIndex=(leftGui.ZIndex or 1)+(self.ZOffset or 4096)})
		self.Gaps[item]=gap
		self.Tree.TextItemsByGui[gap]=following
	end
	local width,_,scaleX,scaleY=dimensions(item,leftGui)
	gap.ZIndex=(leftGui.ZIndex or 1)+(self.ZOffset or 4096)
	local angle=math.rad(leftGui.AbsoluteRotation or leftGui.Rotation or 0);local cosine,sine=math.cos(angle),math.sin(angle)
	local left,top,right,bottom=math.huge,math.huge,-math.huge,-math.huge
	for _,p in {{rect.X,rect.Y},{rect.X+rect.Width,rect.Y},{rect.X+rect.Width,rect.Y+rect.Height},{rect.X,rect.Y+rect.Height}}do
		local dx,dy=p[1]-leftGui.AbsolutePosition.X-leftGui.AbsoluteSize.X/2,p[2]-leftGui.AbsolutePosition.Y-leftGui.AbsoluteSize.Y/2
		local x,y=(dx*cosine+dy*sine+leftGui.AbsoluteSize.X/2)/scaleX,(-dx*sine+dy*cosine+leftGui.AbsoluteSize.Y/2)/scaleY
		left,top,right,bottom=math.min(left,x),math.min(top,y),math.max(right,x),math.max(bottom,y)
	end
	gap.Position=UDim2.fromOffset(left,top);gap.Size=UDim2.fromOffset(right-left,bottom-top)
	return true
end

function TextSelection.new(tree: any,options: any?): any
	local value=setmetatable({Tree=tree,Overlays={},Gaps={},Anchor=nil,EndPoint=nil,Dragging=false,Alive=true,
		CustomStyle=options and options.Style,ZOffset=options and options.ZOffset},TextSelection)
	if not options or options.Register~=false then tree.TextSelection=value end;return value
end

function TextSelection:SetChanged(callback: any)self.Changed=callback end
function TextSelection:RefreshStyles()
	for _,overlay in self.Overlays do overlay.StyleDirty=true end
	for item,gap in self.Gaps do local color=selectedStyle(self.Tree,item,self.CustomStyle);gap.BackgroundColor3=color.Background;gap.BackgroundTransparency=1-color.Alpha end
end
function TextSelection:Notify()
	if self.Alive and self.Changed then return self.Changed(self.Anchor,self.EndPoint)~=false end
	return true
end

-- Host selection changes repaint only text overlays. No CSS invalidation,
-- geometry change or independent render connection is needed.
function TextSelection:Apply(segments: any)
	if not self.Alive then return end
	assert(#segments<=MAX_HIGHLIGHTS,'Text selection highlight budget exceeded')
	local objects=0
	for _,segment in segments do
		if segment.First<segment.Last then objects+=1+(if segment.Item.VerticalAdvance then #(segment.Item.UprightPool or {})elseif segment.Item.Glyphs then #segment.Item.Glyphs else 1)end
		if segment.Previous then objects+=1 end
		assert(objects<=MAX_PAINT_OBJECTS,'Text selection GUI budget exceeded')
	end
	local selected,gaps={},{}
	for _,segment in segments do
		local item=segment.Item
		if selectable(item,self.CustomStyle~=nil) and segment.First<segment.Last then selected[item]=true;paint(self,item,segment.First,segment.Last)end
		if segment.Previous and selectable(item,self.CustomStyle~=nil) and paintGap(self,segment.Previous,item)then gaps[segment.Previous]=true end
	end
	local expired={};for item in self.Overlays do if not selected[item]then table.insert(expired,item)end end
	for _,item in expired do clearOverlay(self,item)end
	table.clear(expired);for item in self.Gaps do if not gaps[item]then table.insert(expired,item)end end
	for _,item in expired do clearGap(self,item)end
end

function TextSelection:Point(point: any): any?
	if not point then return nil end
	if point.Node then return {Node=point.Node,Offset=point.Offset} end
	local ends=graphemes(point.Item);local spans=point.Item.SourceSpans
	local byte=if point.Offset<=0 then 0 else ends[math.min(point.Offset,#ends)]or 0
	for _,span in point.Item.SourceHiddenSpans or {}do if span.Byte==byte then return {Node=span.Node,Offset=span.Start}end end
	if not spans or #spans==0 then return nil end
	for _,span in spans do if span.LastByte>byte then return {Node=span.Node,Offset=span.Start}end end
	local last=spans[#spans];return {Node=last.Node,Offset=last.Finish}
end

function TextSelection:Rect(item: any,first: number,last: number): any?
	local gui=label(item)or item.Gui;if not gui or gui.Visible==false then return nil end
	if item.VerticalAdvance then return Upright.rect(item,first,last)end
	local left,right=widthAt(item,first),widthAt(item,last)
	if TextDirection.of(item)=='rtl'then local width=dimensions(item,gui);left,right=width-right,width-left end
	local _,_,scaleX=dimensions(item,gui);left*=scaleX;right*=scaleX
	return screenRect(gui,left,0,right-left,gui.AbsoluteSize.Y)
end

function TextSelection:GapRect(item: any,following: any): any? return gapRect(item,following)end

function TextSelection:Pick(objects: {any},position: any): any?
	for _,object in objects do
		local current=object
		while current do
			local item=self.Tree.TextItemsByGui[current]
			if item and selectable(item) then return {Item=item,Offset=offsetAt(item,position)} end
			current=current.Parent
		end
	end
	return nil
end

function TextSelection:Clear(silent: boolean?)
	local items={}
	for item in self.Overlays do table.insert(items,item) end
	for _,item in items do clearOverlay(self,item) end
	table.clear(items)
	for item in self.Gaps do table.insert(items,item) end
	for _,item in items do clearGap(self,item) end
	self.Anchor,self.EndPoint,self.Dragging=nil,nil,false
	if not silent then self:Notify()end
end

-- Blank selectable surfaces and editable fields collapse the DOM selection
-- at a node boundary. An absent text hit alone must not empty a live range.
function TextSelection:Collapse(node: any,offset: number?): boolean
	self:Clear(true)
	local point={Node=node,Offset=offset or 0}
	self.Anchor,self.EndPoint=point,point
	return self:Notify()
end

function TextSelection:Begin(objects: {any},position: any,fallbackNode: any?): boolean
	local point=self:Pick(objects,position)
	if not point and fallbackNode then self:Collapse(fallbackNode);return false end
	self:Clear(true)
	if not point then self:Notify();return false end
	self.Anchor,self.EndPoint,self.Dragging=point,point,true
	if not self:Notify()then self.Dragging=false;return false end
	return true
end

function TextSelection:Move(objects: {any},position: any)
	if not self.Dragging or not self.Anchor then return end
	local point=self:Pick(objects,position)
	if not point then return end
	self.EndPoint=point
	if self.Changed then if not self:Notify()then self.Dragging=false end;return end
	local anchor=self.Anchor
	local first,last=anchor,point
	if first.Item.SelectionOrder>last.Item.SelectionOrder or (first.Item==last.Item and first.Offset>last.Offset) then first,last=last,first end
	local selected={}
	local selectedGaps={}
	for index=first.Item.SelectionOrder,last.Item.SelectionOrder do
		local item=self.Tree.TextItems[index]
		if item and selectable(item) and item.Gui.Visible~=false then
			local startOffset=if item==first.Item then first.Offset else 0
			local endOffset=if item==last.Item then last.Offset else #graphemes(item)
			if startOffset<endOffset then selected[item]=true;paint(self,item,startOffset,endOffset) end
			if index<last.Item.SelectionOrder and endOffset>0 then
				local following=self.Tree.TextItems[index+1]
				if following and selectable(following) and paintGap(self,item,following) then selectedGaps[item]=true end
			end
		end
	end
	local expired={}
	for item in self.Overlays do if not selected[item] then table.insert(expired,item) end end
	for _,item in expired do clearOverlay(self,item) end
	table.clear(expired)
	for item in self.Gaps do if not selectedGaps[item] then table.insert(expired,item) end end
	for _,item in expired do clearGap(self,item) end
end

function TextSelection:Finish()
	self.Dragging=false
end

function TextSelection:Destroy()
	if not self.Alive then return end;self.Alive=false;self.Changed=nil
	self:Clear(true)
	if self.Tree.TextSelection==self then self.Tree.TextSelection=nil end
	self.Tree=nil
end

return TextSelection
