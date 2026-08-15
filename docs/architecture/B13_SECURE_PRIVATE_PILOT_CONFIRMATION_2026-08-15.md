# B13 – Sicherer Privat-Pilot-Bestaetigungsfluss

Stand: 2026-08-15  
Kandidat: `1.0.0+2026081411`  
Commit: `7f86ffd1a2c18a41a8b0479c5deba5251fb3a911`  
Backend-Staging: `1.0.0-2026081412-v4` / `0761f938241476d5b6ba7988c873f81a57fb63f0`
Umgebung: internes Android-Staging, kein Echtgeld, Google-Play-Internal-Test

## Ergebnis

Die Vorgaben der „ShareItToo Rechtsmappe Privat-Pilot V4“ sind als
konfigurierbarer Privat-Pilot-Vertrag in App und Backend gebunden. Die
technische Uebergabe- und Rueckgabebestaetigung verwendet in der
Backend-Umgebung keine aus Buchungsdaten ableitbaren Codes mehr, sondern eine
serverseitig erzeugte Einmal-Challenge.

## Sicherheitsvertrag

- sechsstelliger kryptografisch erzeugter Einmal-Code und QR-Payload Version 3;
- im Backend wird nur ein HMAC-Digest gespeichert, niemals der Klartext-Code;
- Bindung an Buchung, Segment, vorzeigende Rolle und vorzeigenden Nutzer;
- Uebergabe: Vermieter zeigt, Mieter bestaetigt;
- Rueckgabe: Mieter zeigt, Vermieter bestaetigt;
- zehn Minuten Gueltigkeit, hoechstens fuenf Fehlversuche;
- neue Challenge widerruft eine vorherige aktive Challenge desselben Schritts;
- erfolgreiche Challenge wird einmalig verbraucht und kann nicht erneut
  verwendet werden;
- Statuswechsel akzeptieren im Privat-Pilot nur serverseitig nachgewiesene
  Bestaetigungen;
- beide Buchungsparteien erhalten nach erfolgreicher Bestaetigung einen
  Echtzeit-Refresh.

Der lokale QA-Modus besitzt weiterhin einen getrennten Test-Fallback. Dieser
ist kein Sicherheitsnachweis und wird im Release durch die Backend-Pflicht
ersetzt.

## Gesetzte offene Punkte

Alle sechs noch offenen V4-Entscheidungen besitzen jetzt eine zentrale,
maschinenlesbare Zwischenregel. Sie sind ausdrücklich nicht als juristisch
final oder fuer Echtgeld freigegeben markiert:

1. Plattformvertrag und Widerrufserklaerungen: getrennte, versionierte
   Erklaerungen; SIT-Annahme vorlaeufig bei Buchungsbestaetigung.
2. Wirkung eines Widerrufs auf den privaten Mietvertrag: Eingang bestaetigen
   und protokollieren; keine automatische Buchungs- oder Geldflussaenderung.
3. Storno: fuer geschlossene Tests 50 Prozent unter 24 Stunden und 100 Prozent
   ab Mietbeginn/Mieter-No-Show.
4. PSP/Geldfluss: nur Test- und Mockzustaende; keine echte Autorisierung,
   Belastung, Auszahlung, Erstattung oder Schadensverrechnung.
5. Fehlende Rueckgabebestaetigung: neutraler Zustand bis T0 plus fuenf
   Kalendertage; keine automatische Eskalation.
6. Fotofluss: vier Basisfotos je Richtung, Gegenbestaetigung oder
   Abweichungsfoto, danach getrennte QR-/Code-Bestaetigung.

Die ersten vier Punkte blockieren weiterhin jede Live-Aktivierung. Aenderungen
werden im zentralen Register, im Backend-Spiegel, in den Rechtstexten und in
den gebundenen Tests gemeinsam versioniert.

