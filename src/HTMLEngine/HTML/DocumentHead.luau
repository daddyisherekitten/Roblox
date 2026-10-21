--!strict
local Node=require(script.Parent.Parent.DOM.Node)
local Doctype=require(script.Parent.Doctype)
local Head={}
local function white(t: any): boolean return t.Kind=="Text" and not t.Text:find("[^\t\n\f\r ]") end
local function tag(t: any,kind: string,name: string): boolean return t.Kind==kind and t.Name==name end
function Head.raw(c: any,t: any)
	c:insert(t); c.OriginalMode=c.Mode; c.Mode="text"; c.Tokenizer.Raw=t.Name
end
function Head.metadata(c: any,t: any): boolean
	if t.Kind=="StartTag" then
		local n=t.Name
		if n=="base" or n=="basefont" or n=="bgsound" or n=="link" or n=="meta" then
			c:insert(t,nil,false);if n=='meta'and c.EncodingProbe then c.EncodingProbe(t.Attributes)end;return true
		elseif n=="title" or n=="style" or n=="noframes" or n=="script" or (n=="noscript" and c.Document.ScriptingEnabled) then Head.raw(c,t); return true
		elseif n=="template" then
			c:insert(t); c:marker(); c.FramesetOK=false; table.insert(c.Templates,"template"); c.Mode="template"; return true
		end
	elseif tag(t,"EndTag","template") then
		if not c:find("template") then c.Warn("unexpected-end-tag","No open template",t.Position); return true end
		c:implied(); c:close("template"); c:clearMarker(); table.remove(c.Templates); c:resetMode(); return true
	end
	return false
