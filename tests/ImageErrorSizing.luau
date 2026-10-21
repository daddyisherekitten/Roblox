--!strict
-- Real retained layout, with native reference font bounds isolated from calibration.
return function(Parser,loadRenderTree,loadWordLayout,loadBlockLayout,cases,expected)
	local factory={};function factory.create(class,parent,props)
		local gui=table.clone(props);gui.ClassName,gui.Parent=class,parent
		function gui:Destroy()self.Destroyed=true;self.Parent=nil end
		return gui
	end;factory.modifier=factory.create
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},
		['Layout/TextMeasure']={measure=function(text,_,size)return Vector2.new(if text=='Missing'then 54.234375 else #text*8,size)end}}
	local words=loadWordLayout(overrides);overrides['Layout/WordLayout']=words
	local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	for index,case in cases do
		local alt=if case.alt~=nil then ' alt="'..case.alt..'"'else ''
		local document=Parser.parseDocument('<!doctype html><body style="margin:0;font:16px/20px Arial"><div style="width:400px"><img id="target" src="missing.png" '..case.attributes..alt..' style="'..case.style..'"></div></body>')
		local tree=renderer.build(document,{AbsoluteSize=Vector2.new(400,800)},function()end,function(font)return font end)
		local item=tree:FindImageItem(require('DOM/Node').findById(document,'target'));local retained=item.Gui
		layout.arrange(tree,400,0,0,function()return true end)
		local reference=expected[index];assert(reference.name==case.name)
		assert(math.abs(item.BoxWidth-reference.width)<.02 and math.abs(item.BoxHeight-reference.height)<.02,
			case.name..': '..item.BoxWidth..'x'..item.BoxHeight..' expected '..reference.width..'x'..reference.height)
		assert(if case.alt==''then not item.ErrorGui else item.ErrorGui.Visible,'Broken icon follows explicit empty alt')
		layout.arrange(tree,400,0,0,function()return true end);assert(item.Gui==retained,'Reflow retains the failed image surface')
	end
	print('Image errors: 18 native Chromium sizing cases, empty/absent alt, icon visibility and retained reflow passed')
end