Am 15.08.2026 wurde festgelegt, dass alle sechs Zwischenregeln im internen und
geschlossenen Test aktiv verwendet werden, bis der Nutzer eine aktualisierte
Entscheidung mitteilt. Die maschinenlesbare Fassung traegt die Version
`V4-INTERIM-2026-08-15`, gilt ausschliesslich fuer interne und geschlossene
Tests und aktiviert weder Echtgeld noch eine rechtliche Live-Freigabe. Jede
spaetere Mitteilung ersetzt den betroffenen Wert zentral in App, Backend,
Rechtstexten und Regressionstests.

## Verifikation

- Flutter-Gesamtsuite: 262 bestanden, 0 fehlgeschlagen.
- Backend-Gesamtsuite: 120 bestanden, 0 fehlgeschlagen, 1 PostgreSQL-Test lokal
  mangels `TEST_DATABASE_URL` uebersprungen.
- Flutter-Gesamtanalyse: 640 bereits vorhandene Warnungen/Hinweise; der Lauf
  bleibt deshalb als eigener Qualitaetsblock offen. Die in diesem Meilenstein
  geaenderten V4-Dateien wurden separat ohne Befund analysiert.
- Legal-Readiness: gueltiger Draft, Live-Freigabe weiterhin fail-closed.
- Datenschutz- und Aufbewahrungsmanifest: Quellhashes aktuell und Validatoren
  bestanden.
- Signierter Android-Kandidat gebaut; APK/AAB-Signatur und binaerer
  Datenschutzscan bestanden.

Artefakt-Hashes:

- AAB: `1ebc15439ce636390a03928a6565824bcb42fccb33e6ee4d95d04b8832925c62`
- APK: `d1147e4ceec978137c0172483ae188db926d2957dc190fe3cd502036b92d0654`
- Datenschutzbericht:
  `bcd7631589b0c116f445bfbbffb8e687843c01e2569a5fbd144d26acb98af9a9`

## Staging-Abnahme

Vor dem Rollout wurden Datenbank und Uploads getrennt gesichert. Das exakte
Backend-Image wurde zunaechst gegen eine temporaere PostgreSQL-Instanz
gestartet. Alle 13 Migrationen und die 14 Spalten der Challenge-Tabelle waren
dort vorhanden. Anschliessend wurde nur Staging mit automatischem Rollback
aktualisiert; FCM bestand seine separate Secret-Pruefung.

Der erste reale Zwei-Rollen-Test deckte eine falsche Tabellenquelle fuer den
Buchungs-Payload auf. Die Abfrage wurde auf den gesperrten Verbund aus
`bookings` und `rental_requests` korrigiert, erneut vollstaendig getestet und
als Backend-Kandidat `2026081412-v4` ausgerollt.

Die wiederholte Abnahme bewies danach:

- Eigener Code kann nicht selbst bestaetigt werden;
- falscher Code wird abgelehnt und reduziert die verbleibenden Versuche;
- korrekter Uebergabe-Code wird durch die Gegenpartei verbraucht;
- identische Wiederholung ist idempotent und erzeugt kein zweites Ereignis;
- Statuswechsel zu `active` ist erst nach verifizierter Uebergabe moeglich;
- Rueckgabe-Code folgt der umgekehrten Rollenrichtung;
- Abschluss ist erst nach verifizierter Rueckgabe moeglich;
- beide Bestaetigungen stehen als Version 3 im Buchungsnachweis;
- genau zwei unveraenderliche Bestaetigungsereignisse wurden protokolliert;
- Testkonten, Inserat und Buchung sind geschlossen beziehungsweise beendet;
  es blieb kein aktiver Testnutzer, kein aktives Inserat, keine offene
  Testbuchung und keine aktive Challenge zurueck;
- Staging ist oeffentlich bereit, nutzt Testzahlung ohne Echtgeld und meldet
  keine fatalen Laufzeitfehler;
- Produktion blieb unveraendert auf Commit
  `09c9211e41da75969b9ee59e9954ac7465250e80`.

Servernachweis:

- Staging-Release:
  `/docker/shareittoo/releases/staging-20260814T224254Z-0761f9382414.json`
- Staging-Sicherung:
  `/docker/shareittoo/backups/staging/shareittoo-staging-20260814T222552Z.sha256`

## Bewusste Grenzen / naechste Schritte

