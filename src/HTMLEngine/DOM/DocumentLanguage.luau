--!strict
local ElementNames=require(script.Parent.ElementNames)
-- Meta language is an insertion effect, not a live query over current metadata.
-- Removing or editing a processed pragma does not undo its document default.
local Work=require(script.Parent.Parent.WorkContext)
local Language={}
local function trim(value)return value:match('^[ \t\n\r\f]*(.-)[ \t\n\r\f]*$')end
function Language.configure(document,options)
	local header=options and options.ContentLanguage
	assert(header==nil or type(header)=='string','ContentLanguage must be a string')
	if header and not header:find(',',1,true)then
		header=trim(header);document.TransportLanguage=if header~=''then header else nil
	end
	document.ContentLanguage=document.PragmaLanguage or document.TransportLanguage
end
function Language.insert(node)
	if not ElementNames.html(node,'meta')then return nil end
	local attrs=node.Attributes
	if (attrs['http-equiv']or''):gsub('[A-Z]',string.lower)~='content-language'then return nil end
	local value=attrs.content;if not value or value:find(',',1,true)then return nil end
	local candidate=value:match('^[ \t\n\r\f]*([^ \t\n\r\f]+)');if not candidate then return nil end
	local document=node;while document.Parent do Work.checkpoint();document=document.Parent end
	if document.Kind~='Document'or document.IsHTML==false then return nil end
	document.PragmaLanguage=candidate
	if document.ContentLanguage==candidate then return nil end
	document.ContentLanguage=candidate;return document
end
function Language.inserted(additions,changed,step)
	local pending={};for i=#additions,1,-1 do table.insert(pending,additions[i])end
	while #pending>0 do
		if step then step()else Work.checkpoint()end
		local node=table.remove(pending);local document=Language.insert(node)
		if document and changed then changed(document)end
		-- Template contents and shadow trees do not belong to this document tree.
		for i=#node.Children,1,-1 do table.insert(pending,node.Children[i])end
	end
end
return Language
