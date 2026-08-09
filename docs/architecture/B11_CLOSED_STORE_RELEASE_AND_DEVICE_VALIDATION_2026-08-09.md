# B11 – Geschlossener Store-Release und reale Geräteabnahme

Stand: 9. August 2026
Technischer Status: in Arbeit; CI, Android-Kandidat und isoliertes Staging bestanden, Store- und Geräte-Gates noch offen
Produktionsstatus: unverändert; kein B11-Code und kein Echtgeld ausgerollt

## Ziel und Freigabegrenze

B11 bereitet einen ausschließlich geschlossenen Pilotkandidaten für Google
Play Internal Testing und Apple TestFlight vor. Der Baustein ist erst
bestanden, wenn signierte Builds auf realen unterstützten Android- und
iOS-Geräten installiert wurden, die Kernmatrix ohne P0-Fehler durchlaufen ist
und jede Store-Buildnummer eindeutig einem Commit zugeordnet werden kann.

Ein öffentlicher Store-Rollout, Produktion, Stripe-Livebetrieb und echtes Geld
sind ausdrücklich nicht Bestandteil dieser Freigabe.

## Abgeschlossener technischer Zwischenstand

### Öffentliche, isolierte Staging-Adresse

- `staging.shareittoo.com` besitzt einen autoritativen A-Eintrag auf
  `2.24.194.2`; Cloudflare- und Google-DNS liefern denselben Wert.
- Caddy terminiert TLS und leitet ausschließlich `/api/*` an
  `shareittoo-staging-api:8080` weiter.
- Der Proxy ist mit Produktions- und Staging-Netz verbunden; beide API-Images
  blieben beim Infrastrukturwechsel unverändert.
- Vor der Änderung wurde
  `/docker/shareittoo/Caddyfile.before-b11-staging-20260809T0945Z` angelegt.
- Vor der Digital-Asset-Links-Erweiterung wurde zusätzlich
  `/docker/shareittoo/Caddyfile.before-b11-assetlinks-20260809T1034Z`
  angelegt.
- Produktions- und Staging-Healthcheck meldeten Datenbank und Mail mit `ok`.

Das kanonische, CI-validierte Proxy-Setup liegt in `backend/ops/Caddyfile`.

### Finale App-Identität und Darstellung

- Android Application ID und Namespace: `com.shareittoo.app`.
- iOS Bundle ID: `com.shareittoo.app`.
- Versionsname: `1.0.0`.
- Interne Android-Buildnummer: `2026080902`.
- Android Verified Links und iOS Associated Domains sind für
  `shareittoo.com`, `www.shareittoo.com` und `staging.shareittoo.com`
  vorbereitet.
- Android Digital Asset Links werden auf allen drei Hosts ohne Weiterleitung
  als `application/json` ausgeliefert. Der aktuelle Fingerabdruck deckt den
  direkt installierbaren APK-Kandidaten ab; der spätere Play-App-Signing-
  Fingerabdruck muss nach Kontoerstellung zusätzlich eingetragen werden.
- Googles öffentlicher Digital-Asset-Links-Prüfdienst bestätigt die Zuordnung
  auf `shareittoo.com`, `www.shareittoo.com` und `staging.shareittoo.com`.
- App-Icon und Startbildschirm verwenden das ShareItToo-Symbol auf weißem
  Hintergrund; alle Android- und iOS-Größen sind ohne Alphakanal erzeugt und
  geprüft.

### Signierung und commitgebundener Android-Kandidat

Der echte Android-Uploadschlüssel liegt ausschließlich außerhalb des
Repositories. `android/key.properties` ist ignoriert und besitzt lokale
Dateirechte `0600`. Öffentlicher SHA-256-Zertifikatsfingerabdruck:

`09:8F:48:5E:57:16:15:58:E9:11:FC:3C:74:28:45:92:55:84:DB:31:C4:74:CD:BA:08:DD:A0:2F:EB:01:29:A4`.

Der signierte aktuelle Android-Kandidat wurde aus dem sauberen Commit
`a37e681ce18c62981992e168965e68b80fc86ff2` gebaut:

