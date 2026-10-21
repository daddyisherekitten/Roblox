--!strict
-- Shared byte decoder for DOM byte sources and standard TextDecoder.
-- UTF state carries incomplete bytes across writes; no DOM or JS dependency.
local data=require(script.Parent.Data)
local Decoder={}
function Decoder.label(label:string):string?
 return data.Labels[(label:gsub('[A-Z]',string.lower):match('^[ \t\n\r\f]*(.-)[ \t\n\r\f]*$'))]
end
function Decoder.supported(name:string):boolean
 return data.Names[name]~=nil
end
 function Decoder.decode(state,bytes,stream,step)
  assert(Decoder.supported(state.Encoding),'Unsupported decoder encoding: '..tostring(state.Encoding))
  bytes=state.Pending..bytes;state.Pending="";local out={};local i=1;local outputBytes=0
  local function append(value)
   outputBytes+=#value
   assert(not state.MaxOutputBytes or outputBytes<=state.MaxOutputBytes,'Decoded HTML exceeds MaxDecodedBytes')
   table.insert(out,value)
  end
  local function emit(code)
   if not state.SeenBOM then state.SeenBOM=true;if code==0xfeff and not state.IgnoreBOM and (state.Encoding=="utf-8"or state.Encoding=="utf-16le"or state.Encoding=="utf-16be")then return end end
   append(utf8.char(code))
  end
  local function invalid()if state.Fatal then state.Pending="";error("The encoded data was not valid "..state.Encoding,0)end;emit(0xfffd)end
  if state.Encoding=='iso-2022-jp'then require(script.Parent.ISO2022JP).decode(state,bytes,stream,emit,invalid,step);return table.concat(out)end
  if state.Encoding=='gbk'or state.Encoding=='gb18030'or state.Encoding=='big5'or state.Encoding=='euc-jp'or state.Encoding=='shift_jis'or state.Encoding=='euc-kr'then
   require(script.Parent.Multibyte).decode(state,bytes,stream,emit,invalid,step);return table.concat(out)
  end
  local asciiCompatible=state.Encoding=='utf-8'or data.SingleByte[state.Encoding]~=nil or state.Encoding=='x-user-defined'
  while i<=#bytes do
   -- Keep ASCII runs as bounded chunks, avoiding one allocation per byte.
   -- Check every byte when a VM/loading budget is supplied, as before.
   if asciiCompatible and bytes:byte(i)<128 then
    local chunk=bytes:sub(i,math.min(i+1023,#bytes));local nonASCII=chunk:find('[\128-\255]')
    if nonASCII then chunk=chunk:sub(1,nonASCII-1)end
    if step then for _=1,#chunk do step()end end
    state.SeenBOM=true;append(chunk);i+=#chunk;continue
   end
   if step then step()end
   if data.SingleByte[state.Encoding]then
    local byte=bytes:byte(i);local code=if byte<128 then byte else data.SingleByte[state.Encoding][byte-127]
    if code then emit(code)else invalid()end;i+=1
   elseif state.Encoding=='x-user-defined'then local byte=bytes:byte(i);emit(if byte<128 then byte else 0xf780+byte-128);i+=1
   elseif state.Encoding=='replacement'then if not state.ReplacementSeen then state.ReplacementSeen=true;invalid()end;i=#bytes+1
   elseif state.Encoding=="utf-16le"or state.Encoding=="utf-16be"then
    if i+1>#bytes then if stream then state.Pending=bytes:sub(i)else invalid()end;break end
    local little=state.Encoding=="utf-16le";local function unit(at)local a,b=bytes:byte(at,at+1);return if little then a+b*256 else a*256+b end
    local code=unit(i);i+=2
    if code>=0xd800 and code<=0xdbff then
     if i+1>#bytes then if stream then state.Pending=bytes:sub(i-2)else invalid()end;break end
     local low=unit(i);if low>=0xdc00 and low<=0xdfff then emit(0x10000+(code-0xd800)*1024+low-0xdc00);i+=2 else invalid()end
    elseif code>=0xdc00 and code<=0xdfff then invalid()else emit(code)end
   else
    local first=bytes:byte(i)
    if first<128 then emit(first);i+=1;continue end
    local count=if first>=194 and first<=223 then 2 elseif first>=224 and first<=239 then 3 elseif first>=240 and first<=244 then 4 else 0
    if count==0 then invalid();i+=1;continue end
    local code=first%(2^(7-count));local consumed=1;local good=true
    for j=1,count-1 do local byte=bytes:byte(i+j)
     if not byte then if stream then state.Pending=bytes:sub(i);return table.concat(out)end;good=false;break end
     if byte<128 or byte>191 or(j==1 and((first==224 and byte<160)or(first==237 and byte>159)or(first==240 and byte<144)or(first==244 and byte>143)))then good=false;break end
     code=code*64+byte-128;consumed+=1
    end
    if good then emit(code)else invalid()end;i+=consumed
   end
  end;return table.concat(out)
 end
return Decoder
