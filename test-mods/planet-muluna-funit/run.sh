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
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

FACTORIO_BIN="${FACTORIO_BIN:-/opt/factorio_space_age_21/bin/x64/factorio}"
FACTORIO_MODS="${FACTORIO_MODS:-/opt/factorio_space_age_21/mods}"
TMP_ROOT="${TMP_ROOT:-/tmp/opencode/muluna-funit}"
TIMEOUT="${TIMEOUT:-900}"
FACTORIO_PORT="${FACTORIO_PORT:-34198}"

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

cat > "$TMP_ROOT/mods/mod-list.json" <<'JSON'
{
  "mods": [
    { "name": "base", "enabled": true },
    { "name": "elevated-rails", "enabled": true },
    { "name": "quality", "enabled": true },
    { "name": "recycler", "enabled": true },
    { "name": "space-age", "enabled": true },
    { "name": "planet-muluna", "enabled": true },
    { "name": "planet-muluna-funit", "enabled": true },
    { "name": "funit", "enabled": true },
    { "name": "PlanetsLib", "enabled": true },
    { "name": "flib", "enabled": true },
    { "name": "bplib", "enabled": true },
    { "name": "rigor-module", "enabled": true },
    { "name": "item-request-proxy-events", "enabled": true },
    { "name": "module-category-defaults", "enabled": true },
    { "name": "muluna-graphics", "enabled": true },
    { "name": "space-exploration-graphics", "enabled": true },
    { "name": "space-exploration-graphics-4", "enabled": true },
    { "name": "space-exploration-graphics-5", "enabled": true },
    { "name": "alien-biomes-graphics", "enabled": true }
  ]
}
JSON

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
