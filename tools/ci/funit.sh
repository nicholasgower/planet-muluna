#!/usr/bin/env bash
# Headless FUnit helper for planet-muluna.
#
# Runs the FUnit suite (optionally filtered to a single suite), parses the
# FUnit log, and prints a compact text or JSON summary. The filtered-manifest
# rewrite is always restored, including on failure or interrupt.
#
# Usage: tools/ci/funit.sh [OPTIONS]
# Run "tools/ci/funit.sh --help" for details.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

RUNNER="$REPO_DIR/test-mods/planet-muluna-funit/run.sh"
PROTO_QUERY="$REPO_DIR/tools/proto_query.py"
TESTS_DIR="$REPO_DIR/test-mods/planet-muluna-funit/tests"
MANIFEST="$TESTS_DIR/manifest.lua"
MANIFEST_REL="test-mods/planet-muluna-funit/tests/manifest.lua"

# FACTORIO_BIN/FACTORIO_MODS are local-development fallbacks. In GitHub
# Actions, .github/opencode/setup-factorio.sh downloads the headless build and
# writes the extracted paths to $GITHUB_ENV, so later steps (including this
# helper) inherit them. The ${VAR:-default} form below only uses the local path
# when the environment variable is absent. Remember whether each value came from
# the environment so run mode can fail clearly if CI forgot to set it; parse-only
# mode (--summary --no-run) does not need Factorio at all.
FACTORIO_BIN_FROM_ENV=0
FACTORIO_MODS_FROM_ENV=0
[[ -n "${FACTORIO_BIN:-}" ]] && FACTORIO_BIN_FROM_ENV=1
[[ -n "${FACTORIO_MODS:-}" ]] && FACTORIO_MODS_FROM_ENV=1
FACTORIO_BIN="${FACTORIO_BIN:-/opt/factorio_space_age_21/bin/x64/factorio}"
FACTORIO_MODS="${FACTORIO_MODS:-/opt/factorio_space_age_21/mods}"
TMP_ROOT="${TMP_ROOT:-/tmp/opencode/muluna-funit}"
TIMEOUT_VALUE="${TIMEOUT:-900}"

SUITE=""
TEST_FILTER=""
TEST_FILTER_SET=0
LOG_ARG=""
SUMMARY=0
NO_RUN=0
JSON=0
BASELINE=0
DATA_ONLY=0

# Parse state.
LOG=""
LOG_EXISTS=0
LOG_END=0
HAS_BEGIN=0
TESTS=0
SUCCESS=0
FAILURES=0
ERRORS=0
STATUS=""
RUNNER_EXIT=0
FAILING_IDS=()
MATCHED_RESULTS=()

SELECTED_SUITE=""

# Temporary-file state used by the EXIT trap.
BACKUP=""
RUN_OUTPUT=""
MANIFEST_TOUCHED=0
MANIFEST_WAS_CLEAN=0

