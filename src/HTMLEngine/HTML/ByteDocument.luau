--!strict
-- Shared byte bounds/sniffing. Definite encodings feed the live parser in chunks;
-- tentative sources retain one bounded reparse before publication or scripts.
local Decoder=require(script.Parent.Parent.Encoding.Decoder)
local Data=require(script.Parent.Parent.Encoding.Data)
local Sniff=require(script.Parent.EncodingSniff)
local Work=require(script.Parent.Parent.WorkContext)
local Bytes={}
local function limit(value,default,name)
	value=if value==nil then default else value
	assert(type(value)=='number'and value>0 and value<math.huge and value%1==0,'Invalid '..name);return value
end
local function validate(bytes,options)
	assert(type(bytes)=='string','HTML bytes must be a string');options=if options==nil then {}else options
	assert(type(options)=='table','HTML byte options must be a dictionary')
	for _,key in {'OverrideEncoding','TransportEncoding','ParentEncoding','DefaultEncoding'}do
		assert(options[key]==nil or type(options[key])=='string','Invalid '..key)
	end
	assert(options.ParentSameOrigin==nil or type(options.ParentSameOrigin)=='boolean','Invalid ParentSameOrigin')
	local maxBytes=limit(options.MaxBytes,1048576,'MaxBytes');assert(#bytes<=maxBytes,'HTML exceeds MaxBytes')
	local maxDecoded=limit(options.MaxDecodedBytes,maxBytes*3,'MaxDecodedBytes')
	if options.DecodeChunkBytes~=nil then assert(limit(options.DecodeChunkBytes,4096,'DecodeChunkBytes')<=65536,'DecodeChunkBytes exceeds 65536')end
	return options,maxDecoded
end

local function decode(bytes,encoding,maxDecoded)
	Work.checkpoint()
	local state={Encoding=encoding,Pending='',SeenBOM=false,MaxOutputBytes=maxDecoded}
	return Decoder.decode(state,bytes,false,Work.checkpoint)
end

local function metadata(document,encoding,confidence,source,restarts,length)
	document.CharacterEncoding=Data.Names[encoding];document.EncodingConfidence=confidence
	document.EncodingSource=source;document.EncodingRestarts=restarts;document.ByteLength=length
end

-- A definite BOM/transport/override encoding cannot restart. Decode only as far
-- as the parser needs, preserving decoder state and document.write boundaries.
-- Tentative inputs keep the pre-publication reparse path until live restart is
-- linked to document/navigation teardown; no script side effect is duplicated.
function Bytes.session(bytes,options,create)
	local maxDecoded;options,maxDecoded=validate(bytes,options)
	local encoding,confidence,source=Sniff.detect(bytes,options)
	if confidence~='certain'then return nil end
	local chunkBytes=options.DecodeChunkBytes or 4096
	local parserOptions=table.clone(options);parserOptions.MaxBytes=maxDecoded;parserOptions._InputStream=true
	local session=create('',parserOptions)
	metadata(session.Document,encoding,confidence,source,0,#bytes)
	local advance,destroy=session.Advance,session.Destroy
	local position,total=1,0
	local state={Encoding=encoding,Pending='',SeenBOM=false,MaxOutputBytes=maxDecoded}
	local function feed()
		Work.checkpoint()
		local last=math.min(position+chunkBytes-1,#bytes)
		local finished=last==#bytes
		state.MaxOutputBytes=maxDecoded-total
		local value=Decoder.decode(state,bytes:sub(position,last),not finished,Work.checkpoint)
		total+=#value;position=last+1
		session:Append(value)
		if finished then bytes='';state=nil;session:Close()end
	end
	local function advanceInput(self,boundary)
		-- A document.write boundary may stop inside a buffered token. It must not
		-- pull more transport bytes or accidentally pass the caller's marker.
		if boundary then return advance(self,boundary)end
		while self.Alive and not self.Done do
			local scriptNode=advance(self)
			if scriptNode or self.Done then return scriptNode end
			feed()
		end
		return nil
	end
	function session:Advance(boundary)
		local ok,result=pcall(advanceInput,self,boundary)
		if not ok then self:Destroy();error(result,0)end
		return result
	end
	function session:Destroy()
		bytes='';state=nil
		destroy(self)
	end
	return session
end

function Bytes.parse(bytes,options,parse)
	local maxDecoded;options,maxDecoded=validate(bytes,options)
	local encoding,confidence,source=Sniff.detect(bytes,options);local restarts=0
	while true do
		Work.checkpoint()
		local decoded=decode(bytes,encoding,maxDecoded)
		local parserOptions=table.clone(options);parserOptions.MaxBytes=maxDecoded
		local restart={}
		parserOptions._EncodingProbe=function(attributes)
			if confidence~='tentative'then return end
			local candidate=Sniff.meta(attributes);if not candidate then return end
			confidence='certain'
			if encoding=='utf-16le'or encoding=='utf-16be'or encoding==candidate then return end
			encoding=candidate;source='parser-meta';error(restart,0)
		end
		local ok,document=pcall(parse,decoded,parserOptions)
		if not ok then if document~=restart then error(document,0)end;restarts+=1;assert(restarts<=1,'HTML encoding restart budget exceeded');continue end
		metadata(document,encoding,confidence,source,restarts,#bytes)
		return document
	end
end
return Bytes
