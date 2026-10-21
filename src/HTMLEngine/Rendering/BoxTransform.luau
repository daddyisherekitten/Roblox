--!strict
-- Applies CSS transforms after normal/positioned layout, without changing flow size.
local Transform2D=require(script.Parent.Parent.CSS.Transform2D)
local MotionPath=require(script.Parent.Parent.CSS.MotionPath)
local LengthExpression=require(script.Parent.Parent.CSS.LengthExpression)
local GroupOpacity=require(script.Parent.GroupOpacity)
local Matrix4=require(script.Parent.Parent.CSS.Matrix4)
local DirtyLayout=require(script.Parent.Parent.Layout.DirtyLayout)
local BoxTransform={}
local ClipRect=require(script.Parent.ClipRect)
local function write(object: any,key: string,value: any) if object[key]~=value then object[key]=value end end
local function component(value: any,axis: string,index: number): number
	local part=value and value[axis]
	return if part and part.Offset~=nil then part.Offset elseif value then value[index] or 0 else 0
end

function BoxTransform.target(box: any): any
	-- Opacity is composited in a clipping CanvasGroup. Transforming only the
	-- inner box would clip scale values above 1 at the group's original bounds.
	-- Transform the composed surface so opacity and transform share one layer.
	return if box.OpacityGroup then box.OpacityGroup.Gui else box.Gui
end

local function reference(box: any): any
	return Transform2D.layoutReference(box.Style,box.OuterWidth or 0,box.OuterHeight or 0)
end

function BoxTransform.origin(box: any): (number,number)
	local ref=reference(box);local x,y=Transform2D.origin(box.Style.TransformOrigin,ref.W,ref.H)
	return ref.X+x,ref.Y+y
end

function BoxTransform.pathDistance(box: any,value: any): number
	local ref=reference(box)
	return LengthExpression.resolve(value,MotionPath.length(box.Style,ref.W,ref.H))
end

-- Share path anchoring between layout and every animation frame.
function BoxTransform.resolve(box: any,operations: any,distanceOverride: any?): any
	local width,height=box.OuterWidth or 0,box.OuterHeight or 0;local ref=reference(box)
	local result=Transform2D.resolve(operations,ref.W,ref.H)
	if box.Style.OffsetPath then
		local path=MotionPath.resolve(box.Style,ref.W,ref.H,distanceOverride)
		local anchor=box.Style.OffsetAnchor or box.Style.TransformOrigin
		local anchorX,anchorY=Transform2D.origin(anchor,width,height)
		result.X+=ref.X+path.X-anchorX;result.Y+=ref.Y+path.Y-anchorY;result.Rotation+=path.Rotation
	end
	return result
end

-- Retain the unscrolled anchor separately. Never feed native GUI coordinates
-- (which may have been rounded or repainted) back into sticky positioning.
function BoxTransform.paintPosition(box: any,x: number,y: number)
	box.TransformPositionX,box.TransformPositionY=x,y
	local paintX,paintY=x+(box.ViewportOffsetX or 0),y+(box.ViewportOffsetY or 0)
	write(BoxTransform.target(box),"Position",UDim2.fromOffset(paintX,paintY))
	ClipRect.apply(box,paintX,paintY)
	box.TransformPaintX,box.TransformPaintY=paintX,paintY
end

-- A replaced inline item has a border surface inside its margin wrapper. Use
-- that same retained surface as block transforms; the margin stays in flow.
function BoxTransform.node(tree: any,node: any): any?
	return if tree.TransformBox then tree:TransformBox(node) else tree.NodeBoxes[node]
end

function BoxTransform.boxes(tree: any): any
	return if tree.TransformBoxes then tree:TransformBoxes()else tree.NodeBoxes
end

function BoxTransform.inline(item: any,factory: any?)
	local box=item.GeometryBox
	if not box or item.InlineBox or not box.Node or not item.BoxGui then return end
	box.Kind,box.Gui,box.Factory='InlineImage',item.BoxGui,factory or item.Factory or item.ImageFactory
	box.ImageItem,box.OpacityGroup=item,item.OpacityGroup
	if box.OpacityGroup then
		GroupOpacity.image(item)
		local target=box.OpacityGroup.Gui;local margin=item.Style.Margin
		local left,top=component(target.Position,'X',1)-margin[4],component(target.Position,'Y',2)-margin[1]
		box.OpacityBounds={left,top,left+component(target.Size,'X',1),top+component(target.Size,'Y',2)}
	end
	-- The item painter just restored its ordinary border position. Capture it
	-- before applying the transform, including after margin/size/scroll changes.
	box.TransformBaseX,box.TransformBaseY=nil,nil
	BoxTransform.apply(box,box.Scene3DContext,false)
