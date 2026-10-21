--!strict
local Matrix=require(script.Parent.Matrix)
local Length=require(script.Parent.Length)
local Syntax=require(script.Parent.Parent.CSS.Syntax)
local Transform={}
local function trim(s: string): string return s:match('^%s*(.-)%s*$') :: string end
local function translation(x: number,y: number): any local t=Matrix.identity();t.TX=x;t.TY=y;return t end
local function angle(token: any,css: boolean): number?
	local factors={deg=1,rad=180/math.pi,grad=.9,turn=360}
	local factor=factors[token.Unit]
	if token.Unit=='' and (not css or token.Value==0) then factor=1 end
	return if factor then token.Value*factor else nil
end
function Transform.parse(text: string?,context: any?,box: any?,css: boolean?): (any,string?)
	local identity=Matrix.identity()
	if not text or trim(text)=='none' or trim(text)=='initial' or trim(text)=='unset' or trim(text)=='' then return identity,nil end
	if #text>16384 then return identity,'transform-limit' end
	context=context or {Width=0,Height=0,FontSize=16,RootFontSize=16}
	box=box or {Width=context.Width,Height=context.Height}
	local lengths=table.clone(context);lengths.Width=box.Width;lengths.Height=box.Height
	local index,count,result=1,0,identity
	while index<=#text do
		local start,finish,name,args=text:find('^%s*([%a]+)%s*%(([^()]*)%)',index)
		if not start then return identity,'invalid-transform' end
		if css then
			name=string.lower(name)
			name=({translatex='translateX',translatey='translateY',scalex='scaleX',scaley='scaleY',skewx='skewX',skewy='skewY'})[name] or name
		end
		local tokens={};local cursor=1
		while cursor<=#args do
			local ws=args:match('^%s*',cursor) :: string;cursor+=#ws
			if cursor>#args then break end
			local word=args:match('^[+%-]?%d+%.?%d*',cursor) or args:match('^[+%-]?%.%d+',cursor)
			if not word then return identity,'invalid-transform' end
			cursor+=#word
			local exp=args:match('^[eE][+%-]?%d+',cursor);if exp then word..=exp;cursor+=#exp end
			local unit=args:match('^[%a%%]+',cursor) or '';word..=unit;cursor+=#unit
			local token=Length.parse(word)
			if not token or math.abs(token.Value)>1e9 or (not css and token.Unit~='') then return identity,'invalid-transform' end
			table.insert(tokens,token);if #tokens>6 then return identity,'invalid-transform' end
			local gap=args:match('^%s*',cursor) :: string;cursor+=#gap
			if args:sub(cursor,cursor)==',' then cursor+=1;if not args:sub(cursor):find('%S') then return identity,'invalid-transform' end
			elseif cursor<=#args and #gap==0 then return identity,'invalid-transform' end
		end
		local n=#tokens;local t=Matrix.identity()
		local function numeric(i: number,default: number?): number?
			local token=tokens[i];if not token then return default end
			return if token.Unit=='' then token.Value else nil
		end
		local function distance(i: number,axis: string,default: number): number?
			if not tokens[i] then return default end
			if css and tokens[i].Unit=='' and tokens[i].Value~=0 then return nil end
			return Length.resolve(tokens[i],lengths,axis,false)
		end
		if name=='matrix' and n==6 then
			t={SX=numeric(1),KY=numeric(2),KX=numeric(3),SY=numeric(4),TX=numeric(5),TY=numeric(6)}
		elseif (name=='translate' and (n==1 or n==2)) or ((name=='translateX' or name=='translateY') and n==1 and css) then
			t.TX=if name=='translateY' then 0 else distance(1,'x',0)
			t.TY=if name=='translateY' then distance(1,'y',0) elseif name=='translateX' then 0 else distance(2,'y',0)
		elseif (name=='scale' and (n==1 or n==2)) or ((name=='scaleX' or name=='scaleY') and n==1 and css) then
			t.SX=if name=='scaleY' then 1 else numeric(1)
			t.SY=if name=='scaleY' then numeric(1) elseif name=='scaleX' then 1 else numeric(2,numeric(1))
		elseif name=='rotate' and (n==1 or (n==3 and not css)) then
			local degrees=angle(tokens[1],css==true);if not degrees then return identity,'invalid-transform' end
			local r=math.rad(degrees%360);t.SX=math.cos(r);t.SY=t.SX;t.KY=math.sin(r);t.KX=-t.KY
			if n==3 then t=Matrix.multiply(translation(tokens[2].Value,tokens[3].Value),Matrix.multiply(t,translation(-tokens[2].Value,-tokens[3].Value))) end
		elseif ((name=='skewX' or name=='skewY') and n==1) or (name=='skew' and (n==1 or n==2) and css) then
			local x=angle(tokens[1],css==true);local y=if n==2 then angle(tokens[2],true) else 0
			if not x or not y then return identity,'invalid-transform' end
			if name=='skewY' then t.KY=math.tan(math.rad(x%180)) else t.KX=math.tan(math.rad(x%180));t.KY=math.tan(math.rad(y%180)) end
		else return identity,'invalid-transform' end
		for _,key in {'SX','SY','KX','KY','TX','TY'} do if t[key]==nil or math.abs(t[key])>1e12 then return identity,'transform-range' end end
		result=Matrix.multiply(result,t)
		if not Matrix.valid(result) or Matrix.scale(result)>1e12 or math.abs(result.TX)>1e12 or math.abs(result.TY)>1e12 then return identity,'transform-range' end
		count+=1;if count>128 then return identity,'transform-limit' end
		index=finish+1
		local ws=text:match('^%s*',index) :: string;index+=#ws
		if text:sub(index,index)==',' and not css then index+=1;if not text:sub(index):find('%S') then return identity,'invalid-transform' end end
	end
	return result,nil
