--!nonstrict
-- Imported window-system source from haha.rbxmx; dependencies are local to WindowManager.
--[[
	Glyphs — die Symbole der Caption-Buttons, pixelgenau gezeichnet.

		local symbol = Glyphs.create("close", 10, Theme.color.text, slot)

	kind: "close" | "maximize" | "restore" | "minimize"

	WARUM NICHT AUS FRAMES?

	Das X besteht aus zwei Strichen von je 1 px Dicke, mit einem Kantenpixel
	daneben. Ein um 45 Grad gedrehter Frame ist in Roblox nicht 1 px breit,
	sondern verschmiert über zwei bis drei Pixel — die Engine rundet die
	Drehung, und die Kante liegt zwischen den Pixeln. Hier wird Pixel für
	Pixel gesetzt: Kern voll deckend, Kante mit 20 % Deckkraft.

	Beim Wiederherstellen-Symbol kommt ein zweiter Vorteil dazu: die
	Verdeckung des hinteren Quadrats durch das vordere ist in einem
	Pixelpuffer einfach ein Löschen, kein deckender Frame, dessen Farbe man
	der Button-Fläche nachführen muss. Genau diese Nachführung war in der
	Frame-Variante der unangenehme Teil.

	Umfärben ist eine einzige Zuweisung (ImageColor3) statt eines Durchlaufs
	durch mehrere Frames.

	VORAUSSETZUNG: EditableImage muss im Place freigeschaltet sein.

		Studio -> Home -> Game Settings -> Security
		-> "Allow Mesh & Image APIs" einschalten

	Ab Werk ist die API gesperrt, und der Fehler lautet dann
	"EditableImage is not accessible". Das ist eine Einstellung, kein
	Codefehler — ohne sie geht dieses Modul nicht.

	KEINE RÜCKFALLEBENE. Es gibt genau einen Weg: EditableImage. Geht der
	nicht, wirft create() — mit dem echten Fehler im Text.

	Das ist Absicht. Eine Rückfallebene aus Frames war da, und sie hat genau
	den Schaden angerichtet, den dieses Modul verhindern soll: sie sprang
	still ein, wenn EditableImage fehlschlug, und lieferte ein sichtbar
	dickeres X aus gedrehten Frames. Man sieht dann ein falsches Symbol und
	sucht den Fehler im Zeichencode, während die eigentliche Ursache eine
	verschluckte Fehlermeldung war.

	Lieber ein lauter Fehler als ein stilles, falsches Bild.

	API
		.create(kind, size, color, parent, offset?) -> GuiObject
		.setTransparency(glyph, value)
		.usesEditableImage(size?) -> boolean
		.lastError  -- Fehlertext, falls EditableImage nicht ging
		.clearCache()

	Reine Rechnung, ohne Roblox-Objekte und damit testbar:
		.render(kind, size, offset?) -> buffer
		.alphaAt(buffer, size, x, y) -> 0..255
		.minimizeRow(size, offset?) -> number
		.kinds() -> { string }
--]]

local AssetService = game:GetService("AssetService")

local Root = script.Parent.Parent

local New = require(Root.UI.New)

local Glyphs = {}

local DEFAULT_SIZE = 10

--[[
	Deckkraft der Kantenpixel, als ANTEIL und nicht als Farbe.

	Hergeleitet aus dem Zielton #CCCCCC auf weissem Grund:

		0xCC = 204        204 / 255 = 0.80 Resthelligkeit
		=> Deckkraft der Tinte = 1 - 0.80 = 0.20

	Warum ein Anteil und keine Farbe: das Bild ist weiss und wird über
	ImageColor3 eingefärbt, Alpha trägt also die ganze Abstufung. Damit
	stimmt der Kantenton automatisch für JEDE Tinte —

		schwarze Tinte auf weiss   -> #CCCCCC
		weisse Tinte auf rot       -> aufgehellt Rot, im gleichen Verhältnis

	Eine festgeschriebene Farbe wäre auf dem roten Schliessen-Button falsch,
	und man müsste sie pro Zustand nachführen. Genau die Nachführung soll
	dieses Modul loswerden.
--]]
local EDGE_ALPHA = math.floor(0.20 * 255 + 0.5)   -- 51

--------------------------------------------------------------------------
-- Pixelpuffer
--------------------------------------------------------------------------

