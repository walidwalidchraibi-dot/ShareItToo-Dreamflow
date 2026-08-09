# B11 – Geschlossener Store-Release und reale Geräteabnahme

Stand: 9. August 2026
Technischer Status: in Arbeit; Android-Kandidat gebaut, Store- und Geräte-Gates noch offen
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

Der signierte Zwischenkandidat wurde aus dem sauberen Commit
`c454b598635f146321bc9f47f1c3ae173ac71261` gebaut:

| Merkmal | Wert |
|---|---|
| Paket | `com.shareittoo.app` |
| Version | `1.0.0 (2026080902)` |
| Kanal | `internal` |
| API | `https://staging.shareittoo.com/api/v1` |
| Firebase im Artefakt | noch deaktiviert |
| AAB SHA-256 | `1e5de015e70530b37e101e86a11a93c1b3269b4f27c9b0928fe28185f3b7b3aa` |
| APK SHA-256 | `b1bbc09940ff6d078caee1434d8f2a92f328821283c012f29bb65c148b085572` |

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

Der vollständige PostgreSQL-16-, Compose-, Caddy-, Image- und
Release-CI-Nachweis für den aktuellen Backendstand wird nach Abschluss des
GitHub-Laufs ergänzt.

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
