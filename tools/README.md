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
| Show exploration science pack discovery | `python3 tools/proto_query.py --dump DUMP exploration-science --rejected --legacy` |
| Compare discovery across mod sets | `tools/ci/science-discovery-report.sh --modsets vanilla,planets` |
| Run only the FUnit data-stage fixtures | `tools/ci/funit.sh --data-only` |
| Run every FUnit modset | `tools/ci/funit-matrix.sh` |
| Print a modset's `mod-list.json` | `tools/ci/funit-mod-list.sh --modset bz` |
| Download a modset's extra mods | `tools/ci/funit-download-modset.sh --modset bz` |
| Check FUnit modset definitions stay in sync | `tools/ci/funit-modsets-check.sh` |
| Lint fixture load-stage globals | `tools/ci/funit-fixture-lint.sh` |
| Prove the data fixtures can fail | `tools/ci/funit-mutation-check.sh` |
| Syntax-check changed Lua files | `tools/ci/lua-check.sh` |
| Check FUnit seam wiring and docs | `tools/ci/funit-seams-check.sh` |
| Check the release export boundary | `tools/ci/export-check.sh` |
| Review a pull request in a temporary worktree | `tools/ci/pr-worktree.sh 123` |
| Generate commit-pinned PR diff links | `python3 tools/pr_diff_links.py <commit>` |

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

### `exploration-science`

Show the final exploration science pack groups written by
`muluna-interstellar-science-pack-conditions`:

```sh
python3 tools/proto_query.py --dump DUMP exploration-science --rejected --legacy
python3 tools/proto_query.py --dump DUMP exploration-science --json
```

The pack list is printed in shipping order, including each pack's item, planet,
representative technology, contributing technologies, and any `baseline`, `legacy`
or `forced` flags.

Options:

- `--rejected` — include lab science pack items that were rejected, with the reason
  and canonical recipe when available.
- `--legacy` — include the technologies that were used from
  `LEGACY_PROGRESS_TECHNOLOGIES`, the full frozen legacy list, and names that are
  missing from the loaded prototype data.
- `--require-pack NAME` — exit `1` when NAME is not a pack item or synthetic key
  (repeatable). Useful as a negative self-test.
- `--json` — print JSON.

Exit status is `1` when the conditions mod-data is missing or a required pack is
absent.

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

## `tools/ci/export-check.sh`

```sh
tools/ci/export-check.sh
tools/ci/export-check.sh --ref v2.7.45
tools/ci/export-check.sh --json
tools/ci/export-check.sh --require-path .opencode/agents/self-learn.md
```

The checker reads the tracked/untracked file list and `git check-attr` to verify
that development-only paths are marked `export-ignore` and that runtime files and
`locale/en/` are not. It catches non-recursive directory patterns such as
`.opencode export-ignore`; use `.opencode/** export-ignore` instead.

`--require-path PATH` asserts that `PATH` is *not* export-ignored. Passing a
development path is therefore expected to exit `1`; it is the negative self-test
that proves the detector is working.

## `tools/ci/pr-worktree.sh`

```sh
tools/ci/pr-worktree.sh 123
tools/ci/pr-worktree.sh 123 --base origin/main --dir /tmp/opencode/muluna-pr-123
```

The helper fetches `refs/pull/<number>/head`, creates a temporary worktree
(default `/tmp/opencode/muluna-pr-<number>`), and prints the PR head, commit
list, diff stat, and changed files. It only checks out the PR; it never runs PR
code. Remove the worktree with the printed `git worktree remove` command.

## `tools/pr_diff_links.py`

```sh
python3 tools/pr_diff_links.py HEAD
python3 tools/pr_diff_links.py <commit> --format json
python3 tools/pr_diff_links.py HEAD --base origin/main
```

Prints commit-pinned GitHub file-diff anchors (`#diff-<sha256-of-path>`) for a
commit. Use it when editing an existing bugfix PR checklist, or when a body was
not generated by `tools/ci/pr-body.sh`. It is read-only; it never checks out
code or contacts the network.

## `tools/ci/funit-seams-check.sh`

```sh
tools/ci/funit-seams-check.sh
tools/ci/funit-seams-check.sh --json
tools/ci/funit-seams-check.sh --require-missing get_storage
```

The checker keeps the FUnit test seams in sync without starting Factorio. It
compares:

- `stage().NAME` calls in `scripts/funit.lua` with `Muluna.funit.NAME` exports in
  `scripts/*.lua`;
- `helpers.funit_call("NAME")` and `remote.call("muluna_funit", "NAME")` calls in
  the FUnit suite with the remote keys in `scripts/funit.lua`;
- every remote key with the `## Test-only production seams` list in
  `test-mods/planet-muluna-funit/README.md`.

It is read-only and exits `1` on drift.

