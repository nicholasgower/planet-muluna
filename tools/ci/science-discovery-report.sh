#!/usr/bin/env bash
# Compare exploration science pack discovery across mod sets.
#
# This is a development helper for planet-muluna. It is not shipped with the mod.
# Each leg runs the data-stage FUnit fixtures in its own scratch directory, then
# queries the resulting prototype dump with tools/proto_query.py
# "exploration-science". It never launches Factorio itself; that is delegated to
# tools/ci/funit.sh.
#
# Usage: tools/ci/science-discovery-report.sh [OPTIONS]
# Run "tools/ci/science-discovery-report.sh --help" for details.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FUNIT="$SCRIPT_DIR/funit.sh"
PROTO_QUERY="$REPO_DIR/tools/proto_query.py"

DEFAULT_MODSETS=(vanilla planets)
MODSETS=("${DEFAULT_MODSETS[@]}")
WORK_DIR="${TMPDIR:-/tmp/opencode}/muluna-science-discovery"
JSON=0
REQUIRE_BASELINE=0

usage() {
  cat <<'EOF'
Usage: tools/ci/science-discovery-report.sh [OPTIONS]

Run data-stage discovery once per mod set and report:
  - pack count and required count;
  - the contributing pack for each planet;
  - legacy-only progress technologies;
  - legacy names missing from the loaded prototype data;
  - rejected lab science pack items.

Options:
  --modsets LIST       Comma-separated mod sets, in order. Valid names are
                       vanilla, aai, bz, no-quality, planets, k2so and
                       muluna-start. Default: vanilla,planets
  --work-dir DIR       Scratch directory for per-modset runs and dumps.
                       Default: ${TMPDIR:-/tmp/opencode}/muluna-science-discovery
  --require-baseline   Exit 1 if metallurgic, agricultural or electromagnetic
                       science pack is absent from any mod set.
  --json               Print one JSON object instead of the text table.
  -h, --help           Show this help.

Exit status:
  0  every mod set produced a valid discovery report
  1  a run failed, a dump or mod-data was missing, or a required baseline pack
     was absent
  2  usage error or missing helper files

Notes:
  - Legs are sequential. Each leg gets its own TMP_ROOT so the dump from one
    mod set is not overwritten by the next.
  - This script is local-only. It does not read tokens and must not be added to
    a GitHub workflow.
  - The per-leg logs and query results are kept in the work directory for
    inspection.

Examples:
  tools/ci/science-discovery-report.sh
  tools/ci/science-discovery-report.sh --modsets vanilla --json
  tools/ci/science-discovery-report.sh --modsets vanilla,planets --require-baseline
EOF
}

die() {
  echo "science-discovery-report.sh: $*" >&2
  echo "Try 'tools/ci/science-discovery-report.sh --help' for usage." >&2
  exit 2
}

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
      vanilla | aai | bz | k2so | no-quality | planets | muluna-start) ;;
      *) die "unknown modset: $item (expected vanilla, aai, bz, k2so, no-quality, planets or muluna-start)." ;;
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
    --work-dir)
      [[ $# -ge 2 ]] || die "--work-dir requires a directory."
      WORK_DIR="$2"
      shift 2
      ;;
    --work-dir=*)
      WORK_DIR="${1#*=}"
      shift
      ;;
    --require-baseline)
      REQUIRE_BASELINE=1
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
[[ -f "$PROTO_QUERY" ]] || die "prototype query helper not found: $PROTO_QUERY"
command -v python3 >/dev/null 2>&1 || die "python3 is required."

mkdir -p -- "$WORK_DIR/runs" "$WORK_DIR/logs" "$WORK_DIR/results" ||
  die "could not create $WORK_DIR."

for modset in "${MODSETS[@]}"; do
  run_dir="$WORK_DIR/runs/$modset"
  funit_out="$WORK_DIR/logs/$modset.funit.out"
  funit_err="$WORK_DIR/logs/$modset.funit.err"
  result_file="$WORK_DIR/results/$modset.json"

  if TMP_ROOT="$run_dir" "$FUNIT" --modset "$modset" --data-only --json \
    >"$funit_out" 2>"$funit_err"; then
    funit_rc=0
  else
    funit_rc=$?
  fi

  PROTO_QUERY="$PROTO_QUERY" python3 - \
    "$modset" "$funit_rc" "$funit_out" "$funit_err" "$result_file" <<'PY'
import json
import os
import subprocess
import sys

modset, funit_rc, funit_out, funit_err, result_file = sys.argv[1:]
funit_rc = int(funit_rc)
proto_query = os.environ["PROTO_QUERY"]

record = {
    "modset": modset,
    "funit_exit_code": funit_rc,
    "status": "failed",
    "error": None,
}

try:
    with open(funit_out, encoding="utf-8", errors="replace") as handle:
        lines = handle.read().splitlines()
except OSError as error:
    lines = []
    record["error"] = f"could not read FUnit output: {error}"

payload = None
for line in reversed(lines):
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

