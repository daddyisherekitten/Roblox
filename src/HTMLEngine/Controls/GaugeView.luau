--!strict
local Geometry=require(script.Parent.Parent.Layout.BorderGeometry)
local View={}
local COLORS={optimum=Color3.fromRGB(16,142,38),suboptimal=Color3.fromRGB(255,185,0),critical=Color3.fromRGB(216,48,48)}
function View.create(item: any,factory: any)
	item.GaugeTrack=factory.create("Frame",item.BoxGui,{Name="GaugeTrack",BackgroundTransparency=0,BackgroundColor3=Color3.fromRGB(239,239,239),ClipsDescendants=true})
	factory.modifier("UICorner",item.GaugeTrack,{CornerRadius=UDim.new(.5,0)})
	factory.modifier("UIStroke",item.GaugeTrack,{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,BorderStrokePosition=Enum.BorderStrokePosition.Inner,
		LineJoinMode=Enum.LineJoinMode.Round,Thickness=1,Color=Color3.fromRGB(178,178,178)})
	item.GaugeFill=factory.create("Frame",item.GaugeTrack,{Name="GaugeFill",BackgroundTransparency=0})
	factory.modifier("UICorner",item.GaugeFill,{CornerRadius=UDim.new(.5,0)})
end
function View.paint(item: any)
	local c,s=item.Control,item.Style
	local owner=item.PaintOwner or item
	local top,_,_,left=Geometry.sizes(s)
	local width,height=item.ContentWidth or 0,item.ContentHeight or s.FontSize
	local thickness=math.min(8,height)
	item.GaugeTrack.Position=UDim2.fromOffset(left+s.Padding[4],top+s.Padding[1]+(height-thickness)/2)
	item.GaugeTrack.Size=UDim2.fromOffset(width,thickness)
	item.GaugeFill.BackgroundColor3=if c.Type == "progress" then s.AccentColor or Color3.fromRGB(0,117,255) else COLORS[c.Gauge.Quality]
	item.GaugeFill.Size=UDim2.new(if c.Gauge.Indeterminate then .3 else c.Gauge.Ratio,0,1,0)
	if owner.GaugeAnimate then owner.GaugeAnimate(c.Gauge.Indeterminate and s.Visibility ~= "hidden") end
	if not owner.GaugeTween then item.GaugeFill.Position=UDim2.fromOffset(0,0) end
end
function View.bind(item: any,services: any?): () -> ()
	local alive=true
	item.GaugeAnimate=function(enabled: boolean)
		if not alive then return end
		if enabled and not item.GaugeTween then
			local tweenService=if services and services.TweenService then services.TweenService else game:GetService("TweenService")
			local info=TweenInfo.new(1.2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true)
			item.GaugeTween=tweenService:Create(item.GaugeFill,info,{Position=UDim2.new(.7,0,0,0)})
			item.GaugeTween:Play()
		elseif not enabled and item.GaugeTween then
			item.GaugeTween:Cancel(); item.GaugeTween:Destroy(); item.GaugeTween=nil
		end
	end
	View.paint(item)
	return function()
		alive=false
		if item.GaugeTween then item.GaugeTween:Cancel(); item.GaugeTween:Destroy(); item.GaugeTween=nil end
		item.GaugeAnimate=nil
	end
end
return View
