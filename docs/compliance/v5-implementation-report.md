# ShareItToo V5.1 - Umsetzungsbericht

Stand: 17.08.2026, lokaler Checkpoint 16.157

## Verbindliche Grenzen

- Der unveränderte, offiziell über Google Play Internal ausgelieferte Kandidat
  ist `1.0.0+2026081509`.
- Der neuere Kandidat `1.0.0+2026081510` wurde lokal kanonisch signiert,
  geprüft und privat archiviert. Er wurde nicht hochgeladen und ist deshalb
  weder Play-Kandidat noch Store-, Closed-Test- oder Produktionsnachweis.
- Spätere Quelländerungen sind ohne neue eindeutige Buildidentität kein
  Kandidaten- oder Store-Nachweis.
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
Startbetrieb deaktiviert seien. Ein klar abgegrenzter Nachtrag bindet jetzt die
spätere Produktentscheidung vom 17.08.2026: FCM und Crashlytics bleiben
unabhängig, freiwillig und standardmäßig aus; Push aktiviert Crash nicht. Der
Quelltext bleibt unverändert sichtbar und der Nachtrag ersetzt ausschließlich
diese zwei alten Startaussagen. Das ist keine Aktivierungsfreigabe. Anbieter-,
Vertrags-, Regions-, Transfer-, Einwilligungs-, Aufbewahrungs-, Lösch- und
Store-Nachweise bleiben getrennt je Dienst zu schließen.

## Offene Tatsachen und Gates

- vollständige Betreiber-/Register-/Steuerangaben
- finale öffentliche Widerrufs-URL
- Hosting-, SMTP- und Kartenanbieter samt Regionen
- lizenzierter Marketplace-PSP samt Vertrag, Region und Geldfluss
- Firebase Push-/Crash-Vertrags-, Regions-, Transfer- und Betreiberfreigaben
- neun Aufbewahrungs-/Löschentscheidungen
- vier reale physische Gerätematrix-Fälle
- Play-ausgelieferter Nachfolgekandidat und vollständige Store-Kandidatenbindung
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

## Prüfstand Checkpoint 16.138

- Google TalkBack wurde auf dem physischen Pixel kurz gebunden; Android
  bestätigte gesprochenes Feedback und das fokussierte ShareItToo-Fenster
- Erkunden, Kategorien, Inserate und alle fünf Hauptnavigationseinträge waren
  mit aussagekräftigen Semantikbeschriftungen im Kandidaten sichtbar
- eine simulierte horizontale Geste öffnete jedoch das Android-Systemmenü und
  bewies keine verlässliche TalkBack-Fokusnavigation; deshalb bleiben
  sequentielle gesprochene Navigation und Doppeltipp-Aktivierung offen
- das Systemmenü wurde sofort geschlossen; TalkBack, Accessibility und
  Touch-Erkundung wurden vollständig deaktiviert. Schriftgröße `0.85`,
  automatische Drehung und null gebundene Accessibility-Dienste wurden
  verifiziert
- der Versuch wird ausdrücklich nicht als TalkBack-Pass gewertet. Nachweis:
  `docs/evidence/b11/android-talkback-bounded-probe-2026081510-20260817T071110Z.json`

## Prüfstand Checkpoint 16.139

- auf dem physischen Pixel und Kandidaten `2026081510` waren Google, Apple
  und Facebook als Anmeldeoptionen sichtbar
- Google öffnete die echte Android-Google-Kontoauswahl; es wurde bewusst kein
  privates Konto ausgewählt, keine Anmeldung abgeschlossen und keine
  Kontokennung erfasst
- Apple und Facebook blieben wie vorgesehen geschlossen und zeigten jeweils
  den klaren SIT-Hinweis, vorübergehend E-Mail zu verwenden
- das synthetische Staging-Testkonto wurde anschließend ohne Ausgabe von
  Zugangsdaten wiederhergestellt
- private lokale Screenshots wurden ausschließlich gehasht und nicht ins
  Repository übernommen
- Push und Crashdiagnose bleiben verbindlich erhalten, getrennt, freiwillig
  und standardmäßig aus; dieser Test änderte keinen der beiden Dienste und
  übertrug keine Crashdaten
- die vollständige Google-Anmeldung bleibt offen, bis eine ausdrücklich dafür
  freigegebene private oder dedizierte Testidentität ausgewählt werden darf.
  Nachweis:
  `docs/evidence/b11/android-social-auth-google-only-2026081510-20260817T072343Z.json`

## Prüfstand Checkpoint 16.140

- der Umsetzungsbericht trennt jetzt ausdrücklich den unveränderten
  Google-Play-Internal-Kandidaten `2026081509` vom lokal signierten,
  geprüften und privat archivierten Kandidaten `2026081510`
- `2026081510` bleibt `built-local-not-uploaded`; daraus wird weder ein
  Play-, Closed-Test-, Store- noch Produktionsnachweis abgeleitet