`--require-missing NAME` adds `NAME` to the required README list. Pass a name that
is intentionally absent; the checker must report it missing and exit `1`. That is
the negative self-test for the README detector.

## FUnit matrix and fixture helpers

These helpers keep the FUnit mod-set matrix and fixtures consistent without
starting Factorio unless noted.

### `tools/ci/funit-modsets-check.sh`

```sh
tools/ci/funit-modsets-check.sh
tools/ci/funit-modsets-check.sh --json
tools/ci/funit-modsets-check.sh --require-missing does-not-exist
```

Compares the `MODSETS` table in `.github/funit/download_mods.py`, the
`FUNIT_MODSET` names and link/mod-list blocks in
`test-mods/planet-muluna-funit/run.sh`, and the `modset` values in both workflow
matrices. It also requires each matrix to have two legs per modset. Read-only;
exits `1` on drift.

`--require-missing NAME` adds `NAME` to the expected set and must fail, proving
the detector works.

### `tools/ci/funit-matrix.sh`

```sh
tools/ci/funit-matrix.sh
tools/ci/funit-matrix.sh --modsets vanilla,bz --data-only
tools/ci/funit-matrix.sh --json
```

Runs `tools/ci/funit.sh` sequentially for each modset and prints one table or one
JSON object. `--fail-fast` stops at the first failure; the default continues and
reports every leg.

### `tools/ci/science-discovery-report.sh`

```sh
tools/ci/science-discovery-report.sh
tools/ci/science-discovery-report.sh --modsets vanilla,planets --require-baseline
tools/ci/science-discovery-report.sh --modsets vanilla --json
```

Runs the data-stage fixtures once per modset, each with its own `TMP_ROOT`, then
queries each dump with `proto_query.py exploration-science`. The report lists pack
counts, the pack selected per planet, legacy-only keys, legacy names missing from the
loaded data, and rejected lab science pack items.

- `--modsets LIST` — comma-separated mod sets, default `vanilla,planets`.
- `--work-dir DIR` — scratch directory for runs, dumps, logs and query results.
- `--require-baseline` — exit `1` if any vanilla planetary pack is missing.
- `--json` — print one JSON object instead of the table.

This helper is local-only. It never reads tokens and is not part of a GitHub
workflow.

### `tools/ci/funit-mod-list.sh`

```sh
tools/ci/funit-mod-list.sh --modset bz
tools/ci/funit-mod-list.sh --modset muluna-start --output /tmp/mod-list.json
tools/ci/funit-mod-list.sh --modset no-quality --output /tmp/mod-list.json
```

Prints the exact `mod-list.json` the runner would write, without launching
Factorio. This is useful for checking that a mod is explicitly disabled (for
example `quality` in the no-quality set) and for feeding probe tools.

### `tools/ci/funit-download-modset.sh`

```sh
tools/ci/funit-download-modset.sh --modset bz --dry-run
tools/ci/funit-download-modset.sh --modset planets
```

Downloads only the named modset's extra mods into `FACTORIO_MODS` (or
`--mods-dir`). It reuses `download_mods.py` with empty dependency files so the
base Muluna dependency set is not re-downloaded. The player token is read from
`FACTORIO_PLAYER_TOKEN`, `FACTORIO_TOKEN`, or `player-data.json`; `--dry-run`
does not need one.

### `tools/ci/funit-fixture-lint.sh`

```sh
tools/ci/funit-fixture-lint.sh
tools/ci/funit-fixture-lint.sh --json
```

Flags load-stage mistakes: `mods[...]` and `data.raw` in runtime suites (control
stage must use `script.active_mods`), `script.active_mods` in data-stage
fixtures, and `assert(true, ...)` weak-test patterns. It skips comments and
strings.

### `tools/ci/funit-mutation-check.sh`

```sh
tools/ci/funit-mutation-check.sh
tools/ci/funit-mutation-check.sh --modset vanilla --keep
```

Temporarily appends a bad-icon item and a `muluna-` recipe with a missing
ingredient to the test mod's `data.lua`, runs `funit.sh --data-only`, and requires
the `prototype_integrity/icon-fields-valid` and
`content_references/muluna-recipes` fixtures to fail. The original file is
restored by an exit trap. This is the automated version of the manual mutation
check used when adding fixtures.

## `tools/ci/opencode-check.sh`

```sh
tools/ci/opencode-check.sh
tools/ci/opencode-check.sh --agent self-learn \
  --agent-file .opencode/agents/self-learn.md --mode subagent --require-read-only
```

The preflight validates the effective agent before a workflow run. It checks the
JSON agent entry or the Markdown agent frontmatter, the expected mode, the
`opencode agent list` result, and (with `--require-read-only`) that file-based
agents deny edit, bash, network, task, and question permissions.

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
