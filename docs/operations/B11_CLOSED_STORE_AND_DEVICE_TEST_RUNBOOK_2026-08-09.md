# B11 – Runbook für geschlossenen Store-Test und reale Geräte

Status: vorbereitet; Ausführung beginnt nach Firebase-, Store- und Gerätefreigabe

## Zweck und Schutzgrenze

Dieses Runbook führt den unveränderten ShareItToo-Kandidaten durch Google Play
Internal Testing, Apple TestFlight und die reale Geräteabnahme. Es erlaubt
ausschließlich geschlossene Tests gegen `staging.shareittoo.com`.

Nicht erlaubt sind öffentlicher Store-Rollout, Produktionsdeployment,
Stripe-Liveschlüssel, echtes Geld, echte Auszahlungen oder nicht ausdrücklich
eingeladene Testpersonen.

## Verbindlicher Release-Eintrag

Vor jeder Installation werden alle Felder ausgefüllt. Ändert sich Commit,
Buildnummer, Signatur, Firebase-Konfiguration oder API-Ziel, beginnt die
betroffene Abnahme mit einem neuen Eintrag von vorn.

| Feld | Aktueller technischer Kandidat |
|---|---|
| Android/iOS Kennung | `com.shareittoo.app` |
| Version | `1.0.0` |
| Buildnummer | `2026080902` |
| Commit | `a37e681ce18c62981992e168965e68b80fc86ff2` |
| Kanal | `internal` |
| API | `https://staging.shareittoo.com/api/v1` |
| Firebase | deaktiviert; kein Store-Upload dieses Zwischenkandidaten |
| AAB SHA-256 | `9c0c95cb6d2839f0bced1de6d459dd17a52fbf56c325de312d93a102ff747a30` |
| APK SHA-256 | `23148626b3631a0979bd1d05381488e6a1845ee72ad737a8c847f427f42bc3e0` |
| API-Image-Digest | `sha256:2a42190b3cd1db6245cba4f5cce1850928e82675cb6fed73d959d257fc5d7855` |

Der erste Push-fähige Store-Kandidat erhält zwingend die höhere Buildnummer
`2026080903`. Seine Hashes, sein Commit und sein Firebase-Status ersetzen die
Zwischenwerte in einem neuen Nachweis; ältere Artefakte werden nicht
überschrieben.

## Eintrittsbedingungen

Vor Beginn müssen alle zutreffenden Punkte nachweisbar erfüllt sein:

- Firebase-Projekt `shareittoo-staging` angelegt; Android- und iOS-App exakt
  mit `com.shareittoo.app` registriert.
- Android `google-services.json`, iOS Firebase-Konfiguration und
  FCM-Service-Account sicher eingebunden; keine Secret-Datei in Git.
- APNs-Key, Apple-Team und Provisioning für TestFlight verfügbar.
- Play-App-Signing-Fingerabdruck zusätzlich in Digital Asset Links
  eingetragen und öffentlich geprüft.
- Google-Play-Internal-Track und TestFlight-interne Gruppe vorhanden.
- Mindestens ein reales unterstütztes Android- und ein reales iOS-Gerät
  verfügbar; Geräte besitzen keine produktiven ShareItToo-Daten.
- Zwei synthetische Testkonten stehen bereit: Vermieterrolle und Mieterrolle.
- Stripe bleibt `memory` oder ausdrücklich freigegebener Testmodus;
  `livemode=false` ist vor und nach jedem Lauf sichtbar.
- Staging `/version` zeigt exakt den freigegebenen Backendcommit; Readiness
  meldet Datenbank und Mail gesund sowie keine tote Queue.
- Vor dem Lauf besteht eine geprüfte Staging-Sicherung von Datenbank und
  Uploads.

## Geräte- und Rollentabelle

Für jede Zeile werden Gerät, Betriebssystem, App-Build, Netz und Tester
eingetragen. Simulatoren dürfen ergänzen, aber keine reale Gerätezeile
ersetzen.

