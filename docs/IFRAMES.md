# Eingebettete Dokumente

Kamera-/Mikrofonrechte werden im aktuellen Profil nicht an Iframes weitergegeben.
Der Child-Realm erhält `PermissionRequestsAllowed=false` und keinen Capturehost;
`getUserMedia` endet ohne Elternabfrage mit `NotAllowedError`, `permissions.query`
meldet `denied`. Die vollständige `allow`-/Permissions-Policy-Delegation bleibt
offen. Siehe [Medienprofil](MEDIA.md#kamera--und-mikrofonberechtigungen--16-oktober-2026).

Ein normales Browser-`iframe` kann eine registrierte Engine-Website auch in
Roblox einbetten:

```html
<iframe
  src="../css-background-position/index.html"
  title="Background positions"
  width="720"
  height="420">
</iframe>
```

Im Browser lädt `src` wie gewohnt. In Roblox löst der Website-Katalog dieselbe
URL auf und mountet das gefundene Modul als eigene `PageSession` in die
begrenzte iframe-Fläche. Das eingebettete Dokument besitzt eine eigene
Scrollposition, Eingabesteuerung, Formulare, Medien und Ressourcenbereinigung.
Die CSS-Hintergrundfarbe von `html` beziehungsweise bei transparentem Root von
`body` wird auf den vollständigen Dokument-Canvas übertragen. Sie füllt damit
auch den sichtbaren iframe-Bereich und horizontalen Überlauf statt dort die
weiße technische Host-Fläche zu zeigen.

Ohne Größenangaben verwendet das Element 300 × 150 Pixel. HTML-Attribute und
CSS für Breite, Höhe, Box-Sizing, Padding, Rahmen, Margin, Sichtbarkeit,
Positionierung, Flex und Grid laufen über das normale Layout der Engine.

Interne Links navigieren standardmäßig nur das eingebettete Dokument.
`target="_parent"` wechselt die direkt umgebende Seite; `target="_top"` wird
durch verschachtelte Frames bis zur obersten Seite weitergereicht. Fragmente
derselben Adresse scrollen ohne erneuten Mount. Eine unbekannte interne URL
zeigt die registrierte 404-Seite.

`srcdoc` wird ebenfalls als unabhängiges Dokument gerendert. Es besitzt
`document.URL = "about:srcdoc"`, den No-Quirks-Modus auch bei fehlendem oder
fehlerhaftem Doctype, und UTF-8 für seine bereits übergebene Unicodequelle.
Relative Adressen verwenden die beim Mount erfasste Basisadresse des Eltern-
dokuments. Eigene `base[href]`-Elemente werden dagegen ausgewertet; Änderungen
der späteren Elternbasis ändern die erfasste About-Basis nicht rückwirkend.
Die [20 nativen Referenzen](../tests/fixtures/srcdoc-browser.json),
[Srcdoc-Suite](../tests/Srcdoc.luau) und tatsächlichen
[Mountoptions](../tests/IFrames.luau) belegen diesen Umfang. Drei Chromium-
Abweichungen bei ungültigen Basisadressen sind ausdrücklich erhalten.
Leeres `src`
erzeugt eine leere `about:blank`-Seite. Maximal vier iframe-Ebenen dürfen
gleichzeitig verschachtelt werden. Beim Navigieren, Entfernen oder Zerstören der
Elternseite wird jede untergeordnete PageSession bereinigt.

Ausstehende Mounts und noch ladende Kinddokumente verzögern das `load` der
Elternseite. Ein erfolgreich geladenes Kind erzeugt genau ein `load` am
Frameknoten pro Navigation, nach seinen eigenen Load-Handlern und Microtasks.
Entfernung und ersetzte Navigationsgenerationen dürfen kein altes Ereignis mehr
ausliefern. Die Runtime bindet die script-blocking Stylesheet-Menge des direkten
Containerdokuments an Parser-/Defer-/Modulscripts des Kindes an; Async bleibt
unabhängig. Ein geerbter Ressourcenhost bleibt von der separaten Kind-Realm
getrennt. Die belegten Browservergleiche und Chromium-Unterschiede stehen im
[H03-Ressourcenprofil](HTML-PARSER-ATTRIBUTES-20261006.md),
[StylesheetEmbedded](../tests/StylesheetEmbedded.luau) und
[Mountcontroller-Test](../tests/IFrames.luau). Vollständige Browsing-Kontext-
Interfaces und native Studio-Abnahme sind damit nicht nachgewiesen.

## Sichtbarkeit und Navigation mit Leave-Abfrage — 15. Oktober 2026

Die tatsächliche Sichtbarkeit der umgebenden Seite wird jetzt rekursiv an ihre
Kinddokumente weitergegeben. `document.hidden`, `document.visibilityState` und
`visibilitychange` beziehen sich auf Tab-/Fenstersichtbarkeit; eine während des
Aufbaus vorübergehend verborgene GUI ändert diesen Dokumentzustand nicht.
Nachfolgend erzeugte oder ersetzte Kinder übernehmen den aktuellen Zustand.
`RuntimeCreated` des Elternhosts wird nicht an Kindrealms weitergereicht;
Ressourcen-/Dialoganbieter können weiterhin geteilt werden. Die Sandbox lässt
einfache Dialoge und Leave-Bestätigungen nur mit `allow-modals` zu, und eine
Sperre des umgebenden Hosts bleibt auch dann wirksam.

Auch `InputServices` werden für jedes Kind einschließlich `srcdoc` separat
zusammengesetzt. Eine ausdrücklich bereitgestellte Eingabequelle des Elternhosts
bleibt für dessen eingebettete Fläche zuständig; ein Kind kann diese Fenster-/
Modalsperre nicht durch den ungefilterten nativen Eingabedienst ersetzen.
Eigene Factory-, PlayerGui-, Task- und weitere Kinddienste bleiben erhalten.
Ohne ausdrücklich gesetzte Elterneingabe bleibt ein separater Kindadapter
verwendbar. `IFrames` prüft Vererbung, Vorrang und unveränderte Quelltabellen;
`StandaloneHTMLWindows` prüft die tatsächliche native Dialoginteraktion mit
einem eingebetteten Realm. Damit werden keine IFrame-Popup-/Window-Fassaden ergänzt.

Eine vollständige Kindnavigation beziehungsweise ein Reload fragt zuerst das
alte Dokument über `RequestLeave` ab. Ein abgebrochener Wechsel erhält seine
PageSession, Realm-Identität und Ladebeiträge. Ein bestätigter Wechsel führt vor
dem endgültigen `Destroy` einmal `CommitLeave` aus. Gehaltene Antworten prüfen
ihre Registrierungs-/Request-Lease erneut; eine neuere Kindnavigation wird durch
eine verspätete Bestätigung nicht zerstört. Fragmentnavigation bleibt im
vorhandenen Dokument und erzeugt keine Leave-Abfrage.

Beim Verlassen einer vollständigen Seite arbeitet `page:RequestLeave` zuerst die
eigene Realm und anschließend ihre Nachkommen ab. Eine gemeinsame Promptgruppe
zeigt höchstens eine Leave-Bestätigung; die übrigen `beforeunload`-Handler laufen
weiter, sofern kein Dokument den Wechsel abbricht. `page:CommitLeave` entlädt
Kinddokumente vor ihrem Elternteil. Das Profil verwendet keine BFCache und meldet
`persisted=false`. Eine reine Entfernung des `iframe` ist davon verschieden:
Sie zerstört das Kind ohne `beforeunload` oder `unload`, entsprechend den
[HTML-Entfernungsschritten](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element).
Die Reihenfolge beim vollständigen Verlassen folgt dem
[HTML-Unload-Algorithmus](https://html.spec.whatwg.org/multipage/document-lifecycle.html#unload-a-document-and-its-descendants).

Nachweise: [IFrameLifecycle](../tests/IFrameLifecycle.luau) prüft Sichtvererbung,
Dienstisolierung, Modalsperren und reentrante beziehungsweise gehaltene
Leave-Antworten; [IFrameLifecycleMounted](../tests/IFrameLifecycleMounted.luau)
verbindet die tatsächliche HTMLPage/PageSession/VM mit Sandbox-Dialogen,
Sichtbarkeit, gruppierten Leave-Abfragen, Ersetzung und Entfernung. Seine
kontrollierten nativen Painthelfer belegen keine Studio-Pixel; Realm-Tasks für
die Sichtprüfungen werden explizit fortgeschaltet. Die bestehende
[IFrameAttributeNavigation](../tests/IFrameAttributeNavigation.luau) mit
40 Kontrollen und 4060 Assertions besteht weiterhin.

Offen bleiben vollständige öffentliche Window-/Document-Fassaden,
Navigable-/History- und Fully-active-Regeln, weitere Sandbox-/Policy-Kombinationen,
BFCache, Lazy Loading und eine gemeinsam pausierte Browser-Agent-Taskschlange
über mehrere eigenständige Realms. Der anfragende Realm pausiert während seiner
Leave-Bestätigung; eine vollständige agentweite Pause sämtlicher Geschwister
wird damit nicht zugesichert. Native Studio-Abnahme bleibt separat.

## Lebende IFrame-Attribute und aktuelle Kindnavigation — 12. Oktober 2026

Der produktive begrenzte Pfad verbindet erfolgreiche null-namespace src/srcdoc-Schreibvorgänge mit der vorhandenen IFrameRuntime-Navigation. Der Setter erfasst seine aktuelle Basis; spätere base-Änderungen allein navigieren nicht. Gleiche src-/srcdoc-Werte laden erneut, srcdoc hat Vorrang, und sein Entfernen verwendet das aktuelle src. sandbox wird für die nächste Navigation übernommen. Fragmente behalten dieselbe Kindseite und ihren noch offenen Ladebeitrag.

Die aktuelle committed Kindseite besitzt eine eigene Lease: eine tatsächliche Kindnavigation nach C verdrängt eine bereits queued oder gehaltene Elternanforderung B. Überholte Ergebnisse/Ereignisse dürfen nicht publizieren; die IFrame-GUI und der Elterneditor mit UTF16-Auswahl bleiben erhalten. [IFrameAttributeNavigation](../tests/IFrameAttributeNavigation.luau) hat40/4060 strenge Kontrollen. Nach unabhängigem Review10fd662a sind Source2/Test40 und die unveränderte18-Fall-Rohfixture exakt produktiv; Root13 einschließlich zwölf Nachbarsuiten und PageLoading hat tatsächlichen Exit0.

[Details und getrennte Referenzen](HTML-PARSER-ATTRIBUTES-20261006.md#lebende-iframe-attribute-und-aktuelle-kindnavigation--12-oktober-2026) erhalten Chromium18/44 plus separate2/8 HTTP-Interleavings. Invalides src→about:blank und abgelehnte Vorfahrenadresse sind eigene Frozen-Projektionen, keine still veränderten Chrome-Rohwerte. Öffentliche Window/Document-Fassaden, detached/lazy, vollständige Sandbox-/Vorfahren-/History-Regeln, native Pixel und allgemeines GC und Lifecycle außerhalb des unten benannten Remove-/Destroy-Batches bleiben offen.

## IFrame-Einzelkind-Cleanup und getrennte Coroutine-Kontexte — 12. Oktober 2026

Der begrenzte Nachtrag zu [IFrameRuntime](../src/HTMLEngine/Rendering/IFrameRuntime.luau) führt eine aktuelle Ersetzung beziehungsweise den unavailable-Fehlerzustand nach einem Cleanupfehler des alten Kindes weiter. Er bewahrt den ersten rohen nil-/false-/Tabellenfehler trotz späterer bewachter Diagnose-, Load-Dispatch- oder Wakefehler. Aktuelle Registrierungs-/Request-/Dokumentgrenzen erhalten neue Quellen, erneut angemeldete Items und neue Owner; überholte Kinder und Rückmeldungen publizieren nicht.

Ein Fehlerkontext gehört zur aktuellen Coroutine. Nur synchrone verschachtelte Remove-/Destroy-/Einzelkind-Aufrufe teilen ihn; beim Ende wird der vorherige Eintrag wiederhergestellt beziehungsweise entfernt, bevor der Fehler weitergegeben wird. Ein pausierter Mount B darf deshalb den Fehler einer unabhängigen Navigation C weder verschlucken noch übernehmen.

[IFrameSingleChildCleanup](../tests/IFrameSingleChildCleanup.luau) hält 51 Kontrollen/819 Assertions; [IFrameSingleChildMounted](../tests/IFrameSingleChildMounted.luau) neun tatsächliche HTMLPage/PageSession/VM-Kontrollen/939 Assertions, zusammen 60/1758. Der Autorstand hat mit 15 unveränderten Nachbarn im 17-Suiten-Lauf tatsächlichen Exit 0. [BUILD-HOLD](../build/iframe-single-child-cleanup-prep/final-build-hold-v3.json) und Original-/V1-/V2-Rotbelege bleiben erhalten; ein neuer breiter Projektcheckpoint ist damit nicht belegt.

Die montierte Pause liegt nach Rückkehr der echten HTMLPage.mount im Mountadapter, vor Veröffentlichung des Kinddokuments. Sie belegt diese kooperative Grenze und eine weitere Navigation auf derselben C-Coroutine, keine gemessene WorkContext-Budgetpause innerhalb des Aufbaus. Andere asynchrone Callback-/Propertyfehler, hart abgebrochene Fortsetzungen, öffentliche Framefassaden, detached/lazy/history/Sandboxbreite, allgemeines GC und native Studio-Pixel bleiben offen.

## IFrame-Remove-/Destroy-Batches — 12. Oktober 2026

Der produktive begrenzte Pfad meldet vor Remove-/Destroy-Rückmeldungen alle alten Registrierungs-/Dokumentslots des Batches ab. Er schließt anschließend ausschließlich die vorher gefangenen Kinder. Ein während Cleanup neu veröffentlichtes Item oder ein neuer Owner bleibt erhalten; verschachteltes Remove/Destroy teilt den ersten Originalfehler und gibt ihn erst nach allem alten Cleanup weiter.

Der [begrenzte Nachweis](HTML-PARSER-ATTRIBUTES-20261006.md#iframe-remove-destroy-batches--12-oktober-2026) hält Original10/215, nested6/136 und tatsächliche HTMLPage/PageSession/VM6/487, insgesamt22/838; Autor15, unabhängiger15er und Root15 haben tatsächlichen Exit0. Nach Review6cb2b079 sind Source1/Test3 exakt produktiv; frühere HOLDs und drei Produktions-Rotbelege bleiben erhalten. Einzelkind-Ersetzung/unavailable sind im eigenen Nachtrag oben begrenzt belegt; sonstige Callback-/Property-Semantik und allgemeines GC werden durch den Batchnachweis nicht geschlossen.

`object` und `embed` verwenden für interne HTML-Dokumente dieselbe isolierte
Laufzeit. `object` liest die Adresse aus `data`, `embed` aus `src`:

```html
<object data="../css-background-position/index.html" type="text/html">
  <p>Fallback content</p>
</object>
<embed src="../css-individual-transforms/index.html" type="text/html">
```

Ohne `data` oder bei einem nicht unterstützten `object[type]` rendert die
Engine den Kindinhalt. Bei erfolgreichem HTML-Dokument bleibt dieser
Fallback wie im Browser verborgen. `embed` ist ein leeres Element und zeigt
bei nicht unterstütztem Typ stattdessen einen lokalen Fehlerzustand. Derzeit
werden `text/html`, `application/xhtml+xml` und ein fehlender Typ als internes
HTML-Dokument behandelt.

Roblox stellt keinen allgemeinen WebView bereit. Externe Websites können daher
nicht dargestellt werden und erzeugen einen sichtbaren Fallback. Noch nicht
vorhanden sind benannte Browsing-Kontexte, eigener Verlauf, echtes Lazy Loading,
vollständige Fehler-/Navigationsereignisse und Sandbox-/Permissions-Policy-Regeln.
`object` und `embed` unterstützen noch keine Bilder, Plugins, Formzuordnung
oder externen Netzressourcen.
