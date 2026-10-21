--!strict
local Node=require(script.Parent.Parent.DOM.Node)
local Template=require(script.Parent.Parent.DOM.TemplateDocument)
local Tokenizer=require(script.Parent.Tokenizer)
local Context=require(script.Parent.TreeContext)
local Head=require(script.Parent.DocumentHead)
local Body=require(script.Parent.DocumentBody)
local Tables=require(script.Parent.TableBuilder)
local Foreign=require(script.Parent.ForeignContent)
local SelectedContent=require(script.Parent.SelectedContent)
local Entities=require(script.Parent.Entities)
local Language=require(script.Parent.Parent.DOM.DocumentLanguage)
local InputStream=require(script.Parent.InputStream)
local Builder={}
local headModes={initial=true,["before-html"]=true,["before-head"]=true,head=true,["head-noscript"]=true,["after-head"]=true,text=true,["after-body"]=true,["after-after-body"]=true,frameset=true,["after-frameset"]=true,["after-after-frameset"]=true}
local function limit(options: any,key: string,fallback: number): number
	local value=if options[key]==nil then fallback else options[key]
	assert(type(value)=="number" and value>0 and value<math.huge and value%1==0,"Invalid "..key); return value
end
function Builder.new(source: string,options: any?,fragmentContext: any?): any
	assert(type(source)=="string","HTML must be a string"); options=options or {}
	local maxBytes=limit(options,"MaxBytes",1024*1024)
	local limits={Nodes=limit(options,"MaxNodes",20000),Depth=limit(options,"MaxDepth",256)}
	local maxDiagnostics=limit(options,"MaxDiagnostics",100)
	assert(#source<=maxBytes,"HTML exceeds MaxBytes")
	local origins;source,origins=InputStream.normalize(source)
	if not fragmentContext and source:sub(1,3)=="\239\187\191" then source=source:sub(4);if origins then origins=origins:sub(4)end end
	local document=options._Document or Node.document()
	if not fragmentContext then document.LegacyFragment=nil end
	if options.IsSrcdoc~=nil then assert(type(options.IsSrcdoc)=='boolean','Invalid IsSrcdoc');document.IsSrcdoc=options.IsSrcdoc end
	if options.FallbackBaseURL~=nil then assert(type(options.FallbackBaseURL)=='string'and options.FallbackBaseURL~='','Invalid FallbackBaseURL');document.FallbackBaseURL=options.FallbackBaseURL end
	document.Mode=if document.IsSrcdoc then 'no-quirks'else 'quirks';document.ScriptingEnabled=options.ScriptingEnabled==true
	if document.IsSrcdoc then document.CharacterEncoding='UTF-8';document.EncodingConfidence='irrelevant'end
	Language.configure(document,options)
	local function diagnostic(code: string,message: string,position: number)
		if #document.Diagnostics<maxDiagnostics then table.insert(document.Diagnostics,{Code=code,Message=message,Position=position}) else document.DiagnosticsTruncated=true end
	end
	local tokenizer=Tokenizer.new(source,diagnostic)
	tokenizer.InputCR=origins
	-- Tree construction, rather than token emission, selects raw/RCDATA states.
	tokenizer.TreeControlled=true
	local c=Context.new(document,tokenizer,limits,diagnostic); c.Node=Node; c.BodyToken=Body.process; c.ForeignInsert=Foreign.insert
	c.DeclarativeShadowRoots=not fragmentContext and not options.DisableDeclarativeShadowRoots
	c.EncodingProbe=if fragmentContext then nil else options._EncodingProbe
	c.HTMLToken=function(ctx: any,t: any): boolean
		if headModes[ctx.Mode] then return Head.process(ctx,t)
		elseif ctx.Mode=="body" then return Body.process(ctx,t) else return Tables.process(ctx,t) end
	end
	local fragmentRoot=nil
	if fragmentContext then
		local namespace=fragmentContext.NamespaceURI
		if namespace=="http://www.w3.org/1999/xhtml" then namespace=nil end
		c.FragmentContext={Name=fragmentContext.LocalName or fragmentContext.Name,NamespaceURI=namespace,Attributes=fragmentContext.Attributes or {}}
		fragmentRoot=c:synthetic("html"); document.DocumentElement=fragmentRoot
		local ancestor=fragmentContext
		while ancestor do
			c:checkpoint()
			if ancestor.Name=="form" and not c.Form then c.Form=ancestor end
			if ancestor.Kind=="Document" then document.Mode=ancestor.Mode or "no-quirks"; break end
			ancestor=ancestor.Parent or ancestor.OwnerDocument
		end
		if not ancestor then document.Mode="no-quirks" end
		if namespace==nil and Template.matches(fragmentContext) then table.insert(c.Templates,"template") end
		c:resetMode()
		local name=fragmentContext.LocalName or fragmentContext.Name
		if namespace==nil and (({title=true,textarea=true,style=true,xmp=true,iframe=true,noembed=true,noframes=true,script=true,plaintext=true})[name] or (name=="noscript" and document.ScriptingEnabled)) then
			-- There is no appropriate last start tag in a raw fragment tokenizer,
			-- so even a matching closing tag is literal text in this context.
			local value=source:gsub("%z",utf8.char(0xFFFD))
			if name=="title" or name=="textarea" then value=Entities.decode(value) end
			c:text(value); source=""; tokenizer.Position=tokenizer.Length+1
		end
	end
	local pending,lookahead,tableText=nil,nil,nil
	local session={Document=document,Alive=true,Done=false,ScriptCreated=options._ScriptCreated==true}
	local points=setmetatable({},{__mode="k"})
	function session:Point(position: number): any local point={Position=position};points[point]=true;return point end
	session.InsertionPoint=session:Point(tokenizer.Length+1)
	local final=not session.ScriptCreated and options._InputStream~=true
	function session:SetMutationHook(callback: any?) c.Mutation=callback end
	function session:SetElementHook(callback: any?) c.CreateElement=callback end
	function session:SetShadowHook(callback: any?) c.ShadowCreated=callback end
	local function insertAt(point: any,value: string): any
		assert(session.Alive and not session.Done,"HTML parser is no longer active")
		assert(type(value)=="string","HTML must be a string")
		if value~=""then
			local endedCR=value:sub(-1)=="\r"
			if point.AfterCR and value:sub(1,1)=="\n"then value=value:sub(2)end
			point.AfterCR=endedCR
		end
		local insertedCR;value,insertedCR=InputStream.normalize(value)
		assert(tokenizer.Length+#value<=maxBytes,"HTML exceeds MaxBytes")
		assert(not pending and not lookahead,"HTML insertion requires a parser boundary")
		local position=point.Position
		for point in points do if point.Position>=position then point.Position+=#value end end
		if tokenizer.InputCR or insertedCR then
			local old=tokenizer.InputCR or string.rep('\0',tokenizer.Length)
			tokenizer.InputCR=old:sub(1,position-1)..(insertedCR or string.rep('\0',#value))..old:sub(position)
		end
		tokenizer.Source=tokenizer.Source:sub(1,position-1)..value..tokenizer.Source:sub(position)
		tokenizer.Length=#tokenizer.Source
		return session:Point(position+#value)
	end
	function session:Insert(value: string): any return insertAt(self.InsertionPoint,value)end
	-- Transport input appends at the end; document.write keeps its own marker.
	-- These positions remain separate while a parser script is blocked.
	local tail=session:Point(tokenizer.Length+1)
	function session:Append(value: string)
		assert(options._InputStream==true and not final,'HTML input stream is closed')
		insertAt(tail,value)
	end
	function session:Close() final=true end
	function session:Destroy()
		if not self.Alive then return end;self.Alive=false;c.Mutation=nil;c.CreateElement=nil;c.ShadowCreated=nil
		tokenizer.Source="";tokenizer.InputCR=nil;tokenizer.Length=0;pending=nil;lookahead=nil;tableText=nil
		table.clear(c.Stack);table.clear(c.Active);table.clear(c.Templates)
	end
	local function read(boundary: any?): any
		local position=tokenizer.Position;local point=session.InsertionPoint
		if boundary and position>=boundary.Position then return nil end
		if position<=tokenizer.Length and point.AfterCR and position==point.Position then
			point.AfterCR=nil
			if tokenizer.Source:sub(position,position)=='\n'and(not tokenizer.InputCR or tokenizer.InputCR:sub(position,position)~='\1')then
				tokenizer.Source=tokenizer.Source:sub(1,position-1)..tokenizer.Source:sub(position+1)
				if tokenizer.InputCR then tokenizer.InputCR=tokenizer.InputCR:sub(1,position-1)..tokenizer.InputCR:sub(position+1)end
				tokenizer.Length-=1
				for marker in points do if marker.Position>position then marker.Position-=1 end end
			end
		end
		return tokenizer:nextIncremental(final,boundary and boundary.Position)
	end
	function session:Advance(boundary: any?): any
		if not self.Alive or self.Done then return nil end
	while true do
		local stop=boundary and boundary.Position
		if stop and tokenizer.Position>=stop and not pending and not lookahead then return nil end
		c:checkpoint(); tokenizer.AllowCDATA=c:adjustedCurrent()~=nil and c:adjustedCurrent().NamespaceURI~=nil
		local buffered=tableText;tableText=nil
		local token=buffered or pending or lookahead or read(boundary)
		if not token then
			if not final or stop then return nil end
			token={Kind="EOF",Position=tokenizer.Length+1}
		end
		local alreadyGrouped=pending~=nil; if pending then pending=nil else lookahead=nil end
		if token.Kind=="Text" and not alreadyGrouped then
			local parts=if buffered then buffered.Parts else {token.Text}
			while true do
				c:checkpoint(); local nextToken=read(boundary)
				if not nextToken or nextToken.Kind~="Text" then
					lookahead=nextToken
					-- In-table characters are one pending sequence until the next
					-- non-character token; a later non-space fosters all of it.
					local current=c:current()
					if not nextToken and(not final or stop)and current and current.NamespaceURI==nil
						and(c.Mode=="table"or c.Mode=="table-body"or c.Mode=="row")
						and({table=true,tbody=true,thead=true,tfoot=true,tr=true})[current.Name]then
						tableText={Kind="Text",Position=token.Position,Parts=parts};return nil
					end
					break
				end
				table.insert(parts,nextToken.Text)
			end
			token.Text=table.concat(parts)
		end
		local current=c:current()
		local scriptNode=if token.Kind=='EndTag'and token.Name=='script'and current and current.Name=='script'
			and(c.Mode=='text'or current.NamespaceURI=='http://www.w3.org/2000/svg')then current else nil
		if c.Mode=="text"and token.Kind=="EOF"and c:current()and c:current().Name=="script"then c:current().ScriptStarted=true;c:current().ScriptParserPending=nil end
		if c.SkipLF then if token.Kind=="Text" and token.Text:sub(1,1)=="\n" then token.Text=token.Text:sub(2) end; c.SkipLF=false end
		local iterations=0
		while true do
			c:checkpoint(); iterations+=1; assert(iterations<128,"HTML tree construction failed to consume a token")
			if token.Kind=="EOF" and #c.Templates>0 and c.Mode~="text" then
				c:close("template"); c:clearMarker(); table.remove(c.Templates); c:resetMode(); continue
			end
			if token.Kind=="Text" and (headModes[c.Mode] or c.Mode=="colgroup") and c.Mode~="text" and not c.Mode:find("frameset",1,true) and not (c:current() and c:current().NamespaceURI) then
				local leading,rest=token.Text:match("^([\t\n\f\r ]+)(.+)$")
				if leading then pending={Kind="Text",Text=rest,Position=token.Position+#leading}; token.Text=leading end
			end
			local consumed=Foreign.process(c,token)
			if consumed==nil then consumed=c.HTMLToken(c,token) end
			if consumed then break end
		end
		if c.SelfClosedScript then scriptNode=c.SelfClosedScript;c.SelfClosedScript=nil end
		if token.Kind=="EOF" then self.Done=true;break end
		if scriptNode then
			scriptNode.ParserInserted=true;scriptNode.ScriptParserPending=nil
			self.InsertionPoint=self:Point(tokenizer.Position)
			return scriptNode
		end
	end
	SelectedContent.initialize(c)
	local reachable,pendingNodes=0,{document}
	while #pendingNodes>0 do
		c:checkpoint(); local node=table.remove(pendingNodes); reachable+=1
		for _,child in node.Children do table.insert(pendingNodes,child) end
		if node.Content then table.insert(pendingNodes,node.Content) end
		if node.InternalShadowRoot then table.insert(pendingNodes,node.InternalShadowRoot)end
	end
	document.NodeCount=reachable
	if fragmentRoot then
		local fragment=Node.documentFragment(); fragment.Diagnostics=document.Diagnostics; fragment.DiagnosticsTruncated=document.DiagnosticsTruncated
		for _,child in table.clone(fragmentRoot.Children) do Node.removeChild(fragmentRoot,child); Node.append(fragment,child) end
		fragment.NodeCount=reachable-1
		Template.assign(fragment,fragmentContext.OwnerDocument or document,nil,true)
		self.Fragment=fragment
		return nil
	end
	return nil
	end
	function session:Result(): any
		assert(self.Done,"HTML parser has not reached EOF")
		return fragmentRoot and self.Fragment or document
	end
	return session
end
function Builder.parse(source: string,options: any?,fragmentContext: any?): any
	local session=Builder.new(source,options,fragmentContext)
	while not session.Done do session:Advance()end
	return session:Result()
end
return Builder
