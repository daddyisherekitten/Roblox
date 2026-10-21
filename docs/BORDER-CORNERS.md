# Diagonale Rahmenübergänge

Nicht einheitliche Rahmen und inset/outset/groove/ridge/double sowie Punkt-/Strichmuster
bekommen diagonale Farbtrennungen. Die Trennung verbindet äußeren und inneren Eckpunkt:
bei gleichen Breiten 45 Grad, sonst entsprechend dem Verhältnis der Kantenbreiten.
Einheitliche solide Rahmen behalten den nativen UIStroke/UICorner-Pfad.

BorderPaint stellt die bisherigen Farben gemeinsam für Streifen und Pixel bereit.
BorderCornerPixels erzeugt vier Ecken in einer kleinen Bildfläche. 16 Unterpixelproben
glätten jede Diagonale. Farbe und Alpha werden gemeinsam berechnet, damit transparente
Kanten sich an der Naht nicht überdecken. Reliefbänder und double-Zwischenräume laufen
bis zur Diagonale. Punkte/Striche verwenden dieselben vollen Kantenlängen wie die
Frame-Segmente, ohne gefüllte Dreiecke in Musterlücken. Die Musterphase um den gesamten
Umfang bleibt eine Näherung.

BorderCorners hält pro Box ein EditableImage und bis zu vier ImageLabels mit ImageRect-
Ausschnitten. Gerade Kanten sparen diese Bereiche aus; Muster werden am Übergang
geclippt. Bei API-/Schreibfehler oder Budgetgrenzen bleibt der vollständige bisherige
Rahmen bestehen, mit einmaliger Diagnose. Layout und Scrollmaße bleiben unverändert.

Budget: 32 Rahmen-/Outline-Boxen und 262144 Bildpixel pro Seite. Sehr breite Rahmen
werden auf höchstens 130px je Atlasachse reduziert. Keine Textur in Kartengröße.
Bei unveränderten Atlasmaßen bleibt dieselbe Bildfläche erhalten. Solide/3D-/doppelte
Rahmen brauchen beim Resize nur Positionsänderungen; Punkt-/Strichmuster aktualisieren
bei anderer Musterverteilung die Pixel. HTMLPage gibt die Ressourcen beim Seitenabbau frei.

Gilt für Blöcke, Bilder und gemusterte Outlines. Individuell gerundete Rahmen bleiben
offen. Boxen mit überlappenden gegenüberliegenden Rahmen verwenden die alte Darstellung.
Bestehende 3D-Farbannäherung und native Rundung einheitlicher solider Rahmen bleiben erhalten.

Demo15 und 18–20 zeigen die Verbesserung ohne weitere Beispiele. Tests/BorderCorners
prüft ungleiche Diagonalen, Alpha, Muster, Größenlimits, Wiederverwendung, API-/Budget-
Fallback, Cleanup und Block-/Bild-/Outline-Integration. Native Sichtprüfung steht aus.

API: [EditableImage](https://create.roblox.com/docs/reference/engine/classes/EditableImage)
und [ImageLabel](https://create.roblox.com/docs/reference/engine/classes/ImageLabel).
