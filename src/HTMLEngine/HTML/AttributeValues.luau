--!strict
-- HTML integer parsing is deliberately distinct from WebIDL conversion and
-- CSS numeric parsing: leading space/+ and trailing non-digits are permitted.
local Values={}
function Values.nonnegative(raw: string?,maximum: number?): number?
	local digits=raw and raw:match("^[\t\n\f\r ]*%+?(%d+)")
	local value=digits and tonumber(digits)
	return if value and value<math.huge and value<=(maximum or 4294967295) then value else nil
end
function Values.positive(raw: string?,fallback: number): number
	local value=Values.nonnegative(raw)
	return if value and value>0 then value else fallback
end
-- A bounded reflected integer still parses a valid arbitrarily long decimal
-- prefix. Overflow clamps; it is not an invalid/missing attribute.
function Values.clampedNonnegative(raw: string?,minimum: number,maximum: number): number
	local digits=raw and raw:match("^[\t\n\f\r ]*%+?(%d+)")
	if not digits then return minimum end
	return math.clamp(tonumber(digits)or math.huge,minimum,maximum)
end
-- Legacy dimension hints are neither CSS numbers nor unsigned IDL values.
-- Consume a decimal prefix; only a percent at the cursor changes its unit.
function Values.dimension(raw: string?,nonzero: boolean?,maximum: number?): any
 if not raw then return nil end
 local digits,at=raw:match('^[\t\n\f\r ]*(%d+)()')
 if not digits then return nil end
 local value=tonumber(digits)
 if raw:sub(at,at)=='.'then
  at+=1;local fraction=raw:sub(at):match('^(%d*)')or''
  if #fraction>0 then value=tonumber(digits..'.'..fraction);at+=#fraction end
 end
 if not value or value==math.huge or value>(maximum or 100000)or nonzero and value==0 then return nil end
 return {Value=value,Percent=raw:sub(at,at)=='%'}
end
return Values
