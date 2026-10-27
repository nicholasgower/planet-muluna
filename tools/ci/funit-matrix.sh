#!/usr/bin/env bash
# Run the FUnit suite once per mod set and print one combined summary.
#
# This is a development helper for planet-muluna. It is not shipped with the mod.
# Each leg is delegated to tools/ci/funit.sh --json so the per-modset parsing and
# exit-code rules stay in one place; this script only aggregates the results.
#
# Runs are strictly sequential: every leg starts a headless Factorio server on
# the same port and reuses the same scratch directory, so parallel runs would
# collide.
#
# Usage: tools/ci/funit-matrix.sh [OPTIONS]
# Run "tools/ci/funit-matrix.sh --help" for details.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FUNIT="$SCRIPT_DIR/funit.sh"

ALL_MODSETS=(vanilla aai bz no-quality planets k2so)
MODSETS=("${ALL_MODSETS[@]}")
DATA_ONLY=0
FAIL_FAST=0
JSON=0

usage() {
  cat <<'EOF'
Usage: tools/ci/funit-matrix.sh [OPTIONS]

Run the headless FUnit suite for several mod sets, one after another, and print
one combined summary. Each leg calls:

  tools/ci/funit.sh --modset NAME --json [--data-only]

Options:
  --modsets LIST     Comma-separated mod sets to run, in order. Valid names are
                     vanilla, aai, bz, no-quality, planets and k2so.
                     Default: vanilla,aai,bz,no-quality,planets,k2so
                     Duplicates are dropped; the first occurrence wins.
  --data-only        Run only the data stage for every modset. Much faster than
                     the runtime suite and the right loop for prototype work.
  --fail-fast        Stop at the first modset that does not pass. Mod sets that
                     were not run are reported as skipped.
  --json             Print a single-line JSON object instead of the text table.
  -h, --help         Show this help.

Exit status:
  0  every modset that ran passed
  1  at least one modset failed, or a leg produced no usable JSON summary
  2  usage error, missing tools/ci/funit.sh, or python3 is unavailable

Notes:
  - Legs are never run in parallel: Factorio binds a fixed port and the runner
    reuses $TMP_ROOT, so concurrent legs would conflict.
  - FACTORIO_BIN, FACTORIO_MODS, TMP_ROOT and TIMEOUT are inherited by every
    leg exactly as for tools/ci/funit.sh.
  - Per-leg stdout JSON and stderr logs are written to a temporary directory
    under ${TMPDIR:-/tmp/opencode}. The directory is removed when every leg
    passes and kept (with its path printed) after a failure so the logs can be
    inspected.

Examples:
  tools/ci/funit-matrix.sh
  tools/ci/funit-matrix.sh --data-only
  tools/ci/funit-matrix.sh --modsets vanilla,k2so --data-only
  tools/ci/funit-matrix.sh --fail-fast --json
EOF
}

die() {
  echo "funit-matrix.sh: $*" >&2
  echo "Try 'tools/ci/funit-matrix.sh --help' for usage." >&2
  exit 2
}

# Split a comma-separated list, trimming surrounding whitespace and dropping
# duplicates while preserving the requested order.
split_modsets() {
  local raw="$1"
  local item
  local -a parsed=()
  local -a result=()
  local existing seen

  [[ -n "${raw//[[:space:]]/}" ]] || die "--modsets requires at least one modset name."

  IFS=',' read -r -a parsed <<<"$raw"
  for item in "${parsed[@]}"; do
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    [[ -n "$item" ]] || die "--modsets contains an empty entry: '$raw'."
    case "$item" in
      vanilla | aai | bz | k2so | no-quality | planets) ;;
      *) die "unknown modset: $item (expected vanilla, aai, bz, k2so, no-quality or planets)." ;;
    esac
    seen=0
    for existing in "${result[@]+"${result[@]}"}"; do
      if [[ "$existing" == "$item" ]]; then
        seen=1
        break
      fi
    done
    if (( seen == 0 )); then
      result+=("$item")
    fi
  done

  MODSETS=("${result[@]}")
}

while (($# > 0)); do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --modsets)
      [[ $# -ge 2 ]] || die "--modsets requires a LIST."
      split_modsets "$2"
      shift 2
      ;;
    --modsets=*)
      split_modsets "${1#*=}"
      shift
      ;;
    --data-only)
      DATA_ONLY=1
      shift
      ;;
    --fail-fast)
      FAIL_FAST=1
      shift
      ;;
    --json)
      JSON=1
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