- Migration 013 und der sichere Zwei-Rollen-Serverfluss sind auf der isolierten
  Staging-Umgebung angewendet und integrativ bestanden.
- Kandidat 2026081411 ist ausschliesslich im Google-Play-Internal-Test als
  `1.0.0-internal-2026081411` verfuegbar. Closed Testing, Open Testing und
  Produktion blieben unveraendert.
- Das Pixel 7 Pro wurde verlustfrei ueber Google Play von 2026081409 auf
  2026081411 aktualisiert. Installer, Versionscode, erhaltener Staging-Login,
  Kaltstart und geladener Feed wurden verifiziert; es trat kein fataler
  Startfehler auf.
- Der reale PSP-Vertrag, finale Rechtsfreigabe, Store-Datenschutzantworten und
  der geschlossene Test bleiben offene Live-Gates.
- Der geschuetzte Store-Review-Nachweis wurde fuer Kandidat 2026081411
  ehrlich auf `review-fixture-refresh-pending` gesetzt: beide Rollen-Logins,
  Staging-Health, Positivlisten-Inserat und Preisangebot bestehen; das
  Erzeugen der neuen akzeptierten Testbuchung endet serverseitig noch mit
  `internal_error`. Die alte stornierte, zahlungsfreie Fixture wurde
  archiviert. Ein neues synthetisches Inserat ist vorbereitet; akzeptierte
  Buchung und gemeinsamer Chat bleiben bis zur Fehlerbehebung offen.
- Naechster technischer Schritt: Google-Play-Installation auf dem zweiten
  Testgeraet und visueller Zwei-Rollen-End-to-End-Test fuer Uebergabe,
  Rueckgabe, Fehlcode, Ablauf, Replay-Schutz und die SIT-Dialoge.

## Google-Play-Internal-Meilenstein 16.51

- Release: `1.0.0-internal-2026081411`
- Status: `Available to internal testers`
- Versionscode: `2026081411`
- Google-Pruefung: noch nicht erfolgt; temporaerer Paketname fuer interne
  Tester bleibt erwartungsgemaess sichtbar.
- Unterstuetzte Telefone: 12.427; kein Geraeteverlust zur Vorversion.
- Downloadgroesse fuer neue Installationen: 59,3 MB; Updategroesse: 5 MB.
- Release-Hinweis bindet den sicheren Privat-Pilot-Ablauf ausdruecklich an
  Staging und Testzahlungen.
- Play-signiertes Pixel-Update: bestanden, Installer `com.android.vending`.
- Repository-Nachweise und Fail-closed-Validatoren: bestanden.
- Grenzen: kein Closed-, Open- oder Production-Release, keine oeffentliche
  Ausrollung, kein Echtgeld und keine Produktionsaenderung.

## Meilenstein 16.52 – aktive V4-Zwischenregeln und ehrlicher Review-Stand

- Alle sechs offenen V4-Punkte sind zentral als Version
  `V4-INTERIM-2026-08-15` fuer interne und geschlossene Tests aktiv. Sie koennen
  nach einer neuen Nutzerentscheidung gemeinsam in App, Backend,
  Rechtstexten und Tests ersetzt werden.
- Echtgeld, Auszahlung, Schadensverrechnung und rechtliche Live-Freigabe
  bleiben technisch ausgeschaltet.
- Der Store-Review-Nachweis ist nicht mehr faelschlich gruen: beide
  Rollen-Logins, Staging-Health, Positivlisten-Inserat und Preisangebot sind
  verifiziert; akzeptierte Buchung und gemeinsamer Chat bleiben wegen eines
  serverseitigen `internal_error` offen.
- Das Werkzeug fuer synthetische Review-Buchungen sendet jetzt die
  Privatstatus-Bestaetigung, die erlaubte Kategorie und alle fuenf getrennten,
  versionierten V4-Erklaerungen.
- Ein begrenzter Wiederholungsversuch verwendete das bereits vorbereitete
  Inserat ohne neuen Upload und ohne weiteres Inserat. Der Fehler blieb
  `internal_error`; als sicherer Serverbezug wurde die Korrelationsnummer
  `cacd5a0f-f85f-4c92-9dc9-af2497186f6c` erfasst. Es wurde kein Zahlungsweg
  aufgerufen.
