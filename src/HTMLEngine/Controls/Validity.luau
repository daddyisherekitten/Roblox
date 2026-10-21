--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
-- Raw validity flags are shared by DOM reads, CSS snapshots and native forms.
-- Candidate eligibility is separate: barred controls still expose raw flags.
local Text=require(script.Parent.TextValue)
local URL=require(script.Parent.URLValue)
local Numeric=require(script.Parent.NumericValue)
local Temporal=require(script.Parent.TemporalValue)
local Pattern=require(script.Parent.Pattern)
local Validity={}
function Validity.read(node:any,c:any,radioPeers:any?,patternMismatch:any?):(any,string)
	local kind,value=c.Type,c.Value or ''
	local missing,mismatch,short,long,bad,under,over,step=false,false,false,false,false,false,false,false
	if kind=='radio'then
		local required,checked=c.Required==true,c.Checked==true
		if radioPeers then radioPeers(function(peer)required=required or peer.Required;checked=checked or peer.Checked end)end
		missing=(node.Attributes.name or '')~=''and required and not checked
	elseif c.Required then
		if kind=='checkbox'then missing=not c.Checked
		elseif kind=='select'then
			local option=c.Options[c.SelectedIndex]
			missing=not option or (not c.SelectMultiple and c.SelectSize==1 and c.SelectedIndex==1 and option.Value==''and option.Node.Parent==node)
		elseif kind=='file'then missing=value==''
		elseif Text.applies(kind)or Temporal.applies(kind)or kind=='number'then missing=not c.Disabled and not c.ReadOnly and value==''end
	end
	mismatch=value~=''and ((kind=='email'and not Text.email(value,c.Multiple))or(kind=='url'and not URL.valid(value)))
	if Text.applies(kind)and c.UserEdited and value~=''then
		local length=Text.length(value);short=c.MinLength~=nil and length<c.MinLength;long=c.MaxLength~=nil and length>c.MaxLength
	end
	if kind=='number'or kind=='range'then
		bad=kind=='number'and c.BadInput==true
		local n=Numeric.parse(value);local limits=if kind=='range'then c.Range else c.Number
		if n then
			under=limits.Min~=nil and n<limits.Min;over=limits.Max~=nil and n>limits.Max
			if limits.Step then local index=(n-limits.Base)/limits.Step;step=math.abs(index)==math.huge or math.abs(index-math.round(index))>1e-8 end
		end
	elseif Temporal.applies(kind)then bad=c.BadInput==true;under,over,step=Temporal.flags(c)end
	local pattern=false
	if ElementNames.htmlName(node)=='input'and Text.applies(kind)and value~=''and node.Attributes.pattern~=nil then pattern=(patternMismatch or Pattern.mismatch)(node,value)end
	local custom=(c.DOMCustomValidity or '')~=''
	local flags={valueMissing=missing,typeMismatch=mismatch,tooShort=short,tooLong=long,badInput=bad,rangeUnderflow=under,rangeOverflow=over,
		stepMismatch=step,customError=custom,patternMismatch=pattern,valid=not(missing or mismatch or short or long or bad or under or over or step or custom or pattern)}
	local reason=if missing then 'missing'elseif mismatch then kind elseif short then 'short'elseif kind=='number'then 'number'elseif Temporal.applies(kind)then 'temporal'else ''
	return flags,reason
end
return Validity
