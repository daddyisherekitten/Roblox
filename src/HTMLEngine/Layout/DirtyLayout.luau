--!strict
-- Reuse final flow results only for unchanged, independent subtrees.
-- Special passes can reuse closed, unchanged branches while their dependent
-- descendants retain the ordinary path whenever the branch itself changes.
local DirtyLayout = {}
local AnchorPosition=require(script.Parent.Parent.CSS.AnchorPosition)
local WritingMode=require(script.Parent.Parent.CSS.WritingMode)

local function attach(tree: any, existing: any?): any
	local context = existing or {Generation=0, Ready=false, Active=false, Owners={}, Dirty={}}
	-- Rebuilding a text run changes ownership, not the cached geometry of other
	-- branches. Drop obsolete item references while retaining the generation.
	context.Owners = {}
	local function visit(box: any, parent: any, dependent: boolean): (boolean, boolean, boolean, boolean)
		local s = box.Style or {}
		local special = s.TableRole == "table" or box.ScrollGui ~= nil or box.OpacityGroup ~= nil or box.InlineOpacityGroups ~= nil
			or (s.Opacity or 1) < 1 or (s.Position ~= nil and s.Position ~= "static") or s.ZIndex ~= nil
		box.DirtyContext, box.LayoutParent = context, parent
		context.Owners[box] = box
		if box.ImageItem then context.Owners[box.ImageItem] = box end
		for _, item in box.Items or {} do context.Owners[item] = box end
		local contains = special
		local positioned = (s.Position ~= nil and s.Position ~= "static") or s.ZIndex ~= nil
		local fixed = s.Position=="fixed" or AnchorPosition.defaultName(s)~=nil or s.HasAnchorFunctions==true
		local heightDependent=WritingMode.vertical(s)and(box.Kind=='Words'or s.Height==nil or s.Height.Intrinsic=='fit-content')
		for _,field in {'Height','MinHeight','MaxHeight'}do if s[field]and s[field].Percent then heightDependent=true;break end end
		for _, child in box.AllChildren or box.Children or {} do
			local childSpecial, childPositioned, childFixed, childHeightDependent = visit(child, box, dependent or special or s.ColumnCount~=nil or s.ColumnWidth~=nil or s.ColumnHeight~=nil)
			contains, positioned = contains or childSpecial, positioned or childPositioned
			fixed = fixed or childFixed
			heightDependent=heightDependent or childHeightDependent
		end
		-- A relative container owns the containing block of its absolute descendants.
		-- Scroll/opacity branches with external positioning dependencies stay conservative.
		local closed = s.Position == "relative" or (special and not positioned)
		-- Grid/flex items are reusable once their actual sizing inputs match.
		-- Track/line resolution still runs in the parent; it supplies those inputs.
		local subgrid = (s.GridColumns and s.GridColumns.Subgrid) or (s.GridRows and s.GridRows.Subgrid)
		box.CanReuseLayout = not dependent and not subgrid and (not contains or closed)
		box.CanTranslateTable = s.TableRole == "table" and not positioned
		box.CanTranslateLayout = not contains and not positioned
		box.UsesHeightBasis=heightDependent
		-- A relative subtree closes ordinary absolute-position dependencies. Its
		-- unchanged parent can retain intrinsic probes; the positioning pass still
		-- checks global coordinates before reusing positioned descendants. Fixed
		-- and external anchor dependencies remain conservative.
		return contains and not(s.Position=="relative" and not fixed), positioned, fixed, heightDependent
	end
	visit(tree, nil, false)
	return context
end

function DirtyLayout.refresh(tree: any)
	local c = tree.DirtyContext
	if not c then return end
	assert(not c.Active, "Layout ownership changes wait for the current pass")
	attach(tree, c)
end

function DirtyLayout.begin(tree: any, items: any?): any
	local c = tree.DirtyContext or attach(tree)
	local partial = c.Ready and items ~= nil and next(items) ~= nil
	local dirty = {}
	local function descendants(box)
		dirty[box]=true
		for _,child in box.AllChildren or box.Children or {} do descendants(child) end
	end
	if partial then
		for item, reason in items do
			local owner = c.Owners[item]
			if not owner then partial = false; break end
			-- A box style change can alter its shared inline style without changing
			-- available width (font size is one example). Its descendants are dirty.
			-- Individual controls retain the narrower owner/ancestor invalidation.
			-- Text replacement already rebuilt its runs. Their fresh/premeasured
			-- geometry can be reused; an unchanged child is not a style invalidation.
			if item==owner and reason ~= "text" and reason ~= "children" then descendants(owner) end
			while owner do dirty[owner] = true; owner = owner.LayoutParent end
		end
	end
	if not partial then c.Generation += 1 end
	c.Dirty, c.Reuse, c.Active = dirty, partial, true
	c.ReusedRoots = {}
	c.Stats = {Mode=if partial then "partial" else "full", Recomputed=0, Reused=0, PositionReused=0, OpacityReused=0}
	return c.Stats
end

function DirtyLayout.rootPass(tree: any)
	local c = tree.DirtyContext
	if c and c.Active then c.Stats.Recomputed += 1 end
end

-- Only scalar, understood sizing inputs are cacheable. Float flows, table
-- contexts and other mutable dependency objects retain their ordinary path.
local sizingFields = {FlexItem=true,ContentWidth=true,ContentHeight=true,HeightBasis=true,QuirksMode=true,QuirksHeightBasis=true,
	SpacingWidth=true,MainAxis=true,MainSize=true,IgnoreMainLimits=true,FloatWidth=true}
