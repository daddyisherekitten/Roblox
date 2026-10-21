--!strict
-- Retained emphasis marks belong to the original word. They never become DOM
-- text or selection sources. Measurements are bounded to that word's caches.
local BidiPaint=require(script.Parent.BidiPaint)
local WritingMode=require(script.Parent.Parent.CSS.WritingMode)
local TextShadows=require(script.Parent.Parent.Rendering.TextShadows)
local Emphasis={}
local data
local function inRanges(ranges: any,code: number): boolean
 local low,high=1,#ranges
 while low<=high do local mid=math.floor((low+high)/2);local r=ranges[mid]
  if code<r[1]then high=mid-1 elseif code>r[2]then low=mid+1 else return true end
 end
 return false
end
function Emphasis.eligible(text: string): boolean
	if text==''then return false end
 if not data then data=require(script.Parent.TextEmphasisData)end
 local first=utf8.codepoint(text,1)
 if not inRanges(data.Skip,first)then return true end
 if inRanges(data.Separators,first)then
  for _,code in utf8.codes(text)do if inRanges(data.Marks,code)then return true end end
 end
 return false
end
local function enabled(item: any): boolean
 local mark=item.Style and item.Style.TextEmphasisStyle
 return item.Kind=='Word'and not item.EmptyInline and mark~=nil and (item.Style.FontSize or 0)>0 and mark.Mark~=''
end
local function physicalSide(style: any): number
 local position,mode=style.TextEmphasisPosition,style.WritingMode
 if mode=='sideways-rl'then return if position.Vertical=='under'then -1 else 1
 elseif mode=='sideways-lr'then return if position.Vertical=='under'then 1 else -1 end
 return if position.Horizontal=='left'then -1 else 1
end
function Emphasis.measure(item: any,font: any,size: number,measure: any,alive: any): boolean
 item.EmphasisActive=enabled(item)
 if not item.EmphasisActive then return true end
 local style=item.Style;local cache=item.EmphasisMeasure
 if not cache or cache.Text~=item.Text or cache.Font~=font or cache.Size~=size or cache.Bidi~=item.NativeBidiForced or cache.Direction~=item.BidiDirection then
		local characters={}
		for first,last in utf8.graphemes(item.Text)do
			if not alive()then return false end
			local text=item.Text:sub(first,last)
			table.insert(characters,{Text=text,First=first,Last=last,Eligible=Emphasis.eligible(text)})
  end
		cache={Text=item.Text,Font=font,Size=size,Bidi=item.NativeBidiForced,Direction=item.BidiDirection,Characters=characters}
		item.EmphasisMeasure=cache
	end
	local eligible=false;for _,character in cache.Characters do if character.Eligible then eligible=true;break end end
	if not eligible then item.EmphasisActive=false;return true end
	-- Upright cells and independently tracked glyphs already own exact advances.
	-- Only a native composed word needs prefix bounds, stored on that word alone.
	if not item.VerticalAdvance and not item.Glyphs and not cache.Prefixes then
		local previous=0
		for _,character in cache.Characters do
			local finish=item.NativeWidth
			if character.Last~=#item.Text or item.MeasuredText~=item.Text or finish==nil then
				local bounds,message=measure(BidiPaint.text(item,item.Text:sub(1,character.Last)),font,size,0)
				if not alive()then return false end;assert(bounds,'Emphasis source measurement failed: '..tostring(message));finish=bounds.X
			end
			character.Start,character.Finish=previous,finish;previous=finish
		end
		cache.Prefixes=true
	end
 local mark=style.TextEmphasisStyle.Mark;local markSize=size*.5
 if cache.Mark~=mark or cache.MarkSize~=markSize then
  local bounds,message=measure(mark,font,markSize,0)
  if not alive()then return false end;assert(bounds,'Emphasis mark measurement failed: '..tostring(message))
  cache.Mark,cache.MarkSize,cache.MarkWidth,cache.MarkHeight=mark,markSize,math.max(1,bounds.X),math.max(markSize,bounds.Y)
 end
 return true
end
-- Marks participate in line extents like ruby; unlike a shadow they are not
-- paint-only overflow. Font ascent/descent remains the host's existing profile.
function Emphasis.extents(item: any,vertical: boolean)
 if not item.EmphasisActive then return end
 local markSize=item.EmphasisMeasure.MarkSize;local position=item.Style.TextEmphasisPosition
 local before
 if vertical then before=(physicalSide(item.Style)>0)==WritingMode.blockReverse(item.Style)
 else before=position.Vertical~='under'end
 local extent=if vertical then item.TextSize/2+markSize else (if before then item.Baseline else item.TextSize-item.Baseline)+markSize
 if before then item.Ascent=math.max(item.Ascent,extent-(item.BaselineShift or 0))else item.Descent=math.max(item.Descent,extent+(item.BaselineShift or 0))end
 if item.LineAlign then item.AlignmentHeight=math.max(item.AlignmentHeight or 0,item.Ascent+item.Descent)end
end
local function write(gui: any,key: string,value: any)if gui[key]~=value then gui[key]=value end end
function Emphasis.hide(item: any)
 for _,mark in item.EmphasisPool or {}do mark.Gui.Visible=false end
