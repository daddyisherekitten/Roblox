--!strict
return function(Parser,Runtime,Events,fixture,DocumentInfo)
	for _,case in fixture.cases do
		local document=Parser.parseDocument(case.html);local events=Events.new(error)
		local runtime=Runtime.new(document,{Events=events,Schedule=function()end})
		local ok,message=runtime:Run('globalThis.accessorResult='..case.action)
		assert(ok,case.name..': '..tostring(message))
		local actual=runtime.Window.Get('accessorResult')
		local expected=case.specExpected or case.expected
		assert(actual==expected,case.name..'\nexpected '..expected..'\nactual '..tostring(actual))
		assert(#runtime.Diagnostics==0,case.name..': '..table.concat(runtime.Diagnostics,' | '))
		runtime:Destroy();events:Destroy()
	end
	local document=Parser.parseDocument('<!doctype html><title>Initial</title><body><p>Body</p>')
	local events=Events.new(error);local runtime=Runtime.new(document,{Events=events,Schedule=function()end})
	assert(runtime:Run([=[
window.metadataDocument=document.implementation.createDocument('http://www.w3.org/1999/xhtml','p:html');
const H='http://www.w3.org/1999/xhtml',head=metadataDocument.createElementNS(H,'p:head'),title=metadataDocument.createElementNS(H,'p:title'),base=metadataDocument.createElementNS(H,'p:base'),meta=metadataDocument.createElementNS(H,'p:meta'),link=metadataDocument.createElementNS(H,'p:link');
title.append(metadataDocument.createTextNode(' \t direct '),metadataDocument.createElement('span'),metadataDocument.createTextNode('\n text \u00a0'));
title.children[0].textContent='excluded';
base.setAttribute('href','https://metadata.test/assets/');base.setAttribute('target','preview');
meta.setAttribute('name','theme-color');meta.setAttribute('content','#123456');
link.setAttribute('rel','stylesheet');link.setAttribute('href','style.css');
head.append(title,base,meta,link);metadataDocument.documentElement.append(head);
window.metadataTitle=metadataDocument.title;
window.svgDocument=metadataDocument.implementation.createDocument('http://www.w3.org/2000/svg','p:svg');
svgDocument.title=' \t SVG \n title ';
window.svgTitle=svgDocument.title;
]=]))
	local info=DocumentInfo.collect(runtime.Window.Get('metadataDocument').DOMNode,'https://metadata.test/index.html')
	assert(info.Title==runtime.Window.Get('metadataTitle')and info.Title=='direct text '..utf8.char(160),'Host metadata and DOM title share child text and ASCII-only whitespace semantics')
	assert(info.BaseURL=='https://metadata.test/assets/'and info.DefaultTarget=='preview'and info.ThemeColor=='#123456'and info.Links[1].URL=='https://metadata.test/assets/style.css','Prefixed metadata uses expanded HTML element names and the same frozen base path')
	local svgInfo=DocumentInfo.collect(runtime.Window.Get('svgDocument').DOMNode)
	assert(svgInfo.Title==runtime.Window.Get('svgTitle')and svgInfo.Title=='SVG title','SVG root titles use the shared host/DOM path')
	assert(runtime:Run('window.heldImplementation=document.implementation;window.orphanFactoryDocument=document.implementation.createHTMLDocument("unused");window.orphanImplementation=orphanFactoryDocument.implementation;'))
	local discarded=setmetatable({},{__mode='k'})
	discarded[runtime.Window.Get('orphanFactoryDocument').DOMNode]=true
	assert(runtime:Run('window.orphanFactoryDocument=null;window.orphanImplementation=null;'))
	runtime:Flush();runtime:PumpTasks()
	for batch=1,2048 do
		if next(discarded)==nil then break end
		local garbage=table.create(2048);for index=1,2048 do garbage[index]={batch,index}end
	end
	assert(next(discarded)==nil,'A cached DOMImplementation cannot root an unreferenced detached document')
	assert(runtime:Run('if(heldImplementation!==document.implementation||heldImplementation.createDocumentType("html","","").ownerDocument!==document)throw new Error("held implementation lost owner or identity");'))
	runtime:Destroy();events:Destroy()
	print('Document accessors: '..#fixture.cases..' native namespace/root/title/body sequences passed')
end
