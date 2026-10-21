--!strict
--!optimize 2
-- Shared @media/matchMedia grammar and three-valued evaluation. Host features
-- describe this renderer's capabilities; they do not invent native OS services.
local Tokens=require(script.Parent.MediaSyntax)
local Length=require(script.Parent.LengthExpression)
local Units=require(script.Parent.LengthUnits)
local Work=require(script.Parent.Parent.WorkContext)
local Media={}
local ranges={width='length',height='length',['device-width']='length',['device-height']='length',
	['aspect-ratio']='ratio',['device-aspect-ratio']='ratio',resolution='resolution',color='integer',
	['color-index']='integer',monochrome='integer',['horizontal-viewport-segments']='integer',['vertical-viewport-segments']='integer'}
local discrete={
	orientation={'Orientation','landscape','portrait landscape'},hover={'Hover','none','none hover'},['any-hover']={'AnyHover','none','none hover'},
	pointer={'Pointer','none','none coarse fine'},['any-pointer']={'AnyPointers','none','none coarse fine'},
	['prefers-reduced-motion']={'ReducedMotion','no-preference','no-preference reduce'},
	['prefers-reduced-transparency']={'ReducedTransparency','no-preference','no-preference reduce'},
	['prefers-reduced-data']={'ReducedData','no-preference','no-preference reduce'},
	['prefers-contrast']={'PreferredContrast','no-preference','no-preference less more custom'},
	['prefers-color-scheme']={'PreferredColorScheme','light','light dark'},['ua-color-scheme']={'UAColorScheme','light','light dark'},
	['forced-colors']={'ForcedColors','none','none active'},['inverted-colors']={'InvertedColors','none','none inverted'},
	update={'Update','fast','none slow fast'},['overflow-block']={'OverflowBlock','scroll','none scroll paged'},['overflow-inline']={'OverflowInline','scroll','none scroll'},
	scripting={'Scripting','enabled','none initial-only enabled'},scan={'Scan','progressive','interlace progressive'},
	['display-mode']={'DisplayMode','browser','browser fullscreen standalone minimal-ui picture-in-picture window-controls-overlay'},
	['color-gamut']={'ColorGamut','srgb','srgb p3 rec2020'},['video-color-gamut']={'VideoColorGamut','srgb','srgb p3 rec2020'},
	['dynamic-range']={'DynamicRange','standard','standard high'},['video-dynamic-range']={'VideoDynamicRange','standard','standard high'},
	['environment-blending']={'EnvironmentBlending','opaque','opaque additive subtractive'},['nav-controls']={'NavigationControls','none','none back'},
	grid={'Grid',0,'0 1'},
}
local forbidden={['not']=true,only=true,['and']=true,['or']=true,layer=true}
local inverse={['<']='>',['>']='<',['<=']='>=',['>=']='<=',['=']='='}
local factors={dppx=1,x=1,dpi=1/96,dpcm=2.54/96}
local function numeric(n)return string.format('%.6g',if n==0 then 0 else n)end
local function identifier(token)return token and token.Kind=='ident'and token.Value end
local function keyword(def,value)return (' '..def[3]..' '):find(' '..value..' ',1,true)~=nil end
local mathFunctions={calc=true,min=true,max=true,clamp=true}
local function relative(items)
	for _,token in items do
		if token.Kind=='dimension'and(Units.font(token.Unit)or Units.contextual(token.Unit))or token.Items and relative(token.Items)then return true end
	end
	return false
