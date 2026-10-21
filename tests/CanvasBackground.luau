--!strict
return function(Parser: any, CanvasBackground: any)
	local function elements(document: any): (any, any)
		local html, body
		local pending={document}
		while #pending>0 do
			local node=table.remove(pending)
			if node.Name=='html' then html=node elseif node.Name=='body' then body=node end
			for index=#node.Children,1,-1 do table.insert(pending,node.Children[index]) end
		end
		return html,body
	end
	local document=Parser.parseDocument('<!doctype html><html><head></head><body><p>Page</p></body></html>')
	local html,body=elements(document)
	local red,cream=Color3.fromRGB(200,20,20),Color3.fromRGB(255,247,237)
	local color,alpha,source=CanvasBackground.resolve(document,{[html]={Background=red,BackgroundAlpha=.75},[body]={Background=cream,BackgroundAlpha=1}})
	assert(color==red and alpha==.75 and source=='html','The nontransparent html background owns the canvas')
	color,alpha,source=CanvasBackground.resolve(document,{[html]={Background=red,BackgroundAlpha=0},[body]={Background=cream,BackgroundAlpha=1}})
	assert(color==cream and alpha==1 and source=='body','A transparent root propagates the body background')
	local root={Attributes={}}
	function root:SetAttribute(key,value)self.Attributes[key]=value end
	CanvasBackground.apply(root,document,{[body]={Background=cream,BackgroundAlpha=.6}})
	assert(root.BackgroundColor3==cream and root.BackgroundTransparency==.4 and root.Attributes.CanvasBackgroundSource=='body')
	local untouched={BackgroundColor3=red,BackgroundTransparency=0}
	CanvasBackground.apply(untouched,document,{})
	assert(untouched.BackgroundColor3==red and untouched.BackgroundTransparency==0,'A document without a canvas color keeps the default surface')
	local H,S='http://www.w3.org/1999/xhtml','http://www.w3.org/2000/svg'
	local function element(name,namespace,localName,children)
		return {Kind='Element',Name=name,LocalName=localName,NamespaceURI=namespace,Attributes={style='authored'},Children=children or{}}
	end
	local first=element('h:body',H,'body');local later=element('body',H,'body')
	local nested=element('body',H,'body');local foreign=element('f:body','urn:canvas','body')
	local plain=element('body','','body');local literal=element('h:body',H,'h:body')
	local frameset=element('frameset',H,'frameset')
	local actual=element('h:html',H,'html',{foreign,plain,literal,frameset,element('div',H,'div',{nested}),first,later})
	local d={Kind='Document',Children={{Kind='Comment',Children={}},actual}}
	local rootStyle=table.freeze({BackgroundAlpha=0,BackgroundImages=table.freeze({table.freeze({Kind='none'})})})
	local firstStyle=table.freeze({Background=cream,BackgroundAlpha=.6,BackgroundImages=table.freeze({table.freeze({Kind='none'})})})
	local styles={[actual]=rootStyle,[first]=firstStyle,[later]={Background=red},[nested]={Background=red},[foreign]={Background=red},[plain]={Background=red},[frameset]={Background=red}}
	local plan=CanvasBackground.plan(d,styles)
	assert(plan.Root==actual and plan.Owner==first and plan.Source=='body','Expanded names select the first direct HTML body; foreign, plain, literal-colon, frameset and nested names are ignored')
	for _=1,3 do CanvasBackground.plan(d,styles)end
	assert(styles[actual]==rootStyle and styles[first]==firstStyle and first.Attributes.style=='authored'and firstStyle.Background==cream and firstStyle.BackgroundAlpha==.6,'Owner planning must not mutate authored or frozen computed styles')
	styles[first]={Background=cream,Display='none'};plan=CanvasBackground.plan(d,styles)
	assert(plan.Owner==first and not plan.Paint,'Hidden first body cannot be replaced by a later painted body')
	styles[first]={BackgroundAlpha=0};plan=CanvasBackground.plan(d,styles)
	assert(plan.Owner==first and not plan.Paint,'Transparent first body cannot be replaced by a later painted body')
	styles[first]=nil;assert(CanvasBackground.plan(d,styles).Owner==actual,'A later styled body cannot replace the first direct body with no computed record')
	styles[first]=firstStyle
	for _,image in {{Kind='url',URL=''},{Kind='url',URL='missing.png'},{Kind='image-set',Candidates={}}}do
		styles[actual]={BackgroundAlpha=0,BackgroundImages={image}}
		assert(CanvasBackground.plan(d,styles).Owner==actual,'Image presence, including empty or failed sources, prevents body takeover')
	end
	styles[actual]={BackgroundAlpha=0,BackgroundImages={{Kind='none'},{Kind='none'}}};assert(CanvasBackground.plan(d,styles).Owner==first,'Only none image layers permit body takeover')
	for _,target in {actual,first}do
		for _,containment in {{Contain={layout=true}},{Contain={size=true}},{Contain={style=true}},{Contain={paint=true}},{ContentVisibility='auto'},{ContentVisibility='hidden'},{ContainerType='size'},{ContainerType='inline-size'},{ContainerType='size scroll-state'},{ContainerType='inline-size scroll-state'}}do
			styles[actual]=rootStyle;styles[first]=firstStyle;styles[target]=containment
			assert(CanvasBackground.plan(d,styles).Owner==actual,'Computed containment on either owner disables body propagation')
		end
	end
	for _,normal in {{Contain={layout=false,paint=false}},{ContentVisibility='visible'},{ContainerType='normal'},{ContainerType='scroll-state'}}do
		styles[actual]=normal;styles[first]=firstStyle;assert(CanvasBackground.plan(d,styles).Owner==first,'Inactive containment and scroll-state alone preserve body propagation')
	end
	for _,other in {element('html','','html',{first}),element('f:html','urn:canvas','html',{first}),element('HTML',H,'HTML',{first}),element('svg',S,'svg',{actual})}do
		styles[other]={Background=red};d.Children[2]=other;plan=CanvasBackground.plan(d,styles)
		assert(plan.Root==other and plan.Owner==other and plan.Style==styles[other],'Actual non-HTML root owns the canvas; a nested HTML root/body never replaces it')
	end
	local empty={Kind='Document',Children={}}
	assert(CanvasBackground.isDocument(empty)and CanvasBackground.plan(empty,{}).Root==nil,'Empty actual documents own a canvas without an invented owner')
	assert(not CanvasBackground.isDocument({Kind='DocumentFragment',Children={}}),'A real DocumentFragment never owns the document canvas')
	local legacy=Parser.parse('<span style="display:inline-block;background:rgba(20,80,140,.5)">Local</span>');local span=legacy.Children[1]
	local fragmentStyles={[span]={Display='inline-block',Background=cream,BackgroundAlpha=.5},[legacy]={DarkScheme=true}}
	local fragmentPlan=CanvasBackground.plan(legacy,fragmentStyles)
	assert(not CanvasBackground.isDocument(legacy)and CanvasBackground.documentRoot(legacy)==nil and fragmentPlan.Root==nil and fragmentPlan.Owner==nil and not fragmentPlan.Paint and not fragmentPlan.Dark and fragmentPlan.Source==nil,'A legacy fragment host cannot own canvas paint or a global UA color scheme')
	local localHost={BackgroundColor3=red,BackgroundTransparency=.4}
	CanvasBackground.apply(localHost,legacy,fragmentStyles)
	assert(localHost.BackgroundColor3==red and localHost.BackgroundTransparency==.4,'Fragment paint planning leaves its enclosing host surface unchanged')
	local actualSpan=Parser.parseDocument('');for _,child in table.clone(actualSpan.Children)do child.Parent=nil end;table.clear(actualSpan.Children);span.Parent=nil;table.clear(legacy.Children);table.insert(actualSpan.Children,span);span.Parent=actualSpan
	assert(CanvasBackground.documentRoot(actualSpan)==span and CanvasBackground.plan(actualSpan,fragmentStyles).Owner==span,'The same element under an actual document remains eligible irrespective of its root name')
	print('Canvas background: actual/expanded-name root, first direct HTML body, ineligible candidates, containment, image eligibility and immutable source styles passed')
end