- das noch offene Kandidatengate verlangt deshalb nicht erneut irgendeinen
  signierten Build, sondern einen tatsächlich über Play ausgelieferten
  Nachfolgekandidaten mit vollständiger Store-Bindung
- Push und Crashdiagnose bleiben in beiden Kandidatengrenzen erhalten,
  getrennt, freiwillig und standardmäßig aus; Push aktiviert Crash nicht
- es erfolgte kein neuer Build, kein Upload und keine externe Änderung.
  Gebundene Nachweise:
  `docs/evidence/b11/android-candidate-2026081510-build-and-device-services-20260817.json`
  und `store/google-only-next-candidate.json`

## Prüfstand Checkpoint 16.141

- die Löschmatrix bildet die Produktentscheidung jetzt korrekt ab: FCM-Push
  und Firebase Crashlytics bleiben verbindlich Bestandteil von SIT
- beide Dienste bleiben getrennt, freiwillig und standardmäßig aus; Push darf
  Crashdiagnose niemals automatisch aktivieren
- die Aufnahmeentscheidung wird nicht fälschlich als Datenschutz- oder
  Löschfreigabe gewertet: Transfergrundlage, Region, Vertrag, Storeangaben,
  Anbieterfristen sowie lokaler Opt-out- und Löschablauf bleiben je Dienst offen
- Firebase Authentication und Google Maps bleiben zusätzlich als eigene
  Anbieterentscheidungen abzugrenzen
- alle neun Aufbewahrungs-/Löschentscheidungen bleiben deshalb formal offen;
  keine Löschroutine, Produktion, Store-Angabe oder externe Übertragung wurde
  durch diesen Dokumentationsschritt aktiviert.

## Prüfstand Checkpoint 16.142

- im echten Backendpfad zeigt die Auswahl des Mietzeitraums keinen lokal
  berechneten Gesamtpreis mehr als verbindlichen Betrag an
- der verbindliche Gesamtpreis wird erst nach „Weiter“ im Checkout über ein
  frisches, zeitlich begrenztes Serverangebot geladen; ändert sich dieses
  Angebot, muss der Nutzer es erneut ausdrücklich bestätigen
- nur der ausdrücklich gebundene lokale QA-Modus darf weiterhin eine lokale
  Vorschau anzeigen; sie ist sichtbar als unverbindliche QA-Vorschau markiert
- der Checkout bleibt geschlossen, wenn das Angebot abgelaufen ist, keine
  Zahlungsart gewählt wurde oder eine der beiden Erklärungen fehlt
- Lieferung, Rückgabeabholung und Express bleiben im gebundenen Serverangebot
  ausgeschaltet; sie werden nicht stillschweigend in den Preis aufgenommen
- 4/4 neue Preis-Wiring-Tests, 61 gezielte Flutter-Tests und die vollständige
  Regression mit 268 bestandenen Tests, 1 bewusstem Skip, 229 Analyzer-
  Hinweisen bei 0 Fehlern sowie grünen Web- und Android-Debug-Builds bestanden
- der Quellstand wurde nicht als Kandidat neu gebaut, umbenannt oder
  hochgeladen. Google Play Internal bleibt unverändert bei `2026081509`; der
  lokale signierte Kandidat `2026081510` bleibt `built-local-not-uploaded`
- Push und Crashdiagnose bleiben erhalten, getrennt, freiwillig und
  standardmäßig aus; dieser Meilenstein änderte keinen Dienst und übertrug
  keine Crashdaten. Nachweis:
  `docs/evidence/b11/v51-selected-range-server-price-truth-20260817T074500Z.json`

## Prüfstand Checkpoint 16.143

- das vollständige, unveränderliche Serverpreis-Abbild wird jetzt vom
  Backendangebot über die Buchungsanfrage bis in alle Buchungsdetailwege
  erhalten: Tage, Tagespreis, Grundmiete, Rabatt, private Mietsumme,
  Plattformbeitrag, Gesamtbetrag, Vermieterauszahlung und Währung
- Buchungsliste, Benachrichtigungen, Chat und App-Links reichen dieselben
  gebundenen Werte weiter; kein Detailweg darf den Plattformbeitrag aus dem
  bereits inklusive Beitrag gespeicherten Gesamtbetrag schätzen
- ein Preis-Abbild gilt nur, wenn es aus ganzzahligen Cent-Beträgen besteht,
  `Mietsumme + Plattformbeitrag = Gesamtbetrag` erfüllt und die optionale
  Vermieterauszahlung exakt der privaten Mietsumme entspricht
- bei einem gültigen Serverpreis werden alte Liefer-, Rückhol- oder
  Prioritätsbeträge nicht zusätzlich in die Launch-Preisanzeige gerechnet
