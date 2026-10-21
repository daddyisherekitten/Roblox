# Arbeitsplan und gemeinsame Regeln

Stand: 9. Oktober 2026. Diese Datei enthält den gemeinsamen Ablauf und die
dauerhaften Projektentscheidungen. Die detaillierten Funktionspläne bleiben
bei ihren jeweiligen Fachbereichen im [Dokumentationsindex](docs/README.md).
Die frühere Planung ist [vollständig archiviert](docs/history/2026-10-06/PLAN-original.md).

## Ziel

Standard-HTML, CSS und JavaScript sollen im Browser und in Roblox möglichst
gleich funktionieren und aussehen. Keine LESS-, jQuery- oder sonstigen
Website-Erweiterungen voraussetzen. Grenzen konkret benennen und mit ihrem
Nachweis erfassen; ein abgeschlossenes Paket ist keine vollständige Kategorie.

## Verbindlicher Gesamtabschluss

Der Auftrag, alle grundsätzlich umsetzbaren HTML-/CSS-Restpunkte zu ergänzen,
bleibt bestehen. H01–H06 und C01–C09 teilen die Arbeit auf; ihr letzter Paketabschluss
beweist keinen vollständigen Gesamtabschluss. Die bestehenden HTML-/CSS-Register
und Fachprofile bleiben maßgeblich. Keine zusätzliche parallele Funktionsliste.

Für einen überprüfbaren Endpunkt muss jede Anforderung des Zielbestands dort
einzeln zugeordnet sein: dokumentierte Standardversion bzw. eingefrorene Quelle,
zulässige und ungültige Werte, Verhalten, Darstellung, dynamische Änderungen,
betroffene Kombinationen und Abnahmekriterien. Derselbe Name in einem Katalog
oder eine bestandene Beispielseite ersetzt diese Zuordnung nicht. Die notwendige
Aufteilung der bestehenden Register in solche Anforderungen ist noch nicht
vollständig durchgeführt; eine genaue Gesamtzahl verbleibender Arbeiten oder
ein Abschlussprozentsatz wird bis dahin nicht behauptet. Neue Standardversionen
werden getrennt als späterer Ausbau erfasst, nicht still in den Zielbestand übernommen.

Jede Anforderung erhält einen eindeutigen Abschlussstand:

| Stand | Bedingung |
| --- | --- |
| Erfüllt | Festgelegte Semantik und Darstellung umgesetzt, erforderliche Fehler-/Änderungs-/Kombinationsfälle geprüft; Nachweise und Umgebung benannt. |
| Offen | Umsetzung fehlt oder erreicht die festgelegten Kriterien noch nicht. Ein funktionierender Teilumfang bleibt innerhalb dieses Standes benannt. |
| Ungeprüft | Verhalten oder Wirkung noch nicht ausreichend untersucht; zählt für den Gesamtabschluss ebenso wie offen. |
| Technische Grenze | Konkrete Roblox-/Hostgrenze mit Nachweis und betroffener Anforderung dokumentiert. Ein fehlender Adapter, hoher Aufwand oder ein fehlender Test allein reichen nicht. |
| Bewusst zurückgestellt | Ausdrückliche Nutzerentscheidung dokumentiert, beispielsweise die echte Dateiauswahl. Nicht als technische Unmöglichkeit oder erfüllte Funktion ausgeben. |

Eine Annäherung benennt das tatsächlich gelieferte Verhalten und die Abweichung.
Sie erfüllt die ursprüngliche Anforderung nur, wenn ihre Abnahmekriterien damit
erreicht werden oder der Nutzer diese Abweichung ausdrücklich akzeptiert hat.
Implementierbare Restfälle werden weder wegen Seltenheit noch wegen Aufwand
aus dem Auftrag entfernt. Ohne weitere Nutzerentscheidung gelten nur belegte
technische Grenzen und bereits ausdrücklich zurückgestellte Funktionen als Ausnahmen.

Der Gesamtumfang ist abgeschlossen, wenn der Zielbestand vollständig zugeordnet
ist, keine offenen oder ungeprüften Anforderungen verbleiben, alle Ausnahmen
belegt sind, die erforderlichen Regressionen und der Codepfadreview bestehen
und die vereinbarte Browser-/Roblox-Vergleichsseite erstellt und visuell abgenommen
ist. Ladeverhalten, Paint-/Layouttrennung, GUI-Erhaltung und Ressourcenabbau
gehören zu dieser Abnahme. Automatische Ersatzobjekttests und native Studio-
Abnahme werden weiter getrennt ausgewiesen.