end
local function mathSource(items,kind,commas)
	local parts,operand={},true
	for index,token in items do
		if token.Kind=='delim'then
			local op=token.Value
			if operand or not ('+-*/,'):find(op,1,true)or op==','and not commas then return nil end
			if (op=='+'or op=='-')and(not token.Space or not items[index+1]or not items[index+1].Space)then return nil end
			table.insert(parts,op);operand=true;continue
		end
		if not operand then return nil end
		local source
		if token.Kind=='dimension'then
			local scale=if kind=='resolution'then factors[token.Unit]elseif kind=='length'and Units.has(token.Unit)then 1 else nil
			if not scale then return nil end;source=numeric(token.Value*scale)..(if kind=='resolution'then 'px'else token.Unit)
		elseif token.Kind=='function'and mathFunctions[token.Value]then
			local body=mathSource(token.Items,kind,token.Value~='calc');if not body then return nil end;source=token.Value..'('..body..')'
		elseif token.Kind=='block'and token.Open=='('then
			local body=mathSource(token.Items,kind,false);if not body then return nil end;source='('..body..')'
		elseif token.Kind=='number'then source=numeric(token.Value)else return nil end
		table.insert(parts,source);operand=false
	end
	return if not operand then table.concat(parts,' ')else nil
end
local function mathNumber(token)
	if token.Kind=='number'then return token.Value,numeric(token.Value)end
	if token.Kind~='function'or not mathFunctions[token.Value]then return nil end
	local body=mathSource(token.Items,'number',token.Value~='calc');if not body then return nil end
	local parsed=Length.number(token.Value..'('..body..')');if parsed==nil then return nil end
	-- CSS numeric calculations use the retained Chromium single-precision
	-- profile; literal ratio components remain ordinary parsed numbers.
	local bytes=buffer.create(4);buffer.writef32(bytes,0,parsed)
	return buffer.readf32(bytes,0),'calc('..numeric(parsed)..')'
end
local function context(environment)
	local size=environment.QueryFontSize or environment.InitialFontSize or 16
	local result={FontSize=size,RootFontSize=environment.QueryRootFontSize or environment.InitialFontSize or 16,WritingMode=environment.QueryWritingMode or 'horizontal-tb',
		ViewportWidth=environment.ViewportWidth or environment.Width or 0,ViewportHeight=environment.ViewportHeight or environment.Height or 0}
	for _,prefix in {'Small','Large','Dynamic'}do for _,axis in {'Width','Height'}do result[prefix..'Viewport'..axis]=environment[prefix..'Viewport'..axis]end end
	for _,name in {'XHeight','ZeroAdvance','CapHeight','IdeographicAdvance','LineHeight'}do
		result[name]=environment['Query'..name]or environment['Initial'..name];result['Root'..name]=environment['Initial'..name]
	end
	return result
end
local function value(name,tokens)
	local kind=ranges[name]or(if name=='grid'then 'boolean'else nil);local first=tokens[1]
	if not first then return nil end
	if kind=='resolution'and #tokens==1 and identifier(first)=='infinite'then return {Kind=kind,Value=math.huge,Text='infinite'}end
	if not kind then
		local word=if #tokens==1 then identifier(first)else nil
		return if word and discrete[name]and keyword(discrete[name],word)then {Kind='keyword',Value=word,Text=word}else nil
	end
	if kind=='ratio'then
		local left,right=first,tokens[3]
		if #tokens~=1 and not(#tokens==3 and tokens[2].Value=='/')then return nil end
		local numerator,ntext=mathNumber(left);local denominator,dtext=1,'1';if right then denominator,dtext=mathNumber(right)end
		if not numerator or numerator<0 or not denominator or denominator<0 then return nil end
		return {Kind=kind,Value=if denominator==0 then math.huge else numerator/denominator,Text=(if denominator==0 then '1'else ntext)..' / '..dtext}
	elseif kind=='integer'or kind=='boolean'then
		local parsed,text
		if #tokens==1 and(first.Kind=='function'or first.Kind=='number'and first.Integer)then parsed,text=mathNumber(first)end
		if parsed==nil then return nil end
		if first.Kind=='function'then parsed=math.floor(parsed+.5)end
		if kind=='boolean'and parsed~=0 and parsed~=1 then return nil end
		return {Kind=kind,Value=parsed,Text=text}
	elseif #tokens==1 and first.Kind=='dimension'then
		local scale=if kind=='resolution'then factors[first.Unit]else Units.scale(first.Unit,{})
		if not scale or first.Unit=='%'then return nil end
		return {Kind=kind,Token=first,Text=numeric(first.Value)..first.Unit}
	elseif kind=='length'and #tokens==1 and first.Kind=='number'and first.Value==0 then
		return {Kind=kind,Value=0,Text='0'}
	elseif #tokens==1 and first.Kind=='function'and mathFunctions[first.Value]then
		local body=mathSource(first.Items,kind,first.Value~='calc');if not body then return nil end
		local source=first.Value..'('..body..')';local parsed=Length.parse(source,context({}))
		if not parsed or parsed.Percent then return nil end
		local contextual=kind=='length'and relative(first.Items)
		return {Kind=kind,Source=if contextual then source else nil,Value=if contextual then nil else parsed.Value,
			Text=if contextual then source else 'calc('..numeric(parsed.Value)..(if kind=='resolution'then 'dppx'else 'px')..')'}
	end
	return nil
