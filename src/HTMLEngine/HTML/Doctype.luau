--!strict
local WorkContext=require(script.Parent.Parent.WorkContext)
local Doctype={}
local function space(ch: string): boolean return ch==" " or ch=="\t" or ch=="\n" or ch=="\r" or ch=="\f" end
-- Runs from the character following DOCTYPE. EOF and abrupt quoted identifiers
-- emit the partially accumulated token; bogus tails preserve its force flag.
function Doctype.scan(source: string,start: number,warn: any): (any,number)
	local token={Name="",ForceQuirks=false}; local position,state=start,"before-name"
	local pieces,quote={},nil
	local function problem(code: string,force: boolean?)
		if force then token.ForceQuirks=true end
		warn(code,"Malformed HTML doctype",position)
	end
	local function finishField()
		local value=table.concat(pieces); pieces={}
		if state=="name" then token.Name=value:lower() elseif state=="public" then token.PublicId=value else token.SystemId=value end
	end
	if position<=#source and not space(source:sub(position,position)) and source:sub(position,position)~='>' then problem("missing-whitespace-before-doctype-name") end
	while true do
		if position%256==0 then WorkContext.checkpoint() end
		local ch=source:sub(position,position); local again=false
		if ch=="" then
			if state=="name" or state=="public" or state=="system" then finishField() end
			if state~="bogus" then problem("eof-in-doctype",true) end
			return token,#source+1
		elseif state=="before-name" then
			if space(ch) then
			elseif ch==">" then problem("missing-doctype-name",true); return token,position+1
			else state="name"; again=true end
		elseif state=="name" then
			if space(ch) or ch==">" then finishField(); state="after-name"; again=true
			else if ch=="\0" then problem("unexpected-null-character"); ch=utf8.char(0xFFFD) end; table.insert(pieces,ch) end
		elseif state=="after-name" then
			if space(ch) then
			elseif ch==">" then return token,position+1
			else
				local keyword=source:sub(position,position+5):lower()
				if keyword=="public" or keyword=="system" then position+=6; state="before-"..keyword; again=true
					if not space(source:sub(position,position)) and (source:sub(position,position)=='"' or source:sub(position,position)=="'") then problem("missing-whitespace-after-doctype-"..keyword.."-keyword") end
				else problem("invalid-character-sequence-after-doctype-name",true); state="bogus"; again=true end
			end
		elseif state=="before-public" or state=="before-system" then
			local field=state:sub(8)
			if space(ch) then
			elseif ch=='"' or ch=="'" then quote=ch; state=field; token[if field=="public" then "PublicId" else "SystemId"]=""
			elseif ch==">" then problem("missing-doctype-"..field.."-identifier",true); return token,position+1
			else problem("missing-quote-before-doctype-"..field.."-identifier",true); state="bogus"; again=true end
		elseif state=="public" or state=="system" then
			if ch==quote then local field=state; finishField(); state="after-"..field
			elseif ch==">" then local field=state; finishField(); problem("abrupt-doctype-"..field.."-identifier",true); return token,position+1
			else if ch=="\0" then problem("unexpected-null-character"); ch=utf8.char(0xFFFD) end; table.insert(pieces,ch) end
		elseif state=="after-public" then
			if space(ch) then state="between-identifiers"
			elseif ch==">" then return token,position+1
			elseif ch=='"' or ch=="'" then problem("missing-whitespace-between-doctype-public-and-system-identifiers"); quote=ch; token.SystemId=""; state="system"
			else problem("missing-quote-before-doctype-system-identifier",true); state="bogus"; again=true end
		elseif state=="between-identifiers" then
			if space(ch) then
			elseif ch==">" then return token,position+1
			elseif ch=='"' or ch=="'" then quote=ch; token.SystemId=""; state="system"
			else problem("missing-quote-before-doctype-system-identifier",true); state="bogus"; again=true end
		elseif state=="after-system" then
			if space(ch) then
			elseif ch==">" then return token,position+1
			else problem("unexpected-character-after-doctype-system-identifier"); state="bogus"; again=true end
		elseif state=="bogus" then if ch==">" then return token,position+1 end end
		if not again then position+=1 end
	end
