--!strict
return function(Filter,Pixels,loadFilters,Parser,loadRenderTree,loadImageLoad)
	local function pixel(r,g,b,a) local buf=buffer.create(4); for i,v in {r,g,b,a or 255} do buffer.writeu8(buf,i-1,v) end; return buf end
	local function check(css,source,expected)
		local output=Pixels.render(source,assert(Filter.parse(css)))
		for i,v in expected do assert(math.abs(buffer.readu8(output,i-1)-v)<=1,css..' channel '..i..': '..buffer.readu8(output,i-1)..' != '..v) end
	end
	check('none',pixel(25,100,200,64),{25,100,200,64})
	check('brightness(2)',pixel(100,150,200),{200,255,255,255})
	check('contrast(0)',pixel(0,100,255),{128,128,128,255})
	check('grayscale()',pixel(255,0,0),{54,54,54,255})
	check('saturate(0)',pixel(0,255,0),{182,182,182,255})
	check('saturate(2)',pixel(120,130,140),{111,131,151,255})
	check('invert()',pixel(0,100,255,80),{255,155,0,80})
	check('sepia()',pixel(255,255,255),{255,255,239,255})
	check('hue-rotate(180deg)',pixel(255,0,0),{0,109,109,255})
	check('opacity(50%) opacity(.5)',pixel(20,40,60,128),{20,40,60,32})
	check('brightness(2) invert()',pixel(200,0,0),{0,255,255,255})
	check('invert() brightness(2)',pixel(200,0,0),{110,255,255,255})
	assert(Filter.parse('grayscale(200%)').Steps[1].Value==1)
	assert(Filter.parse('brightness(200%)').Key==Filter.parse('brightness(2)').Key)
	assert(Filter.parse('hue-rotate(-.5turn)').Steps[1].Value==-180)
	assert(Filter.parse('hue-rotate(200grad)').Steps[1].Value==180)
	assert(math.abs(Filter.parse('hue-rotate(3.141592653589793rad)').Steps[1].Value-180)<1e-9)
	for _,css in {'','blur(-2px)','url(x)','invert(-1)','hue-rotate(20)','brightness(1px)','none invert()','invert(1 2)','invert(1e999)','invert(1) garbage','invert((1))',string.rep('invert() ',17)} do
		assert(Filter.parse(css)==nil,'Must reject whole filter declaration: '..css)
	end
	local queue,reads,creates,destroyed,changes,notices={},0,0,0,0,{}
	local mode,duringRead='ok',nil
	local source=pixel(255,0,0,128)
	local api={CreateEditableImageAsync=function()
		reads+=1
		if duringRead then duringRead() end
		if mode=='denied' then error('access denied') end
		return {Size={X=1,Y=1},ReadPixelsBuffer=function() return source end,Destroy=function() destroyed+=1 end}
	end,CreateEditableImage=function()
		creates+=1
		if mode=='budget' then return nil end
		return {WritePixelsBuffer=function(self,_,_,buf) if mode=='write' then error('write failed') end; self.Pixels=buf end,Destroy=function() destroyed+=1 end}
	end}
	local service=loadFilters({GetService=function() return api end},{defer=function(fn) table.insert(queue,fn) end,wait=function() end})
	local function drain() while #queue>0 do table.remove(queue,1)() end end
	local renderer=loadRenderTree({create=function(_,_,props) return table.clone(props) end})
	local function build(css)
		local tree=renderer.build(Parser.parse('<img src="x" width="30" height="20" style="'..css..'">'),{},error,nil,nil,nil,function() return 'rbxassetid://123' end)
		return tree.ImageItems[1]
	end
	local function start(items) return service.start(items,function() return true end,function(m) table.insert(notices,m) end,function() changes+=1 end) end
	local a,b,c=build('filter:grayscale(1)'),build('filter:grayscale(100%)'),build('display:block;filter:invert()')
	assert(a.Style.Filter.Key==b.Style.Filter.Key and #c.Style.Filter.Steps==1)
	local items={a,b,c}; local stop=start(items); table.clear(items)
	assert(reads==0,'Filters must not block mount')
	drain(); assert(reads==1 and creates==2 and changes==0 and #notices==0)
	assert(a.ImageGui.ImageContent==b.ImageGui.ImageContent and a.ImageGui.ImageContent~=c.ImageGui.ImageContent,'Identical filters share one output')
	assert(a.FilterReady and not a.LoadFailed and not a.TextFallback)
	assert(buffer.readu8(source,0)==255,'Keep source pixels immutable')
	stop(); stop(); assert(destroyed==3,'Release source and both shared outputs exactly once')
	local baseReads=reads
	stop=start({build('filter:invert()')}); stop(); drain(); assert(reads==baseReads,'Disposed page does not allocate')
	stop=start({build('filter:invert()')}); duringRead=stop; drain(); duringRead=nil
	assert(creates==2,'Disposal during source loading prevents output creation')
	for _,failure in {'denied','budget','write'} do
		mode=failure; local item=build('filter:invert()'); local warnings=#notices
		stop=start({item}); drain(); stop()
		assert(not item.FilterReady and item.ImageGui.Image=='rbxassetid://123' and item.ImageGui.ImageContent==nil)
		assert(#notices==warnings+1,'Failure reports once and retains the original')
	end
	mode='ok'
	local fallback=build('filter:invert()'); fallback.TextFallback=true; fallback.LoadFailed=true; fallback.ImageGui.IsLoaded=false
	stop=start({fallback}); drain(); assert(fallback.FilterReady and not fallback.TextFallback and changes==1); stop()
	assert(start({build('filter:none')})==nil)
	local many={}
	for i=1,17 do table.insert(many,build('filter:brightness('..i..')')) end
	local before,warningCount=creates,#notices
	stop=start(many); drain(); assert(creates==before+16 and #notices==warningCount+1 and not many[17].FilterReady); stop()
	local warnings={}
	local cascade=renderer.build(Parser.parse('<style>img{filter:invert() !important}</style><div><img src="x" style="filter:sepia()"></div>'),{},function(m) table.insert(warnings,m) end,nil,nil,nil,function() return 'rbxassetid://123' end)
	assert(cascade.ImageItems[1].Style.Filter.Key=='invert(1)' and #warnings==0,'Filter obeys the existing cascade')
	local invalid=renderer.build(Parser.parse('<img src="x" style="filter:invert();filter:drop-shadow(3px)">'),{},function(m) table.insert(warnings,m) end,nil,nil,nil,function() return 'rbxassetid://123' end)
	assert(invalid.ImageItems[1].Style.Filter.Key=='invert(1)' and #warnings==1,'Unsupported chains preserve the preceding valid declaration')
	local reject=renderer.build(Parser.parse('<div style="filter:invert()"><img src="x"></div>'),{},function(m) table.insert(warnings,m) end,nil,nil,nil,function() return 'rbxassetid://123' end)
	assert(#reject.ImageItems[1].Style.Filter.Steps==0 and #warnings==2,'No accidental filter inheritance or silent container support')
	local normal,broken=build('filter:invert()'),build('filter:invert()')
	broken.ImageGui=setmetatable({IsLoaded=true},{__newindex=function(self,key,value)
		if key=='ImageContent' and type(value)=='table' then error('content assignment failed') end
		rawset(self,key,value)
	end})
	stop=start({normal,broken}); drain()
	assert(not normal.FilterReady and normal.ImageGui.ImageContent=='rbxassetid://123','Assignment failure restores already assigned labels')
	stop()
	local cancelled=Pixels.render(source,Filter.parse('invert()'),function() return false end)
	assert(cancelled==nil,'Pixel processing observes cancellation')
	print('Image filters: eight pixel transforms, ordering/clamping/alpha, CSS parsing, shared outputs, async cancellation, cleanup and fallback passed')
end
