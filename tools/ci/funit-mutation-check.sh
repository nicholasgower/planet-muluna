#!/usr/bin/env bash
# Prove that the data-stage FUnit fixtures can fail.
#
# This is a development helper for planet-muluna. It is not shipped with the mod.
#
# A fixture that cannot fail is not a test. This helper appends a temporary
# mutation block to test-mods/planet-muluna-funit/data.lua, runs
# `tools/ci/funit.sh --data-only`, and requires the run to fail with both
# expected fixture IDs in the log. data.lua is restored byte-for-byte on exit,
# including on failure and interrupt.
#
# Usage: tools/ci/funit-mutation-check.sh [OPTIONS]
# Run "tools/ci/funit-mutation-check.sh --help" for details.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

FUNIT="$REPO_DIR/tools/ci/funit.sh"
DATA_LUA="$REPO_DIR/test-mods/planet-muluna-funit/data.lua"
DATA_LUA_REL="test-mods/planet-muluna-funit/data.lua"

MUTATION_TMP_ROOT="${MUTATION_TMP_ROOT:-/tmp/opencode}"
LAST_RUN_DIR="$MUTATION_TMP_ROOT/muluna-funit-mutation-last"

MUTATION_BEGIN="-- BEGIN tools/ci/funit-mutation-check.sh mutation (temporary)"
MUTATION_END="-- END tools/ci/funit-mutation-check.sh mutation"

# "suite|check id". Keep in sync with the mutation block appended below.
EXPECTED_FIXTURES=(
  "prototype_integrity|icon-fields-valid"
  "content_references|muluna-recipes"
)

MODSET="${FUNIT_MODSET:-vanilla}"
TIMEOUT_VALUE="${TIMEOUT:-900}"
KEEP=0

# Run state used by the EXIT trap.
WORK_DIR=""
BACKUP=""
MUTATED=0
DATA_LUA_WAS_CLEAN=0
FUNIT_TMP=""
FUNIT_LOG=""
RUN_OUTPUT=""

usage() {
  cat <<'EOF'
Usage: tools/ci/funit-mutation-check.sh [OPTIONS]

Prove that the data-stage FUnit fixtures can fail by temporarily breaking two
prototypes and requiring the run to reject both.

The helper appends this block to test-mods/planet-muluna-funit/data.lua:

  an item with `icon = 123`
      -> prototype_integrity/icon-fields-valid must fail
  a muluna-* recipe whose ingredient does not exist
      -> content_references/muluna-recipes must fail

It then runs `tools/ci/funit.sh --data-only` and requires both:
  - the run to exit non-zero, and
  - the log to mention both expected fixture IDs.

data.lua is restored from a byte-for-byte backup on exit, including on failure
and on interrupt (SIGINT/SIGTERM).

Options:
  --modset NAME      Mod set passed to funit.sh: vanilla (default), aai, bz,
                     k2so, no-quality, planets or muluna-start.
  --timeout SECONDS  Maximum Factorio run time (default: 900, or $TIMEOUT).
  --keep             Do not restore data.lua. Prints a loud warning and the
                     backup path. Use only for debugging, and restore the file
                     before running anything else.
  -h, --help         Show this help.

Environment:
  FACTORIO_BIN       Factorio executable (inherited by funit.sh and run.sh).
  FACTORIO_MODS      Source mod directory (inherited by funit.sh and run.sh).
  FUNIT_MODSET       Default mod set; --modset wins.
  TIMEOUT            Default timeout in seconds; --timeout wins.
  MUTATION_TMP_ROOT  Scratch root for the backup and logs
                     (default: /tmp/opencode).

Exit status:
  0  the run failed and both expected fixtures were reported as failing
  1  the mutation check itself failed (the run passed, or a fixture ID is
     missing from the log)
  2  usage error, or the run could not be prepared (missing Factorio, an
     already-mutated data.lua, etc.)
  3  data.lua could not be restored byte-for-byte; restore it by hand now
EOF
}

