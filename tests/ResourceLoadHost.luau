--!strict
return function(ResourceLoadHost,Parser,Node)
	local tasks={};local preloads,decodes,natives,releases,editableReleases=0,0,0,0,0
	local status="Success";local canDecode=true
	local function temporary()natives+=1;local value={};function value:Destroy()assert(not self.Destroyed,"Temporary native target disposed twice");self.Destroyed=true;releases+=1 end;return value end
	local services={Task={defer=function(fn)table.insert(tasks,fn)end},AssetFetchSuccess="Success",CreateImageLabel=temporary,CreateTextLabel=temporary,
		ResolveFont=function(family,weight,style)return{Family=family,Weight=weight,Style=style}end,
		ContentProvider={PreloadAsync=function(_,targets,report)preloads+=1;assert(#targets==1);report(targets[1].Image or"font",status)end},
		AssetService={CreateEditableImageAsync=function()decodes+=1;if not canDecode then return nil end;local value={Size={X=640,Y=360}};function value:Destroy()assert(not self.Destroyed);self.Destroyed=true;editableReleases+=1 end;return value end}}
	local svg=Node.findElement(Parser.parse('<svg width="400" height="200" viewBox="0 0 40 20"></svg>'),function(node)return node.Name=="svg"end)
	local page={Alive=true,ResolveImage=function(source)return if source=="photo.png"or source=="alias.png"then"rbxassetid://123"elseif source=="broken.png"then"rbxassetid://999"else nil end,
		ResolveSVG=function(source)return if source=="drawing.svg"then svg else nil end}
	local host=ResourceLoadHost.new(page,{},services)
	local function pump()while #tasks>0 do table.remove(tasks,1)()end end
	local called=0
	local metadata=0
	host:LoadRasterDimensions("rbxassetid://123",function(ok,data)assert(ok and data.Width==640 and data.Height==360);metadata+=1 end)
	local cancel=host:LoadImage("https://resources.test/photo.png",function()error("Cancelled request completed")end,{Source="photo.png"})
	host:LoadImage("https://resources.test/alias.png",function(ok,data)called+=1;assert(ok and data.Width==640 and data.Height==360)end,{Source="alias.png"});cancel();pump()
	assert(called==1 and metadata==1 and preloads==1 and decodes==1 and natives==1 and releases==1 and editableReleases==1,"Layout metadata and image aliases share native decoding and release both allocations")
	host:LoadImage("https://resources.test/photo.png",function(ok,data)assert(ok and data.Width==640);called+=1 end,{Source="photo.png"});assert(called==1,"Cached resource completion is still deferred");pump();assert(called==2 and decodes==1)
	local cancelCached=host:LoadRasterDimensions("rbxassetid://123",function()error("Cancelled cache subscriber completed")end);cancelCached();pump()
	host:LoadImage("https://resources.test/drawing.svg",function(ok,data)assert(ok and data.Width==400 and data.Height==200 and data.SVG==svg);called+=1 end,{Source="drawing.svg"});pump();assert(called==3 and natives==1,"Packaged SVG uses its actual source geometry")
	status="Failure";host:LoadImage("https://resources.test/broken.png",function(ok)assert(not ok);called+=1 end,{Source="broken.png"});pump();assert(called==4 and decodes==1)
	status="Success";canDecode=false;host:LoadImage("https://resources.test/broken.png",function(ok)assert(not ok);called+=1 end,{Source="broken.png"});pump();assert(called==5 and decodes==2,"Success is not invented when native image decoding is unavailable")
	canDecode=true;host:LoadImage("https://resources.test/broken.png",function(ok)assert(ok);called+=1 end,{Source="broken.png"});pump();assert(called==6 and decodes==3,"Failed native requests can be retried")
	host:LoadFont({Family="Lato",Source='local("Lato")',Descriptors={weight="700",style="italic"}},function(ok,data)assert(ok and data.Family=="Lato"and data.FontFace.Weight==700);called+=1 end);pump()
	host:LoadFont({Family="Alias",Source='local("Lato")',Descriptors={}},function(ok,message)assert(not ok and tostring(message):find("matching its CSS family",1,true));called+=1 end);pump()
	host:LoadFont({Family="Lato",Source='url("lato.woff2")',Descriptors={}},function(ok)assert(not ok);called+=1 end);pump();assert(called==9)
	for _,dimensions in {{0,0},{0,30},{40,0}}do
		local zeroSVG=Node.findElement(Parser.parse('<svg width="'..dimensions[1]..'" height="'..dimensions[2]..'" viewBox="0 0 40 20"></svg>'),function(node)return node.Name=="svg"end)
		page.ResolveSVG=function(source)return if source=="zero.svg"then zeroSVG else nil end
		local zeroHost=ResourceLoadHost.new(page,{},services);local delivered=false
		zeroHost:LoadImage("https://resources.test/zero.svg",function(ok,data)
			assert(ok and data.Width==dimensions[1]and data.Height==dimensions[2],"Zero SVG dimensions are valid decoded metadata")
			delivered=true
		end,{Source="zero.svg"});pump();assert(delivered);zeroHost:Destroy()
	end
	host:LoadImage("https://resources.test/unmapped.png",function()error("Disposed request completed")end,{Source="unmapped.png"});host:Destroy();pump()
	assert(releases==natives,"All temporary native labels released")
	print("Resource host: actual metadata adapters, shared loads, cancellation, retries and explicit font/decoder limitations passed")
end