end

function BoxTransform.paint(box: any,x: number,y: number,rotation: number,scale: number,originX: number?,originY: number?)
	if box.EnsureCanvasCompositor and not box.OpacityGroup and(x~=0 or y~=0 or rotation~=0 or scale~=1)then
		box.EnsureCanvasCompositor()
		-- Promotion replaces the paint target after its ordinary anchor was read.
		local promoted=BoxTransform.target(box);local position=promoted.Position
		box.TransformBaseX,box.TransformBaseY=component(position,'X',1),component(position,'Y',2)
	end
	local target=BoxTransform.target(box);local width,height=box.OuterWidth or 0,box.OuterHeight or 0
	originX,originY=originX or 0,originY or 0
	local bounds=box.OpacityGroup and box.OpacityBounds
	local left,top=if bounds then bounds[1] else 0,if bounds then bounds[2] else 0
	local targetWidth,targetHeight=if bounds then bounds[3]-left else width,if bounds then bounds[4]-top else height
	local targetOriginX,targetOriginY=originX-left,originY-top
	-- Roblox Rotation always uses the GUI center, irrespective of AnchorPoint.
	-- Move that center around the CSS origin to compensate for the native pivot.
	local dx,dy=targetWidth/2-targetOriginX,targetHeight/2-targetOriginY
	local radians=math.rad(rotation);local cosine,sine=math.cos(radians),math.sin(radians)
	local paintX=(box.TransformBaseX or 0)+targetOriginX+x+scale*((cosine-1)*dx-sine*dy)
	local paintY=(box.TransformBaseY or 0)+targetOriginY+y+scale*(sine*dx+(cosine-1)*dy)
	write(target,"AnchorPoint",Vector2.new(if targetWidth>0 then targetOriginX/targetWidth else 0,if targetHeight>0 then targetOriginY/targetHeight else 0))
	BoxTransform.paintPosition(box,paintX,paintY)
	write(target,"Rotation",rotation)
	if scale~=1 or box.TransformScale then
		if not box.TransformScale then box.TransformScale=box.Factory.modifier("UIScale",target,{Scale=1}) end
		write(box.TransformScale,"Scale",scale)
	end
end

-- Sticky/fixed positioning and CSS transforms are separate paint operations.
-- Compose the absolute viewport offset with the retained transform anchor.
function BoxTransform.position(box: any,x: number,y: number,normalX: number,normalY: number)
	local offsetX,offsetY=x-normalX,y-normalY
	box.ViewportOffsetX,box.ViewportOffsetY=offsetX,offsetY
	box.PaintX,box.PaintY=x,y
	local bounds=box.OpacityGroup and box.OpacityBounds
	local baseX=box.TransformPositionX or normalX+(if bounds then math.floor(bounds[1]) else 0)
	local baseY=box.TransformPositionY or normalY+(if bounds then math.floor(bounds[2]) else 0)
	BoxTransform.paintPosition(box,baseX,baseY)
end

local function baseline(box: any,preserveBase: boolean?)
 local target=BoxTransform.target(box)
 local x,y=component(target.Position,"X",1),component(target.Position,"Y",2)
 if box.ClipRectViewport then
  local bounds=box.OpacityGroup and box.OpacityBounds
  x=(box.PaintX or box.LayoutX or 0)+(if bounds then math.floor(bounds[1])else 0)
  y=(box.PaintY or box.LayoutY or 0)+(if bounds then math.floor(bounds[2])else 0)
 end
 local unchanged=box.TransformApplied and math.abs(x-(box.TransformPaintX or math.huge))<.00001 and math.abs(y-(box.TransformPaintY or math.huge))<.00001
 if preserveBase==false or not ((preserveBase and box.TransformBaseX~=nil) or unchanged) then box.TransformBaseX,box.TransformBaseY=x-(box.ViewportOffsetX or 0),y-(box.ViewportOffsetY or 0) end
