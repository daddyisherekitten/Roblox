--!strict
return function(Text,Document,Parser,Viewport,Viewports,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Gradient,Resources,Sources)
 local context={Width=480,Height=320,FontSize=16,RootFontSize=16}
 local function layout(body)
  local doc=Document.prepare(Parser.parse('<svg xmlns="http://www.w3.org/2000/svg">'..body..'</svg>'))
  local root,info=Text.expand(doc.Root.Children[1],context)
  return info,root,doc
 end
 local info,root,doc=layout('<text x="20" y="60" font-size="30">A<tspan>B</tspan>C</text>')
 assert(#info.Glyphs==3 and #info.Chunks==1 and info.Glyphs[1].X==20 and info.Glyphs[3].X>info.Glyphs[2].X,'tspan continues pen')
 assert(doc.Root.Children[1].Name=='text' and doc.Root.Children[1].Children[1].Text=='A','source text preserved')
 info=layout('<text font-family="Missing, &quot;Source Sans Pro&quot;, sans-serif" font-weight="700" font-style="italic">A</text>')
 assert(#info.Diagnostics==0 and info.Glyphs[1].Owner.Font==Text.Font.Faces.BoldIt,'font fallback list and real bold italic face')
 info=layout('<text x="10 50 90" y="70" font-size="20">A<tspan dx="2">BC</tspan>D</text>')
 assert(info.Glyphs[1].X==10 and info.Glyphs[2].X==52 and info.Glyphs[3].X==90,'ancestor lists address descendants')
 info=layout('<text>  A  <tspan> B </tspan> C  </text>');assert(#info.Glyphs==5,'whitespace collapses across spans')
 info=layout('<text xml:space="preserve"> A  B </text>');assert(#info.Glyphs==6,'xml space preserve')
 info=layout('<text x="240" text-anchor="middle" font-size="30">ABC</text>')
 assert(math.abs(info.Glyphs[1].X-(240-info.Chunks[1].Advance/2))<1e-6,'anchor uses advance')
 info=layout('<text x="20" font-size="30" textLength="200" lengthAdjust="spacingAndGlyphs">ABC</text>')
 assert(math.abs(info.Glyphs[3].X+info.Glyphs[3].Advance-20-200)<1e-6 and info.Glyphs[1].Stretch>1,'textLength scales glyph outlines')
 info=layout('<text x="20" font-size="30" textLength="200">ABC</text>')
 assert(math.abs(info.Glyphs[3].X+info.Glyphs[3].Advance-220)<1e-6 and info.Glyphs[1].Stretch==1,'spacing preserves glyph widths')
 info=layout('<text rotate="-15 20">ABC</text>');assert(info.Glyphs[3].Rotation==20,'rotate repeats last value')
 info=layout('<text>fft</text>');assert(#info.Glyphs==1 and info.Glyphs[1].Consumed==3 and info.Glyphs[1].Id==518,'font standard ligature')
 info=layout('<text style="font-variant-ligatures:none">fft</text>');assert(#info.Glyphs==3,'ligatures can be disabled')
 info=layout('<text rotate="0 5 10">fft</text>');assert(#info.Glyphs==3,'per-character rotation splits ligatures')
 local composed=layout('<text>Ä</text>');local decomposed=layout('<text>A&#x308;</text>')
 assert(#decomposed.Glyphs==1 and decomposed.Glyphs[1].Id==composed.Glyphs[1].Id,'canonical Latin composition')
 local nested={}
 for index=1,64 do table.insert(nested,'<tspan id="outer-'..index..'"><tspan id="inner-'..index..'">AB</tspan></tspan>')end
 info,root=layout('<text>'..table.concat(nested)..'</text>')
 assert(#info.Glyphs==128 and #root.Children==64,'Wide nested tspan text preserves every emitted group and glyph')
 for index,outer in root.Children do
  assert(outer.Attributes.id=='outer-'..index and #outer.Children==1 and outer.Children[1].Attributes.id=='inner-'..index
   and #outer.Children[1].Children==2 and outer.Children[1].Children[1].Name=='path','Indexed text ancestors retain source group order and hierarchy')
 end
 local kerned=layout('<text font-size="100">AV</text>');local plain=layout('<text font-size="100" style="font-kerning:none">AV</text>')
 assert(kerned.Chunks[1].Advance<plain.Chunks[1].Advance,'font GPOS kerning')
 -- Independent HarfBuzz 0.56.1 result for the exact TTF: AV advances 530 + 515 / 1000 em.
 assert(math.abs(kerned.Chunks[1].Advance-104.5)<1e-6,'HarfBuzz AV metric oracle')
 info=layout('<text x="200" direction="rtl" unicode-bidi="bidi-override">ABC</text>')
 assert(info.Glyphs[1].X>info.Glyphs[3].X and info.Glyphs[1].X<200,'explicit RTL override')
 info=layout('<text x="20" y="30" writing-mode="vertical-rl">ABC</text>')
 assert(info.Glyphs[1].X==info.Glyphs[3].X and info.Glyphs[3].Y>30,'vertical inline advance')
 info=layout('<text font-size="32" writing-mode="vertical-rl" text-orientation="upright">ABC</text>')
 assert(info.Glyphs[1].Owner.Node.Attributes['text-orientation']=='mixed','text-orientation is not a presentation attribute')
 info=layout('<text font-size="32" writing-mode="vertical-rl" style="text-orientation:upright">ABC</text>')
 assert(info.Glyphs[1].Owner.Node.Attributes['text-orientation']=='upright' and info.Glyphs[2].Y-info.Glyphs[1].Y==32,'CSS upright uses upright glyph advance')
 info=layout('<text x="bad" font-family="Unavailable" font-weight="bold">&#x633;</text>')
 local codes={};for _,p in info.Diagnostics do codes[p.Code]=true end
 assert(codes['invalid-text-position-list'] and codes['svg-font-fallback'] and codes['svg-missing-glyph'] and codes['text-complex-shaping-required'],'explicit unsupported diagnostics')
 local function render(body)
  local data=Viewports(Parser,Viewport,{Cases={{Name='text-test',SVG='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 480 320">'..body..'</svg>'}}},Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources,Text)
  return Raster.render(data.Scenes[1],nil,480),data
 end
 local pixels,data=render('<text x="20" y="80" font-size="60" fill="red" opacity=".5">H</text>')
 assert(#data.Diagnostics==0 and #data.Scenes[1].Shapes==1)
 local count,maxAlpha=0,0
 for at=3,buffer.len(pixels)-1,4 do local a=buffer.readu8(pixels,at);if a>0 then count+=1;maxAlpha=math.max(maxAlpha,a);assert(buffer.readu8(pixels,at-3)==255) end end
 assert(count>200 and maxAlpha==128,'outline pixels with group opacity')
 pixels,data=render('<defs><text id="label">Hi</text></defs><use href="#label" x="30" y="60" font-size="30"/>')
 assert(#data.Scenes[1].Shapes==2,'use supports text')
 local scenes=Viewports(Parser,Viewport,Sources,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources,Text)
 assert(#scenes.Scenes==8)
 for _,problem in scenes.Diagnostics do print('TEXT_DIAGNOSTIC',problem.Case,problem.Code,problem.Value) end
 assert(#scenes.Diagnostics==0,'fixtures must be clean')
 for _,scene in scenes.Scenes do assert(#scene.Shapes>0);local bytes=Raster.render(scene,nil,240);assert(bytes and buffer.len(bytes)==240*160*4) end
 print('SVG text: outlines, positions, spans, whitespace, anchors, textLength, rotation, kerning, ligatures, diagnostics and raster passed')
 return scenes
end
