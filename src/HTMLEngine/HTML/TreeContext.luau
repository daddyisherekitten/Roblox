--!strict
-- Private tree-construction operations; no DOM events or GUI work during parsing.
local Node = require(script.Parent.Parent.DOM.Node)
local SourceDocument=require(script.Parent.Parent.DOM.MediaSourceDocument)
local Template=require(script.Parent.Parent.DOM.TemplateDocument)
local Details = require(script.Parent.Parent.DOM.DetailsState)
local Language=require(script.Parent.Parent.DOM.DocumentLanguage)
local WorkContext = require(script.Parent.Parent.WorkContext)
local DeclarativeShadowRoot=require(script.Parent.DeclarativeShadowRoot)
local FormOwner=require(script.Parent.Parent.DOM.FormOwner)
local Context = {}
Context.__index = Context
local function set(names: string): any
	local result = {}; for name in names:gmatch("%S+") do result[name] = true end; return result
end
Context.Void = set("area base br col embed hr img input link meta param source track wbr")
Context.Special = set("address applet area article aside base basefont bgsound blockquote body br button caption center col colgroup dd details dialog dir div dl dt embed fieldset figcaption figure footer form frame frameset h1 h2 h3 h4 h5 h6 head header hgroup hr html iframe img input keygen li link listing main marquee menu meta nav noembed noframes noscript object ol p param plaintext pre script search section select source style summary table tbody td template textarea tfoot th thead title tr track ul wbr xmp")
local scope = set("applet caption html table td th marquee object template select")
local implied = set("dd dt li optgroup option p rb rp rt rtc")
local mathScope=set("mi mo mn ms mtext annotation-xml")
function Context.isSpecial(node: any): boolean
	if node.NamespaceURI==nil then return Context.Special[node.Name]==true end
	if node.NamespaceURI=="http://www.w3.org/2000/svg" then return node.Name=="foreignObject" or node.Name=="desc" or node.Name=="title" end
	return node.NamespaceURI=="http://www.w3.org/1998/Math/MathML" and mathScope[node.Name]==true
end
function Context.new(document: any, tokenizer: any, limits: any, diagnostic: any): any
	return setmetatable({Document=document, Tokenizer=tokenizer, Limits=limits, Warn=diagnostic,
		Stack={}, Active={}, Templates={}, Mode="initial", Count=1, Foster=false, Form=nil, FramesetOK=true}, Context)
end
function Context:allocate(node: any): any
	self.Count += 1; assert(self.Count <= self.Limits.Nodes, "HTML exceeds MaxNodes")
	local parent=self:location();node.OwnerDocument=if parent.Kind=='Document'then parent else parent.OwnerDocument or self.Document
	return node
