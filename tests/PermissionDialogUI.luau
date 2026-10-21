--!nonstrict
-- Exercises the actual passive permission panels and their routed input.
return function(loadBrowser,loadFallbackWindows,fixture)
	local assertions=0
	local function check(value,message)assertions+=1;assert(value,message)end
	local request={Kind='permission',Title='Gerätezugriff',Origin='http://localhost:8000',Names={'camera','microphone'},Message='Für diese Seite freigeben.'}
	local function find(root,name)for _,object in root:GetDescendants()do if object.Name==name then return object end end end
	local f=fixture();local host=f.Create('Frame',f.Screen,{Size=f.UDim2.fromScale(1,1)})
	local browser=loadBrowser(f).mount(host,{AutoOpen=false,PersistenceEnabled=false,Services={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,Task=f.Task}})
	browser:OpenTab();f:Drain()
	local function click(object)
		local p,s=object.AbsolutePosition,object.AbsoluteSize
		local event=f:Begin(object,nil,p.X+s.X/2,p.Y+s.Y/2);f.Input.InputEnded:Fire(event);f:Drain()
	end
	local results={}
	local function result(ok,value)table.insert(results,{OK=ok,Value=value})end
	local function show()
		local cancel=browser.Overlays:ScriptDialog(request,result);local current=browser.Overlays.Current
		check(current and browser.Input.Modal,'A browser permission request blocks page input through the existing modal scope')
		check(current.Anchor==browser.View.SiteInfo.Root,'Permission panel anchors at the real page-information control')
		check(current.Shield.BackgroundTransparency==1,'Permission bubble leaves the page visually undimmed')
		check(find(current.Panel,'DialogOrigin').Text==request.Origin,'Permission requests expose their requesting origin')
		local message=find(current.Panel,'Message').Text
		check(message:find('Kamera',1,true)and message:find('Mikrofon',1,true),'Camera and microphone are visibly named')
		check(find(current.Panel,'DialogAccept'):FindFirstChild('Label').Text=='Zulassen'and find(current.Panel,'DialogCancel'):FindFirstChild('Label').Text=='Blockieren','Permission actions use explicit allow/block wording')
		local anchor=browser.View.SiteInfo.Root
		check(current.Panel.AbsolutePosition.Y>=anchor.AbsolutePosition.Y+anchor.AbsoluteSize.Y,'Permission bubble appears below the address control')
		for _,object in current.Panel:GetDescendants()do if object:IsA('GuiObject')then check(object.Active==false and object.Selectable==false,'Permission controls stay passive')end end
		return current.Panel,cancel
	end
	local panel,cancel=show();click(find(panel,'DialogAccept'))
	check(#results==1 and results[1].OK==true and results[1].Value=='granted'and not browser.Overlays.Current,'Allow resolves a granted decision once')
	cancel();f:Drain();check(#results==1,'A stale cancellation cannot replace a completed allow')
	panel=show();click(find(panel,'DialogCancel'))
	check(#results==2 and results[2].OK==false and results[2].Value=='denied','Block resolves a denied decision')
	panel=show();click(find(panel,'DialogDismiss'))
	check(#results==3 and results[3].OK==false and results[3].Value==nil,'Close dismisses without recording a block')
	show();f.Input.InputBegan:Fire(f:Event(f.Enum.UserInputType.Keyboard,0,0,f.Enum.KeyCode.Escape));f:Drain()
	check(#results==4 and results[4].Value==nil and not results[4].OK,'Escape dismisses without recording a block')
	show();browser:SetVisible(false);f:Drain()
	check(#results==5 and results[5].Value==nil and not browser.Overlays.Current,'Hiding the browser retires its pending request')
	browser:SetVisible(true);f:Drain();show();browser:Destroy();f:Drain()
	check(#results==6 and results[6].Value==nil and f:GlobalConnections()==0,'Browser destruction dismisses and removes every permission input subscription')

	local g=fixture();local manager=loadFallbackWindows(g).new(g.Screen,{Create=g.Create,Input=g.Input,PlayerGui=g.PlayerGui,Task=g.Task})
	local window=manager:Open({Title='HTML',Size=g.Vector2.new(500,360)})
	local fallbackResults={}
	local function fallbackResult(ok,value)table.insert(fallbackResults,{OK=ok,Value=value})end
	local function fallbackShow()
		local dispose=manager:ShowDialog(window.Content,request,fallbackResult);local dialog=manager.Dialogs[1]
		check(dialog and dialog.Kind=='permission'and not dialog.Field,'Fallback owns its permission panel without a text editor')
		check(find(dialog.Root,'DialogOrigin').Text==request.Origin and find(dialog.Root,'DialogTitle').Text==request.Title,'Fallback permissions display origin and title')
		local message=find(dialog.Root,'Message').Text
		check(message:find('Kamera',1,true)and message:find('Mikrofon',1,true),'Fallback lists both requested capabilities')
		return dialog,dispose
	end
	local function fallbackClick(object)
		local p,s=object.AbsolutePosition,object.AbsoluteSize;local event=g:Event(g.Enum.UserInputType.MouseButton1,p.X+s.X/2,p.Y+s.Y/2)
		g.Input.Mouse=g.Vector2.new(event.Position.X,event.Position.Y);g.Input.InputBegan:Fire(event,false);g.Input.InputEnded:Fire(event);g:Drain()
	end
	local dialog,dispose=fallbackShow();fallbackClick(dialog.Accept)
	check(#fallbackResults==1 and fallbackResults[1].OK and fallbackResults[1].Value=='granted','Fallback allow returns granted through native pointer routing')
	dispose();check(#fallbackResults==1,'Fallback completion remains idempotent')
	dialog=fallbackShow();fallbackClick(dialog.Reject)
	check(#fallbackResults==2 and not fallbackResults[2].OK and fallbackResults[2].Value=='denied','Fallback block has a distinct denied reason')
	fallbackShow();g.Input.InputBegan:Fire(g:Event(g.Enum.UserInputType.Keyboard,0,0,g.Enum.KeyCode.Escape),false)
	check(#fallbackResults==3 and not fallbackResults[3].OK and fallbackResults[3].Value==nil,'Fallback Escape dismisses without recording a block')
	dialog,dispose=fallbackShow();dispose();dispose()
	check(#fallbackResults==4 and fallbackResults[4].Value==nil and #manager.Dialogs==0,'Fallback host cancellation completes once without a decision')
	fallbackShow();window:Close()
	check(#fallbackResults==5 and fallbackResults[5].Value==nil and #manager.Dialogs==0,'Closing a fallback owner retires its pending permission')
	manager:Destroy();check(g:GlobalConnections()==0,'Fallback permission input is completely released')
	print('PermissionDialogUI: '..assertions..' anchored browser and standalone fallback permission assertions passed')
end
