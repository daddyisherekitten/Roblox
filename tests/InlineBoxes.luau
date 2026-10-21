--!strict
return function(Parser: any,DOM: any,loadRenderTree: any,loadWordLayout: any,loadBlockLayout: any)
	local renderer=loadRenderTree({create=function(className,parent,properties)
		local gui=table.clone(properties)
		gui.ClassName,gui.Parent=className,parent
		return gui
	end})
	local overrides={['Layout/FontProfiles']={face=function(font) return font end},
		['Layout/TextMeasure']={measure=function(text,_,size) return {X=#text*6,Y=size} end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local layout=loadBlockLayout(overrides)
	local document=Parser.parse([[<style>kbd{border:1px solid #a5b8ac;border-bottom-width:3px;padding:1px 5px;border-radius:3px}</style><p>Press <kbd id="key">Tab</kbd> now.</p>]])
	local diagnostics={}
	local tree=renderer.build(document,{},function(message) table.insert(diagnostics,message) end)
	local key=tree.NodeBoxes[DOM.findById(document,'key')]
	assert(key and key.Style.Display=='inline-block' and key.Corner and key.InsetEdges,'Inline edges create a painted box')
	assert(key.Style.BorderSizes[1]==1 and key.Style.BorderSizes[3]==3)
	assert(key.Style.Padding[2]==5 and key.Style.Padding[4]==5)
	assert(#diagnostics==0,'Valid inline borders and padding must not emit unsupported-style warnings')
	local height=layout.arrange(tree,320,0,0,function() return true end)
	assert(height>0 and key.OuterWidth>=30 and key.OuterHeight>16,'Inline box edges contribute to measured size')
	local atomic
	local pending={tree}
	while #pending>0 do
		local box=table.remove(pending)
		for _,item in box.Items or {} do if item.InlineBox==key then atomic=item end end
		for _,child in box.Children or {} do table.insert(pending,child) end
	end
	assert(atomic and math.abs(atomic.Width-key.OuterWidth)<.01,'The surrounding line reserves the box width')
	local allocations=key.Gui
	layout.arrange(tree,180,0,0,function() return true end)
	assert(key.Gui==allocations and key.OuterWidth>=30,'Resizing reuses the decorated inline box')
	local spaced=renderer.build(Parser.parse('<p>Before <span id="spaced" style="margin-left:7px">Gap</span> after.</p>'),{},error)
	layout.arrange(spaced,320,0,0,function()return true end)
	local spacing=assert(spaced.NodeBoxes[DOM.findById(spaced.Document or spaced.Node,'spaced')])
	assert(spacing.Style.Margin[4]==7 and spacing.Style.AtomicInline,'Horizontal inline margins own a measured box instead of disappearing into a text fragment')
	local item;local stack={spaced}
	while #stack>0 do
		local current=table.remove(stack)
		for _,candidate in current.Items or {}do if candidate.InlineBox==spacing then item=candidate end end
		for _,child in current.Children or {}do table.insert(stack,child)end
	end
	assert(item and math.abs(item.Width-spacing.OuterWidth-7)<.001,'The line reserves the left margin separately from the painted width')
	print('Inline boxes: kbd border, uneven bottom edge, padding, radius, line width, warnings and resize passed')
end
