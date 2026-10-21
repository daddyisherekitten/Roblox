--!strict
return function(Parser, Style, Sizing, loadRenderTree, loadWordLayout, loadBlockLayout, fixture)
 local fixtureElement=require('DOM/Node').element
	local function near(a,b) assert(math.abs(a-b)<0.00001,tostring(a).." ~= "..tostring(b)) end
	for _,vb in {"0 0 4 2","-10,-20,4,2","0 0 4e1 2e1"} do near(Sizing.viewBoxRatio(vb),2) end
	for _,vb in {"0 0 0 4","0 0 -4 2","0 0 4","0 0 4 2 junk","0,,0,4,2","0 0 4 2,","0 0 1e999 2"} do assert(Sizing.viewBoxRatio(vb)==nil,vb) end
	local dom=Parser.parse('<div>A<svg viewBox="0 0 4 2"><title>Invisible</title><defs><rect /></defs><g /><svg /></svg>B</div>')
	local root=dom.Children[1];local svg=root.Children[2]
	assert(svg.NamespaceURI=="http://www.w3.org/2000/svg" and svg.Attributes.viewBox=="0 0 4 2")
	assert(#svg.Children==4 and root.Children[3].Text=="B" and #dom.Diagnostics==0)
	local empty=Parser.parse('<svg width="20" height="10" /><div>After</div>')
	assert(#empty.Children==2 and empty.Children[2].Name=="div")
	local allocated=0
	local renderer=loadRenderTree({create=function(class,_,props)
		assert(class~="TextButton" and class~="ImageButton")
		allocated+=1;return table.clone(props)
	end})
	local words=loadWordLayout({['Layout/FontProfiles']={face=function(font) return font end},
		['Layout/TextMeasure']={measure=function(_,_,size) return {X=20,Y=size} end}})
	local blocks=loadBlockLayout({['Layout/WordLayout']=words,['Layout/TextMeasure']={measure=function(_,_,size) return {X=20,Y=size} end}})
	local function build(html)
		return renderer.build(Parser.parse(html),{},error)
	end
	local function arrange(tree,width) blocks.arrange(tree,width or 400,0,0,function() return true end) end
	local function check(attrs,css,w,h)
		local tree=build('<svg '..attrs..' style="display:block;'..css..'"><title>Never HTML text</title><rect /></svg><div>After</div>')
		arrange(tree)
		local box=tree.Children[1];local item=box.ImageItem
		assert(item.SVG and #box.Children==0 and #tree.ImageItems==0)
		assert(item.ImageGui and not item.Source and not item.FallbackGui,'Local SVG image surface without remote loading or broken-image placeholder')
		near(item.ContentWidth,w);near(item.ContentHeight,h)
		near(tree.Children[2].LayoutY,box.OuterHeight)
		return tree,item
	end
	check('width="120" height="60"','',120,60)
	check('width="120px" height="60px"','width:180px',180,60)
	check('width="120" height="60" viewBox="0 0 2 1"','height:auto',120,60)
	check('width="120" height="60"','height:auto',120,150)
	check('','',300,150)
	check('viewBox="0 0 4 1"','',400,100)
	check('viewBox="0 0 4 1"','height:50px',200,50)
	check('viewBox="0 0 4 1"','width:50%',200,50)
	check('width="50%" viewBox="0 0 4 1"','',200,50)
	check('width="120" viewBox="0 0 4 1"','max-width:80px',80,20)
	check('viewBox="0 0 4 1"','width:120px;aspect-ratio:2',120,60)
	check('width="0" height="0"','',0,0)
	check('width="120" height="60"','box-sizing:border-box;padding:5px;border:1px solid black',108,48)
	local styled=build('<style>svg{width:80px;height:40px}</style><svg width="120" height="60" />')
	arrange(styled);near(styled.Children[1].Items[1].ContentWidth,80)
	local inline=build('<div style="font-family:Arial;font-size:20px;line-height:24px">A <svg width="80" height="40" style="background-color:red"><title>Hidden</title></svg> B</div><div>After</div>')
	arrange(inline)
	local items=inline.Children[1].Children[1].Items
	assert(#items==3 and items[2].SVG,'SVG is one inline replaced item, no title words')
	near(items[2].BoxWidth,80);near(items[2].BoxHeight,40)
	assert(items[3].X>items[2].X and items[3].LineBaseline==items[2].LineBaseline)
	local count=allocated
	arrange(inline,90)
	assert(allocated==count and items[3].Y>items[2].Y,'Narrow container wraps following text without duplicate GUIs')
	local tree,item=check('viewBox="0 0 4 1"','width:50%',200,50)
	count=allocated
	for _,w in {240,960,480,240} do arrange(tree,w);near(item.ContentWidth,w/2);near(item.ContentHeight,w/8) end
	assert(allocated==count,'Resize reuses SVG box and neighboring text GUIs')
	local percent=build('<div style="width:200px;height:100px"><svg width="50%" height="50%" style="display:block" /></div>')
	arrange(percent)
	local pi=percent.Children[1].Children[1].ImageItem
	near(pi.ContentWidth,100);near(pi.ContentHeight,50)
	local function collect(box,out)
		if box.ImageItem and box.ImageItem.SVG then out[box.ImageItem.SVG.Attributes.id]=box.ImageItem end
		for _,item in box.Items or {} do if item.SVG then out[item.SVG.Attributes.id]=item end end
		for _,child in box.Children or {} do collect(child,out) end
	end
	local actual=build(fixture)
	local svgItems={};collect(actual,svgItems)
	local total=0;for _ in svgItems do total+=1 end;assert(total==9)
	arrange(actual,480);local initial=allocated
	for _,width in {240,480,960,480} do
		arrange(actual,width)
		near(svgItems.inline.ContentWidth,120);near(svgItems.inline.ContentHeight,48)
		near(svgItems.block.ContentWidth,180);near(svgItems.block.ContentHeight,60)
		near(svgItems.relative.ContentWidth,(width-26)/2)
		near(svgItems.relative.ContentHeight,(width-26)/8)
		near(svgItems.intrinsic.ContentWidth,180);near(svgItems.intrinsic.ContentHeight,60)
		near(svgItems['css-wins'].ContentWidth,160);near(svgItems['css-wins'].ContentHeight,40)
		near(svgItems['percent-height'].ContentHeight,50)
		near(svgItems['default-size'].ContentWidth,300);near(svgItems['default-size'].ContentHeight,150)
		near(svgItems.limited.ContentWidth,200);near(svgItems.limited.ContentHeight,50)
		near(svgItems.zero.ContentWidth,0);near(svgItems.zero.ContentHeight,0)
	end
	assert(allocated==initial,'Actual visual fixture resize reuses every GUI')
	local middle=Style.resolve(fixtureElement("svg",{style="vertical-align:middle"}), {Font="Arial",FontSize=16,Color=Color3.new(0,0,0)}, error,true)
	assert(middle.VerticalAlign=="middle")
	print('SVG embedding: foreign subtree, presentation/CSS sizing, intrinsic ratio, percentage axes, inline baseline/wrap, block flow and resize reuse passed')
end
