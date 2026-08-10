# ShareItToo Store-Metadaten

Dieser Ordner ist die maschinenlesbare Quelle für die vorbereiteten Google-
Play- und Apple-Metadaten. `store/submission.json` hält App-Identität,
Wahrheitsgrenzen, öffentliche URLs und die offenen Einreichungsgates fest.
`store/device-validation.json` bindet den späteren B11-Go/No-Go zusätzlich an
denselben Build, vier reale Rollen-/Netz-Gerätezellen, die plattformweiten
Releaseprüfungen und bereinigte lokale Evidenzdateien.

Der aktuelle Zustand ist absichtlich `draft` und
`submissionAllowed: false`. Der Validator darf nur dann einen einreichbaren
Zustand akzeptieren, wenn alle Pflicht-URLs verifiziert, alle Gates geschlossen
und die Buildnummer mindestens `2026080903` ist.

Lokale Prüfung:

```text
dart run tool/validate_store_metadata.dart
node tool/validate_device_evidence.mjs
```

Der Standardlauf prüft den ehrlichen Entwurfszustand. Eine spätere
Store-Automation muss zusätzlich mit `--require-submittable` prüfen und darf
bei einem offenen Gate keinen Upload starten.

Der Gerätevalidator bleibt derzeit bewusst bei `state=testing`,
`goNoGo=hold`, `matrix=0/4` und `releaseChecks=4/7`. Kandidatenidentität und
Signaturen, Staging-Bereinigung/-Gesundheit sowie die Produktionsinvariante
sind bereits nachgewiesen. Nach den realen
Internal-/TestFlight-Läufen darf der Zustand nur mit echten, bereinigten
Dateiverweisen unter `docs/evidence/b11/` auf `passed` wechseln. Der strenge
Nachweis lautet:

```text
node tool/validate_device_evidence.mjs --require-passed
```

Vor dem ersten direkten Android-Gerätelauf prüft folgender Befehl das private
Kandidatenarchiv und verlangt genau ein autorisiertes physisches Telefon:

```text
node tool/prepare_android_device_test.mjs
```

Erst die separate Option `--install` installiert und startet das geprüfte APK.
Dieser Diagnoseweg zählt ausdrücklich nicht als Play-Internal-Installation.

Das geprüfte Google-Play-Store-Icon liegt unter
`store/assets/google-play/icon-512.png`. Der Metadatenvalidator verlangt exakt
512 × 512 Pixel, PNG ohne Alphakanal und höchstens 1.024 KB. Die geprüfte
Feature-Grafik liegt unter
`store/assets/google-play/feature-graphic-1024x500.png`; der Validator verlangt
exakt 1024 × 500 Pixel und ein 24-Bit-RGB-PNG ohne Alphakanal. Sie lässt sich
deterministisch mit `tool/generate_store_feature_graphic.py` aus dem
vorhandenen SIT-Markenasset neu erzeugen. Telefon-Screenshots bleiben im
Manifest bewusst leer, bis sie aus dem finalen Store-Build wahrheitsgetreu
aufgenommen und einzeln geprüft wurden.
Die acht deutschen Alternativtexte sind bereits als validierter Entwurf unter
`store/google-play/de-DE/screenshot_alt_texts.json` vorbereitet. Sie werden
erst einem Bild zugeordnet, wenn die jeweilige reale App-Szene bestanden und
aufgenommen ist.

Er verlangt Build `2026080903` oder höher, denselben vollständigen Commit,
Android- und iOS-Artefakthashes, Play-Internal-/TestFlight-Installation,
TalkBack/VoiceOver, alle Push-Zustände, Binär-/Netzwerkdatenschutz,
Crash-Releasezuordnung, Store-/Signing-Prüfung, Staging-Bereinigung,
Produktionsinvariante und technische sowie produktseitige Freigabe.

Die vorgesehenen öffentlichen URLs stehen bereits im Manifest, bleiben aber
bis zur fachlichen Freigabe auf `draft`. Nach einem Staging-Rollout lassen sich
Routing, Statusmarker und Mindestinhalt ohne Freigabe simulieren:

```text
node tool/verify_public_store_pages.mjs --allow-draft --origin https://staging.shareittoo.com
```

Im echten Uploadmodus akzeptiert derselbe Prüfer ausschließlich im Manifest
als `verified` markierte Seiten mit HTTP 200, den erwarteten maschinenlesbaren
Statusmarkern und den Pflichtinhalten. Support und Datenschutz liefern vor der
ausdrücklichen Freigabe bewusst HTTP 503; die funktionsfähige Kontolöschung
bleibt separat als `operational` erkennbar.

Der signierte Release-Preflight führt die Standardprüfung immer aus. Ein
tatsächlicher Store-Upload muss außerdem
`SIT_REQUIRE_STORE_SUBMISSION=1` setzen; dadurch wird der strenge Modus vor
dem Build für Store-Metadaten und Geräteabnahme erzwungen und anschließend auch
der reale Inhalt aller drei öffentlichen Pflichtseiten geprüft.

Zugangsdaten, API-Schlüssel, Review-Passwörter, Service Accounts und
Zahlungsschlüssel gehören niemals in diesen Ordner.
