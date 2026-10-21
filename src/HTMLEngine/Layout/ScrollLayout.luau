--!strict
local BorderGeometry = require(script.Parent.BorderGeometry)
local LengthExpression=require(script.Parent.Parent.CSS.LengthExpression)
local WritingMode=require(script.Parent.Parent.CSS.WritingMode)
-- Native scrolling moves one content subtree; layout runs only when sizes change.
local ScrollLayout = {}
local DirtyLayout = require(script.Parent.DirtyLayout)
local function thickness(box: any): number
	return if box.Style.ScrollbarWidth=="none" then 0 elseif box.Style.ScrollbarWidth=="thin" then 6 else 10
end
local function gutter(box: any,axis: string): number
	local value=box.Style.ScrollbarGutter
	if not value or not value.Stable then return 0 end
	local vertical = WritingMode.vertical(box.Style)
	if axis ~= (if vertical then "X" else "Y") then return 0 end
	local overflow=if axis=="X" then box.Style.OverflowX else box.Style.OverflowY
	if overflow~="auto" and overflow~="scroll" and overflow~="hidden" then return 0 end
	return thickness(box)*(if value.BothEdges then 2 else 1)
end

-- These are host metrics, shared by intrinsic sizing and placed scrollports.
-- A zero-width scrollbar never reserves a gutter, including stable/both-edges.
function ScrollLayout.reserved(box: any,axis: string): number
	if box.Kind=='Words'or box.Kind=='BlockImage'then return 0 end
	return math.max(if (if axis=="X"then box.Style.OverflowX else box.Style.OverflowY)=="scroll"then thickness(box)else 0,gutter(box,axis))
end
function ScrollLayout.needsWidthProbe(box: any): boolean
	return box.Kind~='Words'and box.Kind~='BlockImage'and thickness(box)>0 and box.Style.OverflowY=="auto"and ScrollLayout.reserved(box,"Y")==0
end
function ScrollLayout.has(box: any): boolean
	if box.Kind=='Words'or box.Kind=='BlockImage'then return false end
	local s=box.Style
	return box.ScrollGui~=nil or ScrollLayout.reserved(box,"X")>0 or ScrollLayout.reserved(box,"Y")>0
		or box.GeometryOnly==true and(s.OverflowX=='auto'or s.OverflowX=='scroll'or s.OverflowY=='auto'or s.OverflowY=='scroll')
end

local function resetGutters(box: any)
	local size = thickness(box)
	box.ScrollX = ScrollLayout.reserved(box,"X")
	box.ScrollY = ScrollLayout.reserved(box,"Y")
	local both = box.Style.ScrollbarGutter and box.Style.ScrollbarGutter.BothEdges
	box.ScrollLeadingX = if both and gutter(box, "Y") > size then size else 0
	box.ScrollLeadingY = if both and gutter(box, "X") > size then size else 0
end

local function write(gui: any, key: string, value: any)
	if gui[key] ~= value then gui[key] = value end
end

local function length(value: any,basis: number): number
	if type(value)=="number" then return value end
	return if value then LengthExpression.resolve(value,basis) else 0
end

local function descendants(box: any, visit: (any,number,number) -> any): boolean
	local function walk(parent: any, x: number, y: number): boolean
		for _,child in parent.Children or {} do
			if child.Kind=="Words" or not child.Style then continue end
			local left,top=x+(child.LayoutX or 0),y+(child.LayoutY or 0)
			local outcome=visit(child,left,top)
			if outcome==true then return true end
			-- A nested scrollport establishes a separate nearest scroll container.
			if outcome~="skip" and not child.ScrollGui and walk(child,left,top) then return true end
		end
		return false
	end
	return walk(box,0,0)
end

