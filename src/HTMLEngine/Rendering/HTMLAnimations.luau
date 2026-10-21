--!strict
--!optimize 2
-- Bounded CSS effects retain native boxes and request local flow layout only
-- when a sampled layout value actually changes.
local Motion=require(script.Parent.Parent.CSS.Motion)
local Transform2D=require(script.Parent.Parent.CSS.Transform2D)
local Individuals=require(script.Parent.Parent.CSS.IndividualTransformValues)
local BoxTransform=require(script.Parent.BoxTransform)
local Matrix4=require(script.Parent.Parent.CSS.Matrix4)
local GroupOpacity=require(script.Parent.GroupOpacity)
local InlineStyle=require(script.Parent.Parent.CSS.InlineStyle)
local Syntax=require(script.Parent.Parent.CSS.Syntax)
local Variables=require(script.Parent.Parent.CSS.Variables)
local LengthExpression=require(script.Parent.Parent.CSS.LengthExpression)
local AnimationValues=require(script.Parent.AnimationValues)
local AnimationColors=require(script.Parent.Parent.CSS.AnimationColors)
local BoxShadow=require(script.Parent.Parent.CSS.BoxShadow)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local ScrollTimeline=require(script.Parent.Parent.CSS.ScrollTimeline)
local PositionedLayout=require(script.Parent.Parent.Layout.PositionedLayout)
local HTMLAnimations={}
local PROPERTIES={"transform","translate","rotate","scale","offset-distance","opacity"}
for _,name in AnimationColors.Order do table.insert(PROPERTIES,name)end
local TRANSITION_PROPERTIES=table.clone(PROPERTIES)
local CSS_PROPERTIES=table.clone(PROPERTIES)
local CSS_TRANSITION_PROPERTIES=table.clone(TRANSITION_PROPERTIES)
for name in AnimationValues.Properties do table.insert(CSS_PROPERTIES,name);table.insert(CSS_TRANSITION_PROPERTIES,name)end
local function equalValue(a: any,b: any): boolean
	if a==b then return true end
	if type(a)~="table"or type(b)~="table"then return false end
	for key,value in a do if not equalValue(value,b[key])then return false end end
	for key in b do if a[key]==nil then return false end end
	return true
end

local function component(value: any,axis: string,index: number): number
	local part=value and value[axis];return if part and part.Offset~=nil then part.Offset elseif value then value[index] or 0 else 0
end
local function lerp(a: number,b: number,t: number): number return a+(b-a)*t end
local function color(a: any,b: any,t: number): any return Color3.new(lerp(a.R,b.R,t),lerp(a.G,b.G,t),lerp(a.B,b.B,t)) end
local function premultiplied(a: any,b: any,t: number): any
	local alpha=math.clamp(lerp(a.Alpha,b.Alpha,t),0,1)
	local function channel(key: string): number return if alpha==0 then 0 else math.clamp(lerp(a.Color[key]*a.Alpha,b.Color[key]*b.Alpha,t)/alpha,0,1)end
	return {Color=Color3.new(channel("R"),channel("G"),channel("B")),Alpha=alpha}
end
local function same(a: any,b: any): boolean
	for key,value in a do if type(value)=="number" and math.abs(value-(b[key] or math.huge))>.0001 then return false elseif type(value)~="number" and value~=b[key] then return false end end
	return true
end
local function visual(box: any): any
	local gui=BoxTransform.target(box)
	local paintGui=box.PaintBackgroundGui or box.Gui
	local backgroundAlpha=1-(paintGui.BackgroundTransparency or 1)
	local shadow=box.ShadowGuis and box.ShadowGuis[1]
	local operations=box.TransformOverride or Transform2D.operations(box.Style)
 local resolved=BoxTransform.resolve(box,operations)
	local scale=if box.TransformScale then box.TransformScale.Scale else 1
	local anchorX,anchorY=gui.AnchorPoint and gui.AnchorPoint.X or 0,gui.AnchorPoint and gui.AnchorPoint.Y or 0
	local bounds=box.OpacityGroup and box.OpacityBounds
	local width,height=if bounds then bounds[3]-bounds[1] else box.OuterWidth or 0,if bounds then bounds[4]-bounds[2] else box.OuterHeight or 0
	local originX,originY=BoxTransform.origin(box)
	originX-=if bounds then bounds[1] else 0;originY-=if bounds then bounds[2] else 0
	-- Retain the unrounded paint position for interrupted/reversed transitions.
	local x=if box.TransformPositionX~=nil then box.TransformPositionX+(box.ViewportOffsetX or 0) else component(gui.Position,"X",1)
	local y=if box.TransformPositionY~=nil then box.TransformPositionY+(box.ViewportOffsetY or 0) else component(gui.Position,"Y",2)
	local layout={};for property in AnimationValues.Properties do layout[property]=AnimationValues.fromStyle(box.Style,property)end
	local vertical=box.Style.WritingMode~='horizontal-tb';local contentW,contentH=box.ContentWidth or width,box.AutoContentHeight or box.ContentHeight or height
	local intrinsic={width=if box.Style.BoxSizing=='border-box'then width else contentW,height=if box.Style.BoxSizing=='border-box'then contentH+height-(box.ContentHeight or height)else contentH}
	intrinsic['inline-size']=if vertical then intrinsic.height else intrinsic.width;intrinsic['block-size']=if vertical then intrinsic.width else intrinsic.height
	local individuals={};for property in Individuals.Fields do individuals[property]=box.SampledIndividualTransforms and box.SampledIndividualTransforms[property]or Individuals.fromStyle(box.Style,property)end
	local colors={};for _,property in AnimationColors.Order do colors[property]=AnimationColors.resolve(AnimationColors.used(box.Style,property),{Color=box.Style.Color,Alpha=box.Style.ColorAlpha or 1})end
	return {Colors=colors,Layout=layout,Individuals=individuals,TransformProperty=box.SampledTransformPropertyOperations or box.Style.Transform or{},Intrinsic=intrinsic,InterpolateSize=box.Style.InterpolateSize,Distance=box.Style.OffsetDistance,ViewportX=box.ViewportOffsetX or 0,ViewportY=box.ViewportOffsetY or 0,Operations=operations,Projected=resolved.Projected or box.Scene3DRoot~=nil,X=x,Y=y,Rotation=gui.Rotation or 0,
		Scale=scale,AnchorX=anchorX,AnchorY=anchorY,SurfaceWidth=width,SurfaceHeight=height,OriginX=originX,OriginY=originY,
		BaseX=box.TransformBaseX or 0,BaseY=box.TransformBaseY or 0,
		Background=if backgroundAlpha==0 then Color3.new(0,0,0)else paintGui.BackgroundColor3,BackgroundAlpha=backgroundAlpha,
		Opacity=if box.OpacityGroup then GroupOpacity.opacity(box.OpacityGroup,box.Style) else box.Style.Opacity or 1,
		Radius=if box.Corner then box.Corner.CornerRadius.Offset else 0,
		ShadowAlpha=if shadow then 1-shadow.Transparency else 0,
		ShadowX=if shadow then component(shadow.Offset,"X",1) else 0,ShadowY=if shadow then component(shadow.Offset,"Y",2) else 0,
		ShadowBlur=if shadow then shadow.BlurRadius.Offset else 0,
		ShadowSpread=if shadow then component(shadow.Spread,"X",1) else 0,
		ShadowColor=if shadow then shadow.Color else Color3.new(0,0,0)}
end
-- Starting style supplies a before-change style only when the element had no
-- rendered style in the preceding update. Resolve it without painting or
-- changing the current author style; the normal transition publisher retains
-- the native surface and controls while its first layout sample is applied.
local function startingVisual(box: any,style: any): any
	local pose=visual(box);local sample=table.clone(box);sample.Style=style;sample.TransformOverride=nil
	pose.Layout={};for property in AnimationValues.Properties do pose.Layout[property]=AnimationValues.fromStyle(style,property)end
	pose.Individuals={};for property in Individuals.Fields do pose.Individuals[property]=Individuals.fromStyle(style,property)end;pose.TransformProperty=style.Transform or{}
	local operations=Transform2D.operations(style);local resolved=BoxTransform.resolve(sample,operations)
	pose.Operations,pose.Projected=operations,resolved.Projected or box.Scene3DRoot~=nil
	pose.Distance=style.OffsetDistance
	pose.Scale,pose.Rotation=resolved.Scale,resolved.Rotation
	local originX,originY=BoxTransform.origin(sample);local bounds=box.OpacityGroup and box.OpacityBounds
	originX-=if bounds then bounds[1]else 0;originY-=if bounds then bounds[2]else 0
	pose.OriginX,pose.OriginY=originX,originY
	pose.AnchorX=if pose.SurfaceWidth>0 then originX/pose.SurfaceWidth else 0
	pose.AnchorY=if pose.SurfaceHeight>0 then originY/pose.SurfaceHeight else 0
	local dx,dy=pose.SurfaceWidth/2-originX,pose.SurfaceHeight/2-originY
	local radians=math.rad(resolved.Rotation);local c,s=math.cos(radians),math.sin(radians)
	pose.X=pose.BaseX+originX+resolved.X+resolved.Scale*((c-1)*dx-s*dy)+pose.ViewportX
	pose.Y=pose.BaseY+originY+resolved.Y+resolved.Scale*(s*dx+(c-1)*dy)+pose.ViewportY
	pose.Opacity=style.Opacity or 1
	pose.Colors={};for _,property in AnimationColors.Order do pose.Colors[property]=AnimationColors.resolve(AnimationColors.used(style,property),{Color=style.Color,Alpha=style.ColorAlpha or 1})end
	pose.Background=style.Background or Color3.new(0,0,0)
	pose.BackgroundAlpha=if style.Background then style.BackgroundAlpha or 1 else 0
	pose.Radius=style.BorderRadius or 0
	local shadow=style.BoxShadows and style.BoxShadows[1]
	pose.ShadowAlpha=if shadow then shadow.Alpha or 1 else 0
	pose.ShadowX,pose.ShadowY=if shadow then shadow.X else 0,if shadow then shadow.Y else 0
	pose.ShadowBlur,pose.ShadowSpread=if shadow then shadow.Blur else 0,if shadow then shadow.Spread or 0 else 0
	pose.ShadowColor=if shadow then (if shadow.Color=="currentcolor"then style.Color else shadow.Color)else Color3.new(0,0,0)
	return pose
end
-- A repaint can leave a running effect's sampled pixels in place (especially
-- native controls). Those pixels belong to the before-change value, never to
-- the after-change target. Resolve the target from the current underlying CSS
-- and the control painter's UA result while retaining the latest flow geometry.
local function targetVisual(box: any): any
	local pose=startingVisual(box,box.Style)
	local control=box.ImageItem
	if control and control.Control and control.AuthorBackground then
		pose.Background,pose.BackgroundAlpha=control.AuthorBackground,control.AuthorBackgroundAlpha or 0
	end
	if pose.BackgroundAlpha==0 then pose.Background=Color3.new(0,0,0)end
	return pose
end
local function relativeOperations(operations: any): boolean
	for _,op in operations or {}do if op.Kind=="translate"then
		for _,value in {op.X,op.Y}do if type(value)=="table"and(value.Percent or value.HasPercent or value.Expression and value.Expression.HasPercent)then return true end end
	end end
	return false
end
local function liveOperations(a: any,b: any,t: number,box: any): any
	local result=Transform2D.interpolate(a,b,t,box.OuterWidth or 0,box.OuterHeight or 0)
	for index,op in result do if op.Kind=="translate"then
		local left,right=a[index],b[index]
		if (not left or left.Kind=="translate")and(not right or right.Kind=="translate")then
			local zero={Value=0,Percent=false}
			op.X=AnimationValues.mix(if left then left.X else zero,if right then right.X else zero,t,box)
			op.Y=AnimationValues.mix(if left then left.Y else zero,if right then right.Y else zero,t,box)
		end
	end end
	return result
end
-- A transition stores paint coordinates, but its flow position and CSS pivot
-- belong to the latest layout. Move both poses into that geometry while
-- retaining the start time and the starting anchor (including interrupted poses).
local function relocate(pose: any,box: any,current: any,endpoint: boolean?)
	if pose.Projected or current.Projected then return end
	if pose.BaseX==current.BaseX and pose.BaseY==current.BaseY and pose.SurfaceWidth==current.SurfaceWidth and pose.SurfaceHeight==current.SurfaceHeight and pose.OriginX==current.OriginX and pose.OriginY==current.OriginY then return end
	local scale=pose.Scale;local c,s=math.cos(math.rad(pose.Rotation)),math.sin(math.rad(pose.Rotation))
	local dx,dy=pose.SurfaceWidth/2-pose.OriginX,pose.SurfaceHeight/2-pose.OriginY
	local x=pose.X-pose.ViewportX-pose.BaseX+scale*(pose.SurfaceWidth/2-pose.AnchorX*pose.SurfaceWidth)-pose.OriginX-scale*(c*dx-s*dy)
	local y=pose.Y-pose.ViewportY-pose.BaseY+scale*(pose.SurfaceHeight/2-pose.AnchorY*pose.SurfaceHeight)-pose.OriginY-scale*(s*dx+c*dy)
	if endpoint then
		-- Re-resolve percentages against the resized transform reference box.
		local resolved=BoxTransform.resolve(box,pose.Operations)
		if not resolved.Projected then x,y=resolved.X,resolved.Y;pose.Scale,pose.Rotation=resolved.Scale,resolved.Rotation end
	end
	scale=pose.Scale;c,s=math.cos(math.rad(pose.Rotation)),math.sin(math.rad(pose.Rotation))
	dx,dy=current.SurfaceWidth/2-current.OriginX,current.SurfaceHeight/2-current.OriginY
	pose.X=current.BaseX+current.OriginX+x+scale*(c*dx-s*dy-current.SurfaceWidth/2+pose.AnchorX*current.SurfaceWidth)+pose.ViewportX
	pose.Y=current.BaseY+current.OriginY+y+scale*(s*dx+c*dy-current.SurfaceHeight/2+pose.AnchorY*current.SurfaceHeight)+pose.ViewportY
	pose.BaseX,pose.BaseY=current.BaseX,current.BaseY
	pose.SurfaceWidth,pose.SurfaceHeight=current.SurfaceWidth,current.SurfaceHeight
	pose.OriginX,pose.OriginY=current.OriginX,current.OriginY
end
local function transitionIndex(style: any,property: string): number?
	local names=style.TransitionProperty or {}
	for index=#names,1,-1 do local name=names[index]
		if name==property or name=="all"or name=='background'and property=='background-color'
			or(name=='border'or name=='border-color')and AnimationColors.Properties[property]and AnimationColors.Properties[property].Side
			or name=='outline'and(property=='outline-color'or property=='outline-width')or name=='text-decoration'and property=='text-decoration-color'
			or name=='font'and(property=='font-size'or property=='line-height')
			or name=='text-emphasis'and property=='text-emphasis-color'
			or name=='margin'and property:match('^margin%-')or name=='padding'and property:match('^padding%-')
			or name=='gap'and(property=='row-gap'or property=='column-gap')
			or name=='border-radius'and AnimationValues.Properties[property]and AnimationValues.Properties[property].Corner
			or(name=='border'or name=='border-width')and AnimationValues.Properties[property]and AnimationValues.Properties[property].BorderSide
			or name=='inset'and(property=='top'or property=='right'or property=='bottom'or property=='left')
			or name=='flex'and(property=='flex-grow'or property=='flex-shrink'or property=='flex-basis')then return index end
	end
	return nil
end
local function transitionValue(pose: any,property: string): any
	if AnimationColors.Properties[property]then return pose.Colors[property]
	elseif AnimationValues.Properties[property]then return pose.Layout[property]
	elseif Individuals.Fields[property]then return pose.Individuals[property]
	elseif property=='transform'then return pose.TransformProperty
	elseif property=='offset-distance'then return pose.Distance
	elseif property=='opacity'then return pose.Opacity
	elseif property=='border-radius'then return pose.Radius
	else return {Alpha=pose.ShadowAlpha,X=pose.ShadowX,Y=pose.ShadowY,Blur=pose.ShadowBlur,Spread=pose.ShadowSpread,Color=pose.ShadowColor}end
end
local function declaration(frame: any,field: string): any?
	local winner
	-- !important declarations do not participate in keyframes.
	for _,entry in frame.Declarations.Normal do if not entry.Error and not entry.Relative and entry.Field==field then winner=entry.Value end end
	return winner
