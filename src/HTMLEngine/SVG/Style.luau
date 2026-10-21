--!strict
local AuthorRules=require(script.Parent.Parent.CSS.AuthorRules)
local Variables=require(script.Parent.Parent.CSS.Variables)
local Paint=require(script.Parent.Paint)
local Rendering=require(script.Parent.Rendering)
local Transform=require(script.Parent.Transform)
local Length=require(script.Parent.Length)
local Cursor=require(script.Parent.Parent.CSS.Cursor)
local CompositeValues=require(script.Parent.Parent.CSS.CompositeValues)
local Style={}
local defaults={color='black',fill='black',stroke='none',['fill-opacity']='1',['stroke-opacity']='1',['stroke-width']='1',['fill-rule']='nonzero',['stroke-dasharray']='none',['stroke-dashoffset']='0',['stroke-linecap']='butt',['stroke-linejoin']='miter',['stroke-miterlimit']='4',['font-size']='16px',opacity='1',display='inline',visibility='visible',overflow='visible',['paint-order']='normal',['shape-rendering']='auto',['color-rendering']='auto',['text-rendering']='auto',['image-rendering']='auto',transform='none',['transform-origin']='0 0',['transform-box']='view-box',['vector-effect']='none',x='0',y='0',cx='0',cy='0',r='0',rx='auto',ry='auto',width='auto',height='auto'}
defaults['mask-image']='none';defaults['mask-mode']='match-source';defaults['mask-type']='luminance';defaults['mix-blend-mode']='normal';defaults.isolation='auto'
defaults.cursor='auto'
defaults['lighting-color']='white';defaults['pointer-events']='visiblePainted'
defaults['flood-color']='black';defaults['flood-opacity']='1'
defaults.filter='none';defaults['color-interpolation-filters']='linearRGB'
defaults['clip-path']='none';defaults['clip-rule']='nonzero'
defaults['stop-color']='black';defaults['stop-opacity']='1';defaults['color-interpolation']='sRGB'
for _,key in {'marker-start','marker-mid','marker-end'} do defaults[key]='none' end
local animationDefaults={['animation-name']='none',['animation-duration']='0s',['animation-delay']='0s',['animation-iteration-count']='1',['animation-direction']='normal',['animation-fill-mode']='none',['animation-timing-function']='ease',['animation-play-state']='running',['transition-property']='all',['transition-duration']='0s',['transition-delay']='0s',['transition-timing-function']='ease'}
for k,v in animationDefaults do defaults[k]=v end
local inherited={color=true,fill=true,stroke=true,['fill-opacity']=true,['stroke-opacity']=true,['stroke-width']=true,['fill-rule']=true,['stroke-dasharray']=true,['stroke-dashoffset']=true,['stroke-linecap']=true,['stroke-linejoin']=true,['stroke-miterlimit']=true,['font-size']=true,visibility=true,['paint-order']=true,['shape-rendering']=true,['color-rendering']=true,['text-rendering']=true,['image-rendering']=true}
inherited['pointer-events']=true;inherited.cursor=true
local textDefaults={['font-family']='Source Sans Pro',['font-weight']='400',['font-style']='normal',['font-kerning']='auto',['font-variant-ligatures']='normal',['text-anchor']='start',['dominant-baseline']='auto',['alignment-baseline']='baseline',['baseline-shift']='0',['letter-spacing']='normal',['word-spacing']='normal',['white-space']='normal',['writing-mode']='horizontal-tb',['text-orientation']='mixed',direction='ltr',['unicode-bidi']='normal'}
for name,value in textDefaults do defaults[name]=value;inherited[name]=name~='unicode-bidi' and name~='alignment-baseline' and name~='baseline-shift' end
defaults['line-height']='normal';inherited['line-height']=true
inherited['color-interpolation-filters']=true;inherited['color-interpolation']=true;inherited['clip-rule']=true
for _,key in {'marker-start','marker-mid','marker-end'} do inherited[key]=true end
local paintKeys={color=true,fill=true,stroke=true,['fill-opacity']=true,['stroke-opacity']=true,['stroke-width']=true,['fill-rule']=true,['stroke-dasharray']=true,['stroke-dashoffset']=true,['stroke-linecap']=true,['stroke-linejoin']=true,['stroke-miterlimit']=true}
local renderKeys={['mix-blend-mode']=true,isolation=true,opacity=true,display=true,visibility=true,overflow=true,['paint-order']=true,['shape-rendering']=true,['color-rendering']=true,['text-rendering']=true,['image-rendering']=true}
local lengthKeys={x='x',y='y',cx='x',cy='y',r='diagonal',rx='x',ry='y',width='x',height='y',['stroke-width']='diagonal',['stroke-dashoffset']='diagonal',['font-size']='font'}
local propertyNames={'font-size'}
for name in defaults do if name~='font-size' then table.insert(propertyNames,name) end end
local function trim(s: string): string return s:match('^%s*(.-)%s*$') :: string end
local function valid(name: string,value: string,context: any,css: boolean?): boolean
	if animationDefaults[name]~=nil then return #value>0 end
	if name=='line-height' then return value=='normal' or Length.resolve(value,context,'font',true)~=nil end
	if textDefaults[name]~=nil then
  if name=='font-family' then return #value>0 end
  if name=='font-weight' then return value=='normal' or value=='bold' or (tonumber(value)~=nil and tonumber(value)>=1 and tonumber(value)<=1000) end
  if name=='letter-spacing' or name=='word-spacing' or name=='baseline-shift' then return value=='normal' or value=='baseline' or value=='sub' or value=='super' or Length.resolve(value,context,'font',false)~=nil end
  local choices={['font-style']=' normal italic oblique ',['font-kerning']=' auto normal none ',['font-variant-ligatures']=' normal none common-ligatures no-common-ligatures ',['text-anchor']=' start middle end ',['dominant-baseline']=' auto alphabetic middle central hanging text-before-edge text-after-edge ideographic ',['alignment-baseline']=' baseline auto alphabetic middle central hanging text-before-edge text-after-edge before-edge after-edge ideographic ',['white-space']=' normal pre pre-wrap pre-line nowrap break-spaces ',['writing-mode']=' horizontal-tb vertical-rl vertical-lr ',['text-orientation']=' mixed upright sideways ',direction=' ltr rtl ',['unicode-bidi']=' normal embed isolate bidi-override isolate-override plaintext '}
  return choices[name]~=nil and choices[name]:find(' '..value..' ',1,true)~=nil
 end
	if name=='mask-type' then return value=='alpha' or value=='luminance'
 elseif name=='mask-mode' then return value=='alpha' or value=='luminance' or value=='match-source'
 elseif name=='mask-image' then return value=='none' or (Paint.reference(value)~=nil and value:match('%)%s*$')~=nil)
 elseif name=='clip-rule' then return value=='nonzero' or value=='evenodd'
 elseif name=='clip-path' or name=='filter' then return value=='none' or (Paint.reference(value)~=nil and value:match('%)%s*$')~=nil)
 elseif name=='marker-start' or name=='marker-mid' or name=='marker-end' then return value=='none' or (Paint.reference(value)~=nil and value:match('%)%s*$')~=nil)
 elseif name=='cursor' then return Cursor.parse(value)~=nil
 elseif name=='pointer-events' then return ({auto=true,none=true,visiblepainted=true,visiblefill=true,visiblestroke=true,visible=true,painted=true,fill=true,stroke=true,all=true,['bounding-box']=true})[value:lower()]==true
 elseif name=='stop-color' or name=='flood-color' or name=='lighting-color' then local state,errors=Paint.resolve({color=value},nil,context);return value~='none' and #errors==0
	elseif name=='stop-opacity' or name=='flood-opacity' then local _,errors=Paint.resolve({['fill-opacity']=value},nil,context);return #errors==0
	elseif name=='color-interpolation' or name=='color-interpolation-filters' then return value=='sRGB' or value=='linearRGB' or value=='auto'
	elseif paintKeys[name] then local _,errors=Paint.resolve({[name]=value},nil,context);return #errors==0
	elseif renderKeys[name] then local _,errors=Rendering.resolve({[name]=value});return #errors==0
	elseif name=='transform' then local _,problem=Transform.parse(value,context,nil,css);return problem==nil
	elseif name=='transform-origin' then local _,_,problem=Transform.origin(value,{X=0,Y=0,Width=context.Width,Height=context.Height},context);return problem==nil
	elseif name=='transform-box' then return value=='view-box' or value=='fill-box' or value=='stroke-box' or value=='content-box' or value=='border-box'
	elseif name=='vector-effect' then return value=='none' or value=='non-scaling-stroke'
	elseif lengthKeys[name] then
		if value=='auto' and (name=='width' or name=='height' or name=='rx' or name=='ry') then return true end
		local n,problem=Length.resolve(value,context,lengthKeys[name],not (name=='x' or name=='y' or name=='cx' or name=='cy'));return n~=nil and problem==nil
	end
	return false
