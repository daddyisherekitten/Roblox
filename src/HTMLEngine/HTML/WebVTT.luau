--!strict
-- Deliberately small WebVTT cue parser for plain subtitle/caption tracks.
local WebVTT = {}

local function timestamp(value: string): number?
	local hours, minutes, seconds, milliseconds = value:match("^(%d%d):(%d%d):(%d%d)%.(%d%d%d)$")
	if not hours then minutes, seconds, milliseconds = value:match("^(%d%d):(%d%d)%.(%d%d%d)$"); hours = "0" end
	local h, m, s, ms = tonumber(hours), tonumber(minutes), tonumber(seconds), tonumber(milliseconds)
	if not h or not m or not s or not ms or m > 59 or s > 59 then return nil end
	return h * 3600 + m * 60 + s + ms / 1000
end

local function plain(value: string): string
	return value:gsub("<[^>]*>", ""):gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&nbsp;", " ")
end

function WebVTT.parse(source: string): ({any}, {string})
	local normalized = source:gsub("^\239\187\191", ""):gsub("\r\n?", "\n")
	local cues, diagnostics = {}, {}
	if not normalized:match("^WEBVTT[%s\n]") then return cues, {"WebVTT header is missing"} end
	local sourceLines=string.split(normalized,"\n")
	local index=2
	while index<=#sourceLines do
		while index<=#sourceLines and sourceLines[index]:match("^%s*$") do index+=1 end
		if index>#sourceLines then break end
		local lines={}
		while index<=#sourceLines and not sourceLines[index]:match("^%s*$") do table.insert(lines,sourceLines[index]);index+=1 end
		local timing = 1
		if lines[1] and not lines[1]:find("-->", 1, true) then timing = 2 end
		local from, to = nil, nil
		if lines[timing] then
			from, to = lines[timing]:match("^%s*(%S+)%s+%-%->%s+(%S+)")
		end
		if from and to then
			local first, last = timestamp(from), timestamp(to)
			if first and last and last > first then
				local text = {}
				for index = timing + 1, #lines do table.insert(text, lines[index]) end
				table.insert(cues, {Start=first, Finish=last, Text=plain(table.concat(text, "\n"))})
			else table.insert(diagnostics, "Invalid WebVTT cue timing: " .. lines[timing]) end
		elseif lines[1] and not lines[1]:match("^NOTE%s") and lines[1]~="NOTE" and lines[1]~="STYLE" and lines[1]~="REGION" then
			table.insert(diagnostics, "Invalid WebVTT cue block")
		end
	end
	table.sort(cues, function(a, b) return a.Start < b.Start end)
	return cues, diagnostics
end

function WebVTT.at(cues: {any}, time: number): string?
	for _, cue in cues do if time >= cue.Start and time < cue.Finish then return cue.Text end end
	return nil
end

return WebVTT
