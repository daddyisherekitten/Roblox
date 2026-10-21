--!nonstrict
-- Chrome-inspired neutral surfaces keep the page and browser controls distinct.
local Tokens = {}
local rgb = Color3.fromRGB
local palettes = {
	Dark = {Background=rgb(32,33,36),Surface=rgb(41,42,45),Elevated=rgb(53,54,58),SurfaceInset=rgb(32,33,36),Toolbar=rgb(53,54,58),Omnibox=rgb(32,33,36),ShortcutCircle=rgb(41,42,45),Text=rgb(232,234,237),Muted=rgb(189,193,198),Disabled=rgb(122,125,130),Border=rgb(95,99,104),Hover=rgb(69,70,74),Pressed=rgb(82,83,87),Danger=rgb(242,139,130),Success=rgb(129,201,149),Scrim=rgb(0,0,0),Tooltip=rgb(232,234,237),TooltipText=rgb(32,33,36)},
	Light = {Background=rgb(255,255,255),Surface=rgb(255,255,255),Elevated=rgb(241,243,244),SurfaceInset=rgb(248,249,250),Toolbar=rgb(255,255,255),Omnibox=rgb(241,243,244),ShortcutCircle=rgb(241,243,244),Text=rgb(32,33,36),Muted=rgb(95,99,104),Disabled=rgb(154,160,166),Border=rgb(218,220,224),Hover=rgb(232,234,237),Pressed=rgb(218,220,224),Danger=rgb(197,34,31),Success=rgb(24,128,56),Scrim=rgb(0,0,0),Tooltip=rgb(60,64,67),TooltipText=rgb(255,255,255)},
}
local accents = {
	Dark={Blue=rgb(138,180,248),Purple=rgb(197,164,242),Green=rgb(129,201,149)},
	Light={Blue=rgb(26,115,232),Purple=rgb(132,48,206),Green=rgb(24,128,56)},
}
Tokens.Constants = {
	Font=Enum.Font.Arial, FontMedium=Enum.Font.Arial, FontBold=Enum.Font.ArialBold,
	TextSmall=12,TextBody=14,TextTitle=24,TextHero=32,
	Space4=4,Space8=8,Space12=12,Space16=16,Space24=24,Space32=32,
	Target=44,ControlHeight=44,Radius8=6,Radius12=8,Radius16=12,
	-- Chromium 155 desktop DIP values. Touch targets deliberately remain larger.
	ChromeToolbarHeight=46,ChromeAddressHeight=34,ChromeBookmarkHeight=34,ChromeBookmarkButtonHeight=28,
	ChromeButtonSize=34,ChromeTouchButtonSize=44,ChromeToolbarGap=4,ChromeLocationMargin=9,
	BorderWidth=1,IconSize=20,IconStroke=2,
	DurationHover=.1,DurationMenu=.14,DurationTheme=.2,TooltipDelay=.5,
	MinimumWidth=480,MinimumHeight=360,MediumWidth=640,WideWidth=900,
	LayerPage=1,LayerChrome=20,LayerPopup=100,LayerModal=200,LayerTooltip=300,
	MouseDragThreshold=6,TouchDragThreshold=12,TouchDragHold=.28,WheelStep=54,
}
function Tokens.resolve(theme,accent)
	theme = if palettes[theme] then theme else 'Dark'
	accent = if accents[theme][accent] then accent else 'Blue'
	local output=table.clone(Tokens.Constants)
	for key,value in palettes[theme] do output[key]=value end
	output.Theme=theme;output.AccentName=accent;output.Accent=accents[theme][accent]
	output.AccentSoft=output.Surface:Lerp(output.Accent,if theme=='Dark' then .2 else .12)
	output.OnAccent=if theme=='Dark' then rgb(32,33,36) else rgb(255,255,255)
	output.SurfaceRaised=output.Elevated;output.TextMuted=output.Muted
	-- State layers are relative to the surface, rather than shared card colors.
	output.ToolbarHover=output.Toolbar:Lerp(output.Text,.08)
	output.ToolbarPressed=output.Toolbar:Lerp(output.Text,.16)
	output.OmniboxHover=output.Omnibox:Lerp(output.Text,.04)
	output.OmniboxFocused=output.Surface
	return output
end
return Tokens
