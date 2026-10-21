--!strict
return function(Parser: any, DOM: any, loadRenderTree: any, Stylesheet: any)
	local renderer = loadRenderTree({ create = function(_, _, properties) return table.clone(properties) end })
	local function render(html: string, css: string?, defaultFont: any?, stylesheets: {[string]: string}?, baseURL: string?): (any, any, any)
		local warnings, boxes = {}, {}
		local document = Parser.parse(html)
		assert(#document.Diagnostics == 0)
		local tree = renderer.build(document, {}, function(message) table.insert(warnings, message) end, nil, nil, nil, nil, css, defaultFont, nil, nil, nil, stylesheets, baseURL)
		local pending = { tree }
		while #pending > 0 do
			local box = table.remove(pending)
			if box.Node and box.Node.Attributes and box.Node.Attributes.id then boxes[box.Node.Attributes.id] = box end
			for _, child in box.Children or {} do table.insert(pending, child) end
		end
		return boxes, warnings, document
	end
	local boxes, warnings, document = render([=[<!DOCTYPE html>
<html lang="de"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Inter Font</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;700&amp;display=swap" rel="stylesheet">
<style>body { font-family: 'Inter'; }</style></head>
<body id="body"><h1 id="heading">Nur die Schriftart Inter</h1>
<p id="text">Dieser Text wird ausschließlich in der Schriftart Inter gerendert.</p></body></html>]=])
	assert(#warnings == 0)
	for _, id in { "body", "heading", "text" } do assert(boxes[id].Style.Font == "Inter") end
	for _, item in boxes.text.Children[1].Items do assert(item.Style.Font == "Inter") end
	assert(boxes.heading.Style.FontSize == 32)
	assert(DOM.findById(document, "body").Attributes.style == nil, "Do not rewrite standard HTML into inline styles")
	boxes, warnings = render('<link rel="stylesheet preload" href="styles.css"><p id="linked">Linked</p>', nil, nil, {['styles.css']='p {color: blue; font-size: 23px}'})
	assert(#warnings == 0 and boxes.linked.Style.Color == Color3.fromRGB(0,0,255) and boxes.linked.Style.FontSize == 23, 'Linked local stylesheet uses the browser href')
	boxes, warnings = render('<link rel="stylesheet" href="missing.css"><p id="safe">Safe</p>', nil, nil, {})
	assert(#warnings == 1 and warnings[1]:find('missing.css',1,true) and boxes.safe, 'Missing linked stylesheet is diagnosed')
	boxes, warnings = render('<link rel="stylesheet" href="theme.css"><link rel="stylesheet" href="disabled.css" disabled><p id="based">Based</p>', nil, nil,
		{['http://localhost:8000/assets/theme.css']='p {color:green}', ['disabled.css']='p {color:red}'}, 'http://localhost:8000/assets/')
	assert(#warnings == 0 and boxes.based.Style.Color == Color3.fromRGB(0,128,0), 'Linked CSS resolves against base URL and disabled sheets stay inactive')
	local owners=Parser.parse('<style disabled media="screen and (min-width:700px)">p {color:green}</style><link rel="stylesheet" href="wide.css" media="(min-width:1000px)"><p id="owner-media">Owner media</p>')
	local ownerSources=Stylesheet.sources(owners,nil,{['wide.css']='p {color:red;width:20vw}'})
	assert(#ownerSources==2 and not ownerSources[1].Disabled and ownerSources[1].Node.Name=='style' and ownerSources[2].Node.Name=='link',
		'Source order includes owner metadata; disabled is not a style content attribute')
	local ownerTree=renderer.build(owners,{AbsoluteSize={X=800,Y=600}},error,nil,nil,nil,nil,nil,nil,nil,nil,nil,{['wide.css']='p {color:red;width:20vw}'})
	local ownerNode=DOM.findById(owners,'owner-media')
	assert(ownerTree.HasMediaQueries and ownerTree.NodeStyles[ownerNode].Color==Color3.fromRGB(0,128,0),'Owner style media applies at its matching viewport')
	assert(ownerTree:SetMediaEnvironment(1200,600) and ownerTree.NodeStyles[ownerNode].Color==Color3.fromRGB(255,0,0),'Owner link media participates in live viewport matching')
	assert(ownerTree.HasViewportUnits and ownerTree:SetMediaEnvironment(1400,600) and ownerTree.NodeStyles[ownerNode].ViewportWidth==1400,
		'Viewport units activated by owner media keep updating within the same media branch')

	-- This sequence asserts standards-mode case-sensitive selector matching.
	-- Quirks matching has separate native and retained-render regressions.
	boxes, warnings = render([=[<!doctype html><html><head><style>
/* Braces in comments { } must not create rules. */
body { font-family: 'Inter'; color: red; line-height: 150%; font-size: 20px; }
* { padding: 0; }
p { color: blue; }
.note { color: green; }
#specific { color: red; }
body .note { font-family: "Ubuntu"; }
p.note, h1 { line-height: 2; }
#important { color: green !important; }
#important { color: red; }
.note { color: blue; }
#hidden { display: none; }
</style></head><body>
<p id="specific" class="note">Specific</p>
<p id="order" class="note">Order</p>
<p id="inline" class="note" style="color: red; font-weight: normal">Inline</p>
<p id="important" style="color: blue">Important</p>
<p id="inline-important" class="note" style="color: red !IMPORTANT; color: blue">Inline important</p>
<div id="computed"><span style="font-size: 30px">Computed</span></div>
<div id="continuous">before<div id="hidden">hidden</div> after</div>
<div id="case" class="Note">Case</div>
<p id="invalid" style="color: invalid; line-height: 150%; font-size: 40px">Invalid</p>
</body><style>#order { text-align: right; } #invalid { color: green; }</style></html>]=])
	assert(boxes.specific.Style.Color == Color3.fromRGB(255, 0, 0), "ID beats later class rules")
	assert(boxes.order.Style.Color == Color3.fromRGB(0, 0, 255) and boxes.order.Style.TextAlign == "right")
	assert(boxes.order.Style.Font == Enum.Font.Ubuntu and boxes.order.Style.LineHeight.Value == 2)
	assert(boxes.inline.Style.Color == Color3.fromRGB(255, 0, 0) and boxes.inline.Style.FontWeight == 400)
	assert(boxes.important.Style.Color == Color3.fromRGB(0, 128, 0), "Important stylesheet beats normal inline")
	assert(boxes["inline-important"].Style.Color == Color3.fromRGB(255, 0, 0))
	assert(boxes.computed.Style.LineHeight.Value == 30)
	assert(boxes.computed.Children[1].Items[1].Style.LineHeight.Value == 30, "Percent inherits as computed px")
	assert(#boxes.continuous.Children == 1 and #boxes.continuous.Children[1].Items == 2 and not boxes.hidden)
	assert(boxes.case.Style.Font == "Inter", "Class matching stays case-sensitive")
	assert(boxes.invalid.Style.Color == Color3.fromRGB(0, 128, 0) and boxes.invalid.Style.LineHeight.Value == 60)
	-- The universal padding rule warns on spans (inline boxes are not supported).
	assert(#warnings == 2)

	boxes, warnings = render([=[<style>
@media print { body { color: red; } }
@font-face { font-family: Fake; src: url("a;b{c}.woff"); }
@import "fake.css";
p, :hover { color: red; }
p { color: blue; unknown: "quoted; } content"; color: green; }
</style><style media="print">body { color: red; }</style>
<style type="text/plain">body { color: red; }</style>
<body id="body"><p id="text">Safe</p></body>]=])
	assert(boxes.body.Style.Color == Color3.new(0, 0, 0), "Both nested and owner print media remain inactive on screen")
	assert(boxes.text.Style.Color == Color3.fromRGB(0, 128, 0), "Quoted delimiters must not hide later declarations")
	assert(#warnings == 2, "Accept font-face, nested/owner media and supported pseudo selectors; diagnose only @import and the unknown declaration")
	boxes, warnings = render('<div class="outer"><p id="direct">A</p><div><p id="nested">B</p></div></div>', '.outer>p {color:red} .outer p {font-size:21px}')
	assert(#warnings == 0 and boxes.direct.Style.Color == Color3.fromRGB(255,0,0))
	assert(boxes.nested.Style.Color ~= Color3.fromRGB(255,0,0) and boxes.nested.Style.FontSize == 21, 'Child combinator must not match grandchildren')
	boxes, warnings = render('<div class="outer"><div class="middle"><div><div class="middle"><p id="retry" class="target">A</p></div></div></div></div><div class="middle"><p id="outside" class="target">B</p></div>', '.outer > .middle .target {padding-left:9px}')
	assert(#warnings == 0 and boxes.retry.Style.Padding[4] == 9 and boxes.outside.Style.Padding[4] == 0,
		'Mixed child/descendant selectors must retry an earlier matching ancestor')
	for _, case in {
		{'.outer > .middle .middle > .target', true},
		{'.outer > .middle > .target', false},
		{'.missing .outer > .middle .target', false},
		{'.outer .middle > .target', true},
		{'.outer > .middle > .spacer .middle > .target', true},
	} do
		boxes = render('<div class="outer"><div class="middle"><div class="spacer"><div class="middle"><p id="target" class="target">A</p></div></div></div></div>', case[1] .. ' {padding-left:9px}')
		assert(boxes.target.Style.Padding[4] == (if case[2] then 9 else 0), case[1])
	end
	boxes, warnings, document = render([=[
		<ul id="list"><li id="one" data-kind="Alpha">One</li><li id="two" data-kind="beta-item">Two</li><li id="three">Three</li></ul>
		<p id="empty"></p><p id="filled"><span>child</span></p>
	]=], [=[
		LI[data-kind] { color: red }
		[data-kind^="BETA" i] { background-color: blue }
		li + li { padding-left: 7px }
		li ~ li { margin-top: 3px }
		li:first-child { font-size: 19px }
		li:nth-child(2n) { line-height: 2 }
		li:is(#three, .missing) { text-align: right }
		li:not([data-kind]) { font-style: italic }
		:where(#empty):empty { height: 4px }
	]=])
	assert(#warnings == 0)
	assert(boxes.one.Style.Color == Color3.fromRGB(255,0,0) and boxes.one.Style.FontSize == 19)
	assert(boxes.two.Style.Background == Color3.fromRGB(0,0,255) and boxes.two.Style.Padding[4] == 7 and boxes.two.Style.Margin[1] == 3)
	assert(boxes.two.Style.LineHeight.Value == 2 and boxes.three.Style.TextAlign == 'right' and boxes.three.Style.FontStyle == 'italic')
	assert(boxes.empty.Style.Height.Value == 4 and boxes.filled.Style.Height == nil, 'Structural and functional pseudo classes match HTML nodes')
	local stateRules = Stylesheet.collect(document, error, '#list:hover > li { color: green } #two:active { font-weight: bold } #list:focus-within { padding-top: 9px }')
	local listNode, twoNode = DOM.findById(document,'list'), DOM.findById(document,'two')
	local hovered = Stylesheet.match(stateRules,twoNode,{hover=twoNode})
	assert(#hovered.Normal == 1 and hovered.Normal[1].Field == 'Color')
	assert(#Stylesheet.match(stateRules,twoNode,{active=twoNode}).Normal == 1)
	assert(#Stylesheet.match(stateRules,listNode,{focus=twoNode}).Normal == 1)
	assert(Stylesheet.stateChanges(stateRules,document,'hover',{}, {hover=twoNode}))
	assert(not Stylesheet.stateChanges(stateRules,document,'hover',{hover=twoNode}, {hover=twoNode}))
	local liveDocument=Parser.parse('<style>#card:hover {background-color:yellow} #card:hover > span {color:red;font-size:20px} #card:focus-within {padding-top:6px}</style><div id="card"><span id="live">Live</span></div>')
	local liveTree=renderer.build(liveDocument,{},error)
	local cardNode,liveNode=DOM.findById(liveDocument,'card'),DOM.findById(liveDocument,'live')
	assert(liveTree.NodeBoxes[cardNode].Style.Background==nil and liveTree.NodeStyles[liveNode].FontSize==16)
	local liveChanged,liveNeedsLayout=liveTree:SetCSSState('hover',liveNode)
	assert(liveChanged and liveNeedsLayout and liveTree.NodeBoxes[cardNode].Style.Background==Color3.fromRGB(255,255,0),
		'A hover that changes font size still requests layout')
	assert(liveTree.NodeStyles[liveNode].Color==Color3.fromRGB(255,0,0) and liveTree.NodeStyles[liveNode].FontSize==20)
	assert(not liveTree:SetCSSState('hover',liveNode),'An unchanged state does not trigger layout work')
	assert(liveTree:SetCSSState('focus',liveNode) and liveTree.NodeBoxes[cardNode].Style.Padding[1]==6)
	assert(liveTree:SetCSSState('hover',nil) and liveTree.NodeStyles[liveNode].FontSize==16)
	local variableDocument=Parser.parse('<style>#variable {--tone:rgb(10,20,30)} #variable:hover {--tone:rgb(40,50,60)} #variable span {color:var(--tone);font-size:var(--size,18px)}</style><div id="variable"><span id="variable-child">Variable</span></div>')
	local variableTree=renderer.build(variableDocument,{},error)
	local variableNode,variableChild=DOM.findById(variableDocument,'variable'),DOM.findById(variableDocument,'variable-child')
	assert(variableTree.NodeStyles[variableChild].Color==Color3.fromRGB(10,20,30) and variableTree.NodeStyles[variableChild].FontSize==18)
	assert(variableTree:SetCSSState('hover',variableChild) and variableTree.NodeStyles[variableChild].Color==Color3.fromRGB(40,50,60),
		'State custom properties recompute inheriting descendants')
	assert(variableTree:SetCSSState('hover',nil) and variableTree.NodeStyles[variableChild].Color==Color3.fromRGB(10,20,30))
	local tokenDocument=Parser.parse([=[<style>
		#token-vars { --tone:rgb(1,2,3); --next:V\61R(--tone); --a:var(--b); --b:VAR(--a) }
		#token-vars span { display:block; color:VAR(--next); width:v\61r(--a, 17px) }
		#token-vars i { --literal:"var(--literal)"; --comment:/*var(--comment)*/6px; --dimension:1var(--dimension); --hash:#var(--hash); --url:url(var(--url)); font-size:var(--comment) }
		</style><div id="token-vars"><span id="token-result">Tokens</span><i id="token-literals">Literals</i></div>]=])
	local tokenTree=renderer.build(tokenDocument,{},error);local tokenResult=DOM.findById(tokenDocument,'token-result');local tokenLiterals=DOM.findById(tokenDocument,'token-literals')
	assert(tokenTree.NodeStyles[tokenResult].Color==Color3.fromRGB(1,2,3)and tokenTree.NodeStyles[tokenResult].Width.Value==17,'Escaped/case-insensitive variable chains and cycles use the same resolver')
	local custom=tokenTree.NodeStyles[tokenLiterals].Custom
	assert(custom['--literal']=='"var(--literal)"'and custom['--comment']=='6px'and custom['--dimension']=='1var(--dimension)'and custom['--hash']=='#var(--hash)'and custom['--url']=='url(var(--url))','Token lookalikes do not manufacture dependency cycles')
	assert(not Stylesheet.supports('(width:var(bad))')and not Stylesheet.supports('(width:VAR())')and Stylesheet.supports('(width:V\\61R(--x,))'),'Pending variable grammar is validated before substitution')
	local invalidDocument=Parser.parse('<style>#invalid-var {color:red;color:var(bad)}</style><div id="invalid-var">Invalid</div>');local invalidWarnings={}
	local invalidTree=renderer.build(invalidDocument,{},function(m)table.insert(invalidWarnings,m)end)
	assert(invalidTree.NodeStyles[DOM.findById(invalidDocument,'invalid-var')].Color==Color3.fromRGB(255,0,0),'Invalid var grammar never overrides a lower valid declaration')
	local mediaDocument=Parser.parse([=[<style>
		#responsive { color:black; padding-top:1px }
		@media screen and (min-width:700px) and (orientation:landscape) { #responsive { color:red; padding-top:9px } }
		@media (max-width:500px), (max-height:300px) { #responsive { color:blue } }
		@media (hover:hover) and (pointer:fine) { #responsive { background-color:green } }
		@media (min-width:300px) { @media (orientation:portrait) { #responsive { font-size:22px } } }
	</style><div id="responsive">Responsive</div>]=])
	local mediaWarnings={}
	local mediaTree=renderer.build(mediaDocument,{AbsoluteSize={X=800,Y=600}},function(message)table.insert(mediaWarnings,message)end)
	local responsiveNode=DOM.findById(mediaDocument,'responsive')
	assert(#mediaWarnings==0 and mediaTree.NodeStyles[responsiveNode].Color==Color3.fromRGB(255,0,0) and mediaTree.NodeStyles[responsiveNode].Padding[1]==9)
	assert(mediaTree:SetMediaEnvironment(800,600,{Hover=true,AnyHover=true,Pointer='fine',AnyPointers={fine=true}}))
	assert(mediaTree.NodeStyles[responsiveNode].Background==Color3.fromRGB(0,128,0),'Input capability media queries update existing styles')
	assert(mediaTree:SetMediaEnvironment(400,700,{Hover=true,AnyHover=true,Pointer='fine',AnyPointers={fine=true}}))
	assert(mediaTree.NodeStyles[responsiveNode].Color==Color3.fromRGB(0,0,255) and mediaTree.NodeStyles[responsiveNode].Padding[1]==1)
	assert(mediaTree.NodeStyles[responsiveNode].FontSize==22,'Nested media queries combine with the parent query')
	local invalidMediaWarnings={}
	local invalidMediaRules=Stylesheet.collect(Parser.parse('<p id="safe">Safe</p>'),function(message)table.insert(invalidMediaWarnings,message)end,
		'@media (unknown-feature:yes) { p {color:red} } p {color:green}')
	Stylesheet.setMediaEnvironment(invalidMediaRules,{Width=400,Height=600})
	assert(#invalidMediaWarnings==0 and #Stylesheet.match(invalidMediaRules,DOM.findById(Parser.parse('<p id="safe">Safe</p>'),'safe')).Normal==1,
		'Unknown features are valid general-enclosed conditions, remain nonmatching and preserve later rules')
	local compactDocument=Parser.parse('<p id="compact">Compact</p>')
	local compactNode=DOM.findById(compactDocument,'compact')
	local compactRules=Stylesheet.collect(compactDocument,error,'@media(max-width:700px){#compact{color:red}}@media(forced-colors:active){#compact{border-width:2px}}')
	Stylesheet.setMediaEnvironment(compactRules,{Width=600,Height=600})
	assert(#Stylesheet.match(compactRules,compactNode).Normal==1,'Compact @media syntax matches the width condition')
	Stylesheet.setMediaEnvironment(compactRules,{Width=600,Height=600,ForcedColors=true})
	assert(#Stylesheet.match(compactRules,compactNode).Normal==2,'Explicit forced-colors environment activates its rules')
	local focusRules=Stylesheet.collect(compactDocument,error,'#compact:focus-visible{outline-color:red}')
	assert(Stylesheet.stateChanges(focusRules,compactDocument,'focus-visible',{}, {['focus-visible']=compactNode}))
	local supportRules=Stylesheet.collect(compactDocument,error,'@supports (position-area:right){#compact{color:red}}@supports not (unlisted-feature:1){#compact{padding-top:3px}}@supports ((display:grid) and (not (unlisted-feature:1))){#compact{margin-top:4px}}')
	assert(#Stylesheet.match(supportRules,compactNode).Normal==3,'@supports evaluates supported declarations, negation and nested conditions')
	local relationalDocument=Parser.parse('<div id="parent"><input id="toggle" type="checkbox"><p id="result">Result</p></div>')
	local relationalParent=DOM.findById(relationalDocument,'parent')
	local relationalInput=DOM.findById(relationalDocument,'toggle')
	local relationalResult=DOM.findById(relationalDocument,'result')
	local relationalRules=Stylesheet.collect(relationalDocument,error,'#parent:has(input:checked)>#result{color:green}')
	local unchecked={['form-state']={[relationalInput]={Type='checkbox',Checked=false}}}
	local checked={['form-state']={[relationalInput]={Type='checkbox',Checked=true}}}
	assert(#Stylesheet.match(relationalRules,relationalResult,unchecked).Normal==0 and #Stylesheet.match(relationalRules,relationalResult,checked).Normal==1)
	local relationalChanged,relationalAffected=Stylesheet.stateChanges(relationalRules,relationalDocument,'form-state',unchecked,checked)
	assert(relationalChanged and relationalAffected[relationalResult] and not relationalAffected[relationalParent],'A checked descendant restyles the :has target')
	local relationalTree=renderer.build(relationalDocument,{},error,nil,nil,nil,nil,'#parent:has(input:checked)>#result{color:green}')
	assert(relationalTree.NodeStyles[relationalResult].Color~=Color3.fromRGB(0,128,0),'The target starts without the checked style')
	local renderedChange=relationalTree:SetCSSState('form-state',checked['form-state'])
	assert(renderedChange,'The rendered target notices the live :has state change')
	assert(relationalTree.NodeStyles[relationalResult].Color==Color3.fromRGB(0,128,0),'The rendered target receives the live :has style')
	local placeholderDocument=Parser.parse('<input id="probe" placeholder="Hint">')
	local placeholderTree=renderer.build(placeholderDocument,{},error,nil,nil,nil,nil,'input::placeholder,textarea::placeholder{color:#64776f}')
	assert(placeholderTree.Controls[1].Item.Editor.PlaceholderColor3==Color3.fromRGB(100,119,111),'::placeholder styles the native Roblox text field')
	local html = '<div id="parent"><p id="text" class="note">Test</p></div>'
	local css = 'div {font-family: Missing, Inter, sans-serif; color: blue} .note {font-size: 24px; padding: 3px}'
	local separate, separateWarnings, separateDocument = render(html, css)
	local embedded = render('<style>' .. css .. '</style>' .. html)
	assert(#separateWarnings == 0 and #separateDocument.Children == 1, 'Separate CSS must not rewrite the DOM')
	assert(DOM.findById(separateDocument, 'text').Attributes.style == nil)
	for _, key in {'Font', 'Color', 'FontSize'} do assert(separate.text.Style[key] == embedded.text.Style[key]) end
	assert(separate.text.Style.Padding[1] == 3)
	assert(separate.text.Style.Font == 'Inter' and separate.text.Children[1].Items[1].Style.Font == 'Inter')
	boxes, warnings = render('<style>p {color:red} #specific {color:red} #important {color:red !important}</style>'
		.. '<p id="normal">A</p><p id="specific">B</p><p id="important">C</p><p id="inline" style="color:red">D</p>'
		.. '<p id="inline-important" style="color:red !important">E</p>',
		'p {color:blue} #inline-important {color:blue !important}')
	assert(#warnings == 0 and boxes.normal.Style.Color == Color3.fromRGB(0, 0, 255))
	for _, id in {'specific', 'important', 'inline', 'inline-important'} do
		assert(boxes[id].Style.Color == Color3.fromRGB(255, 0, 0), 'Separate CSS respects specificity, inline styles and important')
	end
	boxes = render('<style>p {color:red !important}</style><p id="text">A</p>', 'p {color:blue !important}')
	assert(boxes.text.Style.Color == Color3.fromRGB(0, 0, 255), 'Tied important rules use sheet order')
	boxes, warnings = render('<p id="text">Safe</p>', 'p {unknown: "</style><p id=bad>"; color:green}')
	assert(#warnings == 1 and not boxes.bad and boxes.text.Style.Color == Color3.fromRGB(0, 128, 0), 'CSS strings are never parsed as HTML')
	for _, extra in {'', '/* empty sheet */'} do
		boxes, warnings = render('<style>p {color:red}</style><p id="text">A</p>', extra)
		assert(#warnings == 0 and boxes.text.Style.Color == Color3.fromRGB(255, 0, 0))
	end
	boxes = render(html)
	assert(boxes.text.Style.FontSize == 16, 'Separate CSS cannot leak to another render')
	assert(boxes.text.Style.Font == 'PT Serif', 'Pages without CSS font use the engine default')
	local fallbackHTML = '<div id="parent" style="font-family:Roboto"><p id="inherited">A</p><p id="missing" style="font-family:Unknown">B</p><p id="explicit" style="font-family:Unknown, Ubuntu, sans-serif">C</p><p id="generic" style="font-family:monospace">D</p></div><p id="default">E</p><code id="code">F</code>'
	for _, defaultFont in {'PT Serif', 'Inter'} do
		boxes = render(fallbackHTML, nil, defaultFont)
		assert(boxes.inherited.Style.Font == 'Roboto', 'No declaration inherits the parent font')
		assert(boxes.missing.Style.Font == defaultFont and boxes.default.Style.Font == defaultFont)
		assert(boxes.explicit.Style.Font == Enum.Font.Ubuntu and boxes.generic.Style.Font == 'Roboto Mono')
		assert(boxes.parent.Style.DefaultFont == defaultFont)
		assert(boxes.missing.Children[1].Items[1].Style.Font == defaultFont)
	end
	boxes = render('<p id="text">G</p>')
	assert(boxes.text.Style.Font == 'PT Serif', 'A page override cannot change later pages')
	local pseudoDocument=Parser.parse('<p id="generated" data-label="value">Body</p>')
	local pseudoNode=DOM.findById(pseudoDocument,'generated')
	local pseudoRules=Stylesheet.collect(pseudoDocument,error,'p::before{content:"Before " attr(data-label);color:red} p::after{content:" After"} p::marker{content:"✓ "}')
	assert(#Stylesheet.match(pseudoRules,pseudoNode).Normal==0,'Pseudo-element declarations do not style the originating element')
	local before=Stylesheet.matchPseudo(pseudoRules,pseudoNode,'before')
	assert(#before.Normal==2 and before.Normal[1].Field=='GeneratedContent' and before.Normal[2].Field=='Color')
	assert(#Stylesheet.matchPseudo(pseudoRules,pseudoNode,'after').Normal==1 and #Stylesheet.matchPseudo(pseudoRules,pseudoNode,'marker').Normal==1)
	local selectionWarnings={}
	local selectionRules=Stylesheet.collect(pseudoDocument,function(message) table.insert(selectionWarnings,message) end,
		'::selection{background:#c4eaa5;color:#153f36} #generated::selection{background:#8555b4}')
	local selection=Stylesheet.matchPseudo(selectionRules,pseudoNode,'selection')
	assert(#selectionWarnings==0 and #selection.Normal==3,'Global and scoped ::selection rules compile and match')
	assert(#Stylesheet.match(selectionRules,pseudoNode).Normal==0,'Selection colors do not style ordinary text')
	local pickerDocument=Parser.parse('<select id="picker" class="custom-select"><option>One</option></select>')
	local pickerNode=DOM.findById(pickerDocument,'picker')
	local pickerWarnings={}
	local pickerRules=Stylesheet.collect(pickerDocument,function(message) table.insert(pickerWarnings,message) end,
		'.custom-select,.custom-select::picker(select){appearance:base-select}')
	assert(#pickerWarnings==0 and #Stylesheet.match(pickerRules,pickerNode).Normal==1
		and #Stylesheet.matchPseudo(pickerRules,pickerNode,'picker(select)').Normal==1,
		'Custom select and its picker share a valid base-select appearance rule')
	boxes,warnings=render('<p id="generated" data-label="value">Body</p><ul><li id="marked">Item</li></ul>',
		'#generated::before{content:"Before " attr(data-label) " ";color:red} #generated::after{content:" After"} #marked::marker{content:"✓ ";color:blue}')
	local generatedItems=boxes.generated.Children[1].Items
	local generatedText=''
	for _,item in generatedItems do if item.Text then generatedText..=(if item.SpaceBefore and generatedText~='' then ' ' else '')..item.Text end end
	assert(#warnings==0 and generatedText=='Before value Body After' and generatedItems[1].Style.Color==Color3.fromRGB(255,0,0))
	assert(boxes.marked.Marker.CustomText=='✓ ' and boxes.marked.Marker.Style.Color==Color3.fromRGB(0,0,255))
	boxes,warnings=render('<div class="card" id="parent"><p id="child" data-x="&">Nested</p><section><p id="deep">Deep</p></section></div><p id="sibling">Sibling</p>',
		'.card,#unmatched{color:red;>p{color:green}& + p{color:blue}section{p{font-size:22px}}[data-x="&"]{background-color:#123456}} .card > p{color:purple} .card{&{color:blue}color:orange}')
	assert(#warnings==0,table.concat(warnings,' / '))
	assert(boxes.child.Style.Color==Color3.fromRGB(0,128,0),'The nesting selector takes maximum parent-list specificity, even when the ID branch did not match')
	assert(boxes.sibling.Style.Color==Color3.fromRGB(0,0,255)and boxes.deep.Style.FontSize==22,'Sibling selectors and multi-level implicit nesting must match')
	assert(boxes.child.Style.Background==Color3.fromRGB(18,52,86),'Ampersands in quoted attribute values must stay literal')
	assert(boxes.parent.Style.Color==Color3.fromRGB(255,165,0),'Declarations after a child rule retain their source order')
	local nestedDocument=Parser.parse('<div class="card" id="nested-media">X</div>')
	local nestedNode=DOM.findById(nestedDocument,'nested-media');local nestedWarnings={}
	local nestedRules=Stylesheet.collect(nestedDocument,function(message)table.insert(nestedWarnings,message)end,
		'.card{color:red;@media(min-width:700px){color:blue;@supports(width:20px){width:120px}}@layer inner{padding:3px}}')
	Stylesheet.setMediaEnvironment(nestedRules,{Width=800,Height=600})
	boxes,warnings=render('<div class="card" id="nested-groups">X</div>',
		'.card{color:red;@supports(width:20px){color:blue;@layer inner{padding:3px}}}')
	assert(#warnings==0 and boxes['nested-groups'].Style.Color==Color3.fromRGB(0,0,255)and boxes['nested-groups'].Style.Padding[1]==3,'Nested conditional/layer declaration blocks must inherit the enclosing selector')
	assert(#nestedWarnings==0 and #Stylesheet.match(nestedRules,nestedNode).Normal>=3,'Nested media declarations must retain their environment dependency')
	boxes,warnings=render('<div class="p" id="pseudo-parent">P</div>',
		'.p,#missing::before{&{color:red}}.p{color:green}')
	assert(#warnings==0 and boxes['pseudo-parent'].Style.Color==Color3.fromRGB(0,128,0),
		'Nesting cannot represent a pseudo-element parent branch; its invalid :is branch must not alter specificity')
	boxes,warnings=render('<div class="p" id="pseudo-tail">P</div>',
		'.p,.p::before{color:red;&{color:blue}color:orange;content:"X"}')
	assert(#warnings==0 and boxes['pseudo-tail'].Style.Color==Color3.fromRGB(255,165,0))
	local pseudoTail=false
	for _,run in boxes['pseudo-tail'].Children do for _,item in run.Items or {}do
		if item.Style.PseudoElement=='before'then pseudoTail=true;assert(item.Style.Color==Color3.fromRGB(255,165,0),'Trailing CSSNestedDeclarations must style the pseudo-element with its original parent selector')end
	end end
	assert(pseudoTail,'Mixed element/pseudo-element parent declarations must retain generated content')
	boxes,warnings=render('<article class="card"><p id="scoped-child">P</p><section class="excluded"><p id="excluded-child">Q</p></section></article><p id="outside-scope">R</p>',
		'p{color:green}.card{@scope (&) to (> .excluded){p{color:blue}}}')
	assert(#warnings==0 and boxes['scoped-child'].Style.Color==Color3.fromRGB(0,0,255)
		and boxes['excluded-child'].Style.Color==Color3.fromRGB(0,128,0)and boxes['outside-scope'].Style.Color==Color3.fromRGB(0,128,0),
		'Nesting selectors in @scope boundaries reference the containing style; scope limits still exclude their subtree')
	boxes,warnings=render('<div class="p" id="pseudo-group">P</div>',
		'.p::before{content:"X";&{color:red}@media(min-width:0px){color:purple}}')
	assert(#warnings==0)
	for _,run in boxes['pseudo-group'].Children do for _,item in run.Items or {}do if item.Style.PseudoElement=='before'then
		assert(item.Style.Color==Color3.fromRGB(128,0,128),'Declarations inside a nested group target an all-pseudo parent even though explicit & cannot')
	end end end
	-- Subject-only form selectors compare changed subjects, not thousands of
	-- unrelated page elements. Relational and filtered sibling dependencies
	-- still require the general path and must not miss affected nodes.
	local stateDocument=Parser.parseDocument('<!doctype html><body><fieldset id="field"><input id="state-check" type="checkbox"><input id="state-range" type="number" min="3" max="7"><select id="state-select"><option id="state-a" selected>A</option><option id="state-b">B</option></select><span id="state-child">Child</span></fieldset><div id="state-sibling">Sibling</div>'..string.rep('<div>Quiet</div>',2000)..'</body>')
	local function stateNode(id)return assert(DOM.findById(stateDocument,id))end
	local checkbox,number,select,a,b=stateNode('state-check'),stateNode('state-range'),stateNode('state-select'),stateNode('state-a'),stateNode('state-b')
	local before={['form-state']={[checkbox]={Type='checkbox',Checked=false},[number]={Type='number',Value='4'},[select]={Type='select',SelectedOptions={[a]=true}}}}
	local after={['form-state']={[checkbox]={Type='checkbox',Checked=true},[number]={Type='number',Value='9'},[select]={Type='select',SelectedOptions={[b]=true}}}}
	local localRules=Stylesheet.collect(stateDocument,error,'input:is(:checked){color:red}input:out-of-range{color:blue}option:checked{color:green}')
	local selectors=require('CSS/Selectors');local nativeMatch=selectors.matches;local visits=0
	selectors.matches=function(...)visits+=1;return nativeMatch(...)end
	local updated,changed=Stylesheet.stateChanges(localRules,stateDocument,'form-state',before,after)
	selectors.matches=nativeMatch
	assert(updated and changed[checkbox]and changed[number]and changed[a]and changed[b]and not changed[select],'Current form/option states invalidate their actual subjects')
	-- Five candidate subjects, three outer tests twice, plus the nested :is
	-- test for the two input candidates on both snapshots.
	assert(visits<=34,'Subject-only state matching scanned unrelated page elements: '..visits)
	local generalRules=Stylesheet.collect(stateDocument,error,'fieldset:has(input:checked)+div{color:red}input:nth-child(1 of :checked){color:blue}option:nth-child(1 of :checked){color:green}')
	updated,changed=Stylesheet.stateChanges(generalRules,stateDocument,'form-state',before,after)
	assert(updated and changed[stateNode('state-sibling')]and changed[checkbox]and changed[a]and changed[b],'Relational and filtered sibling state rules retain their necessary broader invalidation')
	print("Stylesheets: embedded/linked/separate CSS, original DOM, nesting/source order/specificity, inheritance, cascade, important, isolation and unsupported CSS passed")
end
