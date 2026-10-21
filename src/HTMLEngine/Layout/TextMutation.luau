--!strict
-- Measure replacement text locally; propagate changes in its outer geometry
-- through the dirty tree and retain the already measured replacement run.
local TextMutation = {}
local WritingMode=require(script.Parent.Parent.CSS.WritingMode)

-- Normal blocks fill the available width. Auto-sized tracks, flex bases and
-- shrink-to-fit boxes can depend on a descendant's intrinsic text width instead.
local function independentWidth(box: any): boolean
	local child = box
	while child do
		if not child.LayoutParent and child.Node and child.Node.Kind == "Document" then return true end
		if child.Kind == "Words" then return false end
		local s = child.Style or {}
		if s.Display ~= "block" and s.Display ~= "grid" then return false end
		if (s.Float and s.Float ~= "none") or s.Position == "absolute" or s.Position == "fixed" then return false end
		local parent = child.LayoutParent
		if parent and parent.Style and parent.Style.Display == "grid" then
			local grid = parent.GridLayout
			if not grid or not grid.Columns.Size or grid.Columns.Subgrid or parent.Style.LegacyGrid then return false end
			local placement
			for _, entry in grid.Items do if entry.Box == child then placement = entry; break end end
			if not placement or (placement.Justify ~= "normal" and placement.Justify ~= "stretch")
				or s.AspectRatio or placement.Auto[2] or placement.Auto[4] then return false end
			for column = placement.Column, placement.Column + placement.Columns - 1 do
				local track = grid.Columns.Tracks[column]
				-- Fixed tracks ignore content contributions. Fractional tracks also
				-- need a content-independent minimum on this item/track.
				if not track or not ((track.MinKind == "fixed" and track.MaxKind == "fixed")
					or (track.MaxKind == "fr" and (track.MinKind == "fixed"
						or ((track.MinKind == "auto" or track.MinKind == "min-content") and s.MinWidth ~= nil)))) then return false end
			end
		end
		child = parent
	end
	return true
end

local function textRun(box: any): any?
	if #box.Children ~= 1 then return nil end
	local run = box.Children[1]
	if run.Kind ~= "Words" or #run.Items == 0 then return nil end
	if run.Style.MaxLines or run.Style.TextOverflow == "ellipsis"
		or WritingMode.vertical(run.Style)then return nil end
	for _, item in run.Items do
		local style = item.Style or run.Style
		if (item.Kind ~= "Word" and item.Kind ~= "Space" and item.Kind ~= "Break")
			or item.Glyphs or item.VerticalAdvance or style.InlineFragment or style.OpacityGroup then return nil end
	end
	return run
end

local function fits(run: any, width: number): boolean
	if run.LocalRight and run.LocalRight > width then return false end
	for _, item in run.Items do
		if item.Kind == "Break" then continue end
		if not item.NativeWidth or item.X < 0 or item.X + (item.VisualWidth or item.Width) > width
			or item.LineLeft ~= 0 or item.LineRight ~= width then return false end
	end
	return true
end

local function measurementKey(key: any): boolean
	return type(key) == "string" and (key:match("^Measured") ~= nil or key:match("^Native") ~= nil
		or key:match("^TabBase") ~= nil or key == "TabMinimum")
end

local function fragmented(run: any): boolean
	-- Split records the availability of an overflow-wrap splitter, even when
	-- every word fits normally. Only actual substrings need the conservative
	-- fragment path; an enabled CSS wrapping policy alone does not change boxes.
	for _,item in run.FlowPaintState.Items do if item.WrapOwner then return true end end
	return false
end

