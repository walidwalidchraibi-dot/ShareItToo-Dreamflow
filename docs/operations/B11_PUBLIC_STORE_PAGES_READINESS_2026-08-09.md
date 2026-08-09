# B11 – Öffentliche Store-Pflichtseiten und technische Freigabekette

Stand: 9. August 2026

## Ziel

Dieses Runbook beschreibt die technische Vorbereitung und die spätere
Freigabe der drei öffentlichen Store-Pflichtseiten:

- `https://shareittoo.com/support`
- `https://shareittoo.com/privacy`
- `https://shareittoo.com/account-deletion`

Die Implementierung ersetzt keine rechtliche oder geschäftliche Freigabe.
Support und Datenschutz bleiben bis zur ausdrücklich bestätigten
Anbieteridentität, Kontaktadresse und Endfassung absichtlich fail-closed.

## Technischer Vertrag

Der API-Dienst stellt folgende interne Routen bereit:

| Route | Entwurfszustand | Freigabezustand |
|---|---:|---:|
| `/v1/public/support` | HTTP 503, Marker `draft` | HTTP 200, Marker `approved` |
| `/v1/public/privacy` | HTTP 503, Marker `draft` | HTTP 200, Marker `approved` |
| `/v1/account-deletion` | HTTP 200, Marker `operational` | unverändert funktional |
| `/v1/public/compliance` | maschinenlesbarer Gesamtstatus | maschinenlesbarer Gesamtstatus |

Das kanonische Caddy-Setup ordnet die drei öffentlichen Root-Pfade diesen
API-Routen zu. Es wurde nur im Repository vorbereitet; ein Produktionsdeploy
ist dadurch nicht erfolgt.

Jede HTML-Seite enthält sowohl `data-sit-public-page` als auch
`data-sit-compliance-status`. Damit kann die Freigabe nicht allein durch einen
beliebigen HTTP-200 oder durch die Flutter-SPA vorgetäuscht werden.

## Geschützte Freigabekonfiguration

Standardmäßig gilt `PUBLIC_COMPLIANCE_APPROVED=false`. Für eine spätere
Freigabe müssen alle folgenden Werte bewusst gesetzt werden:

- `PUBLIC_SUPPORT_EMAIL`
- `PUBLIC_PRIVACY_EMAIL`
- `PUBLIC_LEGAL_PROVIDER_NAME`
- `PUBLIC_LEGAL_PROVIDER_ADDRESS`
- `PUBLIC_PRIVACY_EFFECTIVE_DATE` im Format `YYYY-MM-DD`

Erst danach darf `PUBLIC_COMPLIANCE_APPROVED=true` gesetzt werden. Fehlt dann
auch nur ein Pflichtwert oder ist eine E-Mail beziehungsweise das Datum
ungültig, startet der API-Dienst nicht. Diese Regel ist der technische
Schutz gegen eine versehentliche Veröffentlichung unvollständiger
Rechtsangaben.

Die Werte enthalten keine Secrets. Unbestätigte Angaben dürfen weder in Git
noch als scheinbar freigegebene Produktionswerte eingetragen werden.

## Store-Manifest und automatische Prüfung

`store/submission.json` enthält die endgültig vorgesehenen URLs bereits mit
Status `draft`. Dadurch sind Ziel und Routing eindeutig, die drei URL-Gates
bleiben aber offen.

`tool/validate_store_metadata.dart` akzeptiert:

- `verified` mit der exakt vorgesehenen HTTPS-URL;
- `draft` mit der exakt vorgesehenen HTTPS-URL als weiterhin offenes Gate;
- `open` nur ohne URL.

Andere Hosts oder Pfade werden abgelehnt. Der Standardlauf bleibt grün mit
drei offenen URLs und elf offenen B11-Gates. Der strenge Store-Modus bleibt
rot.

`tool/verify_public_store_pages.mjs` prüft zusätzlich reale HTTP-Antworten,
Statusmarker und Mindestinhalte. Für ein später ausgerolltes Staging:

```text
node tool/verify_public_store_pages.mjs --allow-draft --origin https://staging.shareittoo.com
```

Bei `SIT_REQUIRE_STORE_SUBMISSION=1` führt der signierte Release-Preflight
nach dem strengen Manifestcheck automatisch die reale Prüfung der drei
Produktionsseiten aus. Ohne `verified`, HTTP 200 und passende Inhalte erfolgt
kein Store-Build.

