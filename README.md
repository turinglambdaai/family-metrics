# family-metrics

Daily snapshots of release download counts across the turinglambdaai
product family, plus a zero-dependency dashboard for reading them.

- `collect.sh` walks every product repo's releases API once a day
  (GitHub Actions cron), aggregates installer-only download counts
  (sha256/sig/manifest sidecars excluded), and appends a dated file under
  `data/`. Assets whose name carries no version (the stable per-platform
  aliases that get clobbered on every release) are flagged `alias` so the
  dashboard can separate cumulative update-channel traffic from
  per-release installs. A repo whose API call fails mid-run is skipped
  and listed under `skipped` in that day's snapshot instead of aborting
  the whole run — repo renames are followed transparently.
- `data/` grows one file per UTC day; `data/index.json` lists them.
- The dashboard renders straight from those files — no build step, no
  external service.

GitHub only exposes cumulative counts (and a 14-day traffic window), so
the time series only exists from the day snapshotting started: 2026-10-15.