end
local function resolved(v,environment)
	if v.Value~=nil then return v.Value end
	if v.Token then
		local scale=if v.Kind=='resolution'then factors[v.Token.Unit]else Units.scale(v.Token.Unit,context(environment))
		return if scale then v.Token.Value*scale else nil
	end
	local parsed=Length.parse(v.Source,context(environment));return parsed and not parsed.Percent and parsed.Value or nil
end
local function unknown(raw)return {Unknown=true,Text=raw}end
local function feature(tokens,raw)
	local name=identifier(tokens[1]);local prefix=''
	if name and(name:sub(1,4)=='min-'or name:sub(1,4)=='max-')then prefix,name=name:sub(1,4),name:sub(5)end
	if name and(ranges[name]or discrete[name])then
		if #tokens==1 and prefix==''then return {Name=name,Comparison='boolean',Text='('..name..')'}end
		if tokens[2]and tokens[2].Kind=='delim'and tokens[2].Value==':'and(prefix==''or ranges[name])then
			local v=value(name,{table.unpack(tokens,3)})
			if v then return {Name=name,Comparison=if prefix=='min-'then '>='elseif prefix=='max-'then '<='else '=',Value=v,Text='('..prefix..name..': '..v.Text..')'}end
		end
	end
	local parts,operators,current={},{},{}
	for _,token in tokens do
		if token.Kind=='delim'and inverse[token.Value]then table.insert(parts,current);table.insert(operators,token.Value);current={}else table.insert(current,token)end
	end
	table.insert(parts,current)
	if #operators==1 or #operators==2 then
		local terms,text={},{}
		for index,op in operators do
			local left,right=parts[index],parts[index+1];local n,v,reversed
			if #left==1 and ranges[identifier(left[1])]then n=identifier(left[1]);v=value(n,right)
			elseif #right==1 and ranges[identifier(right[1])]then n=identifier(right[1]);v=value(n,left);reversed=true end
			if not n or not v then return unknown(raw)end
			table.insert(terms,{Name=n,Comparison=if reversed then inverse[op]else op,Value=v})
			if index==1 then table.insert(text,if reversed then v.Text else n)end
			table.insert(text,op);table.insert(text,if reversed then n else v.Text)
		end
		if #operators==2 and(not(#parts[2]==1 and identifier(parts[2][1])==terms[1].Name and terms[1].Name==terms[2].Name)
			or operators[1]:sub(1,1)~=operators[2]:sub(1,1)or operators[1]=='=')then return unknown(raw)end
		local result=if #terms==1 then terms[1]else {Operator='and',Terms=terms};result.Text='('..table.concat(text,' ')..')';return result
	end
	return unknown(raw)
end
local condition
local function inParens(token,depth,resolver)
	if resolver then local resolved=resolver(token);if resolved then return resolved end end
	if token.Kind=='function'then return unknown(token.Raw)end
	if token.Kind~='block'or token.Open~='('then return nil end
	local nested=condition(token.Items,true,depth+1,resolver)
	if nested then nested.Text='('..nested.Text..')';return nested end
	return feature(token.Items,token.Raw)