- Vollstaendige App-Suite: 262 bestanden, 0 fehlgeschlagen.
- Vollstaendige Backend-Suite: 120 bestanden, 0 fehlgeschlagen, 1 lokaler
  PostgreSQL-Test mangels `TEST_DATABASE_URL` uebersprungen.
- Analyse der geaenderten V4-Dateien: 0 Befunde. Die 640 bereits vorhandenen
  Hinweise der Gesamtanalyse bleiben transparent offen und werden nicht als
  Freigabe behauptet.
- Google Play bleibt ausschliesslich beim internen Kandidaten
  `1.0.0-internal-2026081411`; Closed, Open, Produktion und Echtgeld wurden
  nicht veraendert.

## Meilenstein 16.53 – Review-Buchung und gemeinsamer Chat repariert

- Die Korrelationsnummer `cacd5a0f-f85f-4c92-9dc9-af2497186f6c` fuehrte zum
  exakten PostgreSQL-Fehler: Der gemeinsame Erstellungszeitpunkt der Buchung
  wurde gleichzeitig als Text und `TIMESTAMPTZ` abgeleitet. Commit `904b1c2`
  bindet alle drei Verwendungen explizit als `TIMESTAMPTZ`.
- Der naechste Annahmeversuch zeigte getrennt, dass das synthetische Werkzeug
  die vorgeschriebene versionierte Vermietererklaerung noch nicht mitsendete.
  Commit `25af918` sendet sie jetzt vollstaendig und uebersetzt fehlende oder
  ungueltige Erklaerungen in einen fachlichen 400er statt eines generischen
  500ers.
- Vor beiden Staging-Rollouts wurden Datenbank und Uploads getrennt gesichert
  und per SHA-256 geprueft. Beide Images waren unveraenderlich an ihren Commit
  gebunden; FCM-Secret-Gate, Container-Health und automatischer Rollback-Pfad
  waren aktiv.
- Aktives Staging: `1.0.0-2026081502-v4-owner-acceptance`, Commit
  `25af918304abb13b9959d5f1e8cc35f186ecec56`.
- Reale Staging-Abnahme: vorhandenes synthetisches Inserat wiederverwendet,
  Buchung angefragt, Vermieterannahme gespeichert, Buchung fuer beide Rollen
  sichtbar, gemeinsamer Thread fuer beide Rollen sichtbar und lesbar sowie je
  eine Nachricht aus Vermieter- und Mieterrolle angenommen.
- Der Store-Review-Nachweis steht deshalb fuer Login, Inserat, akzeptierte
  Buchung und gemeinsamen Chat wieder auf bestanden. Frische Installation und
  zweites Netz bleiben weiterhin offen und werden nicht vorweggenommen.
- Grenzen: Zahlung blieb `memory`, Stripe blieb nicht live, kein
  Zahlungsendpunkt wurde aufgerufen, Produktion blieb auf Commit
  `09c9211e41da75969b9ee59e9954ac7465250e80`, und kein oeffentlicher
  Store-Track wurde veraendert.

## Meilenstein 16.64 – sechs offene V4-Punkte releasefest aktiv

- Alle sechs offenen Punkte bleiben mit Status `open` als aktive
  Zwischenregeln gesetzt. Sie werden erst nach einer neuen Mitteilung des
  Nutzers zentral aktualisiert; keine Regel wurde als juristisch final
  bezeichnet.
- Der Legal-Readiness-Validator prueft jetzt nicht nur die Rechtstext-Hashes,
  sondern auch Version, Testumfang, Echtgeldsperre und alle sechs
  Zwischenentscheidungen gemeinsam in Manifest, Flutter-App und Backend.
- Ein Pausieren der Zwischenregel, stilles Schliessen eines offenen Punkts,
  Aktivieren echter Zahlungen in der App oder Entfernen eines Punkts im
  Backend stoppt den Release fail-closed.
