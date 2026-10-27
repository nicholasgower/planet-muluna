#!/usr/bin/env bash
# funit-download-modset.sh - download one FUnit mod set's extra mods locally.
#
# This is a development helper for planet-muluna. It is not shipped with the mod.
#
# CI downloads each matrix leg's dependency set with
# .github/funit/download_mods.py. Running a mod set locally needs the same extra
# mods, but not Muluna's whole dependency list, which a development machine
# normally already has. This wrapper reuses download_mods.py with empty info
# files, so only the mod set's own `add` list is resolved and downloaded.
#
# Usage:
#   tools/ci/funit-download-modset.sh --modset NAME [OPTIONS]
#   tools/ci/funit-download-modset.sh --modset bz --dry-run
#   tools/ci/funit-download-modset.sh --modset k2so --mods-dir ~/.factorio/mods
#
# Options:
#   --modset NAME             Mod set to download: vanilla, aai, bz, k2so,
#                             no-quality or planets. Required.
#   --mods-dir DIR            Destination mod directory. Defaults to
#                             $FACTORIO_MODS, then /opt/factorio_space_age_21/mods.
#   --factorio-version V      Target version, or "stable"/"latest" to track the
#                             installed game's release channel. Defaults to
#                             $FACTORIO_VERSION, then "stable".
#   --dry-run                 Resolve and print the releases without downloading.
#                             Does not need a token.
#   -h, --help                Show this help and exit.
#
# Token resolution (the token is never printed):
#   1. FACTORIO_PLAYER_TOKEN
#   2. FACTORIO_TOKEN
#   3. service-token from $FACTORIO_DATA/player-data.json
#   4. service-token from /opt/factorio_space_age_21/player-data.json
#
# Environment:
#   FACTORIO_MODS     Default --mods-dir.
#   FACTORIO_VERSION  Default --factorio-version (then "stable").
#   FACTORIO_BIN      Game used to resolve "stable"/"latest" to a version.
#                     Defaults to /opt/factorio_space_age_21/bin/x64/factorio
#                     when that install exists.
#   FACTORIO_USERNAME Portal account that owns the token (default: MeteorSwarm).
#
# Exit status:
#   0  the mod set was resolved (and downloaded, unless --dry-run)
#   1  download failure, missing token, or missing dependency
#   2  usage error
#
# Requires: bash, python3, and network access to mods.factorio.com.
set -euo pipefail

PROG="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOWNLOAD_MODS="$REPO_DIR/.github/funit/download_mods.py"

MODS_DIR="${FACTORIO_MODS:-/opt/factorio_space_age_21/mods}"
FACTORIO_VERSION="${FACTORIO_VERSION:-stable}"
# download_mods.py resolves "stable"/"latest" from FACTORIO_BIN, then from a
# factorio binary on PATH, then from /opt/factorio. Point it at the local Space
# Age install so release labels match the game that will load the mods.
DEFAULT_FACTORIO_BIN="/opt/factorio_space_age_21/bin/x64/factorio"
if [[ -z "${FACTORIO_BIN:-}" && -x "$DEFAULT_FACTORIO_BIN" ]]; then
  FACTORIO_BIN="$DEFAULT_FACTORIO_BIN"
fi
FACTORIO_BIN="${FACTORIO_BIN:-}"
MODSET=""
DRY_RUN=0

TMP_DIR=""
TOKEN=""
PORTAL_USERNAME="${FACTORIO_USERNAME:-}"

usage() {
  sed -n '2,48p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

die() {
  printf '%s: error: %s\n' "$PROG" "$*" >&2
  exit 2
}

fail() {
  printf '%s: error: %s\n' "$PROG" "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf -- "$TMP_DIR"
    TMP_DIR=""
  fi
}
trap cleanup EXIT

# Read the MODSETS table in download_mods.py with ast, so the accepted names
# and per-modset lists never drift from the CI helper. Importing the module
# would write __pycache__, hence ast + python3 -B. MODE is "names", "add" or
# "disable"; NAME selects one mod set for the latter two.
modset_table() {
  python3 -B - "$DOWNLOAD_MODS" "$@" <<'PY'
import ast
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    tree = ast.parse(handle.read())

mode = sys.argv[2]
wanted = sys.argv[3] if len(sys.argv) > 3 else None
for node in tree.body:
    if not isinstance(node, ast.Assign):
        continue
    if not any(getattr(target, "id", None) == "MODSETS" for target in node.targets):
        continue
    for name, config in ast.literal_eval(node.value).items():
        if wanted is not None and name != wanted:
            continue
        if mode == "names":
            print(name)
        elif mode in ("add", "disable"):
            for mod in config.get(mode, []):
                print(mod)
PY
}

modset_names() {
  modset_table names
}

modset_extra_mods() {
  modset_table add "$1"
}

# The token is read from the environment first, then from player-data.json. It
# is only ever assigned to a variable or exported to download_mods.py.
read_player_data_field() {
  python3 -B - "$1" "$2" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        value = json.load(handle).get(sys.argv[2])
except (OSError, ValueError):
    value = None
print(value or "")
PY
}

resolve_credentials() {
  if [[ -n "${FACTORIO_PLAYER_TOKEN:-}" ]]; then
    TOKEN="$FACTORIO_PLAYER_TOKEN"
    return 0
  fi
  if [[ -n "${FACTORIO_TOKEN:-}" ]]; then
    TOKEN="$FACTORIO_TOKEN"
    return 0
  fi

  local candidate
  for candidate in \
    "${FACTORIO_DATA:+$FACTORIO_DATA/player-data.json}" \
    "/opt/factorio_space_age_21/player-data.json"; do
    [[ -n "$candidate" && -f "$candidate" ]] || continue
    TOKEN="$(read_player_data_field "$candidate" "service-token")"
    if [[ -n "$TOKEN" ]]; then
      if [[ -z "$PORTAL_USERNAME" ]]; then
        PORTAL_USERNAME="$(read_player_data_field "$candidate" "service-username")"
      fi
      return 0
    fi
  done

  TOKEN=""
  return 0
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
    --mods-dir)
      [[ $# -ge 2 ]] || die "--mods-dir requires a DIR"
      MODS_DIR="$2"
      shift 2
      ;;
    --mods-dir=*)
      MODS_DIR="${1#*=}"
      shift
      ;;
    --factorio-version)
      [[ $# -ge 2 ]] || die "--factorio-version requires a VALUE"
      FACTORIO_VERSION="$2"
      shift 2
      ;;
    --factorio-version=*)
      FACTORIO_VERSION="${1#*=}"
      shift
      ;;
    --dry-run)
      DRY_RUN=1
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
[[ -n "$MODS_DIR" ]] || die "--mods-dir/FACTORIO_MODS must not be empty"
[[ -n "$FACTORIO_VERSION" ]] || die "--factorio-version must not be empty"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"
[[ -f "$DOWNLOAD_MODS" ]] || fail "download helper not found: $DOWNLOAD_MODS"

AVAILABLE_MODSETS="$(modset_names | paste -sd' ' -)"
case " $AVAILABLE_MODSETS " in
  *" $MODSET "*) ;;
  *) die "unknown --modset: $MODSET (available: $AVAILABLE_MODSETS)" ;;
