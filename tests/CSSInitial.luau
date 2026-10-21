--!strict
return function(Style,Properties,Parser,loadRenderTree)
 local fixtureElement=require('DOM/Node').element
 local function resolve(css,parent,warn)
  return Style.resolve(fixtureElement('div',{style=css}),parent or {},warn or error)
 end
 local failures={}
 for name in Properties do
  local ok,message=pcall(resolve,name..':initial')
  if not ok then table.insert(failures,name..': '..tostring(message)) end
  ok,message=pcall(resolve,name..':INITIAL')
  if not ok then table.insert(failures,name..':INITIAL: '..tostring(message)) end
 end
 table.sort(failures)
 assert(#failures==0,table.concat(failures,'\n'))
 local parent=resolve('color:blue;font-size:28px;direction:rtl;--space:11px;margin:20px;padding:7px')
 local dirty='font:italic 600 24px/2 Arial;color:red;background:red;border:4px solid blue;border-radius:9px;display:flex;position:relative;left:12px;margin:8px;padding:4px;gap:12px;columns:2;opacity:.5'
 local reset=resolve(dirty..';all:initial',parent)
 assert(reset.FontSize==16 and reset.FontWeight==400 and reset.FontStyle=='normal' and reset.LineHeight.Kind=='normal')
 assert(reset.Color==Color3.new(0,0,0) and reset.Background==nil and reset.BorderStyle=='none' and reset.BorderRadius==0)
 assert(reset.Display=='inline' and reset.Position=='static' and reset.Insetleft==nil and reset.ColumnCount==nil)
 assert(reset.Margin[1]==0 and reset.Padding[1]==0 and reset.Gap[1]==0 and reset.Opacity==1)
 assert(reset.Direction=='rtl' and reset.Custom['--space']=='11px','all excludes direction and custom properties')
 assert(resolve('all:initial;margin-left:var(--space)',parent).Margin[4]==11)
 assert(resolve('all:initial;color:red',parent).Color==Color3.fromRGB(255,0,0))
 assert(resolve('color:red!important;all:initial',parent).Color==Color3.fromRGB(255,0,0))
 assert(resolve('all:initial!important;color:red',parent).Color==Color3.new(0,0,0))
 assert(resolve('--reset:INITIAL;'..dirty..';all:var(--reset,initial)',parent).FontSize==16)
 assert(resolve('--space:INITIAL;margin-left:var(--space,3px)',parent).Margin[4]==3)
 local unset=resolve(dirty..';all:unset',parent)
 assert(unset.FontSize==28 and unset.Color==Color3.fromRGB(0,0,255) and unset.Margin[1]==0 and unset.Padding[1]==0)
 local inherit=resolve('all:inherit',parent)
 assert(inherit.FontSize==28 and inherit.Margin[1]==20 and inherit.Padding[1]==7)
 local variants='font-variant-caps:small-caps;font-variant-position:super;font-variant-numeric:tabular-nums;font-variant-ligatures:none;font-feature-settings:"kern" 0;font-kerning:none;font-size-adjust:.7;'
 local fontReset=resolve(variants..'font:INITIAL',parent)
 assert(not fontReset.FontVariantCaps.Smcp and not fontReset.FontVariantPosition.Sups and not fontReset.TabularNums)
 assert(fontReset.FontVariantLigatures.Liga and #fontReset.FontFeatureSettings==0 and fontReset.FontKerning and fontReset.FontSizeAdjust.Kind=='none')
 local variantReset=resolve(variants..'font-variant:INITIAL',parent)
 assert(not variantReset.FontVariantCaps.Smcp and not variantReset.FontVariantPosition.Sups and not variantReset.TabularNums)
 local corner=resolve('border-radius:9px;border-top-left-radius:initial')
 assert(corner.BorderRadii[1].X.Value==0 and corner.BorderRadii[2].X.Value==9 and corner.BorderRadii[3].X.Value==9)
 local rtlCorner=resolve('direction:rtl;border-radius:9px;border-start-start-radius:initial')
 assert(rtlCorner.BorderRadii[2].X.Value==0 and rtlCorner.BorderRadii[1].X.Value==9)
 local inline=Style.resolve(fixtureElement('span',{style='all:initial'}),parent,error,true)
 assert(inline.FontSize==16 and inline.Display=='inline','Global initial reset is safe on inline text')
	local Node=require('DOM/Node')
	local legacy=Parser.parse('<input style="display:inline-block;width:31px;height:17px">')
	for _,name in {'input','span','kbd','a','output','img'}do
		local fragment=if name=='input'then legacy else Parser.parse('<'..name..'>Text</'..name..'>')
		local expected=if name=='input'then'inline-block'else'inline'
		for _,document in {fragment,Node.cloneNode(fragment,true)}do
			local first=document.Children[1]
			assert(Style.resolve(first,{},error).Display==expected,'A legacy fragment host and its clone must not blockify the first '..name)
		end
		local actual=Node.document();local element=fixtureElement(name,table.clone(fragment.Children[1].Attributes));Node.append(actual,element)
		assert(Style.resolve(element,{},error).Display=='block','An actual constructed document root still blockifies '..name..' with the same declarations')
	end
	local foreign=Node.document();local foreignRoot=fixtureElement('f:root',{style='display:inline-grid'});foreignRoot.NamespaceURI='urn:root';foreignRoot.LocalName='root';Node.append(foreign,foreignRoot)
	assert(Style.resolve(foreignRoot,{},error).Display=='grid','Actual-root blockification is independent of HTML tag names and namespace')
	local full=Parser.parseDocument('<!doctype html><html style="display:inline"><body>Root</body></html>')
	assert(Style.resolve(full.DocumentElement,{},error,true).Display=='block','A full parsed document root blockifies even for an inline caller')
	Node.removeChild(legacy,legacy.Children[1])
	local session=Parser.newDocument('<!doctype html><html style="display:inline"><body>Replaced</body></html>',{_Document=legacy})
	while session:Advance()do end
	assert(not legacy.LegacyFragment and Style.resolve(legacy.DocumentElement,{},error).Display=='block','document.open-style full parsing restores actual-root semantics on the retained host')
	session:Destroy()
 local renderer=loadRenderTree({create=function(_,_,props)return table.clone(props)end})
 local tree=renderer.build(Parser.parse('<style>#reset{color:red;font-size:24px;margin:8px}#reset:hover{all:initial;display:block}</style><p id="reset">Text</p>'),{},error)
 local box=tree.Children[1]
 assert(box.Style.FontSize==24 and box.Style.Margin[1]==8)
 tree:SetCSSState('hover',box.Node)
 assert(box.Style.FontSize==16 and box.Style.Margin[1]==0 and box.Style.Color==Color3.new(0,0,0))
 tree:SetCSSState('hover',nil)
 assert(box.Style.FontSize==24 and box.Style.Margin[1]==8,'Leaving hover restores the original cascade')
 local warnings={}
 resolve('missing-property:initial;another-missing-property:initial',nil,function(message)table.insert(warnings,message)end)
 assert(#warnings==2,'initial does not pretend unknown properties have an implementation')
 print('CSS initial: all catalog entries, case-insensitive keywords, global reset, shorthand components, variables, inheritance, important, corners and hover recascade passed')
end