- unvollständige ältere Buchungen und ausdrücklich lokale QA-Buchungen behalten
  ihre bisherige Darstellung; sie werden nicht fälschlich zu einem
  verbindlichen V5.1-Serverpreis hochgestuft
- 5/5 neue Snapshot-Wiring-Tests, zusammen 9/9 Preis-Wiring-Tests, 58 gezielte
  Flutter-Tests, 39 Datenschutz-/Löschtests und die vollständige Regression
  mit 269 bestandenen Tests, 1 bewusstem Skip, 229 Analyzer-Hinweisen bei
  0 Fehlern sowie grünen Web- und Android-Debug-Builds bestanden
- der Quellstand wurde nicht deployt, hochgeladen, als Kandidat neu gebaut oder
  umbenannt. Google Play Internal bleibt unverändert bei `2026081509`; der
  lokale signierte Kandidat `2026081510` bleibt `built-local-not-uploaded`
- Push und Crashdiagnose bleiben bestehen, getrennt, freiwillig und
  standardmäßig aus; Push aktiviert Crash nicht. Dieser Meilenstein änderte
  keinen der beiden Dienste und übertrug keine Crashdaten. Nachweis:
  `docs/evidence/b11/v51-booking-detail-server-price-snapshot-20260817T081200Z.json`

## Prüfstand Checkpoint 16.144

- der Checkout übernimmt einen Serverpreis erst dann als verbindliche Anzeige,
  wenn alle Geldwerte ganzzahlige Centbeträge sind und der Preis vollständig
  in sich stimmt
- der Parser verlangt für den Privatlaunch EUR, 1 bis 365 Miettage,
  `Tagespreis × Tage = Grundmiete`, `Grundmiete − Rabatt = Mietsumme`, den
  exakt einmal centgenau berechneten 10-%-Plattformbeitrag und
  `Mietsumme + Plattformbeitrag = Gesamtbetrag`
- formal gültig aussehende, aber rechnerisch widersprüchliche Antworten sowie
  Nicht-EUR-Preise werden geschlossen verworfen und gelangen nicht in den
  bestätigbaren Checkout-Zustand
- 13/13 Preis-Wiring-Tests, 10 gezielte Flutter-Tests und ein gezielter
  Analyzerlauf mit 0 Hinweisen bestanden; die vollständige Regression blieb
  mit 270 bestandenen Tests, 1 bewusstem Skip, 229 Analyzer-Hinweisen bei
  0 Fehlern sowie grünen Web- und Android-Debug-Builds vollständig grün
- es erfolgte kein Deployment, Upload, Echtgeld-, Store- oder Kandidatenwechsel
- Push und Crashdiagnose bleiben bestehen, getrennt, freiwillig und
  standardmäßig aus; Push aktiviert Crash nicht. Es wurden keine Crashdaten
  übertragen. Nachweis:
  `docs/evidence/b11/v51-checkout-server-quote-validation-20260817T082300Z.json`

## Prüfstand Checkpoint 16.145

- das vollständige Preis-Abbild bleibt jetzt auch beim isolierten lokalen
  QA-Speicherweg erhalten: Tage, Tagespreis, Grundmiete, Rabatt, Mietsumme,
  Plattformbeitrag, Gesamtbetrag, Vermieterauszahlung und Währung
- der echte Backendpfad bleibt davon getrennt und ersetzt die lokale Eingabe
  weiterhin durch die authentifizierte Serverbuchung; QA wird nicht zu einem
  Produktions-, Echtgeld- oder Servernachweis hochgestuft
- 3/3 neue Persistenz-Wiring-Tests, 51 gezielte Buchungs-/Checkout-Tests und
  19 Datenschutzprüfungen bestanden; der gezielte Analyzer erzeugte keine
  neuen Hinweise
- die vollständige Regression blieb mit 270 bestandenen Tests, 1 bewusstem
  Skip, 229 Analyzer-Hinweisen bei 0 Fehlern sowie grünen Web- und
  Android-Debug-Builds vollständig grün
- die Datenschutz-Inventarbindung wurde auf den neuen Quellhash aktualisiert;
  Erhebungszweck, Transport, Anbieter und Berechtigungen änderten sich nicht
- es erfolgte kein Deployment, Upload, Echtgeld-, Store- oder Kandidatenwechsel
- Push und Crashdiagnose bleiben bestehen, getrennt, freiwillig und
  standardmäßig aus; Push aktiviert Crash nicht. Es wurden keine Crashdaten
  übertragen. Nachweis:
  `docs/evidence/b11/v51-local-quote-snapshot-persistence-20260817T083200Z.json`

## Prüfstand Checkpoint 16.146

- die Vermieterannahme rekonstruiert und prüft jetzt erneut exakt dasselbe
  vollständige Preis-Abbild, das beim Mieter gebunden und in der Buchung
  gespeichert wurde; auch die Vermieterauszahlung muss der privaten Mietsumme
  entsprechen
