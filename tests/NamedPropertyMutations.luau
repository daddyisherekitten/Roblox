--!strict
return function(Parser,Node,Runtime,Events,Named,fixture)
	local nativeCount=0
	for _,case in fixture.records do
		if case.auditOnly then continue end
		local events=Events.new(error);local realm=Runtime.new(Parser.parseDocument(fixture.html),{Events=events,ControlAdapter={},Schedule=function()end})
		local ok,message=realm:Run('globalThis.namedMutationResult='..case.source)
		assert(ok,case.name..': '..tostring(message));assert(#realm.Diagnostics==0,case.name..': '..table.concat(realm.Diagnostics,'\n'))
		assert(realm.Window.Get('namedMutationResult')==case.json,case.name..': native named-property sequence differs')
		realm:Destroy();events:Destroy();nativeCount+=1
	end
	assert(nativeCount==10,'Every supported native sequence must execute; three recorded API conformance gaps remain audit-only')
	local function harness(html)
		local document=Parser.parseDocument(html or '<!doctype html><html><head></head><body><img name="kept" id="keptId"></body></html>')
		local body=assert(Node.findElement(document,function(node)return node.Name=='body'end));local steps,hook=0,nil
		local api=Named.new({Wrap=function(node)return node end,Collection=function(entries)return {Entries=entries}end,Step=function()
			steps+=1;local fn=hook;hook=nil;if fn then fn()end
		end})
		local function mutation(parent,added,removed)api:Mutation({Type='childList',Target=parent,AddedNodes=added or{},RemovedNodes=removed or{}})end
		local function insert(parent,node)Node.append(parent,node);mutation(parent,{node})end
		local function remove(parent,node)Node.removeChild(parent,node);mutation(parent,{}, {node})end
		local function attribute(node,key,value)
			local old=node.Attributes[key];node.Attributes[key]=value;api:Mutation({Type='attributes',Target=node,AttributeName=key,OldValue=old})
		end
		return {Document=document,Body=body,API=api,Insert=insert,Remove=remove,Attribute=attribute,StepCount=function()return steps end,Hook=function(fn)hook=fn end}
	end
	-- Small unrelated mutations charge only the visited subtree, preserving the
	-- document-owned index instead of walking every existing element again.
	local h=harness();local _,kept=h.API:Get(h.Document,'Document','kept');local snapshot=h.Document.DOMNamedSnapshots
	local box=Node.element('div',{});Node.append(box,Node.element('span',{}));local before=h.StepCount();h.Insert(h.Body,box)
	assert(h.StepCount()-before==2,'Candidate-free mutation charges its two elements')
	before=h.StepCount();assert(h.API:Entries(h.Document,'Document','kept')[1]==kept);assert(h.StepCount()==before,'Candidate-free updates retain the indexed names')
	assert(h.Document.DOMNamedSnapshots==snapshot,'Candidate-free update retains document snapshot ownership')
	Node.append(box,Node.text('text'));h.API:Mutation({Type='childList',Target=box,AddedNodes={box.Children[#box.Children]}})
	h.API:Mutation({Type='characterData',Target=box.Children[#box.Children],OldValue='old'});before=h.StepCount()
	assert(h.API:Entries(h.Document,'Window','keptId')[1]==kept and h.StepCount()==before,'Text-only changes consume no name-index traversal')
	local other=Parser.parseDocument('<img name="other">');h.API:Entries(other,'Document','other');local image=assert(Node.findElement(other,function(n)return n.Name=='img'end))
	h.Attribute(image,'name','otherChanged');h.API:Entries(other,'Document','otherChanged');before=h.StepCount()
	assert(h.API:Entries(h.Document,'Document','kept')[1]==kept and h.StepCount()==before,'An independent document cannot invalidate the primary index')
	h.API:Destroy()
	-- Actual initial HTML may exceed the dynamically allocated 8192-node cap.
	-- Atomic filtering therefore has its own bound and invalidates conservatively.
	h=harness();h.API:Entries(h.Document,'Document','kept');box=Node.element('div',{})
	for _=1,3000 do Node.append(box,Node.element('span',{}))end
	before=h.StepCount();h.Insert(h.Body,box);assert(h.StepCount()-before==256,'Large atomic candidate classification stays bounded')
	before=h.StepCount();assert(#h.API:Entries(h.Document,'Document','kept')==1 and h.StepCount()>before,'Unknown larger subtrees conservatively rebuild names')
	h.API:Destroy()
	for _,kind in {'wide-input','text-only-input','deep-subtree'}do
		h=harness();h.API:Entries(h.Document,'Document','kept');local nodes={}
		if kind=='deep-subtree'then
			local parent=Node.element('div',{});nodes={parent};for _=1,1500 do local child=Node.element('span',{});Node.append(parent,child);parent=child end
		else for index=1,3000 do nodes[index]=if kind=='text-only-input'then Node.text('text')else Node.element('span',{})end end
		for _,node in nodes do Node.append(h.Body,node)end
		before=h.StepCount();h.API:Mutation({Type='childList',Target=h.Body,AddedNodes=nodes});assert(h.StepCount()-before==256,kind..': classification must not enumerate or queue the whole input/subtree')
		assert(#h.API:Entries(h.Document,'Document','kept')==1,kind..': conservative fallback preserves the named result');h.API:Destroy()
	end
	h=harness();h.API:Entries(h.Document,'Document','kept');local added,removed={},{}
	for index=1,255 do added[index]=Node.element('span',{});removed[index]=Node.element('span',{})end
	before=h.StepCount();h.API:Mutation({Type='childList',Target=h.Body,AddedNodes=added,RemovedNodes=removed})
	assert(h.StepCount()-before==256,'Added and removed lists share one whole-mutation classification budget');h.API:Destroy()
	-- Mutations inside a cooperative snapshot must either restart on a candidate
	-- delta or retain the equivalent result for a candidate-free delta.
	for _,action in {'insert','rename','remove','irrelevant'}do
		h=harness();local original=assert(Node.findById(h.Document,'keptId'));local fresh=Node.element('img',{name='fresh'})
		h.Hook(function()
			if action=='insert'then h.Insert(h.Body,fresh)
			elseif action=='rename'then h.Attribute(original,'name','renamed')
			elseif action=='remove'then h.Remove(h.Body,original)
			else h.Insert(h.Body,Node.element('div',{}))end
		end)
		h.API:Entries(h.Document,'Document','kept')
		assert(#h.API:Entries(h.Document,'Document','kept')==(if action=='rename'or action=='remove'then 0 else 1),action..': cooperative snapshot retained stale names')
		if action=='insert'then assert(h.API:Entries(h.Document,'Document','fresh')[1]==fresh)
		elseif action=='rename'then assert(h.API:Entries(h.Document,'Document','renamed')[1]==original)end
		h.API:Destroy()
	end
	-- The filter's first charge occurs after candidate invalidation. A nested
	-- lookup can see the committed insertion/removal without waiting for Drain.
	for _,action in {'insert','remove','irrelevant'}do
		h=harness();h.API:Entries(h.Document,'Document','kept');local original=assert(Node.findById(h.Document,'keptId'))
		local nested=false
		h.Hook(function()
			nested=true;assert(#h.API:Entries(h.Document,'Document','kept')==(if action=='remove'then 0 else 1),'Filter checkpoint exposed stale candidate names')
			if action=='insert'then assert(#h.API:Entries(h.Document,'Document','fresh')==1)end
		end)
		if action=='insert'then local parent=Node.element('div',{});Node.append(parent,Node.element('img',{name='fresh'}));h.Insert(h.Body,parent)
		elseif action=='remove'then h.Remove(h.Body,original)
		else h.Insert(h.Body,Node.element('div',{}))end
		assert(nested,'Mutation filtering charges its native work');h.API:Destroy()
	end
	h=harness();h.API:Entries(h.Document,'Document','kept');local original=assert(Node.findById(h.Document,'keptId'))
	h.Hook(function()error('deliberate charge abort')end)
	local ok=pcall(h.Remove,h.Body,original);assert(not ok and original.Parent==nil,'An abort after committed mutation keeps the actual DOM operation')
	for _,state in h.Document.DOMNamedSnapshots do assert(next(state.Document)==nil and next(state.Window)==nil,'Removal clears retained candidates before an aborted charge')end
	assert(#h.API:Entries(h.Document,'Document','kept')==0,'The next entry recovers after an aborted mutation charge');h.API:Destroy()
	print('Named property mutation filtering: '..nativeCount..' exact native order/namespace/scope/adoption/reaction sequences; candidate-free/per-document retention, bounded scan, cooperative retries, nested lookup and abort recovery passed')
end
