--!strict
--!optimize 2
--!native
-- Deterministic PNG export for a straight-alpha RGBA Canvas buffer.
local CanvasPNG={}
local crcTable={}
for value=0,255 do
	local crc=value
	for _=1,8 do crc=if bit32.band(crc,1)~=0 then bit32.bxor(0xedb88320,bit32.rshift(crc,1))else bit32.rshift(crc,1)end
	crcTable[value]=crc
end

local function writeByte(target: buffer,offset: number,value: number)buffer.writeu8(target,offset,value%256)end
local function writeBE32(target: buffer,offset: number,value: number)
	writeByte(target,offset,math.floor(value/16777216));writeByte(target,offset+1,math.floor(value/65536));writeByte(target,offset+2,math.floor(value/256));writeByte(target,offset+3,value)
end
local function writeText(target: buffer,offset: number,value: string)
	for index=1,#value do buffer.writeu8(target,offset+index-1,string.byte(value,index))end
end
local function crc32(source: buffer,offset: number,length: number,checkpoint: any?): number
	local crc=0xffffffff
	for index=offset,offset+length-1 do if checkpoint and(index-offset)%16384==0 then checkpoint()end;local byte=buffer.readu8(source,index);crc=bit32.bxor(bit32.rshift(crc,8),crcTable[bit32.band(bit32.bxor(crc,byte),0xff)])end
	return bit32.bxor(crc,0xffffffff)
end
local function adler32(source: buffer,checkpoint: any?): number
	local a,b,index,length=1,0,0,buffer.len(source)
	while index<length do
		if checkpoint then checkpoint()end
		local stop=math.min(length,index+5552)
		for at=index,stop-1 do a+=buffer.readu8(source,at);b+=a end
		a%=65521;b%=65521;index=stop
	end
	return b*65536+a
end

function CanvasPNG.encode(width: number,height: number,pixels: buffer,checkpoint: any?): buffer
	assert(width>0 and height>0 and buffer.len(pixels)>=width*height*4,"PNG export requires a non-empty RGBA bitmap")
	local rowBytes=width*4;local raw=buffer.create((rowBytes+1)*height)
	for y=0,height-1 do if checkpoint then checkpoint()end;local row=y*(rowBytes+1);buffer.writeu8(raw,row,0);buffer.copy(raw,row+1,pixels,y*rowBytes,rowBytes)end
	local rawLength=buffer.len(raw);local blockCount=math.ceil(rawLength/65535);local zlibLength=2+blockCount*5+rawLength+4
	local output=buffer.create(8+25+12+zlibLength+12);local offset=0
	for _,byte in {137,80,78,71,13,10,26,10}do buffer.writeu8(output,offset,byte);offset+=1 end
	writeBE32(output,offset,13);offset+=4;local ihdrStart=offset;writeText(output,offset,"IHDR");offset+=4;writeBE32(output,offset,width);writeBE32(output,offset+4,height);offset+=8
	for _,byte in {8,6,0,0,0}do buffer.writeu8(output,offset,byte);offset+=1 end
	writeBE32(output,offset,crc32(output,ihdrStart,17,checkpoint));offset+=4
	writeBE32(output,offset,zlibLength);offset+=4;local idatStart=offset;writeText(output,offset,"IDAT");offset+=4;buffer.writeu8(output,offset,0x78);buffer.writeu8(output,offset+1,0x01);offset+=2
	local sourceOffset=0
	while sourceOffset<rawLength do
		if checkpoint then checkpoint()end
		local length=math.min(65535,rawLength-sourceOffset);buffer.writeu8(output,offset,if sourceOffset+length==rawLength then 1 else 0);offset+=1
		buffer.writeu8(output,offset,length%256);buffer.writeu8(output,offset+1,math.floor(length/256));local inverse=65535-length;buffer.writeu8(output,offset+2,inverse%256);buffer.writeu8(output,offset+3,math.floor(inverse/256));offset+=4
		buffer.copy(output,offset,raw,sourceOffset,length);offset+=length;sourceOffset+=length
	end
	writeBE32(output,offset,adler32(raw,checkpoint));offset+=4;writeBE32(output,offset,crc32(output,idatStart,4+zlibLength,checkpoint));offset+=4
	writeBE32(output,offset,0);offset+=4;local iendStart=offset;writeText(output,offset,"IEND");offset+=4;writeBE32(output,offset,crc32(output,iendStart,4,checkpoint));offset+=4
	assert(offset==buffer.len(output),"PNG encoder size mismatch")
	return output
end

local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";local alphabetChars=table.create(64)
for index=1,64 do alphabetChars[index]=alphabet:sub(index,index)end
function CanvasPNG.base64(source: buffer,checkpoint: any?): string
	local output={};local length=buffer.len(source)
	for chunkStart=0,length-1,3072 do
		if checkpoint then checkpoint()end
		local parts={};local chunkEnd=math.min(length,chunkStart+3072);local part=1
		for index=chunkStart,chunkEnd-1,3 do
			local a=buffer.readu8(source,index);local hasB=index+1<length;local hasC=index+2<length;local b=if hasB then buffer.readu8(source,index+1)else 0;local c=if hasC then buffer.readu8(source,index+2)else 0
			parts[part]=alphabetChars[math.floor(a/4)+1];parts[part+1]=alphabetChars[(a%4)*16+math.floor(b/16)+1]
			parts[part+2]=if hasB then alphabetChars[(b%16)*4+math.floor(c/64)+1]else"=";parts[part+3]=if hasC then alphabetChars[c%64+1]else"=";part+=4
		end
		table.insert(output,table.concat(parts))
	end
	return table.concat(output)
end

function CanvasPNG.dataURL(width: number,height: number,pixels: buffer,checkpoint: any?): string
	if width==0 or height==0 then return"data:,"end
	return"data:image/png;base64,"..CanvasPNG.base64(CanvasPNG.encode(width,height,pixels,checkpoint),checkpoint)
end
return CanvasPNG