end
condition=function(tokens,allowOr,depth,resolver)
	if depth>32 or #tokens==0 then return nil end
	if identifier(tokens[1])=='not'then
		if #tokens~=2 then return nil end;local term=inParens(tokens[2],depth,resolver);return if term then {Operator='not',Terms={term},Text='not '..term.Text}else nil
	end
	if #tokens%2==0 then return nil end
	local terms,text,operator={},{},nil
	for index=1,#tokens,2 do
		local term=inParens(tokens[index],depth,resolver);if not term then return nil end
		if index>1 then
			local op=identifier(tokens[index-1]);if op~='and'and(op~='or'or not allowOr)or operator and operator~=op then return nil end
			operator=op;table.insert(text,op)
		end
		table.insert(terms,term);table.insert(text,term.Text)
	end
	return if #terms==1 then terms[1]else {Operator=operator,Terms=terms,Text=table.concat(text,' ')}
end
local function branch(tokens)
	local function bad(items)
		for _,token in items do if token.Kind=='bad'or token.Items and bad(token.Items)then return true end end;return false
	end
	if bad(tokens)then return {Invalid=true,Text='not all'}end
	local parsed=condition(tokens,true,0);if parsed then return {Type='all',Tests={parsed},Text=parsed.Text}end
	local index,negated,modifier=1,false,'';local name=identifier(tokens[index])
	if name=='not'or name=='only'then modifier=name..' ';negated=name=='not';index+=1;name=identifier(tokens[index])end
	if not name or forbidden[name]then return {Invalid=true,Text='not all'}end
	index+=1;local tests={};local text=modifier..name
	if index<=#tokens then
		if identifier(tokens[index])~='and'then return {Invalid=true,Text='not all'}end
		parsed=condition({table.unpack(tokens,index+1)},false,0);if not parsed then return {Invalid=true,Text='not all'}end
		table.insert(tests,parsed);text..=' and '..parsed.Text
	end
	return {Negated=negated,Type=name,Tests=tests,Text=text}
end
function Media.compile(source: string): any?
	local tokens=Tokens.parse(source);if not tokens then return nil end
	if #tokens==0 then return {}end
	local result={};for _,part in Tokens.parts(tokens)do Work.checkpoint();if #result>=256 then return nil end;table.insert(result,branch(part))end;return result
end
function Media.serialize(query: any?): string
	if not query then return 'not all'end
	local parts={};for _,option in query do table.insert(parts,option.Text or 'not all')end;return table.concat(parts,', ')
end
function Media.compileCondition(source: string,resolver: any?): any?
	local tokens=Tokens.parse(source);return if tokens then condition(tokens,true,0,resolver)else nil
end
local function compare(actual,expected,op)
	if op=='boolean'then return actual~=0 end
	if op=='<'then return actual<expected elseif op=='>'then return actual>expected elseif op=='<='then return actual<=expected elseif op=='>='then return actual>=expected end
 return actual==expected or math.abs(actual)<math.huge and math.abs(expected)<math.huge and math.abs(actual-expected)<=1e-9*math.max(1,math.abs(actual),math.abs(expected))
end
local function discreteValue(name,env)
	local def=discrete[name];local actual=env[def[1]]
	if name=='orientation'then return if (env.Width or 0)>(env.Height or 0)then 'landscape'else 'portrait'end
	if actual~=nil then
		if name=='scan'and actual==false then return false end
		if name=='grid'and type(actual)=='boolean'then return if actual then 1 else 0 end
		if type(actual)=='boolean'then return if actual then (if name=='hover'or name=='any-hover'then 'hover'elseif name=='forced-colors'then 'active'elseif name=='inverted-colors'then 'inverted'else 'reduce')else def[2]end
		return actual
	end
	if env.MediaType=='print'then if name=='update'then return 'none'elseif name=='overflow-block'then return 'paged'elseif name=='overflow-inline'then return 'none'elseif name=='scan'then return false end end
	if name=='ua-color-scheme'then return env.PreferredColorScheme or def[2]end
	return def[2]
