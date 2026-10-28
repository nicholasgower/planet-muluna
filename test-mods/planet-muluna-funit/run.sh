#!/usr/bin/env bash
# Headless FUnit runner for planet-muluna.
#
# Usage:
#   test-mods/planet-muluna-funit/run.sh
#
# Environment:
#   FACTORIO_BIN   Factorio executable (default: /opt/factorio_space_age_21/bin/x64/factorio)
#   FACTORIO_MODS  Source mod directory containing dependencies
#   TMP_ROOT       Scratch directory (default: /tmp/opencode/muluna-funit)
#   TIMEOUT        Maximum run time in seconds (default: 900)
#   DATA_ONLY      Set to 1 to run --dump-data instead of the FUnit scenario
#   MOD_LIST_ONLY  Set to 1 to write the scratch mod-list.json and exit without
#                  launching Factorio. Factorio does not need to be installed
#                  (FACTORIO_BIN is not checked), but FACTORIO_MODS must still
#                  contain the dependencies so the mod links can be created.
#   FUNIT_MODSET   Mod set to load: "vanilla" (default), "aai" (vanilla plus
#                  aai-industry), "bz" (Brevven's BZ mods with 2.1 releases),
#                  "k2so" (Krastorio 2 Spaced Out and its dependencies),
#                  "no-quality" (vanilla without quality), "planets" (the top
#                  planet mods and their dependencies), or "muluna-start"
#                  (vanilla plus any-planet-start with aps-planet = muluna)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Local development defaults. In GitHub Actions, setup-factorio.sh exports the
# downloaded install paths through $GITHUB_ENV before this runner is called.
FACTORIO_BIN="${FACTORIO_BIN:-/opt/factorio_space_age_21/bin/x64/factorio}"
FACTORIO_MODS="${FACTORIO_MODS:-/opt/factorio_space_age_21/mods}"
TMP_ROOT="${TMP_ROOT:-/tmp/opencode/muluna-funit}"
TIMEOUT="${TIMEOUT:-900}"
FACTORIO_PORT="${FACTORIO_PORT:-34198}"
DATA_ONLY="${DATA_ONLY:-0}"
MOD_LIST_ONLY="${MOD_LIST_ONLY:-0}"
FUNIT_MODSET="${FUNIT_MODSET:-vanilla}"

case "$FUNIT_MODSET" in
  vanilla | aai | bz | k2so | no-quality | planets | muluna-start) ;;
  *)
    echo "Unknown FUNIT_MODSET: $FUNIT_MODSET (expected vanilla, aai, bz, k2so, no-quality, planets or muluna-start)" >&2
    exit 2
    ;;
esac

# The mod list can be generated without Factorio: MOD_LIST_ONLY=1 skips both
# this check and the launch below. The mod directory is still required because
# the mod links are created before the list is written.
if [[ "$MOD_LIST_ONLY" != "1" && ! -x "$FACTORIO_BIN" ]]; then
  echo "Factorio binary not found: $FACTORIO_BIN" >&2
  exit 1
fi
if [[ ! -d "$FACTORIO_MODS" ]]; then
  echo "Factorio mod directory not found: $FACTORIO_MODS" >&2
  exit 1
fi

rm -rf "$TMP_ROOT"
mkdir -p "$TMP_ROOT/mods" "$TMP_ROOT/write-data/script-output" "$TMP_ROOT/write-data/saves"

link_mod() {
  local name="$1"
  local source="$2"
  if [[ ! -e "$source" ]]; then
    echo "Required dependency missing: $source" >&2
    exit 1
  fi
  ln -sfn "$source" "$TMP_ROOT/mods/$name"
}

link_mod "planet-muluna" "$REPO_DIR"
link_mod "planet-muluna-funit" "$SCRIPT_DIR"
link_mod "PlanetsLib" "$FACTORIO_MODS/PlanetsLib"
link_mod "muluna-graphics" "$FACTORIO_MODS/muluna-graphics"

