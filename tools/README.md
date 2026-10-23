# Development tools

These are development helpers for **planet-muluna**. They are not shipped with the
mod. Most of them exist because data-stage bugs depend on the exact final prototype
state, and the final state depends on which mods are installed and on Factorio's
dependency load order.

Use `python3 <script> --help` for the complete option list.

## Quick reference

| Task | Command |
| --- | --- |
| Dump the final prototypes for the installed mod pack | `python3 tools/factorio_probe.py dump` |
| Dump with an extra development mod appended last | `python3 tools/factorio_probe.py dump --add-mod test-mods/planet-muluna-funit` |
| Show data-stage load order | `python3 tools/factorio_probe.py load-order /tmp/opencode/factorio-probe/stdout.log` |
| List machines with data ports | `python3 tools/proto_query.py --dump DUMP machines --data-ports` |
| Check data-port fluid isolation | `python3 tools/proto_query.py --dump DUMP data-port-invariant` |
| Find fluid recipes without indexes | `python3 tools/proto_query.py --dump DUMP recipes --category crafting-with-fluid --missing-fluidbox-index` |
| Run only the FUnit data-stage fixtures | `tools/ci/funit.sh --data-only` |
| Syntax-check changed Lua files | `tools/ci/lua-check.sh` |

## `factorio_probe.py`

`factorio_probe.py dump` builds a scratch mod directory from a mod-list, links the
highest version of every enabled mod, writes a temporary `config.ini`, and runs:

```text
factorio --dump-data
```

`--dump-data` executes the complete `settings` / `data` / `data-updates` /
`data-final-fixes` pipeline and writes `data.raw` as JSON, then exits. It does **not**
generate or load a map, so it is much faster than starting a save.

```sh
python3 tools/factorio_probe.py dump
```

Default output:

```text
/tmp/opencode/factorio-probe/mods/
/tmp/opencode/factorio-probe/stdout.log
/tmp/opencode/factorio-probe/write-data/script-output/data-raw-dump.json
```

Useful options:

- `--mods-dir DIR` — source mod directory (default `$FACTORIO_MODS`, then
  `/opt/factorio_space_age_21/mods`).
- `--mod-list FILE` — mod-list to follow (default `<mods-dir>/mod-list.json`).
- `--add-mod PATH` — append a mod directory or zip to the generated mod list. It is
  appended last, so its `data-final-fixes` runs after the normal mods. Plain required
  dependencies of an added mod are pulled in from the source mod directory when they are
  not already enabled (for example `funit` for the FUnit companion mod). Repeatable.
- `--work-dir DIR` — scratch directory (default `$FACTORIO_PROBE_DIR`, then
  `/tmp/opencode/factorio-probe`).
- `--factorio-bin PATH` — Factorio executable.
- `--timeout SECONDS` — data-stage timeout.
- `--json` — print a machine-readable result.

Built-in mods (`base`, `elevated-rails`, `quality`, `recycler`, `space-age`) are
recognised even though they are not in the mods directory. Version selection uses
Factorio's numeric version ordering and ignores lookalike names such as
`skewer_planet_vesta_assets_2_1.0.7.zip` when resolving
`skewer_planet_vesta_assets`.

`factorio_probe.py load-order` extracts data-stage load order from a log:

```sh
python3 tools/factorio_probe.py load-order /tmp/opencode/factorio-probe/stdout.log
python3 tools/factorio_probe.py load-order LOG --stage data-final-fixes
python3 tools/factorio_probe.py load-order LOG --mod xy-k2so
```

Use it when a prototype patch appears to run at the wrong time. In particular,
`data-final-fixes` is **not** globally last: any mod that depends on Muluna can run
its `data-final-fixes` afterwards.

## `proto_query.py`

`proto_query.py` reads the JSON from `--dump-data`. Point it at the dump explicitly
or set `FACTORIO_DUMP`:

```sh
python3 tools/proto_query.py --dump /path/to/data-raw-dump.json ...
```

### `machines`

```sh
python3 tools/proto_query.py --dump DUMP machines --data-ports --advanced --categories
```

- `--data-ports` — only machines with a `connection_category = "data"` fluidbox.
- `--advanced` — only machines with `crafting-with-fluid` or
  `crafting-with-fluid-and-data`.
- `--category CATEGORY` — require a crafting category (repeatable).
- `--categories` — print the machine's crafting categories.
- `--json` — print JSON.

Data-port positions are printed as **input/output ordinals**, because recipe
`fluidbox_index` is 1-based and counts input and output fluidboxes separately.

### `recipes`

```sh
python3 tools/proto_query.py --dump DUMP recipes --category crafting-with-fluid \
  --missing-fluidbox-index --categories
```

