--!strict
--!optimize 2
--!native
local Matrix=require(script.Parent.Matrix)
local Viewport=require(script.Parent.Viewport)
local Length=require(script.Parent.Length)
local Paint=require(script.Parent.Paint)
local Mask={}
local function empty(): any return {Scene={Shapes={},RenderTree={}},Mode='alpha'} end
function Mask.build(doc: any,node: any,box: any,context: any,t: any,render: any,report: any,active: any): any
 local value=node.Attributes['mask-image'] or node.Attributes.mask or 'none'
 if value=='none' then return nil end
 local url=Paint.reference(value)
 if not url then report('unsupported-mask-reference',value);return empty() end
 local target,scope=doc.Resource(url.URL,node)
 if not target or target.Name~='mask' or target.NamespaceURI~=node.NamespaceURI then report('invalid-mask-reference',value);return empty() end
 if active[target] then report('cyclic-mask-reference',value);return empty() end
 local units=target.Attributes.maskUnits or 'objectBoundingBox'
 local contentUnits=target.Attributes.maskContentUnits or 'userSpaceOnUse'
 if (units~='objectBoundingBox' and units~='userSpaceOnUse') or (contentUnits~='objectBoundingBox' and contentUnits~='userSpaceOnUse') then report('invalid-mask-units',value);return empty() end
 if (units=='objectBoundingBox' or contentUnits=='objectBoundingBox') and (box.Width<=0 or box.Height<=0) then return empty() end
 local regionContext=table.clone(context)
 if units=='objectBoundingBox' then regionContext.Width=1;regionContext.Height=1 end
 local computed=doc.Compute(target,scope,context)
 local a=computed.Attributes;local coordinates={}
 for _,key in {'x','y','width','height'} do
  local axis=if key=='x' or key=='width' then 'x' else 'y'
  local n,issue=Length.resolve(a[key],regionContext,axis,key=='width' or key=='height')
  if not n or issue then report('invalid-mask-region',key);return empty() end
  coordinates[key]=n
 end
 if coordinates.width<=0 or coordinates.height<=0 then return empty() end
 local boxMapping={SX=box.Width,SY=box.Height,TX=box.X,TY=box.Y}
 -- Expanded use geometry already includes x/y in its bounding box, but its
 -- user-space mask coordinates also need that supplemental translation.
 local userMapping=if node.UseTranslation then Matrix.multiply(t,node.UseTranslation) else t
 local regionMapping=if units=='objectBoundingBox' then Matrix.multiply(t,boxMapping) else userMapping
 local region=Viewport.resolve({},coordinates.x,coordinates.y,coordinates.width,coordinates.height,regionMapping,nil,false).Clip
 local ctx=table.clone(context);ctx.FontSize=computed.FontSize
 local mapping=userMapping
 if contentUnits=='objectBoundingBox' then ctx.Width=1;ctx.Height=1;mapping=Matrix.multiply(t,boxMapping) end
 active[target]=true
 local root=doc.Content(target.Children,computed,scope,ctx)
 -- A mask owns its style scope and an isolated transparent surface.
 for _,key in {'opacity','clip-path','mask-image','mask-mode','mix-blend-mode','isolation'} do root.Attributes[key]=a[key] end
 local scene=render(root,{Transform=mapping,UserWidth=ctx.Width,UserHeight=ctx.Height,Clip=region},nil,nil,nil)
 active[target]=nil
 local mode=node.Attributes['mask-mode'] or 'match-source'
 if mode=='match-source' then mode=computed.Values['mask-type'] end
 return {Scene=scene,Mode=mode,Linear=computed.Values['color-interpolation']=='linearRGB'}
end
function Mask.alpha(bytes: buffer,at: number,mode: string,linear: boolean?): number
 local alpha=buffer.readu8(bytes,at+3)/255
 if mode=='alpha' or alpha==0 then return alpha end
 local function channel(i: number): number
  local c=buffer.readu8(bytes,at+i)/255
  return if not linear then c elseif c<=.04045 then c/12.92 else ((c+.055)/1.055)^2.4
 end
 return alpha*(.2125*channel(0)+.7154*channel(1)+.0721*channel(2))
end
return Mask
