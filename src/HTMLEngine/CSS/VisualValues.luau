--!strict
-- Compatibility names and expanded visual declarations share the normal cascade.
local Tokens=require(script.Parent.GridValues)
local Color=require(script.Parent.Color)
local Background=require(script.Parent.Background)
local Length=require(script.Parent.LengthExpression)
local Values={}
Values.Aliases={}
for old,new in {before='block-start',after='block-end',start='inline-start',['end']='inline-end'}do
 for _,suffix in {'','-color','-style','-width'}do Values.Aliases['-webkit-border-'..old..suffix]='border-'..new..suffix end
end
for _,suffix in {'','-image','-clip','-origin','-position','-size','-repeat','-composite','-position-x','-position-y','-repeat-x','-repeat-y'}do
 Values.Aliases['-webkit-mask'..suffix]='mask'..suffix
end
for _,suffix in {'','-source','-slice','-width','-outset','-repeat'}do Values.Aliases['-webkit-mask-box-image'..suffix]='mask-border'..suffix end
Values.SideCorners={top={'top-left','top-right'},right={'top-right','bottom-right'},bottom={'bottom-left','bottom-right'},left={'top-left','bottom-left'},
 ['block-start']={'start-start','start-end'},['block-end']={'end-start','end-end'},['inline-start']={'start-start','end-start'},['inline-end']={'start-end','end-end'}}
local corners={'top-left','top-right','bottom-right','bottom-left','start-start','start-end','end-end','end-start'}
Values.Corners=corners
local shapeNames={round=true,bevel=true,notch=true,squircle=true,scoop=true,square=true}
function Values.shape(value)
 return shapeNames[value] or value:match('^superellipse%([+%-]?%d*%.?%d+%)$')~=nil
end
local function wide(v)return v=='initial' or v=='inherit' or v=='unset'end
function Values.expand(name,value)
 if name=='mask-border'and wide(value)then
  local out={};for _,suffix in {'source','slice','width','outset','repeat','mode'}do table.insert(out,{Name='mask-border-'..suffix,Value=value})end;return out
 end
 if name=='border-image'and wide(value)then
  local out={};for _,suffix in {'source','slice','width','outset','repeat'}do table.insert(out,{Name='border-image-'..suffix,Value=value})end;return out
 end
 if name=='mask' and wide(value)then
  local out={};for _,suffix in {'image','position','size','repeat','origin','clip','composite','mode'}do table.insert(out,{Name='mask-'..suffix,Value=value})end
  for _,suffix in {'source','slice','width','outset','repeat','mode'}do table.insert(out,{Name='mask-border-'..suffix,Value=value})end;return out
 end
 if name=='box-shadow' and wide(value)then
  local out={};for _,suffix in {'color','offset','blur','spread','position'}do table.insert(out,{Name='box-shadow-'..suffix,Value=value})end;return out
 end
 local side=name:match('^border%-(.-)%-radius$')
 if side and Values.SideCorners[side]then
  local pair=Values.SideCorners[side];local out={}
  if wide(value)then for _,c in pair do table.insert(out,{Name='border-'..c..'-radius',Value=value})end;return out end
  local axes=Tokens.tokens(value,'/');if not axes or #axes>2 then return nil end
  local x,y=Tokens.tokens(axes[1]),Tokens.tokens(axes[2] or axes[1]);if not x or not y or #x<1 or #x>2 or #y<1 or #y>2 then return nil end
  for _,v in x do if not Length.parse(v)or Length.resolve(Length.parse(v),100)<0 then return nil end end
  for _,v in y do if not Length.parse(v)or Length.resolve(Length.parse(v),100)<0 then return nil end end
  for i,c in pair do table.insert(out,{Name='border-'..c..'-radius',Value=(x[i] or x[1])..' '..(y[i] or y[1])})end;return out
 end
 if name=='corner' or name:match('^corner%-')and not name:match('%-shape$')then
  local target=name:match('^corner%-(.+)$');local radiusName=if target then 'border-'..target..'-radius' else 'border-radius'
  local shapeName=if target then 'corner-'..target..'-shape'else 'corner-shape'
  if wide(value)then return {{Name=radiusName,Value=value},{Name=shapeName,Value=value}}end
  local parts=Tokens.tokens(value);if not parts then return nil end
  local radii,shapes={},{};for _,p in parts do if Values.shape(p)then table.insert(shapes,p)else table.insert(radii,p)end end
  if #shapes> (if not target then 4 elseif Values.SideCorners[target]then 2 else 1) then return nil end
  local radius=if #radii>0 then table.concat(radii,' ')else '0'
  local shape=if #shapes>0 then table.concat(shapes,' ')else 'round'
  -- Validate every component before returning an expansion.
  local axes=Tokens.tokens(radius,'/');if not axes or #axes>2 then return nil end
  local limit=if not target then 4 else 2
  if target and not Values.SideCorners[target]and #axes>1 then return nil end
  for _,axis in axes do
   local lengths=Tokens.tokens(axis);if not lengths or #lengths<1 or #lengths>limit then return nil end
   for _,p in lengths do local l=Length.parse(p);if not l or Length.resolve(l,100)<0 then return nil end end
  end
  return {{Name=radiusName,Value=radius},{Name=shapeName,Value=shape}}
 end
 if name:match('^corner%-(.-)%-shape$')then
  local group=name:match('^corner%-(.-)%-shape$');local pair=Values.SideCorners[group]
  if pair then
   local parts=Tokens.tokens(value);if not parts or #parts<1 or #parts>2 then return nil end
   for _,p in parts do if not wide(p)and not Values.shape(p)then return nil end end
   return {{Name='corner-'..pair[1]..'-shape',Value=parts[1]},{Name='corner-'..pair[2]..'-shape',Value=parts[2]or parts[1]}}
  end
 end
 return nil
