--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local DOM = require(script.Parent.Parent.DOM.Node)
local Metrics = require(script.Parent.Parent.Layout.FontMetrics)
local Disclosure = {}
-- Pixel-frame fallback when EditableImage is unavailable.
local ARROW_ROWS = {
	{0,146,18}, {1,238,110}, {3,202,74}, {5,166,38},
	{7,131,2}, {8,223,95}, {8,250,123}, {7,158,30},
	{5,194,66}, {3,230,102}, {2,138,9}, {0,174,45},
}

function Disclosure.new(node: any): any
	local summary
	for _,child in node.Children do if ElementNames.htmlName(child) == "summary" then summary=child; break end end
	if not summary then
		summary=DOM.element("summary",{})
		DOM.append(summary,DOM.text("Details"))
		summary.Parent=node -- Render-only fallback; the source DOM is preserved.
	end
	local body=DOM.element("div",{})
	body.Parent=node
	for _,child in node.Children do if child ~= summary then table.insert(body.Children,child) end end
	return {Node=node,SummaryNode=summary,BodyNode=body,Open=node.Attributes.open ~= nil}
end

function Disclosure.marker(d: any, parent: any, factory: any, icons: any?): any
	local content=icons and icons:Get(d.Open)
	local gui=factory.create("Frame",parent,{Name="DisclosureMarker",BackgroundTransparency=1,Rotation=if content then 0 else (if d.Open then 90 else 0)})
	local image=if content then factory.create("ImageLabel",gui,{
		Name="DisclosureIcon",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ImageContent=content,
	}) else nil
	local pixels={}
	local function run(x: number,y: number,width: number,coverage: number)
		if width == 0 or coverage == 0 then return end
		local pixel=factory.create("Frame",gui,{Name="ArrowRow",BorderSizePixel=0,
			Position=UDim2.new(x/12,0,y/12,0),Size=UDim2.new(width/12,0,1/12,0),BackgroundTransparency=1-coverage/255})
		table.insert(pixels,{Gui=pixel,Alpha=coverage/255})
	end
	if not image then for i,row in ARROW_ROWS do
		run(0,i-1,row[1],255)
		run(row[1],i-1,1,row[2])
		run(row[1]+1,i-1,1,row[3])
	end end
	local marker={Kind="disclosure",Gui=gui}
	function marker:SetOpen(open: boolean)
		if image then image.ImageContent=icons:Get(open)
		else gui.Rotation=if open then 90 else 0 end
	end
	function marker:Repaint(style: any)
		local visible=style.Visibility ~= "hidden"
		if gui.Visible ~= visible then gui.Visible=visible end
		local alpha=style.ColorAlpha or 1
		if self.PaintColor==style.Color and self.PaintAlpha==alpha then return end
		if image then
			image.ImageColor3=style.Color
			image.ImageTransparency=1-alpha
		else
		for _,pixel in pixels do
			pixel.Gui.BackgroundColor3=style.Color
			pixel.Gui.BackgroundTransparency=1-pixel.Alpha*alpha
		end
		end
		self.PaintColor,self.PaintAlpha=style.Color,alpha
	end
	function marker:Measure(style: any): number
		local metrics=Metrics.resolve(style)
		local size=math.max(4,math.round(style.FontSize*12/18))
		self.Width,self.Height=size*19/12,metrics.TextSize
		return size
	end
	function marker:Arrange(style: any,baseline: number,left: number): boolean
		local size=self:Measure(style)
		gui.Position=UDim2.fromOffset(left,baseline-size)
		gui.Size=UDim2.fromOffset(size,size)
		self:Repaint(style)
		return true
	end
	d.Marker=marker
	return marker
end

function Disclosure.apply(d: any)
	if not d.Body then return end -- Initially skipped details build on first reveal.
	if d.Open and d.PaintedOpen==false and d.QueueReveal then d.QueueReveal(d)end
	if not d.Open then d.Body.LayoutRevealPending=nil end
	d.Body.Gui.Visible=d.Open and not d.Body.LayoutRevealPending
	d.PaintedOpen=d.Open
	d.Box.Children=if d.Box.HiddenContents then d.Box.SkippedChildren
		else if d.Open then d.Box.AllChildren else (if d.Summary then {d.Summary} else {})
	if d.Marker then d.Marker:SetOpen(d.Open) end
end

function Disclosure.toggle(d: any)
	d.Open=not d.Open
	d.Node.Attributes.open=if d.Open then "" else nil
	Disclosure.apply(d)
end

function Disclosure.hidden(node: any, disclosures: any?): boolean
	local branch,ancestor=node,node.Parent
	while ancestor do
		local d=if disclosures then disclosures[ancestor] else nil
		if d and not d.Open and branch ~= d.SummaryNode then return true end
		branch,ancestor=ancestor,ancestor.Parent
	end
	return false
end

return Disclosure