esac

resolve_credentials
if ((DRY_RUN == 0)) && [[ -z "$TOKEN" ]]; then
  fail "no Factorio player token. Set FACTORIO_PLAYER_TOKEN to the service-token from player-data.json (a ModPortal upload key cannot download mods)."
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/muluna-modset.XXXXXX")" ||
  fail "could not create a temporary directory"

# Empty info files keep download_mods.py from pulling in Muluna's own dependency
# list; only the mod set's `add` entries remain.
printf '{\n  "dependencies": []\n}\n' >"$TMP_DIR/info.json"
printf '{\n  "dependencies": []\n}\n' >"$TMP_DIR/test-info.json"

echo "funit-download-modset.sh"
echo "  modset:      $MODSET"
echo "  requested:   $FACTORIO_VERSION"
echo "  mods dir:    $MODS_DIR"
if ((DRY_RUN == 1)); then
  echo "  mode:        dry run (resolve only, no downloads)"
else
  echo "  mode:        download"
fi

CMD=(
  python3 -B "$DOWNLOAD_MODS"
  --info "$TMP_DIR/info.json"
  --test-info "$TMP_DIR/test-info.json"
  --output-dir "$MODS_DIR"
  --mod-list "$TMP_DIR/mod-list.json"
  --factorio-version "$FACTORIO_VERSION"
  --modset "$MODSET"
  --skip-local-check
)
if ((DRY_RUN == 1)); then
  CMD+=(--dry-run)
fi

# download_mods.py checks TOKEN before FACTORIO_PLAYER_TOKEN, so pass the
# resolved token under both names; this keeps an unrelated ambient TOKEN from
# taking precedence. An empty USERNAME lets FACTORIO_USERNAME win.
RUN_ENV=(
  "TOKEN=$TOKEN"
  "FACTORIO_PLAYER_TOKEN=$TOKEN"
  "USERNAME="
  "FACTORIO_USERNAME=$PORTAL_USERNAME"
)
if [[ -n "$FACTORIO_BIN" ]]; then
  RUN_ENV+=("FACTORIO_BIN=$FACTORIO_BIN")
fi

DOWNLOAD_LOG="$TMP_DIR/download.log"
DOWNLOAD_EXIT=0
env "${RUN_ENV[@]}" "${CMD[@]}" 2>&1 | tee "$DOWNLOAD_LOG" || DOWNLOAD_EXIT=${PIPESTATUS[0]}
if ((DOWNLOAD_EXIT != 0)); then
  fail "download_mods.py failed with status $DOWNLOAD_EXIT"
fi

# A label is resolved by download_mods.py against the installed game or
# factorio.com; a concrete version is already resolved. Report whichever one
# the portal query actually used.
RESOLVED_VERSION="$(
  sed -n "s/^Resolved Factorio version '.*' to \([^ ]*\) (.*$/\1/p" "$DOWNLOAD_LOG" | tail -n 1
)"
RESOLVED_VERSION="${RESOLVED_VERSION:-$FACTORIO_VERSION}"

echo
echo "Summary"
echo "  modset:   $MODSET"
echo "  factorio: $RESOLVED_VERSION"
echo "  mods dir: $MODS_DIR"

if ((DRY_RUN == 1)); then
  echo "  files:    none (dry run)"
  exit 0
fi

EXTRA_MODS="$(modset_extra_mods "$MODSET")"
if [[ -z "$EXTRA_MODS" ]]; then
  echo "  files:    none (this mod set adds no extra mods)"
  exit 0
fi

echo "  files:"
shopt -s nullglob
while IFS= read -r name; do
  [[ -n "$name" ]] || continue
  files=("$MODS_DIR/${name}"_*.zip)
  if ((${#files[@]} == 0)); then
    echo "    $name: MISSING (no ${name}_*.zip in $MODS_DIR)"
    exit 1
  fi
  for file in "${files[@]}"; do
    printf '    %s\n' "$file"
  done
done <<<"$EXTRA_MODS"
shopt -u nullglob
