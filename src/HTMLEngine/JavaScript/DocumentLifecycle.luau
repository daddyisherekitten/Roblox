--!strict
-- Host-driven document visibility and uncached navigation. This module never
-- guesses browser focus or preserves a disposed realm as a back-forward cache.
local DocumentLifecycle={}
function DocumentLifecycle.install(vm: any,_globals: any,options: any): any
	options=table.clone(options)
	local events=assert(options.Events,'Document lifecycle requires host events')
	local document=assert(options.Document)
	local window=assert(options.Window)
	local visible=options.Visible~=false
	local desiredVisible=visible
	local generation=0
	local showing=false
	local loaded=false
	local committed=false
	local pending=false
	local unloading=0
	local activated=false
	local api={Alive=true}
	local function access(action)
		if options.Access then return options.Access(action)end
		return action()
	end
	local function transition()
		if options.BeforeTransition then options.BeforeTransition()end
	end
	local function updateVisibility(show)
		if not api.Alive or visible==show then return end
		visible=show
		events:Dispatch(options.TargetFor(document),events:NewEvent('visibilitychange',{bubbles=true}),true)
	end
	local function pageTransition(kind)
		-- HTML's legacy target override keeps listeners on Window while exposing
		-- Document as target. Historical cancelability has no navigation effect.
		events:Dispatch(window,events:NewEvent(kind,{persisted=false,bubbles=true,cancelable=true},'PageTransitionEvent'),true,options.TargetFor(document))
	end
	function api:ElementGet(node,key)
		if node.Kind~='Document'then return nil end
		local shown=node==document and visible
		if key=='hidden'then return not shown end
		if key=='visibilityState'then return if shown then 'visible'else 'hidden'end
		return nil
	end
	function api:ElementSet(node,key,_value,strict)
		if node.Kind~='Document'or(key~='hidden'and key~='visibilityState')then return false end
		if strict then vm.Model.throw(vm.Model.error('TypeError','Document.'..key..' is read-only'))end
		return true
	end
	function api:InitializeVisibility(show)
		assert(type(show)=='boolean','Initial document visibility must be a boolean')
		if not self.Alive or loaded or committed then return false end
		visible=show;desiredVisible=show;generation+=1
		return true
	end
	function api:SetVisible(show)
		show=show==true
		if not self.Alive or committed or desiredVisible==show then return end
		desiredVisible=show
		if not show then transition()end
		local version=generation
		local function apply()
			if not self.Alive or committed or version~=generation then return end
			access(function()updateVisibility(show)end)
		end
		if options.QueueTask then options.QueueTask(apply)else apply()end
	end
	function api:Loaded()
		if not self.Alive or committed or loaded then return end
		loaded=true;showing=true
		pageTransition('pageshow')
	end
	function api:NotifyUserActivation()
		if self.Alive and not committed and unloading==0 then activated=true end
	end
	function api:IsUnloading()return unloading>0 or committed end
	function api:RequestLeave(request)
		if not self.Alive then return false end
		if committed then return true end
		-- An author callback cannot recursively open another leave prompt.
		if pending or unloading>0 then return false end
		pending=true;unloading+=1
		local ok,result=pcall(function()
			transition()
			local needsPrompt=access(function()
				local event=events:NewEvent('beforeunload',{cancelable=true},'BeforeUnloadEvent')
				local accepted=events:Dispatch(window,event,true)
				return not accepted or vm.Get(event,'returnValue')~=''
			end)
			if not self.Alive or committed then return false end
			local modalsAllowed=if type(options.ModalsAllowed)=='function'then options.ModalsAllowed()else options.ModalsAllowed~=false
			local promptState=request and request.PromptState
			if not needsPrompt or not activated or not modalsAllowed or not options.ConfirmLeave or promptState and promptState.Shown then return true end
			-- Confirmation UI uses its own fixed text; a page's returnValue is not
			-- displayed. The host may wait for a native response here.
			if promptState then promptState.Shown=true end
			return options.ConfirmLeave(request or{})==true and self.Alive and not committed
		end)
		unloading-=1;pending=false
		if not ok then error(result,0)end
		return result
	end
	function api:CommitLeave()
		if not self.Alive or committed then return end
		transition();committed=true;generation+=1;desiredVisible=false;unloading+=1
		local ok,message=pcall(access,function()
			if showing then showing=false;pageTransition('pagehide');updateVisibility(false)end
			if self.Alive then events:Dispatch(window,events:NewEvent('unload'),true,options.TargetFor(document))end
		end)
		unloading-=1
		if not ok then error(message,0)end
	end
	function api:Destroy()
		if not self.Alive then return end
		self.Alive=false;generation+=1;table.clear(options)
	end
	return api
end
return DocumentLifecycle
