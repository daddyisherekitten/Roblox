--!strict
-- Stateful Japanese escape decoder. Invalid escapes reconsume their suffix;
-- the mode persists between streamed writes but resets for a fresh decode.
local JP={}
function JP.decode(state,bytes,stream,emit,invalid,step)
	local mode=state.ISO or {State='ascii',OutputState='ascii',Leading=0,Output=false};state.ISO=mode
	local i=1
	while i<=#bytes do
		if step then step()end;local byte=bytes:byte(i);local current=mode.State
		if current=='escape-start'then
			if byte==0x24 or byte==0x28 then mode.Leading=byte;mode.State='escape';i+=1
			else mode.State=mode.OutputState;mode.Output=false;invalid()end
		elseif current=='escape'then
			local lead=mode.Leading;mode.Leading=0
			local nextState=if lead==0x28 and byte==0x42 then 'ascii'elseif lead==0x28 and byte==0x4a then 'roman'elseif lead==0x28 and byte==0x49 then 'katakana'elseif lead==0x24 and (byte==0x40 or byte==0x42)then 'leading'else nil
			if nextState then local wasOutput=mode.Output;mode.State=nextState;mode.OutputState=nextState;mode.Output=true;i+=1;if wasOutput then invalid()end
			else mode.State=mode.OutputState;mode.Output=false;invalid();bytes=string.char(lead)..bytes:sub(i);i=1 end
		elseif current=='trailing'then
			mode.State=if byte==0x1b then 'escape-start'else 'leading';i+=1
			if byte>=0x21 and byte<=0x7e then local cp=require(script.Parent.Indexes.JIS0208)[(mode.Leading-0x21)*94+byte-0x21+1];if cp then emit(cp)else invalid()end
			else invalid()end
		elseif byte==0x1b then mode.State='escape-start';i+=1
		else
			mode.Output=false;i+=1
			if current=='leading'then
				if byte>=0x21 and byte<=0x7e then mode.Leading=byte;mode.State='trailing'else invalid()end
			elseif current=='katakana'then if byte>=0x21 and byte<=0x5f then emit(0xff61+byte-0x21)else invalid()end
			elseif byte<128 and byte~=0x0e and byte~=0x0f then emit(if current=='roman'and byte==0x5c then 0xa5 elseif current=='roman'and byte==0x7e then 0x203e else byte)
			else invalid()end
		end
	end
	if not stream then
		if mode.State=='trailing'then mode.State='leading';invalid()
		elseif mode.State=='escape-start'then mode.State=mode.OutputState;mode.Output=false;invalid()
		elseif mode.State=='escape'then
			local lead=mode.Leading;mode.Leading=0;mode.State=mode.OutputState;mode.Output=false;invalid()
			-- Replayed '$'/'(' at EOF still obey the previous output mode.
			JP.decode(state,string.char(lead),false,emit,invalid,step)
		end
	end
end
return JP
