--!strict
--!optimize 2
-- Data-only selectors shared by the SVG cascade; no GUI or interaction state.
local Syntax=require(script.Parent.Syntax)
local Validity=require(script.Parent.Parent.Controls.Validity)
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local AttributeStore=require(script.Parent.Parent.DOM.AttributeStore)
local EditingHost=require(script.Parent.Parent.DOM.EditingHost)
local Heading=require(script.Parent.Parent.DOM.Heading)
local FormOwner=require(script.Parent.Parent.DOM.FormOwner)
local DocumentMode=require(script.Parent.Parent.DOM.DocumentMode)
local DocumentAccessors=require(script.Parent.Parent.DOM.DocumentAccessors)
local FormSelectors=require(script.Parent.FormSelectors)
local ControlState=require(script.Parent.Parent.Controls.State)
local ControlDefaults=require(script.Parent.Parent.Controls.Defaults)
local Eligibility=require(script.Parent.Parent.Controls.ValidationEligibility)
local WorkContext=require(script.Parent.Parent.WorkContext)
local Directionality=require(script.Parent.Directionality)
local LanguageRange=require(script.Parent.LanguageRange)
local Selectors={}
local HTML='http://www.w3.org/1999/xhtml'
-- HTML 4.16.2 defines these value comparisons even where the legacy attribute
-- has no behavior on the particular HTML element. Custom values remain exact.
local INSENSITIVE_VALUES=table.freeze({accept=true,['accept-charset']=true,align=true,alink=true,axis=true,bgcolor=true,charset=true,checked=true,clear=true,codetype=true,color=true,compact=true,declare=true,defer=true,dir=true,direction=true,disabled=true,enctype=true,face=true,frame=true,hreflang=true,['http-equiv']=true,lang=true,language=true,link=true,media=true,method=true,multiple=true,nohref=true,noresize=true,noshade=true,nowrap=true,readonly=true,rel=true,rev=true,rules=true,scope=true,scrolling=true,selected=true,shape=true,target=true,text=true,type=true,valign=true,valuetype=true,vlink=true})
local function namespace(node: any): string return node.NamespaceURI or HTML end
local function documentRoot(node: any): boolean
	return node.Parent~=nil and node.Parent.Kind=='Document'and DocumentAccessors.root(node.Parent)==node
end
local function link(node: any): boolean
	local name=ElementNames.htmlName(node)
	if name=='a'or name=='area'then return node.Attributes.href~=nil end
	if not ElementNames.matches(node,'a','http://www.w3.org/2000/svg')then return false end
	return node.Attributes.href~=nil or AttributeStore.expanded(node,'http://www.w3.org/1999/xlink','href')~=nil
end
local function htmlDocument(node: any): boolean
	local document=DocumentMode.document(node)
	return not document or document.IsHTML~=false
end
-- Fold the selector, never the stored DOM name. Script-created uppercase HTML
-- local names cannot match the lowercased HTML selector. XML stays exact, and
-- adoption must take effect without rebuilding the compiled selector.
local function named(node: any,actual: string,value: string,lowered: string,htmlName: boolean): boolean
	if actual~=value and actual~=lowered then return false end
	if value==lowered or not htmlName then return actual==value end
	return actual==(if htmlDocument(node)then lowered else value)