Filters:

- `--category CATEGORY` — require a category (repeatable).
- `--fluid NAME` — require a fluid ingredient or product.
- `--missing-fluidbox-index` — only fluid entries with no `fluidbox_index`.
- `--name TEXT` — substring match on the recipe name.
- `--craftable-in MACHINE` — only recipes whose categories are all in that machine.
- `--categories` — print recipe categories.
- `--json` — print JSON.

### `data-port-invariant`

This is the reusable version of the data-port regression check:

```sh
python3 tools/proto_query.py --dump DUMP data-port-invariant
```

It reports fluids that could be automatically assigned to a data port on an
advanced assembling machine without explicitly naming that port. A fluid is allowed
to use the port when the recipe sets `fluidbox_index` to the port's index; that
keeps the port open to future data fluids instead of hard-coding one.

Options:

- `--machine-category CATEGORY` — machine category to include (repeatable; default:
  `crafting-with-fluid` and `crafting-with-fluid-and-data`).
- `--json` — print JSON.

Exit status is `1` when violations are found, so it can be used in scripts.

### `funit-results`

Summarize the `planet-muluna-funit-results` mod-data bag from a data-only run:

```sh
python3 tools/proto_query.py --dump DUMP funit-results
python3 tools/proto_query.py --dump DUMP funit-results --json --log LOG
```

This is how `tools/ci/funit.sh --data-only` reports pass/fail.

## `tools/ci/funit.sh --data-only`

Run only the test mod's data-stage fixtures:

```sh
tools/ci/funit.sh --data-only
tools/ci/funit.sh --data-only --json
```

This sets `DATA_ONLY=1` on `test-mods/planet-muluna-funit/run.sh`, which uses the
same scratch mod directory as the full runner but runs `--dump-data` instead of
starting the FUnit scenario. It then reads the result bag with `proto_query.py`.
It is the preferred loop while iterating on `prototypes/fixtures/`; use the full
suite before opening a pull request.

`--data-only` cannot be combined with `--suite`, `--test`, `--baseline`, or
`--no-run`.

## `tools/ci/lua-check.sh`

```sh
tools/ci/lua-check.sh
tools/ci/lua-check.sh --all
tools/ci/lua-check.sh prototypes/final-fixes/data-cells.lua
LUAC=luac5.2 tools/ci/lua-check.sh --no-diff-check
```

With no arguments it checks every changed/untracked `*.lua` file and also runs
`git diff --check`. `--all` checks every tracked and untracked Lua file. It uses
`luac5.2` when available, otherwise `luac`; set `LUAC` to override.

## Typical data-stage bug workflow

1. Reproduce the final prototype state:
   ```sh
   python3 tools/factorio_probe.py dump --add-mod test-mods/planet-muluna-funit
   ```
2. Query the symptom:
   ```sh
   python3 tools/proto_query.py --dump /tmp/opencode/factorio-probe/write-data/script-output/data-raw-dump.json \
     machines --data-ports --advanced --categories
   ```
3. Check load order if another mod appears to have overwritten the change:
   ```sh
   python3 tools/factorio_probe.py load-order /tmp/opencode/factorio-probe/stdout.log \
     --stage data-final-fixes
   ```
4. Add or adjust a fixture in `test-mods/planet-muluna-funit/prototypes/fixtures/`
   and iterate with:
   ```sh
   tools/ci/funit.sh --data-only
   ```
5. Finish with the full suite and static checks:
   ```sh
   tools/ci/funit.sh --baseline
   tools/ci/lua-check.sh
   ```

## Engine facts worth remembering

- **`data-final-fixes` is not globally last.** Dependency order still applies.
- **Recipe `fluidbox_index` is 1-based and separate for input and output fluidboxes.**
- **`fluidbox_index = 0` behaves like unset.** Treat `nil` and `0` the same.
- **`optional_fluidbox_indexes` only matters when `fluidbox_index` is set.**
- **Fluidbox filters are ignored on assembling machines.** Do not use
  `fluid_box.filter` to keep fluids out of a data port on an assembling machine.
- **`connection_category` can be a string or a list** containing `"data"`; handle both.
- **Recipe categories are alternatives, not requirements.** A machine can craft a recipe
  when it has any one of the recipe's categories. `electric-engine-unit` has
  `crafting-with-fluid`, `mechanics`, and `maraxsis-hydro-plant`; AM3 still crafts it
  through `crafting-with-fluid`.
- **Behaviour beats category names.** Match recipes by "can this be crafted in a
  machine with a data port", not only by the literal `crafting-with-fluid` category.
