--!strict
local WorkContext=require(script.Parent.Parent.WorkContext)
-- Straight and cubic/quadratic path commands. Preserve completed segments before a syntax error.
local Path={}
function Path.parse(source: string): (any,any)
	local parts,diagnostics={},{}
	local index,total=1,0
	local x,y=0,0
	local part,command=nil,nil
	local previous,cubicControl,quadraticControl=nil,nil,nil
	local function fail(code: string)
		table.insert(diagnostics,{Code=code,Position=index,Attribute='d'})
	end
	if #source>262144 then fail('path-size-limit');return parts,diagnostics end
	if source:match('^%s*none%s*$') then return parts,diagnostics end
	local function space()
		while source:sub(index,index):match('[ \t\r\n]') do index+=1 end
	end
	local function number(comma: boolean): number?
		space()
		if comma and source:sub(index,index)==',' then index+=1;space() end
		local rest=source:sub(index)
		local token=rest:match('^[+%-]?%d+%.?%d*') or rest:match('^[+%-]?%.%d+')
		if not token then fail('invalid-path-number');return nil end
		local suffix=rest:sub(#token+1)
		if suffix:match('^[eE]') then
			local exponent=suffix:match('^[eE][+%-]?%d+')
			if not exponent then fail('invalid-path-number');return nil end
			token..=exponent
		end
		local value=tonumber(token)
		if not value or value~=value or math.abs(value)>1e9 then fail('path-coordinate-range');return nil end
		index+=#token
		return value
	end
	while true do
		WorkContext.checkpoint()
		space();if index>#source then break end
		local char=source:sub(index,index)
		local fresh=false
		if char:match('%a') then
			if not char:match('[MmLlHhVvZzCcSsQqTtAa]') then fail('unsupported-path-command');break end
			command=char;fresh=true;index+=1
		elseif not command then fail('missing-path-command');break end
		local upper=string.upper(command)
		local relative=command~=upper
		if not part and upper~='M' then fail('path-must-start-with-moveto');break end
		if upper=='Z' then
			part.Closed=true;x,y=part.Points[1][1],part.Points[1][2];command=nil
			previous,cubicControl,quadraticControl=nil,nil,nil
			continue
		end
		local count=if upper=='A' then 7 elseif upper=='C' then 6 elseif upper=='S' or upper=='Q' then 4 elseif upper=='H' or upper=='V' then 1 else 2
		local args={}
		for i=1,count do
			local value
			if upper=='A' and (i==4 or i==5) then
				space();if source:sub(index,index)==',' then index+=1;space() end
				local flag=source:sub(index,index)
				if flag~='0' and flag~='1' then fail('invalid-arc-flag');break end
				value=tonumber(flag);index+=1
			else value=number(i>1 or not fresh) end
			if value==nil then break end;args[i]=value
		end
		if #args~=count then break end
		local xx,yy=x,y
		local curve=nil
		if upper=='A' then
			xx,yy=args[6]+(if relative then x else 0),args[7]+(if relative then y else 0)
		elseif upper=='H' then xx=args[1]+(if relative then x else 0)
		elseif upper=='V' then yy=args[1]+(if relative then y else 0)
		else
			if relative then for i=1,count,2 do args[i]+=x;args[i+1]+=y end end
			xx,yy=args[count-1],args[count]
		end
		local valid=math.abs(xx)<=1e9 and math.abs(yy)<=1e9
		for _,value in args do if math.abs(value)>1e9 then valid=false end end
		if not valid then fail('path-coordinate-range');break end
		if upper=='A' then curve={Kind='A',RX=math.abs(args[1]),RY=math.abs(args[2]),Rotation=args[3],Large=args[4],Sweep=args[5]}
		elseif upper=='C' then curve={Kind='C',Control1={args[1],args[2]},Control2={args[3],args[4]}}
		elseif upper=='S' then
			local reflected=if previous=='C' or previous=='S' then {2*x-cubicControl[1],2*y-cubicControl[2]} else {x,y}
			curve={Kind='C',Control1=reflected,Control2={args[1],args[2]}}
		elseif upper=='Q' then curve={Kind='Q',Control1={args[1],args[2]}}
		elseif upper=='T' then
			local reflected=if previous=='Q' or previous=='T' then {2*x-quadraticControl[1],2*y-quadraticControl[2]} else {x,y}
			curve={Kind='Q',Control1=reflected}
		end
		if curve and curve.Kind~='A' then
			for _,control in {curve.Control1,curve.Control2} do
				if math.abs(control[1])>1e9 or math.abs(control[2])>1e9 then valid=false end
			end
			if not valid then fail('path-coordinate-range');break end
		end
		local needed=if upper~='M' and part.Closed then 2 else 1
		if total+needed>4096 then fail('path-point-limit');break end
		if upper=='M' then
			part={Points={},Curves={},Closed=false};table.insert(parts,part)
			command=if relative then 'l' else 'L'
		elseif part.Closed then
			part={Points={{x,y}},Curves={},Closed=false};table.insert(parts,part);total+=1
		end
		x,y=xx,yy;table.insert(part.Points,{x,y});total+=1
		if curve then part.Curves[#part.Points]=curve end
		previous=upper
		cubicControl=if curve and curve.Kind=='C' then curve.Control2 else nil
		quadraticControl=if curve and curve.Kind=='Q' then curve.Control1 else nil
	end
	return parts,diagnostics
end
return Path
