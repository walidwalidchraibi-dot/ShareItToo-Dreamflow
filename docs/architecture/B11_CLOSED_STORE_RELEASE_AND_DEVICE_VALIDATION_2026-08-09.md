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

<!-- SIT_CURRENT_RELEASE_SNAPSHOT_BEGIN -->
### Aktueller maschinengebundener B11-Kandidat

| Merkmal | Verbindlicher Wert |
|---|---|
| App-Identität | `com.shareittoo.app` (Android und iOS) |
| Version und Build | `1.0.0 (2026081107)` |
| App-Commit | `99de848db090372f09d9c6f2fe3b838329584677` |
| Kanal und API | `internal`, `https://staging.shareittoo.com/api/v1` |
| Firebase und Zahlung | vollständig: `true`; `memory`; `stripeLivemode=false` |
| Android-AAB SHA-256 | `5dea2813a9e57343f7896faa44a41904f1a585ef6cc0d2992135dc1d970eab3b` |
| Android-APK SHA-256 | `ae249b35d5724b11dda182765cf0482ade540dbd13b0d08c07af0cf25a8738ab` |
| Uploadzertifikat SHA-256 | `098f485e57161558e911fc3c742845925584db31c474cdba08dda02feb0129a4` |
| Direkte Android-Diagnose | `passed` auf Pixel 7 Pro, Android 16; `docs/evidence/b11/android-direct-smoke-2026081107-20260811T112948Z.json` |
| Direkte Android-App-Link-Diagnose | `pending`; noch kein kandidatenspezifischer Nachweis |
| Angemeldete Android-Sitzungsdiagnose | `passed` auf Pixel 7 Pro, Android 16; `docs/evidence/b11/android-authenticated-session-2026081107-20260811T115022Z.json` |
| Synthetische Android-Rollenbuchung | `pending`; noch kein kandidatenspezifischer Nachweis |
| Authentifizierte Android-Deep-Links | `pending`; noch kein kandidatenspezifischer Nachweis |
| Kontrollierte Android-FCM-Diagnose | `pending/passed/pending`; noch kein vollständiger kandidatenspezifischer Nachweis |
| Android-Abmeldung und Push-Unterdrückung | `pending/pending`; noch kein vollständiger kandidatenspezifischer Nachweis |
| Crashlytics-Releasezuordnung | `open`; noch kein kandidatenspezifischer Nachweis |
| Kandidatenbeleg | `docs/evidence/b11/android-candidate-2026081107.json` |
| Staging-Servercommit | `46e56f489d1fba7decdb1e3f5942425b3c0f9f83` |
| Ehrlicher Freigabestand | `testing/hold`; Gerätezellen 0/4; Releaseprüfungen 3/7 |

Dieser Block wird aus den verbindlichen JSON-Nachweisen geprüft. Die direkten APK-, App-Link-, Sitzungs-, Rollenbuchungs-, Deep-Link-, FCM- und Abmeldediagnosen sind keine Store-Installation. Die kontrollierten synthetischen WLAN-Nachweise schließen weder Hotspot und die vollständige Rollen-/Netzmatrix noch TalkBack, iOS/TestFlight, Produktion oder Echtgeld.
<!-- SIT_CURRENT_RELEASE_SNAPSHOT_END -->

Der chronologisch erhaltene historische Logout-/Push-Lebenszyklusnachweis für Build
`2026081026` liegt unter
`docs/evidence/b11/android-logout-push-lifecycle-2026081026-20260810T140200Z.json`.
Er belegt auf dem physischen Android-Gerät Vordergrund-, Hintergrund- und bei
zuvor beendetem Prozess ausgelöste Staging-Pushs, das vergrößerte adaptive
Symbol, die Anmeldesperre nach einem Kaltstart und die ausbleibende Zustellung
nach dem Logout. Er wurde durch die oben referenzierten exakten Build-1029-
Nachweise abgelöst und schließt weiterhin kein Store-, Hotspot-, TalkBack- oder
iOS-Gate.

