--!strict
return function(Parser: any, Node: any, Style: any, Transform: any, loadRenderTree: any, loadWordLayout: any,Native: any?,CaseData: any?)
 local fixtureElement=require('DOM/Node').element
	assert(Transform.word("Äpfel, Öl, über Straße ß", "uppercase") == "ÄPFEL, ÖL, ÜBER STRASSE SS")
	assert(Transform.word("ÄPFEL ÖL ÜBER STRAẞE", "lowercase") == "äpfel öl über straße")
	assert(Transform.word("éàñÿ", "uppercase") == "ÉÀÑŸ")
	assert(Transform.word("ÉÀÑŸ", "lowercase") == "éàñÿ")
	assert(Transform.word("hELLO", "capitalize") == "HELLO", "Capitalize preserves the rest of the word")
	assert(Transform.word("„äpfel“", "capitalize") == "„Äpfel“")
	assert(Transform.word("eins-zwei über", "capitalize") == "Eins-Zwei Über", "Hyphens and NBSP start capitalization words without adding wrap opportunities")
	assert(Transform.word("123abc", "capitalize") == "123abc")
	assert(Transform.word("ßeta", "capitalize") == "Sseta")
	assert(Transform.word("d’art", "capitalize") == "D’art")
	assert(Transform.word("Äpfel", "none") == "Äpfel")
	assert(Transform.word("🙂東京", "uppercase") == "🙂東京")
	local parent = { FontSize = 20, Font = "Inter", Color = Color3.new(0, 0, 0) }
	local function resolve(css, inherited, warn)
		return Style.resolve(fixtureElement("span",{ style = css }), inherited or parent, warn or function(message) error(message) end, true)
	end
	local upper = resolve("text-transform: UPPERCASE")
	assert(resolve("", upper).TextTransform == "uppercase")
	assert(resolve("text-transform: none", upper).TextTransform == "none")
	local warnings = 0
	assert(resolve("text-transform: lowercase; text-transform: full-width", nil, function() warnings += 1 end).TextTransform == "full-width" and warnings == 0)
	for _,value in {'none uppercase','uppercase lowercase','math-auto full-width','full-width full-width',''}do assert(Transform.parse(value)==nil,'Invalid transform combination: '..value)end
	assert(resolve('text-transform:full-size-kana full-width uppercase').TextTransform=='uppercase full-width full-size-kana')
	assert(Transform.word('iıIİ','uppercase',false,'tr')=='İIIİ')
	assert(Transform.word('Iİİ','lowercase',false,'tr-Latn')=='ıii')
	assert(Transform.word('Iİ','lowercase',false,'tr-Arab')=='ii̇','Turkic rules apply only to Latin')
	assert(Transform.word('ÍJ̀Į̃','lowercase',false,'lt')=='i̇́j̇̀į̇̃')
	assert(Transform.word('i̇j̇','uppercase',false,'lt')=='IJ')
	assert(Transform.word('i̇gis','capitalize',false,'lt')=='Igis','Titlecase applies to the first full typographic character, including its removed dot')
	assert(Transform.word('ijssel','capitalize',false,'nl')=='IJssel')
	assert(Transform.word('ΟΣ ΟΣ́Α Σ','lowercase')=='ος οσ́α σ')
	assert(Transform.word('a ﬁ 𐐨 աև','uppercase')=='A FI 𐐀 ԱԵՒ')
	assert(Transform.word('abc123!?','full-width')=='ａｂｃ１２３！？')
	assert(Transform.word('ぁァㇰㇿ','full-size-kana')=='あアクロ')
	assert(Transform.word('aぁ','uppercase full-width full-size-kana')=='Ａあ')
	assert(Transform.word('ｧｨｩｪｫｯｬｭｮ','full-size-kana')=='ｱｲｳｴｵﾂﾔﾕﾖ')
	assert(Transform.word('ｶﾞﾊﾟ','full-width')=='ガパ','Width mapping preserves canonical combining voice marks without changing the source')
	assert(Transform.word('άυ Μάιος ή ήχος ᾆ','uppercase',false,'el')=='ΑΫ ΜΑΪΟΣ Ή ΗΧΟΣ ΑΙ')
	assert(Transform.word('άι ή σ́','uppercase',false,'el')=='ΑΪ Ή Σ','Greek combining accents use the original linguistic context and preserve decomposed representation')
	assert(Transform.word('α̂ι α̃υ α̑ι Ώ ϣ́','uppercase',false,'el')=='ΑΪ ΑΫ ΑΪ Ω Ϣ́','Greek accent lookalikes/Ohm conversion do not remove Coptic diacritics')
	assert(Transform.word('i','uppercase',false,'tr-*')=='I','Language tags cannot contain range wildcards')
	assert(Transform.word('ar aon tslí an t-uisce','uppercase',false,'ga')=='AR AON tSLÍ AN tUISCE')
	assert(Transform.word('tUISCE nATHAIR NATHAIR','lowercase',false,'ga')=='t-uisce n-athair nathair','Only an original lowercase prefix before an uppercase vowel inserts the hyphen')
	assert(Transform.word('t‐uisce t‑uisce n-Éan','uppercase',false,'ga')=='tUISCE tUISCE N-ÉAN','The conservative Irish prefix profile supports three hyphens without guessing mixed historical spelling')
	assert(Transform.word('ar aon tslí','uppercase',false,'ga-Cyrl')=='AR AON TSLÍ','Explicit non-Latin writing systems disable the Irish Latin adapter')
	local removed,removedMap=Transform.word('t-uisce','uppercase',true,'ga')
	assert(removed=='tUISCE'and removedMap[2].Hidden and removedMap[2].LastByte==1 and removedMap[3].FirstByte==2,'Irish deleted hyphens retain original source boundaries')
	local inserted,insertedMap=Transform.word('tUISCE','lowercase',true,'ga')
	assert(inserted=='t-uisce'and insertedMap[2].FirstByte==2 and insertedMap[2].LastByte==3,'The inserted display hyphen belongs to its existing vowel source interval')
	assert(Transform.word('x','math-auto')=='𝑥'and Transform.word('θ','math-auto')=='𝜃'and Transform.word('xy','math-auto')=='xy')
	local tableCases=0
	for field,mode in {Upper='uppercase',Lower='lowercase',Wide='full-width',Kana='full-size-kana',Math='math-auto'}do
		for code,expected in CaseData and CaseData[field]or{}do
			assert(Transform.word(utf8.char(code),mode)==expected,'Unicode-17 '..field..' mapping U+'..string.format('%X',code));tableCases+=1
		end
	end
	if CaseData then print('Unicode-17 runtime mapping checks: '..tableCases)end
	local labels = 0
	local renderer = loadRenderTree({ create = function(class, _, properties)
		if class == "TextLabel" then labels += 1 end
		local gui=table.clone(properties);function gui:Destroy()self.Destroyed=true end;return gui
	end })
	local document = Parser.parse([[<style>p {text-transform: uppercase !important}</style><p id="source" style="text-transform: lowercase">Straße <span style="text-transform: none">Äpfel</span> &amp; öl</p>]])
	local before = Node.textContent(document)
	local tree = renderer.build(document, {}, function(message) error(message) end)
	local run = tree.Children[1].Children[1]
	assert(labels == 4 and run.Items[1].Text == "STRASSE" and run.Items[2].Text == "Äpfel" and run.Items[4].Text == "ÖL")
	assert(run.Items[1].Gui.Text == "STRASSE" and Node.textContent(document) == before)
	assert(Node.textContent(Node.findById(document, "source")) == "Straße Äpfel & öl")
	local requests, measured = 0, {}
	local layout = loadWordLayout({
		["Layout/FontProfiles"] = { face = function(font) return font end },
		["Layout/TextMeasure"] = { measure = function(text, _, size)
			requests += 1; table.insert(measured, text)
			return { X = utf8.len(text) * 10, Y = size }
		end },
	})
	layout.arrange(run, 125, 0, 0, function() return true end)
	assert(measured[1] == "STRASSE" and run.Items[1].Width == 70 and run.Items[2].LineIndex == 2, "Measure expanded transformed text before wrapping")
	local count = requests
	layout.arrange(run, 300, 0, 0, function() return true end)
	assert(requests == count and run.Items[2].LineIndex == 1)
	local capitalized = renderer.build(Parser.parse([[<p style="text-transform: capitalize">hal<span>lo</span> über&nbsp;öl</p>]]), {}, function(message) error(message) end).Children[1].Children[1]
	assert(#capitalized.Items == 2 and capitalized.Items[1].Text == "Hallo" and capitalized.Items[2].Text == "Über Öl")
	local warned = 0
	local partial = renderer.build(Parser.parse([[<p style="text-transform: uppercase">a<span style="text-transform: lowercase">B</span></p>]]), {}, function() warned += 1 end).Children[1].Children[1]
	assert(#partial.Items == 2 and partial.Items[1].Text == "A" and partial.Items[2].Text == "b" and warned == 0, "Each styled fragment keeps its own text transform")
	local decorated = renderer.build(Parser.parse([[<p style="text-transform: uppercase; text-decoration: underline">pgjqy</p>]]), {}, function(message) error(message) end).Children[1].Children[1]
	count = requests
	layout.arrange(decorated, 300, 0, 0, function() return true end)
	assert(requests == count + 1 and #decorated.Items[1].SkipInkCuts == 0, "Skip ink uses displayed uppercase characters")
	local function displayed(value)
		local parts={};for _,item in value.Items do if item.SpaceBefore then table.insert(parts,' ')end;if item.Text then table.insert(parts,item.Text)end end;return table.concat(parts)
	end
	for _,input in {
		{'el','lowercase','Ο<span style="color:red">Σ</span>','ος'},
		{'el','lowercase','Ο<span style="color:red">Σ</span><i>́</i><b>Α</b>','οσ́α'},
		{'tr','lowercase','I<span style="color:red">̇</span>','i'},
		{'lt','lowercase','I<span style="color:red">́</span>','i̇́'},
		{'nl','capitalize','i<span style="color:red">j</span>ssel','IJssel'},
		{'en','capitalize','ab<span></span>cd ab<wbr>cd ab<span style="text-transform:none">cd</span>ef','Abcd Abcd Abcdef'},
		{'en','math-auto','x y','x y'},
		{'en','math-auto','x<span>y</span>','𝑥𝑦'},
		{'en','math-auto','xy','xy'},
		{'ga','uppercase','t<span style="color:red">-</span><b>uisce</b> n<span>g</span>ael b<span>h</span><i>f</i>uil','tUISCE nGAEL bhFUIL'},
		{'ga','lowercase','t<span style="color:red">U</span>ISCE n<span>A</span>THAIR NATHAIR','t-uisce n-athair nathair'},
	}do
		local styled=renderer.build(Parser.parse('<p lang="'..input[1]..'" style="text-transform:'..input[2]..'">'..input[3]..'</p>'),{},error).Children[1].Children[1]
		assert(displayed(styled)==input[4],'Source-context/style-boundary transform: '..input[3]..' => '..displayed(styled))
		layout.arrange(styled,30,0,0,function()return true end);local measuredCount=requests
		layout.arrange(styled,300,0,0,function()return true end);assert(requests==measuredCount,'Contextual display measurements remain per word and are retained on resize')
	end
	local irishComparisons=0
	for _,record in Native and Native.irish and Native.irish.records or{}do
		local document=Parser.parse('<p lang="'..record.lang..'" style="text-transform:'..record.mode..';text-autospace:no-autospace">'..record.html..'</p>')
		local run=renderer.build(document,{},error).Children[1].Children[1]
		local result=displayed(run)
		-- Firefox currently ignores explicit writing systems and loses Irish
		-- context at font/lang/transform fragment changes. Raw evidence is kept.
		if record.name=='upper-writing-system'then assert(result=='AR AON TSLÍ AN T-UISCE')
		elseif record.name=='upper-prefix-fragments'or record.name=='upper-h-fragments'or record.name=='lower-prefix-fragments'or record.name=='upper-none-boundary'or record.name=='upper-en-boundary'then
			local expected={['upper-prefix-fragments']='tUISCE nGAEL bhFUIL',['upper-h-fragments']='hÉIREANN HATAÍ HÁIT hÁIT',['lower-prefix-fragments']='t-uisce n-athair nathair'}
			assert(result==(expected[record.name]or 't-UISCE'))
		else
			assert(result==record.firefox.display,'Native Irish '..record.name..' => '..result..' ~= '..record.firefox.display);irishComparisons+=1
		end
		if record.expected then assert(result==record.expected,'Pinned Gecko Irish reference: '..record.name)end
		assert(Node.textContent(document)==record.source,'Irish prefix transformations never change DOM source')
	end
	if Native and Native.irish then assert(irishComparisons==321);print('Irish Firefox native output: '..irishComparisons..' cases')end
	local spacingRequests=0;local widthLayout=loadWordLayout({['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)
		spacingRequests+=1;return {X=if text=='　'then 20 elseif text==' 'then 5 else (utf8.len(text)or #text)*10,Y=size}
	end}})
	for _,sample in {{'normal','a b',15},{'pre','a b',30},{'pre','a\tb',40},{'pre','a \tb',40}}do
		local spaced=renderer.build(Parser.parse('<p style="text-transform:full-width;white-space:'..sample[1]..'">'..sample[2]..'</p>'),{},error).Children[1].Children[1]
		widthLayout.arrange(spaced,500,0,0,function()return true end)
		assert(spaced.Items[#spaced.Items].X==sample[3],'Full-width preserved spaces and ordinary numeric tab stops: '..sample[1]..':'..sample[2])
		local before=spacingRequests;widthLayout.arrange(spaced,300,0,0,function()return true end);assert(spacingRequests==before,'Full-width space/tab measurements remain per item and retained')
	end
	local dynamicDocument=Parser.parse('<div id="parent" lang="en" style="text-transform:uppercase"><p id="inherited">iı Iİ</p><p id="own" lang="tr">iı Iİ</p><input id="editor" value="kept"></div><div id="after">End</div>')
	local dynamic=renderer.build(dynamicDocument,{},error);local parentNode=Node.findById(dynamicDocument,'parent');local inheritedNode=Node.findById(dynamicDocument,'inherited');local ownNode=Node.findById(dynamicDocument,'own')
	local ownItems=dynamic.NodeBoxes[ownNode].Children[1].Items;local editor=dynamic.Controls[1];local editorGui=editor.Item.Gui;local after=dynamic.NodeBoxes[Node.findById(dynamicDocument,'after')];local beforeSource=Node.textContent(dynamicDocument)
	for _,tag in {'tr','','az-Latn','tr-Arab','bad--tag','en'}do
		parentNode.Attributes.lang=tag;dynamic:ApplyDOMChanges({[parentNode]={Attributes={lang=true}}})
		local updated=dynamic.NodeBoxes[inheritedNode].Children[1];layout.arrange(updated,100,0,0,function()return true end)
		assert(displayed(updated)==Transform.word('iı Iİ','uppercase',false,tag),'Dynamic inherited language transform: '..tag)
		assert(dynamic.NodeBoxes[ownNode].Children[1].Items==ownItems,'Own-language word items remain unaffected by inherited language mutation')
		assert(dynamic.Controls[1]==editor and editor.Item.Gui==editorGui and dynamic.NodeBoxes[Node.findById(dynamicDocument,'after')]==after,'Language changes preserve unrelated controls and box objects')
		assert(Node.textContent(dynamicDocument)==beforeSource)
	end
	for _,mode in {'lowercase','capitalize full-width','none','uppercase'}do
		parentNode.Attributes.style='text-transform:'..mode;dynamic:ApplyDOMChanges({[parentNode]={Attributes={style=true}}})
		local expected=Transform.word('iı Iİ',mode,false,'en'):gsub('　',' ')
		assert(displayed(dynamic.NodeBoxes[inheritedNode].Children[1])==expected,'Dynamic inherited text-transform preserves collapsed spaces: '..mode)
		assert(dynamic.Controls[1]==editor and editor.Item.Gui==editorGui and dynamic.NodeBoxes[Node.findById(dynamicDocument,'after')]==after)
	end
	local contextDocument=Parser.parse('<p id="context" style="text-transform:lowercase">Ο<span style="color:red">Σ</span><b id="trailing">Α</b></p>');local contextTree=renderer.build(contextDocument,{},error)
	local contextNode=Node.findById(contextDocument,'context');local trailing=Node.findById(contextDocument,'trailing').Children[1]
	for _,value in {'','Α',''}do
		trailing.Text=value;contextTree:ApplyDOMChanges({[trailing]={Text=true}})
		assert(displayed(contextTree.NodeBoxes[contextNode].Children[1])==(if value==''then 'ος'else 'οσα'),'A neighbouring source mutation refreshes context-dependent final sigma across styled fragments')
	end
	local irishDocument=Parser.parse('<p id="irish" lang="ga" style="text-transform:uppercase">t<span id="irish-tail" style="color:red">-uisce</span></p><input id="irish-editor" value="kept">')
	local irishTree=renderer.build(irishDocument,{},error);local irishNode=Node.findById(irishDocument,'irish');local irishTail=Node.findById(irishDocument,'irish-tail').Children[1]
	local irishControl=irishTree.Controls[1];local irishGui=irishControl.Item.Gui
	for _,sample in {{'ga','uppercase','-uisce','tUISCE'},{'en','uppercase','-uisce','T-UISCE'},{'ga','uppercase','-Éan','T-ÉAN'},{'ga','uppercase','-uisce','tUISCE'},{'ga','lowercase','UISCE','t-uisce'},{'ga-Cyrl','lowercase','UISCE','tuisce'},{'ga','lowercase','uisCE','tuisce'}}do
		irishNode.Attributes.lang=sample[1];irishNode.Attributes.style='text-transform:'..sample[2];irishTail.Text=sample[3]
		irishTree:ApplyDOMChanges({[irishNode]={Attributes={lang=true,style=true}},[irishTail]={Text=true}})
		local run=irishTree.NodeBoxes[irishNode].Children[1];assert(displayed(run)==sample[4],'Irish neighbour/language/mode changes: '..sample[1]..'/'..sample[2]..'/'..sample[3])
		layout.arrange(run,30,0,0,function()return true end);local measuredCount=requests;layout.arrange(run,300,0,0,function()return true end)
		assert(requests==measuredCount and irishTree.Controls[1]==irishControl and irishControl.Item.Gui==irishGui,'Irish mutations preserve individual measurements and unrelated controls')
	end
	local metadataDocument=Parser.parseDocument('<!doctype html><html><head></head><body><p id="default-language" style="text-transform:uppercase">i</p></body></html>',{ContentLanguage='en'})
	local metadataTree=renderer.build(metadataDocument,{},error);local metadataNode=Node.findById(metadataDocument,'default-language')
	for _,tag in {'tr','','en'}do
		metadataDocument.ContentLanguage=tag;metadataTree:ApplyDOMChanges({[metadataDocument]={Language=true}})
		assert(displayed(metadataTree.NodeBoxes[metadataNode].Children[1])==(if tag=='tr'then 'İ'else 'I'),'Document-default language refreshes casing without a :lang selector')
	end
	local xmlDocument=Parser.parse('<p id="xml" lang="tr" style="text-transform:uppercase">i</p>');local xml=Node.findById(xmlDocument,'xml')
	xml.AttributeNamespaces={['xml:lang']={Namespace='http://www.w3.org/XML/1998/namespace',LocalName='lang'}};xml.Attributes['xml:lang']=''
	local xmlTree=renderer.build(xmlDocument,{},error)
	for _,tag in {'','tr',''}do
		xml.Attributes['xml:lang']=tag;xmlTree:ApplyDOMChanges({[xml]={Attributes={['xml:lang']=true}}})
		assert(displayed(xmlTree.NodeBoxes[xml].Children[1])==(if tag=='tr'then 'İ'else 'I'),'Namespaced xml:lang precedence and empty language refresh casing')
	end
	local shadowDocument=Parser.parse('<div id="host" lang="en" style="text-transform:uppercase"></div>');local shadowHost=Node.findById(shadowDocument,'host');local shadow=Node.shadowRoot('open',shadowHost)
	shadowHost.InternalShadowRoot,shadowHost.ShadowRoot=shadow,shadow;local shadowCopy=Node.element('p',{});Node.append(shadow,shadowCopy);Node.append(shadowCopy,Node.text('i'))
	local shadowTree=renderer.build(shadowDocument,{},error)
	for _,tag in {'tr','','en'}do
		shadowHost.Attributes.lang=tag;shadowTree:ApplyDOMChanges({[shadowHost]={Attributes={lang=true}}})
		assert(displayed(shadowTree.NodeBoxes[shadowCopy].Children[1])==(if tag=='tr'then 'İ'else 'I'),'Shadow content uses and refreshes its host language')
	end
	local comparisons=0
	for _,record in Native and Native.records or{}do
		if not record.supported or record.mode=='math-auto'or record.lang=='tr-Arab'or(record.name=='scripts-extended'and record.mode~='none'and record.mode~='lowercase')or(record.name=='sigma-fragments'and(record.mode=='lowercase'or record.mode=='uppercase'and record.lang=='el'))or(record.name=='turkic-fragments'and record.mode=='lowercase'and(record.lang=='tr'or record.lang=='az-Latn'or record.lang=='lt'))or(record.mode=='capitalize'and(record.lang=='tr'or record.lang=='az-Latn'or record.lang=='lt'or record.lang=='nl'or record.name=='expansions'or record.name=='greek-accent'or record.name=='dutch-fragments'or record.name=='capitalize-fragments'))then continue end
		local document=Parser.parse('<p lang="'..record.lang..'" style="text-transform:'..record.mode..';text-autospace:no-autospace">'..record.html..'</p>')
		local source=Node.textContent(document);local native=renderer.build(document,{},error).Children[1].Children[1];local parts={}
		for _,item in native.Items do
			if item.SpaceBefore then table.insert(parts,' ')end
			if item.Kind=='Word'or item.Kind=='Space'then table.insert(parts,item.Text)end
		end
		assert(table.concat(parts)==record.display,'Native transform '..record.name..':'..record.mode..':'..record.lang..' => '..table.concat(parts)..' ~= '..record.display)
		assert(Node.textContent(document)==source,'Transformation never changes DOM source')
		comparisons+=1
	end
	if Native then assert(comparisons==520);print('Text-transform native case output: '..comparisons..' cases')end
	print("Text transform: Unicode full/conditional mappings, writing-system rules, width/kana/math, styled context, source spans, inheritance and retained measurements passed")
end
