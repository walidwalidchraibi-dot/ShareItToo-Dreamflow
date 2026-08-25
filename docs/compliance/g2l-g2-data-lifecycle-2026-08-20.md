# G2L - Legal/Privacy-Delta und Datenlebenszyklus

Stand: 20.08.2026

Branch: `codex/master-workflow-20260808`

Implementierungscommit:
`b84787e630a96de632eee90e8c7e016a078fcaef`

GitHub Actions:
[`32383235202`](https://github.com/walidwalidchraibi-dot/ShareItToo-Dreamflow/actions/runs/32383235202)
ist fuer genau diesen Commit GREEN.

## Status und Ergebnis

**G2L ist technisch GREEN.** Der bestehende lokale Zustand unter `Gemerkt`
ist jetzt im Nutzerexport enthalten und wird nach bestaetigter Kontoloeschung
auf dem ausfuehrenden Geraet gezielt entfernt. Die aktuelle Privacy-Oberflaeche
erklaert `Gemerkt` als unverbindlich und grenzt sie von einer Reservierung sowie
einem persistenten Miet- oder Projektkorb ab.

Die spaeteren Datenklassen `Mietkorb` und `Projektkorb` sind in einem
maschinenlesbaren Lebenszyklusvertrag erfasst, bleiben aber bis G2B explizit
`inactive-not-collected`. Eine Aktivierung ohne Export-, Loeschungs- und
Retention-Abdeckung scheitert fail-closed.

## Verbindliche Quellen und Grenzen

- Drive `01_CONTROL_V2.3_AUTONOMOUS.md` und
  `02_CODEX_WORK_PACKAGES_SIT_V2.3.md`.
- Drive `02_SIT_GROWTH_PRODUCT_PROJEKTKORB_UND_PLANER.pdf`, Version 2.0 vom
  18.08.2026.
- V5.2 Core Specification und Rechtsmappe sowie die vorhandenen Privacy-,
  Retention-, Legal- und Store-Manifeste.
- Historische V5.1-Rechts-, Consent-, Quote- und Evidence-Snapshots blieben
  bytegleich.
- Keine Produktions-, VPS/OpenClaw-/Maximus-, SSH-, DNS-, Cloud-, Payment-,
  Store-, Provider-, Account- oder oeffentliche Aktion.

## Geaenderte Laufzeit und Artefakte

- `DataService` exportiert die vier realen lokalen Speicherbereiche
  `saved_item_ids`, den atomaren kanonischen Stand `wishlist_state_v2` sowie
  die kompatiblen Spiegel `wishlists_meta_v1` und `wishlist_assign_v1` in
  einem separaten `localDevice.savedItems`-Abschnitt.
- Fehlerhaftes lokales JSON wird nicht still ausgelassen; der Export bricht
  sichtbar ab, statt einen unvollstaendigen Datensatz als vollstaendig
  auszugeben.
- Beide bestaetigten Kontoloeschungspfade entfernen exakt diese vier lokalen
  Bereiche. Unabhaengige Geraeteeinstellungen bleiben erhalten.
- Die Privacy-Info nennt lokale Merklisten in Zweck, Export und Loeschung.
- Die aktuelle Privacy-Oberflaeche nennt die lokale Aufbewahrungsgrenze und
  fordert fuer einen spaeteren persistenten Korb eine eigene Lifecycle-
  Abdeckung vor Aktivierung.
- `store/g2-data-lifecycle.json` bindet aktuellen und geplanten Zustand. Der
  neue Validator prueft Manifest, Laufzeitquellen, Privacy-Texte und beide
  Loeschungspfade und blockiert vorzeitige Cart-Persistenz.
- Privacy-, Retention- und Legal-Source-Hashes wurden fuer jede tatsaechlich
  geaenderte aktuelle Quelle aktualisiert. Freigabestatus bleiben unveraendert
  draft/open.

## Tests und Verifikation

- Fuenf positive und negative G2-Lifecycle-Validator-Tests PASS.
- G2-Lifecycle-, Privacy-, Retention- und Legal-Validatoren PASS; strikte
  Freigaben bleiben erwartungsgemaess blockiert.
- Fokussierte Flutter-Tests fuer Export, selektive Loeschung und bestehende
  G2A-Persistenz: drei PASS.
- Vollstaendige lokale technische Regression: 303 Flutter-Tests PASS, ein
  dokumentierter Skip, Google-only-Profiltest PASS, Analyzer auf der
  akzeptierten 223er-Baseline, Web-Debug-Build und Android-Debug-APK PASS.
- Der lokale Lauf nutzte `CI=true` nur fuer den erlaubten metadata-only
  Handoff. Daraus wird kein Store-, Signier- oder Device-Pass abgeleitet.
- Exakte GitHub-CI: Backend- und Flutter-Regression PASS. Der signierte
  Android-Releasekandidat und `publish-api-image` wurden uebersprungen.
- `git diff --check`, exakte Source-Hashes und gestagter Umfang waren sauber.

## Datenmigration, Risiken und Rollback

- Keine Datenbankmigration, kein neuer Serverdatensatz und keine Umschreibung
  vorhandener lokaler Wishlist-Daten.
- Ein lokaler Export beschreibt bewusst nur das aktuelle Geraet. Lokal auf
  anderen Geraeten verbliebene App-Daten koennen ohne dort ausgefuehrte
  Loeschung oder spaetere kontogebundene Migration nicht ferngeloescht werden.
- Privacy, Retention, Legal, Store und finaler Binary-Scan bleiben
  draft/open/fail-closed. Es wurde keine Rechtsgrundlage, Frist oder Freigabe
  erfunden.
- Ein normaler Revert des Implementierungscommits stellt den vorherigen Code
  wieder her. Weil G2L weder bestehende Daten umschreibt noch ein Schema
  migriert, ist kein Daten-Rollback erforderlich.

## Naechster Schritt

Das aktive Folgepaket ist **G2B - Persistenter Mietkorb**. Es darf
kontogebundene Cart-/Projektcontainer, lokale Gastvorbereitung mit
Login-Rueckkehr sowie serverseitige Verfuegbarkeits- und Quote-Neupruefung
implementieren. Der Korb bleibt unverbindlich und ist nie eine Reservierung;
direkte Einzelmiete und alle bestehenden V5.2-Buchungs-, Preis-, Vertrags- und
Payment-Gates bleiben erhalten.
