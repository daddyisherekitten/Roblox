--!strict
local Media=require(script.Parent.MediaQueries)
local Tokens=require(script.Parent.MediaSyntax)
local WritingMode=require(script.Parent.WritingMode)
local Queries={}
local values={stuck={none=true,top=true,right=true,bottom=true,left=true,['block-start']=true,['block-end']=true,['inline-start']=true,['inline-end']=true},
	snapped={none=true,x=true,y=true,block=true,inline=true,both=true},
	scrollable={none=true,top=true,right=true,bottom=true,left=true,x=true,y=true,block=true,inline=true,['block-start']=true,['block-end']=true,['inline-start']=true,['inline-end']=true},
	scrolled={none=true,top=true,right=true,bottom=true,left=true,x=true,y=true,block=true,inline=true,['block-start']=true,['block-end']=true,['inline-start']=true,['inline-end']=true}}
local function feature(tokens)
	local first=tokens[1];local name=first and first.Kind=='ident'and first.Value;local allowed=values[name]
	if not allowed then return nil end
	if #tokens==1 then return {Domain='scroll',Name=name,Boolean=true}end
	local word=tokens[3]and tokens[3].Kind=='ident'and tokens[3].Value
	if #tokens==3 and tokens[2].Value==':'and allowed[word]then return {Domain='scroll',Name=name,Value=word}end
	return nil
end
function Queries.compile(token)
	local function resolver(part)
		if part.Kind=='block'and part.Open=='('then local test=feature(part.Items);if test then test.Text=part.Raw end;return test end;return nil
	end
	local test=feature(token.Items)or Media.compileCondition('('..Tokens.raw(token.Items)..')',resolver)
	local function valid(term)
		if not term then return false end
		if term.Operator then for _,child in term.Terms do if not valid(child)then return false end end;return true end
		return term.Domain=='scroll'
	end
	return if valid(test)then {Domain='scroll-query',Condition=test,Text=token.Raw}else nil
end
local function physical(word,mode,direction)
	local style={WritingMode=mode,Direction=direction};local vertical=WritingMode.vertical(style)
	if word=='block'then return if vertical then 'x'else 'y'elseif word=='inline'then return if vertical then 'y'else 'x'end
	if word=='block-start'or word=='block-end'or word=='inline-start'or word=='inline-end'then return ({'top','right','bottom','left'})[WritingMode.side(style,word)]end
	return word
end
function Queries.evaluate(test,env)
	if test.Domain=='scroll-query'then return Media.matchesCondition(test.Condition,env,Queries.evaluate)end
	local snapshot=env.ScrollState or{};local state=snapshot[test.Name]
	if (test.Name=='stuck'or test.Name=='scrollable'or test.Name=='scrolled')and not state then return false end
	state=state or{}
	if test.Boolean then return next(state)~=nil end
	local mode=if test.Name=='snapped'then snapshot.SnapWritingMode or env.QueryWritingMode else env.QueryWritingMode
	local direction=if test.Name=='snapped'then snapshot.SnapDirection or env.QueryDirection else env.QueryDirection
	local word=physical(test.Value,mode or 'horizontal-tb',direction or 'ltr')
	if word=='none'then return next(state)==nil end
	if word=='both'then return state.x==true and state.y==true end
	if word=='x'then return state.x==true or state.left==true or state.right==true
	elseif word=='y'then return state.y==true or state.top==true or state.bottom==true end
	return state[word]==true
end
return Queries