Die anschließende lesende Crashlytics-Triage ist unter
`docs/evidence/b11/crashlytics-open-issues-triage-20260810T221142Z.json`
festgehalten. Beide offenen Fatal-Gruppen stammen aus älteren Builds; für die
vorbereitete Korrektur sind 200 Flutter-Tests sowie Web- und Android-Debug-Build
grün. Da diese Änderung nicht Bestandteil des archivierten Build `2026081029`
ist, muss sie in einem neuen exakten Kandidaten erneut auf Geräten geprüft
werden und schließt hier kein Gate.

## Chronologischer technischer Nachweis

Die folgenden Abschnitte halten die Entwicklungsschritte und damaligen
Kandidatenwerte bewusst historisch fest. Für jede neue Ausführung ist
ausschließlich der oben maschinengebundene Snapshot zusammen mit
`store/device-validation.json` verbindlich.

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
- Interne Android-Buildnummer: `2026080903`.
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
  Hintergrund; alle Android-, iOS- und Web-Größen sind ohne Alphakanal erzeugt
  und geprüft. Frühere Flutter-Standardicons in Favicon, PWA- und
  Maskable-Assets wurden vollständig ersetzt.
- `tool/verify_brand_assets.mjs` bindet alle 34 ausgelieferten Icon- und
  Launch-PNGs an den freigegebenen 1024-Pixel-Master, ihre Sollgröße und das
  deckend weiße RGB-Format. Der Prüfer ist Teil von Regression und
  Release-Preflight; Web-Startfarbe und native Launch-Hintergründe werden
  ebenfalls fail-closed geprüft.
- Der vollständige GitHub-Actions-Lauf `31316133047` für Commit
  `53dc61831a2d3bcc3c7ee9b487827e2ed0b1cfa9` bestätigt den Markenprüfer,
  56/56 Backendtests, 167/167 Fluttertests, Web/Android sowie den signierten
  commitgebundenen Android-Kandidaten.

### Signierung und commitgebundener Android-Kandidat

Der echte Android-Uploadschlüssel liegt ausschließlich außerhalb des
Repositories. `android/key.properties` ist ignoriert und besitzt lokale
Dateirechte `0600`. Öffentlicher SHA-256-Zertifikatsfingerabdruck:

`09:8F:48:5E:57:16:15:58:E9:11:FC:3C:74:28:45:92:55:84:DB:31:C4:74:CD:BA:08:DD:A0:2F:EB:01:29:A4`.

Der signierte aktuelle Android-Kandidat wurde aus dem sauberen Commit
`5594cd32dea38b67c330f75cd71b50325f72c407` gebaut:

| Merkmal | Wert |
|---|---|
| Paket | `com.shareittoo.app` |
| Version | `1.0.0 (2026080903)` |
| Kanal | `internal` |
| API | `https://staging.shareittoo.com/api/v1` |
| Firebase im Artefakt | vollständig an `shareittoo-staging` gebunden |
| AAB SHA-256 | `b62de0ebc0b5b3ba828881f3ed8753a2fe58ac3d82347a14baecc69df593538f` |
| APK SHA-256 | `13a84826527931652bb16e2bf1eb809757d6a16529b819f7fff53157937d4914` |

Der Buildprozess lehnt eine schmutzige Arbeitskopie, falsche App-ID,
ungültige Buildnummer, fehlende Signierung, falsches Paket sowie ungültige
AAB-/APK-Signaturen ab. Ein Push-fähiger Kandidat verlangt zusätzlich alle
Firebase-Kennungen und die echte `android/app/google-services.json`.

`tool/validate_android_signing_config.mjs` prüft zusätzlich vor jedem
Release-Build die Eigentümerrechte von `android/key.properties` und Keystore,
verbietet Symlinks sowie eine Keystore-Ablage im Repository und liest das
Passwort nur über eine kurzlebige Umgebungsvariable für `keytool`. Der normale
CI-Kanal darf seinen kurzlebigen Testschlüssel verwenden. Sobald
`SIT_REQUIRE_STORE_SUBMISSION=1` gesetzt ist, wird ausschließlich der oben
dokumentierte kanonische SHA-256-Fingerabdruck akzeptiert. Der tatsächlich im
APK gefundene Zertifikatsfingerabdruck wird erneut geprüft und in den
commitgebundenen Release-Nachweis geschrieben.

