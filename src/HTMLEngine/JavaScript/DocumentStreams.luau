--!strict
-- Dynamic markup uses the same live tree builder, not reparsed HTML snapshots.
local Parser=require(script.Parent.Parent.HTML.Parser)
local VM=require(script.Parent.VM)
local Streams={}
function Streams.new(ctx: any): any
	local sessions=setmetatable({},{__mode="k"})
	local api={}
	local function controller(node)
		return ctx.Controller and ctx.Controller(node)
	end
	local function check(node)
		if node.IsHTML==false then ctx.Error("InvalidStateError","Dynamic HTML insertion is not available on XML documents")end
		if (node.ThrowOnDynamicMarkupInsertion or 0)>0 then ctx.Error("InvalidStateError","Dynamic markup insertion is not allowed in a parser custom element constructor")end
	end
	local function advanceDetached(session: any,boundary: any?)
		while session.Alive and not session.Done do
			local node=session:Advance(boundary);if not node then break end
			-- Parser preparation in a document without a browsing context does
			-- not execute scripts, and adopting them later must not reactivate them.
			node.ScriptStarted=true
		end
	end
	local function open(node)
		check(node)
		local host=controller(node)
		if host and(host.ParserScriptNesting or 0)>0 then return ctx.Wrap(node)end
		if node.ActiveParserAborted or(node.UnloadCounter or 0)>0 then return ctx.Wrap(node)end
		if sessions[node]then sessions[node]:Destroy()end
		if ctx.EraseListeners then ctx.EraseListeners(node)end
		ctx.Replace(node,{})
		node.DocumentElement,node.Head,node.Body=nil,nil,nil
		local session=Parser.newDocument("",{_Document=node,_ScriptCreated=true,ScriptingEnabled=host~=nil})
		node.Mode="no-quirks"
		session:SetMutationHook(ctx.Mutation)
		session:SetElementHook(ctx.ParserElement)
		session:SetShadowHook(ctx.ParserShadow)
		sessions[node]=session
		if host then host:ReplaceParser(session)end
		return ctx.Wrap(node)
	end
	function api:Get(node,key)
		if key~="open"and key~="close"and key~="write"and key~="writeln"then return false end
		return true,function(args)
			if key=="open"then
				-- WebIDL converts supplied arguments before invoking the HTML
				-- algorithm, even when it subsequently throws or is a parser noop.
				local converted={}
				for index=1,math.min(#args,3)do converted[index]=ctx.String(args[index])end
				if #args>=3 then
					if not ctx.WindowOpen then ctx.Error("InvalidAccessError","Document has no window host")end
					return ctx.WindowOpen(node,converted)
				end
				return open(node)
			elseif key=="close"then
				check(node)
				local host=controller(node)
				if host then host:CloseParser()else
					local session=sessions[node]
					if session and not session.Done then session:Close();advanceDetached(session)end
				end
				return VM.Undefined
			end
			local parts={};for _,value in args do table.insert(parts,ctx.String(value))end
			check(node)
			if key=="writeln"then table.insert(parts,"\n")end
			local value=table.concat(parts)
			local host=controller(node)
			if host and host:WriteParser(value)then return VM.Undefined end
			if host and(host.IgnoreDestructiveWrites or 0)>0 then return VM.Undefined end
			if node.ActiveParserAborted or(node.UnloadCounter or 0)>0 then return VM.Undefined end
			local session=sessions[node]
			if not session or not session.Alive or session.Done then open(node);session=sessions[node]end
			if host then host:WriteParser(value)elseif session then
				local point=session.InsertionPoint;local stop=session:Insert(value)
				advanceDetached(session,stop);session.InsertionPoint=point
			end
			return VM.Undefined
		end
	end
	function api:Destroy()
		for _,session in sessions do session:Destroy()end;table.clear(sessions)
	end
	return api
end
return Streams
