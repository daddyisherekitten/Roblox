--!strict
local BorderGeometry = require(script.Parent.Parent.Layout.BorderGeometry)
local BorderBox = require(script.Parent.BorderBox)
local OutlineBox = require(script.Parent.OutlineBox)
local ImageFit = require(script.Parent.Parent.Layout.ImageFit)
local MediaBox = {}
local function write(object: any, key: string, value: any)
	if object and object[key] ~= value then object[key] = value end
end

-- The managed audio owner can retry a deferred/unmapped source candidate.
-- Native media without that live owner retains the existing source gate.
function MediaBox.canControl(item: any): boolean
	return item.StreamPlayer~=nil or item.Source~=nil or(item.AudioSession~=nil and item.AudioSession.Alive==true)or(item.VideoSelection~=nil and item.VideoSelection.Item==item and item.VideoSelection.Specified==true)
end

function MediaBox.showsPoster(item: any): boolean
	return item.PosterReady~=false and(item.Poster~=nil or item.PosterSVG~=nil)and(item.ShowPoster~=false or item.VideoFrameAvailable==false or(item.VideoWidth or 0)==0 or(item.VideoHeight or 0)==0)
end
function MediaBox.natural(item: any): boolean
	if item.MediaKind~='video'then return false end
	local w,h
	if MediaBox.showsPoster(item)then w,h=item.PosterWidth,item.PosterHeight
	elseif item.VideoFrameAvailable~=false and(item.VideoWidth or 0)>0 and(item.VideoHeight or 0)>0 then w,h=item.VideoWidth,item.VideoHeight end
	local changed=item.IntrinsicWidth~=w or item.IntrinsicHeight~=h
	item.IntrinsicWidth,item.IntrinsicHeight=w,h
	return changed
end

function MediaBox.ensurePoster(item: any,factory: any)
	if item.PosterGui then return end
	item.PosterGui=factory.create('ImageLabel',item.BoxGui,{Name='Poster',Image='',ScaleType=Enum.ScaleType.Stretch,BackgroundTransparency=1,Visible=false})
end

local function surfaces(item: any,x: number,y: number,width: number,height: number)
	write(item.VideoDisplay,'ScaleType',if item.Style.ObjectFit==nil or item.Style.ObjectFit=='fill' then Enum.ScaleType.Stretch else Enum.ScaleType.Fit)
	local function fit(gui,w,h,originX,originY)
		if not gui then return end
		local dx,dy,rw,rh=ImageFit.rectangle({Style=item.Style,ContentWidth=width,ContentHeight=height,IntrinsicWidth=if w and w>0 then w else width,IntrinsicHeight=if h and h>0 then h else height})
		write(gui,'Position',UDim2.fromOffset((originX or x)+dx,(originY or y)+dy));write(gui,'Size',UDim2.fromOffset(rw,rh))
		return rw,rh
	end
	fit(item.VideoGui,item.VideoWidth,item.VideoHeight)
	fit(item.VideoDisplay,item.VideoWidth,item.VideoHeight)
	write(item.StreamSurfaceGui,'Position',UDim2.fromOffset(x,y));write(item.StreamSurfaceGui,'Size',UDim2.fromOffset(width,height))
	fit(item.StreamVideoGui,item.VideoWidth,item.VideoHeight,0,0)
	local pw,ph=fit(item.PosterGui,item.PosterWidth,item.PosterHeight)
	if item.PosterSVGItem and MediaBox.showsPoster(item)and pw and ph then
		item.PosterSVGItem.ContentWidth,item.PosterSVGItem.ContentHeight=pw,ph
		if item.PosterSVGItem.UpdateSVG then item.PosterSVGItem.UpdateSVG()end
	end
end

local CONTROL_HEIGHT = 44
local PLAY_WIDTH = 48
local TIMELINE_INSET = 8
local TIMELINE_TIME_GAP = 12
local TIME_SPEED_GAP = 8
local TIME_WIDTH = 100
local SPEED_WIDTH = 46
local CAPTIONS_WIDTH = 40
local FULLSCREEN_WIDTH = 40
local MUTE_WIDTH = 38
local VOLUME_WIDTH = 96
local KNOB_SIZE = 14