| Plattform | Gerät/Modell | Betriebssystem | Build | Netz | Rolle | Ergebnis |
|---|---|---|---|---|---|---|
| Android real | offen | offen | `2026080903` | WLAN | Vermieter | offen |
| Android real | offen | offen | `2026080903` | Mobilfunk/Hotspot | Mieter | offen |
| iOS real | offen | offen | `2026080903` oder höher | WLAN | Vermieter | offen |
| iOS real | offen | offen | `2026080903` oder höher | Mobilfunk/Hotspot | Mieter | offen |

## Artefakt- und Installationsprüfung

1. Commit, Buildnummer, Paketkennung, API-Ziel und Hash gegen den
   Release-Eintrag prüfen.
2. Android-AAB nur in den geschlossenen Internal-Track laden; Warnungen und
   Play-App-Signing-Zertifikat dokumentieren.
3. Android zunächst über den offiziellen Testlink installieren. Ein direktes
   APK dient nur der Diagnose und zählt nicht als Store-Installation.
4. iOS-Archiv aus dem dokumentierten Commit mit dem ausgewählten Team bauen,
   in TestFlight laden und Verarbeitung ohne kritische Warnung abwarten.
5. TestFlight-Build ausschließlich an interne oder ausdrücklich benannte
   geschlossene Tester verteilen.
6. Auf jedem Gerät eine vorhandene ältere Testinstallation entfernen, wenn
   dadurch Signatur-, Cache- oder Migrationszustand unklar wäre.
7. Erststart und `/version`-sichtbare Releasekennung im Testnachweis erfassen.

## Kernablauf pro Plattform

### Installation, Berechtigungen und Sitzung

1. Store-Installation, Erststart und Darstellung des weißen App-Icons prüfen.
2. Benachrichtigungs-, Foto-/Kamera- und weitere Berechtigungen einmal
   erlauben und einmal ablehnen; die App muss in beiden Fällen verständlich
   bleiben.
3. Verifiziertes Testkonto anmelden, App beenden, neu starten und
   Sitzungswiederherstellung prüfen.
4. Abmelden, erneut anmelden und parallele Sitzung auf dem zweiten Gerät
   prüfen.
5. App-Link für Verifizierung, Passwortweg, Buchung, Chat, öffentliches
   Inserat und öffentliches Profil öffnen; fremde Hosts, ungültige Kennungen
   sowie pausierte oder entfernte Inserate müssen sicher abgewiesen werden.

### Inserat, Suche und Buchung

1. Vermieter erstellt ein synthetisches Inserat mit mindestens einem
   Testbild, Preis, Kaution, Standorttext und Verfügbarkeit.
2. Mieter findet es über Feed und Suche, öffnet Details und sendet eine
   Buchungsanfrage.
3. Vermieter nimmt an; beide Geräte zeigen denselben autoritativen Status.
4. Wiederholtes Tippen, Netzwechsel und erneutes Öffnen dürfen keine doppelte
   Anfrage oder Transition erzeugen.
5. Zahlung bleibt im freigegebenen Testtransport. Betrag, Plattformanteil,
   Kautionslimit und Beleg müssen mit dem Backendzustand übereinstimmen.

### Chat, Push und Offline-Wiederkehr

Für Vermieter und Mieter jeweils prüfen:

1. Nachricht im Vordergrund; genau eine Zustellung und korrekte Lesemarkierung.
2. App im Hintergrund; Push erscheint ohne private Nachrichtendetails auf dem
   Sperrbildschirm, sofern die Systemeinstellung Vorschauen begrenzt.
3. App vollständig beendet; Push öffnet ausschließlich den berechtigten Chat
   oder Buchungszustand.
4. Push-Berechtigung abgelehnt und später in Systemeinstellungen aktiviert.
5. WLAN aus, Aktion versuchen, Mobilfunk/Hotspot aktivieren und sichere
   Wiederkehr ohne doppelte Mutation prüfen.
6. Abmelden und Push an das alte Konto auslösen; das Gerät darf keine private
   Zielansicht des abgemeldeten Kontos öffnen.
7. Tokenwechsel beziehungsweise Neuinstallation prüfen; ungültige alte Tokens
   dürfen keine dauerhafte tote Queue erzeugen.