# Newest matching zip for dependencies that are distributed as zips.
link_zip() {
  local name="$1"
  local pattern="$2"
  local source
  source="$(find "$FACTORIO_MODS" -maxdepth 1 -name "$pattern" -type f | sort -V | tail -n 1)"
  if [[ -z "$source" ]]; then
    echo "Required dependency missing: $pattern" >&2
    exit 1
  fi
  ln -sfn "$source" "$TMP_ROOT/mods/$(basename "$source")"
}

link_zip "flib" 'flib_*.zip'
link_zip "bplib" 'bplib_*.zip'
link_zip "rigor-module" 'rigor-module_*.zip'
link_zip "item-request-proxy-events" 'item-request-proxy-events_*.zip'
link_zip "module-category-defaults" 'module-category-defaults_*.zip'
link_zip "funit" 'funit_*.zip'
link_zip "space-exploration-graphics" 'space-exploration-graphics_*.zip'
link_zip "space-exploration-graphics-4" 'space-exploration-graphics-4_*.zip'
link_zip "space-exploration-graphics-5" 'space-exploration-graphics-5_*.zip'
link_zip "alien-biomes-graphics" 'alien-biomes-graphics_*.zip'

# Krastorio 2 Spaced Out and the dependencies it needs. Keep this list in sync
# with .github/funit/download_mods.py's MODSETS table and with K2SO's info.json.
if [[ "$FUNIT_MODSET" == "aai" ]]; then
  link_zip "aai-industry" 'aai-industry_*.zip'
fi

# Any Planet Start with Muluna as the starting planet. The companion mod's
# settings-updates.lua pins aps-planet to "muluna".
if [[ "$FUNIT_MODSET" == "muluna-start" ]]; then
  link_zip "any-planet-start" 'any-planet-start_*.zip'
fi

# Brevven's BZ mods that have a Factorio 2.1 release. Keep this list in sync
# with .github/funit/download_mods.py's MODSETS table.
if [[ "$FUNIT_MODSET" == "bz" ]]; then
  link_zip "bzcarbon" 'bzcarbon_*.zip'
  link_zip "bzlead" 'bzlead_*.zip'
  link_zip "bzsilicon" 'bzsilicon_*.zip'
  link_zip "bztin" 'bztin_*.zip'
  link_zip "bztitanium" 'bztitanium_*.zip'
  link_zip "bzzirconium" 'bzzirconium_*.zip'
fi

# Prefer a development directory when one is installed, otherwise the newest
# matching zip.
link_mod_or_zip() {
  local name="$1"
  local pattern="$2"
  if [[ -d "$FACTORIO_MODS/$name" ]]; then
    link_mod "$name" "$FACTORIO_MODS/$name"
  else
    link_zip "$name" "$pattern"
  fi
}

# The top planet mods on the mod portal and their required dependencies.
if [[ "$FUNIT_MODSET" == "planets" ]]; then
  link_mod_or_zip "maraxsis" 'maraxsis_*.zip'
  link_mod_or_zip "Cerys-Moon-of-Fulgora" 'Cerys-Moon-of-Fulgora_*.zip'
  link_mod_or_zip "Moshine" 'Moshine_*.zip'
  link_mod_or_zip "corrundum" 'corrundum_*.zip'
  link_mod_or_zip "secretas" 'secretas_*.zip'
  link_mod_or_zip "Paracelsin" 'Paracelsin_*.zip'
  link_mod_or_zip "rubia" 'rubia_*.zip'
  link_zip "SpidertronPatrols" 'SpidertronPatrols_*.zip'
  link_zip "SpidertronEnhancements" 'SpidertronEnhancements_*.zip'
  link_zip "FluidMustFlow" 'FluidMustFlow_*.zip'
  link_zip "Flare Stack" 'Flare Stack_*.zip'
  link_zip "Moshine-assets" 'Moshine-assets_*.zip'
  link_zip "Paracelsin-Graphics" 'Paracelsin-Graphics_*.zip'
  link_zip "SolarMatrix" 'SolarMatrix_*.zip'
  link_zip "Accumulator-V2" 'Accumulator-V2_*.zip'
  link_zip "rubia-assets" 'rubia-assets_*.zip'
  link_zip "machine-upgrades" 'machine-upgrades_*.zip'
  link_zip "RocketCargoInsertion" 'RocketCargoInsertion_*.zip'