local CONTROL_COLOR = Color3.fromRGB(74, 74, 74)
local TRACK_COLOR = Color3.fromRGB(31, 31, 31)
local FILL_COLOR = Color3.fromRGB(226, 226, 226)
local KNOB_COLOR = Color3.fromRGB(248, 248, 248)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local VOLUME_ON_IMAGE = "rbxassetid://96465568269125"
local MUTED_IMAGE = "rbxassetid://89066326142104"

local function hasToken(value: string?, token: string): boolean
	for part in string.gmatch(string.lower(value or ""), "%S+") do if part == token then return true end end
	return false
end

local function rounded(factory: any, object: any, radius: number)
	factory.modifier("UICorner", object, {CornerRadius = UDim.new(0, radius)})
end

local function label(factory: any, parent: any, name: string, text: string, size: number): any
	return factory.create("TextLabel", parent, {
		Name = name,
		Text = text,
		TextSize = size,
		TextColor3 = TEXT_COLOR,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
end

local function geometry(item: any, width: number): any
	local compact = width < 520
	local timeWidth = TIME_WIDTH
	local speedWidth = if width >= 430 and item.RateSupported ~= false then SPEED_WIDTH else 0
	local timeSpeedGap = if speedWidth > 0 then TIME_SPEED_GAP else 0
	local captionsWidth = if #(item.ParsedTracks or item.Tracks or {}) > 0 and width >= 480 then CAPTIONS_WIDTH else 0
	local fullscreenWidth = if item.AllowFullscreen and width >= 560 then FULLSCREEN_WIDTH else 0
	local volumeWidth = if width >= 360 then (if compact then 72 else VOLUME_WIDTH) else 0
	local timelineX = PLAY_WIDTH + TIMELINE_INSET
	local rightWidth = timeWidth + timeSpeedGap + speedWidth + captionsWidth + fullscreenWidth + MUTE_WIDTH + volumeWidth
	local timelineWidth = math.max(0, width - timelineX - TIMELINE_TIME_GAP - rightWidth)
	local timelineEnd = timelineX + timelineWidth
	local timeX = timelineEnd + TIMELINE_TIME_GAP
	local speedX = timeX + timeWidth + timeSpeedGap
	local captionsX = speedX + speedWidth
	local fullscreenX = captionsX + captionsWidth
	local muteX = fullscreenX + fullscreenWidth
	local volumeX = muteX + MUTE_WIDTH
	return {
		TimelineX = timelineX,
		TimelineWidth = timelineWidth,
		TimelineEnd = timelineEnd,
		TimeX = timeX,
		TimeWidth = timeWidth,
		SpeedX = speedX,
		SpeedWidth = speedWidth,
		CaptionsX = captionsX,
		CaptionsWidth = captionsWidth,
		FullscreenX = fullscreenX,
		FullscreenWidth = fullscreenWidth,
		MuteX = muteX,
		VolumeX = volumeX,
		VolumeWidth = volumeWidth,
	}
end

local function arrangeCaption(item: any, x: number, y: number, width: number, height: number, controlsHeight: number)
	if not item.CaptionGui then return end
	local inset = math.min(8, math.floor(width / 8))
	local captionWidth = math.max(0, width - 2 * inset)
	local availableHeight = math.max(0, height - controlsHeight)
	local captionHeight = math.min(26, math.max(0, availableHeight - 8))
	local captionY = math.max(0, availableHeight - captionHeight - 8)
	item.CaptionFits = captionWidth >= 100 and captionHeight >= 22
	write(item.CaptionGui, "Position", UDim2.fromOffset(x + inset, y + captionY))
	write(item.CaptionGui, "Size", UDim2.fromOffset(captionWidth, captionHeight))
end

-- Controls are a retained paint subtree, allocated only on the first reveal.
function MediaBox.ensureControls(item: any, factory: any): boolean
	if not item.Controls or item.ControlsGui then return false end
	item.ControlsGui = factory.create("Frame", item.BoxGui, {
		Name = "MediaControls",
		BackgroundTransparency = if item.MediaKind == "video" then 0.5 else 0,
		BackgroundColor3 = CONTROL_COLOR,
	})
	item.ControlsFocusStroke = factory.modifier("UIStroke", item.ControlsGui, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(126, 190, 255),
		Thickness = 2,
		Enabled = false,
	})
	item.PlayGui = label(factory, item.ControlsGui, "PlayPause", "▶", 18)
	item.PauseLeftGui = factory.create("Frame", item.ControlsGui, {
		Name = "PauseLeft",
		BackgroundTransparency = 0,
		BackgroundColor3 = KNOB_COLOR,
		Visible = false,
	})
	item.PauseRightGui = factory.create("Frame", item.ControlsGui, {
		Name = "PauseRight",
		BackgroundTransparency = 0,
		BackgroundColor3 = KNOB_COLOR,
		Visible = false,
	})
	item.TrackGui = factory.create("Frame", item.ControlsGui, {
		Name = "Timeline",
		BackgroundTransparency = 0,
		BackgroundColor3 = TRACK_COLOR,
	})
	rounded(factory, item.TrackGui, 2)
	item.ProgressGui = factory.create("Frame", item.TrackGui, {
		Name = "Progress",
		BackgroundTransparency = 0,
		BackgroundColor3 = FILL_COLOR,
	})
	rounded(factory, item.ProgressGui, 2)
	item.SeekKnobGui = factory.create("Frame", item.ControlsGui, {
		Name = "SeekKnob",
		BackgroundTransparency = 0,
		BackgroundColor3 = KNOB_COLOR,
	})
	rounded(factory, item.SeekKnobGui, KNOB_SIZE)
	item.TimeGui = label(factory, item.ControlsGui, "Time", "0:00 / 0:00", 16)
	item.TimeGui.TextScaled = true
	item.TimeGui.ClipsDescendants = true
	factory.modifier("UITextSizeConstraint", item.TimeGui, {MinTextSize = 10, MaxTextSize = 16})
	item.SpeedGui = label(factory, item.ControlsGui, "PlaybackRate", "1x", 16)
	item.SpeedGui.TextScaled = true
	item.SpeedGui.ClipsDescendants = true
	factory.modifier("UITextSizeConstraint", item.SpeedGui, {MinTextSize = 10, MaxTextSize = 16})
	item.CaptionsGui = label(factory, item.ControlsGui, "Captions", "CC", 13)
	item.FullscreenGui = label(factory, item.ControlsGui, "Fullscreen", "FS", 13)
	item.MuteButtonGui = factory.create("Frame", item.ControlsGui, {Name = "MuteButton"})
	item.MuteGui = factory.create("ImageLabel", item.MuteButtonGui, {
		Name = "Mute",
		Image = VOLUME_ON_IMAGE,
		ScaleType = Enum.ScaleType.Fit,
	})
	item.MutePreloadGui = factory.create("ImageLabel", item.ControlsGui, {
		Name = "MutedIconPreload",
		Image = MUTED_IMAGE,
		Visible = false,
	})
	item.VolumeGui = factory.create("Frame", item.ControlsGui, {Name = "Volume"})
	item.VolumeTrackGui = factory.create("Frame", item.VolumeGui, {
		Name = "VolumeTrack",
		BackgroundTransparency = 0,
		BackgroundColor3 = TRACK_COLOR,
	})
	rounded(factory, item.VolumeTrackGui, 2)
	item.VolumeFillGui = factory.create("Frame", item.VolumeTrackGui, {
		Name = "VolumeFill",
		BackgroundTransparency = 0,
		BackgroundColor3 = FILL_COLOR,
	})
	rounded(factory, item.VolumeFillGui, 2)
	item.VolumeKnobGui = factory.create("Frame", item.VolumeGui, {
		Name = "VolumeKnob",
		BackgroundTransparency = 0,
		BackgroundColor3 = KNOB_COLOR,
	})
	rounded(factory, item.VolumeKnobGui, KNOB_SIZE)
	return true
end

function MediaBox.create(item: any, parent: any, factory: any, corners: any?)
	local style = item.Style
	item.AllowFullscreen = item.MediaKind == "video" and not hasToken(item.Node.Attributes.controlslist, "nofullscreen")
	item.Gui = factory.create("Frame", parent, {Name = item.Node.Attributes.id or (item.MediaKind .. "Media")})
	item.BoxGui = factory.create("Frame", item.Gui, {
		Name = "MediaBox",
		ClipsDescendants = true,
		BackgroundTransparency = if style.Background then 1 - (style.BackgroundAlpha or 1) elseif item.MediaKind == "audio" then 1 else 0,
		BackgroundColor3 = style.Background or Color3.fromRGB(28, 31, 36),
	})
	if style.BorderRadius > 0 then
		item.BoxCorner = factory.modifier("UICorner", item.BoxGui, {CornerRadius = UDim.new(0, style.BorderRadius)})
	end
	item.BorderEdges = BorderBox.create(style, item.BoxGui, factory, corners)
	item.Outline = OutlineBox.create(style, item.BoxGui, factory, corners)
	if item.MediaKind == "video" then
		item.VideoGui = factory.create("VideoFrame", item.BoxGui, {
			Name = "Video",
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0,
		})
		local ok, display = pcall(factory.create, "VideoDisplay", item.BoxGui, {
			Name = "VideoDisplay",
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0,
			Visible = false,
		})
		if ok then item.VideoDisplay = display end
		if item.VideoDisplay then item.VideoDisplay.ScaleType=Enum.ScaleType.Fit end
		item.StreamSurfaceGui=factory.create('Frame',item.BoxGui,{Name='MediaStreamSurface',BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=0,ClipsDescendants=true,Visible=false})
		MediaBox.ensurePoster(item,factory)
		item.PosterGui.Image=if item.PosterReady==false then ''else item.Poster or ''
		if item.PosterSVG then item.PosterSVGItem={SVG=item.PosterSVG,Style=style,ImageGui=item.PosterGui,Node=item.Node,PreparedPoster=item.PosterReady==false}end
	end
	MediaBox.ensureControls(item, factory)
	item.CaptionGui = label(factory, item.BoxGui, "Caption", "", 16)
	item.CaptionGui.BackgroundTransparency = 0.25
	item.CaptionGui.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	item.CaptionGui.TextWrapped = true
	item.CaptionGui.TextScaled = true
	item.CaptionGui.ClipsDescendants = true
	factory.modifier("UITextSizeConstraint", item.CaptionGui, {MinTextSize = 8, MaxTextSize = 16})
	item.CaptionGui.Visible = false
	item.MissingGui = label(factory, item.BoxGui, "MediaFallback", if item.Source then "Loading media..." else "Media source unavailable", 14)
	item.MissingGui.TextColor3 = Color3.fromRGB(210, 214, 220)
	item.MissingGui.Visible = item.Source == nil
end

local function clock(value: number): string
	value = math.max(0, math.floor(value))
	return string.format("%d:%02d", math.floor(value / 60), value % 60)
end

function MediaBox.paint(item: any)
	write(item.ControlsGui,"Visible",item.Controls==true and not (item.Style and item.Style.Hidden))
	local duration = math.max(0, item.Duration or 0)
	local current = math.clamp(item.CurrentTime or 0, 0, if duration > 0 then duration else math.huge)
	local progress = if duration > 0 then current / duration else 0
	local storedVolume = math.clamp(item.Volume or 1, 0, 1)
	local volume = if item.Muted then 0 else storedVolume
	local controlsWidth = item.ControlsWidth or (item.ControlsGui and item.ControlsGui.AbsoluteSize.X) or 0
	local g = if item.SpeedGui or item.ControlsGui then geometry(item, controlsWidth) else nil
	local function paintButton(gui: any, action: string)
		if not gui then return end
		write(gui, "BackgroundColor3", TEXT_COLOR)
		write(gui, "BackgroundTransparency", if item.PressedAction == action then 0.72 elseif item.HoverAction == action then 0.86 else 1)
	end
	paintButton(item.PlayGui, "toggle")
	paintButton(item.SpeedGui, "speed")
	paintButton(item.CaptionsGui, "captions")
	paintButton(item.FullscreenGui, "fullscreen")
	paintButton(item.MuteButtonGui, "mute")
	paintButton(item.VolumeGui, "volume")
	write(item.ControlsFocusStroke, "Enabled", item.FocusVisible == true)
	write(item.PlayGui, "Text", if item.Playing then "" else "▶")
	write(item.PauseLeftGui, "Visible", item.Playing == true)
	write(item.PauseRightGui, "Visible", item.Playing == true)
	write(item.TimeGui, "Text", if item.StreamPlayer then'LIVE'else clock(current) .. " / " .. clock(duration))
	write(item.ProgressGui, "Size", UDim2.fromScale(progress, 1))
	write(item.MuteGui, "Image", if item.Muted or storedVolume <= 0 then MUTED_IMAGE else VOLUME_ON_IMAGE)
	if item.SpeedGui then
		write(item.SpeedGui, "Text", string.format("%gx", item.PlaybackRate or 1))
		write(item.SpeedGui, "Visible", g.SpeedWidth > 0)
	end
	if item.CaptionsGui then
		write(item.CaptionsGui, "Visible", #(item.ParsedTracks or item.Tracks or {}) > 0 and item.CaptionsFits ~= false)
		write(item.CaptionsGui, "TextColor3", if item.Captions then Color3.fromRGB(126, 190, 255) else TEXT_COLOR)
	end
	if item.FullscreenGui then
		write(item.FullscreenGui, "Visible", item.AllowFullscreen and item.FullscreenFits ~= false)
		write(item.FullscreenGui, "Text", if item.Fullscreen then "EXIT" else "FS")
	end
	write(item.VolumeFillGui, "Size", UDim2.fromScale(volume, 1))
	write(item.TrackGui, "BackgroundColor3", if item.HoverAction == "seek" or item.PressedAction == "seek" then Color3.fromRGB(18, 18, 18) else TRACK_COLOR)
	write(item.SeekKnobGui, "BackgroundColor3", if item.HoverAction == "seek" or item.PressedAction == "seek" then TEXT_COLOR else KNOB_COLOR)
	if item.ControlsGui then
		local controlsHeight = item.ControlsHeight or item.ControlsGui.AbsoluteSize.Y
		local seekX = g.TimelineX + math.floor(g.TimelineWidth * progress + 0.5) - math.floor(KNOB_SIZE / 2)
		write(item.SeekKnobGui, "Position", UDim2.fromOffset(seekX, math.floor((controlsHeight - KNOB_SIZE) / 2)))
		local volumeRail = math.max(0, g.VolumeWidth - 2 * TIMELINE_INSET)
		local volumeX = TIMELINE_INSET + math.floor(volumeRail * volume + 0.5) - math.floor(KNOB_SIZE / 2)
		write(item.VolumeKnobGui, "Position", UDim2.fromOffset(volumeX, math.floor((controlsHeight - KNOB_SIZE) / 2)))
	end
	if item.CaptionGui then
		write(item.CaptionGui, "Text", item.CaptionText or "")
		write(item.CaptionGui, "Visible", item.Captions == true and item.HasPlayed == true and item.CaptionFits ~= false and item.CaptionText ~= nil and item.CaptionText ~= "")
	end
	local posterVisible=MediaBox.showsPoster(item)
	write(item.PosterGui, "Visible",posterVisible)
	write(item.StreamSurfaceGui,'Visible',item.StreamPlayer~=nil)
	write(item.StreamVideoGui,'Visible',item.StreamPlayer~=nil and item.StreamPlayer.FrameEnabled==true)
	write(item.VideoDisplay, "Visible", item.StreamPlayer==nil and item.UsingVideoPlayer == true)
	write(item.VideoGui, "Visible", item.StreamPlayer==nil and item.UsingVideoPlayer ~= true)
	if item.MissingGui then
		local hasSource=item.Source~=nil or item.StreamPlayer~=nil
		write(item.MissingGui, "Text", if not hasSource then "Media source unavailable" elseif item.LoadFailed then "Media failed to load" else "Loading media...")
		write(item.MissingGui, "Visible", not posterVisible and(not hasSource or item.LoadFailed == true or item.Loading == true))
	end
end

function MediaBox.arrange(item: any)
	if item.Fullscreen then MediaBox.paint(item);return end
	local style, padding = item.Style, item.Style.Padding
	local bt, _, _, bl = BorderGeometry.sizes(style)
	write(item.BoxGui, "Visible", style.Visibility ~= "hidden")
	write(item.BoxGui, "Position", UDim2.fromOffset(style.Margin[4], style.Margin[1]))
	write(item.BoxGui, "Size", UDim2.fromOffset(item.BoxWidth, item.BoxHeight))
	local x, y = bl + padding[4], bt + padding[1]
	local width, height = item.ContentWidth, item.ContentHeight
	local controlsHeight = if item.Controls then math.min(CONTROL_HEIGHT, height) else 0
	if item.MediaKind == "video" then
		surfaces(item,x,y,width,height)
	end
	if item.ControlsGui then
		local cy = if item.MediaKind == "audio" then y + math.floor((height - controlsHeight) / 2) else y + height - controlsHeight
		local g = geometry(item, width)
		item.ControlsWidth, item.ControlsHeight = width, controlsHeight
		item.SpeedFits, item.CaptionsFits, item.FullscreenFits = g.SpeedWidth > 0, g.CaptionsWidth > 0, g.FullscreenWidth > 0
		write(item.ControlsGui, "Position", UDim2.fromOffset(x, cy))
		write(item.ControlsGui, "Size", UDim2.fromOffset(width, controlsHeight))
		write(item.PlayGui, "Position", UDim2.fromOffset(0, 0))
		write(item.PlayGui, "Size", UDim2.fromOffset(PLAY_WIDTH, controlsHeight))
		local pauseY = math.floor((controlsHeight - 14) / 2)
		write(item.PauseLeftGui, "Position", UDim2.fromOffset(math.floor(PLAY_WIDTH / 2) - 5, pauseY))
		write(item.PauseLeftGui, "Size", UDim2.fromOffset(3, 14))
		write(item.PauseRightGui, "Position", UDim2.fromOffset(math.floor(PLAY_WIDTH / 2) + 2, pauseY))
		write(item.PauseRightGui, "Size", UDim2.fromOffset(3, 14))
		write(item.TrackGui, "Position", UDim2.fromOffset(g.TimelineX, math.floor(controlsHeight / 2) - 2))
		write(item.TrackGui, "Size", UDim2.fromOffset(g.TimelineWidth, 4))
		write(item.TimeGui, "Position", UDim2.fromOffset(g.TimeX, 0))
		write(item.TimeGui, "Size", UDim2.fromOffset(g.TimeWidth, controlsHeight))
		write(item.SpeedGui, "Position", UDim2.fromOffset(g.SpeedX, 0))
		write(item.SpeedGui, "Size", UDim2.fromOffset(g.SpeedWidth, controlsHeight))
		write(item.CaptionsGui, "Position", UDim2.fromOffset(g.CaptionsX, 0))
		write(item.CaptionsGui, "Size", UDim2.fromOffset(g.CaptionsWidth, controlsHeight))
		write(item.FullscreenGui, "Position", UDim2.fromOffset(g.FullscreenX, 0))
		write(item.FullscreenGui, "Size", UDim2.fromOffset(g.FullscreenWidth, controlsHeight))
		write(item.MuteButtonGui, "Position", UDim2.fromOffset(g.MuteX, 0))
		write(item.MuteButtonGui, "Size", UDim2.fromOffset(MUTE_WIDTH, controlsHeight))
		local muteSize = math.min(20, controlsHeight)
		write(item.MuteGui, "Position", UDim2.fromOffset(math.floor((MUTE_WIDTH - muteSize) / 2), math.floor((controlsHeight - muteSize) / 2)))
		write(item.MuteGui, "Size", UDim2.fromOffset(muteSize, muteSize))
		write(item.VolumeGui, "Position", UDim2.fromOffset(g.VolumeX, 0))
		write(item.VolumeGui, "Size", UDim2.fromOffset(g.VolumeWidth, controlsHeight))
		write(item.VolumeGui, "Visible", g.VolumeWidth > 0)
		write(item.VolumeTrackGui, "Position", UDim2.fromOffset(TIMELINE_INSET, math.floor(controlsHeight / 2) - 2))
		write(item.VolumeTrackGui, "Size", UDim2.fromOffset(math.max(0, g.VolumeWidth - 2 * TIMELINE_INSET), 4))
	end
	arrangeCaption(item, x, y, width, height, controlsHeight)
	write(item.MissingGui, "Position", UDim2.fromOffset(x, y))
	local missingHeight = if item.MediaKind == "audio" then height else math.max(0, height - controlsHeight)
	write(item.MissingGui, "Size", UDim2.fromOffset(width, missingHeight))
	if item.BorderEdges then BorderBox.arrange(item.BorderEdges, style, item.BoxWidth, item.BoxHeight) end
	if item.Outline then OutlineBox.arrange(item.Outline, item.BoxWidth, item.BoxHeight) end
	MediaBox.paint(item)
end

function MediaBox.action(item: any, position: any): (string, number?)
	if item.Controls==false or not item.ControlsGui or not position then return "none" end
	local p, size = item.ControlsGui.AbsolutePosition, item.ControlsGui.AbsoluteSize
	local x, y = position.X - p.X, position.Y - p.Y
	if y < 0 or y >= size.Y or x < 0 or x >= size.X then return "none" end
	local g = geometry(item, size.X)
	if x < PLAY_WIDTH then return "toggle" end
	if x >= g.TimelineX and x < g.TimelineEnd then
		return "seek", math.clamp((x - g.TimelineX) / math.max(1, g.TimelineWidth), 0, 1)
	end
	if g.SpeedWidth > 0 and x >= g.SpeedX and x < g.CaptionsX then return "speed" end
	if g.CaptionsWidth > 0 and x >= g.CaptionsX and x < g.FullscreenX then return "captions" end
	if g.FullscreenWidth > 0 and x >= g.FullscreenX and x < g.MuteX then return "fullscreen" end
	if x >= g.MuteX and x < g.VolumeX then return "mute" end
	if g.VolumeWidth > 0 and x >= g.VolumeX then
		local rail = math.max(1, g.VolumeWidth - 2 * TIMELINE_INSET)
		return "volume", math.clamp((x - g.VolumeX - TIMELINE_INSET) / rail, 0, 1)
	end
	return "none"
end

function MediaBox.dragValue(item: any, action: string, position: any): number?
	if not item.ControlsGui or not position then return nil end
	local p, size = item.ControlsGui.AbsolutePosition, item.ControlsGui.AbsoluteSize
	local x = position.X - p.X
	local g = geometry(item, size.X)
	if action == "seek" then
		return math.clamp((x - g.TimelineX) / math.max(1, g.TimelineWidth), 0, 1)
	elseif action == "volume" then
		local rail = math.max(1, g.VolumeWidth - 2 * TIMELINE_INSET)
		return math.clamp((x - g.VolumeX - TIMELINE_INSET) / rail, 0, 1)
	end
	return nil
end

function MediaBox.fullscreen(item: any, width: number, height: number)
	width, height = math.max(1, width), math.max(1, height)
	write(item.Gui, "Position", UDim2.fromOffset(0, 0))
	write(item.Gui, "Size", UDim2.fromOffset(width, height))
	write(item.BoxGui, "Position", UDim2.fromOffset(0, 0))
	write(item.BoxGui, "Size", UDim2.fromOffset(width, height))
	surfaces(item,0,0,width,height)
	local controlsHeight = if item.Controls then math.min(CONTROL_HEIGHT, height) else 0
	local g = geometry(item, width)
	item.ControlsWidth, item.ControlsHeight = width, controlsHeight
	item.SpeedFits, item.CaptionsFits, item.FullscreenFits = g.SpeedWidth > 0, g.CaptionsWidth > 0, g.FullscreenWidth > 0
	write(item.ControlsGui, "Position", UDim2.fromOffset(0, height - controlsHeight))
	write(item.ControlsGui, "Size", UDim2.fromOffset(width, controlsHeight))
	write(item.PlayGui, "Position", UDim2.fromOffset(0, 0));write(item.PlayGui, "Size", UDim2.fromOffset(PLAY_WIDTH, controlsHeight))
	local pauseY = math.floor((controlsHeight - 14) / 2)
	write(item.PauseLeftGui, "Position", UDim2.fromOffset(math.floor(PLAY_WIDTH / 2) - 5, pauseY));write(item.PauseLeftGui, "Size", UDim2.fromOffset(3, 14))
	write(item.PauseRightGui, "Position", UDim2.fromOffset(math.floor(PLAY_WIDTH / 2) + 2, pauseY));write(item.PauseRightGui, "Size", UDim2.fromOffset(3, 14))
	write(item.TrackGui, "Position", UDim2.fromOffset(g.TimelineX, math.floor(controlsHeight / 2) - 2));write(item.TrackGui, "Size", UDim2.fromOffset(g.TimelineWidth, 4))
	write(item.TimeGui, "Position", UDim2.fromOffset(g.TimeX, 0));write(item.TimeGui, "Size", UDim2.fromOffset(g.TimeWidth, controlsHeight))
	write(item.SpeedGui, "Position", UDim2.fromOffset(g.SpeedX, 0));write(item.SpeedGui, "Size", UDim2.fromOffset(g.SpeedWidth, controlsHeight))
	write(item.CaptionsGui, "Position", UDim2.fromOffset(g.CaptionsX, 0));write(item.CaptionsGui, "Size", UDim2.fromOffset(g.CaptionsWidth, controlsHeight))
	write(item.FullscreenGui, "Position", UDim2.fromOffset(g.FullscreenX, 0));write(item.FullscreenGui, "Size", UDim2.fromOffset(g.FullscreenWidth, controlsHeight))
	write(item.MuteButtonGui, "Position", UDim2.fromOffset(g.MuteX, 0));write(item.MuteButtonGui, "Size", UDim2.fromOffset(MUTE_WIDTH, controlsHeight))
	local muteSize = math.min(20, controlsHeight)
	write(item.MuteGui, "Position", UDim2.fromOffset(math.floor((MUTE_WIDTH - muteSize) / 2), math.floor((controlsHeight - muteSize) / 2)));write(item.MuteGui, "Size", UDim2.fromOffset(muteSize, muteSize))
	write(item.VolumeGui, "Position", UDim2.fromOffset(g.VolumeX, 0));write(item.VolumeGui, "Size", UDim2.fromOffset(g.VolumeWidth, controlsHeight));write(item.VolumeGui, "Visible", g.VolumeWidth > 0)
	write(item.VolumeTrackGui, "Position", UDim2.fromOffset(TIMELINE_INSET, math.floor(controlsHeight / 2) - 2));write(item.VolumeTrackGui, "Size", UDim2.fromOffset(math.max(0, g.VolumeWidth - 2 * TIMELINE_INSET), 4))
	arrangeCaption(item, 0, 0, width, height, controlsHeight)
	write(item.MissingGui, "Position", UDim2.fromOffset(0, 0));write(item.MissingGui, "Size", UDim2.fromOffset(width, math.max(0, height - controlsHeight)))
	MediaBox.paint(item)
end

return MediaBox