end
local EDITABLE_INPUTS=table.freeze({text=true,search=true,url=true,tel=true,email=true,password=true,date=true,['datetime-local']=true,month=true,week=true,time=true,number=true})
local PLACEHOLDER_INPUTS=table.freeze({text=true,search=true,url=true,tel=true,email=true,password=true,number=true})
local SIMPLE_PSEUDOS=table.freeze({root=true,scope=true,empty=true,['first-child']=true,['last-child']=true,['only-child']=true,['first-of-type']=true,['last-of-type']=true,['only-of-type']=true,hover=true,active=true,focus=true,['focus-visible']=true,['focus-within']=true,['popover-open']=true,modal=true,fullscreen=true,disabled=true,enabled=true,['read-only']=true,['read-write']=true,checked=true,indeterminate=true,['placeholder-shown']=true,valid=true,invalid=true,['user-invalid']=true,['user-valid']=true,open=true,['any-link']=true,link=true,visited=true,target=true,defined=true,required=true,optional=true,default=true,['in-range']=true,['out-of-range']=true})
local trim=Syntax.trim
function Selectors.list(text: string): any
	text=Syntax.preprocess(text)
	local result,index={},1
	while index<=#text do local item,nextIndex=Syntax.scan(text,index,',',nil,true);table.insert(result,trim(item));index=nextIndex end
	if text:match(',[ \t\n\r\f]*$') then table.insert(result,'') end
	return result
end
local function previous(node: any): any
	local last
	for _, sibling in (node.Parent and node.Parent.Children) or {} do
		if sibling == node then return last end
		if sibling.Kind == 'Element' then last = sibling end
	end
	return nil
end

-- Count directly instead of allocating two filtered sibling arrays per pseudo.
-- Do not retain DOM-derived indexes: scripts may reorder/reparent children.
local function siblingPosition(node: any, ofType: boolean, filter: any?, states: any?, scope: any?): (number, number)
	local function accepted(sibling)
		if sibling.Kind~='Element'or ofType and((sibling.LocalName or sibling.Name)~=(node.LocalName or node.Name)or namespace(sibling)~=namespace(node))then return false end
		if not filter then return true end
		for _,test in filter do if Selectors.matches(sibling,test,states,scope)then return true end end
		return false
	end
	if not node.Parent then return if accepted(node)then 1 else 0,1 end
	local at, count = 0, 0
	for _, sibling in node.Parent.Children do
		if accepted(sibling) then
			count += 1
			if sibling == node then at = count end
		end
	end
	return at, count - at + 1
end
local function nth(test: any,index: number): boolean
	local a,b=test.Coefficient,test.Offset
	return if a==0 then index==b else (index-b)/a>=0 and (index-b)%a==0
end
local function disabled(node: any): boolean
	local name=ElementNames.htmlName(node)
	if not name then return false end
	local definition=node.CustomElementDefinition
	local face=definition and definition.FormAssociated and definition.Name==definition.LocalName and node.CustomElementState=='custom'
	if not face and name~='button' and name~='fieldset' and name~='input' and name~='optgroup' and name~='option' and name~='select' and name~='textarea' then return false end
	if node.Attributes.disabled~=nil then return true end
	if name=='option' and ElementNames.html(node.Parent,'optgroup')and node.Parent.Attributes.disabled~=nil then return true end
	local branch,ancestor=node,node.Parent
	while ancestor do
		if (name=='option'or name=='optgroup')and ElementNames.html(ancestor,'select')and disabled(ancestor)then return true end
		if ElementNames.html(ancestor,'fieldset')and ancestor.Attributes.disabled~=nil then
			local firstLegend
			for _,child in ancestor.Children do if ElementNames.html(child,'legend')then firstLegend=child;break end end
			if branch~=firstLegend then return true end
		end
		branch,ancestor=ancestor,ancestor.Parent
	end
	return false
end
local function readWrite(node: any): boolean
	local name=ElementNames.htmlName(node)
	if not name then return false end
	if name=='textarea' then return node.Attributes.readonly==nil and not disabled(node) end
	if name~='input' then return EditingHost.isEditable(node)end
	local kind=ControlDefaults.kind(node)
	return EDITABLE_INPUTS[kind]==true and node.Attributes.readonly==nil and not disabled(node)
end
local function formState(node: any,states: any?): any
	local current=states and states.GetFormState and states.GetFormState(node)
		or states and states['form-state'] and states['form-state'][node]
	if current then return current end
	return ControlState.create(node)
