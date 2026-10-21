--!strict
local Head=require(script.Parent.DocumentHead)
local Body=require(script.Parent.DocumentBody)
local Tables={}
local tableContext={table=true,template=true,html=true}
local sectionContext={tbody=true,tfoot=true,thead=true,template=true,html=true}
local rowContext={tr=true,template=true,html=true}
local sections={tbody=true,tfoot=true,thead=true}
local cells={td=true,th=true}
local structural={caption=true,col=true,colgroup=true,tbody=true,td=true,tfoot=true,th=true,thead=true,tr=true}
local function endCell(c: any)
	c:implied(); local name=if c:inScope("td","table") then "td" else "th"; c:close(name); c:clearMarker(); c.Mode="row"
end
local function foster(c: any,t: any): boolean
	local previous=c.Foster; c.Foster=true; local result=Body.process(c,t); c.Foster=previous; return result
end
function Tables.process(c: any,t: any): boolean
	local mode,n,start,finish=c.Mode,t.Name,t.Kind=="StartTag",t.Kind=="EndTag"
	if mode=="template" then
		if t.Kind=="Text" or (t.Kind=="Comment" or t.Kind=="ProcessingInstruction") or t.Kind=="Declaration" then return Body.process(c,t) end
		if Head.metadata(c,t) then return true end
		if finish then return true end
		local nextMode=if start and (n=="caption" or n=="colgroup" or sections[n]) then "table"
			elseif start and n=="col" then "colgroup" elseif start and n=="tr" then "table-body"
			elseif start and cells[n] then "row" else "body"
		c.Templates[#c.Templates]=nextMode; c.Mode=nextMode; return false
	elseif mode=="cell" then
		if finish and cells[n] then if c:inScope(n,"table") then c:implied(); c:close(n); c:clearMarker(); c.Mode="row" end; return true end
		if (start and structural[n]) or (finish and (n=="table" or n=="tr" or sections[n])) then
			if (start and (c:inScope("td","table") or c:inScope("th","table"))) or (finish and c:inScope(n,"table")) then endCell(c); return false end
			return true
		end
		if finish and (n=="body" or n=="caption" or n=="col" or n=="colgroup" or n=="html") then return true end
		return Body.process(c,t)
	elseif mode=="caption" then
		if (finish and n=="caption") or (start and structural[n]) or (finish and n=="table") then
			if c:inScope("caption","table") then c:implied(); c:close("caption"); c:clearMarker(); c.Mode="table"; return finish and n=="caption" end
			return true
		end
		if finish and (n=="body" or n=="col" or n=="colgroup" or n=="html" or sections[n] or cells[n] or n=="tr") then return true end
		return Body.process(c,t)
	elseif mode=="colgroup" then
		if t.Kind=="Text" and not t.Text:find("[^\t\n\f\r ]") then c:text(t.Text); return true
		elseif (t.Kind=="Comment" or t.Kind=="ProcessingInstruction") then c:comment(t); return true elseif t.Kind=="Declaration" then return true
		elseif start and n=="html" then return Body.process(c,t)
		elseif start and n=="col" then c:insert(t,nil,false); return true
		elseif Head.metadata(c,t) then return true
		elseif finish and n=="col" then return true end
		if c:current().Name~="colgroup" then return true end
		c:pop(); c.Mode="table"; return finish and n=="colgroup"
	elseif mode=="row" then
		if start and cells[n] then c:clearTo(rowContext); c:insert(t); c.Mode="cell"; c:marker(); return true end
		if (finish and n=="tr") or (start and (n=="caption" or n=="col" or n=="colgroup" or sections[n] or n=="tr")) or (finish and (n=="table" or sections[n])) then
			if not c:inScope("tr","table") or (finish and sections[n] and not c:inScope(n,"table")) then return true end
			c:clearTo(rowContext); c:pop(); c.Mode="table-body"; return finish and n=="tr"
		end
		if finish and (n=="body" or n=="caption" or n=="col" or n=="colgroup" or n=="html" or cells[n]) then return true end
	elseif mode=="table-body" then
		if start and n=="tr" then c:clearTo(sectionContext); c:insert(t); c.Mode="row"; return true
		elseif start and cells[n] then c:clearTo(sectionContext); c:synthetic("tr"); c.Mode="row"; return false
		elseif finish and sections[n] then if c:inScope(n,"table") then c:clearTo(sectionContext); c:pop(); c.Mode="table" end; return true
		elseif (start and (n=="caption" or n=="col" or n=="colgroup" or sections[n])) or (finish and n=="table") then
			if not c:inScope("tbody","table") and not c:inScope("thead","table") and not c:inScope("tfoot","table") then return true end
			c:clearTo(sectionContext); c:pop(); c.Mode="table"; return false
		elseif finish and (n=="body" or n=="caption" or n=="col" or n=="colgroup" or n=="html" or cells[n] or n=="tr") then return true end
	end
	-- The remaining row/section cases use the in-table rules.
	if ((start and (n=="caption" or n=="table" or n=="tbody" or n=="tfoot" or n=="thead" or n=="tr" or cells[n]))
		or (finish and (n=="table" or n=="tbody" or n=="tfoot" or n=="thead" or n=="tr" or cells[n]))) and c:inScope("select") then
		c:close("select"); c:resetMode(); return false
	end
	if t.Kind=="Text" and ({table=true,tbody=true,tfoot=true,thead=true,tr=true})[c:current().Name] then
		if not t.Text:find("[^\t\n\f\r ]") then c:text(t.Text); return true end
		return foster(c,t)
	elseif (t.Kind=="Comment" or t.Kind=="ProcessingInstruction") then c:comment(t); return true elseif t.Kind=="Declaration" then return true end
	if start then
		if n=="caption" then c:clearTo(tableContext); c:marker(); c:insert(t); c.Mode="caption"; return true
		elseif n=="colgroup" then c:clearTo(tableContext); c:insert(t); c.Mode="colgroup"; return true
		elseif n=="col" then c:clearTo(tableContext); c:synthetic("colgroup"); c.Mode="colgroup"; return false
		elseif sections[n] then c:clearTo(tableContext); c:insert(t); c.Mode="table-body"; return true
		elseif cells[n] or n=="tr" then c:clearTo(tableContext); c:synthetic("tbody"); c.Mode="table-body"; return false
		elseif n=="table" then if c:inScope("table","table") then c:close("table"); c:resetMode(); return false end; return true
		elseif n=="style" or n=="script" or n=="template" then return Head.metadata(c,t)
		elseif n=="input" and (t.Attributes.type or ""):lower()=="hidden" then c:insert(t,nil,false); return true
		elseif n=="form" then
			if not c.Form or #c.Templates>0 then local form=c:insert(t,nil,false); if #c.Templates==0 then c.Form=form end end
			return true
		end
	elseif finish then
		if n=="table" then if c:inScope("table","table") then c:close("table"); c:resetMode() end; return true
		elseif n=="template" then return Head.metadata(c,t)
		elseif n=="body" or n=="caption" or n=="col" or n=="colgroup" or n=="html" or sections[n] or cells[n] or n=="tr" then return true end
	end
	return foster(c,t)
end
return Tables
