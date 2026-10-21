--!strict
local Icons=require(script.Parent.CursorIcons)
local Lease={}
local states=setmetatable({},{__mode="k"})

function Lease.new(input: any,priority: number?): any
	local state=states[input]
	if not state then state={Requests={},Serial=0}; states[input]=state end
	local token,disposed={},false
	local function paint()
		local chosen
		for _,r in state.Requests do
			if not chosen or r.Priority > chosen.Priority or (r.Priority == chosen.Priority and r.Serial > chosen.Serial) then chosen=r end
		end
		if chosen then
			if not state.Saved then
				state.Saved={Icon=input.MouseIcon or "",Enabled=input.MouseIconEnabled ~= false}
			end
			local icon=Icons[chosen.Kind] or chosen.Kind
			local enabled=chosen.Kind ~= "none"
			if input.MouseIcon ~= icon then input.MouseIcon=icon end
			if input.MouseIconEnabled ~= enabled then input.MouseIconEnabled=enabled end
			state.Icon,state.Enabled=icon,enabled
		elseif state.Saved then
			-- Do not overwrite a cursor another script changed after our last write.
			if input.MouseIcon == state.Icon then input.MouseIcon=state.Saved.Icon end
			if input.MouseIconEnabled == state.Enabled then input.MouseIconEnabled=state.Saved.Enabled end
			state.Saved=nil
		end
	end
	local self={}
	function self:Set(kind: string?)
		if disposed then return end
		if kind then state.Serial+=1; state.Requests[token]={Kind=kind,Priority=priority or 0,Serial=state.Serial}
		else state.Requests[token]=nil end
		paint()
	end
	function self:Destroy() if disposed then return end; self:Set(nil); disposed=true end
	return self
end
return Lease