end
function Emphasis.color(item: any)
 local style=item.Style
 for _,mark in item.EmphasisPool or {}do
  mark.Style=style
  write(mark.TextGui,'TextColor3',style.TextEmphasisColor or style.Color)
  write(mark.TextGui,'TextTransparency',if style.FontSize==0 or style.Visibility=='hidden'then 1 else 1-(style.TextEmphasisColorAlpha or style.ColorAlpha or 1))
  TextShadows.arrange(mark)
 end
end
local function component(value: any,axis: number): number
	local part=if axis==1 then value.X else value.Y
	return if part then part.Offset else value[axis]
end
-- Bounds of real retained mark/shadow boxes in the source GUI parent's axes.
-- CanvasGroups clip their viewport, so line extents alone cannot preserve
-- these outside-the-font-box paint children, particularly after rotation.
function Emphasis.bounds(item: any,offsetX: number?,offsetY: number?): any?
	local gui=item.Gui
	if not gui or gui.Visible==false or not gui.Position or not gui.Size then return nil end
	local w,h=component(gui.Size,1),component(gui.Size,2)
	local anchor=gui.AnchorPoint or Vector2.new(0,0)
	local ox,oy=component(gui.Position,1)-(offsetX or 0),component(gui.Position,2)-(offsetY or 0)
	local rotation=gui.Rotation or 0;local bounds
	for _,mark in item.EmphasisPool or {}do
		if not mark.Gui.Visible or not mark.Gui.Position then continue end
		local dx,dy=component(mark.Gui.Position,1)-w*anchor.X,component(mark.Gui.Position,2)-h*anchor.Y
		local x,y=ox+dx,oy+dy
		if rotation==90 then x,y=ox-dy,oy+dx elseif rotation==-90 then x,y=ox+dy,oy-dx end
		local left,top=x-mark.Width/2,y-mark.Height/2
		local function include(sx: number,sy: number)
			local r={left+sx,top+sy,left+mark.Width+sx,top+mark.Height+sy}
			if not bounds then bounds=r else bounds={math.min(bounds[1],r[1]),math.min(bounds[2],r[2]),math.max(bounds[3],r[3]),math.max(bounds[4],r[4])}end
		end
		if mark.TextGui.TextTransparency~=1 then include(0,0)end
		for _,copy in mark.ShadowLabels or {}do if copy.Gui.Visible then local shadow=mark.Style.TextShadows[copy.Index];include(shadow.X,shadow.Y)end end
	end
	return bounds
end
function Emphasis.paint(run: any,item: any)
 Emphasis.hide(item)
 if not item.EmphasisActive or not run.Factory then return end
 local cache,style=item.EmphasisMeasure,item.Style;local vertical=WritingMode.vertical(style)
 local rotation=item.Gui.Rotation or 0;local position=style.TextEmphasisPosition
 item.EmphasisPool=item.EmphasisPool or {}
 for index,character in cache.Characters do
  if not character.Eligible then continue end
  local mark=item.EmphasisPool[index]
  if not mark then
   mark={Style=style,Kind='Emphasis',Owner=item}
   mark.Gui=run.Factory.create('Frame',item.Gui,{Name='Emphasis_'..index,AnchorPoint=Vector2.new(.5,.5),Visible=false,ZIndex=18})
   mark.TextGui=run.Factory.create('TextLabel',mark.Gui,{Name='Mark',LineHeight=1,TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center,ZIndex=18})
   TextShadows.create(mark,run.Factory.create);item.EmphasisPool[index]=mark
  end
  mark.Style,mark.Text,mark.TextSize,mark.FontFace=style,cache.Mark,cache.MarkSize,item.FontFace
  mark.Width,mark.Height,mark.ShadowRotation=cache.MarkWidth,cache.MarkHeight,0
  mark.First,mark.Last=character.First,character.Last
  local center
  if item.VerticalAdvance then local glyph=item.VerticalCharacters[index];center=glyph.Advance+glyph.Cell/2
  elseif item.Glyphs then local glyph=item.Glyphs[index];center=BidiPaint.glyphX(item,glyph)+glyph.Width/2
  else center=(character.Start+character.Finish)/2;if item.BidiDirection=='rtl'then center=item.Width-center end end
  local mx,my
  if vertical then
   local distance=(item.NativeHeight or item.Height)/2+cache.MarkWidth/2
   local side=physicalSide(style)
   if item.VerticalAdvance then mx,my=item.Height/2+side*distance,center
   elseif rotation==90 then mx,my=center,item.Height/2-side*distance
   else mx,my=center,item.Height/2+side*distance end
  else mx,my=center,if position.Vertical=='under'then item.Height+cache.MarkHeight/2 else -cache.MarkHeight/2 end
  write(mark.Gui,'Visible',style.Visibility~='hidden');write(mark.Gui,'Rotation',-rotation)
  write(mark.Gui,'Position',UDim2.fromOffset(mx,my));write(mark.Gui,'Size',UDim2.fromOffset(cache.MarkWidth,cache.MarkHeight))
  write(mark.TextGui,'Text',cache.Mark);write(mark.TextGui,'FontFace',item.FontFace);write(mark.TextGui,'TextSize',cache.MarkSize)
  write(mark.TextGui,'OpenTypeFeatures',style.OpenTypeFeatures);write(mark.TextGui,'Size',UDim2.fromOffset(cache.MarkWidth,cache.MarkHeight))
 end
 Emphasis.color(item)
end
return Emphasis
