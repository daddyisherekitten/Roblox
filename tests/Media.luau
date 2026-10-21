--!strict
return function(Parser: any,MediaSources: any,WebVTT: any,loadRenderTree: any,ImageSources: any)
	local audio={['tone.ogg']='11',['tone.mp3']='12'}
	local videos={['clip.webm']='21',['clip.mp4']='22'}
	local tracks={['captions.vtt']='WEBVTT\n\n00:00.500 --> 00:02.000\nHello &amp; Roblox\n\n00:02.500 --> 00:04.000\nSecond cue'}
	local resolver=MediaSources.new(audio,videos,tracks)
	assert(resolver:Asset('audio','./tone.ogg')=='rbxassetid://11' and resolver:Asset('video','clip.mp4')=='rbxassetid://22')
	assert(resolver:Track('./captions.vtt')==tracks['captions.vtt'])
	local document=Parser.parse('<audio controls><source src="missing.wav" type="audio/wav"><source src="tone.mp3" type="audio/mpeg"></audio><video controls poster="poster.png"><source src="clip.webm" type="video/webm"><track src="captions.vtt" kind="captions" default></video>')
	local a,aAsset=MediaSources.select(document.Children[1],'audio',resolver)
	local v,vAsset=MediaSources.select(document.Children[2],'video',resolver)
	assert(a=='tone.mp3' and aAsset=='rbxassetid://12' and v=='clip.webm' and vAsset=='rbxassetid://21')
	local mediaTracks=MediaSources.tracks(document.Children[2],resolver)
	assert(#mediaTracks==1 and mediaTracks[1].Default and mediaTracks[1].Kind=='captions')
	local cues,diagnostics=WebVTT.parse(tracks['captions.vtt'])
	assert(#diagnostics==0 and #cues==2 and cues[1].Start==.5 and cues[1].Text=='Hello & Roblox')
	assert(WebVTT.at(cues,1)=='Hello & Roblox' and WebVTT.at(cues,2.2)==nil and WebVTT.at(cues,3)=='Second cue')
	assert(not pcall(MediaSources.new,{bad=0},nil,nil))
	local renderer=loadRenderTree({create=function(_,_,props)return table.clone(props)end,modifier=function(_,_,props)return table.clone(props)end})
	local errors={}
	local tree=renderer.build(document,{AbsoluteSize={X=800,Y=600}},function(message)table.insert(errors,message)end,nil,nil,nil,function()return 'rbxassetid://31'end,nil,nil,nil,nil,nil,nil,nil,resolver)
	assert(#errors==0 and #tree.MediaItems==2)
	assert(tree.MediaItems[1].Controls and tree.MediaItems[2].Poster=='rbxassetid://31' and tree.MediaItems[2].AllowFullscreen)
	assert(tree.MediaItems[1].ControlsGui.BackgroundTransparency==0 and tree.MediaItems[2].ControlsGui.BackgroundTransparency==.5)
	assert(tree.MediaItems[2].CaptionGui.TextWrapped and tree.MediaItems[2].CaptionGui.TextScaled and tree.MediaItems[2].CaptionGui.ClipsDescendants,
		'Video captions must wrap and scale within their own box')
	assert(tree.MediaByNode[document.Children[1]]==tree.MediaItems[1] and tree.MediaByNode[document.Children[2]]==tree.MediaItems[2])
	local restricted=Parser.parse('<video controls controlslist="nodownload nofullscreen" src="clip.webm"></video>')
	local restrictedTree=renderer.build(restricted,{AbsoluteSize={X=800,Y=600}},function(message)table.insert(errors,message)end,nil,nil,nil,function()return nil end,nil,nil,nil,nil,nil,nil,nil,resolver)
	assert(#restrictedTree.MediaItems==1 and not restrictedTree.MediaItems[1].AllowFullscreen)
	local svg=ImageSources.newSVGResolver({['sample.svg']='<svg width="320" height="180" viewBox="0 0 320 180"><circle cx="30" cy="30" r="20"/></svg>'})
	local localMedia=Parser.parse('<picture><source srcset="sample.svg" type="image/svg+xml"><img src="sample.svg" alt="Geometric sample" width="320" height="180"></picture><video controls poster="sample.svg" width="320" height="180"><source src="clip.webm" type="video/webm"></video><object data="sample.svg" type="image/svg+xml" width="150" height="90"></object><embed src="sample.svg" type="image/svg+xml" width="150" height="90">')
	local localErrors={}
	local localTree=renderer.build(localMedia,{AbsoluteSize={X=800,Y=600}},function(message)table.insert(localErrors,message)end,
		nil,nil,nil,function()return nil end,nil,nil,nil,nil,nil,nil,nil,resolver,nil,nil,nil,svg)
	assert(#localErrors==0 and #localTree.SVGItems==2 and #localTree.IFrameItems==2 and #localTree.MediaItems==1,
		'Local SVG must back picture, video poster, object and embed without image asset diagnostics')
	local picture=localTree.SVGItems[1]
	local poster=localTree.MediaItems[1]
	assert(picture.SelectedSource=='sample.svg' and picture.ImageGui and picture.TextFallback==false
		and picture.FallbackGui.Visible==false and poster.PosterSVGItem==localTree.SVGItems[2]
		and poster.PosterSVGItem.ImageGui==poster.PosterGui and localTree.IFrameItems[1].UnsupportedType==nil
		and localTree.IFrameItems[2].UnsupportedType==nil)
	local styled=Parser.parse('<audio controls><source src="tone.mp3" type="audio/mpeg"></audio><video controls><source src="clip.webm" type="video/webm"></video><iframe srcdoc="&lt;p&gt;Test&lt;/p&gt;"></iframe>')
	local styleErrors={}
	local styledTree=renderer.build(styled,{AbsoluteSize={X=800,Y=600}},function(message)table.insert(styleErrors,message)end,
		nil,nil,nil,nil,'audio{width:100%;margin:8px 0}video,iframe{max-width:100%}iframe{border:1px solid #c9d9d0}',
		nil,nil,nil,nil,nil,nil,resolver)
	assert(#styleErrors==0 and styledTree.MediaItems[1].Style.Width and styledTree.IFrameItems[1].Style.BorderSizes[1]==1,
		'Replaced inline media accept CSS box dimensions, margins and borders without inline-style diagnostics')
	assert(styledTree.MediaItems[1].Style.Display=='inline' and styledTree.MediaItems[2].Style.Display=='inline'
		and styledTree.IFrameItems[1].Style.Display=='inline'
		and localTree.IFrameItems[1].Style.Display=='inline' and localTree.IFrameItems[2].Style.Display=='inline',
		'Browser-default media and embedded objects participate in inline line boxes')
	print('Media: source mapping, compatible fallbacks, WebVTT cues, poster, controlslist and render items passed')
end