function TextMutation.capture(box: any): any?
	local context = box.DirtyContext
	if not context or not context.Ready then return nil end
	local run = textRun(box)
	local state = run and run.FlowPaintState
	if not state or fragmented(run) or state.ConstrainedLines or not run.LocalBottom then return nil end
	local ancestor = box
	while ancestor do
		local style = ancestor.Style or {}
		if ancestor.OpacityGroup or ancestor.InlineOpacityGroups or ancestor.ScrollGui or ancestor.Scene3DRoot
			or (style.Opacity or 1) < 1 or style.TableRole == "table"
			or style.ColumnCount or style.ColumnWidth or style.ColumnHeight then return nil end
		ancestor = ancestor.LayoutParent
	end
	local items, zIndex = {}, nil
	for _, item in run.Items do
		local saved = {Kind=item.Kind, Text=item.Text, Measurements={}}
		for _, key in {"NativeWidth", "NativeHeight", "Width", "Height", "X", "Y", "Baseline", "LineBaseline", "LineIndex", "LineLeft", "LineRight", "LineTop", "LineHeight"} do
			saved[key] = item[key]
		end
		for key, value in item do if measurementKey(key) then saved.Measurements[key] = value end end
		table.insert(items, saved)
		if zIndex == nil and item.Gui then zIndex = item.Gui.ZIndex end
	end
	return {Generation=context.Generation, Width=state.Width, X=state.X, Y=state.Y,
		HeightBasis=run.HeightBasis, LayoutX=run.LayoutX, LayoutY=run.LayoutY,
		LocalRight=run.LocalRight, LocalBottom=run.LocalBottom, FirstBaseline=run.FirstBaseline,
		ContentWidth=box.ContentWidth, ContentHeight=box.ContentHeight, Items=items,
		ZIndex=zIndex, Fits=fits(run,state.Width), IndependentWidth=independentWidth(box),
		Cache=if run.CachedLayout then table.clone(run.CachedLayout) else nil}
end

function TextMutation.canKeepLayout(box: any, arrange: any, alive: () -> boolean): boolean
	local saved = box.PendingTextLayout
	box.PendingTextLayout = nil
	if not saved then return false end
	local context = box.DirtyContext
	if not context or not context.Ready or context.Generation ~= saved.Generation
		or box.ContentWidth ~= saved.ContentWidth or box.ContentHeight ~= saved.ContentHeight then return false end
	local run = textRun(box)
	-- A full/recovery pass may already have consumed the replacement run.
	if not run or run.FlowPaintState then return false end
	for index, item in run.Items do
		local previous = saved.Items[index]
		if previous and item.Kind == previous.Kind and item.Text == previous.Text then
			-- Reuse pure font bounds for an unchanged prefix ("Neuigkeiten:").
			-- WordLayout validates font/size/weight/style before using them.
			for key, value in previous.Measurements do item[key] = value end
		end
	end
	run.HeightBasis = saved.HeightBasis
	local height, width = arrange(run, saved.Width, saved.X, saved.Y, alive)
	if not alive() then return false end
	run.LayoutX, run.LayoutY = saved.LayoutX, saved.LayoutY
	run.LocalRight, run.LocalBottom = width, height
	run.CachedLayout = saved.Cache
	if run.CachedLayout then
		run.CachedLayout.Height,run.CachedLayout.Width,run.CachedLayout.Bottom=height,width,height
	end
	-- Preserve positioned paint ranking even if height changes require reflow.
	if saved.ZIndex then
		for _, item in run.Items do if item.Gui then item.Gui.ZIndex = saved.ZIndex end end
	end
	if height ~= saved.LocalBottom or run.FirstBaseline ~= saved.FirstBaseline then return false end
	if fragmented(run) then return false end
	local sameGeometry = #run.Items == 1 and #saved.Items == 1 and run.Items[1].Kind == "Word" and width == saved.LocalRight
	if sameGeometry then
		for _, key in {"NativeWidth", "NativeHeight", "Width", "Height", "X", "Y", "Baseline", "LineBaseline", "LineIndex", "LineLeft", "LineRight", "LineTop", "LineHeight"} do
			if run.Items[1][key] ~= saved.Items[1][key] then sameGeometry = false; break end
		end
	end
	if not sameGeometry then
		-- Both old and new paint must fit; shrinking existing overflow changes
		-- ancestor extents too. Alignment may move text within the retained line.
		run.LocalRight = width
		if not saved.IndependentWidth or not saved.Fits or not fits(run,saved.Width) then return false end
	end
	return true
end

return TextMutation
