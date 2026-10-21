--!strict
local Syntax=require(script.Parent.Syntax)
local Selectors=require(script.Parent.Selectors)
local AuthorRules={}
function AuthorRules.declarations(text: string): any
	local result={}
	for _,item in Syntax.declarations(text) do
		local name,value=item.Text:match('^%s*([%w_%-]+)%s*:%s*(.-)%s*$')
		if name then table.insert(result,{Name=if name:sub(1,2)=='--' then name else name:lower(),Value=value,Important=item.Important}) end
	end
	return result
end
function AuthorRules.collect(document: any,diagnostic: any,extra: string?,keyframes: any?): any
	local rules={};local bytes=0
	local function parse(text: string)
		bytes+=#text;assert(bytes<=1024*1024,'CSS stylesheet budget exceeded')
		local index=1
		while index<=#text do
			local header,nextIndex,delimiter=Syntax.scan(text,index,'{;}');index=nextIndex
			if not header:find('%S') and delimiter=='' then break end
			if delimiter~='{' then diagnostic('unsupported-css-rule',header);continue end
			local body,after=Syntax.scan(text,index,'}');index=after
			local animationName=header:match('^%s*@keyframes%s+([%w_-]+)%s*$')
			if animationName and keyframes then keyframes(animationName,body);continue end
			if header:match('^%s*@') then diagnostic('unsupported-css-at-rule',header);continue end
			local selectors,valid={},true
			for _,entry in Selectors.list(header) do local compiled=Selectors.compile(entry);if not compiled then valid=false;break end;table.insert(selectors,compiled) end
			if not valid or #selectors==0 then diagnostic('unsupported-css-selector',header);continue end
			table.insert(rules,{Selectors=selectors,Declarations=AuthorRules.declarations(body),Order=#rules+1})
			assert(#rules<=4096,'CSS rule budget exceeded')
		end
	end
	local function visit(node: any)
		if node.Kind=='Element' and node.Name=='style' then
			local a=node.Attributes;local media=(a.media or ''):lower()
			if media~='' and media~='all' and media~='screen' then diagnostic('unsupported-css-media',media);return end
			if a.type and a.type~='' and a.type:lower()~='text/css' then return end
			local pieces={};for _,c in node.Children do if c.Kind=='Text' then table.insert(pieces,c.Text) end end;parse(table.concat(pieces))
		end
		for _,c in node.Children do visit(c) end
	end
	visit(document);if extra then parse(extra) end;return rules
end
function AuthorRules.match(rules: any,node: any,states: any?): any
	local result={}
	for _,rule in rules do
		local highest
		for _,selector in rule.Selectors do
			if Selectors.matches(node,selector,states) then
				local greater=not highest
				if highest then for i=1,3 do if selector.Specificity[i]~=highest[i] then greater=selector.Specificity[i]>highest[i];break end end end
				if greater then highest=selector.Specificity end
			end
		end
		if highest then for _,entry in rule.Declarations do table.insert(result,{Name=entry.Name,Value=entry.Value,Important=entry.Important,Rank={0,highest[1],highest[2],highest[3],rule.Order},CSS=true}) end end
	end
	return result
end
local function dependsOn(selector: any,state: string): boolean
	for _,part in selector.Parts do
		for _,test in part.Tests do
			if test.Kind=='pseudo' then
				if test.Name==state or (state=='focus' and test.Name=='focus-within') then return true end
				for _,nested in test.Selectors or {} do if dependsOn(nested,state) then return true end end
				for _,nested in test.Filter or {} do if dependsOn(nested,state) then return true end end
			end
		end
	end
	return false
end
-- Stable visual state identity, independent of the particular hit on an inert shape.
local stateSelectors=setmetatable({},{__mode='k'})
local function relevantSelectors(rules: any,state: string): any
 local byState=stateSelectors[rules]
 if not byState then byState={};stateSelectors[rules]=byState end
 if byState[state] then return byState[state] end
 local relevant={}
 for _,rule in rules do for _,selector in rule.Selectors do
  if dependsOn(selector,state) then table.insert(relevant,selector) end
 end end
 byState[state]=relevant;return relevant
end
function AuthorRules.stateKey(rules: any,document: any,state: string,states: any): string
 local relevant=relevantSelectors(rules,state)
 if #relevant==0 then return '' end
 local matches={};local index=0
 local function visit(node)
  if node.Kind=='Element' then
   for _,selector in relevant do index+=1;if Selectors.matches(node,selector,states) then table.insert(matches,tostring(index)) end end
  end
  for _,child in node.Children or {} do visit(child) end
 end
 visit(document);return table.concat(matches,',')
end
function AuthorRules.stateChanges(rules: any,document: any,state: string,before: any,after: any): boolean
	local relevant=relevantSelectors(rules,state)
	if #relevant==0 then return false end
	local function visit(node: any): boolean
		if node.Kind=='Element' then
			for _,selector in relevant do
				if Selectors.matches(node,selector,before)~=Selectors.matches(node,selector,after) then return true end
			end
		end
		for _,child in node.Children or {} do if visit(child) then return true end end
		return false
	end
	return visit(document)
end
return AuthorRules
