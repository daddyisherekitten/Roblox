--!strict
-- Build an independent styled rendering tree. Source nodes and definitions stay immutable.
local Parser=require(script.Parent.Parser)
local Style=require(script.Parent.Style)
local Length=require(script.Parent.Length)
local Viewport=require(script.Parent.Viewport)
local Conditional=require(script.Parent.Conditional)
local Document={}
local function absolute(url: string,base: string): string
	if url:match('^%a[%w+.-]*:') or url:sub(1,1)=='/' then return url end
	local authority,path=base:match('^(%a[%w+.-]*://[^/]*)(/.*)$')
	path=path or base;path=path:match('^[^?#]*') :: string
	local prefix=path:match('^(.*[/])') or ''
	local parts={};for part in (prefix..url):gmatch('[^/]+') do if part=='..' and #parts>0 then table.remove(parts) elseif part~='.' then table.insert(parts,part) end end
	return (authority or '')..(if prefix:sub(1,1)=='/' then '/' else '')..table.concat(parts,'/')
end
function Document.prepare(document: any,options: any?): any
	options=options or {};local diagnostics={};local count=0;local cache={}
	local function report(code: string,value: any) if #diagnostics<100 then table.insert(diagnostics,{Code=code,Value=value}) end end
	local function scope(doc: any,url: string): any return {Document=doc,URL=url,Rules=Style.collect(doc,report,if doc==document then options.CSS else nil)} end
	local original=scope(document,options.URL or '')
 local view=Conditional.view(document,options.Fragment,report)
	local output={Kind='Document',Children={},Valid=document.Valid,Diagnostics=diagnostics}
	local function external(url: string,base: string): any
		url=absolute(url,base)
		if cache[url]~=nil then return cache[url] or nil end
		cache[url]=false
		local n=0;for _ in cache do n+=1 end;if n>32 then report('external-document-limit',url);return nil end
		if not options.Resolve then report('external-reference-unavailable',url);return nil end
		local ok,value=pcall(options.Resolve,url,base)
		if not ok or not value then report('external-reference-unavailable',url);return nil end
		local source=if type(value)=='table' then value.SVG else value
		if type(source)~='string' then report('invalid-external-document',url);return nil end
		local doc=Parser.parse(source)
		if not doc.Valid then report('invalid-external-document',url);return nil end
		local resolved=scope(doc,if type(value)=='table' then value.URL or url else url);cache[url]=resolved;return resolved
	end
 local function animated(computed,node)
  local overrides=options.Animated and options.Animated[node]
  for key,value in overrides or {} do
   if key:sub(1,1)=='_' then continue end
   computed.Values[key]=value;computed.Attributes[key]=value
   if key=='transform' then
    computed.Attributes.style=if overrides._transformCSS then 'transform:'..value..';' else nil
    computed.Kinds.transform=overrides._transformCSS~=nil
   elseif key=='font-size' then computed.FontSize=Length.resolve(value,{Width=480,Height=320,FontSize=computed.FontSize,RootFontSize=16},'font',true) or computed.FontSize end
  end
  return computed
 end
	-- Resource access is shared by use and paint servers, with the same resolver cache.
 function output.Resource(href: string,from: any): (any,any)
  local source=from.Scope or from
  local file,fragment=href:match('^(.-)#(.*)$')
  if not file then file=href end
  local targetScope=if file=='' then source else external(file,source.URL)
  if not targetScope then return nil,nil end
  if fragment then fragment=fragment:gsub('%%(%x%x)',function(hex) return string.char(tonumber(hex,16)) end) end
  return if fragment and fragment~='' then targetScope.Document.Ids[fragment] else targetScope.Document.Root,targetScope
 end
 local compute
 local computedResources={}
 local function sameContext(a,b)
  for key,value in a do if b[key]~=value then return false end end
  for key,value in b do if a[key]~=value then return false end end
  return true
 end
 compute=function(node: any,source: any,context: any,parent: any?,depth: number?): any
  depth=depth or 0
  if depth>128 then report('resource-style-limit',node.Name);return nil end
  local inherited=parent
  local cached=computedResources[node]
  for _,entry in cached or {} do
   if entry.Scope==source and entry.Parent==inherited and sameContext(entry.Context,context) then return entry.Value end
  end
  if not parent and node.Parent and node.Parent.Kind=='Element' then parent=compute(node.Parent,source,context,nil,depth+1) end
  local ctx=table.clone(context)
  if parent then ctx.FontSize=parent.FontSize end
  local computed=animated(Style.compute(node,parent,ctx,source.Rules,report,options.States),node)
  -- A prepared document is one immutable state. Repeated paint-server bindings
  -- can reuse its resource ancestry styles; a new hover/mutation prepares anew.
  if not cached then cached={};computedResources[node]=cached end
  if #cached<32 then table.insert(cached,{Scope=source,Parent=inherited,Context=table.clone(context),Value=computed}) end
  return computed
 end
 output.Compute=compute
	local images={};local imageCount,imageBytes=0,0
 function output.ImageResource(href: string,from: any): any
  local url=absolute(href,from.Scope.URL)
  if images[url]~=nil then return images[url] or nil end
  images[url]=false;imageCount+=1
  if imageCount>32 then report('image-resource-limit',url);return nil end
  if url:lower():match('%.svg$') then
   local root,source=output.Resource(href,from)
   if root and root.Name=='svg' then images[url]={Root=root,Scope=source};return images[url] end
   return nil
  end
  if not options.ResolveImage then return nil end
  local ok,value=pcall(options.ResolveImage,url,from.Scope.URL)
  if not ok then report('image-load-failed',url..': '..tostring(value));return nil end
  if not value then return nil end
  local w,h=value.Width,value.Height
  if type(w)~='number' or type(h)~='number' or w~=math.floor(w) or h~=math.floor(h) or w<1 or h<1 or w>1024 or h>1024 or typeof(value.Pixels)~='buffer' or buffer.len(value.Pixels)~=w*h*4 then report('invalid-image-resource',url);return nil end
  imageBytes+=w*h*4
  if imageBytes>32*1024*1024 then report('image-memory-limit',url);return nil end
  local pixels=buffer.create(w*h*4);buffer.copy(pixels,0,value.Pixels)
  images[url]={Width=w,Height=h,Pixels=pixels};return images[url]
 end
 local active={};local walk
	walk=function(node: any,parent: any,parentStyle: any,context: any,source: any,depth: number,instance: boolean?,dimensions: any?,eventSource: any?): any
		count+=1;if count>20000 or depth>128 then report('use-expansion-limit',node.Attributes and node.Attributes.id);return nil end
		if node.Kind=='Text' and parent and (parent.Name=='text' or parent.Name=='tspan' or parent.Name=='textPath') then return {Kind='Text',Text=node.Text,Children={},Parent=parent,Source=node} end
		if node.Kind~='Element' then return nil end
		if not Conditional.matches(node.Attributes,options) then return nil end
  if Conditional.Unsupported[node.Name] then report('unsupported-svg-extension',node.Name..':'..Conditional.Unsupported[node.Name]);return nil end
		if ({script=true,view=true,title=true,desc=true,metadata=true,animate=true,animateColor=true,animateTransform=true,animateMotion=true,set=true,mpath=true})[node.Name] then return nil end
		if node.NamespaceURI~=Parser.Namespace then return nil end
		local computed=animated(Style.compute(node,parentStyle,context,source.Rules,report,options.States),node)
		local copy={Kind='Element',Name=node.Name,NamespaceURI=node.NamespaceURI,Attributes=table.clone(computed.Attributes),Children={},Parent=parent,Source=node,EventSource=eventSource,Scope=source,Computed=computed}
		if node==document.Root and options.RootSize then copy.Attributes.width=tostring(options.RootSize.Width);copy.Attributes.height=tostring(options.RootSize.Height) end
  if node==document.Root and view then for key,value in view do copy.Attributes[key]=value end end
		if node.Name=='switch' then copy.Name='g' end
		if dimensions and (node.Name=='symbol' or node.Name=='svg') then
			for key,value in dimensions do if value~='auto' then copy.Attributes[key]=value end end
		end
		if node.Name=='symbol' then
			if not instance then return copy end
			copy.Name='svg';copy.Attributes.x='0';copy.Attributes.y='0'
			if not node.Attributes.overflow and not (node.Attributes.style or ''):find('overflow',1,true) then copy.Attributes.overflow='hidden' end
		end
		if node.Name=='defs' or node.Name=='style' then return copy end
		if computed.Values.display=='none' then return copy end
		local childContext=table.clone(context);childContext.FontSize=computed.FontSize
		if not parentStyle then childContext.RootFontSize=computed.FontSize end
		if copy.Name=='svg' then
			local box=Viewport.viewBox(copy.Attributes.viewBox)
			childContext.Width=if box then box.Width else Length.attribute(copy.Attributes.width,context,'x',context.Width,true)
			childContext.Height=if box then box.Height else Length.attribute(copy.Attributes.height,context,'y',context.Height,true)
		end
		if node.Name=='use' then
			copy.Name='g'
			local href=node.Attributes.href
			if href==nil then href=node.ExpandedAttributes and node.ExpandedAttributes['http://www.w3.org/1999/xlink\0href'] end
			if not href or href=='' then report('missing-use-reference',href);return copy end
			local file,fragment=href:match('^(.-)#(.*)$')
			if not file then file=href end
			local targetScope=if file=='' then source else external(file,source.URL)
			if not targetScope then return copy end
			if fragment then fragment=fragment:gsub('%%(%x%x)',function(hex) return string.char(tonumber(hex,16)) end) end
			local target=if fragment and fragment~='' then targetScope.Document.Ids[fragment] else targetScope.Document.Root
			if not target then report('missing-use-target',href);return copy end
			local ancestor=node
			while ancestor and ancestor~=target do ancestor=ancestor.Parent end
			if ancestor then report('cyclic-use-reference',href);return copy end
			if active[target] then report('cyclic-use-reference',href);return copy end
			local allowed={svg=true,symbol=true,g=true,use=true,path=true,rect=true,circle=true,ellipse=true,line=true,polyline=true,polygon=true,image=true,text=true}
			if not allowed[target.Name] then report('unsupported-use-target',href);return copy end
			local x=Length.attribute(computed.Values.x,context,'x',0,false);local y=Length.attribute(computed.Values.y,context,'y',0,false)
			copy.UseTranslation={SX=1,SY=1,TX=x,TY=y}
			local offset={Kind='Element',Name='g',NamespaceURI=Parser.Namespace,Attributes={transform=`translate({x} {y})`},Children={},Parent=copy}
			table.insert(copy.Children,offset)
			active[target]=true
			local child=walk(target,offset,computed,childContext,targetScope,depth+1,true,{width=computed.Values.width,height=computed.Values.height},eventSource or node)
			active[target]=nil
			if child then table.insert(offset.Children,child) end
			return copy
		end
		for _,child in node.Children do
   if node.Name=='switch' and (child.Kind~='Element' or not Conditional.matches(child.Attributes,options)) then continue end
			local c=walk(child,copy,computed,childContext,source,depth+1,nil,nil,eventSource);if c then table.insert(copy.Children,c) end
   if node.Name=='switch' then break end
  end
		return copy
	end
 -- Instantiate non-rendered resource content with the resource's own inheritance.
 function output.Content(children: any,computed: any,source: any,context: any): any
  local root={Kind='Element',Name='g',NamespaceURI=Parser.Namespace,Attributes={},Children={},Scope=source,Computed=computed}
  for _,child in children do
   local copy=walk(child,root,computed,context,source,0)
   if copy then table.insert(root.Children,copy) end
  end
  return root
 end
	local root=walk(document.Root,output,nil,{Width=options.Width or 480,Height=options.Height or 320,FontSize=16,RootFontSize=16},original,0)
	output.Root=root;if root then table.insert(output.Children,root) end
	return output
end
return Document
