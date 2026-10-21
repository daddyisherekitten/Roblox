--!nonstrict
-- Imported window-system source from haha.rbxmx; dependencies are local to WindowManager.
--[[
	MessageBox — Standarddialog mit Symbol, Text und Schaltflächen.

		MessageBox.show(wm, {
			title = "Editor",
			message = "Möchten Sie die Änderungen speichern?",
			icon = "question",
			buttons = "YesNoCancel",
			onResult = function(name, index)
				print(name)   -- "Yes" | "No" | "Cancel"
			end,
		})

	icon: "info" | "warning" | "error" | "question" | nil

	Zu jedem Symbol gehört ein Klang aus Windows' Standardschema — ausser bei
	"question", das dort seit Vista stumm ist. sound = false schaltet ihn ab.

	Der Dialog ist mindestens 298 x 152 px — das ist das an echtem Windows
	gemessene Maß eines Standarddialogs — und wächst mit dem Text bis 500 px
	Breite. Platziert wird er vom WindowManager (mittig plus Kaskade).

	NICHT GRÖSSENVERÄNDERBAR und ohne Minimieren/Maximieren, wie in Windows.
	Das kommt über resizable = false an wm:open(), und dadurch baut Window
	Windows/Resize gar nicht erst an — an den Kanten bleibt der normale Zeiger.

	KEIN EIGENER KNOPF IN DER TASKLEISTE, solange der Dialog modal ist — und
	das ist er, wenn man ihn nicht ausdrücklich abschaltet.

	Mit Besitzer folgt das aus der Besitzregel: der Dialog gehört dem Fenster,
	aus dem er kommt (config.owner, sonst das gerade aktive), und wird dort
	von ihm vertreten. Derselbe Besitzer bestimmt auch die Position — mittig
	in ihm statt in der Kaskade.

	Ohne Besitzer gilt es trotzdem: ein modaler Dialog sperrt alles andere,
	es gibt also nichts, wohin man von ihm weg könnte. Ein Knopf, über den
	man zurückfindet, wäre für einen Zustand da, den es nicht gibt.

	NICHT-MODAL IST DER EINE FALL MIT KNOPF, und nur ohne Besitzer: dann ist
	es ein eigenständiges Fenster, und ohne Knopf käme man nicht mehr heran,
	sobald es verdeckt ist.

		owner = false     ausdrücklich keiner, statt aufs aktive Fenster
		                  zurückzufallen
		modal = false     Elternfenster bleibt bedienbar

	API
		.show(manager, config) -> Window
		.buttons               die sechs Windows-Sätze

		.modalDepth(manager)     wie viele modale Dialoge offen sind

	Reine Rechnung, ohne Roblox-Objekte und damit testbar:
		.computeLayout(measure, message, hasIcon, buttonCount) -> layout
		.resolveButtons(value) -> { string }
		.hasIcon(name) · .iconAsset(name) · .iconKinds()
		.soundAsset(name)   nil heisst lautlos
		.beep(name, manager) Klang ohne Dialog, wie Windows' MessageBeep
		.nextIndex(current, count, delta)   Pfeiltasten, mit Umlauf
		.directionOf(keyCode)              -1, 1 oder nil
--]]

local TextService = game:GetService("TextService")
local SoundService = game:GetService("SoundService")

local Root = script.Parent.Parent

local Theme = require(Root.UI.Theme)
local New = require(Root.UI.New)
local Button = require(Root.UI.Button)
local Preload = require(Root.UI.Preload)

local MessageBox = {}

--------------------------------------------------------------------------
-- Maße, alle aus Windows abgemessen
--------------------------------------------------------------------------

local ICON_SIZE = 32
local ICON_PADDING = 10       -- zwischen Symbol und Text
local PADDING_LEFT = 12
local PADDING_TOP = 24
local TEXT_PADDING = 12       -- rechts neben dem Text
local BOTTOM_HEIGHT = 42      -- Fussleiste mit den Schaltflächen
local BUTTON_GAP = 8
local BUTTON_MARGIN = 12

