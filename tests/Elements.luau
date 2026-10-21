--!strict
-- Real parser, catalog, styles and render tree; only GUI allocation is substituted.
return function(Elements: any, Parser: any, Style: any, loadRenderTree: any, loadWordLayout: any, loadBlockLayout: any)
 local fixtureElement=require('DOM/Node').element
	local created, diagnostics = {}, {}
	local renderer = loadRenderTree({ create = function(className, parent, properties)
		local gui = table.clone(properties)
		gui.ClassName, gui.Parent = className, parent
		table.insert(created, gui)
		return gui
	end })
	local tree = renderer.build(Parser.parse([[<html><head><title>Hidden title</title><style>p{color:red}</style></head><body><h1>Heading</h1><h2 style="font-size: 18px; margin: 0">Small</h2><p>One <span>two</span><br><a href="x">three</a> <b>four</b> <strong>five</strong> <em>six</em> <i>seven</i> <span style="color: red">eight</span><img src="x"><input type="hidden"><button style="display:none">Hidden button</button><script>hidden()</script></p><template id="hidden-template"><p id="never-rendered">Template content</p><style>body{display:none}</style></template><custom-box>Fallback</custom-box><div style="display: none">Hidden div</div></body></html>]]), {}, function(message)
		table.insert(diagnostics, message)
	end)
	local body = tree.Children[1].Children[1]
	assert(body.Node.Name == "body" and body.Style.Margin[1] == 8)
	assert(#body.Children == 5 and body.Children[5].Style.Hidden and not body.Children[5].Gui.Visible,
		"Hidden standalone blocks are retained without paint; inert templates produce no boxes")
	assert(body.Children[1].Style.FontSize == 32 and body.Children[1].Style.Margin[1] == 20)
	assert(body.Children[2].Style.FontSize == 18 and body.Children[2].Style.Margin[1] == 0, "Inline styles must override catalog defaults")
	local paragraph = body.Children[3]
	assert(paragraph.Style.Margin[1] == 16 and paragraph.Style.FontSize == 16)
	local words = paragraph.Children[1].Items
	assert(#words == 10 and words[3].Kind == "Break" and words[10].Kind == "Image", "Inline content, images and br must keep the same flow")
	assert(words[4].Text == "three" and not words[4].SpaceBefore)
	local rendered = {}
	for _, gui in created do
		if gui.ClassName == "TextLabel" then
			local hidden, ancestor = false, gui
			while ancestor do if ancestor.Visible == false then hidden = true; break end; ancestor = ancestor.Parent end
			if hidden then continue end
			table.insert(rendered, gui.Text)
			if gui.Text == "eight" then assert(gui.TextColor3 == Color3.fromRGB(255, 0, 0), "Span text styles must be applied") end
		end
	end
	assert(table.concat(rendered, " ") == "Heading Small One two three four five six seven eight Fallback")
	assert(#diagnostics == 1, "Links render natively; only the unmapped image warning remains")
	assert(Elements["custom-box"] == nil and body.Children[4].Kind=="Words"and body.Children[4].Items[1].SourceSpans[1].Node.Parent.Name=="custom-box", "Generic fallback must not imply registered support")
	assert(Elements.template.Render == "hidden" and Elements.template.Support == "supported")
	local supported, parserOnly, partial = 0, 0, 0
	for name, entry in Elements do
		if entry.Support == "supported" then supported += if name == "svg" then 0 else 1
		elseif entry.Support == "parser-only" then parserOnly += 1
		elseif entry.Support == "partial" then partial += 1
		else error("Unknown element support status: " .. tostring(entry.Support)) end
	end
	assert(supported == 113 and parserOnly == 0 and partial == 0, "Support status is scoped to the documented Roblox profile")
	assert(Elements.script.Support == 'supported' and Elements.script.Render == 'hidden', 'Executable scripts remain nonvisual elements')

	table.clear(created)
	local shadowDocument = Parser.parse([[<style>#shadow-shell{display:none}.internal{color:blue}</style><x-card style="display:block"><h2 id="light-title" slot="title">Light title</h2><p id="light-body">Light body</p><p id="unmatched" slot="missing">Unmatched</p><template shadowrootmode="open"><style>:host{padding:7px}::slotted(h2){color:green}.internal{display:block;color:red}</style><section id="shadow-shell" class="internal"><slot name="title"><h2>Title fallback</h2></slot><slot><p>Body fallback</p></slot><slot name="empty"><p id="empty-fallback">Empty fallback</p></slot></section></template></x-card>]])
	local shadowHost = shadowDocument.Children[2]
	local shadowRoot = shadowHost.ShadowRoot
	local shellNode = shadowRoot.Children[2]
	local titleSlot, defaultSlot, emptySlot = shellNode.Children[1], shellNode.Children[2], shellNode.Children[3]
	local shadowTree = renderer.build(shadowDocument, {}, function(message) error(message) end)
	local hostBox, shellBox = shadowTree.Children[1], shadowTree.Children[1].Children[1]
	assert(hostBox.Node == shadowHost and shellBox.Node == shellNode, "A host renders its attached shadow tree")
	assert(hostBox.Style.Padding[1] == 7 and shadowTree.NodeStyles[shadowHost.Children[1]].Color == Color3.fromRGB(0, 128, 0), "Shadow :host and ::slotted styles apply to the host and assigned light child")
	assert(shellBox.Style.Color == Color3.fromRGB(255, 0, 0), "Shadow-local CSS applies while document selectors stay outside the shadow root")
	assert(#shadowTree.SlotAssignments[titleSlot] == 1 and shadowTree.SlotAssignments[titleSlot][1].Attributes.id == "light-title")
	assert(#shadowTree.SlotAssignments[defaultSlot] == 1 and shadowTree.SlotAssignments[defaultSlot][1].Attributes.id == "light-body")
	assert(#shadowTree.SlotAssignments[emptySlot] == 0 and shadowTree.NodeBoxes[emptySlot.Children[1]] ~= nil, "An empty slot renders its fallback children")
	assert(shadowTree.NodeBoxes[shadowHost.Children[1]] and shadowTree.NodeBoxes[shadowHost.Children[2]] and shadowTree.NodeBoxes[shadowHost.Children[3]] == nil, "Only assigned light children enter the flattened render tree")
	local shadowText = {}
	for _, gui in created do if gui.ClassName == "TextLabel" then table.insert(shadowText, gui.Text) end end
	local flattened = table.concat(shadowText, " ")
	assert(flattened:find("Light title", 1, true) and flattened:find("Light body", 1, true) and flattened:find("Empty fallback", 1, true), flattened)
	assert(not flattened:find("Title fallback", 1, true) and not flattened:find("Body fallback", 1, true) and not flattened:find("Unmatched", 1, true), flattened)
	assert(Elements.slot.Render == "slot" and Elements.slot.Support == "supported")

	local semantic = renderer.build(Parser.parse([[<main id="content" aria-label="Primary"><header><hgroup><h1>Title</h1><p>Lead</p></hgroup></header><nav>Links</nav><section><article>Story</article><aside>Related</aside></section><search>Find</search><footer>End</footer></main>]]), {}, function(message) error(message) end)
	local semanticMain=semantic.Children[1]
	assert(semanticMain.SemanticRole=='main' and semanticMain.SemanticLabel=='Primary')
	local expected={header='banner',hgroup='group',nav='navigation',section='region',article='article',aside='complementary',search='search',footer='contentinfo'}
	local pending={semanticMain}
	while #pending>0 do
		local box=table.remove(pending)
		if expected[box.Node.Name] then assert(box.SemanticRole==expected[box.Node.Name]);expected[box.Node.Name]=nil end
		for _,child in box.Children or {} do if child.Node then table.insert(pending,child) end end
	end
	assert(next(expected)==nil and Elements.main.Render=='block' and Elements.search.Support=='supported')

	local inlineSemantic=renderer.build(Parser.parse([[<p><abbr title="HyperText Markup Language">HTML</abbr> <data value="sku-42">Widget</data> <time datetime="2026-09-20">Sunday</time> <q cite="source">outer <q>inner</q></q> <bdo dir="rtl">abc</bdo></p>]]),{},function(message) error(message) end)
	local semanticItems=inlineSemantic.Children[1].Children[1].Items
	local values,texts={},{ }
	for _,item in semanticItems do
		if item.Text then table.insert(texts,item.Text) end
		if item.Style and item.Style.SemanticValue then values[item.Style.SemanticValue]=true end
	end
	assert(values['HyperText Markup Language'] and values['sku-42'] and values['2026-09-20'] and values.source)
	local semanticText=table.concat(texts,' ')
	assert(semanticText:find('“outer',1,true) and semanticText:find('‘inner’',1,true) and semanticText:find('”',1,true) and semanticText:find('abc',1,true),semanticText)
	local overrideFound=false
	for _,item in semanticItems do if item.Text=='abc'then overrideFound=true;assert(item.BidiDirection=='rtl'and item.NativeBidiForced and item.SourceSpans,'bdo resolves visual override while preserving logical source')end end
	assert(overrideFound)
	assert(Elements.abbr.Defaults.DecorationStyle=='dotted' and Elements.bdi.Render=='inline')

	local fallback=renderer.build(Parser.parse([[<menu id="commands"><li>Save</li><li>Export</li></menu><noscript id="fallback">No script</noscript>]]),{},function(message) error(message) end)
	local commands,fallbackBox=fallback.Children[1],fallback.Children[2]
	assert(commands.Node.Name=='menu' and commands.Style.Padding[4]==40 and commands.Style.ListStyleType=='disc')
	assert(commands.Children[1].Marker and commands.Children[2].Marker and fallbackBox.Node.Name=='noscript')
	assert(Elements.menu.Support=='supported' and Elements.noscript.Render=='block')
	assert(Elements.selectedcontent.Render=='inline' and Elements.selectedcontent.Support=='supported')

	local rubyTree=renderer.build(Parser.parse([[<p>Read <ruby id="ruby-example">漢<rp>(</rp><rt id="ruby-note">kan</rt><rp>)</rp></ruby> aloud.</p>]]),{},function(message) error(message) end)
	local rubyItems=rubyTree.Children[1].Children[1].Items
	local rubyBox
	for _,item in rubyItems do if item.InlineBox then rubyBox=item.InlineBox end end
	assert(rubyBox and rubyBox.Node.Name=='ruby' and rubyBox.Style.Display=='inline-grid')
	assert(#rubyBox.Children==2 and rubyBox.Children[1].Kind=='Words', 'rp fallback text must stay hidden')
	local annotation=rubyBox.Children[2]
	assert(annotation.Node.Name=='rt' and annotation.Style.FontSize==8)
	assert(annotation.Style.GridRowStart.Number==1 and annotation.Style.GridColumnStart.Number==1)
	assert(Elements.ruby.Support=='supported' and Elements.rp.Render=='hidden')
	local layoutOverrides={['Layout/FontProfiles']={face=function(font) return font end},['Layout/TextMeasure']={measure=function(text,_,size) return {X=#text*size*.5,Y=size} end}}
	layoutOverrides['Layout/WordLayout']=loadWordLayout(layoutOverrides)
	local rubyLayout=loadBlockLayout(layoutOverrides)
	rubyLayout.arrange(rubyTree,420,0,0,function() return true end)
	assert(rubyBox.OuterWidth>0 and rubyBox.OuterHeight>annotation.OuterHeight)
	assert(annotation.LayoutY<=rubyBox.Children[1].LayoutY and rubyBox.FirstBaseline>annotation.OuterHeight, 'rt must sit above the base-text baseline')
	local rubyOverlap=rubyBox.GridLayout.Rows.Ends[1]-rubyBox.GridLayout.Rows.Starts[2]
	assert(rubyOverlap>0 and rubyOverlap<annotation.Style.FontSize/2, 'Ruby rows need a small gap-safe overlap without touching the base glyphs')
	local tallRubyTree=renderer.build(Parser.parse([[<p style="font-size:22px;line-height:3"><ruby id="tall-ruby">東京<rt id="tall-note">とうきょう</rt></ruby></p>]]),{},error)
	rubyLayout.arrange(tallRubyTree,420,0,0,function() return true end)
	local tallRuby=tallRubyTree.Children[1].Children[1].Items[1].InlineBox
	local base=tallRuby.Children[1].Items[1]
	local note=tallRuby.Children[2]
	local noteWord=note.Children[1].Items[1]
	local glyphGap=base.Gui.Position[2]-(note.LayoutY+noteWord.Gui.Position[2])
	assert(tallRuby.Style.LineHeight.Kind=='number' and tallRuby.Style.LineHeight.Value==3,
		'The author line-height stays on the ruby box')
	assert(tallRuby.Children[1].Style.LineHeight.Kind=='normal' and glyphGap>=3 and glyphGap<=16,
		'Large paragraph line-height must not separate ruby annotations from their base glyphs: '..tostring(glyphGap))
	local underTree=renderer.build(Parser.parse([[<style>.row{font-size:23px;line-height:2.2}.row ruby{ruby-position:under;ruby-align:start}.row rt{font-size:11px}ruby:hover{ruby-position:over;ruby-align:center}@media(max-width:500px){.row{color:red;font-size:19px}}</style><p class="row"><ruby>大阪<rt>おおさか</rt></ruby> unter dem Basistext</p>]]),{},error)
	local underRuby=underTree.Children[1].Children[1].Items[1].InlineBox
	local underNote=underRuby.Children[2]
	local function checkUnder()
		rubyLayout.arrange(underTree,420,0,0,function()return true end)
		assert(underNote.LayoutY>underRuby.Children[1].LayoutY,'ruby-position:under must paint the annotation below its base')
		assert(underRuby.Style.TextAlign=='start','Ruby alignment must follow ruby-align')
	end
	checkUnder()
	underTree:SetMediaEnvironment(800,300)
	checkUnder()
	underTree:SetMediaEnvironment(420,300)
	checkUnder()
	assert(underRuby.Children[1].Style.FontSize==19 and underRuby.Children[1].Style.LineHeight.Kind=='normal','Media changes update the compact Ruby base style without inheriting excess leading')
	underTree:SetCSSState('hover',underRuby.Node)
	rubyLayout.arrange(underTree,420,0,0,function()return true end)
	assert(underNote.LayoutY<underRuby.Children[1].LayoutY and underRuby.Style.TextAlign=='center','Ruby positioning follows live CSS states')
	underTree:SetCSSState('hover',nil)
	checkUnder()

	local hidden = renderer.build(Parser.parse([[<div>Hel<div style="display: none">hidden</div>lo <div style="display: none">hidden</div>world</div>]]), {}, function(message) error(message) end)
	local hiddenFlow = hidden.Children[1].Children
	local hiddenBreak = renderer.build(Parser.parse([[<style>.off {display: none !important}</style><p>Hel<br class="off" style="display: block">lo<br style="display: none">world<br>Next</p>]]), {}, function(message) error(message) end)
	local breakItems = hiddenBreak.Children[1].Children[1].Items
	assert(#breakItems == 3 and breakItems[1].Text == "Helloworld" and breakItems[2].Kind == "Break" and breakItems[3].Text == "Next", "Hidden br must not split text or create a line")
	assert(#hiddenFlow == 1 and #hiddenFlow[1].Items == 2, "Hidden blocks cannot interrupt surrounding inline flow")
	assert(hiddenFlow[1].Items[1].Text == "Hello" and hiddenFlow[1].Items[2].Text == "world" and hiddenFlow[1].Items[2].SpaceBefore)

	-- Defaults and public catalog entries cannot leak changes between elements.
	local parent = { FontSize = 16, Font = Enum.Font.Arial, Color = {} }
	local function resolve(name)
		return Style.resolve(fixtureElement(name,{}), parent, function(message) error(message) end)
	end
	local first, second = resolve("h2"), resolve("h2")
	assert(first.FontSize == 24 and first.Margin[1] == 16)
	first.Margin[1] = 99
	assert(second.Margin[1] == 16 and resolve("h2").Margin[1] == 16)
	assert(not pcall(function() Elements.h2.Defaults.Margin[1] = 99 end))
	assert(not pcall(function() Elements.h2.Render = "hidden" end))
	assert(not pcall(function() Elements.h2 = nil end))
	local function near(a, b) assert(math.abs(a - b) < 0.00001) end
	for index, pair in {{1.17, 1}, {1, 1.33}, {.83, 1.67}, {.67, 2.33}} do
		local name = "h" .. (index + 2)
		assert(Elements[name].Render == "block")
		for _, size in {16, 20, 30} do
			local inherited = {FontSize = size, Font = Enum.Font.Arial, Color = {}, LineHeight = {Kind = "number", Value = 1.4}}
			local value = Style.resolve(fixtureElement(name,{}), inherited, function(message) error(message) end)
			near(value.FontSize, size * pair[1]); near(value.Margin[1], size * pair[1] * pair[2])
			near(value.Margin[3], value.Margin[1]); assert(value.Margin[2] == 0 and value.Margin[4] == 0)
			assert(value.FontWeight == 700 and value.LineHeight.Value == 1.4)
			local explicit = Style.resolve(fixtureElement(name,{style = "margin-top: 2px; font-size: 24px; font-weight: normal"}), inherited, function(message) error(message) end)
			assert(explicit.FontSize == 24 and explicit.FontWeight == 400 and explicit.Margin[1] == 2)
			near(explicit.Margin[3], 24 * pair[2])
		end
	end
	print("Element catalog: headings, semantics, ruby, roles, defaults, warnings, fallback and independent styles passed")
end
