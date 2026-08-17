# ShareItToo V5.1 - Umsetzungsbericht

Stand: 17.08.2026, lokaler Checkpoint 16.137

## Verbindliche Grenzen

- Der unveränderte interne Kandidat ist `1.0.0+2026081509`. Spätere
  Quelländerungen sind kein Kandidaten- oder Store-Nachweis.
- Echtgeld, produktive Zahlungen, öffentliche Rechtstexte, Produktion und
  Store-Einreichung bleiben gesperrt.
- Firebase Cloud Messaging und Firebase Crashlytics bleiben Bestandteil des
  Launchumfangs. Sie sind getrennte freiwillige Dienste, im nächsten
  Kandidaten standardmäßig aus; Push aktiviert Crashlytics nicht.
- Werbung, Marketingtracking, allgemeine Analytics und externe generative KI
  bleiben aus, solange sie nicht separat entschieden und geprüft wurden.

## Umgesetzt und technisch geprüft

- V5.1-Nachfolgemapping für die sechs früher offenen V4-Entscheidungen
- serverseitiges, zehn Minuten gültiges und manipulationsgeschütztes Angebot
- Plattformvertrag mit genau zwei ausdrücklichen Erklärungen
- unveränderlicher, authentifizierter HTML-Vertragsbeleg
- V5.1-Widerruf, getrennte Erstattungsobligationen und Stornoregeln
- rollen- und buchungsgebundene Übergabe-/Rückgabefotos mit Gegenbestätigung
- neutrale Rückgabezeitachse bis T0+5 sowie begründete Fallfristen
- exakter, hashgebundener Satz aus sieben deutschen V5.1-Rechtsassets
- unveränderliche Finanzdokumente ausschließlich aus erfolgreich erfassten
  Zahlungs-, Erstattungs- und Auszahlungssnapshots
- getrennte Darstellung von privatem Mietpreis und SIT-Plattformgebühr ohne
  pauschalen 19-%-Umsatzsteuerausweis auf die private Miete
- authentifizierter Belegdownload mit serverseitiger und clientseitiger
  Hashbindung; unbekannte Typen, falsche Summen und unvollständige Snapshots
  werden geschlossen abgelehnt

## Finanzdokument-Boundary

Vor einem tatsächlich erfolgreichen Quellereignis entsteht kein Beleg. Der
Mieter erhält nach erfolgreicher Zahlung eine Buchungs-/Zahlungsübersicht und
gegebenenfalls einen separaten SIT-Gebührenbeleg. Der Vermieter erhält keine
SIT-Gebührenrechnung, sondern erst nach einer tatsächlich ausgeführten
Auszahlung einen Auszahlungsnachweis. Ein Erstattungsbeleg entsteht erst nach
erfolgreicher Erstattung und weist Mietpreis und SIT-Gebühr mit getrennten
Schuldnern aus.

Die Datenbank erzwingt Dokumenttyp, Quellobjekt, Rollen und Summengleichungen.
Dokumente und Downloadereignisse sind append-only. Die Release-App bezieht die
Liste authentifiziert vom Backend, ruft vor PDF-Darstellung den exakten
Serverbeleg ab und vergleicht dessen Hash mit dem unveränderlichen Snapshot.
Nur der ausdrücklich markierte QA-Modus darf lokale Testbelege erzeugen; diese
tragen sichtbar `TESTBELEG` und sind weder Echtgeld- noch Steuerbelege.

Echtbetrieb bleibt zusätzlich geschlossen, bis Betreiber-/Steuerangaben,
SIT-Gebühren-Steuerbehandlung und Live-Ausstellung ausdrücklich freigegeben
sind. Migration 020 wurde nicht auf Staging oder Produktion angewandt; dieser
Checkpoint ist Quell- und Teststand, kein Deployment.

## Rechtsasset-Boundary

Der V5.1-Satz wird aus genau der 54-seitigen Quelle mit SHA-256
`587bfd9e53539e5895c3d9dcb6fc437e0bf7c6e91db144841d0fe986b274b3fc`
reproduzierbar erzeugt. Das Manifest bindet jede Datei an ihren Inhalts-Hash.
Es bleibt `draft-blocked`, kann nicht veröffentlicht und nicht in
`legal_document_snapshots` provisioniert werden.

Die Quelle behauptet auf Seite 38 noch, dass externe Push- und Crashdienste im
Startbetrieb deaktiviert seien. Die spätere Produktentscheidung vom 17.08.2026
behält FCM und Crashlytics bei. Dieser Widerspruch ist im Manifest ausdrücklich
als aktivierungsblockierend festgehalten. Vor einer Freigabe müssen der
Datenschutztext angepasst und Anbieter-, Transfer-, Einwilligungs-,
Aufbewahrungs-, Lösch- und Store-Nachweise geschlossen werden.