end
local function optionSelected(node: any,states: any?): boolean
	if states and states.GetOptionSelected then return states.GetOptionSelected(node)end
	local parent=node.Parent
	while parent do
		WorkContext.checkpoint()
		if ElementNames.html(parent,'select')then
			local state=states and states['form-state']and states['form-state'][parent]
			if state and state.SelectedOptions then return state.SelectedOptions[node]==true end
			break
		end
		parent=parent.Parent
	end
	return node.Attributes.selected~=nil
end
Selectors.optionSelected=optionSelected
local function invalid(node: any,states: any?): boolean
	local name=ElementNames.htmlName(node)
	if not name then return false end
	local definition=node.CustomElementDefinition
	if name=='form' or name=='fieldset' then
		local root=node;if name=='form'then while root.Parent do root=root.Parent end end
		local pending={root}
		while #pending>0 do
			local candidate=table.remove(pending);local d=candidate.CustomElementDefinition
			local candidateName=ElementNames.htmlName(candidate)
			local eligible=candidateName and(candidateName=='input'or candidateName=='textarea'or candidateName=='select'or candidateName=='button'or d and d.FormAssociated and d.Name==d.LocalName and candidate.CustomElementState=='custom')
			if eligible then
				if (name=='fieldset'or FormOwner.resolve(candidate)==node)and invalid(candidate,states)then return true end
			end
			for _,child in candidate.Children do table.insert(pending,child)end
		end
		return false
	end
	if definition and definition.FormAssociated and definition.Name==definition.LocalName and node.CustomElementState=='custom' and definition.API and definition.API.Internals then local internals=definition.API.Internals;local flags=internals:Validity(node);return internals:WillValidate(node)and not flags.valid end
	if name~='input' and name~='textarea' and name~='select' and name~='button'then return false end
	local c=formState(node,states)
	if not Eligibility.applies(node,c)then return false end
	local flags=states and states.GetValidity and states.GetValidity(node)or c.Validity
	if flags then return not flags.valid end
	local flags=Validity.read(node,c,function(callback)
		local name=node.Attributes.name or '';if name==''then return end
		local root=node;while root.Parent do WorkContext.checkpoint();root=root.Parent end
		local form=FormOwner.resolve(node);local pending={root}
		while #pending>0 do
			WorkContext.checkpoint();local peer=table.remove(pending)
			if ElementNames.html(peer,'input')and (peer.Attributes.type or ''):lower()=='radio'and (peer.Attributes.name or '')==name and FormOwner.resolve(peer)==form then callback(formState(peer,states))end
			for _,child in peer.Children do table.insert(pending,child)end
		end
	end)
	return not flags.valid
