-- Compare a calibrated Chromium host profile, preserving raw native outcomes.
return function(Media,fixtures,Parser,Runtime,Events,Sheet,Style,loadRenderTree)
	local fields={hover='Hover',['any-hover']='AnyHover',pointer='Pointer',['prefers-color-scheme']='PreferredColorScheme',
		['forced-colors']='ForcedColors',['prefers-reduced-motion']='ReducedMotion',['prefers-reduced-transparency']='ReducedTransparency',
		['prefers-reduced-data']='ReducedData',['prefers-contrast']='PreferredContrast',update='Update',['overflow-block']='OverflowBlock',
		['overflow-inline']='OverflowInline',scripting='Scripting',scan='Scan',['color-gamut']='ColorGamut',['video-color-gamut']='VideoColorGamut',
		['dynamic-range']='DynamicRange',['video-dynamic-range']='VideoDynamicRange',['display-mode']='DisplayMode',['inverted-colors']='InvertedColors',
		['environment-blending']='EnvironmentBlending',['nav-controls']='NavigationControls'}
	local compared,serialized,deviations=0,0,0
	for _,scene in fixtures.cases do
		local metrics=scene.metrics
		local env={Width=metrics.width,Height=metrics.height,DeviceWidth=metrics.deviceWidth,DeviceHeight=metrics.deviceHeight,
			Resolution=if scene.environment.type=='print'then 300/96 else metrics.resolution,MediaType=scene.environment.type,
			UnsupportedFeatures={},AnyPointers={}}
		for name,values in scene.features do
			if name=='any-pointer'then for _,v in values do env.AnyPointers[v]=true end
			elseif fields[name]and #values>0 then env[fields[name]]=values[#values]end
		end
		for _,name in scene.unsupported do env.UnsupportedFeatures[name]=true end
		if #scene.features.scan==0 and not env.UnsupportedFeatures.scan then env.Scan=false end
		for _,probe in scene.queries do
			local query=assert(Media.compile(probe.source),probe.source)
			local expected=if probe.normativeMatches~=nil then probe.normativeMatches else probe.matches
			assert(Media.matches(query,env)==expected,scene.name..' '..probe.source..' expected '..tostring(expected))
			compared+=1;if probe.deviation then deviations+=1 end
			local nativeUnsupported=false
			for name in env.UnsupportedFeatures do if probe.source:find(name,1,true)then nativeUnsupported=true;break end end
			if not nativeUnsupported then
				local text=Media.serialize(query);local expectedText=probe.normativeMedia or probe.media
				assert(text==expectedText,probe.source..' serialization expected '..expectedText..' got '..text);serialized+=1
			end
		end
	end
	-- Known extra capabilities use an explicit renderer environment, not fabricated OS detection.
	local function matches(source,env)return Media.matches(assert(Media.compile(source)),env or {})end
	assert(matches('(prefers-reduced-data: reduce)',{ReducedData=true}))
	assert(matches('(prefers-reduced-transparency)',{ReducedTransparency=true}))
	assert(matches('(prefers-contrast: custom)',{PreferredContrast='custom'}))
	assert(matches('(video-color-gamut: srgb) and (video-color-gamut: p3)',{VideoColorGamut='p3'}))
	assert(matches('(video-dynamic-range: standard) and (video-dynamic-range: high)',{VideoDynamicRange='high'}))
	assert(matches('(inverted-colors)',{InvertedColors=true})and matches('(inverted-colors: none)',{}))
	assert(matches('(scan: progressive)',{})and not matches('(scan)',{Scan=false}))
	assert(matches('(2 <= horizontal-viewport-segments <= 3)',{HorizontalViewportSegments=2}))
	assert(matches('(height: 10em)',{Height=200,InitialFontSize=20}))
	local fontQuery=assert(Media.compile('(width:calc(1em + 1px))'))
	assert(Media.matches(fontQuery,{Width=17})and Media.matches(fontQuery,{Width=21,InitialFontSize=20}))
	assert(Media.matches(assert(Media.compile(Media.serialize(fontQuery))),{Width=21,InitialFontSize=20}),
		'Media serialization must retain relative font units, not freeze them at 16px')
	assert(matches('(width: 100dvw)',{Width=640,DynamicViewportWidth=640}))
	assert(not matches('(width: 100dvw)',{Width=640,DynamicViewportWidth=600}))
	assert(not matches('(width: 800.001px)',{Width=800}),'Equality must not use the old 0.01px tolerance')
	assert(not matches('not (unknown)',{}),'Unknown remains unknown under negation')
	assert(matches('not ((unknown) and (width < -1px))',{Width=0}))
	assert(matches('bad!, (width:calc(min(1px,2px) + 799px))',{Width=800}),'Nested commas do not split the query list')
	assert(Media.compile(string.rep('a',65537))==nil and Media.compile(string.rep('(',34))==nil,'Parser resource limits are explicit')
	local doc=Parser.parseDocument('<!doctype html><html><body><div id="target"></div></body></html>')
	local target=doc.Children[#doc.Children].Children[#doc.Children[#doc.Children].Children].Children[1]
	local css='#target{color:red}@media bad!, (prefers-contrast:more){#target{color:blue}}@media (prefers-reduced-transparency:reduce){#target{background:green}}'
	local rules=Sheet.collect(doc,error,css)
	local inherited={FontSize=16,Font='Arial',Color=Color3.new(0,0,0)}
	Sheet.setMediaEnvironment(rules,{PreferredContrast='no-preference'})
	assert(Style.resolve(target,inherited,error,false,Sheet.match(rules,target)).Color.R==1)
	assert(Sheet.setMediaEnvironment(rules,{PreferredContrast='more'}))
	assert(Style.resolve(target,inherited,error,false,Sheet.match(rules,target)).Color.B==1)
	assert(not Sheet.setMediaEnvironment(rules,{PreferredContrast='more',Width=500}),'Unchanged truth values do not invalidate style rules')
	-- Real retained rendering path: preference-only paint keeps every GUI and needs no layout.
	local allocations=0;local renderer=loadRenderTree({create=function(_,_,props)allocations+=1;return table.clone(props)end,modifier=function(_,_,props)allocations+=1;return table.clone(props)end})
	local tree=renderer.build(doc,{AbsoluteSize={X=800,Y=600}},error,nil,nil,nil,nil,css)
	local guis={};for node,box in tree.NodeBoxes do guis[node]=box.Gui end
	local before=allocations;local changed,layout=tree:SetMediaEnvironment(800,600,{PreferredContrast='more',ReducedTransparency=true})
	assert(changed and not layout and allocations==before)
	for node,box in tree.NodeBoxes do assert(box.Gui==guis[node])end
	local view={Width=800,Height=600,Environment={PreferredContrast='more',ReducedTransparency=true}}
	local runtime=Runtime.new(doc,{Events=Events.new(doc),Diagnostic=error,Schedule=function()end,GeometryAdapter={GetViewport=function()return view end}})
	runtime:Run([=[
if (!matchMedia('').matches || matchMedia('').media !== '') throw new Error('empty query');
if (!matchMedia('bad!, (prefers-contrast:more)').matches) throw new Error('list recovery');
if (matchMedia('not (future)').matches) throw new Error('three-valued query');
if (!matchMedia('(width:calc(min(1px,2px) + 799px))').matches) throw new Error('nested commas');
if (matchMedia('bad!, screen').media !== 'not all, screen') throw new Error('serialization');
const sheet=new CSSStyleSheet();sheet.replaceSync('@media bad!, screen {div{color:red}}');
if (sheet.cssRules[0].media.mediaText !== 'not all, screen') throw new Error('CSSOM serialization');
let notifications=[];
const preference=matchMedia('(prefers-contrast:more)');
preference.addEventListener('change',event=>notifications.push([event.matches,event.media]));
]=])
	view.Environment.PreferredContrast='no-preference'
	runtime.Geometry:ViewportChanged();runtime.Geometry:ViewportChanged();runtime:PumpTasks()
	runtime:Run("if (notifications.length !== 1 || notifications[0][0] !== false || notifications[0][1] !== '(prefers-contrast: more)') throw new Error('change notification');")
	view.Environment.PreferredContrast='more';runtime.Geometry:ViewportChanged();runtime:PumpTasks()
	runtime:Run("if (notifications.length !== 2 || notifications[1][0] !== true) throw new Error('change restoration');")
	runtime:Destroy()
	print('Media queries: '..compared..' native matches, '..serialized..' serializations, '..deviations..' preserved normative deviations; actual CSS/retained/JS paths passed')
end
