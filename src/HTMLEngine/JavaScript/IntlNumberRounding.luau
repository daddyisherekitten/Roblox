--!strict
-- Decimal-string rounding avoids lossy Number conversion of BigInts or exact
-- Intl mathematical-value strings. All nine ECMA-402 rounding modes use the
-- same quotient/remainder path, including allowed cash-rounding increments.
local Rounding={}
local function addOne(digits)
 local out={};local carry=1;for i=#digits,1,-1 do local n=tonumber(digits:sub(i,i))+carry;out[i]=tostring(n%10);carry=math.floor(n/10)end;return(if carry>0 then '1'else '')..table.concat(out)
end
local function divide(digits,divisor,charge)
 local out={};local carry=0;for i=1,#digits do if charge then charge()end;local n=carry*10+tonumber(digits:sub(i,i));out[i]=tostring(math.floor(n/divisor));carry=n%divisor end
 local result=table.concat(out):gsub('^0+','');return if result==''then '0'else result,carry
end
local function multiply(digits,multiplier)
 local out={};local carry=0;for i=#digits,1,-1 do local n=tonumber(digits:sub(i,i))*multiplier+carry;out[i]=tostring(n%10);carry=math.floor(n/10)end;return(if carry>0 then tostring(carry)else '')..table.concat(out)
end
local function increment(mode,negative,comparison,nonzero,odd)
 if not nonzero then return false end
 if mode=='ceil'then return not negative elseif mode=='floor'then return negative elseif mode=='expand'then return true elseif mode=='trunc'then return false end
 if comparison>0 then return true elseif comparison<0 then return false end
 return mode=='halfExpand'or mode=='halfCeil'and not negative or mode=='halfFloor'and negative or mode=='halfEven'and odd
end
local function quantize(digits,point,total,negative,mode,quantum,charge)
 if #digits<total then digits..=string.rep('0',total-#digits)end
 local kept=digits:sub(1,total);if kept==''then kept='0'end
 local lost=digits:sub(total+1);local q,remainder=divide(kept,quantum,charge);local nonzero=remainder~=0 or lost:find('[1-9]')~=nil
 local comparison=2*remainder-quantum
 if comparison==0 then comparison=if lost:find('[1-9]')then 1 else 0
 elseif comparison==-1 then local first=tonumber(lost:sub(1,1))or 0;comparison=if first>5 or first==5 and lost:sub(2):find('[1-9]')then 1 elseif first==5 then 0 else -1
 elseif comparison<0 then comparison=-1 else comparison=1 end
 if increment(mode,negative,comparison,nonzero,tonumber(q:sub(-1))%2==1)then q=addOne(q)end
 kept=multiply(q,quantum);if #kept<total then kept=string.rep('0',total-#kept)..kept elseif #kept>total then point+=#kept-total end
 if #kept<point then kept..=string.rep('0',point-#kept)end
 local integer=kept:sub(1,point):gsub('^0+','');local fraction=kept:sub(point+1)
 return if integer==''then '0'else integer,fraction
end
function Rounding.format(digits: string,point: number,negative: boolean,state: any,charge: (() -> ())?): (string,string)
 if point>#digits then digits..=string.rep('0',point-#digits)end
 if point<0 then digits=string.rep('0',-point)..digits;point=0 end
 local first=digits:find('[1-9]')or math.max(point,1)
 local significant=state.MaxSignificant~=nil and(state.Priority=='auto'or first-1+state.MaxSignificant>point+state.MaxFraction and state.Priority=='morePrecision'or first-1+state.MaxSignificant<point+state.MaxFraction and state.Priority=='lessPrecision')
 local total=if significant then first-1+state.MaxSignificant else point+state.MaxFraction
 local integer,fraction=quantize(digits,point,total,negative,state.Rounding,state.Increment,charge)
 local minFraction=state.MinFraction
 if significant then
  local count=if integer=='0'then 0 else #integer
  if count==0 then local at=fraction:find('[1-9]');minFraction=if at then at-1+state.MinSignificant else state.MinSignificant-1 else minFraction=math.max(state.MinSignificant-count,0)end
 end
 while #fraction>minFraction and fraction:sub(-1)=='0'do fraction=fraction:sub(1,-2)end
 if #fraction<minFraction then fraction..=string.rep('0',minFraction-#fraction)end
 if state.Zeros=='stripIfInteger'and not fraction:find('[1-9]')then fraction=''end
 return integer,fraction
end
return Rounding
