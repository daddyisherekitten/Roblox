--!strict
return function(Parser: any,DOM: any,Style: any,Stylesheet: any,TextSelection: any)
	local document=Parser.parse('<p id="sample">hello</p>')
	local node=DOM.findById(document,'sample')
	local warnings={}
	local rules=Stylesheet.collect(document,function(message) table.insert(warnings,message) end,
		'::selection{background:#c4eaa5;color:#153f36} #sample::selection{background:#8555b4;color:#ffffff}')
	local style=Style.resolve(node,{},error,false)
	style.Node=node
	local parent={}
	local gui={Parent=parent,AbsolutePosition=Vector2.new(100,50),AbsoluteSize=Vector2.new(40,20),
		FontFace='mock',TextSize=16,TextXAlignment=Enum.TextXAlignment.Left,
		TextYAlignment=Enum.TextYAlignment.Top,LineHeight=1,ZIndex=1,Visible=true}
	function gui:IsA(className) return className=='TextLabel' end
	local item={Text='hello',Style=style,Gui=gui,FontFace='mock',TextSize=16,SelectionOrder=1}
	local nextGui={Parent=parent,AbsolutePosition=Vector2.new(150,50),AbsoluteSize=Vector2.new(40,20),
		FontFace='mock',TextSize=16,TextXAlignment=Enum.TextXAlignment.Left,
		TextYAlignment=Enum.TextYAlignment.Top,LineHeight=1,ZIndex=1,Visible=true}
	function nextGui:IsA(className) return className=='TextLabel' end
	local nextItem={Text='world',Style=style,Gui=nextGui,FontFace='mock',TextSize=16,SelectionOrder=2}
	local tree={CSSRules=rules,CSSStates={},TextItems={item,nextItem},TextItemsByGui={[gui]=item,[nextGui]=nextItem}}
	local selection=TextSelection.new(tree)
	assert(selection:Begin({gui},Vector2.new(100,55)))
	selection:Move({gui},Vector2.new(124,55))
	local overlay=selection.Overlays[item]
	assert(#warnings==0 and overlay and overlay.Frame.Size[1]==24)
	assert(overlay.Frame.BackgroundColor3==Color3.fromRGB(133,85,180))
	assert(overlay.Text.TextColor3==Color3.fromRGB(255,255,255))
	selection:Move({gui},Vector2.new(132,55))
	assert(selection.Overlays[item]==overlay and overlay.Frame.Size[1]==32,'Dragging reuses the selection overlay')
	selection:Move({nextGui},Vector2.new(174,55))
	local gap=selection.Gaps[item]
	assert(gap and gap.Size[1]==10 and tree.TextItemsByGui[gap]==nextItem,'Selected space fills the same-line gap')
	selection:Move({gap},Vector2.new(145,55))
	assert(selection.Gaps[item]==gap,'Dragging over the gap retains its highlight')
	selection:Finish()
	selection:Clear()
	assert(overlay.Frame.Destroyed and gap.Destroyed and tree.TextItemsByGui[overlay.Frame]==nil)
	style.UserSelect='none'
	assert(not selection:Begin({gui},Vector2.new(110,55)),'user-select:none prevents pointer selection')
	style.UserSelect='text'
	-- The fixture measures eight pixels per character at 16px and scales with size.
	assert(selection:Begin({gui},Vector2.new(100,55)))
	selection:Move({gui},Vector2.new(124,55))
	local resizedOverlay=selection.Overlays[item]
	item.TextSize=32;gui.TextSize=32;gui.AbsoluteSize=Vector2.new(80,40)
	selection:Move({gui},Vector2.new(124,55))
	assert(selection.EndPoint.Offset==2 and resizedOverlay.Frame.Size[1]==32,
		'Responsive font sizing invalidates this word\'s cached prefix widths')
	assert(resizedOverlay.Text.TextSize==32,'The retained selected text follows its source font size')
	gui.Visible=false
	assert(selection:Pick({gui},Vector2.new(110,55))==nil,'Hidden text is not selectable')
	gui.Visible=true
	selection:Clear()
	local wordFrame={Parent=parent,AbsolutePosition=Vector2.new(100,80),AbsoluteSize=Vector2.new(34,20),ZIndex=1,Visible=true}
	function wordFrame:IsA(className) return className=='Frame' end
	local glyphs={}
	for index,character in {'a','b','c'} do
		local glyphGui={Parent=wordFrame,AbsoluteSize=Vector2.new(10,20),FontFace='mock',TextSize=16,
			TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,LineHeight=1}
		table.insert(glyphs,{Text=character,X=(index-1)*12,Gui=glyphGui})
	end
	local spaced={Text='abc',Style=style,Gui=wordFrame,Glyphs=glyphs,SelectionOrder=1}
	local spacedTree={CSSRules=rules,CSSStates={},TextItems={spaced},TextItemsByGui={[wordFrame]=spaced}}
	local spacedSelection=TextSelection.new(spacedTree)
	assert(spacedSelection:Begin({glyphs[1].Gui},Vector2.new(100,85)),'Letter-spaced glyphs are selectable')
	spacedSelection:Move({glyphs[3].Gui},Vector2.new(124,85))
	local spacedOverlay=spacedSelection.Overlays[spaced]
	assert(spacedOverlay and spacedOverlay.Frame.Size[1]==24 and spacedOverlay.Glyphs[1].Visible and spacedOverlay.Glyphs[2].Visible)
	for _,glyph in glyphs do glyph.Gui.TextSize=24 end
	spacedSelection:Move({glyphs[3].Gui},Vector2.new(124,85))
	assert(spacedOverlay.Glyphs[1].TextSize==24,'Retained glyph selections also follow responsive typography')
	spacedSelection:Destroy()
	assert(spacedOverlay.Frame.Destroyed)
	selection:Destroy()
	local invalidVisibleReads=0
	local playerGui={};function playerGui:IsA(_)return false end
	local screen=setmetatable({Enabled=true,Parent=playerGui},{__index=function(_,key)
		if key=='Visible'then invalidVisibleReads+=1;error('Visible is not a valid member of ScreenGui')end
		return nil
	end})
	function screen:IsA(kind)return kind=='ScreenGui'or kind=='LayerCollector'end
	local ancestor={Visible=true,Parent=screen};function ancestor:IsA(kind)return kind=='Frame'or kind=='GuiObject'end
	gui.Parent=ancestor;nextGui.Parent=ancestor
	local hierarchy=TextSelection.new(tree)
	assert(hierarchy:Pick({gui},Vector2.new(110,55))~=nil,'Text under an enabled ScreenGui remains selectable')
	screen.Enabled=false;assert(hierarchy:Pick({gui},Vector2.new(110,55))==nil,'A disabled LayerCollector suppresses selection')
	screen.Enabled=true;ancestor.Visible=false;assert(hierarchy:Pick({gui},Vector2.new(110,55))==nil,'A hidden GuiObject ancestor suppresses selection')
	ancestor.Visible=true;assert(hierarchy:Begin({gui},Vector2.new(100,55)),'Selection works again after ancestors become visible')
	hierarchy:Move({gui},Vector2.new(132,55));assert(hierarchy.Overlays[item]~=nil,'Actual visible hierarchy paints a selection')
	hierarchy:Destroy();assert(invalidVisibleReads==0,'ScreenGui is never asked for the GuiObject-only Visible member')
	print('Text selection: scoped colors, word gaps, letter-spaced glyphs, overlay reuse and cleanup passed')
end