### Push, Crash-Berichte und Deep Links

- Das Firebase-Projekt `shareittoo-staging` wurde im kostenlosen Spark-Tarif
  ohne Google Analytics angelegt. Android und iOS sind exakt als
  `com.shareittoo.app` registriert; die Projektnummer ist `214007794438`.
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
  Fehlende, nicht lesbare, strukturell falsche oder an ein anderes Firebase-
  Projekt gebundene Dateien führen bei aktiviertem FCM zu einem geschlossenen
  Startfehler.
- iOS besitzt Push Capability, ein umgebungsgebundenes `aps-environment`-
  Entitlement, die Hintergrundmodi `fetch` und `remote-notification` sowie den
  Crashlytics-dSYM-Upload. Die Laufzeit wartet vor dem FCM-Token begrenzt auf
  den APNs-Token und bricht andernfalls sicher ab.
- `tool/validate_firebase_release_config.mjs` bindet Plattformdateien,
  Buildwerte, Paket-/Bundle-ID, verbotene Tracking-SDKs, APNs und den
  Symbolupload fail-closed an Regression und Release-Preflight. Detailvertrag:
  `docs/operations/B11_FIREBASE_PUSH_RELEASE_GATE_2026-08-09.md`.
- Optionale Installationsskripte von `@firebase/util` und `protobufjs` sind in
  der pnpm-Lieferkettenrichtlinie ausdrücklich verboten.
- Inserat- und Profilfreigaben erzeugen keine Platzhalter-/Altdomains mehr,
  sondern commitgebundene Links der aktuellen ShareItToo-API-Umgebung.
  Backend und App unterstützen `listing` und `profile`; nicht öffentliche
  Inserate werden beim Öffnen erneut abgewiesen.
- Der kanonische FCM-Service-Account
  `sit-fcm-staging@shareittoo-staging.iam.gserviceaccount.com` ist ausschließlich
  auf Staging aktiv. Die root-eigene Datei ist nur für die dedizierte
  Laufzeitgruppe lesbar und read-only in den nicht privilegierten Container
  eingebunden. Die echte Google-Authentisierung wurde ohne Pushversand
  bestätigt.

### Android-Binärdatenschutz

- App-Backup und Geräteübertragung sind für Sitzungen und lokale App-Daten
  ausgeschlossen; Klartextverkehr und Legacy-Speichermodus sind deaktiviert.
- Alte Speicherberechtigungen enden bei API 32 beziehungsweise API 28.
- Jeder signierte AAB-/APK-Kandidat wird auf Identität, Commit/API-Bindung,
  Berechtigungen, Manifestrichtlinien, erwartete Firebase-Komponenten,
  unerlaubte Tracking-SDKs und bekannte falsche Laufzeitursprünge geprüft.
- Der lokale, echt signierte Commit
  `5c917d8e9c3597d52c61970d7f5a044e512d4008` bestand diesen Scan mit null
  Befunden. AAB-Hash:
  `edeb58d154680fa2b180e40683e9aa85b0a80b6c374b21348a7d30a178530085`;
  APK-Hash:
  `7aafb1a04ed4e17e98756866a7ffd43cacbed3309205988e149311f3f28c9985`.
- Die Negativprobe mit dem vorherigen Kandidaten wurde mit elf erwarteten
  Befunden abgelehnt. Der genaue Nachweis steht in
  `docs/operations/B11_ANDROID_BINARY_PRIVACY_AND_PUBLIC_LINKS_2026-08-09.md`.
- Das plattformübergreifende Store-Gate bleibt offen, bis ein finaler
  Firebase-Kandidat, IPA-/Privacy-Manifest-Scan, reale Netzwerkbeobachtung und
  die Store-Formularabgleiche bestanden sind.
- Die anschließende lesende Laufzeitkontrolle bestätigte Staging weiterhin
  gesund auf Commit `281d34e147b96667d6a8c12c45dbedd3e60cca56` mit
  `memory`-Payment und `livemode=false`; der bestehende Produktions-Healthcheck
  meldete Datenbank und Mail `ok`. Dieser Baustein wurde nirgends ausgerollt.
