# planet-muluna-funit

Development-only FUnit test suite for **planet-muluna**. This companion mod is not
part of a normal Muluna install: `test-mods` is marked `export-ignore` in
`.gitattributes`, so it is excluded from release zips.

The suite has two parts:

1. **Data-stage fixtures** in `prototypes/fixtures/` inspect the final prototype set
   and record pass/fail results in the `planet-muluna-funit-results` mod-data
   prototype. They are controlled by the `planet-muluna-funit-enable-data-fixtures`
   startup setting (enabled by default); the runtime suite fails if it is disabled,
   so fixtures cannot be skipped silently.
2. **Runtime tests** in `tests/suites/` read those results and exercise live
   mechanics (surfaces, entities, storage, event handlers, remote interfaces).

`scenarios/__funit__muluna/control.lua` starts FUnit, converts the recorded data
fixtures into FUnit tests, and loads every runtime suite in `tests/manifest.lua`.

## Running

From the repository root:

```sh
./test-mods/planet-muluna-funit/run.sh
```

For a faster loop while editing data-stage fixtures, run only the data stage:

```sh
tools/ci/funit.sh --data-only
```

That uses the same scratch mod directory and `--dump-data`, then summarizes the
`planet-muluna-funit-results` mod-data bag. The full runner below is still required
before opening a pull request.

The runner is headless and self-contained:

- links the **current worktree** as `planet-muluna` (not the installed mod);
- links the dependency mods from `FACTORIO_MODS`;
- writes a scratch mod directory, config and logs under `TMP_ROOT`;
- disables server auto-pause so FUnit can advance ticks without a player;
- detects whether the Factorio binary supports `--disable-audio`, so it works
  with both the full client and the dedicated headless server build;
- stops Factorio after FUnit prints `====END====`;
- exits non-zero on any FUnit `FAILURE` or `ERROR`.

Useful environment variables:

