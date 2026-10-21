--!strict
local Defaults=require(script.Parent.Parent.Controls.Defaults)
local Scheme={}
Scheme.Dark={
 Canvas=Color3.fromRGB(18,18,18),Text=Color3.fromRGB(238,238,238),
 Field=Color3.fromRGB(59,59,59),Button=Color3.fromRGB(107,107,107),
 Border=Color3.fromRGB(133,133,133),Disabled=Color3.fromRGB(45,45,45),
 Accent=Color3.fromRGB(153,200,255),AccentHover=Color3.fromRGB(209,230,255),
 AccentPressed=Color3.fromRGB(97,169,255),DisabledToggle=Color3.fromRGB(118,118,118),
 Thumb=Color3.fromRGB(159,159,159),Track=Color3.fromRGB(44,44,44),
}
function Scheme.apply(node,s)
 local choice=s.ColorScheme or {};local dark=choice.Dark and (not choice.Light or s.PreferredColorScheme=='dark') or false
 s.DarkScheme=dark
 local kind=Defaults.kind(node)
 if dark then
  local p=Scheme.Dark
  if kind and kind~='output' and kind~='progress' and kind~='meter' then
   if not s.ControlColorSpecified then s.Color=p.Text end
   if not s.ControlBackgroundSpecified and kind~='range' then s.Background=if kind=='button' or kind=='submit' or kind=='reset' then p.Button else p.Field;s.BackgroundAlpha=1 end
   if not s.ControlBorderSpecified then s.BorderColor=p.Border end
  elseif s.ColorIsDefault then s.Color=p.Text end
  if not s.ScrollbarColor or s.ScrollbarColor.Auto then s.ScrollbarColor={Thumb=p.Thumb,Track=p.Track,ThumbAlpha=1,TrackAlpha=1}end
 elseif s.ColorIsDefault and not kind then s.Color=Color3.new(0,0,0)end
end
return Scheme
