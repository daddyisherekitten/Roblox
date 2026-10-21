--!strict
-- Minimize squared unused space before flexing. Monotone partition optima
-- allow divide-and-conquer DP, avoiding a quadratic scan per flex line.
local FlexBalance={}
function FlexBalance.collect(items,limit,gap,minimum,alive)
 local n=#items
 if n==0 then return {} end
 local prefix={[0]=0};local sizes={}
 for i,item in items do
  sizes[i]=math.max(0,math.max(item.Min,math.min(item.Max,item.Base))+item.Extra)
  prefix[i]=prefix[i-1]+sizes[i]+gap
 end
 local function used(first,last)return prefix[last]-prefix[first-1]-gap end
 local lastFit={};local last=0
 for first=1,n do
  last=math.max(last,first)
  while last<n and used(first,last+1)<=limit+1e-7 do last+=1 end
  lastFit[first]=last
 end
 local needed={[n+1]=0}
 for first=n,1,-1 do needed[first]=1+needed[lastFit[first]+1] end
 local count=math.min(n,math.max(minimum,needed[1]))
 local previous={[n+1]=0};local cuts={}
 for k=1,count do
  if not alive() then return {} end
  local current={};local choices={};cuts[k]=choices
  local first=1
  while first<=n-k+1 and needed[first]>k do first+=1 end
  local aborted=false
  local function solve(lo,hi,optLo,optHi)
   if lo>hi then return end
   local mid=math.floor((lo+hi)/2)
   local best,bestEnd=math.huge,nil
   for finish=math.max(mid,optLo),math.min(lastFit[mid],n-k+1,optHi) do
    if not alive() then aborted=true;return end
    local tail=previous[finish+1]
    if tail then
     local error=limit-used(mid,finish)
     local score=tail+error*error
     if score<best-1e-7 or (math.abs(score-best)<1e-7 and (not bestEnd or finish>bestEnd)) then best,bestEnd=score,finish end
    end
   end
   if bestEnd then
    current[mid],choices[mid]=best,bestEnd
    solve(lo,mid-1,optLo,bestEnd);solve(mid+1,hi,bestEnd,optHi)
   else
    solve(lo,mid-1,optLo,optHi);solve(mid+1,hi,optLo,optHi)
   end
  end
  solve(first,n-k+1,first,n-k+1)
  if aborted then return {} end
  previous=current
 end
 local result={};local first=1
 for k=count,1,-1 do
  local finish=assert(cuts[k][first],'Missing balanced flex partition')
  local line={Items={},Used=used(first,finish),Cross=0}
  for i=first,finish do table.insert(line.Items,items[i]) end
  table.insert(result,line);first=finish+1
 end
 return result
end
return FlexBalance
