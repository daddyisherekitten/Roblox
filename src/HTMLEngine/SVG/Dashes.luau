--!strict
--!optimize 2
--!native
-- Dasharray/offset decomposition; geometry caps are applied after splitting.
local PathMetrics=require(script.Parent.PathMetrics)
local Dashes={}
function Dashes.split(parts: any,pattern: any,author: number?,check: any?,offset: any?,lineCap: string?): any?
	if not pattern then return parts end
	local total=PathMetrics.measure(parts)
	local values,sum={},0
	for _,entry in pattern do
		local value=PathMetrics.calibrate(entry.Value,entry.Percent,total,author)
		table.insert(values,value);sum+=value
	end
	if sum==0 then return parts end
	if #values%2==1 then local count=#values;for i=1,count do table.insert(values,values[i]) end;sum*=2 end
	local phase=if offset then PathMetrics.calibrate(offset.Value,offset.Percent,total,author) else 0
	assert(math.abs(phase)<math.huge and (sum<math.huge or phase==0),'SVG dash offset numeric budget exceeded')
	phase=if sum<math.huge then phase%sum else 0
	local result,steps={},0
	for _,part in parts do
		if check and not check() then return nil end
		local runs,current={},nil
		local index,remaining=1,values[1]
		local skip=phase
		while skip>values[index] do skip-=values[index];index=index%#values+1 end
		remaining=values[index]-skip
		local function finish()
			if current and #current>1 then table.insert(runs,{Points=current,Closed=false}) end
			current=nil
		end
		local points=part.Points
		for i=1,if part.Closed then #points else #points-1 do
			local a,b=points[i],points[i%#points+1]
			local length=PathMetrics.distance(a,b)
			local position=0
			while position<length do
				steps+=1;assert(steps<=65536,'SVG dash subdivision budget exceeded')
				if check and steps%256==0 and not check() then return nil end
				if remaining==0 then
					if index%2==1 then
						if not current and lineCap~='butt' and lineCap~=nil then
							local t=position/length;local p={a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t}
							table.insert(runs,{Points={p,p},Closed=false,Direction={b[1]-a[1],b[2]-a[2]}})
						end
						finish()
					end
					index=index%#values+1;remaining=values[index];continue
				end
				local edgeRemaining=length-position
				local atVertex=math.abs(remaining-edgeRemaining)<=1e-12*math.max(1,length)
				local amount=if atVertex then edgeRemaining else math.min(remaining,edgeRemaining)
				assert(position+amount>position,'SVG dash precision budget exceeded')
				local function at(distance: number): any
					if distance==0 then return a elseif distance==length then return b end
					local t=distance/length;return {a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t}
				end
				if index%2==1 then
					if not current then current={at(position)} end
					table.insert(current,at(position+amount))
				end
				position+=amount;remaining=if atVertex then 0 else remaining-amount
			end
		end
		finish()
		if lineCap and lineCap~='butt' and #points>0 then
			local endpoint=if part.Closed then points[1] else points[#points]
			local function dot()
				local previous=points[if part.Closed then #points else math.max(1,#points-1)]
				table.insert(runs,{Points={endpoint,endpoint},Closed=false,Direction={endpoint[1]-previous[1],endpoint[2]-previous[2]}})
			end
			if (#points>1 or part.Closed) and PathMetrics.measure({part})==0 then
				if index%2==1 then dot() end
			elseif remaining==0 then
				for _=1,#values do
					index=index%#values+1
					if values[index]>0 then break end
					if index%2==1 then dot() end
				end
			end
		end
		-- A zero-length gap must not introduce butt caps at a geometric corner.
		local merged={}
		for _,run in runs do
			local last=merged[#merged]
			local a=if last then last.Points[#last.Points] else nil
			local b=run.Points[1]
			if a and a[1]==b[1] and a[2]==b[2] then
				for i=2,#run.Points do table.insert(last.Points,run.Points[i]) end
			else table.insert(merged,run) end
		end
		runs=merged
		-- Rejoin a dash crossing the closing seam so its corner retains a join.
		if part.Closed and #runs>0 then
			local first,last=runs[1].Points,runs[#runs].Points
			if first[1][1]==last[#last][1] and first[1][2]==last[#last][2] then
				if #runs==1 then runs[1].Closed=true
				else for i=2,#first do table.insert(last,first[i]) end;table.remove(runs,1) end
			end
		end
		for _,run in runs do table.insert(result,run) end
	end
	return result
end
return Dashes