## Offene Tatsachen und Gates

- vollständige Betreiber-/Register-/Steuerangaben
- finale öffentliche Widerrufs-URL
- Hosting-, SMTP- und Kartenanbieter samt Regionen
- lizenzierter Marketplace-PSP samt Vertrag, Region und Geldfluss
- Firebase Push-/Crash-Provider-, Transfer- und Vertragsnachweise
- neun Aufbewahrungs-/Löschentscheidungen
- vier reale physische Gerätematrix-Fälle
- neuer signierter Kandidat und vollständige Kandidatenbindung
- unabhängige Rechts-/Produktprüfung, soweit verfügbar

Bis diese Punkte belegt sind, bleibt Go/No-Go auf `HOLD`.

Die neun Aufbewahrungs-/Löschfragen sind in Checkpoint 16.127 nicht mehr ein
undifferenzierter Block: Für jede Entscheidung liegen jetzt Klassifikation,
Empfehlung, Implementierungsstand und belastbare Quellen vor. Zwei Regeln sind
technisch beziehungsweise betrieblich entscheidungsreif (Credential-Purge und
14-Tage-Backuprotation). Die übrigen Regeln bleiben bewusst offen, bis ihre
Betreiber-/Rechtsgrundlage bestätigt ist. Keine kategorieweise Löschung wurde
aktiviert.

## Prüfstand Checkpoint 16.126

- Backend: 198 bestanden, 1 PostgreSQL-Integrationstest ohne lokale
  `TEST_DATABASE_URL` bewusst übersprungen
- Flutter: 275 bestanden, 1 bewusster Skip
- Analyzer: 229 Hinweise, 0 Fehler
- technische Node-/Vertragsprüfungen: 607 bestanden
- Finanzdokument-spezifisch: 7 Backend-, 3 Modell-/Fail-closed- und 4
  Verkabelungstests bestanden
- Rechtsasset-Validator: 6 bestanden
- Datenschutz-, Rechts-, Retention-, Store- und Release-Gates: grün und
  weiterhin fail-closed
- Web-Debug-Build: grün
- Android-Debug-Build: grün

Dieser Bericht beschreibt den Quell- und Prüfstand. Er ist keine Freigabe für
Produktion, Echtgeld, öffentliche Verträge oder Store-Review.

## Prüfstand Checkpoint 16.127

- alle neun Retention-/Löschentscheidungen einzeln vorbereitet, keine als
  beschlossen ausgegeben
- maschinenlesbarer Beleg und lesbare Entscheidungsmatrix gebunden
- FCM-Push und Firebase Crashlytics ausdrücklich erhalten: getrennte
  freiwillige Opt-ins, beide standardmäßig aus, keine Kopplung
- abgelaufene Zugangsdaten: bestehende automatische Bereinigung mit Startlauf,
  Sechs-Stunden-Takt und maximal vorgeschlagenem 24-Stunden-Abschlussfenster
- Backups: bestehende 14-Tage-Rotation als Betreiberentscheidung vorbereitet;
  keine falsche Behauptung kontobezogener Einzellöschung aus alten Backups
- HGB-, AO-, BGB- und BfDI-Quellen gebunden; keine pauschale Rechtsfrist auf
  fachlich unterschiedliche Daten übertragen
- Retention-/Datenschutz-/V5.1-Validatoren grün und weiterhin fail-closed
- vollständige Node-Prüfsuite: 611 bestanden, 0 fehlgeschlagen
- bestehender Kandidat, Staging, Produktion, Store, Echtgeld und öffentliche
  Rechtstexte unverändert

## Prüfstand Checkpoint 16.131

- alle Flutter-Bilddarsteller nutzen jetzt zentral `AppImage`; direkte
  `Image.network`-/`NetworkImage`-Umgehungen außerhalb dieses kontrollierten
  Darstellers sind entfernt
- ein signierter Release lädt ausschließlich Bilder aus dem authentifizierten
  SIT-Uploadspeicher; beliebige externe Hosts und unbekannte Schemas enden
  neutral und ohne Netzabruf
- lokale Debug-/QA-Demos behalten ihren ausdrücklich auf Nicht-Release-Builds
  begrenzten externen Bildpfad
- `backend_config.dart` und `app_image.dart` sind als datenschutzrelevante
  Quellen hashgebunden; der Datenschutzvalidator bleibt `draft` und
  fail-closed
- 277 Flutter-Tests bestanden bei einem bewussten Skip; 618 Tooltests,
  Android-Debug-Build und Web-Debug-Build bestanden; der Analyzer bleibt bei
  229 Hinweisen und 0 Fehlern
- FCM-Push und Firebase Crashlytics bleiben unverändert erhalten: getrennte,
  freiwillige, standardmäßig ausgeschaltete Entscheidungen; Push aktiviert
  Crashlytics nicht
