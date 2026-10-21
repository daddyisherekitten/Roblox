--!strict
--!optimize 2
local Node = require(script.Parent.Parent.DOM.Node)
local Template=require(script.Parent.Parent.DOM.TemplateDocument)
local Tokenizer = require(script.Parent.Tokenizer)
local DocumentBuilder = require(script.Parent.DocumentBuilder)
local SVGNames=require(script.Parent.SVGNames)
local Doctype=require(script.Parent.Doctype)
local Language=require(script.Parent.Parent.DOM.DocumentLanguage)
local DeclarativeShadowRoot=require(script.Parent.DeclarativeShadowRoot)
local Parser = {}
local WorkContext=require(script.Parent.Parent.WorkContext)
local SVG_NAMESPACE = "http://www.w3.org/2000/svg"
local void = { area = true, base = true, br = true, col = true, embed = true, hr = true,
	img = true, input = true, link = true, meta = true, param = true, source = true, track = true, wbr = true }

local function limit(options: any, key: string, fallback: number): number
	local value = if options[key] == nil then fallback else options[key]
	assert(type(value) == "number" and value > 0 and value < math.huge and value % 1 == 0, "Invalid " .. key)
	return value
end

-- Attach declarative shadow roots only from templates in the active tree.
-- A shadow template nested inside an ordinary template remains inert.
local function attachDeclarativeShadowRoots(root: any)
	local pending = {root}
	local attached = 0
	while #pending > 0 do
		WorkContext.checkpoint()
		local node = table.remove(pending)
		if node.Kind == "Element" then
			for index, child in node.Children do
				if child.Kind == "Element" and child.Name == "template" and child.Content then
					local content=DeclarativeShadowRoot.create(child,node)
					if content then
						table.remove(node.Children, index)
						attached += 1
						child.Parent, child.Content = nil, nil
						break
					end
				end
			end
			if node.InternalShadowRoot then table.insert(pending, node.InternalShadowRoot) end
		end
		for index = #node.Children, 1, -1 do table.insert(pending, node.Children[index]) end
	end
	return attached
end

