--!strict
return function(Flow: any, Style: any, Media: any, Letters: any)
 local fixtureElement=require('DOM/Node').element
	local strut={Ascent=9,Descent=3}
	for _,n in {128,512,1024} do
		for _,floats in {false,true} do
			local reads,writes,neededCalls=0,0,0
			local items={}
			for index=1,n do
				local px=0
				items[index]=setmetatable({Kind="Word",Text="a",WrapBefore=false,SpaceBefore=index>1,SpaceWidth=1,Ascent=9,Descent=3,Baseline=9}, {
					__index=function(_,key) if key=="Width" then reads+=1;return 1 elseif key=="X" then return px end;return nil end,
					__newindex=function(t,key,value) if key=="X" then writes+=1;px=value else rawset(t,key,value)end end,
				})
			end
			local bounds=if floats then function(y,_height,needed)
				if needed then neededCalls+=1;assert(needed==2*n-1) end
				return 5,15,y
			end else nil
			local height,extent=Flow.arrange(items,10,strut,nil,nil,nil,nil,bounds)
			local offset=if floats then 5 else 0
			assert(height==12 and extent==2*n-1+offset)
			for index,item in items do assert(item.X==2*(index-1)+offset and item.Y==0) end
			assert(reads<=4*n and writes<=3*n,"Retained nowrap flow must perform linear work, including unchanged bounds")
			assert(neededCalls==(if floats then 1 else 0),"Only an empty float-constrained line requests group width")
		end
	end
	local varying={
		{Kind="Word",Text="A",Width=5,Ascent=9,Descent=3,Baseline=9},
		{Kind="Word",Text="B",Width=5,Ascent=15,Descent=3,Baseline=15},
	}
	Flow.arrange(varying,100,strut,nil,nil,nil,nil,function(y,height)
		return if height>12 then 10 else 5,100,y
	end)
	assert(varying[1].X==10 and varying[2].X==15,"A genuine float-bound change must still shift the existing line")
	local workCalls=0
	local stopped=Flow.arrange(varying,100,strut,nil,nil,nil,nil,nil,function()workCalls+=1;return false end)
	assert(stopped==0 and workCalls==1,"Flow cancellation remains immediate")
	for _,prefix in {"all", "only all", "screen", "only screen"} do
		local query=Media.compile(prefix.." and (min-width:10px) and (max-width:90px)")
		assert(query and Media.matches(query,{Width=50}) and not Media.matches(query,{Width=100}),prefix)
	end
	local negated=Media.compile("not all and (min-width:10px)")
	assert(negated and not Media.matches(negated,{Width=20}) and Media.matches(negated,{Width=5}))
	assert(Media.matches(Media.compile("all"),{}) and Media.matches(Media.compile("(min-width:10px)"),{Width=20}))
	assert(not Media.matches(Media.compile("all (min-width:10px)"),{Width=20}),"Explicit media types require and")
	local function style(css: string): any
		return Style.resolve(fixtureElement("div",{style=css}), {FontSize=16,Color=Color3.new(0,0,0)},error)
	end
	local circle=style("clip-path:circle(40% at 50% 50%)").ClipPath
	local centered=style("clip-path:circle(40% at center)").ClipPath
	assert(circle.Kind==centered.Kind and circle.Radius.Value==centered.Radius.Value and circle.Radius.Percent==centered.Radius.Percent)
	local ellipse=style("clip-path:ellipse(40% 30% at 50% 50%)").ClipPath
	assert(ellipse.Kind=="ellipse" and ellipse.X.Value==40 and ellipse.Y.Value==30)
	for _,value in {"right 10px","center 10px","left 10px"} do
		local p=style("background-position:"..value).BackgroundPositions[1]
		assert(p.X.Anchor==(if value:sub(1,5)=="right" then 1 elseif value:sub(1,6)=="center" then .5 else 0) and not p.X.Offset)
		assert(p.Y.Anchor==0 and p.Y.Offset.Value==10 and not p.Y.Offset.Percent)
	end
	local reversed=style("background-position:top right").BackgroundPositions[1]
	assert(reversed.X.Anchor==1 and reversed.Y.Anchor==0)
	local numeric=style("background-position:20% 30px").BackgroundPositions[1]
	assert(numeric.X.Offset.Value==20 and numeric.X.Offset.Percent and numeric.Y.Offset.Value==30)
	local edge=style("background-position:right 10px bottom 20%").BackgroundPositions[1]
	assert(edge.X.Anchor==1 and edge.X.Offset.Value==10 and edge.Y.Anchor==1 and edge.Y.Offset.Percent)
	local axis=style("background-position-x:right 10px").BackgroundPositions[1]
	assert(axis.X.Anchor==1 and axis.X.Offset.Value==10,"Explicit axis properties keep their edge-offset grammar")
	local mask=style("mask-position:right 10px").MaskPositions[1]
	assert(mask.X.Anchor==1 and mask.Y.Offset.Value==10)
	local radial=style("background-image:radial-gradient(circle at right 10px, red, blue)").BackgroundImages[1]
	assert(radial.Position.X.Anchor==1 and radial.Position.Y.Offset.Value==10)
	local warnings=0
	Style.resolve(fixtureElement("div",{style="background-position:top 10px"}), {FontSize=16},function()warnings+=1 end)
	assert(warnings==1,"A keyword/numeric pair cannot reverse the x/y order")
	local face={Family="independent-tabular-audit",Weight="Regular",Style="Normal"}
	for _,width in {4,7} do
		local calls=0
		local item={Style={TabularNums=true},Glyphs=Letters.split("109")}
		assert(Letters.measure(item,face,57,function()calls+=1;return {X=width,Y=57}end,function()return true end))
		Letters.arrange(item,0,0)
		assert(calls==10 and item.Width==3*width,"Independent items cannot reuse another item's native digit measurements")
	end
	local item={Style={TabularNums=true},Glyphs=Letters.split("10")}
	local alive,calls=true,0
	assert(not Letters.measure(item,face,57,function()calls+=1;alive=false;return {X=7,Y=57}end,function()return alive end))
	assert(calls==1 and item.Glyphs[1].Width==nil,"Cancelled tabular measurement must not publish partial bounds")
	print("CSS/layout audit: linear nowrap, changing float bounds, media all, clip centers, background coordinates and independent tabular measurements passed")
end
