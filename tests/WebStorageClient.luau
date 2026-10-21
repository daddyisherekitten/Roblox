--!strict
-- Real JavaScript realms use the same injected transport as the Roblox host.
-- The clock and DataStore are fakes; no network or live DataStore is touched.
return function(Client, Protocol, Server, Parser, Runtime, Events, Strings)
	local function copy(value)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, item in value do result[key] = copy(item) end
		return result
	end
	local function scheduler()
		local state = {Now = 0, Queue = {}, Serial = 0, Running = false, Waits = 0}
		local function enqueue(thread, at)
			state.Serial += 1
			table.insert(state.Queue, {Thread = thread, At = at, Serial = state.Serial})
		end
		function state:Advance(seconds)
			local target, steps = self.Now + seconds, 0
			while true do
				local best
				for index, item in self.Queue do
					local previous = best and self.Queue[best]
					if item.At <= target and (not previous or item.At < previous.At or item.At == previous.At and item.Serial < previous.Serial) then best = index end
				end
				if not best then break end
				local item = table.remove(self.Queue, best)
				self.Now = item.At; self.Running = true
				local ok, delay = coroutine.resume(item.Thread)
				self.Running = false
				assert(ok, tostring(delay)); steps += 1
				assert(steps < 10000, "Fake task queue did not settle")
				if coroutine.status(item.Thread) ~= "dead" then enqueue(item.Thread, self.Now + (delay or 0)) end
			end
			self.Now = target
		end
		local api = {}
		function api.spawn(callback) enqueue(coroutine.create(callback), state.Now) end
		api.defer = api.spawn
		function api.delay(seconds, callback)
			local thread=coroutine.create(callback);enqueue(thread,state.Now+seconds);return thread
		end
		function api.cancel(thread)
			for index=#state.Queue,1,-1 do if state.Queue[index].Thread==thread then table.remove(state.Queue,index)end end
		end
		function api.wait(seconds)
			state.Waits += 1
			if state.Running then return coroutine.yield(seconds or 0) end
			state:Advance(seconds or 0)
			return seconds or 0
		end
		state.Task = api
		return state
	end
	local origin, otherOrigin = "https://storage.test", "https://other.test"
	local function harness()
		local clock = scheduler()
		local store = {Records = {}, Gets = 0, Updates = 0, FailUpdates = 0, GetDelay = 0}
		function store:GetAsync(key)
			self.Gets += 1
			if self.GetDelay > 0 then clock.Task.wait(self.GetDelay) end
			return copy(self.Records[key])
		end
		function store:UpdateAsync(key, transform)
			self.Updates += 1
			if self.FailUpdates > 0 then self.FailUpdates -= 1; error("injected DataStore failure") end
			local record = transform(copy(self.Records[key]))
			self.Records[key] = copy(record)
			return copy(record)
		end
		local h = {Clock = clock, Store = store, Receivers = {}, Sent = {}, Dirty = 0, DropSaved = false, SendFailures = 0}
		function h:NewServer()
			self.Server = Server.new({Store = store, AllowedOrigins = {[origin] = true, [otherOrigin] = true}, Clock = function() return clock.Now end,
				OnDirty = function(state)
					self.Dirty += 1
					if self.FlushDelay then clock.Task.delay(self.FlushDelay, function() self.Server:Flush(state.UserId, state.Origin) end) end
				end,
				OnError = function(userId, address, message)
					local player = self.Server.Players[userId]
					local state = player and player.States[address]
					for _, batch in if state then state.Pending else {} do
						local receive = self.Receivers[tostring(userId) .. ":" .. batch.ClientId]
						if receive then receive({Ok = false, Error = message, Origin = address, ClientId = batch.ClientId, Sequence = batch.Sequence}) end
					end
				end,
				OnSaved = function(userId, address, clientId, sequence)
					local receive = self.Receivers[tostring(userId) .. ":" .. clientId]
					if receive and not self.DropSaved then receive({Ok = true, Status = "saved", Origin = address, ClientId = clientId, Sequence = sequence}) end
				end})
		end
		function h:Host(userId, clientId, loadTimeout)
			local diagnostics = {}
			local receiverKey = tostring(userId) .. ":" .. clientId
			local client = Client.new({ClientId = clientId, Task = clock.Task, Clock = function() return clock.Now end, LoadTimeout = loadTimeout,
				Load = function(address) return self.Server:Load(userId, address) end,
				Send = function(packet)
					table.insert(self.Sent, copy(packet))
					if self.SendFailures > 0 then self.SendFailures -= 1; error("injected transport failure") end
					local reply = self.Server:Accept(userId, packet)
					local receive = self.Receivers[receiverKey]
					if receive then receive(reply) end
				end,
				Subscribe = function(receive)
					self.Receivers[receiverKey] = receive
					return function() self.Receivers[receiverKey] = nil end
				end,
				Diagnostic = function(message) table.insert(diagnostics, message) end})
			return client, diagnostics
		end
		function h:Record(userId, address)
			local area, message = Protocol.decodeRecord(self.Store.Records[Protocol.key(userId, address)], address)
			assert(area, message)
			return area
		end
		h:NewServer()
		return h
	end
	local function realm(url, getArea, clock)
		local output, diagnostics = {}, {}
		local events = Events.new(error)
		local runtime = Runtime.new(Parser.parseDocument("<html><body></body></html>"), {URL = url, Events = events, GetStorageArea = getArea,
			Clock = function() return clock.Now end, Schedule = function() end,
			Console = function(_, message) table.insert(output, message) end,
			Diagnostic = function(message) table.insert(diagnostics, message) end})
		local value = {Runtime = runtime, Output = output, Diagnostics = diagnostics}
		function value:Run(source)
			runtime:Run(source)
			assert(#diagnostics == 0, table.concat(diagnostics, " / "))
		end
		function value:Destroy() runtime:Destroy(); events:Destroy() end
		return value
	end

	-- Preparation finishes before page scripts read or update saved values.
	local h = harness()
	local lone = Strings.fromUnits({0xd800, 0x78, 0xdc00})
	h.Store.Records[Protocol.key(17, origin)] = {Version = Protocol.Version, Origin = origin, Receipts = {}, Entries = {
		{Key = Protocol.encode("visits"), Value = Protocol.encode("41")}, {Key = Protocol.encode("units"), Value = Protocol.encode(lone)}}}
	local client = h:Host(17, "browser-first")
	local getArea = client:Prepare("HTTPS://STORAGE.TEST:443/start?view=1#page")
	assert(h.Store.Gets == 1 and getArea("local").Values.units == lone, "Saved UTF-16 strings must be present before scripts run")
	local first = realm(origin .. "/start", getArea, h.Clock)
	local waits, gets, sends = h.Clock.Waits, h.Store.Gets, #h.Sent
	first:Run([[localStorage.setItem('visits',String(Number(localStorage.getItem('visits'))+1));sessionStorage.setItem('tab','one');console.log(localStorage.getItem('visits'),sessionStorage.getItem('tab'));]])
	assert(first.Output[1] == "42 one", "A startup script updates the loaded value instead of replacing it with an empty cache")
	assert(h.Clock.Waits == waits and h.Store.Gets == gets and #h.Sent == sends, "JavaScript storage operations are synchronous cache operations and never yield or call the transport")
	h.Clock:Advance(0)
	assert(#h.Sent == 1 and client.Origins[origin].Status == "pending" and client.Origins[origin].Flight, "Acceptance is not a durable acknowledgement")
	assert(h.Store.Updates == 0 and h:Record(17, origin).Values.visits == "41", "Accepted writes wait for server persistence")
	local firstReceive = h.Receivers["17:browser-first"]
	for _, reply in {
		{Ok = true, Status = "saved", Origin = origin, ClientId = "other-browser", Sequence = 1},
		{Ok = true, Status = "saved", Origin = otherOrigin, ClientId = "browser-first", Sequence = 1},
		{Ok = true, Status = "saved", Origin = origin, ClientId = "browser-first", Sequence = 2},
	} do firstReceive(reply) end
	assert(client.Origins[origin].Flight and client.Origins[origin].Status == "pending", "Unrelated client, origin, and sequence replies cannot acknowledge this batch")
	assert(h.Server:Flush(17, origin))
	h.Clock:Advance(0)
	assert(client.Origins[origin].Status == "saved" and not client.Origins[origin].Flight and h:Record(17, origin).Values.visits == "42")
	assert(#h.Clock.Queue==0,'Durable acknowledgement cancels the native retry wake immediately')
	first:Destroy()
	assert(#getArea("local").Subscribers == 0 and #getArea("session").Subscribers == 0, "Page disposal releases realm subscriptions")
	local second = realm(origin .. "/next", client:Prepare(origin .. "/next"), h.Clock)
	second:Run([[console.log(localStorage.getItem('visits'),sessionStorage.getItem('tab'));]])
	assert(second.Output[1] == "42 one" and h.Store.Gets == 1, "Navigation reuses the origin cache and this browser's session area")
	second:Destroy(); client:Destroy()
	h:NewServer()
	local nextClient = h:Host(17, "browser-second")
	local nextPage = realm(origin .. "/rejoin", nextClient:Prepare(origin .. "/rejoin"), h.Clock)
	nextPage:Run([[console.log(localStorage.getItem('visits'),sessionStorage.getItem('tab'),localStorage.getItem('units').charCodeAt(0));]])
	assert(nextPage.Output[1] == "42 null 55296", "Local storage survives a new server/browser session, session storage starts empty, and lone surrogates survive persistence")
	nextPage:Destroy(); nextClient:Destroy()
	local resumedClient=h:Host(17,"browser-first")
	local resumedPage=realm(origin.."/resume",resumedClient:Prepare(origin),h.Clock)
	resumedPage:Run([[localStorage.setItem('visits','43');]])
	h.Clock:Advance(0)
	assert(h.Sent[#h.Sent].Sequence==2,"An injected host ID resumes after its stored durable receipt instead of discarding a new batch as a duplicate")
	assert(h.Server:Flush(17,origin));h.Clock:Advance(0)
	assert(h:Record(17,origin).Values.visits=="43")
	resumedPage:Destroy();resumedClient:Destroy()

	-- Retry uses the original batch; new writes wait behind its durable receipt.
	local retry = harness()
	local retryClient = retry:Host(23, "browser-retry")
	local retryPage = realm(origin .. "/retry", retryClient:Prepare(origin .. "/retry"), retry.Clock)
	local observed = {}
	local stopObserve = retryClient:Observe(origin, function(status, message) table.insert(observed, {status, message}) end)
	retryPage:Run([[localStorage.setItem('draft','first');]])
	retry.Clock:Advance(0)
	retryPage:Run([[localStorage.setItem('draft','second');localStorage.setItem('after','queued');]])
	retry.Clock:Advance(0)
	assert(#retry.Sent == 1 and retryClient.Origins[origin].Status == "pending", "An outstanding batch blocks later delivery without blocking JavaScript mutations")
	retry.Store.FailUpdates = 1
	assert(not retry.Server:Flush(23, origin) and retry.Server:Pending(23, origin))
	assert(retryClient.Origins[origin].Flight and retryClient.Origins[origin].Status == "pending", "A failed durable save retains the client's outstanding batch")
	assert(retryClient.Origins[origin].Error:find("injected DataStore failure", 1, true) and observed[#observed][2] == retryClient.Origins[origin].Error, "A server save-error reply reports the failure while the unsaved queue stays pending")
	retry.Clock:Advance(5)
	assert(#retry.Sent == 2 and retry.Sent[1].Sequence == retry.Sent[2].Sequence and retry.Sent[2].Changes[1].Value == Protocol.encode("first"), "Retries preserve the exact in-flight sequence and value")
	assert(#retry.Server.Players[23].States[origin].Pending == 1, "Duplicate accepted retries do not apply the operation twice")
	assert(retry.Server:Flush(23, origin))
	retry.Clock:Advance(0)
	assert(#retry.Sent == 3 and retry.Sent[3].Sequence == 2 and retry:Record(23, origin).Values.draft == "first", "The queued update dispatches only after sequence one has been saved")
	assert(retry.Server:Flush(23, origin))
	retry.Clock:Advance(0)
	local saved = retry:Record(23, origin)
	assert(saved.Values.draft == "second" and saved.Values.after == "queued" and retryClient.Origins[origin].PendingChars == 0)
	assert(observed[#observed][1] == "saved", "Observers report saved only after all pending changes are durable")
	stopObserve(); retryPage:Destroy(); retryClient:Destroy()
	local closing=harness();local closingClient=closing:Host(24,'browser-closing')
	local closingPage=realm(origin,closingClient:Prepare(origin),closing.Clock)
	closingPage:Run([[localStorage.setItem('draft','pending');]]);closing.Clock:Advance(0)
	assert(#closing.Clock.Queue==1,'An outstanding batch owns exactly one retry wake')
	local sentBeforeClose=#closing.Sent;closingPage:Destroy();closingClient:Destroy()
	assert(#closing.Clock.Queue==0,'Browser disposal cancels its suspended storage retry')
	closing.Clock:Advance(60);assert(#closing.Sent==sentBeforeClose,'Canceled retries never send after disposal')
	local legacy=harness();legacy.Clock.Task.cancel=nil
	local legacyClient=legacy:Host(25,'browser-legacytasks');local legacyPage=realm(origin,legacyClient:Prepare(origin),legacy.Clock)
	legacyPage:Run([[localStorage.setItem('draft','pending');]]);legacy.Clock:Advance(0)
	legacyPage:Destroy();legacyClient:Destroy();legacy.Clock:Advance(60)
	assert(#legacy.Sent==1,'Injected task APIs without cancellation retain the guarded no-op fallback')

	-- A lost durable reply is recovered by the server's saved duplicate receipt.
	local lost = harness()
	local lostClient = lost:Host(29, "browser-lostack")
	local lostPage = realm(origin .. "/lost", lostClient:Prepare(origin), lost.Clock)
	lostPage:Run([[localStorage.setItem('once','written');]])
	lost.Clock:Advance(0); lost.DropSaved = true
	assert(lost.Server:Flush(29, origin))
	assert(lostClient.Origins[origin].Flight and not lost.Server:Pending(29, origin))
	lost.Clock:Advance(5)
	assert(#lost.Sent == 2 and lost.Store.Updates == 1 and lostClient.Origins[origin].Status == "saved", "A persisted duplicate acknowledges the lost reply without another DataStore update")
	lostPage:Destroy(); lostClient:Destroy()
	local disconnected = harness(); disconnected.SendFailures = 1
	local disconnectedClient, disconnectedDiagnostics = disconnected:Host(30, "browser-transport")
	local disconnectedPage = realm(origin, disconnectedClient:Prepare(origin), disconnected.Clock)
	disconnectedPage:Run([[localStorage.setItem('offline','retained');console.log(localStorage.getItem('offline'));]])
	disconnected.Clock:Advance(0)
	assert(disconnectedPage.Output[1] == "retained" and #disconnectedDiagnostics == 1 and not disconnected.Server:Pending(30, origin) and disconnectedClient.Origins[origin].Flight, "A thrown transport error retains the synchronous local value and its unsaved batch")
	disconnected.Clock:Advance(5)
	assert(disconnected.Server:Pending(30, origin) and disconnected.Server:Flush(30, origin))
	disconnected.Clock:Advance(0)
	assert(disconnected:Record(30, origin).Values.offline == "retained" and disconnectedClient.Origins[origin].Status == "saved" and disconnectedClient.Origins[origin].Error == nil)
	disconnectedPage:Destroy(); disconnectedClient:Destroy()

	-- Large startup batches respect the wire limit and a graceful host flush
	-- drains later batches before the transport is destroyed.
	local draining = harness(); draining.FlushDelay = .2
	local drainingClient = draining:Host(32, "browser-draining")
	local drainingPage = realm(origin, drainingClient:Prepare(origin), draining.Clock)
	drainingPage:Run("for(let i=0;i<" .. tostring(Protocol.MaxChanges + 2) .. ";i++){localStorage.setItem('k'+i,String(i))}localStorage.setItem('k" .. tostring(Protocol.MaxChanges + 1) .. "','replacement');")
	assert(not drainingClient:Flush(.1) and drainingClient.Origins[origin].Flight and drainingClient.Origins[origin].Status == "pending", "A graceful flush timeout preserves all queued data for a later retry")
	assert(drainingClient:Flush(2) and #draining.Sent == 2 and #draining.Sent[1].Changes == Protocol.MaxChanges and #draining.Sent[2].Changes == 2, "Graceful flush drains sequential bounded batches and coalesces the final unsent replacement")
	assert(draining.Store.Updates == 2 and draining:Record(32, origin).Values["k" .. tostring(Protocol.MaxChanges + 1)] == "replacement" and drainingClient.Origins[origin].PendingChars == 0)
	drainingPage:Destroy(); drainingClient:Destroy()

	-- A delayed RPC cannot expose writable empty local storage before its result.
	local late = harness(); late.Store.GetDelay = 1
	late.Store.Records[Protocol.key(31, origin)] = {Version = Protocol.Version, Origin = origin, Receipts = {}, Entries = {{Key = Protocol.encode("saved"), Value = Protocol.encode("loaded")}}}
	local lateClient, lateDiagnostics = late:Host(31, "browser-lateload", .1)
	local lateArea = lateClient:Prepare(origin .. "/slow")
	local latePage = realm(origin .. "/slow", lateArea, late.Clock)
	latePage:Run([[try{localStorage.setItem('saved','overwrite')}catch(e){console.log(e.name)}sessionStorage.setItem('alive','yes');console.log(sessionStorage.getItem('alive'));]])
	assert(latePage.Output[1] == "SecurityError" and latePage.Output[2] == "yes" and #late.Sent == 0 and #lateDiagnostics == 1, "A timed-out load denies local storage while preserving available session storage")
	late.Clock:Advance(1)
	latePage:Run([[console.log(localStorage.getItem('saved'),sessionStorage.getItem('alive'));]])
	assert(latePage.Output[3] == "loaded yes" and #late.Sent == 0, "Late completion installs the saved record without overwriting it")
	latePage:Destroy(); lateClient:Destroy()

	-- Backend corruption and unapproved origins never become empty local areas.
	local corrupt = harness()
	corrupt.Store.Records[Protocol.key(37, origin)] = {Version = Protocol.Version, Origin = origin, Receipts = {}, Entries = {{Key = "zzzz", Value = "0000"}}}
	local corruptClient = corrupt:Host(37, "browser-corrupt")
	local corruptPage = realm(origin, corruptClient:Prepare(origin), corrupt.Clock)
	corruptPage:Run([[try{console.log(localStorage.length)}catch(e){console.log(e.name)}sessionStorage.setItem('ok','session');console.log(sessionStorage.getItem('ok'));]])
	assert(corruptPage.Output[1] == "SecurityError" and corruptPage.Output[2] == "session" and #corrupt.Sent == 0)
	local deniedPage = realm("https://denied.test/", corruptClient:Prepare("https://denied.test/"), corrupt.Clock)
	deniedPage:Run([[try{localStorage.setItem('x','x')}catch(e){console.log(e.name)}try{sessionStorage.setItem('x','x')}catch(e){console.log(e.name)}]])
	assert(deniedPage.Output[1] == "SecurityError" and deniedPage.Output[2] == "SecurityError" and corrupt.Store.Gets == 1, "Unapproved origins deny both storage areas and do not access the DataStore")
	local opaquePage = realm("about:blank", corruptClient:Prepare("about:blank"), corrupt.Clock)
	opaquePage:Run([[for(const kind of ['localStorage','sessionStorage']){try{console.log(window[kind].length)}catch(e){console.log(e.name)}}]])
	assert(opaquePage.Output[1] == "SecurityError" and opaquePage.Output[2] == "SecurityError")
	corruptPage:Destroy(); deniedPage:Destroy(); opaquePage:Destroy(); corruptClient:Destroy()

	-- Two real realms share storage events only through the same origin/session.
	local shared = harness()
	local sharedClient = shared:Host(41, "browser-shared")
	local sharedArea = sharedClient:Prepare(origin .. "/source")
	local source = realm(origin .. "/source", sharedArea, shared.Clock)
	local peer = realm(origin .. "/peer", sharedClient:Prepare(origin .. "/peer"), shared.Clock)
	local listener = [[var seen=[];window.addEventListener('storage',e=>{seen.push(e.key+'|'+e.oldValue+'|'+e.newValue+'|'+e.url+'|'+(e.storageArea===localStorage?'local':'session')+'|'+e.isTrusted)});]]
	source:Run(listener); peer:Run(listener)
	source:Run([[localStorage.setItem('event','one');sessionStorage.setItem('tab','same');localStorage.setItem('event','one');console.log(seen.length);]])
	peer:Run([[console.log(seen.length);]])
	assert(source.Output[1] == "0" and peer.Output[1] == "0", "Events are queued and exclude the writing realm and no-op writes")
	peer.Runtime:PumpTasks()
	peer:Run([[console.log(seen.length);console.log(seen[0]);console.log(seen[1]);]])
	assert(peer.Output[2] == "2" and peer.Output[3] == "event|null|one|https://storage.test/source|local|true" and peer.Output[4] == "tab|null|same|https://storage.test/source|session|true", "The peer receives trusted events with its own storage object and the source URL")
	local isolatedArea = sharedClient:Prepare(otherOrigin)
	local isolated = realm(otherOrigin, isolatedArea, shared.Clock)
	isolated:Run(listener)
	local otherPlayerClient = shared:Host(43, "browser-otherplayer")
	local otherPlayer = realm(origin, otherPlayerClient:Prepare(origin), shared.Clock)
	otherPlayer:Run(listener)
	source:Run([[localStorage.setItem('event','two');]])
	assert(peer.Runtime.EventLoop.TaskCount == 1, "A peer event is queued before disposal")
	peer:Destroy()
	shared.Clock:Advance(0)
	assert(shared.Server:Flush(41, origin)); shared.Clock:Advance(0)
	isolated.Runtime:PumpTasks(); otherPlayer.Runtime:PumpTasks()
	isolated:Run([[console.log(localStorage.getItem('event'),sessionStorage.getItem('tab'),seen.length);]])
	otherPlayer:Run([[console.log(localStorage.getItem('event'),sessionStorage.getItem('tab'),seen.length);]])
	assert(isolated.Output[1] == "null null 0" and otherPlayer.Output[1] == "null null 0", "Approved origins and players keep both values and storage events isolated")
	assert(#sharedArea("local").Subscribers == 1 and #sharedArea("session").Subscribers == 1 and #peer.Output == 4 and #peer.Diagnostics == 0, "Disposal cancels a queued storage event and removes both subscriptions")
	source:Destroy(); isolated:Destroy(); otherPlayer:Destroy(); sharedClient:Destroy(); otherPlayerClient:Destroy()
	-- Native transport connection waits can overlap for independently mounted
	-- origins. Only one ACK subscriber is installed, and disposal cancels it.
	local nativeClock=scheduler();local connections,connected=0,0
	local changesRemote={OnClientEvent={}}
	function changesRemote.OnClientEvent:Connect(_callback)
		connections+=1;connected+=1;local handle={Alive=true}
		function handle:Disconnect() if self.Alive then self.Alive=false;connected-=1 end end
		return handle
	end
	function changesRemote:FireServer(_packet) end
	local loadRemote={}
	function loadRemote:InvokeServer(address) return {Ok=true,Record=Protocol.createRecord(address)} end
	local folder={}
	function folder:WaitForChild(name) return if name=="Load" then loadRemote else changesRemote end
	local replicated={}
	function replicated:WaitForChild(_name,_timeout) nativeClock.Task.wait(.1);return folder end
	local nativeClient=Client.fromReplicatedStorage(replicated,{ClientId="browser-native",Task=nativeClock.Task,Clock=function() return nativeClock.Now end})
	nativeClock.Task.spawn(function() nativeClient:Prepare(origin) end)
	nativeClock.Task.spawn(function() nativeClient:Prepare(otherOrigin) end)
	nativeClock:Advance(.5)
	assert(connections==1 and connected==1 and nativeClient.Origins[origin].Area and nativeClient.Origins[otherOrigin].Area,"Concurrent remote discovery installs one connection for both origins")
	nativeClient:Destroy();assert(connected==0)
	local closedClient=Client.fromReplicatedStorage(replicated,{ClientId="browser-nativeclosed",Task=nativeClock.Task,Clock=function() return nativeClock.Now end})
	nativeClock.Task.spawn(function() closedClient:Prepare(origin) end);nativeClock:Advance(0)
	closedClient:Destroy();nativeClock:Advance(.2)
	assert(connections==1 and connected==0,"Closing during remote discovery never installs a late event connection")
	print("Web Storage client/runtime: preload, durable acknowledgements, retries, navigation, session lifetime, origin/player isolation, late/corrupt loads, native transport lifetime and queued realm events passed")
end
