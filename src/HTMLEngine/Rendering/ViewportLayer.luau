--!strict
-- Fixed boxes use a page overlay. Sticky boxes stay in their normal GUI
-- hierarchy so their nearest scrollport clips them and their parent bounds
-- can push them out of the way.
local ViewportLayer={}
local BorderGeometry=require(script.Parent.Parent.Layout.BorderGeometry)
local BoxTransform=require(script.Parent.BoxTransform)
local TopLayerLayout=require(script.Parent.TopLayerLayout)
local function write(gui: any,key: string,value: any)
	if gui[key]~=value then gui[key]=value end
end

function ViewportLayer.attach(tree: any,root: any,factory: any): any?
	if not root.Parent then return nil end
	local hasFixed=false
	for _,box in tree.ViewportPositioned or {} do
		if box.Style.Position=="fixed" and not box.TopLayerActive and not box.FixedContainingBox then hasFixed=true;break end
	end
	local layer = tree.ViewportLayer
	if hasFixed and not layer then layer=factory.create("Frame",root.Parent,{
		Name="HTMLViewportPositionLayer",BackgroundTransparency=1,BorderSizePixel=0,
		ClipsDescendants=true,Active=false,ZIndex=900,Visible=not tree.PresentationHidden,
	}); tree.ViewportLayer = layer end
	if layer and layer.SetAttribute then
		layer:SetAttribute("HTMLPageOverlay",true)
		layer:SetAttribute("HTMLHitTestPassthrough",true)
	end
	-- Return formerly fixed boxes to their original flow/scroll surface, and
	-- move new fixed boxes together with their opacity compositing surface.
	for _, box in tree.NodeBoxes or {} do
		if box.TopLayerActive then box.ViewportHome=nil;continue end
		local surface = if box.OpacityGroup then box.OpacityGroup.Gui else box.Gui
		if box.Style.Position == "fixed" and not box.HiddenByAncestor and not box.FixedContainingBox and layer then
			if not box.ViewportHome then box.ViewportHome = surface.Parent end
			write(surface, "Parent", layer)
		elseif box.ViewportHome then
			write(surface, "Parent", box.ViewportHome)
			box.ViewportHome = nil
		end
	end
	if layer then write(layer, "Visible", hasFixed and not tree.PresentationHidden) end
	tree.PositioningSurfacesDirty = nil
	return if hasFixed then layer else nil
end