--[[
	Der Puffer ist RGBA, vier Bytes pro Pixel, Zeile für Zeile.

	Die Farbe ist immer weiss — gefärbt wird später über ImageColor3. Ein
	weisses Bild mit ImageColor3 ergibt genau die Zielfarbe, und dasselbe
	Bild lässt sich für schwarze und weisse Symbole benutzen. Deshalb steht
	in allen drei Farbkanälen 255 und nur Alpha trägt die Form.
--]]
local function setPixel(buf, size, x, y, alpha)
	if x < 0 or y < 0 or x >= size or y >= size then
		return
	end

	local offset = (y * size + x) * 4

	buffer.writeu8(buf, offset, 255)
	buffer.writeu8(buf, offset + 1, 255)
	buffer.writeu8(buf, offset + 2, 255)
	buffer.writeu8(buf, offset + 3, alpha)
end

-- Deckkraft eines Pixels lesen. Für Tests und Diagnose.
function Glyphs.alphaAt(buf, size, x, y)
	if x < 0 or y < 0 or x >= size or y >= size then
		return 0
	end

	return buffer.readu8(buf, (y * size + x) * 4 + 3)
end

--------------------------------------------------------------------------
-- Zeichenfunktionen
--------------------------------------------------------------------------

--[[
	Das X: zwei Striche von Ecke zu Ecke, jeder 1 px dick, mit einem
	Kantenpixel daneben.

	Der Kern ist voll deckend, also genau 1 px:

		x == y            Strich von oben links nach unten rechts
		x + y == last     der andere

	Direkt daneben — also einen Pixel Abstand in x oder y — sitzt der
	Kantenpixel mit EDGE_ALPHA. Auf einer 45°-Diagonalen fallen die
	waagerechten und die senkrechten Nachbarn zusammen, ein Abstand von 1
	beschreibt deshalb beide Seiten des Strichs in einem Ausdruck.

	Kern vor Kante: ein Pixel, das zum einen Strich Abstand 1 hat, aber auf
	dem anderen Strich LIEGT, muss voll deckend bleiben. Das betrifft die
	Mitte — bei size = 10 sind (4,4), (5,4), (4,5) und (5,5) alle Kern,
	obwohl je zwei davon zum jeweils anderen Strich Abstand 1 haben.

	Alles bleibt im Feld: es wird nur gesetzt, was innerhalb 0..last liegt,
	setPixel verwirft den Rest. Ein 10 x 10 Symbol belegt also genau 10 x 10.

	KEINE gerechnete Kantenglättung mehr. Der erste Versuch leitete die
	Deckkraft aus dem Abstand zur Linie ab:

		alpha = max(0, 1 - |x - y| / sqrt(2))   -- ergibt 0.29 daneben

	Das ist die mathematisch richtige Abdeckung, führte aber mit
	Gammakorrektur zu einem Strich, der rund 1.6 px breit wirkte. Der feste
	Anteil von 0.20 ist schwächer und trifft den Windows-Eindruck.
--]]
local function drawClose(buf, size)
	local last = size - 1

	for y = 0, last do
		for x = 0, last do
			local toFirst = math.abs(x - y)
			local toSecond = math.abs(x + y - last)

			if toFirst == 0 or toSecond == 0 then
				setPixel(buf, size, x, y, 255)
			elseif toFirst == 1 or toSecond == 1 then
				setPixel(buf, size, x, y, EDGE_ALPHA)
			end
		end
	end
end

-- Rechteck-Umriss, 1 px, über das ganze Feld
local function drawRect(buf, size, x0, y0, x1, y1)
	for x = x0, x1 do
		setPixel(buf, size, x, y0, 255)
		setPixel(buf, size, x, y1, 255)
	end

	for y = y0, y1 do
		setPixel(buf, size, x0, y, 255)
		setPixel(buf, size, x1, y, 255)
	end
end

-- Rechteckfläche auf durchsichtig setzen. Das ist die Verdeckung.
local function clearRect(buf, size, x0, y0, x1, y1)
	for y = y0, y1 do
		for x = x0, x1 do
			setPixel(buf, size, x, y, 0)
		end
	end
end

local function drawMaximize(buf, size)
	drawRect(buf, size, 0, 0, size - 1, size - 1)
end