usage() {
  cat <<'EOF'
Usage: tools/ci/funit.sh [OPTIONS]

Run the headless FUnit suite for planet-muluna and print a compact summary,
or parse an existing FUnit log without starting Factorio.

Options:
  --suite NAME       Run only one suite. NAME may be a suite basename
                     ("smoke"), a basename fragment ("tele"), or the
                     full require path
                     ("__planet-muluna-funit__.tests.suites.smoke").
                     The data_fixtures suite is always included because the
                     runtime suites depend on its fixtures. The manifest is
                     rewritten only for the run and restored afterwards.
  --test ID          Do not reduce execution time: the suite still runs in
                     full. Only the printed summary/results are filtered to
                     lines containing ID (case-sensitive substring match).
  --summary          Print the parsed summary. This is the default after a
                     run; combine with --no-run to parse an existing log.
  --log FILE         With --no-run, read FILE instead of
                     $TMP_ROOT/stdout.log. After a run, copy the run log to
                     FILE and summarize that copy.
  --no-run           Do not start Factorio; only parse an existing log.
  --timeout SECONDS  Maximum run time for one Factorio run (default: 900).
                     Passed to run.sh as TIMEOUT.
  --json             Print a single-line JSON summary instead of text.
  --baseline         Run the full suite and require it to pass; labels the
                     summary as a baseline. Cannot be combined with --suite
                     or --no-run.
  --data-only        Run only the data stage with --dump-data and summarize
                     the planet-muluna-funit results. This is much faster than
                     the runtime suite and is the right loop for prototype
                     fixtures. Cannot be combined with --suite, --test,
                     --baseline, or --no-run.
  -h, --help         Show this help.

Environment overrides:
  FACTORIO_BIN       Factorio executable. The /opt/... value is a local
                     development default only; GitHub Actions supplies the
                     extracted install path through $GITHUB_ENV.
  FACTORIO_MODS      Source mod directory. The /opt/... value is a local
                     development default only; GitHub Actions supplies it
                     through $GITHUB_ENV.
  TMP_ROOT           Runner scratch directory
                     (default: /tmp/opencode/muluna-funit)
  TIMEOUT            Maximum run time in seconds; --timeout wins.

Summary statuses:
  passed       log reached ====END==== with no FAILURE/ERROR lines
  failed       log reached ====END==== with FAILURE/ERROR lines
  incomplete   log did not reach ====END==== (timeout, crash, interrupt)
  missing-log  no log file was found (parse-only mode)
  error        run.sh failed and did not leave a usable passing log

Exit status:
  0  tests passed
  1  tests failed, the log is incomplete, or the runner failed
  2  usage error, missing log, or unable to prepare the run

Examples:
  tools/ci/funit.sh
  tools/ci/funit.sh --baseline --json
  tools/ci/funit.sh --data-only
  tools/ci/funit.sh --data-only --json
  tools/ci/funit.sh --suite smoke
  tools/ci/funit.sh --suite telescope --test "telescope probability"
  tools/ci/funit.sh --summary --no-run --log /tmp/opencode/muluna-funit/stdout.log
EOF
}

die() {
  echo "funit.sh: $*" >&2
  echo "Try 'tools/ci/funit.sh --help' for usage." >&2
  exit 2
}

json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

json_array() {
  local first=1 item
  printf '['
  for item in "$@"; do
    if (( first == 0 )); then
      printf ','
    fi
    printf '"%s"' "$(json_escape "$item")"
    first=0
  done
  printf ']'
}

# ---------------------------------------------------------------------------
# Manifest handling
# ---------------------------------------------------------------------------

restore_manifest() {
  local rc=0

  if [[ "$MANIFEST_TOUCHED" -eq 1 && -n "$BACKUP" ]]; then
    # Byte-for-byte restore from the pre-run backup.
    if ! cmp -s -- "$BACKUP" "$MANIFEST"; then
      cp -f -- "$BACKUP" "$MANIFEST"
    fi
    if ! cmp -s -- "$BACKUP" "$MANIFEST"; then
      echo "funit.sh: ERROR: failed to restore $MANIFEST byte-for-byte." >&2
      rc=1
    fi
    rm -f -- "$BACKUP"
    BACKUP=""
    MANIFEST_TOUCHED=0

    # Explicit post-restore verification requested by the workflow docs.
    if command -v git >/dev/null 2>&1 &&
      git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      if ! git -C "$REPO_DIR" diff --exit-code -- "$MANIFEST_REL" >/dev/null 2>&1; then
        if [[ "$MANIFEST_WAS_CLEAN" -eq 1 ]]; then
          echo "funit.sh: ERROR: git diff still reports changes in $MANIFEST_REL after restoration:" >&2
          git -C "$REPO_DIR" diff -- "$MANIFEST_REL" >&2 || true
          rc=1
        else
          echo "funit.sh: note: $MANIFEST_REL was already modified before this run; the" >&2
          echo "          pre-run contents were restored byte-for-byte." >&2
        fi
      fi
    fi
  fi

  return "$rc"
}

cleanup() {
  if [[ -n "$BACKUP" ]]; then
    rm -f -- "$BACKUP"
    BACKUP=""
  fi
  if [[ -n "$RUN_OUTPUT" ]]; then
    rm -f -- "$RUN_OUTPUT"
    RUN_OUTPUT=""
  fi
}

on_exit() {
  local rc=$?
  trap - EXIT INT TERM
  if ! restore_manifest; then
    rc=1
  fi
  cleanup
  exit "$rc"
}

trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

prepare_manifest() {
  local selected="$1"

  MANIFEST_WAS_CLEAN=0
  if command -v git >/dev/null 2>&1 &&
    git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git -C "$REPO_DIR" diff --quiet -- "$MANIFEST_REL"; then
      MANIFEST_WAS_CLEAN=1
    fi
  fi

  BACKUP="$(mktemp "${TMPDIR:-/tmp}/muluna-funit-manifest.XXXXXX")" ||
    die "Could not create a manifest backup file."
  cp -f -- "$MANIFEST" "$BACKUP" || die "Could not back up $MANIFEST."
  MANIFEST_TOUCHED=1

  {
    printf '%s\n' "-- Temporary filtered manifest generated by tools/ci/funit.sh."
    printf '%s\n' "-- The original file is restored automatically on exit."
    printf '%s\n' "return {"
    printf '  "%s",\n' "__planet-muluna-funit__.tests.suites.data_fixtures"
    if [[ "$selected" != "__planet-muluna-funit__.tests.suites.data_fixtures" ]]; then
      printf '  "%s",\n' "$selected"
    fi
    printf '%s\n' "}"
  } >"$MANIFEST"
}

# Resolve --suite to a single require path. Prints a clear error and returns 1
# when there is no match or the name is ambiguous.
resolve_suite() {
  local raw="$1"
  local q="$1"
  local f base
  local -a available=()
  local -a exact=()
  local -a partial=()

  q="${q%.lua}"
  q="${q##*/}"
  # A full require path ends in ".suite"; use its basename component.
  if [[ "$q" == *.* ]]; then
    q="${q##*.}"
  fi

  if [[ -z "$q" ]]; then
    echo "funit.sh: --suite requires a non-empty suite name." >&2
    return 1
  fi

  for f in "$TESTS_DIR"/suites/*.lua; do
    [[ -e "$f" ]] || continue
    base="$(basename "$f" .lua)"
    available+=("$base")
    if [[ "$raw" == "__planet-muluna-funit__.tests.suites.$base" ||
      "$raw" == "$base" ||
      "$raw" == "$base.lua" ||
      "$q" == "$base" ]]; then
      exact+=("__planet-muluna-funit__.tests.suites.$base")
    elif [[ "$base" == *"$q"* ]]; then
      partial+=("__planet-muluna-funit__.tests.suites.$base")
    fi
  done

  if (( ${#exact[@]} == 1 )); then
    SELECTED_SUITE="${exact[0]}"
    return 0
  fi
  if (( ${#exact[@]} > 1 )); then
    echo "funit.sh: suite name '$raw' is ambiguous; it matches:" >&2
    printf '  %s\n' "${exact[@]}" >&2
    return 1
  fi
  if (( ${#partial[@]} == 0 )); then
    echo "funit.sh: no FUnit suite matches '$raw'." >&2
    echo "Available suites: ${available[*]}" >&2
    return 1
  fi
  if (( ${#partial[@]} > 1 )); then
    echo "funit.sh: suite name '$raw' is ambiguous; it matches:" >&2
    printf '  %s\n' "${partial[@]}" >&2
    echo "Use an exact suite name to disambiguate." >&2
    return 1
  fi

  SELECTED_SUITE="${partial[0]}"
  return 0
}

# ---------------------------------------------------------------------------
# Log parsing
# ---------------------------------------------------------------------------

parse_log() {
  local log="$1"
  local begin_line line id

  TESTS=0
  SUCCESS=0
  FAILURES=0
  ERRORS=0
  LOG_END=0
  HAS_BEGIN=0
  FAILING_IDS=()

  if [[ ! -f "$log" || ! -r "$log" ]]; then
    LOG_EXISTS=0
    return 0
  fi
  LOG_EXISTS=1

  if grep -aqE '__FUNIT__[^[:space:]]*====END====' "$log"; then
    LOG_END=1
  fi

  begin_line="$(grep -aoE '__FUNIT__[^[:space:]]*====BEGIN [0-9]+ TESTS====' "$log" | tail -n 1 || true)"
  if [[ -n "$begin_line" ]]; then
    HAS_BEGIN=1
    TESTS="$(sed -E 's/.*====BEGIN ([0-9]+) TESTS====/\1/' <<<"$begin_line")"
  fi

  SUCCESS="$(grep -acE '__FUNIT__[^[:space:]]*__SUCCESS__' "$log" || true)"
  FAILURES="$(grep -acE '__FUNIT__[^[:space:]]*__FAILURE__' "$log" || true)"
  ERRORS="$(grep -acE '__FUNIT__[^[:space:]]*__ERROR__' "$log" || true)"
  SUCCESS="${SUCCESS:-0}"
  FAILURES="${FAILURES:-0}"
  ERRORS="${ERRORS:-0}"

  if (( HAS_BEGIN == 0 )); then
    TESTS=$((SUCCESS + FAILURES + ERRORS))
  fi

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    id="$(printf '%s\n' "$line" | sed -E 's/^.*__FUNIT__[^[:space:]]*__(FAILURE|ERROR)__//')"
    id="${id%$'\r'}"
    [[ -n "$id" ]] || id="(unnamed)"
    FAILING_IDS+=("$id")
  done < <(grep -aE '__FUNIT__[^[:space:]]*__(FAILURE|ERROR)__' "$log" || true)

  return 0
}

collect_matches() {
  local line label

  MATCHED_RESULTS=()
  [[ -n "$TEST_FILTER" ]] || return 0
  [[ "$LOG_EXISTS" -eq 1 ]] || return 0

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    label="$(printf '%s\n' "$line" | sed -E 's/^.*__FUNIT__[^[:space:]]*__//')"
    label="${label%$'\r'}"
    label="$(sed -E 's/^(SUCCESS|FAILURE|ERROR)__/\1 /' <<<"$label")"
    MATCHED_RESULTS+=("$label")
  done < <(grep -aF -- "$TEST_FILTER" "$LOG" 2>/dev/null | grep -aE '__FUNIT__' || true)

  return 0
}

compute_status() {
  if [[ "$LOG_EXISTS" -eq 0 ]]; then
    STATUS="missing-log"
    return 0
  fi
  if [[ "$LOG_END" -eq 0 || "$HAS_BEGIN" -eq 0 ]]; then
    STATUS="incomplete"
    return 0
  fi
  if (( FAILURES + ERRORS > 0 )); then
    STATUS="failed"
    return 0
  fi
  if (( SUCCESS != TESTS )); then
    STATUS="incomplete"
    return 0
  fi
  STATUS="passed"
  return 0
}

status_message() {
  case "$STATUS" in
    passed)
      printf '%s\n' "FUnit passed."
      ;;
    failed)
      printf 'FUnit reported %d failure(s) and %d error(s).\n' "$FAILURES" "$ERRORS"
      ;;
    incomplete)
      printf '%s\n' "FUnit never reached ====END====; the run timed out, crashed, or was interrupted."
      ;;
    missing-log)
      printf 'No FUnit log found at %s.\n' "$LOG"
      ;;
    error)
      printf 'The FUnit runner failed (run.sh exit %d) and did not leave a usable passing log.\n' "$RUNNER_EXIT"
      ;;
    *)
      printf 'FUnit status: %s\n' "$STATUS"
      ;;
  esac
}

print_summary() {
  local id label

  if (( BASELINE == 1 )); then
    echo "FUnit summary (baseline)"
  else
    echo "FUnit summary"
  fi
  printf '  %-10s %s\n' "status:" "$STATUS"
  printf '  %-10s %s\n' "tests:" "$TESTS"
  printf '  %-10s %s\n' "success:" "$SUCCESS"
  printf '  %-10s %s\n' "failures:" "$FAILURES"
  printf '  %-10s %s\n' "errors:" "$ERRORS"
  if [[ -n "$SUITE" ]]; then
    printf '  %-10s %s (filtered manifest: data_fixtures + %s)\n' \
      "suite:" "$SUITE" "$(basename "${SELECTED_SUITE##*.}")"
  fi
  if (( RUNNER_EXIT != 0 )) && [[ "$STATUS" != "passed" ]]; then
    printf '  %-10s %s\n' "runner:" "run.sh exited $RUNNER_EXIT"
  fi
  printf '  %-10s %s\n' "log:" "$LOG"

  if (( ${#FAILING_IDS[@]} > 0 )); then
    echo "  failing tests:"
    for id in "${FAILING_IDS[@]}"; do
      printf '    - %s\n' "$id"
    done
  fi

  if [[ -n "$TEST_FILTER" ]]; then
    printf '  %-10s %s (%d match(es))\n' "filter:" "$TEST_FILTER" "${#MATCHED_RESULTS[@]}"
    if (( ${#MATCHED_RESULTS[@]} == 0 )); then
      echo "    (no result lines mention this ID)"
    else
      for label in "${MATCHED_RESULTS[@]}"; do
        printf '    - %s\n' "$label"
      done
    fi
  fi
}

print_json() {
  printf '{"status":"%s","tests":%d,"success":%d,"failures":%d,"errors":%d' \
    "$(json_escape "$STATUS")" "$TESTS" "$SUCCESS" "$FAILURES" "$ERRORS"
  printf ',"failing_test_ids":'
  json_array "${FAILING_IDS[@]+"${FAILING_IDS[@]}"}"
  printf ',"log":"%s"' "$(json_escape "$LOG")"

  if [[ -n "$SUITE" ]]; then
    printf ',"suite":"%s"' "$(json_escape "$SUITE")"
    printf ',"filtered":true'
  fi
  if [[ -n "$TEST_FILTER" ]]; then
    printf ',"filter":"%s"' "$(json_escape "$TEST_FILTER")"
    printf ',"matched_results":'
    json_array "${MATCHED_RESULTS[@]+"${MATCHED_RESULTS[@]}"}"
  fi
  if (( BASELINE == 1 )); then
    printf ',"baseline":true'
  fi
  if (( RUNNER_EXIT != 0 )); then
    printf ',"runner_exit":%d' "$RUNNER_EXIT"
  fi
  printf '}\n'
}

print_diagnostics() {
  if [[ "$LOG_EXISTS" -eq 0 ]]; then
    status_message >&2
    return 0
  fi

  status_message >&2
  if [[ "$STATUS" == "incomplete" ]]; then
    echo "funit.sh: last relevant log lines from $LOG:" >&2
    grep -aE '__FUNIT__|Error|error|FAILURE|ERROR|Timeout|timeout' "$LOG" 2>/dev/null |
      tail -n 20 >&2 || true
  fi

  return 0
}

report() {
  if (( JSON == 1 )); then
    print_json
  else
    print_summary
  fi

  if [[ "$STATUS" != "passed" ]]; then
    print_diagnostics
  fi

  # A --test filter that matches nothing is almost always a typo; say so, but
  # keep the suite result as the authoritative exit status.
  if [[ -n "$TEST_FILTER" ]] && (( ${#MATCHED_RESULTS[@]} == 0 )); then
    echo "funit.sh: warning: no FUnit result line mentions '$TEST_FILTER'." >&2
  fi

  case "$STATUS" in
    passed) return 0 ;;
    missing-log) return 2 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

while (($# > 0)); do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --suite)
      [[ $# -ge 2 ]] || die "--suite requires a NAME."
      SUITE="$2"
      shift 2
      ;;
    --suite=*)
      SUITE="${1#*=}"
      shift
      ;;
    --test)
      [[ $# -ge 2 ]] || die "--test requires an ID."
      TEST_FILTER="$2"
      TEST_FILTER_SET=1
      shift 2
      ;;
    --test=*)
      TEST_FILTER="${1#*=}"
      TEST_FILTER_SET=1
      shift
      ;;
    --log)
      [[ $# -ge 2 ]] || die "--log requires a FILE."
      LOG_ARG="$2"
      shift 2
      ;;
    --log=*)
      LOG_ARG="${1#*=}"
      shift
      ;;
    --timeout)
      [[ $# -ge 2 ]] || die "--timeout requires SECONDS."
      TIMEOUT_VALUE="$2"
      shift 2
      ;;
    --timeout=*)
      TIMEOUT_VALUE="${1#*=}"
      shift
      ;;
    --summary)
      SUMMARY=1
      shift
      ;;
    --no-run)
      NO_RUN=1
      shift
      ;;
    --json)
      JSON=1
      shift
      ;;
    --baseline)
      BASELINE=1
      shift
      ;;
    --data-only)
      DATA_ONLY=1
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

[[ -n "$TIMEOUT_VALUE" ]] || die "--timeout/TIMEOUT must not be empty."
[[ "$TIMEOUT_VALUE" =~ ^[0-9]+$ ]] || die "--timeout must be a whole number of seconds."
(( TIMEOUT_VALUE > 0 )) || die "--timeout must be greater than zero."

if (( BASELINE == 1 )) && [[ -n "$SUITE" ]]; then
  die "--baseline runs the full suite and cannot be combined with --suite."
fi

if (( BASELINE == 1 )) && (( NO_RUN == 1 )); then
  die "--baseline requires a run and cannot be combined with --no-run."
fi

if (( NO_RUN == 1 )) && [[ -n "$SUITE" ]]; then
  die "--suite requires a run and cannot be combined with --no-run."
fi

if (( DATA_ONLY == 1 )); then
  (( NO_RUN == 0 )) || die "--data-only requires a run and cannot be combined with --no-run."
  (( BASELINE == 0 )) || die "--data-only cannot be combined with --baseline."
  [[ -z "$SUITE" ]] || die "--data-only cannot be combined with --suite."
  (( TEST_FILTER_SET == 0 )) || die "--data-only cannot be combined with --test."
fi

[[ -z "$SUITE" ]] || resolve_suite "$SUITE" || exit 2
if (( TEST_FILTER_SET == 1 )) && [[ -z "$TEST_FILTER" ]]; then
  die "--test requires a non-empty ID."
fi

# ---------------------------------------------------------------------------
# Parse-only mode
# ---------------------------------------------------------------------------

if (( NO_RUN == 1 )); then
  LOG="${LOG_ARG:-$TMP_ROOT/stdout.log}"
  parse_log "$LOG"
  compute_status
  collect_matches
  rc=0
  report || rc=$?
  exit "$rc"
fi

# A real run needs Factorio. In CI, setup-factorio.sh must have exported the
# paths through $GITHUB_ENV; refuse to fall back to the local development paths,
# which do not exist on a GitHub-hosted runner.
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  (( FACTORIO_BIN_FROM_ENV == 1 )) ||
    die "GitHub Actions did not set FACTORIO_BIN; run .github/opencode/setup-factorio.sh first."
  (( FACTORIO_MODS_FROM_ENV == 1 )) ||
    die "GitHub Actions did not set FACTORIO_MODS; run .github/opencode/setup-factorio.sh first."
fi

# ---------------------------------------------------------------------------
# Run mode
# ---------------------------------------------------------------------------

[[ -f "$RUNNER" ]] || die "FUnit runner not found: $RUNNER"
[[ -x "$RUNNER" ]] || die "FUnit runner is not executable: $RUNNER"
[[ -x "$FACTORIO_BIN" ]] || die "Factorio binary not found or not executable: $FACTORIO_BIN"
[[ -d "$FACTORIO_MODS" ]] || die "Factorio mod directory not found: $FACTORIO_MODS"
[[ -f "$PROTO_QUERY" ]] || die "Prototype query helper not found: $PROTO_QUERY"

if (( DATA_ONLY == 1 )); then
  RUN_OUTPUT="$(mktemp "${TMPDIR:-/tmp}/muluna-funit-data.XXXXXX")" ||
    die "Could not create a temporary file for the data-probe output."

  echo "Running Muluna data-stage fixtures (timeout ${TIMEOUT_VALUE}s)..." >&2
  echo "  binary: $FACTORIO_BIN" >&2
  echo "  mods:   $FACTORIO_MODS" >&2
  echo "  tmp:    $TMP_ROOT" >&2

  set +e
  DATA_ONLY=1 \
    FACTORIO_BIN="$FACTORIO_BIN" \
    FACTORIO_MODS="$FACTORIO_MODS" \
    TMP_ROOT="$TMP_ROOT" \
    TIMEOUT="$TIMEOUT_VALUE" \
    "$RUNNER" 2>&1 | tee "$RUN_OUTPUT" >&2
  RUNNER_EXIT=${PIPESTATUS[0]}
  set -e

  RUN_LOG="$TMP_ROOT/stdout.log"
  DUMP="$TMP_ROOT/write-data/script-output/data-raw-dump.json"
  if [[ -n "$LOG_ARG" && -f "$RUN_LOG" && "$LOG_ARG" != "$RUN_LOG" ]]; then
    mkdir -p -- "$(dirname -- "$LOG_ARG")"
    cp -f -- "$RUN_LOG" "$LOG_ARG" || die "Could not copy $RUN_LOG to $LOG_ARG."
    LOG="$LOG_ARG"
  elif [[ -n "$LOG_ARG" ]]; then
    LOG="$LOG_ARG"
  else
    LOG="$RUN_LOG"
  fi

  if (( RUNNER_EXIT != 0 )) && [[ ! -f "$DUMP" ]]; then
    echo "funit.sh: data-stage run failed and produced no prototype dump (see $RUN_LOG)." >&2
    tail -n 40 "$RUN_LOG" >&2 || true
    exit 1
  fi

  QUERY_ARGS=(
    python3 "$PROTO_QUERY"
    --dump "$DUMP"
    funit-results
    --log "$LOG"
  )
  if (( JSON == 1 )); then
    QUERY_ARGS+=(--json)
  fi

  set +e
  "${QUERY_ARGS[@]}"
  QUERY_EXIT=$?
  set -e

  if (( RUNNER_EXIT != 0 && QUERY_EXIT == 0 )); then
    echo "funit.sh: data-stage dump exists but run.sh exited $RUNNER_EXIT." >&2
    exit 1
  fi
  exit "$QUERY_EXIT"
fi

if [[ -n "$SUITE" ]]; then
  prepare_manifest "$SELECTED_SUITE"
  echo "Filtered suite: $SUITE ($SELECTED_SUITE)" >&2
  echo "  manifest: data_fixtures + selected suite (restored on exit)" >&2
fi

RUN_OUTPUT="$(mktemp "${TMPDIR:-/tmp}/muluna-funit-run.XXXXXX")" ||
  die "Could not create a temporary file for runner output."

echo "Running Muluna FUnit suite (timeout ${TIMEOUT_VALUE}s)..." >&2
echo "  binary: $FACTORIO_BIN" >&2
echo "  mods:   $FACTORIO_MODS" >&2
echo "  tmp:    $TMP_ROOT" >&2

set +e
FACTORIO_BIN="$FACTORIO_BIN" \
  FACTORIO_MODS="$FACTORIO_MODS" \
  TMP_ROOT="$TMP_ROOT" \
  TIMEOUT="$TIMEOUT_VALUE" \
  "$RUNNER" 2>&1 | tee "$RUN_OUTPUT" >&2
RUNNER_EXIT=${PIPESTATUS[0]}
set -e

RUN_LOG="$TMP_ROOT/stdout.log"
if [[ -n "$LOG_ARG" ]]; then
  if [[ -f "$RUN_LOG" ]]; then
    if [[ "$LOG_ARG" != "$RUN_LOG" ]]; then
      mkdir -p -- "$(dirname -- "$LOG_ARG")"
      if ! cp -f -- "$RUN_LOG" "$LOG_ARG"; then
        echo "funit.sh: could not copy $RUN_LOG to $LOG_ARG." >&2
        exit 2
      fi
    fi
    LOG="$LOG_ARG"
  else
    LOG="$LOG_ARG"
  fi
else
  LOG="$RUN_LOG"
fi

parse_log "$LOG"
compute_status

# A failing run.sh with a passing log means the runner broke (for example
# after printing ====END====). A failing run.sh with no log at all is also a
# runner error, not a missing-input usage error.
if (( RUNNER_EXIT != 0 )) && [[ "$STATUS" == "passed" || "$STATUS" == "missing-log" ]]; then
  STATUS="error"
fi

collect_matches

if (( RUNNER_EXIT != 0 )); then
  echo "funit.sh: run.sh exited with status $RUNNER_EXIT (see $LOG)." >&2
  if [[ "$STATUS" == "incomplete" || "$STATUS" == "missing-log" ]]; then
    echo "funit.sh: the FUnit log did not reach ====END====; treating this as a timeout or runner failure." >&2
  fi
fi

rc=0
report || rc=$?
exit "$rc"