fi

if [[ "$FUNIT_MODSET" == "k2so" ]]; then
  link_zip "Krastorio2" 'Krastorio2_*.zip'
  link_zip "Krastorio2Assets" 'Krastorio2Assets_*.zip'
  link_zip "Krastorio2MenuSimulations" 'Krastorio2MenuSimulations_*.zip'
  link_zip "Krastorio2-spaced-out" 'Krastorio2-spaced-out_*.zip'
  link_zip "k2so-assets" 'k2so-assets_*.zip'
  link_zip "ChangeInserterDropLane" 'ChangeInserterDropLane_*.zip'
fi

MOD_NAMES=(
  base
  elevated-rails
  quality
  recycler
  space-age
  planet-muluna
  planet-muluna-funit
  funit
  PlanetsLib
  flib
  bplib
  rigor-module
  item-request-proxy-events
  module-category-defaults
  muluna-graphics
  space-exploration-graphics
  space-exploration-graphics-4
  space-exploration-graphics-5
  alien-biomes-graphics
)
if [[ "$FUNIT_MODSET" == "aai" ]]; then
  MOD_NAMES+=(aai-industry)
fi
if [[ "$FUNIT_MODSET" == "muluna-start" ]]; then
  MOD_NAMES+=(any-planet-start)
fi
if [[ "$FUNIT_MODSET" == "bz" ]]; then
  MOD_NAMES+=(
    bzcarbon
    bzlead
    bzsilicon
    bztin
    bztitanium
    bzzirconium
  )
fi
if [[ "$FUNIT_MODSET" == "planets" ]]; then
  MOD_NAMES+=(
    maraxsis
    Cerys-Moon-of-Fulgora
    Moshine
    corrundum
    secretas
    Paracelsin
    rubia
    SpidertronPatrols
    SpidertronEnhancements
    FluidMustFlow
    "Flare Stack"
    Moshine-assets
    Paracelsin-Graphics
    SolarMatrix
    Accumulator-V2
    rubia-assets
    machine-upgrades
    RocketCargoInsertion
  )
fi
if [[ "$FUNIT_MODSET" == "k2so" ]]; then
  MOD_NAMES+=(
    Krastorio2
    Krastorio2Assets
    Krastorio2MenuSimulations
    Krastorio2-spaced-out
    k2so-assets
    ChangeInserterDropLane
  )
fi

