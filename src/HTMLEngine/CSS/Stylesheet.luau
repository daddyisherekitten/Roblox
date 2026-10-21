--!strict
--!optimize 2
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
-- Compile author rules for a mount or stylesheet mutation. DOM text stays intact.
local Syntax = require(script.Parent.Syntax)
local DocumentMode=require(script.Parent.Parent.DOM.DocumentMode)
local Nesting = require(script.Parent.Nesting)
local Style = require(script.Parent.InlineStyle)
local Selectors = require(script.Parent.Selectors)
local MediaQueries = require(script.Parent.MediaQueries)
local ContainerQueries = require(script.Parent.ContainerQueries)
local CascadeLayers = require(script.Parent.CascadeLayers)
local ScopeRules = require(script.Parent.ScopeRules)
local ShadowSelectors = require(script.Parent.ShadowSelectors)
local CounterStyles = require(script.Parent.CounterStyles)
local RegisteredProperties = require(script.Parent.RegisteredProperties)
local AnchorPosition=require(script.Parent.AnchorPosition)
local Prelude=require(script.Parent.StylesheetPrelude)
local Imports=require(script.Parent.ImportRules)
local URL = require(script.Parent.Parent.Navigation.URL)
local Stylesheet = {}
local WorkContext=require(script.Parent.Parent.WorkContext)
local EMPTY = table.freeze({Normal = table.freeze({}), Important = table.freeze({})})
local NO_RULES = table.freeze({})
-- Classify immutable compiled selectors once per rule-list owner. This stores
-- candidates only: element state, queries, scopes and cascade still run live.
-- RenderTree replaces lists in place and calls invalidate after replacement.
-- Values are weak too: scoped selectors may point back to a document that
-- owns this list. An ordinary weak-key table would retain that owner cycle.
local targetIndexes = setmetatable({}, {__mode="kv"})
local function targetIndex(rules: any): any
	local indexed = targetIndexes[rules]
	if indexed then return indexed end
	indexed = {Elements={}, Raw={}, Pseudos={}, Parts={}, Shadows={}}
	for index=1,#rules do
		local rule = rules[index]
		local pseudo, special = rule.PseudoElement, rule.ShadowSpecial
		if not pseudo then
			table.insert(indexed.Raw,rule)
			if not special or special=='host-descendant' then table.insert(indexed.Elements,rule) end
			if special then
				local list=indexed.Shadows[special] or {};indexed.Shadows[special]=list
				table.insert(list,rule)
			end
		end
		if rule.Part then
			local key=pseudo or false
			local list=indexed.Parts[key] or {};indexed.Parts[key]=list
			table.insert(list,rule)
		elseif pseudo then
			local list=indexed.Pseudos[pseudo] or {};indexed.Pseudos[pseudo]=list
			table.insert(list,rule)
		end
	end
	targetIndexes[rules]=indexed
	return indexed
end

local trim=Syntax.trim

