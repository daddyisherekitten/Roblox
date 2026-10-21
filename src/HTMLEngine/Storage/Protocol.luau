--!strict
-- Wire and DataStore records use ASCII UTF-16 units. JavaScript strings may
-- contain lone surrogates, which JSON/Roblox UTF-8 strings cannot preserve.
local Strings = require(script.Parent.Parent.JavaScript.Strings)
local Protocol = {
	Version = 1, QuotaBytes = 1048576, MaxEntries = 4096,
	MaxChanges = 128, MaxWireBytes = 2300000, MaxReceipts = 32,
	MaxPendingBytes = 8388608,
}

function Protocol.origin(address: any): string?
	if type(address) ~= "string" or #address > 2048 or address:find("[%z\1-\32\127]") then return nil end
	local scheme, authority = address:match("^([%a][%w+%.%-]*)://([^/?#]+)")
	if not scheme or not authority then return nil end
	scheme = scheme:lower()
	if scheme ~= "http" and scheme ~= "https" then return nil end
	authority = authority:match("([^@]+)$") or authority
	local host, port
	if authority:sub(1, 1) == "[" then
		host, port = authority:match("^(%[[%x:%.]+%]):?(%d*)$")
		if not host or not host:find(":", 1, true) then return nil end
	else
		host, port = authority:match("^([%w%.%-]+):?(%d*)$")
		if not host or host == "" or host:find("%.%.") then return nil end
	end
	host = host:lower()
	if port ~= "" then
		local number = tonumber(port)
		if not number or number < 0 or number > 65535 then return nil end
		port = tostring(number)
		if (scheme == "http" and number == 80) or (scheme == "https" and number == 443) then port = "" end
	end
	return scheme .. "://" .. host .. (if port == "" then "" else ":" .. port)
end