function ViewportLayer.update(tree: any,root: any,changedScrollBox: any?)
	if tree.LayoutInProgress or tree.LayoutNeedsRecovery then return end
	local stickyByScrollBox=tree.StickyByScrollBox
	if changedScrollBox and (not stickyByScrollBox or not stickyByScrollBox[changedScrollBox]) then return end
	local layer=tree.ViewportLayer
	local size=root.AbsoluteWindowSize or root.AbsoluteSize
	if layer and layer.Parent then
		local rootPosition=root.AbsolutePosition or Vector2.new(0,0)
		local parentPosition=if layer.Parent.AbsolutePosition then layer.Parent.AbsolutePosition else Vector2.new(0,0)
		write(layer,"Position",UDim2.fromOffset(rootPosition.X-parentPosition.X,rootPosition.Y-parentPosition.Y))
		write(layer,"Size",UDim2.fromOffset(size.X,size.Y))
	end
	local positioned=if changedScrollBox then stickyByScrollBox[changedScrollBox] else tree.ViewportPositioned or {}
	if not changedScrollBox then stickyByScrollBox={} end
	for _,box in positioned do
		if box.TopLayerActive then continue end
		if not changedScrollBox and box.ViewportKind=="sticky" and box.StickyScrollBox then
			local group=stickyByScrollBox[box.StickyScrollBox]
			if not group then group={};stickyByScrollBox[box.StickyScrollBox]=group end
			table.insert(group,box)
		end
		if box.Style.Position=="fixed" and box.ViewportKind=="fixed" and box.FixedViewportX~=nil and box.FixedViewportY~=nil then
			BoxTransform.position(box,box.FixedViewportX,box.FixedViewportY,box.FixedViewportX,box.FixedViewportY)
		elseif box.Style.Position=="sticky" and box.ViewportKind=="sticky" and box.StickyNormalY~=nil then
			local scrollBox=box.StickyScrollBox
			local scrollGui=if scrollBox==tree then root else scrollBox.ScrollGui
			local canvas=scrollGui.CanvasPosition or Vector2.new(0,0)
			local view=scrollGui.AbsoluteWindowSize
			local borderTop,borderRight,borderBottom,borderLeft=0,0,0,0
			if scrollBox~=tree then
				borderTop,borderRight,borderBottom,borderLeft=BorderGeometry.sizes(scrollBox.Style)
			end
			local leadingX, leadingY = scrollBox.ScrollLeadingX or 0, scrollBox.ScrollLeadingY or 0
			local viewWidth=if view then view.X else (if scrollBox==tree then size.X else scrollBox.OuterWidth-borderLeft-borderRight-(scrollBox.ScrollY or 0))
			local viewHeight=if view then view.Y else (if scrollBox==tree then size.Y else scrollBox.OuterHeight-borderTop-borderBottom-(scrollBox.ScrollX or 0))
			local x,y=box.StickyNormalX,box.StickyNormalY
			if box.StickyLeft~=nil then
				x=math.max(x,box.StickyScrollX+borderLeft+leadingX+canvas.X+box.StickyLeft-box.StickyParentX)
			end
			if box.StickyRight~=nil then
				x=math.min(x,box.StickyScrollX+borderLeft+canvas.X+viewWidth-box.StickyRight-box.OuterWidth-box.StickyParentX)
			end
			if box.StickyTop~=nil then
				y=math.max(y,box.StickyScrollY+borderTop+leadingY+canvas.Y+box.StickyTop-box.StickyParentY)
			end
			if box.StickyBottom~=nil then
				y=math.min(y,box.StickyScrollY+borderTop+canvas.Y+viewHeight-box.StickyBottom-box.OuterHeight-box.StickyParentY)
			end
			x=math.clamp(x,box.StickyMinX,box.StickyMaxX)
			y=math.clamp(y,box.StickyMinY,box.StickyMaxY)
			box.StickyOffsetX,box.StickyOffsetY=x-box.StickyNormalX,y-box.StickyNormalY
			BoxTransform.position(box,x,y,box.StickyNormalX,box.StickyNormalY)
		end
	end
	if not changedScrollBox then
		TopLayerLayout.updateScroll(tree,root)
		tree.StickyByScrollBox=stickyByScrollBox
		if tree.SyncViewportListeners then tree.SyncViewportListeners() end
	end
end

function ViewportLayer.destroy(tree: any)
	local layer=tree.ViewportLayer
	if layer and layer.Parent then layer:Destroy() end
	tree.ViewportLayer=nil
end

-- Property signals can be deferred until after a scroll frame has moved.
-- Sample only the scrollports that own sticky boxes before each rendered frame.
-- This updates their paint position without requesting any document layout.
function ViewportLayer.start(page: any,tree: any,root: any,services: any?)
	local positions=setmetatable({},{__mode="k"})
	local function refresh()
		if not page.Alive then return end
		for owner in tree.StickyByScrollBox or {} do
			local gui=if owner==tree then root else owner.ScrollGui
			if gui and positions[gui]~=gui.CanvasPosition then
				positions[gui]=gui.CanvasPosition
				ViewportLayer.update(tree,root,owner)
			end
		end
	end
	local connection
	local function sync()
		local needed = page.Alive and next(tree.StickyByScrollBox or {}) ~= nil
		if needed and not connection then
			local runService=if services and services.RunService then services.RunService else game:GetService("RunService")
			local signal=runService.PreRender or runService.RenderStepped or runService.Heartbeat
			connection = signal:Connect(refresh)
		elseif not needed and connection then connection:Disconnect(); connection = nil; table.clear(positions) end
	end
	tree.SyncViewportListeners = sync
	sync()
	page:AddCleanup(function()
		if connection then connection:Disconnect(); connection = nil end
		if tree.SyncViewportListeners == sync then tree.SyncViewportListeners = nil end
		table.clear(positions)
	end)
	return refresh
end

return ViewportLayer
