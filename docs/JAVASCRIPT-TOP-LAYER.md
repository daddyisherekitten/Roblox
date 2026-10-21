# JavaScript: Dialoge und Popover

Stand: 4. Oktober 2026. Implementierter Teilumfang aus P07, Vergleich 06.

## Erreichbare APIs

| Bereich | Implementiert |
| --- | --- |
| Dialog | show(), showModal(), close(returnValue), requestClose(returnValue), open, returnValue, closedBy |
| Popover | showPopover(options), hidePopover(), togglePopover(force/options), popover-Attributreflexion; auto, hint und manual |
| Ereignisse | ToggleEvent mit oldState/newState/source; beforetoggle, gebündeltes toggle, cancel und close samt Handlerproperties |
| Standardaktionen | command/commandfor, popovertarget/popovertargetaction, method="dialog", Escape, Klick außerhalb, Fokus und Fokuswiederherstellung |
| Darstellung | :modal/:popover-open, gemeinsame Reihenfolge für Modal-Hintergrund und Popover, Opacity/Transform-Außensurfaces; gemeinsame CSS-Positionierung mit Autor-Inset, Auto-Margin, Größenbegrenzungen und schriftabhängigen UA-Abständen |
| DOM-Lebensdauer | Einfügen/Entfernen, Attributkonvertierung eines vorhandenen Elements, erhaltene Box-/Controlidentität, Resize und Ressourcenabbau |

JavaScript/TopLayer ist der gemeinsame Besitzer des Zustands. Runtime verbindet native Aktionen mit dem vorhandenen serialisierten Realm-Einstieg. Rendering/HTMLScripts, Dialog/Popover und Input/Controller setzen Zustand, Fokus, CSS-Pseudoklassen und native Darstellung um. DOMReconcile und RenderTree halten die Registrierungen nach Strukturänderungen aktuell. Methoden prüfen ihren Empfänger und wandeln Argumente nach Web-IDL-Regeln um.

Öffnendes beforetoggle ist abbrechbar. requestClose löst cancel aus und respektiert preventDefault; close schließt direkt. toggle/close verwenden die vorhandene Aufgabenwarteschlange. Ein erneuter Zustandswechsel ersetzt die wartende Toggle-Aufgabe, statt beliebig viele wirkungslose Aufgaben anzusammeln. Native Eingaben und API-Aufrufe teilen dieselben Algorithmen. Popover-Wechsel brauchen keine Layoutberechnung, solange Größe, Selektoren und Dokumentfluss unverändert bleiben.

## Nachweise

Nichtmodale Dialoge bleiben in der gewöhnlichen CSS-Stapelung. Autorregeln bestimmen, ob sie statisch, absolut oder fest positioniert sind; transformierte Vorfahren bleiben ihre Bezugselemente. Modale Dialoge und geöffnete Popover verlassen diese Vorfahren für ihre oberste Ebene. Absolute Elemente dieser Ebene scrollen mit dem Dokument, feste bleiben am Viewport. CSS-Viewportwerte und die nach Scrollleisten verbleibende Layoutfläche werden getrennt berechnet. Rendering/TopLayerLayout und Layout/PositionedLayout teilen diese Regeln mit gewöhnlichen Elementen; es gibt keine Seiten-Sonderpositionierung.

- 21 unveränderte JavaScript-Referenzen stimmen im nativen Browser und in Luau überein: Methoden, Umwandlung, Receiver, No-ops, Fehler, Quellen, Aufgabenreihenfolge, Attribute und verschachtelte Auto-/Hint-/Manual-Fälle.
- JavaScriptTopLayerRendering prüft echte native Controls, Formulare, Fokus/Inertheit, Escape, gemeinsame Ebenen, Opacity, gezielte Paint-Aktualisierung, Resize und Detach/Rebind.
- JavaScriptTopLayerPerformanceReviewPage vergleicht 25 Bedienzustände der eingefrorenen Vergleichsseite 06 gegen Browserzustände und prüft zusätzlich dynamische Ressourcen und Cleanup.
- TopLayerPositioning vergleicht 104 native Browsermessungen: gewöhnliche und transformierte Vorfahren, Autor-Insets/Positionen, Auto-Margins, Scrollen, zwei Viewportgrößen, Scrollleisten, Schriftgrößen, UA-Padding und Größenbegrenzungen. Alle 24 Bedienaktionen der Vergleichsseite laufen zusätzlich durch tatsächliche native Mausereignisse und Hit-Tests.

Quellen: tests/fixtures/javascript-top-layer.json, javascript-top-layer-browser.json,
top-layer-positioning.json und top-layer-positioning-browser.json. Vergleich 06
bleibt unter javascript-top-layer-review-page.json erhalten; die aktuelle Seite 07
unter examples/websites/javascript-tests enthält eine kompakte Dialog-/Popoverkarte.
Keine FPS-Messung. Der native Studio-Sichtvergleich der Korrektur ist noch offen.

## Grenzen

Dieses Profil ergänzt Methoden auf den vorhandenen DOM-Wrappers. Es behauptet keine vollständige HTMLElement-/HTMLDialogElement-Konstruktor- und Prototypfamilie. CloseWatcher als öffentliche API, Attributhandler mit vollständigem Standardscope, Cross-Realm/Shadow-/Iframe-Inertheit und sämtliche Accessibility-/OS-Fokusdetails bleiben weitere Teilpunkte. Die vorhandenen Grenzen für besondere Tabellen-/Shadow-Strukturen gelten auch innerhalb dynamischer Dialoge. CSS-Verarbeitung und native Text-/Schriftgeometrie behalten ihre separat dokumentierten Grenzen.

Für erneute Popover-Aufrufe innerhalb von beforetoggle folgt dieses Profil dem geprüften nativen Browser: Ein erneuter Aufruf auf demselben Element während seines laufenden Zustandswechsels wird ignoriert. Der neueste WHATWG-Algorithmus fordert hier teilweise InvalidStateError. Vollständige Konformität für beliebige verschachtelte Show-/Hide-Aufrufe wird deshalb noch nicht behauptet. Entfernen des popover-Attributs während des Schließereignisses räumt den Zustand auf, ohne beforetoggle nochmals auszulösen.

Normative Grundlagen: [HTML-Dialoge](https://html.spec.whatwg.org/multipage/interactive-elements.html#the-dialog-element), [HTML-Popover](https://html.spec.whatwg.org/multipage/popover.html), [ToggleEvent](https://html.spec.whatwg.org/multipage/interaction.html#the-toggleevent-interface), [Web IDL](https://webidl.spec.whatwg.org/).
