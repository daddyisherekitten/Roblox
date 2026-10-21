--!strict
-- Hit the same retained 3D scene that is painted on a raster surface. Native
-- descendants are hidden by the compositor, so Roblox cannot pick them.
local Matrix=require(script.Parent.Parent.CSS.Matrix4)
local Corners=require(script.Parent.CornerRadii)
local Hit={}
local scenes=setmetatable({},{__mode="kv"})
local function localPoint(matrix: any,x: number,y: number): any?
	local a,b,c=matrix[1]-x*matrix[4],matrix[5]-x*matrix[8],x*matrix[16]-matrix[13]
	local d,e,f=matrix[2]-y*matrix[4],matrix[6]-y*matrix[8],y*matrix[16]-matrix[14]
	local determinant=a*e-b*d
	if math.abs(determinant)<1e-12 then return nil end
	local u,v=(c*e-b*f)/determinant,(a*f-c*d)/determinant
	local p=Matrix.point(matrix,u,v)
	if p.W<=.000001 or u~=u or v~=v then return nil end
	return {X=u,Y=v,Depth=p.Z/p.W}
end
local function inside(x: number,y: number,width: number,height: number,radii: any?): boolean
	if x<0 or y<0 or x>=width or y>=height then return false end
	for index,radius in radii or {}do
		local rx,ry=radius[1],radius[2]
		local dx,dy=if index==1 or index==4 then x else width-x,if index<=2 then y else height-y
		if rx>0 and ry>0 and dx<rx and dy<ry and ((dx-rx)/rx)^2+((dy-ry)/ry)^2>1 then return false end
	end
	return true
end
local function prepare(node: any,parent: any,depth: number): any?
	if depth>64 then return nil end
	local box=node.Box
	local width,height=box.OuterWidth or 0,box.OuterHeight or 0
	local matrix=Matrix.multiply(parent,node.Matrix)
	local radii=Corners.resolve(box.Style,width,height)
	if not radii and (box.Style.BorderRadius or 0)>0 then
		local radius=math.min(box.Style.BorderRadius,width/2,height/2)
		radii={{radius,radius},{radius,radius},{radius,radius},{radius,radius}}
	end
	local result={Box=box,Matrix=matrix,BackFacing=Matrix.backFacing(matrix),Width=width,Height=height,
		Radii=radii,Preserve=node.Preserve,Clip=node.Clip,Children={},Words={}}
	local childrenMatrix=if node.Preserve then Matrix.multiply(matrix,node.Perspective or Matrix.identity())else node.Perspective or Matrix.identity()
	for _,child in node.Children do
		local prepared=prepare(child,childrenMatrix,depth+1)
		if prepared then table.insert(result.Children,prepared)end
	end
	-- Word rectangles retain their source GUI/DOM identity; do not construct
	-- native hitboxes or replace the original editor/control instances.
	local origin=box.Gui and box.Gui.AbsolutePosition
	if origin then
		local size=box.Gui.AbsoluteSize
		local sx,sy=if size and size.X>0 then width/size.X else 1,if size and size.Y>0 then height/size.Y else 1
		for _,run in box.Children or {}do
			if run.Kind~="Words"then continue end
			for _,item in run.Items or {}do
				local gui=item.TextGui or item.Gui
				if gui and gui.AbsolutePosition and gui.AbsoluteSize and item.Text then
					local p,s=gui.AbsolutePosition,gui.AbsoluteSize
					table.insert(result.Words,{Gui=gui,Node=item.Node or run.Node,X=(p.X-origin.X)*sx,Y=(p.Y-origin.Y)*sy,Width=s.X*sx,Height=s.Y*sy,Style=item.Style or run.Style})
				end
			end
		end
	end
	return result
end
function Hit.attach(surface: any,node: any,bounds: any): any
	Hit.detach(surface)
	local record={Surface=surface,Scene=prepare(node,Matrix.identity(),0),Bounds=bounds}
	scenes[surface]=record
	if node.Box.Gui then scenes[node.Box.Gui]=record end
	return record -- The owning box retains it while alive; the registry is weak.
end
function Hit.detach(surface: any)
	local record=surface and scenes[surface]
	if record then
		scenes[record.Surface]=nil
		local gui=record.Scene and record.Scene.Box.Gui
		if gui and scenes[gui]==record then scenes[gui]=nil end
	end
end
function Hit.has(surface: any): boolean return scenes[surface]~=nil end
local function pick(prepared: any,x: number,y: number,registry: any,styles: any): any?
	local box,style=prepared.Box,prepared.Box.Style
	if style.Hidden then return nil end
	local point=localPoint(prepared.Matrix,x,y)
	if not point then return nil end
	local within=inside(point.X,point.Y,prepared.Width,prepared.Height,prepared.Radii)
	if prepared.Clip and not within then return nil end
	if not prepared.Preserve and style.BackfaceVisibility=="hidden"and prepared.BackFacing then return nil end
	local candidate
	if within and style.Visibility~="hidden"and style.PointerEvents~="none"and not(prepared.BackFacing and style.BackfaceVisibility=="hidden")then
		candidate={Node=box.Node,Gui=box.Gui,Point=point,Depth=if prepared.Preserve then point.Depth else 0}
		for _,word in prepared.Words do
			local ws=styles and styles[word.Gui]or word.Style or style
			if ws.Visibility~="hidden"and ws.PointerEvents~="none"and inside(point.X-word.X,point.Y-word.Y,word.Width,word.Height,nil)then
				candidate={Node=registry[word.Gui]or word.Node or box.Node,Gui=word.Gui,Point=point,Depth=if prepared.Preserve then point.Depth else 0}
			end
		end
	end
	local cx,cy=if prepared.Preserve then x else point.X,if prepared.Preserve then y else point.Y
	for _,child in prepared.Children do
		local hit=pick(child,cx,cy,registry,styles)
		if hit then
			if not candidate or hit.Depth>=candidate.Depth-.00001 then candidate=hit end
		end
	end
	if candidate and not prepared.Preserve then candidate.Depth=point.Depth end
	return candidate
end
function Hit.pick(surface: any,position: any,registry: any,styles: any?): (any?,any?,any?)
	local record=scenes[surface]
	if not record or not record.Scene then return nil end
	surface=record.Surface
	local p,s=surface.AbsolutePosition,surface.AbsoluteSize
	if not p or not s or s.X<=0 or s.Y<=0 then return nil end
	local x,y=position.X-p.X-s.X/2,position.Y-p.Y-s.Y/2
	local rotation=math.rad(surface.AbsoluteRotation or 0)
	local cosine,sine=math.cos(rotation),math.sin(rotation)
	local bounds=record.Bounds
	x,y=(x*cosine+y*sine+s.X/2)*bounds.Width/s.X+bounds.Left,(-x*sine+y*cosine+s.Y/2)*bounds.Height/s.Y+bounds.Top
	local result=pick(record.Scene,x,y,registry,styles)
	if result then return result.Node,result.Gui,result.Point end
	return nil
end
return Hit