- GitHub-Actions-Lauf `31317921211` bestätigte den Implementierungscommit
  vollständig mit PostgreSQL-Integration, 169 von 169 Fluttertests, Analyzer-
  Basis 696, Web/Android, signiertem AAB/APK und erneut grünem Binärscan. Das
  veröffentlichte, nicht ausgerollte API-Image trägt den Digest
  `sha256:e41f79c3e1faa268e3abd9e14600b1d4a1e3b0bd677aea9548fb6435c6b0fdff`.

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
`2dac78321b278a06c1ba8a27e9789f5860ad001c` und meldet öffentlich sowie lokal
Version, Datenbank, Mail, Benachrichtigungsqueue und Zahlungs-Memory-Transport
gesund. FCM ist ausschließlich auf Staging mit dem kanonischen
`shareittoo-staging`-Absender aktiv; der Service-Account wird eng begrenzt und
read-only eingebunden. Die echte Google-Authentisierung ist bestanden, eine
reale Push-Nachricht wurde vor dem Gerätetest bewusst noch nicht versendet.

Der kontrollierte Rollout-Nachweis liegt unter
`/docker/shareittoo/releases/staging-20260809T184811Z-2dac78321b27.json` und
enthält `stagingFcm=true`. Ein erster Aktivierungsversuch stoppte wegen zu eng
gesetzter Leserechte fail-closed und wurde ohne Secret-Offenlegung vollständig
zurückgerollt, bevor die dedizierte Laufzeitgruppe implementiert und geprüft
wurde.

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
Datenbankcontainer behielten bei allen B11-Staging-Vorgängen ihre vorherigen
Container- und Image-IDs; beide blieben gesund.

## Externe Gates und ehrlicher Status

| Gate | Status | Nächster eindeutiger Schritt |
|---|---|---|
| Firebase-Projekt | Android technisch fertig | realen Android-Push auf eigenem Pilotgerät prüfen; iOS/APNs folgt separat |
| FCM-Service-Account | Staging bestanden | echte Zustellung, Tokenwechsel und Abmeldung auf dem Pilotgerät prüfen |
| APNs | offen | Apple-ID und Developer-Mitgliedschaft einrichten; danach Team, Push-Key und Provisioning verbinden |
| Google Play Internal Testing | gesperrt | Entwicklerkontoart wählen und Registrierungsgebühr durch Walid abschließen |
| App Store Connect/TestFlight | gesperrt | Apple-Anmeldung und 2FA durch Walid; vollständiges Xcode und Team-Signierung einrichten |
| Reale Android-Geräte | Direkt-Smoke bestanden, Matrix offen | aktuellen Kandidaten auf Pixel 7 Pro funktional über WLAN und Hotspot sowie später unverändert über Play Internal prüfen |
| Reale iOS-Geräte | offen | TestFlight-Build auf mindestens einem unterstützten Gerät testen |
| Stripe-Testmodus | offen | echte Testschlüssel und Webhook erst nach ausdrücklicher Kontofreigabe verbinden |
| Tester/Einladungen | offen | zwei Rollen festlegen und ausschließlich geschlossene Gruppen einladen |

Es ist derzeit kein vollständiges Xcode installiert, kein iOS-Signing-Team
verbunden und kein physisches iOS-Gerät für TestFlight verfügbar. Für Android
wurden reale Direktinstallationen auf OnePlus und Pixel nachgewiesen; diese
ersetzen weder die offene Rollen-/Netzmatrix noch die spätere Installation
über Google Play Internal. Diese Punkte dürfen nicht als bestanden markiert
werden.

## Noch auszuführende Kernmatrix

Das ausführbare Test- und Evidenzprotokoll liegt unter
`docs/operations/B11_CLOSED_STORE_AND_DEVICE_TEST_RUNBOOK_2026-08-09.md`. Es
definiert Release-Eintrag, Eintrittsbedingungen, reale Geräte-/Rollenmatrix,
Store-Installation, Push-/Offline-Fälle, Barrierefreiheit, Datenschutz,
Fehlerklassen, Stop-Regeln, Rückfall und B11-Go/No-Go.