local function anchorSnapshot(box: any): any?
	local gui=box.ScrollGui
	if not gui or box.Style.OverflowAnchor=="none" or not box.OuterHeight then return nil end
	local position=gui.CanvasPosition
	if position.X<=0 and position.Y<=0 then return nil end
	local viewWidth=math.max(0,(box.OuterWidth or 0)-(box.ScrollY or 0))
	local viewHeight=math.max(0,(box.OuterHeight or 0)-(box.ScrollX or 0))
	local selected,selectedX,selectedY,nearest=nil,0,0,math.huge
	local vertical=WritingMode.vertical(box.Style)
	descendants(box,function(child,left,top)
		local style=child.Style
		if style.OverflowAnchor=="none" or style.Position=="fixed" or style.Position=="sticky" or style.Position=="absolute" then return "skip" end
		local right,bottom=left+(child.OuterWidth or 0),top+(child.OuterHeight or 0)
		if right>position.X and left<position.X+viewWidth and bottom>position.Y and top<position.Y+viewHeight then
			local distance=if vertical then math.max(0,left-position.X)+math.max(0,top-position.Y)*.001
				else math.max(0,top-position.Y)+math.max(0,left-position.X)*.001
			if distance<=nearest then selected,selectedX,selectedY,nearest=child,left,top,distance end
		end
		return false
	end)
	return if selected then {Node=selected,X=selectedX,Y=selectedY,Position=position} else nil
end

local function descendantPosition(box: any,target: any): (number?,number?)
	local foundX,foundY=nil,nil
	descendants(box,function(child,left,top)
		if child==target then foundX,foundY=left,top;return true end
		return false
	end)
	return foundX,foundY
end

local function initialTarget(box: any): (any?,number?,number?)
	local found,foundX,foundY=nil,nil,nil
	descendants(box,function(child,left,top)
		if child.Style.ScrollInitialTarget=="nearest" then found,foundX,foundY=child,left,top;return true end
		return false
	end)
	return found,foundX,foundY
end

local function physicalAlign(style: any,align: any): (string,string)
	local vertical=WritingMode.vertical(style)
	local function physical(mode: string,reverse: boolean): string
		return if reverse and mode=='start'then 'end'elseif reverse and mode=='end'then 'start'else mode
	end
	return physical(if vertical then align.Block else align.Inline,if vertical then WritingMode.blockReverse(style)else WritingMode.inlineReverse(style)),
		physical(if vertical then align.Inline else align.Block,if vertical then WritingMode.inlineReverse(style)else false)
end
local function markerTarget(box: any,child: any,width: number,height: number): any
	local horizontal,downward=physicalAlign(box.Style,child.Style.ScrollSnapAlign or {Inline="start",Block="start"})
	local padding=box.Style.ScrollPadding or {0,0,0,0}
	local margin=child.Style.ScrollMargin or {0,0,0,0}
	local function target(start: number,size: number,view: number,mode: string,padStart: number,padEnd: number,marginStart: number,marginEnd: number): number
		if mode=="center" then return start+size/2-view/2+(marginEnd-marginStart+padEnd-padStart)/2
		elseif mode=="end" then return start+size+marginEnd-view+padEnd
		else return start-marginStart-padStart end
	end
	local x=target(child.LayoutX or 0,child.OuterWidth or 0,width,horizontal,
		length(padding[4],width),length(padding[2],width),length(margin[4],width),length(margin[2],width))
	local y=target(child.LayoutY or 0,child.OuterHeight or 0,height,downward,
		length(padding[1],height),length(padding[3],height),length(margin[1],height),length(margin[3],height))
	return Vector2.new(math.max(0,x),math.max(0,y))
end

function ScrollLayout.refreshMarkers(box: any)
	if box.ScrollDestroyed then return end
	local targets, markers = box.ScrollMarkerTargets, box.ScrollMarkers
	if not targets or not markers or #targets==0 then return end
	local gui=box.ScrollGui
	local canvas=gui.CanvasSize
	local canvasWidth=if canvas.X then canvas.X.Offset else canvas[1] or 0
	local canvasHeight=if canvas.Y then canvas.Y.Offset else canvas[2] or 0
	local maxX=math.max(0,canvasWidth-(box.ScrollMarkerViewWidth or 0))
	local maxY=math.max(0,canvasHeight-(box.ScrollMarkerViewHeight or 0))
	local position=gui.CanvasPosition
	local axis=box.Style.ScrollSnapType and box.Style.ScrollSnapType.Axis
	local vertical=WritingMode.vertical(box.Style)
	local horizontal=axis=="x"or axis=="inline"and not vertical or axis=="block"and vertical or(axis~="x"and axis~="y"and axis~="inline"and axis~="block"and maxX>maxY)
	local active,nearest=1,math.huge
	for index,target in targets do
		local distance=if horizontal then math.abs(position.X-math.clamp(target.X,0,maxX)) else math.abs(position.Y-math.clamp(target.Y,0,maxY))
		if distance<nearest then active,nearest=index,distance end
	end
	for index,marker in markers do
		local child=box.ScrollMarkerChildren and box.ScrollMarkerChildren[index]
		if not child or not marker.Visible then continue end
		local current=index==active
		local style=if current then child.ScrollMarkerCurrentStyle or child.ScrollMarkerStyle else child.ScrollMarkerStyle
		local label=if current then child.ScrollMarkerCurrentText or child.ScrollMarkerText else child.ScrollMarkerText
		if style then
			write(marker,"BackgroundTransparency",if style.Background then 1-(style.BackgroundAlpha or 1) else 1)
			if style.Background then write(marker,"BackgroundColor3",style.Background) end
			write(marker,"Text",if label and label~="" then label else "●")
			write(marker,"TextColor3",style.Color)
			write(marker,"TextTransparency",1-(style.ColorAlpha or 1))
			write(marker,"TextSize",style.FontSize or 16)
			if child.ScrollMarkerFontFace then write(marker,"FontFace",child.ScrollMarkerFontFace) end
		else
			write(marker,"BackgroundTransparency",0)
			write(marker,"BackgroundColor3",Color3.fromRGB(22,137,113))
			write(marker,"Text","")
		end
	end
