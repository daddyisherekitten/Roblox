# S37/S38: Eingaben, Ereignisse und Änderungen zur Laufzeit

> Laborhinweis vom 14. Oktober 2026: Die SVG-Demo und ihre Seiten sind entfernt. Start-/Generatoranweisungen unten sind historisch; die SVG-Engine bleibt erhalten. [Quellen und Regressionen](SVG-SUPPORT.md#entferntes-vergleichslabor--14-oktober-2026).

Stand 14.09.2026. S35/S36 einschließlich Spot-Kantenkorrektur vom Nutzer zum
Fortfahren freigegeben. S37/S38 sind im unten beschriebenen Umfang implementiert;
der native Browser-/Studio-Vergleich einschließlich nachträglicher Korrekturen wurde
am 14.09.2026 mit „perfekt alles passt weiter“ zum Fortfahren freigegeben.

## Vergleich

Für dieses historische Paket StudioDemoConfig auf `S37_S38` setzen; in Studio Stop → Play.
Browser: [acht Tafeln](../tests/fixtures/svg-regressions.zip), alternativ
[S37](../tests/fixtures/svg-regressions.zip) / [S38](../tests/fixtures/svg-regressions.zip).
Die SVG-Quellen werden in Browser und Roblox aus demselben Generator übernommen.
Die Browsertafeln enthalten native SVGs in getrennten HTML-srcdoc-Frames, damit
IDs und Styles der Tafeln einander nicht beeinflussen. Source Sans Pro wird
eingebettet. Jeder Frame startet seine Eingabelogik selbst; der Elternrahmen
empfaengt nur Status und Tasten ueber postMessage mit gepruefter Fensterquelle.

| Tafel | Prüfung |
|---|---|
| Zustände | Blau → Hover grün → gedrückt orange → losgelassen grün. Fokus violett. Enter/Leertaste erhöhen den Zähler genau einmal. |
| Fokus/Link | Tab: B → A → C, rückwärts mit Shift+Tab. Titel/ARIA-Label und Beschreibung erscheinen im Status. C meldet `#destination`. |
| Ereignisse | Blau: svg capture → group capture → target → group bubble. Rot: stopPropagation verhindert die weitere Bubble-Phase. |
| Capture | Kreis auch außerhalb der Tafel ziehen, dann loslassen. Freie Bewegung danach darf nicht weiterziehen. Auch Touch prüfen. |
| Farbe | Klick wechselt nur die Füllung; nach dem ersten Fokusaufbau keine neue Treffergeometrie. |
| Geometrie | Kreis verändert zwei Attribute gemeinsam. Polygonspitze und Trefferfläche folgen; Pfeiltasten bewegen den fokussierten Kreis. |
| Ressourcen | Ein geänderter Farb-Stopp aktualisiert beide Verbraucher desselben Verlaufs. |
| Abfragen | Roter Punkt bei 0/25/50/75/100 % Pfadlänge. Gestrichelte BBox: 400 × 150; CTM-Versatz bei 480 px: (20,20). |

1/2/3 setzt die Tafelbreite auf 240/480/960 px; R setzt alle Sessions zurück.
Der ScreenCTM-Skalierungswert und der CTM-Versatz ändern sich entsprechend.
Roblox-Tab bleibt innerhalb der jeweils aktiven Tafel, der Browser kann zwischen
seinen Dokumenten weitergehen. Der Link wird in dieser Vergleichsszene nur gemeldet.
Der Host kann über `Navigate` die erlaubte Navigation implementieren.

## Umsetzung

- `SVG/Events`: Listener mit Capture/Once, Target-/Bubble-Phase, festgehaltenem
  Ereignispfad, preventDefault, stopPropagation und stopImmediatePropagation.
- `SVG/Session`: stabiler Quellbaum; Zustände für CSS, geometrische Pointer-Ziele,
  Pointer Capture, Fokus/Tab, Tastatur-Ereignisse und Metadaten.
- `SetAttribute`/Entfernen per nil: Änderungen werden bis `Flush` gesammelt.
  Ressourcen werden aus dem aktuellen Quellbaum erneut aufgelöst. Dies ist noch
  kein selektiver Abhängigkeitsgraph: Die Szene wird neu aufgebaut, ihre
  unveränderte Treffergeometrie jedoch wiederverwendet.
- `SVG/Queries`: lokale BBox, CTM/ScreenCTM, Gesamtlänge und Punkt bei Pfadlänge.
  Kurvenabfragen verwenden die gemeinsame begrenzte Kurvenzerlegung.
- `SVGLab/Interactive`: passive ImageLabels/Frames, eigene Eingaben über
  UserInputService. Pro Tafel ein zusammengefasster Rasterjob; überholte Jobs
  dürfen nichts installieren. Gleich große Bilder werden im bestehenden
  EditableImage aktualisiert, Größenwechsel und Cleanup geben Besitz frei.
- `RuntimeActions` sind ausdrücklich Luau-Laboraktionen, gepaart mit Browser-JS.
  Sie zählen **nicht** als SVG-script-/JavaScript-Unterstützung (S41).

## Prüfung und verbleibender Umfang

`SVGRuntime` prüft Ereignisphasen, Reentranz bei Once, Propagationsstopps,
CSS-Pixelzustände, Fokusreihenfolge, verhinderte Links, Metadaten, Capture außerhalb
der Tafel, Touch-Abbruch, gebündelte Änderungen, Clip-Abhängigkeiten, gemeinsame
Verläufe, Treffer-Cache und Geometrieabfragen. `SVGInteractiveHost` prüft den echten
Host mit gemocktem Raster/Roblox: unveränderte Mausbewegungen ohne Rasterjob,
schnelles Drücken/Loslassen während Rasterarbeit, Bildwiederverwendung, 20 Resets,
überholte Größenänderungen, Fensterfokusverlust und Freigabe während Rasterarbeit.
Rastermathematik läuft separat in der vollständigen SVG-Suite.

Noch offen, nicht als Vollsupport deklarieren:

- use-/Unterdokument-Retargeting und Text-Zeichenflächen aus S36;
- vollständiges Browser-PointerEvent-Modell, verzögerte Capture-Ereignisse,
  gleichzeitige unabhängige Mehrfinger-CSS-Zustände und native Tab-Navigation
  über mehrere HTML-/SVG-Dokumente;
- native Screenreader-Anbindung: Metadaten stehen der Luau-API/Prüfzeile zur
  Verfügung, nicht automatisch Betriebssystem-Hilfstechniken;
- allgemeine DOM-Strukturoperationen, Script-Ausführung, MutationObserver,
  SVGAnimated*-Objekte und EventListener-Optionen wie passive/AbortSignal;
- getCTM bei verschachtelten SVG-Viewports: aktuell Abbildung in die äußere
  Tafel, nicht jeweils den nächsten SVG-Viewport. getBBox-Optionen für Stroke,
  Marker und Clipping sowie vollständige Text-/use-Geometrieabfragen;
- selektiver Paint-/Ressourcen-Neuaufbau und größere Szenenbudgets (S44);
- Anschluss dieses Session-Hosts an beliebige HTML-Seiten (S43).

Referenz: [SVG 2 Interaktion](https://www.w3.org/TR/SVG2/interact.html),
[SVG-Geometrie-Interfaces](https://www.w3.org/TR/SVG2/types.html#InterfaceSVGGraphicsElement).

Validierung abgeschlossen: vollständige SVG-Suite normal und -O2, HTML-Suite,
Projekt-Audit (367 Luau, 6 JS, 64 HTML, 268 lokale Referenzen) und die drei Builds
StudioWorkspace/SVGLab/HTMLPage bestanden. Acht 480-px-Ausgaben aus dem tatsächlichen
Luau-Raster in build/svg-s37-s38-preview.png angesehen. Rojo auf Port 34872 liefert
den neuen Host und S37_S38. Dies ersetzt nicht den noch offenen Studio-/Browser-
Eingabevergleich durch den Nutzer.

Nach Nutzervergleich: vertikaler Hitbox-Versatz korrigiert. Der interaktive Host
rechnet GetMouseLocation-Bildschirmkoordinaten mit dem aktuellen GetGuiInset in
CoreUISafeInsets-Koordinaten um. InputObject.Position bei Touch bleibt unverändert.
ScreenCTM addiert den GUI-Inset zum GUI-Ursprung, um Bildschirmkoordinaten zu liefern.
Regression: A/B/C oberhalb und im unteren Inneren, Scrollversatz, Touch und die
Inset-Kombinationen (0,0), (0,36), (20,58). Vorherige Host-Mocks verwendeten nur
identische Ursprünge und konnten diese Integrationsabweichung nicht erkennen.
Referenz: [Roblox-Definition von AbsolutePosition](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GuiBase2d.yaml).

HTML-Eingabekorrektur nach Nutzervergleich: Die bisherigen SVG-Blob-Frames wurden
vom Elternfenster per contentDocument instrumentiert. Diese Abhaengigkeit von
zugreifbaren Frame-Dokumenten ist entfernt: srcdoc enthaelt das SVG und die
zugehoerige Eingabelogik zusammen. Der Elternrahmen liest keinen Frame-DOM mehr.
Damit starten Capture, Polygonzug, Verlaufswechsel und Pfadschritte direkt im
Dokument, auch wenn dessen DOM fuer das Elternfenster nicht zugaenglich ist.
`scripts/test-svg-runtime-browser.cjs` fuehrt die tatsaechlich generierten Eltern-
und Frame-Skripte mit DOM-Mocks aus, deren contentDocument-Zugriff absichtlich
fehlschlaegt. Alle drei Seiten geprueft: Frame-Start, Ziehen/Loslassen, Skalierung,
Geometrie, Farben, Ressourcen, Punktabfragen, Tastatur sowie Reset und Nachrichten
fremder/veralteter Frames. Der native Browser-Vergleich bleibt beim Nutzer.

Leistungskorrektur nach Nutzervergleich (Ziehen/schnelle Verlaufswechsel):
Maus-/Touchbewegungen werden pro Engine-Frame auf die letzte Position reduziert;
Mouse-up verarbeitet die letzte Bewegung vor Freigabe. Capture benoetigt beim
Bewegen keinen synchronen Hit-Geometrieaufbau. Der Host baut die Szene im
zusammengefassten Rasterjob auf. Laufende Bilder duerfen bei weiterem Ziehen
fertig werden; Reset/Groessenwechsel/Abbau brechen ab. Ein beendeter Active-Zustand
darf durch ein altes Bild nicht wieder aufblitzen.
Wiederkehrende Bilder erhalten einen gemeinsamen LRU-Cache (max. 8 MiB/24 Eintraege).
Der Schluessel enthaelt Tafelbreite, Quellattribute/-text und CSS-Zustaende.
Laufende Capture-Positionen verdraengen keine wiederverwendbaren Farbzustände.
Reset und Abbau leeren den Cache. Die Lab-Resolver bleiben statisch.
Raster.paint addiert vollstaendige Innenbereiche per Span-Differenz; die 16
Antialiasing-Samples bleiben an den Kanten erhalten. Acht originale Vergleichs-
Raster sind nach der Optimierung bytegenau identisch.
CLI-Messung (-O2, 480 px, je 5 Rasterungen, keine Studio-FPS-Zusage): Kreis 5.80→3.93 ms,
Polygon 18.99→6.58 ms, Verlauf 55.49→35.00 ms. Warme Farbzustände brauchen keinen
neuen Rasterlauf. Vollstaendige SVG-Tests normal/-O2 bestanden; Host-Regression
prueft zusaetzlich 100 Bewegungen → einen Aufbau/Rasterlauf, Endposition beim
Loslassen und wiederholte Farbzustände ohne Rasterarbeit. Native Studio-Messung
und Bedienvergleich bleiben beim Nutzer.