Die Matrix ist zusätzlich unter `store/device-validation.json`
maschinenlesbar und fail-closed gebunden. Referenzierte Pass-Belege werden
inhaltlich als kandidatengebundene JSON-Dokumente geprüft; eine beliebige
nicht leere Datei kann kein Geräte-, Release- oder Freigabegate schließen.
Abweichende Commits, Zell-/Prüfungs-IDs, credential-förmige Felder und
Roh-Gerätekennungen werden abgelehnt. Der aktuelle ehrliche Zustand ist
`testing`, `hold`, vier offene Gerätezellen und drei von sieben bestandene
Releaseprüfungen. `tool/validate_device_evidence.mjs` prüft App-Identität,
Mindestbuild `2026080903`, vollständigen Commit, Android-/iOS-Artefakthashes,
Play-Internal-/TestFlight-Installation, physische Rollen-/Netzmatrix,
TalkBack/VoiceOver, alle Push-Zustände, Binär-/Netzwerkdatenschutz,
Crash-Releasezuordnung, Store-Warnungen, Staging-Bereinigung und
Produktionsinvariante. Der strenge Lauf verlangt vorhandene bereinigte Belege
unter `docs/evidence/b11/` und schließt mit den drei zugehörigen Store-Gates
gemeinsam. Er ist im späteren Uploadmodus Pflicht und bleibt bis zur realen
Ausführung erwartungsgemäß gesperrt. Detailnachweis:
`docs/operations/B11_MACHINE_READABLE_DEVICE_EVIDENCE_2026-08-09.md`.

Der unveränderte Kandidat `2026080903` wurde am 9. August 2026 nach der
fail-closed Vorprüfung erstmals direkt auf einem physischen OnePlus-Gerät mit
Android 16 installiert. Installierte Version, Buildnummer, Erststart und
Vordergrundaktivität wurden bestätigt; der bereinigte Nachweis liegt unter
`docs/evidence/b11/android-direct-smoke-2026080903-20260809T202357Z.json`.
Weil die Installation nicht über Google Play Internal erfolgte und noch keine
Funktions-, Push-, Netzwerk- oder Accessibility-Matrix durchgeführt wurde,
bleiben alle vier Gerätezellen und das B11-Go unverändert offen.

### Kandidat 2026080904 und korrigierte Registrierungsübergabe

Der reale Test des vorherigen Kandidaten zeigte eine missverständliche
Registrierungsübergabe: Nach einer vom Backend angenommenen Registrierung ohne
sofortige Sitzung erschien nur kurz der Hinweis zur E-Mail-Bestätigung; danach
kehrte die App in den Gastkontext zurück. Dadurch konnte der Eindruck
entstehen, die Registrierung sei bereits abgeschlossen oder verloren
gegangen. Die Korrektur leitet jetzt auf eine dauerhafte Anmeldeseite mit dem
Hinweis `Prüfe deine E-Mail` weiter, übernimmt die eingegebene E-Mail-Adresse
und leert beide Passwortfelder. Die Formulierung bleibt bewusst
enumerationssicher und bestätigt nicht, ob ein konkretes Konto existiert.

Die Korrektur ist als eigener Widgettest abgesichert. Der vollständige lokale
Stand besteht mit 173 von 173 Fluttertests, unveränderter Analyzer-Basis 696,
17 von 17 Evidenzvalidatortests und acht von acht Android-
Gerätevorbereitungstests. Build `2026080904` ist an Commit
`3b9bfe0f94febf141dc8ad2680fa84ffbf5cdfc9` gebunden, mit dem kanonischen
Uploadzertifikat signiert, vollständig für Firebase konfiguriert und weiterhin
ausschließlich auf `https://staging.shareittoo.com/api/v1` sowie
`stripeLivemode=false` begrenzt.

Der unveränderte neue APK-Kandidat wurde auf einem physischen Pixel 7 Pro mit
Android 16 installiert. Zurückgelesene Version und Buildnummer, Erststart und
Vordergrundaktivität sind bestanden. Der bereinigte Nachweis liegt unter
`docs/evidence/b11/android-direct-smoke-2026080904-20260809T213814Z.json`;
`store/device-validation.json` bindet ihn fail-closed an Kandidat, Hash und
Signatur. Der ältere OnePlus-Nachweis bleibt historisch erhalten, ist aber
nicht mehr der aktuelle Kandidatenbeleg.

