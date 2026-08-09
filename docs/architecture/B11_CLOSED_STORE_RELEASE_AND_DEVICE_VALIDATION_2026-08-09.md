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
| Firebase-Projekt | angelegt | öffentliche Android-/iOS-Konfigurationsdateien lokal einbinden und den strengen Releaseprüfer bestehen lassen |
| FCM-Service-Account | offen | nach Projekterstellung erzeugen, außerhalb Git sichern und read-only auf Staging mounten |
| APNs | offen | Apple-ID und Developer-Mitgliedschaft einrichten; danach Team, Push-Key und Provisioning verbinden |
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

Das ausführbare Test- und Evidenzprotokoll liegt unter
`docs/operations/B11_CLOSED_STORE_AND_DEVICE_TEST_RUNBOOK_2026-08-09.md`. Es
definiert Release-Eintrag, Eintrittsbedingungen, reale Geräte-/Rollenmatrix,
Store-Installation, Push-/Offline-Fälle, Barrierefreiheit, Datenschutz,
Fehlerklassen, Stop-Regeln, Rückfall und B11-Go/No-Go.

Die Matrix ist zusätzlich unter `store/device-validation.json`
maschinenlesbar und fail-closed gebunden. Der aktuelle ehrliche Zustand ist
`planned`, `no-go`, vier offene Gerätezellen und sieben offene
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
