--!strict
-- Fault injection at the raw mount boundary supplements the real VM tests.
return function(loadHost,fixture)
	local assertions=0
	local function check(value,label)assertions+=1;assert(value,label)end
	for _,kind in{'nil','false','table'}do
		local f=fixture();local pages={};local rootOptions
		local primary=if kind=='table'then{}elseif kind=='false'then false else nil
		local secondary={}
		local function mount(target,_,options)
			local page={Alive=true,DocumentOrigin='http://fault.test',DocumentURL=options.DocumentURL,Title='Fault test',Cleanups={}}
			page.Root=f.Create('Frame',target,{Size=f.UDim2.fromScale(1,1),BackgroundTransparency=1})
			page.Root:SetAttribute('Status','ready')
			function page:AddCleanup(callback)table.insert(self.Cleanups,callback)end
			function page:SetVisible(visible)self.Root.Visible=visible end
			function page:SetDocumentVisible(visible)self.DocumentVisible=visible end
			function page:HasExecutingScripts()return false end
			function page:CommitLeave()self.Committed=true end
			function page:RequestLeave()return true end
			function page:Destroy()
				if not self.Alive then return end;self.Alive=false
				for index=#self.Cleanups,1,-1 do self.Cleanups[index]()end
				self.Root:Destroy();if self.Fail then error(secondary,0)end
			end
			local runtime={Alive=true}
			function runtime:IsExecuting()return false end
			function runtime:Destroy()if not self.Alive then return end;self.Alive=false;if page.Fail then error(primary,0)end end
			page.JavaScriptRuntime=runtime
			options.JavaScriptServices.RuntimeCreated(runtime,page)
			if not rootOptions then rootOptions=options end
			table.insert(pages,page);return page
		end
		local target=f.Create('Frame',f.Screen,{Size=f.UDim2.fromOffset(900,600)})
		local root=loadHost(f).mount(target,'',{DocumentURL='http://fault.test/root',Diagnostic=error,
			FallbackServices={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,RunService=f.Run,Task=f.Task}},mount)
		local host=root.FallbackHost;local manager=host.Manager
		local first=rootOptions.JavaScriptServices.WindowHost.Open({URL='',Target='first',Features={Popup=true}})
		local second=rootOptions.JavaScriptServices.WindowHost.Open({URL='',Target='second',Features={Popup=true}})
		check(first and second and #pages==3,'Three independently owned native window/page records are mounted')
		pages[2].Fail=true
		local ok,value=pcall(function()root:Destroy()end)
		check(not ok and value==primary,'Teardown preserves the first '..kind..' payload instead of a later page cleanup failure')
		for _,page in pages do check(not page.Alive and not page.JavaScriptRuntime.Alive and page.Root.Parent==nil,'Every page and runtime is retired despite sibling cleanup errors')end
		check(not host.Alive and not manager.Alive and #manager:GetWindows()==0,'The complete UI family is retired before returning the first error')
		check(first.IsDiscarded()and second.IsDiscarded()and next(host.Names)==nil,'Retained handles lose their document and named contexts')
		f:Drain();target:Destroy();check(f:GlobalConnections()==0,'A throwing diagnostic/cleanup cannot strand native input or frame subscriptions')
	end
	print('Standalone host lifetime: '..assertions..' nil/false/table first-error, sibling retirement and native-input cleanup controls passed')
end
