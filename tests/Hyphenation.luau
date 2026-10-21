--!strict
return function(Parser,Style,Hyphenation,loadRenderTree,loadWordLayout,loadBlockLayout,Native)
	local function spell(text,language,limits)
		local points=Hyphenation.points(text,language,limits);local result={}
		for first,last in utf8.graphemes(text)do table.insert(result,text:sub(first,last));if points[last]then table.insert(result,"-")end end
		return table.concat(result)
	end
	assert(spell("hyphenation","en-US")=="hy-phen-ation")
	assert(spell("representation","en-US")=="rep-re-sen-ta-tion")
	assert(spell("Silbentrennung","de")=="Sil-ben-tren-nung")
	assert(spell("Gestaltungsidee","de-DE")=="Ge-stal-tungs-idee")
	assert(spell("Silbentrennung","DE-latn-AT")=="Sil-ben-tren-nung")
	assert(spell("Silbentrennung","")=="Silbentrennung"and spell("Silbentrennung","xx")=="Silbentrennung")
	assert(spell("hyphenation","en-Cyrl")=="hyphenation"and spell("hyphenation","bad--lang")=="hyphenation")
	assert(spell("Silbentrennung","de-x-cyrl")=="Sil-ben-tren-nung","Private-use subtags do not select a script")
	assert(spell("überraschend","de")==spell("überraschend","de"):gsub("ü","ü"),"Canonical grapheme normalization keeps the original spelling")
	assert(spell("Silbentrennung","de",{50,2,2})=="Silbentrennung")
	assert(spell("Silbentrennung","de",{5,7,5})=="Silbentrennung")
	assert(spell("Silbentrennung","de",{5,3,3})=="Sil-ben-tren-nung")
	for language,word in {fr="extraordinaire",es="extraordinario",it="rappresentazione",nl="lettergrepen",pt="representação",da="stavelsesdeling",uk="представлення",pl="przedstawienie",sl="predstavitev",et="esindamine",lt="atstovavimas",af="verteenwoordiging"}do
		assert(next(Hyphenation.points(word,language))~=nil,'The licensed resource supplies linguistic opportunities: '..language)
	end
	local allocated,measured=0,0
	local renderer=loadRenderTree({create=function(_,parent,props)
		allocated+=1;local gui=table.clone(props);gui.Parent=parent;if gui.Visible==nil then gui.Visible=true end
		function gui:Destroy()self.Destroyed=true end;return gui
	end,modifier=function(_,_,props)return table.clone(props)end})
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)
		measured+=1;local n=0;for _ in utf8.graphemes(text)do n+=1 end;return {X=n*5,Y=size}
	end}}
	local layout=loadWordLayout(overrides);overrides["Layout/WordLayout"]=layout
	local blocks=loadBlockLayout(overrides)
	local function build(text,css,language)
		local tree=renderer.build(Parser.parse('<div lang="'..(language or 'en-US')..'" style="font-family:Roboto;font-size:20px;line-height:20px;hyphens:auto;'..(css or ''):gsub('"','&quot;')..'">'..text..'</div><div>End</div>'),{},error)
		return tree,tree.Children[1].Children[1]
	end
	local function arrange(run,width)return layout.arrange(run,width,0,0,function()return true end)end
	local function textOf(run)
		local out={};for _,item in run.DisplayItems or run.Items do if item.Kind=="Word"then table.insert(out,item.Text)end end;return out
	end
	local tree,run=build('hyphenation')
	assert(arrange(run,30)==60)
	assert(table.concat(textOf(run),'|')=='hy-|phen-|ation','Only linguistic opportunities may create automatic hyphens')
	local allocation,calls=allocated,measured
	arrange(run,30);assert(allocated==allocation and measured==calls,'Unchanged element retains its own measures and fragment GUIs')
	arrange(run,100);assert(run.Items[1].Gui.Visible and #run.DisplayItems==1)
	arrange(run,30);assert(allocated==allocation and measured==calls,'Wide/narrow restores retained pieces')
	blocks.arrange(tree,30,0,0,function()return true end);assert(tree.Children[2].Gui.Position[2]==60)
	local _,unknown=build('hyphenation','','')
	assert(arrange(unknown,30)==20 and not unknown.Items[1].WrapPool,'Unknown language never falls back to arbitrary grapheme hyphenation')
	local _,overflow=build('hyphenation','overflow-wrap:break-word','')
	arrange(overflow,30);assert(table.concat(textOf(overflow),'|')=='hyphen|ation','Emergency breaks never invent hyphens')
	local _,manual=build('hy&shy;phen&shy;ation','hyphens:manual')
	assert(manual.Items[1].Text=='hyphenation'and #manual.Items[1].SourceHiddenSpans==2)
	arrange(manual,30);assert(table.concat(textOf(manual),'|')=='hy-|phen-|ation')
	assert(manual.DisplayItems[1].SourceSpans[#manual.DisplayItems[1].SourceSpans].Start==2,'Chosen manual hyphen keeps its source UTF-16 offset')
	arrange(manual,100);assert(manual.Items[1].Gui.Visible and manual.Items[1].Text=='hyphenation')
	local _,none=build('hy&shy;phen&shy;ation','hyphens:none')
	assert(arrange(none,30)==20 and none.Items[1].Text=='hyphenation','none hides SHY and disables its breaks')
	local _,priority=build('hyphen&shy;ation')
	arrange(priority,40);assert(table.concat(textOf(priority),'|')=='hyphen-|ation','Explicit SHY overrides unrelated dictionary points')
	arrange(priority,30);assert(table.concat(textOf(priority),'|')=='hy-|phen-|ation','An oversized explicit-SHY portion may use additional automatic dictionary points')
	local _,oversized=build('hy&shy;phen&shy;ation','hyphens:manual')
	arrange(oversized,15);assert(table.concat(textOf(oversized),'|')=='hy-|phen-|ation','An oversized indivisible syllable overflows while preserving the following explicit opportunity')
	local _,custom=build('hyphenation','hyphenate-character:"~~"')
	arrange(custom,35);assert(table.concat(textOf(custom),'|')=='hy~~|phen~~|ation','Measure the complete custom hyphen string')
	local _,empty=build('hyphenation','hyphenate-character:""')
	arrange(empty,30);assert(table.concat(textOf(empty),'|')=='hyphen|ation','Empty hyphen string still supplies linguistic opportunities')
	local _,filled=build('AA hyphenation')
	arrange(filled,35);assert(filled.DisplayItems[2].LineIndex==1 and filled.DisplayItems[2].Text=='hy-','Hyphenation fills the occupied line before moving the word')
	local _,joined=build('hy<span style="color:red">phen</span>ation')
	arrange(joined,30);assert(table.concat(textOf(joined),'|')=='hy-|phen-|ation','Inline style boundaries do not divide lexical words')
	local _,boundary=build('AA hy<span style="color:red">phenation</span>')
	arrange(boundary,35);assert(boundary.DisplayItems[2].Text=='hy-'and boundary.DisplayItems[2].LineIndex==1,'A dictionary break at an inline boundary retains its preceding style')
	local spacedTree,spaced=build('hyphenation','letter-spacing:1px')
	arrange(spaced,35);assert(spaced.DisplayItems[1].Text=='hy-'and #spaced.DisplayItems[1].Glyphs==3,'Hyphens retain individual glyph measurement in tracking mode')
	local firstFrame,textItems=spaced.DisplayItems[1].Gui,#spacedTree.TextItems
	arrange(spaced,50);assert(spaced.DisplayItems[1].Gui==firstFrame and not firstFrame.Destroyed,'Changed glyph fragments retain their registered word Frame')
	for _=1,20 do arrange(spaced,35);arrange(spaced,50)end
	assert(spaced.DisplayItems[1].Gui==firstFrame and not firstFrame.Destroyed and #spacedTree.TextItems==textItems,'Repeated tracked hyphenation preserves stable fragment Frames and registered item count')
	for _,mode in {'nowrap','pre'}do local _,unbroken=build('hy&shy;phenation','white-space:'..mode);assert(arrange(unbroken,30)==20 and not unbroken.DisplayItems)end
	local _,all=build('hyphenation','word-break:break-all')
	arrange(all,30);assert(table.concat(textOf(all),'|')=='hyphen|ation','break-all suppresses generated hyphenation characters')
	-- Language changes affect lexical grouping as well as retained break caches.
	-- Exercise the real mutation/recascade path, retaining unrelated controls.
	local Node=require('DOM/Node');local DocumentLanguage=require('DOM/DocumentLanguage')
	local document=Parser.parse('<div id="parent" lang="en-US" style="font-family:Roboto;font-size:20px;line-height:20px;hyphens:auto"><div id="inherited">hyphenation</div><div id="own" lang="de">Silbentrennung</div><div id="boundary" lang="">hyphenation</div><input id="editor" value="kept" style="width:30px"><div id="joined">hy<span lang="">phen</span>ation</div></div><div id="after">End</div>')
	local dynamic=renderer.build(document,{},error)
	local function node(id)return assert(Node.findById(document,id),id)end
	local function firstRun(source)
		local box=assert(dynamic.NodeBoxes[source]);for _,child in box.Children do if child.Kind=='Words'then return child end end
		error('Missing word run: '..tostring(source.Attributes.id))
	end
	local inheritedNode,ownNode,boundaryNode=node('inherited'),node('own'),node('boundary')
	local ownRun,boundaryRun=firstRun(ownNode),firstRun(boundaryNode)
	local ownWord,boundaryWord=ownRun.Items[1],boundaryRun.Items[1]
	local editorControl,afterBox=dynamic.Controls[1],dynamic.NodeBoxes[node('after')]
	local editorGui,afterGui=editorControl.Item.Gui,afterBox.Gui
	local function dynamicLayout()
		blocks.arrange(dynamic,30,0,0,function()return true end)
		assert(dynamic.Controls[1]==editorControl and editorControl.Item.Gui==editorGui and not editorGui.Destroyed,'Language changes preserve the unrelated editor')
		assert(dynamic.NodeBoxes[node('after')]==afterBox and afterBox.Gui==afterGui and not afterGui.Destroyed,'Language changes preserve following layout boxes')
		assert(firstRun(ownNode).Items[1]==ownWord and firstRun(boundaryNode).Items[1]==boundaryWord,'Own-language and empty-language boundaries retain their word items')
	end
	dynamicLayout();assert(table.concat(textOf(firstRun(inheritedNode)),'|')=='hy-|phen-|ation')
	assert(#firstRun(node('joined')).Items==3,'An empty own language creates a lexical style boundary')
	assert(firstRun(inheritedNode).Items[1].Style.HyphenationLanguage=='en-US')
	assert(table.concat(textOf(ownRun),'|')=='Sil-|ben-|tren-|nung' and table.concat(textOf(boundaryRun),'|')=='hyphenation')
	for _,language in {'','xx','en-US'}do
		node('parent').Attributes.lang=language
		local needed=dynamic:ApplyDOMChanges({[node('parent')]={Attributes={lang=true}}});assert(needed,'Language mutation requests geometry')
		dynamicLayout()
		local expected=if language=='en-US'then 'hy-|phen-|ation'else 'hyphenation'
		assert(table.concat(textOf(firstRun(inheritedNode)),'|')==expected,'Known/unknown language changes replace stale linguistic opportunities')
		assert(firstRun(inheritedNode).Items[1].Style.HyphenationLanguage==language,'Word style language snapshot follows recascade')
		assert(#firstRun(node('joined')).Items==(if language==''then 1 else 3),'Language mutation refreshes style grouping, including removal and return of a language boundary')
	end
	-- Inserting a pragma changes the document default; editing it later does not.
	local metaDocument=Parser.parseDocument('<!doctype html><html><head></head><body><div id="copy" style="font-family:Roboto;font-size:20px;line-height:20px;hyphens:auto">hyphenation</div></body></html>',{ContentLanguage='en-US'})
	local metaTree=renderer.build(metaDocument,{},error);local copy=assert(Node.findById(metaDocument,'copy'))
	local function metaRun()return metaTree.NodeBoxes[copy].Children[1]end
	arrange(metaRun(),30);assert(table.concat(textOf(metaRun()),'|')=='hy-|phen-|ation')
	local head=metaDocument.Children[2].Children[1]
	for _,language in {'xx','en-US'}do
		local meta=Node.element('meta',{['http-equiv']='content-language',content=language});Node.append(head,meta)
		assert(DocumentLanguage.insert(meta)==metaDocument)
		local needed=metaTree:ApplyDOMChanges({[metaDocument]={Language=true}});assert(needed)
		arrange(metaRun(),30);assert(table.concat(textOf(metaRun()),'|')==(if language=='en-US'then 'hy-|phen-|ation'else 'hyphenation'),'Inserted meta default refreshes automatic hyphenation')
		meta.Attributes.content='de'
		metaTree:ApplyDOMChanges({[meta]={Attributes={content=true}}})
		arrange(metaRun(),30);assert(table.concat(textOf(metaRun()),'|')==(if language=='en-US'then 'hy-|phen-|ation'else 'hyphenation'),'Editing a processed pragma does not alter the insertion-only document default')
	end
	local xmlDocument=Parser.parse('<div id="xml" lang="de" style="font-family:Roboto;font-size:20px;line-height:20px;hyphens:auto">Silbentrennung</div>')
	local xml=assert(Node.findById(xmlDocument,'xml'));xml.AttributeNamespaces={['xml:lang']={Namespace='http://www.w3.org/XML/1998/namespace',LocalName='lang'}}
	xml.Attributes['xml:lang']='';local xmlTree=renderer.build(xmlDocument,{},error)
	local function xmlRun()return xmlTree.NodeBoxes[xml].Children[1]end
	arrange(xmlRun(),30);assert(table.concat(textOf(xmlRun()),'|')=='Silbentrennung','An empty namespaced xml:lang takes precedence over lang')
	for _,language in {'de',''}do
		xml.Attributes['xml:lang']=language;local needed=xmlTree:ApplyDOMChanges({[xml]={Attributes={['xml:lang']=true}}});assert(needed)
		arrange(xmlRun(),30);assert(table.concat(textOf(xmlRun()),'|')==(if language=='de'then 'Sil-|ben-|tren-|nung'else 'Silbentrennung'),'Namespaced xml:lang changes refresh automatic hyphenation')
	end
	-- Shadow-root language comes from its host, not the rendering/slot parent.
	local shadowDocument=Parser.parse('<div id="host" lang="en-US" style="font-family:Roboto;font-size:20px;line-height:20px;hyphens:auto"></div>')
	local host=assert(Node.findById(shadowDocument,'host'));local shadow=Node.shadowRoot('open',host);host.InternalShadowRoot,host.ShadowRoot=shadow,shadow
	local shadowCopy=Node.element('div',{id='shadow-copy'});Node.append(shadow,shadowCopy);Node.append(shadowCopy,Node.text('hyphenation'))
	local shadowTree=renderer.build(shadowDocument,{},error)
	local function shadowRun()return assert(shadowTree.NodeBoxes[shadowCopy]).Children[1]end
	for _,language in {'en-US','','en-US'}do
		host.Attributes.lang=language;shadowTree:ApplyDOMChanges({[host]={Attributes={lang=true}}})
		arrange(shadowRun(),30)
		assert(table.concat(textOf(shadowRun()),'|')==(if language=='en-US'then 'hy-|phen-|ation'else 'hyphenation'),'Shadow-host language mutation refreshes its inherited lexical words')
	end
	-- Uniform words initially share a native label across equal inline source
	-- styles. Changing one source's existing hyphenation rules must repartition
	-- just that lexical owner before reusing its retained layout/paint pipeline.
	local inlineCases={
		{'hyphens','manual','none','manual','hy<span id="middle">p&shy;hen</span>ation'},
		{'hyphenate-character','"-"','"~~"','manual','hy&shy;<span id="middle">phen&shy;</span>ation'},
		{'hyphenate-limit-chars','5 2 2','50 2 2','auto','hy<span id="middle">phen</span>ation'},
	}
	local function inlineFixture(record,source)
		local css='#middle.changed,#middle:hover{'..record[1]..':'..record[3]..'}'
		local html='<style>'..css..'</style><div id="copy" lang="en-US" style="font-family:Roboto;font-size:20px;line-height:20px;hyphens:'..record[4]..';'..record[1]..':'..record[2]:gsub('"','&quot;')..'">'..(source or record[5])..'</div><input id="kept" value="kept"><div id="following">End</div>'
		local doc=Parser.parse(html);local rendered=renderer.build(doc,{},error)
		return rendered,assert(Node.findById(doc,'copy')),assert(Node.findById(doc,'middle')),assert(Node.findById(doc,'following'))
	end
	local function inlineResult(rendered,copy)
		blocks.arrange(rendered,30,0,0,function()return true end)
		local box=assert(rendered.NodeBoxes[copy]);local words=box.Children[1]
		return tostring(#words.Items)..':'..table.concat(textOf(words),'|')..':'..tostring(box.OuterHeight),words
	end
	for _,record in inlineCases do
		local freshHTML=record[5]:gsub('id="middle"','id="middle" style="'..record[1]..':'..record[3]:gsub('"','&quot;')..'"')
		local fresh,freshCopy=inlineFixture(record,freshHTML);local expected=inlineResult(fresh,freshCopy)
		for _,route in {'style','class','hover'}do
			local rendered,copy,middle,following=inlineFixture(record)
			local initial,words=inlineResult(rendered,copy);assert(#words.Items==1,'Equal inline source styles initially share one word label')
			local copyBox,followingBox=rendered.NodeBoxes[copy],rendered.NodeBoxes[following]
			local copyGui,followingGui=copyBox.Gui,followingBox.Gui;local control=rendered.Controls[1];local controlGui=control.Item.Gui
			for _=1,2 do
				if route=='hover'then local changed,needed=rendered:SetCSSState('hover',middle);assert(changed and needed)
				else middle.Attributes[route]=if route=='style'then record[1]..':'..record[3]else 'changed';assert(rendered:ApplyDOMChanges({[middle]={Attributes={[route]=true}}}))end
				local actual,current=inlineResult(rendered,copy)
				assert(actual==expected,record[1]..' '..route..' recascade must match a fresh identical DOM: '..actual..' / '..expected)
				local sourceText={};for _,item in current.Items do if item.Kind=='Word'then table.insert(sourceText,item.Text)end end
				assert(table.concat(sourceText)=='hyphenation','Repartition preserves the complete lexical source text')
				assert(rendered.NodeBoxes[copy]==copyBox and copyBox.Gui==copyGui and not copyGui.Destroyed)
				assert(rendered.NodeBoxes[following]==followingBox and followingBox.Gui==followingGui and not followingGui.Destroyed)
				assert(rendered.Controls[1]==control and control.Item.Gui==controlGui and not controlGui.Destroyed,'Hyphenation source regroup retains unrelated controls')
				if route=='hover'then local changed,needed=rendered:SetCSSState('hover',nil);assert(changed and needed)
				else middle.Attributes[route]=nil;assert(rendered:ApplyDOMChanges({[middle]={Attributes={[route]=true}}}))end
				assert(inlineResult(rendered,copy)==initial,'Removing a hyphenation override merges the original source group and restores lines')
			end
		end
	end
	-- A uniform source rule change needs layout but no word/frame replacement.
	for _,record in {inlineCases[2],inlineCases[3]}do
		local rendered,copy=inlineFixture(record,'hy&shy;<span id="middle">phen&shy;</span>ation')
		local _,words=inlineResult(rendered,copy);local word=words.Items[1];local wordGui=word.Gui
		for _,value in {record[3],record[2],record[3]}do
			copy.Attributes.style=copy.Attributes.style..';'..record[1]..':'..value
			assert(rendered:ApplyDOMChanges({[copy]={Attributes={style=true}}}));inlineResult(rendered,copy)
			assert(words.Items[1]==word and word.Gui==wordGui and not wordGui.Destroyed,'Uniform hyphenation rules retain the original word GUI')
		end
	end
	local comparisons=0
	for _,record in Native and Native.records or {}do
		if record.hyphens=='auto'then continue end -- Captured Chrome has no automatic language resources installed.
		local _,native=build(record.word,'hyphens:'..record.hyphens,record.language)
		arrange(native,record.columns*5+.01)
		local lines={}
		local hidden={};for _,item in native.Items do for _,span in item.SourceHiddenSpans or {}do hidden[span.Start]=true end end
		for _,item in native.DisplayItems or native.Items do
			for _,span in item.SourceSpans or {}do
				if hidden[span.Start]then continue end
				local line=item.LineIndex;lines[line]=lines[line]or {};table.insert(lines[line],span.Start)
			end
		end
		local expected=record.lines
		assert(#lines==#expected,'Native manual/none line count: '..record.word..':'..record.columns..':'..record.hyphens)
		for index,line in lines do assert(table.concat(line,',')==table.concat(expected[index],','),'Native manual/none source offsets: '..record.word..':'..record.columns..':'..record.hyphens)end
		comparisons+=1
	end
	if Native then assert(comparisons==60);print('Hyphenation native reference: '..comparisons..' manual/none layouts preserve the browser source boundaries')end
	print('Hyphenation: licensed language patterns, dynamic inherited/xml/meta/shadow languages, explicit SHY, lexical inline groups, custom strings, source offsets, retained measurements/GUIs and emergency precedence passed')
end
