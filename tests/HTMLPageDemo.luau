--!strict
-- Only the current visual flex suite; earlier features retain their independent tests.
return function(html: string, Parser: any, loadRenderTree: any)
	local document = Parser.parse(html)
	assert(#document.Diagnostics == 0)
	local renderer = loadRenderTree({create = function(_, _, props) return table.clone(props) end, modifier = function(_, _, props) return table.clone(props) end})
	local tree = renderer.build(document, {}, error, nil, nil, nil, function(src) return if src == "landschaft.png" then "rbxassetid://94339162936897" else nil end)
	local boxes, pending, flex = {}, {tree}, 0
	while #pending > 0 do
		local box = table.remove(pending)
		if box.Node and box.Node.Attributes then
			if box.Node.Attributes.id then boxes[box.Node.Attributes.id] = box end
			if box.Style.Display == 'flex' then flex += 1 end
		end
		for _, child in box.Children or {} do table.insert(pending, child) end
	end
	if boxes['stress-svg'] then
		local counts={}
		local function visit(node)
			if node.Kind=='Element' then counts[node.Name]=(counts[node.Name] or 0)+1 end
			for _,child in node.Children or {} do visit(child) end
		end
		visit(document)
		assert(#tree.SVGItems==1 and #tree.Controls==0)
		assert(counts.svg==2 and counts.use==9 and counts.filter==3)
		assert(counts.linearGradient==4 and counts.radialGradient==1 and counts.pattern==1)
		assert(counts.clipPath==1 and counts.mask==1 and counts.marker==1 and counts.textPath==1)
		assert(counts.feDropShadow==1 and counts.feGaussianBlur==1 and counts.feTurbulence==1 and counts.feDisplacementMap==1)
		print('HTML page demo: supported SVG stress document and embedded renderer target passed')
		return
	end
	assert(flex == 16 and #tree.ImageItems == 17)
	local filters=0
	for _,item in tree.ImageItems do if #item.Style.Filter.Steps>0 then filters+=1 end end
	assert(filters==13 and boxes['image-filters'],'Demo34 contains color filters, chains, blur and drop shadows')
	assert(boxes['preview-options'].Legend and boxes['preview-options'].Legend.Node.Name == 'legend')
	local typed={}
	for _,c in tree.Controls do typed[c.Node.Attributes.id or '']=c end
	assert(typed['preview-email'].Type == 'email' and typed['preview-url'].Type == 'url' and typed['preview-message'].MinLength == 5)
	assert(typed['preview-email'].Node.Attributes.autofocus ~= nil)
	assert(boxes['row-gap'].Style.Gap[2] == 12 and boxes['row-gap'].Style.AlignItems == 'stretch')
	assert(boxes['row-alignment'].Style.JustifyContent == 'space-between' and boxes['row-alignment'].Style.AlignItems == 'center')
	assert(boxes.column.Style.FlexDirection == 'column' and boxes.column.Style.Gap[1] == 10)
	assert(boxes.column.Style.JustifyContent == 'center' and boxes.column.Style.AlignItems == 'flex-end')
	assert(#boxes.column.Children == 3 and boxes.column.Children[1].Style.Width == nil)
	assert(boxes.fixed.Style.FlexGrow == 0 and boxes.fixed.Style.FlexShrink == 0 and boxes.fixed.Style.Width.Value == 72)
	assert(boxes['grow-one'].Style.FlexGrow == 1 and boxes['grow-one'].Style.FlexBasis.Value == 120)
	assert(boxes['grow-two'].Style.FlexGrow == 2 and boxes['grow-two'].Style.FlexShrink == 1 and boxes['grow-two'].Style.FlexBasis.Value == 120)
	assert(boxes.wrap.Style.FlexWrap == 'wrap' and boxes.wrap.Style.AlignContent == 'center')
	assert(boxes.wrap.Style.Gap[1] == 8 and boxes.wrap.Style.Gap[2] == 12 and #boxes.wrap.Children == 4)
	assert(boxes.wrap.Children[1].Style.FlexBasis.Value == 160)
	assert(boxes['item-controls'].Style.FlexDirection == 'row-reverse')
	assert(boxes['control-a'].Style.Order == 1 and boxes['control-a'].Style.AlignSelf == 'flex-end')
	assert(boxes['control-b'].Style.Order == -1 and boxes['control-b'].Style.AlignSelf == 'center')
	assert(boxes['control-column'].Style.FlexDirection == 'column-reverse')
	assert(boxes['auto-margins'].Style.FlexDirection == 'row' and boxes['auto-margins'].Style.FlexWrap == 'wrap')
	assert(boxes['auto-end'].Style.MarginAuto[1] and boxes['auto-end'].Style.MarginAuto[4])
	assert(boxes.baselines.Style.AlignItems == 'baseline' and boxes['baseline-large'].Style.AlignSelf == 'baseline')
	assert(boxes['baseline-small'].Style.FontSize == 18 and boxes['baseline-medium'].Style.FontSize == 28 and boxes['baseline-large'].Style.FontSize == 40)
	assert(boxes['position-card'].Style.Position == 'relative' and boxes['position-badge'].Style.Position == 'absolute')
	assert(boxes['position-label'].Style.Insetleft.Value == 8 and boxes['position-badge'].Style.ZIndex == 2 and boxes['position-under'].Style.ZIndex == 1)
	assert(boxes['position-badge'].Style.Insettop.Value == 8 and boxes['position-badge'].Style.Insetleft == nil)
	assert(boxes['simple-features'].Style.Gap[1] == 8 and boxes['simple-features'].Style.Gap[2] == 12)
	assert(boxes['simple-start'].Style.TextAlign == 'start' and boxes['simple-end'].Style.TextAlign == 'end')
	assert(boxes['simple-start'].Style.BorderSize == 1 and boxes['simple-end'].Style.BorderSize == 3 and boxes['simple-italic'].Style.BorderSize == 5)
	assert(not html:find('HTML-Kurztest', 1, true) and not html:find('data:image', 1, true))
	for id, kind in {['counter-zero'] = 'decimal-leading-zero', ['counter-alpha'] = 'lower-alpha', ['counter-upper-alpha'] = 'upper-alpha', ['counter-roman'] = 'lower-roman', ['counter-upper-roman'] = 'upper-roman'} do
		assert(boxes[id].Children[1].Marker.Kind == kind and #boxes[id].Children == 2)
	end
	assert(boxes['scroll-text'].ScrollGui and boxes['scroll-text'].Style.OverflowY == 'auto')
	assert(boxes['scroll-cards'].ScrollGui and boxes['scroll-cards'].Style.OverflowX == 'scroll' and boxes['scroll-cards'].Style.OverflowY == 'hidden')
	for side, size in {2, 4, 6, 8} do assert(boxes['border-sides'].Style.BorderSizes[side] == size) end
	for side, kind in {'dashed', 'dotted', 'double', 'solid'} do assert(boxes['border-sides'].Style.BorderSides[side].Style == kind) end
	assert(boxes['outline-test'].Outline and boxes['outline-test'].Style.OutlineOffset == 5)
	assert(boxes['ellipsis-test'].Style.TextOverflow == 'ellipsis' and boxes['ellipsis-test'].Style.WhiteSpace == 'nowrap')
	assert(boxes['contact-test'].Style.FontStyle == 'italic' and boxes['contact-test'].Style.BorderStyle == 'outset')
	assert(boxes['description-test'].Style.BorderStyle == 'groove' and boxes['word-wrap-test'].Style.OverflowWrap == 'break-word')
	assert(boxes['figure-test'].Style.BorderStyle == 'ridge' and boxes['figure-test'].Style.Margin[4] == 40)
	assert(boxes['figure-test'].Style.BackgroundAlpha == .15)
	assert(boxes['inside-list'].Style.ListStylePosition == 'inside')
	assert(boxes['percent-spacing'].Style.Padding[1].Percent and boxes['font-short'].Style.FontWeight == 700)
	assert(boxes['opacity-test'].OpacityGroup and boxes['block-image'].Kind == 'BlockImage')
	assert(#boxes['flex-images'].Children == 2 and boxes['scroll-ellipsis'].ScrollGui)
	assert(boxes['relative-units'].Style.FontSize == 25 and boxes['relative-units'].Style.Gap[2] == 10)
	assert(boxes['relative-em'].Style.FontSize == 30 and boxes['relative-em'].Style.Padding[1] == 15)
	assert(boxes['relative-rem'].Style.FontSize == 20 and boxes['relative-rem'].Style.Padding[1] == 10)
	assert(#tree.Controls == 16 and boxes['preview-result'].ImageItem.Control.Type == 'output')
	assert(#boxes['table-basic'].TableRows == 4 and boxes['table-basic'].TableGrid.Columns == 3)
	assert(#boxes['table-basic'].TableCaptions == 1 and boxes['table-basic'].TableCaptions[1].Style.CaptionSide == 'top')
	assert(boxes['table-empty'].TableCaptions[1].Style.CaptionSide == 'bottom' and boxes['table-empty'].Style.EmptyCells == 'hide')
	assert(boxes['table-empty'].TableGrid.Entries[3].Cell.Style.EmptyCells == 'show')
	assert(boxes['table-basic'].CollapsedBorders and boxes['table-basic'].Style.BorderCollapse == 'collapse')
	assert(boxes['table-basic'].Style.TableLayout == 'fixed' and #boxes['table-basic'].TableColumns == 3)
	assert(boxes['table-basic'].TableColumns[1].Width.Value == 100 and boxes['table-basic'].TableColumns[2].Width.Percent)
	local cursorKinds={}
	for _,entry in boxes['cursor-test'].TableGrid.Entries do
		local value=entry.Cell.Style.Cursor
		cursorKinds[if type(value) == 'table' then 'url' else value]=true
	end
	for _,kind in {'auto','default','pointer','text','none','help','crosshair','grab','grabbing','copy','alias','cell','vertical-text','url',
		'not-allowed','no-drop','move','all-scroll','zoom-in','zoom-out','n-resize','s-resize','e-resize','w-resize',
		'ne-resize','nw-resize','se-resize','sw-resize','ns-resize','ew-resize','nesw-resize','nwse-resize','col-resize','row-resize'} do assert(cursorKinds[kind],kind) end
	assert(boxes['table-basic'].TableGrid.Entries[1].RowSpan == 2 and boxes['table-basic'].TableGrid.Entries[2].ColSpan == 2)
	assert(boxes['css-table'].Style.Direction=='rtl' and boxes['css-table'].Style.Height.Percent and #boxes['css-table'].TableRows==2)
	assert(#boxes['table-tracks'].TableRows==3 and boxes['table-tracks'].TableRows[3].Implicit)
	assert(#boxes['table-tracks'].RowTracks.Indices==2 and #boxes['table-tracks'].ColumnTracks.Indices==2)
	local disclosure=tree.Disclosures[boxes['preview-details'].Node]
	assert(not disclosure.Open and disclosure.Control.Type == 'summary' and not disclosure.Body.Gui.Visible)
	local textareas=0
	for _,c in tree.Controls do if c.Type == 'textarea' then textareas+=1; assert(c.Item.ResizeGrip and c.LayoutStyle.Resize == 'both') end end
	assert(textareas == 1)
	local gauges=0
	for _,c in tree.Controls do
		if c.DisplayOnly then
			gauges+=1
			assert(if c.Type == 'progress' then c.Value == '60' and c.Gauge.Ratio == .6 else c.Value == '70' and c.Gauge.Quality == 'suboptimal')
		end
	end
	assert(gauges == 2)
	local numbers=0
	for _,c in tree.Controls do if c.Type == 'number' then numbers+=1; assert(c.Value == '2' and c.Number.Min == 1 and c.Number.Max == 10) end end
	assert(numbers == 1)
	local range
	for _,c in tree.Controls do if c.Node.Attributes.id == 'preview-volume' then range=c end end
	assert(range.Type == 'range' and range.Value == '50' and range.Range.Min == 0 and range.Range.Max == 100 and range.Range.Step == 1)
	local selects=0
	for _,c in tree.Controls do
		if c.Type == 'select' then
			selects+=1
			assert(c.Node.Attributes.id == 'preview-mode' and #c.Options == 3 and c.Value == 'standard' and c.Options[3].Disabled)
		end
	end
	assert(selects == 1)
	print('HTML page demo: 29 compact examples, including the interactive form')
end