- Die sechs Funktionswege wurden gemeinsam erneut geprueft: getrennte
  Buchungserklaerungen, neutraler Plattformwiderruf, 50/100-Storno,
  Test-/Mock-Geldfluss, neutrales Rueckgabefenster T0 plus fuenf Tage sowie
  vier Fotos je Richtung mit Gegenbestaetigung und QR-/Code-Ablauf.
- Ergebnis: 11 Legal-Validator-Tests, 12 Backend-Tests und 60 Flutter-Tests
  bestanden; kein Fehler.
- Der bereits aus Google Play installierte Android-Kandidat 2026081505 bleibt
  unveraendert. Die neue Aenderung ist eine Repository- und Release-Sperre und
  erfordert allein keinen neuen Store-Kandidaten. Der physische V4-Rollenlauf
  auf 2026081505 war bereits bestanden.
- Produktion, oeffentliche Store-Tracks, Echtgeld, juristische Live-Freigabe,
  manuelle TalkBack-Abnahme und Zwei-Geraete-Matrix blieben unveraendert
  geschlossen beziehungsweise offen.
- Maschinenlesbarer Nachweis:
  `docs/evidence/b11/v4-interim-contract-enforcement-20260815T042919Z.json`.

## Meilenstein 16.65 – exakter Play-Review-, Screenshot- und Technikstand

- Der bereits aktive Google-Play-Internal-Kandidat `2026081505` wurde als
  exakte Play-Split-Installation mit Installer `com.android.vending`
  kontrolliert. Es wurde kein neuer Store-Kandidat hochgeladen und kein
  oeffentlicher Track veraendert.
- Die vier vorgesehenen Telefon-Screenshots wurden direkt aus diesem exakten
  Kandidaten neu aufgenommen und visuell freigegeben: Feed, Inseratdetail,
  Suche und Anzeige erstellen. Alle Bilder sind 1080 x 1920 Pixel, enthalten
  keine Kontodaten oder Zugangsdaten. Die vier alten Fassungen wurden am
  15. August durch diese vier exakten Bilder ersetzt und als Play-Listing-
  Entwurf gespeichert; es wurde nichts zur Pruefung eingereicht.
- Der geschuetzte Staging-Reviewbestand ist fuer Build `2026081505` erneut
  geprueft: technische Zugaenglichkeit sowie acht von zehn Szenarien bestehen.
  Frische Installation und zweites Netz bleiben ehrlich offen.
- Die Google-Play-Datensicherheitsmatrix ist an denselben Kandidaten gebunden:
  16 von 17 Antworten sind technisch vorbereitet, aber nicht in der Console
  gespeichert. Die Dienstleister-/Sharing-Einstufung umfasst fuenf aktive
  Auftragsverarbeiter; ihre rechtliche und nutzerseitige Freigabe bleibt offen
  und blockiert das Speichern fail-closed.
- Die Analyse-Regressionssperre wurde ohne Erhoehung der Toleranz repariert.
  Nach Korrektur der neuen asynchronen UI-Stellen sank der Gesamtstand von 640
  auf 611 Meldungen; die neue feste Obergrenze ist 611. Commit: `5e5677b`.
- Der vollstaendige technische Pruefpfad bestand: alle Repository- und
  Store-Validatoren, alle 266 Flutter-Tests, Web-Debug-Build und
  Android-Debug-Build. Der Datenschutz-Quellnachweis wurde ausschliesslich
  fuer die technisch geaenderte Standortdatei auf deren neuen SHA-256
  aktualisiert; die Datennutzung selbst wurde nicht erweitert.
- Alle sechs offenen V4-Punkte bleiben unveraendert als aktive
  `V4-INTERIM-2026-08-15`-Regeln gesetzt. Sie sind weder entfernt noch als
  final beschlossen markiert und werden erst nach einer neuen Mitteilung des
  Nutzers zentral aktualisiert.
- Weiterhin offen: manuelle TalkBack-/Grossschrift-Abnahme, zweites Netz,
  frische Installation, Closed Testing, Apple-Tooling/-Mitgliedschaft,
  finale Rechts- und Datenschutzentscheidungen sowie echte Zahlungsfreigabe.
  Produktion, Echtgeld und oeffentliche Store-Tracks blieben unveraendert.