--[[
	Ein Standarddialog ist 298 x 152 px, gemessen bei 1920x1080 und 100 %.
	Kurze Meldungen bekommen also immer genau dieses Fenster; nur längerer
	Text lässt es wachsen, und zwar bis 500 px Breite.

	Nicht skalieren — die DPI erledigt das globale UIScale in Layers.
--]]
local MIN_SIZE = Vector2.new(298, 152)
local MAX_WIDTH = 500

--------------------------------------------------------------------------
-- Schaltflächensätze
--------------------------------------------------------------------------

--[[
	Die sechs Sätze aus Windows, in Anzeigereihenfolge von links nach rechts.

	Der ERSTE Eintrag ist die Standardschaltfläche (kräftiger Rahmen), der
	LETZTE gilt als Abbruch — das ist die, die auch das X in der Titelleiste
	meldet. Bei OKCancel also "Cancel", bei einem einzelnen Knopf eben "OK".
--]]
MessageBox.buttons = {
	OK               = { "OK" },
	OKCancel         = { "OK", "Cancel" },
	YesNo            = { "Yes", "No" },
	YesNoCancel      = { "Yes", "No", "Cancel" },
	RetryCancel      = { "Retry", "Cancel" },
	AbortRetryIgnore = { "Abort", "Retry", "Ignore" },
}

