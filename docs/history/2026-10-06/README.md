# Originaldokumente vor der Neuordnung

Die Sicherung vom 6. Oktober 2026 enthält alle damals vorhandenen Markdown-
und JSON-Dokumente unter `docs`, README, PLAN sowie den vorherigen Projektprüfer.
Alle Inhalte sind bytegetreu erhalten; Zeichencodierung und Zeilenenden wurden
in der Sicherung nicht normalisiert.

[originals.zip](originals.zip) enthält die Originaldateien unter ihren damaligen
Projektpfaden. [preservation.json](preservation.json) führt jeden Pfad, Bytezahl
und SHA-256-Prüfsumme auf. Zum Wiederherstellen ausgewählte ZIP-Einträge zuerst
in ein separates Verzeichnis entpacken und vergleichen, bevor aktive Dateien
überschrieben werden. Neue Projektänderungen dabei erhalten.

## Direkt lesbare große Originale

- [README](README-original.md): früherer Einstieg mit angesammelten Funktionsständen.
- [PLAN](PLAN-original.md): vollständige ältere Regeln, Messformeln und Etappenpläne.
- [AI-HANDOFF](AI-HANDOFF-original.md): Entscheidungen, Schriftmessungen, Fixes und Übergaben.
- [PROJECT-REVIEW](PROJECT-REVIEW-original.md): frühere Code-/SVG-/Layout-/Formularreviews.
- [HTML-COMPLETION](HTML-COMPLETION-original.md): historische vollständige Checkliste.
- [CSS-COMPLETION](CSS-COMPLETION-original.md): historische vollständige Checkliste.

Relative Links in diesen unveränderten Originalen beziehen sich auf ihren
ursprünglichen Projektpfad. Für heutige Navigation den [aktuellen Index](../../README.md)
verwenden. Alte Checkboxen, Demo-, Budget- und Freigabestatus bleiben historische
Angaben und erteilen keine neuen Arbeitsaufträge.

## Ergebnis der Neuordnung

Die sechs großen Sammeldateien wurden durch kurze Einstiege mit klarer
Zuständigkeit ersetzt; ihre direkt lesbaren Originale stehen oben. Die weiteren
Fachprofile, P/R/S-Pläne, API-Daten und Auditprotokolle behalten ihre Pfade.
Ein Register ordnet alle 147 aktuellen Dokumentationsdateien einschließlich
Sicherung und maschineller Daten zu. Detailstatus wird nicht in README und
gemeinsamer Planung nochmals als eigene Abschlussliste geführt.

Verifikation am 6. Oktober: 136 Originaldateien vollständig anhand SHA-256
verifiziert, darunter 135 Markdown-/JSON-Dokumente und der vorherige Projektprüfer.
Die 1.379 Dateien unter `src`, `examples` und `tests` stimmen mit dem Stand vor
der Neuordnung überein. Lokale Markdownziele und Überschriften sind geprüft;
zwei bereits vorher fehlende Seitenverweise im September-Stresstest bleiben
explizit historisch klassifiziert. Die Projektprüfung und das unveränderte
JavaScript-API-Register bestehen. Der Dokumentationsprüfer besitzt eigene
Regressionen für Verlust, falsche Zuordnung, neue defekte Verweise und veränderte
Sicherungen. Dies ist keine neue Engine-Konformitäts- oder FPS-Prüfung.

Es werden nur Dokumente und deren Wartungsprüfung geändert. Alte Unsicherheiten
werden als abzugleichen erhalten; nur belegte veraltete Einstiegsangaben wurden
konkret korrigiert, etwa die aktiven Websites und der vorhandene Audiohost.

## Prüfen

```powershell
python scripts/check-documentation.py
python scripts/check-documentation.py --verify-cleanup
python scripts/test-documentation.py
```

Der Standardcheck verifiziert Sicherung, Dokumentregister und lokale Verweise.
`--verify-cleanup` prüft zusätzlich die gespeicherten Fingerprints von `src`,
`examples` und `tests`: Bei dieser Neuordnung bleibt deren Inhalt unverändert.
Spätere beabsichtigte Codeänderungen dürfen diesen einmaligen Vergleich verändern;
die Sicherungsprüfsummen werden dafür nicht neu erzeugt.
