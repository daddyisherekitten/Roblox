--!strict
return function(Selectors,Variables,Style,Document,Parser,Viewport,Viewports,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,CSSSources,UseSources)
	local function parse(body) return Parser.parse('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 480 320">'..body..'</svg>') end
	local doc=parse('<g id="parent"><rect id="first" class="a b" data-key="Abc hello"/><circle/><rect id="last"/></g>')
	for _,selector in {'g > rect.a','svg #first','[data-key]','[data-key^="abc" i]','[data-key~="hello"]','rect:first-child',':is(circle, #first)',':not(circle)',':where(.a)','#parent rect:nth-child(1)'} do
		local compiled=Selectors.compile(selector);assert(compiled,selector);assert(Selectors.matches(doc.Ids.first,compiled),selector)
	end
	for _,selector in {'circle + rect','rect ~ rect','rect:last-child','rect:nth-of-type(2)'} do assert(Selectors.matches(doc.Ids.last,Selectors.compile(selector)),selector) end
	assert(not Selectors.matches(doc.Ids.first,Selectors.compile('circle + rect')))
	assert(Selectors.compile(':where(#a)').Specificity[1]==0 and Selectors.compile(':is(.a,#b)').Specificity[1]==1)
	assert(Selectors.compile('g >')==nil and Selectors.compile(':unsupported')==nil)
	assert(Selectors.compile(':nth-child(bogus)')==nil and #Selectors.list('rect,')==2)
	assert(Selectors.matches(doc.Ids.parent,Selectors.compile(':hover'),{hover=doc.Ids.first}))
	local v=Variables.compute({['--a']='var(--b, red)',['--b']='var(--a)',['--safe']='var(--a, blue)',['--fallbackCycle']='var(--exists, var(--fallbackCycle))',['--exists']='green'})
	assert(v['--a']==nil and v['--b']==nil and v['--safe']==' blue' and v['--fallbackCycle']==nil)
	v=Variables.compute({['--a']='red',['--alias']='var(--a)'});local child=Variables.compute({['--a']='blue'},v)
	assert(child['--alias']=='red','Inherited custom properties are already computed')
	assert(Variables.substitute('"var(--a)"',child)=='"var(--a)"')
	assert(Variables.substitute('var(--missing,)',child)=='')
	local function prepare(body,options) return Document.prepare(parse(body),options) end
	local function shapes(prepared)
		local result={};local function visit(n) if Geometry.Supported[n.Name] then table.insert(result,n) end;for _,c in n.Children do visit(c) end end
		visit(prepared.Root);return result
	end
	local styled=prepare('<style>rect {fill:red} .a {fill:blue} #win {fill:green!important} :where(#win) {fill:yellow!important}</style><rect id="win" class="a" fill="pink" style="fill:orange" width="50" height="50"/>')
	assert(shapes(styled)[1].Attributes.fill=='green')
	styled=prepare('<style>rect {fill:red} #win {fill:green!important}</style><rect id="win" style="fill:blue!important"/>');assert(shapes(styled)[1].Attributes.fill=='blue')
	styled=prepare('<g fill="blue" style="--a:red"><rect style="fill:var(--a)"/><rect style="fill:green;fill:var(--missing)"/><rect style="fill:initial"/><rect style="fill:revert"/></g>')
	local s=shapes(styled);assert(s[1].Attributes.fill=='red' and s[2].Attributes.fill=='blue' and s[3].Attributes.fill=='black' and s[4].Attributes.fill=='blue')
	styled=prepare('<rect style="fill:red;fill:nonsense;stroke:var(--absent, blue)"/>');s=shapes(styled);assert(s[1].Attributes.fill=='red' and s[1].Attributes.stroke=='blue')
	local source=parse('<defs><symbol id="arrow" viewBox="0 0 100 50"><path d="M0 0H100V50H0Z"/></symbol></defs><use href="#arrow" width="80" height="40" fill="red"/><use href="#arrow" x="100" width="160" height="80" fill="blue"/>')
	local used=Document.prepare(source);s=shapes(used);assert(#s==2 and s[1].Attributes.fill=='red' and s[2].Attributes.fill=='blue')
	assert(source.Ids.arrow.Children[1].Attributes.fill==nil,'Source definitions remain unchanged')
	source.Ids.arrow.Children[1].Attributes.d='M0 0H20V20H0Z'
	local changed=shapes(Document.prepare(source));assert(changed[1].Attributes.d=='M0 0H20V20H0Z' and changed[2].Attributes.d==changed[1].Attributes.d)
	assert(s[1].Attributes.d~=changed[1].Attributes.d,'Existing prepared trees are independent snapshots')
	s[1].Attributes.fill='yellow';assert(s[2].Attributes.fill=='blue','Instance attributes are isolated')
	used=prepare('<defs><rect id="a" width="40" height="40"/><rect id="b" fill="red"/></defs><use href="#a" xlink:href="#b" fill="blue"/>')
	assert(shapes(used)[1].Attributes.fill=='blue','href takes precedence over xlink')
	used=prepare('<defs><rect id="a" width="40" height="40"/></defs><use xlink:href="#a" fill="green"/>');assert(shapes(used)[1].Attributes.fill=='green')
	used=prepare('<defs><g id="a"><use href="#b"/></g><g id="b"><use href="#a"/></g><rect id="ok" width="10" height="10"/></defs><use href="#a"/><use href="#missing"/><use href="#ok"/>')
	assert(#used.Diagnostics==2 and #shapes(used)==1)
	local loads=0
	used=prepare('<use href="icons.svg#star" fill="red"/><use href="icons.svg#star" fill="blue"/>',{Resolve=function(url) loads+=1;assert(url=='icons.svg');return '<svg xmlns="http://www.w3.org/2000/svg"><g id="star"><rect width="10" height="10"/></g></svg>' end})
	assert(loads==1 and #shapes(used)==2 and #used.Diagnostics==0)
	local failed=prepare('<use href="absent.svg#x"/><rect width="20" height="20"/>',{Resolve=function() error('unavailable') end})
	assert(#failed.Diagnostics==1 and #shapes(failed)==1)
	local pathTest=prepare('<use href="../icons.svg#star"/>',{URL='/assets/pages/main.svg',Resolve=function(url) assert(url=='/assets/icons.svg');return '<svg xmlns="http://www.w3.org/2000/svg"><rect id="star" width="20" height="20"/></svg>' end})
	assert(#pathTest.Diagnostics==0 and #shapes(pathTest)==1)
	local changing=parse('<g id="parent" fill="red"><rect width="10" height="10"/><rect width="10" height="10" fill="blue"/></g>')
	local before=shapes(Document.prepare(changing));changing.Ids.parent.Attributes.fill='green'
	local after=shapes(Document.prepare(changing));assert(before[1].Attributes.fill=='red' and after[1].Attributes.fill=='green' and after[2].Attributes.fill=='blue')
	local function observe(sources) return Viewports(Parser,Viewport,sources,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document) end
	local cssData=if CSSSources then observe(CSSSources) else nil
	local useData=if UseSources then observe(UseSources) else nil
	if cssData then
		assert(#cssData.Diagnostics==0)
		local function pixel(bytes,w,x,y) local at=(math.floor(y*w/480)*w+math.floor(x*w/480))*4;return {buffer.readu8(bytes,at),buffer.readu8(bytes,at+1),buffer.readu8(bytes,at+2),buffer.readu8(bytes,at+3)} end
		local function expect(actual,expected) for i,value in expected do assert(math.abs(actual[i]-value)<=1,`CSS pixel channel {i}: {actual[i]} ~= {value}`) end end
		for _,w in {240,480,960} do
			local cascade=Raster.render(cssData.Scenes[1],{},w,nil)
			local colors={{255,0,0,255},{0,0,255,255},{0,128,0,255},{255,165,0,255},{255,165,0,255},{0,0,255,255},{0,128,0,255},{0,128,0,255}}
			for i,color in colors do expect(pixel(cascade,w,55+(i-1)%4*115,if i<=4 then 65 else 215),color) end
			local selectors=Raster.render(cssData.Scenes[2],{},w,nil)
			for i=0,3 do expect(pixel(selectors,w,55+i*115,55),{0,128,0,255}) end
			expect(pixel(selectors,w,65,175),{255,0,0,255});expect(pixel(selectors,w,305,175),{0,128,0,255})
			expect(pixel(selectors,w,155,175),{0,0,255,255});expect(pixel(selectors,w,395,175),{0,0,255,255})
			local variables=Raster.render(cssData.Scenes[3],{},w,nil)
			for i,color in {{0,0,255,255},{0,128,0,255},{255,165,0,255},{0,0,255,255},{128,0,128,255},{0,128,0,255}} do expect(pixel(variables,w,60+(i-1)%3*155,if i<=3 then 60 else 210),color) end
		end
	end
	if useData then
		assert(#useData.Diagnostics==2,'Only the deliberately missing and cyclic references produce diagnostics')
		for _,w in {240,480,960} do
			for _,scene in useData.Scenes do assert(Raster.render(scene,{},w,nil)) end
			local pixels=Raster.render(useData.Scenes[3],{},w,nil)
			for y=20,119 do for x=60,159 do
				local a=(math.floor(y*w/480)*w+math.floor(x*w/480))*4;local b=a+240*w/480*4
				for c=0,3 do assert(math.abs(buffer.readu8(pixels,a+c)-buffer.readu8(pixels,b+c))<=1,'Local and resolved external stars match within one quantization step') end
			end end
		end
	end
	print('SVG S15/S16: selectors, cascade, custom-property cycles/fallback/inheritance, independent use styles, href/xlink, external cache and reference isolation passed')
	return cssData,useData
end