- fehlt der Preis oder widersprechen sich Centwerte, Währung, Tage,
  Plattformbeitrag, Gesamtbetrag oder Auszahlung, zeigt SIT ausdrücklich
  „Preisprüfung fehlgeschlagen“ und deaktiviert sowohl Erklärung als auch
  verbindliche Annahme
- diese gemeinsame letzte Schranke gilt für alle vier Annahmewege:
  Anfragedetail, Vermieter-Anfragenliste, Nachrichten und laufende
  Vermieteransicht
- der Vermieter sieht vor der Erklärung getrennt den privaten Mietpreis, den
  vom Mieter getragenen SIT-Plattformbeitrag, den Gesamtpreis des Mieters und
  die vorgesehene eigene Auszahlung
- nur außerhalb des echten Backendpfads bleibt ein lokaler Testpreis möglich;
  er ist sichtbar mit „kein Echtgeld“ als nicht bindend gekennzeichnet
- 11/11 neue bzw. angepasste Wiring-Tests und 9 gezielte Flutter-Tests
  bestanden; der gezielte Analyzer erzeugte keine neuen Hinweise
- die vollständige Regression blieb mit 271 bestandenen Tests, 1 bewusstem
  Skip, 229 Analyzer-Hinweisen bei 0 Fehlern sowie grünen Web- und
  Android-Debug-Builds vollständig grün
- es erfolgte kein Deployment, Upload, Echtgeld-, Store- oder Kandidatenwechsel
- Push und Crashdiagnose bleiben bestehen, getrennt, freiwillig und
  standardmäßig aus; Push aktiviert Crash nicht. Es wurden keine Crashdaten
  übertragen. Nachweis:
  `docs/evidence/b11/v51-owner-acceptance-server-price-gate-20260817T084500Z.json`

## Prüfstand Checkpoint 16.147

- die vom Server gesetzte verbindliche Annahmefrist bleibt jetzt im
  Buchungsmodell, im Checkout und im isolierten lokalen QA-Speicherweg
  vollständig erhalten; der echte Backendpfad bleibt weiterhin die
  maßgebliche Quelle
- die Anfragedetailansicht zeigt dem Vermieter die genaue Annahmefrist und
  deaktiviert die Annahme, sobald die 30-Minuten-Frist abgelaufen ist
- dieselbe Fristschranke gilt über den gemeinsamen Annahmedialog für alle vier
  Annahmewege; nach Ablauf sind sowohl die Erklärung als auch die verbindliche
  Annahme deaktiviert
- unmittelbar beim Tippen auf „Verbindlich annehmen“ wird die Frist nochmals
  geprüft, damit ein während des geöffneten Dialogs eintretender Ablauf nicht
  umgangen werden kann
- das Backend bleibt die letzte maßgebliche Schranke und weist einen
  Annahmeversuch nach der gespeicherten Frist mit
  `booking_request_expired` zurück
- 32/32 gezielte Struktur-, Backend- und Datenschutztests sowie 12/12
  gezielte Flutter-Tests bestanden; die gezielte Analyse erzeugte keine Fehler
- die vollständige Regression blieb mit 282 bestandenen Tests, 1 bewusstem
  Skip, 229 Analyzer-Hinweisen bei 0 Fehlern sowie grünen Web- und
  Android-Debug-Builds vollständig grün
- die Datenschutz-Inventarbindung wurde auf den neuen Quellhash aktualisiert;
  Erhebungszweck, Transport, Anbieter und Berechtigungen änderten sich nicht
- es erfolgte kein Deployment, Upload, Echtgeld-, Store- oder Kandidatenwechsel
- Push und Crashdiagnose bleiben bestehen, getrennt, freiwillig und
  standardmäßig aus; Push aktiviert Crash nicht. Es wurden keine Crashdaten
  übertragen. Nachweis:
  `docs/evidence/b11/v51-owner-acceptance-deadline-gate-20260817T085811Z.json`

## Prüfstand Checkpoint 16.148

- weist das Backend einen Annahmeversuch exakt mit
  `booking_request_expired` zurück, zeigt SIT jetzt zentral das mittige Popup
  „Annahmefrist abgelaufen“ statt eines technischen oder kaum sichtbaren
  Fehlers
- die Meldung erklärt, dass die 30-Minuten-Frist abgelaufen ist, dass die
  Anfrage nicht mehr angenommen werden kann und dass die Ansicht neu geladen
  werden soll
- andere Backendfehler werden nicht fälschlich als Fristablauf ausgegeben,
  sondern weiterhin an die bestehende Fehlerbehandlung weitergereicht
- alle vier Vermieter-Annahmewege verwenden dieselbe zentrale Abschluss- und
  Fehlerfunktion; nach einer abgelaufenen Annahme entstehen weder
  Erfolgsmeldung noch Chatstatus-, Timeline- oder Navigations-Folgeschritte