end
function Values.parse(kind,value,parseLength)
 if kind=='corner-shapes'then
  local parts=Tokens.tokens(value);if not parts or #parts<1 or #parts>4 then return nil,false end
  for _,p in parts do if not Values.shape(p)then return nil,false end end
  return {parts[1],parts[2]or parts[1],parts[3]or parts[1],parts[4]or parts[2]or parts[1]},true
 elseif kind=='repeat-axis'then
  local parts=Tokens.tokens(value,',');if not parts or #parts<1 or #parts>8 then return nil,false end
  for _,p in parts do if not ({['repeat']=true,['no-repeat']=true,round=true,space=true})[p]then return nil,false end end
  return parts,true
 elseif kind=='clip-rect'then
  if value=='auto'then return nil,true end
  local body=value:match('^rect%((.*)%)$');if not body then return nil,false end
  local parts=Tokens.tokens(body,if body:find(',',1,true)then ','else nil);if not parts or #parts~=4 then return nil,false end
  local out={};for _,p in parts do
   if p=='auto'then table.insert(out,false)else local l=parseLength(p,true);if not l or l.Percent then return nil,false end;table.insert(out,l)end
  end;return out,true
 elseif kind:match('^shadow%-')then
  local parts=Tokens.tokens(value,',');if not parts or #parts<1 or #parts>16 then return nil,false end
  local out={}
  for _,p in parts do
   if kind=='shadow-color'then local c,a=Color.parse(p);if not c then return nil,false end;table.insert(out,{Color=c,Alpha=a or 1})
   elseif kind=='shadow-position'then if p~='inset'and p~='outset'then return nil,false end;table.insert(out,p)
   elseif kind=='shadow-offset'and p=='none'then table.insert(out,false)
   else
    local lengths=Tokens.tokens(p);if not lengths or #lengths<1 or #lengths>(if kind=='shadow-offset'then 2 else 1)then return nil,false end
    local numbers={};for _,l in lengths do local n=parseLength(l,true);if not n or n.Percent then return nil,false end
     local v=Length.resolve(n,0);if kind=='shadow-blur'and (v<0 or v>1000)then return nil,false end;table.insert(numbers,v)
    end
    table.insert(out,if kind=='shadow-offset'then {X=numbers[1],Y=numbers[2]or numbers[1]}else numbers[1])
   end
  end;return out,true
 elseif kind=='mask-shorthand'then
  local result=Background.shorthand(value,parseLength)
  if not result or result.Color then return nil,false end
  local source={Kind='layers',Layers=result.Images,Key=value}
  local enabled=false
  for _,image in result.Images do if image.Kind=='url'then return nil,false end;if image.Kind~='none'then enabled=true end end
  if not enabled then source=nil end
  local origin,clip=result.Origins,result.Clips
  if not value:find('box',1,true)then origin,clip={'border-box'},{'border-box'}end
  return {MaskImage=source,MaskPositions=result.Positions,MaskSizes=result.Sizes,MaskRepeats=result.Repeats,MaskOrigins=origin,MaskClips=clip,MaskComposite='add',MaskMode='alpha'},true
 end
 return nil,false