die() {
  echo "funit-mutation-check.sh: $*" >&2
  echo "Try 'tools/ci/funit-mutation-check.sh --help' for usage." >&2
  exit 2
}

# ---------------------------------------------------------------------------
# data.lua mutation and restore
# ---------------------------------------------------------------------------

warn_kept_mutation() {
  cat >&2 <<EOF
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
WARNING: --keep left $DATA_LUA_REL MUTATED.
Do not commit it and do not run another FUnit command until it is restored.
  restore from the backup:
    cp -f -- '$BACKUP' '$DATA_LUA'
  or discard the mutation:
    git checkout -- $DATA_LUA_REL
The backup is kept at: $BACKUP
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
EOF
}

restore_data_lua() {
  if (( MUTATED == 0 )); then
    return 0
  fi

  if (( KEEP == 1 )); then
    warn_kept_mutation
    return 0
  fi

  if ! cp -f -- "$BACKUP" "$DATA_LUA"; then
    echo "funit-mutation-check.sh: ERROR: could not copy the backup back to $DATA_LUA_REL." >&2
    echo "  Restore it by hand from: $BACKUP" >&2
    return 1
  fi

  if ! cmp -s -- "$BACKUP" "$DATA_LUA"; then
    echo "funit-mutation-check.sh: ERROR: $DATA_LUA_REL does not match the backup after restore." >&2
    echo "  Restore it by hand from: $BACKUP" >&2
    return 1
  fi

  MUTATED=0
  echo "Restored $DATA_LUA_REL from the backup." >&2

  # If the file was clean before the run, git must agree after the restore.
  if (( DATA_LUA_WAS_CLEAN == 1 )) && command -v git >/dev/null 2>&1; then
    if ! git -C "$REPO_DIR" diff --exit-code -- "$DATA_LUA_REL" >/dev/null 2>&1; then
      echo "funit-mutation-check.sh: ERROR: git still reports changes in $DATA_LUA_REL after restore:" >&2
      git -C "$REPO_DIR" diff -- "$DATA_LUA_REL" >&2 || true
      return 1
    fi
  fi

  return 0
}

cleanup() {
  if (( KEEP == 0 )) && [[ -n "$WORK_DIR" ]]; then
    rm -rf -- "$WORK_DIR"
    WORK_DIR=""
  fi
}

on_exit() {
  local rc=$?
  trap - EXIT INT TERM

  if ! restore_data_lua; then
    rc=3
  fi
  cleanup
  exit "$rc"
}

trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

append_mutation() {
  MUTATED=1
  cat >>"$DATA_LUA" <<'LUA'

-- BEGIN tools/ci/funit-mutation-check.sh mutation (temporary)
-- Appended by tools/ci/funit-mutation-check.sh and removed automatically on
-- exit. Never commit this block. Both prototypes are deliberately broken so
-- the data-stage fixtures have something to reject:
--
--   muluna-funit-mutation-bad-icon
--     `icon` is a number instead of a file path string, which
--     prototype_integrity/icon-fields-valid must report.
--   muluna-funit-mutation-missing-ingredient
--     A muluna-* recipe whose ingredient does not exist, which
--     content_references/muluna-recipes must report.
data:extend({
  {
    type = "item",
    name = "muluna-funit-mutation-bad-icon",
    icon = 123,
    stack_size = 1,
  },
  {
    type = "recipe",
    name = "muluna-funit-mutation-missing-ingredient",
    enabled = false,
    ingredients = {
      { type = "item", name = "muluna-funit-mutation-nonexistent-item", amount = 1 },
    },
    results = {
      { type = "item", name = "iron-plate", amount = 1 },
    },
  },
})
-- END tools/ci/funit-mutation-check.sh mutation
LUA

  if ! { grep -qF -- "$MUTATION_BEGIN" "$DATA_LUA" && grep -qF -- "$MUTATION_END" "$DATA_LUA"; }; then
    die "the mutation block was not appended to $DATA_LUA_REL completely."
  fi
}

# ---------------------------------------------------------------------------
# Log inspection
# ---------------------------------------------------------------------------