## Meilenstein 16.66 – Fresh-Install-Nachweis und SIT-Popup-Zugaenglichkeit

- Der exakte Google-Play-Internal-Kandidat `2026081505` blieb als vierteiliges
  Play-Split-Paket mit Installer `com.android.vending` unveraendert installiert.
- Die isolierten SIT-App-Daten wurden kontrolliert geleert. Der erste Start
  erschien korrekt abgemeldet; die Android-16-Benachrichtigungsfreigabe wurde
  durchlaufen, das geschuetzte synthetische Staging-Konto automatisch
  wiederhergestellt und der Login ueberstand den anschliessenden Kaltstart.
- Der Store-Review-Zugang steht dadurch bei 9 von 10 bestandenen Szenarien.
  Nur der Nachweis ueber ein zweites wirklich getrenntes Netz bleibt offen und
  wird nicht vorweggenommen.
- Maschinenlesbarer Nachweis:
  `docs/evidence/b11/android-fresh-install-2026081505-20260815T054742Z.json`.
  Repository-Commit: `814a64e`.
- Beim Lauf wurde sichtbar, dass das rote Schliessen-Symbol der zentrierten
  SIT-Popups noch keinen Screenreader-Namen hatte. Die gemeinsame
  Popup-Komponente benennt diese Aktion jetzt eindeutig mit `Schliessen`.
  Repository-Commit: `8f60af5`. Diese UI-Verbesserung gehoert erst zum
  naechsten App-Kandidaten und wird dem unveraenderten Play-Build `2026081505`
  nicht rueckwirkend zugeschrieben.
- Der vollstaendige technische Pruefpfad bestand: saemtliche Repository-,
  Store-, Rechts-, Datenschutz-, Review- und Geraetepruefer, 266 Flutter-Tests,
  Web-Debug-Build und Android-Debug-Build. Apple blieb im ausdruecklich offenen
  Android-Rollover-Modus.
- Alle sechs offenen V4-Punkte bleiben unveraendert als aktive Zwischenregeln
  `V4-INTERIM-2026-08-15` gesetzt. Sie sind weder entfernt noch finalisiert und
  werden erst nach einer neuen Mitteilung des Nutzers zentral aktualisiert.
- Produktion, Echtgeld, oeffentliche Store-Tracks, Closed Testing,
  Apple-Tooling/-Mitgliedschaft, TalkBack-/Grossschrift-Geraetematrix sowie
  finale Rechts- und Datenschutzfreigaben blieben unveraendert geschlossen
  beziehungsweise offen.

## Meilenstein 16.67 – Android-SMS-Nachweis korrekt gebunden

- Der bereits vorhandene anonymisierte Realgeraete-Nachweis fuer Firebase-
  Telefonverifizierung wurde aus dem veralteten Zwischenstatus uebernommen:
  Der Google-Play-Internal-Build `2026081403` erhielt eine echte SMS, nahm den
  neuesten gueltigen Code an, behielt den verifizierten Zustand nach frischem
  Login und lehnte einen falschen Code ab, ohne das Konto zu verifizieren.
- Der aktuelle Play-Kandidat `2026081505` ist getrennt als derzeitige
  Quell- und Store-Bindung dokumentiert. Er enthaelt die anschliessend
  eingefuehrten zentrierten SIT-Dialoge mit spezifischen Erklaerungen fuer
  ungueltige Telefonnummer, falschen oder abgelaufenen Code und technische
  Verbindungsfehler. Dem aktuellen Kandidaten wird kein neuer SMS-Versand
  zugeschrieben.
- Der Validator liest nun die drei konkreten, bereinigten Nachweise selbst,
  prueft Build, Play-Auslieferung, Signing-Ergebnis, reale SMS-Ergebnisse und
  die Bindung an den aktuellen Store-Kandidaten. Geschwaechte oder fehlende
  Belege stoppen den Release fail-closed.
- Android-App-Verifizierung und Android-Realgeraete-SMS stehen damit auf
  `passed`. Weiterhin offen bleiben Apple/APNs, ein realer Apple-SMS-Test und
  die noch nicht final gespeicherte Store-/Dienstleister-Einstufung.
