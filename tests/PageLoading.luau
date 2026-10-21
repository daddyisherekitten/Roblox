--!strict
-- Mount real render/layout trees; hold image completion independently from layout.
return function(loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Dialog,Popover,DOM)
	local function signal()
		local entries={};local api={}
		function api:Connect(fn)local entry={Connected=true,Callback=fn};function entry:Disconnect()self.Connected=false end;table.insert(entries,entry);return entry end
		function api:Fire(...)for _,entry in table.clone(entries)do if entry.Connected then entry.Callback(...)end end end
		function api:Count()local count=0;for _,entry in entries do if entry.Connected then count+=1 end end;return count end
		return api
	end
	local function gui(class,parent,props)
		local object={ClassName=class,Parent=parent,Visible=true,AbsoluteSize=Vector2.new(400,300),AbsolutePosition=Vector2.new(0,0),Destroying=signal()}
		object.AnchorPoint=Vector2.new(0,0);object.Position=UDim2.fromOffset(0,0)
		object.BackgroundColor3=Color3.new(1,1,1);object.BackgroundTransparency=1
		if class=='ScrollingFrame'then object.CanvasPosition=Vector2.new(0,0);object.ScrollBarThickness=10 end
		for key,value in props or {}do object[key]=value end
		local attributes,signals,properties={},{},{}
		function object:GetAttribute(key)return attributes[key]end
		function object:GetAttributeChangedSignal(key)signals[key]=signals[key]or signal();return signals[key]end
		function object:SetAttribute(key,value)local changed=attributes[key]~=value;attributes[key]=value;if changed and signals[key]then signals[key]:Fire()end end
		function object:GetPropertyChangedSignal(key)properties[key]=properties[key]or signal();return properties[key]end
		function object:IsA(kind)return kind==class or kind=='GuiObject'end
		function object:Destroy()assert(not self.Destroyed,'Loading surface was destroyed twice');self.Destroyed=true;self.Parent=nil;self.Destroying:Fire()end
		return object
	end
	local function fixture(images,scripting,cooperative,byteFlow,stream,resolution)
		local jobs,created={},{};local time,passes=0,0;local tree,root,blank,page,wake
		local pending=false;local localItems=nil;local fontPublications=0;local observerPublications=0
		local changes={};local liveInput;local liveWaits=0;local livePublications=0;local publishedWidths={};local latestWidth=25
		local function enqueue(delay,callback)local job={Due=time+delay,Callback=callback};table.insert(jobs,job);return job end
		local tasks={defer=function(fn)return enqueue(0,fn)end,delay=enqueue,cancel=function(job)job.Cancelled=true end}
		local waits=0
		tasks.wait=function()
			waits+=1
			if page and page.Presented then
				assert(root.Visible,'Live input must not hide an already presented page')
				if liveInput then
					liveWaits+=1;assert(liveWaits<2048,'Continuous input starved layout publication across 2048 frame pauses')
					liveInput()
				end
			else assert(root and not root.Visible and blank and blank.Visible,'CPU loading pauses retain a blank surface')end
			time+=.016
			if cooperative=='cancel'then root:Destroy()end
			coroutine.yield('page-load')
		end
		local factory={create=function(class,parent,props)
			local object=gui(class,parent,props);table.insert(created,object)
			if props.Name=='WebsiteScrollingFrame'then root=object elseif props.Name=='HTMLLoadingSurface'then blank=object end
			return object
		end,modifier=gui}
		local renderer=loadRenderTree(factory)
		local emptyImageRuntime={Add=function(_,items)assert(#items==0)end,Remove=function(_,items)assert(#items==0)end}
		local layoutOptions={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return Vector2.new(#text*size*.45,size)end}}
		layoutOptions['Layout/WordLayout']=loadWordLayout(layoutOptions)
		local block=loadBlockLayout(layoutOptions)
		local module=loadHTMLPage({
            ['Rendering/BackgroundImages']=if resolution then {new=function(_,_,_,_,backgroundOptions)
                assert(backgroundOptions.Resolution==resolution,'Initial background resource density must receive configured MediaFeatures.Resolution')
                return {Destroy=function()end,RefreshFixed=function()end}
            end} else nil,
			['Rendering/GuiFactory']=factory,
			['Rendering/ImageLoad']={start=function()return function()end,emptyImageRuntime end},
			['Rendering/ImageDimensions']={start=function()return function()end,emptyImageRuntime end},
			['Layout/WordLayout']=layoutOptions['Layout/WordLayout'],
			['Layout/TextMeasure']=layoutOptions['Layout/TextMeasure'],
			['Rendering/RenderTree']={build=function(document,viewport,diagnostic)
				assert(viewport.Visible==false and blank.Visible,'The document is hidden before building any child')
				tree=renderer.build(document,viewport,diagnostic,function(font)return font end)
				Dialog.open(tree,DOM.findById(document,'modal'),true)
				Popover.show(tree,DOM.findById(document,'popover'))
				if images then tree.SVGItems={{}} end
				return tree
			end},
			['Rendering/SVGImages']={start=function(owner)
				owner.Root:SetAttribute('SVGReady',false)
				owner.Root:SetAttribute('SVGVisibleReady',false)
				return {}
			end},
			['Layout/BlockLayout']={arrange=function(...)
				passes+=1
				if not page or not page.Presented then assert(root.Visible==false and blank.Visible,'Initial layout never exposes intermediate geometry')end
				return block.arrange(...)
			end},
			['Input/Controller']={start=function()end},
			['Rendering/HTMLScripts']={ShouldStart=function()return true end,hasScripts=function()return false end,start=function(owner,_,schedule)
				wake=schedule
				if byteFlow then
					assert(owner.Document.CharacterEncoding=='UTF-8','Byte mount publishes its actual character encoding')
					if byteFlow=='certain'then
						assert(owner.ParserSession and owner.ParserFirstScript and not DOM.findById(owner.Document,'byte-future'),
							'Certain byte mount pauses at the script insertion point before later markup')
						while not owner.ParserSession.Done do owner.ParserSession:Advance()end
					else assert(not owner.ParserSession and DOM.findById(owner.Document,'byte-future'),'Tentative bytes retain the bounded pre-publication path')end
				end
				owner.JavaScriptRuntime={Pending=changes,HasOwnBlockingStylesheets=function()return false end,
					ResourcesChanged=function()end,
					SubscribeStylesheetChanges=function()return function()end end,
					HasPending=function()return pending end,Flush=function()
					if next(changes)then local batch=changes;changes={};owner.JavaScriptRuntime.Pending=changes;pending=false;return tree:ApplyDOMChanges(batch)end
					pending=false;local items=localItems;localItems=nil;return items~=nil,items
				end,FontLayoutCompleted=function()fontPublications+=1 end,AfterLayout=function()
					observerPublications+=1
					local bar=tree.NodeBoxes[DOM.findById(owner.Document,'live-bar')]
					if bar then table.insert(publishedWidths,bar.OuterWidth)end
					if liveInput then livePublications+=1;if livePublications>=3 then liveInput=nil end end
				end}
			end},
		},tasks,function()if cooperative then time+=.0005 end;return time end)
		local enabled=scripting==true or scripting=='default'
		local mountOptions=if scripting=='default'then {RenderWorkBudgetMS=0}else {JavaScript=enabled,RenderWorkBudgetMS=0}
		if cooperative then mountOptions.RenderWorkBudgetMS=2 end
        if resolution then mountOptions.MediaFeatures={Resolution=resolution}end
		if byteFlow then
			mountOptions.ByteSource=true
			mountOptions.DocumentEncoding=if byteFlow=='certain'then {TransportEncoding='utf-8'}else{}
		end
		local function execute(fn)
			local thread=coroutine.create(fn)
			while coroutine.status(thread)~='dead'do local ok,message=coroutine.resume(thread);assert(ok,tostring(message))end
		end
		local source='<div style="position:fixed;top:0;left:0;width:100px;height:30px">Fixed</div><p id="stable-copy">Normal flow</p><noscript><p id="script-fallback" style="position:fixed;bottom:0">Enable JavaScript</p></noscript><dialog id="modal"><button>Dialog</button></dialog><div id="popover" popover>Popover</div>'
		if stream then source..='<style>.live-narrow{width:40%}.live-wide{width:80%}</style><div style="width:200px"><div id="live-bar" style="width:25%;height:8px"></div></div>'end
		if byteFlow then source='<meta charset=utf-8>'..source..'<script></script><p id="byte-future">Later</p>'end
		execute(function()page=module.mount(gui('Frame',nil,{}),source,mountOptions)end)
		if cooperative=='cancel'then return {Page=page,Root=root,Blank=blank,Waits=function()return waits end}end
		assert(page.Document.ScriptingEnabled==enabled,'Page parser follows the JavaScript option')
		local fallback=DOM.findById(page.Document,'script-fallback')
		assert(if enabled then fallback==nil else fallback~=nil and tree.NodeBoxes[fallback]~=nil,'Fallback is rendered only when JavaScript is disabled')
		local function drain()
			local rounds=0
			while #jobs>0 do rounds+=1;assert(rounds<30,'Loading failed to settle');local job=table.remove(jobs,1);if not job.Cancelled then time=math.max(time,job.Due);execute(job.Callback)end end
		end
		return {Page=page,Root=root,Blank=blank,Tree=tree,Drain=drain,Jobs=jobs,Passes=function()return passes end,Waits=function()return waits end,
			Stream=function(mode)
				local bar=DOM.findById(page.Document,'live-bar');local copy=DOM.findById(page.Document,'stable-copy')
				local function change(value)
					latestWidth=value;bar.Attributes.style='width:'..value..'%;height:8px';changes[bar]={Attributes={style=true}}
					if mode=='class'then
						latestWidth=if value<60 then 40 else 80;bar.Attributes.style='height:8px';bar.Attributes.class=if latestWidth==40 then 'live-narrow'else 'live-wide'
						changes[bar].Attributes.class=true
					end
					copy.Children[1].Text=tostring(value);changes[copy.Children[1]]={Text=true,Attributes={}}
					pending=true;wake()
				end
				change(40);liveInput=function()
					if mode=='structure' or mode=='viewport' or mode=='attribute' or mode=='dispose'then
						liveInput=nil
						if mode=='viewport'then root.AbsoluteSize=Vector2.new(650,400);root:GetPropertyChangedSignal('AbsoluteSize'):Fire()
						elseif mode=='dispose'then root:Destroy()
						elseif mode=='structure'then DOM.append(copy,DOM.element('span',{}));changes[copy]={Children=true,Attributes={}};pending=true;wake()
						else bar.Attributes.title='changed';changes[bar]={Attributes={title=true}};pending=true;wake()end
					else change(41+liveWaits%50)end
				end
			end,LiveWaits=function()return liveWaits end,LatestWidth=function()return latestWidth end,PublishedWidths=publishedWidths,
			Paint=function()pending=true;wake()end,Finish=function()root:SetAttribute('SVGVisibleReady',true)end,
			MeasureLocal=function()
				local node=DOM.findById(page.Document,'stable-copy');local box=tree.NodeBoxes[node]
				node.Children[1].Text='Newer flow';box:RefreshText(true)
				localItems={[box]=true};pending=true;wake()
			end,FontPublications=function()return fontPublications end,ObserverPublications=function()return observerPublications end}
	end
	local a=fixture(true)
	assert(not a.Root.Visible and a.Blank.Visible and not a.Tree.DialogHost.Layer.Visible and not a.Tree.ViewportLayer.Visible)
	a.Drain()
	assert(a.Root:GetAttribute('Status')=='ready'and not a.Root:GetAttribute('Presented')and not a.Root.Visible and a.Blank.Visible,'Measured geometry still waits for the initial SVG upload')
	-- A resize during initial loading must settle before revealing the new width.
	a.Root.AbsoluteSize=Vector2.new(650,400);a.Root:GetPropertyChangedSignal('AbsoluteSize'):Fire()
	a.Finish();a.Paint();a.Drain()
	assert(a.Page.Presented and a.Root.Visible and a.Blank.Destroyed and a.Root:GetAttribute('SVGReady')==false,'Visible SVGs release the page while hover prewarming continues')
	assert(a.Tree.DialogHost.Layer.Visible and a.Tree.ViewportLayer.Visible,'Top-layer and fixed surfaces reveal with the document')
	local passes=a.Passes()
	a.Page:SetVisible(false);assert(not a.Root.Visible and not a.Tree.DialogHost.Layer.Visible and not a.Tree.ViewportLayer.Visible)
	a.Page:SetVisible(true);assert(a.Root.Visible and a.Tree.DialogHost.Layer.Visible and a.Passes()==passes,'A failed navigation can restore the previous page without rebuilding it')
	a.Root:SetAttribute('SVGVisibleReady',false)
	a.Root.AbsoluteSize=Vector2.new(720,450);a.Root:GetPropertyChangedSignal('AbsoluteSize'):Fire();a.Drain()
	assert(a.Root.Visible and a.Blank.Destroyed,'Later layout/SVG work never reactivates the loading screen')
	a.Page:Destroy()
	local b=fixture(true);b.Drain();b.Finish();b.Paint();b.Drain()
	assert(b.Page.Presented,'A paint-only initialization callback cannot strand a measured page behind the blank surface')
	local localPasses,observers=b.Passes(),b.ObserverPublications()
	b.MeasureLocal();b.Drain()
	assert(b.Passes()==localPasses and b.FontPublications()==1 and b.ObserverPublications()==observers,
		'A genuine stable text measurement releases font layout readiness without arranging the page or publishing every observer')
	b.Page:Destroy()
	local c=fixture(true);c.Drain();c.Finish();c.Page:Destroy();c.Drain()
	assert(c.Blank.Destroyed and c.Root.Destroyed and not c.Root.Visible and not c.Page.Presented,'Disposal invalidates an already queued reveal')
	assert(c.Root:GetAttributeChangedSignal('SVGVisibleReady'):Count()==0,'Disposal removes presentation listeners')
	assert(c.Root:GetAttributeChangedSignal('CompositeVisibleReady'):Count()==0,'Disposal removes composition presentation listeners')
	local composite=fixture(true);composite.Root:SetAttribute('CompositeVisibleReady',false);composite.Drain();composite.Finish();composite.Drain()
	assert(not composite.Page.Presented and composite.Blank.Visible,'Initial blended pixels must finish before blank loading is released')
	composite.Root:SetAttribute('CompositeVisibleReady',true);composite.Drain();assert(composite.Page.Presented,'Finished composition releases the initial presentation')
	composite.Root:SetAttribute('CompositeVisibleReady',false);composite.Drain();assert(composite.Root.Visible,'Later blend work does not re-hide a presented page');composite.Page:Destroy()
	local d=fixture(false);d.Drain();assert(d.Page.Presented and d.Root.Visible and d.Blank.Destroyed,'Documents without SVG reveal after their first stable layout');d.Page:Destroy()
	local e=fixture(false,true);e.Drain();assert(e.Page.Presented and e.Root.Visible,'Enabled scripting without script tags still hides noscript');e.Page:Destroy()
	local f=fixture(false,'default');f.Drain();assert(f.Page.Presented and f.Root.Visible,'Scripting is enabled by default for mounted pages');f.Page:Destroy()
	local g=fixture(false,false,true);g.Drain();assert(g.Page.Presented and g.Waits()>0 and not g.Page.LoadingWork.Active,'Parsing, GUI and layout pauses settle before the first reveal');g.Page:Destroy()
	local h=fixture(false,false,'cancel');assert(not h.Page.Alive and h.Root.Destroyed and h.Blank.Destroyed and h.Waits()==1,'Cancellation during parsing removes the complete staging surface')
	for _,mode in {'style','class'}do
	local continuous=fixture(false,true,true,nil,true);continuous.Drain()
	local bar=continuous.Tree.NodeBoxes[DOM.findById(continuous.Page.Document,'live-bar')];local retained=bar.Gui
	local beforePasses,beforePublications=continuous.Passes(),#continuous.PublishedWidths
	continuous.Stream(mode);continuous.Drain()
	assert(continuous.LiveWaits()>1 and #continuous.PublishedWidths>=beforePublications+3,'Continuous events must still publish intermediate geometry: waits='..continuous.LiveWaits()..', publications='..#continuous.PublishedWidths..', previous='..beforePublications..', passes='..continuous.Passes()..', error='..tostring(continuous.Root:GetAttribute('Error')))
	assert(continuous.Passes()<=beforePasses+5,'Queued style/text input must retain partial passes instead of repeatedly restarting the page')
	assert(math.abs(bar.OuterWidth-2*continuous.LatestWidth())<.01 and bar.Gui==retained and not continuous.Page:HasPendingLayout(),'The latest queued percentage reaches the retained bar')
	assert(continuous.PublishedWidths[beforePublications+1]~=continuous.PublishedWidths[beforePublications],'The first complete pass advances the visible bar while input is still arriving')
	continuous.Page:Destroy()
	end
	for _,mode in {'structure','viewport','attribute','dispose'}do
		local interrupted=fixture(false,true,true,nil,true);interrupted.Drain();local previous=interrupted.Passes()
		interrupted.Stream(mode);interrupted.Drain()
		if mode=='dispose'then assert(not interrupted.Page.Alive and interrupted.Root.Destroyed,'Disposal still aborts a live pass')
		else
			assert(interrupted.LiveWaits()==1 and interrupted.Passes()==previous+2 and interrupted.Page.LastLayoutStats.Mode=='full','Unsafe changes still cancel and recover the actual layout: '..mode)
			assert(interrupted.Root:GetAttribute('Status')=='ready'and not interrupted.Page:HasPendingLayout())
			if mode=='viewport'then assert(interrupted.Page:GeometryViewport().Width==650)end
			interrupted.Page:Destroy()
		end
	end
	local definite=fixture(false,true,false,'certain');definite.Drain()
	local byteParser=definite.Page.ParserSession;assert(definite.Page.Presented and byteParser.Done)
	definite.Page:Destroy();assert(not byteParser.Alive,'Byte mount disposal releases its parser and retained source')
	local tentative=fixture(false,true,false,'tentative');tentative.Drain();assert(tentative.Page.Presented);tentative.Page:Destroy()
	for _,density in {.75,2.5}do local f=fixture(false,false,false,nil,false,density);f.Drain();assert(f.Page.Presented);f.Page:Destroy()end
    print('Page loading: blank construction/layout, SVG upload vs prewarming, top layers, paint-only initialization, resize, restore and stale reveal cleanup passed')
end
