--!strict
-- Style queries inspect computed custom-property values of one ancestor.
-- Registered properties reuse the renderer's typed computation, including
-- defaults/inheritance; unregistered token streams retain case and whitespace.
local Tokens=require(script.Parent.MediaSyntax)
local Media=require(script.Parent.MediaQueries)
local Variables=require(script.Parent.Variables)
local Registered=require(script.Parent.RegisteredProperties)
local Units=require(script.Parent.LengthUnits)
local Length=require(script.Parent.LengthExpression)
local Queries={}
local function name(token)
	local value=token and token.Kind=='ident'and(token.Decoded or token.Value)
	return if value and value:sub(1,2)=='--'and #value>2 then value else nil
end
local function source(tokens)
	local out={};for index,token in tokens do table.insert(out,(if index==1 then ''elseif token.Space then ' 'else '/**/')..token.Raw)end;return table.concat(out)
end
local function feature(tokens)
	local property=name(tokens[1])
	if property and #tokens==1 then return {Domain='style',Name=property,Boolean=true}end
	if property and tokens[2]and tokens[2].Value==':'then
		local values={table.unpack(tokens,3)}
		if #values>=2 and values[#values].Kind=='ident'and values[#values].Value=='important'and values[#values-1].Value=='!'then table.remove(values);table.remove(values)end
		for _,token in values do if token.Kind=='bad'or token.Kind=='delim'and (';<>=!'):find(token.Value,1,true)then return nil end end
		return {Domain='style',Name=property,Value=source(values)}
	end
	local parts,operators,current={},{},{}
	for _,token in tokens do
		if token.Kind=='delim'and({['<']=true,['>']=true,['<=']=true,['>=']=true,['=']=true})[token.Value]then
			table.insert(parts,current);table.insert(operators,token.Value);current={}
		else table.insert(current,token)end
	end
	table.insert(parts,current)
	if #operators<1 or #operators>2 then return nil end
	local found=false;for _,part in parts do if #part==0 then return nil end;if #part==1 and name(part[1])then found=true end end
	if not found or #operators==2 and(operators[1]:sub(1,1)~=operators[2]:sub(1,1)or operators[1]=='='or #parts[2]~=1 or not name(parts[2][1]))then return nil end
	return {Domain='style',Range=parts,Comparisons=operators}
end
function Queries.compile(token)
	local function resolve(part)
		if part.Kind=='block'and part.Open=='('then local result=feature(part.Items);if result then result.Text=part.Raw end;return result end
		return nil
	end
	local direct=feature(token.Items)
	local parsed=direct or Media.compileCondition('('..source(token.Items)..')',resolve)
	local function valid(term)
		if not term then return false end
		if term.Operator then for _,child in term.Terms do if not valid(child)then return false end end;return true end
		return term.Domain=='style'
	end
	return if valid(parsed)then {Domain='style-query',Condition=parsed,Text=token.Raw}else nil
end
local function signature(value)
	if value==nil then return nil end
	local tokens=Tokens.parse(value);if not tokens then return nil end
	local result={};for index,token in tokens do
		if token.Kind=='bad'then return nil end
		table.insert(result,(if index>1 and token.Space then ' 'else '')..token.Kind..':'..#token.Raw..':'..token.Raw)
	end;return table.concat(result,'|')
end
local function context(env)
	return {FontSize=env.QueryFontSize or 16,RootFontSize=env.QueryRootFontSize or 16,
		ViewportWidth=env.ViewportWidth or env.Width or 0,ViewportHeight=env.ViewportHeight or env.Height or 0,
		WritingMode=env.QueryWritingMode,Color=env.Style and env.Style.Color,ColorAlpha=env.Style and env.Style.ColorAlpha}
end
local factors={deg={'angle',1},grad={'angle',.9},rad={'angle',180/math.pi},turn={'angle',360},
	s={'time',1},ms={'time',.001},hz={'frequency',1},khz={'frequency',1000},dppx={'resolution',1},x={'resolution',1},dpi={'resolution',1/96},dpcm={'resolution',2.54/96}}
local function numeric(tokens,env)
	local text=source(tokens);if #tokens==1 and name(tokens[1])then text='var('..name(tokens[1])..')'end
	text=Variables.substitute(text,env.Custom or{});if text==nil then return nil end
	local parsed=Tokens.parse(text);if not parsed then return nil end
	local token=parsed[1]
	if #parsed==1 then
		if token.Kind=='number'then return 'number',token.Value
		elseif token.Kind=='percentage'then return 'percentage',token.Value
		elseif token.Kind=='dimension'then
			local factor=factors[token.Unit];if factor then return factor[1],token.Value*factor[2]end
			local scale=Units.scale(token.Unit,context(env));if scale then return 'length',token.Value*scale end
		end
	end
	local number=Length.number(text);if number~=nil then return 'number',number end
	local length=Length.parse(text,context(env));if not length then return nil end
	if not length.Percent then return 'length',length.Value end
	return nil
end
function Queries.evaluate(test,env)
	if test.Domain=='style-query'then return Media.matchesCondition(test.Condition,env,Queries.evaluate)end
	local custom=env.Custom or{};local registry=env.PropertyRegistry or{}
	if test.Range then
		local kind,number=numeric(test.Range[1],env);if not kind then return false end
		for index,op in test.Comparisons do
			local nextKind,nextNumber=numeric(test.Range[index+1],env);if not nextKind then return false end
			if kind=='number'and number==0 and nextKind=='length'then kind='length'elseif nextKind=='number'and nextNumber==0 and kind=='length'then nextKind='length'end
			if kind~=nextKind then return false end
			local accepted=if op=='<'then number<nextNumber elseif op=='>'then number>nextNumber elseif op=='<='then number<=nextNumber elseif op=='>='then number>=nextNumber else math.abs(number-nextNumber)<=1e-9*math.max(1,math.abs(number),math.abs(nextNumber))
			if not accepted then return false end;kind,number=nextKind,nextNumber
		end;return true
	end
	local actual=custom[test.Name]
	if test.Boolean then
		local registration=registry[test.Name];local initial=registration and Registered.compute(registration,registration.Initial,context(env))
		return signature(actual)~=signature(initial)
	end
	local keyword=test.Value:lower()
	if keyword=='revert'or keyword=='revert-layer'then return false end
	local substituted=Variables.substitute(test.Value,custom)
	local expected
	if substituted~=nil then expected=Variables.compute({[test.Name]=substituted},env.ParentCustom,registry,context(env))[test.Name]
	elseif registry[test.Name]then expected=Variables.compute({[test.Name]='unset'},env.ParentCustom,registry,context(env))[test.Name]end
	return signature(actual)==signature(expected)
end
return Queries