- bestehender Kandidat `1.0.0+2026081509`, Staging, Produktion, Store,
  Echtgeld und öffentliche Rechtstexte blieben unverändert. Nachweis:
  `docs/evidence/b11/v51-release-image-origin-policy-20260817.json`

## Prüfstand Checkpoint 16.132

- der unveränderte Play-Internal-Kandidat `1.0.0+2026081509` wurde auf dem
  physischen Pixel 7 Pro ohne TalkBack bei 200-Prozent-Schrift auf allen fünf
  Hauptflächen geprüft
- Erkunden, Wunschlisten, Buchungen, Nachrichten, Profil und die
  Hauptnavigation renderten; Wunschlistentitel und zentrale Profilfakten
  wurden im bestehenden Kandidaten jedoch sichtbar gekürzt
- der Großtext-Fall bleibt deshalb ehrlich `testing` beziehungsweise nicht
  bestanden; TalkBack-Traversierung bleibt als eigener Nachweis offen
- die Quelle schaltet Wunschlisten ab 160 Prozent auf eine einspaltige,
  höhenangepasste Darstellung mit zwei Titelzeilen und stapelt im Profil
  Identität und ungekürzte Kennzahlen vertikal
- zwei neue 200-Prozent-Widgettests und vier fail-closed
  Verkabelungstests sichern die Korrektur; vollständige Regressionen ergaben
  279 Flutter-Tests plus einen bewussten Skip und 622 Tooltests ohne Fehler
- Analyzer unverändert 229 Hinweise bei 0 Fehlern; Android- und
  Web-Debug-Build bestanden
- der Quellfix ist noch kein physischer Pass: Er benötigt einen neuen,
  eindeutig gebundenen signierten Kandidaten und erneute Geräteprüfung
- FCM-Push und Firebase Crashlytics blieben unverändert erhalten, getrennt,
  freiwillig und standardmäßig aus; Push aktiviert Crashlytics nicht
- Produktion, Store, Echtgeld, öffentliche Rechtstexte und der bestehende
  Kandidat blieben unverändert. Nachweis:
  `docs/evidence/b11/android-large-text-physical-2026081509-20260817T053900Z.json`

## Prüfstand Checkpoint 16.133

- auf dem unveränderten Play-Internal-Kandidaten wurden die Konto- und
  Moderationsoberflächen mit einem synthetischen Konto physisch geprüft
- die Kontolöschung zeigte Voraussetzungen und Unwiderruflichkeit und wurde
  sicher abgebrochen; kein Konto wurde gelöscht
- die Blockliste war erreichbar; der private Datenexport öffnete die
  Android-Freigabeoberfläche, die ohne Zielauswahl geschlossen wurde
- das synthetische Gegenprofil bot Melden und Blockieren; die Meldegründe
  waren erreichbar, ohne eine Meldung abzusenden
- die App verweigerte das Blockieren korrekt, solange Übergabe oder Rückgabe
  noch nicht vollständig abgeschlossen waren; niemand wurde blockiert
- der Gesamtfall bleibt `testing`: erfolgreiche UI-Blockierung mit Rücknahme
  und tatsächliche UI-Löschung eines neuen Wegwerfkontos sind noch offen
- serverseitige Nachweise für Melden, Blockieren mit Rücknahme, privaten Export
  und isolierte Wegwerf-Kontolöschung bleiben gültig
- FCM-Push und Firebase Crashlytics blieben unverändert erhalten, getrennt,
  freiwillig und standardmäßig aus; Push aktiviert Crashlytics nicht
- Produktion, Store, Echtgeld, öffentliche Rechtstexte und der bestehende
  Kandidat blieben unverändert. Nachweis:
  `docs/evidence/b11/android-moderation-account-ui-2026081509-20260817T061138Z.json`

## Prüfstand Checkpoint 16.134

- der Crashlytics-Restnachweis wurde auf dem unveränderten Play-Kandidaten
  gezielt und ohne Crashereignis vorgeprüft
- dessen Benachrichtigungseinstellungen enthalten noch die ältere
  Feed-Steuerung, aber nicht die später implementierten getrennten freiwilligen
  Gerätedienst-Schalter für Push und Crashdiagnose
- der exakt begrenzte kalte App-Link für
  `b11-android-2026081509` endete erwartungsgemäß mit `Diagnose gesperrt`;
  es wurde kein kontrolliertes oder produktives Crashereignis erzeugt
- Mapping, native Symbole, Cache-Drain und sichtbare exakte
  Crashlytics-Releasezuordnung bleiben bestanden; nur das kontrollierte,
  bereinigte Ereignis bleibt offen
- der nächste Kandidat muss die unabhängigen, standardmäßig ausgeschalteten
  Einwilligungen enthalten, genau einen Staging-Lauf kompilieren und nach
  freiwilliger Aktivierung die exakte Console-Zuordnung beweisen; danach wird
  Crashdiagnose wieder ausgeschaltet
