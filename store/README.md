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

Der signierte Release-Preflight führt die Standardprüfung immer aus. Ein
tatsächlicher Store-Upload muss außerdem
`SIT_REQUIRE_STORE_SUBMISSION=1` setzen; dadurch wird der strenge Modus vor
dem Build erzwungen.

Zugangsdaten, API-Schlüssel, Review-Passwörter, Service Accounts und
Zahlungsschlüssel gehören niemals in diesen Ordner.