## Verbindliche Abnahme vor Freigabe

1. Anbieteridentität und Copyright fachlich bestätigen.
2. Supportadresse festlegen und reale Zustellung in beide Richtungen prüfen.
3. Datenschutzerklärung einschließlich Verantwortlichem, Rechtsgrundlagen,
   Empfängern, Drittlandtransfers, Fristen und Betroffenenrechten fachlich
   prüfen lassen.
4. Öffentliche Root-Routen zuerst auf isoliertem Staging ausrollen und mit dem
   Prüfer abnehmen.
5. Produktionsrollout separat freigeben, danach alle drei Seiten extern und
   ohne Sitzung prüfen.
6. Erst nach gespeicherter Evidenz die jeweiligen Manifeststatus auf
   `verified` setzen.
7. Den strengen Release-Preflight erneut ausführen. Alle weiteren B11-Gates
   bleiben unabhängig davon verbindlich.

## Aktueller Schutzstatus

- Implementierungscommit:
  `396d843a92c362c6ffc22ae25550a3eb6a9f0318`.
- GitHub-Actions-Lauf `31313881656` für
  `281d34e147b96667d6a8c12c45dbedd3e60cca56` vollständig grün: 56/56 Backendtests
  einschließlich PostgreSQL-16, Caddy/Compose, 167/167 Fluttertests,
  Analyzer-Basis 696, Web/Android und signierter commitgebundener
  Android-Kandidat.
- Veröffentlichtes und ausschließlich auf Staging ausgerolltes API-Image:
  `sha256:e19621042205e096698a9ec945d29793a5c963707f9589b3989c4e4ecc77070e`.
- Keine unbestätigte Rechtsidentität wurde übernommen.
- Keine Support- oder Datenschutzseite wurde als freigegeben markiert.
- Das isolierte Staging meldet exakt `281d34e147b9`; ein Produktionsdeploy
  wurde nicht ausgeführt.
- Produktion, Stripe-Live und Echtgeld bleiben geschützt.
- Die vier neuen API-Routen sind über das bestehende
  `https://staging.shareittoo.com/api/...`-Routing abgenommen. Die öffentlichen
  Root-Routen wurden nicht aktiviert und Caddy wurde nicht verändert.

## Verifizierter Staging-Rollout vom 9. August 2026

- Vorheriger Staging-Commit:
  `a37e681ce18c62981992e168965e68b80fc86ff2`.
- Neuer Staging-Commit:
  `281d34e147b96667d6a8c12c45dbedd3e60cca56`.
- Registry-Digest, lokale Image-ID und laufende Container-Image-ID stimmen
  überein:
  `sha256:e19621042205e096698a9ec945d29793a5c963707f9589b3989c4e4ecc77070e`.
- Die OCI-Revision meldet exakt den neuen Commit. Der Rollout erfolgte mit dem
  aktuellen gehärteten Harness aus dem zuvor freigegebenen Release; das
  historische Zielskript wurde nicht verwendet.
- Releasebeleg:
  `/docker/shareittoo/releases/staging-20260809T131142Z-281d34e147b9.json`.
- Intern und über `https://staging.shareittoo.com/api` bestanden `/version`,
  `/health/live`, `/health/ready` und `/health` mit HTTP 200.
- `/v1/public/compliance` meldet HTTP 200, `status=draft`,
  `submissionReady=false`, Support/Datenschutz `draft` und Kontolöschung
  `operational`.
- `/v1/public/support` und `/v1/public/privacy` melden erwartungsgemäß HTTP 503
  mit den richtigen Seiten- und `draft`-Markern.
- `/v1/account-deletion` meldet HTTP 200 mit den Markern
  `account-deletion` und `operational`.
- Staging-API und -PostgreSQL sind gesund. Mail, Push und Payment bleiben im
  Memory-Modus; `STRIPE_LIVEMODE=false`. Die neuen Logs enthalten keinen
  Fatal-, Uncaught-, Unhandled-, Start- oder sonstigen Fehler.
- Produktions-API-Image-ID und Caddy-Image blieben unverändert. Die
  Caddyfile-Prüfsumme war vor und nach dem Rollout identisch:
  `4aea918ebb07f3bd52c17342172b24bb3a7df3c17dc4be0afe749de940f5d44d`.
- Kein Caddy-Reload, keine DNS-/Mail-/Cron-Änderung, kein Produktionsdeploy und
  kein Echtgeld.