| Merkmal | Wert |
|---|---|
| Paket | `com.shareittoo.app` |
| Version | `1.0.0 (2026080902)` |
| Kanal | `internal` |
| API | `https://staging.shareittoo.com/api/v1` |
| Firebase im Artefakt | noch deaktiviert |
| AAB SHA-256 | `9c0c95cb6d2839f0bced1de6d459dd17a52fbf56c325de312d93a102ff747a30` |
| APK SHA-256 | `23148626b3631a0979bd1d05381488e6a1845ee72ad737a8c847f427f42bc3e0` |

Der Buildprozess lehnt eine schmutzige Arbeitskopie, falsche App-ID,
ungültige Buildnummer, fehlende Signierung, falsches Paket sowie ungültige
AAB-/APK-Signaturen ab. Ein Push-fähiger Kandidat verlangt zusätzlich alle
Firebase-Kennungen und die echte `android/app/google-services.json`.

### Push, Crash-Berichte und Deep Links

- Die App initialisiert Firebase nur bei vollständiger plattformspezifischer
  Build-Konfiguration; unvollständige Entwickler- und CI-Builds bleiben sicher
  deaktiviert.
- Push-Berechtigung, Tokenregistrierung, Tokenwechsel, Hintergrundempfang und
  Öffnen eines geprüften Action-Links sind vorbereitet.
- Crashlytics sammelt nur in Release-Builds; synchrone und asynchrone fatale
  Fehler erhalten die jeweilige Release-Identität.
- Das Backend verwendet den offiziellen Firebase-Admin-Transport, maximal 500
  Geräte pro Batch, entfernt ungültige Tokens und schreibt weder Tokens noch
  Zugangsdaten in Logs.
- Der Service-Account wird nur als read-only Datei in den Container gemountet.
  Fehlende oder nicht lesbare Dateien führen bei aktiviertem FCM zu einem
  geschlossenen Startfehler.
- Optionale Installationsskripte von `@firebase/util` und `protobufjs` sind in
  der pnpm-Lieferkettenrichtlinie ausdrücklich verboten.

## Bisherige automatische Abnahme

- Flutter-Analyzer: keine neue Regression; bekannte Basis 696.
- Flutter: 167 von 167 Tests bestanden.
- Web-Debug-Build: bestanden.
- Android-Debug-APK: bestanden.
- Android-Release-AAB und -APK: gebaut, Paketkennung, Version und Signatur
  bestanden.
- Backend-Syntax und FCM-Datenvertrag: bestanden.
- Secret-Scan: kein hochwahrscheinliches Geheimnis in Historie oder
  Arbeitsbaum.
- Produktionsabhängigkeiten: keine hohe oder kritische bekannte
  Schwachstelle; eine moderate indirekte `uuid`-Warnung aus dem optionalen
  Google-Cloud-Storage-Abhängigkeitszweig bleibt dokumentiert.

### Vollständiger CI- und Image-Nachweis

GitHub-Actions-Lauf `31309281497` ist für Commit
`a37e681ce18c62981992e168965e68b80fc86ff2` vollständig grün:

- Backend: 55 von 55 Tests einschließlich echter PostgreSQL-16-Integration.
- Flutter: 167 von 167 Tests; Analyzer-Basis 696 ohne neue Regression.
- Web-Debug und Android-Debug bestanden.
- Separater signierter, commitgebundener Android-Release-AAB/-APK bestanden.
- Produktionsabhängigkeiten: keine hohe oder kritische bekannte
  Schwachstelle; Secret-Scan ohne hochwahrscheinlichen Treffer.
- Produktions- und Staging-Compose sowie kanonisches Caddy-Setup validiert.
- Verifiziertes API-Image erst nach beiden grünen Jobs veröffentlicht.

Unveränderlicher Registry-Digest:
`sha256:2a42190b3cd1db6245cba4f5cce1850928e82675cb6fed73d959d257fc5d7855`.

### Ausgerolltes isoliertes Staging

Staging läuft exakt mit Commit
`a37e681ce18c62981992e168965e68b80fc86ff2` und meldet öffentlich sowie lokal
Version, Datenbank, Mail, Benachrichtigungsqueue und Zahlungs-Memory-Transport
gesund. FCM bleibt bis zur geschützten Firebase-Konfiguration im
Memory-Modus; der vorbereitete read-only Service-Account-Mount zeigt derzeit
bewusst auf `/dev/null`.