end
function Selectors.compile(text: string,depth: number?,namespaces: any?,forbidHas: boolean?,defaultExemption: string?): any?
	depth=depth or 0;if depth>16 or #text>4096 then return nil end
	text=Syntax.preprocess(text)
	local parts,specificity={}, {0,0,0};local index,relation=1,nil
	local implicitNamespaces=if defaultExemption and namespaces and namespaces['']~=nil then {}else nil
	local function add(s: any) for i=1,3 do specificity[i]+=s[i] end end
	while index<=#text do
		local spaces=text:match('^[ \t\n\r\f]*',index) :: string;index+=#spaces;if index>#text then break end
		if text:sub(index,index+1)=='/*'then index=(text:find('*/',index+2,true)or #text)+2;continue end
		local ch=text:sub(index,index)
		if ch=='>' or ch=='+' or ch=='~' then
			if #parts==0 or relation then return nil end;relation=ch;index+=1;continue
		end
		local part={Tests={},Relation=relation or ' '};relation=nil
		local tag,after=Syntax.identifier(text,index)
		if tag then index=after elseif ch=='*'then tag='*';index+=1 end
		local namespace=namespaces and namespaces['']
		if text:sub(index,index)=='|'then
			local prefix=tag or '';index+=1
			if prefix=='*'then namespace=nil elseif prefix==''then namespace=''else namespace=namespaces and namespaces[prefix];if namespace==nil then return nil end end
			tag,after=Syntax.identifier(text,index)
			if tag then index=after elseif text:sub(index,index)=='*'then tag='*';index+=1 else return nil end
		end
		if namespace~=nil then
			table.insert(part.Tests,{Kind='namespace',Value=namespace})
			if not tag and implicitNamespaces then implicitNamespaces[part]=true end
		end
		if tag and tag~='*'then table.insert(part.Tests,{Kind='tag',Value=tag,LowerValue=DocumentMode.fold(tag)});specificity[3]+=1 end
		local start=index
		while index<=#text do
			ch=text:sub(index,index)
			if ch=='.' or ch=='#' then
				local name,nextIndex=Syntax.identifier(text,index+1);if not name then return nil end
				table.insert(part.Tests,{Kind=if ch=='#' then 'id' else 'class',Value=name});specificity[if ch=='#' then 1 else 2]+=1;index=nextIndex
			elseif ch=='[' then
				local body,nextIndex,stop=Syntax.scan(text,index+1,']',nil,true);if stop~=']' then return nil end
				body=trim(body)
				local name,nameEnd=Syntax.identifier(body,1)
				local attrNamespace
				if body:sub(1,1)=='*'and body:sub(2,2)=='|'then name='*';nameEnd=2 end
				if body:sub(nameEnd,nameEnd)=='|'and body:sub(nameEnd+1,nameEnd+1)~='='then
					local prefix=name or '';if prefix~='*'then attrNamespace=if prefix==''then ''else namespaces and namespaces[prefix];if attrNamespace==nil then return nil end end
					name,nameEnd=Syntax.identifier(body,nameEnd+1)
				else attrNamespace=''end
				if not name then return nil end
				local rest=trim(body:sub(nameEnd))
					local test={Kind='attribute',Name=name,LowerName=DocumentMode.fold(name)}
				test.Namespace=attrNamespace
				if rest~='' then
					local op,value=rest:match('^([~|^$*]?=)[ \t\n\r\f]*(.-)[ \t\n\r\f]*$');if not op then return nil end
					local quote=value:sub(1,1)
					local decoded,ending
					if quote=='"' or quote=="'" then decoded,ending=Syntax.stringToken(value,1)
					else decoded,ending=Syntax.identifier(value,1)end
					if decoded==nil then return nil end
					local tail=value:sub((Syntax.skip(value,ending)));local flag
					if tail~=''then
						flag,ending=Syntax.identifier(tail,1)
						if not flag or Syntax.skip(tail,ending)<=#tail or flag:lower()~='i'and flag:lower()~='s'then return nil end
					end
					value=decoded
					test.Operator=op;test.Value=value;test.Insensitive=flag and flag:lower()=='i'
				end
				table.insert(part.Tests,test);specificity[2]+=1;index=nextIndex
			elseif ch==':' then
				local name,nextName=Syntax.identifier(text,index+1);if not name then return nil end;index=nextName;name=name:lower()
				local test={Kind='pseudo',Name=name:lower()}
				if text:sub(index,index)=='(' then
					local body,nextIndex,stop=Syntax.scan(text,index+1,')',nil,true);if stop~=')' then return nil end;index=nextIndex
					if name=='is' or name=='where' or name=='not' or name=='has' then
						if name=='has'and forbidHas then return nil end
						test.Selectors={};local highest={0,0,0}
						for _,entry in Selectors.list(body) do
							if name=='has'and entry==''then return nil end
							local source=if name=='has' then ':scope '..entry else entry
							local compiled=Selectors.compile(source,depth+1,namespaces,forbidHas or name=='has',if name=='has'then 'relative'else 'subject')
							-- :is/:where use forgiving lists: unsupported branches and
							-- pseudo-elements cannot invalidate a valid sibling branch.
							if not compiled then if name=='is'or name=='where'then continue else return nil end end
							if name=='has' then compiled.Specificity[2]-=1 end
							table.insert(test.Selectors,compiled)
							for i=1,3 do if compiled.Specificity[i]~=highest[i] then if compiled.Specificity[i]>highest[i] then highest=compiled.Specificity end;break end end
						end
						if #test.Selectors==0 and name~='is'and name~='where'then return nil end;if name~='where' then add(highest) end
					elseif name=='lang'then
						test.Languages={}
						for _,language in Selectors.list(body)do
							local quote=language:sub(1,1)
							if quote=='"'or quote=="'"then local value=Syntax.string(language);if value==nil then return nil end;language=value
							else local value,ending=Syntax.identifier(language);if not value or ending<=#language then return nil end;language=value end
							table.insert(test.Languages,LanguageRange.compile(language))
						end
						if #test.Languages==0 then return nil end;specificity[2]+=1
					elseif name=='dir'then
						local ident,ending=Syntax.identifier(body,(Syntax.skip(body,1)))
						if not ident or Syntax.skip(body,ending)<=#body then return nil end
						-- Unknown direction identifiers are valid selectors that match
						-- nothing; strings and multiple tokens are syntax errors.
						test.Value=ident:lower();specificity[2]+=1
					elseif name=='heading'then
						local levels=Syntax.integerList(body);if not levels then return nil end
						test.Levels={};for _,level in levels do test.Levels[level]=true end;specificity[2]+=1
					elseif name=='state' then
						local ident,ending=Syntax.identifier(body,(Syntax.skip(body,1)))
						if not ident or Syntax.skip(body,ending)<=#body then return nil end
						test.Value=ident;specificity[2]+=1
					elseif name=='nth-child' or name=='nth-last-child' or name=='nth-of-type' or name=='nth-last-of-type' then
						local a,b,after=Syntax.anb(body);if a==nil then return nil end
						local remainder=body:sub((Syntax.skip(body,after)))
						if remainder~=''then
							local keyword,ending=Syntax.identifier(remainder,1)
							if not keyword or keyword:lower()~='of'then return nil end
							local of=remainder:sub((Syntax.skip(remainder,ending)))
							if name=='nth-of-type'or name=='nth-last-of-type'then return nil end
							test.Filter={};local highest={0,0,0}
							for _,entry in Selectors.list(of)do local compiled=Selectors.compile(entry,depth+1,namespaces,forbidHas);if not compiled then return nil end;table.insert(test.Filter,compiled)
								for i=1,3 do if compiled.Specificity[i]~=highest[i]then if compiled.Specificity[i]>highest[i]then highest=compiled.Specificity end;break end end
							end
							if #test.Filter==0 then return nil end;add(highest)
						end
						test.Coefficient=a;test.Offset=b;specificity[2]+=1
					else return nil end
				else
					if not SIMPLE_PSEUDOS[test.Name]and test.Name~='heading'then return nil end;specificity[2]+=1
				end
				table.insert(part.Tests,test)
			elseif text:sub(index,index+1)=='/*'then index=(text:find('*/',index+2,true)or #text)+2
			else break end
		end
		if #part.Tests==0 and not tag and start==index and ch~='*' and text:sub(start-1,start-1)~='*' then return nil end
		-- Only bare hover/active compounds have this legacy restriction. A
		-- universal/namespace selector is not a type selector; functional
		-- arguments are exempt, including their recursively compiled filters.
		if depth==0 then
			local hover,other=false,false
			for _,test in part.Tests do
				if test.Kind=='pseudo'and(test.Name=='hover'or test.Name=='active')then hover=true
				elseif test.Kind~='namespace'then other=true end
			end
			part.QuirksHover=hover and not other
		end
		table.insert(parts,part);if #parts>128 then return nil end
		if index<=#text and not text:sub(index,index):match('[ \t\n\r\f>+~]') then return nil end
	end
	if #parts==0 or relation then return nil end
	-- Logical arguments exempt only their implicit subject namespace. Relative
	-- selectors instead exempt the synthetic anchor; all author compounds,
	-- explicit types/universals and ancestor namespaces keep their constraints.
	local exempt=if defaultExemption=='subject'then parts[#parts]elseif defaultExemption=='relative'then parts[1]else nil
	if exempt and implicitNamespaces and implicitNamespaces[exempt]then table.remove(exempt.Tests,1)end
	return {Parts=parts,Specificity=specificity}
end
local function matchesPart(node: any,part: any,states: any?,scope: any?,identifier: any): boolean
	if not node or node.Kind~='Element' then return false end
	-- Only semantic pseudos need this lookup; simple class/type/sibling queries
	-- retain their linear scan and never confuse a source prefix with a tag.
	local htmlName,nameRead=nil,false
	for _,test in part.Tests do
		local value=test.Value
		if test.Kind=='namespace'then if namespace(node)~=value then return false end
		elseif test.Kind=='tag' then if not named(node,node.LocalName or node.Name,value,test.LowerValue,namespace(node)==HTML)then return false end
		elseif test.Kind=='id' then if not identifier(node.Attributes.id,value)then return false end
		elseif test.Kind=='class' then
			local found=false;for word in (node.Attributes.class or ''):gmatch('[^ \t\n\r\f]+') do if identifier(word,value)then found=true;break end end;if not found then return false end
		elseif test.Kind=='attribute' then
			local found=false
			for name,entry in node.Attributes do
				local info=node.AttributeNamespaces and node.AttributeNamespaces[name]
				local localName=if info then info.LocalName or name:match('[^:]+$')else name
				local uri=if info then info.NamespaceURI or info.Namespace or ''else ''
				if (test.Namespace==nil or test.Namespace==uri)and named(node,localName,test.Name,test.LowerName,uri==''and namespace(node)==HTML)then
					if not test.Operator then found=true;break end
					local actual,expected=entry,value
					if test.Insensitive or test.Insensitive==nil and uri==''and namespace(node)==HTML and INSENSITIVE_VALUES[localName]and htmlDocument(node)then
						actual=DocumentMode.fold(actual);expected=DocumentMode.fold(expected)
					end
					local op=test.Operator;local match=false
					if op=='='then match=actual==expected
					elseif op=='|='then match=actual==expected or actual:sub(1,#expected+1)==expected..'-'
					elseif expected~=''then
						if op=='^='then match=actual:sub(1,#expected)==expected elseif op=='$='then match=actual:sub(-#expected)==expected elseif op=='*='then match=actual:find(expected,1,true)~=nil
						elseif op=='~='then for word in actual:gmatch('[^ \t\n\r\f]+')do if word==expected then match=true;break end end end
					end
					if match then found=true;break end
				end
			end
			if not found then return false end
		elseif test.Kind=='pseudo' then
			if not nameRead then htmlName=ElementNames.htmlName(node);nameRead=true end
			local name=test.Name
			if test.Selectors then
				local found=false
				if name=='has' then
					for _,selector in test.Selectors do
						local relation=selector.Parts[2] and selector.Parts[2].Relation
						local base=if relation=='+' or relation=='~' then node.Parent else node
						local pending={}
						for _,child in base and base.Children or {} do table.insert(pending,child) end
						while #pending>0 do
							local candidate=table.remove(pending)
							if candidate.Kind=='Element' then
								if Selectors.matches(candidate,selector,states,node) then found=true;break end
								for _,child in candidate.Children do table.insert(pending,child) end
							end
						end
						if found then break end
					end
				else for _,s in test.Selectors do if Selectors.matches(node,s,states,scope) then found=true;break end end end
				if (name=='not' and found) or (name~='not' and not found) then return false end
			elseif name=='lang'then
				local language=LanguageRange.language(node);local found=false
				for _,range in test.Languages do if LanguageRange.matches(language,range)then found=true;break end end
				if not found then return false end
			elseif name=='dir'then
				if test.Value~='ltr'and test.Value~='rtl'then return false end
				local read=states and states['form-state']and function(current)local entry=states['form-state'][current];return entry and entry.Value end
				if Directionality.of(node,read)~=test.Value then return false end
			elseif name=='open'then
				if htmlName=='details'or htmlName=='dialog'then if node.Attributes.open==nil then return false end
				elseif htmlName=='select'then if formState(node,states).SelectList or not states or states.open~=node then return false end
				elseif htmlName~='input'or not states or states.open~=node then return false end
			elseif name=='defined'then
				if htmlName then
					local state=node.CustomElementState
					if state and state~='custom'and state~='uncustomized'or not state and ElementNames.custom(htmlName)then return false end
				end
			elseif name=='any-link'or name=='link'or name=='visited'then
				if not link(node)or name=='visited'then return false end
			elseif name=='target'then if not states or states.target~=node then return false end
			elseif name=='required'or name=='optional'then
				local inputType=ControlDefaults.kind(node)
				local eligible=htmlName=='textarea'or htmlName=='select'or htmlName=='input'and(EDITABLE_INPUTS[inputType]or inputType=='checkbox'or inputType=='radio'or inputType=='file')
				if not eligible or(node.Attributes.required~=nil)~=(name=='required')then return false end
			elseif name=='default'then if not FormSelectors.default(node)then return false end
			elseif name=='in-range'or name=='out-of-range'then
				if htmlName~='input'then return false end
				local outside=FormSelectors.range(node,formState(node,states))
				if outside==nil or outside~=(name=='out-of-range')then return false end
			elseif name=='heading'then
				local level=Heading.level(node)
				if not level or test.Levels and not test.Levels[level]then return false end
			elseif name=='state' then if not node.CustomStates or not node.CustomStates[test.Value]then return false end
			elseif name=='root' then
				if not documentRoot(node)then return false end
			elseif name=='scope' then
				if scope then if node~=scope then return false end elseif not documentRoot(node)then return false end
			elseif name=='empty' then for _,c in node.Children do if c.Kind=='Element' or (c.Kind=='Text' and #c.Text>0) then return false end end
			elseif name=='fullscreen'then if not node.FullscreenFlag then return false end
			elseif name=='popover-open' or name=='modal' then if not (states and states[name] and states[name][node]) then return false end
			elseif name=='disabled' or name=='enabled' then
				local definition=node.CustomElementDefinition
				local eligible=htmlName and(definition and definition.FormAssociated and definition.Name==definition.LocalName and node.CustomElementState=='custom'or htmlName=='button'or htmlName=='fieldset'or htmlName=='input'or htmlName=='optgroup'or htmlName=='option'or htmlName=='select'or htmlName=='textarea')
				if not eligible or disabled(node)~=(name=='disabled') then return false end
			elseif name=='read-only' or name=='read-write' then if not htmlName or readWrite(node)~=(name=='read-write') then return false end
			elseif name=='checked' then
				local kind=(node.Attributes.type or ''):lower()
				if htmlName=='option' then
					if not optionSelected(node,states)then return false end
				elseif htmlName~='input' or (kind~='checkbox' and kind~='radio') or not formState(node,states).Checked then return false end
			elseif name=='indeterminate' then
				local kind=(node.Attributes.type or ''):lower()
				if htmlName=='progress' then if node.Attributes.value~=nil then return false end
				elseif htmlName=='input' and kind=='checkbox' then if not formState(node,states).Indeterminate then return false end
				elseif htmlName=='input' and kind=='radio' then
					local current=node;while current.Parent do current=current.Parent end
					local form=FormOwner.resolve(node)
					local pending={current};while #pending>0 do local other=table.remove(pending)
						if ElementNames.html(other,'input')and(other.Attributes.type or ''):lower()=='radio'and(other.Attributes.name or '')==(node.Attributes.name or '')then
							if FormOwner.resolve(other)==form and formState(other,states).Checked then return false end
						end
						for _,child in other.Children do table.insert(pending,child)end
					end
				else return false end
			elseif name=='placeholder-shown' then
				if (htmlName~='input' and htmlName~='textarea') or node.Attributes.placeholder==nil or formState(node,states).Value~='' then return false end
				if htmlName=='input'and not PLACEHOLDER_INPUTS[ControlDefaults.kind(node)]then return false end
			elseif name=='invalid' or name=='valid' then
				local definition=node.CustomElementDefinition
				if definition and definition.FormAssociated and definition.Name==definition.LocalName and node.CustomElementState=='custom' and definition.API and definition.API.Internals then
				elseif htmlName~='form'and htmlName~='fieldset'and not Eligibility.applies(node,formState(node,states))then return false end
				if invalid(node,states)~=(name=='invalid') then return false end
			elseif name=='user-invalid'or name=='user-valid' then
				if htmlName~='input'and htmlName~='textarea'and htmlName~='select'then return false end
				local state=formState(node,states)
				local inputType=(node.Attributes.type or'text'):lower()
				if state.Disabled or state.ReadOnly or htmlName=='input'and(inputType=='hidden'or inputType=='button'or inputType=='submit'or inputType=='reset')or not(state.UserEdited or state.UserInvalid)or invalid(node,states)~=(name=='user-invalid')then return false end
			elseif name=='hover' or name=='active' or name=='focus' or name=='focus-visible' or name=='focus-within' then
				local hit=states and (states[name] or (name=='focus-within' and states.focus))
				if name~='focus' and name~='focus-visible' and hit then while hit and hit~=node do hit=hit.Parent end end
				if hit~=node then return false end
			else
				local at,reverse=siblingPosition(node,name:find('of-type',1,true)~=nil,test.Filter,states,scope)
				if at==0 then return false end
				if name:sub(1,4)=='nth-' then if not nth(test,if name:find('last') then reverse else at) then return false end
				elseif name:sub(1,6)=='first-' then if at~=1 then return false end
				elseif name:sub(1,5)=='last-' then if reverse~=1 then return false end
				elseif at~=1 or reverse~=1 then return false end
			end
		end
	end
	return true
end
function Selectors.matches(node: any,selector: any,states: any?,scope: any?,parentOf: any?): boolean
 local quirks
 local function identifier(actual,value)
  if actual==nil then return false end
  if actual==value then return true end
  if quirks==nil then quirks=node~=nil and DocumentMode.quirks(node)end
  return quirks and DocumentMode.fold(actual)==DocumentMode.fold(value)
 end
 local function parent(candidate)return if parentOf then parentOf(candidate)else candidate and candidate.Parent end
	local function match(candidate: any,index: number): boolean
		if candidate and selector.Parts[index].QuirksHover then
			if quirks==nil then quirks=DocumentMode.quirks(node)end
			if quirks and not link(candidate)then return false end
		end
		if not matchesPart(candidate,selector.Parts[index],states,scope,identifier) then return false end
		if index==1 then return true end
		local relation=selector.Parts[index].Relation
  if relation=='>' then return match(parent(candidate),index-1)
		elseif relation=='+' then return match(previous(candidate),index-1)
		elseif relation=='~' then
			local children=candidate.Parent and candidate.Parent.Children
			local at=children and table.find(children,candidate)
			if not at then return false end
			-- One reverse scan; repeatedly finding previous(candidate) was quadratic.
			for siblingIndex=at-1,1,-1 do
				local sibling=children[siblingIndex]
				if sibling.Kind=='Element' and match(sibling,index-1) then return true end
			end
			return false
		end
  candidate=parent(candidate)
  while candidate do if match(candidate,index-1) then return true end;candidate=parent(candidate) end
		return false
	end
	return match(node,#selector.Parts)
end
return Selectors
