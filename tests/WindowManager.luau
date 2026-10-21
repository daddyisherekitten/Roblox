--!strict
return function(load,fixture,loadHost,loadBrowser,loadBinding,loadDemo)
	do
		local browserFixture,loadWindowManager=fixture,load

local f=browserFixture();f.DeferTweens=true
local Snap=loadWindowManager(f,'Windows/Snap')
local holder=f.Create('Frame',f.Screen,{Size=f.UDim2.fromScale(1,1)})
local layers={get=function()return holder end};local origin=f.Vector2.zero;local area=f.Vector2.new(900,600)
local service=f.Game:GetService('TweenService');local create=service.Create;local created={}
service.Create=function(self,object,info,goals)local tween=create(self,object,info,goals);table.insert(created,{Object=object,Tween=tween,Goals=goals});return tween end
Snap.showPreview(layers,'left',origin,area,4);f:Drain()
local frame=holder:FindFirstChild('SnapPreview');assert(frame.Visible and Snap.previewZone(layers)=='left')
table.clear(created);Snap.hidePreview(layers);assert(#created==2 and frame.Visible)
local firstFade=created[2].Tween;local firstCallbacks=firstFade.Completed:Snapshot()
for _=1,24 do Snap.hidePreview(layers)end
local repeatedFadeTweens=#created-2
f:StepTweens(.5);assert(frame.Visible,'A visible hide must remain until fade completion')
f:Drain();assert(not frame.Visible and not Snap.previewZone(layers))
table.clear(created);for _=1,24 do Snap.hidePreview(layers)end
local hiddenTweens=#created;f:Drain()
print('SNAP OPERATIONS RunningHideCalls=24 RestartTweens='..repeatedFadeTweens..' SettledHiddenCalls=24 NativeTweens='..hiddenTweens)
Snap.showPreview(layers,'left',origin,area,4);f:StepTweens(.5);Snap.hidePreview(layers)
local old=created[#created].Tween.Completed:Snapshot();local oldCompletion=old[#old]
Snap.showPreview(layers,'right',origin,area,7);assert(frame.Visible and frame.ZIndex==7 and Snap.previewZone(layers)=='right')
Snap.hidePreview(layers);local latest=created[#created].Tween
oldCompletion('Completed')
local staleVisible=frame.Visible;local latestListeners=latest.Completed:Count()
f:Drain();assert(not frame.Visible)
Snap.showPreview(layers,'topRight',origin,area,8);f:Drain();assert(frame.Visible and Snap.previewZone(layers)=='topRight')
local otherHolder=f.Create('Frame',f.Screen,{Size=f.UDim2.fromScale(1,1)});local other={get=function()return otherHolder end}
Snap.showPreview(other,'right',origin,area,2);f:Drain();Snap.hidePreview(layers)
local pending=created[#created].Tween
Snap.destroyPreview(layers);assert(frame.Destroyed and pending.Cancelled and otherHolder:FindFirstChild('SnapPreview').Visible)
Snap.destroyPreview(layers);Snap.destroyPreview(other);f:Drain();assert(f:GlobalConnections()==0)
print('SNAP REVERSE StaleCompletionKeptVisible='..tostring(staleVisible)..' LatestCompletionListeners='..latestListeners..' PerManagerAndDestroy=true')
assert(repeatedFadeTweens==0 and hiddenTweens==0,'Repeated hides must preserve an existing fade and allocate no native tweens')
assert(staleVisible and latestListeners==2,'Stale hide completion must not retire a newer reversed hide')
print('PASS Snap follow-up candidate')

	end
	do
		local browserFixture,loadWindowManager=fixture,load

local f=browserFixture();local Interactive=loadWindowManager(f,'UI/Interactive')
local function owner()
 local entries={};local cleanup={items={}}
 function cleanup:add(callback)table.insert(self.items,callback)end
 function cleanup:clean()for index=#self.items,1,-1 do self.items[index]()end;table.clear(self.items)end
 local router={}
 function router:register(frame,handlers,lifetime)
  entries[frame]=handlers
  local function remove()entries[frame]=nil end;lifetime:add(remove);return remove
 end
 return router,cleanup,entries
end
local a=f.Create('Frame',f.Screen,{BackgroundTransparency=1});local b=f.Create('Frame',f.Screen,{BackgroundTransparency=1})
local spec={instance=a,prop='BackgroundTransparency',idle=1,hover=.4,press=.1}
local router,cleanup,entries=owner();local other,otherCleanup,otherEntries=owner()
local documentedOK,documentedError=pcall(Interactive.paint,a,spec,cleanup)
print('INTERACTIVE ORIGINAL ThreeArgumentSucceeded='..tostring(documentedOK)..' MissingOwner='..tostring(not documentedOK and string.find(tostring(documentedError),'opts.input fehlt',1,true)~=nil))
assert(not documentedOK,'The helper must not guess a global router owner')
cleanup:clean()
router,cleanup,entries=owner()
local ok,remove=pcall(Interactive.paint,a,spec,cleanup,router)
print('INTERACTIVE EXPLICIT OwnerSuppliedSucceeded='..tostring(ok))
assert(ok and type(remove)=='function','Explicit owner must make the paint shorthand usable')
local handlers=entries[a];assert(handlers and not otherEntries[a] and a.BackgroundTransparency==1)
handlers.onEnter();assert(math.abs(a.BackgroundTransparency-.4)<1e-6)
handlers.onDown(1);assert(math.abs(a.BackgroundTransparency-.1)<1e-6)
handlers.onLeave();assert(a.BackgroundTransparency==1)
handlers.onEnter();handlers.onUp(1);assert(math.abs(a.BackgroundTransparency-.4)<1e-6)
local secondSpec={instance=b,prop='BackgroundTransparency',idle=1,hover=.2,press=0}
Interactive.paint(b,secondSpec,otherCleanup,other);assert(otherEntries[b] and not entries[b])
remove();assert(not entries[a] and otherEntries[b]);cleanup:clean();otherCleanup:clean();f:Drain()
assert(not otherEntries[b] and f:GlobalConnections()==0)
print('PASS Interactive paint ownership and cleanup')

	end
	local f=fixture();local API=load(f);local manager=API.new(f.Screen,{Animations=false,Services={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,Clock=function()return f:Clock()end}})
	local a=manager:Open({Title='A',Size=f.Vector2.new(500,350),Position=f.Vector2.new(50,60)})
	local b=manager:Open({Title='B'});assert(manager:GetFocused()==b and #manager:GetWindows()==2)
	do
		local core=manager.Core;local reorder=core._reorder;local reordered=0;local changed=0
		core._reorder=function(self,...)reordered+=1;return reorder(self,...)end
		local connection=manager.FocusChanged:Connect(function()changed+=1 end)
		for _=1,24 do manager:Focus(b)end
		assert(reordered==0 and changed==0,'Refocusing the already frontmost window must not reorder families or emit focus changes')
		manager:Focus(a);assert(reordered==1 and changed==1 and a.Root.ZIndex>b.Root.ZIndex,'Changing focus still reorders actual windows')
		manager:Focus(b);assert(reordered==2 and changed==2 and b.Root.ZIndex>a.Root.ZIndex)
		connection:Disconnect();core._reorder=reorder
		print('WindowManager operations: 24 repeated frontmost focus calls = 0 family reorders; two actual switches = 2')
	end
	manager:Focus(a);assert(a.Root.ZIndex>b.Root.ZIndex and manager:GetWindows()[1]==a,'Focus must not reorder opening order')
	local child=f.Create('Frame',b.Content);f:Click(child);assert(manager:GetFocused()==b,'Content clicks focus the actual hit window')
	local foreign=f.Create('Frame',f.Screen);f:Hits(foreign,a.CloseButton);f.Input.InputBegan:Fire(f:Event(f.Enum.UserInputType.MouseButton1));assert(a.Alive,'Foreign UI must occlude native windows')
	local held=f:Begin(a.Titlebar,nil,100,90);f:Hits(a.Titlebar)
	f.Input.InputChanged:Fire(f:Event(f.Enum.UserInputType.MouseMovement,150,110))
	assert(a:GetPosition().X==100 and a:GetPosition().Y==80 and a.Root:GetAttribute('HTMLViewportResizing'))
	f.Input.InputEnded:Fire(held);assert(not a.Root:GetAttribute('HTMLViewportResizing'))
	local grip=a.Root:FindFirstChild('Grip_NW');held=f:Begin(grip,nil,100,80)
	f.Input.InputChanged:Fire(f:Event(f.Enum.UserInputType.MouseMovement,1000,1000))
	assert(a:GetSize().X==320 and a:GetSize().Y==220 and a:GetPosition().X==280 and a:GetPosition().Y==210,'Left/top resize retains opposite edges at minimum')
	f.Input.WindowFocusReleased:Fire();assert(not manager.Input.Pressed and not a.Root:GetAttribute('HTMLViewportResizing'))
	local p,s=a:GetPosition(),a:GetSize();f:Click(a.MaximizeButton);assert(a.State=='maximized'and a:GetSize().X==900)
	f:Click(a.MaximizeButton);assert(a.State=='normal'and a:GetPosition().X==p.X and a:GetSize().X==s.X)
	a:Snap('left');assert(a.State=='snapped'and a:GetSize().X==450);a:Restore()
	local touch=f:Begin(a.Root:FindFirstChild('Grip_SE'),f.Enum.UserInputType.Touch,600,400)
	f.Input.InputEnded:Fire(f:Event(f.Enum.UserInputType.Touch,600,400));assert(manager.Input.Pressed,'Unrelated touches cannot release the gesture')
	touch.Position=f.Vector2.new(620,410);f.Input.InputChanged:Fire(touch);assert(a:GetSize().X==s.X+20)
	f.Input.InputEnded:Fire(touch);assert(not manager.Input.Pressed)
	f:Click(a.Titlebar);f:Click(a.Titlebar);assert(a.State=='maximized','Double title click should maximize');a:Restore()
	f:Click(a.MinimizeButton);assert(a.State=='minimized'and not a.Root.Visible and a.Dock.Visible and manager:GetFocused()==b)
	f:Click(a.Dock);assert(a.State=='normal'and a.Root.Visible and manager:GetFocused()==a)
	b:Maximize();b:Minimize();b:Restore();assert(b.State=='maximized','Minimizing must retain the maximized restore state')
	local fixed=manager:Open({Resizable=false,Minimizable=false});assert(not fixed.Root:FindFirstChild('Grip_SE')and not fixed:Maximize()and not fixed:Minimize());fixed:Close()
	f.Screen.AbsoluteSize=f.Vector2.new(250,150);assert(b:GetSize().X==250 and b:GetSize().Y==150 and not manager.Input.Pressed)
	local closeCount=0;a:OnClose(function()closeCount+=1 end)
	f:Click(a.CloseButton);assert(not a.Alive and closeCount==1 and #manager:GetWindows()==1)
	a:Close();assert(closeCount==1)
	for _,object in manager.Root:GetDescendants()do if object:IsA('GuiObject')and object~=child then assert(object.Active==false and object.Selectable==false,'Native windows must use manual input')end end
	b.Root:Destroy();assert(not b.Alive and not manager:GetFocused()and #manager:GetWindows()==0,'External native destruction must release model ownership')
	local pos,size=API.Geometry.rectFor('right',f.Vector2.new(901,601));assert(pos.X==450 and size.X==451)
	f.Screen.AbsoluteSize=f.Vector2.new(900,600)
	local owner=manager:Open({Title='Owner'})
	assert(owner.Native._shadow and owner.Native._shadow.Enabled,'Imported windows must create their native shadow')
	local answers={}
	local dialog=manager:MessageBox({Title='Question',Message='Save changes?',Icon='question',Buttons='YesNoCancel',Sound=false,Owner=owner,
		OnResult=function(name)table.insert(answers,name)end})
	assert(manager:ModalDepth()==1 and not owner:IsInputEnabled()and manager:GetFocused()==dialog)
	assert(owner.Native:looksActive()and not dialog.MinimizeButton and not dialog.MaximizeButton,'Owned dialogs retain active owner chrome and hide minimize/maximize')
	f:Click(owner.CloseButton);assert(owner.Alive and dialog.Alive,'A blocked owner cannot receive close clicks')
	f.Input.InputBegan:Fire(f:Event(f.Enum.UserInputType.Keyboard,0,0,f.Enum.KeyCode.Right))
	f.Input.InputBegan:Fire(f:Event(f.Enum.UserInputType.Keyboard,0,0,f.Enum.KeyCode.Return))
	f:Drain();assert(not dialog.Alive and owner:IsInputEnabled()and manager:ModalDepth()==0 and #answers==1 and answers[1]=='No')
	dialog:Close();f:Drain();assert(#answers==1,'Dialog result must be reported exactly once')
	local global=manager:ShowError('A global error',{Owner=false,Sound=false})
	assert(manager:ModalDepth()==1 and not manager:CanReceivePointer(owner,f.Vector2.new(1,1)))
	local nested=manager:MessageBox({Title='Nested',Message='Another question',Icon='question',Owner=global,Sound=false})
	assert(manager:ModalDepth()==2 and not owner:IsInputEnabled()and not manager:Focus(owner),'A nested owner dialog must retain the application modal boundary')
	nested:Close();f:Drain();assert(manager:ModalDepth()==1 and manager:GetFocused()==global)
	f:Click(global.CloseButton);f:Drain();assert(manager:ModalDepth()==0)
	local owned=manager:Open({Title='Owned',Owner=owner})
	manager:Focus(owner);assert(owned.Root.ZIndex>owner.Root.ZIndex,'Owned windows remain above their owner')
	do
		local order=manager.Core._windows
		-- Exercise the non-tail case as well: the same focused owner may have
		-- newer family members in the ordering without losing its focus flag.
		local at=table.find(order,owner.Native);table.remove(order,at);table.insert(order,1,owner.Native)
		manager:Focus(owner)
		assert(order[#order]==owner.Native and owned.Root.ZIndex>owner.Root.ZIndex,'Same focused owner behind another window still repairs family order')
	end
	owner:Close();assert(not owned.Alive and #manager:GetWindows()==0,'Owned windows close with their owner')
	local audible=manager:ShowError('Audible error',{Owner=false})
	local sound=manager.Core._dialogSounds['rbxassetid://135623551518267'];assert(sound and sound.Played)
	audible:Close();f:Drain()
	local animated=API.new(f.Screen,{Services={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,Task=f.Task}})
	local moving=animated:Open({Title='Animated'})
	assert(moving.Root:GetAttribute('HTMLViewportResizing'),'Opening animation defers content layout')
	f:Drain();assert(not moving.Root:GetAttribute('HTMLViewportResizing'))
	moving:Close();assert(not moving.Alive and not moving.Native.cleanup:isCleaned())
	animated:Destroy();f:Drain();assert(moving.Native.cleanup:isCleaned(),'Destroy during a closing animation releases its pending resources')
	manager:Destroy();manager:Destroy();assert(f:GlobalConnections()==0)
	assert(sound.Destroyed,'Dialog sounds belong to their manager')
	local connected=API.new(f.Screen,{Animations=false,Services={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui}})
	local engine={Websites={names=function()return{}end,url=function()return'http://localhost:8000/comparison/index.html'end}}
	local services={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,Task=f.Task,RunService=f.Run,Clock=function()return f:Clock()end}
	local host=loadHost(f).new(connected,loadBrowser(f),loadBinding(f),engine,{Services=services,PersistenceEnabled=false,Pages={loadDemo(f)(connected)}})
	local record=host:Open('wayline://windows');f:Drain()
	assert(record.Browser:GetActiveTab().Title=='Windows and dialogs','The native comparison page must mount inside the connected browser')
	local browser=record.Browser;local first=browser:GetActiveTab()
	assert(browser.View.TabStrip==nil and browser.OpenTab==nil and browser.MoveTab==nil and browser.ReopenTab==nil,'Browser has no tab surface or tab creation/reordering API')
	local same=browser:Open('wayline://windows');f:Drain()
	assert(same==first and #browser:GetTabs()==1 and record.Window.Alive,'Host Open keeps one document context in the existing window')
	local icon=browser.View.Reload.Icon;local artwork=icon:FindFirstChild('Artwork')
	assert(artwork.Image=='rbxassetid://72168208218331','Browser icons must use the replacement atlas')
	assert(artwork.Visible and #icon:GetChildren()==1 and icon:GetAttribute('IconRenderMode')=='image','Pending browser icons must contain only the image artwork')
	local loadSignal=artwork:GetPropertyChangedSignal('IsLoaded');assert(loadSignal:Count()==0,'Browser icons must not wait on a load-time glyph swap')
	artwork.IsLoaded=true
	assert(artwork.Visible and #icon:GetChildren()==1 and loadSignal:Count()==0,'Loading changes must preserve the image-only icon')
	browser.View:Menu()
	for _,object in browser.Overlays.Current.Panel:GetDescendants()do if object:IsA('TextLabel')then assert(object.Text~='Wayline guide','The browser menu must not include the guide entry')end end
	browser.Overlays:Dismiss();f:Drain()
	local dialogKeys=f.Input.InputBegan:Count();local dialogResults={}
	local dismissPrompt=browser.Overlays:ScriptDialog({Kind='prompt',Message='Your name?',DefaultValue='Initial',Origin='http://localhost:8000'},function(ok,value)table.insert(dialogResults,{OK=ok,Value=value})end)
	local promptPanel=browser.Overlays.Current.Panel
	assert(browser.Input.Modal and promptPanel:FindFirstChild('DialogValue').Text=='Initial','Script prompts use a modal browser-owned text field')
	promptPanel:FindFirstChild('DialogValue').Text='Edited'
	f.Input.InputBegan:Fire(f:Event(f.Enum.UserInputType.Keyboard,0,0,f.Enum.KeyCode.Return));f:Drain()
	assert(#dialogResults==1 and dialogResults[1].OK and dialogResults[1].Value=='Edited'and not browser.Input.Modal and f.Input.InputBegan:Count()==dialogKeys,'Prompt Enter resolves the edited value once and releases modal listeners')
	dismissPrompt();f:Drain();assert(#dialogResults==1)
	browser.Overlays:ScriptDialog({Kind='confirm',Message='Continue?'},function(ok)table.insert(dialogResults,{OK=ok})end)
	f.Input.InputBegan:Fire(f:Event(f.Enum.UserInputType.Keyboard,0,0,f.Enum.KeyCode.Escape));f:Drain()
	assert(#dialogResults==2 and dialogResults[2].OK==false,'Escape rejects a script confirmation')
	browser.Overlays:ScriptDialog({Kind='alert',Message='Information'},function(ok)table.insert(dialogResults,{OK=ok})end)
	assert(not browser.Overlays.Current.Panel:FindFirstChild('DialogCancel'),'Alerts show only the acknowledgement button')
	browser:SetVisible(false);f:Drain();assert(#dialogResults==3 and dialogResults[3].OK==false and not browser.Overlays.Current,'Hiding the browser cancels an outstanding script dialog')
	browser:SetVisible(true);f:Drain()
	local editor=f.Create('TextBox',browser:GetActiveTab().Content,{Text='Native editor',Size=f.UDim2.fromOffset(180,24),CursorPosition=5,SelectionStart=2})
	editor:CaptureFocus();browser.Input.Focus=nil
	browser.Overlays:ScriptDialog({Kind='alert',Message='Keep the editor'},function()end)
	assert(not editor:IsFocused())
	f.Input.InputBegan:Fire(f:Event(f.Enum.UserInputType.Keyboard,0,0,f.Enum.KeyCode.Return));f:Drain()
	assert(editor:IsFocused()and editor.CursorPosition==5 and editor.SelectionStart==2,'Dialog dismissal must restore an HTML/native editor and its selection even when Browser.Input did not own its focus')
	editor:ReleaseFocus(false);editor:Destroy();browser.Input.Focus=nil
	local textService=f.Game:GetService('TextService');local measure=textService.GetTextSize
	local failedResults=0;textService.GetTextSize=function()error('measurement failed')end
	local constructed=pcall(function()browser.Overlays:ScriptDialog({Kind='confirm',Message='Unavailable measurement'},function(ok)assert(not ok);failedResults+=1 end)end)
	textService.GetTextSize=measure;f:Drain()
	assert(not constructed and failedResults==1 and not browser.Overlays.Current and not browser.Input.Modal and f.Input.InputBegan:Count()==dialogKeys,'Failed native dialog construction must remove its modal shield, fields and listeners')
	textService.GetTextSize=function(...)
		browser.Overlays:Dismiss();return measure(...)
	end
	browser.Overlays:ScriptDialog({Kind='confirm',Message='Dismiss during measurement'},function(ok)assert(not ok);failedResults+=1 end)
	textService.GetTextSize=measure;f:Drain()
	assert(failedResults==2 and not browser.Overlays.Current and not browser.Input.Modal and f.Input.InputBegan:Count()==dialogKeys,'A reentrant dismissal during measurement must not install retired keyboard listeners')
	-- Cursor artwork is shared by value, never through an HTML module import.
	browser.Input:Cancel();f.Input.MouseIcon='prior-cursor';f.Input.MouseIconEnabled=true
	local function mouseOver(object)
		local point=object.AbsolutePosition+f.Vector2.new(10,10);f:Hits(object)
		f.Input.Mouse=point
		f.Input.InputChanged:Fire(f:Event(f.Enum.UserInputType.MouseMovement,point.X,point.Y))
	end
	for _,button in {browser.View.MenuButton,browser.View.Star,browser.View.Reload,browser.View.Back,browser.View.Forward}do
		mouseOver(button.Root);assert(f.Input.MouseIcon=='rbxassetid://100262753082865','Toolbar controls use the normal arrow')
	end
	mouseOver(browser.View.Back.Root);assert(f.Input.MouseIcon=='rbxassetid://100262753082865','Disabled controls use the default arrow')
	mouseOver(browser.View.URL);assert(f.Input.MouseIcon=='rbxassetid://124712621961653','Browser text fields use the HTML text cursor artwork')
	mouseOver(browser.View.Chrome);assert(f.Input.MouseIcon=='rbxassetid://100262753082865','Browser surfaces use the HTML arrow artwork')
	local htmlArea=f.Create('Frame',browser:GetActiveTab().Content,{Size=f.UDim2.fromScale(1,1)})
	mouseOver(htmlArea);assert(f.Input.MouseIcon=='prior-cursor','HTML content must regain cursor ownership from the browser')
	mouseOver(browser.View.MenuButton.Root);f.Input.MouseIcon='foreign-cursor';mouseOver(htmlArea)
	assert(f.Input.MouseIcon=='foreign-cursor','Releasing the browser cursor must preserve another owner\'s changes')
	mouseOver(browser.View.MenuButton.Root);f.Input.WindowFocusReleased:Fire();f:Drain()
	assert(f.Input.MouseIcon=='foreign-cursor','Focus loss must release the cursor, including queued updates')
	f.Input.WindowFocused:Fire();f:Drain();assert(f.Input.MouseIcon=='rbxassetid://100262753082865')
	browser:SetVisible(false);assert(f.Input.MouseIcon=='foreign-cursor');browser:SetVisible(true);f:Drain()
	local point=browser.View.MenuButton.Root.AbsolutePosition+f.Vector2.new(10,10)
	local touchCursor=f:Begin(browser.View.MenuButton.Root,f.Enum.UserInputType.Touch,point.X,point.Y);f:Drain()
	assert(f.Input.MouseIcon=='foreign-cursor','Touch must not retain a custom mouse cursor')
	browser.Input:Cancel();f.Input.InputEnded:Fire(touchCursor);htmlArea:Destroy()
	local warning=connected:MessageBox({Owner=record.Window,Icon='warning',Message='Connected modal',Sound=false})
	assert(not record.Browser.Focused and not record.Window:IsInputEnabled(),'Native modal focus blocks the owning browser')
	warning:Close();f:Drain();assert(record.Browser.Focused and record.Window:IsInputEnabled())
	local sibling=host:Open('wayline://windows');f:Drain()
	local compact=sibling.Browser
	sibling.Window:SetSize(f.Vector2.new(500,420));f:Drain()
	local current=compact:GetActiveTab()
	for _=1,20 do assert(compact:Open('wayline://windows')==current)end;f:Drain()
	assert(#compact:GetTabs()==1 and compact.View.TabStrip==nil,'Repeated loads in a small window never add tabs or an overflow strip')
	assert(compact.View.URL.AbsoluteSize.X>0 and compact.View.Bar.Visible,'Address field remains available in the compact window')
	record.Window:RequestClose();f:Drain()
	assert(not record.Window.Alive and not browser.Alive and sibling.Window.Alive and sibling.Browser.Alive and #connected:GetWindows()==1,'Closing one browser window preserves its sibling')
	sibling.Window:RequestClose();f:Drain()
	assert(not sibling.Window.Alive and not sibling.Browser.Alive and #connected:GetWindows()==0 and next(host.Windows)==nil,'Closing the final browser window releases its host record')
	host:Destroy();connected:Destroy();f:Drain();assert(f:GlobalConnections()==0)
	print('WindowManager: focus, mouse/touch, single-document browser windows, resize/snap, native shadows, modal results, owned windows and cleanup passed')
end
