--!strict
--!optimize 2
--!native
-- SVG 1.1 / Skia-compatible seeded gradient noise. No global random state.
local Noise={}
function Noise.random(seed: number): number return (16807*seed)%2147483647 end
function Noise.new(seed: number): any
 seed=if seed<0 then math.ceil(seed) else math.floor(seed)
 if seed<=0 then seed=-math.fmod(seed,2147483646)+1 end
 seed=math.min(seed,2147483646)
 local p,g={},{}
 for c=1,4 do
  g[c]={}
  for i=0,255 do
   p[i]=i;seed=Noise.random(seed);local x=(seed%512-256)/256
   seed=Noise.random(seed);local y=(seed%512-256)/256
   local length=math.sqrt(x*x+y*y)
   -- A degenerate gradient contributes zero, without consuming extra randoms.
   g[c][i]=if length==0 then {0,0} else {x/length,y/length}
  end
 end
 for i=255,1,-1 do seed=Noise.random(seed);local j=seed%256;p[i],p[j]=p[j],p[i] end
 return {Permutation=p,Gradients=g}
end
local function noise2(data: any,c: number,x: number,y: number,s: any?): number
 local ix,iy=math.floor(x),math.floor(y);local fx,fy=x-ix,y-iy
 local x0,x1,y0,y1=ix,ix+1,iy,iy+1
 if s then
  if s.Width>0 then x0=s.X+(x0-s.X)%s.Width;x1=s.X+(x1-s.X)%s.Width end
  if s.Height>0 then y0=s.Y+(y0-s.Y)%s.Height;y1=s.Y+(y1-s.Y)%s.Height end
 end
 local p,g=data.Permutation,data.Gradients[c]
 local px0,px1=p[x0%256],p[x1%256]
 local g00,g10,g01,g11=g[p[(px0+y0)%256]],g[p[(px1+y0)%256]],g[p[(px0+y1)%256]],g[p[(px1+y1)%256]]
 local d00=g00[1]*fx+g00[2]*fy;local d10=g10[1]*(fx-1)+g10[2]*fy
 local d01=g01[1]*fx+g01[2]*(fy-1);local d11=g11[1]*(fx-1)+g11[2]*(fy-1)
 local sx,sy=fx*fx*(3-2*fx),fy*fy*(3-2*fy)
 local a=d00+sx*(d10-d00);local b=d01+sx*(d11-d01)
 return a+sy*(b-a)
end
function Noise.frequency(f: number,size: number): number
 if f==0 or size<=0 then return f end
 local lo,hi=math.floor(size*f)/size,math.ceil(size*f)/size
 return if lo>0 and f/lo<hi/f then lo else hi
end
function Noise.sample(step: any,x: number,y: number): any
 local fx,fy=step.FrequencyX,step.FrequencyY;local tile=step.NoiseTile
 if step.Stitch then fx=Noise.frequency(fx,tile.Width);fy=Noise.frequency(fy,tile.Height) end
 local stitch=if step.Stitch then {X=math.floor(tile.X*fx),Y=math.floor(tile.Y*fy),Width=math.round(tile.Width*fx),Height=math.round(tile.Height*fy)} else nil
 x*=fx;y*=fy
 local result={0,0,0,0};local amplitude=1
 for _=1,step.Octaves do
  for c=1,4 do
   local v=noise2(step.Noise,c,x,y,stitch)
   result[c]+=(if step.NoiseType=='fractalNoise' then v else math.abs(v))*amplitude
  end
  x*=2;y*=2;amplitude*=.5
  if stitch then stitch.X*=2;stitch.Y*=2;stitch.Width*=2;stitch.Height*=2 end
 end
 for c=1,4 do result[c]=math.clamp(if step.NoiseType=='fractalNoise' then result[c]*.5+.5 else result[c],0,1) end
 return result
end
return Noise
