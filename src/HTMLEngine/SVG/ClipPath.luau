--!strict
local Matrix=require(script.Parent.Matrix)
local Transform=require(script.Parent.Transform)
local Paint=require(script.Parent.Paint)
local ClipPath={}
function ClipPath.build(doc: any,node: any,box: any,context: any,t: any,render: any,report: any,active: any): any
 local value=node.Attributes['clip-path'] or 'none'
 if value=='none' then return nil end
 local url=Paint.reference(value)
 if not url then report('unsupported-clip-path',value);return nil end
 local target,scope=doc.Resource(url.URL,node)
 if not target or target.Name~='clipPath' then report('invalid-clip-reference',value);return nil end
 if active[target] then report('cyclic-clip-reference',value);return {Shapes={},RenderTree={}} end
 local ctx=table.clone(context);local mapping=t
 local units=target.Attributes.clipPathUnits or 'userSpaceOnUse'
 if units=='objectBoundingBox' then
  if box.Width<=0 or box.Height<=0 then return {Shapes={},RenderTree={}} end
  ctx.Width=1;ctx.Height=1
  mapping=Matrix.multiply(t,{SX=box.Width,SY=box.Height,TX=box.X,TY=box.Y})
 elseif units~='userSpaceOnUse' then report('invalid-clip-units',units);return nil end
 local computed=doc.Compute(target,scope,ctx)
 local transform,issues=Transform.resolve(Transform.declarations(computed.Attributes),{X=0,Y=0,Width=ctx.Width,Height=ctx.Height},ctx)
 for _,issue in issues do report(issue,value) end
 mapping=Matrix.multiply(mapping,transform)
 active[target]=true
 local root=doc.Content(target.Children,computed,scope,ctx)
 root.Attributes['clip-path']=computed.Values['clip-path'];root.Scope=scope
 local function silhouette(n: any)
  if n.Kind~='Element' then return end
  local a=n.Attributes
  a['mask-image']='none';a['mix-blend-mode']='normal';a.isolation='auto'
  a.fill='white';a.stroke='none';a.opacity='1';a['fill-opacity']='1';a['fill-rule']=a['clip-rule'] or 'nonzero'
  a['marker-start']='none';a['marker-mid']='none';a['marker-end']='none'
  -- Text stays semantic until the common visitor expands its actual font outlines.
  if n.Name=='g' and n.Source and n.Source.Name~='use' then report('invalid-clip-child','g');n.Name='defs' end
  if n.Name=='image' then report('invalid-clip-child','image');n.Name='defs' end
  for _,child in n.Children do silhouette(child) end
 end
 silhouette(root)
 local scene=render(root,{Transform=mapping,UserWidth=ctx.Width,UserHeight=ctx.Height},nil,nil,nil)
 active[target]=nil
 return scene
end
return ClipPath