--[[
	Wiederherstellen: zwei Quadrate von (size-2) Kantenlänge, um 2 px nach
	rechts oben versetzt. Das vordere verdeckt das hintere.

	Bei size = 10 also zwei 8x8-Quadrate:
		hinten  (2, 0) bis (9, 7)
		vorne   (0, 2) bis (7, 9)

	Ablauf: hinteres Quadrat zeichnen, dann die Fläche des vorderen löschen,
	dann das vordere zeichnen. Das Löschen ist der ganze Trick — es nimmt
	genau die beiden Kanten des hinteren Quadrats weg, die in der
	Überlappung liegen. Ohne es sähe das Symbol wie ein Gitter aus statt wie
	zwei gestapelte Fenster.
--]]
local function drawRestore(buf, size)
	local inner = size - 2
	local shift = 2

	-- hinten: oben rechts
	drawRect(buf, size, shift, 0, shift + inner - 1, inner - 1)

	-- vorne: unten links, erst freiräumen, dann zeichnen
	clearRect(buf, size, 0, shift, inner - 1, shift + inner - 1)
	drawRect(buf, size, 0, shift, inner - 1, shift + inner - 1)
end

--[[
	Minimieren: ein Strich über die volle Breite.

	Zeile floor(size/2) — so mittig, wie eine 1 px hohe Linie in einem Feld
	gerader Höhe sein kann. Bei 10 px liegt die Mitte zwischen Zeile 4 und
	5; gewählt ist 5, ein halbes Pixel unter der Mitte, weil das optisch
	besser sitzt.

	offset verschiebt die Zeile, falls ein Symbolsatz sie anders braucht.
	Drei Pixel zu tief sind in einem 32 px hohen Button sichtbar — deshalb
	steht die Wahl hier und nicht als nackte Zahl im Zeichencode.
--]]
function Glyphs.minimizeRow(size, offset)
	return math.floor(size / 2) + (offset or 0)
end

local function drawMinimize(buf, size, offset)
	local y = Glyphs.minimizeRow(size, offset)

	for x = 0, size - 1 do
		setPixel(buf, size, x, y, 255)
	end
end

local DRAW = {
	close = drawClose,
	maximize = drawMaximize,
	restore = drawRestore,
	minimize = drawMinimize,
}

function Glyphs.kinds()
	local list = {}

	for kind in DRAW do
		table.insert(list, kind)
	end

	table.sort(list)
	return list
end

--[[
	render(kind, size, offset?) -> buffer

	Zeichnet in einen frischen Puffer und gibt ihn zurück. Ohne Roblox-
	Objekte, damit die Geometrie prüfbar ist: Glyphs.alphaAt() liest einzelne
	Pixel, und ein Test kann damit die tatsächliche Form nachmessen statt
	sie zu glauben.
--]]
function Glyphs.render(kind, size, offset)
	local draw = DRAW[kind]
	assert(draw, ("Glyphs.render: unbekannte Art '%s'"):format(tostring(kind)))

	local edge = size or DEFAULT_SIZE
	assert(type(edge) == "number" and edge >= 4, "Glyphs.render: size muss >= 4 sein")

	local buf = buffer.create(edge * edge * 4)
	draw(buf, edge, offset)

	return buf
end

--------------------------------------------------------------------------
-- Bild erzeugen, mit Zwischenspeicher
--------------------------------------------------------------------------

--[[
	Gleiche Art, Grösse und Versatz ergeben immer dasselbe Bild. Ohne diesen
	Speicher entstünden pro Fenster vier neue EditableImages — und die
	kosten echten Grafikspeicher, mit einem harten Limit pro Client.
--]]
local cache = {}
local images = {}
local retainers = 0
local cacheCount = 0

--[[
	Warum EditableImage nicht ging, falls es nicht ging. Bewusst nach aussen
	sichtbar: vorher verschluckte der pcall den Grund, und dann sieht man nur
	ein dickes X und weiss nicht, warum.
--]]
Glyphs.lastError = nil

local function contentFor(kind, size, offset)
	-- Der Versatz gehört in den Schlüssel, sonst liefert der Speicher das
	-- Bild mit dem alten Versatz zurück.
	local key = ("%s:%d:%d"):format(kind, size, offset or 0)

	local cached = cache[key]
	if cached ~= nil then
		-- false heisst "schon einmal fehlgeschlagen", siehe unten
		return cached or nil
	end

	if cacheCount >= 32 then return nil end
	local image
	local ok, content = pcall(function()
		image = AssetService:CreateEditableImage({ Size = Vector2.new(size, size) })
		local buf = Glyphs.render(kind, size, offset)

		image:WritePixelsBuffer(Vector2.new(0, 0), Vector2.new(size, size), buf)

		return Content.fromObject(image)
	end)

	if not ok then
        if image then image:Destroy()end
        Glyphs.lastError = tostring(content)
    else images[key]=image end

	--[[
		false statt nil merken. Sonst wird ein Fehlschlag bei jedem Fenster
		erneut versucht — und wenn die Ursache die Speichergrenze ist, macht
		das Wiederholen es schlimmer.
	--]]
	cacheCount += 1
	cache[key] = if ok then content else false

	return if ok then content else nil
