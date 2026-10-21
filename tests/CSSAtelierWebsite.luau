--!strict
-- Run the delivered browser script against mounted DOM/CSS/control surfaces.
return function(Parser,Node,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,FormModel,html,css,app,svgs,fontReference)
	local function signal()
		local entries={};local api={}
		function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(entries,{c,fn});return c end
		function api:Fire(...)for _,entry in table.clone(entries)do if entry[1].Connected then entry[2](...)end end end
		return api
	end
	local guis={};local factory={}
	function factory.create(class,parent,properties)
		local gui=table.clone(properties);gui.ClassName=class;gui.Parent=parent;gui.Visible=true
		gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(1120,900)
		if class=="ScrollingFrame"then gui.CanvasPosition=Vector2.new(0,0)end
		gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal();local attributes,signals={},{}
		function gui:GetPropertyChangedSignal(key)if not signals[key]then signals[key]=signal()end;return signals[key]end
		function gui:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal("attribute:"..key)end
		function gui:SetAttribute(key,value)attributes[key]=value;if signals["attribute:"..key]then signals["attribute:"..key]:Fire()end end
		function gui:GetAttribute(key)return attributes[key]end
		function gui:IsA(kind)return kind==class or kind=="GuiObject"end
		function gui:IsFocused()return false end
		function gui:Destroy()assert(not self.Destroyed,"GUI disposed twice");self.Destroyed=true;for _,child in guis do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil end
		table.insert(guis,gui);return gui
	end
	factory.modifier=factory.create
	local effectImages={}
	function factory.createImage(size)
		local image={Size=size};function image:WritePixelsBuffer(_,_,pixels)self.Pixels=pixels end
		function image:Destroy()assert(not self.Destroyed);self.Destroyed=true end
		table.insert(effectImages,image);return image
	end
	local textMeasurements=0
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)textMeasurements+=1;return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	local words=loadWordLayout(overrides);overrides["Layout/WordLayout"]=words;local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local document=Parser.parseDocument(html,{ScriptingEnabled=true});assert(#document.Diagnostics==0,table.concat(document.Diagnostics," | "))
	local svgNodes={};for name,source in svgs do svgNodes[name]=assert(Node.findElement(Parser.parse(source),function(n)return n.Name=="svg"end))end
	local url="http://localhost:8000/css-atelier/index.html";local messages={}
	local root=factory.create("ScrollingFrame",nil,{})
	local function svg(reference)return svgNodes[reference]or svgNodes[reference:gsub("^http://localhost:8000/css%-atelier/","")]end
	local tree=renderer.build(document,root,function(message)table.insert(messages,message)end,function(font)return font end,nil,nil,nil,nil,nil,nil,nil,nil,{["styles.css"]=css,["tokens.css"]=":root{--imported-color:#dc654c}",["namespaces.css"]="@namespace svg url(\"http://www.w3.org/2000/svg\");.namespace-preview svg|text{fill:#dc654c;font:32px Georgia,serif}"},url,nil,nil,nil,nil,svg)
	local events=require("Input/Events").new(error);local model=FormModel.new(document,tree.Controls,events,function()end)
	local page={Alive=true,Document=document,DocumentURL=url,BaseURL=url,Root=root,Events=events,FormModel=model,Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	function page:RefreshDOMControls()model:RefreshControls()end
	local width=1120;local arrangements,realm,flushing=0,nil,false;local lastLayoutStats
	function page:GeometryViewport()return {Width=width,Height=900,ClientWidth=width,ClientHeight=900,ScrollWidth=width,ScrollHeight=tree.OuterHeight or 900,ScrollX=0,ScrollY=0}end
	function page:HasPendingLayout()return false end
	local function arrange(targets)
		arrangements+=1;tree:SetMediaEnvironment(width,900);tree.ViewportHeight=900
		for pass=1,8 do
			lastLayoutStats=Dirty.begin(tree,targets);layout.arrange(tree,width,0,0,function()return true end);Dirty.finish(tree,true)
			local _,needed,items=tree:RefreshContainerSizes();if not needed then break end;targets=items;assert(pass<8,'Container styles did not converge')
		end
	end
	function page:FlushScriptLayout()
		if flushing or not realm then return end;flushing=true
		local needed,targets=realm:Flush()
		if needed then
			local remaining={};for item,reason in targets or {}do
				if not tree:CanKeepTextLayout(item,words.arrange,function()return true end)then remaining[item]=reason end
			end
			if next(remaining)then arrange(remaining)end
		end
		flushing=false
	end
	local callbacks={};local clock=0;local storageArea=require("JavaScript/Storage").createArea()
	local services={Clock=function()return clock end,RunService={RenderStepped=signal()},Task={delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Cancelled=true end},
		ScriptSources={[url:gsub("index.html$","app.js")]=app},GetStorageArea=function()return storageArea end,
		LoadImage=function(reference,complete,spec)
			table.insert(callbacks,function()local asset=svg(spec.Source or reference);if asset then complete(true,{Width=480,Height=240})else complete(false,"Missing image")end end)
		end,
		LoadFont=function(_,complete)table.insert(callbacks,function()complete(true,{Family="arial"})end)end}
	arrange();root:SetAttribute("Status","ready")
	realm=HTMLScripts.start(page,tree,function()end,function(message)table.insert(messages,message)end,{JavaScriptServices=services})
	local function settle()
		for attempt=1,40 do
			local pending=callbacks;callbacks={};for _,complete in pending do complete()end
			page:FlushScriptLayout();realm:AfterLayout();clock+=.01;local tasks=realm:PumpTasks()
			if #callbacks==0 and tasks==0 and not realm:HasPending()then break end
			assert(attempt<40,"Website tasks did not converge")
		end
		page:FlushScriptLayout()
	end
	local function node(id)return assert(Node.findById(document,id),id)end
	local function text(id)return Node.textContent(node(id))end
	local function run(source)local ok,err=realm:Run(source);assert(ok,tostring(err));settle()end
	local function click(id)run("document.getElementById('"..id.."').click();")end
	settle()
	local productNode=assert(Node.findElement(document,function(n)return n.Attributes.class=='product-grid'end))
	local productGrid=tree.NodeBoxes[productNode];local productHeight=productGrid.OuterHeight
	local productGuis={};for _,card in productGrid.Children do table.insert(productGuis,card.Gui)end
	local function checkProducts()
		local stacked=productGrid.GridLayout.Columns.Last==1
		for index,card in productGrid.Children do
			local title,description,link=card.Children[1],card.Children[2],card.Children[3]
			local gap=if stacked then 12 else 16
			local function near(a,b)assert(math.abs(a-b)<.001,'Subgrid geometry: '..a..' != '..b)end
			near(title.LayoutY,23);near(description.LayoutY,title.LayoutY+title.OuterHeight+gap)
			near(link.LayoutY,description.LayoutY+description.OuterHeight+gap)
			near(card.OuterHeight,link.LayoutY+link.OuterHeight+23)
			assert(card.Gui==productGuis[index],'Product cards retain their surfaces')
			if not stacked then
				near(card.OuterHeight,productGrid.OuterHeight)
				near(description.LayoutY,productGrid.Children[1].Children[2].LayoutY)
				near(link.LayoutY,productGrid.Children[1].Children[3].LayoutY)
			end
		end
	end
	checkProducts()
	assert(productHeight<380,'Three-column cards must fit their content rather than inflated inherited heights: '..productHeight)
	run([=[
	function verify(value,message){if(!value)throw new Error(message);}
	for(const feature of ['layers','variables','selectors','shadow','container','media-range','text-box','subgrid','colors','image-set','scroll-timeline','anchor','interpolate-size','composition','waapi','typed-om','highlight']) {
	 verify(document.querySelector('[data-feature="'+feature+'"]').classList.contains('available'),'feature unavailable: '+feature);
	}
	verify(!document.querySelector('[data-feature="view-transition"]').classList.contains('available'),'unsupported snapshots must stay unavailable');
	]=])
	local function style(id)return assert(tree.NodeStyles[node(id)],id)end
	local function color(actual,r,g,b)return actual and math.abs(actual.R-r/255)<.0001 and math.abs(actual.G-g/255)<.0001 and math.abs(actual.B-b/255)<.0001 end
	local blendBox=tree.NodeBoxes[node('blend-stage')];local blendChildren=blendBox.Children
	local initialBlendLayouts=arrangements;local blendGuis={blendChildren[1].Gui,blendChildren[2].Gui};local initialBlendPositions={blendChildren[1].PaintX,blendChildren[2].PaintX}
	for _,mode in {'screen','difference','multiply','normal','multiply'}do
		run("document.getElementById('blend-mode').value='"..mode.."';document.getElementById('blend-mode').dispatchEvent(new Event('change'));")
		assert(blendChildren[2].Style.MixBlendMode==mode and color(blendChildren[2].Style.Background,65,100,200),'The real blend callback retains its specified blue color')
		assert(arrangements==initialBlendLayouts and blendChildren[1].Gui==blendGuis[1]and blendChildren[2].Gui==blendGuis[2],'Blend mode changes paint without layout or replacing native elements')
		assert(blendChildren[1].PaintX==initialBlendPositions[1]and blendChildren[2].PaintX==initialBlendPositions[2]and initialBlendPositions[1]~=initialBlendPositions[2],'Mode changes retain distinct painted positions')
		if mode~='normal'then assert(blendBox.CompositeSurface,'The real script must update the shared composition path')end
	end
	local effectItem=tree.NodeBoxes[node('effect-image')].ImageItem;local effectGui=effectItem.Gui
	local effectLayouts=arrangements
	run("document.getElementById('clip-check').checked=true;document.getElementById('clip-check').dispatchEvent(new Event('change'));")
	assert(arrangements==effectLayouts,'Clip must only repaint the image: '..tree.NodeBoxes[node('effect-image')].Kind)
	run("document.getElementById('mask-check').checked=true;document.getElementById('mask-check').dispatchEvent(new Event('change'));")
	assert(arrangements==effectLayouts,'Mask must only repaint the image')
	run("document.getElementById('effect-image').style.filter='blur(7px)';")
	assert(arrangements==effectLayouts,'Changing the image filter alone must only repaint')
	local effectWidth,effectHeight=effectItem.BoxWidth,effectItem.BoxHeight
	run("document.getElementById('blur-range').value='7';document.getElementById('blur-range').dispatchEvent(new Event('input'));")
	assert(effectItem.Style.ClipPath and effectItem.Style.MaskImage and effectItem.Style.Filter.HasRaster and effectItem.Style.Filter.Steps[1].Value==7,'All three actual image controls update CSS paint effects')
	assert(effectItem.Gui==effectGui and effectItem.BoxWidth==effectWidth and effectItem.BoxHeight==effectHeight,'The slider also updates its text output while retaining image geometry')
	local disclosureNode=assert(Node.findElement(document,function(n)return n.Name=='details'and n.Attributes.class=='open-demo'end))
	local disclosure=tree.Disclosures[disclosureNode];local disclosureGui=disclosure.Box.Gui
	realm:ToggleDetails(disclosureNode);settle()
	assert(disclosure.Open and color(disclosure.Box.Style.Background,229,236,255)
		and color(disclosureGui.BackgroundColor3,229,236,255) and disclosureGui.BackgroundTransparency==0,
		'CSS Atelier native open state paints the blue rounded details card')
	realm:ToggleDetails(disclosureNode);settle()
	assert(not disclosure.Open and disclosureGui.BackgroundTransparency==1 and disclosure.Box.Gui==disclosureGui,
		'CSS Atelier closing details removes the blue fill without rebuilding the card')
	local original=tree.NodeBoxes[node('layer-sample')].Gui
	assert(color(style('layer-sample').Background,65,100,200),'Later layer initially wins')
	click('layer-toggle');local bg=style('layer-sample').Background;assert(color(bg,220,101,76),'revert-layer restores base layer: '..tostring(bg and bg.R)..','..tostring(bg and bg.G)..','..tostring(bg and bg.B))
	assert(tree.NodeBoxes[node('layer-sample')].Gui==original,'Cascade mutation retains native box')
	click('layer-toggle');assert(color(style('layer-sample').Background,65,100,200))
	local sample=Node.findElement(node('var-panel'),function(n)return (n.Attributes.class or ''):find('var-sample',1,true)~=nil end)
	assert(color(tree.NodeStyles[sample].Color,65,100,200),'Invalid substituted color inherits')
	local inlineStyle=require('CSS/InlineStyle');local sheet=require('CSS/Stylesheet')
	local savedResolve,savedPseudo=inlineStyle.resolve,sheet.matchPseudo;local variableResolves,variablePseudos=0,0
	local codeDetails=assert(Node.findElement(document,function(n)return n.Name=='details'and n.Attributes.class=='code-details'end))
	local disclosureResolves,disclosurePseudos=0,0
	inlineStyle.resolve=function(...)disclosureResolves+=1;return savedResolve(...)end
	sheet.matchPseudo=function(...)disclosurePseudos+=1;return savedPseudo(...)end
	local opened,openError=pcall(function()realm:ToggleDetails(codeDetails);settle()end)
	inlineStyle.resolve,sheet.matchPseudo=savedResolve,savedPseudo;assert(opened,openError)
	assert(disclosureResolves<80 and disclosurePseudos<80,'Code disclosure must not recascade unrelated page styles/pseudos')
	assert(lastLayoutStats.Mode=='partial'and lastLayoutStats.Reused>0,'Code disclosure reflows with retained unrelated layout caches')
	print('CSS Atelier code details: '..disclosureResolves..' style / '..disclosurePseudos..' pseudo checks; '..lastLayoutStats.Recomputed..' layout / '..lastLayoutStats.Reused..' cache hits')
	realm:ToggleDetails(codeDetails);settle()
	local unrelated=tree.NodeBoxes[node('cssom-tile')];local unrelatedGui,unrelatedCache=unrelated.Gui,unrelated.CachedLayout
	inlineStyle.resolve=function(element,...)
		variableResolves+=1
		return savedResolve(element,...)
	end
	sheet.matchPseudo=function(...)variablePseudos+=1;return savedPseudo(...)end
	local toggled,toggleError=pcall(run,"document.getElementById('valid-variable').checked=true;document.getElementById('valid-variable').dispatchEvent(new Event('change'));")
	inlineStyle.resolve,sheet.matchPseudo=savedResolve,savedPseudo
	assert(toggled,toggleError)
	-- A real CSS-variable + text batch previously recascaded 791 elements.
	-- Leave headroom for generated content without permitting page-wide work.
	assert(variableResolves<80,'A local variable/text mutation recascaded the page: '..variableResolves)
	assert(variablePseudos<80,'A local variable/text mutation rechecked unrelated pseudo selectors: '..variablePseudos)
	assert(unrelated.Gui==unrelatedGui and unrelated.CachedLayout==unrelatedCache,'Unrelated CSSOM card retains its GUI and layout cache')
	assert(color(tree.NodeStyles[sample].Color,220,101,76),'Valid variable paints sample')
	assert(Node.textContent(sample)=='Die Variable ist gültiges Korall.','The same batch must also update the explanation text')
	run("document.getElementById('valid-variable').checked=false;document.getElementById('valid-variable').dispatchEvent(new Event('change'));")
	assert(color(tree.NodeStyles[sample].Color,65,100,200)and Node.textContent(sample)=='Ich erbe das Blau.','Unticking restores inherited color and text')
	local keywordResolves,keywordPseudos=0,0
	inlineStyle.resolve=function(...)keywordResolves+=1;return savedResolve(...)end
	sheet.matchPseudo=function(...)keywordPseudos+=1;return savedPseudo(...)end
	local updated,updateError=pcall(run,"document.getElementById('wide-keyword').value='inherit';document.getElementById('wide-keyword').dispatchEvent(new Event('change'));")
	inlineStyle.resolve,sheet.matchPseudo=savedResolve,savedPseudo;assert(updated,updateError)
	assert(keywordResolves<80 and keywordPseudos<80,'A computed-color read/text publication must not recascade unrelated elements/pseudos: '..keywordResolves..'/'..keywordPseudos)
	assert(text('wide-result'):find('Berechnete Farbe:',1,true))
	assert(color(style('keyword-sample').Color,65,100,200)and text('wide-result')=='Berechnete Farbe: rgb(65, 100, 200)','The synchronous computed-color read must remain current')
	print('CSS Atelier local controls: checkbox '..variableResolves..' style / '..variablePseudos..' pseudo checks; color selector '..keywordResolves..' style / '..keywordPseudos..' pseudo checks')
	local story=Node.findElement(node('container-shell'),function(n)return (n.Attributes.class or ''):find('container-story',1,true)~=nil end)
	local heading=Node.findElement(story,function(n)return n.Name=='h4'end)
	local storyBox=tree.NodeBoxes[story];local imageNode=Node.findElement(story,function(n)return n.Name=='img'end)
	local imageBox=tree.NodeBoxes[imageNode];local copyBox=storyBox.Children[2]
	local imageGui,copyGui=imageBox.Gui,copyBox.Gui
	local headingRun=tree.NodeBoxes[heading].Children[1];local glyphGuis={}
	for _,item in headingRun.Items do for _,glyph in item.Glyphs or{}do glyphGuis[glyph]=glyph.Gui end end
	for stateIndex,requested in {423,560,422,421,300,600,780,420,423}do
		run("document.getElementById('container-width').value='"..requested.."';document.getElementById('container-width').dispatchEvent(new Event('input'));")
		local shell=tree.NodeBoxes[node('container-shell')]
		local native=fontReference.states[stateIndex]
		assert(native.width==requested and math.abs(shell.OuterWidth-native.shell[3])<.001
			and math.abs(tree.NodeStyles[heading].FontSize-native.fontSize)<.001,'Actual native container and derived font sizes match every resize control')
		assert(math.abs(shell.OuterWidth-requested)<.001 and math.abs(storyBox.OuterWidth-(requested-2))<.001,'The query uses the content box within the bordered shell')
		if requested>422 then
			local track=(requested-60)/2
			assert(storyBox.Style.Display=='grid'and math.abs(imageBox.OuterWidth-track)<.001
				and math.abs(copyBox.OuterWidth-track)<.001,'Responsive image min-height must not widen its Grid track: '..requested..' / '..imageBox.OuterWidth)
			assert(math.abs(imageBox.LayoutX-18)<.001 and math.abs(copyBox.LayoutX-(18+track+22))<.001,'Image and copy share two equal tracks with the declared gap')
			assert(imageBox.OuterHeight>=230 and copyBox.LayoutX+copyBox.OuterWidth<=storyBox.OuterWidth-18+.001,'Copy remains inside the card and image retains its minimum height')
			assert(math.abs(imageBox.OuterWidth-native.image[3])<.001 and math.abs(copyBox.OuterWidth-native.copy[3])<.001,'Equal Grid tracks are independently confirmed by the actual native text/CSS controls')
		else
			assert(storyBox.Style.Display~='grid'and math.abs(imageBox.OuterWidth-(requested-38))<.001,'At or below 420px content width the image uses the padded single column')
			assert(copyBox.LayoutY>=imageBox.LayoutY+imageBox.OuterHeight,'Narrow copy follows the image instead of staying beside it')
		end
		assert(imageBox.Gui==imageGui and copyBox.Gui==copyGui,'Crossing the container breakpoint retains image/copy surfaces')
		assert(tree.NodeBoxes[heading].Children[1]==headingRun,'A container font resize retains the actual heading word owner')
		for _,item in headingRun.Items do if item.Glyphs then
			local size=math.ceil(item.Style.FontSize);local expected=#item.Glyphs*size*.45+(#item.Glyphs-1)*(item.Style.LetterSpacing or 0)
			assert(item.MeasuredSize==size and math.abs(item.Width-expected)<.001,'Placed tracked words must use current font bounds after repeated pure probes')
			for _,glyph in item.Glyphs do assert(glyph.Gui==glyphGuis[glyph] and math.abs(glyph.Width-size*.45)<.001,'Font-dependent Grid reflow retains each glyph GUI and publishes its new measured width')end
		end end
		local warm=textMeasurements;local allocated=#guis
		for _,minimum in {true,false,true}do layout.naturalWidth(copyBox,storyBox.ContentWidth,function()return true end,minimum)end
		assert(textMeasurements==warm and #guis==allocated,'Warm container-font intrinsic queries reuse bounds without allocating glyphs or remeasuring native text')
	end
	run("document.getElementById('container-width').value='300';document.getElementById('container-width').dispatchEvent(new Event('input'));")
	assert(tree.NodeStyles[story].Display~='grid'and tree.NodeStyles[heading].FontSize==24,'Narrow container reflows and clamps type')
	run("document.getElementById('container-width').value='600';document.getElementById('container-width').dispatchEvent(new Event('input'));")
	assert(tree.NodeStyles[story].Display=='grid'and math.abs(tree.NodeStyles[heading].FontSize-35.88)<.01,'Wide container uses content width: '..tostring(tree.NodeStyles[story].Display)..' / '..tostring(tree.NodeStyles[heading].FontSize))
	local dropcap=Node.findElement(document,function(n)return n.Attributes.class=='dropcap'end);local cap=tree.NodeBoxes[dropcap].Children[1]
	assert(cap.InitialLetter and cap.Style.FontSize>50 and cap.Style.Float=='left','Initial letter projects a floating box')
	assert(cap.Children[1].Items[1].SourceSpans[1].Node==dropcap.Children[1],'Initial keeps actual DOM source boundary')
	local svgItem;for _,item in tree.SVGItems do if item.SVGDeclarations then svgItem=item;break end end
	assert(svgItem,'Inline namespace SVG has a stylesheet bridge')
	local vectorText=Node.findElement(svgItem.SVG,function(n)return n.Name=='text'end);local raw=svgItem.SVGDeclarations(vectorText,{})
	local filled=false;for _,entry in raw.Normal do if entry.Name=='fill'and entry.Value=='#dc654c'then filled=true end end;assert(filled,'Imported namespace rule reaches SVG paint')
	local tile=tree.NodeBoxes[node('cssom-tile')];local retained=tile.Gui
	click('cssom-toggle');assert(color(tile.Style.Background,220,101,76),'CSSOM rule paints actual element')
	run("document.getElementById('typed-width').value='180';document.getElementById('typed-width').dispatchEvent(new Event('input'));")
	assert(tile.Style.Width.Value==180 and tile.Gui==retained,'Typed OM changes retained layout width')
	local beforeTransform=arrangements
	run("document.getElementById('cssom-tile').attributeStyleMap.set('transform',new CSSTransformValue([new CSSTranslate(CSS.px(12),CSS.px(0)),new CSSScale(1.2,1)]));")
	assert(tile.Gui==retained and tile.Style.Transform[1].Kind=='translate'and tile.Style.Transform[1].X.Value==12 and tile.Style.Transform[2].Kind=='scale'and tile.Style.Transform[2].Value==1.2,'Typed components reach the actual retained CSS transform renderer')
	assert(arrangements==beforeTransform,'A typed transform repaint needs no geometric relayout')
	run("document.getElementById('cssom-tile').attributeStyleMap.delete('transform');")
	local shadowStage=assert(Node.findElement(document,function(n)return (' '..(n.Attributes.class or '')..' '):find(' shadow-stage ',1,true)~=nil end))
	local chip=assert(Node.findElement(shadowStage,function(n)return n.Name=='atelier-chip'end))
	local surface=assert(Node.findElement(chip.InternalShadowRoot,function(n)return n.Attributes.part=='surface'end))
	local surfaceBox=tree.NodeBoxes[surface];local surfaceGui=surfaceBox.Gui
	local surfaceBackground,surfaceBorder=surfaceBox.Style.Background,surfaceBox.Style.BorderColor
	local shadowResolves,shadowPseudos,shadowCollections=0,0,0;local savedCollect=sheet.collect
	local beforeShadowLayout=arrangements
	local beforeShadowOwners=tree.DirtyContext.Owners
	inlineStyle.resolve=function(...)shadowResolves+=1;return savedResolve(...)end
	sheet.matchPseudo=function(...)shadowPseudos+=1;return savedPseudo(...)end
	sheet.collect=function(...)shadowCollections+=1;return savedCollect(...)end
	local changedTheme,themeError=pcall(click,'shadow-toggle')
	inlineStyle.resolve,sheet.matchPseudo,sheet.collect=savedResolve,savedPseudo,savedCollect;assert(changedTheme,themeError)
	assert(shadowResolves<80 and shadowPseudos<80 and shadowCollections==0,'Outer theme must not recascade the page or rebuild shadow stylesheets')
	print('CSS Atelier outer theme: '..shadowResolves..' style / '..shadowPseudos..' pseudo checks / '..shadowCollections..' stylesheet rebuilds')
	assert(node('shadow-toggle').Attributes['aria-pressed']=='true'and color(surfaceBox.Style.Background,241,228,160)
		and color(surfaceBox.Style.BorderColor,191,167,67),'An outer class updates the exported shadow part background and border')
	assert(arrangements==beforeShadowLayout and surfaceBox.Gui==surfaceGui and tree.DirtyContext.Owners==beforeShadowOwners,
		'A shadow theme paint does not relayout, rebuild ownership or replace its surface')
	click('shadow-toggle')
	assert(surfaceBox.Style.Background==surfaceBackground and surfaceBox.Style.BorderColor==surfaceBorder,'Changing the outer theme back restores shadow paint')
	click('height-toggle');assert(node('height-toggle').Attributes['aria-expanded']=='true')
	click('height-toggle');assert(node('height-toggle').Attributes['aria-expanded']=='false')
	local flip=tree.NodeBoxes[node('flip-card')];assert(flip and flip.RichButton and flip.Scene3DSurface,'The actual button renders two 3D faces')
	local flipGui=flip.Gui
	for _,pressed in {'true','false','true','false'}do
		click('flip-card');assert(node('flip-card').Attributes['aria-pressed']==pressed)
		assert(flip.Gui==flipGui and flip.Scene3DSurface and flip.OuterHeight==210,'Turning the actual card retains its 210px layout and control')
	end
	run("document.getElementById('flip-card').disabled=true;document.getElementById('flip-card').click();")
	assert(node('flip-card').Attributes['aria-pressed']=='false','A rich button retains native disabled activation rules')
	run("document.getElementById('flip-card').disabled=false;")
	click('highlight-toggle');run("verify(CSS.highlights.has('atelier-selection'),'range registered');")
	click('highlight-toggle');run("verify(CSS.highlights.size===0,'range removed');")
	click('view-toggle');assert(text('transition-time')=='Abends','Unavailable snapshots retain real DOM image switch')
	for _,nextWidth in {390,800,1120,1120}do width=nextWidth;arrange();realm:AfterLayout();settle();checkProducts()end
	assert(math.abs(productGrid.OuterHeight-productHeight)<.001,'Returning to the initial width restores the initial Subgrid height')
	assert(tile.Gui==retained and retained.Destroyed~=true,'Responsive layout retains CSSOM element')
	for _,message in messages do
		assert(not message:match('JavaScript:')and not message:match('budget exceeded')and not message:match('did not converge'),message)
		assert(message:match('view%-transition')or message:match('font%-variation%-settings')or message:match('%-webkit%-tap%-highlight%-color'),message)
	end
	print('CSS Atelier: real script initialization, cascade, variables, queries/units, initial source ranges, SVG namespace bridge, CSSOM/Typed OM, highlights, fallback and responsive identity passed')
	for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end
	model:Destroy();events:Destroy();tree.VisualEffects:Destroy();root:Destroy()
	for _,image in effectImages do assert(image.Destroyed,'Composition textures are released with the website')end
end
