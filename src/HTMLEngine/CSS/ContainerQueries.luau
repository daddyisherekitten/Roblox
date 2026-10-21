--!strict
-- Choose one ancestor supporting every requested size axis, then evaluate.
local ContainerQueries={}
local MediaQueries=require(script.Parent.MediaQueries)
local Tokens=require(script.Parent.MediaSyntax)
local StyleQueries=require(script.Parent.ContainerStyleQueries)
local Variables=require(script.Parent.Variables)
local ScrollQueries=require(script.Parent.ContainerScrollQueries)
local forbidden={none=true,['not']=true,['and']=true,['or']=true,default=true,initial=true,inherit=true,unset=true,revert=true,['revert-layer']=true}
local function resolver(token)
	if token.Kind=='function'and token.Value=='style'then return StyleQueries.compile(token)end
	if token.Kind=='function'and token.Value=='scroll-state'then return ScrollQueries.compile(token)end
	if token.Kind~='block'or token.Open~='('then return nil end
	local parts,axis,featureName,variables={},nil,nil,{}
	local function dependencies(items)
		for _,part in items do if part.Kind=='function'and part.Value=='var'then local first=part.Items[1];if first and first.Kind=='ident'then variables[first.Decoded or first.Value]=true end end;if part.Items then dependencies(part.Items)end end
	end
	dependencies(token.Items)
	for _,part in token.Items do
		local name=if part.Kind=='ident'then part.Value else ''
		local prefix,base='',name
		if name:sub(1,4)=='min-'or name:sub(1,4)=='max-'then prefix,base=name:sub(1,4),name:sub(5)end
		if ({width=true,height=true,['inline-size']=true,['block-size']=true,['aspect-ratio']=true,orientation=true})[base]then featureName=base end
		if base=='inline-size'or base=='block-size'then
			axis=if base=='inline-size'then 'inline'else 'block'
			part=table.clone(part);part.Value,part.Raw=prefix..'width',prefix..'width'
		end
		table.insert(parts,part)
	end
	local dynamic=next(variables)~=nil
	if dynamic and not featureName then return nil end -- Let nested condition groups resolve their own features.
	if not axis and not dynamic then return nil end
	local raw='('..Tokens.raw(parts)..')';local skeleton=raw
	if dynamic then
		local dummy={};for name in variables do dummy[name]=if featureName=='orientation'then 'landscape'elseif featureName=='aspect-ratio'then '1'else '0px'end
		skeleton=Variables.substitute(raw,dummy);if not skeleton then return nil end
	end
	local parsed=MediaQueries.compileCondition(skeleton);if not parsed then return nil end
	local function logical(term)
		if term.Operator then for _,child in term.Terms do logical(child)end elseif term.Name=='width'then term.LogicalAxis=axis end
	end
	logical(parsed)
	return if dynamic then {Domain='size-query',Condition=parsed,Source=raw,Axis=axis,Variables=variables,Text=token.Raw}else parsed
end

function ContainerQueries.compile(source: string): any?
	source=source:match("^%s*(.-)%s*$") or ""
	local tokens=Tokens.parse(source);if not tokens then return nil end
	local first=tokens[1];local name=first and first.Kind=='ident'and(first.Decoded or first.Value);local condition=source
	if name and not forbidden[name:lower()]and #tokens>1 then condition=source:sub(first.After)else name=nil end
	local parsed=MediaQueries.compileCondition(condition,resolver);if not parsed then return nil end
	local function allowed(term)
		if term.Operator then for _,child in term.Terms do if not allowed(child)then return false end end;return true end
		if term.Domain=='size-query'then return allowed(term.Condition)end
		return term.Domain=='style-query'or term.Domain=='scroll-query'or term.Name=='width'or term.Name=='height'or term.Name=='aspect-ratio'or term.Name=='orientation'
	end
	if not allowed(parsed)then return nil end
	local styleNames={};local scroll=false
	local function dependencies(term)
		if term.Operator then for _,child in term.Terms do dependencies(child)end
		elseif term.Domain=='style-query'then dependencies(term.Condition)
		elseif term.Domain=='scroll-query'then scroll=true
		elseif term.Domain=='size-query'then for name in term.Variables do styleNames[name]=true end
		elseif term.Domain=='style'then
			if term.Name then styleNames[term.Name]=true end
			local function variables(tokens)
				for _,token in tokens do if token.Kind=='ident'and(token.Decoded or token.Value):sub(1,2)=='--'then styleNames[token.Decoded or token.Value]=true end;if token.Items then variables(token.Items)end end
			end
			if term.Range then for _,part in term.Range do variables(part)end elseif term.Value then variables(Tokens.parse(term.Value)or{})end
		end
	end
	dependencies(parsed);return {Name=name,Condition=parsed,StyleNames=styleNames,HasScroll=scroll}
end

function ContainerQueries.matches(queries: any?,environment: any?): boolean
	for _,query in queries or {} do
		if not environment then return false end
		local function eligible(candidate)
			if query.Name then local found=false;for _,name in candidate.Names or{}do if name==query.Name then found=true;break end end;if not found then return false end end
			local function axes(term)
				if term.Operator then for _,child in term.Terms do if not axes(child)then return false end end;return true end
				if term.Domain=='style-query'then return candidate.StyleEligible~=false end
				if term.Domain=='scroll-query'then return candidate.ScrollEligible==true end
				if term.Domain=='size-query'then return axes(term.Condition)end
				if term.LogicalAxis then
					local vertical=(candidate.QueryWritingMode or 'horizontal-tb')~='horizontal-tb'
					return if (term.LogicalAxis=='inline')~=vertical then candidate.WidthEligible~=false else candidate.HeightEligible~=false
				end
				if term.Name=='width'then return candidate.WidthEligible~=false elseif term.Name=='height'then return candidate.HeightEligible~=false end
				return candidate.WidthEligible~=false and candidate.HeightEligible~=false
			end
			return axes(query.Condition)
		end
		local selected
		for _,candidate in environment.Ancestors or{environment}do if eligible(candidate)then selected=candidate;break end end
		local function evaluate(term,env)
			if term.Domain=='scroll-query'then return ScrollQueries.evaluate(term,env)end
			if term.Domain~='size-query'then return StyleQueries.evaluate(term,env)end
			local substituted=Variables.substitute(term.Source,env.Custom or{});if not substituted then return nil end
			local parsed=MediaQueries.compileCondition(substituted);if not parsed then return nil end
			local function logical(test)
				if test.Operator then for _,child in test.Terms do logical(child)end elseif test.Name=='width'and term.Axis then test.LogicalAxis=term.Axis end
			end
			logical(parsed);return MediaQueries.evaluateCondition(parsed,env)
		end
		if not selected or not MediaQueries.matchesCondition(query.Condition,selected,evaluate)then return false end
	end
	return true
end

return ContainerQueries