end
function Head.process(c: any,t: any): boolean
	local mode=c.Mode
	if mode=="text" then
		if t.Kind=="Text" then c:text(t.Text)
		elseif t.Kind=="EndTag" then c:pop(); c.Mode=c.OriginalMode
		elseif t.Kind=="EOF" then c.Warn("eof-in-text","Unclosed text element",t.Position); c:pop(); c.Mode=c.OriginalMode; return false end
		return true
	end
	if mode=="initial" then
		if white(t) then return true elseif (t.Kind=="Comment" or t.Kind=="ProcessingInstruction") then c:comment(t,c.Document); return true
		elseif t.Kind=="Declaration" and t.Doctype then
			local d=t.Doctype; c:attach(c:allocate(Node.documentType(d.Name,d.PublicId or "",d.SystemId or "")),c.Document)
			c.Document.Mode=if c.Document.IsSrcdoc then 'no-quirks'else Doctype.mode(d); c.Mode="before-html"; return true
		end
		c.Document.Mode=if c.Document.IsSrcdoc then 'no-quirks'else 'quirks';c.Mode="before-html";return false
	elseif mode=="before-html" then
		if t.Kind=="Declaration" or white(t) then return true elseif (t.Kind=="Comment" or t.Kind=="ProcessingInstruction") then c:comment(t,c.Document); return true end
		if t.Kind=="EndTag" and t.Name~="head" and t.Name~="body" and t.Name~="html" and t.Name~="br" then return true end
		c.Document.DocumentElement=if tag(t,"StartTag","html") then c:insert(t) else c:synthetic("html")
		c.Mode="before-head"; return tag(t,"StartTag","html")
	elseif mode=="before-head" then
		if white(t) or t.Kind=="Declaration" then return true elseif (t.Kind=="Comment" or t.Kind=="ProcessingInstruction") then c:comment(t); return true
		elseif tag(t,"StartTag","html") then return c.BodyToken(c,t)
		elseif t.Kind=="EndTag" and t.Name~="head" and t.Name~="body" and t.Name~="html" and t.Name~="br" then return true end
		c.Document.Head=if tag(t,"StartTag","head") then c:insert(t) else c:synthetic("head")
		c.Mode="head"; return tag(t,"StartTag","head")
	elseif mode=="head" then
		if white(t) then c:text(t.Text); return true elseif (t.Kind=="Comment" or t.Kind=="ProcessingInstruction") then c:comment(t); return true
		elseif t.Kind=="Declaration" then return true elseif tag(t,"StartTag","html") then return c.BodyToken(c,t)
		elseif Head.metadata(c,t) then return true
		elseif tag(t,"StartTag","noscript") then c:insert(t); c.Mode="head-noscript"; return true
		elseif tag(t,"StartTag","head") then return true
		elseif tag(t,"EndTag","head") then c:pop(); c.Mode="after-head"; return true
		elseif t.Kind=="EndTag" and t.Name~="body" and t.Name~="html" and t.Name~="br" then return true end
		c:pop(); c.Mode="after-head"; return false
	elseif mode=="head-noscript" then
		if tag(t,"EndTag","noscript") then c:pop(); c.Mode="head"; return true end
		if white(t) then c:text(t.Text); return true end
		if t.Kind=="Comment" or t.Kind=="ProcessingInstruction" then c:comment(t); return true end
		if tag(t,"StartTag","html") then return c.BodyToken(c,t) end
		if t.Kind=="Declaration" then return true end
		if t.Kind=="StartTag" and ({basefont=true,bgsound=true,link=true,meta=true,noframes=true,style=true})[t.Name] then return Head.metadata(c,t) end
		if tag(t,"StartTag","head") or tag(t,"StartTag","noscript") or (t.Kind=="EndTag" and t.Name~="br") then return true end
		c:pop(); c.Mode="head"; return false
	elseif mode=="after-head" then
		if white(t) then c:text(t.Text); return true elseif (t.Kind=="Comment" or t.Kind=="ProcessingInstruction") then c:comment(t); return true
		elseif t.Kind=="Declaration" or tag(t,"StartTag","head") then return true
		elseif tag(t,"StartTag","html") then return c.BodyToken(c,t)
		elseif tag(t,"StartTag","body") then c.Document.Body=c:insert(t); c.FramesetOK=false; c.Mode="body"; return true
		elseif tag(t,"StartTag","frameset") then c.Document.Body=c:insert(t); c.Mode="frameset"; return true
		elseif tag(t,"EndTag","template") then return Head.metadata(c,t)
		elseif t.Kind=="StartTag" and ({base=true,basefont=true,bgsound=true,link=true,meta=true,noframes=true,script=true,style=true,template=true,title=true})[t.Name] then
			local head=c.Document.Head; c:push(head); Head.metadata(c,t); c:remove(head); return true
		elseif t.Kind=="EndTag" and t.Name~="body" and t.Name~="html" and t.Name~="br" then return true end
		c.Document.Body=c:synthetic("body"); c.FramesetOK=true; c.Mode="body"; return false
	elseif mode=="after-body" or mode=="after-after-body" then
		if white(t) or tag(t,"StartTag","html") then return c.BodyToken(c,t)
		elseif (t.Kind=="Comment" or t.Kind=="ProcessingInstruction") then c:comment(t,if mode=="after-body" then c.Document.DocumentElement else c.Document); return true
		elseif t.Kind=="Declaration" or t.Kind=="EOF" then return true
		elseif tag(t,"EndTag","html") and mode=="after-body" then c.Mode="after-after-body"; return true end
		c.Mode="body"; return false
	elseif mode=="frameset" or mode=="after-frameset" or mode=="after-after-frameset" then
		if t.Kind=="Text" then c:text((t.Text:gsub("[^\t\n\f\r ]",""))); return true end
		if white(t) then c:text(t.Text); return true elseif (t.Kind=="Comment" or t.Kind=="ProcessingInstruction") then c:comment(t,if mode=="after-after-frameset" then c.Document else nil); return true
		elseif tag(t,"StartTag","html") then return c.BodyToken(c,t)
		elseif tag(t,"StartTag","noframes") then return Head.metadata(c,t)
		elseif tag(t,"StartTag","frameset") and mode=="frameset" then c:insert(t)
		elseif tag(t,"StartTag","frame") and mode=="frameset" then c:insert(t,nil,false)
		elseif tag(t,"EndTag","frameset") and mode=="frameset" and c:current().Name~="html" then c:pop(); if c:current().Name~="frameset" then c.Mode="after-frameset" end
		elseif tag(t,"EndTag","html") and mode=="after-frameset" then c.Mode="after-after-frameset" end
		return true
	end
	return false
end
return Head
