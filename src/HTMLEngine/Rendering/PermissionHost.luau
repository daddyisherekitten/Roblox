--!strict
-- Session permissions belong to an origin and a window family, never cookies
-- or Roblox device permissions. This adapter only owns the access prompt.
local PermissionHost={}
local names={camera=true,microphone=true}

function PermissionHost.new(services,store)
	services=services or{};store=store or{}
	store.States=store.States or{};store.Listeners=store.Listeners or{}
	local self={Alive=true,Requests={},Subscriptions={}}
	local function allowed()
		return self.Alive and(type(services.CanRequest)~='function'or services.CanRequest()==true)
	end
	local function state(origin,name)
		local states=store.States[origin]
		return states and states[name]or'prompt'
	end
	local function publish(origin,changed,value)
		if #changed==0 then return end
		local states=store.States[origin]or{};store.States[origin]=states
		-- Publish all decisions before notifying either PermissionStatus. A
		-- combined request cannot expose half of a camera/microphone answer.
		for _,name in changed do states[name]=value end
		local listeners=store.Listeners[origin]
		if not listeners then return end
		local firstError,failed
		for _,name in changed do
			for callback in table.clone(listeners)do if listeners[callback]then
				local ok,message=pcall(callback,name,value)
				if not ok and not failed then firstError,failed=message,true end
			end end
		end
		if failed and services.Report then services.Report(firstError)end
	end
	function self:Query(origin,name)
		if not names[name]or type(origin)~='string'or origin==''or origin=='null'then return'denied'end
		return state(origin,name)
	end
	function self:Subscribe(origin,callback)
		if not self.Alive or type(origin)~='string'or type(callback)~='function'then return function()end end
		local listeners=store.Listeners[origin]or{};store.Listeners[origin]=listeners
		local subscribed=true
		local function wrapped(name,value)if self.Alive and subscribed then callback(name,value)end end
		listeners[wrapped]=true
		local function unsubscribe()
			if not subscribed then return end;subscribed=false;listeners[wrapped]=nil;self.Subscriptions[unsubscribe]=nil
			if next(listeners)==nil and store.Listeners[origin]==listeners then store.Listeners[origin]=nil end
		end
		self.Subscriptions[unsubscribe]=true
		return unsubscribe
	end
	function self:Request(request,complete)
		local origin=request and request.Origin
		local wanted,pending,seen={},{},{}
		local function reject(message)complete(false,message);return function()end end
		if not allowed()or type(origin)~='string'or origin==''or origin=='null'then return reject('Permission request is not allowed.')end
		for _,name in request.Names or{}do
			if not names[name]then return reject('Unsupported permission.')end
			if not seen[name]then
				seen[name]=true;table.insert(wanted,name)
				local value=state(origin,name)
				if value=='denied'then return reject('Permission request denied.')end
				if value~='granted'then table.insert(pending,name)end
			end
		end
		if #wanted==0 then return reject('No permission was requested.')end
		if #pending==0 then complete(true);return function()end end
		if type(services.Show)~='function'then return reject('Permission prompt is unavailable.')end
		local token={Done=false};self.Requests[token]=true
		local function cancel()
			if token.Done then return end;token.Done=true;self.Requests[token]=nil
			if token.Cancel then token.Cancel()end
		end
		local function finish(accepted,reason)
			if token.Done then return end;token.Done=true;self.Requests[token]=nil
			if not self.Alive then return end
			if not allowed()then complete(false,'Permission request dismissed.');return end
			if accepted==true and reason=='granted'then
				publish(origin,pending,'granted');if self.Alive then complete(true)end
			elseif reason=='denied'then
				publish(origin,pending,'denied');if self.Alive then complete(false,'Permission request denied.')end
			else complete(false,'Permission request dismissed.')end
		end
		local ok,result=pcall(services.Show,{Kind='permission',Origin=origin,URL=request.URL,Names=pending},finish)
		if not ok then
			if not token.Done then token.Done=true;self.Requests[token]=nil;complete(false,'Permission prompt failed.')end
			if services.Report then services.Report(result)end
		elseif type(result)=='function'then
			token.Cancel=result
			if token.Done then result()end
		end
		return cancel
	end
	function self:Destroy()
		if not self.Alive then return end;self.Alive=false
		local firstError,failed
		for token in self.Requests do
			token.Done=true;self.Requests[token]=nil
			if token.Cancel then local ok,message=pcall(token.Cancel);if not ok and not failed then firstError,failed=message,true end end
		end
		for unsubscribe in table.clone(self.Subscriptions)do unsubscribe()end
		if failed then error(firstError,0)end
	end
	return self
end
return PermissionHost