{
  printf '{\n  "mods": [\n'
  for i in "${!MOD_NAMES[@]}"; do
    enabled="true"
    # Factorio auto-enables an installed mod that is recommended by an enabled
    # mod, so the no-quality set must write quality as explicitly disabled
    # rather than omitting it from the list.
    if [[ "$FUNIT_MODSET" == "no-quality" && "${MOD_NAMES[$i]}" == "quality" ]]; then
      enabled="false"
    fi
    printf '    { "name": "%s", "enabled": %s }' "${MOD_NAMES[$i]}" "$enabled"
    if (( i < ${#MOD_NAMES[@]} - 1 )); then
      printf ','
    fi
    printf '\n'
  done
  printf '  ]\n}\n'
} > "$TMP_ROOT/mods/mod-list.json"

# Print the generated list and stop before touching server-settings.json, which
# is read from the Factorio install and therefore needs FACTORIO_BIN.
if [[ "$MOD_LIST_ONLY" == "1" ]]; then
  echo "Wrote mod list for modset '$FUNIT_MODSET': $TMP_ROOT/mods/mod-list.json" >&2
  echo "$TMP_ROOT/mods/mod-list.json"
  exit 0
fi

sed 's/"auto_pause": true/"auto_pause": false/' "$(dirname "$FACTORIO_BIN")/../../data/server-settings.example.json" > "$TMP_ROOT/server-settings.json"

cat > "$TMP_ROOT/config.ini" <<EOF
; version=13
[path]
read-data=__PATH__executable__/../../data
write-data=$TMP_ROOT/write-data

[general]
locale=en

[other]
; verbose-logging=false
EOF

LOG="$TMP_ROOT/stdout.log"
if [[ "$DATA_ONLY" == "1" ]]; then
  echo "Running Muluna data-stage probe..."
  echo "  binary: $FACTORIO_BIN"
  echo "  mods:   $TMP_ROOT/mods"
  echo "  log:    $LOG"

  set +e
  if command -v timeout >/dev/null 2>&1; then
    timeout "${TIMEOUT}s" "$FACTORIO_BIN" \
      --config "$TMP_ROOT/config.ini" \
      --mod-directory "$TMP_ROOT/mods" \
      --dump-data \
      --no-log-rotation \
      >"$LOG" 2>&1
  else
    "$FACTORIO_BIN" \
      --config "$TMP_ROOT/config.ini" \
      --mod-directory "$TMP_ROOT/mods" \
      --dump-data \
      --no-log-rotation \
      >"$LOG" 2>&1
  fi
  FACTORIO_STATUS=$?
  set -e

  if [[ "$FACTORIO_STATUS" -ne 0 ]]; then
    echo "Data-stage probe failed (Factorio exit $FACTORIO_STATUS)." >&2
    tail -n 80 "$LOG" >&2 || true
  fi
  exit "$FACTORIO_STATUS"
fi

echo "Running Muluna FUnit suite..."
echo "  binary: $FACTORIO_BIN"
echo "  mods:   $TMP_ROOT/mods"
echo "  log:    $LOG"

# The dedicated headless server build has no audio subsystem and rejects
# --disable-audio, while the full client accepts it. Only pass the flag when
# the binary advertises it so the same runner works with either install.
FACTORIO_ARGS=(
  --config "$TMP_ROOT/config.ini"
  --mod-directory "$TMP_ROOT/mods"
  --start-server-load-scenario planet-muluna-funit/__funit__muluna
  --port "$FACTORIO_PORT"
  --server-settings "$TMP_ROOT/server-settings.json"
  --no-log-rotation
)
if "$FACTORIO_BIN" --help 2>&1 | grep -q -- '--disable-audio'; then
  FACTORIO_ARGS+=(--disable-audio)
fi

set +e
"$FACTORIO_BIN" \
  "${FACTORIO_ARGS[@]}" \
  >"$LOG" 2>&1 &
FACTORIO_PID=$!
set -e

finished=0
for ((i = 0; i < TIMEOUT; i++)); do
  if grep -q '====END====' "$LOG" 2>/dev/null; then
    finished=1
    break
  fi
  if ! kill -0 "$FACTORIO_PID" 2>/dev/null; then
    break
  fi
  sleep 1
done

if kill -0 "$FACTORIO_PID" 2>/dev/null; then
  kill "$FACTORIO_PID" 2>/dev/null || true
fi
wait "$FACTORIO_PID" 2>/dev/null || true

if [[ ! -f "$LOG" ]]; then
  echo "No Factorio log was produced at $LOG." >&2
  exit 1
fi

if [[ "$finished" -ne 1 ]]; then
  echo "FUnit did not reach ====END==== within ${TIMEOUT}s." >&2
  grep -nE '__FUNIT__|Error|error|FAILURE|ERROR' "$LOG" | tail -n 80 >&2 || true
  tail -n 80 "$LOG" >&2 || true
  exit 1
fi

if grep -qE '__FUNIT__.*(FAILURE__|ERROR__)' "$LOG"; then
  echo "FUnit reported failures:" >&2
  grep -nE '__FUNIT__.*(FAILURE__|ERROR__)' "$LOG" >&2
  exit 1
fi

echo "FUnit suite passed."
grep -oE '__FUNIT__[^ ]*====BEGIN [0-9]+ TESTS====' "$LOG" | tail -n 1 || true
grep -c '__FUNIT__.*SUCCESS__' "$LOG" | sed 's/^/SUCCESS lines: /' || true
