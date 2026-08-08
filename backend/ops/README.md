# Release and production operations

## Immutable release identity

`build_release_image.sh` refuses a dirty worktree, resolves the full Git SHA,
uses the commit timestamp as deterministic build time and creates an API image
tagged with that exact SHA. The same version, commit and build timestamp are
stored as OCI image labels and are returned by `/version`, `/health`,
`/health/live` and `/health/ready`.

```sh
./ops/build_release_image.sh
```

`deploy_release.sh` deploys only an image whose revision label matches the
requested full commit. Staging and production use separate Compose files,
databases, volumes, secrets and upload storage. Production additionally
requires `CONFIRM_PRODUCTION_DEPLOY` to equal the exact commit and performs a
fresh backup before rollout.

```sh
./ops/deploy_release.sh staging FULL_40_CHARACTER_COMMIT

CONFIRM_PRODUCTION_DEPLOY=FULL_40_CHARACTER_COMMIT \
  ./ops/deploy_release.sh production FULL_40_CHARACTER_COMMIT
```

Each successful deployment writes a mode-`0600` JSON record under
`/docker/shareittoo/releases`. Rollback uses the same script with the previous
commit recorded in that release evidence; no floating `latest` image is used.

## Backups and restore proof

`backup.sh` writes a PostgreSQL custom-format dump, an upload archive and a
SHA-256 manifest to `/docker/shareittoo/backups/daily`. Files are mode `0600`
and retained for 14 days.

`verify_restore.sh` verifies the manifest and archive, starts a temporary
PostgreSQL container backed by a temporary volume, restores the dump, checks
that public tables exist, extracts the upload archive into a temporary
directory and removes every temporary resource. It never connects to or
modifies the production database. Successful checks are recorded under
`/docker/shareittoo/backups/restore-checks`.

## Monitoring

`healthcheck.sh` checks the public site and API, database/mail status, the
three ShareItToo containers, disk usage and backup freshness. Failures are
recorded by systemd and are visible with:

```sh
systemctl status shareittoo-health.service
journalctl -u shareittoo-health.service
```

After the first version-labelled rollout and successful isolated restore, set
`REQUIRE_RELEASE_IDENTITY=true` and `REQUIRE_RECENT_RESTORE_CHECK=true` in the
production `.env`. The health service will then also reject an unknown runtime
commit or a restore proof older than roughly eight days.

Install the included units in `/etc/systemd/system`, reload systemd, run the
backup, health and restore-check services once, then enable all three timers.

```sh
install -m 0644 ops/systemd/shareittoo-*.service /etc/systemd/system/
install -m 0644 ops/systemd/shareittoo-*.timer /etc/systemd/system/
systemctl daemon-reload
systemctl start shareittoo-backup.service
systemctl start shareittoo-restore-check.service
systemctl start shareittoo-health.service
systemctl enable --now shareittoo-backup.timer shareittoo-restore-check.timer shareittoo-health.timer
systemctl list-timers 'shareittoo-*'
```