end
function Context:current(): any return self.Stack[#self.Stack] end
function Context:adjustedCurrent(): any return if #self.Stack==1 and self.FragmentContext then self.FragmentContext else self:current() end
function Context:push(node: any)
	assert(#self.Stack < self.Limits.Depth, "HTML exceeds MaxDepth"); table.insert(self.Stack, node)
end
function Context:pop(): any return table.remove(self.Stack) end
function Context:remove(node: any)
	local index=table.find(self.Stack,node); if index then table.remove(self.Stack,index) end
end
function Context:find(name: string): any
	for i=#self.Stack,1,-1 do if self.Stack[i].Name==name and self.Stack[i].NamespaceURI==nil then return self.Stack[i],i end end
	return nil
end
function Context:inScope(name: any, kind: string?): boolean
	for i=#self.Stack,1,-1 do
		local node=self.Stack[i]; local n=node.Name
		if node==name or (type(name)=="string" and n==name and node.NamespaceURI==nil) then return true end
		if kind=="table" then if node.NamespaceURI==nil and (n=="html" or n=="table" or n=="template") then return false end
		elseif kind=="select" then if n~="option" and n~="optgroup" then return false end
		elseif (node.NamespaceURI==nil and (scope[n] or (kind=="list" and (n=="ol" or n=="ul")) or (kind=="button" and n=="button")))
			or (node.NamespaceURI=="http://www.w3.org/2000/svg" and (n=="foreignObject" or n=="desc" or n=="title"))
			or (node.NamespaceURI=="http://www.w3.org/1998/Math/MathML" and mathScope[n]) then return false end
	end
	return false
end
function Context:implied(except: string?)
	while self:current() and self:current().NamespaceURI==nil and implied[self:current().Name] and self:current().Name~=except do self:pop() end
end
function Context:close(name: string)
	local _,index=self:find(name); if index then for _=#self.Stack,index,-1 do self:pop() end end
end
function Context:closeP()
	self:implied("p"); self:close("p")
end
function Context:clearTo(names: any)
	while self:current() and not (self:current().NamespaceURI==nil and names[self:current().Name]) do self:pop() end
end
local function content(parent: any): any return if parent.Name=="template" and parent.Content then parent.Content else parent end
function Context:location(override: any?): (any, any)
	local target=override or self:current() or self.Document
	if self.Foster and (target.Name=="table" or target.Name=="tbody" or target.Name=="tfoot" or target.Name=="thead" or target.Name=="tr") then
		local lastTable,tableIndex=self:find("table"); local template,templateIndex=self:find("template")
		if template and (not tableIndex or templateIndex>tableIndex) then return template.Content,nil end
		if not lastTable then return content(self.Stack[1]),nil end
		if lastTable.Parent then return lastTable.Parent,lastTable end
		return content(self.Stack[tableIndex-1]),nil
	end
	return content(target),nil
end
function Context:attach(node: any, parent: any?, before: any?)
	if node.Parent then
		FormOwner.beforeRemove(node)
		local oldParent=node.Parent;Node.removeChild(oldParent,node)
		if self.Mutation then self.Mutation({Type="childList",Target=oldParent,AddedNodes={},RemovedNodes={node}})end
	end
	local target,reference=parent,before
	if not target then target,reference=self:location() end
	Template.assign(node,if target.Kind=='Document'then target else target.OwnerDocument or self.Document)
	-- Only trusted parser-created nodes reach here. This also permits temporary
	-- construction states without invoking public DOM mutation validation.
	local index=if reference then table.find(target.Children,reference) else nil
	node.Parent=target; table.insert(target.Children,index or #target.Children+1,node)
	Language.insert(node)
	if self.Mutation then self.Mutation({Type="childList",Target=target,AddedNodes={node},RemovedNodes={}})end
end
function Context:insert(token: any, namespace: string?, push: boolean?): any
	local node=self:allocate(Node.element(token.Name,table.clone(token.Attributes or {})))
	node.AttributeOrder=table.clone(token.AttributeOrder or {}); node.NamespaceURI=namespace
	SourceDocument.seed(node,node.OwnerDocument)
	if namespace==nil and(node.Name=='link'or node.Name=='style')then node.StylesheetParserInserted=self.FragmentContext==nil end
	if node.Name=="script"and(namespace==nil or namespace=='http://www.w3.org/2000/svg')then node.ParserInserted=true;node.ScriptParserPending=true end
	if Template.matches(node)then self:allocate(Template.contents(node,node.OwnerDocument));node.Content.OwnerDocument=Template.owner(node.OwnerDocument)end
	if self.CreateElement and namespace==nil then local parent=self:location();self.CreateElement(node,parent)end
	if namespace==nil and self.Form and not self.FragmentContext and #self.Templates==0 then
		FormOwner.parserAssociate(node,self.Form,self:location())
	end
	local shadow=nil
	if self.DeclarativeShadowRoots and node.Name=='template' and namespace==nil then
		shadow=DeclarativeShadowRoot.create(node,self:adjustedCurrent())
	end
	if shadow then if self.ShadowCreated then self.ShadowCreated(shadow)end else self:attach(node)end
	Details.parserInserted(node,function()self:checkpoint()end)
	if push~=false then self:push(node) end
	return node
end
function Context:synthetic(name: string): any return self:insert({Name=name,Attributes={},AttributeOrder={}}) end
function Context:merge(node: any, token: any)
	for _,name in token.AttributeOrder or {} do
		if node.Attributes[name]==nil then node.Attributes[name]=token.Attributes[name]; table.insert(node.AttributeOrder,name) end
	end
end
function Context:text(value: string)
	if value=="" then return end
	local parent,before=self:location(); local index=if before then table.find(parent.Children,before) else #parent.Children+1
	local previous=parent.Children[index-1]
	if previous and previous.Kind=="Text" then
		local old=previous.Text;previous.Text ..= value
		if self.Mutation then self.Mutation({Type="characterData",Target=previous,OldValue=old})end
	else self:attach(self:allocate(Node.text(value)),parent,before) end
end
function Context:comment(token: any, parent: any?)
	self:attach(self:allocate(if token.Kind=="ProcessingInstruction" then Node.processingInstruction(token.Target,token.Text) else Node.comment(token.Text)),parent)
end
function Context:marker() table.insert(self.Active,false) end
function Context:clearMarker()
	while #self.Active>0 do if table.remove(self.Active)==false then break end end
end
function Context:active(name: string): any
	for i=#self.Active,1,-1 do local node=self.Active[i]; if node==false then break end; if node.Name==name then return node,i end end
	return nil
end
function Context:clone(node: any): any
	local copy=self:allocate(Node.element(node.Name,table.clone(node.Attributes)))
	copy.AttributeOrder=table.clone(node.AttributeOrder or {}); copy.NamespaceURI=node.NamespaceURI; return copy
end
function Context:reconstruct()
	local index=#self.Active; local last=self.Active[index]
	if not last or table.find(self.Stack,last) then return end
	while index>1 and self.Active[index-1]~=false and not table.find(self.Stack,self.Active[index-1]) do index-=1 end
	for i=index,#self.Active do local copy=self:clone(self.Active[i]); self:attach(copy); self:push(copy); self.Active[i]=copy end
end
function Context:resetMode()
	for i=#self.Stack,1,-1 do
		local node=if i==1 and self.FragmentContext then self.FragmentContext else self.Stack[i]
		local n=node.Name
		if node.NamespaceURI~=nil then continue end
		local mode=({td="cell",th="cell",tr="row",tbody="table-body",thead="table-body",tfoot="table-body",caption="caption",colgroup="colgroup",table="table",head="head",body="body",frameset="frameset"})[n]
		if n=="template" then self.Mode=self.Templates[#self.Templates] or "template"; return end
		if n=="head" and i==1 and self.FragmentContext then self.Mode="body"; return end
		if mode then self.Mode=mode; return end
		if n=="html" then self.Mode=if self.Document.Head then "after-head" else "before-head"; return end
	end
	self.Mode="body"
end
function Context:checkpoint() WorkContext.checkpoint() end
return Context
