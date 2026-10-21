--!strict
-- Color effects keep currentColor symbolic until the sampled foreground is
-- known. Author values and inherited samples never share a mutable snapshot.
local Variables=require(script.Parent.Variables)
local Colors={}
Colors.Properties={
 color={Field='Color'},['background-color']={Field='Background'},
 ['outline-color']={Field='OutlineColor'},['text-decoration-color']={Field='DecorationColor'},
 ['text-emphasis-color']={Field='TextEmphasisColor'},
 ['border-top-color']={Field='BorderColor',Side=1},['border-right-color']={Field='BorderColor',Side=2},
 ['border-bottom-color']={Field='BorderColor',Side=3},['border-left-color']={Field='BorderColor',Side=4},
}
Colors.Order={'color','background-color','border-top-color','border-right-color','border-bottom-color','border-left-color','outline-color','text-decoration-color','text-emphasis-color'}
for index,property in Colors.Order do Colors.Properties[property].SourceBit=bit32.lshift(1,index-1)end
local function read(style,property)
 local spec=Colors.Properties[property];local edge=spec.Side and style.BorderSides and style.BorderSides[spec.Side]
 local tint=if edge then edge.Color else style[spec.Field];local alpha=if edge then edge.Alpha else style[spec.Field..'Alpha']
 if (property=='text-decoration-color'or property=='text-emphasis-color')and tint==nil then tint='currentcolor'end
 return {Color=tint or Color3.new(0,0,0),Alpha=if tint==nil then 0 else alpha or 1}
end
function Colors.fromStyle(style,property)
 if bit32.band(style.AnimationColorSources or 0,Colors.Properties[property].SourceBit)~=0 then return {Color='currentcolor',Alpha=1}end
 return read(style,property)
end
Colors.used=read
function Colors.base(box,property)
 return if box.AnimationColorAuthor and box.AnimationColorAuthor[property]then box.AnimationColorAuthor[property]else Colors.fromStyle(box.Style,property)
end
function Colors.snapshot(style)
 local result={};for _,property in Colors.Order do result[property]=Colors.fromStyle(style,property)end;return result
end
local function mixConstant(a,b,t)
 local alpha=math.clamp(a.Alpha+(b.Alpha-a.Alpha)*t,0,1)
 local function channel(key)return if alpha==0 then 0 else (a.Color[key]*a.Alpha+(b.Color[key]*b.Alpha-a.Color[key]*a.Alpha)*t)/alpha end
 return {Color=Color3.new(channel('R'),channel('G'),channel('B')),Alpha=alpha}
end
local function symbolic(value)return value.Kind~=nil or value.Color=='currentcolor'end
function Colors.mix(a,b,t)
 if symbolic(a)or symbolic(b)then return {Kind='mix',Left=a,Right=b,Progress=t}end
 return mixConstant(a,b,t)
end
local function addConstant(a,b,count)
 local alpha=math.clamp(a.Alpha+b.Alpha*count,0,1)
 local function channel(key)return if alpha==0 then 0 else (a.Color[key]*a.Alpha+b.Color[key]*b.Alpha*count)/alpha end
 return {Color=Color3.new(channel('R'),channel('G'),channel('B')),Alpha=alpha}
end
function Colors.add(a,b,count)
 count=count or 1
 if symbolic(a)or symbolic(b)then return {Kind='add',Left=a,Right=b,Count=count}end
 return addConstant(a,b,count)
end
function Colors.resolve(value,current,unclamped)
 local result
 if value.Kind=='mix'then result=mixConstant(Colors.resolve(value.Left,current,true),Colors.resolve(value.Right,current,true),value.Progress)
 elseif value.Kind=='add'then result=addConstant(Colors.resolve(value.Left,current,true),Colors.resolve(value.Right,current,true),value.Count)
 elseif value.Color=='currentcolor'then result=current
 else result=value end
 if unclamped then return result end
 local tint=result.Color
 if tint.R>=0 and tint.R<=1 and tint.G>=0 and tint.G<=1 and tint.B>=0 and tint.B<=1 then return result end
 return {Color=Color3.new(math.clamp(tint.R,0,1),math.clamp(tint.G,0,1),math.clamp(tint.B,0,1)),Alpha=result.Alpha}