local function units(value: string): {number}
	assert(type(value) == "string", "Storage strings must be strings")
	-- Validate UTF-8/WTF-8 rather than accepting overlong or truncated sequences.
	local index = 1
	while index <= #value do
		local first = value:byte(index)
		local count = if first < 128 then 0 elseif first >= 194 and first <= 223 then 1 elseif first >= 224 and first <= 239 then 2 elseif first >= 240 and first <= 244 then 3 else -1
		assert(count >= 0 and index + count <= #value, "Invalid storage string encoding")
		for offset = 1, count do
			local byte = value:byte(index + offset)
			assert(byte >= 128 and byte <= 191, "Invalid storage string encoding")
		end
		local second = if count > 0 then value:byte(index + 1) else 0
		assert(not (first == 224 and second < 160) and not (first == 240 and second < 144) and not (first == 244 and second > 143), "Invalid storage string encoding")
		index += count + 1
	end
	return Strings.units(value)
end

function Protocol.encode(value: string): string
	local parts = {}
	for _, unit in units(value) do table.insert(parts, string.format("%04x", unit)) end
	return table.concat(parts)
end

function Protocol.decode(value: string): string
	assert(type(value) == "string" and #value <= Protocol.QuotaBytes * 2 and #value % 4 == 0 and not value:find("[^%x]"), "Invalid encoded storage string")
	local result = {}
	for index = 1, #value, 4 do table.insert(result, tonumber(value:sub(index, index + 3), 16) :: number) end
	return Strings.fromUnits(result)
end

function Protocol.bytes(value: string): number
	return #units(value) * 2
end

function Protocol.createArea(): any
	return {Values = {}, Order = {}, Bytes = 0, QuotaBytes = Protocol.QuotaBytes, MaxEntries = Protocol.MaxEntries, Subscribers = {}}
end

function Protocol.cloneArea(area: any): any
	local result = Protocol.createArea()
	result.Values, result.Order, result.Bytes = table.clone(area.Values), table.clone(area.Order), area.Bytes
	return result
end

function Protocol.clientId(value: any): boolean
	return type(value) == "string" and #value >= 8 and #value <= 64 and value:match("^[%w%-_]+$") ~= nil
end

function Protocol.sequence(value: any): boolean
	return type(value) == "number" and value >= 1 and value <= 9007199254740991 and value % 1 == 0
end

function Protocol.encodeChange(change: any): any
	if change.Kind == "clear" then return {Kind = "clear"} end
	local result = {Kind = change.Kind, Key = Protocol.encode(change.Key)}
	assert(change.Kind == "set" or change.Kind == "remove", "Invalid storage operation")
	if change.Kind == "set" then result.Value = Protocol.encode(change.NewValue) end
	return result
end

local function listLength(value: any, maximum: number): number?
	if type(value) ~= "table" then return nil end
	local length, count = #value, 0
	if length > maximum then return nil end
	for key in value do
		if type(key) ~= "number" or key < 1 or key > length or key % 1 ~= 0 then return nil end
		count += 1
	end
	return if count == length then length else nil
end

function Protocol.validateChanges(encoded: any): (any?, string?, number?)
	local length = listLength(encoded, Protocol.MaxChanges)
	if not length or length == 0 then return nil, "Invalid storage change list" end
	local changes, wireBytes = {}, 0
	local success, message = pcall(function()
		for _, change in encoded do
			assert(type(change) == "table", "Invalid storage operation")
			local kind = change.Kind
			assert(kind == "set" or kind == "remove" or kind == "clear", "Invalid storage operation")
			for key in change do assert(key == "Kind" or (kind ~= "clear" and key == "Key") or (kind == "set" and key == "Value"), "Unexpected storage operation field") end
			wireBytes += 32
			local item = {Kind = kind}
			if kind ~= "clear" then
				assert(type(change.Key) == "string", "Missing storage key")
				wireBytes += #change.Key
				assert(wireBytes <= Protocol.MaxWireBytes, "Storage batch is too large")
				item.Key = Protocol.decode(change.Key)
			end
			if kind == "set" then
				assert(type(change.Value) == "string", "Missing storage value")
				wireBytes += #change.Value
				assert(wireBytes <= Protocol.MaxWireBytes, "Storage batch is too large")
				item.NewValue = Protocol.decode(change.Value)
			end
			table.insert(changes, item)
		end
	end)
	if not success then return nil, tostring(message) end
	return changes, nil, wireBytes
end

-- Apply to a cloned area when validating an untrusted batch. A quota failure
-- must never partially alter the live area or a persisted DataStore record.
function Protocol.applyChanges(area: any, changes: any): (boolean, string?)
	for _, change in changes do
		if change.Kind == "clear" then
			table.clear(area.Values); table.clear(area.Order); area.Bytes = 0
		elseif change.Kind == "remove" then
			local old = area.Values[change.Key]
			if old ~= nil then
				area.Bytes -= Protocol.bytes(change.Key) + Protocol.bytes(old)
				area.Values[change.Key] = nil
				local index = table.find(area.Order, change.Key)
				if index then table.remove(area.Order, index) end
			end
		else
			local old = area.Values[change.Key]
			local bytes = area.Bytes + Protocol.bytes(change.NewValue) - (if old ~= nil then Protocol.bytes(old) else 0) + (if old == nil then Protocol.bytes(change.Key) else 0)
			if bytes > Protocol.QuotaBytes or (old == nil and #area.Order >= Protocol.MaxEntries) then return false, "Storage quota exceeded" end
			if old == nil then table.insert(area.Order, change.Key) end
			area.Values[change.Key], area.Bytes = change.NewValue, bytes
		end
	end
	return true
end

function Protocol.createRecord(origin: string): any
	return {Version = Protocol.Version, Origin = origin, Entries = {}, Receipts = {}}
end

function Protocol.decodeRecord(record: any, origin: string): (any?, string?)
	if type(record) ~= "table" or record.Version ~= Protocol.Version or record.Origin ~= origin then return nil, "Invalid storage record or origin" end
	local entries, receipts = listLength(record.Entries, Protocol.MaxEntries), listLength(record.Receipts, Protocol.MaxReceipts)
	if not entries or not receipts then return nil, "Invalid storage record lists" end
	local area = Protocol.createArea()
	local success, message = pcall(function()
		local receiptIds = {}
		for _, receipt in record.Receipts do
			assert(type(receipt) == "table" and Protocol.clientId(receipt.ClientId) and Protocol.sequence(receipt.Sequence) and not receiptIds[receipt.ClientId], "Invalid storage receipt")
			receiptIds[receipt.ClientId] = true
		end
		for _, entry in record.Entries do
			assert(type(entry) == "table", "Invalid storage entry")
			local key, value = Protocol.decode(entry.Key), Protocol.decode(entry.Value)
			assert(area.Values[key] == nil, "Duplicate storage entry")
			area.Bytes += Protocol.bytes(key) + Protocol.bytes(value)
			assert(area.Bytes <= Protocol.QuotaBytes, "Storage record exceeds quota")
			area.Values[key] = value; table.insert(area.Order, key)
		end
	end)
	if not success then return nil, tostring(message) end
	return area
end

function Protocol.encodeRecord(area: any, origin: string, receipts: any?): any
	local record = Protocol.createRecord(origin)
	for _, key in area.Order do table.insert(record.Entries, {Key = Protocol.encode(key), Value = Protocol.encode(area.Values[key])}) end
	for _, receipt in receipts or {} do table.insert(record.Receipts, {ClientId = receipt.ClientId, Sequence = receipt.Sequence}) end
	return record
end

function Protocol.receipt(receipts: any, clientId: string): number
	for _, item in receipts do if item.ClientId == clientId then return item.Sequence end end
	return 0
end

function Protocol.setReceipt(receipts: any, clientId: string, sequence: number)
	for index = #receipts, 1, -1 do if receipts[index].ClientId == clientId then table.remove(receipts, index) end end
	table.insert(receipts, {ClientId = clientId, Sequence = sequence})
	while #receipts > Protocol.MaxReceipts do table.remove(receipts, 1) end
end

function Protocol.key(userId: number, origin: string): string
	-- Two independent 32-bit polynomial hashes keep DataStore keys bounded.
	-- The original origin is also checked inside every record, so collisions
	-- are rejected rather than merging two websites' data.
	local first, second = 5381, 2166136261
	for index = 1, #origin do
		local byte = origin:byte(index)
		first = (first * 33 + byte) % 4294967296
		second = (second * 65599 + byte) % 4294967296
	end
	return tostring(userId) .. ":" .. string.format("%08x%08x", first, second)
end

return Protocol