end
local function variableFrameStyle(frame: any,box: any,property: string,field: string): any?
	local entries,variable={},false
	for _,entry in frame.Declarations.Normal do
		if not entry.Error and(entry.Field==field or property=='background-color'and entry.Field=='BackgroundShorthand'
			or entry.VariableProperty==property or property=='background-color'and entry.VariableProperty=='background')then
			table.insert(entries,entry);variable=variable or entry.VariableProperty~=nil or entry.Wide~=nil
		end
	end
	if not variable then return nil end
	local fake={Name=box.Node and box.Node.Name or'div',Kind='Element',Attributes={}}
	return InlineStyle.resolve(fake,box.Style,function()end,false,{Normal=entries,Important={}})
end
local function processedKeyframes(definition: any,box: any,timing: string,composition: string): any
	local result={Frames={}};local groups={}
	for _,frame in definition.Frames do
		local timingStyle=variableFrameStyle(frame,box,'animation-timing-function','AnimationTiming')
		local compositionStyle=variableFrameStyle(frame,box,'animation-composition','AnimationComposition')
		local curve=Motion.serializeEasing(Motion.pick(if timingStyle then timingStyle.AnimationTiming else declaration(frame,'AnimationTiming'),1,timing))
		local mode=Motion.pick(if compositionStyle then compositionStyle.AnimationComposition else declaration(frame,'AnimationComposition'),1,'auto')
		local resolvedMode=if mode=='auto'then composition else mode
		local key=tostring(frame.Offset)..'|'..curve..'|'..resolvedMode;local group=groups[key]
		if not group then
			group={Offset=frame.Offset,Order=frame.Order or #result.Frames+1,Easing=curve,Composite=mode,Declarations={Normal={},Important={}}}
			groups[key]=group;table.insert(result.Frames,group)
		end
		-- Keep source order inside a matching offset/timing/composite group.
		-- Important and invalid declarations cannot replace a valid earlier
		-- keyframe value; the regular declaration resolver enforces that rule.
		for _,entry in frame.Declarations.Normal do table.insert(group.Declarations.Normal,entry)end
	end
	table.sort(result.Frames,function(a,b)return if a.Offset==b.Offset then a.Order<b.Order else a.Offset<b.Offset end)
	return result
end
local function frameValue(frame: any,property: string,box: any,parentStyle: any?): any?
	local spec=AnimationValues.Properties[property]
	if AnimationColors.Properties[property]then return AnimationColors.stop(frame,property,box,parentStyle,InlineStyle.resolve)
	elseif property=='font-size'or property=='line-height'then return AnimationValues.metricStop(frame,property,box,parentStyle,InlineStyle.resolve)
	elseif Individuals.Fields[property]then
		local entries={};local field=Individuals.Fields[property];local contextual=false;local inherit=false
		for _,entry in frame.Declarations.Normal do if not entry.Error and(entry.Field==field or entry.VariableProperty==property)then
			table.insert(entries,entry);contextual=contextual or entry.Relative~=nil or entry.Wide~=nil or entry.VariableProperty~=nil;inherit=inherit or entry.Wide=='inherit'
		end end
		if #entries==0 then return nil end
		if not contextual then return Individuals.value(entries[#entries].Value)end
		local fake={Name=box.Node and box.Node.Name or'div',Kind='Element',Attributes={}}
		local context=if inherit and parentStyle then parentStyle else box.Style
		local style=InlineStyle.resolve(fake,context,function()end,false,{Normal=entries,Important={}})
		return Individuals.fromStyle(style,property)
	elseif spec then
		local entries={}
		for _,entry in frame.Declarations.Normal do
			if not entry.Error and (AnimationValues.matches(spec,entry,property)or entry.VariableProperty=="margin"and spec.Field=="Margin"or entry.VariableProperty=="padding"and spec.Field=="Padding"or entry.VariableProperty=="gap"and spec.Field=="Gap")then table.insert(entries,entry)end
		end
		if #entries==0 then return nil end
		frame.LayoutCache=frame.LayoutCache or setmetatable({},{__mode="k"})
		local cached=frame.LayoutCache[box.Style]
		if not cached then cached={};frame.LayoutCache[box.Style]=cached end
		local context=table.concat({tostring(box.Style.FontSize),tostring(box.Style.RootFontSize),tostring(box.Style.ViewportWidth),tostring(box.Style.ViewportHeight)},"|")
		if cached.Context~=context then table.clear(cached);cached.Context=context end
		if cached[property]==nil then
			local fake={Name=box.Node and box.Node.Name or "div",Kind="Element",Attributes={}}
			local style=InlineStyle.resolve(fake,box.Style,function()end,false,{Normal=entries,Important={}})
			cached[property]=AnimationValues.fromStyle(style,property)
		end
		return cached[property]
	elseif property=="transform" then
		local style=variableFrameStyle(frame,box,property,'Transform')
		local value=if style then style.Transform else declaration(frame,"Transform");if not value then return nil end
		local resolved=BoxTransform.resolve(box,Transform2D.operations(box.Style,value));resolved.PropertyOperations=value;return resolved
	elseif property=="offset-distance" then
		local style=variableFrameStyle(frame,box,property,'OffsetDistance')
		local value=if style then style.OffsetDistance else declaration(frame,"OffsetDistance");if not value then return nil end
		return {Distance=value}
	elseif property=="opacity" then local style=variableFrameStyle(frame,box,property,'Opacity');return if style then style.Opacity else declaration(frame,"Opacity")
	end
	return nil
end
local function baseValue(property: string,box: any): any
	if AnimationColors.Properties[property]then return AnimationColors.base(box,property)
	elseif AnimationValues.Properties[property]then return AnimationValues.base(box,property)
	elseif Individuals.Fields[property]then return Individuals.fromStyle(box.Style,property)
	elseif property=="transform" then
		local resolved=BoxTransform.resolve(box,Transform2D.operations(box.Style));resolved.PropertyOperations=box.Style.Transform or {};return resolved
	elseif property=="offset-distance" then return {Distance=box.Style.OffsetDistance}
	elseif property=="opacity" then return box.Style.Opacity or 1
	else return {Color=box.Style.Background or Color3.new(1,1,1),Alpha=box.Style.Background and (box.Style.BackgroundAlpha or 1) or 0} end
end
local function stops(definition: any,property: string,box: any,parentStyle: any?): any
	local result={}
	for _,frame in definition.Frames do local value=frameValue(frame,property,box,parentStyle);if value~=nil then table.insert(result,{Offset=frame.Offset,Value=value,Easing=frame.Easing or Motion.pick(declaration(frame,"AnimationTiming"),1,nil),Composite=frame.Composite}) end end
	if #result==0 then return result end
	local base=baseValue(property,box)
	if result[1].Offset>0 then table.insert(result,1,{Offset=0,Value=base,Composite='replace',Underlying=true}) end
	if result[#result].Offset<1 then table.insert(result,{Offset=1,Value=base,Composite='replace',Underlying=true}) end
	return result
end
local function cssSegment(values: any,progress: number,timing: any,before: boolean?): (any,any,number,any,any)
	if #values==1 then return values[1].Value,values[1].Value,0,values[1],values[1]end
	local index=1
	for i=1,#values-1 do if values[i].Offset<=progress then index=i else break end end
	if progress>=values[#values].Offset then index=#values-1 end
	local a,b=values[index],values[index+1]
	local t=if a.Offset==b.Offset then 1 else math.clamp((progress-a.Offset)/(b.Offset-a.Offset),0,1)
	return a.Value,b.Value,Motion.ease(a.Easing or timing,t,before),a,b
end
local function interpolated(a: any,b: any,t: number,box: any?): any
 local operations=if box and a.Operations and b.Operations then Transform2D.interpolate(a.Operations,b.Operations,t,box.OuterWidth or 0,box.OuterHeight or 0) else nil
 return {X=lerp(a.X,b.X,t),Y=lerp(a.Y,b.Y,t),Rotation=lerp(a.Rotation,b.Rotation,t),Scale=lerp(a.Scale,b.Scale,t),Operations=operations,Projected=a.Projected or b.Projected}
end
local function paintTransform(box: any,value: any)
 -- Even a sampled identity can retain a nonzero native AnchorPoint. Layout
 -- must normalize that surface instead of taking transform:none's fast path.
 box.TransformApplied=true
 box.TransformOverride=value.Operations
 if value.Operations and (value.Projected or box.Scene3DRoot) then if BoxTransform.paint3D(box,value.Operations) then return end end
	-- An effect can introduce the first projected surface after initial layout.
	-- Returning to a native 2D value must restore the hidden source GUIs and
	-- detach its projected hit registry; retaining the texture is only a cache.
	if box.Scene3DSurface and box.VisualEffects then box.VisualEffects:ClearScene(box)end
	local originX,originY=BoxTransform.origin(box)
	BoxTransform.paint(box,value.X,value.Y,value.Rotation,value.Scale,originX,originY)
end
local function sampledContainingBlock(box: any,operations: any,tree: any,page: any)
	local before=PositionedLayout.establishesFixedContainingBlock(box.Style,box)
	box.AnimationTransformContainingBlock=#operations>0 or box.HasScriptTransformEffects==true or box.CSSAnimationTransformEffects==true
	if before==PositionedLayout.establishesFixedContainingBlock(box.Style,box)then return end
	local function positionedDescendant(owner)
		for _,child in owner.Children or{}do
			local position=child.Style and child.Style.Position
			if position=='absolute'or position=='fixed'or positionedDescendant(child)then return true end
		end
		return false
	end
	-- Only entry/exit changes positioning dependencies. Ordinary samples stay
	-- on the retained paint path, including identity samples and paused reads.
	if positionedDescendant(box)then
		if tree.SyncPositioning then tree:SyncPositioning()end
		if page.RequestAnimationLayout then page:RequestAnimationLayout(box)end
	end
end
local function pathValue(box: any,a: any,b: any,t: number,composition: string?): any
	local distance=lerp(BoxTransform.pathDistance(box,a.Distance),BoxTransform.pathDistance(box,b.Distance),t)
	if composition=="add" or composition=="accumulate" then distance+=BoxTransform.pathDistance(box,box.Style.OffsetDistance) end
	return BoxTransform.resolve(box,Transform2D.operations(box.Style),{Value=distance,Percent=false})
end
local function paintProperty(box: any,property: string,a: any,b: any,t: number,composition: string?)
	if property=="offset-distance" then paintTransform(box,pathValue(box,a,b,t,composition));return end
	if composition=="add" or composition=="accumulate" then
		local base=baseValue(property,box)
		if property=="transform" then
			local function combined(value: any): any
 if value.Operations and (value.Projected or box.Scene3DRoot) then local ops=table.clone(base.Operations);for _,op in value.Operations do table.insert(ops,op) end;return BoxTransform.resolve(box,ops) end
 return {X=base.X+value.X,Y=base.Y+value.Y,Rotation=base.Rotation+value.Rotation,Scale=base.Scale*value.Scale} end
			a,b=combined(a),combined(b)
		elseif property=="opacity" then a,b=math.clamp(base+a,0,1),math.clamp(base+b,0,1) end
	end
	if property=="transform" then
		paintTransform(box,interpolated(a,b,t,box))
	elseif property=="opacity" then if box.OpacityGroup then GroupOpacity.paint(box.OpacityGroup,box.Style,lerp(a,b,t)) end
 else local value=premultiplied(a,b,t);box.SampledBackgroundColor=value;local paintGui=box.PaintBackgroundGui or box.Gui;paintGui.BackgroundColor3=value.Color;paintGui.BackgroundTransparency=1-value.Alpha end
end

local function cssMixed(property: string,a: any,b: any,t: number,box: any,interpolateSize: string?): any
	if AnimationColors.Properties[property]then return AnimationColors.mix(a,b,t)
	elseif AnimationValues.Properties[property]then return AnimationValues.mix(a,b,t,box,property,interpolateSize)
	elseif Individuals.Fields[property]then return Individuals.mix(property,a,b,t,AnimationValues.mix,box)
	elseif property=="transform"then
		local operations=Transform2D.interpolate(a.PropertyOperations or a.Operations,b.PropertyOperations or b.Operations,t,box.OuterWidth or 0,box.OuterHeight or 0)
		local value=BoxTransform.resolve(box,Transform2D.operations(box.Style,operations));value.PropertyOperations=operations;return value
	elseif property=="offset-distance"then
		return {Distance={Value=lerp(BoxTransform.pathDistance(box,a.Distance),BoxTransform.pathDistance(box,b.Distance),t),Percent=false}}
	elseif property=="opacity"then return lerp(a,b,t)
	else return premultiplied(a,b,t)end
end
local function cssCompose(property: string,base: any,value: any,mode: string,box: any,interpolateSize: string?): any
	if mode=="replace"then return value end
	if AnimationColors.Properties[property]then return AnimationColors.add(base,value)
	elseif AnimationValues.Properties[property]then return AnimationValues.add(base,value,box,nil,property,interpolateSize,mode)
	elseif Individuals.Fields[property]then return Individuals.compose(property,base,value,nil,AnimationValues.add,box)
	elseif property=="opacity"then return base+value
	elseif property=="offset-distance"then return {Distance=AnimationValues.add(base.Distance,value.Distance,{ContentWidth=BoxTransform.pathDistance(box,{Value=100,Percent=true})})}
	elseif property=="transform"then
		local a,b=base.PropertyOperations or base.Operations or {},value.PropertyOperations or value.Operations or {}
		local operations=Transform2D.compose(a,b,mode,box.OuterWidth or 0,box.OuterHeight or 0)
		local result=BoxTransform.resolve(box,Transform2D.operations(box.Style,operations));result.PropertyOperations=operations;return result
	end
	return value
end
local function cssSample(values: any,progress: number,timing: any,before: boolean?,property: string,box: any,underlying: any,composition: string,interpolateSize: string?): any
	local a,b,t,left,right=cssSegment(values,progress,timing,before)
	local leftMode=if left.Composite==nil or left.Composite=='auto'then composition else left.Composite
	local rightMode=if right.Composite==nil or right.Composite=='auto'then composition else right.Composite
	a=if left.Underlying then underlying else cssCompose(property,underlying,a,leftMode,box,interpolateSize)
	b=if right.Underlying then underlying else cssCompose(property,underlying,b,rightMode,box,interpolateSize)
	return cssMixed(property,a,b,t,box,interpolateSize)
end
local function paintAnimation(item: any,progress: number,before: boolean?)
	item.SampledProgress,item.SampledBefore=progress,before
	item.SampledValues={};item.LayoutValues={}
	for property,values in item.Properties do
		local a,b,t=cssSegment(values,progress,item.Timing,before)
		local value=cssMixed(property,a,b,t,item.Box,item.InterpolateSize);item.SampledValues[property]=value
		if AnimationValues.Properties[property]then item.LayoutValues[property]=value end
	end
end

local function metricPublisher(page:any,tree:any):any
	if not tree.RefreshAnimationMetrics then return nil end
	return function(box,values)
		local items=tree:RefreshAnimationMetrics(box,values)
		if page.Alive and page.RequestAnimationLayout then for item in items do page:RequestAnimationLayout(item)end end
	end
end
local function publishColors(page,tree,box,properties,changed)
	if not tree.RefreshAnimationColors then
		if changed['background-color']then
			local value=AnimationColors.resolve(properties['background-color'],{Color=box.Style.Color,Alpha=box.Style.ColorAlpha or 1})
			paintProperty(box,'background-color',value,value,1)
		end
		return
	end
	local colors=AnimationColors.values(properties,changed)
	if not next(colors)and not box.AnimationColorAuthor then return end
	local items=tree:RefreshAnimationColors(box,colors)
	-- Native controls retain a transition-owned background surface. Their UA
	-- painter deliberately leaves that surface alone during the transition.
	if changed['background-color']then
		local value=AnimationColors.resolve(properties['background-color'],{Color=box.Style.Color,Alpha=box.Style.ColorAlpha or 1})
		paintProperty(box,'background-color',value,value,1)
	else box.SampledBackgroundColor=nil end
	if page.Alive and page.RequestAnimationLayout then for item in items do page:RequestAnimationLayout(item)end end
end
local function publishShadows(page,tree,box,properties,changed)
	local values=if changed['text-shadow']then BoxShadow.resolve(properties['text-shadow'],{Color=box.Style.Color,Alpha=box.Style.ColorAlpha or 1})else nil
	if values==nil and not box.AnimationTextShadowAuthor then return end
	if tree.RefreshAnimationTextShadows then
		local items=tree:RefreshAnimationTextShadows(box,values)
		if page.Alive and page.RequestAnimationLayout then for item in items do page:RequestAnimationLayout(item)end end
	else
		if not box.AnimationTextShadowAuthor then box.AnimationTextShadowAuthor={Value=box.Style.TextShadows}end
		box.Style.TextShadows=if values~=nil then values else box.AnimationTextShadowAuthor.Value
		if values==nil then box.AnimationTextShadowAuthor=nil end
	end
end
function HTMLAnimations.start(page: any,tree: any,diagnostic: (string)->(),services: any?,budgetMS: number?,syncViewport: (() -> ())?): any?
	local keyframes=tree.CSSRules and tree.CSSRules.Keyframes or {}
	-- An idle runtime keeps no frame connection. It must still observe a
	-- stylesheet that introduces the first animation after page creation.
	local runService=if services and services.RunService then services.RunService else game:GetService("RunService")
	local signal=runService.RenderStepped or runService.Heartbeat;assert(signal and signal.Connect,"CSS animations require RunService")
	local now=if services and services.Clock then services.Clock else os.clock
	-- A rendering update can publish several layout passes. They all use the
	-- same animation time; advancing the clock while publishing animated width
	-- would request another layout indefinitely without reaching the next frame.
	local frameTime=now()
	local self={Snapshots={},Pending={},Transitions={},CompletedTransitions={},OwnedCSSRecords={},Animations={},FilledAnimations={},AnimationRecords={},RestoreBoxes={},WorkQueue={},NextWork=1,Started=false,Alive=true,Frames=0,Dropped=0}
	local connection,tick;local scrollConnections={}
	local cssSubscribers={}
	local function notifyCSSRecords()for _,callback in table.clone(cssSubscribers)do callback()end end
	local function updateConnection()
		local working=false
		for _,transition in self.Transitions do for _,data in transition.Properties do if not data.DOMOwned then working=true;break end end end
		local wanted={}
		for _,item in self.Animations do
			if item.DOMOwned then continue end
			if item.Play~='paused'and not item.ScrollDriven then working=true end
			if item.Play~='paused'and item.Scroll and not item.Scroll.GetPropertyChangedSignal then working=true end
			if item.Play~='paused'and item.Scroll then wanted[item.Scroll]=true end
		end
		for gui,connections in scrollConnections do if not wanted[gui]then for _,c in connections do c:Disconnect()end;scrollConnections[gui]=nil end end
		for gui in wanted do if not scrollConnections[gui]and gui.GetPropertyChangedSignal then
			local connections={};scrollConnections[gui]=connections
			for _,key in {'CanvasPosition','AbsoluteWindowSize','AbsoluteCanvasSize'}do
				table.insert(connections,gui:GetPropertyChangedSignal(key):Connect(function()
					for _,item in self.Animations do if item.Scroll==gui then item.ScrollDirty=true end end
					if tick then tick()end
				end))
			end
		end end
		if working and not connection then connection=signal:Connect(tick)
		elseif not working and connection then connection:Disconnect();connection=nil end
	end
	local scrollOwners={}
	for _,candidate in tree.NodeBoxes or {} do if candidate.ScrollGui then scrollOwners[candidate.ScrollGui]=candidate end end
	local function scrollAncestor(box: any,timeline: string): (any?,string?,any?,any?)
		local spec=ScrollTimeline.parse(timeline,{FontSize=box.Style.FontSize,ViewportWidth=tree.OuterWidth,ViewportHeight=tree.ViewportHeight})
		if not spec or spec.Kind=='none'or spec.Kind=='auto'then return nil,nil,nil,spec end
		if spec.Kind=='scroll'and spec.Scroller=='self'then return box.ScrollGui,spec.Axis,nil,spec end
		if spec.Kind=='scroll'and spec.Scroller=='root'then return page.Root,spec.Axis,nil,spec end
		local gui=BoxTransform.target(box).Parent
		while gui do
			if gui.ClassName=="ScrollingFrame" then
				local owner=scrollOwners[gui]
				if spec.Kind=='scroll'or spec.Kind=='view'then return gui,spec.Axis,if spec.Kind=='view'then box else nil,spec end
				for index,name in if owner then owner.Style.ScrollTimelineNames or {} else {} do
					if name==timeline then return gui,(owner.Style.ScrollTimelineAxes or {})[((index-1)%(#(owner.Style.ScrollTimelineAxes or {"block"})))+1] or "block" end
				end
			end
			gui=gui.Parent
		end
		return nil,nil
	end
	local function boxes(nodes: any): any
		local result={};for node in nodes or {} do local box=BoxTransform.node(tree,node);if box then result[node]=box end end;return result
	end
	function self:BeforeStyleChange(nodes: any)
		for node,box in boxes(nodes) do
			local pose=visual(box);local transition=self.Transitions[box]
			if transition and transition.SampledOperations then pose.Operations=transition.SampledOperations end
			self.Snapshots[node]=pose
		end
	end
	function self:StyleChanged(nodes: any)
		for node,box in boxes(nodes) do
			self.Pending[node]=self.Snapshots[node] or visual(box)
		end
		table.clear(self.Snapshots)
	end
	local function reconcileAnimations(box: any)
		keyframes=tree.CSSRules and tree.CSSRules.Keyframes or {}
		local definitions=if tree.AnimationKeyframes and box.Node then tree:AnimationKeyframes(box.Node)else keyframes
		local old=self.AnimationRecords[box]or {};local records={};local used={}
		local oldLength=0;for index in old do oldLength=math.max(oldLength,index)end
		-- CSS matches repeated names from the end of the list, preserving the
		-- existing clock while an index or @keyframes definition changes.
		for index=#(box.Style.AnimationName or {}),1,-1 do
			local name=box.Style.AnimationName[index];local definition=definitions[name]
			if box.Style.Display=="none"or box.Style.Hidden or box.HiddenByAncestor then definition=nil end
			if name=="none"or not definition then continue end
			local item
			for previous=oldLength,1,-1 do if old[previous]and not used[previous]and old[previous].Name==name then item=old[previous];used[previous]=true;break end end
			if not item then
				if #self.Animations>=128 then continue end
				local started=frameTime;local play=Motion.pick(box.Style.AnimationPlay,index,"running")
				item={Box=box,Name=name,Start=started,Play=play,PausedAt=if play=="paused"then started else nil,HeldProgress=if play=="paused"then 0 else nil,LayoutValues={},InterpolateSize=box.Style.InterpolateSize or'numeric-only'}
				table.insert(self.Animations,item);table.insert(self.WorkQueue,{Animation=item})
			end
			item.Index=index
			local parent=box.Node and (ShadowTree.FlatParent(box.Node)or box.Node.Parent);local parentStyle=parent and tree.NodeStyles[parent]
			local parentSize=parentStyle and parentStyle.FontSize
			local frameTiming=Motion.pick(box.Style.AnimationTiming,index,'ease');local frameComposition=Motion.pick(box.Style.AnimationComposition,index,'replace')
			if item.Definition~=definition or item.Style~=box.Style or item.Width~=box.OuterWidth or item.Height~=box.OuterHeight or item.Revision~=tree.AnimationStyleRevision
				or item.FontSize~=box.Style.FontSize or item.RootFontSize~=box.Style.RootFontSize or item.ParentFontSize~=parentSize
				or item.ParentColor~=(parentStyle and parentStyle.Color)or item.ParentColorAlpha~=(parentStyle and parentStyle.ColorAlpha)
				or item.ProcessedTiming~=frameTiming or item.ProcessedComposition~=frameComposition then
				item.ProcessedDefinition=processedKeyframes(definition,box,frameTiming,frameComposition)
				item.ProcessedTiming,item.ProcessedComposition=frameTiming,frameComposition
				local important={};local author=if tree.AnimationDeclarations and box.Node then tree:AnimationDeclarations(box.Node)else {Important={}}
				for _,entries in {author.Important,InlineStyle.compile(box.Node and box.Node.Attributes.style or "").Important}do
					for _,entry in entries do if not entry.Error then
						for _,property in CSS_PROPERTIES do
							local spec=AnimationValues.Properties[property];local field=if spec then spec.Field else Individuals.Fields[property]or ({transform="Transform",["offset-distance"]="OffsetDistance",opacity="Opacity",["background-color"]="Background"})[property]
							if (if spec then AnimationValues.matches(spec,entry,property)elseif AnimationColors.Properties[property]then AnimationColors.matches(entry,property)else entry.Field==field)or property=='background-color'and(entry.Field=='BackgroundShorthand'or entry.VariableProperty=='background')or entry.VariableProperty==property then important[property]=true end
						end
					end end
				end
				local properties={};item.TransformTargeted=false
				for _,property in CSS_PROPERTIES do
					local transformed=property=='transform'or Individuals.Fields[property]~=nil
					if important[property]and not transformed then continue end
					local values=stops(item.ProcessedDefinition,property,box,parentStyle)
					if #values>0 then
						if transformed then item.TransformTargeted=true end
						if not important[property]then properties[property]=values end
					end
				end
				item.Properties=properties;item.Definition=definition;item.Style=box.Style;item.Width=box.OuterWidth;item.Height=box.OuterHeight
				item.Revision=tree.AnimationStyleRevision
				item.FontSize,item.RootFontSize,item.ParentFontSize=box.Style.FontSize,box.Style.RootFontSize,parentSize
				item.ParentColor,item.ParentColorAlpha=parentStyle and parentStyle.Color,parentStyle and parentStyle.ColorAlpha
			end
			if (item.Properties.transform or item.Properties.translate or item.Properties.rotate or item.Properties.scale)and box.TransformBaseX==nil then local target=BoxTransform.target(box);box.TransformBaseX=component(target.Position,"X",1)-(box.ViewportOffsetX or 0);box.TransformBaseY=component(target.Position,"Y",2)-(box.ViewportOffsetY or 0)end
			item.Duration=Motion.pick(box.Style.AnimationDuration,index,0);item.Delay=Motion.pick(box.Style.AnimationDelay,index,0)
			item.Timing=Motion.pick(box.Style.AnimationTiming,index,"ease");item.Iterations=Motion.pick(box.Style.AnimationIteration,index,1)
			item.Direction=Motion.pick(box.Style.AnimationDirection,index,"normal");item.Fill=Motion.pick(box.Style.AnimationFill,index,"none")
			item.Composition=Motion.pick(box.Style.AnimationComposition,index,"replace");item.Timeline=Motion.pick(box.Style.AnimationTimeline,index,"auto")
			item.ScrollDriven=item.Timeline~="auto";item.Scroll,item.Axis,item.ViewSubject,item.TimelineSpec=scrollAncestor(box,item.Timeline);item.Axis=item.Axis or box.Style.ScrollTimelineAxis;item.ScrollDirty=true
			item.RangeStart=Motion.pick(box.Style.AnimationRangeStart,index,{Name='normal',Offset={Value=0,Percent=true}})
			item.RangeEnd=Motion.pick(box.Style.AnimationRangeEnd,index,{Name='normal',Offset={Value=100,Percent=true}})
			if item.Finished and not item.Removed and not item.ScrollDriven and not item.DOMOwned then
				local sampleTime=if item.Play=="paused"then item.PausedAt or item.Start else frameTime
				local progress,finished,before=Motion.progress(sampleTime-item.Start-item.Delay,item.Duration,item.Iterations,item.Direction)
				if not finished then item.Finished=false;table.insert(self.Animations,item);table.insert(self.WorkQueue,{Animation=item})
				elseif progress~=nil then item.LastProgress=progress;item.LastEased=Motion.ease(item.Timing,progress,before);item.LastBefore=before end
			end
			records[index]=item
		end
		for index,item in old do if not used[index]then item.Removed=true;item.Finished=true;item.LayoutValues={};local position=table.find(self.Animations,item);if position then table.remove(self.Animations,position)end end end
		if next(records)then self.AnimationRecords[box]=records
		else self.AnimationRecords[box]=nil;if oldLength>0 then self.RestoreBoxes[box]=true end end
		local filled={};for index,item in records do if item.Finished and not item.Removed and (item.Fill=="forwards"or item.Fill=="both")then filled[index]=item end end
		self.FilledAnimations[box]=if next(filled)then filled else nil
	end
	local function publishLayout(box: any)
		local properties,changed={},{}
		local function underlying(property: string): any
			local value=properties[property]
			if value==nil then value=baseValue(property,box);properties[property]=value end
			return value
		end
		local records=self.AnimationRecords[box]or {}
		local currentTransform=false
		for _,item in records do if not item.Removed and not item.DOMCanceled and item.TransformTargeted then
			local sampleTime=if item.Play=='paused'then item.PausedAt or item.Start else frameTime
			local current=if item.DOMOwned then item.DOMTiming and(item.DOMTiming.IsCurrent or type(item.DOMTiming.progress)=='number')elseif item.ScrollDriven then item.Scroll~=nil and not item.Finished else sampleTime-item.Start-item.Delay<item.Duration*item.Iterations
			if current or not item.DOMOwned and(item.Fill=='forwards'or item.Fill=='both')then currentTransform=true;break end
		end end
		box.CSSAnimationTransformEffects=currentTransform
		for index=1,#(box.Style.AnimationName or {})do
			local item=records[index];if not item or item.Removed or item.DOMCanceled then continue end
			for property,value in item.SampledValues or {}do
				if not item.DOMOwned and item.Finished and item.Fill~="forwards"and item.Fill~="both"then continue end
				local composition=item.DOMComposition or item.Composition
				if not item.DOMOwned and item.SampledProgress~=nil then value=cssSample(item.Properties[property],item.SampledProgress,item.Timing,item.SampledBefore,property,box,underlying(property),composition,item.InterpolateSize)
				elseif composition~="replace"then value=cssCompose(property,underlying(property),value,composition,box,item.InterpolateSize)end
				properties[property]=value;changed[property]=true
			end
		end
		local transition=self.Transitions[box]
		if transition and(transition.Properties.transform or transition.Properties.translate or transition.Properties.rotate or transition.Properties.scale)then box.CSSAnimationTransformEffects=true end
		for property,value in if transition then transition.LayoutValues or {}else {}do properties[property]=value;changed[property]=true end
		for property,value in if transition then transition.IndividualValues or {}else {}do properties[property]=value;changed[property]=true end
		for property,value in if transition then transition.ColorValues or {}else {}do properties[property]=value;changed[property]=true end
		box.CSSAnimationColorProperties,box.CSSAnimationColorChanged=AnimationColors.values(properties,changed),{}
		for property in box.CSSAnimationColorProperties do box.CSSAnimationColorChanged[property]=true end
		local layout,layoutChanged={},{};for property in changed do if AnimationValues.Properties[property]then layout[property]=properties[property];layoutChanged[property]=true end end
		box.CSSAnimationLayoutProperties,box.CSSAnimationLayoutChanged=layout,layoutChanged
		local request=if page.RequestAnimationLayout then function(target)page:RequestAnimationLayout(target)end else nil
		if not box.HasScriptLayoutEffects then AnimationValues.write(box,layout,layoutChanged,request,if tree.PaintAnimationDecorations then function(target)tree:PaintAnimationDecorations(target)end else nil,metricPublisher(page,tree))end
		if not box.HasScriptColorEffects then publishColors(page,tree,box,properties,box.CSSAnimationColorChanged)end
		if not box.HasScriptLayoutEffects then publishShadows(page,tree,box,properties,changed)end
		if self.RestoreTransitionPaint then self:RestoreTransitionPaint(box)end
		local touched=box.CSSAnimationPaintProperties or {};local nextTouched={}
		for _,property in PROPERTIES do if changed[property]then nextTouched[property]=true end end
  if changed['transform-origin']then nextTouched['transform-origin']=true end
		local function paints(property)return (changed[property]or touched[property])and not(transition and transition.Properties[property])end
		if paints("opacity")and box.OpacityGroup then GroupOpacity.paint(box.OpacityGroup,box.Style,math.clamp(underlying("opacity"),0,1))end
		local transformOperations
		if changed['transform-origin']or touched['transform-origin']or paints("transform")or paints("offset-distance")or changed.translate or touched.translate or changed.rotate or touched.rotate or changed.scale or touched.scale then
			local value=underlying("transform");local distance=underlying("offset-distance").Distance
			local individuals={};for property in Individuals.Fields do individuals[property]=underlying(property)end
			local raw=value.PropertyOperations or box.Style.Transform or{}
			-- A concurrent transform transition owns only its transform list;
			-- individual properties still precede that list in the paint matrix.
			if transition and transition.TransformProperty then raw=transition.TransformProperty end
			box.SampledIndividualTransforms=individuals;box.SampledTransformPropertyOperations=raw
			transformOperations=Individuals.operations(box.Style,individuals,raw)
			local resolved=BoxTransform.resolve(box,transformOperations,distance)
			paintTransform(box,resolved)
		end
		if not box.HasScriptTransformEffects and(transformOperations or box.CSSAnimationTransformEffects or box.AnimationTransformContainingBlock~=nil)then
			if not transformOperations then
				local individuals={};for property in Individuals.Fields do individuals[property]=underlying(property)end
				local raw=if transition and transition.TransformProperty then transition.TransformProperty else underlying('transform').PropertyOperations or box.Style.Transform or{}
				transformOperations=Individuals.operations(box.Style,individuals,raw)
			end
			sampledContainingBlock(box,transformOperations,tree,page)
			if not box.CSSAnimationTransformEffects and not transition then box.AnimationTransformContainingBlock=nil end
		end
		box.CSSAnimationPaintProperties=if next(nextTouched)then nextTouched else nil
		if not next(nextTouched)and not transition then box.SampledIndividualTransforms=nil;box.SampledTransformPropertyOperations=nil end
	end
	local function publishLayouts(changedNodes: any?)
		local function touched(box) return not changedNodes or changedNodes[box.Node] end
		local targets={};for box in self.AnimationRecords do if touched(box)then targets[box]=true end end
		for box in self.Transitions do if touched(box)then targets[box]=true end end
		-- The last effect needs one publication to restore its author layout and
		-- paint. Static page boxes must never enter the per-frame publisher.
		for box in self.RestoreBoxes do if touched(box)then targets[box]=true end end
		local ordered={};for box in targets do local depth=0;local node=box.Node;while node do depth+=1;node=ShadowTree.FlatParent(node)or node.Parent end;table.insert(ordered,{Box=box,Depth=depth})end
		table.sort(ordered,function(a,b)return a.Depth<b.Depth end)
		for _,entry in ordered do publishLayout(entry.Box);self.RestoreBoxes[entry.Box]=nil end
	end
	local knownBoxes={}
	local advanceTransition,advanceAnimation
	function self:DOMChanged(kept: any)
		kept=table.clone(kept);for _,box in BoxTransform.boxes(tree)do if box.Kind=="InlineImage"then kept[box]=true end end
		if tree.RefreshAnimationTextShadows then for box in knownBoxes do if not kept[box]and box.AnimationTextShadowAuthor then tree:RefreshAnimationTextShadows(box,nil)end end end
		if tree.RefreshAnimationColors then for box in knownBoxes do if not kept[box]and box.AnimationColorAuthor then tree:RefreshAnimationColors(box,{})end end end
		if tree.RefreshAnimationMetrics then
			for box in knownBoxes do if not kept[box]and box.AnimationMetricAuthor then tree:RefreshAnimationMetrics(box,{})end end
		end
		for box in self.RestoreBoxes do if not kept[box]then self.RestoreBoxes[box]=nil end end
		for box in self.Transitions do if not kept[box] then self.Transitions[box]=nil end end
		for box in self.CompletedTransitions do if not kept[box]then self.CompletedTransitions[box]=nil end end
		for record in self.OwnedCSSRecords do if not kept[record.Box]then record.Removed=true;self.OwnedCSSRecords[record]=nil end end
		for box in self.FilledAnimations do if not kept[box]then self.FilledAnimations[box]=nil end end
		for i=#self.Animations,1,-1 do
			local item=self.Animations[i]
			if not kept[item.Box] then item.Finished=true;table.remove(self.Animations,i) end
		end
		for i=#self.WorkQueue,1,-1 do
			local job=self.WorkQueue[i]
			if (job.Animation and job.Animation.Finished) or (job.TransitionBox and not kept[job.TransitionBox]) then table.remove(self.WorkQueue,i) end
		end
		for node in self.Pending do if not BoxTransform.node(tree,node) then self.Pending[node]=nil end end
		for node in self.Snapshots do if not BoxTransform.node(tree,node) then self.Snapshots[node]=nil end end
		for box in knownBoxes do if not kept[box] then knownBoxes[box]=nil end end
		for box in self.AnimationRecords do if not kept[box]then self.AnimationRecords[box]=nil end end
		updateConnection()
		notifyCSSRecords()
	end
	function self:AfterLayout(changedNodes: any?)
		local function touched(box) return not changedNodes or changedNodes[box.Node] end
		-- An idle runtime has no frame subscription. Seed a newly started effect
		-- once; updateConnection below holds this sample for its follow-up passes.
		if not connection then frameTime=now()end
		self.Started=true
		-- Paint-only style publications do not move unrelated boxes. Reconcile
		-- their effects locally; real layout still visits the complete tree.
		for _,box in if changedNodes then boxes(changedNodes) else BoxTransform.boxes(tree) do
			local rendered=not(box.Style.Hidden or box.Style.Display=="none"or box.HiddenByAncestor or box.TopLayerHidden)
			if rendered and not knownBoxes[box]and box.Node and box.Node.Kind=="Element"and tree.StartingStyle then
				local starting=tree:StartingStyle(box.Node)
				if starting then self.Pending[box.Node]=startingVisual(box,starting)end
			elseif not rendered then
				self.Pending[box.Node]=nil
				if self.Transitions[box]then self.RestoreBoxes[box]=true end
				self.Transitions[box]=nil
			end
			knownBoxes[box]=rendered;reconcileAnimations(box)
		end
		for box,filled in self.FilledAnimations do if not touched(box) then continue end;for index=1,#(box.Style.AnimationName or {})do local item=filled[index];if not item or item.DOMOwned then continue end
			if Motion.pick(box.Style.AnimationName,item.Index,"none")==item.Name then paintAnimation(item,item.LastProgress or 1,item.LastBefore)else filled[index]=nil end
		end end
		for box,item in self.Transitions do
			if not touched(box) then continue end
			local current=visual(box)
			relocate(item.Before,box,current)
			relocate(item.Target,box,current,true)
			for _,data in item.Properties do
				if data.Before and data.Before~=item.Before then relocate(data.Before,box,current)end
				if data.Target and data.Target~=item.Target then relocate(data.Target,box,current,true)end
			end
		end
		for _,item in self.Animations do
			if not touched(item.Box) then continue end
			if item.DOMOwned then continue end
			local play=Motion.pick(item.Box.Style.AnimationPlay,item.Index,"running")
			if play~=item.Play then
				local changedAt=frameTime
				if play=="paused" then item.PausedAt=changedAt;item.HeldProgress=item.LastProgress or 0
				else item.Start+=changedAt-(item.PausedAt or changedAt);item.PausedAt=nil end
				item.Play=play
			end
			if item.ScrollDriven then
				item.ScrollDirty=true
				-- A paused scroll animation still applies its held keyframe, even
				-- after layout repaints the element's unanimated appearance.
				if item.Play=="paused" and item.Scroll then paintAnimation(item,item.HeldProgress or 0)elseif item.Scroll then advanceAnimation(item,frameTime)end
			else
				local sampleTime=if item.Play=="paused" then item.PausedAt or item.Start else frameTime
				local progress,finished,before=Motion.progress(sampleTime-item.Start-item.Delay,item.Duration,item.Iterations,item.Direction)
				if finished and item.Fill~='forwards'and item.Fill~='both'then progress=nil end
				if progress==nil and (item.Fill=="backwards" or item.Fill=="both") then progress=if item.Direction=="reverse" or item.Direction=="alternate-reverse" then 1 else 0 end
				if progress~=nil then paintAnimation(item,progress,before)else item.SampledValues=nil;item.LayoutValues={}end
			end
		end
		for node,before in self.Pending do
			if changedNodes and not changedNodes[node] then continue end
			self.Pending[node]=nil
			local box=BoxTransform.node(tree,node);if not box then continue end
			local target=targetVisual(box);local properties={};local previous=self.Transitions[box]
			relocate(before,box,target)
			-- Native Position offsets are integers, but AnchorPoint is fractional.
			-- Keep the starting anchor throughout the transition and express the
			-- endpoint in that same coordinate system. Interpolating compensating
			-- positions and anchors independently makes a pure translateY wobble.
			-- Scale changes the anchor's displacement; rotation still uses the
			-- native surface center, so rebasing does not change the CSS pivot.
			if not (before.Projected or target.Projected) then
				target.X+=(before.AnchorX-target.AnchorX)*target.SurfaceWidth*target.Scale
				target.Y+=(before.AnchorY-target.AnchorY)*target.SurfaceHeight*target.Scale
				target.AnchorX,target.AnchorY=before.AnchorX,before.AnchorY
			end
			for _,property in CSS_TRANSITION_PROPERTIES do
				local index=transitionIndex(box.Style,property);if not index then continue end
				local existing=previous and previous.Properties[property]
				local targetValue=transitionValue(target,property)
				if existing and equalValue(existing.TargetValue,targetValue)then properties[property]=existing;continue end
				local duration=Motion.pick(box.Style.TransitionDuration,index,0);if duration<=0 then continue end
				if AnimationValues.Properties[property]then
					local function numeric(value)return type(value)=="number"or type(value)=="table"and not value.Auto and not value.Intrinsic and (type(value.Value)=="number"or value.Kind=="length")end
					local from,to=before.Layout[property],target.Layout[property]
					if property=='transform-origin'or property=='text-shadow'then
      -- Three length/percentage coordinates share the transform paint basis.
     elseif property=='box-shadow'then
						if not BoxShadow.compatible(from,to)and Motion.pick(box.Style.TransitionBehavior,index,'normal')~='allow-discrete'then continue end
					elseif not AnimationValues.Properties[property].Corner and(not numeric(from)or not numeric(to))then
						if box.Style.InterpolateSize~='allow-keywords'or numeric(from)==numeric(to)or not target.Intrinsic[property]then continue end
					end
				end
				-- Flow movement alone cannot start a CSS transform transition.
				local differs=if AnimationValues.Properties[property]then not equalValue(before.Layout[property],target.Layout[property])elseif Individuals.Fields[property]then not equalValue(before.Individuals[property],target.Individuals[property])elseif property=="transform" then not Matrix4.equal(Transform2D.matrix(before.TransformProperty,box.OuterWidth or 0,box.OuterHeight or 0),Transform2D.matrix(target.TransformProperty,box.OuterWidth or 0,box.OuterHeight or 0)) elseif property=="offset-distance" then not same({X=before.X,Y=before.Y,Rotation=before.Rotation,Scale=before.Scale,AnchorX=before.AnchorX,AnchorY=before.AnchorY},{X=target.X,Y=target.Y,Rotation=target.Rotation,Scale=target.Scale,AnchorX=target.AnchorX,AnchorY=target.AnchorY})
					elseif property=="opacity" then math.abs(before.Opacity-target.Opacity)>.0001
					elseif property=="border-radius" then math.abs(before.Radius-target.Radius)>.0001
					elseif property=="box-shadow" then math.abs(before.ShadowAlpha-target.ShadowAlpha)>.0001 or math.abs(before.ShadowX-target.ShadowX)>.0001 or math.abs(before.ShadowY-target.ShadowY)>.0001 or math.abs(before.ShadowBlur-target.ShadowBlur)>.0001 or math.abs(before.ShadowSpread-target.ShadowSpread)>.0001 or before.ShadowColor~=target.ShadowColor
					elseif AnimationColors.Properties[property]then not equalValue(before.Colors[property],target.Colors[property])
					else before.Background~=target.Background or math.abs(before.BackgroundAlpha-target.BackgroundAlpha)>.0001
				if differs then
					local factor=1;local reversingValue=transitionValue(before,property)
					if existing and equalValue(existing.ReversingValue,targetValue)then
						local elapsed=frameTime-(existing.Start or previous.Start)-(existing.Delay or 0)
						local progress=if existing.DOMTiming and type(existing.DOMTiming.progress)=='number'then existing.DOMTiming.progress else Motion.ease(existing.Timing or'ease',math.clamp(elapsed/math.max(existing.Duration or 0,.000001),0,1),elapsed<0)
						factor=math.clamp(math.abs(progress*(existing.ReversingFactor or 1)+(1-(existing.ReversingFactor or 1))),0,1)
						reversingValue=existing.TargetValue
					end
					local delay=Motion.pick(box.Style.TransitionDelay,index,0)
					local data={Index=index,Before=before,Target=target,TargetValue=targetValue,ReversingValue=reversingValue,ReversingFactor=factor,
						Start=frameTime,Duration=duration*factor,Delay=if delay<0 then delay*factor else delay,Timing=Motion.pick(box.Style.TransitionTiming,index,'ease')}
					if AnimationValues.Properties[property]then
						data.From=before.Layout[property];data.To=target.Layout[property]
						local function resolve(value,pose)
							if type(value)=='table'and(value.Auto or value.Intrinsic)and pose.Intrinsic and pose.Intrinsic[property]then return {Value=pose.Intrinsic[property],Percent=false,ResolvedKeyword=value}end
							return value
						end
						if box.Style.InterpolateSize=='allow-keywords'then data.From=resolve(data.From,before);data.To=resolve(data.To,target)end
					elseif Individuals.Fields[property]then data.From=before.Individuals[property];data.To=target.Individuals[property]
					end
					properties[property]=data
				end
			end
			if next(properties) then
				local gui=BoxTransform.target(box)
				if properties.transform or properties["offset-distance"] then
 if before.Projected or target.Projected then BoxTransform.paint3D(box,before.Operations) end
					BoxTransform.paintPosition(box,before.X-before.ViewportX,before.Y-before.ViewportY);gui.Rotation=before.Rotation;gui.AnchorPoint=Vector2.new(before.AnchorX,before.AnchorY)
					if box.TransformScale then box.TransformScale.Scale=before.Scale end
				end
				if properties["background-color"] then
					local paintGui=box.PaintBackgroundGui or box.Gui
					paintGui.BackgroundColor3=before.Background;paintGui.BackgroundTransparency=1-before.BackgroundAlpha
					if box.ImageItem then box.ImageItem.TransitioningBackground=true end
				end
				if properties["border-radius"] and box.Corner then box.Corner.CornerRadius=UDim.new(0,before.Radius) end
				if properties["box-shadow"] and box.ShadowGuis and box.ShadowGuis[1] then
					local shadow=box.ShadowGuis[1];shadow.Transparency=1-before.ShadowAlpha;shadow.Offset=UDim2.fromOffset(before.ShadowX,before.ShadowY)
					shadow.BlurRadius=UDim.new(0,before.ShadowBlur);shadow.Spread=UDim2.fromOffset(before.ShadowSpread,before.ShadowSpread)
				end
				if properties.opacity and box.OpacityGroup then GroupOpacity.paint(box.OpacityGroup,box.Style,before.Opacity) end
				if not self.Transitions[box] then table.insert(self.WorkQueue,{TransitionBox=box}) end
				local layout,individuals,colors={},{},{};for property,data in properties do
					if AnimationValues.Properties[property]then layout[property]=if previous and previous.Properties[property]==data then previous.LayoutValues[property]else before.Layout[property]
					elseif Individuals.Fields[property]then individuals[property]=if previous and previous.Properties[property]==data then previous.IndividualValues[property]else before.Individuals[property]
					elseif AnimationColors.Properties[property]then colors[property]=if previous and previous.Properties[property]==data then previous.ColorValues[property]else before.Colors[property]end
				end
				self.Transitions[box]={Box=box,Before=before,Target=target,Properties=properties,LayoutValues=layout,IndividualValues=individuals,ColorValues=colors,Start=frameTime,
					LiveRelativeTransform=properties.transform~=nil and(relativeOperations(before.Operations)or relativeOperations(target.Operations))}
			elseif previous then self.Transitions[box]=nil;self.RestoreBoxes[box]=true
			end
		end
		-- Layout republishes the author transform and opacity. Restore the
		-- transition's current sample after geometry moves, including a width
		-- transition that caused this layout; keep its original clock.
		for box,item in table.clone(self.Transitions)do if touched(box) then advanceTransition(box,item,frameTime) end end
		-- A controller can finish or cancel its paint while the transition still
		-- has a CSS owning element. Only a real authored target/property/render
		-- change disassociates that retained record.
		local authorStyles={}
		for record in self.OwnedCSSRecords do
			local box=record.Box;if not touched(box)then continue end
			local active=self.Transitions[box]and self.Transitions[box].Properties[record.Property]
			if active==record then continue end
			local style=authorStyles[box]
			if not style then
				style=box.AnimationMetricUnderlyingStyle or box.Style
				if box.AnimationAuthorFields or box.AnimationMetricAuthor then
					style=table.clone(style)
					for field,author in box.AnimationAuthorFields or{}do style[field]=author.Value end
					for field,value in box.AnimationMetricAuthor or{}do style[field]=value end
				end
				authorStyles[box]=style
			end
			local property=record.Property;local target
			if AnimationValues.Properties[property]then target=AnimationValues.fromStyle(style,property)
			elseif Individuals.Fields[property]then target=Individuals.fromStyle(style,property)
			elseif AnimationColors.Properties[property]then
				local foreground=AnimationColors.resolve(AnimationColors.base(box,'color'),{Color=style.Color,Alpha=style.ColorAlpha or 1})
				target=AnimationColors.resolve(AnimationColors.base(box,property),foreground)
			elseif property=='transform'then target=style.Transform or{}
			elseif property=='offset-distance'then target=style.OffsetDistance
			elseif property=='opacity'then target=style.Opacity or 1
			else target=transitionValue(targetVisual(box),property)end
			if not knownBoxes[box]or not transitionIndex(box.Style,record.Property)or(active and active~=record)or not equalValue(record.TargetValue,target)then
				record.Removed=true;self.OwnedCSSRecords[record]=nil
			end
		end
		publishLayouts(changedNodes)
		notifyCSSRecords()
		updateConnection()
	end
	advanceTransition=function(box: any,item: any,started: number,restore: boolean?)
		local complete=true
		for property,data in item.Properties do
			local index=data.Index;local duration=data.Duration or Motion.pick(box.Style.TransitionDuration,index,0);local delay=data.Delay or Motion.pick(box.Style.TransitionDelay,index,0)
			local elapsed=started-(data.Start or item.Start)-delay
			local raw=math.clamp(elapsed/math.max(duration,.000001),0,1)
			local driven=data.DOMTiming
			if data.DOMOwned and not driven then complete=false;continue end
			if driven then raw=if driven.Phase=='after'then 1 else 0;if driven.IsCurrent or type(driven.progress)=='number'then complete=false end
			elseif raw<1 then complete=false end
			data.Completed=if driven then driven.Phase=='after'and driven.progress==nil else raw==1
			local t=if driven then(if type(driven.progress)=='number'then driven.progress elseif driven.Phase=='after'then 1 else 0)else Motion.ease(data.Timing or Motion.pick(box.Style.TransitionTiming,index,"ease"),raw,elapsed<0)
			if data.DOMValueKnown then
				local value=data.DOMValue
				if AnimationColors.Properties[property]then item.ColorValues[property]=value
				elseif AnimationValues.Properties[property]then item.LayoutValues[property]=value
				elseif Individuals.Fields[property]then item.IndividualValues[property]=value
				elseif property=='transform'then item.TransformProperty=value.PropertyOperations or value.Operations;box.SampledTransformPropertyOperations=item.TransformProperty;paintTransform(box,value)
				elseif property=='offset-distance'then paintTransform(box,BoxTransform.resolve(box,Transform2D.operations(box.Style),value.Distance))
				elseif property=='opacity'and box.OpacityGroup then GroupOpacity.paint(box.OpacityGroup,box.Style,math.clamp(value,0,1))end
				continue
			end
			if AnimationColors.Properties[property]then
				item.ColorValues[property]=AnimationColors.mix((data.Before or item.Before).Colors[property],(data.Target or item.Target).Colors[property],t)
			elseif AnimationValues.Properties[property]then
				item.LayoutValues[property]=AnimationValues.mix(data.From,data.To,t,box,property)
			elseif Individuals.Fields[property]then
				item.IndividualValues[property]=Individuals.mix(property,data.From,data.To,t,AnimationValues.mix,box)
			elseif property=="transform" or property=="offset-distance" then
				box.TransformApplied=true
				local a,b=data.Before or item.Before,data.Target or item.Target
				if property=='transform'then
					item.TransformProperty=liveOperations(a.TransformProperty,b.TransformProperty,t,box)
					box.SampledTransformPropertyOperations=item.TransformProperty
					if next(item.IndividualValues)then continue end
				end
				if item.LiveRelativeTransform then
					if property=="offset-distance"then continue end
					local operations=liveOperations(a.Operations,b.Operations,t,box);item.SampledOperations=operations
					local distance;local path=item.Properties["offset-distance"]
					if path then
						local pd=path.Duration or Motion.pick(box.Style.TransitionDuration,path.Index,0);local pdelay=path.Delay or Motion.pick(box.Style.TransitionDelay,path.Index,0)
						local pe=started-(path.Start or item.Start)-pdelay;local pt=Motion.ease(path.Timing or Motion.pick(box.Style.TransitionTiming,path.Index,"ease"),math.clamp(pe/math.max(pd,.000001),0,1),pe<0)
						distance=AnimationValues.mix(a.Distance,b.Distance,pt,box)
					end
					local resolved=BoxTransform.resolve(box,operations,distance)
					if resolved.Projected or box.Scene3DRoot then BoxTransform.paint3D(box,operations)
					else local ox,oy=BoxTransform.origin(box);BoxTransform.paint(box,resolved.X,resolved.Y,resolved.Rotation,resolved.Scale,ox,oy)end
 elseif property=="transform" and (a.Projected or b.Projected or box.Scene3DRoot) then
  BoxTransform.paint3D(box,Transform2D.interpolate(a.Operations,b.Operations,t,box.OuterWidth or 0,box.OuterHeight or 0))
 else
  local target=BoxTransform.target(box);target.AnchorPoint=Vector2.new(a.AnchorX,a.AnchorY);BoxTransform.paintPosition(box,lerp(a.X-a.ViewportX,b.X-b.ViewportX,t),lerp(a.Y-a.ViewportY,b.Y-b.ViewportY,t));target.Rotation=lerp(a.Rotation,b.Rotation,t);if box.TransformScale then box.TransformScale.Scale=lerp(a.Scale,b.Scale,t) end
 end
			elseif property=="opacity" then if box.OpacityGroup then GroupOpacity.paint(box.OpacityGroup,box.Style,lerp((data.Before or item.Before).Opacity,(data.Target or item.Target).Opacity,t)) end
			elseif property=="border-radius" then if box.Corner then box.Corner.CornerRadius=UDim.new(0,lerp((data.Before or item.Before).Radius,(data.Target or item.Target).Radius,t)) end
			elseif property=="box-shadow" then
				local shadow=box.ShadowGuis and box.ShadowGuis[1]
				if shadow then
					local a,b=data.Before or item.Before,data.Target or item.Target
					shadow.Transparency=1-lerp(a.ShadowAlpha,b.ShadowAlpha,t)
					shadow.Offset=UDim2.fromOffset(lerp(a.ShadowX,b.ShadowX,t),lerp(a.ShadowY,b.ShadowY,t))
					shadow.BlurRadius=UDim.new(0,lerp(a.ShadowBlur,b.ShadowBlur,t))
					shadow.Spread=UDim2.fromOffset(lerp(a.ShadowSpread,b.ShadowSpread,t),lerp(a.ShadowSpread,b.ShadowSpread,t))
					shadow.Color=color(a.ShadowColor,b.ShadowColor,t)
				end
			else local a,b=data.Before or item.Before,data.Target or item.Target;paintProperty(box,'background-color',{Color=a.Background,Alpha=a.BackgroundAlpha},{Color=b.Background,Alpha=b.BackgroundAlpha},t)end
		end
		if complete then
			if box.ImageItem then box.ImageItem.TransitioningBackground=false end
			self.Transitions[box]=nil
			self.RestoreBoxes[box]=true
			if not restore then self.CompletedTransitions[box]=item end
		end
	end
	advanceAnimation=function(item: any,started: number): boolean
		if item.DOMOwned then return false end
		if item.Play=="paused" then return false end
		local progress,finished,before
		if item.ScrollDriven then
			if not item.Scroll then return false end
			if not item.ScrollDirty and item.Scroll.GetPropertyChangedSignal then return false end;item.ScrollDirty=false
			local owner=scrollOwners[item.Scroll];local style=owner and owner.Style or {};local vertical=(style.WritingMode or'horizontal-tb')~='horizontal-tb'
			local horizontal=item.Axis=='x'or item.Axis=='inline'and not vertical or item.Axis=='block'and vertical;local position=item.Scroll.CanvasPosition or Vector2.zero
			local canvas=item.Scroll.AbsoluteCanvasSize or Vector2.new(component(item.Scroll.CanvasSize,"X",1),component(item.Scroll.CanvasSize,"Y",2))
			local viewport=item.Scroll.AbsoluteWindowSize or item.Scroll.AbsoluteSize or Vector2.zero;local extent=if horizontal then canvas.X-viewport.X else canvas.Y-viewport.Y
			if extent<=0 then item.SampledValues=nil;item.LayoutValues={};return false end
			local offset=if horizontal then position.X else position.Y;local port=if horizontal then viewport.X else viewport.Y
			local start,size,insetStart,insetEnd=0,extent,0,0
			if item.ViewSubject then
				local subject=item.ViewSubject;local node=subject.Node;size=if horizontal then subject.OuterWidth or 0 else subject.OuterHeight or 0
				while node do local current=BoxTransform.node(tree,node);if current==owner or current==tree then break end;if current then start+=if horizontal then current.LayoutX or 0 else current.LayoutY or 0 end;node=ShadowTree.FlatParent(node)or(if node.Kind=='ShadowRoot'then node.Host else node.Parent)end
				local insets=item.TimelineSpec and item.TimelineSpec.Insets
				local padding=style.ScrollPadding or {0,0,0,0};local leading=if horizontal then 4 else 1;local trailing=if horizontal then 2 else 3
				local function inset(value,side)return if not value or value.Auto then (if type(padding[side])=='table'then LengthExpression.resolve(padding[side],port)else padding[side]or 0)else LengthExpression.resolve(value,port)end
				insetStart,insetEnd=inset(insets and insets[1],leading),inset(insets and insets[2],trailing)
			end
			local function endpoint(point)
				local a,b=0,extent;if item.ViewSubject then a,b=ScrollTimeline.bounds(point.Name,start,size,port,insetStart,insetEnd)end
				return a+LengthExpression.resolve(point.Offset,b-a)
			end
			local first,last=endpoint(item.RangeStart),endpoint(item.RangeEnd);if last<=first then return false end
			local raw=(offset-first)/(last-first);before=raw<0
			if raw<0 and item.Fill~='both'and item.Fill~='backwards'or raw>1 and item.Fill~='both'and item.Fill~='forwards'then item.SampledValues=nil;item.LayoutValues={};return true end
			progress=math.clamp(raw,0,1);if item.Direction=='reverse'or item.Direction=='alternate-reverse'then progress=1-progress end;finished=false
		else
			local elapsed=started-item.Start-item.Delay;progress,finished,before=Motion.progress(elapsed,item.Duration,item.Iterations,item.Direction)
		end
		if progress==nil then if item.Fill~="backwards" and item.Fill~="both" then item.SampledValues=nil;item.LayoutValues={};return false else progress=if item.Direction=="reverse" or item.Direction=="alternate-reverse" then 1 else 0 end end
		local eased=Motion.ease(item.Timing,progress,before)
		item.LastProgress,item.LastEased,item.LastBefore=progress,eased,before
		paintAnimation(item,progress,before)
		if finished then
			if item.Fill~="forwards" and item.Fill~="both" then item.SampledValues=nil;item.LayoutValues={}end
			if item.Fill=="forwards"or item.Fill=="both"then self.FilledAnimations[item.Box]=self.FilledAnimations[item.Box]or {};self.FilledAnimations[item.Box][item.Index]=item end
			item.Finished=true
			local index=table.find(self.Animations,item)
			if index then table.remove(self.Animations,index) end
		end
		return true
	end
	function self:RestoreTransitionPaint(box)
		-- A retained currentColor recascade repaints its dependent surfaces.
		-- Reapply direct paint transitions at the held publication time, without
		-- changing their clocks, restarting effects or requesting layout.
		local transition=self.Transitions[box]or self.CompletedTransitions[box]
		if transition then advanceTransition(box,transition,frameTime,true);self.CompletedTransitions[box]=nil end
	end
	-- Releasing the last script effect must expose the CSS effect at the same
	-- publication, including a forwards fill that no longer requests frames.
	function self:PaintUnderlying(node: any)
		if not self.Alive or not page.Alive then return end
		local box=BoxTransform.node(tree,node);if not box then return end
		local filled=self.FilledAnimations[box]
		if filled then for index=1,#(box.Style.AnimationName or {})do local item=filled[index];if item and Motion.pick(box.Style.AnimationName,item.Index,"none")==item.Name then paintAnimation(item,item.LastProgress or 1,item.LastBefore)end end end
		local sample=frameTime
		for _,item in table.clone(self.Animations)do if item.Box~=box then continue end
			if item.DOMOwned then continue end
			if item.Play=="paused"then
				local progress=if item.ScrollDriven then item.HeldProgress or item.LastProgress else Motion.progress((item.PausedAt or item.Start)-item.Start-item.Delay,item.Duration,item.Iterations,item.Direction)
				if progress~=nil then paintAnimation(item,progress)end
			else advanceAnimation(item,sample)end
		end
		local transition=self.Transitions[box];if transition then advanceTransition(box,transition,sample)end
		publishLayout(box)
		self.RestoreBoxes[box]=nil
		updateConnection()
	end
	-- Script commit reads lower CSS animation effects without painting or
	-- advancing native transitions (which have a higher cascade priority).
	function self:SampleUnderlying(node: any,properties: any,targeted: any,liveSample: boolean?,beforeRecord: any?): (boolean,string?)
		local box=BoxTransform.node(tree,node);if not box then return true,nil end
		-- The caller may hold a previously published CSS layout sample. Always
		-- begin from author values so additive lower effects are applied once.
		for _,property in CSS_PROPERTIES do if targeted[property]then properties[property]=baseValue(property,box)end end
		-- CSS transitions sort before CSS animations and author-created effects
		-- in each property's effect stack. Their held values are the underlying
		-- input; only the class of the final participating effect decides where
		-- the resulting value enters the cascade. Sampling cannot repaint or
		-- advance a transition's retained clock.
		local transition=self.Transitions[box]
		for property,data in transition and transition.Properties or{}do
			if not targeted[property]or data==beforeRecord or data.DOMCanceled then continue end
			local value
			if data.DOMOwned then
				if data.DOMValueKnown then value=data.DOMValue end
			else
				local elapsed=(if liveSample then now()else frameTime)-(data.Start or transition.Start)-(data.Delay or 0)
				local t=Motion.ease(data.Timing or'ease',math.clamp(elapsed/math.max(data.Duration or 0,.000001),0,1),elapsed<0)
				local a,b=data.Before or transition.Before,data.Target or transition.Target
				if AnimationValues.Properties[property]then value=AnimationValues.mix(data.From,data.To,t,box,property)
				elseif Individuals.Fields[property]then value=Individuals.mix(property,data.From,data.To,t,AnimationValues.mix,box)
				elseif AnimationColors.Properties[property]then value=AnimationColors.mix(a.Colors[property],b.Colors[property],t)
				elseif property=='opacity'then value=lerp(a.Opacity,b.Opacity,t)
				elseif property=='transform'then value={PropertyOperations=liveOperations(a.TransformProperty,b.TransformProperty,t,box)}
				elseif property=='offset-distance'then value={Distance=AnimationValues.mix(a.Distance,b.Distance,t,box,property)}end
			end
			if value~=nil then properties[property]=value end
		end
		local function apply(item: any,progress: number,before: boolean?): (boolean,string?)
			for _,property in CSS_PROPERTIES do
				if not targeted[property]then continue end
				local list=item.Properties[property];if not list then continue end
				properties[property]=cssSample(list,progress,item.Timing,before,property,box,properties[property]or baseValue(property,box),item.Composition,item.InterpolateSize)
			end;return true,nil
		end
		-- Direct commitStyles may sample the current time. Repainting after a
		-- layout must retain the frame sample and cannot advance layout effects.
		local sample=if liveSample then now()else frameTime
		local records=self.AnimationRecords[box]or {}
		for index=1,#(box.Style.AnimationName or {})do
			local item=records[index];if item==beforeRecord then break end
			if not item or item.Removed or item.DOMCanceled or item.Finished and item.Fill~="forwards"and item.Fill~="both"then continue end
			local progress,before
			if item.DOMOwned then
				-- Controlled values already include their own endpoint composition.
				for property,value in item.SampledValues or{}do if targeted[property]then properties[property]=value end end
				continue
			elseif item.Finished then progress,before=item.LastProgress or 1,item.LastBefore
			elseif item.ScrollDriven then progress=item.HeldProgress or item.LastProgress
			else local finished;progress,finished,before=Motion.progress((if item.Play=="paused"then item.PausedAt or item.Start else sample)-item.Start-item.Delay,item.Duration,item.Iterations,item.Direction)end
			if progress==nil and(item.Fill=="backwards"or item.Fill=="both")then progress=if item.Direction=="reverse"or item.Direction=="alternate-reverse"then 1 else 0 end
			if progress~=nil then local ok,message=apply(item,progress,before);if not ok then return false,message end end
		end
		return true,nil
	end
	function self:GetCSSRecords()
		local result={}
		for _,records in self.AnimationRecords do for _,item in records do if not item.Removed and not item.ScrollDriven then table.insert(result,{Record=item,Kind='animation',Target=item.Box.Node,Index=item.Index})end end end
		local seen={}
		for box,transition in self.Transitions do for property,data in transition.Properties do if not data.Removed then data.Box=box;data.Property=property;data.Transition=transition;seen[data]=true;table.insert(result,{Record=data,Kind='transition',Target=box.Node,Property=property,Index=data.Index})end end end
		for data in self.OwnedCSSRecords do if not seen[data]and not data.Removed then table.insert(result,{Record=data,Kind='transition',Target=data.Box.Node,Property=data.Property,Index=data.Index})end end
		return result
	end
	function self:AcquireCSSRecord(record)
		if record.Removed then return end
		record.DOMOwned=true;record.DOMCanceled=false
		if record.Property then
			self.OwnedCSSRecords[record]=true
			local box=record.Box;local transition=self.Transitions[box]
			if not transition then transition={Box=box,Before=record.Before,Target=record.Target,Properties={},LayoutValues={},IndividualValues={},ColorValues={},Start=record.Start};self.Transitions[box]=transition end
			if not transition.Properties[record.Property]then transition.Properties[record.Property]=record;record.Transition=transition end
		end
		updateConnection()
	end
	function self:CSSRecordTime(record)return((if record.Play=='paused'then record.PausedAt or record.Start else now())-record.Start)*1000 end
	function self:ApplyCSSRecord(record,values,timing)
		if not self.Alive or not page.Alive or record.Removed or record.DOMCanceled then return end
		record.DOMTiming=timing
		local box=record.Box
		if record.Property then
			local transition=self.Transitions[box]
			if not transition or transition.Properties[record.Property]~=record then return end
			record.DOMValue=values[record.Property];record.DOMValueKnown=record.DOMValue~=nil
			advanceTransition(box,transition,frameTime,true)
		else
			record.SampledValues=values;record.DOMComposition='replace';record.LastProgress=timing.progress;record.LastBefore=timing.Phase=='before'
		end
		publishLayout(box)
		if tree.ScriptAnimationPaint then tree.ScriptAnimationPaint:AfterLayout()end
		updateConnection()
	end
	function self:ReleaseCSSRecord(record,cancel)
		if not self.Alive then return end
		record.DOMCanceled=cancel==true;record.SampledValues=nil;record.DOMTiming={Phase='idle',IsCurrent=false};record.DOMValue=nil;record.DOMValueKnown=nil
		local box=record.Box
		if cancel and record.Property then box.CSSAnimationPaintProperties=box.CSSAnimationPaintProperties or{};box.CSSAnimationPaintProperties[record.Property]=true end
		if cancel and record.Property then local transition=self.Transitions[box];if transition and transition.Properties[record.Property]==record then
			transition.Properties[record.Property]=nil;transition.LayoutValues[record.Property]=nil;transition.IndividualValues[record.Property]=nil;transition.ColorValues[record.Property]=nil
			if not next(transition.Properties)then self.Transitions[box]=nil end
		end end
		publishLayout(box);if tree.ScriptAnimationPaint then tree.ScriptAnimationPaint:AfterLayout()end;updateConnection()
	end
	function self:SubscribeCSSRecords(callback)
		local key={};cssSubscribers[key]=callback
		return function()cssSubscribers[key]=nil end
	end
	tick=function()
		if not self.Alive or not page.Alive or tree.LayoutInProgress or tree.LayoutNeedsRecovery then return end
		if syncViewport then syncViewport() end
		local started=now();frameTime=started;local deadline=started+math.max(.00025,(budgetMS or 2)/1000);self.Frames+=1
		-- Resume after the last serviced job rather than restarting at a costly
		-- 3D animation every frame. Transitions share the same fair queue.
		local queue=self.WorkQueue
		for _=1,#queue do
			if #queue==0 then break end
			if self.NextWork>#queue then self.NextWork=1 end
			local index=self.NextWork;local job=queue[index];local worked=false
			local animation=job.Animation
			if animation then
				if not animation.Finished then worked=advanceAnimation(animation,started) end
			else
				local transition=self.Transitions[job.TransitionBox]
				if transition then advanceTransition(job.TransitionBox,transition,started);worked=true end
			end
			if (animation and animation.Finished) or (not animation and not self.Transitions[job.TransitionBox]) then table.remove(queue,index)
			else self.NextWork=index+1 end
			if worked and now()>=deadline then self.Dropped+=1;break end
		end
		if page.LazyMedia then page.LazyMedia:Check()end
		page.Root:SetAttribute("CSSAnimationFrames",self.Frames);page.Root:SetAttribute("CSSAnimationBudgetSkips",self.Dropped)
		publishLayouts()
		if tree.ScriptAnimationPaint then tree.ScriptAnimationPaint:AfterLayout()end
		updateConnection()
	end
	tree.MotionRuntime=self
	page:AddCleanup(function()
		self.Alive=false;if connection then connection:Disconnect();connection=nil end;tree.MotionRuntime=nil
		for _,connections in scrollConnections do for _,c in connections do c:Disconnect()end end;table.clear(scrollConnections)
		-- Releasing the final DOM-controlled transition queues its restoration
		-- after removing it from Transitions. Disposal has no next frame to drain
		-- that queue, so restore its owned author bases before clearing the queue.
		local restore=table.clone(self.RestoreBoxes)
		for box in self.AnimationRecords do restore[box]=true end
		for box in self.Transitions do restore[box]=true end
		for box in restore do
			box.CSSAnimationLayoutProperties=nil;box.CSSAnimationLayoutChanged=nil;box.CSSAnimationPaintProperties=nil;box.CSSAnimationColorProperties=nil;box.CSSAnimationColorChanged=nil
			box.SampledIndividualTransforms=nil;box.SampledTransformPropertyOperations=nil;box.AnimationTransformContainingBlock=nil
			AnimationValues.write(box,{},{},nil,nil,metricPublisher(page,tree));publishColors(page,tree,box,{},{});publishShadows(page,tree,box,{},{})
		end
		for box in knownBoxes do box.CSSAnimationTransformEffects=nil;if not box.HasScriptTransformEffects then box.AnimationTransformContainingBlock=nil end end
		table.clear(self.Transitions);table.clear(self.CompletedTransitions);table.clear(self.OwnedCSSRecords);table.clear(self.Animations);table.clear(self.FilledAnimations);table.clear(self.AnimationRecords);table.clear(self.RestoreBoxes);table.clear(self.WorkQueue);table.clear(self.Snapshots);table.clear(self.Pending)
		table.clear(knownBoxes)
		table.clear(cssSubscribers)
	end)
	return self
end

-- Script effects share the existing paint primitives and current box geometry.
-- They never mutate author declarations, replace native controls, or own a
-- frame connection. Their caller schedules timing and publication.
function HTMLAnimations.scriptAdapter(page: any,tree: any,diagnostic: ((string)->())?): any
	local self={Alive=true};local nodes,states={},{};local order=0
	local metricBoxes,colorBoxes,shadowBoxes={},{},{}
	tree.ScriptAnimationPaint=self
 local supported={transform=true,translate=true,rotate=true,scale=true,["offset-distance"]=true,opacity=true,["background-color"]=true,['border-radius']=true,['border-width']=true}
 local SCRIPT_PROPERTIES=table.clone(PROPERTIES);for name in AnimationValues.Properties do supported[name]=true;table.insert(SCRIPT_PROPERTIES,name)end
 for name in AnimationColors.Properties do supported[name]=true end;supported['border-color']=true
 local shorthands={margin={'margin-top','margin-right','margin-bottom','margin-left'},padding={'padding-top','padding-right','padding-bottom','padding-left'},inset={'top','right','bottom','left'},gap={'row-gap','column-gap'},flex={'flex-grow','flex-shrink','flex-basis'},['border-width']={},['border-radius']={},['border-color']={}}
 for name,spec in AnimationValues.Properties do if spec.BorderSide then table.insert(shorthands['border-width'],name)elseif spec.Corner then table.insert(shorthands['border-radius'],name)end end
 for name,spec in AnimationColors.Properties do if spec.Side then table.insert(shorthands['border-color'],name)end end
 for name in shorthands do supported[name]=true end
 local fields={Transform="transform",Translate="translate",Rotate="rotate",Scale="scale",OffsetDistance="offset-distance",Opacity="opacity",Background="background-color"}
 for field,name in AnimationValues.Fields do fields[field]=name end
 local function transformProperty(operations,box)
  local result=Transform2D.resolve(operations or{},box.OuterWidth or 0,box.OuterHeight or 0);result.PropertyOperations=operations or{};return result
 end
 local function scriptBase(property,box)
  if AnimationValues.Properties[property]then
   if box.CSSAnimationLayoutChanged and box.CSSAnimationLayoutChanged[property]then return box.CSSAnimationLayoutProperties[property]end
   return AnimationValues.base(box,property)
  end
  if property=='transform'then return transformProperty(box.Style.Transform,box)end
  return baseValue(property,box)
 end
 local function sampleCSS(node,box,properties,targeted,liveSample,beforeRecord)
  if not tree.MotionRuntime or not tree.MotionRuntime.SampleUnderlying then return true,nil end
  local ok,message=tree.MotionRuntime:SampleUnderlying(node,properties,targeted,liveSample,beforeRecord)
  properties.transform=transformProperty(properties.transform.PropertyOperations or properties.transform.Operations,box)
  return ok,message
 end
	local importantCache=setmetatable({},{__mode="kv"})
	local definitions=setmetatable({},{__mode="kv"})
	local function importantProperties(node: any,box: any): any
		local old=importantCache[node];local source=node.Attributes.style or ""
		local revision=tree.AnimationStyleRevision
		if revision~=nil and old and old.Revision==revision and old.Style==box.Style and old.Source==source then return old.Properties end
		local result={};local author=if tree.AnimationDeclarations then tree:AnimationDeclarations(node)else {Important={}}
		for _,entries in {author.Important,InlineStyle.compile(source).Important}do for _,entry in entries do
			local property=fields[entry.Field]or fields[entry.VariableProperty and (Individuals.Fields[entry.VariableProperty]or ({transform="Transform",["offset-distance"]="OffsetDistance",opacity="Opacity",["background-color"]="Background",background="Background"})[entry.VariableProperty])]
			if property and not entry.Error and not AnimationValues.Fields[entry.Field]then result[property]=true end
   if not entry.Error then for name,spec in AnimationValues.Properties do if AnimationValues.matches(spec,entry,name)then result[name]=true end end end
   if not entry.Error then for name in AnimationColors.Properties do if AnimationColors.matches(entry,name)then result[name]=true end end end
		end end
		importantCache[node]={Revision=revision,Style=box.Style,Source=source,Properties=result};return result
	end
	function self:Validate(node: any,frames: any,composite: string): (boolean,string?)
		local box=node and BoxTransform.node(tree,node)
		if node and not box and not (tree.NodeStyles[node]and tree.NodeStyles[node].Hidden)then
			-- Detached/new targets may obtain a box on the next publication.
			if node.Parent and tree.NodeStyles[node]then return false,"Script animation of inline fragments is not supported"end
		end
		for _,frame in frames do
			for property in frame.Values do
				if box and box.Kind=='InlineImage'and property~='transform'and property~='opacity'and not Individuals.Fields[property]then
					return false,"Script animation of inline replaced surfaces supports only transform, translate, rotate, scale and opacity"
				end
				if not supported[property]then return false,"Script animation property is not supported: "..property end
			end
		end;return true,nil
	end
 local function opacityNumber(source:string):number?
  local percent=tonumber(source:match('^%s*(.-)%%%s*$')or'');local value=tonumber(source)or(percent and percent/100)
  return if value and value==value and math.abs(value)~=math.huge then value else nil
 end
 local function frameText(property,value,entries)
  if not ({margin=true,padding=true,inset=true,gap=true,flex=true})[property]then return value end
  local entry=entries.Normal[1];if not entry then return value end
  if entry.Wide then return entry.Wide end
  if entry.VariableProperty then return value:match('^%s*(.-)%s*$')end
  local parts,index={},1
  while index<=#value do local part,after=Syntax.scan(value,index,' \t\r\n\f');index=after;if part~=''then table.insert(parts,part)end end
  local function lengthText(part)
   local n,unit=part:match('^([+%-]?%d*%.?%d+)([%a%%]*)$')
   if n then return tostring(tonumber(n))..(if unit==''then'px'else unit:lower())end
   if part:lower():match('^calc%(')and not entry.Relative then
    local parsed=InlineStyle.length(part,nil,true)
    if parsed then local text=LengthExpression.serialize(parsed)
     if text then return text:gsub('calc%(%((.-)%)%)','calc(%1)')end
     return 'calc('..tostring(parsed.Value)..(if parsed.Percent then'%'else'px')..')'
    end
   end
   return if part:find('(',1,true)then part else part:lower()
  end
  if property=='flex'then
   local parsed=entry.Value;local basis
   for i,part in parts do if tonumber(part)==nil or #parts==3 and i==3 then basis=lengthText(part)end end
   if value:match('^%s*[Aa][Uu][Tt][Oo]%s*$')or value:match('^%s*[Nn][Oo][Nn][Ee]%s*$')then basis='auto'end
   return tostring(parsed.Grow)..' '..tostring(parsed.Shrink)..' '..(basis or'0%')
  end
  for i,part in parts do parts[i]=lengthText(part)end
  if #parts==4 and parts[4]==parts[2]then table.remove(parts,4)end
  if #parts==3 and parts[3]==parts[1]then table.remove(parts,3)end
  if #parts==2 and parts[2]==parts[1]then table.remove(parts,2)end
  return table.concat(parts,' ')
 end
 function self:NormalizeFrames(frames:any):any
  for _,frame in frames do
   frame.ParsedValues={}
   for property,value in frame.Values do if supported[property]then
    -- A keyframe value is one CSS value, never a declaration list or an
    -- important author declaration. Invalid values leave their offset intact.
    local _,_,delimiter=Syntax.scan(value,1,';!{}')
    local entries=if delimiter==''then InlineStyle.compile(property..':'..value)else {Normal={}}
    local valid=false;for _,entry in entries.Normal do if not entry.Error then valid=true end end
    if valid or value==''then frame.ParsedValues[property]=entries;frame.Values[property]=frameText(property,value,entries)else frame.Values[property]=nil;frame.Names[property]=nil end
   end end
  end
  return frames
 end
	local function compile(frames: any): any
		if definitions[frames]then return definitions[frames]end
		local result={Frames={},Targeted={}}
		for _,frame in frames do
			local entries={Normal={},Important={}};local sources={};local names={}
   for property in frame.Values do if supported[property]then table.insert(names,property)end end
   -- Computing keyframes gives a longhand priority over its shorthand. Lua
   -- table iteration must not decide which side/color/radius wins.
   table.sort(names,function(a,b)local ac,bc=#(shorthands[a]or{a}),#(shorthands[b]or{b});return if ac~=bc then ac>bc else a<b end)
			for _,property in names do local value=frame.Values[property]
				local declarations=frame.ParsedValues and frame.ParsedValues[property]or InlineStyle.compile(property..":"..value)
				local valid=false
				for _,entry in declarations.Normal do
     if property=='opacity'and not entry.Error then
      local raw=opacityNumber(value)
      if raw then entry=table.clone(entry);entry.Value=raw end
     end
					table.insert(entries.Normal,entry);valid=valid or not entry.Error
    end
    if valid then local source={Property=property,Value=value,Variable=Syntax.findFunction(value,1,'var')~=nil};for _,name in shorthands[property]or{property}do result.Targeted[name]=true;sources[name]=source end end
			end
   table.insert(result.Frames,{Offset=frame.ComputedOffset,Easing=frame.Easing,Composite=frame.Composite,Declarations=entries,Raw=frame.Values,Sources=sources,Neutral=frame.Neutral})
		end;definitions[frames]=result;return result
	end
	function self:TargetedProperties(frames:any):any return compile(frames).Targeted end
	local function values(definition: any,property: string,box: any,underlying: any): any
		local result={}
		for _,frame in definition.Frames do
			if frame.Neutral and frame.Neutral[property]then table.insert(result,{Offset=frame.Offset,Value=underlying,Easing=frame.Easing,Composite='replace',Underlying=true});continue end
			local resolved=frame
			local origin=frame.Sources and frame.Sources[property];local sourceProperty=origin and origin.Property or property
			local raw=origin and origin.Value or frame.Raw and frame.Raw[property]
			local contextual=sourceProperty~=property
   local layoutSpec=AnimationValues.Properties[property]
   for _,entry in frame.Declarations.Normal do if not entry.Error and(entry.VariableProperty==property or(fields[entry.Field]==property or layoutSpec and AnimationValues.matches(layoutSpec,entry,property))and(entry.Relative or entry.Wide or(property=="background-color"and type(entry.Value)=="table"and entry.Value.Color=="currentcolor")))then contextual=true;break end end
			if raw and contextual and property~='font-size'and property~='line-height'and(not AnimationColors.Properties[property]or sourceProperty~=property)then
				local variable=origin and origin.Variable or Syntax.findFunction(raw,1,'var')~=nil
				local source=Variables.substitute(raw,box.Style.Custom)or(if variable then'unset'else nil)
				if source then
						-- Resolve em/viewport lengths, currentColor and CSS-wide values
						-- in the live target context rather than freezing keyframe text.
						frame.ContextCache=frame.ContextCache or setmetatable({},{__mode="kv"})
						local cache=frame.ContextCache[box.Style]or {};frame.ContextCache[box.Style]=cache
						local record=cache[sourceProperty];local revision=tree.AnimationStyleRevision
						local style=if revision~=nil and record and record.Revision==revision and record.Source==source and record.Size==box.Style.FontSize and record.RootSize==box.Style.RootFontSize and record.ViewportWidth==box.Style.ViewportWidth and record.ViewportHeight==box.Style.ViewportHeight then record.Style else nil
						if style==nil then
       local _,_,delimiter=Syntax.scan(source,1,';!{}')
       local entries=if delimiter==''then InlineStyle.compile(sourceProperty..":"..source)else {Normal={}}
       local valid=false;for _,entry in entries.Normal do if not entry.Error then valid=true end end
       if not valid and variable then entries=InlineStyle.compile(sourceProperty..':unset');valid=true end
							local fake={Name=box.Node and box.Node.Name or "div",Attributes={},Parent=nil,Kind="Element"}
							local context=box.Style
							if source:match("^%s*inherit%s*$")and box.Node and box.Node.Parent then context=tree.NodeStyles[box.Node.Parent]or box.Style end
							style=if valid then InlineStyle.resolve(fake,context,function()end,false,entries)else false;cache[sourceProperty]={Revision=revision,Source=source,Size=box.Style.FontSize,RootSize=box.Style.RootFontSize,ViewportWidth=box.Style.ViewportWidth,ViewportHeight=box.Style.ViewportHeight,Style=style}
						end
      if style then
						local parsed
      if layoutSpec then parsed=AnimationValues.fromStyle(style,property)
      elseif AnimationColors.Properties[property]then parsed=AnimationColors.fromStyle(style,property)
      elseif Individuals.Fields[property]then parsed=Individuals.fromStyle(style,property)
      elseif property=="transform"then parsed=transformProperty(style.Transform,box)
						elseif property=="offset-distance"then parsed={Distance=style.OffsetDistance}
						elseif property=="opacity"then parsed=opacityNumber(source)or style.Opacity
						else parsed={Color=style.Background or Color3.new(0,0,0),Alpha=if style.Background then style.BackgroundAlpha or 1 else 0}end
      table.insert(result,{Offset=frame.Offset,Value=parsed,Easing=frame.Easing,Composite=frame.Composite});continue
						end
				end
				continue
			end
   local value
   if AnimationColors.Properties[property]then
    local parent=box.Node and(ShadowTree.FlatParent(box.Node)or box.Node.Parent);value=frameValue(resolved,property,box,parent and tree.NodeStyles[parent])
   elseif property=='font-size'or property=='line-height'then
    local parent=box.Node and(ShadowTree.FlatParent(box.Node)or box.Node.Parent);value=frameValue(resolved,property,box,parent and tree.NodeStyles[parent])
   elseif layoutSpec and(layoutSpec.Corner or layoutSpec.BorderSide or layoutSpec.Field=='Gap')then value=frameValue(resolved,property,box)
   elseif layoutSpec then
    for _,entry in frame.Declarations.Normal do if not entry.Error and AnimationValues.matches(layoutSpec,entry,property) then value=entry.Value;if value==nil then value={Auto=true}end end end
   elseif property=='transform'then local transform=declaration(resolved,'Transform');if transform then value=transformProperty(transform,box)end
   else value=frameValue(resolved,property,box)end
   if value~=nil then table.insert(result,{Offset=frame.Offset,Value=value,Easing=frame.Easing,Composite=frame.Composite})end
		end
		if #result==0 then return result end
  if result[1].Offset>0 then table.insert(result,1,{Offset=0,Value=underlying,Easing="linear",Composite="replace",Underlying=true})end
  if result[#result].Offset<1 then table.insert(result,{Offset=1,Value=underlying,Easing="linear",Composite="replace",Underlying=true})end
		return result
	end
	local function sample(stops: any,progress: number,before: boolean): (any,any,number)
  if #stops==1 then return stops[1].Value,stops[1].Value,0,stops[1],stops[1] end
		local index=1
		for i=1,#stops-1 do if stops[i].Offset<=progress then index=i else break end end
		if progress>=stops[#stops].Offset then index=#stops-1 end
		local a,b=stops[index],stops[index+1];local t=if a.Offset==b.Offset then 1 else (progress-a.Offset)/(b.Offset-a.Offset)
  return a.Value,b.Value,Motion.ease(a.Easing,t,before),a,b
	end
	local function mixedLength(a: any,b: any,t: number,basis: number): any
		local function linear(v: any): (number,number)
			if not v then return 0,0 end
			if v.Kind=="length"and v.Op=="linear"then return v.Pixels,v.PercentValue end
   if v.Expression and v.Expression.Op=='linear'then return v.Expression.Pixels,v.Expression.PercentValue end
			if v.Value~=nil then return if v.Percent then 0 else v.Value,if v.Percent then v.Value else 0 end
			return LengthExpression.resolve(v,basis),0
		end
		local ap,ar=linear(a);local bp,br=linear(b);local pixels,percent=lerp(ap,bp,t),lerp(ar,br,t)
		if pixels==0 or percent==0 then return {Value=if percent~=0 then percent else pixels,Percent=percent~=0}end
		return LengthExpression.linear(pixels,percent)
	end
 local function mixed(property: string,a: any,b: any,t: number,box: any,interpolateSize: string?): any
  if AnimationColors.Properties[property]then return AnimationColors.mix(a,b,t)
  elseif AnimationValues.Properties[property]then return AnimationValues.mix(a,b,t,box,property,interpolateSize)
  elseif Individuals.Fields[property]then return Individuals.mix(property,a,b,t,AnimationValues.mix,box)
  elseif property=="transform"then
			local result=interpolated(a,b,t,box)
			-- Matching translation functions retain computed percentages. A
			-- matrix fallback resolves their reference box at commit time.
			for index,op in result.Operations or {}do
				local left,right=(a.Operations or {})[index],(b.Operations or {})[index]
				if op.Kind=="translate"and(not left or left.Kind=="translate")and(not right or right.Kind=="translate")then
					left=left or {};right=right or {};op.X=mixedLength(left.X,right.X,t,box.OuterWidth or 0);op.Y=mixedLength(left.Y,right.Y,t,box.OuterHeight or 0);op.Z=mixedLength(left.Z,right.Z,t,0)
				end
			end
   return if result.Operations then transformProperty(result.Operations,box)else result
		elseif property=="offset-distance"then return {Distance=mixedLength(a.Distance,b.Distance,t,BoxTransform.pathDistance(box,{Value=100,Percent=true}))}
		elseif property=="opacity"then return lerp(a,b,t)
		else return premultiplied(a,b,t)end
	end
 local function compose(property,underlying,value,mode,box,count,interpolateSize)
  if mode=="replace"then return value end;count=count or 1
  if count~=count or math.abs(count)==math.huge then return underlying end
  if AnimationColors.Properties[property]then return AnimationColors.add(underlying,value,count)
  elseif AnimationValues.Properties[property]then return AnimationValues.add(underlying,value,box,count,property,interpolateSize,mode)
  elseif Individuals.Fields[property]then return Individuals.compose(property,underlying,value,count,AnimationValues.add,box)
  elseif property=="opacity"then return underlying+value*count
  elseif property=="offset-distance"then return {Distance=AnimationValues.add(underlying.Distance,value.Distance,box,count)}
  elseif property=="transform"then
   local a,b=underlying.Operations or {},value.Operations or {}
   local ops=Transform2D.compose(a,b,mode,box.OuterWidth or 0,box.OuterHeight or 0,count)
   return transformProperty(ops,box)
  end
  return value
 end
 local function applyStack(box: any,group: any,properties: any,changed: any,ignored: any?,restoreIgnored: boolean?)
		for _,state in group do
			local timing=state.Timing;if not timing or type(timing.progress)~="number"then continue end
   for _,property in SCRIPT_PROPERTIES do
				local list=values(state.Definition,property,box,properties[property]);if #list==0 then continue end
				if ignored and ignored[property]then
					-- A valid script effect raises this property's final stack to the
					-- Animation origin even if an important author value suppresses
					-- it. Other properties keep their own transition-origin value.
					if restoreIgnored then changed[property]=true;properties[property]=baseValue(property,box)end
					continue
				end
    local a,b,t,left,right=sample(list,timing.progress,timing.Phase=="before")
    if state.IterationComposite=="accumulate"and type(timing.currentIteration)=="number"and timing.currentIteration>0 then
     local final=list[#list].Value;a=compose(property,a,final,"accumulate",box,timing.currentIteration,state.InterpolateSize);b=compose(property,b,final,"accumulate",box,timing.currentIteration,state.InterpolateSize)
    end
    local leftMode=if left.Composite=="auto"or left.Composite==nil then state.Composite or "replace"else left.Composite
    local rightMode=if right.Composite=="auto"or right.Composite==nil then state.Composite or "replace"else right.Composite
    a=compose(property,properties[property],a,leftMode,box,nil,state.InterpolateSize);b=compose(property,properties[property],b,rightMode,box,nil,state.InterpolateSize)
    changed[property]=true;properties[property]=mixed(property,a,b,t,box,state.InterpolateSize)
			end
		end
	end
	local function numberText(value: number): string
		if math.abs(value)<.0000005 then value=0 end
		return (string.format("%.6f",value):gsub("0+$",""):gsub("%.$",""))
	end
	local function lengthText(value: any): string
		if not value then return "0px"end
  if value.Expression and value.Expression.Op=='linear'then value=value.Expression end
		if value.Kind=="length"and value.Op=="linear"then
			local px,pct=value.Pixels,value.PercentValue
			if pct==0 then return numberText(px).."px"elseif px==0 then return numberText(pct).."%"end
			return "calc("..numberText(pct).."% "..(if px<0 then "- "else "+ ")..numberText(math.abs(px)).."px)"
		end
		return numberText(if value.Value~=nil then value.Value else LengthExpression.resolve(value,0))..(if value.Percent then "%"else "px")
	end
	local function transformText(operations: any,box: any,names: any?): string
		local result={}
		for index,op in operations or {}do
			local name,args
			if op.Kind=="translate"then
				if names and names[index]=='translatex'then name,args='translateX',{lengthText(op.X)}
				elseif names and names[index]=='translatey'then name,args='translateY',{lengthText(op.Y)}
				elseif names and names[index]=='translatez'then name,args='translateZ',{lengthText(op.Z)}
				elseif op.Z and LengthExpression.resolve(op.Z,0)~=0 or names and names[index]=='translate3d'then name,args="translate3d",{lengthText(op.X),lengthText(op.Y),lengthText(op.Z)}
				else name,args="translate",{lengthText(op.X)};local y=lengthText(op.Y);if y~="0px"and y~="0%"then table.insert(args,y)end end
			elseif op.Kind=="scale"then
				if names and names[index]=='scalex'then name,args='scaleX',{numberText(op.Value)}
				elseif names and names[index]=='scaley'then name,args='scaleY',{numberText(op.Y or op.Value)}
				elseif names and names[index]=='scalez'then name,args='scaleZ',{numberText(op.Z or 1)}
				elseif (op.Z or 1)~=1 or names and names[index]=='scale3d'then name,args="scale3d",{numberText(op.Value),numberText(op.Y or op.Value),numberText(op.Z or 1)}
				else name,args="scale",{numberText(op.Value)};if (op.Y or op.Value)~=op.Value then table.insert(args,numberText(op.Y))end end
			elseif op.Kind=="rotate"then name,args=if names and names[index]=='rotatez'then'rotateZ'else'rotate',{numberText(op.Value).."deg"}
			elseif op.Kind=="tilt"then name,args=if op.Axis=="x"then "rotateX"else "rotateY",{numberText(op.Value).."deg"}
			elseif op.Kind=="rotate3d"then name,args="rotate3d",{numberText(op.X),numberText(op.Y),numberText(op.Z),numberText(op.Value).."deg"}
			elseif op.Kind=="skew"then
				if names and names[index]=='skewx'then name,args='skewX',{numberText(op.X)..'deg'}
				elseif names and names[index]=='skewy'then name,args='skewY',{numberText(op.Y)..'deg'}
				else name,args="skew",{numberText(op.X).."deg",numberText(op.Y).."deg"}end
			elseif op.Kind=="perspective"then name,args="perspective",{if op.Value==math.huge then "none"else numberText(op.Value).."px"}
			elseif op.Kind=="matrix"then
				local m=op.Values;local flat=m[3]==0 and m[4]==0 and m[7]==0 and m[8]==0 and m[9]==0 and m[10]==0 and m[11]==1 and m[12]==0 and m[15]==0 and m[16]==1
				if names and names[index]=='matrix3d'then flat=false end
				name,args=if flat then "matrix"else "matrix3d",{}
				for _,n in if flat then {m[1],m[2],m[5],m[6],m[13],m[14]}else m do table.insert(args,numberText(n))end
			end
			if name then table.insert(result,name.."("..table.concat(args,", ")..")")end
		end
		return if #result==0 then "none"else table.concat(result," ")
	end
	local function cssValueText(property,value,box)
		if AnimationValues.Properties[property]then return AnimationValues.serialize(value,property,box)
		elseif Individuals.Fields[property]then return Individuals.serialize(property,value)
		elseif property=='transform'then
			local operations=value.PropertyOperations or value.Operations
			-- Read function forms from the parsed winning value. Raw source can
			-- end in an invalid declaration or still contain an unresolved var().
			local names={};for index,op in operations or{}do names[index]=op.FunctionName end
			return transformText(operations,box,names)
		elseif property=='offset-distance'then return lengthText(value.Distance)
		elseif property=='opacity'then return numberText(value)
		elseif AnimationColors.Properties[property]then
			local parent=box.Node and(ShadowTree.FlatParent(box.Node)or box.Node.Parent);local parentStyle=parent and tree.NodeStyles[parent]or box.Style
			local foreground={Color=box.Style.Color,Alpha=box.Style.ColorAlpha or 1}
			value=AnimationColors.resolve(value,if property=='color'then {Color=parentStyle.Color,Alpha=parentStyle.ColorAlpha or 1}else foreground)
			local c=value.Color;local rgb={tostring(math.floor(c.R*255+.5)),tostring(math.floor(c.G*255+.5)),tostring(math.floor(c.B*255+.5))}
			return if value.Alpha==1 then'rgb('..table.concat(rgb,', ')..')'else'rgba('..table.concat(rgb,', ')..', '..numberText(value.Alpha)..')'
		end
		return nil
	end
	function self:GetCSSRecords()
		local motion=tree.MotionRuntime;if not motion then return{}end
		local result={}
		for _,entry in motion:GetCSSRecords()do
			local record=entry.Record;local box=record.Box
			if entry.Kind=='transition'and not supported[entry.Property]then continue end
			local exportDefinition=record.ProcessedDefinition or record.Definition
			local changed=record.ExportDefinition~=exportDefinition or record.ExportStyle~=box.Style or record.ExportRevision~=tree.AnimationStyleRevision
				or record.ExportFont~=box.Style.FontSize or record.ExportWidth~=box.OuterWidth or record.ExportHeight~=box.OuterHeight or record.ExportCurve~=record.Timing
			if not record.ExportFrames or changed then
				local frames={}
				if entry.Kind=='animation'then
					local parent=box.Node and(ShadowTree.FlatParent(box.Node)or box.Node.Parent);local parentStyle=parent and tree.NodeStyles[parent]
					for _,frame in exportDefinition.Frames do
						local values,names={},{}
						for _,property in SCRIPT_PROPERTIES do
							local value=frameValue(frame,property,box,parentStyle)
								if value~=nil then local source=cssValueText(property,value,box);if source then values[property]=source;names[property]=property:gsub('%-(.)',string.upper)end end
						end
						table.insert(frames,{Offset=frame.Offset,ComputedOffset=frame.Offset,Easing=frame.Easing or Motion.serializeEasing(record.Timing),Composite=frame.Composite or'auto',Values=values,Names=names,Order=frame.Order})
					end
					local targeted={};for _,frame in frames do for property in frame.Values do targeted[property]=true end end
					for _,offset in{0,1}do
						local endpoint;local defaultCurve=Motion.serializeEasing(record.Timing)
						for _,frame in frames do if frame.Offset==offset and frame.Easing==defaultCurve and(frame.Composite=='auto'or frame.Composite=='replace')then endpoint=frame;break end end
						local generated=false
						if not endpoint then endpoint={Offset=offset,ComputedOffset=offset,Easing=defaultCurve,Composite='replace',Values={},Names={},Neutral={},Order=if offset==0 then-1 else math.huge};generated=true end
						for property in targeted do
							local present=false;for _,frame in frames do if frame.Offset==offset and frame.Values[property]~=nil then present=true;break end end
							if not present then endpoint.Neutral=endpoint.Neutral or{};endpoint.Neutral[property]=true;endpoint.Values[property]=cssValueText(property,baseValue(property,box),box);endpoint.Names[property]=property:gsub('%-(.)',string.upper)end
						end
						if generated and next(endpoint.Values)then table.insert(frames,endpoint)end
					end
					table.sort(frames,function(a,b)return if a.Offset==b.Offset then a.Order<b.Order else a.Offset<b.Offset end)
				else
					local property=entry.Property;local transition=record.Transition
					for index,pose in{record.Before or transition.Before,record.Target or transition.Target}do
						local value=if AnimationValues.Properties[property]or Individuals.Fields[property]then(if index==1 then record.From else record.To)elseif property=='opacity'then pose.Opacity elseif property=='transform'then{PropertyOperations=pose.TransformProperty}elseif property=='offset-distance'then{Distance=pose.Distance}else pose.Colors[property]
						local source=cssValueText(property,value,box)
						if source then table.insert(frames,{Offset=index-1,ComputedOffset=index-1,Easing='linear',Composite='auto',Values={[property]=source},Names={[property]=property:gsub('%-(.)',string.upper)}})end
					end
				end
				record.ExportFrames=frames;record.ExportDefinition=exportDefinition;record.ExportStyle=box.Style;record.ExportRevision=tree.AnimationStyleRevision;record.ExportFont=box.Style.FontSize;record.ExportWidth=box.OuterWidth;record.ExportHeight=box.OuterHeight;record.ExportCurve=record.Timing
			end
			entry.Frames=record.ExportFrames
			entry.Timing={duration=record.Duration*1000,delay=record.Delay*1000,endDelay=0,fill=if entry.Kind=='animation'then record.Fill else'backwards',iterations=if entry.Kind=='animation'then record.Iterations else 1,iterationStart=0,direction=if entry.Kind=='animation'then record.Direction else'normal',easing=if entry.Kind=='animation'then'linear'else record.Timing}
			entry.Play=if entry.Kind=='animation'then Motion.pick(box.Style.AnimationPlay,record.Index,'running')else'running'
			entry.CurrentTime=motion:CSSRecordTime(record);entry.Canceled=record.DOMCanceled==true
			entry.Composite=if entry.Kind=='animation'then record.Composition else'replace';entry.Name=record.Name
			table.insert(result,entry)
		end
		return result
	end
	function self:AcquireCSSRecord(record)if tree.MotionRuntime then tree.MotionRuntime:AcquireCSSRecord(record)end end
	function self:ApplyCSSRecord(record,frames,timing,animation,composite,iterationComposite)
		local motion=tree.MotionRuntime;if not motion or record.DOMCanceled or record.Removed then return end
		local box=record.Box;local properties={};for _,property in SCRIPT_PROPERTIES do properties[property]=baseValue(property,box)end
		if not record.Property then motion:SampleUnderlying(box.Node,properties,supported,false,record)end
		local changed={};applyStack(box,{{Definition=compile(frames),Timing=timing,Composite=composite,IterationComposite=iterationComposite,InterpolateSize=record.InterpolateSize or box.Style.InterpolateSize}},properties,changed,if record.Property then nil else importantProperties(box.Node,box))
		local values={};for property in changed do values[property]=properties[property]end
		motion:ApplyCSSRecord(record,values,timing)
	end
	function self:ReleaseCSSRecord(record,cancel)if tree.MotionRuntime then tree.MotionRuntime:ReleaseCSSRecord(record,cancel)end end
	function self:SubscribeCSSRecords(callback)
		return if tree.MotionRuntime then tree.MotionRuntime:SubscribeCSSRecords(callback)else function()end
	end
	function self:SampleCommit(node: any,stack: any,targeted: any): (any?,string?,string?)
		if not self.Alive or not page.Alive then return nil,"InvalidStateError","Animation target is not being rendered"end
		local current=node;while current and current.Kind~="Document"do
			local style=tree.NodeStyles[current]
			if style and(style.Hidden or style.Display=="none")then return nil,"InvalidStateError","Animation target is not being rendered"end
			current=ShadowTree.FlatParent(current) or (if current.Kind=='ShadowRoot'then current.Host else current.Parent)
		end
		if not current or not ShadowTree.Connected(node)or not tree.NodeStyles[node]then return nil,"InvalidStateError","Animation target is not being rendered"end
		local box=BoxTransform.node(tree,node)or {Style=tree.NodeStyles[node],Node=node,OuterWidth=0,OuterHeight=0}
  local requested=table.clone(targeted.Properties or targeted)
  for property,longhands in shorthands do if requested[property]then for _,name in longhands do requested[name]=true end end end
  local properties={};for _,property in SCRIPT_PROPERTIES do properties[property]=scriptBase(property,box)end
		local ignored=importantProperties(node,box)
		if tree.MotionRuntime and tree.MotionRuntime.SampleUnderlying then
			local ok,message=sampleCSS(node,box,properties,requested,true,targeted.BeforeRecord);if not ok then return nil,"NotSupportedError",message end
		end
  for property in ignored do properties[property]=scriptBase(property,box)end
  local group={};for _,item in stack do local state=states[item.Animation];table.insert(group,{Definition=compile(item.Frames),Timing=item.Timing,Composite=item.Composite,IterationComposite=item.IterationComposite,InterpolateSize=if state then state.InterpolateSize else box.Style.InterpolateSize})end
		applyStack(box,group,properties,{},ignored)
		-- Invalid values do not make their property an animation target. A
		-- valid but out-of-effect animation still commits its underlying value.
		local own=compile(targeted.Frames or {})
  local entries={};for _,property in SCRIPT_PROPERTIES do
			if not requested[property]or(targeted.Frames and not own.Targeted[property])then continue end
			local value=properties[property];local source
   if AnimationValues.Properties[property]then source=AnimationValues.serialize(value,property,box)
   elseif Individuals.Fields[property]then source=Individuals.serialize(property,value)
   elseif property=="transform"then source=transformText(value.Operations,box)
			elseif property=="offset-distance"then source=lengthText(value.Distance)
			elseif property=="opacity"then source=numberText(math.clamp(value,0,1))
			else
				local parent=node and(ShadowTree.FlatParent(node)or node.Parent);local parentStyle=parent and tree.NodeStyles[parent]or box.Style
				local foreground=AnimationColors.resolve(properties.color,{Color=parentStyle.Color,Alpha=parentStyle.ColorAlpha or 1})
				value=AnimationColors.resolve(value,if property=='color'then {Color=parentStyle.Color,Alpha=parentStyle.ColorAlpha or 1}else foreground)
				local c=value.Color;local rgb={tostring(math.floor(c.R*255+.5)),tostring(math.floor(c.G*255+.5)),tostring(math.floor(c.B*255+.5))}
				source=if value.Alpha==1 then "rgb("..table.concat(rgb,", ")..")"else "rgba("..table.concat(rgb,", ")..", "..numberText(value.Alpha)..")"
			end
			table.insert(entries,{Name=property,Value=source})
		end
		return entries,nil,nil
	end
	function self:PrepareCommit()
		if page.FlushScriptLayout then page:FlushScriptLayout()end
	end
	local function ensureOpacity(box: any)
		-- Script-created compositors participate in subsequent layout just like
		-- compositors discovered from author CSS during the initial build.
		tree.HasOpacity=true
		if box.OpacityGroup then return end
		box.OpacityGroup=GroupOpacity.create(box.Gui.Parent,box.Style.Opacity or 1,box.Factory)
		box.Gui.Parent=box.OpacityGroup.Content;box.TransformBaseX,box.TransformBaseY=nil,nil
		if box.Kind=='InlineImage'then
			local item=box.ImageItem;item.OpacityGroup=box.OpacityGroup
			box.Gui.Position=UDim2.fromOffset(item.Style.Margin[4],item.Style.Margin[1]);box.Gui.AnchorPoint=Vector2.new(0,0);box.Gui.Rotation=0
			if box.TransformScale then box.TransformScale.Parent=box.OpacityGroup.Gui;box.TransformScale.Scale=1 end
			BoxTransform.inline(item,box.Factory)
			return
		end
		-- Existing dirty-cache bounds predate this newly inserted compositing
		-- surface. Arrange from the retained geometry without reflowing children.
		local dirty=box.DirtyContext;box.DirtyContext=nil;GroupOpacity.arrange(box);box.DirtyContext=dirty
		box.TransformBaseX=component(box.OpacityGroup.Gui.Position,"X",1)-(box.ViewportOffsetX or 0)
		box.TransformBaseY=component(box.OpacityGroup.Gui.Position,"Y",2)-(box.ViewportOffsetY or 0)
	end
	local function paint(node: any,inheritedPublication: boolean?)
		local box=BoxTransform.node(tree,node);local group=nodes[node]
		local old=metricBoxes[node]
		if old and old~=box then if tree.RefreshAnimationMetrics then tree:RefreshAnimationMetrics(old,{})end;metricBoxes[node]=nil end
		local oldShadow=shadowBoxes[node]
		if oldShadow and oldShadow~=box then if tree.RefreshAnimationTextShadows then tree:RefreshAnimationTextShadows(oldShadow,nil)end;shadowBoxes[node]=nil end
		local oldColor=colorBoxes[node]
		if oldColor and oldColor~=box then if tree.RefreshAnimationColors then tree:RefreshAnimationColors(oldColor,{})end;colorBoxes[node]=nil end
		if not box or not box.Gui or tree.LayoutInProgress or tree.LayoutNeedsRecovery then return end
		local previousColor,previousAlpha,previousShadows=box.Style.Color,box.Style.ColorAlpha,box.Style.TextShadows
		local previousEmphasis,previousEmphasisAlpha=box.Style.TextEmphasisColor,box.Style.TextEmphasisColorAlpha
  local properties={};for _,property in SCRIPT_PROPERTIES do properties[property]=scriptBase(property,box)end
		local ignored=importantProperties(node,box)
		if group and tree.MotionRuntime and tree.MotionRuntime.SampleUnderlying then
			sampleCSS(node,box,properties,supported)
		end
		local changed={}
		if group then
			table.sort(group,function(a,b)return a.Order<b.Order end)
			applyStack(box,group,properties,changed,ignored,true)
		end
  box.HasScriptTransformEffects=false
  for _,state in group or{}do
   local timing=state.Timing
   if timing and(timing.IsCurrent or type(timing.progress)=='number')then
    local targeted=state.Definition.Targeted
    if targeted.transform or targeted.translate or targeted.rotate or targeted.scale then box.HasScriptTransformEffects=true;break end
   end
  end
  if changed.opacity then ensureOpacity(box)end
  box.HasScriptColorEffects=false;for property in changed do if AnimationColors.Properties[property]then box.HasScriptColorEffects=true;break end end
  for property in box.CSSAnimationColorChanged or{}do if not changed[property]then changed[property]=true;properties[property]=box.CSSAnimationColorProperties[property]end end
  box.HasScriptLayoutEffects=false;for property in changed do if AnimationValues.Properties[property]then box.HasScriptLayoutEffects=true;break end end
  for property in box.CSSAnimationLayoutChanged or{}do if not changed[property]then changed[property]=true;properties[property]=box.CSSAnimationLayoutProperties[property]end end
  AnimationValues.write(box,properties,changed,if page.RequestAnimationLayout then function(target)page:RequestAnimationLayout(target)end else nil,if tree.PaintAnimationDecorations then function(target)tree:PaintAnimationDecorations(target)end else nil,metricPublisher(page,tree))
  publishColors(page,tree,box,properties,changed)
  publishShadows(page,tree,box,properties,changed)
  shadowBoxes[node]=if box.AnimationTextShadowAuthor then box else nil
  colorBoxes[node]=if box.AnimationColorAuthor then box else nil
  if tree.MotionRuntime and tree.MotionRuntime.RestoreTransitionPaint then tree.MotionRuntime:RestoreTransitionPaint(box)end
  metricBoxes[node]=if box.AnimationMetricAuthor then box else nil
		-- Restore a property previously touched even when its final effect has
		-- just been removed, while preserving the current author style.
		local touched=box.ScriptAnimationProperties or {};for key in changed do touched[key]=true end;box.ScriptAnimationProperties=touched
		if touched.opacity and box.OpacityGroup then GroupOpacity.paint(box.OpacityGroup,box.Style,math.clamp(properties.opacity,0,1))end
		local transformOperations
		if touched['transform-origin']or touched.transform or touched["offset-distance"]or touched.translate or touched.rotate or touched.scale then
			if box.TransformBaseX==nil then local gui=BoxTransform.target(box);box.TransformBaseX=component(gui.Position,"X",1)-(box.ViewportOffsetX or 0);box.TransformBaseY=component(gui.Position,"Y",2)-(box.ViewportOffsetY or 0)end
			local individuals={};for property in Individuals.Fields do individuals[property]=properties[property]end
			box.SampledIndividualTransforms=individuals;box.SampledTransformPropertyOperations=properties.transform.Operations
			transformOperations=Individuals.operations(box.Style,individuals,properties.transform.Operations)
   local distance=if changed['offset-distance']then properties['offset-distance'].Distance else nil
   box.OffsetDistanceOverride=distance
   local transform=BoxTransform.resolve(box,transformOperations,distance)
			paintTransform(box,transform)
		end
  if transformOperations or box.HasScriptTransformEffects or box.AnimationTransformContainingBlock~=nil then
   if not transformOperations then local individuals={};for property in Individuals.Fields do individuals[property]=properties[property]end;transformOperations=Individuals.operations(box.Style,individuals,properties.transform.Operations)end
   sampledContainingBlock(box,transformOperations,tree,page)
  end
		if transformOperations and page.LazyMedia then page.LazyMedia:Check()end
		if not group or #group==0 then
			box.ScriptAnimationProperties=nil
			box.HasScriptTransformEffects=nil
			box.HasScriptColorEffects=nil
			box.SampledIndividualTransforms=nil;box.SampledTransformPropertyOperations=nil
			if tree.MotionRuntime and tree.MotionRuntime.PaintUnderlying then tree.MotionRuntime:PaintUnderlying(node)end
			if not box.CSSAnimationTransformEffects and not box.CSSAnimationPaintProperties and not(tree.MotionRuntime and tree.MotionRuntime.Transitions[box])then box.AnimationTransformContainingBlock=nil end
		end
		if not inheritedPublication and(previousColor~=box.Style.Color or previousAlpha~=box.Style.ColorAlpha or previousShadows~=box.Style.TextShadows or previousEmphasis~=box.Style.TextEmphasisColor or previousEmphasisAlpha~=box.Style.TextEmphasisColorAlpha)then
			-- currentTime can change a parent's inherited color/shadows without a
			-- DOM batch or layout. Publish retained descendant effects immediately so
			-- a same-script computed read sees the new additive/inherited basis.
			local children={}
			for child in nodes do if child~=node then
				local ancestor=ShadowTree.FlatParent(child)or child.Parent;local depth=0
				while ancestor and ancestor~=node do depth+=1;ancestor=ShadowTree.FlatParent(ancestor)or ancestor.Parent end
				if ancestor then table.insert(children,{Node=child,Depth=depth})end
			end end
			table.sort(children,function(a,b)return a.Depth<b.Depth end)
			for _,entry in children do paint(entry.Node,true)end
		end
	end
 function self:Apply(node: any,frames: any,timing: any,animation: any,composite: string?,iterationComposite: string?)
		if not self.Alive or not page.Alive then return end
		local state=states[animation]
		if state and state.Node~=node then self:Release(state.Node,animation);state=nil end
		if not state then order+=1;local box=BoxTransform.node(tree,node);state={Node=node,Animation=animation,Order=animation.AnimationState and animation.AnimationState.Sequence or order,InterpolateSize=box and box.Style.InterpolateSize or'numeric-only'};states[animation]=state;nodes[node]=nodes[node]or {};table.insert(nodes[node],state)end
		if state.Frames~=frames then state.Frames=frames;state.Definition=compile(frames)end
  state.Timing=timing;state.Composite=composite;state.IterationComposite=iterationComposite;paint(node)
	end
	function self:Release(node: any,animation: any)
		local state=states[animation];if not state then return end;states[animation]=nil
		local group=nodes[state.Node];local index=group and table.find(group,state);if index then table.remove(group,index)end
		if group and #group==0 then nodes[state.Node]=nil end;paint(state.Node)
	end
	function self:AfterLayout()if not self.Alive then return end;for node in nodes do paint(node)end end
	function self:Destroy()
		if not self.Alive then return end
		local affected={};for node in nodes do table.insert(affected,node)end;table.clear(nodes);table.clear(states);table.clear(importantCache);table.clear(definitions)
		for _,node in affected do paint(node)end;table.clear(metricBoxes);table.clear(colorBoxes);table.clear(shadowBoxes);self.Alive=false;if tree.ScriptAnimationPaint==self then tree.ScriptAnimationPaint=nil end
	end
	return self
end

return HTMLAnimations