- 8/8 Annahme-Wiring-Tests und 57/57 gezielte Flutter-Tests bestanden
- die vollständige Regression blieb mit 282 bestandenen Tests, 1 bewusstem
  Skip, 229 Analyzer-Hinweisen bei 0 Fehlern sowie grünen Web- und
  Android-Debug-Builds vollständig grün
- die Datenschutz-Inventarbindung der zwei bereits inventarisierten Ansichten
  wurde aktualisiert; Datenerhebung, Speicherung, Transport, Anbieter und
  Berechtigungen änderten sich nicht
- es erfolgte kein Deployment, Upload, Echtgeld-, Store- oder Kandidatenwechsel
- Push und Crashdiagnose bleiben bestehen, getrennt, freiwillig und
  standardmäßig aus; Push aktiviert Crash nicht. Es wurden keine Crashdaten
  übertragen. Nachweis:
  `docs/evidence/b11/v51-owner-acceptance-expired-popup-20260817T091611Z.json`

## Prüfstand Checkpoint 16.149

- der Checkout unterscheidet jetzt bekannte serverseitige Buchungsschranken
  und zeigt verständliche SIT-Texte statt interner Fehlercodes oder der
  pauschalen Aufforderung, nur die Verbindung zu prüfen
- abgelaufene, fehlende oder geänderte verbindliche Preise werden aus dem
  bestätigbaren Zustand entfernt; SIT lädt danach automatisch einen frischen
  Serverpreis, den der Nutzer erneut prüfen und bestätigen muss
- nicht mehr verfügbare Zeiträume, vorhandene Doppelanfragen, eigene Anzeigen,
  fehlende Anmeldung, bereits laufende Serververarbeitung und vorübergehend
  gesperrte Buchungen erhalten jeweils eine begrenzte, ehrliche Meldung
- Moderations- oder Blockgründe werden bewusst neutral formuliert und legen
  keine privaten Gegenpartei-Informationen offen
- unbekannte Fehler bleiben fail-closed bei der generischen Meldung; es wird
  kein Erfolg, keine Belastung und keine erzeugte Buchung behauptet
- 4/4 neue Checkout-Fehler-Wiring-Tests, insgesamt 17/17 gezielte Node-Tests,
  11/11 gezielte Flutter-Tests und 16/16 Datenschutztests bestanden; die
  geänderte Checkout-Datei hat 0 Analyzer-Hinweise
- die vollständige Regression blieb mit 282 bestandenen Tests, 1 bewusstem
  Skip, 229 Analyzer-Hinweisen bei 0 Fehlern sowie grünen Web- und
  Android-Debug-Builds vollständig grün
- es erfolgte kein Deployment, Upload, Echtgeld-, Store- oder Kandidatenwechsel
- Push und Crashdiagnose bleiben bestehen, getrennt, freiwillig und
  standardmäßig aus; Push aktiviert Crash nicht. Es wurden keine Crashdaten
  übertragen. Nachweis:
  `docs/evidence/b11/v51-checkout-backend-error-mapping-20260817T092630Z.json`

## Prüfstand Checkpoint 16.150

- jede neue Serverpreisabfrage setzt jetzt sowohl die Bestätigung der privaten
  Bedingungen als auch die Erklärung zur vorzeitigen Leistung und
  Widerrufsfolge auf nicht bestätigt zurück
- dasselbe gilt sofort beim automatischen Ablauf des zehn Minuten gültigen
  Preisangebots; alte Häkchen bleiben nicht sichtbar oder technisch wirksam
- nach einem abgelaufenen oder geänderten Preis kann der automatisch neu
  geladene Preis deshalb erst gesendet werden, wenn der Nutzer beide
  Erklärungen für den frischen Preis erneut bewusst setzt
- der Absende-Guard verlangt weiterhin gleichzeitig beide Erklärungen, einen
  frischen Serverpreis, die Zahlungsbereitschaft und einen nicht laufenden
  Sendevorgang
- 5/5 Checkout-Fehler-/Neubestätigungs-Wiring-Tests, 9/9 gezielte Node-Tests
  und 8/8 gezielte Flutter-Tests bestanden; die Checkout-Datei hat weiterhin
  0 Analyzer-Hinweise
- die vollständige Regression blieb mit 282 bestandenen Tests, 1 bewusstem
  Skip, 229 Analyzer-Hinweisen bei 0 Fehlern sowie grünen Web- und
  Android-Debug-Builds vollständig grün
- es erfolgte kein Deployment, Upload, Echtgeld-, Store- oder Kandidatenwechsel
- Push und Crashdiagnose bleiben bestehen, getrennt, freiwillig und
  standardmäßig aus; Push aktiviert Crash nicht. Es wurden keine Crashdaten
  übertragen. Nachweis:
  `docs/evidence/b11/v51-checkout-reconfirmation-after-requote-20260817T093351Z.json`

## Prüfstand Checkpoint 16.151

