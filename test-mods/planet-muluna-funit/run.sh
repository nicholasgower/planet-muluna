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
#   FUNIT_MODSET   Mod set to load: "vanilla" (default), "k2so" (Krastorio 2
#                  Spaced Out and its dependencies), or "no-quality" (vanilla
#                  without the quality mod)
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
FUNIT_MODSET="${FUNIT_MODSET:-vanilla}"

case "$FUNIT_MODSET" in
  vanilla | k2so | no-quality) ;;
  *)
    echo "Unknown FUNIT_MODSET: $FUNIT_MODSET (expected vanilla, k2so or no-quality)" >&2
    exit 2
    ;;
esac

if [[ ! -x "$FACTORIO_BIN" ]]; then
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