end
local function localMatrix(box: any): any
 local ref=reference(box);local originX,originY=BoxTransform.origin(box)
 local operations=box.TransformOverride or Transform2D.operations(box.Style)
 local matrix=Transform2D.matrix(operations,ref.W,ref.H)
 matrix=Matrix4.around(matrix,originX,originY,if box.Style.TransformOrigin.Z then LengthExpression.resolve(box.Style.TransformOrigin.Z,0) else 0)
 if box.Style.OffsetPath then
  local path=MotionPath.resolve(box.Style,ref.W,ref.H,box.OffsetDistanceOverride)
  local ax,ay=Transform2D.origin(box.Style.OffsetAnchor or box.Style.TransformOrigin,box.OuterWidth or 0,box.OuterHeight or 0)
  matrix=Matrix4.multiply(Matrix4.translate(ref.X+path.X-ax,ref.Y+path.Y-ay),Matrix4.multiply(Matrix4.around(Matrix4.rotate(0,0,1,path.Rotation),originX,originY),matrix))
 end
 return matrix
end
local function perspectiveMatrix(style: any,width: number,height: number): any?
 if not style.Perspective then return nil end
 local x,y=Transform2D.origin(style.PerspectiveOrigin,width,height)
 return Matrix4.around(Matrix4.perspective(LengthExpression.resolve(style.Perspective,0)),x,y)