- eine offen gelassene Vermieter-Anfragedetailansicht beobachtet jetzt auch
  die normale serverseitige 30-Minuten-Annahmefrist und baut sich beim Ablauf
  ohne manuelles Neuladen neu auf
- unmittelbar nach dem Ablauf wechselt der sichtbare Hinweis auf
  „Annahmefrist abgelaufen“ und der Annahmebutton wird deaktiviert; ein zuvor
  gerenderter aktiver Button bleibt nicht bis zur nächsten Navigation stehen
- der Zeitgeber läuft nur für eine tatsächlich ausstehende Remote-Anfrage mit
  zukünftiger gebundener Frist oder für den bereits vorhandenen
  Express-Bestätigungsfall und beendet sich nach Wegfall beider Gründe
- lokale QA-Daten erhalten keinen fälschlich servergebundenen Zeitgeber; die
  Backendprüfung `booking_request_expired` und der zentrale SIT-Fehlerdialog
  bleiben unverändert die letzte maßgebliche Schranke
- 14/14 gezielte Strukturtests und 52/52 gezielte Flutter-Buchungs- und
  Sicherheitstests bestanden
- die vollständige Regression blieb mit 282 bestandenen Tests, 1 bewusstem
  Skip, 229 Analyzer-Hinweisen bei 0 Fehlern sowie grünen Web- und
  Android-Debug-Builds vollständig grün; das technische Gesamttor bestand mit
  der dokumentierten lokalen Kandidaten-Rollover-Grenze
- es erfolgte kein Deployment, Upload, Echtgeld-, Store- oder Kandidatenwechsel
- Push und Crashdiagnose bleiben bestehen, getrennt, freiwillig und
  standardmäßig aus; Push aktiviert Crash nicht. Es wurden keine Crashdaten
  übertragen. Nachweis:
  `docs/evidence/b11/v51-owner-acceptance-live-deadline-20260817T095017Z.json`

## Prüfstand Checkpoint 16.152

- ein bereits geöffnetes zentrales Vermieter-Annahmefenster beobachtet die
  gebundene 30-Minuten-Frist jetzt selbst und wechselt beim exakten Ablauf
  ohne erneutes Tippen oder Schließen in den abgelaufenen Zustand
- eine zuvor gesetzte Annahmeerklärung wird beim Ablauf sofort zurückgesetzt;
  Checkbox und verbindlicher Annahmebutton werden gleichzeitig technisch
  deaktiviert und der sichtbare Ablaufhinweis erscheint im selben Dialog
- der Dialog verwendet genau einen Fristzeitgeber und beendet ihn beim
  Schließen zuverlässig; ein späterer Callback kann keine bereits entfernte
  Ansicht mehr verändern
- die zusätzliche Prüfung beim Antippen, der gemeinsame Serverabschluss und
  die serverseitige Schranke `booking_request_expired` bleiben unverändert;
  alle vier Annahmewege profitieren vom gemeinsamen Dialog
- 10/10 Annahme-Wiring-Tests und 52/52 gezielte Flutter-Buchungs- und
  Sicherheitstests bestanden; die gezielte Dialoganalyse hatte 0 Hinweise
- die vollständige Regression blieb mit 282 bestandenen Tests, 1 bewusstem
  Skip, 229 Analyzer-Hinweisen bei 0 Fehlern sowie grünen Web- und
  Android-Debug-Builds vollständig grün; das technische Gesamttor bestand mit
  der dokumentierten lokalen Kandidaten-Rollover-Grenze
- es erfolgte kein Deployment, Upload, Echtgeld-, Store- oder Kandidatenwechsel
- Push und Crashdiagnose bleiben bestehen, getrennt, freiwillig und
  standardmäßig aus; Push aktiviert Crash nicht. Es wurden keine Crashdaten
  übertragen. Nachweis:
  `docs/evidence/b11/v51-owner-acceptance-dialog-live-expiry-20260817T100225Z.json`

## Prüfstand Checkpoint 16.153

- die Vermieterübersicht wertet eine ausstehende Remote-Anfrage nicht mehr
  pauschal als aktive „Anfrage“, wenn ihre servergebundene Annahmefrist fehlt
  oder bereits abgelaufen ist
- fehlt die Pflichtfrist, zeigt die Karte „Annahme gesperrt“; nach Ablauf
  wechselt sie sichtbar auf „Annahmefrist abgelaufen“ und verwendet die rote
  Warnfarbe statt eines neutralen aktiven Status
- die Übersicht plant genau den jeweils nächsten zukünftigen Ablaufzeitpunkt,
  baut sich dort neu auf und plant danach gegebenenfalls die nächste Frist;
  ihr Zeitgeber wird bei neu geladenen Daten ersetzt und beim Verlassen beendet
- der isolierte QA-Modus bleibt von einer behaupteten Serverfrist getrennt;
  Dialogprüfung, Antippprüfung und Backendschranke bleiben die verbindlichen
  technischen Annahme-Gates