# Match "suite/id" and the "[funit] data fixture suite / id" log form, where the
# slash is surrounded by spaces.
fixture_pattern() {
  local suite="$1" id="$2"
  printf '%s[[:space:]]*/[[:space:]]*%s' "$suite" "$id"
}

log_has() {
  local pattern="$1" file
  for file in "$FUNIT_LOG" "$RUN_OUTPUT"; do
    if [[ -f "$file" ]] && grep -aqE -- "$pattern" "$file"; then
      return 0
    fi
  done
  return 1
}

print_log_tail() {
  local file="$1" lines="${2:-40}"
  if [[ -f "$file" ]]; then
    echo "--- last $lines lines of $file ---" >&2
    tail -n "$lines" -- "$file" >&2 || true
  fi
}

preserve_logs() {
  mkdir -p -- "$LAST_RUN_DIR" 2>/dev/null || return 0
  if [[ -f "$FUNIT_LOG" ]]; then
    cp -f -- "$FUNIT_LOG" "$LAST_RUN_DIR/funit-stdout.log" 2>/dev/null || true
  fi
  if [[ -f "$RUN_OUTPUT" ]]; then
    cp -f -- "$RUN_OUTPUT" "$LAST_RUN_DIR/funit-run.log" 2>/dev/null || true
  fi
  echo "  logs kept: $LAST_RUN_DIR" >&2
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
    --modset)
      [[ $# -ge 2 ]] || die "--modset requires a NAME."
      MODSET="$2"
      shift 2
      ;;
    --modset=*)
      MODSET="${1#*=}"
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
    --keep)
      KEEP=1
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

case "$MODSET" in
  vanilla | aai | bz | k2so | no-quality | planets | muluna-start) ;;
  *) die "unknown --modset: $MODSET (expected vanilla, aai, bz, k2so, no-quality, planets or muluna-start)." ;;
esac

[[ -n "$TIMEOUT_VALUE" ]] || die "--timeout/TIMEOUT must not be empty."
[[ "$TIMEOUT_VALUE" =~ ^[0-9]+$ ]] || die "--timeout must be a whole number of seconds."
(( TIMEOUT_VALUE > 0 )) || die "--timeout must be greater than zero."

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------

[[ -f "$FUNIT" ]] || die "FUnit helper not found: $FUNIT"
[[ -x "$FUNIT" ]] || die "FUnit helper is not executable: $FUNIT"
[[ -f "$DATA_LUA" ]] || die "Fixture entry point not found: $DATA_LUA_REL"
[[ -w "$DATA_LUA" ]] || die "$DATA_LUA_REL is not writable; cannot append the mutation."

if grep -qF -- "$MUTATION_BEGIN" "$DATA_LUA"; then
  echo "funit-mutation-check.sh: $DATA_LUA_REL already contains the mutation block." >&2
  echo "  A previous --keep run probably left it behind. Restore the file first:" >&2
  echo "    git checkout -- $DATA_LUA_REL" >&2
  exit 2
fi

FACTORIO_BIN="${FACTORIO_BIN:-/opt/factorio_space_age_21/bin/x64/factorio}"
FACTORIO_MODS="${FACTORIO_MODS:-/opt/factorio_space_age_21/mods}"
[[ -x "$FACTORIO_BIN" ]] || die "Factorio binary not found or not executable: $FACTORIO_BIN (set FACTORIO_BIN)."
[[ -d "$FACTORIO_MODS" ]] || die "Factorio mod directory not found: $FACTORIO_MODS (set FACTORIO_MODS)."

# ---------------------------------------------------------------------------
# Prepare the mutation
# ---------------------------------------------------------------------------

mkdir -p -- "$MUTATION_TMP_ROOT" || die "Could not create the scratch root $MUTATION_TMP_ROOT."
WORK_DIR="$(mktemp -d "$MUTATION_TMP_ROOT/muluna-funit-mutation.XXXXXX")" ||
  die "Could not create a scratch directory under $MUTATION_TMP_ROOT."

BACKUP="$WORK_DIR/data.lua.orig"
cp -p -- "$DATA_LUA" "$BACKUP" || die "Could not back up $DATA_LUA_REL."

