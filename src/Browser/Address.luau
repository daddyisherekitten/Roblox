--!strict
-- Local address resolution and search. External rendering is supplied by the host.
local Address = {}
Address.__index = Address
Address.Scheme = 'wayline'
Address.Home = 'wayline://home'

local function trim(value)
	return value:match('^%s*(.-)%s*$') or ''
end
local function encode(value)
	return (value:gsub('[^%w%-%._~]', function(character)
		return string.format('%%%02X', string.byte(character))
	end))
end
local function decode(value)
	return (value:gsub('%+', ' '):gsub('%%(%x%x)', function(byte)
		return string.char(tonumber(byte, 16) :: number)
	end))
end
local function query(value)
	local params = {}
	for part in value:gmatch('[^&]+') do
		local key, item = part:match('^([^=]*)=(.*)$')
		key, item = decode(key or part), decode(item or '')
		params[key] = item
	end
	local keys = {}
	for key in params do table.insert(keys, key) end
	table.sort(keys)
	local parts = {}
	for _, key in keys do table.insert(parts, encode(key)..'='..encode(params[key])) end
	return params, table.concat(parts, '&')
end
local function ipv6(literal)
	if literal:find(':::', 1, true) then return false end
	local ipv4 = literal:match('([^:]+)$')
	if ipv4 and ipv4:find('.', 1, true) then
		local octets = {}
		for octet in ipv4:gmatch('[^.]+') do
			if not octet:match('^%d+$') or tonumber(octet) > 255 then return false end
			table.insert(octets, octet)
		end
		if #octets ~= 4 or ipv4:sub(1, 1) == '.' or ipv4:sub(-1) == '.' or ipv4:find('..', 1, true) then return false end
		literal = literal:sub(1, #literal - #ipv4)..'0:0'
	end
	local compressed = literal:find('::', 1, true)
	if compressed and literal:find('::', compressed + 2, true) then return false end
	if literal:sub(1, 1) == ':' and literal:sub(1, 2) ~= '::' then return false end
	if literal:sub(-1) == ':' and literal:sub(-2) ~= '::' then return false end
	local groups = 0
	for part in literal:gmatch('[^:]+') do
		if #part > 4 or not part:match('^%x+$') then return false end
		groups += 1
	end
	return if compressed then groups < 8 else groups == 8
end
local function external(value)
	local scheme, authority, tail = value:match('^([%a][%w+%-%.]*)://([^/%?#]+)(.*)$')
	if not scheme then return nil end
	scheme = scheme:lower()
	if scheme ~= 'http' and scheme ~= 'https' then return nil end
	if authority:find('@', 1, true) or authority:find('%s') then return nil end
	authority = authority:lower()
	local host, port
	if authority:sub(1, 1) == '[' then
		local ending = authority:find(']', 2, true)
		if not ending then return nil end
		host = authority:sub(1, ending)
		local literal = host:sub(2, -2)
		if not ipv6(literal) then return nil end
		local suffix = authority:sub(ending + 1)
		if suffix ~= '' then port = suffix:match('^:(%d+)$'); if not port then return nil end end
	else
		host, port = authority:match('^(.-):(%d+)$')
		host = host or authority
		if not host:match('^[%w%.%-%_]+$') then return nil end
	end
	if port then
		local numeric = tonumber(port)
		if not numeric or numeric > 65535 then return nil end
		authority = host..(if (scheme == 'https' and numeric == 443) or (scheme == 'http' and numeric == 80) then '' else ':'..tostring(numeric))
	end
	if authority == '' then return nil end
	if tail == '' or tail:sub(1, 1) == '?' or tail:sub(1, 1) == '#' then tail = '/'..tail end
	return scheme..'://'..authority..tail
end
function Address.Encode(value) return encode(value) end
function Address.Decode(value) return decode(value) end
function Address.NormalizeExternal(value) return external(trim(value)) end
function Address.new(registry, externalResolver)
	return setmetatable({Registry = registry, ExternalResolver = externalResolver}, Address)
end
function Address:Search(text)
	text = trim(tostring(text or '')):lower()
	local matches = {}
	for _, item in self.Registry:List() do
		local route = tostring(item.Route or ''):lower()
		local title = tostring(item.Title or ''):lower()
		local url = item.Address or ('wayline://'..route)
		local rank = 0
		if text == '' then rank = 1
		elseif title == text or route == text or url:lower() == text then rank = 100
		elseif title:sub(1, #text) == text or route:sub(1, #text) == text or url:lower():sub(1, #text) == text then rank = 60
		elseif title:find(text, 1, true) or route:find(text, 1, true) or url:lower():find(text, 1, true) then rank = 40
		elseif tostring(item.Description or ''):lower():find(text, 1, true) then rank = 20
		else
			for _, keyword in item.Keywords or {} do
				if tostring(keyword):lower():find(text, 1, true) then rank = 15; break end
			end
		end
		if rank > 0 then
			table.insert(matches, {Address = url, URL = url, Route = route, Title = item.Title, Description = item.Description, Icon = item.Icon, Score = rank, Definition = item})
		end
	end
	table.sort(matches, function(a, b)
		if a.Score ~= b.Score then return a.Score > b.Score end
		return a.Title:lower() < b.Title:lower()
	end)
	return matches
end
function Address:Resolve(text, base, allowRelative)
	local function failure(url, reason)
		return {URL = url, Kind = 'error', Route = 'error', Title = 'Page unavailable', Icon = 'warning', Error = reason}
	end
	if type(text) ~= 'string' then return failure(Address.Home, 'Enter an address or search phrase.') end
	text = trim(text)
	if text == '' or text == 'about:newtab' then text = Address.Home end
	local length = utf8.len(text)
	if not length or length > 512 or text:find('[%z\1-\31\127]') then return failure(Address.Home, 'Addresses must contain at most 512 readable characters.') end
	local relative = text:sub(1,1)=='#'or text:sub(1,1)=='/'or text:sub(1,2)=='./'or text:sub(1,3)=='../'
	if allowRelative and relative and type(base)=='string'and external(base)then
		if self.ExternalResolver then
			local ok,result=pcall(self.ExternalResolver,text,base)
			local url=if ok and type(result)=='table'then result.URL elseif ok and type(result)=='string'then result else nil
			url=if type(url)=='string'then external(url)else nil
			if url and(type(result)~='table'or result.Kind==nil or result.Kind=='external')then
				if type(result)=='table'then
					local resolved=table.clone(result);resolved.URL=url;resolved.Kind='external';return resolved
				end
				return {URL=url,Kind='external',Title=url,Icon='page'}
			end
		end
		return failure(text,'This relative address is not registered by the host.')
	end
	local scheme, rest = text:match('^([%a][%w+%-%.]*)://(.*)$')
	local bare = text:match('^([%w%-_]+)$')
	local routeText = if scheme and scheme:lower() == Address.Scheme then rest else nil
	if bare and self.Registry:Get(bare:lower()) then routeText = bare end
	if routeText then
		local route, rawQuery = routeText:match('^([^%?#]*)(.*)$')
		route = (route or ''):lower():gsub('/+$', '')
		local raw = (rawQuery or ''):match('^%?([^#]*)') or ''
		local params, encoded = query(raw)
		local url = 'wayline://'..route..(if encoded ~= '' then '?'..encoded else '')
		local definition = self.Registry:Get(route)
		if not definition then return failure(url, 'This internal page is no longer registered. Return Home to choose another page.') end
		return {URL = url, Kind = 'internal', Route = route, Query = params, Title = definition.Title, Icon = definition.Icon, Definition = definition}
	end
	local lower = text:lower()
	local authority = lower:match('^([^/%?#]+)') or ''
	local loopback = authority == 'localhost' or authority:match('^localhost:%d+$') ~= nil
		or authority == '127.0.0.1' or authority:match('^127%.0%.0%.1:%d+$') ~= nil
		or authority == '[::1]' or authority:match('^%[::1%]:%d+$') ~= nil
	local looksExternal = scheme ~= nil or loopback or text:match('^[%a][%w+%-%.]*:') ~= nil or text:match('^[%w%-]+%.[%w%.%-]+[:/%?#]?') ~= nil
	if text == 'about:blank' then
		if self.Registry.FindAddress then
			local definition = self.Registry:FindAddress(text)
			if definition and definition.Kind == 'external' then return {URL = text, Kind = 'external', Title = definition.Title or 'Blank page', Icon = definition.Icon or 'page', Definition = definition} end
		end
		if self.ExternalResolver then
			local ok, result = pcall(self.ExternalResolver, text, base)
			if ok and result then return if type(result) == 'table' then result else {URL = text, Kind = 'external', Title = 'Blank page', Icon = 'page'} end
		end
		return failure(text, 'Blank external pages are not available in this browser.')
	end
	if looksExternal then
		local url = external(if scheme then text else (if loopback then 'http://' else 'https://')..text)
		if not url then return failure(text, 'Only internal Wayline pages and host-registered HTTP addresses are supported.') end
		if self.Registry.FindAddress then
			local definition = self.Registry:FindAddress(url)
			if definition and definition.Kind == 'external' then return {URL = url, Kind = 'external', Title = definition.Title or url, Icon = definition.Icon or 'page', Definition = definition} end
		end
		if self.ExternalResolver then
			local ok, result = pcall(self.ExternalResolver, url, base)
			if ok and result then
				if type(result) == 'table' then result.URL = result.URL or url; result.Kind = result.Kind or 'external'; return result end
				return {URL = url, Kind = 'external', Title = url, Icon = 'page'}
			end
		end
		return failure(url, 'This address is not registered by the host. Wayline cannot render arbitrary websites.')
	end
	return self:Resolve('wayline://search?q='..encode(text))
end
return Address