--[[
	Nimmt einen Satznamen, eine fertige Liste oder nil.

	Ein unbekannter Name ist ein Tippfehler und soll auffallen, statt still zu
	"OK" zu werden — sonst sucht man später, warum der Dialog nur einen Knopf
	hat.
--]]
function MessageBox.resolveButtons(value)
	if value == nil then
		return MessageBox.buttons.OK
	end

	if type(value) == "string" then
		local preset = MessageBox.buttons[value]
		assert(preset, ("MessageBox: unbekannter Schaltflächensatz '%s'"):format(value))
		return preset
	end

	assert(type(value) == "table" and #value > 0, "MessageBox: buttons ist leer")
	return value
end

--------------------------------------------------------------------------
-- Symbole
--------------------------------------------------------------------------

--[[
	Die vier Windows-Symbole als Assets.

	Sie stehen HIER und nicht in Theme, weil sie nur hier benutzt werden. Theme
	hält die Werte, die durch das ganze Projekt gehen — Farben, Maße, Cursor.
	Ein Asset, das genau eine Stelle braucht, gehört an diese Stelle; sonst
	wächst Theme zu einer Ablage für alles.

	32 x 32 px, links oben mit 12 px seitlich und 24 px von der Titelleiste.
	Die Maße stehen oben in ICON_SIZE und den Rändern.
--]]
local ICONS = {
	info     = "rbxassetid://135828903791013",
	warning  = "rbxassetid://131716641876787",
	error    = "rbxassetid://89827250672939",
	question = "rbxassetid://138112317873666",
}

-- Alle vier vorladen, nicht nur das zuerst benutzte: welcher Dialog als
-- erster kommt, weiss man nicht.
for _, assetId in ICONS do
	Preload.add(assetId)
end

--[[
	Ist der Name eine bekannte Art? Getrennt, damit computeLayout dieselbe
	Antwort benutzt wie show — sonst rechnet das Layout mit einem Symbol, das
	danach nicht gezeichnet wird, und der Text beginnt 42 px zu weit rechts.
--]]
function MessageBox.hasIcon(name)
	return name ~= nil and ICONS[name] ~= nil
end

function MessageBox.iconAsset(name)
	return ICONS[name]
end

-- Alle Arten, sortiert. Für Diagnose und Tests.
function MessageBox.iconKinds()
	local list = {}

	for kind in ICONS do
		table.insert(list, kind)
	end

	table.sort(list)
	return list
end

--------------------------------------------------------------------------
-- Klänge
--------------------------------------------------------------------------

--[[
	Windows spielt zu einem Dialog den Klang seines Symbols, nicht den des
	Dialogs. Die Zuordnung stammt aus dem Standard-Schema von Windows 10:

		Symbol      Windows-Ereignis                Datei
		error       Critical Stop (SystemHand)      Windows Foreground
		warning     Exclamation (SystemExclamation) Windows Background
		info        Asterisk (SystemAsterisk)       Windows Background
		question    Question (SystemQuestion)       — nichts —

	DASS FRAGE STUMM IST, IST KEIN VERSEHEN. Seit Windows Vista hat das
	Ereignis "Frage" im Standardschema keine Datei mehr zugewiesen. Ein
	Dialog mit Fragezeichen erscheint also lautlos, und genau so verhält es
	sich hier.

	Nur der Fehler bekommt den lauteren Vordergrundklang — das ist die
	Abstufung, die Windows macht: eine Meldung, die man nur zur Kenntnis
	nimmt, klingt zurückhaltender als eine, die etwas verhindert hat.
--]]
local SOUND_BACKGROUND = "rbxassetid://111575544680858"
local SOUND_FOREGROUND = "rbxassetid://135623551518267"

local SOUNDS = {
	error    = SOUND_FOREGROUND,
	warning  = SOUND_BACKGROUND,
	info     = SOUND_BACKGROUND,
	-- question fehlt absichtlich, siehe oben
}

--[[
	Welcher Klang gehört zu einem Symbol? nil heisst lautlos.

	Getrennt, damit die Zuordnung prüfbar ist, ohne einen Dialog zu öffnen —
	und damit ein Aufrufer sie nachschlagen kann, statt sie nachzubauen.
--]]
function MessageBox.soundAsset(iconName)
	return SOUNDS[iconName]
end

--[[
	Für jeden Klang EINE Sound-Instanz, die bleibt.

	Der erste Entwurf erzeugte pro Meldung eine neue Instanz und zerstörte sie
	danach — und genau das erzeugte den hörbaren Verzug: Roblox lädt ein
	Audio-Asset beim ersten Play, und eine frische Instanz kennt es nicht. Der
	Klang setzte also erst nach dem Laden ein, sichtbar versetzt zum Dialog.

	Eine bleibende Instanz wird einmal geladen und danach sofort gespielt.
	Nebenbei fällt das Aufräumen weg: keine Ended-Verbindung, kein Notausgang
	für den Fall, dass Ended nie kommt.

	Sie hängen an SoundService und nicht am Dialog — sonst bräche der Klang
	ab, sobald das Fenster schliesst. Bei einem Klick auf "OK" wäre das schon
	nach einem Bruchteil der Laufzeit.
--]]
local function soundFor(manager, assetId)
	manager._dialogSounds=manager._dialogSounds or {}
	local existing = manager._dialogSounds[assetId]
	if existing then
		return existing
	end

	local sound = Instance.new("Sound")
	sound.Name = "MessageBoxSound"
	sound.SoundId = assetId
	sound.Parent = SoundService

	manager._dialogSounds[assetId] = sound
	manager._cleanup:add(function()sound:Destroy();manager._dialogSounds[assetId]=nil end)
	return sound
end

-- Preload bounded asset IDs; Sound instances are created and owned by the manager.
for _, assetId in SOUNDS do
	Preload.add(assetId)
end

local function playSound(manager, assetId)
	if not assetId then
		return
	end

	local sound = soundFor(manager, assetId)

	--[[
		TimePosition zurücksetzen, bevor gespielt wird. Zwei Dialoge kurz
		hintereinander teilen sich dieselbe Instanz; ohne das Zurücksetzen
		liefe der zweite Klang dort weiter, wo der erste stand.
	--]]
	sound.TimePosition = 0
	sound:Play()
end

--[[
	beep(iconName)

	Spielt den Klang eines Symbols, ohne einen Dialog zu öffnen. Bei einem
	stummen Symbol passiert nichts.

	Der Name ist von Windows' MessageBeep entlehnt, und die Funktion tut
	dasselbe: sie meldet akustisch, ohne etwas anzuzeigen. Praktisch für eine
	Eingabe, die abgelehnt wird — und für den Selbsttest, der alle Klänge
	nacheinander hörbar macht.
--]]
function MessageBox.beep(iconName, manager)
	assert(manager,"MessageBox.beep requires a window manager")
	playSound(manager,MessageBox.soundAsset(iconName))
end

--------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------

--[[
	computeLayout(measure, message, hasIcon, buttonCount) -> layout

	measure(text, maxWidth) -> Vector2 misst den Text. Als Funktion übergeben,
	damit die Rechnung ohne Roblox prüfbar bleibt — sonst hinge sie an
	TextService und liesse sich nur in Studio testen.

	Ablauf:
	  1. Text EINZEILIG messen  -> gewünschte Breite
	  2. auf 298..500 begrenzen, aber mindestens so breit wie die Knopfgruppe
	  3. bei der gefundenen Breite UMBROCHEN messen -> Höhe
	  4. Höhe gegen Symbolgrösse und Mindesthöhe abgleichen

	Schritt 2 ist der, den man leicht vergisst: drei Schaltflächen sind
	zusammen 280 px breit plus Ränder, also breiter als das 298-px-Mindestmaß
	knapp zulässt. Ohne die Prüfung ragt die Gruppe links aus dem Dialog
	heraus.
--]]
function MessageBox.computeLayout(measure, message, hasIcon, buttonCount, titlebarHeight)
	local barHeight = titlebarHeight or Theme.size.titlebarHeight
	local count = buttonCount or 1

	local contentX = PADDING_LEFT + (if hasIcon then ICON_SIZE + ICON_PADDING else 0)

	local singleLine = measure(message, math.huge)
	local wanted = contentX + singleLine.X + TEXT_PADDING

	local buttonRow = Button.groupWidth(count, BUTTON_GAP) + 2 * BUTTON_MARGIN

	local width = math.clamp(math.max(wanted, buttonRow), MIN_SIZE.X, MAX_WIDTH)

	local textWidth = width - contentX - TEXT_PADDING
	local wrapped = measure(message, textWidth)

	local contentHeight = math.max(wrapped.Y, if hasIcon then ICON_SIZE else 0)

	local height = math.max(
		barHeight + PADDING_TOP + contentHeight + PADDING_TOP + BOTTOM_HEIGHT,
		MIN_SIZE.Y
	)

	return {
		width = math.round(width),
		height = math.round(height),
		contentX = contentX,
		textWidth = math.round(textWidth),
		contentHeight = math.round(contentHeight),
	}
end

--[[
	Textmessung über Roblox. Der Notnagel schätzt über die Zeichenzahl —
	besser ein etwas schiefer Dialog als gar keiner, wenn GetTextSize einmal
	nicht verfügbar ist.
--]]
local function measureWithRoblox(text, maxWidth)
	local bounds = if maxWidth == math.huge then 9999 else maxWidth

	--[[
		Gemessen wird mit Theme.size.text — derselben Grösse, mit der die
		Meldung danach gezeichnet wird. Messen und Zeichnen MÜSSEN dieselbe
		Grösse benutzen, sonst rechnet der Dialog mit einer Textmenge, die er
		nicht darstellt: er wird zu schmal und schneidet ab, oder zu hoch und
		hat unten Luft.
	--]]
	local ok, size = pcall(function()
		return TextService:GetTextSize(
			text,
			Theme.size.text,
			Theme.font.ui,
			Vector2.new(bounds, 9999)
		)
	end)

	if ok then
		return size
	end

	local perChar = Theme.size.text * 0.55
	return Vector2.new(#text * perChar, Theme.size.text * 1.4)
end

--------------------------------------------------------------------------
-- show
--------------------------------------------------------------------------

--------------------------------------------------------------------------
-- Tastatur
--------------------------------------------------------------------------

--[[
	nextIndex(current, count, delta) -> number

	Der nächste Knopf beim Drücken einer Pfeiltaste, MIT Umlauf: von der
	letzten Schaltfläche nach rechts landet man wieder auf der ersten. So
	macht es Windows, und es erspart das Zurücktasten durch die ganze Reihe.

	Die Modulo-Rechnung ist auf 0-basiert gedreht und danach zurück, weil
	Lua-Indizes bei 1 anfangen — ohne das gäbe (1 - 1) % 3 + 1 den falschen
	Rand.
--]]
function MessageBox.nextIndex(current, count, delta)
	if count <= 0 then
		return 1
	end

	return (current - 1 + delta) % count + 1
end

--[[
	Welche Richtung gehört zu einer Taste?

	Links und Hoch gehen zurück, Rechts und Runter vor. Windows behandelt
	beide Achsen gleich, weil eine Knopfreihe je nach Dialog waagerecht oder
	senkrecht stehen kann — und wer Hoch drückt, meint immer "das davor".

	nil heisst: keine Navigationstaste.
--]]
function MessageBox.directionOf(keyCode)
	if keyCode == Enum.KeyCode.Left or keyCode == Enum.KeyCode.Up then
		return -1
	end

	if keyCode == Enum.KeyCode.Right or keyCode == Enum.KeyCode.Down then
		return 1
	end

	return nil
end

--------------------------------------------------------------------------
-- Modalität
--------------------------------------------------------------------------

--[[
	centerOn(ownerPosition, ownerSize, dialogSize) -> Vector2

	Ein Dialog erscheint MITTIG IM ELTERNFENSTER, nicht mittig auf dem
	Bildschirm. Das ist kein Schönheitsdetail: der Dialog gehört sichtbar zu
	dem Fenster, das ihn ausgelöst hat, und man muss den Blick nicht suchen
	lassen.

	Gerundet, weil ein halbes Pixel Versatz beim Rendern unscharf wird.
--]]
function MessageBox.centerOn(ownerPosition, ownerSize, dialogSize)
	return Vector2.new(
		math.round(ownerPosition.X + (ownerSize.X - dialogSize.X) / 2),
		math.round(ownerPosition.Y + (ownerSize.Y - dialogSize.Y) / 2)
	)
end

--[[
	ANWENDUNGSMODAL, NICHT SYSTEMMODAL — und das ist der Unterschied, den
	Windows macht.

	Die Mechanik dazu liegt im WindowManager (:pushModal / :popModal), und
	zwar seit sie dort hingehört: sie war ein `local modalStack = {}` auf
	Modulebene HIER, also globaler Zustand in einem Dialogmodul. Zwei
	Manager teilten sich einen Stapel, und er überlebte jedes shutdown().

	Was der Dialog beisteuert, ist nur noch die Antwort auf einen Klick
	daneben: blinken und den Hintergrundklang spielen.
--]]
function MessageBox.modalDepth(manager)
	assert(manager, "MessageBox.modalDepth: manager fehlt")
	return manager:modalDepth()
end

--------------------------------------------------------------------------
-- Die Teile des Dialogs
--------------------------------------------------------------------------

--[[
	Symbol und Text. Beide hängen an derselben Rechnung: layout.contentX
	sagt, wo der Text beginnt, und das hängt daran, ob links ein Symbol
	steht.

	Genau deshalb benutzt computeLayout dieselbe hasIcon-Antwort wie hier —
	sonst rechnet das Layout mit einem Symbol, das danach nicht gezeichnet
	wird, und der Text beginnt 42 px zu weit rechts.
--]]
local function buildBody(content, cfg, message, layout, hasIcon)
	if hasIcon then
		--[[
			ScaleType.Fit: das Asset behält sein Seitenverhältnis. Bei einem
			quadratischen Symbol in einem quadratischen Feld ändert das
			nichts, aber es verhindert Verzerrung, falls jemand ein anderes
			Bild einträgt.
		--]]
		New("ImageLabel", {
			Name = "Symbol",
			Position = UDim2.fromOffset(PADDING_LEFT, PADDING_TOP),
			Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
			Image = MessageBox.iconAsset(cfg.icon),
			ScaleType = Enum.ScaleType.Fit,
			Parent = content,
		})
	end

	New("TextLabel", {
		Name = "Nachricht",
		Position = UDim2.fromOffset(layout.contentX, PADDING_TOP),
		Size = UDim2.new(1, -(layout.contentX + TEXT_PADDING), 1, -(PADDING_TOP + BOTTOM_HEIGHT)),
		Text = message,

		--[[
			Theme.size.text, nicht Theme.button.textSize: die Meldung ist
			Fliesstext. Hinge sie am Knopfmaß, verschöbe eine Änderung an den
			Schaltflächen still die Textgrösse im Dialog.
		--]]
		TextSize = Theme.size.text,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Parent = content,
	})
end

--[[
	Die Fussleiste mit den Schaltflächen.

	Sie sitzt rechts unten und wird von links nach rechts in der angegebenen
	Reihenfolge gefüllt: [ Ja ] [ Nein ] [ Abbrechen ]. Deshalb wird die
	Gesamtbreite VORAB gerechnet — das erste Element steht am weitesten
	links, nicht am Rand.
--]]
local function buildFooter(window, buttons, onFinish)
	local content = window:getContent()
	local cleanup = window.cleanup

	local bottom = New("Frame", {
		Name = "Fussleiste",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, BOTTOM_HEIGHT),
		BackgroundColor3 = Theme.color.chrome,
		Parent = content,
	})

	local left = Button.groupWidth(#buttons, BUTTON_GAP) + BUTTON_MARGIN
	local handles = {}

	for index, name in buttons do
		table.insert(handles, Button.create({
			parent = bottom,
			cleanup = cleanup,
			input = window.input,
			text = name,
			default = index == 1,
			anchorPoint = Vector2.new(0, 0.5),
			position = UDim2.new(1, -left, 0.5, 0),
			focused = window.focused,

			onClick = function()
				onFinish(name, index)
			end,
		}))

		left -= Theme.button.width + BUTTON_GAP
	end

	--[[
		Die Schaltflächen folgen dem Fokus des Fensters. Windows zeichnet die
		Knöpfe eines inaktiven Dialogs blasser — anklickbar bleiben sie, sie
		treten nur zurück.

		Über window.focusChanged und nicht über den Manager: so muss dieser
		Dialog nicht wissen, welche anderen Fenster es gibt.
	--]]
	cleanup:add(window.focusChanged:connect(function(value)
		for _, handle in handles do
			handle:setFocused(value)
		end
	end))

	return handles
end

--[[
	Pfeiltasten, Enter und Esc.

	DIE AUSWAHL IST DER STANDARDKNOPF. In Windows gibt es keine zweite
	Markierung daneben: was Enter auslöst, ist genau das, was den
	Akzentrahmen trägt. Deshalb läuft die Auswahl über setDefault und nicht
	über einen eigenen Zustand.

	Startwert 1, also der erste Knopf. Der ist schon beim Erzeugen als
	default markiert, die Anzeige stimmt also von Anfang an.
--]]
local function bindKeyboard(window, buttons, handles, onFinish)
	local selected = 1

	local function select(index)
		selected = index

		for position, handle in handles do
			handle:setDefault(position == index)
		end
	end

	--[[
		Nur auf das DRÜCKEN reagieren, nicht auf das Loslassen. Sonst liefe
		jede Aktion zweimal — und bei Enter würde der Dialog schliessen und
		das Loslassen ginge ins Leere.
	--]]
	window.cleanup:add(window.keyPressed:connect(function(keyCode, down)
		if not down then
			return
		end

		local direction = MessageBox.directionOf(keyCode)

		if direction then
			select(MessageBox.nextIndex(selected, #handles, direction))
			return
		end

		if keyCode == Enum.KeyCode.Return or keyCode == Enum.KeyCode.KeypadEnter then
			onFinish(buttons[selected], selected)
			return
		end

		--[[
			Esc ist der ABBRUCH, also die letzte Schaltfläche im Satz — bei
			OKCancel "Cancel", bei einem einzelnen Knopf eben "OK". Dieselbe
			Regel wie beim X in der Titelleiste: Wegklicken heisst abbrechen.
		--]]
		if keyCode == Enum.KeyCode.Escape then
			onFinish(buttons[#buttons], #buttons)
		end
	end))
end

--------------------------------------------------------------------------

function MessageBox.show(manager, config)
	assert(manager, "MessageBox.show: manager fehlt")

	local cfg = config or {}

	local message = cfg.message or ""
	local buttons = MessageBox.resolveButtons(cfg.buttons)

	--[[
		Ein unbekannter Symbolname ist ein Tippfehler und soll auffallen. Still
		ohne Symbol zu zeichnen wäre schlimmer: der Dialog sieht dann fast
		richtig aus, und man sucht lange.
	--]]
	if cfg.icon ~= nil then
		assert(MessageBox.hasIcon(cfg.icon),
			("MessageBox: unbekanntes Symbol '%s'"):format(tostring(cfg.icon)))
	end

	local hasIcon = MessageBox.hasIcon(cfg.icon)

	--[[
		Der Klang gehört zum Symbol. sound = false schaltet ihn ab — nützlich
		für Dialoge, die in Folge erscheinen, damit es nicht klappert.
	--]]
	if cfg.sound ~= false then
		MessageBox.beep(cfg.icon,manager)
	end

	local layout = MessageBox.computeLayout(
		cfg.measure or measureWithRoblox,
		message,
		hasIcon,
		#buttons,
		Theme.size.titlebarHeight
	)

	--[[
		resizable = false lässt Window die Griffzonen weg, showMinimize und
		showMaximize lassen die beiden Buttons weg. Übrig bleibt das X — und
		das ist bei einem Dialog kleiner als bei einem Fenster, deshalb
		captionSize.
	--]]
	--[[
		Das Elternfenster ist das gerade aktive, sofern keins angegeben wurde —
		so bestimmt es auch Windows, wenn ein Programm keinen Besitzer nennt.

		Daraus folgt die Position: mittig im Elternfenster. Gibt es keins,
		bleibt die Kaskade des Managers.
	--]]
	--[[
		owner = false heisst AUSDRÜCKLICH KEINER.

		Ohne diese Unterscheidung liesse sich ein besitzerloser Dialog gar
		nicht anfordern: nil bedeutet "nicht gesagt" und fällt auf das aktive
		Fenster zurück, und ein aktives Fenster gibt es fast immer.

		Gebraucht für den Vergleich mit echtem Windows — dort ist ein Dialog
		ohne Elternfenster bildschirmmittig, blinkt nicht und gibt keinen Ton.
		Dieselbe Dreiwertigkeit wie bei showInTaskbar, aus demselben Grund.
	--]]
	local owner = if cfg.owner == false
		then nil
		else (cfg.owner or manager:getFocused())
	local dialogSize = Vector2.new(layout.width, layout.height)

	local position = cfg.position

	if not position and owner and owner.isVisible and owner:isVisible() then
		position = MessageBox.centerOn(owner:getPosition(), owner:getSize(), dialogSize)
	end

	--[[
		DER BESITZER GEHT JETZT AUCH AN open(), nicht nur in die Rechnung für
		die Position.

		Daran hängt der Knopf in der Taskleiste: ein Fenster mit Besitzer
		bekommt keinen eigenen, der Besitzer vertritt es. Genau das erwartet
		man von einem Dialog — er ist eine Rückfrage des Programms und kein
		zweites Programm.

		Ohne Besitzer (show ohne offenes Fenster) bleibt es beim eigenen
		Knopf, und das ist richtig so: dann gibt es nichts, was ihn vertreten
		könnte, und ohne Knopf wäre der Dialog aus der Leiste unerreichbar.
	--]]
	--[[
		EIN MODALER DIALOG BEKOMMT NIE EINEN EIGENEN KNOPF, auch ohne
		Besitzer.

		Mit Besitzer folgt das schon aus der Besitzregel. Ohne Besitzer musste
		es ausdrücklich hin: showInTaskbar = false, derselbe Schalter, der für
		besitzerlose Werkzeugfenster gedacht ist.

		Das naheliegende Gegenargument — ein Dialog ohne Knopf wäre aus der
		Leiste unerreichbar — trägt bei einem MODALEN Dialog nicht: solange er
		offen ist, ist ohnehin nichts anderes bedienbar. Es gibt nichts, wohin
		man von ihm weg könnte, und also auch nichts, wohin man zurückfinden
		müsste.

		NICHT-MODAL BLEIBT ES BEIM KNOPF. Ein besitzerloses, nicht-modales
		Fenster ist ein eigenständiges Fenster; ohne Knopf und ohne Besitzer
		käme man wirklich nicht mehr heran, sobald es verdeckt ist.
	--]]
	local modal = cfg.modal ~= false

	local window = manager:open({
		title = cfg.title or "Meldung",
		appId = cfg.appId or "messagebox",
		icon = cfg.windowIcon,
		size = dialogSize,
		position = position,
		owner = owner,
		showInTaskbar = if modal then false else nil,
		resizable = false,
		showMinimize = false,
		showMaximize = false,
		captionSize = Theme.size.dialogCaption,
	})

	--[[
		MODAL, sofern nicht ausdrücklich abgeschaltet.

		Ab hier ist das ELTERNFENSTER gesperrt — nicht die ganze Oberfläche.
		Andere Fenster, der Desktop und die Taskleiste bleiben bedienbar, so
		wie es MB_APPLMODAL in Windows vorgibt. Nur ein Dialog OHNE Besitzer
		sperrt alles, weil es dann nichts Kleineres zu sperren gibt.

		Klickt jemand ins gesperrte Fenster, blinkt der Dialog und spielt den
		Vordergrundklang — dieselbe Antwort wie in Windows.

		Der Klang ist SOUND_BACKGROUND und NICHT der Klang des Symbols:
		Windows meldet die Absage immer mit demselben Ton, egal ob der Dialog
		eine Warnung oder eine Information zeigt.

		Nachgeprüft: es ist der Hintergrundklang, nicht der Vordergrundklang.
		Der Vordergrundklang gehört dem Fehlerdialog selbst — die Absage ist
		die leisere Rückmeldung, nicht die lautere.
	--]]
	if modal then
		manager:pushModal({
			frame = window.frame,
			owner = owner,
			onBlocked = function()
				window:flash()
				if cfg.sound~=false then playSound(manager,SOUND_BACKGROUND)end
			end,
		})

		--[[
			Über closed und nicht am Ende von finish(): das X in der
			Titelleiste geht nicht durch finish, und ein Dialog, der die
			Sperre beim Wegklicken nicht löst, würde die ganze Oberfläche
			lahmlegen.
		--]]
		window.closed:connect(function()
			manager:popModal(window.frame)
		end)
	end

	buildBody(window:getContent(), cfg, message, layout, hasIcon)

	--[[
		DAS ERGEBNIS DARF GENAU EINMAL GEMELDET WERDEN.

		Ohne den Riegel käme es doppelt: einmal von der Schaltfläche und
		danach noch einmal vom closed-Ereignis, das der Aufruf von close()
		auslöst.

		Er steht HIER und nicht in einem der Teile darunter, weil ihn drei
		Wege teilen: Klick, Taste und das X in der Titelleiste.
	--]]
	local gemeldet = false

	local function melde(name, index)
		if gemeldet then
			return
		end

		gemeldet = true

		--[[
			task.defer, damit der Aufrufer im Rückruf gefahrlos weitere
			Fenster öffnen oder dieses erneut anfassen kann — sonst liefe das
			mitten im Aufräumen des Dialogs.
		--]]
		if cfg.onResult then
			task.defer(cfg.onResult, name, index)
		end
	end

	local function finish(name, index)
		melde(name, index)
		window:close()
	end

	local handles = buildFooter(window, buttons, finish)

	bindKeyboard(window, buttons, handles, finish)

	--[[
		Das X in der Titelleiste zählt wie die LETZTE Schaltfläche — bei
		OKCancel also "Cancel". So verhält sich Windows: Wegklicken heisst
		abbrechen, nicht bestätigen.

		Nur melden, nicht schliessen: das Fenster ist an dieser Stelle schon
		dabei.
	--]]
	window.closed:connect(function()
		melde(buttons[#buttons], #buttons)
	end)

	return window
end

return MessageBox