### Übergabe, Rückgabe, Storno und Vertrauen

1. Übergabe und Rückgabe in zulässiger Reihenfolge durchführen.
2. Storno- und Testrefundweg aus beiden Rollen prüfen.
3. Kontrollierten Streitfall mit ausschließlich synthetischer Evidenz anlegen.
4. Meldung und Blockierung prüfen; gesperrte Interaktion muss serverseitig
   abgewiesen werden.
5. Nach berechtigtem Abschluss je Rolle genau eine Bewertung erstellen;
   Duplikat muss abgewiesen werden.

### Datenschutz und Kontolebenszyklus

1. Kontodatenexport auslösen; Datei muss privat, vollständig und ohne
   Passwort-/Token-Hashes, Zahlungskennungen oder Staff-Notizen sein.
2. Exportdatei unmittelbar nach Prüfung vom Testgerät löschen.
3. Kontolöschungs-Preflight prüfen, blockierende Buchung zuerst korrekt
   abschließen oder stornieren und Konto regulär löschen.
4. Gelöschtes Konto darf keine neue Sitzung erhalten; berechtigte Auditspur
   bleibt ohne unnötige private Nutzdaten erhalten.

## Barrierefreiheit

Auf mindestens einer realen Gerätekonfiguration je Plattform:

- Systemschrift auf mindestens 200 Prozent; keine abgeschnittene P0-Aktion.
- TalkBack beziehungsweise VoiceOver vollständig für Login, Feed, Inserat,
  Buchung, Chat, Zahlungstest, Export und Löschung verwenden.
- Fokusreihenfolge, Rollen, Namen, Busy-, Fehler- und Erfolgsmeldungen prüfen.
- Kontrast, Touchziele, Hoch-/Querformat und kleine unterstützte
  Displaybreite prüfen.
- Externe Tastatur oder Switch-/Full-Keyboard-Access ergänzend prüfen, sofern
  auf dem Gerät verfügbar.

## Crashlytics- und Releasezuordnung

1. Nur auf dem geschlossenen Staging-Build ein kontrolliertes, als solches
   markiertes Testereignis erzeugen.
2. In Crashlytics prüfen: Paketkennung, Plattform, Version, Buildnummer,
   Commit-/Releasekennung und Testzeit stimmen überein.
3. Sicherstellen, dass weder Token, E-Mail, Nachrichtentext, Adresse noch
   Zahlungsdaten im Ereignis erscheinen.
4. Ereignis im Nachweis referenzieren, nicht dessen sensible Rohdaten kopieren.

## Evidenz und Datenschutz

Jeder Lauf erhält eine eindeutige Kennung im Format
`b11-<plattform>-<build>-<kurzzeit>`. Erfasst werden:

- Gerät und Betriebssystem ohne persönliche Gerätekennung;
- Store-Track, Version, Build, Commit und Artefakthash;
- Testschritt, erwartetes Ergebnis, tatsächliches Ergebnis und Schweregrad;
- bereinigter Screenshot oder Bildschirmaufnahme, wenn für den Fehler nötig;
- relevante serverseitige Anfragekennung, niemals Token oder vollständige
  private Nutzdaten;
- Abschlusszeit, Testerrolle und Freigabeentscheidung.

Screenshots werden vor Ablage auf E-Mail, Namen, Adressen, Nachrichten,
Geräte-IDs und Zahlungsdetails geprüft. Versehentlich erfasste private Daten
werden nicht in Git, Telegram oder den Masterplan kopiert.

### Maschinenlesbarer Go/No-Go-Nachweis

`store/device-validation.json` ist die verbindliche Ergänzung zu diesem
Runbook. Vor Beginn wird dort derselbe Commit, Build, API-Ziel, Firebase- und
Zahlungsmodus eingetragen. Jede der vier Rollen-/Netz-Zellen erhält nach der
Ausführung Gerätemodell, Betriebssystem, Store-Installationsweg, alle
Einzelresultate und einen bereinigten Nachweis unter `docs/evidence/b11/`.

Der offene Stand muss jederzeit bestehen:

```text
node tool/validate_device_evidence.mjs
```

B11 darf nur freigegeben werden, wenn zusätzlich der strenge Lauf besteht:

```text
node tool/validate_device_evidence.mjs --require-passed
```

Der strenge Lauf verlangt vier bestandene reale Gerätezellen, sieben
plattformweite Releaseprüfungen, technische und produktseitige Freigabe sowie
die gemeinsame Schließung der drei zugehörigen Store-Gates. Zugangsdaten,
Tokens, Roh-Gerätekennungen und unbereinigte Nutzerdaten sind in Manifest und
Evidenzablage verboten. Detailvertrag:
`docs/operations/B11_MACHINE_READABLE_DEVICE_EVIDENCE_2026-08-09.md`.

## Fehlerklassen und Stop-Regeln

| Klasse | Bedeutung | Reaktion |
|---|---|---|
| P0 | Datenverlust, Kontoübernahme, Secret-/Privatdatenleck, falscher Geldfluss, nicht autorisierter Zugriff, App startet nicht oder Kernbuchung unmöglich | Test sofort stoppen, Track nicht freigeben, Staging sichern, Ursache beheben und gesamte betroffene Matrix mit höherer Buildnummer wiederholen |
| P1 | Wesentliche Kernfunktion, Push, Deep Link oder Accessibility-Weg unbrauchbar, aber kein unmittelbarer P0-Schaden | Keine B11-Freigabe; Fix und betroffene Plattformmatrix wiederholen |
| P2 | Begrenzte Abweichung mit verständlichem Workaround | Dokumentieren, priorisieren und explizit vor Pilotfreigabe bewerten |
| P3 | Kosmetik ohne Funktions- oder Zugänglichkeitsverlust | Backlog; blockiert geschlossenen Test nicht automatisch |

Bei falscher API-Umgebung, unerwartetem `livemode=true`, unbekanntem Commit,
nicht reproduzierbarer Signatur oder fehlendem Staging-Backup gilt unabhängig
von der sichtbaren Funktion sofort No-Go.

## Rückfall und Bereinigung

1. Fehlerhaften Store-Build deaktivieren beziehungsweise Testerzugriff
   stoppen; keinen öffentlichen Rollout auslösen.
2. Staging nur über den aktuellen abgesicherten Deploy-Harness auf den letzten
   dokumentierten gesunden Image-Digest zurücksetzen.
3. Datenbank nicht herabmigrieren. Bei additiver Migration zunächst ältere App
   auf neuem Schema prüfen; Restore nur nach eigener Restore-Abnahme.
4. Synthetische Buchungen, Inserate, Uploads und aktive Testkonten regulär
   bereinigen; notwendige Audit-/Fallspuren bleiben nachvollziehbar.
5. Push-Tokens der Testgeräte beim Abmelden oder Kontolöschen deaktivieren.
6. Readiness, Version, Queue, Payment-Status und Produktionsinvariante nach dem
   Rückfall erneut prüfen.

## B11-Go/No-Go

B11 ist nur bestanden, wenn alle Punkte erfüllt sind:

- derselbe dokumentierte Build wurde aus Play Internal Testing und TestFlight
  auf realen Geräten installiert;
- die vollständige Kernmatrix ist auf Android und iOS ohne offenen P0 oder P1
  bestanden;
- TalkBack und VoiceOver sind auf den Kernwegen bestanden;
- Push in Vordergrund, Hintergrund und beendetem Zustand ist geprüft;
- Crashlytics zeigt die korrekte Releasezuordnung ohne sensible Nutzdaten;
- Store-Warnungen, App-Signing-Fingerabdrücke und Deep Links sind geprüft;
- synthetische Testdaten sind bereinigt und Staging bleibt gesund;
- Produktion und Echtgeldpfade blieben unverändert;
- Bericht, Masterplan und Maximus enthalten denselben finalen Buildstand.
- `node tool/validate_device_evidence.mjs --require-passed` besteht für genau
  diesen unveränderten Build.

Erst danach darf B12 mit exakt diesem unveränderten Geräte-Build beginnen.