end
function Values.register(p)
 local function entry(kind,field,values,limitations)return {Kind=kind,Field=field,Values=values,Limitations=limitations,Inherited=false,Replaced=true}end
 for _,field in {'background','mask'}do
  for _,axis in {'x','y'}do
   local name=field..'-repeat-'..axis
   p[name]=entry('repeat-axis',if field=='mask'then 'MaskRepeats'else 'BackgroundRepeats','repeat | no-repeat | round | space; comma-separated','Achsenkomponente der vorhandenen Wiederholung.');p[name].Axis=axis:upper()
   if field=='mask'then p[field..'-position-'..axis]=table.clone(p['background-position-'..axis]);p[field..'-position-'..axis].Field='MaskPositions'end
  end
 end
 for logical,axis in {block='y',inline='x'}do
  Values.Aliases['background-position-'..logical]='background-position-'..axis
  Values.Aliases['background-repeat-'..logical]='background-repeat-'..axis
 end
 p['corner-shape']=entry('corner-shapes','CornerShapes','round | bevel | notch | squircle | scoop | square | superellipse(number); 1–4 Werte','Form pro Ecke; Rasterpfad mit begrenzter Auflösung, keine exakte Schattenkontur für nicht-runde Formen.')
 for _,c in corners do
  local e=table.clone(p['corner-shape']);if c:find('start',1,true)or c:find('end',1,true)then e.LogicalCorner=c else e.Corner=c end;p['corner-'..c..'-shape']=e
  p['corner-'..c]=entry('visual-shorthand','VisualShorthand','Radius || Form','Kurzform für den einzelnen Radius und die einzelne Eckform.')
 end
 for side in Values.SideCorners do
  p['border-'..side..'-radius']=entry('visual-shorthand','VisualShorthand','1–2 Radien [ / 1–2 Radien ]','Kurzform für die zwei Radien der Seite; logische Seiten folgen direction.')
  p['corner-'..side..'-shape']=entry('visual-shorthand','VisualShorthand','1–2 Eckformen','Kurzform für die zwei Eckformen der Seite.')
  p['corner-'..side]=entry('visual-shorthand','VisualShorthand','Radien || Eckformen','Kurzform für die beiden Radien und Formen der Seite.')
 end
 p.corner=entry('visual-shorthand','VisualShorthand','border-radius || corner-shape','Kurzform für alle Radien und Formen.')
 for suffix,field in {color='ShadowColors',offset='ShadowOffsets',blur='ShadowBlurs',spread='ShadowSpreads',position='ShadowPositions'}do
  p['box-shadow-'..suffix]=entry('shadow-'..suffix,field,'Liste von '..suffix..'-Werten','Komponentenlisten werden wie CSS pro Schatten zyklisch wiederholt; vorhandener Roblox-Schattenrenderer.')
 end
 p.clip=entry('clip-rect','ClipRect','auto | rect(top,right,bottom,left)','Rechteckiger Ausschnitt für absolute/fixed Boxen; automatische Kanten folgen der Boxgröße.')
 p['border-image'].Values='url(...) | linear/radial/conic-gradient(...) [slice [fill] [ / width [ / outset ] ]] [1–2 stretch | round | repeat | space]'
 p['border-image'].Limitations='Verlaufsquellen mit neun Segmenten, Slice/Fill, Breite und Outset; externe Roblox-Bilder bleiben im begrenzten nativen Slice-Profil.'
 p['border-image-source'].Values='none | url(...) | linear/radial/conic-gradient(...)'
 p['border-image-source'].Limitations='Verlaufsraster mit Farbstopps; URL-Quellen benötigen Roblox-Assetzuordnungen.'
 p['border-image-slice'].Kind='border-image-slice';p['border-image-slice'].Values='1–4 nichtnegative Zahlen/% [fill]'
 p['border-image-width'].Kind='border-image-width';p['border-image-width'].Values='1–4 Zahlen | Längen/% | auto'
 p['border-image-width'].Limitations='Neun-Segment-Verläufe: Zahlen skalieren die Rahmenbreite, Längen/% und auto bestimmen die Segmentbreite; URL-Quellen bleiben im nativen Slice-Profil.'
 p['border-image-outset'].Kind='border-image-outset';p['border-image-outset'].Values='1–4 Zahlen oder nichtnegative Längen'
 p['border-image-outset'].Limitations='Zahlen skalieren die Rahmenbreite, Längen erweitern den Bildbereich ohne Einfluss auf das Layout.'
 p['border-image-repeat'].Kind='border-image-repeat';p['border-image-repeat'].Values='1–2 stretch | round | repeat | space';p['border-image-repeat'].Limitations='Verlaufssegmente werden pro Achse gestreckt, gekachelt, gerundet oder mit Zwischenräumen verteilt; URL-Quellen haben nur natives Slice/Tile.'
 p.mask.Kind,p.mask.Field='mask-shorthand','MaskShorthand'
 p.mask.Values='1–8 Verlaufsmasken mit Position / Größe, Wiederholung und Bezugsboxen';p.mask.Limitations='Setzt Maskenkomponenten gemeinsam und setzt mask-border zurück; keine URL-Quellen oder Composite-/Mode-Tokens in der Kurzform.'
 p['mask-position'].Limitations='Position pro Verlaufsmaske, Listen werden zyklisch zugeordnet.'
 p['mask-size'].Limitations='Größe pro Verlaufsmaske; bei mehreren Rastermasken werden Listen zyklisch zugeordnet.'
 p['mask-repeat'].Limitations='repeat/no-repeat/space/round pro Achse; komplexe Wiederholung verwendet das begrenzte Maskenraster.'
 p['mask-mode'].Allowed.luminance=true;p['mask-mode'].Values='alpha | luminance';p['mask-mode'].Limitations='Verlaufsquellen mit Alpha oder gewichteter RGB-Luminanz; keine SVG-mask-Quellen.'
 p['mask-border'].Kind='mask-border-shorthand';p['mask-border'].Field='MaskBorderShorthand';p['mask-border'].Values='gradient(...) [slice [fill] [ / width [ / outset ] ]] [1–2 stretch | round | repeat | space] [alpha | luminance]';p['mask-border'].Limitations='Neun-Segment-Verlaufsmaske; keine URL-Pixelquellen. Flächen außerhalb der Box werden nicht gerastert.'
 p['mask-border-source'].Kind='mask-border-source';p['mask-border-source'].Limitations='Lineare, radiale und konische Verlaufsquelle; keine URL-Pixelquellen.'
 p['mask-border-source'].Values='none | linear/radial/conic-gradient(...)'
 for suffix,kind in {slice='border-image-slice',width='border-image-width',outset='border-image-outset'}do
  p['mask-border-'..suffix]=table.clone(p['border-image-'..suffix]);p['mask-border-'..suffix].Field='MaskBorder'..suffix:sub(1,1):upper()..suffix:sub(2);p['mask-border-'..suffix].Kind=kind
 end
 p['mask-border-repeat']=table.clone(p['border-image-repeat']);p['mask-border-repeat'].Allowed=table.clone(p['border-image-repeat'].Allowed);p['mask-border-repeat'].Field='MaskBorderRepeat'
 p['mask-border-mode']=table.clone(p['mask-mode']);p['mask-border-mode'].Allowed=table.clone(p['mask-mode'].Allowed);p['mask-border-mode'].Field='MaskBorderMode'
 for alias,name in Values.Aliases do
  -- The deprecated mask-box-image family is an accepted parser compatibility
  -- spelling outside the dated property inventory, like the existing base alias.
  if not alias:match('^%-webkit%-mask%-box%-image')then
   local e=table.clone(p[name]);if e.Allowed then e.Allowed=table.clone(e.Allowed)end;e.Limitations='Kompatibilitätsname für '..name..'. '..e.Limitations;p[alias]=e
  end
 end
end
return Values