end
local function less(a: any,b: any): boolean
	if a.Important~=b.Important then return not a.Important end
	for i=1,5 do if a.Rank[i]~=b.Rank[i] then return a.Rank[i]<b.Rank[i] end end
	return a.Index<b.Index
end
function Style.collect(document: any,diagnostic: any,extra: string?): any return AuthorRules.collect(document,diagnostic,extra,function() end) end
function Style.stateKey(document,rules,state,states) return AuthorRules.stateKey(rules,document,state,states) end
function Style.stateChanges(document: any,rules: any,state: string,before: any,after: any): boolean return AuthorRules.stateChanges(rules,document,state,before,after) end
function Style.compute(node: any,parent: any?,context: any,rules: any,diagnostic: any,states: any?): any
	local candidates=if node.ExternalDeclarations then {}else AuthorRules.match(rules,node,states)
	if node.ExternalDeclarations then
		local declarations=node.ExternalDeclarations(states);local order=0
		for _,entries in {declarations.Normal,declarations.Important}do for _,entry in entries do
			if defaults[entry.Name]~=nil or entry.Name=='font'or entry.Name:sub(1,2)=='--'then
				order+=1;table.insert(candidates,{Name=entry.Name,Value=entry.Value,Important=entry.Important,Rank={0,0,0,0,order},CSS=true})
			end
		end end
	end
	for name,value in node.Attributes do
		-- CSS-only property: unlike writing-mode, this is not an SVG presentation attribute.
		if name=='text-orientation' or name=='line-height' or name=='white-space' or name=='font-kerning' or name=='font-variant-ligatures' then continue end
		if (node.Name=='text' or node.Name=='tspan') and (name=='x' or name=='y') then continue end
		if (name=='gradientTransform' and (node.Name=='linearGradient' or node.Name=='radialGradient')) or (name=='patternTransform' and node.Name=='pattern') then table.insert(candidates,{Name='transform',Value=value,Important=false,Rank={-1,0,0,0,0},CSS=false}) end
		if name=='marker' or name=='mask' then table.insert(candidates,{Name=name,Value=value,Important=false,Rank={-1,0,0,0,0},CSS=false}) end
		if defaults[name]~=nil then table.insert(candidates,{Name=name,Value=value,Important=false,Rank={-1,0,0,0,0},CSS=false}) end
	end
	for _,entry in AuthorRules.declarations(node.Attributes.style or '') do
		table.insert(candidates,{Name=entry.Name,Value=entry.Value,Important=entry.Important,Rank={1,0,0,0,0},CSS=true})
	end
	local expanded={}
	for _,entry in candidates do
		if entry.Name=='font'then
			local properties={};for _,name in {'font-family','font-size','font-weight','font-style','line-height'}do properties[name]={Field=name,Name=name}end
			local value=CompositeValues.parse('FontShorthand',entry.Value,function(property,token)return token,valid(property.Name,token,context,true)end,properties)
			if value then
				for _,name in {'font-family','font-size','font-weight','font-style','line-height'}do
					local part=table.clone(entry);part.Name=name;part.Value=value[name]or defaults[name];table.insert(expanded,part)
				end
			end
		else table.insert(expanded,entry)end
	end;candidates=expanded
	for i,entry in candidates do entry.Index=i;entry.Important=entry.Important==true end
	table.sort(candidates,less)
	local winners,custom={},{}
	local wide={inherit=true,initial=true,unset=true,revert=true,['revert-layer']=true}
	local function consider(entry: any,name: string)
		local value=trim(entry.Value)
		if name:sub(1,2)=='--' then custom[name]=value;return end
		if defaults[name]==nil then diagnostic('unsupported-svg-css-property',name);return end
		if wide[value] or value:find('var(',1,true) or valid(name,value,context,entry.CSS) then winners[name]={Value=value,CSS=entry.CSS}
		else diagnostic('invalid-css-declaration',name..':'..value) end
	end
	for _,entry in candidates do
		if entry.Name=='mask' then
   if wide[trim(entry.Value)] or valid('mask-image',trim(entry.Value),context,entry.CSS) or entry.Value:find('var(',1,true) then
    consider(entry,'mask-image');local reset=table.clone(entry);reset.Value=if wide[trim(entry.Value)] then entry.Value else 'match-source';consider(reset,'mask-mode')
   else diagnostic('unsupported-mask-shorthand',entry.Value) end
  elseif entry.Name=='marker' then for _,key in {'marker-start','marker-mid','marker-end'} do consider(entry,key) end
		elseif entry.Name=='all' and wide[trim(entry.Value)] then for name in defaults do consider(entry,name) end
		else consider(entry,entry.Name) end
	end
	local variables=Variables.compute(custom,parent and parent.Custom)
	local values,kinds={},{}
	local function fallback(name: string): string
		return if inherited[name] and parent then parent.Values[name] else defaults[name]
	end
	local usedContext=table.clone(context)
	for _,name in propertyNames do
		local winner=winners[name];local value=if winner then winner.Value else fallback(name)
		local kind=winner and winner.CSS
		if not winner then
			if node.Name=='mask' then
    if name=='x' or name=='y' then value='-10%' elseif name=='width' or name=='height' then value='120%' end
   end
   if name=='overflow' and (node.Name=='marker' or node.Name=='pattern' or (node.Name=='svg' and node.Parent and node.Parent.Kind=='Element')) then value='hidden' end
			if name=='transform-origin' and node.Name=='svg' and (not node.Parent or node.Parent.Kind~='Element') then value='50% 50%' end
		elseif value:find('var(',1,true) then
			value=Variables.substitute(value,variables)
			if not value or (not wide[trim(value)] and not valid(name,trim(value),usedContext,kind)) then value='unset' end
			value=trim(value)
		end
		if value=='inherit' or (value=='unset' and inherited[name]) or value=='revert' or value=='revert-layer' then
			value=if value=='inherit' and parent then parent.Values[name] else fallback(name)
			kind=parent and parent.Kinds[name]
		elseif value=='initial' or value=='unset' then value=defaults[name];if name=='transform-origin' then value='50% 50%' end;kind=false end
		if name=='font-size' then
			local n=Length.resolve(value,context,'font',true) or context.FontSize
			value=tostring(n)..'px';usedContext.FontSize=n
		elseif lengthKeys[name] and value~='auto' then
			local parsed=Length.parse(value)
			if parsed and parsed.Unit~='%' then local n=Length.resolve(parsed,usedContext,lengthKeys[name],false);if n then value=tostring(n) end end
		end
		values[name]=value;kinds[name]=kind
	end
	local attributes=table.clone(node.Attributes);attributes.style=nil
	for name,value in values do
		if (node.Name=='text' or node.Name=='tspan') and (name=='x' or name=='y') then continue end
		if ((node.Name=='linearGradient' or node.Name=='radialGradient') and (name=='cx' or name=='cy' or name=='r')) or (node.Name=='pattern' and (name=='x' or name=='y' or name=='width' or name=='height')) then continue end
		attributes[name]=value
	end
	if node.Name=='svg' or node.Name=='symbol' then
		if attributes.width=='auto' then attributes.width=nil end
		if attributes.height=='auto' then attributes.height=nil end
	end
	if kinds.transform then attributes.transform=nil;attributes.style='transform:'..values.transform..';' end
	return {Values=values,Kinds=kinds,Custom=variables,Attributes=attributes,FontSize=usedContext.FontSize,Specified=winners}
end
return Style