end
function Colors.prepare(style,parent,overrides)
 local sources,base=0,if overrides then {}else nil
 for _,property in Colors.Order do
  local spec=Colors.Properties[property];local edge=spec.Side and style.BorderSides and style.BorderSides[spec.Side]
  local tint=if edge then edge.Color else style[spec.Field]
  if tint=='currentcolor'or property=='text-decoration-color'and tint==nil then sources=bit32.bor(sources,spec.SourceBit)end
  if base then base[property]=read(style,property)end
 end
 style.AnimationColorSources=if sources~=0 then sources else nil
 if not overrides then return end
 style.AnimationColorBase=base
 local ancestor={Color=parent.Color,Alpha=parent.ColorAlpha or 1}
 local foreground=Colors.resolve(overrides.color or base.color,ancestor)
 for _,property in Colors.Order do
  local value=overrides[property];if not value then continue end
  value=if property=='color'then foreground else Colors.resolve(value,foreground)
  local spec=Colors.Properties[property]
  if spec.Side then
   if not style.BorderSides then
    style.BorderSides={};for side=1,4 do style.BorderSides[side]={Width=style.BorderWidth,Style=style.BorderStyle,Color=style.BorderColor,Alpha=style.BorderColorAlpha or 1}end
   end
   style.BorderSides[spec.Side].Color,style.BorderSides[spec.Side].Alpha=value.Color,value.Alpha
  else style[spec.Field],style[spec.Field..'Alpha']=value.Color,value.Alpha end
  -- A sampled color is a resolved computed value for inheritance. Its author
  -- currentColor source remains isolated in AnimationColorBase instead.
  sources=bit32.band(sources,bit32.bnot(spec.SourceBit))
 end
 style.AnimationColorSources=if sources~=0 then sources else nil
end
function Colors.matches(entry,property)
 local spec=Colors.Properties[property];if entry.VariableProperty==property then return true end
 if spec.Side then
  if entry.Field~='BorderColor'and entry.Field~='Border'then return false end
  return not entry.BorderSide or entry.BorderSide==spec.Side
 end
 return entry.Field==spec.Field or property=='background-color'and(entry.Field=='BackgroundShorthand'or entry.VariableProperty=='background')
  or property=='outline-color'and entry.Field=='Outline'or property=='text-decoration-color'and entry.ResetDecoration==true
  or property=='text-emphasis-color'and entry.Field=='TextEmphasisShorthand'
end
function Colors.stop(frame,property,box,parent,resolve)
 local entries,contextual={},false
 for _,entry in frame.Declarations.Normal do if not entry.Error and Colors.matches(entry,property)then table.insert(entries,entry);contextual=contextual or entry.Wide~=nil or entry.VariableProperty~=nil or entry.Relative~=nil or entry.LogicalSides~=nil end end
 if #entries==0 then return nil end
 local last=entries[#entries]
 if property=='color'then
  local wide=last.Wide
  if last.VariableProperty then wide=Variables.substitute(last.Raw,box.Style.Custom);wide=wide and wide:match('^%s*(.-)%s*$')or'unset'end
  if wide=='inherit'or wide=='unset'then return {Color='currentcolor',Alpha=1}end
 end
 if not contextual then
  local entry=entries[#entries];local value=entry.Value
  if entry.BorderComponents then value=value[Colors.Properties[property].Side]end
  return {Color=value.Color or Color3.new(0,0,0),Alpha=value.Alpha or(if value.Color then 1 else 0)}
 end
 local context=table.clone(box.Style)
 if property=='color'and parent then context.Color,context.ColorAlpha=parent.Color,parent.ColorAlpha end
 -- inherit uses the actual parent's computed color longhand. Variables still
 -- belong to the animation target, including an inherited custom-property map.
 local inherit=false;for _,entry in entries do if entry.Wide=='inherit'then inherit=true end end
 if inherit and parent then context=table.clone(parent)end
 context.Custom=box.Style.Custom
 local fake={Kind='Element',Name=box.Node and box.Node.Name or'div',Attributes={}}
 local style=resolve(fake,context,function()end,false,{Normal=entries,Important={}})
 return Colors.fromStyle(style,property)
end
function Colors.values(properties,changed)
 local result={};for _,property in Colors.Order do if changed[property]then result[property]=properties[property]end end;return result
end
return Colors
