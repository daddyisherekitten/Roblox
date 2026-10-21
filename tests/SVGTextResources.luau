--!strict
return function(Text,Document,Parser,Viewport,Viewports,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Gradient,Resources,Sources)
 local ctx={Width=480,Height=320,FontSize=16,RootFontSize=16}
 local function layout(defs,body)
  local doc=Document.prepare(Parser.parse('<svg xmlns="http://www.w3.org/2000/svg">'..defs..body..'</svg>'))
  local context=table.clone(ctx);context.Document=doc
  local root=doc.Root.Children[#doc.Root.Children]
  local tree,info=Text.expand(root,context)
  return info,tree,doc
 end
 local defs='<defs><path id="p" d="M20 80 H420"/></defs>'
 local info=layout(defs,'<text font-size="30"><textPath href="#p" startOffset="25%">ABC</textPath></text>')
 assert(#info.Glyphs==3 and #info.Diagnostics==0,'textPath characters preserved')
 local path=info.Glyphs[1].Path;assert(path and path.Length==400 and path.Offset==100)
 local p=Text.Paths.place(path,info.Glyphs[1]);assert(math.abs(p.X-120)<1e-6 and p.Y==80 and p.Angle==0,'straight path offset and baseline')
 local x,y,dx,dy=Text.Paths.point(path,200);assert(x==220 and y==80 and dx==1 and dy==0)
 assert(Text.Paths.point(path,-1)==nil and Text.Paths.point(path,401)==nil,'open path outside midpoint hidden')
 info=layout(defs,'<text font-size="30" text-anchor="middle"><textPath href="#p" startOffset="50%">ABC</textPath></text>')
 p=Text.Paths.place(info.Glyphs[1].Path,info.Glyphs[1]);assert(math.abs(p.X-(220-info.Chunks[1].Advance/2))<1e-6,'path text-anchor')
 info=layout('<defs><path id="p" d="M0 0 V100" transform="translate(40 30)"/></defs>','<text><textPath href="#p">A</textPath></text>')
 p=Text.Paths.place(info.Glyphs[1].Path,info.Glyphs[1]);assert(math.abs(p.X-40)<1e-6 and math.abs(p.Y-30)<1e-6 and math.abs(p.Angle-math.pi/2)<1e-6,'path transform and tangent')
 info=layout('<defs><path id="p" d="M0 0 H100 M300 0 H400"/></defs>','<text><textPath href="#p">A</textPath></text>')
 x,y=Text.Paths.point(info.Glyphs[1].Path,150);assert(x==350 and y==0,'moveto gap not counted')
 info=layout('<defs><path id="p" d="M0 0 H100 V100 H0 Z"/></defs>','<text><textPath href="#p">A</textPath></text>')
 x,y=Text.Paths.point(info.Glyphs[1].Path,450);assert(x==50 and y==0,'closed path wraps')
 info=layout(defs,'<text><textPath href="#p" side="right">A</textPath></text>')
 p=Text.Paths.place(info.Glyphs[1].Path,info.Glyphs[1]);assert(math.abs(p.X-420)<1e-6 and math.abs(math.abs(p.Angle)-math.pi)<1e-6,'reverse side')
 info=layout('', '<text><textPath href="#missing">A</textPath></text>')
 assert(#info.Diagnostics>0 and info.Glyphs[1].Path==false,'missing path suppressed with diagnosis')
 info=layout('', '<text x="20" y="70" font-size="26" style="white-space:pre;line-height:40px">A\nB\nC</text>')
 assert(#info.Glyphs==3 and info.Glyphs[2].X==20 and info.Glyphs[2].Y==110 and info.Glyphs[3].Y==150,'preserved newline and line-height')
 local function render(body)
  local data=Viewports(Parser,Viewport,{Cases={{Name='resource-test',SVG='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 480 320">'..body..'</svg>'}}},Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources,Text)
  return Raster.render(data.Scenes[1],nil,240),data
 end
 local direct='<text x="20" y="80" font-size="64" fill="red">BO</text>'
 local original=render(direct)
 local clipped,data=render('<defs><clipPath id="c"><text x="20" y="80" font-size="64" fill="none" stroke="blue" stroke-width="20" opacity=".2">BO</text></clipPath></defs><rect width="200" height="120" fill="red" clip-path="url(#c)"/>')
 local function sameVisible(a,b)
  for at=0,buffer.len(a)-4,4 do
   local alpha=buffer.readu8(a,at+3)
   if alpha~=buffer.readu8(b,at+3) then return false end
   -- RGB under exactly zero alpha has no visual meaning; clip clears those bytes.
   if alpha>0 then for c=0,2 do if buffer.readu8(a,at+c)~=buffer.readu8(b,at+c) then return false end end end
  end
  return true
 end
 assert(#data.Diagnostics==0 and sameVisible(original,clipped),'clip uses glyph silhouette, ignores fill/stroke/opacity and preserves counters')
 local masked=render('<defs><mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" width="200" height="120"><text x="20" y="80" font-size="64" fill="white">BO</text></mask></defs><rect width="200" height="120" fill="red" mask="url(#m)"/>')
 assert(sameVisible(original,masked),'white glyph mask matches direct text')
 local sceneData=Viewports(Parser,Viewport,Sources,Raster,Length,Geometry,Paint,Transform,Bounds,Rendering,Document,Gradient,Resources,Text)
 for _,problem in sceneData.Diagnostics do print('TEXT_RESOURCE_DIAGNOSTIC',problem.Case,problem.Code,problem.Value) end
 assert(#sceneData.Diagnostics==0 and #sceneData.Scenes==8,'eight clean shared native fixtures')
 for _,scene in sceneData.Scenes do
  local bytes=Raster.render(scene,nil,240);assert(bytes and buffer.len(bytes)==240*160*4)
  local painted=false;for at=3,buffer.len(bytes)-1,4 do if buffer.readu8(bytes,at)>0 then painted=true;break end end
  assert(painted,scene.Name)
 end
 print('SVG S27/S28: path lookup, transforms, offsets, anchors, gaps, closed/reversed paths, newlines, glyph clips/masks and eight resource fixtures passed')
 return sceneData
end
