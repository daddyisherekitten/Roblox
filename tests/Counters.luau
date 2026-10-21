--!strict
return function(Parser: any,Style: any,Counters: any,loadRenderTree: any)
 local fixtureElement=require('DOM/Node').element
	local parent={FontSize=16,Font="Arial",Color=Color3.new(0,0,0)}
	local function resolve(css: string,warnings: any?): any
		return Style.resolve(fixtureElement("div",{style=css}),parent,function(message)
			if warnings then table.insert(warnings,message) else error(message) end
		end,true)
	end
	local parsed=resolve('counter-reset:chapter 2 item;counter-increment:chapter 3;counter-set:item 7')
	assert(parsed.CounterReset[1].Name=="chapter" and parsed.CounterReset[1].Value==2)
	assert(parsed.CounterReset[2].Name=="item" and parsed.CounterReset[2].Value==0)
	assert(parsed.CounterIncrement[1].Value==3 and parsed.CounterSet[1].Value==7)
	assert(Counters.parse('ReVeRsEd(-chapter)',0,true)[1].Name=='-chapter'and Counters.parse('NONE',0)and not Counters.parse('-1',0),'Counter keywords are case insensitive while valid hyphenated names remain case sensitive')
	assert(Counters.format(8,"decimal-leading-zero")=="08" and Counters.format(27,"upper-alpha")=="AA")
	assert(Counters.format(14,"lower-roman")=="xiv")
	local part,finish=Counters.content('counter(chapter, upper-roman)',1)
	assert(part and finish and part.Name=="chapter" and part.Style=="upper-roman")
	part,finish=Counters.content('counters(item, ".", decimal-leading-zero)',1)
	assert(part and finish and part.Kind=="counters" and part.Separator=="." and part.Style=="decimal-leading-zero")
	local warnings={}
	local invalid=resolve('counter-reset:none extra;counter-increment:item 1.5',warnings)
	assert(#warnings==2 and #invalid.CounterReset==0 and #invalid.CounterIncrement==0)

	local labels={}
	local renderer=loadRenderTree({create=function(className: string,_,props: any)
		local gui=table.clone(props);gui.ClassName=className
		if className=="TextLabel" and type(gui.Text)=="string" then table.insert(labels,gui.Text) end
		return gui
	end})
	local source=[==[
		<style>
		body{counter-reset:section}
		h2{counter-increment:section}
		h2::before{content:"S" counter(section,upper-roman) " "}
		.jump{counter-set:section 9}
		.outline,.outline ol{counter-reset:item;list-style-type:none}
		.outline li{counter-increment:item}
		.outline li::before{content:counters(item,".") " "}
		.tasks{counter-reset:task;list-style-type:decimal}
		.tasks li{counter-increment:task}
		.tasks li::marker{content:"T" counter(task) " ✓ "}
		</style><body><h2>A</h2><h2 class="jump">B</h2><ol class="outline"><li>Outer<ol><li>Inner</li></ol></li></ol><ol class="tasks"><li>Task</li></ol></body>
	]==]
	local tree=renderer.build(Parser.parse(source),{AbsoluteSize={X=800,Y=600}},error)
	local text=table.concat(labels,"|")
	assert(text:find("SI",1,true),text)
	assert(text:find("SIX",1,true),text)
	assert(text:find("1.1",1,true),text)
	local customMarker
	local pending={tree}
	while #pending>0 do
		local box=table.remove(pending)
		if box.Marker and box.Marker.Kind=="custom" then customMarker=box.Marker.CustomText end
		for _,child in box.Children or {} do table.insert(pending,child) end
	end
	assert(customMarker=="T1 ✓ ",customMarker or "missing custom marker")
	labels={}
	renderer.build(Parser.parse('<style>h2{counter-reset:chapter 5}p{counter-increment:chapter}p::before{content:counters(chapter,".")" "}</style><body><h2>Reset</h2><p>First</p><p>Second</p><h2>Reset again</h2><p>Third</p></body>'),{},error)
	text=table.concat(labels,'|')
	assert(table.find(labels,'6')and table.find(labels,'7')and not text:find('5.6',1,true),'Sibling reset scopes must survive element leave and replace prior sibling instance: '..text)
	local state=Counters.new()
	Counters.enter(state,{CounterReset={{Name='x',Value=2}}})
	Counters.enter(state,{CounterReset={{Name='x',Value=5}}});Counters.leave(state)
	Counters.enter(state,{CounterIncrement={{Name='x',Value=1}}})
	assert(Counters.render(state,{Kind='counters',Name='x',Style='decimal',Separator='.'})=='2.6','Sibling scope must retain the inner counter alongside its ancestor')
	Counters.leave(state);Counters.leave(state)
	Counters.enter(state,{CounterIncrement={{Name='x',Value=1}}})
	assert(Counters.render(state,{Kind='counters',Name='x',Style='decimal',Separator='.'})=='3','Leaving the parent must end all child sibling counter scopes')
	Counters.leave(state)
	-- HTML presentational hints feed the same counter as author generated
	-- content, including nested lists and display:list-item on arbitrary tags.
	labels={}
	local listTree=renderer.build(Parser.parse([=[<style>
	li::before,.css-item::before{content:"(" counters(list-item,".") ") "}
	.evens>li{counter-increment:list-item 2}.paused{counter-increment:list-item 0}
	.no-increment{counter-increment:none}.css-item{display:list-item;list-style-type:decimal}
	.override{counter-reset:list-item 10}.set{counter-set:list-item 6}
	</style><body><ol start="  +5tail"><li id="first">First</li><li value="9tail" id="value">Value</li><li id="next">Next</li></ol>
	<ol reversed start="9"><li id="reverse-first">First</li><li value="4" id="reverse-set">Set</li><li id="reverse-last">Last</li></ol>
	<ol reversed><li id="auto-first">First<ol><li id="inner-first">Inner</li><li id="inner-last">Inner</li></ol></li><li id="auto-last">Last</li></ol>
	<ol reversed><li id="native-first">Native marker</li><li id="native-set" value="7">Native value</li><li id="native-next">Native next</li></ol>
	<ol class="evens"><li id="even-first">Even</li><li id="even-last">Even</li></ol>
	<ol><li class="no-increment" id="ordinary">Ordinary</li><li class="paused" id="paused">Paused</li><li class="set" value="99" id="author-set">Author set</li></ol>
	<ol class="override" start="100"><li id="author-reset">Author reset</li></ol><div class="css-item" id="css-item">CSS item</div></body>]=]),{},error)
	local function number(id)
		for node,box in listTree.NodeBoxes do if node.Attributes and node.Attributes.id==id then return box.Marker and box.Marker.Number end end
		return nil
	end
	for id,expected in {first=5,value=9,next=10,['reverse-first']=9,['reverse-set']=4,['reverse-last']=3,['auto-first']=2,['auto-last']=1,['native-first']=3,['native-set']=7,['native-next']=6,['inner-first']=1,['inner-last']=2,['even-first']=2,['even-last']=4,ordinary=1,paused=1,['author-set']=6,['author-reset']=11,['css-item']=12}do
		assert(number(id)==expected,id..' expected '..expected..' got '..tostring(number(id)))
	end
	text=table.concat(labels,'|');assert(text:find('(2.1)',1,true)and text:find('(12)',1,true),'Implicit counters and custom marker numbers must share the same state: '..text)
	assert(text:find('(8)',1,true),'CSS reversed() auto count before a later value hint must remain separate from the native HTML marker ordinal 3')
	local relativeTree=renderer.build(Parser.parse('<style>body{font-size:20px}section{font-size:1.5em}h2{font-size:.5em}</style><body><ol reversed><li id="relative-first">First</li><li id="relative-second"><section><h2 id="relative-later">Later subtree</h2></section></li></ol></body>'),{},error)
	for node,box in relativeTree.NodeBoxes do
		local id=node.Attributes and node.Attributes.id
		if id=='relative-later'then assert(box.Style.FontSize==15,'Counter lookahead must preserve relative font inheritance through unvisited ancestors')
		elseif id=='relative-first'then assert(box.Marker.Number==2,'Reversed native ordinals must survive lookahead into a future subtree')end
	end
	relativeTree:GeneratedChanges(true)
	assert(next(relativeTree:GeneratedChanges(true))==nil,'Repeated generated-counter pass must preserve inherited lookahead styles and stable marker output')
	part,finish=Counters.content('counters(chapter, "\\2e ", symbols(numeric "0" "1")) tail',1)
	assert(part and part.Separator=='.'and finish and part.Style.System=='numeric','Balanced anonymous counter syntax and escaped separators failed')
	state=Counters.new();Counters.enter(state,{})
	assert(Counters.render(state,{Kind='counter',Name='missing',Style='none'})==''and Counters.value(state,'missing')==0 and state.Values.missing,'Reading a missing counter must instantiate it even with style none')
	Counters.leave(state)
	print("Counters: parsing, formatting, scope nesting, generated content and custom markers passed")
end
