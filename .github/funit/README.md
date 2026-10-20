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
  image's mod updater does not try to download it.
- `.github/workflows/funit.yml` writes a single scenario mod list instead of
  using `expand_dependencies.rb`. The paid DLC mods are supplied by the
  headless server image; all other dependencies are downloaded by the image's
  `docker-update-mods.sh` from the mod portal.
- FUnit itself is packaged from a shallow GitLab clone at a pinned commit, so
  the test framework does not depend on a mod-portal release.

## Scenario

Muluna's scenario lives inside the companion mod at
`test-mods/planet-muluna-funit/scenarios/__funit__muluna`. The build job copies
it to the top-level `scenarios/__funit__muluna` directory so the shared
entrypoint can load it by name. Its `control.lua` still requires the suites from
`__planet-muluna-funit__`.

## Credentials

Public mod downloads now require a Factorio account. The workflow reads:

- `FACTORIO_USERNAME` — repository variable or secret (falls back to
  `MeteorSwarm`, the mod-portal owner of Muluna).
- `FACTORIO_TOKEN` — repository secret used by the release workflow.

If the token is missing, the workflow fails before running Factorio with a
clear error. The paid Space Age mods are built into the headless server image
and are not downloaded from the portal.
