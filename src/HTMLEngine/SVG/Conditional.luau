--!strict
local Conditional={}
-- Audited legacy/draft elements are reported rather than treated as ordinary groups.
Conditional.Unsupported={font='svg-font',glyph='svg-font',['missing-glyph']='svg-font',hkern='svg-font',vkern='svg-font',altGlyph='alternate-glyph',altGlyphDef='alternate-glyph',altGlyphItem='alternate-glyph',glyphRef='alternate-glyph',tref='text-reference',['color-profile']='color-profile',cursor='svg-cursor-resource',flowRoot='draft-flow-text',flowRegion='draft-flow-text',flowPara='draft-flow-text',meshgradient='draft-mesh-gradient',meshrow='draft-mesh-gradient',meshpatch='draft-mesh-gradient',hatch='draft-hatch',hatchpath='draft-hatch',discard='svg-tiny-discard',handler='svg-tiny-handler',listener='svg-tiny-listener',prefetch='svg-tiny-prefetch',multiImage='svg-tiny-multi-image',subImage='svg-tiny-multi-image'}
function Conditional.matches(a: any,options: any): boolean
 for _,key in {'requiredFeatures','requiredExtensions'} do
  if a[key] then
   if not a[key]:match('%S') then return false end
   local supported=if key=='requiredFeatures' then options.Features or {} else options.Extensions or {}
   for feature in a[key]:gmatch('%S+') do if not supported[feature] then return false end end
  end
 end
 if a.systemLanguage then
  local languages=options.Languages or {'en'};local found=false
  for wanted in a.systemLanguage:gmatch('[^,]+') do
   wanted=wanted:match('^%s*(.-)%s*$'):lower()
   for _,lang in languages do lang=lang:lower();if wanted~='' and (lang==wanted or lang:sub(1,#wanted+1)==wanted..'-') then found=true;break end end
  end
  if not found then return false end
 end
 return true
end
function Conditional.view(document: any,fragment: string?,report: any): any?
 if not fragment or fragment=='' then return nil end
 fragment=fragment:gsub('^#',''):gsub('%%(%x%x)',function(h)return string.char(tonumber(h,16))end)
 local target=document.Ids[fragment]
 if target then
  if target.Name~='view' then report('svg-fragment-target-not-view',fragment);return nil end
  if target.Attributes.viewTarget then report('svg-view-target-highlight-unimplemented',target.Attributes.viewTarget) end
  return {viewBox=target.Attributes.viewBox,preserveAspectRatio=target.Attributes.preserveAspectRatio}
 end
 local body=fragment:match('^svgView%((.*)%)$')
 if body then
  local result={}
  for item in body:gmatch('[^;]+') do local key,value=item:match('^%s*([%w]+)%((.*)%)%s*$')
   if key=='viewBox' or key=='preserveAspectRatio' then result[key]=value:gsub(',',' ') else report('svg-view-fragment-unimplemented',item) end
  end
  return result
 end
 report('svg-fragment-unavailable',fragment);return nil
end
return Conditional
