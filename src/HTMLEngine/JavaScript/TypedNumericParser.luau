--!strict
-- Typed numeric parsing reuses the CSS tokenizer used by Geometry Interfaces.
-- Only algebraically resolvable terms fold; contextual units retain their AST.
local Tokens=require(script.Parent.GeometryTransformParser)
local Parser={}
local INVALID={}
function Parser.parse(ctx: any,numeric: any,source: string): any
	local function invalid()error(INVALID,0)end
	local function run()
		if #source>65536 then invalid()end
		local tokens=Tokens.tokens(source);if not tokens then invalid()end
		local at,depth,count=1,0,0
		local function peek()return tokens[at]end
		local function take(kind)local token=peek();if token.Kind~=kind then invalid()end;at+=1;return token end
		local function unit(value)return ctx.Values[value]end
		local function make(operator,members)
			count+=1;if count>256 then invalid()end
			local folded=unit(members[1]);local same=folded and folded.Kind=='unit';local result=folded and folded.Value
			if operator=='sum'or operator=='min'or operator=='max'or operator=='clamp'then
				local numbers={}
				for _,member in members do
					local s=unit(member)
					if not same or not s or s.Kind~='unit'or ctx.UnitTypes[s.Unit][1]~=ctx.UnitTypes[folded.Unit][1]then same=false;break end
					table.insert(numbers,s.Value*ctx.UnitTypes[s.Unit][2]/ctx.UnitTypes[folded.Unit][2])
				end
				if same then
					result=numbers[1]
					if operator=='clamp'then result=math.max(numbers[1],math.min(numbers[2],numbers[3]))
					else for i=2,#numbers do result=if operator=='sum'then result+numbers[i]elseif operator=='min'then math.min(result,numbers[i])else math.max(result,numbers[i])end end
				end
			elseif operator=='negate'then if same then result=-result end
			elseif operator=='invert'then same=same and folded.Unit=='number'and result~=0;if same then result=1/result end
			elseif operator=='product'then
				local dimensional=nil;result=1
				for _,member in members do
					local s=unit(member);if not s or s.Kind~='unit'then same=false;break end
					if s.Unit~='number'then if dimensional then same=false;break end;dimensional=s.Unit end
					result*=s.Value
				end
				if same then return ctx.Scalar(ctx.Finite(result),dimensional or'number')end
			end
			if same then return ctx.Scalar(ctx.Finite(result),folded.Unit)end
			return numeric:Make(operator,members)
		end
		local sum,product,term,func
		func=function(name)
			depth+=1;if depth>64 then invalid()end
			if name~='calc'and name~='min'and name~='max'and name~='clamp'then invalid()end
			local members={sum()}
			while peek().Kind==','do at+=1;if #members>=256 then invalid()end;table.insert(members,sum())end
			if peek().Kind~='eof'then take(')')end;depth-=1
			if name=='calc'then
				if #members~=1 then invalid()end;return members[1]
			end
			if name=='clamp'and #members~=3 then invalid()end
			return make(name,members)
		end
		term=function()
			ctx.VM.Step();count+=1;if count>256 then invalid()end
			local token=peek();at+=1
			if token.Kind=='number'then return ctx.Scalar(ctx.Finite(token.Value),ctx.ValidUnit(if token.Unit==''then'number'elseif token.Unit=='%'then'percent'else token.Unit))end
			if token.Kind=='function'then return func(token.Name)end
			if token.Kind=='('then depth+=1;if depth>64 then invalid()end;local value=sum();if peek().Kind~='eof'then take(')')end;depth-=1;return value end
			invalid()
		end
		product=function()
			local members={term()}
			while peek().Kind=='*'or peek().Kind=='/'do local operator=peek().Kind;at+=1;local right=term();table.insert(members,if operator=='/'then make('invert',{right})else right)end
			return if #members==1 then members[1]else make('product',members)
		end
		sum=function()
			local members={product()}
			while peek().Kind=='+'or peek().Kind=='-'do
				local token=peek();if not token.Gap or not tokens[at+1].Gap then invalid()end;at+=1;local right=product();table.insert(members,if token.Kind=='-'then make('negate',{right})else right)
			end
			return if #members==1 then members[1]else make('sum',members)
		end
		local value
		if peek().Kind=='number'then value=term()elseif peek().Kind=='function'then local name=peek().Name;at+=1;value=func(name);if name=='calc'and unit(value).Kind=='unit'then value=numeric:Make('sum',{value})end else invalid()end
		take('eof');return value
	end
	local ok,result=pcall(run);if ok then return result end
	if result==INVALID or type(result)=='table'and ctx.VM.Model.exceptionValue(result).ErrorName=='TypeError'then
		ctx.VM.Model.throw(ctx.VM:Construct(ctx.Globals.DOMException,{'Invalid CSS numeric value','SyntaxError'}))
	end
	error(result,0)
end
return Parser