| Variable | Default | Meaning |
| --- | --- | --- |
| `FACTORIO_BIN` | `/opt/factorio_space_age_21/bin/x64/factorio` | Factorio executable |
| `FACTORIO_MODS` | `/opt/factorio_space_age_21/mods` | Directory containing dependency mods |
| `TMP_ROOT` | `/tmp/opencode/muluna-funit` | Scratch mod directory, config and logs |
| `TIMEOUT` | `900` | Seconds to wait for `====END====` |
| `FACTORIO_PORT` | `34198` | Local server port used by the headless instance |
| `DATA_ONLY` | `0` | Run `--dump-data` instead of the scenario (used by `funit.sh --data-only`) |
| `MOD_LIST_ONLY` | `0` | Write the scratch `mod-list.json` and exit without launching Factorio (used by `funit-mod-list.sh`) |
| `FUNIT_MODSET` | `vanilla` | `vanilla`, `aai` (aai-industry), `bz` (Brevven's BZ mods with 2.1 releases), `no-quality` (quality disabled), `planets` (top planet mods), `k2so` (Krastorio 2 Spaced Out and its dependencies), or `muluna-start` (any-planet-start with `aps-planet = muluna`) |

The full log is `$TMP_ROOT/stdout.log`; on failure the runner prints the relevant
FUnit lines and the tail of the log. A data-only run also writes the prototype dump to
`$TMP_ROOT/write-data/script-output/data-raw-dump.json`.

CI runs the suite once against the latest stable Factorio release and once against the
latest experimental release. To reproduce either leg locally, point `FACTORIO_BIN` and
`FACTORIO_MODS` at a matching install; the mod must pass on both (see `AGENTS.md`,
"Factorio version support (stable and experimental)").

## Requirements

- Factorio 2.1 with Space Age.
- The `funit` mod.
- The same dependencies as the development environment: `PlanetsLib`,
  `muluna-graphics`, `flib`, `bplib`, `rigor-module`, `item-request-proxy-events`,
  `module-category-defaults`, and the space-exploration/alien-biomes graphics mods.
- `factorio` must be able to bind `FACTORIO_PORT` (or set another port).

The scenario is started with:

```text
--start-server-load-scenario planet-muluna-funit/__funit__muluna
```

## Layout

```text
info.json, settings.lua     companion-mod metadata and fixture setting
settings-updates.lua        test-profile setting overrides (scan cost vs. scan area)
data.lua                    creates the result bag, runs data-stage fixtures
data-updates.lua            data-updates fixtures
data-final-fixes.lua        data-final-fixes fixtures (after Muluna's own patches)
prototypes/fixtures/        prototype-level checks, grouped by feature
lib/results.lua             records fixture results in mod-data
scenarios/__funit__muluna/  FUnit scenario entry point
tests/helpers.lua           shared surface/entity/storage helpers
tests/manifest.lua          runtime suite load order
tests/suites/               runtime behavioral suites
run.sh                      headless runner
```

## Test-only production seams

Most mechanics are reachable through normal Factorio events or entity APIs. A few
paths are only reachable by a player (or are otherwise awkward in a headless
scenario), so `scripts/funit.lua` exposes a `muluna_funit` remote interface **only
when the `funit` mod is active**:

- `get_storage`, `get_constants`
- `get_telescope_data`, `update_telescope`, `get_telescope_signals`
- `get_telescope_probability`, `get_telescope_min_pollution`,
  `get_telescope_max_pollution`
- `get_state_integer`, `get_time_to_next_asteroid_check`
- `get_burner_roboport_data`, `short_update_roboport`
- `get_heat_assembling_machine_data`
- `get_compound_blueprint_tags`, `transform_compound_offset`
- `get_nav_scan_area`, `set_nav_beacon_enabled`, `build_nav_beacon`,
  `handle_invalid_nav_surface`
- `set_cheat_mode`
- `get_walking_controller_branch`
- `build_entity_gui`, `handle_gui_click`

The production modules export their internal helpers through `Muluna.funit` under
the same `script.active_mods["funit"]` guard. They are inert in normal play.

## Adding a test

1. **Prototype-only check:** add `results.check("suite", "id", function() ... end)`
   to a file in `prototypes/fixtures/` and list it in that stage's array in
   `prototypes/fixtures/manifest.lua`.
2. **Runtime behavior:** add a suite under `tests/suites/`, register it in
   `tests/manifest.lua`, and use `runner.test` / `runner.assert`.
3. Use `tests/helpers.lua` for Muluna/Nauvis surfaces and test areas. Clean up
   entities and storage mutations at the end of the test, and restore force
   technologies you change.
4. Run the runner and check both `SUCCESS` lines and the exit code.

Runtime tests must not assume a player exists. Use `surface.create_entity`,
`raise_built = true`, the `muluna_funit` interface, and `runner.after_n_ticks_do`
to wait for real tick handlers. Tests that need many ticks should derive the delay
from the relevant startup setting rather than hardcoding a value.

Use `helpers.set_tiles(surface, tiles, options)` for tile changes. It keeps the
five-argument `set_tiles` call in one place; pass `raise_event = true` to raise
`script_raised_set_tiles` after the tiles have been applied, and
`remove_colliding_entities = false` when a test intentionally builds beneath an
entity. Use `helpers.wait_until(runner, predicate, options)` for asynchronous
conditions instead of copying a deadline loop. It supports `timeout`, `interval`,
`message`, and optional `on_success` / `on_failure` cleanup callbacks.

## Coverage notes and limitations

The suite covers:

- Muluna surface creation, wind, cargo pods, lunar rocks, and storage.
- Lunar rock mining yields for big and huge rocks.
- The PlanetsLib entity removal floor rule configured for both lunar rock
  prototypes, including its gravel tile, crushed stone item, and Muluna waiting
  message. The deconstruction queue behaviour itself is covered by PlanetsLib's
  FUnit suite because the implementation lives there.
- Telescope registration, power, recipe assignment, pollution state, combinator
  signals, platform-count signal, and space-platform state mapping.
- Telescope blueprint recipe replacement across surfaces preserves the captured
  facing direction, including rotated placement and the supplied Muluna-to-Nauvis
  blueprint regression.
- Interstellar science-pack gating, partial progress, and cheat-mode behavior,
  including dynamic exploration pack discovery, alternative recipes, legacy
  fallback, Rigor Module recipe exclusion, pinned vanilla ordering, and
  one-pack-per-planet selection.
- Heat assembling machines (reactor link and fixed recipe).
- Burner/vacuum roboports (refueler link, propellant energy, statuses).
- Compound entity blueprints: subentity wires and control behavior, rotated
  placement, overlap restoration, deferred wire targets, malformed tags, and
  bplib's vector-style placement positions.
- Nav beacons on planets vs. space platforms, registration cleanup, sparse storage
  keys, quality scaling, and scan-size base selection (the test profile deliberately
  makes `platform-power-consumption` differ from `scan_area` so the energy/area
  mix-up is caught).
- Ground diggers on Muluna vs. Nauvis, recipe locking, technology completion, and
  cleanup.
- Walking-particle storage and controller-input precedence.
- Prototype fixtures for planets, science, telescopes, nav beacons, heat/roboports,
  ground diggers, cargo drops, public API helpers, and data-port fluidbox isolation
  (including modded fluid recipe categories and recipes added after Muluna's
  data-final-fixes).
- Muluna start (`any-planet-start` with `aps-planet = muluna`): APS choice and
  starting-planet selection, discovery-technology swap, aluminum automation science
  pack, aluminum electronics trigger, collapsed start technology tree, reduced
  wood-gasification productivity, Muluna orbit/connection, default item import
  locations, and map-gen control ordering.

Some paths remain player- or graphics-bound and are only partially covered:

- The full player-driven nav-beacon scan path (charting and energy deduction); the
  scan-size calculation itself is covered through `get_nav_scan_area`.
- Player-driven ground-digger construction (PlanetsLib's custom input).
- Walking-particle creation/cleanup for a real character.
- GUI-only code paths.
- The APS `on_player_created` spawn, teleport, crash-site, and Nauvis-clearing
  path. The headless scenario has no player, so the Muluna-start suite checks the
  selected planet through APS's public `get_planet` interface and the final
  prototype state instead.
- Cross-mod compatibility branches that require mods not enabled in the default
  test profile, including the `AAI Industry + Muluna start` branch.

For these, prefer a narrow test-only export over weakening an assertion or turning
the test into a prototype-existence check.