Vor dem Wechsel wurden Datenbank und Uploads unter
`/docker/sit-staging/backups/pre-b11-20260809T110327Z` gesichert und geprüft.
Der abgesicherte Rollout-Nachweis liegt unter
`/docker/sit-staging/backups/staging-20260809T110413Z-a37e681ce18c.json`.

Die vollständige produktionsnahe B10-Kernmatrix wurde auf dem neuen B11-Image
erneut bestanden: Sicherheitsheader, CORS-Grenze, Anfragekorrelation,
datensparsamer Kontodatenexport, Feed/Suche, Bild, Chat, Buchungen und sichere
Ablehnung eines ungültigen Zahlungs-Webhooks. Alle 25-fachen Parallelproben
blieben deutlich unter ihren Grenzwerten; null aktive synthetische Testkonten
blieben zurück. Nachweis:
`/docker/sit-staging/backups/b11-live-acceptance-20260809T110631Z.json`.

Produktion wurde weder migriert noch neu gestartet. API- und
Datenbankcontainer behielten exakt ihre vorherigen Container- und Image-IDs;
beide blieben gesund. Das Produktions-API-Image blieb unverändert bei
`sha256:db30af4c03512ca774d6ca275620bdef2becb0b6269d67d1514d27170c1af0d7`.

## Externe Gates und ehrlicher Status

| Gate | Status | Nächster eindeutiger Schritt |
|---|---|---|
| Firebase-Projekt | vorbereitet | Walid akzeptiert einmalig die Firebase-Nutzungsbedingungen; danach Projekt `shareittoo-staging` anlegen und Android/iOS registrieren |
| FCM-Service-Account | offen | nach Projekterstellung erzeugen, außerhalb Git sichern und read-only auf Staging mounten |
| APNs | offen | Apple Developer Team, Push-Key und Provisioning verbinden |
| Google Play Internal Testing | gesperrt | Entwicklerkontoart wählen und Registrierungsgebühr durch Walid abschließen |
| App Store Connect/TestFlight | gesperrt | Apple-Anmeldung und 2FA durch Walid; vollständiges Xcode und Team-Signierung einrichten |
| Reale Android-Geräte | offen | APK/AAB auf mindestens einem unterstützten Gerät und zwei Netzen testen |
| Reale iOS-Geräte | offen | TestFlight-Build auf mindestens einem unterstützten Gerät testen |
| Stripe-Testmodus | offen | echte Testschlüssel und Webhook erst nach ausdrücklicher Kontofreigabe verbinden |
| Tester/Einladungen | offen | zwei Rollen festlegen und ausschließlich geschlossene Gruppen einladen |

Es ist derzeit kein vollständiges Xcode installiert, kein iOS-Signing-Team
verbunden und kein physisches Android- oder iOS-Gerät an den Build-Mac
angeschlossen. Diese Punkte dürfen nicht als bestanden markiert werden.

## Noch auszuführende Kernmatrix

Auf beiden Plattformen und mit Vermieter- sowie Mieterrolle:

1. Installation, Erststart, Berechtigungen, Login und Neustart.
2. Feed/Suche, Inserat, Bild-Upload und Buchungsanfrage.
3. Annahme, Stripe-Testzahlung, Statussynchronisation und Beleg.
4. Chat, Push im Vordergrund/Hintergrund/beendet, Deep Link und Offline-Wiederkehr.
5. Übergabe, Rückgabe, Storno/Erstattung, Streitfall und Review.
6. Datenexport, Abmeldung, erneuter Login und Kontolöschung.
7. Große Schrift, VoiceOver/TalkBack, Tastatur-/Fokusweg und unterstützte
   Displaygrößen.
8. Crashlytics-Testereignis mit korrekter Commit- und Buildzuordnung.

## B11-Abnahmekriterium

B11 bleibt offen, bis mindestens ein Android-Internal-Build und ein
TestFlight-Build installierbar sind, die Kernmatrix auf realen Geräten ohne
P0-Fehler bestanden ist, Store-Warnungen und Crashberichte geprüft wurden und
die Buildnummern eindeutig auf die dokumentierten Commits zeigen.
