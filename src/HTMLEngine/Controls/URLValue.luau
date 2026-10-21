--!strict
-- Absolute URL syntax checks only; no navigation/network requests or URL rewriting.
local URLValue = {}
local SPECIAL = {http=true, https=true, ftp=true, ws=true, wss=true}
local function ipv6(host: string): boolean
	if host:find("[^%x:.]") then return false end
	local compression = host:find("::", 1, true)
	if (host:sub(1,1) == ":" and host:sub(1,2) ~= "::") or (host:sub(-1) == ":" and host:sub(-2) ~= "::") then return false end
	if compression and host:find("::", compression+2, true) then return false end
	local parts = string.split(host, ":")
	local count = 0
	for index, part in parts do
		if part == "" then
			if not compression then return false end
		elseif part:find(".", 1, true) then
			if index ~= #parts then return false end
			local bytes = string.split(part, ".")
			if #bytes ~= 4 then return false end
			for _, byte in bytes do
				if not byte:match("^%d+$") or #byte > 3 or (#byte > 1 and byte:sub(1,1) == "0") or tonumber(byte) > 255 then return false end
			end
			count += 2
		else
			if #part > 4 then return false end
			count += 1
		end
	end
	if host:find(":::", 1, true) then return false end
	if compression then return count < 8 end
	return count == 8
end
local function ipv4(host: string): boolean
	local parts = string.split(host:gsub("%.$", ""), ".")
	local last = parts[#parts]
	if not last:match("^%d+$") and not last:lower():match("^0x%x*$") then return true end
	if #parts > 4 then return false end
	for index, part in parts do
		if part == "" then return false end
		local base = 10
		if part:sub(1,2):lower() == "0x" then base,part=16,part:sub(3)
		elseif #part > 1 and part:sub(1,1) == "0" then base,part=8,part:sub(2) end
		if part ~= "" and not part:match(if base == 16 then "^%x+$" elseif base == 8 then "^[0-7]+$" else "^%d+$") then return false end
		local number = if part == "" then 0 else tonumber(part,base)
		if not number or number >= (if index == #parts then 256^(5-#parts) else 256) then return false end
	end
	return true
end
local function authority(value: string, empty: boolean?, special: boolean?): boolean
	-- Credentials precede the last @; they do not replace a required host.
	local hostport = value:match(".*@(.*)$") or value
	if hostport == "" then return empty == true end
	local host, port
	if hostport:sub(1,1) == "[" then
		local address, tail = hostport:match("^%[([^%]]+)%](.*)$")
		if not address or not ipv6(address) or (tail ~= "" and tail:sub(1,1) ~= ":") then return false end
		port = if tail ~= "" then tail:sub(2) else nil
	else
		host, port = hostport:match("^([^:]+):(.*)$")
		host = host or hostport
		if special ~= false then host = host:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex,16)) end) end
		if host == "" or host:find("[%z\1-\32\127/#:<>?@%[\\%]%^|]") then return false end
		if special ~= false and (host:find("%%") or not ipv4(host)) then return false end
	end
	return port == nil or port == "" or (port:match("^%d+$") ~= nil and (tonumber(port) or math.huge) <= 65535)
end
function URLValue.valid(value: string): boolean
	local scheme, rest = value:match("^([a-zA-Z][a-zA-Z0-9+%.%-]*):(.*)$")
	if not scheme then return false end
	scheme = scheme:lower()
	-- URL parsing removes embedded tabs/newlines; input sanitization removes CR/LF.
	rest = rest:gsub("\t", "")
	if SPECIAL[scheme] then
		rest = rest:gsub("\\", "/"):gsub("^/+", "")
		return authority(rest:match("^[^/?#]*") or "")
	end
	if scheme == "file" then
		if rest:sub(1,2) ~= "//" then return true end
		local host = rest:sub(3):match("^[^/\\?#]*") or ""
		if host:sub(1,1) == "[" then return host:sub(-1) == "]" and ipv6(host:sub(2,-2)) end
		return not host:find("[@:]") and authority(host, true)
	end
	if rest:sub(1,2) == "//" then return authority(rest:sub(3):match("^[^/?#]*") or "", true, false) end
	return true -- Opaque absolute URLs, such as mailto:, data: and urn:.
end
return URLValue
