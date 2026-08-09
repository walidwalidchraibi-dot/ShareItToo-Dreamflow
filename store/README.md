# ShareItToo Store-Metadaten

Dieser Ordner ist die maschinenlesbare Quelle für die vorbereiteten Google-
Play- und Apple-Metadaten. `store/submission.json` hält App-Identität,
Wahrheitsgrenzen, öffentliche URLs und die offenen Einreichungsgates fest.

Der aktuelle Zustand ist absichtlich `draft` und
`submissionAllowed: false`. Der Validator darf nur dann einen einreichbaren
Zustand akzeptieren, wenn alle Pflicht-URLs verifiziert, alle Gates geschlossen
und die Buildnummer mindestens `2026080903` ist.

Lokale Prüfung:

```text
dart run tool/validate_store_metadata.dart
```

Der Standardlauf prüft den ehrlichen Entwurfszustand. Eine spätere
Store-Automation muss zusätzlich mit `--require-submittable` prüfen und darf
bei einem offenen Gate keinen Upload starten.

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
dem Build erzwungen und anschließend auch der reale Inhalt aller drei
öffentlichen Pflichtseiten geprüft.

Zugangsdaten, API-Schlüssel, Review-Passwörter, Service Accounts und
Zahlungsschlüssel gehören niemals in diesen Ordner.
