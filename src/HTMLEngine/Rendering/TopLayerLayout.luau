--!strict
-- Top-layer state changes affect the CSS cascade; placement still comes from
-- the same positioning pass as ordinary absolute/fixed elements.
local BoxTransform = require(script.Parent.BoxTransform)
local TopLayerLayout = {}

function TopLayerLayout.flags(tree: any, box: any, active: boolean, layoutAsTopLayer: boolean, hidden: boolean)
	if box.LayoutAsTopLayer~=nil and (box.LayoutAsTopLayer~=layoutAsTopLayer or box.TopLayerHidden~=hidden and not layoutAsTopLayer) then
		local pending=tree.TopLayerLayoutItems or {};tree.TopLayerLayoutItems=pending;pending[box]=true
	end
	box.TopLayerActive,box.LayoutAsTopLayer,box.TopLayerHidden=active,layoutAsTopLayer,hidden
end

function TopLayerLayout.syncState(tree: any, name: string, members: any)
	if not tree.SetCSSState then return end
	local queued=tree.PendingCSSStates and tree.PendingCSSStates[name]
	local previous=if queued then queued.Node else tree.CSSStates and tree.CSSStates[name]
	local same=true
	for node in previous or {} do if not members[node] then same=false;break end end
	if same then for node in members do if not previous or not previous[node] then same=false;break end end end
	if same then return end
	local _,layout,items=tree:SetCSSState(name,members)
	if layout and not tree.LayoutInProgress then
		local pending=tree.TopLayerLayoutItems or {};tree.TopLayerLayoutItems=pending
		if items and next(items) then for item,reason in items do pending[item]=reason end else pending[tree]=true end
	end
end

function TopLayerLayout.home(tree: any, state: any, fallback: any): any
	local box=state.Box
	if box.Style.Position=="fixed" and box.ViewportKind=="fixed" and tree.ViewportLayer then return tree.ViewportLayer end
	return state.NaturalParent or fallback
end

function TopLayerLayout.paint(box: any, root: any)
	if box.OuterWidth==nil or box.OuterHeight==nil then return end
	local x,y
	if box.TopLayerActive then
		local scroll=root.CanvasPosition or Vector2.new(0,0)
		x=(box.TopLayerDocumentX or 0)-(if box.Style.Position=="fixed" then 0 else scroll.X)
		y=(box.TopLayerDocumentY or 0)-(if box.Style.Position=="fixed" then 0 else scroll.Y)
	elseif box.Style.Position=="fixed" and box.ViewportKind=="fixed" then
		x,y=box.FixedViewportX or 0,box.FixedViewportY or 0
	else x,y=box.PaintX or box.LayoutX or 0,box.PaintY or box.LayoutY or 0 end
	box.TopLayerPaintX,box.TopLayerPaintY=x,y
	local bounds=box.OpacityGroup and box.OpacityBounds
	local left,top=if bounds then math.floor(bounds[1])else 0,if bounds then math.floor(bounds[2])else 0
	local surface=BoxTransform.target(box)
	surface.Position=UDim2.fromOffset(x+left,y+top)
	box.TransformBaseX,box.TransformBaseY=x+left,y+top
	BoxTransform.apply(box,nil,true)
end

function TopLayerLayout.updateScroll(tree: any, root: any)
	for _,state in tree.Dialogs or {} do if state.Box.TopLayerActive then TopLayerLayout.paint(state.Box,root) end end
	for _,state in tree.Popovers or {} do
		if state.Open and not(tree.DialogsByNode and tree.DialogsByNode[state.Node])then TopLayerLayout.paint(state.Box,root)end
	end
end

return TopLayerLayout
