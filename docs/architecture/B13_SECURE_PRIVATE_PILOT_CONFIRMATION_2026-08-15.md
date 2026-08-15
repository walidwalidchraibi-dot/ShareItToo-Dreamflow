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
