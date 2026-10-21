--!strict
local FilterColor=require(script.Parent.FilterColor)
local FilterNoise=require(script.Parent.FilterNoise)
local Viewport=require(script.Parent.Viewport)
local Matrix=require(script.Parent.Matrix)
local Image=require(script.Parent.Image)
local Kernel={}
Kernel.Kinds={feImage=true,feTile=true,feMorphology=true,feConvolveMatrix=true,feDisplacementMap=true,feTurbulence=true}
function Kernel.parse(step: any,a: any,doc: any,scope: any,sx: number,sy: number,report: any): boolean
 local function list(key: string,default: any,max: number): any
  if a[key]==nil then return default end
  local n=FilterColor.numbers(a[key]);if not n or #n<1 or #n>max then error(key) end;return n
 end
 local function scalar(key: string,default: number): number return list(key,{default},1)[1] end
 local ok,err=pcall(function()
  if step.Kind=='feMorphology' then
   step.Operator=a.operator or 'erode';if step.Operator~='erode' and step.Operator~='dilate' then error('operator') end
   local r=list('radius',{0},2)
   local enabled=r[1]>0 and (r[2] or r[1])>0
   step.RadiusX=if enabled then r[1]*sx else 0;step.RadiusY=if enabled then (r[2] or r[1])*sy else 0
  elseif step.Kind=='feConvolveMatrix' then
   local order=list('order',{3},2);step.OrderX=order[1];step.OrderY=order[2] or order[1]
   if step.OrderX%1~=0 or step.OrderY%1~=0 or step.OrderX<1 or step.OrderY<1 or step.OrderX*step.OrderY>225 then error('order (maximum 225 entries)') end
   step.Kernel=list('kernelMatrix',{},225)
   if #step.Kernel~=step.OrderX*step.OrderY then step.PassThrough=true;report('invalid-convolution-kernel',a.kernelMatrix);return end
   local sum=0;for _,n in step.Kernel do sum+=n end;if sum==0 then sum=1 end
   step.Divisor=scalar('divisor',sum);if step.Divisor==0 then step.Divisor=sum end
   step.Bias=scalar('bias',0);step.TargetX=scalar('targetX',math.floor(step.OrderX/2));step.TargetY=scalar('targetY',math.floor(step.OrderY/2))
   if step.TargetX%1~=0 or step.TargetY%1~=0 or step.TargetX<0 or step.TargetY<0 or step.TargetX>=step.OrderX or step.TargetY>=step.OrderY then error('target') end
   step.EdgeMode=a.edgeMode or 'duplicate';if step.EdgeMode~='duplicate' and step.EdgeMode~='wrap' and step.EdgeMode~='none' then error('edgeMode') end
   if a.preserveAlpha and a.preserveAlpha~='true' and a.preserveAlpha~='false' then error('preserveAlpha') end
   step.PreserveAlpha=a.preserveAlpha=='true'
   if a.kernelUnitLength then local v=list('kernelUnitLength',{},2);if v[1]>0 and (v[2] or v[1])>0 then step.UnitX=v[1]*sx;step.UnitY=(v[2] or v[1])*sy end end
  elseif step.Kind=='feDisplacementMap' then
   step.ScaleX=scalar('scale',0)*sx;step.ScaleY=scalar('scale',0)*sy
   local channels={R=1,G=2,B=3,A=4};step.ChannelX=channels[a.xChannelSelector or 'A'];step.ChannelY=channels[a.yChannelSelector or 'A']
   if not step.ChannelX or not step.ChannelY then error('channelSelector') end
  elseif step.Kind=='feTurbulence' then
   local v=list('baseFrequency',{0},2);if v[1]<0 or (v[2] or v[1])<0 then error('baseFrequency') end
   step.FrequencyX=v[1];step.FrequencyY=v[2] or v[1];step.Octaves=scalar('numOctaves',1)
   if step.Octaves<0 or step.Octaves%1~=0 then error('numOctaves') end
   if step.Octaves>9 then report('turbulence-octave-limit',tostring(step.Octaves));step.Octaves=9 end
   step.NoiseType=a.type or 'turbulence';if step.NoiseType~='turbulence' and step.NoiseType~='fractalNoise' then error('type') end
   if a.stitchTiles and a.stitchTiles~='stitch' and a.stitchTiles~='noStitch' then error('stitchTiles') end
   step.Stitch=a.stitchTiles=='stitch';step.Noise=FilterNoise.new(scalar('seed',0));step.PrimitiveX=sx;step.PrimitiveY=sy
  elseif step.Kind=='feImage' then
   local href=a.href or a['xlink:href'];step.Space='sRGB'
   if not href then report('filter-image-unavailable','missing href');return end
   if href:find('#',1,true) then report('unsupported-filter-image-reference',href);return end
   step.Image=doc.ImageResource(href,{Scope=scope})
   if not step.Image then report('filter-image-unavailable',href)
   elseif step.Image.Root then report('unsupported-filter-image-reference',href);step.Image=nil end
   step.Aspect=a.preserveAspectRatio
  end
 end)
 if not ok then report('invalid-filter-parameter',step.Kind..':'..tostring(err));return false end
 return true