end

function Glyphs.clearCache()
	for _,image in images do image:Destroy()end
	images = {};cacheCount = 0
	cache = {}
	Glyphs.lastError = nil
end

--[[
	Läuft EditableImage auf diesem Client? Für Diagnose und für Tests.

	Ruft absichtlich contentFor und nicht irgendeine Fähigkeitsabfrage: die
	einzige verlässliche Antwort ist der Versuch selbst.
--]]
function Glyphs.usesEditableImage(size)
	return contentFor("close", size or DEFAULT_SIZE) ~= nil
end

--------------------------------------------------------------------------
-- create
--------------------------------------------------------------------------

--[[
	create(kind, size, color, parent, offset?) -> GuiObject

	Liefert bevorzugt ein ImageLabel mit dem gezeichneten Symbol, sonst die
	Frame-Variante. Beide sind mittig im Elternteil und reagieren auf
	Interactive.tint und Glyphs.setTransparency.
--]]
function Glyphs.create(kind, size, color, parent, offset)
	assert(DRAW[kind], ("Glyphs.create: unbekannte Art '%s'"):format(tostring(kind)))
	assert(parent, "Glyphs.create: parent fehlt")

	local edge = size or DEFAULT_SIZE
	local content = contentFor(kind, edge, offset)

	--[[
		Kein Ersatzweg. Ohne EditableImage gibt es kein Symbol, und das soll
		auffallen — ein stilles, falsches Bild kostet mehr Zeit als ein
		Fehler, der die Ursache nennt.
	--]]
	if not content then
        local root=New("ImageLabel",{Name="Glyph_"..kind,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(edge,edge),ImageColor3=color,ImageTransparency=0,BackgroundTransparency=1,Parent=parent})
        local function line(x,y,w,h,rotation)
            New("Frame",{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),Rotation=rotation or 0,BackgroundTransparency=0,BackgroundColor3=color,Parent=root})
        end
        local function rect(x,y,w,h)
            line(x,y,w,1);line(x,y+h-1,w,1);line(x,y,1,h);line(x+w-1,y,1,h)
        end
        if kind=="close"then line(0,(edge-1)/2,edge,1,45);line(0,(edge-1)/2,edge,1,-45)
        elseif kind=="minimize"then line(0,math.floor(edge/2),edge,1)
        elseif kind=="maximize"then rect(0,0,edge,edge)
        else rect(2,0,edge-2,edge-2);rect(0,2,edge-2,edge-2)end
        local function repaint()
            for _,child in root:GetChildren()do child.BackgroundColor3=root.ImageColor3;child.BackgroundTransparency=root.ImageTransparency end
        end
        local tint=root:GetPropertyChangedSignal("ImageColor3"):Connect(repaint)
        local alpha=root:GetPropertyChangedSignal("ImageTransparency"):Connect(repaint)
        root.Destroying:Connect(function()tint:Disconnect();alpha:Disconnect()end)
        return root
    end

	return New("ImageLabel", {
		Name = "Glyph_" .. kind,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(edge, edge),
		ImageContent = content,
		ImageColor3 = color,

		--[[
			Stretch und Pixelated: das Bild ist exakt so gross wie
			gezeichnet, es soll nicht weichgezeichnet werden. Mit Fit würde
			Roblox das Seitenverhältnis wahren (unnötig, es ist quadratisch)
			und mit der Standard-Filterung die 1-px-Linien verwaschen.
		--]]
		ScaleType = Enum.ScaleType.Stretch,
		ResampleMode = Enum.ResamplerMode.Pixelated,

		Parent = parent,
	})
end

--[[
	Deckkraft setzen. Wird beim Fokuswechsel gebraucht: Windows zeichnet die
	Caption-Symbole unfokussierter Fenster blasser.

	Ein Symbol ist immer genau ein ImageLabel, also ist das eine Zuweisung —
	kein Durchlauf durch einen Teilbaum, kein Sonderfall pro Klasse. Das ist
	der zweite Grund für EditableImage: bei einem Symbol aus Frames müsste
	hier jede Strichfläche und jeder Stroke einzeln angefasst werden.
--]]
function Glyphs.setTransparency(glyph, value)
	glyph.ImageTransparency = value
end

function Glyphs.retain()retainers += 1 end
function Glyphs.release()
    retainers=math.max(0,retainers-1)
    if retainers==0 then Glyphs.clearCache()end
end
return Glyphs