function Parser.parse(source: string, options: any?): any
	assert(type(source) == "string", "HTML must be a string")
	options = options or {}
	local maxBytes = limit(options, "MaxBytes", 1024 * 1024)
	local maxNodes = limit(options, "MaxNodes", 20000)
	local maxDepth = limit(options, "MaxDepth", 256)
	local maxDiagnostics = limit(options, "MaxDiagnostics", 100)
	assert(#source <= maxBytes, "HTML exceeds MaxBytes")
	-- Byte offsets in diagnostics refer to this normalized input.
	source = source:gsub("\r\n", "\n"):gsub("\r", "\n")
	if source:sub(1, 3) == "\239\187\191" then source = source:sub(4) end
	local document = Node.document()
	-- This legacy parseHTML API keeps a flat, Document-shaped fragment host.
	-- Its first child is not a CSS document root; parseDocument uses the builder.
	document.LegacyFragment = true
	Language.configure(document,options)
	document.ScriptingEnabled=options.ScriptingEnabled==true
	document.Mode="quirks"
	local initial=true
	local function diagnostic(code: string, message: string, position: number)
		if #document.Diagnostics < maxDiagnostics then
			table.insert(document.Diagnostics, { Code = code, Message = message, Position = position })
		else document.DiagnosticsTruncated = true end
	end
	local tokenizer = Tokenizer.new(source, diagnostic)
	local stack, nodeCount = { document }, 1
	local textParts = {}
	local skipLeadingLF = false
	local function append(child: any)
		nodeCount += 1
		assert(nodeCount <= maxNodes, "HTML exceeds MaxNodes")
		local parent = stack[#stack]
		local target=if Template.matches(parent)then parent.Content else parent
		Template.assign(child,if target.Kind=='Document'then target else target.OwnerDocument or document)
		Node.append(target,child)
		Language.insert(child)
	end
	while true do
		WorkContext.checkpoint()
		local token = tokenizer:next()
		if not token then break end
		if skipLeadingLF then
			if token.Kind == "Text" and token.Text:sub(1, 1) == "\n" then token.Text = token.Text:sub(2) end
			skipLeadingLF = false
		end
		if token.Kind ~= "Text" and #textParts > 0 then
			append(Node.text(table.concat(textParts)))
			table.clear(textParts)
		end
		if token.Kind == "Text" then
			if token.Text:find("[^\t\n\f\r ]")then initial=false end
			local value=if stack[#stack].NamespaceURI==SVG_NAMESPACE then token.Text:gsub("%z",utf8.char(0xFFFD)) else token.Text:gsub("%z","")
            if value ~= "" then table.insert(textParts, value) end
		elseif token.Kind == "Comment" then append(Node.comment(token.Text))
        elseif token.Kind == "ProcessingInstruction" then append(Node.processingInstruction(token.Target,token.Text))
		elseif token.Kind=="Declaration"then
			if initial and token.Doctype then
				local value=token.Doctype;append(Node.documentType(value.Name,value.PublicId or"",value.SystemId or""));document.Mode=Doctype.mode(value);initial=false
			end
		elseif token.Kind == "StartTag" then
			initial=false
			-- Foreign SVG content is one replaced HTML box. Preserve its subtree,
			-- honor foreign self-closing tags and never apply HTML table/void rules.
			if token.Name == "svg" or stack[#stack].NamespaceURI == SVG_NAMESPACE then
				local attributes = token.Attributes
				for lower, adjusted in SVGNames.Attributes do
					if attributes[lower] then attributes[adjusted],attributes[lower]=attributes[lower],nil end
				end
				local element = Node.element(SVGNames.Tags[token.Name] or token.Name, attributes)
				element.AttributeOrder = token.AttributeOrder
				for index,name in element.AttributeOrder do element.AttributeOrder[index]=SVGNames.Attributes[name] or name end
				element.NamespaceURI = SVG_NAMESPACE
				assert(#stack <= maxDepth, "HTML exceeds MaxDepth")
				append(element)
				if not token.SelfClosing then table.insert(stack,element) end
				-- SVG title is not HTML RCDATA; foreign descendants remain inert.
				tokenizer.Raw = nil
				continue
			end
			if stack[#stack].Name == "colgroup" and token.Name ~= "col" and token.Name ~= "template" and token.Name ~= "script" then table.remove(stack) end
			local tableCells=token.Name == "td" or token.Name == "th"
			local tableGroup=token.Name == "thead" or token.Name == "tbody" or token.Name == "tfoot"
			if tableCells or token.Name == "tr" or tableGroup then
				for index=#stack,2,-1 do
					local name=stack[index].Name
					if name == "table" or (tableCells and name == "tr") then break end
					if (tableCells and (name == "td" or name == "th")) or (token.Name == "tr" and name == "tr")
						or (tableGroup and (name == "tr" or name == "thead" or name == "tbody" or name == "tfoot")) then
						for _=#stack,index,-1 do table.remove(stack) end
						if tableGroup and name == "tr" then continue end
						break
					end
				end
			end
			if token.Name == "option" or token.Name == "optgroup" then
				for index = #stack, 2, -1 do
					local name = stack[index].Name
					if name == "select" or (name == "optgroup" and token.Name == "option") then break end
					if name == "option" or name == "optgroup" then
						for _ = #stack, index, -1 do table.remove(stack) end
						if token.Name == "option" then break end
					end
				end
			end
			-- Terms/descriptions may omit end tags; an inner dl is its own boundary.
			if token.Name == "dt" or token.Name == "dd" then
				for index = #stack, 2, -1 do
					local name = stack[index].Name
					if name == "dl" then break end
					if name == "dt" or name == "dd" then
						for _ = #stack, index, -1 do table.remove(stack) end
						break
					end
				end
			end
			-- li end tags may be omitted. Stop at the nearest list boundary so
			-- an inner list never closes an entry belonging to its outer list.
			if token.Name == "li" then
				for index = #stack, 2, -1 do
					local name = stack[index].Name
					if name == "ul" or name == "ol" then break end
					if name == "li" then
						for _ = #stack, index, -1 do table.remove(stack) end
						break
					end
				end
			end
			assert(#stack <= maxDepth, "HTML exceeds MaxDepth")
			local element = Node.element(token.Name, token.Attributes)
			element.AttributeOrder = token.AttributeOrder
			if token.Name == "template" then
				Template.contents(element,document)
				nodeCount += 1
				assert(nodeCount <= maxNodes, "HTML exceeds MaxNodes")
			end
			append(element)
			if token.Name=='noscript'and document.ScriptingEnabled then tokenizer.Raw='noscript' end
			if not void[token.Name] then
				if token.SelfClosing then
					diagnostic("ignored-self-close", "Only void elements close with /> in this HTML subset", token.Position)
				end
				table.insert(stack, element)
				skipLeadingLF = token.Name == "pre" or token.Name == "textarea" or token.Name == "listing"
			end
		elseif token.Kind == "EndTag" then
			if stack[#stack].NamespaceURI == SVG_NAMESPACE then
				local found = nil
				for index=#stack,2,-1 do
					if stack[index].NamespaceURI ~= SVG_NAMESPACE then break end
					if stack[index].Name:lower() == token.Name then found=index; break end
				end
				if found then
					if found < #stack then diagnostic("implicit-close","SVG children closed by end tag",token.Position) end
					for _=#stack,found,-1 do table.remove(stack) end
				else diagnostic("unmatched-end-tag","No SVG element for </"..token.Name..">",token.Position) end
				continue
			end
			if token.Name == "table" and stack[#stack].Name == "colgroup" then table.remove(stack) end
			if token.Name == "tr" or token.Name == "table" or token.Name == "thead" or token.Name == "tbody" or token.Name == "tfoot" then
				while #stack > 1 and stack[#stack].Name ~= token.Name do
					local name=stack[#stack].Name
					if name == "td" or name == "th" or (token.Name ~= "tr" and name == "tr")
						or (token.Name == "table" and (name == "thead" or name == "tbody" or name == "tfoot")) then table.remove(stack) else break end
				end
			end
			if token.Name == "select" or token.Name == "optgroup" then
				if stack[#stack].Name == "option" then table.remove(stack) end
				if token.Name == "select" and stack[#stack].Name == "optgroup" then table.remove(stack) end
			end
			if token.Name == "dl" and (stack[#stack].Name == "dt" or stack[#stack].Name == "dd")
				and stack[#stack - 1].Name == "dl" then table.remove(stack) end
			if (token.Name == "ul" or token.Name == "ol") and stack[#stack].Name == "li"
				and stack[#stack - 1].Name == token.Name then table.remove(stack) end
			local found = nil
			for index = #stack, 2, -1 do
				if stack[index].Name == token.Name then found = index; break end
			end
			if found then
				if found < #stack then diagnostic("implicit-close", "Unclosed children closed by </" .. token.Name .. ">", token.Position) end
				for _ = #stack, found, -1 do table.remove(stack) end
			else diagnostic("unmatched-end-tag", "No open element for </" .. token.Name .. ">", token.Position) end
		end
	end
	if #textParts > 0 then append(Node.text(table.concat(textParts))) end
	if #stack > 1 then diagnostic("unclosed-elements", "Open elements were closed at end of input", #source + 1) end
	local attachedShadowRoots = if options.DisableDeclarativeShadowRoots then 0 else attachDeclarativeShadowRoots(document)
	document.NodeCount = nodeCount - attachedShadowRoots
	return document
end

-- Fragment parsing retains the public parseHTML contract. Full documents use
-- insertion modes while consuming tokens, never a reordered fragment tree.
function Parser.parseFragment(source: string,context: any,options: any?): any
	assert(type(context)=="table" and context.Kind=="Element","HTML fragment requires an element context")
	return DocumentBuilder.parse(source,options,context)
end
function Parser.parseDocument(source: string, options: any?): any
    return DocumentBuilder.parse(source, options)
end
function Parser.newDocument(source: string,options: any?): any
	return DocumentBuilder.new(source,options)
end
function Parser.parseDocumentBytes(bytes: string,options: any?): any
	return require(script.Parent.ByteDocument).parse(bytes,options,Parser.parseDocument)
end
function Parser.newDocumentBytes(bytes: string,options: any?): any?
	return require(script.Parent.ByteDocument).session(bytes,options,Parser.newDocument)
end

return Parser
