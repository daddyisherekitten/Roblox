--!strict
return function(Parser,Node,Runtime,Events,Storage,html,css,app,loadRenderTree,loadWordLayout,loadBlockLayout)
	local document=Parser.parseDocument(html);assert(#document.Diagnostics==0)
	local diagnostics={};local events=Events.new(function(value)table.insert(diagnostics,value)end)
	local area=Storage.createArea();local category=require('Controls/State').create(Node.findById(document,'category'))
	local model=require('Controls/FormModel').new(document,{category},events,function()end)
	local runtime=Runtime.new(document,{Events=events,URL='http://localhost:8000/hangman/index.html',
		ScriptSources={['http://localhost:8000/hangman/app.js']=app},
		ControlAdapter={Events=events,FocusControl=function()end,
			ResolveControl=function(node)return if node==category.Node then category else nil end,
			SetControlValue=function(node,value)assert(node==category.Node);model:SetValue(category,value)end},
		GetControl=function(node)return if node==category.Node then category.Value else nil end,
		SetControl=function(node,_,value)assert(node==category.Node);model:SetValue(category,value)end,
		GetStorageArea=function()return area end,Click=function(node)events:Emit(node,'click')end,
		Schedule=function()end,ApplyChanges=function()return false end,Diagnostic=function(value)table.insert(diagnostics,value)end})
	local function run(source)
		local ok,message=runtime:Run(source);assert(ok,tostring(message))
		for _=1,32 do runtime:Flush();if runtime:PumpTasks()==0 then break end end
		runtime:Flush();assert(#diagnostics==0,table.concat(diagnostics,' | '))
	end
	local function node(id)return assert(Node.findById(document,id),id)end
	local function text(id)return Node.textContent(node(id))end
	local function click(id)run("document.getElementById('"..id.."').click();")end
	local function key(letter)run("document.querySelector('[data-letter=\""..letter.."\"]').click();")end
	local function keyboard(letter,extra)run("document.dispatchEvent(new KeyboardEvent('keydown',{key:'"..letter.."'"..(extra or '').."}));")end
	local function setCategory(value)run("document.getElementById('category').value='"..value.."';document.getElementById('category').dispatchEvent(new Event('change'));")end
	local function solve(value)
		local guessed={};for _,code in utf8.codes(value)do local char=utf8.char(code);if not guessed[char]then key(char);guessed[char]=true end end
	end
	run('Math.random=function(){return 0;};');runtime:Start();runtime:PumpTasks();runtime:Flush()
	assert(runtime.ScriptsRun==1 and #diagnostics==0,'The actual Hangman defer script starts once')
	assert(#node('keyboard').Children==29 and text('mistakes')=='0 / 6'and text('letter-count')=='11 Buchstaben')
	assert(runtime.EventLoop.TimerCount==0,'Hangman is idle without timer work')
	local firstKey=node('keyboard').Children[1];local firstSlot=node('word').Children[1]
	key('S');assert(text('mistakes')=='0 / 6'and Node.textContent(firstSlot)=='S')
	key('S');keyboard('s');assert(text('mistakes')=='0 / 6','Repeated click or lowercase physical key cannot consume another turn')
	key('Q');key('Q');assert(text('mistakes')=='1 / 6'and node('drawing').Attributes.src=='assets/stage-1.svg','An incorrect letter adds just one mistake')
	for _,extra in {',ctrlKey:true',',repeat:true',',isComposing:true'}do
		keyboard('n',extra)
		assert(Node.textContent(node('word').Children[3])=='','Control shortcuts, repeat and composing keys do not guess')
	end
	solve('SONNENBLUME');assert(text('wins')=='1'and text('streak')=='1'and text('best-streak')=='1 Wort am Stück.')
	assert(node('result').Attributes.hidden==nil and text('result-title')=='Gut kombiniert.')
	assert(node('hint').Attributes.disabled~=nil,'Completed round locks guesses and the hint')
	local finished=text('status');key('Z');click('hint');assert(text('status')==finished,'Completed round is stable')
	run("window.saved=JSON.parse(localStorage.getItem('spielraum.hangman.records.v1'));window.savedWins=window.saved.wins;window.savedBest=window.saved.bestStreak;")
	assert(runtime.Window.Get('savedWins')==1 and runtime.Window.Get('savedBest')==1,'Personal statistics are stored')
	click('play-again');assert(text('letter-count')=='10 Buchstaben','Next word differs from the previous one')
	assert(node('keyboard').Children[1]==firstKey and node('word').Children[1]==firstSlot,'New words retain key and letter surfaces')
	assert(node('drawing').Attributes.src=='assets/stage-0.svg'and text('mistakes')=='0 / 6')
	solve('REGENBOGEN');assert(text('wins')=='2'and text('streak')=='2'and text('best-streak')=='2 Wörter am Stück.')
	click('new-round')
	for _,letter in {'Q','J','X','Y','Z','V'}do key(letter)end
	assert(text('mistakes')=='6 / 6'and text('wins')=='2'and text('streak')=='0','Exactly six distinct incorrect guesses lose and end a streak')
	assert(node('drawing').Attributes.src=='assets/stage-6.svg'and text('result-summary'):find('SONNENBLUME',1,true))
	assert(Node.textContent(node('word'))=='SONNENBLUME','Losing reveals the full word')
	local lost=text('status');key('S');assert(text('status')==lost,'Losing cannot become a late win')
	keyboard('Enter');assert(text('mistakes')=='0 / 6'and node('result').Attributes.hidden~=nil,'Enter can begin the next round')
	setCategory('places');assert(text('word-category')=='Orte & unterwegs'and text('letter-count')=='7 Buchstaben','Category '..category.Value..' picked '..text('word-category')..' / '..text('letter-count'))
	run('Math.random=function(){return .40;};')
	click('hint')
	assert(Node.textContent(node('word'))=='HH'and text('hint-note'):find('Tipp benutzt',1,true),'A hint reveals all occurrences of one unguessed letter')
	run('Math.random=function(){return 0;};')
	local hintText=text('hint-note');click('hint');assert(text('hint-note')==hintText and text('mistakes')=='0 / 6','Only one hint per round, without a mistake')
	solve('BAHNHOF');assert(text('wins')=='3'and text('streak')=='1')
	setCategory('things');key('Q');setCategory('food')
	assert(text('word-category')=='Essen & Trinken'and text('mistakes')=='0 / 6','Category changes reset the puzzle')
	solve('ERDBEERE');assert(text('wins')=='4')
	run('Math.random=function(){return .999999;};');setCategory('things');assert(text('letter-count')=='7 Buchstaben')
	solve('FAHRRAD');assert(text('wins')=='5')
	run('Math.random=function(){return .30;};');setCategory('places')
	assert(text('letter-count')=='8 Buchstaben','The umlaut word has its correct letter count')
	keyboard('ü');solve('BÜCHEREI');assert(text('wins')=='6','Umlaut input is uppercased and accepted')
	setCategory('invalid');assert(category.Value=='all','Invalid category returns to the full word list')
	for _=1,5 do click('new-round')end
	assert(#node('keyboard').Children==29 and runtime.EventLoop.TimerCount==0,'Restarts add no key nodes or background timers')
	local factory={create=function(class,parent,props)
		local gui=table.clone(props);gui.Parent=parent;gui.ClassName=class;gui.Visible=gui.Visible~=false;gui.Destroy=function()end
		gui.Position=gui.Position or UDim2.fromOffset(0,0);gui.AnchorPoint=gui.AnchorPoint or Vector2.new(0,0)
		gui.BackgroundColor3=gui.BackgroundColor3 or Color3.new(1,1,1);gui.BackgroundTransparency=gui.BackgroundTransparency or 1;gui.ZIndex=gui.ZIndex or 1
		local attributes={};function gui:SetAttribute(name,value)attributes[name]=value end;function gui:GetAttribute(name)return attributes[name]end
		function gui:IsA(kind)return kind==class or kind=='GuiObject'end;return gui
	end}
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(value,_,size)return{X=(utf8.len(value)or 0)*size*.45,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	for _,width in {320,480,1080}do
		local warnings={};local tree=renderer.build(document,factory.create('Frame',nil,{AbsoluteSize=Vector2.new(width,900)}),function(value)table.insert(warnings,value)end,nil,nil,nil,function()return 'rbxassetid://1'end,nil,nil,nil,nil,nil,{['styles.css']=css},'http://localhost:8000/hangman/index.html')
		assert(#warnings==0,table.concat(warnings,' | '));layout.arrange(tree,width,0,0,function()return true end)
		local keyboardBox=assert(tree.NodeBoxes[node('keyboard')]);assert(keyboardBox.OuterWidth<=width+.01,'The alphabet fits the viewport at '..width)
		local drawing=assert(tree:FindImageItem(node('drawing')));assert(drawing.ContentWidth>100 and drawing.ContentWidth<=300.01 and drawing.ContentHeight>50,'The illustration keeps a visible responsive surface')
		for _,keyNode in node('keyboard').Children do local box=assert(tree.NodeBoxes[keyNode]);assert(box.OuterWidth>20 and box.OuterHeight>=39.9,'Every alphabet key remains usable')end
		if tree.VisualEffects then tree.VisualEffects:Destroy()end
	end
	runtime:Destroy();model:Destroy();events:Destroy()
	print('Hangman: real script, repeated guesses, lowercase/umlauts, keyboard filters, six-part loss, complete word win, hint, statistics, retained nodes and responsive layout passed')
end