- Zehn gezielte Validator-Tests und zwei Flutter-Vertragstests bestanden. Der
  Release-Vorcheck bestand alle lokalen Stufen bis zum externen Firebase-
  Projektwert, der in dieser lokalen Sitzung nicht gesetzt war; es wurde keine
  Firebase-, Produktions-, Zahlungs- oder Store-Aenderung ausgefuehrt.
- Telefonnummern, SMS-Codes, Firebase-Token, Kontodaten und Geraete-IDs sind
  aus allen Nachweisen ausgeschlossen.
- Alle sechs offenen V4-Punkte bleiben unveraendert als aktive Zwischenregeln
  `V4-INTERIM-2026-08-15` gesetzt. Sie werden erst nach einer neuen Mitteilung
  des Nutzers aktualisiert und sind weder entfernt noch finalisiert.

## Meilenstein 16.69 – Offen-Status in App und Backend verriegelt

- Alle sechs V4-Entscheidungen tragen jetzt nicht nur im Store-Manifest,
  sondern auch in der Flutter-App und im Backend-Domainmodell ausdruecklich
  den maschinenlesbaren Status `open`.
- Die Zwischenregeln bleiben gleichzeitig fuer interne und geschlossene Tests
  aktiv. `open` bedeutet deshalb bewusst "noch nicht final entschieden" und
  nicht "funktionslos".
- Der Rechtsvalidator verlangt exakt sechs `status: 'open'`-Eintraege in App
  und Backend. Ein stilles Entfernen, Schliessen oder Umdeuten stoppt den
  Release-Vorcheck fail-closed.
- 19 gezielte Backend-/Rechtsvalidator-Tests und der Flutter-Vertragstest
  bestanden. Es wurden weder Echtgeld, Produktion noch Store-Ausrollung
  aktiviert.
- Eine spaetere Aenderung erfolgt erst nach einer ausdruecklichen Mitteilung
  des Nutzers und muss dann Manifest, App, Backend, Rechtstexte und Tests
  gemeinsam aktualisieren.

## Meilenstein 16.68 – Android-WLAN-Matrix 9/11 und Zugänglichkeits-Vorlauf

- Die zuvor pauschal offene Android-WLAN-/Owner-Zelle ist jetzt an die bereits
  vorhandenen exakten Nachweise des Google-Play-Builds `2026081505` gebunden.
  Neun von elf Teilpruefungen stehen belegt auf `passed`: frischer Start,
  Anmeldung/Sitzung, Inserat/Buchung, Chat/Deep-Link, Push im Vordergrund,
  Push im Hintergrund, Push bei beendetem Prozess, Uebergabe/Rueckgabe und
  Offline-Wiederherstellung.
- `moderationAndAccount` bleibt ehrlich auf `testing`: Melden, Blockieren,
  Datenexport und sichere Abmeldung sind belegt; die irreversible Loeschung
  eines gesonderten Wegwerf-Testkontos wurde nicht ungefragt ausgefuehrt.
- `largeTextAndScreenReader` bleibt ebenfalls auf `testing`. Auf dem realen
  Pixel 7 Pro wurden der exakte Play-Kandidat, Play-Installer, WLAN, TalkBack
  und mindestens 200 Prozent Schrift gleichzeitig ohne Vorbedingungsblocker
  erkannt. Die eigentliche SIT-Traversierung wurde jedoch vom erstmaligen
  Android-TalkBack-Einfuehrungsbildschirm abgefangen und deshalb nicht als
  App-Abnahme gewertet.
- Nach dem Vorlauf wurden Schriftgroesse exakt auf 85 Prozent,
  Zugänglichkeitsdienste auf aus und `accessibility_enabled` auf 0
  wiederhergestellt; ShareItToo wurde wieder in den Vordergrund gebracht.
- Der Gerätevalidator prueft nun auch nicht abgeschlossene
  `device-matrix-cell-progress`-Belege: Kandidat, Zelle, jeder Teilstatus,
  Zeitstempel, Zusammenfassung und alle referenzierten bereinigten Nachweise
  muessen uebereinstimmen. Ein vorgezogener Pass stoppt fail-closed.
