#!/usr/bin/env bash
# funit-mod-list.sh - print or write the FUnit mod-list.json for a mod set.
#
# This is a development helper for planet-muluna. It is not shipped with the mod.
#
# The FUnit matrix builds its mod-list.json inside
# test-mods/planet-muluna-funit/run.sh. This wrapper drives that code path with
# MOD_LIST_ONLY=1, so the list can be inspected, diffed, or compared with a CI
# artifact without starting Factorio (and without Factorio being installed).
#
# Usage:
#   tools/ci/funit-mod-list.sh --modset NAME [--output FILE] [--tmp-root DIR]
#   tools/ci/funit-mod-list.sh --modset no-quality
#   tools/ci/funit-mod-list.sh --modset bz --output /tmp/opencode/bz-mod-list.json
#
# Environment overrides:
#   FACTORIO_MODS  Source mod directory containing the dependencies
#                  (default: /opt/factorio_space_age_21/mods)
#   TMP_ROOT       Scratch directory (default: /tmp/opencode/muluna-funit).
#                  It is recreated by run.sh, so do not point it at data.
#
# Exit status:
#   0  the mod list was printed or written
#   1  run.sh failed or did not write a mod list
#   2  usage error
set -euo pipefail

PROG="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUNNER="$REPO_DIR/test-mods/planet-muluna-funit/run.sh"

FACTORIO_MODS="${FACTORIO_MODS:-/opt/factorio_space_age_21/mods}"
TMP_ROOT="${TMP_ROOT:-/tmp/opencode/muluna-funit}"

MODSET=""
OUTPUT=""

# The accepted mod-set names live in run.sh's case statement and
# download_mods.py's MODSETS table; this wrapper deliberately does not keep a
# third copy. run.sh validates the name and prints the accepted list.

usage() {
  sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

die() {
  printf '%s: error: %s\n' "$PROG" "$*" >&2
  exit 2
}

fail() {
  printf '%s: error: %s\n' "$PROG" "$*" >&2
  exit 1
}

while (($# > 0)); do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --modset)
      [[ $# -ge 2 ]] || die "--modset requires a NAME"
      MODSET="$2"
      shift 2
      ;;
    --modset=*)
      MODSET="${1#*=}"
      shift
      ;;
    --output)
      [[ $# -ge 2 ]] || die "--output requires a FILE"
      OUTPUT="$2"
      shift 2
      ;;
    --output=*)
      OUTPUT="${1#*=}"
      shift
      ;;
    --tmp-root)
      [[ $# -ge 2 ]] || die "--tmp-root requires a DIR"
      TMP_ROOT="$2"
      shift 2
      ;;
    --tmp-root=*)
      TMP_ROOT="${1#*=}"
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      die "unexpected argument: $1"
      ;;
  esac
done

if (($# > 0)); then
  die "unexpected argument: $1"
fi

[[ -n "$MODSET" ]] || die "--modset is required"
[[ -n "$TMP_ROOT" ]] || die "--tmp-root/TMP_ROOT must not be empty"
[[ -f "$RUNNER" ]] || fail "FUnit runner not found: $RUNNER"

printf '%s: modset %s, mods %s, tmp %s\n' \
  "$PROG" "$MODSET" "$FACTORIO_MODS" "$TMP_ROOT" >&2

# run.sh writes the path to stdout, so capture its output instead of letting it
# mix with the JSON. It is relayed to stderr only when the run fails.
RUNNER_EXIT=0
RUNNER_OUT="$(
  MOD_LIST_ONLY=1 \
    FUNIT_MODSET="$MODSET" \
    FACTORIO_MODS="$FACTORIO_MODS" \
    TMP_ROOT="$TMP_ROOT" \
    "$RUNNER" 2>&1
)" || RUNNER_EXIT=$?
if ((RUNNER_EXIT != 0)); then
  printf '%s\n' "$RUNNER_OUT" >&2
  if ((RUNNER_EXIT == 2)); then
    die "run.sh rejected the arguments (status 2)"
  fi
  fail "run.sh failed with status $RUNNER_EXIT while generating the mod list"
fi

# Prefer the path run.sh printed, falling back to the documented location.
MOD_LIST="$TMP_ROOT/mods/mod-list.json"
PRINTED_PATH="$(printf '%s\n' "$RUNNER_OUT" | tail -n 1)"
if [[ -n "$PRINTED_PATH" && -f "$PRINTED_PATH" ]]; then
  MOD_LIST="$PRINTED_PATH"
fi
[[ -f "$MOD_LIST" ]] || fail "run.sh did not write a mod list (expected $MOD_LIST)"

if [[ -n "$OUTPUT" ]]; then
  mkdir -p -- "$(dirname -- "$OUTPUT")"
  cp -f -- "$MOD_LIST" "$OUTPUT" || fail "could not copy $MOD_LIST to $OUTPUT"
  printf '%s: wrote %s\n' "$PROG" "$OUTPUT" >&2
else
  cat -- "$MOD_LIST"
fi
