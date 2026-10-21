--!strict
-- Atomic per-player saves use a renewable session lease and monotonic revisions.
local DataStoreService = game:GetService('DataStoreService')
local HttpService = game:GetService('HttpService')
local Store = {}
Store.__index = Store
local LEASE_SECONDS = 120
local function envelope(raw)
	if type(raw) == 'table' and raw.RecordVersion == 1 and type(raw.Data) == 'table' and type(raw.Revision) == 'number' and raw.Revision >= 0 and raw.Revision % 1 == 0 then return raw end
	return nil
end
function Store.new(schema, options)
	options = options or {}
	return setmetatable({Schema = schema, DataStore = options.DataStore or DataStoreService:GetDataStore(options.Name or 'WaylineBrowser_v1'), JobID = game.JobId, RetryCount = options.RetryCount or 3}, Store)
end
function Store:_Retry(callback)
	local last
	for attempt = 1, self.RetryCount do
		local ok, result = pcall(callback)
		if ok then return true, result end
		last = result
		if attempt < self.RetryCount then task.wait(math.min(2 ^ (attempt - 1), 4)) end
	end
	return false, last
end
function Store:Load(userID)
	local token = (if self.JobID ~= '' then self.JobID else 'studio')..':'..HttpService:GenerateGUID(false)
	local captured, reason, restored
	local ok, result = self:_Retry(function()
		return self.DataStore:UpdateAsync('player_'..userID, function(raw)
			local now = os.time()
			local record = envelope(raw)
			local original = if record then record.Data else raw
			local migrated, migrationError = self.Schema.Migrate(original)
			if not migrated then reason = 'malformed'; captured = nil; return nil end
			captured = migrated; restored = original ~= nil
			if record and type(record.Lease) == 'table' and record.Lease.Token ~= token and type(record.Lease.Expires) == 'number' and record.Lease.Expires > now then
				reason = 'conflict'; return nil
			end
			reason = nil
			return {RecordVersion = 1, Revision = if record then record.Revision else 0, Data = migrated, Lease = {Token = token, Expires = now + LEASE_SECONDS}, UpdatedAt = if record then record.UpdatedAt else now, WriteID = if record then record.WriteID else nil}
		end)
	end)
	if not ok then return {Data = self.Schema.DefaultData(), Restored = false, Writable = false, Error = 'unavailable', Token = token, Revision = 0} end
	if not result then return {Data = captured or self.Schema.DefaultData(), Restored = restored == true and captured ~= nil, Writable = false, Error = reason or 'unavailable', Token = token, Revision = 0} end
	return {Data = result.Data, Restored = restored == true, Writable = true, Token = token, Revision = result.Revision, LastLease = os.clock()}
end
function Store:Write(userID, state, data, release, changed)
	local writeID = HttpService:GenerateGUID(false)
	local expected = state.Revision
	local conflict = false
	local ok, result = self:_Retry(function()
		return self.DataStore:UpdateAsync('player_'..userID, function(raw)
			local record = envelope(raw)
			if record and record.WriteID == writeID then return record end
			if not record or type(record.Lease) ~= 'table' or record.Lease.Token ~= state.Token or record.Revision ~= expected then conflict = true; return nil end
			return {RecordVersion = 1, Revision = expected + (if changed then 1 else 0), Data = data, Lease = if release then nil else {Token = state.Token, Expires = os.time() + LEASE_SECONDS}, UpdatedAt = if changed then os.time() else record.UpdatedAt, WriteID = writeID}
		end)
	end)
	if not ok then return false, 'unavailable' end
	if not result or conflict then return false, 'conflict' end
	state.Revision = result.Revision; state.LastLease = os.clock()
	return true
end
return Store
