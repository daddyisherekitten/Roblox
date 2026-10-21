--!strict
return function(loadIFrameRuntime: any)
	local deferred=0
	local Runtime=loadIFrameRuntime({defer=function(callback)deferred+=1;callback()end})
	local function item(attributes: any): any
		local content={Attributes={}}
		function content:SetAttribute(key,value)self.Attributes[key]=value end
		return {Node={Attributes=attributes},ContentGui=content,FallbackGui={},SelectedSource=attributes.src or attributes.data or 'about:blank'}
	end
	local first=item({src='../css-background-position/index.html',title='Background positions'})
	local cleanups,parentNavigations={},{ }
	local page={Alive=true,Document={},BaseURL='http://localhost:8000/main/index.html',
		AddCleanup=function(_,callback)table.insert(cleanups,callback)end,
		Navigate=function(href,_,data)table.insert(parentNavigations,{Href=href,Target=data.Target})end}
	local mounted={}
	local function mount(target,html,options)
		local child={Alive=true,Root={Attributes={}},Scrolls={}}
		function child.Root:SetAttribute(key,value)self.Attributes[key]=value end
		function child:Destroy()self.Alive=false end
		function child:ScrollToFragment(fragment)table.insert(self.Scrolls,fragment)end
		table.insert(mounted,{Target=target,HTML=html,Options=options,Page=child})
		return child
	end
	local function resolver(_,reference)
		if reference:find('missing',1,true) then
			return {Kind='missing',Name='NotFound',URL='http://localhost:8000/missing/index.html',Website={HTML='<p>404</p>',Options={}}}
		end
		return {Kind='internal',Name='CSSBackgroundPosition',URL='http://localhost:8000/css-background-position/index.html#top',Fragment='top',Website={HTML='<p>Background positions</p>',Stylesheets={['styles.css']='p{}'},Options={}}}
	end
	local diagnostics={}
	local api=Runtime.start(page,{IFrameItems={first}},function(message)table.insert(diagnostics,message)end,mount,{IFrameDepth=0,IFrameResolver=resolver})
	assert(deferred==1 and #mounted==1 and first.ChildPage==mounted[1].Page and first.CurrentURL:find('css%-background%-position'))
	assert(first.FallbackGui.Visible==false and first.ContentGui.Attributes.Status=='ready' and mounted[1].Options.IFrameDepth==1)
	assert(#mounted[1].Page.Scrolls==1 and mounted[1].Page.Scrolls[1]=='top')
	local firstChild=first.ChildPage
	mounted[1].Options.Navigate('http://localhost:8000/missing/index.html',{}, {Target=''})
	assert(not firstChild.Alive and #mounted==2 and mounted[2].Page.Root.Attributes.HTTPStatus==404)
	mounted[2].Options.Navigate('http://localhost:8000/main/index.html',{}, {Target='_parent'})
	assert(#parentNavigations==1 and parentNavigations[1].Target=='_self')
	api:Reload(first);assert(#mounted==3 and not mounted[2].Page.Alive)
	cleanups[1]();assert(not mounted[3].Page.Alive)

	local srcdoc=item({srcdoc='<p>Inline frame</p>'})
	local srcdocCleanups={}
	local srcdocPage={Alive=true,Document={},BaseURL='http://localhost:8000/test/index.html',AddCleanup=function(_,callback)table.insert(srcdocCleanups,callback)end}
	Runtime.start(srcdocPage,{IFrameItems={srcdoc}},function(message)table.insert(diagnostics,message)end,mount,{IFrameDepth=0})
	assert(mounted[#mounted].HTML=='<p>Inline frame</p>')
	assert(mounted[#mounted].Options.IsSrcdoc and mounted[#mounted].Options.DocumentURL=='about:srcdoc'
		and mounted[#mounted].Options.FallbackBaseURL==srcdocPage.BaseURL and srcdoc.CurrentURL=='about:srcdoc',
		'Srcdoc keeps its own document URL, forced standards parser and inherited about-base URL')
	srcdocCleanups[1]()

	local objectItem=item({data='../css-background-position/index.html',type='text/html'});objectItem.EmbeddedKind='object'
	local embedItem=item({src='../css-individual-transforms/index.html',type='text/html'});embedItem.EmbeddedKind='embed'
	local embeddedCleanups={}
	Runtime.start({Alive=true,Document={},BaseURL='http://localhost:8000/test/index.html',AddCleanup=function(_,callback)table.insert(embeddedCleanups,callback)end},
		{IFrameItems={objectItem,embedItem}},function(message)table.insert(diagnostics,message)end,mount,{IFrameDepth=0,IFrameResolver=resolver})
	assert(objectItem.ChildPage and embedItem.ChildPage and objectItem.CurrentURL and embedItem.CurrentURL)
	assert(objectItem.ContentGui.Attributes.Status=='ready' and embedItem.ContentGui.Attributes.Status=='ready')
	local objectChild,embedChild=objectItem.ChildPage,embedItem.ChildPage
	embeddedCleanups[1]();assert(not objectChild.Alive and not embedChild.Alive and objectItem.ChildPage==nil and embedItem.ChildPage==nil)

	local localSVG='<svg width="320" height="180" viewBox="0 0 320 180"><circle cx="40" cy="40" r="20"/></svg>'
	local svgObject=item({data='sample.svg',type='image/svg+xml'});svgObject.EmbeddedKind='object'
	local svgEmbed=item({src='./sample.svg',type='image/svg+xml'});svgEmbed.EmbeddedKind='embed'
	local svgCleanups={}
	Runtime.start({Alive=true,Document={},BaseURL='http://localhost:8000/html-css-stress-media/index.html',AddCleanup=function(_,callback)table.insert(svgCleanups,callback)end},
		{IFrameItems={svgObject,svgEmbed}},function(message)table.insert(diagnostics,message)end,mount,
		{IFrameDepth=0,SVGs={['sample.svg']=localSVG}})
	assert(svgObject.ChildPage and svgEmbed.ChildPage and mounted[#mounted].HTML:find(localSVG,1,true)
		and mounted[#mounted-1].HTML:find(localSVG,1,true),"Local SVG object/embed must mount their own scalable document")
	assert(mounted[#mounted].Options.ScrollBarThickness==0 and mounted[#mounted-1].Options.ScrollBarThickness==0,
		"Local SVG embeds use the full content box without a reserved scrollbar strip")
	svgCleanups[1]()

	local tooDeep=item({src='../main/index.html'})
	local depthCleanups={}
	Runtime.start({Alive=true,Document={},BaseURL='http://localhost:8000/test/index.html',AddCleanup=function(_,callback)table.insert(depthCleanups,callback)end},
		{IFrameItems={tooDeep}},function(message)table.insert(diagnostics,message)end,mount,{IFrameDepth=4,IFrameResolver=resolver})
	assert(tooDeep.Error=='iframe nesting limit reached' and tooDeep.FallbackGui.Visible)
	depthCleanups[1]()
	assert(#diagnostics==1)
	local queue={};local incremental=loadIFrameRuntime({defer=function(callback)table.insert(queue,callback)end})
	local pending=item({srcdoc="later"});local pendingPage={Alive=true,Document={},AddCleanup=function()end}
	local pendingTree={IFrameItems={}};local mountedBefore=#mounted
	local lifecycle=incremental.start(pendingPage,pendingTree,error,mount)
	lifecycle:Add({pending});lifecycle:Remove({pending});table.remove(queue,1)()
	assert(#mounted==mountedBefore and pending.ChildPage==nil,"Removed iframe work never mounts a child page")
	lifecycle:Add({pending});table.remove(queue,1)();local child=pending.ChildPage
	assert(child and child.Alive)
	lifecycle:Remove({pending});assert(not child.Alive and pending.ChildPage==nil,"Removal releases a mounted child even after its renderer array was pruned")
	lifecycle:Destroy()
	local yielding=item({srcdoc="yielding"});local yieldedChild
	local late;late=incremental.start(pendingPage,{IFrameItems={}},error,function(...)
		late:Remove({yielding});yieldedChild=mount(...);return yieldedChild
	end)
	late:Add({yielding});table.remove(queue,1)()
	assert(yieldedChild and not yieldedChild.Alive and yielding.ChildPage==nil,"A mount superseded during its yield releases the returned page")
	late:Destroy()
	-- Real mounted-document controller dependencies, including initial deferred
	-- mounting, child readiness and obsolete navigation callbacks.
	local wakes,loads,complete,subscriptionCount=0,0,false,0
	local loadPage={Alive=true,Document={},BaseURL='https://frames.test/page',DocumentURL='https://frames.test/page',AddCleanup=function()end,
		JavaScriptRuntime={ResourcesChanged=function()wakes+=1 end},HasOwnBlockingStylesheets=function()return true end,
		SubscribeStylesheetChanges=function(_,callback)subscriptionCount+=1;return function()subscriptionCount-=1 end end,
		Events={Emit=function(_,node,kind,_,flags)assert(kind=='load'and not flags.Bubbles);loads+=1 end}}
	local services={LoadStylesheet=function()end,LoadScript=function()end,ResourceServices={},RuntimeCreated=function()error('Parent realm owner cannot initialize a child')end}
	local inheritedStyles={['shared.css']='p{color:red}'}
	local loading=item({srcdoc='<p>Loading child</p>'});local mountedOptions,unsubscribe,oldNotify
	local loadController=incremental.start(loadPage,{IFrameItems={loading}},error,function(target,html,opts)
		mountedOptions=opts;assert(opts.HasParentBlockingStylesheets(),'Child receives its immediate parent stylesheet set')
		unsubscribe=opts.SubscribeParentStylesheetChanges(function()end)
		local child=mount(target,html,opts);child.JavaScriptRuntime={IsDocumentComplete=function()return complete end}
		opts.JavaScriptServices.RuntimeCreated(child.JavaScriptRuntime,child)
		local destroy=child.Destroy;child.Destroy=function(self)unsubscribe();destroy(self)end
		return child
	end,{JavaScriptServices=services,Stylesheets=inheritedStyles})
	assert(loadController:PendingCount()==1 and loads==0,'Deferred mounting delays containing document load')
	table.remove(queue,1)()
	assert(loadController:PendingCount()==1 and loads==0 and subscriptionCount==1,'Mounted child with pending resources still delays its owner')
	local inherited=mountedOptions.JavaScriptServices
	assert(inherited~=services and inherited.LoadStylesheet==services.LoadStylesheet and inherited.LoadScript==services.LoadScript
		and inherited.ResourceServices==services.ResourceServices and mountedOptions.Stylesheets==inheritedStyles,'Child isolates its service table while preserving inherited resource callbacks and stylesheet sources')
	assert(type(inherited.RuntimeCreated)=='function'and inherited.RuntimeCreated~=services.RuntimeCreated and services.RuntimeCreated~=nil,'Child retains its own pending mount without inheriting or removing the parent realm ownership callback')
	complete=true;mountedOptions.DocumentLoadStateChanged('complete')
	assert(loadController:PendingCount()==0 and loads==1,'Only child completion emits the frame load')
	mountedOptions.DocumentLoadStateChanged('complete');assert(loads==1,'One frame load per navigation generation')
	oldNotify=mountedOptions.DocumentLoadStateChanged;loadController:Remove({loading});assert(subscriptionCount==0)
	oldNotify('complete');assert(loads==1 and loadController:PendingCount()==0,'Removed child completion never emits a stale frame load')
	assert(wakes>0,'Child state changes wake pending parent resource tasks')
	loadController:Destroy();assert(loadPage.IFrameRuntime==nil)
	-- A child can supply native factories/resources, but cannot replace a
	-- containing window's filtered input owner with the global native service.
	local filtered,native,customFactory,customGui,customTasks={},{},{},{},{}
	local parentClock=function()return 1 end
	local parentInput=table.freeze({Input=filtered,Factory={},Clock=parentClock})
	local configuredInput=table.freeze({Input=native,Factory=customFactory,PlayerGui=customGui,Task=customTasks,ChildSetting=true})
	local inputItems={item({src='child'}),item({srcdoc='<p>srcdoc</p>'})}
	local inputCleanups={};local inputOptions={}
	local inputOwner=incremental.start({Alive=true,Document={},BaseURL='https://frames.test/input',AddCleanup=function(_,fn)table.insert(inputCleanups,fn)end},
		{IFrameItems=inputItems},error,function(target,html,opts)table.insert(inputOptions,opts);return mount(target,html,opts)end,
		{InputServices=parentInput,IFrameResolver=function()return {Kind='internal',URL='https://frames.test/child',Website={HTML='<p>child</p>',Options={InputServices=configuredInput}}}end})
	while #queue>0 do table.remove(queue,1)()end
	local configured,inline=inputOptions[1].InputServices,inputOptions[2].InputServices
	assert(configured~=configuredInput and configured~=parentInput and configured.Input==filtered,'An explicit child native service cannot bypass its parent filtered input owner')
	assert(configured.Factory==customFactory and configured.PlayerGui==customGui and configured.Task==customTasks and configured.Clock==parentClock and configured.ChildSetting,'Child native resources and parent defaults survive independent settings merge')
	assert(inline~=parentInput and inline.Input==filtered and inline.Factory==parentInput.Factory and inline.Clock==parentClock,'Srcdoc inherits a separate settings table and the same effective input owner')
	assert(configuredInput.Input==native and configuredInput.Clock==nil and parentInput.Factory~=customFactory and parentInput.ChildSetting==nil,'Parent and child source settings are immutable during input ownership projection')
	inputOwner:Destroy()
	local explicitOptions
	local explicit=incremental.start({Alive=true,Document={},BaseURL='https://frames.test/input',AddCleanup=function()end},{IFrameItems={item({src='child'})}},error,
		function(target,html,opts)explicitOptions=opts;return mount(target,html,opts)end,
		{InputServices={Factory={}},IFrameResolver=function()return {Kind='internal',URL='https://frames.test/child',Website={HTML='<p>child</p>',Options={InputServices=configuredInput}}}end})
	while #queue>0 do table.remove(queue,1)()end
	assert(explicitOptions.InputServices.Input==native and explicitOptions.InputServices~=configuredInput,'Without an explicit containing input owner, an independent child input adapter remains supported')
	explicit:Destroy()
	print('Embedded documents: iframe src/srcdoc, object data, embed src, independent navigation, parent targets, reload, depth limits and cleanup passed')
end