- 11/11 Annahme-Wiring-Tests und 53/53 gezielte Flutter-Buchungs-,
  Hydrations- und Sicherheitstests bestanden; die gezielte Übersichtsanalyse
  blieb bei den zwei bereits vorhandenen Hinweisen und ohne neue Diagnose
- die vollständige Regression blieb mit 282 bestandenen Tests, 1 bewusstem
  Skip, 229 Analyzer-Hinweisen bei 0 Fehlern sowie grünen Web- und
  Android-Debug-Builds vollständig grün; das technische Gesamttor bestand mit
  der dokumentierten lokalen Kandidaten-Rollover-Grenze
- es erfolgte kein Deployment, Upload, Echtgeld-, Store- oder Kandidatenwechsel
- Push und Crashdiagnose bleiben bestehen, getrennt, freiwillig und
  standardmäßig aus; Push aktiviert Crash nicht. Es wurden keine Crashdaten
  übertragen. Nachweis:
  `docs/evidence/b11/v51-owner-request-overview-live-expiry-20260817T101258Z.json`

## Prüfstand Checkpoint 16.154

- auch die geöffnete Vermieter-Detailansicht beobachtet ihre servergebundene
  Annahmefrist jetzt selbst und baut sich am exakten Ablaufzeitpunkt neu auf
- ihr bisher optisch aktiver grüner Annahmebutton wird dann technisch
  deaktiviert; Statusmarke und Erklärung zeigen sichtbar
  „Annahmefrist abgelaufen“ statt eine weiterhin aktive Anfrage zu behaupten
- fehlt im echten Backend die Pflichtfrist, zeigt die Ansicht
  „Annahme gesperrt“ und erklärt, dass die verbindliche Annahmefrist fehlt;
  der isolierte QA-Modus bleibt davon getrennt
- der Ansichtszeitgeber wird bei jedem Neuladen ersetzt und beim Verlassen
  beendet; gemeinsamer Dialog, Antippprüfung und Backendschranke bleiben als
  zusätzliche unabhängige Schutzschichten bestehen
- 12/12 Annahme-Wiring-Tests und 53/53 gezielte Flutter-Buchungs-,
  Hydrations- und Sicherheitstests bestanden; die gezielte Dateianalyse blieb
  bei 26 bereits vorhandenen Hinweisen und ohne neue Diagnose
- die vollständige Regression blieb mit 282 bestandenen Tests, 1 bewusstem
  Skip, 229 Analyzer-Hinweisen bei 0 Fehlern sowie grünen Web- und
  Android-Debug-Builds vollständig grün; das technische Gesamttor bestand mit
  der dokumentierten lokalen Kandidaten-Rollover-Grenze
- der Quellhash der bereits inventarisierten Detailansicht wurde aktualisiert;
  Datenerhebung, Speicherung, Transport, Anbieter und Berechtigungen änderten
  sich nicht
- es erfolgte kein Deployment, Upload, Echtgeld-, Store- oder Kandidatenwechsel
- Push und Crashdiagnose bleiben bestehen, getrennt, freiwillig und
  standardmäßig aus; Push aktiviert Crash nicht. Es wurden keine Crashdaten
  übertragen. Nachweis:
  `docs/evidence/b11/v51-owner-detail-live-expiry-20260817T102341Z.json`

## Prüfstand Checkpoint 16.155

- Firebase Cloud Messaging und Firebase Crashlytics bleiben verbindlich
  Bestandteil des vorgesehenen SIT-Launchumfangs
- ein datierter Nachtrag in der internen V5.1-Datenschutzfassung ersetzt jetzt
  ausschließlich die zwei alten Aussagen auf Quellseite 38, wonach externe
  Push- und Crashdienste beim Start generell nicht aktiviert seien; der
  ursprüngliche Quelltext bleibt für die Nachvollziehbarkeit sichtbar
- der Nachtrag bindet beide Dienste als unabhängige, freiwillige und
  standardmäßig ausgeschaltete Entscheidungen; Push kann Crashdiagnose nicht
  aktivieren
- Werbung, Marketingtracking, allgemeine Analytics und externe generative KI
  bleiben weiterhin aus
- die Produktentscheidung ist ausdrücklich keine Live-, Datenschutz- oder
  Store-Freigabe. Anbieterrolle, Vertrag, Regionen, Drittlandtransfer,
  Datenfelder, Einwilligung/Widerruf, Aufbewahrung/Löschung und Store-Angaben
  bleiben je Dienst offen und aktivierungsblockierend
- Manifest, V5.1-Rechtsvalidator und allgemeiner Datenschutzvalidator lehnen
  sowohl Entfernen/Koppeln der Dienste als auch eine vorzeitige Freigabe
  geschlossen ab
