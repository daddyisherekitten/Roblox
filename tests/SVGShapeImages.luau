--!strict
return function(Embedded,Parser,Raster,ShapeImage,loadShapeImages)
 local markup='<svg xmlns="http://www.w3.org/2000/svg" width="80" height="40" viewBox="0 0 8 4"><rect x="1" y="0" width="1" height="1" opacity=".5019607843"/><rect x="4" y="1" width="1" height="1"/><rect x="5" y="2" width="1" height="1"/><rect x="1" y="3" width="1" height="1"/></svg>'
 local node=Parser.parse(markup).Children[1]
 local scene,errors=Embedded.build(Embedded.document(node),80,40)
 assert(#errors==0)
 local rgba,h=Raster.render(scene,nil,80);assert(h==40)
 local alpha=ShapeImage.alpha(rgba,80,h)
 local rows=ShapeImage.rows(alpha,80,h,.5)
 assert(rows.Rows[1][1]==10 and rows.Rows[1][2]==20)
 assert(rows.Rows[11][1]==40 and rows.Rows[11][2]==50)
 assert(rows.Rows[21][1]==50 and rows.Rows[21][2]==60)
 assert(rows.Rows[31][1]==10 and rows.Rows[31][2]==20)
 local strict=ShapeImage.rows(alpha,80,h,128/255);assert(strict.Rows[1]==false)
 local translucent=Parser.parse('<svg width="8" height="4" style="opacity:.4"><rect width="8" height="4"/></svg>').Children[1]
 local transparentScene=Embedded.build(Embedded.document(translucent,true),8,4)
 local transparentPixels=Raster.render(transparentScene,nil,8)
 assert(buffer.readu8(transparentPixels,3)==102,'External SVG root opacity belongs to the image alpha')
 for _,mode in {'alpha','luminance'} do
  local source=Parser.parse('<svg width="8" height="4"><defs><mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" width="8" height="4" style="mask-type:'..mode..'"><rect width="8" height="4" fill="black"/></mask></defs><rect width="8" height="4" fill="red" mask="url(#m)"/></svg>').Children[1]
  local masked,diagnostics=Embedded.build(Embedded.document(source),8,4);assert(#diagnostics==0)
  local pixels=Raster.render(masked,nil,8)
  assert(buffer.readu8(pixels,(2*8+4)*4+3)==(if mode=='alpha' then 255 else 0),'SVG mask-type must affect the actual mask pixels')
 end
 local tasks,cleanups={},{}
 local page={Alive=true,ResolveSVG=function(src)return if src=='alpha.svg' then node else nil end}
 function page:AddCleanup(fn)table.insert(cleanups,fn)end
 local scheduler={defer=function(fn)table.insert(tasks,fn)end,wait=function()error('Unexpected wait')end}
 local changed=0;local tree={Children={}}
 local loader=loadShapeImages().start(page,tree,error,function()changed+=1 end,{Task=scheduler,Embedded=Embedded,Raster=Raster,WorkBudgetMS=0})
 assert(not loader.Get('alpha.svg',.5));tasks[1]()
 local loaded=loader.Get('alpha.svg',.5)
 assert(changed==1 and loaded.Width==80 and loaded.Height==40 and loaded.Rows[21][2]==60)
 cleanups[1]();assert(not tree.ShapeImageProvider)
 print('SVG shape images: real raster alpha/threshold, SVG mask-type alpha/luminance, URL source loading and disposal passed')
end
