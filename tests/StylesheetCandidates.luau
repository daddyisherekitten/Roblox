--!strict
-- Candidate indexing must not memoize any live selector/query/cascade result.
return function(Parser,Node,Style,Stylesheet)
	local document=Parser.parseDocument('<!doctype html><div class="outer"><p id="probe" class="probe"></p></div><p id="outside" class="probe"></p>')
	local probe,outside=Node.findById(document,'probe'),Node.findById(document,'outside')
	local rules=Stylesheet.collect(document,error,[=[
		@layer early,late;
		@layer early { .probe::before { color:red; background:red!important } }
		@layer late { .probe::before { color:blue; background:blue!important } }
		.probe::before { color:green; background:green!important }
		.probe:hover::before { font-size:23px }
		@scope (.outer) { .probe::before { padding-left:7px } }
		@media (min-width:700px) { .probe::before { margin-top:9px } }
		@container card (min-width:200px) { .probe::before { width:80px } }
		@starting-style { .probe::before { opacity:.2 } }
		.probe::after { color:purple }
		.probe { color:orange }
	]=])
	local function pseudo(node,states,container,starting)
		return Style.resolve(node,{FontSize=16},error,false,Stylesheet.matchPseudo(rules,node,'before',states,container,nil,starting))
	end
	Stylesheet.setMediaEnvironment(rules,{Width=800,Height=600})
	local narrow={Names={'card'},Width=100,Height=300}
	local wide={Names={'card'},Width=300,Height=300}
	local initial=pseudo(probe,nil,narrow)
	assert(initial.Color==Color3.fromRGB(0,128,0)and initial.Background==Color3.fromRGB(255,0,0),'Normal/important layer precedence remains live')
	assert(initial.Padding[4]==7 and initial.Margin[1]==9 and initial.Width==nil and initial.Opacity==1,'Scope, media, container and starting-style selection')
	local hover=pseudo(probe,{hover=probe},wide)
	assert(hover.FontSize==23 and hover.Width.Value==80,'Warmed candidates must reevaluate element state and container size')
	assert(pseudo(outside,nil,wide).Padding[4]==0,'One rule list must not share the previous element scope result')
	Stylesheet.setMediaEnvironment(rules,{Width=500,Height=600})
	assert(pseudo(probe,nil,wide).Margin[1]==16 and pseudo(probe,nil,wide,true).Opacity==.2,'Warmed candidates must reevaluate media and starting-style')
	assert(Style.resolve(probe,{FontSize=16},error,false,Stylesheet.match(rules,probe)).Color==Color3.fromRGB(255,165,0),'Pseudo candidates never leak into element rules')
	assert(#Stylesheet.matchPseudo(rules,probe,'marker').Normal==0,'An absent pseudo target has no candidates')
	assert(#Stylesheet.matchPart(rules,probe).Normal==0 and #Stylesheet.matchShadow(rules,probe,'host').Normal==0,'Ordinary rules never leak into part/host target lists')

	-- Real renderer replacements preserve list identity and explicitly invalidate.
	local alias=rules
	local replacement=Stylesheet.collect(document,error,'.probe::marker {color:blue} .probe {color:red}')
	table.clear(rules);for key,value in replacement do rules[key]=value end
	Stylesheet.invalidate(rules)
	assert(alias==rules and #Stylesheet.matchPseudo(alias,probe,'before').Normal==0 and #Stylesheet.matchPseudo(alias,probe,'marker').Normal==1,'In-place replacement invalidates every target list')
	assert(Style.resolve(probe,{FontSize=16},error,false,Stylesheet.match(alias,probe)).Color==Color3.fromRGB(255,0,0),'Ordinary target refresh after replacement')
	assert(#Stylesheet.rawMatch(alias,probe).Normal==1,'SVG raw declarations retain their separate path')

	-- Instrument classification reads on actual parser rules. A cold build scans
	-- once; subsequent queries inspect only their own target's compiled selectors.
	local sources={}
	for index=1,320 do table.insert(sources,'.irrelevant-'..index..' {color:red}')end
	table.insert(sources,'.probe::before {color:blue}.probe:hover::before {color:red}.probe::after {color:green}')
	local compiled=Stylesheet.collect(document,error,table.concat(sources,'\n'))
	local observed,reads={},0
	for key,value in compiled do if type(key)~='number'then observed[key]=value end end
	for index,rule in compiled do
		if type(index)=='number'then observed[index]=setmetatable({}, {__index=function(_,key)
			if key=='PseudoElement'then reads+=1 end
			return rule[key]
		end})end
	end
	Stylesheet.matchPseudo(observed,probe,'before') -- Build this owner's index.
	reads=0
	local queryCount=120
	for _=1,queryCount do
		assert(#Stylesheet.matchPseudo(observed,probe,'before').Normal==1)
		assert(#Stylesheet.matchPseudo(observed,probe,'after').Normal==1)
		assert(#Stylesheet.matchPseudo(observed,probe,'marker').Normal==0)
	end
	local indexedReads=reads
	reads=0
	for _=1,queryCount do for _,name in {'before','after','marker'}do
		for index=1,#observed do local _candidate=observed[index].PseudoElement==name end
	end end
	local fullScanReads=reads
	local coldRebuildReads=indexedReads-queryCount*3
	assert(fullScanReads==queryCount*3*#observed and coldRebuildReads>=0 and coldRebuildReads%#observed==0 and indexedReads<fullScanReads,
		'Warm queries inspect their target only; GC may discard the weak index and add a complete cold classification')
	Stylesheet.invalidate(observed);reads=0
	Stylesheet.matchPseudo(observed,probe,'marker')
	assert(reads==#observed,'Explicit invalidation rebuilds exactly once even when the requested target is absent')
	-- Scoped/part selectors can reference the document, which can in turn own
	-- a renderer and this rule list. A weak key alone cannot break that cycle.
	local orphaned=setmetatable({}, {__mode='k'})
	local function abandonedScopedOwner(indexed)
		local owner=Parser.parseDocument('<!doctype html><p id="probe" class="probe"></p>')
		local ownRules=Stylesheet.collect(owner,error,'@scope { .probe:hover::before {color:red} }')
		local ownNode=Node.findById(owner,'probe')
		owner.RetainedRenderer={CSSRules=ownRules}
		if indexed==1 then Stylesheet.matchPseudo(ownRules,ownNode,'before')end
		orphaned[owner]=tostring(indexed)..'-document';orphaned[ownRules]=tostring(indexed)..'-rules'
	end
	abandonedScopedOwner(0);abandonedScopedOwner(1)
	for batch=1,2048 do
		if next(orphaned)==nil then break end
		local garbage=table.create(2048)
		for index=1,2048 do garbage[index]={index,batch}end
	end
	local retained={};for _,label in orphaned do table.insert(retained,label)end
	assert(next(orphaned)==nil,'Cached scoped selectors must not root abandoned documents through a value-to-owner cycle: '..table.concat(retained,','))
	print('Stylesheet candidates: '..#observed..' compiled rules / '..(queryCount*3)..' warm pseudo queries; classification reads '..fullScanReads..' -> '..indexedReads..'; live state/query/scope/layer/starting and in-place replacement passed')
end
