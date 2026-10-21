# Mauszeiger

Alle gelieferten IDs stehen unverändert in `Input/CursorIcons.luau`, einschließlich
pointerIcon/textCursorIcon/defaultCursorIcon und des url-Presets. Export:
`Engine.CursorIcons`. `default` verwendet defaultCursorIcon. `none` behält seine
Assetzuordnung, wird als CSS-Schlüsselwort aber mit MouseIconEnabled=false umgesetzt.

CSS `cursor` ist vererbt und funktioniert auf Block-, Inline-, Bild- und
Formularelementen. Unterstützt werden auto, default, pointer, text, not-allowed,
no-drop, help, crosshair, alle gelieferten Richtungs-/Achsen-/Spalten-/Zeilen-resize-
Werte, all-scroll, move, zoom-in/out, none, cell, vertical-text, alias, grab,
grabbing und copy. Nicht gelieferte wait/progress-Assets fehlen weiterhin.

Beispiele:

```css
.action { cursor: pointer; }
.forbidden { cursor: not-allowed; }
.drag { cursor: grab; }
.custom { cursor: url("rbxassetid://119334102167665"), default; }
```

`url` ist eine CSS-Funktion, kein Cursor-Schlüsselwort. Die URL-Kurzform kann
mehrere Quellen mit abschließendem Schlüsselwort enthalten. Direkte Roblox-IDs
und Namen aus CursorIcons werden erkannt; andere Quellen fallen auf das
Schlüsselwort zurück. Browser können rbxassetid-Quellen nicht laden und zeigen
den Fallback. Keine Hotspot-Koordinaten oder HTTP-/lokalen Bilddateien für Roblox;
Asset-Ladefehler/-Berechtigungen behandelt Roblox, keine eigene asynchrone
Ladekette. Die Bildgröße/Positionierung der nativen Cursor-Assets bestimmt Roblox.

Auto: Text über Text-GUIs/Textfeldern, pointer über href-Links, default über
übrigen Flächen und Buttons. Ein deaktiviertes Feld erhält automatisch default;
not-allowed ist eine explizite CSS-Auswahl. Pointer stellt keine Link-Navigation
bereit. Textarea-Ziehgriffe verwenden nwse-/ew-/ns-resize und halten diesen
Zeiger während des Mausdrags auch außerhalb des Feldes. Die temporären
Fensterecken verwenden nwse-/nesw-resize und sind jetzt passive Frames.

CursorController arbeitet auch ohne Formularcontrols. Änderungen kommen über
Mausereignisse, Scroll-/Root-Geometrie, Sichtbarkeit, Fensterfokus und fertige
Layouts. Kein RenderStepped/Heartbeat und kein Cursor-bedingter Layout-Aufruf.
RenderTree speichert NodeStyles/HitStyles; InlineWords trennt Fragmente an Cursor-
und Linkgrenzen, auch ohne Leerzeichen und innerhalb eines Labels.

CursorLease koordiniert mehrere Seiten/Resize-Griffe auf demselben InputService.
Beim Verlassen, Touch, Fokusverlust oder Destroy wird der vorherige Zeiger
wiederhergestellt. Spätere Änderungen anderer Scripts werden beim Loslassen
nicht überschrieben. Fenstergriffe haben höhere Priorität. HTMLInputBlocker
markiert ihre passiven Frames für HitTest, ohne TextButton/ImageButton.

Darstellung über UserInputService.MouseIcon. Roblox kann das Icon über nativen
TextBoxen vorübergehend durch den eigenen Textcursor ersetzen. CursorPreload lädt
alle unterschiedlichen IDs beim ersten mountHTML einmal pro Client im Hintergrund
über ContentProvider:PreloadAsync vor. Temporäre, ungeparentete ImageLabels werden
anschließend auch bei Fehlern zerstört. Layout und Eingabe warten nicht darauf;
vor Abschluss des Downloads kann der erste Cursorwechsel weiterhin verzögert sein.
Zusätzliche, nicht im Katalog enthaltene CSS-url-Assets werden nicht vorgeladen.
Keine künstliche
Cursor-Overlay-GUI; deshalb kann CSS über einem Editor diese Roblox-Vorgabe
nicht in jedem Zustand übersteuern. Die gelieferten Assets sind erst im echten
Studio/Spiel auf Zugriff und sichtbare Übereinstimmung zu prüfen.

Demo32 enthält jedes unterstützte Schlüsselwort einmal und das url-Asset mit
Browser-Fallback. Tests/Cursors prüft Mapping, CSS, Vererbung, fragmentierte Texte,
Auto-Ziele, none, URL-Fallback, Touch/Fokus, stationäre Aktualisierung, Resize-
Capture, mehrere Besitzer und Cleanup. Tests/HTMLPageDemo prüft die vollständige
Liste. Tests verwenden GUI-/Input-Mocks.

Referenz: [Roblox UserInputService](https://create.roblox.com/docs/reference/engine/classes/UserInputService).