if (($# > 0)); then
  die "unexpected argument: $1"
fi

[[ -f "$FUNIT" ]] || die "FUnit helper not found: $FUNIT"
[[ -x "$FUNIT" ]] || die "FUnit helper is not executable: $FUNIT"
command -v python3 >/dev/null 2>&1 || die "python3 is required to parse the FUnit summaries."

MATRIX_BASE="${TMPDIR:-/tmp/opencode}"
mkdir -p -- "$MATRIX_BASE" || die "could not create $MATRIX_BASE."
MATRIX_DIR="$(mktemp -d "$MATRIX_BASE/muluna-funit-matrix.XXXXXX")" ||
  die "could not create a temporary results directory in $MATRIX_BASE."

RUN_MODSETS=()
SKIPPED=()
OVERALL_RC=0
KEEP_RESULTS=0

cleanup() {
  if (( KEEP_RESULTS == 0 )); then
    rm -rf -- "$MATRIX_DIR"
  fi
}
on_exit() {
  local rc=$?
  trap - EXIT INT TERM
  cleanup
  exit "$rc"
}
trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Normalize one leg's funit.sh output into a single record so the summary step
# never has to guess about missing or malformed JSON. The record always exists
# for a leg that ran, even when funit.sh died before printing anything.
parse_leg() {
  local modset="$1" rc="$2" raw="$3" log="$4" out="$5"

  python3 - "$modset" "$rc" "$raw" "$log" >"$out" <<'PY'
import json
import sys

modset = sys.argv[1]
exit_code = int(sys.argv[2])
raw_path = sys.argv[3]
log_path = sys.argv[4]

record = {
    "modset": modset,
    "status": "error",
    "tests": 0,
    "success": 0,
    "failures": 0,
    "errors": 0,
    "exit_code": exit_code,
    "failing_test_ids": [],
    "log": log_path,
}

try:
    with open(raw_path, encoding="utf-8", errors="replace") as handle:
        text = handle.read()
except OSError:
    text = ""

payload = None
for line in reversed(text.splitlines()):
    line = line.strip()
    if not (line.startswith("{") and line.endswith("}")):
        continue
    try:
        candidate = json.loads(line)
    except json.JSONDecodeError:
        continue
    if isinstance(candidate, dict):
        payload = candidate
        break

if payload is None:
    # funit.sh never printed a summary line: usage error, missing Factorio, or
    # a runner crash before the query step.
    record["status"] = "no-json"
    record["note"] = "funit.sh produced no JSON summary (exit %d)" % exit_code
else:
    status = payload.get("status")
    record["status"] = str(status) if isinstance(status, str) and status else "unknown"
    for key in ("tests", "success", "failures", "errors"):
        value = payload.get(key)
        if isinstance(value, bool):
            value = None
        if isinstance(value, int) and value >= 0:
            record[key] = value
    failing = payload.get("failing_test_ids")
    if isinstance(failing, list):
        record["failing_test_ids"] = [str(item) for item in failing]
    if payload.get("data_only"):
        record["data_only"] = True
    if isinstance(payload.get("suite"), str):
        record["suite"] = payload["suite"]

# funit.sh and the reported status must agree. Disagreement is a runner problem,
# not a pass, so surface it as an error instead of hiding it in the table.
if exit_code != 0 and record["status"] == "passed":
    record["status"] = "error"
    record["note"] = "funit.sh exited %d but reported passed" % exit_code
elif exit_code == 0 and record["status"] != "passed":
    record["note"] = "funit.sh exited 0 but reported %s" % record["status"]

record["passed"] = record["status"] == "passed" and exit_code == 0
json.dump(record, sys.stdout, separators=(",", ":"))
PY
}

for i in "${!MODSETS[@]}"; do
  modset="${MODSETS[$i]}"
  raw="$MATRIX_DIR/$modset.json"
  log="$MATRIX_DIR/$modset.log"
  record="$MATRIX_DIR/$modset.result.json"

  leg_args=(--modset "$modset" --json)
  if (( DATA_ONLY == 1 )); then
    leg_args+=(--data-only)
  fi

  echo "==> [$((i + 1))/${#MODSETS[@]}] modset $modset" >&2

  # Keep the leg's stdout (the JSON summary) separate from its stderr (progress
  # and diagnostics) so a crashed leg cannot corrupt the summary line.
  set +e
  "$FUNIT" "${leg_args[@]}" >"$raw" 2>"$log"
  leg_rc=$?
  set -e

  parse_leg "$modset" "$leg_rc" "$raw" "$log" "$record" ||
    die "could not parse the FUnit summary for modset $modset."

  RUN_MODSETS+=("$modset")

  leg_passed=0
  if python3 -c 'import json,sys; raise SystemExit(0 if json.load(open(sys.argv[1], encoding="utf-8")).get("passed") else 1)' "$record"; then
    leg_passed=1
  fi

  if (( leg_passed == 0 )); then
    OVERALL_RC=1
    if (( FAIL_FAST == 1 )); then
      echo "funit-matrix.sh: modset $modset did not pass; stopping early (--fail-fast)." >&2
      for ((j = i + 1; j < ${#MODSETS[@]}; j++)); do
        SKIPPED+=("${MODSETS[$j]}")
      done
      break
    fi
  fi
done

set +e
MATRIX_DIR="$MATRIX_DIR" \
  MATRIX_MODSETS="${RUN_MODSETS[*]-}" \
  MATRIX_SKIPPED="${SKIPPED[*]-}" \
  MATRIX_JSON="$JSON" \
  MATRIX_DATA_ONLY="$DATA_ONLY" \
  MATRIX_FAIL_FAST="$FAIL_FAST" \
  python3 - <<'PY'
import json
import os
from pathlib import Path

directory = Path(os.environ["MATRIX_DIR"])
modsets = os.environ["MATRIX_MODSETS"].split()
skipped = os.environ["MATRIX_SKIPPED"].split()
as_json = os.environ["MATRIX_JSON"] == "1"
data_only = os.environ["MATRIX_DATA_ONLY"] == "1"
fail_fast = os.environ["MATRIX_FAIL_FAST"] == "1"

records = []
for modset in modsets:
    path = directory / ("%s.result.json" % modset)
    try:
        with path.open(encoding="utf-8") as handle:
            records.append(json.load(handle))
    except (OSError, json.JSONDecodeError) as error:
        records.append(
            {
                "modset": modset,
                "status": "error",
                "tests": 0,
                "success": 0,
                "failures": 0,
                "errors": 0,
                "exit_code": 2,
                "failing_test_ids": [],
                "log": str(directory / ("%s.log" % modset)),
                "note": "could not read %s: %s" % (path, error),
                "passed": False,
            }
        )

passed = [record for record in records if record.get("passed")]
failed = [record for record in records if not record.get("passed")]
ok = bool(records) and not failed and not skipped

if as_json:
    print(
        json.dumps(
            {
                "passed": ok,
                "data_only": data_only,
                "fail_fast": fail_fast,
                "modsets": records,
                "skipped": skipped,
                "summary": {
                    "total": len(records),
                    "passed": len(passed),
                    "failed": len(failed),
                    "skipped": len(skipped),
                },
            },
            separators=(",", ":"),
        )
    )
else:
    label = "FUnit matrix (data-only)" if data_only else "FUnit matrix"
    print(label)
    print(
        "  %-12s %-11s %6s %8s %9s %7s"
        % ("modset", "status", "tests", "success", "failures", "errors")
    )
    for record in records:
        print(
            "  %-12s %-11s %6d %8d %9d %7d"
            % (
                record["modset"],
                record["status"],
                record["tests"],
                record["success"],
                record["failures"],
                record["errors"],
            )
        )

    for record in failed:
        note = record.get("note")
        if note:
            print("  %s: %s" % (record["modset"], note))
        for test_id in record.get("failing_test_ids") or []:
            print("    - %s/%s" % (record["modset"], test_id))
        print("    log: %s" % record["log"])

    if skipped:
        print("  skipped: %s" % ", ".join(skipped))

    if ok:
        print("\nOverall: PASSED (%d/%d modsets)" % (len(passed), len(records)))
    else:
        names = ", ".join(record["modset"] for record in failed) or "(none ran)"
        print(
            "\nOverall: FAILED (%d/%d modsets passed; failed: %s)"
            % (len(passed), len(records), names)
        )
    if failed or skipped:
        print("  results: %s" % directory)
PY
summary_rc=$?
set -e

if (( summary_rc != 0 )); then
  KEEP_RESULTS=1
  echo "funit-matrix.sh: could not build the combined summary; per-leg output is in $MATRIX_DIR." >&2
  exit 1
fi

if (( OVERALL_RC != 0 )); then
  KEEP_RESULTS=1
  exit 1
fi

exit 0