Die GitHub-Läufe `31337631522` und `31337633477` bestätigten Commit
`9e24e7d6c4d0e9bbf263daf249b5796e95c25376` vollständig. Beide Backend- und
Flutter-Hauptjobs einschließlich signiertem Kontrollbuild sind grün. Der
Push-Lauf veröffentlichte das nicht ausgerollte API-Image mit Digest
`sha256:559c3078b5c17f122c6456257a2e41716db9c61c5674b9f0ae67e85239c7a82e`.
Weder Staging noch Produktion, Stripe-Live, DNS oder Echtgeld wurden dadurch
verändert.

Die reale Registrierung mit synthetischem Rollenalias, Bestätigungslink und
anschließendem Login ist noch nicht abgeschlossen. Ebenso bleiben Play
Internal, beide Android-Rollen-/Netzzellen, kontrollierte Push-Zustellung,
TalkBack, iOS/TestFlight und alle Freigaben offen. Die UI-Checkbox bezeichnet
korrekt ein Mindestalter von 18 Jahren; App, Backend und Storetexte bleiben für
den MVP konsistent auf volljährige Nutzer begrenzt.

### Echter Staging-Mailversand und bestätigtes Vermieter-Testkonto

Die offene Registrierung war serverseitig korrekt angenommen worden; das
synthetische Vermieter-Testkonto blieb zunächst unbestätigt, weil Staging noch
im sicheren `memory`-Mailmodus lief. Dieser Modus meldet die Mailkomponente als
funktionsfähig, liefert absichtlich aber keine externe Nachricht aus. Es lag
kein Gmail-, DNS- oder Kontofehler vor.

Commit `9a1371e02d8e7d63d3dee30ca169c6c7f37fa966` ergänzt die SMTP-Werte in
`backend/compose.staging.yml`, führt dieselben Schlüssel in
`backend/.env.staging.example` auf und dokumentiert im B2-Runbook den
ausdrücklichen Opt-in: Standard bleibt `memory`; nur für die geschlossene
Endgeräte-Abnahme wird der bereits IP-freigegebene Google-Workspace-Relay ohne
Produktionspasswort aktiviert.

Die lokale Backend-Suite und die Staging-Compose-Prüfung sind grün. Die
GitHub-Läufe `31338903466` und `31338906287` bestätigten Backend, Flutter-
Regression, signierten commitgebundenen Android-Kontrollbuild und API-Image-
Publikation vollständig. Der veröffentlichte und auf Staging ausgerollte
Digest lautet
`sha256:802e9215741dad72410837187705675882d0be6af028cd1b67ab95ef27630aaa`.

Staging läuft exakt auf diesem Commit. Datenbank, SMTP-Mail und
Benachrichtigungswarteschlange sind gesund; FCM bleibt ausschließlich in
Staging aktiv, während Zahlungstransport `memory` und `livemode=false`
bleiben. Der geschützte Release-Beleg liegt unter
`/docker/shareittoo/releases/staging-20260809T222808Z-9a1371e02d8e.json`.
Produktion wurde weder ausgerollt noch neu gestartet; DNS, Caddy, Cron,
Stripe-Live und Echtgeld blieben unverändert.

Der erneut angeforderte Bestätigungsbrief traf im Firmenpostfach ein. Der
einmalige Link wurde verarbeitet, und eine direkte Datenbankprüfung bestätigt
das synthetische Konto als vorhanden, aktiv und E-Mail-verifiziert. Tokenwert,
Passwort und andere Zugangsdaten wurden nicht ausgegeben oder gespeichert.

Der Pixel steht nun auf der Anmeldeseite mit vorausgefüllter Test-E-Mail und
absichtlich leerem Passwortfeld. Der Gaststart und die Staging-Verbindung sind
stabil; der leere Katalog meldet korrekt `Keine Anzeigen gefunden`. Als neuer
Cold-Start-UX-Punkt bleibt zu prüfen, ob die kanonischen Kategorien auch ohne
aktive Anzeigen sichtbar sein sollen. Login, Sitzung, erstes Pilotinserat,
zweites Mieter-Testkonto und vollständige Staging-Testbuchung bleiben offen.