if payload:
    record["funit_status"] = payload.get("status")
    record["tests"] = payload.get("tests")
    record["failures"] = payload.get("failures")
    record["errors"] = payload.get("errors")
    dump = payload.get("dump")
    if dump:
        record["dump"] = dump
    else:
        record["error"] = "FUnit summary did not include a dump path"

if funit_rc != 0:
    record["error"] = record["error"] or f"FUnit exited {funit_rc}"

if not record.get("dump"):
    try:
        with open(funit_err, encoding="utf-8", errors="replace") as handle:
            stderr = handle.read().strip()
    except OSError:
        stderr = ""
    if stderr:
        record["funit_stderr"] = stderr
else:
    query = subprocess.run(
        [
            sys.executable,
            proto_query,
            "--dump",
            record["dump"],
            "exploration-science",
            "--json",
            "--rejected",
            "--legacy",
        ],
        capture_output=True,
        text=True,
    )
    if query.returncode != 0:
        record["error"] = "exploration-science query failed"
        record["query_stderr"] = query.stderr.strip()
    else:
        try:
            result = json.loads(query.stdout)
        except json.JSONDecodeError as error:
            record["error"] = f"could not parse query JSON: {error}"
        else:
            record.update(result)
            record["status"] = "passed" if funit_rc == 0 else "failed"

with open(result_file, "w", encoding="utf-8") as handle:
    json.dump(record, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
done

PROTO_QUERY="$PROTO_QUERY" python3 - \
  "$WORK_DIR" "$REQUIRE_BASELINE" "$JSON" "${MODSETS[@]}" <<'PY'
import json
import os
import sys

work_dir = sys.argv[1]
require_baseline = sys.argv[2] == "1"
as_json = sys.argv[3] == "1"
modsets = sys.argv[4:]
baseline = [
    "metallurgic-science-pack",
    "agricultural-science-pack",
    "electromagnetic-science-pack",
]

records = []
overall_ok = True
for modset in modsets:
    path = os.path.join(work_dir, "results", modset + ".json")
    try:
        with open(path, encoding="utf-8") as handle:
            record = json.load(handle)
    except (OSError, json.JSONDecodeError) as error:
        record = {
            "modset": modset,
            "status": "error",
            "error": f"could not read query result: {error}",
        }

    packs = record.get("packs") or []
    record["pack_count"] = len(packs)
    by_planet = {}
    for pack in packs:
        planet = pack.get("planet")
        item = pack.get("item") or pack.get("key")
        if planet and item:
            by_planet.setdefault(planet, []).append(item)
    record["packs_by_planet"] = by_planet
    record["legacy_only_keys"] = [
        pack.get("key") for pack in packs if pack.get("legacy")
    ]
    record["legacy_extras"] = record.get("legacy_extras") or []
    record["missing_legacy_technologies"] = record.get("missing_legacy_technologies") or []
    record["rejected_count"] = len(record.get("rejected_items") or [])
    missing_baseline = [
        name
        for name in baseline
        if not any(pack.get("item") == name or pack.get("key") == name for pack in packs)
    ]
    record["missing_baseline"] = missing_baseline

    if record.get("status") != "passed":
        overall_ok = False
    if require_baseline and missing_baseline:
        overall_ok = False
        record["status"] = "failed"

    records.append(record)

if as_json:
    print(
        json.dumps(
            {
                "status": "passed" if overall_ok else "failed",
                "require_baseline": require_baseline,
                "modsets": records,
            },
            separators=(",", ":"),
        )
    )
else:
    print("Science discovery report")
    print(
        "{:<11} {:>5} {:>5} {:>8} {:>14} {:>14} {:>10}".format(
            "modset", "packs", "req", "planets", "legacy extras", "missing legacy", "rejected"
        )
    )
    for record in records:
        by_planet = record.get("packs_by_planet") or {}
        planets = "; ".join(
            "{}={}".format(planet, ",".join(items))
            for planet, items in sorted(by_planet.items())
        ) or "none"
        print(
            "{:<11} {:>5} {:>5} {:>8} {:>14} {:>14} {:>10}".format(
                record["modset"],
                record.get("pack_count", 0),
                record.get("required_science_packs", "-"),
                len(by_planet),
                len(record.get("legacy_extras") or []),
                len(record.get("missing_legacy_technologies") or []),
                record.get("rejected_count", 0),
            )
        )
        print("  packs: " + planets)
        if record.get("legacy_extras"):
            print("  legacy extras: " + ", ".join(record["legacy_extras"]))
        if record.get("missing_legacy_technologies"):
            print(
                "  missing legacy: "
                + ", ".join(record["missing_legacy_technologies"])
            )
        if record.get("missing_baseline"):
            print("  missing baseline: " + ", ".join(record["missing_baseline"]))
        if record.get("error"):
            print("  error: " + str(record["error"]))
    print(f"work dir: {work_dir}")
    print(f"status: {'passed' if overall_ok else 'failed'}")

sys.exit(0 if overall_ok else 1)
PY