end

function ScrollLayout.scrollToMarker(box: any,index: number): boolean
	if box.ScrollDestroyed then return false end
	local target=box.ScrollMarkerTargets and box.ScrollMarkerTargets[index]
	local gui=box.ScrollGui
	if not target or not gui then return false end
	local canvas=gui.CanvasSize
	local canvasWidth=if canvas.X then canvas.X.Offset else canvas[1] or 0
	local canvasHeight=if canvas.Y then canvas.Y.Offset else canvas[2] or 0
	local maxX=math.max(0,canvasWidth-(box.ScrollMarkerViewWidth or 0))
	local maxY=math.max(0,canvasHeight-(box.ScrollMarkerViewHeight or 0))
	local destination=Vector2.new(math.clamp(target.X,0,maxX),math.clamp(target.Y,0,maxY))
	if box.ScrollMarkerTweenConnection then box.ScrollMarkerTweenConnection:Disconnect();box.ScrollMarkerTweenConnection=nil end
	if box.ScrollMarkerTween then box.ScrollMarkerTween:Cancel();box.ScrollMarkerTween=nil end
	if box.ScrollSnapTween then box.ScrollSnapTween:Cancel();box.ScrollSnapTween=nil end
	box.ScrollMarkerNavigating=false
	if destination==gui.CanvasPosition then return false end
	local service=box.TweenService
	if box.Style.ScrollBehavior=="smooth" and not service then
		local ok,result=pcall(function() return game:GetService("TweenService") end)
		if ok then service=result end
	end
	if box.Style.ScrollBehavior=="smooth" and service then
		local ok,tween=pcall(function()
			return service:Create(gui,TweenInfo.new(.3,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{CanvasPosition=destination})
		end)
		if ok and tween then
			box.ScrollMarkerTween=tween
			box.ScrollMarkerNavigating=true
			if tween.Completed then
				box.ScrollMarkerTweenConnection=tween.Completed:Connect(function()
					if box.ScrollMarkerTween~=tween then return end
					box.ScrollMarkerTween=nil
					box.ScrollMarkerNavigating=false
					if box.ScrollMarkerTweenConnection then box.ScrollMarkerTweenConnection:Disconnect();box.ScrollMarkerTweenConnection=nil end
					ScrollLayout.refreshMarkers(box)
				end)
			end
			tween:Play()
			return true
		end
	end
	gui.CanvasPosition=destination
	ScrollLayout.refreshMarkers(box)
	return true
end

local function markers(box: any,width: number,height: number)
	local mode=box.Style.ScrollMarkerGroup
	if mode==nil or mode=="none" or not box.Factory then
		if box.ScrollMarkerGui then write(box.ScrollMarkerGui,"Visible",false) end
		return
	end
	local candidates={}
	for _,child in box.Children or {} do
		local align=child.Kind~="Words" and child.Style and child.Style.ScrollSnapAlign
		if align and (align.Inline~="none" or align.Block~="none") then table.insert(candidates,child) end
	end
	if #candidates==0 then if box.ScrollMarkerGui then write(box.ScrollMarkerGui,"Visible",false) end;return end
	if not box.ScrollMarkerGui then
		box.ScrollMarkerGui=box.Factory.create("Frame",box.Gui.Parent,{Name="ScrollMarkerGroup",BackgroundTransparency=1,ZIndex=100005})
		box.ScrollMarkers={};box.ScrollMarkerTargets={};box.ScrollMarkerChildren={};box.ScrollMarkerConnections={}
	end
	local group=box.ScrollMarkerGui;write(group,"Visible",box.Style.Visibility~="hidden")
	box.ScrollMarkerViewWidth,box.ScrollMarkerViewHeight=width,height
	local cell=14
	for _,child in candidates do
		local style=child.ScrollMarkerStyle or child.ScrollMarkerCurrentStyle
		if style then
			local padding=style.Padding or {0,0,0,0}
			local function pixels(value: any): number return if type(value)=="number" then value else 0 end
			local fontSize=style.FontSize or 16
			cell=math.max(cell,math.ceil(fontSize+math.max(pixels(padding[2])+pixels(padding[4]),pixels(padding[1])+pixels(padding[3]))))
		end
	end
	local hostPosition=box.Gui.Position
	local hostX=if hostPosition.X then hostPosition.X.Offset else hostPosition[1] or 0
	local hostY=if hostPosition.Y then hostPosition.Y.Offset else hostPosition[2] or 0
	write(group,"Position",UDim2.fromOffset(hostX,hostY+(if mode=="before" then -cell else box.OuterHeight+2)))
	write(group,"Size",UDim2.fromOffset(#candidates*cell,cell))
	for index,child in candidates do
		local marker=box.ScrollMarkers[index]
		if not marker then
			marker=box.Factory.create("TextButton",group,{Name="ScrollMarker_"..index,Text="",AutoButtonColor=false,BorderSizePixel=0,ZIndex=100005,
				TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center})
			box.Factory.modifier("UICorner",marker,{CornerRadius=UDim.new(.5,0)});box.ScrollMarkers[index]=marker
		end
		write(marker,"Visible",true);write(marker,"Position",UDim2.fromOffset((index-1)*cell+(if cell==14 then 2 else 0),if cell==14 then 1 else 0))
		write(marker,"Size",UDim2.fromOffset(if cell==14 then 8 else cell,if cell==14 then 8 else cell))
		box.ScrollMarkerChildren[index]=child
		box.ScrollMarkerTargets[index]=markerTarget(box,child,width,height)
		if not box.ScrollMarkerConnections[index] then
			local ok,connection=pcall(function() return marker.Activated:Connect(function()
				ScrollLayout.scrollToMarker(box,index)
			end) end)
			if ok then box.ScrollMarkerConnections[index]=connection end
		end
	end
	for index=#candidates+1,#(box.ScrollMarkers or {}) do write(box.ScrollMarkers[index],"Visible",false);box.ScrollMarkerChildren[index]=nil;box.ScrollMarkerTargets[index]=nil end
	if not box.ScrollMarkerScrollConnection then
		local ok,connection=pcall(function() return box.ScrollGui:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			ScrollLayout.refreshMarkers(box)
		end) end)
		if ok then box.ScrollMarkerScrollConnection=connection end
	end
	ScrollLayout.refreshMarkers(box)
end

function ScrollLayout.reset(box: any, entries: {any})
	if box.Style and box.Style.Hidden then return end
	if box.Style and ScrollLayout.has(box) then
		box.AnchorSnapshot=anchorSnapshot(box)
		local c = box.DirtyContext
		box.ScrollNeedsReset = c ~= nil and c.Active and c.Reuse
		box.ScrollParticipated = not box.ScrollNeedsReset
		if not box.ScrollNeedsReset then
			resetGutters(box)
		end
		table.insert(entries, box)
	elseif box.Style and(box.ScrollX~=nil or box.ScrollY~=nil)then
		-- Removing a stable hidden gutter has no native scroll surface to reset.
		resetGutters(box)
	end
	for _, child in box.Children or {} do ScrollLayout.reset(child, entries) end
end

function ScrollLayout.prepare(box: any)
	if not ScrollLayout.has(box) then return end
	if box.ScrollNeedsReset then
		resetGutters(box)
		box.ScrollNeedsReset = false
	end
	box.ScrollParticipated = true
end

function ScrollLayout.settle(entries: {any}): boolean
	local changed = false
	for _, box in entries do
		if box.ScrollParticipated == false then continue end
		-- Add gutters monotonically in this layout; a new resize starts without auto gutters.
		local x, y = box.ScrollX, box.ScrollY
		local size=thickness(box)
		local vertical=WritingMode.vertical(box.Style)
		local reverseInline=WritingMode.inlineReverse(box.Style)
		local right=box.ScrollRight-(if not vertical and reverseInline then math.min(0,box.ScrollStartX or 0)else 0)
		local bottom=box.ScrollBottom-(if vertical and reverseInline then math.min(0,box.ScrollStartY or 0)else 0)
		if x == 0 and box.Style.OverflowX == "auto" and right > box.OuterWidth - y + .01 then
			box.ScrollX, changed = size, size>0 or changed
		end
		-- Test against the gutters used by this pass: auto height can grow for a new horizontal bar.
		if y == 0 and box.Style.OverflowY == "auto" and bottom > (box.TableGridHeight or box.OuterHeight) - x + .01 then
			box.ScrollY, changed = size, size>0 or changed
		end
		if box.ScrollX ~= x or box.ScrollY ~= y then DirtyLayout.invalidate(box) end
	end
	return changed
end

-- Theme/scrollbar colors do not change the scrollport or its canvas geometry.
function ScrollLayout.paint(box: any)
	local s,gui=box.Style,box.ScrollGui
	if not gui then return end
	local scrollbar=s.ScrollbarColor
	write(gui,"ScrollBarImageColor3",if scrollbar and not scrollbar.Auto then scrollbar.Thumb else Color3.fromRGB(139,139,139))
	write(gui,"ScrollBarImageTransparency",if s.Visibility~="hidden"and thickness(box)>0 then 1-(if scrollbar and not scrollbar.Auto then scrollbar.ThumbAlpha or 1 else 1)else 1)
	for _,axis in {"X","Y"}do
		local track=box["ScrollTrack"..axis]
		if track then
			write(track,"BackgroundColor3",if scrollbar and not scrollbar.Auto then scrollbar.Track else Color3.fromRGB(225,225,225))
			write(track,"BackgroundTransparency",if scrollbar and not scrollbar.Auto then 1-(scrollbar.TrackAlpha or 1)else 0)
		end
	end
end

function ScrollLayout.commit(entries: {any})
	for _, box in entries do
		if box.ScrollParticipated == false then continue end
		local s, gui = box.Style, box.ScrollGui
		-- A stable hidden gutter participates in geometry without a ScrollingFrame.
		if not gui then continue end
		write(gui,"ClipsDescendants",s.OverflowX~="visible" or s.OverflowY~="visible")
		write(gui,"ScrollingEnabled",s.OverflowX=="auto" or s.OverflowX=="scroll" or s.OverflowY=="auto" or s.OverflowY=="scroll")
		local barSize = thickness(box)
		write(gui, "ScrollBarThickness", barSize)
		ScrollLayout.paint(box)
		write(gui, "ElasticBehavior", if s.OverscrollX == "auto" and s.OverscrollY == "auto" then Enum.ElasticBehavior.WhenScrollable else Enum.ElasticBehavior.Never)
		write(gui, "ScrollingDirection", if s.TouchAction == "pan-x" then Enum.ScrollingDirection.X elseif s.TouchAction == "pan-y" then Enum.ScrollingDirection.Y
			elseif s.OverflowX == "hidden" then Enum.ScrollingDirection.Y elseif s.OverflowY == "hidden" then Enum.ScrollingDirection.X else Enum.ScrollingDirection.XY)
		local bt, br, bb, bl = BorderGeometry.sizes(s)
		local width, height = math.max(0, box.OuterWidth - br - bl), math.max(0, (box.TableGridHeight or box.OuterHeight) - bt - bb)
		local viewWidth, viewHeight = math.max(0, width - box.ScrollY), math.max(0, height - box.ScrollX)
		local canvasWidth = if s.OverflowX == "hidden" then viewWidth else math.max(viewWidth, box.ScrollRight - br - bl)
		local canvasHeight = if s.OverflowY == "hidden" then viewHeight else math.max(viewHeight, box.ScrollBottom - bt - bb)
		-- Snapshot before native size changes can clamp the old position.
		local position = gui.CanvasPosition
		local leadingX, leadingY = box.ScrollLeadingX or 0, box.ScrollLeadingY or 0
		write(gui, "Position", UDim2.fromOffset(bl + leadingX, bt + leadingY))
		write(gui, "Size", UDim2.fromOffset(math.max(0, width - leadingX), math.max(0, height - leadingY)))
		write(gui, "HorizontalScrollBarInset", if box.ScrollX > 0 then Enum.ScrollBarInset.Always else Enum.ScrollBarInset.None)
		write(gui, "VerticalScrollBarInset", if box.ScrollY > 0 then Enum.ScrollBarInset.Always else Enum.ScrollBarInset.None)
		write(gui, "CanvasSize", UDim2.fromOffset(if canvasWidth > viewWidth + .01 then canvasWidth else 0,
			if canvasHeight > viewHeight + .01 then canvasHeight else 0))
		write(box.ScrollContent, "Position", UDim2.fromOffset(-bl - leadingX, -bt - leadingY))
		write(box.ScrollContent, "Size", UDim2.fromOffset(canvasWidth + br + bl, canvasHeight + bt + bb))
		local targetX,targetY=position.X,position.Y
		if not box.ScrollInitialApplied then
			local target,left,top=initialTarget(box)
			if target and position.X==0 and position.Y==0 then
				local vertical=WritingMode.vertical(s)
				if vertical then
					targetX=if WritingMode.blockReverse(s)then (left or 0)+(target.OuterWidth or 0)-viewWidth else left or 0
					local bottom=(top or 0)+(target.OuterHeight or 0)
					if (top or 0)<targetY then targetY=top or 0
					elseif bottom>targetY+viewHeight then targetY=bottom-viewHeight end
				else
					targetY=top or 0
					local right=(left or 0)+(target.OuterWidth or 0)
					if (left or 0)<targetX then targetX=left or 0
					elseif right>targetX+viewWidth then targetX=right-viewWidth end
				end
				box.ScrollInitialApplied=true
			elseif position.X~=0 or position.Y~=0 then box.ScrollInitialApplied=true end
		end
		local anchor=box.AnchorSnapshot
		if anchor and position==anchor.Position then
			local newX,newY=descendantPosition(box,anchor.Node)
			if newX then
				if position.X>0 then targetX+=(newX-anchor.X) end
				if position.Y>0 then targetY+=(newY-anchor.Y) end
			end
		end
		box.AnchorSnapshot=nil
		write(gui, "CanvasPosition", Vector2.new(math.clamp(targetX, 0, math.max(0, canvasWidth - viewWidth)),
			math.clamp(targetY, 0, math.max(0, canvasHeight - viewHeight))))
		markers(box,viewWidth,viewHeight)
		for _, axis in {"X", "Y"} do
			local track = box["ScrollTrack" .. axis]
			if not track then continue end
			local horizontal = axis == "X"
			write(track, "Position", UDim2.fromOffset(bl + (if horizontal then 0 else viewWidth), bt + (if horizontal then viewHeight else 0)))
			local size=thickness(box)
			write(track, "Size", UDim2.fromOffset(if horizontal then viewWidth else math.min(size, width),
				if horizontal then math.min(size, height) else viewHeight))
			write(track, "Visible", s.Visibility ~= "hidden" and (if horizontal then canvasWidth <= viewWidth + .01 else canvasHeight <= viewHeight + .01))
		end
	end
end

function ScrollLayout.snapTargets(box: any): (any?,any?,any?)
	if box.ScrollDestroyed then return nil,nil,nil end
	local gui,s=box.ScrollGui,box.Style
	local snap=s and s.ScrollSnapType
	if not gui or not snap or snap.Axis=="none" or box.ScrollMarkerNavigating then return nil,nil,nil end
	local width=math.max(0,box.OuterWidth-(box.ScrollY or 0));local height=math.max(0,box.OuterHeight-(box.ScrollX or 0))
	local padding=s.ScrollPadding or {0,0,0,0};local current=gui.CanvasPosition
	local bestX,bestY,dx,dy=current.X,current.Y,math.huge,math.huge
	local targetX,targetY
	local vertical=WritingMode.vertical(s)
	local axisX=snap.Axis=='x'or snap.Axis=='both'or snap.Axis=='inline'and not vertical or snap.Axis=='block'and vertical
	local axisY=snap.Axis=='y'or snap.Axis=='both'or snap.Axis=='inline'and vertical or snap.Axis=='block'and not vertical
	for _,child in box.Children or {} do
		if child.Kind=="Words" or not child.Style then continue end
		local align=child.Style.ScrollSnapAlign
		if not align or (align.Block=="none" and align.Inline=="none") then continue end
		local horizontal,downward=physicalAlign(s,align)
		local margin=child.Style.ScrollMargin or {0,0,0,0}
		local function target(start,sizeValue,view,mode,padStart,padEnd,marginStart,marginEnd)
			if mode=="center" then return start+sizeValue/2-view/2+(marginEnd-marginStart+padEnd-padStart)/2
			elseif mode=="end" then return start+sizeValue+marginEnd-view+padEnd
			else return start-marginStart-padStart end
		end
		if horizontal~="none" and axisX then
			local value=target(child.LayoutX or 0,child.OuterWidth or 0,width,horizontal,length(padding[4],width),length(padding[2],width),length(margin[4],width),length(margin[2],width))
			local distance=math.abs(value-current.X);if distance<dx then dx,bestX,targetX=distance,value,child end
		end
		if downward~="none" and axisY then
			local value=target(child.LayoutY or 0,child.OuterHeight or 0,height,downward,length(padding[1],height),length(padding[3],height),length(margin[1],height),length(margin[3],height))
			local distance=math.abs(value-current.Y);if distance<dy then dy,bestY,targetY=distance,value,child end
		end
	end
	local canvas=gui.CanvasSize
	local canvasWidth=if canvas.X then canvas.X.Offset else canvas[1] or 0;local canvasHeight=if canvas.Y then canvas.Y.Offset else canvas[2] or 0
	local maxX=math.max(0,canvasWidth-width);local maxY=math.max(0,canvasHeight-height)
	local nextPosition=Vector2.new(math.clamp(bestX,0,maxX),math.clamp(bestY,0,maxY))
	return nextPosition,targetX,targetY
end
function ScrollLayout.snap(box: any, instant: boolean?): boolean
	local nextPosition=ScrollLayout.snapTargets(box);if not nextPosition then return false end
	local gui=box.ScrollGui
	if box.ScrollSnapTween then
		local previous=box.ScrollSnapTween;box.ScrollSnapTween=nil
		previous:Cancel()
		if box.ScrollDestroyed or box.ScrollGui~=gui or box.ScrollSnapTween then return false end
	end
	if nextPosition==gui.CanvasPosition then return false end
	local tweenService=box.TweenService
	if not instant then
		if not tweenService then
			local ok,result=pcall(function() return game:GetService("TweenService") end)
			if ok then tweenService=result end
		end
	else tweenService=nil
	end
	if tweenService then
		local tween=tweenService:Create(gui,TweenInfo.new(.18,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{CanvasPosition=nextPosition})
		box.ScrollSnapTween=tween
		tween:Play()
	else gui.CanvasPosition=nextPosition end
	return true
end

function ScrollLayout.snapTree(box: any): boolean
	if box.ScrollDestroyed then return false end
	if box.LayoutInProgress or box.LayoutNeedsRecovery then box.ScrollSnapPending = true; return false end
	local changed=ScrollLayout.snap(box)
	for _,child in box.Children or {} do if child.Kind~="Words" then changed=ScrollLayout.snapTree(child) or changed end end
	return changed
end

-- PageSession owns the Gui tree; stop work which can otherwise outlive those
-- instances. Clear identity guards before Cancel, which may fire Completed.
function ScrollLayout.destroyTree(box: any)
	if box.ScrollDestroyed then return end
	box.ScrollDestroyed=true
	for _,field in {"ScrollMarkerTweenConnection","ScrollMarkerScrollConnection"} do
		local connection=box[field];box[field]=nil
		if connection then connection:Disconnect() end
	end
	for _,connection in box.ScrollMarkerConnections or {} do connection:Disconnect() end
	box.ScrollMarkerConnections=nil
	for _,field in {"ScrollMarkerTween","ScrollSnapTween"} do
		local tween=box[field];box[field]=nil
		if tween then tween:Cancel() end
	end
	box.ScrollMarkerNavigating=false
	box.ScrollMarkerTargets,box.ScrollMarkerChildren,box.AnchorSnapshot=nil,nil,nil
	for _,child in box.AllChildren or box.Children or {} do ScrollLayout.destroyTree(child) end
end

return ScrollLayout
