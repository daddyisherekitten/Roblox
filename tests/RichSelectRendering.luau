--!strict
return function(Parser,Node,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,FormModel,Controller,loadFontPreload,loadImageDimensions,loadImageLoad)
	local function signal()
		local listeners={};local api={}
		function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(listeners,{c,fn});return c end
		function api:Fire(...)for _,entry in table.clone(listeners)do if entry[1].Connected then entry[2](...)end end end
		function api:Count()local n=0;for _,entry in listeners do if entry[1].Connected then n+=1 end end;return n end
		return api
	end
	local guis={};local factory={create=function(class,parent,props)
		local gui=table.clone(props);gui.ClassName=class;gui.Parent=parent;gui.Visible=true;gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(600,480)
		if class=='ScrollingFrame'then gui.CanvasPosition=Vector2.new(0,0)end
		local attributes,signals={},{};gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal()
		function gui:GetPropertyChangedSignal(key)signals[key]=signals[key]or signal();return signals[key]end
		function gui:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal('attribute:'..key)end
		function gui:SetAttribute(key,value)attributes[key]=value end;function gui:GetAttribute(key)return attributes[key]end
		function gui:IsA(kind)return kind==class or kind=='GuiObject'end
		function gui:Destroy()assert(not self.Destroyed,'Double GUI cleanup');self.Destroyed=true;for _,child in guis do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil end
		table.insert(guis,gui);return gui
	end};factory.modifier=factory.create
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.5,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local document=Parser.parseDocument([=[<!doctype html><style>
		select { appearance:base-select; width:240px } selectedcontent { display:flex; align-items:center; gap:8px }
		b { color:red } i { color:blue }
	</style><select id="s"><button><selectedcontent id="m"></selectedcontent></button>
		<option value="a"><b>Alpha</b><img src="icon" width="18" height="12"></option>
		<option value="b"><i>Beta</i><img src="icon" width="22" height="16"></option></select>
	<p id="outside">Retained outside.</p><script></script>]=])
	local warnings={};local root=factory.create('ScrollingFrame',nil,{})
	local tree=renderer.build(document,root,function(m)table.insert(warnings,m)end,function(font)return font end,nil,nil,function()return 'rbxassetid://1'end)
	local events=Events.new(error);local model=FormModel.new(document,tree.Controls,events,function()end)
	local page={Alive=true,Document=document,Root=root,Events=events,FormModel=model,Cleanups={},DocumentURL='https://example.test/select'}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end;function page:RefreshDOMControls()model:RefreshControls()end
	local realm,flushing;local arrangements=0
	local function arrange(targets)arrangements+=1;Dirty.begin(tree,targets);layout.arrange(tree,600,0,0,function()return true end);Dirty.finish(tree,true)end
	function page:FlushScriptLayout()if realm and not flushing then flushing=true;local needed,targets=realm:Flush();if needed then arrange(targets)end;flushing=false end end
	function page:HasPendingLayout()return false end
	function page:GeometryViewport()return {Width=600,Height=480,ClientWidth=600,ClientHeight=480,ScrollWidth=600,ScrollHeight=480,ScrollX=0,ScrollY=0}end
	arrange();root:SetAttribute('Status','ready')
	local services={Clock=function()return 0 end,RunService={RenderStepped=signal()},Task={delay=function(_,fn)return {Callback=fn}end,cancel=function(t)t.Canceled=true end}}
	local diagnostics={};realm=HTMLScripts.start(page,tree,function()end,function(m)table.insert(diagnostics,m)end,{JavaScriptServices=services})
	local select=Node.findById(document,'s');local mirror=Node.findById(document,'m');local box=tree.NodeBoxes[select];local surface=box.Gui;local outside=tree.NodeBoxes[Node.findById(document,'outside')].Gui
	assert(box.RichSelect and not model:Resolve(mirror.Parent)and #tree.Controls==1,'First select button is inert, one selectable rich control')
	assert(box.Style.FontSize==16 and box.Style.Padding[1]==4 and box.Style.Display=='inline-flex','Base-select UA layout inherits font and preserves native padding')
	local function visibleCopy(text,width,color)
		local copied=mirror.Children[1];assert(Node.textContent(copied)==text)
		local found=false;for _,item in tree.TextItems do if item.Text==text then assert(item.Style.Color==color,'Rich text color');found=true end end
		assert(found,'Rich text was flattened or omitted')
		local image=tree.NodeBoxes[mirror.Children[2]];assert(image and image.ImageItem and image.ImageItem.BoxWidth==width,'Rich image geometry')
		assert(tree.NodeBoxes[select].Gui==surface and tree.NodeBoxes[Node.findById(document,'outside')].Gui==outside,'Retained select and unrelated GUI')
		assert(#warnings==0 and #diagnostics==0,table.concat(warnings,' / ')..table.concat(diagnostics,' / '))
	end
	visibleCopy('Alpha',18,Color3.fromRGB(255,0,0))
	local function run(code)
		assert(realm:Run(code));for _=1,16 do page:FlushScriptLayout();realm:AfterLayout();local tasks=realm:PumpTasks();if not realm:HasPending()and tasks==0 then break end end;page:FlushScriptLayout()
		assert(not realm:HasPending(),'Mirror replacement caused a flush loop')
	end
	run("globalThis.s=document.getElementById('s');s.value='b';");visibleCopy('Beta',22,Color3.fromRGB(0,0,255))
	run("s.value='a';");visibleCopy('Alpha',18,Color3.fromRGB(255,0,0))
	local before=arrangements;run("s.options[0].firstChild.textContent='Other';");visibleCopy('Alpha',18,Color3.fromRGB(255,0,0));assert(arrangements==before,'Unchanged snapshot should not dirty rich layout')
	run("s.value='a';");visibleCopy('Other',18,Color3.fromRGB(255,0,0))
	run("globalThis.iconSheet=document.createElement('style');iconSheet.textContent='#s::picker-icon{content:\"v\";color:blue;width:18px}';document.head.append(iconSheet);")
	local icon
	for _,item in tree.TextItems do if item.Text=='v'and item.Style.PseudoElement=='picker-icon'then icon=item end end
	assert(icon and icon.Gui.TextColor3==Color3.fromRGB(0,0,255),'Generated picker content reaches real text paint')
	run("iconSheet.textContent='#s::picker-icon{content:none}';")
	assert(icon.Gui.Destroyed and tree.NodeBoxes[select].Gui==surface,'Removing picker content releases only the generated box')
	run("iconSheet.remove();")
	assert(tree:PseudoStyle(select,'picker-icon').GeneratedContent[1].Kind=='counter','Removing the author rule restores the UA disclosure counter')
	assert(services.RunService.RenderStepped:Count()==0,'No idle update connection')
	page.Alive=false;for i=#page.Cleanups,1,-1 do page.Cleanups[i]()end;model:Destroy();events:Destroy()
	assert(model.Controls[1].UpdateSelectedContent==nil,'Released mirror hooks')
	local nativeDoc=Parser.parseDocument([=[<!doctype html><style id="native-styles">select::picker(select){appearance:base-select}select.native-picker::picker(select){appearance:auto}option b {color:red} option i {color:blue}</style><select id="native" style="appearance:base-select;width:220px"><button><selectedcontent id="nm"></selectedcontent></button><option value="a"><b>Alpha</b><img src="icon" width="18" height="12"></option><option value="b"><i>Beta</i><img src="icon" width="22" height="36"></option></select>]=])
	local nativeTree=renderer.build(nativeDoc,root,error,function(font)return font end,nil,nil,function()return 'rbxassetid://1'end);layout.arrange(nativeTree,600,0,0,function()return true end)
	local nativePage={Alive=true,Document=nativeDoc,Root=root,Cleanups={}};function nativePage:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox()return nil end;function input:IsKeyDown()return false end;function input:GetStringForKeyCode()return ''end
	local requests={};local cleanup=Controller.start(nativePage,nativeTree,function(_,target)requests[target]=true end,error,{Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return{}end},Factory=factory,Clock=function()return 0 end})
	local nativeSelect=Node.findById(nativeDoc,'native');local nativeMirror=Node.findById(nativeDoc,'nm');local nativeControl=nativePage.FormModel:Resolve(nativeSelect);local nativeSurface=nativeControl.Item.Gui
	local Popup=require('Input/SelectPopup');local richViews={}
	local function word(view,text,host)
		for _,item in view.TextItems do if item.Text==text and(not host or item.Style.Node==host)then return item end end
		return nil
	end
	local fragments=require('Rendering/PickerFragments').new(nativePage,nativeTree,error,{PickerLayout=layout})
	local mount=fragments.MountPicker;fragments.MountPicker=function(...)local record=mount(...);table.insert(richViews,record.Tree);return record end
	local popupParent=factory.create('Frame',nil,{});root.Parent=popupParent;root.AbsoluteSize=Vector2.new(600,480)
	nativeControl.Item.BoxGui.AbsolutePosition=Vector2.new(10,10);nativeControl.Item.BoxGui.AbsoluteSize=Vector2.new(220,30)
	local picked=0;local popup=Popup.new(nativePage,function(_,index)picked=index end,factory,nil,fragments)
	popup:Open(nativeControl);assert(#richViews==1 and popup.CustomPicker,'Rich options share one retained CSS picker tree')
	assert(word(richViews[1],'Alpha').Style.Color==Color3.fromRGB(255,0,0)and word(richViews[1],'Beta').Style.Color==Color3.fromRGB(0,0,255),'Picker uses author selectors against original option ancestry')
	local firstOption,secondOption=nativeControl.Options[1].Node,nativeControl.Options[2].Node
	assert(word(richViews[1],'✓',firstOption).Style.Visibility=='visible'and word(richViews[1],'✓',secondOption).Style.Visibility=='hidden','Only the selected option shows its generated checkmark')
	local nativeSheet=Node.findById(nativeDoc,'native-styles')
	-- Resolve through the original stylesheet and update the already open view.
	nativeSheet.Children[1].Text..=' option::checkmark{content:"+";color:green} option:checked::checkmark{color:red}'
	nativeTree:ApplyDOMChanges({[nativeSheet]={Text=true}});popup:Refresh()
	assert(word(richViews[1],'+',firstOption).Gui.TextColor3==Color3.fromRGB(255,0,0)and word(richViews[1],'+',firstOption).Gui.TextTransparency==0,'Checked pseudo author color reaches popup paint')
	nativePage.FormModel:SetValue(nativeControl,'b');popup:Refresh()
	assert(word(richViews[1],'+',firstOption).Gui.TextTransparency==1 and word(richViews[1],'+',secondOption).Gui.TextTransparency==0,'Live selection changes generated checkmark visibility without replacing option views')
	nativePage.FormModel:SetValue(nativeControl,'a');popup:Refresh()
	assert(richViews[1].NodeBoxes[secondOption].OuterHeight>richViews[1].NodeBoxes[firstOption].OuterHeight and nativeTree.NodeBoxes[nativeSelect].Gui==nativeSurface,'Image heights determine individual row geometry; page identity is retained')
	local option=nativeControl.Options[1].Node;local optionGui=richViews[1].Gui;option.Children[1].Children[1].Text='Changed'
	popup:Refresh();assert(#richViews==1 and richViews[1].Gui==optionGui and word(richViews[1],'Changed'),'Open picker refreshes original option content on the retained view')
	option.Children[1].Children[1].Text='Alpha';popup:Refresh()
	popup:HighlightRow(2);popup:Commit();assert(picked==2 and richViews[1].Gui.Destroyed,'Rich picker commits and releases its retained view')
	-- The picker opts in independently of the rich first button. Changing
	-- its appearance releases only its own fragments, not the page control.
	nativeSelect.Attributes.class='native-picker';nativeTree:ApplyDOMChanges({[nativeSelect]={Attributes={class=true}}})
	popup:Open(nativeControl);assert(not popup.CustomPicker and #richViews==1,'A base-select button does not force a custom picker')
	nativeSelect.Attributes.class=nil;nativeTree:ApplyDOMChanges({[nativeSelect]={Attributes={class=true}}});popup:Refresh()
	assert(popup.CustomPicker and #richViews==2 and nativeControl.Item.Gui==nativeSurface,'An open picker switches to its own live appearance without replacing the select')
	local labeledView=richViews[2];local labeledImage=labeledView.ImageItems[1].Gui;option.Attributes.label='Only the label';nativeTree:RefreshSelectContent(nativeSelect);popup:Refresh()
	assert(not labeledView.Gui.Destroyed and labeledImage.Destroyed and #richViews==2 and #labeledView.ImageItems==1,'A nonempty label retains the picker and releases only its suppressed option resources')
	assert(word(labeledView,'Only')and word(labeledView,'label')and not word(labeledView,'Alpha')and word(labeledView,'Beta'),'The specified label is the sole visible content of its option; other options stay intact')
	option.Attributes.label='';nativeTree:RefreshSelectContent(nativeSelect);popup:Refresh()
	assert(#richViews==2 and word(labeledView,'Alpha')and #labeledView.ImageItems==2,'An empty label restores rich children on the retained row/view')
	nativeControl.Item.Style.Appearance='auto';popup:Refresh()
	assert(not popup.CustomPicker and richViews[2].Gui.Destroyed,'Picker base appearance requires base appearance on its select')
	nativeControl.Item.Style.Appearance='base-select';option.Attributes.label=nil;nativeTree:RefreshSelectContent(nativeSelect);popup:Close()
	-- A cooperative mount may finish after its host closed, even after another
	-- popup for the same control opened. The old completion must not close it.
	local pendingPopup;local mode,lateViews=0,{}
	local cancellationFragments={MountPicker=function(...)
		local record=mount(...);table.insert(lateViews,record.Tree)
		if mode>0 then local reopen=mode==2;mode=0;pendingPopup:Close();if reopen then pendingPopup:Open(nativeControl)end end
		return record
	end}
	pendingPopup=Popup.new(nativePage,function()end,factory,nil,cancellationFragments)
	mode=1;pendingPopup:Open(nativeControl)
	assert(pendingPopup.Control==nil and lateViews[1].Gui.Destroyed,'Late mount is released after closing')
	table.clear(lateViews);mode=2;pendingPopup:Open(nativeControl)
	assert(pendingPopup.Control==nativeControl and #lateViews==2,'Old completion cannot close the replacement popup for the same control')
	assert(lateViews[1].Gui.Destroyed and not lateViews[2].Gui.Destroyed,'Only canceled content is released')
	pendingPopup:Close();assert(lateViews[2].Gui.Destroyed,'Replacement resources are released on their own close')
	local refreshingPopup;local refreshOnce=true;local refreshedViews={}
	refreshingPopup=Popup.new(nativePage,function()end,factory,nil,{MountPicker=function(...)
		local record=mount(...);table.insert(refreshedViews,record.Tree)
		if refreshOnce then refreshOnce=false;option.Children[1].Children[1].Text='Concurrent';refreshingPopup:Refresh()end
		return record
	end})
	refreshingPopup:Open(nativeControl)
	assert(#refreshedViews==1 and word(refreshedViews[1],'Concurrent'),'Reentrant refresh is coalesced without duplicating retained picker views')
	refreshingPopup:Close();assert(refreshedViews[1].Gui.Destroyed,'Coalesced picker views are released')
	option.Children[1].Children[1].Text='Alpha'
	nativePage:SetValue('native','b');assert(Node.textContent(nativeMirror)=='Beta'and next(requests),'Native selection updates DOM copy and requests local rich layout')
	layout.arrange(nativeTree,600,0,0,function()return true end);local nativeLabel
	for _,item in nativeTree.TextItems do if item.Text=='Beta'then nativeLabel=item.Gui end end;assert(nativeLabel,'Native rich selection paints without JavaScript')
	nativeTree.LayoutInProgress=true;table.clear(requests);nativePage:SetValue('native','a')
	assert(Node.textContent(nativeMirror)=='Alpha'and nativeTree.PendingRichSelectChanges and not nativeLabel.Destroyed,'A running layout retains its current native snapshot')
	nativeTree.LayoutInProgress=false;local changed,needed=nativeTree:FlushCSSStates();assert(changed and needed and not nativeTree.PendingRichSelectChanges,'Deferred native copy publishes at the layout boundary')
	layout.arrange(nativeTree,600,0,0,function()return true end);assert(nativeControl.Item.Gui==nativeSurface,'Native select surface survives copy updates')
	nativePage.Alive=false;cleanup()
	-- Rich legends use their original group ancestry, retain their row and
	-- update the popup's outer bounds when their actual content height changes.
	local groupedDoc=Parser.parseDocument([=[<!doctype html><style>
		select::picker(select){appearance:base-select}optgroup {color:green;font-size:20px} legend b{color:purple}
	</style><select id="grouped" style="appearance:base-select;width:220px"><button><selectedcontent></selectedcontent></button><optgroup label="Ignored"><legend id="legend"><b>Places</b><img id="groupImage" src="icon" width="18" height="28"></legend><option value="a">Alpha</option><option value="b">Beta</option></optgroup></select>]=])
	local groupedTree=renderer.build(groupedDoc,root,error,function(font)return font end,nil,nil,function()return 'rbxassetid://1'end)
	layout.arrange(groupedTree,600,0,0,function()return true end)
	local groupedPage={Alive=true,Document=groupedDoc,Root=root,Cleanups={}};function groupedPage:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	local stopGrouped=Controller.start(groupedPage,groupedTree,function()end,error,{Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return{}end},Factory=factory,Clock=function()return 0 end})
	local groupedSelect=Node.findById(groupedDoc,'grouped');local grouped=groupedPage.FormModel:Resolve(groupedSelect)
	grouped.Item.BoxGui.AbsolutePosition=Vector2.new(10,420);grouped.Item.BoxGui.AbsoluteSize=Vector2.new(220,30)
	local groupViews={};local groupFragments=require('Rendering/PickerFragments').new(groupedPage,groupedTree,error,{PickerLayout=layout})
	local groupMount=groupFragments.MountPicker;groupFragments.MountPicker=function(...)local record=groupMount(...);table.insert(groupViews,record.Tree);return record end
	local groupPopup=Popup.new(groupedPage,function()error('Group must not be selectable')end,factory,nil,groupFragments)
	groupPopup:Open(grouped)
	local legend=Node.findById(groupedDoc,'legend');local group=legend.Parent;local legendSurface=groupViews[1].NodeBoxes[legend].Gui
	assert(#groupViews==1 and groupViews[1].NodeBoxes[legend]and grouped.SelectRows[1].Caption=='Places','First rich legend replaces the label attribute inside the shared CSS picker')
	assert(word(groupViews[1],'Places').Style.Color==Color3.fromRGB(128,0,128)and word(groupViews[1],'Alpha').Style.Color==Color3.fromRGB(0,128,0)and word(groupViews[1],'Alpha').Style.FontSize==20,'Legend/option styles inherit through the original optgroup')
	local function live(name)for i=#guis,1,-1 do if guis[i].Name==name and not guis[i].Destroyed then return guis[i]end end end
	local groupSurface=groupViews[1].NodeBoxes[group].Gui;local popupSurface=live('SelectPopup');local initialHeight=popupSurface.Size[2]
	Node.findById(groupedDoc,'groupImage').Attributes.height='80';groupPopup:Refresh()
	assert(groupSurface==groupViews[1].NodeBoxes[group].Gui and popupSurface==live('SelectPopup')and popupSurface.Size[2]>=initialHeight,'A growing legend retains the actual group and popup, subject to its CSS max height')
	-- The native UA picks the larger block-start area here. The isolated CDP
	-- capture in select-ua-browser.json measures the actual anonymous picker,
	-- including legend growth; its bottom remains at the select's top (420).
	assert(popupSurface.Position[2]+popupSurface.Size[2]==420,'UA most-block-size chooses the larger area above the select and retains its anchor edge during growth')
	Node.findById(groupedDoc,'groupImage').Attributes.height='12';groupPopup:Refresh()
	assert(popupSurface.Size[2]<=initialHeight and groupViews[1].NodeBoxes[legend].OuterHeight<80,'Shrinking legend restores its actual CSS row size within the same constrained popup')
	Node.removeChild(legend.Parent,legend)
	groupedTree:RefreshSelectContent(groupedSelect);groupedPage:RefreshDOMControls();groupPopup:Refresh()
	assert(legendSurface.Destroyed and word(groupViews[1],'Ignored')and groupSurface==groupViews[1].NodeBoxes[group].Gui and not groupViews[1].Gui.Destroyed,'Removing the first legend restores the group label and releases only its owned subtree')
	groupPopup:Close();groupedPage.Alive=false;stopGrouped()
	local resourceDoc=Parser.parseDocument('<!doctype html><style>select::picker(select){appearance:base-select}</style><select id="resources" style="appearance:base-select;width:220px"><button><selectedcontent></selectedcontent></button><option><span>Late image</span><img id="lateImage" src="late"></option></select>')
	local resourceTree=renderer.build(resourceDoc,root,error,function(font)return font end,nil,nil,function(source)return if source=='late'then 'rbxassetid://1'else 'rbxassetid://2'end)
	layout.arrange(resourceTree,600,0,0,function()return true end)
	local resourceControl=resourceTree.Controls[1];resourceControl.Item.BoxGui.AbsolutePosition=Vector2.new(10,10);resourceControl.Item.BoxGui.AbsoluteSize=Vector2.new(220,30)
	local completions,canceled,queue,preloads={},{},{},0
	local resourcePage={Alive=true,Root=root,ResourceLoadHost={}}
	function resourcePage.ResourceLoadHost:LoadRasterDimensions(source,complete)
		local index=#completions+1;completions[index]={Source=source,Finish=complete};return function()canceled[index]=true end
	end
	local resourceServices={Task={defer=function(fn)table.insert(queue,fn)end},ContentProvider={PreloadAsync=function(_,targets,callback)
		preloads+=1;for _,target in targets do if target.ClassName=='ImageLabel'then target.IsLoaded=true;target:GetPropertyChangedSignal('IsLoaded'):Fire()end;callback('resource','Success')end
	end}}
	local resourceEnums=table.clone(Enum);resourceEnums.AssetFetchStatus={Success='Success'}
	local nativeFonts=loadFontPreload({GetService=function()error('Use injected font provider')end},nil,resourceEnums)
	local nativeDimensions,nativeImages=loadImageDimensions(nil,nil),loadImageLoad(nil,nil,resourceEnums)
	local resourceViews={};local resourceFragments=require('Rendering/PickerFragments').new(resourcePage,resourceTree,error,{PickerLayout=layout,ResourceServices=resourceServices,PickerFontPreload=nativeFonts,PickerImageDimensions=nativeDimensions,PickerImageLoad=nativeImages})
	local resourceMount=resourceFragments.MountPicker;resourceFragments.MountPicker=function(...)local record=resourceMount(...);table.insert(resourceViews,record.Tree);return record end
	local resourcePopup=Popup.new(resourcePage,function()end,factory,nil,resourceFragments)
	resourcePopup:Open(resourceControl);local loadedPopup=live('SelectPopup');local unloadedHeight=loadedPopup.Size[2]
	assert(#completions==1 and completions[1].Source=='rbxassetid://1','Picker shares the permitted native image metadata host')
	completions[1].Finish(true,{Width=64,Height=16})
	assert(resourceViews[1].ImageItems[1].IntrinsicWidth==64 and loadedPopup.Size[2]<unloadedHeight and live('SelectPopup')==loadedPopup,'Image decode updates real row/popup geometry on retained surfaces')
	while #queue>0 do table.remove(queue,1)()end
	assert(preloads==2,'One font preload and one raster preload are scheduled; completion adds no idle or repeated work')
	-- selectedcontent contains a distinct snapshot with the same copied ID.
	-- Mutate the actual option resource, not that independent selected copy.
	local lateNode=resourceControl.Options[1].Node.Children[2];lateNode.Attributes.src='other';resourcePopup:Refresh()
	assert(#completions==2 and completions[2].Source=='rbxassetid://2','Retained source changes subscribe to the new image: '..#completions..'/'..tostring(completions[2]and completions[2].Source)..'/'..tostring(resourceViews[1].ImageItems[1]and resourceViews[1].ImageItems[1].Source))
	local resourceOption=resourceControl.Options[1].Node;local resourceGui=resourceViews[1].Gui
	resourceOption.Attributes.label='Fallback';resourcePopup:Refresh()
	assert(canceled[2]and #resourceViews[1].ImageItems==0 and resourceViews[1].Gui==resourceGui,'A label cancels the hidden image registration while retaining the option host')
	completions[2].Finish(true,{Width=200,Height=100});assert(#resourceViews[1].ImageItems==0,'A late suppressed image cannot restore its old surface')
	resourceOption.Attributes.label=nil;resourcePopup:Refresh()
	assert(#completions==3 and resourceViews[1].Gui==resourceGui,'Restoring rich children subscribes a fresh image on the same host')
	local oldView=resourceViews[1];resourcePopup:Close()
	assert(canceled[3]and oldView.Gui.Destroyed,'Closing releases pending metadata subscriptions and picker GUI')
	completions[3].Finish(true,{Width=200,Height=100});while #queue>0 do table.remove(queue,1)()end
	assert(not live('SelectPopup')and preloads==2,'Late image/font callbacks neither reopen a popup nor preload released surfaces')
	resourcePage.Alive=false
	-- A base dropdown's UA fallback renders only the selected option's label,
	-- alongside the real generated picker icon. It must not copy rich option
	-- children into author DOM, or lose its native host on appearance changes.
	local modesDoc=Parser.parseDocument([=[<!doctype html><style id="modeStyles">
		select::picker(select){appearance:base-select}select::picker-icon{content:"v";color:red;width:18px;height:20px}
		option b{color:blue}
	</style><form id="modeForm"><select id="modeSelect" style="appearance:base-select">
		<option value="a" label="Short"><b>Hidden styled content</b><img src="icon" width="28" height="30"></option>
		<option value="b">A considerably longer caption</option><option value="c">A considerably longer caption</option>
	</select></form><p id="modeOutside">Independent neighbor</p>]=])
	local modesTree=renderer.build(modesDoc,root,error,function(font)return font end,nil,nil,function()return 'rbxassetid://1'end)
	layout.arrange(modesTree,600,0,0,function()return true end)
	local modesPage={Alive=true,Document=modesDoc,Root=root,Cleanups={}};function modesPage:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	local modeRequests={};local stopModes=Controller.start(modesPage,modesTree,function(_,target)modeRequests[target]=true end,error,{Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return{}end},Factory=factory,Clock=function()return 0 end})
	local modesSelect=Node.findById(modesDoc,'modeSelect');local modesControl=modesPage.FormModel:Resolve(modesSelect)
	local modesBox=modesTree.NodeBoxes[modesSelect];local modesGui,modesItem,modesStyle=modesControl.Item.Gui,modesControl.Item,modesBox.Style
	local outsideGui=modesTree.NodeBoxes[Node.findById(modesDoc,'modeOutside')].Gui
	assert(modesBox.RichSelect and modesBox.SelectFallback and #modesSelect.Children>0 and #modesTree.ImageItems==0,'UA fallback is rich layout with no data-option images or inserted author children')
	assert(word(modesTree,'Short')and word(modesTree,'v').Style.Color==Color3.fromRGB(255,0,0)and not word(modesTree,'Hidden'),'Fallback caption and cascaded picker icon are actually painted')
	local shortWidth=modesBox.OuterWidth;modesPage:Focus(modesSelect)
	modesPage:SetValue('modeSelect','b');assert(word(modesTree,'considerably')and next(modeRequests),'Selecting a different fallback caption refreshes its actual words and schedules layout')
	layout.arrange(modesTree,600,0,0,function()return true end);assert(modesBox.OuterWidth>shortWidth,'Fallback width measures the selected label rather than all options')
	table.clear(modeRequests);local fallbackWord=word(modesTree,'considerably').Gui
	modesPage:SetValue('modeSelect','c');assert(not next(modeRequests)and word(modesTree,'considerably').Gui==fallbackWord,'Equal displayed captions change selection without recreating words or scheduling layout')
	modesTree.LayoutInProgress=true;modesPage:SetValue('modeSelect','a')
	assert(modesTree.PendingRichSelectChanges and not fallbackWord.Destroyed,'Fallback changes during layout keep the old visible words')
	modesTree.LayoutInProgress=false;local updated,needsLayout=modesTree:FlushCSSStates()
	assert(updated and needsLayout and word(modesTree,'Short'),'Deferred fallback publishes safely at the layout boundary: '..tostring(updated)..'/'..tostring(needsLayout)..'/'..tostring(modesControl.SelectedIndex)..'/'..tostring(modesBox.SelectCaption))
	local function mode(attribute,value)
		modesSelect.Attributes[attribute]=value
		modesTree:ApplyDOMChanges({[modesSelect]={Attributes={[attribute]=true}}})
		layout.arrange(modesTree,600,0,0,function()return true end)
		assert(modesControl.Item==modesItem and modesItem.Gui==modesGui and modesTree.NodeStyles[modesSelect]==modesStyle and not modesGui.Destroyed and modesControl.Focused,'Appearance/mode changes preserve select, style, surface and focus')
		assert(modesTree.NodeBoxes[Node.findById(modesDoc,'modeOutside')].Gui==outsideGui,'Mode changes preserve independent neighbors')
	end
	mode('style','appearance:auto');assert(not modesItem.RichSelect and modesItem.Label.Text=='Short'and modesItem.SelectArrowGui and modesBox.Kind=='BlockImage','Rich-to-native transition builds only the anonymous ordinary control view')
	local ordinaryCaption=modesItem.Label
	mode('style','appearance:base-select');assert(ordinaryCaption.Destroyed and modesItem.RichSelect and modesBox.Kind==nil and word(modesTree,'Short')and word(modesTree,'v'),'Returning to base releases native contents and restores actual fallback words and generated icon')
	mode('size','3');assert(modesItem.RichSelect and modesTree.NodeBoxes[modesSelect].RichSelectList and modesTree.NodeBoxes[modesSelect].ScrollGui and not word(modesTree,'v'),'A base dropdown becoming a rich list no longer paints its picker icon')
	mode('size',nil);assert(modesItem.RichSelect and word(modesTree,'v'),'Removing size restores the dropdown on the same focused surface')
	-- The first authored button replaces only fallback participation.
	local authored=Node.element('button',{});local mirror=Node.element('selectedcontent',{});Node.append(authored,mirror)
	local bold=Node.element('b',{});Node.append(bold,Node.text('Own button'));Node.append(authored,bold);Node.insertBefore(modesSelect,authored,modesSelect.Children[1])
	modesTree:ApplyDOMChanges({[modesSelect]={Children=true}});layout.arrange(modesTree,600,0,0,function()return true end)
	assert(not modesBox.SelectFallback and word(modesTree,'Own')and not word(modesTree,'Short'),'An inserted first button participates without replacing the select surface')
	Node.removeChild(modesSelect,authored);modesTree:ApplyDOMChanges({[modesSelect]={Children=true}})
	assert(modesBox.SelectFallback and word(modesTree,'Short')and modesItem.Gui==modesGui,'Removing the first button restores the UA caption on the same surface')
	modesControl.Options[1].Node.Attributes.label='Changed caption';modesTree:ApplyDOMChanges({[modesControl.Options[1].Node]={Attributes={label=true}}})
	assert(word(modesTree,'Changed')and not word(modesTree,'Short'),'Current option metadata refreshes the visible fallback, not only the data record')
	modesPage:SetValue('modeSelect','b');modesPage:Reset('modeForm')
	assert(modesControl.SelectedIndex==1 and word(modesTree,'Changed'),'Native reset republishes the default fallback label')
	modesPage:SetValue('modeSelect','missing');assert(modesControl.SelectedIndex==0 and not word(modesTree,'Changed')and word(modesTree,'v'),'No selected option clears only the anonymous caption, retaining its picker icon')
	modesSelect.Attributes.style='appearance:base-select;color:green';modesTree:ApplyDOMChanges({[modesSelect]={Attributes={style=true}}})
	assert(modesControl.SelectedIndex==0 and not word(modesTree,'Changed'),'Paint-only changes preserve an explicitly empty selectedness state')
	mode('style','appearance:auto')
	local oldAnchor=modesItem.BoxGui;oldAnchor.AbsolutePosition=Vector2.new(20,40);oldAnchor.AbsoluteSize=Vector2.new(180,26)
	local modeFragments=require('Rendering/PickerFragments').new(modesPage,modesTree,error,{PickerLayout=layout})
	local modesPopup=Popup.new(modesPage,function()end,factory,nil,modeFragments);modesPopup:Open(modesControl)
	local retainedPopup=live('SelectPopup');assert(retainedPopup and oldAnchor:GetPropertyChangedSignal('AbsolutePosition'):Count()==1,'An ordinary picker watches its actual native anchor')
	mode('style','appearance:base-select');local baseAnchor=modesItem.BoxGui;baseAnchor.AbsolutePosition=Vector2.new(20,40);baseAnchor.AbsoluteSize=Vector2.new(180,26);modesPopup:Refresh()
	assert(modesPopup.Control==modesControl and not retainedPopup.Destroyed and oldAnchor:GetPropertyChangedSignal('AbsolutePosition'):Count()==0 and baseAnchor:GetPropertyChangedSignal('AbsolutePosition'):Count()==1,'Open appearance changes retain the popup and move its subscriptions to the current base surface')
	oldAnchor:GetPropertyChangedSignal('AbsolutePosition'):Fire();assert(modesPopup.Control==modesControl,'A retired native face cannot close the current picker')
	local keptPicker=modesPopup.PickerView.Tree.Gui
	baseAnchor:GetPropertyChangedSignal('AbsolutePosition'):Fire();assert(modesPopup.Control==modesControl and modesPopup.PickerView.Tree.Gui==keptPicker and baseAnchor:GetPropertyChangedSignal('AbsolutePosition'):Count()==1,'The current base anchor refreshes its retained picker when it moves')
	modesPopup:Close();assert(baseAnchor:GetPropertyChangedSignal('AbsolutePosition'):Count()==0 and keptPicker.Destroyed,'Explicit close releases the active anchor subscription and custom tree')
	modesPage.Alive=false;stopModes()
	-- Promoting an ordinary block select releases its retired layout wrapper,
	-- including opacity surfaces, while preserving the actual focused GUI.
	local blockDoc=Parser.parseDocument('<!doctype html><select id="block" style="display:block;opacity:.5;width:160px"><option value="a">A</option><option value="b">B</option></select>')
	local blockTree=renderer.build(blockDoc,root,error,function(font)return font end);layout.arrange(blockTree,600,0,0,function()return true end)
	local blockSelect=Node.findById(blockDoc,'block');local blockControl=blockTree.Controls[1];local blockItem=blockControl.Item;local blockGui=blockItem.Gui
	local blockWrapper=blockTree.NodeBoxes[blockSelect];local retiredWrapper=if blockWrapper.OpacityGroup then blockWrapper.OpacityGroup.Gui else blockWrapper.Gui
	local blockModel=FormModel.new(blockDoc,blockTree.Controls,Events.new(error),function()end,true);blockModel:SetValue(blockControl,'b');blockControl.Focused=true
	blockSelect.Attributes.style='display:block;opacity:.5;width:160px;appearance:base-select'
	blockTree:ApplyDOMChanges({[blockSelect]={Attributes={style=true}}});layout.arrange(blockTree,600,0,0,function()return true end)
	assert(retiredWrapper.Destroyed and blockControl.Item==blockItem and blockItem.Gui==blockGui and not blockGui.Destroyed and blockControl.Value=='b'and blockControl.Focused,'Ordinary block promotion frees its old wrapper and preserves surface, value, record and focus')
	assert(word(blockTree,'B')and blockTree.NodeBoxes[blockSelect].RichSelect,'Promoted block paints the currently selected fallback')
	blockModel:Destroy()
	-- Base listboxes participate in the actual page layout, rather than an
	-- anonymous native TextLabel list. Rich descendants remain author nodes.
	local listDoc=Parser.parseDocument([=[<!doctype html><style>
		select{appearance:base-select;width:240px;height:76px;font-size:16px;line-height:24px}
		option b{color:red}legend i{color:blue}option::checkmark{content:"!";width:10px}
	</style><form id="listForm"><select id="richList" multiple size="3"><button>Hidden button</button>
		<optgroup id="richGroup" label="Fallback group"><legend id="richLegend"><i>Rich group</i></legend>
		<option id="richA" value="a" selected><b>Alpha</b><img id="listImage" src="icon" width="18" height="30"></option>
		<option id="richB" value="b"><i>Beta</i></option><option id="richDisabled" disabled value="disabled">Skip</option>
		<option id="richC" value="c">Gamma</option></optgroup></select></form><p id="listOutside">Stable neighbor</p>]=])
	local listTree=renderer.build(listDoc,root,error,function(font)return font end,nil,nil,function()return 'rbxassetid://1'end)
	layout.arrange(listTree,600,0,0,function()return true end)
	local listSelect=Node.findById(listDoc,'richList');local listBox=listTree.NodeBoxes[listSelect];local listSurface=listBox.Gui
	local listA,listB,listC=Node.findById(listDoc,'richA'),Node.findById(listDoc,'richB'),Node.findById(listDoc,'richC')
	local listOutside=listTree.NodeBoxes[Node.findById(listDoc,'listOutside')].Gui
	assert(listBox.RichSelectList and listBox.ScrollGui and listBox.OuterHeight==76 and not word(listTree,'Hidden'),'Base list uses authored height, normal scrolling and excludes its first button')
	assert(word(listTree,'Alpha').Gui.TextColor3==Color3.fromRGB(255,0,0)and word(listTree,'Rich').Gui.TextColor3==Color3.fromRGB(0,0,255),'Rich option and legend formatting reaches actual word paint')
	assert(listTree.NodeBoxes[Node.findById(listDoc,'listImage')].ImageItem.BoxHeight==30 and listTree.NodeBoxes[listA].OuterHeight>=30,'Option rows include actual image geometry')
	assert(listTree.NodeBoxes[listB].LayoutY>listTree.NodeBoxes[listA].LayoutY and listTree.NodeBoxes[listC].LayoutY>listTree.NodeBoxes[listB].LayoutY,'Rich list rows participate in normal retained block ordering')
	local hits={};local listInput={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function listInput:GetFocusedTextBox()return nil end;function listInput:IsKeyDown()return false end;function listInput:GetStringForKeyCode()return ''end
	local listPage={Alive=true,Document=listDoc,Root=root,Cleanups={}};function listPage:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	local listRequests={};local stopList=Controller.start(listPage,listTree,function(_,target)listRequests[target]=true end,error,{Input=listInput,Factory=factory,Clock=function()return 0 end,PlayerGui={GetGuiObjectsAtPosition=function()return hits end}})
	local listControl=listPage.FormModel:Resolve(listSelect);listPage:Focus(listSelect)
	local alphaWord=word(listTree,'Alpha').Gui;local betaWord=word(listTree,'Beta').Gui
	hits={betaWord};local mouse={UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(15,15)}
	listInput.InputBegan:Fire(mouse,false);listInput.InputEnded:Fire(mouse,false)
	assert(listControl.Value=='b'and listControl.SelectedIndex==2,'Clicking a formatted option descendant uses its actual option row')
	listInput.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Down},false)
	assert(listControl.Value=='c'and listControl.SelectedIndex==4 and listBox.ScrollGui.CanvasPosition.Y>0,'Keyboard selection skips disabled rows and reveals the actual variable-height row: '..tostring(listControl.Value)..'/'..tostring(listControl.SelectedIndex)..'/'..tostring(listBox.ScrollGui.CanvasPosition.Y)..'/'..tostring(listTree.NodeBoxes[listC].LayoutParent==listBox)..'/'..tostring(listBox.ScrollGui.CanvasSize[2]))
	assert(listSurface==listControl.Item.Gui and alphaWord==word(listTree,'Alpha').Gui and betaWord==word(listTree,'Beta').Gui and listTree.NodeBoxes[Node.findById(listDoc,'listOutside')].Gui==listOutside and not next(listRequests),'Selection changes retained paint without page layout or new words')
	listPage:Reset('listForm');assert(listControl.Value=='a'and listControl.SelectedIndex==1,'Rich list resets through the shared native form model')
	listA.Attributes.label='Label only';listTree:ApplyDOMChanges({[listA]={Attributes={label=true}}});layout.arrange(listTree,600,0,0,function()return true end)
	assert(word(listTree,'Label')and not word(listTree,'Alpha')and #listTree.ImageItems==0,'An option label suppresses rich descendants and their rendered resources')
	listA.Attributes.label=nil;listTree:ApplyDOMChanges({[listA]={Attributes={label=true}}});layout.arrange(listTree,600,0,0,function()return true end)
	assert(word(listTree,'Alpha')and #listTree.ImageItems==1,'Removing label restores rich contents through the same page resource path')
	local group=Node.findById(listDoc,'richGroup');local legend=Node.findById(listDoc,'richLegend');Node.removeChild(group,legend)
	listTree:ApplyDOMChanges({[group]={Children=true}});layout.arrange(listTree,600,0,0,function()return true end)
	assert(word(listTree,'Fallback')and not word(listTree,'Rich')and #group.Children==7,'Missing first legend uses an anonymous group label without author DOM insertion')
	local richScroll=listBox.ScrollGui
	listSelect.Attributes.style='appearance:auto';listTree:ApplyDOMChanges({[listSelect]={Attributes={style=true}}});layout.arrange(listTree,600,0,0,function()return true end)
	assert(not listControl.Item.RichSelect and listControl.Item.SelectScroll and richScroll.Visible==false and #listTree.ImageItems==0,'Native list mode retires rich descendants and hides its owned generic scroll surface')
	listSelect.Attributes.style='appearance:base-select';listTree:ApplyDOMChanges({[listSelect]={Attributes={style=true}}});layout.arrange(listTree,600,0,0,function()return true end)
	assert(listControl.Item.RichSelect and listBox.RichSelectList and listBox.ScrollGui==richScroll and richScroll.Visible and #listTree.ImageItems==1 and listControl.Item.Gui==listSurface,'Returning to a base list reuses select and scroll surfaces and restores its rich resources')
	listPage.Alive=false;stopList()
	print('Rich select: actual DOM/JS/retained render paths, inherited UA defaults, bold/colored text, image layout, snapshot changes, bounded flushes and cleanup passed')
end
