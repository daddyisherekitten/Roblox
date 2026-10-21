--!strict
-- Component values keep function commas and comments out of query-list recovery.
local Syntax=require(script.Parent.Syntax)
local Work=require(script.Parent.Parent.WorkContext)
local MediaSyntax={}
local closing={['(']=')',['[']=']',['{']='}'}
local function number(source,index)
	local raw,after=source:match('^([+%-]?%d*%.%d+[eE][+%-]?%d+)()',index)
	if not raw then raw,after=source:match('^([+%-]?%d+[eE][+%-]?%d+)()',index)end
	return raw,after
end
function MediaSyntax.parse(source: string): any?
	if #source>65536 then return nil end
	local index,count=1,0
	local read
	read=function(stop,depth)
		if depth>32 then return nil end
		local out={}
		local previous=index-1
		while index<=#source do
			Work.checkpoint();local start=index;local char=source:sub(index,index)
			if stop and char==stop then index+=1;return out,true end
			if char:match('[ \t\n\r\f]')then index+=1;continue end
			if source:sub(index,index+1)=='/*'then index=(source:find('*/',index+2,true)or #source)+2;continue end
			count+=1;if count>8192 then return nil end
			local token
			if char=='"'or char=="'"then
				index+=1;local bad=false
				while index<=#source and source:sub(index,index)~=char do
					local c=source:sub(index,index)
					if c:match('[\n\r\f]')then bad=true;break end
					if c=='\\'then index+=1;if source:sub(index,index)=='\r'and source:sub(index+1,index+1)=='\n'then index+=1 end end
					index+=1
				end
				if source:sub(index,index)==char then index+=1 end
				token={Kind=if bad then 'bad'else 'string'}
			else
				local raw,after=number(source,index)
				if not raw then raw,after=source:match('^([+%-]?%d*%.%d+)()',index)end
				if not raw then raw,after=source:match('^([+%-]?%d+)()',index)end
				if raw then
					index=after;local unit,finish=Syntax.identifier(source,index)
					token={Kind='number',Value=tonumber(raw),Integer=not raw:find('[%.eE]')}
					if unit then token.Kind,token.Unit,index='dimension',unit:lower(),finish
					elseif source:sub(index,index)=='%'then token.Kind='percentage';index+=1 end
				else
					local name,finish=Syntax.identifier(source,index)
					if name then
						index=finish;token={Kind='ident',Value=name:lower(),Decoded=name}
						if source:sub(index,index)=='('then
							index+=1;local items,closed=read(')',depth+1);if not items then return nil end
							token.Kind,token.Items,token.Closed='function',items,closed
						end
					elseif closing[char]then
						index+=1;local items,closed=read(closing[char],depth+1);if not items then return nil end
						token={Kind='block',Open=char,Items=items,Closed=closed}
					else
						index+=1;local value=char
						if (char=='<'or char=='>')and source:sub(index,index)=='='then index+=1;value..='='end
						token={Kind=if char==')'or char==']'or char=='}'then 'bad'else 'delim',Value=value}
					end
				end
			end
			token.Raw=source:sub(start,index-1)
			token.Start,token.After=start,index
			token.Space=source:sub(previous+1,start-1):find('[ \t\n\r\f]')~=nil
			previous=index-1
			table.insert(out,token)
		end
		return out,false
	end
	return read(nil,0)
end
function MediaSyntax.parts(tokens): any
	local result,current={},{}
	for _,token in tokens do
		if token.Kind=='delim'and token.Value==','then table.insert(result,current);current={}else table.insert(current,token)end
	end
	table.insert(result,current);return result
end
function MediaSyntax.raw(tokens): string
	local parts={};for _,token in tokens do table.insert(parts,token.Raw)end;return table.concat(parts,' ')
end
return MediaSyntax