local function cacheableSizing(sizing: any?): boolean
	for key, value in sizing or {} do
		if not sizingFields[key] or (type(value) ~= "number" and type(value) ~= "string" and type(value) ~= "boolean") then return false end
	end
	return true
end
local function sameSizing(a: any?, b: any?): boolean
	for key, value in a or {} do if not b or b[key] ~= value then return false end end
	for key, value in b or {} do if not a or a[key] ~= value then return false end end
	return true
end

-- Intrinsic/probe results are separate from placed geometry. Returning a
-- cached probe must never restore an old stretched size onto a live GUI.
function DirtyLayout.measure(box: any, tag: string, available: number, inputs: any?, compute: () -> any, alive: () -> boolean): any
	local c = box.DirtyContext
	if not c or not c.Active or not box.CanReuseLayout or not cacheableSizing(inputs) then return compute() end
	local measurements = box.LayoutMeasurements
	local cached = measurements and measurements[tag]
	if c.Reuse and not c.Dirty[box] and cached and cached.Generation == c.Generation
		and cached.Available == available and sameSizing(cached.Inputs,inputs)
		and (cached.QuirksMode==true)==(box.QuirksMode==true) and cached.QuirksHeightBasis==box.QuirksHeightBasis
		and (cached.LegacyLineHeight==true)==(box.LegacyLineHeight==true)then
		c.Stats.MeasurementReused = (c.Stats.MeasurementReused or 0) + 1
		return cached.Result
	end
	local result = compute()
	if alive() then
		measurements = box.LayoutMeasurements or {}; box.LayoutMeasurements = measurements
		measurements[tag] = {Generation=c.Generation,Available=available,Inputs=if inputs then table.clone(inputs) else nil,Result=result,
			QuirksMode=box.QuirksMode,QuirksHeightBasis=box.QuirksHeightBasis,LegacyLineHeight=box.LegacyLineHeight}
	end
	return result
end

function DirtyLayout.get(box: any, available: number, x: number, y: number, sizing: any?, alive: (() -> boolean)?): any
	local c = box.DirtyContext
	if not c or not c.Active then return nil end
	local cached = box.CachedLayout
	if c.Reuse and box.CanReuseLayout and not c.Dirty[box] and cacheableSizing(sizing) and cached and sameSizing(cached.Sizing,sizing)
		and cached.Generation == c.Generation and cached.Available == available and (not box.UsesHeightBasis or cached.HeightBasis == box.HeightBasis)
		and (cached.QuirksMode==true)==(box.QuirksMode==true) and cached.QuirksHeightBasis==box.QuirksHeightBasis
		and (cached.LegacyLineHeight==true)==(box.LegacyLineHeight==true)
		and ((cached.X == x and cached.Y == y) or box.CanTranslateTable
			or (box.CanTranslateLayout and (box.Kind ~= "Words" or box.TranslateLayout ~= nil))) then
		if cached.X ~= x or cached.Y ~= y then
			-- Independent branches keep descendant geometry in local coordinates.
			if box.Kind == "Words" then
				if not box.TranslateLayout(x,y,alive or function() return true end) then return nil end
			else
				box.LayoutX+=x-cached.X; box.LayoutY+=y-cached.Y
				box.PaintX,box.PaintY=box.LayoutX,box.LayoutY
				if not box.LayoutProbe then box.Gui.Position=UDim2.fromOffset(box.LayoutX,box.LayoutY) end
				-- A translated transformed surface needs a new untransformed anchor.
				box.TransformBaseX,box.TransformBaseY=box.LayoutX,box.LayoutY
			end
			cached.X,cached.Y=x,y
		end
		c.Stats.Reused += 1
		c.ReusedRoots[box] = true
		return cached
	end
	DirtyLayout.touch(box)
	c.Stats.Recomputed += 1
	return nil
end

-- An enclosing cache hit covers all descendants until one of the later passes
-- actually changes geometry inside that branch.
function DirtyLayout.wasReused(box: any): boolean
	local c = box.DirtyContext
	if not c or not c.Active or not c.Reuse then return false end
	while box do
		if c.ReusedRoots[box] then return true end
		box = box.LayoutParent
	end
	return false
end

function DirtyLayout.touch(box: any)
	local c = box.DirtyContext
	if not c or not c.Active then return end
	while box do c.ReusedRoots[box] = nil; box = box.LayoutParent end
end

function DirtyLayout.invalidate(box: any)
	local c = box.DirtyContext
	if not c or not c.Active then return end
	DirtyLayout.touch(box)
	while box do c.Dirty[box] = true; box = box.LayoutParent end
end

function DirtyLayout.put(box: any, available: number, x: number, y: number, sizing: any?, height: number, width: number, bottom: number)
	local c = box.DirtyContext
	if not c or not c.Active then return end
	if not cacheableSizing(sizing) or not box.CanReuseLayout then box.CachedLayout = nil; return end
	box.CachedLayout = {Generation=c.Generation, Available=available,HeightBasis=box.HeightBasis, X=x, Y=y, Height=height, Width=width, Bottom=bottom,
		QuirksMode=box.QuirksMode,QuirksHeightBasis=box.QuirksHeightBasis,
		LegacyLineHeight=box.LegacyLineHeight,
		Sizing=if sizing then table.clone(sizing) else nil}
end

function DirtyLayout.finish(tree: any, success: boolean)
	local c = tree.DirtyContext
	if not c then return end
	c.Active, c.Ready = false, success
	table.clear(c.Dirty)
	table.clear(c.ReusedRoots)
	if not success then c.Generation += 1 end
end

return DirtyLayout
