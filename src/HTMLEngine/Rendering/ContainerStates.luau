--!strict
-- A post-layout/scroll snapshot stays stable throughout the ensuing cascade.
local Scroll=require(script.Parent.Parent.Layout.ScrollLayout)
local Work=require(script.Parent.Parent.WorkContext)
local States={}
local function dimensions(gui)
	local view=gui.AbsoluteWindowSize or gui.AbsoluteSize or {X=0,Y=0}
	local canvas=gui.AbsoluteCanvasSize
	if not canvas then local size=gui.CanvasSize or{};canvas={X=size.X and size.X.Offset or size[1]or 0,Y=size.Y and size.Y.Offset or size[2]or 0}end
	return math.max(0,canvas.X-view.X),math.max(0,canvas.Y-view.Y)
end
local function key(state)
	local result={};for _,name in {'stuck','snapped','scrollable','scrolled'}do
		local part=state[name];table.insert(result,if part then name else '!')
		for _,edge in {'top','right','bottom','left','x','y'}do if part and part[edge]then table.insert(result,edge)end end
	end
	table.insert(result,state.SnapWritingMode or'');table.insert(result,state.SnapDirection or'');return table.concat(result,':')
end
function States.snapshot(tree,root)
	local index=tree.ContainerStateIndex
	if not index then
		index={Owners={},Containers={}};tree.ContainerStateIndex=index
		for _,box in tree.NodeBoxes do
			Work.checkpoint()
			if box.ScrollGui and box.Style.ScrollSnapType and box.Style.ScrollSnapType.Axis~='none'then table.insert(index.Owners,box)end
			if box.Style and(box.Style.ContainerType or'normal'):find('scroll-state',1,true)then table.insert(index.Containers,box)end
		end
	end
	local snapTargets={}
	for _,owner in index.Owners do
		Work.checkpoint()
		if owner.ScrollGui then
			local _,x,y=Scroll.snapTargets(owner)
			for _,pair in {{x,'x'},{y,'y'}}do
				local target=pair[1];if target then local entry=snapTargets[target]or{};snapTargets[target]=entry;entry[pair[2]]=true;entry.WritingMode=owner.Style.WritingMode;entry.Direction=owner.Style.Direction end
			end
		end
	end
	local changed=false
	for _,box in index.Containers do
		Work.checkpoint()
		local style=box.Style
		if not style or not(style.ContainerType or'normal'):find('scroll-state',1,true)then continue end
		local previous=box.ContainerScrollState
		local state={snapped={}}
		if style.Position=='sticky'then
			local x,y=box.StickyOffsetX or 0,box.StickyOffsetY or 0;state.stuck={}
			if x>1e-6 then state.stuck.left=true elseif x< -1e-6 then state.stuck.right=true end
			if y>1e-6 then state.stuck.top=true elseif y< -1e-6 then state.stuck.bottom=true end
		end
		local snapped=snapTargets[box];if snapped then state.snapped.x=snapped.x;state.snapped.y=snapped.y;state.SnapWritingMode=snapped.WritingMode;state.SnapDirection=snapped.Direction end
		local gui=box.ScrollGui
		if not gui and box.Node.Name=='html'then gui=root end
		if gui then
			state.scrollable={};state.scrolled=previous and previous.scrolled or{}
			local position=gui.CanvasPosition or{X=0,Y=0};local maxX,maxY=dimensions(gui)
			local rootScroller=gui==root
			if rootScroller or style.OverflowX=='auto'or style.OverflowX=='scroll'then
				if position.X>1e-6 then state.scrollable.left=true end;if position.X<maxX-1e-6 then state.scrollable.right=true end
			end
			if rootScroller or style.OverflowY=='auto'or style.OverflowY=='scroll'then
				if position.Y>1e-6 then state.scrollable.top=true end;if position.Y<maxY-1e-6 then state.scrollable.bottom=true end
			end
			local old=box.ContainerScrollPosition
			local relative=if gui==root then tree.ContainerRelativeScroll else box.ContainerRelativeScroll
			if relative then state.scrolled=relative
			elseif box.ContainerUserScroll and old and(position.X~=old.X or position.Y~=old.Y)then
				state.scrolled={}
				if position.X>old.X then state.scrolled.right=true elseif position.X<old.X then state.scrolled.left=true end
				if position.Y>old.Y then state.scrolled.bottom=true elseif position.Y<old.Y then state.scrolled.top=true end
			end
			box.ContainerRelativeScroll,box.ContainerUserScroll=nil,nil;if gui==root then tree.ContainerRelativeScroll=nil end
			box.ContainerScrollPosition={X=position.X,Y=position.Y}
		end
		state.Key=key(state);if not previous or previous.Key~=state.Key then changed=true;box.ContainerScrollState=state end
	end
	return changed
end
return States
