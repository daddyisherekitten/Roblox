--!strict
-- EncodingService decodes trusted generated tiles, never page-supplied payloads.
local Decoder = {}
local MAX_TILE_BYTES = 1024 * 1024 * 4
function Decoder.decode(packed: any, encodingService: any?, compressionAlgorithm: any?): buffer
	assert(type(packed)=="table", "Invalid packaged pixel tile")
	local width,height=packed.Width,packed.Height
	assert(type(width)=="number" and width%1==0 and width>0 and width<=1024, "Invalid packaged pixel width")
	assert(type(height)=="number" and height%1==0 and height>0 and height<=1024, "Invalid packaged pixel height")
	local bytes=width*height*4
	assert(bytes<=MAX_TILE_BYTES and packed.Bytes==bytes, "Invalid packaged pixel byte length")
	assert(type(packed.Data)=="table" and #packed.Data>0, "Missing packaged pixel data")
	local encodedBytes=0
	for _,chunk in packed.Data do
		assert(type(chunk)=="string" and #chunk<=60000, "Invalid packaged pixel chunk")
		encodedBytes+=#chunk
	end
	assert(encodedBytes<=MAX_TILE_BYTES*2, "Packaged pixel payload exceeds budget")
	local service=encodingService or game:GetService("EncodingService")
	local algorithm=compressionAlgorithm or Enum.CompressionAlgorithm.Zstd
	local compressed=service:Base64Decode(buffer.fromstring(table.concat(packed.Data)))
	assert(typeof(compressed)=="buffer", "Invalid decoded compressed pixels")
	assert(service:GetDecompressedBufferSize(compressed,algorithm)==bytes, "Packaged pixel decompressed size mismatch")
	local pixels=service:DecompressBuffer(compressed,algorithm)
	assert(typeof(pixels)=="buffer" and buffer.len(pixels)==bytes, "Packaged pixel output size mismatch")
	return pixels
end
return Decoder
