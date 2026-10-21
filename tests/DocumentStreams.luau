--!strict
return function(Parser,Runtime,Events,fixtures,ordering,Tokenizer)
	-- An insertion boundary must never borrow a closing delimiter from later
	-- stored source. Include delimiters spanning the bounded scanner's chunks.
	for _,item in {
		{Source='<!DOCTYPE html>',Kind='Declaration'},
		{Source='<?check '..string.rep('x',515)..'?>',Kind='ProcessingInstruction'},
		{Source='</!'..string.rep('x',515)..'>',Kind='Comment'},
		{Source='<!--'..string.rep('x',515)..'-->',Kind='Comment'},
		{Source='<![CDATA['..string.rep('x',255)..']]>',Kind='Text'},
		{Source='<![CDATA['..string.rep('x>',256)..']]>',Kind='Text'},
	}do
		local warnings={};local tokenizer=Tokenizer.new(item.Source,function(...)table.insert(warnings,{...})end);tokenizer.AllowCDATA=true
		for boundary=1,#item.Source do
			local token=tokenizer:nextIncremental(false,boundary)
			assert(token==nil and tokenizer.Position==1 and tokenizer.Source==item.Source,'An incomplete token preserves its source and starting position')
			assert(#warnings==0,'An incomplete input segment cannot publish provisional warnings')
		end
		local token=tokenizer:nextIncremental(false,#item.Source+1)
		assert(token and token.Kind==(item.Kind or 'Text')and tokenizer.Source==item.Source,'A complete delimiter is recognized across bounded scan chunks')
	end
	local tokenizer=Tokenizer.new('<i title="&amp;">&amp;</i>',function()end)
	assert(tokenizer:nextIncremental(false).Attributes.title=='&','Attribute entity decoding is unchanged by the bounded token prefix')
	assert(tokenizer:nextIncremental(false).Text=='&'and tokenizer:nextIncremental(false).Kind=='EndTag')
	local function run(fixture,source)
		local output={};local events=Events.new(error);local clock=0;local realm
		local parser=Parser.newDocument(source,{ScriptingEnabled=true});local first=parser:Advance()
		realm=Runtime.new(parser.Document,{URL='https://scripts.test/index.html',Events=events,Clock=function()return clock end,
			Schedule=function()end,ApplyChanges=function()return false end,Console=function(_,value)table.insert(output,value)end,
			ParserSession=parser,ParserFirstScript=first,
			LoadScript=function(url,complete)
				local resource=fixture.resources and fixture.resources[url];local cancelled=false
				if not resource then complete(false,'Missing resource '..url);return end
				local id=realm.EventLoop.Methods.setTimeout({function()if not cancelled then complete(true,{Source=resource.Source,MIME=resource.MIME or 'text/javascript'})end end,resource.Delay or 0})
				return function()cancelled=true;realm.EventLoop.Methods.clearTimeout({id})end
			end})
		realm:Start()
		for _=1,120 do clock+=.001;realm:PumpTasks();realm.EventLoop:Checkpoint()end
		assert(#realm.Diagnostics==0,fixture.name..': '..table.concat(realm.Diagnostics,'\n'))
		assert(#output==#fixture.expected,fixture.name..': ['..table.concat(output,' | ')..'] expected ['..table.concat(fixture.expected,' | ')..']')
		for index,value in output do assert(value==fixture.expected[index],fixture.name..': ['..table.concat(output,' | ')..'] expected ['..table.concat(fixture.expected,' | ')..']')end
		realm:Destroy();events:Destroy();assert(not parser.Alive,'Parser must release retained source on realm destruction')
	end
	for _,fixture in fixtures do run(fixture,fixture.html)end
	local prefix="<script>document.addEventListener('DOMContentLoaded',()=>console.log('dcl',document.readyState));window.addEventListener('load',()=>console.log('load',document.readyState));</script>"
	for _,fixture in ordering do run(fixture,'<!doctype html><html><body>'..prefix..fixture.html..'</body></html>')end
	print('Live document streams: '..#fixtures..' native write/replacement and '..#ordering..' shared script ordering references passed')
end
