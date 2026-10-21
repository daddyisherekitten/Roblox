--!strict
-- Resolve once during CSS compilation; font profiles/measurements stay unchanged.
local Syntax = require(script.Parent.Syntax)
local FontFamily = {}
FontFamily.Default = 'PT Serif'
local fonts = {
	['arial'] = Enum.Font.Arial, ['source sans pro'] = Enum.Font.SourceSans,
	['ubuntu'] = Enum.Font.Ubuntu, ['roboto'] = 'Roboto',
	['roboto condensed'] = 'Roboto Condensed', ['roboto mono'] = 'Roboto Mono',
	['roboto slab'] = 'Roboto Slab', ['inter'] = 'Inter', ['open sans'] = 'Open Sans',
	['pt serif'] = 'PT Serif',
	['lato'] = 'Lato',
	['lora'] = 'Lora',
	['merriweather'] = 'Merriweather',
	['montserrat'] = 'Montserrat',
	['noto sans'] = 'Noto Sans',
	['nunito sans'] = 'Nunito Sans',
	['playfair display'] = 'Playfair Display',
	['poppins'] = 'Poppins',
	['work sans'] = 'Work Sans',
	['builder sans'] = 'Builder Sans',
}
local generics = {
	['sans-serif'] = Enum.Font.Arial, ['serif'] = 'Roboto Slab',
	['monospace'] = 'Roboto Mono', ['system-ui'] = Enum.Font.Arial,
}
local reserved = {inherit = true, initial = true, unset = true, revert = true, ['revert-layer'] = true, default = true}

function FontFamily.parse(value: string): any
	local selected, cursor = nil, 1
	while true do
		local part, nextCursor, delimiter = Syntax.scan(value, cursor, ',')
		cursor = nextCursor
		part = part:match('^%s*(.-)%s*$') :: string
		if part == '' or part:find('\\', 1, true) then return nil end -- CSS escapes not supported yet.
		local quote = part:sub(1, 1)
		local font
		if quote == '"' or quote == "'" then
			if #part < 2 or part:sub(-1) ~= quote then return nil end
			local name = part:sub(2, -2)
			if name:find(quote, 1, true) or name:find('[\r\n\f]') then return nil end
			font = fonts[name:lower()] -- Quoted generic names are literal family names.
		else
			local names = {}
			for name in part:gmatch('%S+') do
				-- Unquoted names are sequences of CSS identifiers (without escapes).
				if not name:match('^%-?[a-z_\128-\255][a-z0-9_\128-\255%-]*$')
					and not name:match('^%-%-[a-z0-9_\128-\255%-]+$') then return nil end
				if reserved[name] then return nil end
				table.insert(names, name)
			end
			local name = table.concat(names, ' ')
			font = generics[name] or fonts[name]
		end
		selected = selected or font
		if delimiter == '' then break end
	end
	-- false is a valid unavailable list; resolve its fallback per page, not at compile time.
	return selected or false
end

function FontFamily.default(value: any): any
	if value == nil then return FontFamily.Default end
	assert(type(value) == 'string', 'options.DefaultFont must be a font-family string')
	local font = FontFamily.parse(value:lower())
	assert(font, 'options.DefaultFont must name a supported font family')
	return font
end

return FontFamily
