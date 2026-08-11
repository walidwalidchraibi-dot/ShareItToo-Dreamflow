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

`store/platform-account-readiness.json` hält zusätzlich den geheimnisfreien
Ist-Stand der drei externen Kontovoraussetzungen fest. Aktuell verlangt Google
Play noch die Erstellung eines Entwicklerkontos einschließlich bewusster Wahl
zwischen Organisation und persönlichem Konto; für Apple fehlt die
Entwicklermitgliedschaft, und die Firebase-Nutzungsbedingungen sind noch nicht
als vom Eigentümer bestätigt belegt. Der Store-Prüfer koppelt diese drei
Zustände fest an `googlePlayAccountAndFee`, `appleAccountXcodeAndSigning` und
`firebaseTermsAcceptedByOwner`. Ein Gate kann daher nicht durch bloßes Ändern
von `open` auf `closed` umgangen werden. E-Mail-Adressen, Konto-IDs,
Zugangsdaten, Käufe und Vertragsannahmen gehören nicht in diesen Nachweis.

Lokale Prüfung:

```text
dart run tool/validate_store_metadata.dart
node tool/validate_device_evidence.mjs
```

Der Standardlauf prüft den ehrlichen Entwurfszustand. Eine spätere
Store-Automation muss zusätzlich mit `--require-submittable` prüfen und darf
bei einem offenen Gate keinen Upload starten.

`store/privacy-disclosures.json` ist die maschinenlesbare, quell- und
binärgebundene Grundlage für Google Play Data Safety und Apple App Privacy.
Sie inventarisiert aktuell 17 Datentypen und acht Dienste bzw. technische
Empfänger. Der signierte Android-Kandidat enthält neben Firebase Cloud
Messaging und Crashlytics auch die aktivierte Google-Maps-Platform-Anbindung.
Präziser Standort bleibt deshalb konservativ deklariert; die
Anwendungs-/API-Beschränkung des eingebetteten Maps-Client-Schlüssels ist ein
offener Console-Nachweis. KI-Helfer, Analytics, Werbung und Stripe sind im
Kandidaten deaktiviert; der Zahlungsmodus bleibt `memory`.

Der Standardlauf akzeptiert nur den ehrlichen Entwurf mit offenen
Eigentümerentscheidungen, nicht abgesendeten Store-Formularen,
`binaryPrivacyAndNetwork=testing` und
`finalBinaryPrivacyScan=open`:

```text
node tool/validate_privacy_disclosures.mjs
```

Der Store-Modus verlangt zusätzlich `--require-approved`. Er bleibt gesperrt,
bis die Data-Safety-/App-Privacy-Formulare, Empfängerklassifizierung,
Aufbewahrung/Löschung, Maps-Schlüsselbeschränkung und der finale Stripe-
Datenfluss separat belegt sind, der plattformübergreifende Binär-/Netztest
bestanden ist und der Store-Gate geschlossen wurde. Die technische Matrix ist
keine Rechtsfreigabe.

`store/legal-readiness.json` bindet den Rechts-/Nutzerinhalts-Gate zusätzlich
an die vier derzeitigen App-Texte und an die technische Registrierungskette.
Die rechtliche Anbieteridentität und der Copyright-Inhaber sind eigene,
fail-closed Freigaben: Ihr jeweiliger Store-Gate muss denselben Status haben
und darf erst mit einem bereinigten JSON-Nachweis unter `docs/evidence/b11/`
geschlossen werden. Im Entwurf bleiben alle Rechtsfreigaben offen und ohne
Nachweisreferenz.
Mindestalter, AGB und Datenschutz müssen separat und ausdrücklich bestätigt
werden; App, Auth-Service und Backend dürfen diese Zustimmungen nicht
vorausfüllen. Der Standardlauf akzeptiert den nachweislich unfreigegebenen
Entwurf:

```text
node tool/validate_legal_readiness.mjs
```

Der signierte Release-Preflight führt die Entwurfsprüfung immer aus und ruft
bei `SIT_REQUIRE_STORE_SUBMISSION=1` zusätzlich `--require-approved` auf.
Dieser Store-Modus bleibt geschlossen, bis alle vier Texte inhaltsgleich freigegeben,
unter den kanonischen öffentlichen HTTPS-URLs erreichbar, alle erforderlichen
Freigaben belegt und die verbundenen Store-Gates geschlossen sind. Der
aktuelle Rechtsstatus bleibt ausdrücklich `draft`; der technische
Nachweis ist keine Rechtsberatung oder Rechtsfreigabe.

`store/review-access.json` hält den Zugang für die zwei synthetischen
Store-Review-Rollen getrennt vom Geräte- und Rechtsstatus fest. Zugangsdaten
bleiben ausschließlich in einem privaten, nur für den Eigentümer lesbaren
Tresor außerhalb des Repositories und später in den geschützten Store-Feldern.
Die technische Diagnose meldet beide Rollen per Passwort an und liest nur
Konto-, Inserat-, Buchungs- und Chatstatus; sie gibt weder E-Mail-Adressen,
Passwörter, Tokens noch interne Objektkennungen aus:

```text
node tool/diagnose_store_review_accounts.mjs
node tool/validate_store_review_access.mjs
```

Der aktuelle Zustand ist weiterhin ehrlich `testing`, aber der technische
Zugang ist bestanden: Zwei neue synthetische Staging-Konten sind über den
realen SMTP-Weg bestätigt, beide Passwort-Logins funktionieren, und beide
Rollen sehen dasselbe aktive Inserat, dieselbe akzeptierte Buchung und den
gemeinsamen Chat. Melden/Blockieren, ein vollständiger privater Datenexport
und die Kontolöschung wurden zusätzlich mit kontrollierten synthetischen
Staging-Daten nachgewiesen. Für den Löschtest wurde ausschließlich ein älteres
entbehrliches Mieterkonto geschlossen; die aktiven Review-Konten blieben
unverändert. Damit stehen acht von zehn Review-Szenarien auf `passed`. Der
strenge Release-Gate bleibt wegen der noch offenen Geräte- und geschützten
Store-Feld-Prüfungen geschlossen:

```text
node tool/validate_store_review_access.mjs --require-ready
```

Erst nach frischer Installation, Zweitnetz und Eintrag beider Konten in die
geschützten Store-Felder dürfen `readyForStore`, der Store-Gate
`reviewAccounts` und der strenge Validator gemeinsam auf bestanden wechseln.

Der Gerätevalidator bleibt derzeit bewusst bei `state=testing`,
`goNoGo=hold`, `matrix=0/4` und `releaseChecks=3/7`. Kandidatenidentität und
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