- 50/50 gezielte Node-Prüfungen und 18/18 gezielte Flutter-Prüfungen
  bestanden; die vollständige Regression blieb mit 282 bestandenen Tests,
  1 bewusstem Skip, 229 Analyzer-Hinweisen bei 0 Fehlern sowie grünen Web-
  und Android-Debug-Builds vollständig grün
- die zwei geänderten Rechtsassets wurden mit ihren neuen Hashes im
  Datenschutz-Inventar neu gebunden; Datenerhebung, Speicherung, Transport,
  Anbieter und Berechtigungen änderten sich nicht
- es erfolgte kein Deployment, Upload, Echtgeld-, Store- oder Kandidatenwechsel
  und es wurden keine Crashdaten erzeugt oder übertragen. Nachweis:
  `docs/evidence/b11/v51-push-crash-successor-decision-20260817T103613Z.json`

## Prüfstand Checkpoint 16.156

- FCM-Push und Firebase Crashlytics besitzen jetzt zwei getrennte,
  maschinenlesbare Anbieter-/Aufbewahrungs-/Löschbereitschaftsbelege; kein
  Dienst kann durch den Nachweis des anderen freigegeben werden
- für FCM sind die bestehende Sitzungsregistrierungs-, Token- und
  Firebase-Installationslöschung samt gespeichertem Wiederholungsversuch an
  ihre echten Quellhashes gebunden; Googles Abschlussfenster von bis zu 180
  Tagen nach dem installationsgebundenen Löschantrag wird als
  anbietergesteuert und nicht als SIT-Sofortlöschung ausgewiesen
- für Crashlytics sind standardmäßig ausgeschaltete Erfassung, getrennte
  Aktivierung und Löschung noch nicht gesendeter Geräteberichte belegt
- bereits bei Google gespeicherte Crashberichte werden ausdrücklich nicht als
  vollständig löschbar behauptet: Die aktuelle Firebase-Schnittstelle setzt
  eine stabile Benutzerzuordnung und einen autorisierten serverseitigen
  Löschaufruf voraus; beides ist in SIT noch nicht implementiert oder
  betrieblich bestätigt
- Vertrag, Verarbeitungsorte, Drittlandtransfer, Betreiberakzeptanz,
  Storeangaben und ein neuer physisch geprüfter Nachfolgekandidat bleiben für
  beide Dienste getrennt `open`; die neun Retention-Entscheidungen bleiben
  ebenfalls offen
- 52/52 gezielte Node-Prüfungen bestanden; die vollständige Regression blieb
  mit 282 bestandenen Flutter-Tests, 1 bewusstem Skip, 229
  Analyzer-Hinweisen bei 0 Fehlern sowie grünen Web- und
  Android-Debug-Builds vollständig grün
- es erfolgte kein Deployment, Upload, Echtgeld-, Store-, Anbieterconsole-
  oder Kandidatenwechsel und es wurden keine Crashdaten erzeugt oder
  übertragen. Nachweis:
  `docs/evidence/b11/v51-firebase-service-specific-retention-readiness-20260817T105628Z.json`

## Prüfstand Checkpoint 16.157

- eine zentrale Retention-Ausführungsvorprüfung bewertet jetzt die neun
  Entscheidungen, technische Cutoff-/Eligible-Row-Reife, alle vier externen
  Anbieter, Rechts-/Betreiberfreigabe sowie Datenschutz- und Store-Gates
  gemeinsam
- der aktuelle Stand bleibt mit genau 20 stabilen, rein symbolischen
  Blockercodes geschlossen; Richtlinienwerte, E-Mails, Kennungen oder andere
  sensible Inhalte werden nicht in das Ergebnis übernommen
- auch vollständig unterschriebene Richtlinien können allein keine Löschung
  ermöglichen: kategorieweiser Purge, angewandte Fristen, berechnete
  löschbare Zeilen und ein verifizierter Staging-Trockenlauf müssen zusätzlich
  gemeinsam vorliegen
- die Vorprüfung stellt keinen destruktiven API-Pfad bereit und hat weder
  Datenbankzeilen gelesen oder verändert noch Fristen, Betreiberentscheidungen
  oder Anbieterfreigaben erfunden
- 36/36 gezielte Retention-Prüfungen bestanden; die vollständige Regression
  blieb mit 282 bestandenen Flutter-Tests, 1 bewusstem Skip, 229
  Analyzer-Hinweisen bei 0 Fehlern sowie grünen Web- und
  Android-Debug-Builds vollständig grün
- FCM-Push und Crashlytics bleiben unverändert getrennt, freiwillig und im
  nächsten Kandidaten standardmäßig aus; es erfolgte kein Deployment,
  Upload, Echtgeld-, Store-, Anbieterconsole- oder Kandidatenwechsel und kein
  Crashereignis. Nachweis:
  `docs/evidence/b11/v51-retention-execution-preflight-20260817T130000Z.json`