- Push blieb unangetastet und aktiviert Crashlytics weiterhin nicht
- Produktion, Store, Echtgeld, öffentliche Rechtstexte und der bestehende
  Kandidat blieben unverändert. Nachweis:
  `docs/evidence/b11/android-crash-controlled-event-gate-2026081509-20260817T061900Z.json`

## Prüfstand Checkpoint 16.135

- der lokale Plan für den nächsten konsolidierten internen Kandidaten wurde
  verschärft; gebaut oder hochgeladen wurde noch nichts
- `2026081510` ist ausschließlich für Google-Anmeldung, internen Kanal und
  isoliertes Staging zulässig; Apple, Facebook, Produktion, Store-Einreichung
  und Echtgeld bleiben geschlossen
- FCM-Push und Firebase Crashlytics sind als getrennte, freiwillige und
  standardmäßig ausgeschaltete Dienste verbindlich im Kandidatenvertrag
  erhalten
- der Build wird technisch verweigert, solange nicht genau der
  buildgebundene bereinigte Crashlauf `b11-android-2026081510` aktiviert ist
- Großtextkorrektur für Wunschlisten und Profil muss enthalten bleiben;
  V5.1-Rechtsassets bleiben `draft-blocked`
- 14 Plan-, Rollover-, Provider-, Crash- und Fail-closed-Tests bestanden; der
  aktuelle Stand bleibt bewusst `prepared-not-built`, weil die Buildnummer
  noch unverändert `2026081509` ist
- Produktion, Store, Echtgeld, öffentliche Rechtstexte und der bestehende
  Kandidat blieben unverändert. Nachweis:
  `docs/evidence/b11/next-candidate-safety-contract-2026081510-20260817.json`

## Prüfstand Checkpoint 16.136

- der konsolidierte interne Android-Kandidat `1.0.0+2026081510` wurde aus
  Commit `4cb004641391efe40fa2bf89f62da11bc1f71291` gebaut, kanonisch signiert,
  binär auf Datenschutz geprüft und im privaten unveränderlichen Archiv
  abgelegt
- AAB und APK sind lokal vorhanden; es erfolgte kein Upload, keine
  Store-Einreichung, keine Closed-Test-Änderung, keine Produktion und kein
  Echtgeldvorgang
- vollständige Regression: 279 Flutter-Tests bestanden, 1 bewusster Skip,
  Analyzer 229 Hinweise und 0 Fehler, Web- und Android-Debug-Build grün sowie
  14/14 Kandidaten-/Rollover-Tests grün
- der Kandidat wurde nach der erwarteten Signaturabweichung zur installierten
  Play-Version direkt auf dem Pixel 7 Pro installiert; Kaltstart und
  Staging-Feed bestanden
- Push und Crashdiagnose waren nach Neuinstallation getrennt sichtbar und
  beide standardmäßig aus; Push wurde mit eigenem Einwilligungsdialog
  aktiviert, Crash blieb dabei aus, anschließend wurde Push wieder
  ausgeschaltet
- Endzustand auf dem Testgerät: Push aus, Crashdiagnose aus; die Android-
  Benachrichtigungsberechtigung wurde beim Push-Grenztest erteilt
- der kontrollierte bereinigte Crashlauf `b11-android-2026081510` wurde noch
  nicht übertragen, weil dafür eine separate ausdrückliche Freigabe für die
  technische Firebase-Datenübertragung erforderlich ist
- GO/NO-GO bleibt `HOLD`. Nachweis:
  `docs/evidence/b11/android-candidate-2026081510-build-and-device-services-20260817.json`

## Prüfstand Checkpoint 16.137

- die Großtextkorrektur wurde auf dem physischen Pixel 7 Pro mit dem exakten
  Kandidaten `2026081510` und Android-Schriftgröße 200 % geprüft
- Wunschlisten wechseln sichtbar in das einspaltige Layout; „Demnächst
  benötigt“, Leerzustand und Navigation sind vollständig lesbar
- das Profil stapelt Identität und Kennzahlen; Bewertung, Buchungen,
  „Dabei seit“ und Anzeigenzahl sind ohne Ellipse oder Abschneiden sichtbar
- private lokale Screenshots wurden nur gehasht und nicht ins Repository
  übernommen
- Schriftgröße `0.85`, deaktivierte Bedienungshilfe und automatische Drehung
  wurden danach verifiziert wiederhergestellt
- TalkBack bleibt als eigenständiger manueller Bedienungshilfe-Test offen und
  wird durch diesen Großtext-Pass nicht vorweggenommen. Nachweis:
  `docs/evidence/b11/android-large-text-physical-2026081510-20260817T070236Z.json`
