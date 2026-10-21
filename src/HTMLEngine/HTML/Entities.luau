--!strict
local Named=require(script.Parent.NamedEntities)
local WorkContext=require(script.Parent.Parent.WorkContext)
local Entities={}
local replacement=utf8.char(0xFFFD)
local c1={[128]=0x20AC,[130]=0x201A,[131]=0x0192,[132]=0x201E,[133]=0x2026,[134]=0x2020,[135]=0x2021,[136]=0x02C6,[137]=0x2030,[138]=0x0160,[139]=0x2039,[140]=0x0152,[142]=0x017D,[145]=0x2018,[146]=0x2019,[147]=0x201C,[148]=0x201D,[149]=0x2022,[150]=0x2013,[151]=0x2014,[152]=0x02DC,[153]=0x2122,[154]=0x0161,[155]=0x203A,[156]=0x0153,[158]=0x017E,[159]=0x0178}
function Entities.decode(value: string,attribute: boolean?): string
	if not value:find("&",1,true) then return value end
	local result={}; local cursor=1; local length=#value
	while cursor<=length do
		WorkContext.checkpoint()
		local start=value:find("&",cursor,true)
		if not start then table.insert(result,value:sub(cursor)); break end
		table.insert(result,value:sub(cursor,start-1))
		local stop,decoded=start+1,nil
		if value:sub(stop,stop)=="#" then
			stop+=1; local hex=value:sub(stop,stop):lower()=="x"; if hex then stop+=1 end
			local digits=stop; local code=0
			while stop<=length do
				if stop%256==0 then WorkContext.checkpoint() end
				local byte=value:byte(stop); local number=if byte>=48 and byte<=57 then byte-48 elseif hex and byte>=65 and byte<=70 then byte-55 elseif hex and byte>=97 and byte<=102 then byte-87 else nil
				if not number then break end
				code=math.min(0x110000,code*(if hex then 16 else 10)+number); stop+=1
			end
			if stop>digits then
				if value:sub(stop,stop)==";" then stop+=1 end
				decoded=if code==0 or code>0x10FFFF or (code>=0xD800 and code<=0xDFFF) then replacement else utf8.char(c1[code] or code)
			end
		else
			local endName=stop
			while endName<=math.min(length,stop+31) and value:sub(endName,endName):match("[A-Za-z0-9]") do endName+=1 end
			if value:sub(endName,endName)==";" then endName+=1 end
			for ending=endName-1,stop,-1 do
				local name=value:sub(stop,ending); local candidate=Named[name]
				if candidate then
					local nextByte=value:sub(ending+1,ending+1)
					if not (attribute and name:sub(-1)~=";" and (nextByte=="=" or nextByte:match("[A-Za-z0-9]"))) then decoded=candidate; stop=ending+1 end
					break
				end
			end
		end
		if decoded then table.insert(result,decoded); cursor=stop else table.insert(result,"&"); cursor=start+1 end
	end
	return table.concat(result)
end

return Entities