Ein später gefundener Fehler innerhalb des festgelegten Umfangs wird als Fehler
mit Regressionstest behoben. Eine bereits bekannte, aber bisher nicht erfasste
Standardanforderung wird als Erfassungslücke gekennzeichnet; ihre Entdeckung
wird nicht als neuer freiwilliger Ausbau dargestellt. Gesamtabschlussmeldungen
dürfen solche bekannten Lücken nicht verschweigen. Bis zur vollständigen
Zuordnung werden Ergebnisse als abgeschlossene Teilanforderungen mit dem
weiterhin offenen Paketstand gemeldet.

## Zuständigkeiten

| Information | Eine maßgebliche Stelle |
| --- | --- |
| Start, Demoauswahl, Bedienung | [README](README.md) |
| Architektur und Modulverantwortung | [ARCHITECTURE](docs/ARCHITECTURE.md) |
| HTML-Abdeckungsprüfung und verbleibende Erfassung | [HTML-COMPLETION](docs/HTML-COMPLETION.md) |
| CSS-Abdeckungsprüfung und verbleibende Erfassung | [CSS-COMPLETION](docs/CSS-COMPLETION.md) |
| JavaScript-Bestand | [JAVASCRIPT-IMPLEMENTATION](docs/JAVASCRIPT-IMPLEMENTATION.md) |
| JavaScript-Ausbau P/R | [JAVASCRIPT-ROADMAP](docs/JAVASCRIPT-ROADMAP.md) |
| SVG-Bestand und Ausbau S | [SVG-SUPPORT](docs/SVG-SUPPORT.md), [SVG-PLAN](docs/SVG-PLAN.md) |
| Letztes Arbeitsergebnis | [AI-HANDOFF](docs/AI-HANDOFF.md) |
| Datierte Nachweise | [PROJECT-REVIEW](docs/PROJECT-REVIEW.md) |

README und Übergabe verlinken den Funktionsbestand; sie führen keine eigenen
P/R/S-Abhaklisten. Detaillierte Profile gehören zu dem im Index genannten Bereich.

## Architekturregeln

- Engine und Browseroberfläche bleiben getrennt. Tests und Demos liegen außerhalb
  der Engine; ausgelieferte Website-Module werden aus Browserquellen generiert.
- Alle GuiObjects behalten `Active = false`, natives Scrollen bleibt aktiviert.
  Klick, Hover, Fokus und Trefferprüfung verwenden das eigene Eingabesystem.
- Eine Seite besitzt ihren Scrollbereich; Seitenelemente bleiben hierarchisch
  zugeordnet. Keine Entfernung oder Nichterstellung wegen Entfernung zum Viewport.
- Standardmäßig ein TextLabel pro Wort; bei abweichendem `letter-spacing` Labels
  je Graphem im Wort-Frame. Keine Umstellung auf Satz-Labels.
- Textmaße werden individuell gemessen. Unveränderte Elemente behalten ihre
  eigenen Messwerte; keine geteilten Textmaß-Caches zwischen verschiedenen Elementen.
  Schriftgrößen verwenden `ceil(htmlSize * fontFactor)`; bestehende Kalibrierungen erhalten.
- Paint-, Layout-, Struktur- und Ressourcenänderungen getrennt behandeln.
  Unveränderte GUI-/DOM-Identität, Scrollposition und Eingaben erhalten. Notwendige
  Verschiebungen nachfolgender Elemente bleiben Teil der Layoutabhängigkeiten.
- Änderungen bündeln, nur bei Arbeit rechnen; keine Schleife pro Element und
  kein dauerndes Scannen ruhender Seiten. Lange Ladeabschnitte in begrenzte
  Arbeitspakete teilen. Langsameres Laden ist einem großen Hänger vorzuziehen.
- Fensterziehen soll erst beim Loslassen neu layouten; sprunghafte Größenwechsel
  wie Fullscreen behandeln. Kein pauschales 200-ms-Resize-Debounce wiedereinführen.
- Beim Abbau Jobs, Events und native Ressourcen freigeben; späte Ergebnisse
  dürfen keine zerstörte oder neue Seite verändern. Pools/Caches brauchen
  begrenzte Größen, klare Besitzer und vollständiges Zurücksetzen.