end
function Transform.declarations(a: any): any
	local result={Transform=a.transform,Origin=a['transform-origin'],Box=a['transform-box'],Vector=a['vector-effect'],CSS=false}
	local keys={transform='Transform',['transform-origin']='Origin',['transform-box']='Box',['vector-effect']='Vector'}
	local important={}
	for _,item in Syntax.declarations(a.style or '') do
		local name,value=item.Text:match('^%s*([%a%-]+)%s*:%s*(.-)%s*$')
		local key=name and keys[string.lower(name)]
		if key and (item.Important or not important[key]) then result[key]=value;important[key]=item.Important;if key=='Transform' then result.CSS=true end end
	end
	return result
end
function Transform.origin(text: string?,box: any,context: any,isRoot: boolean?): (number,number,string?)
	text=trim(text or if isRoot then '50% 50%' else '0 0')
	if text=='initial' or text=='unset' then text='50% 50%' end
	local words={};for w in text:gmatch('%S+') do table.insert(words,w) end
	if #words==1 then if words[1]=='top' or words[1]=='bottom' then table.insert(words,1,'center') else table.insert(words,'center') end end
	if #words==3 then local z=Length.resolve(words[3],context,'x',false);if z~=0 then return 0,0,'unsupported-3d-origin' end;table.remove(words) end
	if #words~=2 then return 0,0,'invalid-transform-origin' end
	if words[1]=='top' or words[1]=='bottom' or words[2]=='left' or words[2]=='right' then words[1],words[2]=words[2],words[1] end
	local function used(word: string,axis: string): number?
		local keywords=if axis=='x' then {left=0,center=.5,right=1} else {top=0,center=.5,bottom=1}
		local size=if axis=='x' then box.Width else box.Height
		if keywords[word] then return size*keywords[word] end
		local ctx=table.clone(context);ctx.Width=box.Width;ctx.Height=box.Height
		return Length.resolve(word,ctx,axis,false)
	end
	local x,y=used(words[1],'x'),used(words[2],'y')
	if not x or not y or math.abs(x)>1e9 or math.abs(y)>1e9 then return 0,0,'invalid-transform-origin' end
	return box.X+x,box.Y+y,nil
end
function Transform.resolve(declarations: any,box: any,context: any,isRoot: boolean?): (any,any)
	local t,problem=Transform.parse(declarations.Transform,context,box,declarations.CSS)
	local x,y,originProblem=Transform.origin(declarations.Origin,box,context,isRoot)
	local errors={};if problem then table.insert(errors,problem) end;if originProblem then table.insert(errors,originProblem) end
	return Matrix.multiply(translation(x,y),Matrix.multiply(t,translation(-x,-y))),errors
end
return Transform