Die Store-Vorbereitung ist zusätzlich in vier codebasierten Arbeitsunterlagen
festgehalten:

- `docs/operations/B11_STORE_SUBMISSION_PACKET_2026-08-09.md` mit deutschen
  Listing-Texten, Review-Hinweisen, Zahlungsabgrenzung und Einreichungsgates;
- `docs/operations/B11_STORE_PRIVACY_DISCLOSURE_MATRIX_2026-08-09.md` mit
  Google-Data-Safety- und Apple-App-Privacy-Zuordnung je Datentyp;
- `docs/operations/B11_STORE_SCREENSHOT_REVIEW_AND_TESTER_PLAN_2026-08-09.md`
  mit realen Bildszenen, Datenschutzprüfung, Review-Konten und geschlossenen
  Testgruppen;
- `docs/operations/B11_MACHINE_READABLE_DEVICE_EVIDENCE_2026-08-09.md` mit
  Geräte-/Rollenmatrix, Go/No-Go-Vertrag und bereinigter Evidenzablage.

Die Unterlagen sind noch keine Store-Abgabe. Öffentliche Support-,
Datenschutz- und Produktions-Kontolöschseiten sowie bestätigte Rechtsangaben
bleiben harte Eintrittsgates. Die externe Löschfunktion ist auf Staging unter
`https://staging.shareittoo.com/api/v1/account-deletion` erreichbar; die
entsprechende Produktions-API-URL lieferte am 9. August 2026 noch 404.

Die kanonischen Store-Texte und Gates liegen außerdem maschinenlesbar unter
`store/`. `tool/validate_store_metadata.dart` prüft Identität, Version,
Zeichen-/Bytegrenzen, Wahrheitsgrenzen, Quelldokumente, HTTPS-URLs und den
Freigabestatus. Der Standardlauf ist Bestandteil der lokalen und CI-
Regression sowie des signierten Release-Preflights. Ein tatsächlicher Upload
muss zusätzlich `SIT_REQUIRE_STORE_SUBMISSION=1` setzen; der strenge Modus
schließt bei jedem offenen Gate.

Der Release-Preflight prüft außerdem immer den ehrlichen Rechtsentwurf mit
`tool/validate_legal_readiness.mjs`. Im Store-Modus erzwingt er zusätzlich
`--require-approved`; geänderte oder nicht freigegebene AGB, Community-Regeln,
Storno-/Widerrufsregeln oder Gebühren-/Zahlungstexte sowie offene Rechts-,
Moderations- oder Konsistenzfreigaben stoppen den Build vor einem Upload.

Der geprüfte Entwurfsstand besteht mit `submissionAllowed=false`, drei offenen
Pflicht-URLs, elf offenen Gates, aktuellem Build `2026080902` und Mindest-
Store-Build `2026080903`. Der strenge Modus bricht mit genau diesen offenen
Punkten wie vorgesehen ab. Die vollständige lokale Regression blieb grün:
Analyzer-Basis 696 ohne neue Regression, 167 von 167 Flutter-Tests sowie Web-
Debug- und Android-Debug-Build bestanden.

GitHub-Actions-Lauf `31311617837` bestätigte Commit
`419b425b9182df3c35a81464cd006158acfd32e3` anschließend vollständig: 55 von
55 Backendtests, 167 von 167 Flutter-Tests, Analyzer-Basis 696, Web-/Android-
Debug, signierter commitgebundener Android-Release und Image-Publishing sind
grün. Der veröffentlichte API-Digest lautet
`sha256:30651b635bd783be77e97da73dfd27bb104e7a52672f086d46cc7c3f8e02b174`.

Dieser Lauf belegt nur Store-Metadaten- und Pipeline-Automation. Das mit dem
kurzlebigen CI-Schlüssel signierte Artefakt bleibt Version `2026080902`, ohne
Firebase und ist kein hochzuladender Store-Kandidat. Das neue API-Image wurde
weder auf Staging noch auf Produktion ausgerollt: Staging bleibt auf dem
vollständig abgenommenen technischen Commit `a37e681ce18c62981992e168965e68b80fc86ff2`;
Produktion bleibt geschützt und unverändert.