end
function Kernel.finish(step: any,r: any,box: any,pu: string,report: any)
 if step.Kind=='feImage' and step.Image then
  local im=step.Image;local fit=Viewport.resolve({viewBox=`0 0 {im.Width} {im.Height}`,preserveAspectRatio=step.Aspect},r.X,r.Y,r.Width,r.Height)
  for _,code in fit.Diagnostics do report(code,step.Aspect) end
  if not fit.Disabled then step.Sampler={Pixels=im.Pixels,Width=im.Width,Height=im.Height,Inverse=Matrix.inverse(fit.Transform)} end
 elseif step.Kind=='feTurbulence' then
  step.OriginX=if pu=='objectBoundingBox' then box.X else 0;step.OriginY=if pu=='objectBoundingBox' then box.Y else 0
  step.NoiseTile={X=(r.X-step.OriginX)/step.PrimitiveX,Y=(r.Y-step.OriginY)/step.PrimitiveY,Width=r.Width/step.PrimitiveX,Height=r.Height/step.PrimitiveY}
 end
end
function Kernel.image(step: any,x: number,y: number): any
 if not step.Sampler then return {0,0,0,0} end
 local c=Image.sample(step.Sampler,x,y);return {c[1]/255,c[2]/255,c[3]/255,c[4]}
end
function Kernel.convolve(step: any,x: number,y: number,sample: any,xx: number,xy: number,yx: number,yy: number): any
 if step.PassThrough then return sample(x,y,'none') end
 local sums={0,0,0,0}
 for i=0,step.OrderY-1 do for j=0,step.OrderX-1 do
  local dx,dy=j-step.TargetX,i-step.TargetY
  local c=sample(x+dx*xx+dy*yx,y+dx*xy+dy*yy,step.EdgeMode)
  local k=step.Kernel[(step.OrderY-1-i)*step.OrderX+step.OrderX-j]
  for channel=1,4 do sums[channel]+=c[channel]*k*(if channel<4 and not step.PreserveAlpha then c[4] else 1) end
 end end
 local alpha=if step.PreserveAlpha then sample(x,y,'none')[4] else math.clamp(sums[4]/step.Divisor+step.Bias,0,1)
 if alpha<=0 then return {0,0,0,0} end
 local result={0,0,0,alpha}
 for channel=1,3 do
  result[channel]=if step.PreserveAlpha then math.clamp(sums[channel]/step.Divisor+step.Bias,0,1) else math.clamp(sums[channel]/step.Divisor+step.Bias*alpha,0,alpha)/alpha
 end
 return result
end
return Kernel