end
function Doctype.mode(token: any): string
	if token.ForceQuirks or token.Name~="html"then return "quirks"end
	local public=(token.PublicId or""):lower();local system=(token.SystemId or""):lower()
	if system=="http://www.ibm.com/data/dtd/v11/ibmxhtml1-transitional.dtd"or public=="html"or public=="-//w3o//dtd w3 html strict 3.0//en//"or public=="-/w3c/dtd html 4.0 transitional/en"then return "quirks"end
	local oldPrefixes={
		"+//silmaril//dtd html pro v0r11 19970101//","-//as//dtd html 3.0 aswedit + extensions//","-//advasoft ltd//dtd html 3.0 aswedit + extensions//",
		"-//ietf//dtd html 2.0 level 1//","-//ietf//dtd html 2.0 level 2//","-//ietf//dtd html 2.0 strict level 1//","-//ietf//dtd html 2.0 strict level 2//","-//ietf//dtd html 2.0 strict//","-//ietf//dtd html 2.0//","-//ietf//dtd html 2.1e//","-//ietf//dtd html 3.0//","-//ietf//dtd html 3.2 final//","-//ietf//dtd html 3.2//","-//ietf//dtd html 3//","-//ietf//dtd html level 0//","-//ietf//dtd html level 1//","-//ietf//dtd html level 2//","-//ietf//dtd html level 3//","-//ietf//dtd html strict level 0//","-//ietf//dtd html strict level 1//","-//ietf//dtd html strict level 2//","-//ietf//dtd html strict level 3//","-//ietf//dtd html strict//","-//ietf//dtd html//",
		"-//metrius//dtd metrius presentational//","-//microsoft//dtd internet explorer 2.0 html strict//","-//microsoft//dtd internet explorer 2.0 html//","-//microsoft//dtd internet explorer 2.0 tables//","-//microsoft//dtd internet explorer 3.0 html strict//","-//microsoft//dtd internet explorer 3.0 html//","-//microsoft//dtd internet explorer 3.0 tables//",
		"-//netscape comm. corp.//dtd html//","-//netscape comm. corp.//dtd strict html//","-//o'reilly and associates//dtd html 2.0//","-//o'reilly and associates//dtd html extended 1.0//","-//o'reilly and associates//dtd html extended relaxed 1.0//","-//sq//dtd html 2.0 hotmetal + extensions//","-//softquad software//dtd hotmetal pro 6.0::19990601::extensions to html 4.0//","-//softquad//dtd hotmetal pro 4.0::19971010::extensions to html 4.0//","-//spyglass//dtd html 2.0 extended//","-//sun microsystems corp.//dtd hotjava html//","-//sun microsystems corp.//dtd hotjava strict html//",
		"-//w3c//dtd html 3 1995-03-24//","-//w3c//dtd html 3.2 draft//","-//w3c//dtd html 3.2 final//","-//w3c//dtd html 3.2//","-//w3c//dtd html 3.2s draft//","-//w3c//dtd html 4.0 frameset//","-//w3c//dtd html 4.0 transitional//","-//w3c//dtd html experimental 19960712//","-//w3c//dtd html experimental 970421//","-//w3c//dtd w3 html//","-//w3o//dtd w3 html 3.0//","-//webtechs//dtd mozilla html 2.0//","-//webtechs//dtd mozilla html//"
	}
	for _,prefix in oldPrefixes do if public:sub(1,#prefix)==prefix then return "quirks"end end
	local html4=false
	-- Current HTML rules treat both missing and empty HTML 4.01 system IDs as
	-- quirks; only a nonempty system ID selects limited quirks.
	for _,prefix in {"-//w3c//dtd html 4.01 frameset//","-//w3c//dtd html 4.01 transitional//"}do if public:sub(1,#prefix)==prefix then html4=true end end
	if html4 then return if system=="" then"quirks"else"limited-quirks"end
	for _,prefix in {"-//w3c//dtd xhtml 1.0 frameset//","-//w3c//dtd xhtml 1.0 transitional//"}do if public:sub(1,#prefix)==prefix then return "limited-quirks"end end
	return "no-quirks"
end
return Doctype
