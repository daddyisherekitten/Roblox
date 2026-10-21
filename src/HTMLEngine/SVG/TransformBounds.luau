--!strict
-- Reference boxes for the current geometry subset, without clipping or markers.
local Matrix=require(script.Parent.Matrix)
local Transform=require(script.Parent.Transform)
local Geometry=require(script.Parent.Geometry)
local Curves=require(script.Parent.Curves)
local Paint=require(script.Parent.Paint)
local Length=require(script.Parent.Length)
local Viewport=require(script.Parent.Viewport)
local Rendering=require(script.Parent.Rendering)
local TransformBounds={}
function TransformBounds.reference(node: any,context: any,parentPaint: any?,stroke: boolean?,work: any?): any
	work=work or {Vertices=0,Nodes=0}
	local collect
	collect=function(current: any,ctx: any,inherited: any,apply: boolean): any
		if current.Kind~='Element' or current.NamespaceURI~=node.NamespaceURI then return {} end
		if current.Name=='text' and ctx.TextExpand then current=ctx.TextExpand(current,ctx) end
		work.Nodes+=1;assert(work.Nodes<=16384,'SVG transform bounds node budget exceeded')
		local a=current.Attributes
		if Rendering.resolve(a).Display=='none' then return {} end
		local localContext=table.clone(ctx)
		if a['font-size'] then localContext.FontSize=Length.resolve(a['font-size'],ctx,'font',true) or ctx.FontSize end
		local state=Paint.resolve(a,inherited,localContext)
		local points={};local viewport
		local function append(list: any)
			work.Vertices+=#list;assert(work.Vertices<=262144,'SVG transform bounds budget exceeded')
			for _,p in list do table.insert(points,p) end
		end
		if Geometry.Supported[current.Name] then
			local g=Geometry.build(current.Name,a,localContext,current.OutlineSubpaths)
			if g then
				local parts=if g.Subpaths then Curves.flatten(g.Subpaths,64) else {{Points=Geometry.contour(g,64),Closed=g.Closed}}
				local _,color,width=Paint.used(state,localContext)
				for _,part in parts do
					append(part.Points)
					if stroke and color and width>0 then
						for _,contour in Geometry.stroke(part.Points,part.Closed,width,{LineCap=state.LineCap,LineJoin=state.LineJoin,MiterLimit=state.MiterLimit,Scale=64}) do append(contour) end
					end
				end
			end
		elseif current.Name=='image' then
   if ctx.ImageBox then append(Matrix.rectangle(Matrix.identity(),ctx.ImageBox(current,localContext)))
   else
    local x=Length.attribute(a.x,localContext,'x',0,false);local y=Length.attribute(a.y,localContext,'y',0,false)
    local w=Length.attribute(a.width,localContext,'x',0,true);local h=Length.attribute(a.height,localContext,'y',0,true)
    append({{x,y},{x+w,y},{x+w,y+h},{x,y+h}})
   end
  elseif current.Name=='g' or current.Name=='a' or current.Name=='svg' then
			if current.Name=='svg' then
				local function read(key: string,axis: string,default: number): number return Length.attribute(a[key],localContext,axis,default,false) end
				viewport=Viewport.resolve(a,read('x','x',0),read('y','y',0),read('width','x',ctx.Width),read('height','y',ctx.Height))
				if viewport.Disabled then return {} end
				localContext.Width=viewport.UserWidth;localContext.Height=viewport.UserHeight
				localContext.X=viewport.UserX;localContext.Y=viewport.UserY
			end
			for _,child in current.Children do append(collect(child,localContext,state,true)) end
		end
		if viewport then points=Matrix.polygon(viewport.Transform,points) end
		if apply then
			local declarations=Transform.declarations(a)
			local box={X=0,Y=0,Width=ctx.Width,Height=ctx.Height}
			if declarations.Box=='fill-box' or declarations.Box=='stroke-box' or declarations.Box=='content-box' or declarations.Box=='border-box' then
				local wantsStroke=declarations.Box=='stroke-box' or declarations.Box=='border-box'
				if wantsStroke~=(stroke==true) then
					box=TransformBounds.reference(current,ctx,inherited,wantsStroke,work)
				else box=Matrix.bounds(points) end
			end
			local transform=Transform.resolve(declarations,box,ctx)
			points=Matrix.polygon(transform,points)
		end
		return points
	end
	return Matrix.bounds(collect(node,context,parentPaint,false))
end
return TransformBounds