end
local function evaluate(test,env,featureEvaluator): boolean?
	if test.Unknown or env.UnsupportedFeatures and env.UnsupportedFeatures[test.Name]then return nil end
	if test.Domain then return if featureEvaluator then featureEvaluator(test,env)else nil end
	if test.Operator then
		if test.Operator=='not'then local result=evaluate(test.Terms[1],env,featureEvaluator);return if result~=nil then not result else nil end
		local uncertain=false
		for _,term in test.Terms do Work.checkpoint();local result=evaluate(term,env,featureEvaluator)
			if test.Operator=='and'and result==false then return false elseif test.Operator=='or'and result==true then return true end
			if result==nil then uncertain=true end
		end
		return if uncertain then nil else test.Operator=='and'
	end
	local name=test.Name;local visual=env.Visual~=false and env.MediaType~='speech'
	if not visual and name~='scripting'and name~='prefers-reduced-data'then return false end
	if ranges[name]then
		local actual
		if test.LogicalAxis then
			local vertical=(env.QueryWritingMode or 'horizontal-tb')~='horizontal-tb'
			actual=env[if (test.LogicalAxis=='inline')~=vertical then 'Width'else 'Height']or 0
		elseif name=='width'or name=='height'then actual=env[if name=='width'then 'Width'else 'Height']or 0
		elseif name=='device-width'or name=='device-height'then local field=if name=='device-width'then 'DeviceWidth'else 'DeviceHeight';actual=env[field]or env[if name=='device-width'then 'Width'else 'Height']or 0
		elseif name=='aspect-ratio'or name=='device-aspect-ratio'then
			local width=if name=='aspect-ratio'then env.Width else env.DeviceWidth or env.Width
			local height=if name=='aspect-ratio'then env.Height else env.DeviceHeight or env.Height
			actual=if (height or 0)==0 then math.huge else (width or 0)/height
		elseif name=='resolution'then actual=env.Resolution or env.DevicePixelRatio or(if env.MediaType=='print'then 300/96 else 1)
		elseif name=='color'then actual=env.ColorBits or 8 elseif name=='color-index'then actual=env.ColorIndex or 0 elseif name=='monochrome'then actual=env.MonochromeBits or 0
		else actual=env[if name=='horizontal-viewport-segments'then 'HorizontalViewportSegments'else 'VerticalViewportSegments']or 1 end
		local expected=if test.Comparison=='boolean'then 0 else resolved(test.Value,env)
		return if expected~=nil then compare(actual,expected,test.Comparison)else nil
	end
	local actual=discreteValue(name,env);local def=discrete[name];if not def then return nil end
	if actual==false then return false end
	if name=='any-pointer'then
		actual=actual or {};if type(actual)~='table'then actual={}end
		if test.Comparison=='boolean'then return actual.fine==true or actual.coarse==true end
		local expected=test.Value.Value;return if expected=='none'then not(actual.fine==true or actual.coarse==true)else actual[expected]==true
	end
	if test.Comparison=='boolean'then return actual~=0 and actual~='none'and actual~='no-preference'end
	local expected=test.Value.Value
	if name=='color-gamut'or name=='video-color-gamut'then local rank={srgb=1,p3=2,rec2020=3};return (rank[actual]or 0)>=(rank[expected]or 1)end
	if name=='dynamic-range'or name=='video-dynamic-range'then return expected=='standard'or actual=='high'end
	return actual==expected
end
function Media.matchesCondition(query: any,environment: any,featureEvaluator: any?): boolean return evaluate(query,environment or {},featureEvaluator)==true end
function Media.evaluateCondition(query: any,environment: any,featureEvaluator: any?): boolean? return evaluate(query,environment or {},featureEvaluator)end
function Media.matches(query: any?,environment: any): boolean
	if not query then return false end
	if #query==0 then return true end
	local env=environment or {}
	for _,option in query do Work.checkpoint()
		if option.Invalid then continue end
		local accepted=option.Type=='all'or option.Type==(env.MediaType or 'screen')
		for _,test in option.Tests do
			local result=evaluate(test,env)
			if result==false then accepted=false;break elseif result==nil and accepted~=false then accepted=nil end
		end
		if option.Negated and accepted~=nil then accepted=not accepted end
		if accepted==true then return true end
	end
	return false
end
return Media