- Nur dokumentierte Ressourcenhosts zusichern. Roblox-Bild-/Font-/Audio-Zuordnungen
  ersetzen keinen allgemeinen Webdownload oder eine zugesicherte Assetberechtigung.
- Module nach Aufgabe trennen; ab etwa 400–600 Zeilen Verantwortung prüfen.
  Keine leeren Gerüste auf Vorrat und keine Sammeldatei für unabhängige Aufgaben.
- Die bisherigen Nutzerentscheidungen zur angenäherten Textdekoration bleiben
  erhalten: keine neue Kalibrierung pro Schrift allein für Unter-/Durchstreichung.
  Die ursprünglichen Formeln und Messangaben stehen im archivierten Plan.

## Ablauf für weitere Arbeit

1. Aktuellen Fachbereich, konkrete Lücke und betroffene Codepfade bestimmen.
   Alte offene Listen zuerst mit neueren Profilen und Code abgleichen.
2. Einen klar begrenzten Funktionsumfang mit Abschlusskriterien festlegen.
   Verhalten, sichtbares Ergebnis, Fehler und Kombinationen einschließen.
3. In der bestehenden Architektur implementieren. Standardreferenz und dieselben
   Websitequellen für Browser und Roblox verwenden.
4. Nach jedem größeren Paket den Code samt betroffenen Verbindungen reviewen:
   VM/DOM, Layout, Rendering, Eingabe, Ressourcen und Lifecycle.
5. Sinnvolle Funktions-/Integrationsregressionen und erforderliche Checks ausführen.
   Paint ohne Layout, lokale Invalidierung, Wiederverwendung und Abbau strukturell
   prüfen. Automatische Tests sind erlaubt; FPS-Benchmarks übernimmt Tobias.
6. Das zuständige Fachprofil und seine Nachweise aktualisieren. Einen echten
   Studiovergleich, Ersatzobjekttests und eine Nutzerbestätigung getrennt führen.
7. Die Übergabe kurz aktualisieren. Datierte Ergebnisse archivieren; in README
   und diesem Plan nur Zuständigkeit oder Arbeitsablauf ändern.

## Nächster fachlicher Abgleich

Die Dokumentation wird jetzt geordnet. Ein vollständiger neuer HTML-/CSS-Audit
ist damit noch nicht durchgeführt. Danach ist der passende nächste Schritt:

1. HTML-Elemente, globale und elementbezogene Attribute gegen die Standardreferenz
   erfassen; Registrierung, DOM-Reflexion, Verhalten und Darstellung unterscheiden.
2. Die historischen HTML-/CSS-Checklisten mit aktuellem Code und neueren
   JavaScript-/DOM-Profilen abgleichen. Widersprüche einzeln auflösen.
3. Für jede echte Lücke Implementierung, Tests, Kombinationen, Hostgrenze und
   verbleibenden Sichtvergleich am zuständigen Fachprofil dokumentieren.

Der Auftrag vom 6. Oktober ist als abgegrenztes Paket dokumentiert:
[Dokumentparser/Attributkombinationen](docs/HTML-PARSER-ATTRIBUTES-20261006.md),
[Gesamtcode-/Pfadreview und sichere Kürzungen](docs/audit-2026-10-06/README.md)
sowie [datierter CSS-Referenzbestand mit Bedarf-/Hostgrenzen](docs/CSS-GAPS-20261006.md).
Der gesamte Enginebestand ist strukturell erfasst, kritische Ausführungspfade
zusätzlich semantisch geprüft. Die noch offenen Standardachsen stehen in den
Fachregistern; die Pakete behaupten keine vollständige Browserkonformität.
Eine nicht implementierte Funktion ist nicht automatisch unnötig oder unmöglich.
Bei neuen Änderungen bleiben Verhaltenserhalt, geeignete Regressionen und
Überprüfung der betroffenen Abhängigkeiten verbindlich. FPS-Messungen bleiben
beim Nutzer.

Dies ist ein Folgeplan und keine Zusage bereits implementierter Browservollständigkeit.
Frühere Nutzungsbudget-, Demo- und Freigabeangaben bleiben als datierte Historie
erhalten und werden nicht als aktuelle Sitzungswerte oder neue Aufträge übernommen.
