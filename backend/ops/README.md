# Production operations

`backup.sh` writes a PostgreSQL custom-format dump, an upload archive and a
SHA-256 manifest to `/docker/shareittoo/backups/daily`. Files are mode `0600`
and retained for 14 days.

`healthcheck.sh` checks the public site and API, database/mail status, the
three ShareItToo containers, disk usage and backup freshness. Failures are
recorded by systemd and are visible with:

```sh
systemctl status shareittoo-health.service
journalctl -u shareittoo-health.service
```

Install the included units in `/etc/systemd/system`, reload systemd, run both
services once, then enable both timers.
