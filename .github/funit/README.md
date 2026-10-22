# FUnit CI helpers

These scripts are vendored from the [FUnit](https://gitlab.com/jfletcher94/funit)
GitHub Actions template, via
[PlanetsLib](https://github.com/nicholasgower/PlanetsLib)'s
`.github/funit/` helpers on the `funit-test-suite` branch. They are licensed
under `LGPL-3.0-or-later WITH FUnit-CI-Exception`; the exception permits
project-specific CI adaptations to be copied and modified without applying
copyleft to this repository.

Sources (FUnit commit `b69c2f277a467726e3a8c555d48df5b647ec5a64`):

- `entrypoint.sh` — `entrypoint.sh`
- `prepare_test_environment.sh` — `scripts/prepare_test_environment.sh`
- `parse_funit_json.rb` — `scripts/parse_funit_json.rb`

## Muluna-specific changes

- `prepare_test_environment.sh` uses `GITHUB_WORKSPACE` and reads the test
  config from `artifacts/planet-muluna/test`. Muluna is a single-mod repository
  at the root; its fixtures live in `test-mods/planet-muluna-funit`, which the
  release `.gitattributes` excludes from the mod archive.
- `entrypoint.sh` renames `funit-report-muluna.json` to
  `funit-report-<scenario>.json` after the run. It also treats `recycler` as a
  built-in mod alongside `space-age`, `quality` and `elevated-rails`, so the
  image's mod updater does not try to download it. If every enabled mod is
  present in `/mods_cache`, the entrypoint skips the portal update entirely.
- `.github/funit/download_mods.py` reads `info.json` and the companion test
  mod's `info.json` and downloads every required dependency plus every
  recommended (`+`) dependency for the target Factorio version. Optional (`?`
  / `(?)`) and incompatible (`!`) entries are skipped. It writes the scenario's
  `mod-list.json` from the downloaded set, so the list cannot drift from the
  mod's declared dependencies. `FACTORIO_VERSION=latest` is resolved to the
  version installed in the image (falling back to factorio.com's experimental
  release), so it stays in sync with the `factoriotools/factorio:latest` tag.
- The paid DLC mods are supplied by the headless server image; the main mod,
  test mod and FUnit are packaged by the build job.
- FUnit itself is packaged from a shallow GitLab clone at a pinned commit, so
  the test framework does not depend on a mod-portal release.

## Scenario

Muluna's scenario lives inside the companion mod at
`test-mods/planet-muluna-funit/scenarios/__funit__muluna`. The build job copies
it to the top-level `scenarios/__funit__muluna` directory so the shared
entrypoint can load it by name. Its `control.lua` still requires the suites from
`__planet-muluna-funit__`.

## Credentials

Downloading public mods requires a Factorio account that owns the game. The
workflow reads:

- `FACTORIO_USERNAME` — repository variable or secret (falls back to
  `MeteorSwarm`, the mod-portal owner of Muluna).
- `FACTORIO_PLAYER_TOKEN` — repository secret containing the `service-token`
  from the Factorio client's `player-data.json`. This is a *player* token, not
  the ModPortal upload API key used by the release workflow.

`FACTORIO_TOKEN` is still used as a fallback in case a repository stores a
player token under that name, but the existing upload key will get HTTP 403
from the download endpoint. If the token is missing or invalid, the workflow
fails before running Factorio with an actionable error. The paid Space Age mods
are built into the headless server image and are not downloaded from the
portal.