if command -v git >/dev/null 2>&1 &&
  git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git -C "$REPO_DIR" diff --quiet -- "$DATA_LUA_REL"; then
    DATA_LUA_WAS_CLEAN=1
  else
    echo "funit-mutation-check.sh: note: $DATA_LUA_REL already has uncommitted changes;" >&2
    echo "  the current contents are restored byte-for-byte." >&2
  fi
fi

FUNIT_TMP="$WORK_DIR/funit"
FUNIT_LOG="$FUNIT_TMP/stdout.log"
RUN_OUTPUT="$WORK_DIR/funit-run.log"

echo "funit-mutation-check.sh: proving the data-stage fixtures can fail" >&2
echo "  data.lua:  $DATA_LUA_REL (backup: $BACKUP)" >&2
echo "  modset:    $MODSET" >&2
echo "  timeout:   ${TIMEOUT_VALUE}s" >&2
echo "  expected failing fixtures:" >&2
for entry in "${EXPECTED_FIXTURES[@]}"; do
  printf '    - %s/%s\n' "${entry%%|*}" "${entry#*|}" >&2
done

append_mutation
echo "  mutation:  appended to $DATA_LUA_REL" >&2

# ---------------------------------------------------------------------------
# Run the data stage
# ---------------------------------------------------------------------------

echo "Running tools/ci/funit.sh --data-only --modset $MODSET ..." >&2

set +e
TMP_ROOT="$FUNIT_TMP" \
  "$FUNIT" --data-only --modset "$MODSET" --timeout "$TIMEOUT_VALUE" \
  >"$RUN_OUTPUT" 2>&1
RUN_EXIT=$?
set -e

echo "  funit.sh exit: $RUN_EXIT" >&2

# funit.sh reserves exit 2 for usage errors and runs it could not prepare, so a
# 2 never proves anything about the fixtures.
if (( RUN_EXIT == 2 )); then
  echo "funit-mutation-check.sh: funit.sh could not prepare the run (exit 2)." >&2
  print_log_tail "$RUN_OUTPUT" 40
  preserve_logs
  exit 2
fi

# ---------------------------------------------------------------------------
# Verdict
# ---------------------------------------------------------------------------

all_found=1
echo "Expected fixture results:" >&2
for entry in "${EXPECTED_FIXTURES[@]}"; do
  suite="${entry%%|*}"
  id="${entry#*|}"
  if log_has "$(fixture_pattern "$suite" "$id")"; then
    printf '  %-45s reported failing\n' "$suite/$id" >&2
  else
    printf '  %-45s MISSING\n' "$suite/$id" >&2
    all_found=0
  fi
done

if (( RUN_EXIT == 0 )); then
  echo "funit-mutation-check.sh: FAILED: the data-stage run passed with the mutation applied." >&2
  echo "  The mutated prototypes did not make any fixture fail, so at least one of" >&2
  echo "  these fixtures cannot detect the crash class it claims to cover." >&2
  echo "  Check that the 'planet-muluna-funit-enable-data-fixtures' startup setting" >&2
  echo "  is enabled (it defaults to true)." >&2
  print_log_tail "$FUNIT_LOG" 40
  print_log_tail "$RUN_OUTPUT" 40
  preserve_logs
  exit 1
fi

if (( all_found == 0 )); then
  echo "funit-mutation-check.sh: FAILED: the run failed, but not with both expected fixtures." >&2
  echo "  A failing run alone is not enough: it can also mean the mutation aborted" >&2
  echo "  the data stage before data-final-fixes ran the fixtures (for example if the" >&2
  echo "  engine rejects the mutated prototype at data:extend time), or that a fixture" >&2
  echo "  was renamed. Inspect the log below." >&2
  print_log_tail "$FUNIT_LOG" 60
  print_log_tail "$RUN_OUTPUT" 60
  preserve_logs
  exit 1
fi

echo "funit-mutation-check.sh: OK: the run failed and both expected fixtures reported failure." >&2
exit 0