### Technische Grundlage der öffentlichen Pflichtseiten

Die endgültig vorgesehenen Root-URLs für Support, Datenschutz und
Kontolöschung sind nun im Store-Manifest eindeutig festgelegt. Ihr Status
bleibt `draft`; dadurch zählt der Validator weiterhin exakt drei offene
URL-Gates. Beliebige andere Hosts oder Pfade werden abgelehnt.

Der API-Dienst stellt eine fail-closed Seitenkette bereit:

- Support und Datenschutz liefern ohne ausdrückliche Freigabe HTTP 503 und
  maschinenlesbaren Status `draft`;
- die funktionsfähige Kontolöschung trägt separat den Status `operational`;
- eine JSON-Übersicht meldet den Gesamtstatus;
- das kanonische Caddy-Setup bereitet die öffentlichen Root-Pfade auf
  Produktion und isoliertem Staging vor.

Eine spätere Freigabe setzt bestätigte Support-/Datenschutzkontakte,
Anbietername, Anschrift und Wirksamkeitsdatum voraus. Wird
`PUBLIC_COMPLIANCE_APPROVED=true` ohne einen vollständigen und formal gültigen
Satz dieser Werte gesetzt, verweigert der API-Dienst den Start. Im jetzigen
Stand wurde keine Rechtsangabe als wahr angenommen.

`tool/verify_public_store_pages.mjs` prüft reale HTTP-Antworten,
maschinenlesbare Seiten- und Freigabemarker sowie Mindestinhalte. Der
signierte Release-Preflight ruft ihn bei `SIT_REQUIRE_STORE_SUBMISSION=1` nach
dem strengen Manifestcheck auf. Damit genügt weder ein zufälliger HTTP-200
noch die Auslieferung der Flutter-SPA als falscher Store-Nachweis.

Lokale Nachweise dieses Zwischenstands: Backend 55 von 55 ausführbaren Tests
grün, ein PostgreSQL-Integrationstest lokal mangels Testdatenbank übersprungen;
Flutter 167 von 167, Analyzer-Basis 696, Web-Debug und Android-Debug grün;
Validator im Standardmodus grün und im strengen Modus mit exakt drei URL- und
elf Release-Gates erwartungsgemäß geschlossen. Caddy und die echte
PostgreSQL-Integration werden zusätzlich in GitHub Actions geprüft.

GitHub-Actions-Lauf `31312753286` bestätigte anschließend Commit
`396d843a92c362c6ffc22ae25550a3eb6a9f0318` vollständig:

- 56 von 56 Backendtests einschließlich echter PostgreSQL-16-Integration;
- Secret- und Produktionsabhängigkeitsprüfung bestanden;
- Produktions- und Staging-Compose sowie die neuen Caddy-Root-Routen
  erfolgreich validiert;
- 167 von 167 Fluttertests, Analyzer-Basis 696, Web-Debug und Android-Debug;
- separater signierter und commitgebundener Android-Release-Kandidat;
- Store-Validator im normalen Entwurfsmodus sowohl in Regression als auch im
  Release-Preflight grün;
- API-Image erst nach beiden grünen Hauptjobs veröffentlicht.

Der veröffentlichte und ausdrücklich nicht ausgerollte Registry-Digest lautet
`sha256:7a9aa907b0b4a8f17e49f2090631c5fa2796010f0f0d05cc416f4ea24cf9be40`.
Das CI-Android-Artefakt bleibt Build `2026080902`, ohne Firebase und mit einem
kurzlebigen CI-Schlüssel; es ist kein Store-Kandidat.

Detail-Runbook:
`docs/operations/B11_PUBLIC_STORE_PAGES_READINESS_2026-08-09.md`.

Es erfolgte kein Staging- oder Produktionsdeploy. Staging bleibt auf
`a37e681ce18c62981992e168965e68b80fc86ff2`; Produktion, Stripe-Live und
Echtgeld bleiben geschützt.

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
