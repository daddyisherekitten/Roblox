--!strict
return function(Parser: any, Style: any, Flow: any, loadRenderTree: any, loadWordLayout: any, loadBlockLayout: any, Native: any)
 local fixtureElement=require('DOM/Node').element
	local parent = { FontSize = 20, Font = "Inter", Color = Color3.new(0, 0, 0) }
	local function resolve(css, inherited, warn)
		return Style.resolve(fixtureElement("p",{ style = css }), inherited or parent, warn or function(message) error(message) end)
	end
	assert(resolve("").TextIndent.Value == 0)
	for _, value in { "0", "20px", "-12.5px", "25%", "-10%" } do
		local style = resolve("text-indent: " .. value)
		local child = resolve("", style)
		assert(child.TextIndent.Value == style.TextIndent.Value and child.TextIndent.Percent == style.TextIndent.Percent)
		assert(child.TextIndent ~= style.TextIndent)
	end
	for _, value in { "auto", "12", "each-line", "--1px", "-+2px", "100001px", "10px hanging hanging", "10px each-line each-line", "10px 20px", "hanging" } do
		local warnings = 0
		assert(resolve("text-indent: 10px; text-indent: " .. value, nil, function() warnings += 1 end).TextIndent.Value == 10 and warnings == 1)
	end
	for _,value in {'20px hanging','each-line 25%','hanging -10px each-line','each-line hanging calc(10px + 10%)'}do
		local style=resolve('text-indent:'..value);local inherited=resolve('',style)
		assert(inherited.TextIndent.EachLine==style.TextIndent.EachLine and inherited.TextIndent.Hanging==style.TextIndent.Hanging)
	end
	local strut = { Ascent = 8, Descent = 2 }
	local function word() return { Kind = "Word", Width = 20, SpaceBefore = true, SpaceWidth = 5, Baseline = 8, Ascent = 8, Descent = 2 } end
	local items = {word(), word(), word()}
	assert(Flow.arrange(items, 60, strut, "left", 10) == 20)
	assert(items[1].X == 10 and items[2].X == 35 and items[3].X == 0 and items[3].LineIndex == 2)
	local two = {word(), word()}
	for align, expected in {left = 20, center = 37.5, right = 55} do
		Flow.arrange(two, 100, strut, align, 20)
		assert(two[1].X == expected and two[2].X == expected + 25)
	end
	Flow.arrange(items, 70, strut, "justify", 10)
	assert(items[1].X == 10 and items[2].X == 50 and items[3].X == 0)
	Flow.arrange(two, 35, strut, "left", -10)
	assert(two[1].X == -10 and two[2].X == 15 and two[2].LineIndex == 1)
	Flow.arrange(two, 10, strut, "left", 100)
	assert(two[1].X == 100 and two[1].LineIndex == 1 and two[2].X == 0, "Oversized indents cannot invent an extra empty line")
	local breaks = {word(), {Kind = "Break"}, word()}
	Flow.arrange(breaks, 100, strut, "left", 20)
	assert(breaks[1].X == 20 and breaks[3].X == 0, "br does not repeat the indent")
	local leading = {{Kind = "Break"}, word()}
	Flow.arrange(leading, 100, strut, "left", 20)
	assert(leading[2].X == 0 and leading[2].LineIndex == 2)
	local emptyHeight, emptyWidth = Flow.arrange({}, 100, strut, "left", 20)
	assert(emptyHeight == 0 and emptyWidth == 0)
	local renderer = loadRenderTree({create = function(_, _, properties)local gui=table.clone(properties);function gui:Destroy()self.Destroyed=true end;return gui end})
	local requests = 0
	local layout = loadWordLayout({
		["Layout/FontProfiles"] = {face = function(font) return font end},
		["Layout/TextMeasure"] = {measure = function(text, _, size)
			requests += 1
			return {X = if text == " " then 5 else 20, Y = size}
		end},
	})
	local block = loadBlockLayout({["Layout/WordLayout"] = layout})
	local function build(html) return renderer.build(Parser.parse(html), {}, function(message) error(message) end) end
	local tree = build([[<div style="padding: 10px; text-indent: 25%"><p style="margin: 0">AA BB</p></div>]])
	block.arrange(tree, 120, 0, 0, function() return true end)
	local run = tree.Children[1].Children[1].Children[1]
	assert(run.Items[1].X == 25, "Percent refers to content width, excluding padding")
	local count = requests
	block.arrange(tree, 220, 0, 0, function() return true end)
	assert(run.Items[1].X == 50 and requests == count, "Resize recomputes percent indent without measuring again")
	local mixed = build([[<div style="text-indent: 20px">AA<div>BB</div>CC</div>]])
	block.arrange(mixed, 120, 0, 0, function() return true end)
	local children = mixed.Children[1].Children
	assert(children[1].Items[1].X == 20 and children[2].Children[1].Items[1].X == 20)
	assert(children[3].Items[1].X == 0, "Later anonymous runs do not restart the parent's indent")
	local afterBlock = build([[<div style="text-indent: 20px"><div>AA</div>BB</div>]])
	block.arrange(afterBlock, 120, 0, 0, function() return true end)
	assert(afterBlock.Children[1].Children[2].Items[1].X == 0)
	local hidden = build([[<p style="text-indent: 20px"><span style="display: none">AA</span><span style="text-indent: 99px">BB</span></p>]])
	block.arrange(hidden, 120, 0, 0, function() return true end)
	assert(hidden.Children[1].Children[1].Items[1].X == 20, "Hidden nodes do not consume indent; span indent does not shift a word")
	for _,case in {{'10px',30,55},{'25%',20,45},{'calc(10px + 25%)',30,55},{'10px hanging',30,45}}do
		local intrinsic=build('<div style="text-indent:'..case[1]..'">AA BB</div>').Children[1].Children[1]
		assert(block.naturalWidth(intrinsic,200,function()return true end,true)==case[2],'Absolute first/following indents contribute to min-content: '..case[1])
		assert(block.naturalWidth(intrinsic,200,function()return true end,false)==case[3],'Percent contributes zero and absolute indent contributes to max-content: '..case[1])
	end
	local nativeLayout=loadWordLayout({["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)return {X=#text*5,Y=size}end}})
	local nativeBlock=loadBlockLayout({["Layout/WordLayout"]=nativeLayout})
	local Node=require('DOM/Node');local comparisons=0
	for _,record in Native and Native.records or {}do
		if not record.supported then continue end
		local value=record.specified:gsub('([%-]?[%d%.]+)px',function(pixels)return tostring(tonumber(pixels)*5/record.advance)..'px'end)
		local document=Parser.parse('<div style="font-family:Roboto;font-size:10px;line-height:20px;white-space:'..record.whiteSpace..';direction:'..record.direction..';text-align:'..record.align..';text-indent:'..value..'">'..record.html..'</div>')
		local tree=renderer.build(document,{},error)
		local height=nativeBlock.arrange(tree,record.columns*5+.01,0,0,function()return true end)
		local key=record.specified..'/'..record.direction..'/'..record.align..'/'..record.name..'/'..record.columns
		assert(height==record.height,'Native indent height: '..key..': '..height..' vs '..record.height)
		local starts,source={},0
		local function sources(node)if node.Kind=='Text'then starts[node]=source;source+=#node.Text else for _,child in node.Children or {}do sources(child)end end end
		sources(document)
		local actual={}
		local function positions(box,x,y)
			x+=box.LayoutX or 0;y+=box.LayoutY or 0
			if box.Kind=='Words'then
				for _,item in box.DisplayItems or box.Items do for _,span in item.SourceSpans or {}do
					actual[starts[span.Node]+span.Start]={x=(x+item.X)/5+span.FirstByte-1,line=math.floor((y+item.LineTop+.01)/20)+1}
				end end
			else for _,child in box.Children or {}do positions(child,x,y)end end
		end
		positions(tree,0,0)
		for _,character in record.chars do if character.text:match('[A-Z]')then
			local point=assert(actual[character.offset],key..': missing source '..character.offset)
			assert(point.line==character.line and math.abs(point.x-character.x)<.025,'Native indent position: '..key..':'..character.offset..' => '..point.x..','..point.line..' vs '..character.x..','..character.line)
		end end
		comparisons+=1
	end
	if Native then assert(comparisons==2160);print('Text-indent native reference: '..comparisons..' layouts match original source positions and line heights')end
	local document=Parser.parse('<div id="parent" style="text-indent:0;line-height:20px"><div id="copy">AA BB<br>CC DD EE</div><div id="own" style="text-indent:3px">AA BB</div><input id="editor" value="kept" style="width:30px"></div><div id="after">End</div>')
	local dynamic=renderer.build(document,{},error)
	local target=assert(Node.findById(document,'parent'));local copy=assert(Node.findById(document,'copy'));local own=assert(Node.findById(document,'own'))
	local dynamicRun=dynamic.NodeBoxes[copy].Children[1];local retained=dynamicRun.Items;local ownRun=dynamic.NodeBoxes[own].Children[1]
	local editor,after=dynamic.Controls[1],dynamic.NodeBoxes[Node.findById(document,'after')]
	local editorGui,afterGui=editor.Item.Gui,after.Gui
	for _,case in {{'10px each-line','ltr',50},{'10px hanging each-line','rtl',50},{'-25% hanging','ltr',70},{'25% each-line','rtl',70},{'0','ltr',50}}do
		target.Attributes.style='line-height:20px;text-indent:'..case[1]..';direction:'..case[2]
		assert(dynamic:ApplyDOMChanges({[target]={Attributes={style=true}}}))
		local expected=build('<div style="line-height:20px;text-indent:'..case[1]..';direction:'..case[2]..'">AA BB<br>CC DD EE</div>')
		block.arrange(expected,case[3],0,0,function()return true end);block.arrange(dynamic,case[3],0,0,function()return true end)
		local reference=expected.Children[1].Children[1];assert(dynamic.NodeBoxes[copy].Children[1]==dynamicRun and dynamicRun.Items==retained,'Dynamic indent preserves existing word owners')
		for index,item in retained do if item.Kind~='Break'then assert(item.X==reference.Items[index].X and item.LineIndex==reference.Items[index].LineIndex,'Dynamic signed/percentage/logical indent updates retained words')end end
		assert(dynamic.NodeBoxes[own].Children[1]==ownRun and ownRun.Style.TextIndent.Value==3,'Own indent overrides inherited changes')
		assert(dynamic.Controls[1]==editor and editor.Item.Gui==editorGui and not editorGui.Destroyed,'Indent mutation preserves the unrelated editor')
		assert(dynamic.NodeBoxes[Node.findById(document,'after')]==after and after.Gui==afterGui and not afterGui.Destroyed,'Indent mutation preserves following boxes')
	end
	print("Text indent: signed px/percent, inheritance, first-line wrapping, br, alignment, padding, anonymous blocks and resize reuse passed")
end
