--!strict
return function(Parser: any, DOM: any, Style: any, loadRenderTree: any, loadWordLayout: any, loadBlockLayout: any, Native: any)
 local fixtureElement=require('DOM/Node').element
	local function resolve(css, parent, warn)
		return Style.resolve(fixtureElement("div",{style = css}), parent or {}, warn or function(message) error(message) end)
	end
	for _, mode in {"normal", "nowrap", "pre", "pre-wrap", "pre-line", "break-spaces"} do
		assert(resolve("", resolve("white-space: " .. mode)).WhiteSpace == mode)
	end
	assert(resolve("white-space: NORMAL", resolve("white-space: pre")).WhiteSpace == "normal")
	for _,collapse in {'collapse','discard','preserve','preserve-breaks','preserve-spaces','break-spaces'}do
		for _,wrap in {'wrap','nowrap'}do
			local axes=resolve('white-space: '..wrap..' '..collapse)
			assert(axes.WhiteSpaceCollapse==collapse and axes.TextWrapMode==wrap,'Whitespace shorthand accepts independent axes in either order')
			local inherited=resolve('',axes);assert(inherited.WhiteSpaceCollapse==collapse and inherited.TextWrapMode==wrap)
			local longhands=resolve('white-space:normal;white-space-collapse:'..collapse..';text-wrap-mode:'..wrap)
			assert(longhands.WhiteSpace==axes.WhiteSpace,'Longhands do not approximate preserve-spaces or preserved breaks with nowrap')
		end
	end
	assert(resolve('white-space:pre !important;text-wrap-mode:wrap').TextWrapMode=='nowrap')
	assert(resolve('white-space:pre;text-wrap-mode:wrap !important').WhiteSpace=='pre-wrap')
	assert(resolve('white-space:var(--mode);--mode:preserve-spaces nowrap').WhiteSpace=='preserve-spaces nowrap')
	assert(resolve('white-space:inherit',resolve('white-space:preserve-breaks nowrap')).WhiteSpace=='preserve-breaks nowrap')
	for _, value in {"invalid", "nowrap nowrap", "collapse preserve", "normal wrap", "nowrap preserve nowrap"} do
		local warnings = 0
		assert(resolve("white-space: nowrap; white-space: " .. value, nil, function() warnings += 1 end).WhiteSpace == "nowrap" and warnings == 1)
	end
	for _, case in {{"4", "number", 4}, {"2.5", "number", 2.5}, {"0", "number", 0}, {"32px", "px", 32}, {"0px", "px", 0}} do
		local parent = resolve("tab-size: " .. case[1])
		local child = resolve("", parent)
		assert(child.TabSize.Kind == case[2] and child.TabSize.Value == case[3] and child.TabSize ~= parent.TabSize)
	end
	assert(resolve("tab-size: 4 !important; tab-size: 2").TabSize.Value == 4)
	assert(resolve('font-size:20px;tab-size:4ex').TabSize.Value == 40,
		'Font-relative tab stops resolve to a computed pixel length')
	for _, value in {"-1", "-1px", "10%", "normal", "nan", "2 4", "100001"} do
		local warnings = 0
		assert(resolve("tab-size: 4; tab-size: " .. value, nil, function() warnings += 1 end).TabSize.Value == 4 and warnings == 1)
	end
	local labels, frames, requests = 0, 0, 0
	local renderer = loadRenderTree({create = function(class, owner, props)
		if class == "TextLabel" then labels += 1 else frames += 1 end
		local object = table.clone(props)
		object.ClassName, object.Parent = class, owner
		function object:Destroy()self.Destroyed=true end
		return setmetatable(object, {__newindex = function(target, key, value)
			assert(class ~= "Frame" or (key ~= "FontFace" and key ~= "TextSize"), "Whitespace frames are not text labels")
			rawset(target, key, value)
		end})
	end})
	local layout = loadWordLayout({
		["Layout/FontProfiles"] = {face = function(font) return font end},
		["Layout/TextMeasure"] = {measure = function(text, _, size)
			requests += 1
			return {X = if text == " " then 5 else #text * 10, Y = size}
		end},
	})
	local block = loadBlockLayout({["Layout/WordLayout"] = layout})
	local function build(html)
		return renderer.build(Parser.parse(html), {}, function(message) error(message) end, function() return "face" end)
	end
	local function run(mode, text, css)
		return build('<div style="line-height: 20px; white-space: ' .. mode .. '; ' .. (css or "") .. '">' .. text .. '</div>').Children[1].Children[1]
	end
	local function arrange(words, width) return layout.arrange(words, width or 200, 0, 0, function() return true end) end
	local function wordsIn(run)
		local result = {}
		for _, item in run.Items do if item.Kind == "Word" then table.insert(result, item) end end
		return result
	end
	local normal = run("normal", "  AA   BB\n CC\tDD  ")
	assert(#normal.Items == 4 and arrange(normal, 45) == 40)
	assert(normal.Items[2].X == 25 and normal.Items[3].LineIndex == 2)
	local nowrap = run("nowrap", "  AA   BB\n CC\tDD  ")
	local height, extent = arrange(nowrap, 45)
	assert(height == 20 and extent == 95 and #nowrap.Items == 4, "nowrap collapses whitespace but keeps all words on one line")
	local forced = run("nowrap", "AA BB<br>CC DD")
	assert(arrange(forced, 1) == 40 and forced.Items[4].LineIndex == 2, "br still forces a break in nowrap")
	local preLine = run("pre-line", "  AA  \tBB  \r\n  CC \r\n\r\n DD  ")
	assert(arrange(preLine, 200) == 80 and #preLine.Items == 7)
	local preLineWords = wordsIn(preLine)
	assert(preLineWords[1].X == 0 and preLineWords[2].X == 25 and preLineWords[3].X == 0 and preLineWords[4].LineIndex == 4)
	assert(arrange(preLine, 30) == 100, "pre-line preserves newlines and also wraps collapsed spaces")
	assert(arrange(run("pre-line", "AA<span>  </span>\n<span>  BB</span>")) == 40)
	assert(build('<div style="white-space: pre-line">  \t </div>').Children[1].Children[1] == nil)
	assert(arrange(run("pre-line", "AA\n")) == 20)
	local breakNoWrap=run('preserve-breaks nowrap','AA   BB\nCC DD')
	assert(arrange(breakNoWrap,20)==40 and wordsIn(breakNoWrap)[2].X==25 and wordsIn(breakNoWrap)[4].X==25,'nowrap disables soft wrapping while preserving newline breaks')
	local preserveSpaces=run('preserve-spaces',' AA\tBB\n CC ')
	assert(arrange(preserveSpaces,200)==20 and wordsIn(preserveSpaces)[2].X==30 and wordsIn(preserveSpaces)[3].X==60,'preserve-spaces converts tabs and LF to retained ordinary spaces')
	local discard=run('discard',' AA\tBB\n CC ')
	assert(#wordsIn(discard)==1 and wordsIn(discard)[1].Text=='AABBCC'and arrange(discard,20)==20,'discard removes whitespace without inventing break opportunities')
	local sourceStarts={};for _,span in wordsIn(discard)[1].SourceSpans do table.insert(sourceStarts,span.Start)end
	assert(table.concat(sourceStarts,',')=='1,2,4,5,8,9','Discarded whitespace leaves visible UTF-16 source offsets unchanged')
	assert(build('<div style="white-space:discard"> \t\n </div>').Children[1].Children[1]==nil,'Discard-only whitespace never creates an anonymous line')
	assert(arrange(run('preserve-breaks nowrap','\n\n'))==40,'Preserved newline-only lines remain significant with nowrap')
	local encodedCR=run('preserve-breaks nowrap','AA&#13;BB')
	assert(arrange(encodedCR,20)==20 and wordsIn(encodedCR)[2].X==25,'Encoded CR is a CSS space; raw HTML CR is normalized by the parser')
	local encodedFF=run('pre','AA&#12;BB')
	assert(arrange(encodedFF,20)==20 and wordsIn(encodedFF)[1].Text=='AA\fBB'and #wordsIn(encodedFF)[1].SourceSpans==5,'Form feed is a source control glyph, never an invented line break or CSS space')
	for _,html in {'AA<span>\f</span>BB','AA<div style="display:none">hidden</div><span>\f</span>BB'}do
		local inlineFF=run('normal',html);local text={};local source=0
		for _,word in wordsIn(inlineFF)do table.insert(text,word.Text);source+=#word.SourceSpans end
		assert(table.concat(text)=='AA\fBB'and source==5 and arrange(inlineFF)==20,'Inline FF and hidden siblings preserve a significant control glyph with its source span')
	end
	local before = labels
	local pre = run("pre", "  AA   BB\n\n CC  ")
	height, extent = arrange(pre, 20)
	local words = wordsIn(pre)
	assert(labels == before + 3, "Preserved whitespace cannot turn the line into a sentence label")
	assert(height == 60 and extent == 65 and words[1].X == 10 and words[2].X == 45 and words[2].LineIndex == 1)
	assert(words[3].X == 5 and words[3].LineIndex == 3)
	local count, allocated = requests, frames
	arrange(pre, 200)
	assert(requests == count and frames == allocated)
	local wrap = run("pre-wrap", "  AA   BB CC")
	assert(arrange(wrap, 50) == 40)
	words = wordsIn(wrap)
	assert(words[1].X == 10 and words[2].X == 0 and words[2].LineIndex == 2 and words[3].X == 25)
	local trailing = run("pre-wrap", "AA     ", "text-align: center")
	height, extent = arrange(trailing, 40)
	assert(height == 20 and trailing.Items[1].X == 0 and extent == 40, "Only overflowing pre-wrap spaces hang at the block end; fitting spaces count for alignment")
	local decoratedTrailing=run('pre-wrap','AA<span style="padding-right:10px">     </span>','text-align:center')
	height,extent=arrange(decoratedTrailing,40)
	assert(height==20 and decoratedTrailing.Items[1].X==0 and extent==55,'An inline end padding prevents preceding spaces from hanging')
	local preTrailing = run("pre", "AA  ", "text-align: center")
	arrange(preTrailing, 40)
	assert(preTrailing.Items[1].X == 5, "pre trailing spaces count for alignment")
	assert(arrange(run("pre", "\n\n")) == 40)
	assert(arrange(run("pre", "AA\n")) == 20, "A final newline does not invent another empty line")
	local spaces = run("pre", "   ")
	height, extent = arrange(spaces)
	assert(height == 20 and extent == 15)
	assert(build('<div style="white-space: normal">   </div>').Children[1].Children[1] == nil)
	local tabs = run("pre", "AA\tBB\tCC")
	arrange(tabs)
	words = wordsIn(tabs)
	assert(words[2].X == 40 and words[3].X == 80, "Tabs advance to eight-space stops, not a fixed eight-space gap")
	count = requests
	arrange(tabs, 100)
	assert(requests == count, "Tab zero and space measurements are reused on resize")
	for _, mode in {"pre", "pre-wrap"} do
		for _, case in {{15, 40}, {16, 80}, {20, 80}} do
			local nearStop = run(mode, "AA&#9;BB", "text-indent: " .. case[1] .. "px")
			arrange(nearStop)
			assert(wordsIn(nearStop)[2].X == case[2], "Tabs require half the zero width, not half the narrower space width")
		end
	end
	local tabWrap = run("pre-wrap", "AA BB\tCC")
	arrange(tabWrap, 65)
	assert(wordsIn(tabWrap)[3].X == 0 and wordsIn(tabWrap)[3].LineIndex == 2)
	for _, case in {{"4", 40}, {"2.5", 25}, {"0", 20}, {"32px", 32}, {"0px", 20}} do
		local sized = run("pre", "AA&#9;BB", "tab-size: " .. case[1])
		arrange(sized)
		assert(wordsIn(sized)[2].X == case[2], "Numeric, fractional, pixel and zero tab stops")
	end
	local inheritedTab = build('<style>div {tab-size: 3 !important}</style><div style="white-space: pre; tab-size: 4">AA<span>&#9;BB</span></div>').Children[1].Children[1]
	arrange(inheritedTab)
	assert(wordsIn(inheritedTab)[2].X == 30)
	local inlineTab = run("pre", 'AA<span style="font-size: 30px; word-spacing: 15px; tab-size: 3">&#9;BB</span>')
	arrange(inlineTab)
	assert(wordsIn(inlineTab)[2].X == 30, "Numeric tabs use block spacing, not inline spacing")
	count = requests
	arrange(inlineTab, 100)
	assert(requests == count, "The block-font tab measurement is cached per item")
	local mixedSize = run("pre", 'AAAA<span style="font-size: 40px">&#9;B</span>', "font-size: 20px; tab-size: 3")
	local mixedRequests = 0
	local mixedLayout = loadWordLayout({["Layout/TextMeasure"] = {measure = function(text, _, size)
		mixedRequests += 1
		return {X = if text == " " then (if size > 30 then 10 else 5) else #text * 10, Y = size}
	end}})
	local function arrangeMixed() mixedLayout.arrange(mixedSize, 200, 0, 0, function() return true end) end
	arrangeMixed()
	assert(wordsIn(mixedSize)[2].X == 45, "Inline font size must not change the block's numeric tab grid")
	count = mixedRequests
	arrangeMixed()
	assert(mixedRequests == count)
	mixedSize.Style.FontSize = 40
	arrangeMixed()
	assert(wordsIn(mixedSize)[2].X == 60, "Changing the block font size updates tab stops")
	for _, mode in {"normal", "nowrap", "pre-line"} do
		local collapsedTab = run(mode, "AA\tBB", "tab-size: 0")
		arrange(collapsedTab)
		assert(wordsIn(collapsedTab)[2].X == 25, "tab-size only affects preserved tabs")
	end
	local broken = run("break-spaces", "AA   BB")
	height, extent = arrange(broken, 30)
	words = wordsIn(broken)
	assert(height == 40 and extent == 30 and words[2].X == 5 and words[2].LineIndex == 2)
	assert(broken.Items[2].X == 20 and broken.Items[3].X == 25 and broken.Items[4].X == 0)
	local unbreakableSpace = run("break-spaces", "AA BB")
	height, extent = arrange(unbreakableSpace, 20)
	assert(height == 40 and extent == 25 and unbreakableSpace.Items[2].LineIndex == 1, "No break before the first preserved space")
	local onlySpaces = run("break-spaces", "     ")
	height, extent = arrange(onlySpaces, 10)
	assert(height == 60 and extent == 10 and onlySpaces.Items[5].LineIndex == 3, "Space-only lines wrap and retain height")
	count = requests
	arrange(onlySpaces, 20)
	assert(requests == count and onlySpaces.Items[5].LineIndex == 2)
	local breakTrailing = run("break-spaces", "AA  ", "text-align: center; text-decoration: underline")
	height, extent = arrange(breakTrailing, 40)
	assert(height == 20 and breakTrailing.Items[1].X == 5 and extent == 35)
	assert(#breakTrailing.Items[2].DecorationFrames == 1)
	local breakTabs = run("break-spaces", "AA\t\tBB", "tab-size: 4")
	assert(arrange(breakTabs, 40) == 40 and wordsIn(breakTabs)[2].X == 20)
	local splitBreak = run("break-spaces", "AA <span>  BB</span>")
	assert(arrange(splitBreak, 30) == 40 and wordsIn(splitBreak)[2].X == 5)
	local zeroWidth = run("break-spaces", "  ")
	assert(arrange(zeroWidth, 0) == 40, "A space wider than the line overflows without an infinite wrap loop")
	local mixed = build('<div style="line-height: 20px">AA <span style="white-space: nowrap">BB CC</span> DD</div>').Children[1].Children[1]
	assert(arrange(mixed, 60) == 60)
	assert(mixed.Items[2].LineIndex == 2 and mixed.Items[3].LineIndex == 2 and mixed.Items[4].LineIndex == 3, "Wrap an entire nowrap span at its preceding normal space")
	local inherited = build('<style>div {white-space: pre !important}</style><div style="white-space: normal">AA<span>   </span>BB<span style="white-space: normal">   CC</span></div>').Children[1].Children[1]
	arrange(inherited)
	words = wordsIn(inherited)
	assert(words[2].X == 35 and words[3].X == 60)
	local split = run("pre-wrap", "AA <span>  </span>BB")
	arrange(split, 30)
	assert(wordsIn(split)[2].X == 0 and wordsIn(split)[2].LineIndex == 2)
	local spaced = run("pre", "AB CD", "letter-spacing: 2px; word-spacing: 3px; text-decoration: underline")
	arrange(spaced)
	words = wordsIn(spaced)
	assert(words[1].Width == 22 and words[2].X == 34, "Preserved spaces combine native width, word spacing and both letter transitions")
	assert(spaced.Items[2].Width == 12 and #spaced.Items[2].DecorationFrames == 1)
	local justified = run("pre-wrap", "AA  BB CC", "text-align: justify")
	arrange(justified, 60)
	words = wordsIn(justified)
	assert(words[2].X == 40 and words[3].X == 0, "Justification expands preserved internal spaces, not hanging spaces")
	local indented = run("pre-wrap", " AA BB CC", "text-indent: 10px")
	arrange(indented, 45)
	assert(wordsIn(indented)[1].X == 15 and wordsIn(indented)[2].X == 0)
	local doc = Parser.parse('<div style="white-space: pre">  AA\tBB\nCC</div>')
	local original = DOM.textContent(doc)
	renderer.build(doc, {}, function(message) error(message) end)
	assert(DOM.textContent(doc) == original, "Whitespace processing never mutates the DOM")
	for _, mode in {"nowrap", "pre"} do
		local tree = build('<div style="width: 30px; overflow: hidden; white-space: ' .. mode .. '">AA BB CC</div>')
		local _, canvasWidth = block.arrange(tree, 30, 0, 0, function() return true end)
		local box=tree.Children[1];local clip=assert(box.ClipContent)
		assert(canvasWidth==30 and clip.ClipsDescendants and clip.Parent==box.Gui
			and clip.Size[1]==30 and clip.Size[2]==box.OuterHeight,"Non-wrapping overflow is clipped to the content host without expanding the canvas")
		local overflowing=false
		for _,item in box.Children[1].Items do
			if item.Gui then assert(item.Gui.Parent==clip)end
			if item.Kind=="Word"and item.X+item.Width>clip.Size[1]then overflowing=true end
		end
		assert(overflowing,"Clipped nowrap/pre glyphs retain their full unwrapped positions")
	end
	local cancel = run("pre", "AA  BB")
	assert(layout.arrange(cancel, 20, 0, 0, function() return false end) == 0)
	local nativeLayout=loadWordLayout({["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)
		local count=0;for _ in utf8.graphemes(text)do count+=1 end;return {X=count*5,Y=size}
	end}})
	local supported={};for _,support in Native and Native.supports or {}do if support.supported then supported[support.collapse..':'..support.wrap]=true end end
	local comparisons=0
	for _,record in Native and Native.records or {}do
		if not supported[record.collapse..':'..record.wrap]or record.name=='encoded-cr'or record.name=='encoded-ff'then continue end
		local document=Parser.parse('<div style="font-size:10px;line-height:20px;tab-size:4;white-space-collapse:'..record.collapse..';text-wrap-mode:'..record.wrap..';text-align:'..record.align..'">'..record.html..'</div>')
		local tree=renderer.build(document,{},error);local native=tree.Children[1].Children[1]
		local height=if native then nativeLayout.arrange(native,record.columns*5+.01,0,0,function()return true end)else 0
		local key=record.collapse..'/'..record.wrap..'/'..record.name..'/'..record.columns
		assert(height==record.height,'Native whitespace height: '..key..': '..height..' vs '..record.height)
		local starts,source={},0
		local function offsets(node)
			if node.Kind=='Text'then starts[node]=source;source+=#node.Text else for _,child in node.Children or {}do offsets(child)end end
		end
		offsets(document)
		local actual={}
		for _,item in native and native.DisplayItems or native and native.Items or {}do
			for _,span in item.SourceSpans or {}do
				if item.Kind=='Word'then actual[starts[span.Node]+span.Start]={x=item.X/5+span.FirstByte-1,line=item.LineIndex}
				elseif item.Kind=='Space'then
					local position=item.X
					for byte=1,span.FirstByte-1 do
						if item.Text:sub(byte,byte)==' 'then position+=item.SpaceUnit
						elseif item.TabWidth>0 then local remaining=item.TabWidth-position%item.TabWidth;if remaining<item.TabMinimum then remaining+=item.TabWidth end;position+=remaining end
					end
					actual[starts[span.Node]+span.Start]={x=position/5,line=item.LineIndex}
				end
			end
		end
		for _,character in record.chars do
			if character.text:match('[A-Z]')or actual[character.offset]then
				local position=assert(actual[character.offset],'Native whitespace source span: '..key..':'..character.offset)
				assert(position.line==character.line and math.abs(position.x-character.x)<.02,'Native whitespace word position: '..key..':'..character.offset..' => '..position.x..','..position.line..' vs '..character.x..','..character.line)
			end
		end
		comparisons+=1
	end
	if Native then assert(comparisons==264);print('White space native reference: '..comparisons..' layouts preserve source positions and line heights')end
	local document=Parser.parse('<div id="parent" style="font-family:Roboto;line-height:20px;white-space:normal"><div id="inherited"> AA  BB\n CC </div><div id="own" style="white-space:pre"> AA  BB\n CC </div><input id="editor" value="kept" style="width:30px"></div><div id="after">End</div>')
	local dynamic=renderer.build(document,{},error)
	local parent=assert(DOM.findById(document,'parent'));local inherited=assert(DOM.findById(document,'inherited'));local own=assert(DOM.findById(document,'own'))
	local function dynamicRun(node)return assert(dynamic.NodeBoxes[node]).Children[1]end
	local ownWords=dynamicRun(own).Items;local editor,after=dynamic.Controls[1],dynamic.NodeBoxes[DOM.findById(document,'after')]
	local editorGui,afterGui=editor.Item.Gui,after.Gui
	local source=DOM.textContent(document)
	for _,mode in {'preserve-breaks nowrap','preserve-spaces nowrap','discard','break-spaces','pre','normal'}do
		parent.Attributes.style='font-family:Roboto;line-height:20px;white-space:'..mode
		assert(dynamic:ApplyDOMChanges({[parent]={Attributes={style=true}}}),'Whitespace axis changes request new geometry')
		block.arrange(dynamic,30,0,0,function()return true end)
		local updated=dynamicRun(inherited);local expected=run(mode,' AA  BB\n CC ')
		arrange(expected,30)
		assert(#updated.Items==#expected.Items,'Dynamic whitespace rebuilds words/spaces/breaks: '..mode)
		for index,item in updated.Items do
			local reference=expected.Items[index]
			assert(item.Kind==reference.Kind and item.Text==reference.Text,'Dynamic whitespace token: '..mode..':'..index)
			if item.Kind~='Break'then assert(item.LineIndex==reference.LineIndex and math.abs(item.X-reference.X)<.001,'Dynamic whitespace layout: '..mode..':'..index)end
		end
		assert(dynamicRun(own).Items==ownWords,'An explicit whitespace boundary retains its word items')
		assert(dynamic.Controls[1]==editor and editor.Item.Gui==editorGui and not editorGui.Destroyed,'Whitespace mutation preserves an unrelated control')
		assert(dynamic.NodeBoxes[DOM.findById(document,'after')]==after and after.Gui==afterGui and not afterGui.Destroyed,'Whitespace mutation preserves following boxes')
		assert(DOM.textContent(document)==source,'Dynamic whitespace preserves original DOM text')
	end
	print("White space: six modes, numeric/pixel tab stops, preserved spaces/tabs/newlines, inline nowrap groups, alignment, spacing, decorations, overflow, DOM preservation and resize reuse passed")
end
