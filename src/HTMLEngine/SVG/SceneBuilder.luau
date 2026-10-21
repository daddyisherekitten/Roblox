--!strict
-- Shared SVG scene builder for the standalone lab and embedded HTML viewports.
local WorkContext=require(script.Parent.Parent.WorkContext)
return function(Parser: any,Viewport: any,Sources: any,Raster: any,Lengths: any?,Geometries: any?,Paints: any?,Transforms: any?,Bounds: any?,Rendering: any?,Documents: any?,Gradients: any?,Resources: any?,Text: any?): any
 local viewportWidth,viewportHeight=Sources.Width or 480,Sources.Height or 320
	local data={Stage=Sources.Stage or if Paints then "S07" elseif Geometries then "S06" elseif Lengths then "S05" else "S04",Title=Sources.Title or if Paints then "S07 · Füllung und Kontur" elseif Geometries then "S06 · SVG-Grundformen" elseif Lengths then "S05 · Längen und Prozentbezüge" else "S04 · viewBox und Viewports",Scenes={},Glyphs={},Diagnostics={},SourceSHA256=Sources.SourceSHA256,Render=Raster.render}
	local function length(text: string?,basis: number,default: number): number
		if text==nil then return default end
		local percent=text:match("^([+%-]?[%d%.]+)%%$")
		local value=if percent then tonumber(percent)*basis/100 else tonumber(text)
		assert(value and value==value and math.abs(value)<math.huge,"S04 probe requires numeric/percent viewport lengths")
		return value
	end
	for _,source in Sources.Cases do
		local scene={Name=source.Name,Width=viewportWidth,Height=viewportHeight,Shapes={},Nodes={},Probes=source.Probes,Caption=source.Caption}
		if Rendering then scene.RenderTree={} end
		local doc=source.Document or Parser.parse(source.SVG);assert(doc.Valid,"Invalid SVG fixture")
		if Documents then
			doc=Documents.prepare(doc,{RootSize=if Sources.EmbeddedSize then {Width=viewportWidth,Height=viewportHeight} else nil,Width=viewportWidth,Height=viewportHeight,URL=source.Name..'.svg',CSS=source.CSS,States=Sources.States,Animated=Sources.Animated,Fragment=source.Fragment,Languages=source.Languages or Sources.Languages,Features=Sources.Features,Extensions=Sources.Extensions,ResolveImage=Sources.ResolveImage,Resolve=function(url) return Sources.Documents and Sources.Documents[url] end})
		end
  -- Bounds, gradients and painting can all ask for the same text outlines.
  -- These nodes are immutable within this prepared document; viewport/font inputs
  -- still distinguish resource instances laid out in different coordinate systems.
  local textExpansions={}
  local function expandText(node,context)
   local entries=textExpansions[node]
   for _,entry in entries or {} do
    if entry.Width==context.Width and entry.Height==context.Height and entry.FontSize==context.FontSize and entry.RootFontSize==context.RootFontSize then return entry.Node end
   end
   local expanded=Text.expand(node,context,function(code,value) table.insert(data.Diagnostics,{Case=source.Name,Code=code,Value=value}) end,Sources.ResolveFont)
   if not entries then entries={};textExpansions[node]=entries end
   table.insert(entries,{Width=context.Width,Height=context.Height,FontSize=context.FontSize,RootFontSize=context.RootFontSize,Node=expanded})
   return expanded
  end
  local referenceBoxes={}
  local function sameContext(a,b)
   for key,value in a do if b[key]~=value then return false end end
   for key,value in b do if a[key]~=value then return false end end
   return true
  end
  local function referenceBox(node,context,paint,stroke)
   local entries=referenceBoxes[node]
   for _,entry in entries or {} do
    if entry.Paint==paint and entry.Stroke==stroke and sameContext(entry.Context,context) then return entry.Box end
   end
   local box=Bounds.reference(node,context,paint,stroke)
   if not entries then entries={};referenceBoxes[node]=entries end
   if #entries<32 then table.insert(entries,{Context=table.clone(context),Paint=paint,Stroke=stroke,Box=box}) end
   return box
  end
		local visit
  local resources
  if Resources then
   resources=Resources.new(doc,function(root,state,w,h,contextPaint)
    local saved=scene
    scene={Width=w or saved.Width,Height=h or saved.Height,Shapes={},Nodes={},RenderTree={}}
    visit(root,state,nil,nil,nil,nil,scene.RenderTree,contextPaint)
    local result=scene;scene=saved;return result
   end,function(code,value) table.insert(data.Diagnostics,{Case=source.Name,Code=code,Value=value}) end)
  end
  visit=function(node: any,parent: any?,isRoot: boolean?,inheritedFont: any?,inheritedPaint: any?,inheritedRendering: any?,target: any?,contextPaint: any?)
   WorkContext.checkpoint()
			if node.Kind~="Element" or node.NamespaceURI~=Parser.Namespace then return end
   if node.Name=='foreignObject' then table.insert(data.Diagnostics,{Case=source.Name,Code='foreign-object-raster-bridge-unavailable',Value=node.Attributes.id});return end
			if Text and node.Name=='text' then
    local ctx={Document=doc,Width=if parent then parent.UserWidth else viewportWidth,Height=if parent then parent.UserHeight else viewportHeight,FontSize=if inheritedFont then inheritedFont.FontSize else 16,RootFontSize=if inheritedFont then inheritedFont.RootFontSize else 16}
    local expanded=expandText(node,ctx)
    visit(expanded,parent,isRoot,inheritedFont,inheritedPaint,inheritedRendering,target,contextPaint);return
   end
			local a=node.Attributes
			local rendering
   local group
			if Rendering then
				local problems;rendering,problems=Rendering.resolve(a,inheritedRendering,node.Name=='svg' and not isRoot)
				for _,problem in problems do table.insert(data.Diagnostics,{Case=source.Name,Element=a.id,Code=problem.Code,Attribute=problem.Attribute,Value=problem.Value}) end
				if rendering.Display=='none' then return end
				target=target or scene.RenderTree
				if node.Name=='g' or node.Name=='a' or node.Name=='svg' then
					group={Children={},Opacity=rendering.Opacity,BlendMode=rendering.BlendMode,Isolation=rendering.Isolation};table.insert(target,group);target=group.Children
				end
			end
			local font=inheritedFont or {FontSize=16,RootFontSize=16}
			local context=table.clone(font)
			context.Document=doc
			context.Width=if parent then parent.UserWidth else viewportWidth
			context.Height=if parent then parent.UserHeight else viewportHeight
			context.X=if parent then parent.UserX or 0 else 0;context.Y=if parent then parent.UserY or 0 else 0
			if resources then context.ImageBox=resources.ImageBox end
			if Text then context.TextExpand=expandText end
			local boundsContext=table.clone(context)
			local function read(text: string?,axis: string,default: number,nonNegative: boolean?): number
				if not Lengths then return length(text,if axis=="x" then context.Width elseif axis=="y" then context.Height else 0,default) end
				local value,problem=Lengths.attribute(text,context,axis,default,nonNegative)
				if problem then table.insert(data.Diagnostics,{Case=source.Name,Element=a.id,Code=problem,Value=text}) end
				return value
			end
			if Lengths and a["font-size"] then
				font=table.clone(font);font.FontSize=read(a["font-size"],"font",font.FontSize,true)
				context.FontSize=font.FontSize
			end
			local paintState=inheritedPaint
			if Paints then
				local problems
				paintState,problems=Paints.resolve(a,inheritedPaint,context)
				for _,problem in problems do table.insert(data.Diagnostics,{Case=source.Name,Element=a.id,Code=problem.Code,Attribute=problem.Attribute,Value=problem.Value}) end
			end
			local declarations
			if Transforms then
				declarations=Transforms.declarations(a)
				-- view-box origin is the user coordinate origin, not viewBox min-x/min-y.
				local box={X=0,Y=0,Width=context.Width,Height=context.Height}
				local boxName=declarations.Box or 'view-box'
				if boxName=='fill-box' or boxName=='content-box' or boxName=='stroke-box' or boxName=='border-box' then
					box=referenceBox(node,boundsContext,inheritedPaint,boxName=='stroke-box' or boxName=='border-box')
				elseif boxName~='view-box' and boxName~='initial' and boxName~='unset' then
					table.insert(data.Diagnostics,{Case=source.Name,Element=a.id,Code='unsupported-transform-box',Value=boxName})
				end
				local transform,problems=Transforms.resolve(declarations,box,context,isRoot)
				for _,code in problems do table.insert(data.Diagnostics,{Case=source.Name,Element=a.id,Code=code}) end
				parent=if parent then table.clone(parent) else {UserWidth=viewportWidth,UserHeight=viewportHeight,Transform={SX=1,SY=1,TX=0,TY=0},Clip={X=0,Y=0,Width=viewportWidth,Height=viewportHeight}}
				parent.Transform=Viewport.compose(parent.Transform,transform)
			end
   if source.Runtime and Bounds and parent then
    local key=node.Source or node
    -- Expanded glyphs retain the semantic text source; keep its full group record.
    if not scene.Nodes[key] or (key.Name~='text' and key.Name~='tspan') then
     -- DOM queries need local bounds, but cursor/hit testing only needs the node
     -- and render shapes. Computing every ancestor's bounds here repeatedly
     -- expands text and flattens paths even if getBBox is never called.
     scene.Nodes[key]=setmetatable({Node=node,Transform=parent.Transform,Visible=not rendering or rendering.Visibility=='visible'},{__index=function(entry,property)
      if property~='Box' then return nil end
      local box=referenceBox(node,boundsContext,inheritedPaint,false)
      rawset(entry,'Box',box)
      return box
     end})
    end
   end
			if resources and group and node.Name~='svg' and (a['clip-path'] or 'none')~='none' then
    group.ClipPath=resources.Clip(node,referenceBox(node,boundsContext,inheritedPaint,false),context,parent.Transform)
   end
   if resources and group and node.Name~='svg' and (a['mask-image'] or 'none')~='none' then
    group.Mask=resources.Mask(node,referenceBox(node,boundsContext,inheritedPaint,false),context,parent.Transform)
   end
   if resources and group and node.Name~='svg' and (a.filter or 'none')~='none' then
    group.Filter=resources.Filter(node,referenceBox(node,boundsContext,inheritedPaint,false),context,parent.Transform,parent.Clip)
   end
   if node.Name=="svg" then
				local pw,ph=if parent then parent.UserWidth else viewportWidth,if parent then parent.UserHeight else viewportHeight
				local state=Viewport.resolve(a,if isRoot then 0 else read(a.x,"x",0),if isRoot then 0 else read(a.y,"y",0),
					if isRoot then viewportWidth else read(a.width,"x",pw,true),if isRoot then viewportHeight else read(a.height,"y",ph,true),
					if parent then parent.Transform else nil,if parent then parent.Clip else {X=0,Y=0,Width=viewportWidth,Height=viewportHeight},if rendering then rendering.Overflow=="visible" else a.overflow=="visible")
				for _,code in state.Diagnostics do table.insert(data.Diagnostics,{Case=source.Name,Element=a.id,Code=code}) end
				if state.Disabled then return end
    if source.Runtime and scene.Nodes[node.Source or node] then scene.Nodes[node.Source or node].Transform=state.Transform end
    if resources and group and ((a.filter or 'none')~='none' or (a['clip-path'] or 'none')~='none' or (a['mask-image'] or 'none')~='none') then
     local inner=table.clone(context);inner.Width=state.UserWidth;inner.Height=state.UserHeight
     local contents={Kind='Element',Name='g',NamespaceURI=node.NamespaceURI,Attributes={},Children=node.Children}
     local box=referenceBox(contents,inner,paintState,false)
     group.Filter=resources.Filter(node,box,inner,state.Transform,state.Clip)
     group.ClipPath=resources.Clip(node,box,inner,state.Transform)
     group.Mask=resources.Mask(node,box,inner,state.Transform)
    end
				for _,child in node.Children do visit(child,state,nil,font,paintState,rendering,target,contextPaint) end
			elseif node.Name=="g" or node.Name=="a" then
				for _,child in node.Children do visit(child,parent,nil,font,paintState,rendering,target,contextPaint) end
			elseif node.Name=='image' and resources then
    local shape=resources.Image(node,context,parent)
    if shape then
     shape.PointerEvents=a['pointer-events'];shape.SourceNode=node.EventSource or node.Source or node;shape.SourceId=a.id;shape.Opacity=rendering.Opacity;shape.Hidden=rendering.Visibility~='visible'
     shape.ClipPath=resources.Clip(node,shape.ImageBox,context,parent.Transform)
     shape.Mask=resources.Mask(node,shape.ImageBox,context,parent.Transform)
     shape.Filter=resources.Filter(node,shape.ImageBox,context,parent.Transform,parent.Clip)
     shape.BlendMode=rendering.BlendMode;shape.Isolation=rendering.Isolation;shape.ShapeRendering=rendering.ShapeRendering
     table.insert(scene.Shapes,shape);table.insert(target,shape)
    end
   elseif Geometries and Geometries.Supported[node.Name] then
				local geometry,problems=Geometries.build(node.Name,a,context,node.OutlineSubpaths)
				for _,problem in problems do table.insert(data.Diagnostics,{Case=source.Name,Element=a.id,Code=problem.Code,Attribute=problem.Attribute,Position=problem.Position}) end
				if not geometry then return end
    if source.Runtime and scene.Nodes[node.Source or node] and scene.Nodes[node.Source or node].Node==node then scene.Nodes[node.Source or node].Geometry=geometry end
				local function color(value: string?): any
					if not value or value=="none" then return nil end
					assert(value:match("^#%x%x%x%x%x%x$"),"S06 probe paint requires six-digit RGB")
					return {tonumber(value:sub(2,3),16),tonumber(value:sub(4,5),16),tonumber(value:sub(6,7),16)}
				end
				local fill,stroke,strokeWidth
				if Paints then fill,stroke,strokeWidth=Paints.used(paintState,context)
				else fill,stroke,strokeWidth=color(a.fill or "#000000"),color(a.stroke),read(a["stroke-width"],"diagonal",1,true) end
				if resources then
     local box=if (fill and fill.URL) or (stroke and stroke.URL) then referenceBox(node.TextRoot or node,boundsContext,inheritedPaint,false) else nil
     fill=resources.Bind(node,fill,box,context,parent.Transform,contextPaint)
     stroke=resources.Bind(node,stroke,box,context,parent.Transform,contextPaint)
    elseif Gradients and ((fill and fill.URL) or (stroke and stroke.URL)) then
     local box=referenceBox(node.TextRoot or node,boundsContext,inheritedPaint,false)
     local function report(code: string,value: any) table.insert(data.Diagnostics,{Case=source.Name,Element=a.id,Code=code,Value=value}) end
     fill=Gradients.bind(doc,node,fill,box,context,parent.Transform,report)
     stroke=Gradients.bind(doc,node,stroke,box,context,parent.Transform,report)
    end
    local vector=declarations and declarations.Vector
				if vector and vector~='none' and vector~='non-scaling-stroke' then table.insert(data.Diagnostics,{Case=source.Name,Element=a.id,Code='unsupported-vector-effect',Value=vector}) end
				local shape={PointerEvents=a['pointer-events'],SourceNode=node.EventSource or node.Source or node,SourceId=a.id,Geometry=geometry,Transform=parent.Transform,Clip=parent.Clip,NonScalingStroke=vector=='non-scaling-stroke',
					Fill=fill,Stroke=stroke,StrokeWidth=strokeWidth,FillRule=if Paints then paintState.FillRule else nil,DashArray=if Paints then Paints.dashes(paintState,context) else nil,DashOffset=if Paints then Paints.offset(paintState,context) else nil,LineCap=if Paints then paintState.LineCap else nil,LineJoin=if Paints then paintState.LineJoin else nil,MiterLimit=if Paints then paintState.MiterLimit else nil}
    if resources then
     if (a.filter or 'none')~='none' then shape.Filter=resources.Filter(node,referenceBox(node,boundsContext,inheritedPaint,false),context,parent.Transform,parent.Clip) end
     if (a['clip-path'] or 'none')~='none' then shape.ClipPath=resources.Clip(node,referenceBox(node,boundsContext,inheritedPaint,false),context,parent.Transform) end
     if (a['mask-image'] or 'none')~='none' then shape.Mask=resources.Mask(node,referenceBox(node,boundsContext,inheritedPaint,false),context,parent.Transform) end
     if (a['marker-start'] or 'none')~='none' or (a['marker-mid'] or 'none')~='none' or (a['marker-end'] or 'none')~='none' then
      -- Context paint uses the paint value, independently of fill/stroke-opacity.
      local contextState=table.clone(paintState);contextState.FillOpacity=1;contextState.StrokeOpacity=1
      local cf,cs=Paints.used(contextState,context)
      local box=if (cf and cf.URL) or (cs and cs.URL) then referenceBox(node,boundsContext,inheritedPaint,false) else nil
      shape.ContextFill=resources.Bind(node,cf,box,context,parent.Transform,contextPaint)
      shape.ContextStroke=resources.Bind(node,cs,box,context,parent.Transform,contextPaint)
      shape.Markers=resources.Markers(node,shape,context)
     end
    end
				if rendering then
					shape.Opacity=rendering.Opacity;shape.Hidden=rendering.Visibility~='visible';shape.BlendMode=rendering.BlendMode;shape.Isolation=rendering.Isolation;shape.PaintOrder=rendering.PaintOrder;shape.ShapeRendering=rendering.ShapeRendering
					table.insert(target,shape)
				end
				table.insert(scene.Shapes,shape)
			elseif node.Name=="rect" or node.Name=="circle" then
				local hex=a.fill or "#000000"
				if hex=="none" then return end
				assert(hex:match("^#%x%x%x%x%x%x$"),"S04 probe uses solid RGB paint")
				local x,y,w,h
				if node.Name=="circle" then
					local r=read(a.r,"diagonal",0,true);w,h=r*2,r*2;x,y=read(a.cx,"x",0)-r,read(a.cy,"y",0)-r
				else x,y,w,h=read(a.x,"x",0),read(a.y,"y",0),read(a.width,"x",0,true),read(a.height,"y",0,true) end
				x,y=Viewport.point(parent.Transform,x,y)
				table.insert(scene.Shapes,{SourceId=a.id,Kind=if node.Name=="circle" then "ellipse" else "rect",x=x,y=y,width=w*parent.Transform.SX,height=h*parent.Transform.SY,Clip=parent.Clip,
					Color={tonumber(hex:sub(2,3),16),tonumber(hex:sub(4,5),16),tonumber(hex:sub(6,7),16)}})
			end
		end
		visit(doc.Root,nil,true)
		if Documents then for _,problem in doc.Diagnostics do table.insert(data.Diagnostics,{Case=source.Name,Code=problem.Code,Value=problem.Value}) end end
		table.insert(data.Scenes,scene)
	end
	return data
end
