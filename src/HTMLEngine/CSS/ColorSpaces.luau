--!strict
-- CSS Color 4 Oklab conversion, D65/sRGB destination. Native Color3 surfaces
-- have no wider gamut: final out-of-gamut channels are clipped at paint time.
local Spaces={}
local function linear(v)return if math.abs(v)<=.04045 then v/12.92 else math.sign(v)*((math.abs(v)+.055)/1.055)^2.4 end
local function gamma(v)return if math.abs(v)<=.0031308 then 12.92*v else math.sign(v)*(1.055*math.abs(v)^(1/2.4)-.055)end
local function cube(v)return math.sign(v)*math.abs(v)^(1/3)end
function Spaces.coordinates(color: Color3,space: string): any
	local r,g,b=color.R,color.G,color.B
	if space=='srgb'then return {r,g,b}end
	r,g,b=linear(r),linear(g),linear(b)
	if space=='srgb-linear'then return {r,g,b}end
	local l=cube(.4122214708*r+.5363325363*g+.0514459929*b)
	local m=cube(.2119034982*r+.6806995451*g+.1073969566*b)
	local s=cube(.0883024619*r+.2817188376*g+.6299787005*b)
	local L=.2104542553*l+.793617785*m-.0040720468*s
	local a=1.9779984951*l-2.428592205*m+.4505937099*s
	local z=.0259040371*l+.7827717662*m-.808675766*s
	if space=='oklch'then return {L,math.sqrt(a*a+z*z),math.deg(math.atan2(z,a))%360}end
	return {L,a,z}
end
function Spaces.color(value: any,space: string): Color3
	local r,g,b=value[1],value[2],value[3]
	if space=='oklch'then local angle=math.rad(b);g,b=g*math.cos(angle),g*math.sin(angle);space='oklab'end
	if space=='oklab'then
		local l=(r+.3963377774*g+.2158037573*b)^3
		local m=(r-.1055613458*g-.0638541728*b)^3
		local s=(r-.0894841775*g-1.291485548*b)^3
		r,g,b=4.0767416621*l-3.3077115913*m+.2309699292*s,-1.2684380046*l+2.6097574011*m-.3413193965*s,-.0041960863*l-.7034186147*m+1.707614701*s
	end
	if space~='srgb'then r,g,b=gamma(r),gamma(g),gamma(b)end
	return Color3.new(math.clamp(r,0,1),math.clamp(g,0,1),math.clamp(b,0,1))
end
function Spaces.hue(a:number,b:number,method:string): (number,number)
	local delta=b-a
	if method=='shorter'then if delta>180 then a+=360 elseif delta< -180 then b+=360 end
	elseif method=='longer'then if delta>0 and delta<180 then a+=360 elseif delta<=0 and delta> -180 then b+=360 end
	elseif method=='increasing'then if b<a then b+=360 end
	elseif method=='decreasing'then if a<b then a+=360 end end
	return a,b
end
return Spaces
