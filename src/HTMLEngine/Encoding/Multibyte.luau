--!strict
-- Decode legacy byte sequences without consuming ASCII delimiters on errors.
-- Incomplete prefixes carry at most three bytes; indexes load on actual use.
local Multi={}
local function between(byte,low,high)return byte and byte>=low and byte<=high end
local function index(name)
	if name=='gbk'or name=='gb18030'then return require(script.Parent.Indexes.GB18030)
	elseif name=='big5'then return require(script.Parent.Indexes.Big5)
	elseif name=='euc-kr'then return require(script.Parent.Indexes.EUCKR)
	else return require(script.Parent.Indexes.JIS0208)end
end
local function rangePoint(pointer)
	if pointer>39419 and pointer<189000 or pointer>1237575 then return nil end
	if pointer==7457 then return 0xe7c7 end
	local ranges=require(script.Parent.Indexes.GBRanges);local low,high=1,#ranges
	while low<=high do local mid=math.floor((low+high)/2);if ranges[mid][1]<=pointer then low=mid+1 else high=mid-1 end end
	local row=ranges[high];return row[2]+pointer-row[1]
end
function Multi.decode(state,bytes,stream,emit,invalid,step)
	local name=state.Encoding;local map;local i=1
	local function point(pointer)
		if pointer==nil then return nil end;map=map or index(name);return map[pointer+1]
	end
	local function incomplete()
		if stream then state.Pending=bytes:sub(i)else invalid()end;i=#bytes+1
	end
	local function pairError(trail)invalid();i+=if trail<128 then 1 else 2 end
	while i<=#bytes do
		if step then step()end
		local lead,trail=bytes:byte(i,i+1)
		if lead<128 then emit(lead);i+=1;continue end
		if name=='gbk'or name=='gb18030'then
			if lead==0x80 then emit(0x20ac);i+=1;continue end
			if not between(lead,0x81,0xfe)then invalid();i+=1;continue end
			if not trail then incomplete();continue end
			if between(trail,0x30,0x39)then
				local third,fourth=bytes:byte(i+2,i+3)
				if not third then incomplete();continue end
				if not between(third,0x81,0xfe)then invalid();i+=1;continue end
				if not fourth then incomplete();continue end
				if not between(fourth,0x30,0x39)then invalid();i+=1;continue end
				local cp=rangePoint(((lead-0x81)*10+trail-0x30)*1260+(third-0x81)*10+fourth-0x30)
				if cp then emit(cp)else invalid()end;i+=4;continue
			end
			local pointer=if between(trail,0x40,0x7e)or between(trail,0x80,0xfe)then (lead-0x81)*190+trail-(if trail<0x7f then 0x40 else 0x41)else nil
			local cp=point(pointer);if cp then emit(cp);i+=2 else pairError(trail)end
		elseif name=='big5'then
			if not between(lead,0x81,0xfe)then invalid();i+=1;continue end
			if not trail then incomplete();continue end
			local pointer=if between(trail,0x40,0x7e)or between(trail,0xa1,0xfe)then (lead-0x81)*157+trail-(if trail<0x7f then 0x40 else 0x62)else nil
			if pointer==1133 or pointer==1135 or pointer==1164 or pointer==1166 then
				emit(if pointer<1164 then 0xca else 0xea);emit(if pointer==1133 or pointer==1164 then 0x304 else 0x30c);i+=2;continue
			end
			local cp=point(pointer);if cp then emit(cp);i+=2 else pairError(trail)end
		elseif name=='shift_jis'then
			if lead==0x80 then emit(lead);i+=1;continue end
			if between(lead,0xa1,0xdf)then emit(0xff61+lead-0xa1);i+=1;continue end
			if not (between(lead,0x81,0x9f)or between(lead,0xe0,0xfc))then invalid();i+=1;continue end
			if not trail then incomplete();continue end
			local pointer=if between(trail,0x40,0x7e)or between(trail,0x80,0xfc)then (lead-(if lead<0xa0 then 0x81 else 0xc1))*188+trail-(if trail<0x7f then 0x40 else 0x41)else nil
			local cp=if pointer and pointer>=8836 and pointer<=10715 then 0xe000+pointer-8836 else point(pointer)
			if cp then emit(cp);i+=2 else pairError(trail)end
		elseif name=='euc-jp'then
			if not (lead==0x8e or lead==0x8f or between(lead,0xa1,0xfe))then invalid();i+=1;continue end
			if not trail then incomplete();continue end
			if lead==0x8e and between(trail,0xa1,0xdf)then emit(0xff61+trail-0xa1);i+=2;continue end
			if lead==0x8f and between(trail,0xa1,0xfe)then
				local third=bytes:byte(i+2);if not third then incomplete();continue end
				local cp=if between(third,0xa1,0xfe)then require(script.Parent.Indexes.JIS0212)[(trail-0xa1)*94+third-0xa1+1]else nil
				if cp then emit(cp);i+=3 else invalid();i+=if third<128 then 2 else 3 end;continue
			end
			local cp=if between(lead,0xa1,0xfe)and between(trail,0xa1,0xfe)then point((lead-0xa1)*94+trail-0xa1)else nil
			if cp then emit(cp);i+=2 else pairError(trail)end
		else -- EUC-KR (Windows' extended Korean index)
			if not between(lead,0x81,0xfe)then invalid();i+=1;continue end
			if not trail then incomplete();continue end
			local cp=if between(trail,0x41,0xfe)then point((lead-0x81)*190+trail-0x41)else nil
			if cp then emit(cp);i+=2 else pairError(trail)end
		end
	end
end
return Multi
