--!strict
local Context=require(script.Parent.TreeContext)
local Formatting=require(script.Parent.Formatting)
local Head=require(script.Parent.DocumentHead)
local Body={}
local block={address=true,article=true,aside=true,blockquote=true,center=true,details=true,dialog=true,dir=true,div=true,dl=true,fieldset=true,figcaption=true,figure=true,footer=true,header=true,hgroup=true,main=true,menu=true,nav=true,ol=true,p=true,search=true,section=true,summary=true,ul=true}
local function heading(n: string): boolean return n:match("^h[1-6]$")~=nil end
local function paragraph(c: any) if c:inScope("p","button") then c:closeP() end end
local function listItem(c: any,names: any)
	for i=#c.Stack,1,-1 do
		local node=c.Stack[i]; local n=node.Name
		if node.NamespaceURI==nil and names[n] then c:implied(n); for _=#c.Stack,i,-1 do c:pop() end; break end
		if Context.isSpecial(node) and not (node.NamespaceURI==nil and (n=="address" or n=="div" or n=="p")) then break end
	end
end
function Body.process(c: any,t: any): boolean
	if t.Kind=="Text" then local value=t.Text:gsub("%z",""); if value~="" then c:reconstruct(); c:text(value); if value:find("[^\t\n\f\r ]") then c.FramesetOK=false end end; return true
	elseif (t.Kind=="Comment" or t.Kind=="ProcessingInstruction") then c:comment(t); return true
	elseif t.Kind=="Declaration" or t.Kind=="EOF" then return true end
	local n=t.Name
	if t.Kind=="StartTag" then
		if n=="html" then if #c.Templates==0 then c:merge(c.Document.DocumentElement,t) end
		elseif n=="body" then if c.Document.Body and #c.Templates==0 then c:merge(c.Document.Body,t); c.FramesetOK=false end
		elseif n=="head" or n=="caption" or n=="col" or n=="colgroup" or n=="frame" or n=="tbody" or n=="td" or n=="tfoot" or n=="th" or n=="thead" or n=="tr" then return true
		elseif n=="frameset" then
			if not c.FramesetOK or #c.Templates>0 or not c.Document.Body then return true end
			local body=c.Document.Body; if body.Parent then c.Node.removeChild(body.Parent,body) end
			while #c.Stack>1 do c:pop() end; c.Document.Body=c:insert(t); c.Mode="frameset"
		elseif Head.metadata(c,t) then return true
		elseif block[n] then paragraph(c); c:insert(t)
		elseif heading(n) then paragraph(c); if heading(c:current().Name) then c:pop() end; c:insert(t)
		elseif n=="pre" or n=="listing" then paragraph(c); c:insert(t); c.SkipLF=true; c.FramesetOK=false
		elseif n=="form" then
			if c.Form and #c.Templates==0 then return true end
			paragraph(c); local node=c:insert(t); if #c.Templates==0 then c.Form=node end
		elseif n=="li" then c.FramesetOK=false; listItem(c,{li=true}); paragraph(c); c:insert(t)
		elseif n=="dd" or n=="dt" then c.FramesetOK=false; listItem(c,{dd=true,dt=true}); paragraph(c); c:insert(t)
		elseif n=="plaintext" then paragraph(c); c:insert(t); c.Tokenizer.Raw="plaintext"
		elseif n=="button" then
			if c:inScope("button") then c:implied(); c:close("button") end
			c:reconstruct(); c:insert(t); c.FramesetOK=false
		elseif Formatting.Names[n] then
			if n=="a" then
				local old=c:active("a"); if old then Formatting.finish(c,"a"); c:remove(old); local index=table.find(c.Active,old); if index then table.remove(c.Active,index) end end
			end
			c:reconstruct()
			if n=="nobr" and c:inScope("nobr") then Formatting.finish(c,"nobr"); c:reconstruct() end
			Formatting.add(c,c:insert(t))
		elseif n=="applet" or n=="marquee" or n=="object" then c:reconstruct(); c:insert(t); c:marker(); c.FramesetOK=false
		elseif n=="table" then if c.Document.Mode~="quirks" then paragraph(c) end; c:insert(t); c.FramesetOK=false; c.Mode="table"
		elseif n=="area" or n=="br" or n=="embed" or n=="img" or n=="keygen" or n=="wbr" then c:reconstruct(); c:insert(t,nil,false); c.FramesetOK=false
		elseif n=="input" then if c:inScope("select") then c:close("select") end; c:reconstruct(); c:insert(t,nil,false); if (t.Attributes.type or ""):lower()~="hidden" then c.FramesetOK=false end
		elseif n=="param" or n=="source" or n=="track" then c:insert(t,nil,false)
		elseif n=="hr" then paragraph(c); if c:inScope("select") then c:implied() end; c:insert(t,nil,false); c.FramesetOK=false
		elseif n=="image" then t.Name="img"; return Body.process(c,t)
		elseif n=="textarea" then Head.raw(c,t); c.SkipLF=true; c.FramesetOK=false
		elseif n=="xmp" then paragraph(c); c:reconstruct(); c.FramesetOK=false; Head.raw(c,t)
		elseif n=="iframe" then c.FramesetOK=false; Head.raw(c,t)
		elseif n=="noembed" or (n=="noscript" and c.Document.ScriptingEnabled) then Head.raw(c,t)
		elseif n=="select" then if c:inScope("select") then c:close("select") else c:reconstruct(); c:insert(t); c.FramesetOK=false end
		elseif n=="option" or n=="optgroup" then
			if c:inScope("select") then c:implied(if n=="option" then "optgroup" else nil) elseif c:current().Name=="option" then c:pop() end
			c:reconstruct(); c:insert(t)
		elseif n=="rb" or n=="rtc" then if c:inScope("ruby") then c:implied() end; c:insert(t)
		elseif n=="rp" or n=="rt" then if c:inScope("ruby") then c:implied("rtc") end; c:insert(t)
		elseif n=="svg" or n=="math" then c:reconstruct(); c.ForeignInsert(c,t,if n=="svg" then "http://www.w3.org/2000/svg" else "http://www.w3.org/1998/Math/MathML")
		else c:reconstruct(); c:insert(t) end
		return true
	end
	if n=="template" then return Head.metadata(c,t)
	elseif n=="select" then if c:inScope("select") then c:implied(); c:close("select") end
	elseif n=="body" then if c:inScope("body") then c.Mode="after-body" end
	elseif n=="html" then if c:inScope("body") then c.Mode="after-body"; return false end
	elseif n=="p" then if not c:inScope("p","button") then c:synthetic("p") end; c:closeP()
	elseif block[n] or n=="pre" or n=="listing" or n=="button" then if c:inScope(n) then c:implied(); c:close(n) end
	elseif n=="form" then
		if #c.Templates==0 then local form=c.Form; c.Form=nil; if form and c:inScope(form) then c:implied(); c:remove(form) end
		elseif c:inScope("form") then c:implied(); c:close("form") end
	elseif n=="li" or n=="dd" or n=="dt" then if c:inScope(n,if n=="li" then "list" else nil) then c:implied(n); c:close(n) end
	elseif heading(n) then
		local target=nil; for i=#c.Stack,1,-1 do if heading(c.Stack[i].Name) and c:inScope(c.Stack[i]) then target=c.Stack[i]; break end end
		if target then c:implied(); while c:pop()~=target do end end
	elseif Formatting.Names[n] then Formatting.finish(c,n)
	elseif n=="applet" or n=="marquee" or n=="object" then if c:inScope(n) then c:implied(); c:close(n); c:clearMarker() end
	elseif n=="br" then t.Kind="StartTag"; t.Attributes={}; t.AttributeOrder={}; return Body.process(c,t)
	else Formatting.ordinaryEnd(c,n) end
	return true
end
return Body
