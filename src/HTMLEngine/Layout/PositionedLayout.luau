--!strict
local BorderGeometry = require(script.Parent.BorderGeometry)
-- Position boxes after normal flow has established containing-block sizes.
-- Coordinates stay numeric; no AbsolutePosition reads or style mutation.
local PositionedLayout = {}
local DirtyLayout = require(script.Parent.DirtyLayout)
local LengthExpression=require(script.Parent.Parent.CSS.LengthExpression)
local Transform2D=require(script.Parent.Parent.CSS.Transform2D)
local AnchorPosition=require(script.Parent.Parent.CSS.AnchorPosition)
local LayoutProbe=require(script.Parent.LayoutProbe)
local AnchorRegistry=require(script.Parent.AnchorRegistry)
local AnchorFallback=require(script.Parent.AnchorFallback)
local BoxSpacing=require(script.Parent.BoxSpacing)
local PositionArea=require(script.Parent.Parent.CSS.PositionArea)
local WritingMode=require(script.Parent.Parent.CSS.WritingMode)
local BoxAlignment=require(script.Parent.BoxAlignment)

function PositionedLayout.establishesFixedContainingBlock(style: any, box: any?): boolean
	local contain = style.Contain or {}
	-- Sampled transforms and current transform effects share the same block.
	-- The latter have implicit will-change even while their value is none.
	local transformed=if box and box.AnimationTransformContainingBlock~=nil then box.AnimationTransformContainingBlock else #Transform2D.operations(style)>0
	return transformed or style.Perspective ~= nil
		or (style.Filter and #style.Filter.Steps > 0) or contain.Layout == true or contain.Paint == true
end

local function value(length: any, size: number?): number?
	if length and length.Kind=='anchor'then length=length.Fallback end
	if not length or (length.Percent and size == nil) then return nil end
	return LengthExpression.resolve(length,size or 0)
end

local function write(gui: any, key: string, result: any)
	if gui[key] ~= result then gui[key] = result end
end

local function axis(start: number?, finish: number?, size: number, space: number, before: number, after: number,
	autoBefore: boolean, autoAfter: boolean, fallback: number, horizontal: boolean, reverse: boolean?): number
	if start ~= nil then
		local free = space - start - (finish or 0) - size - before - after
		if finish ~= nil then
			if autoBefore and autoAfter then
				if horizontal and free<0 then
					if reverse then before+=free else after+=free end
				else before+=free/2;after+=free/2 end
			elseif autoBefore then before+=free elseif autoAfter then after+=free end
		end
		return if reverse and finish~=nil then space-finish-after-size else start+before
	elseif finish ~= nil then return space - finish - after - size end
	return fallback + before
end

local function flexStatic(parent: any, child: any): (number, number)
	local s, m = parent.Style, child.LayoutMargin
	local row = s.FlexDirection ~= "column" and s.FlexDirection ~= "column-reverse"
	local reversed = s.FlexDirection == "row-reverse" or s.FlexDirection == "column-reverse"
	local w, h = child.OuterWidth + m[2] + m[4], child.OuterHeight + m[1] + m[3]
	local freeMain = if row then parent.ContentWidth - w else parent.ContentHeight - h
	local freeCross = if row then parent.ContentHeight - h else parent.ContentWidth - w
	local justify,justifySafety = BoxAlignment.split(s.JustifyContent)
	local main = if justify == "center" or justify == "space-around" or justify == "space-evenly" then freeMain / 2
		elseif justify == "flex-end" then freeMain else 0
	local align,alignSafety = BoxAlignment.split(if child.Style.AlignSelf == "auto" then s.AlignItems else child.Style.AlignSelf)
	local cross = if align == "center" then freeCross / 2 elseif align == "flex-end" then freeCross else 0
	if justifySafety and BoxAlignment.horizontalContainer(s)then
		local mainReverse=reversed~=(row and s.Direction=="rtl")
		main=BoxAlignment.offset(BoxAlignment.resolve(s.JustifyContent,row,s,s,mainReverse,freeMain),freeMain)
		-- The physical edge is resolved already; the legacy reversal below is bypassed.
	elseif reversed then main = freeMain - main end
	if alignSafety and BoxAlignment.horizontalContainer(s)then
		local crossReverse=(s.FlexWrap=="wrap-reverse")~=(not row and s.Direction=="rtl")
		local raw=if child.Style.AlignSelf=="auto"then s.AlignItems else child.Style.AlignSelf
		cross=BoxAlignment.offset(BoxAlignment.resolve(raw,not row,s,child.Style,crossReverse,freeCross),freeCross)
	elseif s.FlexWrap == "wrap-reverse" then cross = freeCross - cross end
	local bt, _, _, bl = BorderGeometry.sizes(s)
	return bl + s.Padding[4] + (if row then main else cross), bt + s.Padding[1] + (if row then cross else main)
end

local function paint(box: any)
	local entries = {}
	local flex = box.Style.Display == "flex" or box.Style.Display == "inline-flex" or box.Style.Display == "grid" or box.Style.Display == "inline-grid"
	for index, child in box.Children do
		local positioned = child.Kind ~= "Words" and child.Style.Position ~= "static" and child.Style.Position ~= nil
		local display=if child.Kind~="Words" then child.Style.Display else "inline"
		local foreground=child.Kind=="Words" or display=="flex" or display=="inline-flex" or display=="grid" or display=="inline-grid"
		table.insert(entries, {Child = child, Index = index, Order = if flex and child.Kind ~= "Words" then child.Style.Order or 0 else 0,
			Z = if child.Kind ~= "Words" and (positioned or flex) then child.Style.ZIndex or 0 else 0,
			Positioned = if positioned then 1 else 0, Foreground=if foreground then 1 else 0})
		if child.Kind == "Words" then
			for itemIndex, item in child.Items do
				local inlineBox=item.InlineBox
				if inlineBox and inlineBox.Style.Position=="relative" then
					table.insert(entries,{Child=inlineBox,Index=index+itemIndex/(#child.Items+1),Order=0,
						Z=inlineBox.Style.ZIndex or 0,Positioned=1,Foreground=1})
				end
			end
		end
	end
	table.sort(entries, function(a, b)
		if a.Z ~= b.Z then return a.Z < b.Z end
		if a.Positioned ~= b.Positioned then return a.Positioned < b.Positioned end
		-- CSS paints ordinary in-flow block backgrounds/borders before inline,
		-- flex and grid contents. This matters when border-image-outset from a
		-- later block reaches into an earlier flex/grid row.
		-- Flex/grid items share one paint phase, regardless of their own display.
		-- Promoting nested flex containers here would override CSS order.
		if not flex and a.Positioned==0 and a.Foreground~=b.Foreground then return a.Foreground<b.Foreground end
		if a.Order ~= b.Order then return a.Order < b.Order end
		return a.Index < b.Index
	end)
	for rank, entry in entries do
		local child = entry.Child
		if child.Kind == "Words" then
			for _, marker in child.EllipsisPool or {} do write(marker.Gui, "ZIndex", rank) end
			for _, item in child.Items do
				if item.Gui and not (item.InlineBox and item.InlineBox.Style.Position=="relative") then write(item.Gui, "ZIndex", rank) end
				for _, fragment in item.WrapPool or {} do write(fragment.Gui, "ZIndex", rank) end
			end
		else write(child.Gui, "ZIndex", rank) end
	end
end

-- Page boxes and anonymous top-layer fragments share used sizing, insets and
-- fallback trials. Callers supply their containing block and live anchor lookup.
function PositionedLayout.place(child: any, base: any, containing: any, lookup: any, layout: any, natural: any, alive: any, context: any?): any
	context=context or {}
	local globalX,globalY=context.X or 0,context.Y or 0
	local function geometry(candidate)
		local anchorName=AnchorPosition.defaultName(candidate)
		local area=PositionArea.region(candidate.PositionArea or 'none',containing,candidate,anchorName and lookup[anchorName],context.OffsetX,context.OffsetY)
		local usedContaining=area or containing
		local s=AnchorPosition.usedStyle(candidate,lookup,usedContaining,true,0)
		if area and s==candidate then s=table.clone(candidate);s.Margin=table.clone(candidate.Margin);s.Padding=table.clone(candidate.Padding)end
		BoxSpacing.resolve(s,usedContaining.Width)
		local m=s.Margin
		local function inset(length,side)
			local horizontal=side=='left'or side=='right';local offset=if horizontal then context.OffsetX or 0 else context.OffsetY or 0
			length=AnchorPosition.resolve(length,side,lookup,usedContaining,s,offset,true)
			return value(length,if horizontal then usedContaining.Width else usedContaining.Height)
		end
		local l,r=inset(s.Insetleft,'left'),inset(s.Insetright,'right')
		local t,b=inset(s.Insettop,'top'),inset(s.Insetbottom,'bottom')
		if area then
			l,r,t,b=l or 0,r or 0,t or 0,b or 0
			for side,n in {left=l,right=r,top=t,bottom=b}do s['Inset'..side]={Value=n,Percent=false}end
		end
		return s,m,l,r,t,b,usedContaining
	end
	local function space(candidate)
		local _,_,l,r,t,b,cb=geometry(candidate)
		return cb.Width-(l or 0)-(r or 0),cb.Height-(t or 0)-(b or 0)
	end
	local function place(candidate)
		local s,m,l,r,t,b,usedContaining=geometry(candidate)
		local area=usedContaining.AreaTracks
		local cs=containing.Style or {};local mode=cs.WritingMode or 'horizontal-tb'
		local inlineAxis=if WritingMode.vertical(cs)then 'y'else 'x'
		local function alignment(axis)
			local raw=if axis==inlineAxis then s.JustifySelf else s.AlignSelf
			local align,safety=BoxAlignment.split(raw)
			local function result(position,implicitUnsafe)
				return if safety then safety..' '..position else position,implicitUnsafe
			end
			if align=='auto'or align=='normal'or raw==nil then
				local start=if axis=='x'then candidate.Insetleft else candidate.Insettop
				local finish=if axis=='x'then candidate.Insetright else candidate.Insetbottom
				if (start~=nil)~=(finish~=nil)then return result(if start then 'start-physical'else 'end-physical',true)end
				local track=area and area[axis]
				return result(if track=='center'then 'center'elseif track=='span-all'then 'anchor-center'elseif track=='start'or track=='span-start'then 'end-physical'else 'start-physical')
			end
			return raw
		end
		if s.MaxHeight and s.MaxHeight.PickerStretch then
			s=table.clone(s);s.MaxHeight={Value=math.max(0,usedContaining.Height-(t or 0)-(b or 0)-m[1]-m[3])}
		end
		if s.MaxWidth and s.MaxWidth.PickerStretch then
			s=table.clone(s);s.MaxWidth={Value=math.max(0,usedContaining.Width-(l or 0)-(r or 0)-m[2]-m[4])}
		end
		local ct, cr, cb, cl = BorderGeometry.sizes(s)
		local horizontal = s.Padding[2] + s.Padding[4] + cr + cl
		local vertical = s.Padding[1] + s.Padding[3] + ct + cb
		local hint: any = {Positioned = true,HeightBasis=usedContaining.Height,Style=if s~=child.Style then s else nil}
		if not s.Width and not (s.AspectRatio and s.Height) then
			local available = math.max(0, usedContaining.Width - (l or 0) - (r or 0))
			local used = available
			if l == nil or r == nil or s.UAWidthFitContent or area and alignment('x')~='stretch' then
				local minimum = LayoutProbe.natural(child,usedContaining.Width,natural,alive,true,s)
				local maximum = LayoutProbe.natural(child,usedContaining.Width,natural,alive,false,s)
				used = math.max(minimum, math.min(maximum, available))
			end
			hint.ContentWidth = math.max(0, used - horizontal - m[2] - m[4])
		end
		if not s.Height and not s.UAHeightFitContent and t ~= nil and b ~= nil and(not area or alignment('y')=='stretch')then
			hint.ContentHeight = math.max(0, usedContaining.Height - t - b - vertical - m[1] - m[3])
		end
		LayoutProbe.arrange(child, usedContaining.Width, layout, alive, hint)
		m=child.LayoutMargin
		local staticX, staticY = context.StaticX or child.StaticX or 0, context.StaticY or child.StaticY or 0
		if context.Static then staticX,staticY=context.Static(child)end
		local auto = s.MarginAuto or {}
		local x,y
		if area then
			local function aligned(axis,start,finish,size,before,after)
				local origin=if axis=='x'then usedContaining.X else usedContaining.Y
				local extent=if axis=='x'then usedContaining.Width else usedContaining.Height
				local free=extent-start-finish-size-before-after
				local raw,unsafe=alignment(axis);local align,safety=BoxAlignment.split(raw);local reverse=PositionArea.reverse(cs,axis)
				if safety then
					align=BoxAlignment.overflow(align,safety,free)
					-- Explicit safety replaces the existing automatic overflow-limit policy.
					unsafe=true
				end
				if align=='self-start'or align=='self-end'then reverse=PositionArea.reverse(s,axis);align=if align=='self-start'then 'start'else 'end'end
				local target
				if align=='anchor-center'then
					local center=if axis=='x'then usedContaining.AnchorCenterX else usedContaining.AnchorCenterY
					target=center-size/2+(before-after)/2
				else
					local endAligned=align=='end-physical'or align=='right'or(align=='end'or align=='flex-end')~=reverse and (align=='start'or align=='flex-start'or align=='stretch'or align=='end'or align=='flex-end')
					target=origin+start+before+(if align=='center'then free/2 elseif endAligned then free else 0)
				end
				if not unsafe then
					-- Default abspos overflow alignment uses the union of the
					-- original block and its selected area, rather than clamping
					-- a wide centered box to the anchor's narrow center track.
					local original=if axis=='x'then containing.X else containing.Y
					local originalSize=if axis=='x'then containing.Width else containing.Height
					local first=math.min(origin+start,original)+before
					local last=math.max(origin+extent-finish,original+originalSize)-after-size
					target=if last>=first then math.clamp(target,first,last)else(if reverse then last else first)
				end
				return target
			end
			x=aligned('x',l,r,child.OuterWidth,m[4],m[2])-globalX
			y=aligned('y',t,b,child.OuterHeight,m[1],m[3])-globalY
		else
			local reverseX=PositionArea.reverse(cs,'x')
			local reverseY=PositionArea.reverse(cs,'y')
			x = containing.X - globalX + axis(l, r, child.OuterWidth, containing.Width, m[4], m[2], auto[4], auto[2],
				globalX + staticX - containing.X, true,reverseX)
			y = containing.Y - globalY + axis(t, b, child.OuterHeight, containing.Height, m[1], m[3], auto[1], auto[3],
				globalY + staticY - containing.Y, false,reverseY)
		end
		return {X=x,Y=y,Style=s,Margin=m,Width=child.OuterWidth,Height=child.OuterHeight,
			CBX=usedContaining.X+(l or 0),CBY=usedContaining.Y+(t or 0),
			CBWidth=usedContaining.Width-(l or 0)-(r or 0),CBHeight=usedContaining.Height-(t or 0)-(b or 0)}
	end
	local chosen=AnchorFallback.choose(child,base,containing,place,function(candidate)
		local m=candidate.Margin
		return candidate.CBWidth>=0 and candidate.CBHeight>=0
			and globalX+candidate.X-m[4]>=candidate.CBX and globalY+candidate.Y-m[1]>=candidate.CBY
			and globalX+candidate.X+candidate.Width+m[2]<=candidate.CBX+candidate.CBWidth
			and globalY+candidate.Y+candidate.Height+m[3]<=candidate.CBY+candidate.CBHeight
	end,space)
	return chosen
end

function PositionedLayout.arrange(root: any, width: number, layout: any, natural: any, alive: any): (number, number)
	local canvasPosition=if root.Gui and root.Gui.IsA and root.Gui:IsA("ScrollingFrame") then root.Gui.CanvasPosition else Vector2.new(0,0)
	local viewport = {X = 0, Y = 0, Width = width, Height = root.ViewportHeight or root.OuterHeight,Style=root.Style,Owner=root}
	local fixedViewport={X=canvasPosition.X,Y=canvasPosition.Y,Width=viewport.Width,Height=viewport.Height,Style=root.Style,Owner=root}
	local anchors=AnchorRegistry.new(root,function(box,parent)
		local s=box.Style;local owner=parent and parent.Box
		local w=owner and owner.ContentWidth or width;local h=owner and owner.DefiniteHeight and owner.ContentHeight or nil
		return value(s.Insetleft,w)or -(value(s.Insetright,w)or 0),value(s.Insettop,h)or -(value(s.Insetbottom,h)or 0)
	end,PositionedLayout.establishesFixedContainingBlock,alive)
	root.AnchorRegistry=anchors
	local anchorKey=anchors.Key
	local function visit(box: any, globalX: number, globalY: number, containing: any, scrollContext: any, fixedContaining: any, fixedOwner: any?): (number, number)
		if not alive() then return 0, 0 end
		if not box.HasPositioning then return box.LocalRight, box.LocalBottom end
		local cached = box.PositionedResult
		if DirtyLayout.wasReused(box) and cached and cached.X == globalX and cached.Y == globalY
			and cached.AnchorKey==anchorKey
			and cached.CX == containing.X and cached.CY == containing.Y
			and cached.CW == containing.Width and cached.CH == containing.Height
			and cached.FO == fixedOwner and cached.FX == fixedContaining.X and cached.FY == fixedContaining.Y
			and cached.FW == fixedContaining.Width and cached.FH == fixedContaining.Height then
			box.DirtyContext.Stats.PositionReused += 1
			return cached.Right, cached.Bottom
		end
		DirtyLayout.touch(box)
		local incoming = if box.CanReuseLayout then {X=globalX,Y=globalY,CX=containing.X,CY=containing.Y,CW=containing.Width,CH=containing.Height,
			FO=fixedOwner,FX=fixedContaining.X,FY=fixedContaining.Y,FW=fixedContaining.Width,FH=fixedContaining.Height,AnchorKey=anchorKey} else nil
		local style = box.Style
		local bt, br, bb, bl = BorderGeometry.sizes(style)
		if box.ScrollGui then scrollContext={Box=box,X=globalX,Y=globalY} end
		local fixedBlock = box ~= root and PositionedLayout.establishesFixedContainingBlock(style,box)
		if (style.Position ~= nil and style.Position ~= "static") or fixedBlock then
			local ownContaining = {X = globalX + bl + (box.ScrollLeadingX or 0), Y = globalY + bt + (box.ScrollLeadingY or 0),
				Width = math.max(0, box.OuterWidth - br - bl - (box.ScrollY or 0)),
				Height = math.max(0, box.OuterHeight - bt - bb - (box.ScrollX or 0)),Style=style,Owner=box}
			containing = ownContaining
			if fixedBlock then fixedContaining, fixedOwner = ownContaining, box end
		end
		local right, bottom = box.UnclippedRight or box.LocalRight or box.OuterWidth, box.UnclippedBottom or box.LocalBottom or box.OuterHeight
		local gridRight,gridBottom=box.ScrollRight or right,box.ScrollBottom or bottom
		for _, child in box.PositioningChildren or box.Children do
			if child.Kind == "Words" or child.CollapsedByTable or child.Style.Hidden then continue end
			local s, m = child.Style, child.LayoutMargin
			local caption=box.TableSurface and s.TableRole == "caption"
			local surfaceOffset=if caption then 0 else box.CaptionTop or 0
			local x, y = child.LayoutX or 0, child.LayoutY or 0
			if s.Position == "absolute" or s.Position=="fixed" or child.LayoutAsTopLayer then
				local containing=if s.Position=="fixed" then fixedContaining else containing
				if child.LayoutAsTopLayer then containing=viewport
				elseif child.GridContaining and (style.Position=='relative' or style.Position=='absolute') then
                    local g=child.GridContaining;containing={X=globalX+g.X,Y=globalY+g.Y,Width=g.Width,Height=g.Height,Style=style,Owner=box}
                end
				local lookup=setmetatable({},{__index=function(cache,name)
					if not name then return nil end
					local found=if name=='match-parent'then AnchorRegistry.default(anchors,root,child)else AnchorRegistry.find(anchors,root,child,name)
					rawset(cache,name,found or false);return found
				end})
				local chosen=PositionedLayout.place(child,s,containing,lookup,layout,natural,alive,{X=globalX,Y=globalY,
					Static=if style.Display=='flex'or style.Display=='inline-flex'then function(item)return flexStatic(box,item)end else nil,
					OffsetX=if child.LayoutAsTopLayer then canvasPosition.X else 0,OffsetY=if child.LayoutAsTopLayer then canvasPosition.Y else 0})
				x,y,s,m=chosen.X,chosen.Y,chosen.Style,chosen.Margin
				child.AnchorUsedStyle=if s~=child.Style then s else nil
				if not alive() then return 0,0 end
				if s.Position=="fixed" then
					local owner=if child.LayoutAsTopLayer then nil else fixedOwner
					child.FixedContainingBox = owner
					child.ViewportKind = if owner then nil else "fixed"
					child.FixedViewportX = if owner then nil else globalX+x-(if child.LayoutAsTopLayer then 0 else canvasPosition.X)
					child.FixedViewportY = if owner then nil else globalY+surfaceOffset+y-(if child.LayoutAsTopLayer then 0 else canvasPosition.Y)
				end
			elseif s.Position == "relative" then
				local l, r = value(s.Insetleft, box.ContentWidth), value(s.Insetright, box.ContentWidth)
				local parentHeight = if box.DefiniteHeight then box.ContentHeight else nil
				local t, b = value(s.Insettop, parentHeight), value(s.Insetbottom, parentHeight)
				x += l or -(r or 0); y += t or -(b or 0)
			elseif s.Position=="sticky" then
				local scrollBox=scrollContext.Box
				local st,sr,sb,sl=0,0,0,0
				if scrollBox~=root then st,sr,sb,sl=BorderGeometry.sizes(scrollBox.Style) end
				local scrollHeight=if scrollBox==root then viewport.Height else math.max(0,scrollBox.OuterHeight-st-sb-(scrollBox.ScrollX or 0))
				local scrollWidth=if scrollBox==root then viewport.Width else math.max(0,scrollBox.OuterWidth-sl-sr-(scrollBox.ScrollY or 0))
				child.ViewportKind="sticky"
				child.StickyScrollBox=scrollBox
				child.StickyScrollX,child.StickyScrollY=scrollContext.X,scrollContext.Y
				child.StickyParentX,child.StickyParentY=globalX,globalY+surfaceOffset
				child.StickyNormalX,child.StickyNormalY=x,y
				child.StickyLeft,child.StickyRight=value(s.Insetleft,scrollWidth),value(s.Insetright,scrollWidth)
				child.StickyTop,child.StickyBottom=value(s.Insettop,scrollHeight),value(s.Insetbottom,scrollHeight)
				child.StickyMinX=math.min(x,bl+style.Padding[4]+m[4])
				child.StickyMinY=math.min(y,bt+style.Padding[1]+m[1])
				child.StickyMaxX=math.max(x,box.OuterWidth-br-style.Padding[2]-child.OuterWidth-m[2])
				child.StickyMaxY=math.max(y,box.OuterHeight-bb-style.Padding[3]-child.OuterHeight-m[3])
			end
			if child.TopLayer then
				-- Keep the logical document position even though the GUI is reparented
				-- into the viewport overlay.  Non-modal <dialog>.show() uses this
				-- static block position, matching the browser's absolute dialog box.
				child.TopLayerDocumentX = globalX + x
				child.TopLayerDocumentY = globalY + surfaceOffset + y
			end
			child.PaintX,child.PaintY=x,y
			AnchorRegistry.update(anchors,child,globalX+x,globalY+surfaceOffset+y)
			write(child.Gui, "Position", UDim2.fromOffset(x, y))
			local childRight, childBottom = visit(child, globalX + x, globalY + surfaceOffset + y, containing, scrollContext, fixedContaining, fixedOwner)
			if not child.LayoutAsTopLayer and not child.TopLayerHidden and (s.Position~="fixed" or child.FixedContainingBox) then
				right = math.max(right, x + childRight + m[2] + style.Padding[2] + br)
				bottom = math.max(bottom, surfaceOffset + y + childBottom + m[3] + (if caption then 0 else style.Padding[3] + bb))
			end
			if not caption and not child.LayoutAsTopLayer and not child.TopLayerHidden and (s.Position~="fixed" or child.FixedContainingBox) then
				gridRight=math.max(gridRight,x+childRight+m[2]+style.Padding[2]+br)
				gridBottom=math.max(gridBottom,y+childBottom+m[3]+style.Padding[3]+bb)
			end
		end
		paint(box)
		if box.ScrollGui then box.ScrollRight, box.ScrollBottom = if box.TableSurface then gridRight else right, if box.TableSurface then gridBottom else bottom end
		if style.Overflow == "hidden" or box.TableContentClipped then right, bottom = box.OuterWidth, box.OuterHeight end
		if incoming then incoming.Right, incoming.Bottom = right, bottom end
		box.PositionedResult = incoming
		return right, bottom
	end
	return visit(root, 0, 0, viewport, {Box=root,X=0,Y=0}, fixedViewport, nil)
end
function PositionedLayout.externalAnchors(root:any,box:any,implicit:any,viewport:any,dependencies:any?):any
	local registry=root.AnchorRegistry or {Names={},Boxes={}}
	return AnchorRegistry.external(registry,root,box,implicit,function(record)
		local item=record.Box.ImageItem
		local gui=if item and item.BoxGui then item.BoxGui else record.Box.Gui
		local found=table.clone(record)
		if gui and gui.AbsolutePosition and gui.AbsoluteSize then
			if dependencies then dependencies[gui]=true end
			local p,size=gui.AbsolutePosition,gui.AbsoluteSize
			found.X,found.Y,found.Width,found.Height=p.X-viewport.X,p.Y-viewport.Y,size.X,size.Y
		end
		return found
	end)
end
return PositionedLayout