local function splitCondition(source: string, word: string): {string}?
	local depth, quote, parts, start = 0, nil, {}, 1
	local index = 1
	while index <= #source do
		local char = source:sub(index,index)
		if quote then
			if char == '\\' then index += 1 elseif char == quote then quote = nil end
		elseif char == '"' or char == "'" then quote = char
		elseif char == '(' then depth += 1
		elseif char == ')' then depth -= 1
		elseif depth == 0 and source:sub(index,index+#word+1):lower() == ' '..word..' ' then
			table.insert(parts,trim(source:sub(start,index-1)))
			index += #word+1;start = index+1
		end
		index += 1
	end
	if #parts == 0 then return nil end
	table.insert(parts,trim(source:sub(start)))
	return parts
end

local function supports(source: string, depth: number?,quirks: boolean?): boolean
	depth = depth or 0
	if depth > 16 then return false end
	source = trim(source)
	local negated = source:match('^[Nn][Oo][Tt]%s+(.+)$')
	if negated then return not supports(negated,depth+1,quirks) end
	for _,word in {'or','and'} do
		local parts = splitCondition(source,word)
		if parts then
			for _,part in parts do
				local result = supports(part,depth+1,quirks)
				if word == 'or' and result then return true end
				if word == 'and' and not result then return false end
			end
			return word == 'and'
		end
	end
	local selector = source:match('^[Ss][Ee][Ll][Ee][Cc][Tt][Oo][Rr]%((.*)%)$')
	if selector then return Selectors.compile(selector) ~= nil end
	if source:sub(1,1) ~= '(' or source:sub(-1) ~= ')' then return false end
	local inner = trim(source:sub(2,-2))
	if inner:sub(1,1) == '(' or inner:lower():match('^not%s+') then return supports(inner,depth+1,quirks) end
	if inner:find(':',1,true) then
		local declaration = Style.compile(inner,quirks)
		local entry = declaration.Normal[1]
		return entry ~= nil and #declaration.Normal == 1 and #declaration.Important == 0 and entry.Error == nil
	end
	return supports(inner,depth+1,quirks)
end

local function less(a: any, b: any): boolean
	for index = 1, 3 do
		if a.Specificity[index] ~= b.Specificity[index] then
			return a.Specificity[index] < b.Specificity[index]
		end
	end
	return a.Order < b.Order
end

local function linkedSource(stylesheets: {[string]: string}, href: string, baseURL: string?): string?
	if stylesheets[href] ~= nil then return stylesheets[href] end
	if not baseURL or baseURL == "" then return nil end
	local resolved = URL.resolve(baseURL, href)
	for _, key in { resolved.URL, resolved.Path } do
		if key and stylesheets[key] ~= nil then return stylesheets[key] end
	end
	return nil
end

-- Style block source is child text, including CDATA (a DOM Text subtype),
-- rather than the recursive Element.textContent view.
function Stylesheet.styleText(node: any): string
	local parts={}
	for _,child in node.Children do
		WorkContext.checkpoint()
		if child.Kind=='Text'or child.Kind=='CDATASection'then table.insert(parts,child.Text)end
	end
	return table.concat(parts)
end
function Stylesheet.styleMutationOwner(record: any): any
	local kind=record.Type or record.type
	local node=record.Target or record.target
	if kind=='characterData'and node then node=node.Parent end
	return if(kind=='childList'or kind=='characterData')and ElementNames.style(node)then node else nil
end
function Stylesheet.styleAncestor(node: any): any
	while node do if ElementNames.style(node)then return node end;node=node.Parent end
	return nil
end
function Stylesheet.isMetadata(node: any): boolean
	while node do
		-- Scripts share the non-rendered mutation path, including when inserted
		-- in body. Their presence can still affect selectors on rendered nodes.
		if ElementNames.html(node,"head")or ElementNames.style(node)or ElementNames.html(node,"link")or ElementNames.script(node) then return true end
		node = node.Parent
	end
	return false
end

-- Source discovery is shared with the JavaScript CSSOM adapter. Disabled
-- sheets remain associated with their owner and keep their place in this list.
function Stylesheet.sources(document: any, css: string?, stylesheets: {[string]: string}?, baseURL: string?, diagnostic: ((string) -> ())?): any
	if document.Kind=='ShadowRoot'then
		local at=document;while at and at.Kind~='Document'do at=if at.Kind=='ShadowRoot'then at.Host else at.Parent end
		if not at then return{}end
	end
	local result, pending = {}, {document}
	while #pending > 0 do
		WorkContext.checkpoint()
		local node = table.remove(pending)
		if ElementNames.style(node)or ElementNames.html(node,"link") then
			local attributes = node.Attributes
			local kind = (if ElementNames.style(node)then attributes.type or "text/css"else trim(attributes.type or "text/css")):lower()
			if kind ~= "" and kind ~= "text/css" then continue end
			local source, href
			if ElementNames.style(node) then
				source = Stylesheet.styleText(node)
			else
				local linked = false
				for relation in (attributes.rel or ""):lower():gmatch("%S+") do if relation == "stylesheet" then linked = true; break end end
				if not linked then continue end
				href = attributes.href or ""
				source = if stylesheets then linkedSource(stylesheets, href, baseURL) else nil
				local resource=node.StylesheetResourceState
				if resource then source=resource.Source end
				if source == nil and stylesheets and diagnostic then diagnostic("Linked stylesheet is unavailable: " .. href) end
				if resource and resource.URL then href=resource.URL
				elseif baseURL and baseURL ~= "" then href = URL.resolve(baseURL, href).URL or href end
			end
			if source ~= nil then
				table.insert(result, {Node=node, Source=source, Href=href, Title=if document.Kind=='ShadowRoot'or attributes.title == "" then nil else attributes.title, Media=attributes.media or "",
					Disabled=ElementNames.html(node,"link") and attributes.disabled ~= nil,
					OriginClean=not node.StylesheetResourceState or node.StylesheetResourceState.OriginClean~=false,
					Resource=node.StylesheetResourceState,SourceURL=node.StylesheetResourceState and node.StylesheetResourceState.ResponseURL,ResourceVersion=node.StylesheetResourceState and node.StylesheetResourceState.Generation})
			end
		end
		for index = #node.Children, 1, -1 do table.insert(pending, node.Children[index]) end
	end
	-- The mount's separate CSS remains a final author sheet. It has no DOM owner.
	if css and css ~= "" then table.insert(result, {Source=css, Media="", Disabled=false, Synthetic=true}) end
	return result
end

function Stylesheet.collect(document: any, diagnostic: (string) -> (), css: string?, stylesheets: {[string]: string}?, baseURL: string?, provider: any?): any
	local quirks=DocumentMode.quirks(document)
	local rules = {}
	rules.Keyframes = {}
	rules.Layers=CascadeLayers.new()
	rules.CounterStyles={};rules.CounterStyleDefinitions={}
	rules.PropertyRegistry={};rules.PropertyDefinitions={}
	rules.KeyframeDefinitions={}
	rules.PositionTries={};rules.PositionTryDefinitions={}
	local mediaCount = 0
	local containerCount = 0
	rules.ContainerStyleNames={}
	local namespaces,sourceURL={},baseURL;local currentResource
	local importDepth=0
	local importing={};local importedBytes=0
	local function keyframes(name: string,body: string,media: any?,layer: any?)
		if not name:match("^[%a_%-][%w_%-]*$") or #name>128 then diagnostic("Unsupported @keyframes name: "..name);return end
		local frames,index={},1
		while index<=#body and #frames<64 do
			local header,nextIndex,delimiter=Syntax.scan(body,index,"{");index=nextIndex
			if delimiter~="{" then if header:find("%S") then diagnostic("Incomplete @keyframes entry: "..header) end;break end
			local declarations,after,closing=Syntax.scan(body,index,"}");index=after
			if closing=="" then diagnostic("@keyframes entry closed at end of block") end
			local cursor=1
			while cursor<=#header do
				local token,following,comma=Syntax.scan(header,cursor,",");cursor=following;token=token:match("^%s*(.-)%s*$") or ""
				local percentage=tonumber(token:match("^([+]?%d*%.?%d+)%%$"))
				local offset=if token:lower()=="from" then 0 elseif token:lower()=="to" then 1 elseif percentage then percentage/100 else nil
				if offset==nil or offset<0 or offset>1 then diagnostic("Unsupported @keyframes selector: "..token)
				else table.insert(frames,{Offset=offset,Declarations=Style.compile(declarations,quirks),Source=declarations,Order=#frames+1}) end
				if comma=="" then break end
			end
		end
		table.sort(frames,function(a,b)return if a.Offset==b.Offset then a.Order<b.Order else a.Offset<b.Offset end)
		table.insert(rules.KeyframeDefinitions,{Name=name,Frames=frames,Media=media,Layer=layer})
	end
	local function parse(source: string, media: any?, containers: any?,layer: any?,scopes: any?,owner: any?,starting: boolean?,nesting: string?,singleNested: boolean?,depth: number?)
		source=Syntax.preprocess(source)
        depth=depth or 0;assert(depth<=32,'CSS rule nesting budget exceeded')
        if nesting and not singleNested then
         for _,part in Nesting.body(source)do
          if part.Kind=='Declarations'then
           -- Nested declarations inherit the exact parent selector list,
           -- including pseudo-elements and each branch's own specificity.
           parse(nesting..'{'..part.Source..'}',media,containers,layer,scopes,owner,starting,nil,nil,depth+1)
          else parse(part.Source,media,containers,layer,scopes,owner,starting,nesting,true,depth+1)end
         end
         return
        end
		local index = 1
		local preludePhase,importIndex=0,0 -- imports, namespaces, body; each sheet owns its namespace map.
		while index <= #source do
			WorkContext.checkpoint()
			local headerStart=index
			local header, nextIndex, delimiter = Syntax.scan(source, index, "{;}",nil,true)
			local rawHeader=source:sub(headerStart,nextIndex-2)
			index = nextIndex
			if delimiter == "" and not header:find("%S") then break end
			if delimiter ~= "{" then
				local clean=trim(header);local atName,prelude=Syntax.atRule(clean)
				if atName then clean='@'..atName..(if prelude==''then''else' '..prelude)end
				local lower=clean:lower()
				if depth==0 and delimiter==';'and lower:match('^@namespace%s')then
					local prefix,uri=Prelude.namespace(clean:sub(11))
					if preludePhase<=1 and prefix~=nil and uri~=nil then namespaces[prefix]=uri;preludePhase=1 else diagnostic('Invalid or misplaced @namespace: '..clean)end
					continue
				elseif depth==0 and delimiter==';'and lower:match('^@import%s')then
					local imported=Prelude.import(prelude)
					if preludePhase>0 or not imported then diagnostic('Invalid or misplaced @import: '..clean);continue end
					importIndex+=1;local child=currentResource and currentResource.Imports[importIndex]
					local href,tail=imported.Href,imported.Media
					local importedLayer=layer
					if imported.Supports then local test=imported.Supports;if not supports(if test:find(':',1,true)then '('..test..')'else test,nil,quirks)then continue end end
					local importedMedia=media
					if tail~=''then local query=MediaQueries.compile(tail);if not query then diagnostic('Invalid @import media: '..tail);continue end;importedMedia=if media then table.clone(media)else {};table.insert(importedMedia,query)end
					if imported.Layer~=nil then importedLayer=CascadeLayers.declare(rules.Layers,imported.Layer,layer,importedMedia);if not importedLayer then diagnostic('Invalid @import layer');continue end end
					local resolved=URL.resolve(sourceURL or baseURL or '/',href).URL or href
					local overlay=if child and provider and provider.RenderImport then provider:RenderImport(child)else nil
					if overlay and overlay.Disabled then continue end
					local content=if overlay then overlay.Source elseif currentResource then child and child.Source else stylesheets and linkedSource(stylesheets,href,sourceURL or baseURL)
					if not content then if not currentResource then diagnostic('Imported stylesheet is unavailable: '..href)end;continue end
					if importing[resolved]then continue end -- Cyclic imports contribute no second rule tree.
					if importDepth>=32 then diagnostic('CSS import depth exceeded: '..href);continue end
					importedBytes+=#content;assert(importedBytes<=1024*1024,'CSS import budget exceeded')
					local savedNamespaces,savedURL,savedResource=namespaces,sourceURL,currentResource
					namespaces={};sourceURL=if child then child.ResponseURL or resolved else resolved;currentResource=child;importing[resolved]=true
					importDepth+=1;parse(content,importedMedia,containers,importedLayer,scopes,owner,starting,nil,nil,0);importDepth-=1
					importing[resolved]=nil;namespaces,sourceURL,currentResource=savedNamespaces,savedURL,savedResource
					continue
				elseif depth==0 and delimiter==';'and lower:match('^@charset%s')then continue end
				local statement=if atName=='layer'and prelude~=''then prelude else nil
				if delimiter==';'and statement then
					local valid=true;local names={};for _,name in Selectors.list(statement)do name=trim(name);if not CascadeLayers.valid(name)then valid=false;break end;table.insert(names,name)end
					if valid then for _,name in names do if not CascadeLayers.declare(rules.Layers,name,layer,media)then diagnostic('Invalid @layer name: '..name)end end else diagnostic('Invalid @layer statement: '..statement)end
				elseif scopes and not trim(header):match('^@')and header:find(':',1,true)then
					parse(':where(:scope){'..header..'}',media,containers,layer,scopes,owner,starting)
				else diagnostic("Unsupported or incomplete CSS rule: " .. header)end
				continue
			end
			local body, afterBody, closing = Syntax.scan(source, index, "}",true)
			if Imports.closes(header)then preludePhase=2 end
			index = afterBody
			if closing == "" then diagnostic("CSS rule closed at end of style block") end
			-- Browser font resources are valid website CSS. Font selection is mapped to
			-- the engine's bundled, premeasured face with the same family and style.
			local cleanHeader = header:match("^%s*(.-)%s*$") :: string
			local atName,prelude=Syntax.atRule(cleanHeader)
			if atName then cleanHeader='@'..atName..(if prelude==''then''else' '..prelude)end
			local lowerHeader = cleanHeader:lower()
			local keyframeName=cleanHeader:match("^@[Kk][Ee][Yy][Ff][Rr][Aa][Mm][Ee][Ss]%s+(.+)$")
			if keyframeName then keyframes(keyframeName:match("^%s*(.-)%s*$") or "",body,media,layer);continue end
			if lowerHeader:match('^@position%-try%s')then
				local name=AnchorPosition.name(trim(cleanHeader:sub(14)))
				if not name then diagnostic('Invalid @position-try name: '..cleanHeader);continue end
				local accepted={}
				for _,declaration in Syntax.declarations(body)do
					local head,_,colon=Syntax.scan(declaration.Text,1,':');head=trim(head)
					local property,ending=Syntax.identifier(head)
					property=if colon==':'and property and ending>#head then property:lower()else nil
					local allowed=property and AnchorPosition.acceptedProperty(property)
					if allowed and not declaration.Important then table.insert(accepted,declaration.Raw)end
				end
				local source=table.concat(accepted,';')
				table.insert(rules.PositionTryDefinitions,{Name=name,Declarations=Style.compile(source,quirks),Source=source,Media=media,Layer=layer})
				continue
			end
			if lowerHeader=='@starting-style'then parse(body,media,containers,layer,scopes,owner,true,nesting,nil,depth+1);continue end
			if lowerHeader=='@layer'or lowerHeader:match('^@layer%s')then
				local name=trim(cleanHeader:sub(7));local child=CascadeLayers.declare(rules.Layers,name,layer,media)
				if child then parse(body,media,containers,child,scopes,owner,starting,nesting,nil,depth+1)else diagnostic('Invalid @layer name: '..name)end;continue
			end
			if lowerHeader=='@scope'or lowerHeader:match('^@scope[%s%(]')then
				local scope=ScopeRules.parse(cleanHeader:sub(7),owner,document,nesting,namespaces,scopes~=nil)
				if scope then local nested=if scopes then table.clone(scopes)else{};table.insert(nested,scope);parse(body,media,containers,layer,nested,owner,starting,nil,nil,depth+1)else diagnostic('Invalid @scope boundaries: '..cleanHeader)end;continue
			end
			local counterName=cleanHeader:match('^@[Cc][Oo][Uu][Nn][Tt][Ee][Rr]%-[Ss][Tt][Yy][Ll][Ee]%s+(.+)$')
			if counterName then local descriptor,message=CounterStyles.parse(trim(counterName),body);if descriptor then table.insert(rules.CounterStyleDefinitions,{Name=descriptor.Name,Value=descriptor,Media=media,Layer=layer})elseif message then diagnostic(message)end;continue end
			local propertyName=cleanHeader:match('^@[Pp][Rr][Oo][Pp][Ee][Rr][Tt][Yy]%s+(.+)$')
			if propertyName then local descriptor,message=RegisteredProperties.parse(trim(propertyName),body);if descriptor then table.insert(rules.PropertyDefinitions,{Name=descriptor.Name,Value=descriptor,Media=media})elseif message then diagnostic(message)end;continue end
			if lowerHeader:sub(1, 6) == "@media" and (lowerHeader:sub(7, 7) == "" or lowerHeader:sub(7, 7):match("[%s%(]")) then
				local rawName,_,rawAfter=Syntax.atRule(rawHeader);local query = MediaQueries.compile(if rawName=='media'then rawHeader:sub(rawAfter)else prelude)
				if not query then diagnostic("Unsupported media query: " .. cleanHeader:sub(7)); continue end
				local combined = if media then table.clone(media) else {}
				table.insert(combined, query)
				parse(body, combined,containers,layer,scopes,owner,starting,nesting,nil,depth+1)
				continue
			end
			if lowerHeader:sub(1,9) == '@supports' and (lowerHeader:sub(10,10) == '' or lowerHeader:sub(10,10):match('[%s%(]')) then
				if supports(cleanHeader:sub(10),nil,quirks) then parse(body,media,containers,layer,scopes,owner,starting,nesting,nil,depth+1) end
				continue
			end
			if lowerHeader:sub(1,10)=="@container" and (lowerHeader:sub(11,11)=="" or lowerHeader:sub(11,11):match("%s")) then
				local rawName,_,rawAfter=Syntax.atRule(rawHeader);local query=ContainerQueries.compile(if rawName=='container'then rawHeader:sub(rawAfter)else prelude)
				if not query then diagnostic("Unsupported container query: "..cleanHeader:sub(11));continue end
				for name in query.StyleNames do rules.ContainerStyleNames[name]=true end
				if query.HasScroll then rules.HasScrollContainers=true end
				local combined=if containers then table.clone(containers) else {};table.insert(combined,query)
				parse(body,media,combined,layer,scopes,owner,starting,nesting,nil,depth+1)
				continue
			end
			if lowerHeader == "@font-face" then continue end
			if nesting and not cleanHeader:match('^@')then
             local expanded=Nesting.resolve(cleanHeader,nesting)
             if not expanded then diagnostic('Unsupported nested CSS selector: '..cleanHeader);continue end
             header=expanded
            end
			-- Skip entire unsupported at-rule blocks, including nested rules.
			local selectors, valid = {}, true
			for _, entry in Selectors.list(header) do
				local special
				local selectorSource = trim(entry)
				local scopeExemption,scopeRootEligible
				if scopes then selectorSource,scopeExemption,scopeRootEligible=ScopeRules.selector(selectorSource)
                elseif selectorSource:find('&',1,true)then
                 selectorSource,scopeExemption=ScopeRules.selector(selectorSource)
                 if scopeExemption then valid=false;break end
                end
				local targetCurrent = selectorSource:match("::scroll%-marker:target%-current%s*$") ~= nil
				if targetCurrent then selectorSource = selectorSource:gsub(":target%-current%s*$", "") end
    local slotSelector,slotContext,slotHost,hostDescendant,hostContext,part
    if selectorSource:lower():find('::part(',1,true)then
     local prepared,parsed=ShadowSelectors.part(selectorSource,document);if not prepared then valid=false;break end
     selectorSource,part,special=prepared,parsed,'part'
    elseif document.Kind=="ShadowRoot"then
     local prepared,context=ShadowSelectors.host(selectorSource)
     if prepared then
      selectorSource,hostContext,special=prepared,context,'host-descendant';hostDescendant=true
     else
      if selectorSource:lower():find('::slotted(',1,true)then
       local prepared,slot=ShadowSelectors.slotted(selectorSource,document);if not prepared then valid=false;break end
       special,selectorSource,slotSelector,slotContext,slotHost='slotted',prepared,slot.Selector,slot.Context,slot.Host
      end
     end
    end
				local pseudoElement=selectorSource:match("::([%a%-]+)%s*$")
				local highlight=selectorSource:match("::highlight%((.-)%)%s*$")
				if highlight then local argument=highlight:match('^%s*(.-)%s*$');local name,finish=Syntax.identifier(argument);if name and finish>#argument then pseudoElement='highlight('..name..')'else valid=false;break end end
				if selectorSource:match("::picker%(%s*select%s*%)%s*$") then pseudoElement="picker(select)" end
				if not highlight and pseudoElement~="first-letter"and pseudoElement~="before" and pseudoElement~="after" and pseudoElement~="marker" and pseudoElement~="scroll-marker" and pseudoElement~="backdrop" and pseudoElement~="placeholder" and pseudoElement~="selection" and pseudoElement~="picker(select)" and pseudoElement~='picker-icon'and pseudoElement~='checkmark'then pseudoElement=nil end
				if targetCurrent and pseudoElement~="scroll-marker" then valid=false;break end
				local selectorText=if highlight then selectorSource:gsub("::highlight%(.-%)%s*$","") elseif pseudoElement=="picker(select)" then selectorSource:gsub("::picker%(%s*select%s*%)%s*$","") elseif pseudoElement then selectorSource:gsub("::[%a%-]+%s*$","") else selectorSource
				if pseudoElement and selectorText:match('^%s*$') then selectorText='*' end
				local compiled = Selectors.compile(selectorText,if special=='slotted'then 1 else nil,namespaces,nil,scopeExemption)
				if not compiled or (special == "slotted" and #compiled.Parts ~= 1) then valid = false; break end
				if scopes and not compiled.ShadowSpecial and not special then compiled.ScopeRootEligible=scopeRootEligible end
				if pseudoElement or special=='part'then compiled.Parts[#compiled.Parts].QuirksHover=false end
				compiled.PseudoElement=pseudoElement
				compiled.PseudoState=if targetCurrent then "target-current" else nil
    compiled.ShadowSpecial=special
    if hostDescendant and #compiled.Parts==1 then compiled.ShadowSpecial='host'end
    compiled.ShadowContext,compiled.Part=hostContext,part
    compiled.ShadowHost=if document.Kind=='ShadowRoot'then document.Host else nil
    compiled.SlotSelector=slotSelector
    compiled.SlotContext,compiled.SlotHost=slotContext,slotHost
				if pseudoElement then compiled.Specificity[3]+=1 end
    if hostContext then for i=1,3 do compiled.Specificity[i]+=hostContext.Specificity[i]end end
    if part then for i=1,3 do compiled.Specificity[i]+=part.Host.Specificity[i]end;compiled.Specificity[3]+=1;if part.Context then for i=1,3 do compiled.Specificity[i]+=part.Context.Specificity[i]end end end
    if slotSelector then for i=1,3 do compiled.Specificity[i]+=slotSelector.Specificity[i]end;compiled.Specificity[3]+=1;if slotContext then for i=1,3 do compiled.Specificity[i]+=slotContext.Specificity[i]end end end
				if targetCurrent then compiled.Specificity[2]+=1 end
				-- Shared matching applies HTML folding per element/document; keep
				-- original names for SVG, XML, namespaced attributes and adoption.
				table.insert(selectors, compiled)
			end
			if not valid then diagnostic("Unsupported CSS selector or at-rule: " .. header); continue end
            local segments=Nesting.body(body);local hasRules=false
            for _,part in segments do if part.Kind=='Rule'then hasRules=true;break end end
            if hasRules then
             for _,part in segments do
              if part.Kind=='Declarations'then parse(header..'{'..part.Source..'}',media,containers,layer,scopes,owner,starting,nil,nil,depth+1)
              else parse(part.Source,media,containers,layer,scopes,owner,starting,header,true,depth+1)end
             end
             continue
            end
			local declarations = Style.compile(body,quirks)
			local raw={Normal={},Important={}}
			for _,declaration in Syntax.declarations(body)do
				local source=declaration.Text:match('^%s*(.-)%s*$');local name,after=Syntax.identifier(source)
				if name then local tail=source:sub(after):match('^%s*:%s*(.-)%s*$');if tail then table.insert(if declaration.Important then raw.Important else raw.Normal,{Name=if name:sub(1,2)=='--'then name else name:lower(),Value=tail,Important=declaration.Important})end end
			end
			for _, compiled in selectors do
				compiled.Declarations, compiled.Order, compiled.Media,compiled.Containers = declarations, #rules + 1, media,containers
				compiled.RawDeclarations=raw
				compiled.Layer,compiled.Scopes,compiled.Starting=layer,scopes,starting
				if media then mediaCount += 1 end
				if containers then containerCount += 1 end
				table.insert(rules, compiled)
			end
		end
	end
	local function sourceRules(source)
		if source.Disabled then return end
		namespaces={};sourceURL=source.SourceURL or source.Href or baseURL;currentResource=source.Resource
		local activeURL=sourceURL and(URL.resolve(baseURL or '/',sourceURL).URL or sourceURL);if activeURL then importing[activeURL]=true end
		local media = trim(source.Media or "")
		if media == "" then parse(source.Source,nil,nil,nil,nil,source.Node);if activeURL then importing[activeURL]=nil end;return end
		local query = MediaQueries.compile(media)
		if not query then if activeURL then importing[activeURL]=nil end;return end -- Invalid queries are a non-matching media list.
		parse(source.Source, {query},nil,nil,nil,source.Node)
		if activeURL then importing[activeURL]=nil end
	end
	for _, source in Stylesheet.sources(document, css, stylesheets, baseURL, diagnostic) do
  local overlay = if provider then provider:RenderSource(source.Node,document) else nil
		sourceRules(overlay or source)
	end
	if provider then for _, source in provider:RenderAdopted(document) do sourceRules(source) end end
	-- Ascending specificity/source order lets valid later declarations override.
	-- Separate CSS is the final author sheet, never inserted into the HTML/DOM.
	table.sort(rules, less)
	rules.MediaCount = mediaCount
	rules.ContainerCount=containerCount
	rules.MediaEnvironment = {}
	CascadeLayers.update(rules.Layers,{})
	Stylesheet.setMediaEnvironment(rules,{})
	return rules
end

local function mediaMatches(rule: any, environment: any): boolean
	for _, query in rule.Media or {} do if not MediaQueries.matches(query, environment) then return false end end
	return true
end

function Stylesheet.setMediaEnvironment(rules: any, environment: any): boolean
	local previous = rules.MediaEnvironment or {}
	local changed = false
	if rules.MediaCount and rules.MediaCount > 0 then
		for index=1,#rules do
			local rule=rules[index]
			if rule.Media and mediaMatches(rule, previous) ~= mediaMatches(rule, environment) then changed = true; break end
		end
	end
	if rules.Layers and CascadeLayers.update(rules.Layers,environment)then changed=true end
	local function definitions(entries,target,valueField)
		local selected={}
		for _,entry in entries or{}do
			if mediaMatches(entry,environment)then local previous=selected[entry.Name];if not previous or CascadeLayers.compare(previous.Layer,entry.Layer)<=0 then selected[entry.Name]=entry end end
		end
		for name in target do if not selected[name]then target[name]=nil;changed=true end end
		for name,entry in selected do local value=if valueField then entry[valueField]else entry;if target[name]~=value then target[name]=value;changed=true end end
	end
	definitions(rules.CounterStyleDefinitions,rules.CounterStyles or{},'Value')
	definitions(rules.KeyframeDefinitions,rules.Keyframes or{},nil)
	definitions(rules.PositionTryDefinitions,rules.PositionTries or{},nil)
	definitions(rules.PropertyDefinitions,rules.PropertyRegistry or{},'Value')
	rules.MediaEnvironment = environment
	return changed
end

local function scopedMatches(node,rule,states,scope)
 if rule.Part then return ShadowSelectors.partMatches(node,rule,states)and Selectors.matches(node,rule,states,scope)end
 if rule.ShadowSpecial=='host'or rule.ShadowSpecial=='host-descendant'then
  return ShadowSelectors.context(rule,states)and Selectors.matches(node,rule,states,scope or rule.ShadowHost,function(n)local p=n and n.Parent;return if p and p.Kind=='ShadowRoot'then p.Host else p end)
 end
 return Selectors.matches(node,rule,states,scope)
end
local function declarationSet(matches)
 if #matches==0 then return EMPTY end
 local function ranked(a,b,important)
  local layers=CascadeLayers.compare(a.Rule.Layer,b.Rule.Layer)
  if layers~=0 then return if important then layers>0 else layers<0 end
  for i=1,3 do local x,y=a.Rule.Specificity[i],b.Rule.Specificity[i];if x~=y then return x<y end end
  if a.Distance~=b.Distance then return a.Distance>b.Distance end
  return a.Rule.Order<b.Rule.Order
 end
 local result={Normal={},Important={}}
 table.sort(matches,function(a,b)return ranked(a,b,false)end)
 for _,match in matches do for _,entry in match.Rule.Declarations.Normal do local copy=table.clone(entry);copy.CascadeLayer=match.Rule.Layer;table.insert(result.Normal,copy)end end
 table.sort(matches,function(a,b)return ranked(a,b,true)end)
 for _,match in matches do for _,entry in match.Rule.Declarations.Important do local copy=table.clone(entry);copy.CascadeLayer=match.Rule.Layer;table.insert(result.Important,copy)end end
 return result
end
local function eligible(rules,node,rule,states,container)
 WorkContext.checkpoint()
 if not mediaMatches(rule,rules.MediaEnvironment)or not ContainerQueries.matches(rule.Containers,container)then return false end
 local scopeNode=if rule.Part then ShadowSelectors.partHost(node,rule.Part)else node;if not scopeNode then return false end
 local inside,distance,scope=ScopeRules.match(scopeNode,rule,states)
 return inside and scopedMatches(node,rule,states,scope),distance
end
function Stylesheet.match(rules: any, node: any, states: any?,container: any?,starting: boolean?): any
	local matches={}
	for _,rule in targetIndex(rules).Elements do
  if (starting or not rule.Starting)and not rule.PseudoElement and (not rule.ShadowSpecial or rule.ShadowSpecial=='host-descendant')then
			local hit,distance=eligible(rules,node,rule,states,container);if hit then table.insert(matches,{Rule=rule,Distance=distance})end
		end
	end
	local result=declarationSet(matches)
	if next(rules.PositionTries or{})then if result==EMPTY then result={Normal={},Important={}}end;result.PositionTries=rules.PositionTries end
	if next(rules.PropertyRegistry or{})then if result==EMPTY then result={Normal={},Important={}}end;result.PropertyRegistry=rules.PropertyRegistry end
	return result
end
-- SVG paints use the same selector/query/layer/scope order without routing
-- SVG-only declarations through the HTML box-property compiler.
function Stylesheet.rawMatch(rules,node,states,container)
	local projected={}
	for _,rule in targetIndex(rules).Raw do if not rule.PseudoElement and not rule.Starting then
		local hit,distance=eligible(rules,node,rule,states,container)
		if hit then local copy=table.clone(rule);copy.Declarations=rule.RawDeclarations or EMPTY;table.insert(projected,{Rule=copy,Distance=distance})end
	end end
	return declarationSet(projected)
end
function Stylesheet.partScopes(node:any):any return ShadowSelectors.partScopes(node)end
function Stylesheet.matchPart(rules:any,node:any,states:any?,container:any?,starting:boolean?,pseudo:string?):any
 local matches={}
 for _,rule in targetIndex(rules).Parts[pseudo or false] or NO_RULES do if rule.Part and rule.PseudoElement==pseudo and(starting or not rule.Starting)then
  local hit,distance=eligible(rules,node,rule,states,container);if hit then table.insert(matches,{Rule=rule,Distance=distance})end
 end end
 return declarationSet(matches)
end

function Stylesheet.matchShadow(rules: any, node: any, kind: string, states: any?, container: any?,starting: boolean?): any
	local matches={}
	for _,rule in targetIndex(rules).Shadows[kind] or NO_RULES do
  if (starting or not rule.Starting)and not rule.PseudoElement and rule.ShadowSpecial==kind and(kind~='slotted'or ShadowSelectors.slotMatches(node,rule,states))then
			local hit,distance=eligible(rules,node,rule,states,container);if hit then table.insert(matches,{Rule=rule,Distance=distance})end
		end
	end
	return declarationSet(matches)
end

function Stylesheet.matchPseudo(rules: any,node: any,name: string,states: any?,container: any?,targetCurrent: boolean?,starting: boolean?): any
	local matches={}
	for _,rule in targetIndex(rules).Pseudos[name] or NO_RULES do
		if not rule.Part and (starting or not rule.Starting)and rule.PseudoElement==name and(not rule.PseudoState or(rule.PseudoState=="target-current"and targetCurrent))and(rule.ShadowSpecial~='slotted'or ShadowSelectors.slotMatches(node,rule,states))then
			local hit,distance=eligible(rules,node,rule,states,container);if hit then table.insert(matches,{Rule=rule,Distance=distance})end
		end
	end
	return declarationSet(matches)
end

local formStateNames=table.freeze({checked=true,indeterminate=true,['placeholder-shown']=true,valid=true,invalid=true,['user-invalid']=true,['user-valid']=true,['in-range']=true,['out-of-range']=true,dir=true})
-- Validation aggregates forms/fieldsets and radio indeterminacy reads peers;
-- keep those on the conservative path. These four tests read only the subject.
local localFormNames=table.freeze({checked=true,['placeholder-shown']=true,['in-range']=true,['out-of-range']=true})
local function stateTest(name: string,state: string): boolean
	return name==state or state=='focus'and name=='focus-within' or state=='form-state'and formStateNames[name]==true
end
local function dependsOn(selector: any, state: string): boolean
	for _, part in selector.Parts do
		for _, test in part.Tests do
			if test.Kind == "pseudo" then
				if stateTest(test.Name,state)then return true end
				for _, nested in test.Selectors or {} do if dependsOn(nested, state) then return true end end
				for _, nested in test.Filter or {} do if dependsOn(nested, state) then return true end end
			end
		end
	end
	return false
end

local stateSelectors = setmetatable({}, {__mode="k"})
function Stylesheet.invalidate(rules: any)
	stateSelectors[rules] = nil
	targetIndexes[rules] = nil
end
-- A state on the subject can only change matches on the elements whose
-- state changed. Relational/nested ancestor tests retain the general path.
local function subjectState(selector: any, state: string): boolean
	for index, part in selector.Parts do
		for _, test in part.Tests do
			if test.Kind ~= "pseudo" then continue end
			local direct = stateTest(test.Name,state)
			if direct and index ~= #selector.Parts then return false end
			if direct and state=='form-state'and not localFormNames[test.Name]then return false end
			for _,nested in test.Filter or{}do if dependsOn(nested,state)then return false end end
			for _, nested in test.Selectors or {} do
				if dependsOn(nested, state) and (index ~= #selector.Parts or test.Name == "has"
					or #nested.Parts ~= 1 or not subjectState(nested, state)) then return false end
			end
		end
	end
	return true
end
local function relevantSelectors(rules: any, state: string): any
	local byState = stateSelectors[rules]
	if not byState then byState={}; stateSelectors[rules]=byState end
	if byState[state] then return byState[state] end
	local relevant={Local={},General={}}
	for index=1,#rules do
		local selector=rules[index]
		if not selector.Starting and dependsOn(selector,state) then
			local localState = (state == "hover" or state == "active" or state == "focus" or state == "focus-visible"or state=='form-state')
				and subjectState(selector, state)
			table.insert(if localState then relevant.Local else relevant.General, selector)
		end
	end
	byState[state]=relevant
	return relevant
end

function Stylesheet.stateChanges(rules: any, document: any, state: string, before: any, after: any): (boolean, any, boolean)
	local relevant = relevantSelectors(rules,state)
	local changed = setmetatable({}, {__mode="k"})
	local generated = false
	local function mark(node: any, selector: any)
		changed[node]=true
		local pseudo=selector.PseudoElement
		if pseudo == "before" or pseudo == "after" or pseudo == "marker" then generated=true end
	end
	if #relevant.Local==0 and #relevant.General==0 then return false,changed,false end
	if #relevant.Local > 0 then
		local function chain(node: any): any
			local result={}
			while node do
				result[node]=true
				if state == "focus-visible" then break end
				node=node.Parent
			end
			return result
		end
		local function compare(node: any)
			if node.Kind ~= "Element" then return end
			local ancestor=node
			while ancestor and ancestor ~= document do
				ancestor=if ancestor.Kind == "ShadowRoot" then ancestor.Host else ancestor.Parent
			end
			if ancestor ~= document then return end
			for _, selector in relevant.Local do
				if Selectors.matches(node,selector,before) ~= Selectors.matches(node,selector,after) then mark(node,selector) end
			end
		end
		if state=='form-state'then
			local old,new=before[state]or{},after[state]or{}
			local candidates={}
			local function add(node,previous,current)
				if previous==current then return end;candidates[node]=true
				local a,b=previous and previous.SelectedOptions or{},current and current.SelectedOptions or{}
				for option,selected in a do if selected~=b[option]then candidates[option]=true end end
				for option,selected in b do if selected~=a[option]then candidates[option]=true end end
			end
			for node,entry in old do add(node,entry,new[node])end
			for node,entry in new do if old[node]==nil then add(node,nil,entry)end end
			for node in candidates do compare(node)end
		else
			local old, new = chain(before[state]), chain(after[state])
			for node in old do if not new[node] then compare(node) end end
			for node in new do if not old[node] then compare(node) end end
			-- :focus is exact, whereas :focus-within uses the ancestor chain.
			if state == "focus" then
				if before[state] and new[before[state]] then compare(before[state]) end
				if after[state] and old[after[state]] then compare(after[state]) end
			end
		end
	end
	if #relevant.General == 0 then return next(changed) ~= nil,changed,generated end
	local function visit(node: any)
		if node.Kind == "Element" then
			for _, selector in relevant.General do
				if Selectors.matches(node, selector, before) ~= Selectors.matches(node, selector, after) then mark(node,selector) end
			end
		end
		for _, child in node.Children or {} do visit(child) end
		if node.InternalShadowRoot then visit(node.InternalShadowRoot) end
	end
	visit(document)
	return next(changed) ~= nil, changed, generated
end

function Stylesheet.supports(condition: string): boolean return supports(condition)end
return Stylesheet
