# B13 – Sicherer Privat-Pilot-Bestaetigungsfluss

Stand: 2026-08-15  
Kandidat: `1.0.0+2026081411`  
Commit: `7f86ffd1a2c18a41a8b0479c5deba5251fb3a911`  
Umgebung: internes Android-Staging, kein Echtgeld, kein externer Upload

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

## Verifikation

- Flutter-Gesamtsuite: 262 bestanden, 0 fehlgeschlagen.
- Backend-Gesamtsuite: 118 bestanden, 0 fehlgeschlagen, 1 PostgreSQL-Test lokal
  mangels `TEST_DATABASE_URL` uebersprungen.
- Flutter-Gesamtanalyse: Exit 0; nur bereits bekannte Warnungen/Hinweise.
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

## Bewusste Grenzen / naechste Schritte

- Migration 013 muss vor Nutzung auf der isolierten Staging-Datenbank
  angewendet und dort integrativ geprueft werden.
- Kandidat 2026081411 wurde nicht zu Google Play hochgeladen und nicht auf
  Produktion ausgerollt.
- Der reale PSP-Vertrag, finale Rechtsfreigabe, Store-Datenschutzantworten und
  der geschlossene Test bleiben offene Live-Gates.
- Naechster technischer Schritt: Staging-Migration, Deployment des gebundenen
  Backends, Installation des Kandidaten und ein Zwei-Geraete-Test fuer
  Uebergabe, Rueckgabe, Fehlcode, Ablauf und Replay-Schutz.

