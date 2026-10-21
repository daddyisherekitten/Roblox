--!strict
local WorkContext=require(script.Parent.Parent.WorkContext)
local ScriptData={}
local function boundary(ch: string): boolean return ch==" " or ch=="\t" or ch=="\n" or ch=="\r" or ch=="\f" or ch=="/" or ch==">" end
-- Script escaped and double-escaped states change whether </script> closes
-- the element. No JavaScript is evaluated by this scanner.
function ScriptData.ending(source: string,start: number): number?
	local cursor,state,length=start,"data",#source
	while cursor<=length do
		if cursor%256==0 then WorkContext.checkpoint() end
		local ch=source:sub(cursor,cursor)
		if state=="data" and source:sub(cursor,cursor+3)=="<!--" then state="escaped"; cursor+=4
		elseif state~="data" and source:sub(cursor,cursor+2)=="-->" then state="data"; cursor+=3
		elseif ch=="<" then
			local closing=source:sub(cursor+1,cursor+1)=="/"
			local nameStart=cursor+(if closing then 2 else 1); local last=nameStart
			while source:sub(last,last):match("[A-Za-z]") do last+=1 end
			local script=source:sub(nameStart,last-1):lower()=="script" and boundary(source:sub(last,last))
			if script and closing then
				if state~="double" then return cursor end
				state="escaped"; cursor=last+1
			elseif script and state=="escaped" then state="double"; cursor=last+1
			else cursor+=1 end
		else cursor+=1 end
	end
	return nil
end
return ScriptData