- 62 Geräte-Nachweistests und 15 B11-Dokumenttests bestanden. Der gesamte
  lokale Release-Vorcheck bestand erneut bis zum externen Firebase-Projektwert
  dieser Sitzung. Keine externe Konfiguration, Produktion, Zahlung oder
  Store-Ausrollung wurde veraendert.
- Alle sechs offenen V4-Punkte bleiben unveraendert als aktive Zwischenregeln
  `V4-INTERIM-2026-08-15` gesetzt. Sie werden erst nach einer neuen Mitteilung
  des Nutzers aktualisiert und sind weder entfernt noch finalisiert.

## Meilenstein 16.70 – Google-Play-Kandidat 1506 intern aktiv und geschlossen vorbereitet

- Der exakte Android-Kandidat `1.0.0+2026081506` ist im Google-Play-Internal-
  Track aktiv. Die Auslieferung wurde auf dem Pixel 7 Pro als vierteiliges
  Play-Split-Paket mit Installer `com.android.vending` nachgewiesen; Version,
  Play-App-Signing-Zertifikat und verifizierte App-Links stimmen.
- Kaltstart, Wiederherstellung der bereits vorhandenen Anmeldung und der
  authentifizierte Staging-Feed bestanden auf genau diesem Play-Build. Der
  Nachweis enthaelt weder Identitaetsdaten noch Zugangsdaten oder rohe
  Geraete-IDs.
- Der Closed-Alpha-Entwurf enthaelt ausschliesslich Build `2026081506`, meldet
  keine technischen Releasefehler und ist als Entwurf gespeichert. Er wurde
  weder zur Pruefung gesendet noch gestartet.
- Die oeffentlichen Seiten Datenschutz, Support und Kontoloeschung antworten
  erfolgreich. `https://shareittoo.com/privacy` ist in Google Play gespeichert
  und erscheint in der Veroeffentlichungsuebersicht. Die Datensicherheits-
  erklaerung bleibt der einzige offene App-Content-Bereich und wird wegen der
  offenen Dienstleister-, Aufbewahrungs- und Rechtsentscheidungen nicht
  geraten, gespeichert oder eingereicht.
- Android nutzt fuer neue Fotos den systemeigenen Fotoauswaehler und fordert
  keine breite Medienbibliothek-Berechtigung mehr an. Die vier Store-Bilder
  wurden erneut direkt aus Build `2026081506` aufgenommen, visuell geprueft
  und sind bytegenau identisch zu den vier bereits gespeicherten Bildern.
  Deshalb war kein erneutes Hochladen oder Aendern des Play-Listings noetig.
- Die bestandene Geraetematrix von Build `2026081505` wurde nicht auf den neuen
  Kandidaten uebertragen. Fuer `2026081506` stehen die vier Matrixzellen wieder
  ehrlich auf offen; bestaetigt sind bisher nur die exakt neu beobachteten
  Installations-, Signatur-, Link-, Feed- und Sitzungsmerkmale. Frische
  Installation, zweites Konto, Chat-/Bildfluss, Push, Crashlytics, Offline-
  Wiederherstellung und zweites Netz werden separat neu geprueft.
- Der vollstaendige Android-Regressionslauf bestand alle Validatoren, alle 266
  Flutter-Tests, Web-Debug-Build und Android-Debug-Build. Auch der lokale
  Release-Vorcheck bestand fuer `com.shareittoo.app` in Version
  `1.0.0+2026081506`; der Status bleibt bewusst `hold` mit 0/4 Geraetezellen
  und 5/7 Releasepruefungen.
- Produktion, Echtgeld, oeffentliche Store-Tracks, Review-Versand und Closed-
  Test-Rollout blieben unveraendert. Alle sechs V4-Punkte bleiben mit
  `status: open` unter `V4-INTERIM-2026-08-15` aktiv und werden erst nach einer
  neuen Mitteilung des Nutzers zentral aktualisiert.