end
local function grouping(style: any): boolean
 return (style.Opacity or 1)<1 or style.Overflow=="hidden" or style.Overflow=="scroll" or style.Overflow=="auto" or style.OverflowX=="hidden" or style.OverflowY=="hidden" or style.ClipPath~=nil or style.MaskImage~=nil or (style.Filter and #(style.Filter.Steps or {})>0) or style.Isolation=="isolate" or (style.Contain and style.Contain.Paint)
end
local function sceneNode(box: any,isRoot: boolean): any
 local x,y=if isRoot then 0 else box.PaintX or box.LayoutX or component(box.Gui.Position,"X",1),if isRoot then 0 else box.PaintY or box.LayoutY or component(box.Gui.Position,"Y",2)
 local node={Box=box,Matrix=Matrix4.multiply(Matrix4.translate(x,y),localMatrix(box)),Children={},Preserve=box.Style.TransformStyle=="preserve-3d" and not grouping(box.Style),Perspective=perspectiveMatrix(box.Style,box.OuterWidth or 0,box.OuterHeight or 0),Clip=box.Style.Overflow=="hidden" or box.Style.OverflowX=="hidden" or box.Style.OverflowY=="hidden" or (box.Style.Contain and box.Style.Contain.Paint)}
 for _,child in box.Children or {} do
	if child.Style and child.Style.Hidden then continue end
  if child.Kind=="Words" then for _,atomic in child.Children or {} do if atomic.OuterWidth and not atomic.Style.Hidden then table.insert(node.Children,sceneNode(atomic,false)) end end
  elseif child.Style and child.OuterWidth then table.insert(node.Children,sceneNode(child,false)) end
 end
 return node
end
local function needsScene(box: any): boolean
 if not Matrix4.native(localMatrix(box)) or box.Style.TransformStyle=="preserve-3d" then return true end
 return false
end
function BoxTransform.paint3D(box: any,operations: any?,distance: any?)
 local root=box.Scene3DRoot or box
 if not root.VisualEffects or not root.VisualEffects.DrawScene then return false end
 if operations then box.TransformOverride=operations end
 if distance then box.OffsetDistanceOverride=distance end
 local node=sceneNode(root,true)
 -- The retained outer CanvasGroup already applies the root's opacity once.
 node.NativeOpacity=root.OpacityGroup~=nil
 local context=root.Scene3DContext
 if context then node.Matrix=Matrix4.multiply(Matrix4.around(Matrix4.perspective(context.Depth),context.OriginX,context.OriginY),node.Matrix) end
 baseline(root,true)
 local target=BoxTransform.target(root)
 write(target,"AnchorPoint",Vector2.new(0,0));BoxTransform.paintPosition(root,root.TransformBaseX or 0,root.TransformBaseY or 0);write(target,"Rotation",0)
 if root.TransformScale then write(root.TransformScale,"Scale",1) end
 root.TransformPaintX,root.TransformPaintY=(root.TransformBaseX or 0)+(root.ViewportOffsetX or 0),(root.TransformBaseY or 0)+(root.ViewportOffsetY or 0)
 local drawn=root.VisualEffects:DrawScene(root,node)
 if drawn then root.TransformApplied=true end
 return drawn
end
function BoxTransform.apply(box: any,inheritedPerspective: any?,preserveBase: boolean?)
 if box.Node.Kind=="Document" or not box.OuterWidth or not box.OuterHeight then return end
	if box.ContentSkipped and box.TopLayerActive then write(BoxTransform.target(box),"Visible",false);return end
 if preserveBase then box.TransformOverride=nil;box.OffsetDistanceOverride=nil end
 local style=box.Style;local operations=box.TransformOverride or Transform2D.operations(style)
 if box.Scene3DRoot and box.Scene3DRoot~=box then BoxTransform.paint3D(box);return end
 if #operations==0 and not style.OffsetPath and not box.TransformApplied and style.TransformStyle~="preserve-3d" then
  ClipRect.apply(box,box.PaintX or box.LayoutX or 0,box.PaintY or box.LayoutY or 0);return
 end
 baseline(box,preserveBase)
 box.Scene3DContext=inheritedPerspective
 if needsScene(box) and BoxTransform.paint3D(box) then return end
 if box.VisualEffects then if box.VisualEffects.ClearScene then box.VisualEffects:ClearScene(box) end end
 local target=BoxTransform.target(box);local hasPath=style.OffsetPath~=nil
 local originX,originY=BoxTransform.origin(box)
 if #operations==0 and not hasPath then originX,originY=0,0 end
 local result=BoxTransform.resolve(box,operations)
 write(target,"Visible",not style.Hidden and (box.CanvasPaintGui~=nil or style.Visibility~="hidden") and not (style.BackfaceVisibility=="hidden" and result.BackFacing))
 BoxTransform.paint(box,result.X,result.Y,result.Rotation,result.Scale,originX,originY)
 box.TransformApplied=#operations>0 or hasPath
end

function BoxTransform.applyTree(box: any,inheritedPerspective: any?,alive: (() -> boolean)?)
	if alive and not alive() then return end
	box.ViewportOffsetX,box.ViewportOffsetY=0,0
	box.TransformPositionX,box.TransformPositionY=nil,nil
	box.Scene3DRoot=nil
 if box.VisualEffects and box.VisualEffects.ClearScene then box.VisualEffects:ClearScene(box) end
 box.TransformOverride=nil;box.OffsetDistanceOverride=nil
 -- Flow/positioning has just established the new native position. Capture it
 -- even when transform:none takes the paint fast path, otherwise the next
 -- hover can reuse a base from before a resize. Cached subtrees still carry
 -- their transformed surface and must retain their existing unpainted base.
 if box.TransformBaseX==nil or box.Kind~='InlineImage'and not DirtyLayout.wasReused(box)then baseline(box,false) end
 BoxTransform.apply(box,inheritedPerspective,true)
 if box.Scene3DSurface then
  local function mark(node: any)
   node.Scene3DRoot=box
   for _,child in node.Children or {} do if child.Kind=="Words" then for _,atomic in child.Children or {} do mark(atomic) end else mark(child) end end
  end
  mark(box);return
 end
 local own
	if box.Style and box.Style.Perspective then
		local originX,originY=Transform2D.origin(box.Style.PerspectiveOrigin,box.OuterWidth or 0,box.OuterHeight or 0)
		own={Depth=LengthExpression.resolve(box.Style.Perspective,math.max(1,box.Style.ViewportWidth or 1)),OriginX=originX,OriginY=originY}
	end
	local outgoing=own or (if box.Style and box.Style.TransformStyle=="preserve-3d" then inheritedPerspective else nil)
	local function descend(child: any)
		local context=outgoing
		if context then
			local childX=child.PaintX or child.LayoutX or component(child.Gui and child.Gui.Position,"X",1)
			local childY=child.PaintY or child.LayoutY or component(child.Gui and child.Gui.Position,"Y",2)
			context={Depth=context.Depth,OriginX=context.OriginX-childX,OriginY=context.OriginY-childY}
		end
		BoxTransform.applyTree(child,context,alive)
	end
	for _,child in box.Children or {} do
		if child.Kind=="Words" then
			for _,atomic in child.Children or {} do descend(atomic) end
			for _,item in child.Items or {} do
				if item.Kind=='Image'and not item.InlineBox and item.GeometryBox then descend(item.GeometryBox)end
			end
		else descend(child) end
	end
end
return BoxTransform
