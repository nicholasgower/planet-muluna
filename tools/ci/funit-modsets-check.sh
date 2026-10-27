#!/usr/bin/env bash
# Check that the FUnit mod-set definitions agree across every source of truth.
#
# This is a development helper for planet-muluna. It is not shipped with the mod.
#
# Usage:
#   tools/ci/funit-modsets-check.sh
#   tools/ci/funit-modsets-check.sh --json
#   tools/ci/funit-modsets-check.sh --require-missing NAME
#
# The checker compares the modset names in:
#   - MODSETS in .github/funit/download_mods.py (imported with importlib);
#   - the FUNIT_MODSET names accepted by test-mods/planet-muluna-funit/run.sh,
#     plus the per-modset link and MOD_NAMES blocks that load the added mods;
#   - the modset legs of the unit-test-job and parse-results-job matrices in
#     .github/workflows/funit.yml.
#
# Every non-vanilla modset except no-quality needs a link block and a MOD_NAMES
# block in run.sh; no-quality only disables quality, so it has no add block.
# Both workflow matrices must contain the same modsets as the other sources and
# len(modsets) * 2 legs (one per release channel: stable and experimental).
#
# `--require-missing NAME` adds NAME to the expected set. Use a name that is
# intentionally absent; the checker must report it missing and exit 1. This is
# the negative self-test that proves the drift detector works.
#
# Exit status:
#   0  every source agrees
#   1  drift detected, or the --require-missing self-test failed as intended
#   2  usage error (including a missing python3)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)" ||
  {
    echo "funit-modsets-check.sh: not inside a git work tree: $SCRIPT_DIR" >&2
    exit 2
  }

JSON_OUTPUT=0
REQUIRE_MISSING_NAMES=()

usage() {
  sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

die() {
  echo "funit-modsets-check.sh: $*" >&2
  echo "Try 'tools/ci/funit-modsets-check.sh --help' for usage." >&2
  exit 2
}

while (($# > 0)); do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --json)
      JSON_OUTPUT=1
      shift
      ;;
    --require-missing)
      [ "$#" -ge 2 ] || die "--require-missing requires a NAME"
      [ -n "$2" ] || die "--require-missing requires a non-empty NAME"
      REQUIRE_MISSING_NAMES+=("$2")
      shift 2
      ;;
    --require-missing=*)
      [ -n "${1#*=}" ] || die "--require-missing requires a non-empty NAME"
      REQUIRE_MISSING_NAMES+=("${1#*=}")
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
[ "$#" -eq 0 ] || die "unexpected argument: $1"

command -v python3 >/dev/null 2>&1 || die "python3 is required but was not found on PATH"

# One name per line keeps names with punctuation intact; the parser ignores
# blank lines.
REQUIRE_MISSING=""
if ((${#REQUIRE_MISSING_NAMES[@]} > 0)); then
  REQUIRE_MISSING="$(printf '%s\n' "${REQUIRE_MISSING_NAMES[@]}")"
fi

REPO_DIR="$REPO_DIR" JSON_OUTPUT="$JSON_OUTPUT" REQUIRE_MISSING="$REQUIRE_MISSING" \
  exec python3 - <<'PY'
import importlib.util
import json
import os
import re
import sys
from pathlib import Path

REPO = Path(os.environ["REPO_DIR"])
JSON_OUTPUT = os.environ["JSON_OUTPUT"] == "1"
REQUIRE_MISSING = [
    name.strip()
    for name in os.environ.get("REQUIRE_MISSING", "").splitlines()
    if name.strip()
]

MODSETS_PATH = REPO / ".github" / "funit" / "download_mods.py"
RUNNER_PATH = REPO / "test-mods" / "planet-muluna-funit" / "run.sh"
WORKFLOW_PATH = REPO / ".github" / "workflows" / "funit.yml"

# Modsets that legitimately have no add block in run.sh: vanilla adds nothing
# and no-quality only disables the quality mod.
NO_ADD_BLOCK = {"vanilla", "no-quality"}

CHECKS = []
DIFFERENCES = []


def rel(path):
    try:
        return str(path.relative_to(REPO))
    except ValueError:
        return str(path)


def read(path):
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return None


def add(name, status, detail):
    CHECKS.append({"name": name, "status": status, "detail": detail})
    if status != "PASS":
        DIFFERENCES.append("%s: %s" % (name, detail))


def names(values):
    values = sorted(values)
    return ", ".join(values) if values else "(none)"


def indent_of(line):
    return len(line) - len(line.lstrip())


# ---------------------------------------------------------------------------
# Sources
# ---------------------------------------------------------------------------


def load_modsets(path):
    """Import MODSETS from download_mods.py so nested dicts need no parsing."""
    if not path.is_file():
        return {}, "%s is missing" % rel(path)
    try:
        spec = importlib.util.spec_from_file_location(
            "muluna_funit_download_mods", path
        )
        if spec is None or spec.loader is None:
            raise ImportError("no import loader available")
        module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = module
        spec.loader.exec_module(module)
    except Exception as exc:  # report any import failure as drift, not a traceback
        return {}, "could not import %s: %s: %s" % (rel(path), type(exc).__name__, exc)

    raw = getattr(module, "MODSETS", None)
    if not isinstance(raw, dict) or not raw:
        return {}, "%s does not define a non-empty MODSETS dict" % rel(path)
    return {str(key): value for key, value in raw.items()}, None


def parse_run_case(text):
    """Return the modset names in run.sh's case "$FUNIT_MODSET" block."""
    match = re.search(
        r'^\s*case\s+["\']?\$FUNIT_MODSET["\']?\s+in\b(.*?)^\s*esac\b',
        text,
        re.S | re.M,
    )
    if not match:
        return None

    found = []
    for line in match.group(1).splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or ")" not in stripped:
            continue
        pattern = stripped.split(")", 1)[0].strip()
        # The catch-all alternative starts the error branch; stop there so the
        # error message text is never mistaken for an accepted name.
        if "*" in pattern:
            break
        if not pattern or any(char in pattern for char in '"\'$('):
            continue
        for alternative in pattern.split("|"):
            alternative = alternative.strip().strip("\"'")
            if re.fullmatch(r"[A-Za-z0-9_.-]+", alternative):
                found.append(alternative)
    return found


RUN_IF = re.compile(
    r'^\s*if\s+\[\[\s*["\']?\$FUNIT_MODSET["\']?\s*==\s*["\']([^"\']+)["\']'
)
LINK_CALL = re.compile(r"\blink_(?:mod|zip|mod_or_zip)\b")


def parse_run_blocks(text):
    """Return {modset: {"link": n, "mod_names": n, "other": n}} for run.sh.

    Each `if [[ "$FUNIT_MODSET" == "NAME" ]]; then ... fi` block is classified
    by whether it links dependency mods, extends MOD_NAMES, or does neither.
    """
    lines = text.splitlines()
    blocks = {}
    index = 0
    while index < len(lines):
        match = RUN_IF.match(lines[index])
        if not match:
            index += 1
            continue

        name = match.group(1)
        cursor = index
        while cursor < len(lines) and not re.search(r"\bthen\b", lines[cursor]):
            cursor += 1
        if cursor >= len(lines):
            break

        body = []
        cursor += 1
        while cursor < len(lines) and lines[cursor].strip() != "fi":
            body.append(lines[cursor])
            cursor += 1
        body_text = "\n".join(body)

        has_link = bool(LINK_CALL.search(body_text))
        has_names = "MOD_NAMES+=" in body_text
        counts = blocks.setdefault(name, {"link": 0, "mod_names": 0, "other": 0})
        counts["link"] += int(has_link)
        counts["mod_names"] += int(has_names)
        if not has_link and not has_names:
            counts["other"] += 1

        index = cursor + 1
    return blocks


def find_job_section(text, job):
    """Return the YAML text of one top-level job, or None."""
    match = re.search(r"^  %s:\s*$" % re.escape(job), text, re.M)
    if not match:
        return None
    rest = text[match.end():]
    following = re.search(r"^  [A-Za-z0-9_.-]+:\s*$", rest, re.M)
    return rest[: following.start()] if following else rest


def yaml_scalar(value):
    value = re.sub(r"\s+#.*$", "", value.strip())
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def parse_matrix(section):
    """Return the matrix include legs as a list of dicts, or None.

    This is a deliberately small parser for the workflow's include-list shape:

        matrix:
          include:
            - channel: stable
              modset: vanilla

    It does not handle axis-style matrices (`modset: [a, b]`).
    """
    if section is None:
        return None

    lines = section.splitlines()
    matrix_index = None
    for position, line in enumerate(lines):
        if re.match(r"^\s*matrix:\s*$", line):
            matrix_index = position
            break
    if matrix_index is None:
        return None

    include_index = None
    for position in range(matrix_index + 1, len(lines)):
        line = lines[position]
        if re.match(r"^\s*include:\s*$", line):
            include_index = position
            break
        if (
            re.match(r"^\s*[A-Za-z0-9_.-]+:\s*$", line)
            and indent_of(line) <= indent_of(lines[matrix_index])
        ):
            break
    if include_index is None:
        return None

    legs = []
    entry_indent = None
    current = None
    for line in lines[include_index + 1:]:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        indent = indent_of(line)
        item = re.match(r"^(\s*)-\s+(.*)$", line)
        if item and (entry_indent is None or indent == entry_indent):
            entry_indent = indent
            current = {}
            legs.append(current)
            key_match = re.match(r"([A-Za-z0-9_.-]+):\s*(.*)$", item.group(2))
            if key_match:
                current[key_match.group(1)] = yaml_scalar(key_match.group(2))
            continue

        if entry_indent is not None and indent <= entry_indent:
            break

        if current is not None:
            key_match = re.match(r"([A-Za-z0-9_.-]+):\s*(.*)$", stripped)
            if key_match:
                current[key_match.group(1)] = yaml_scalar(key_match.group(2))
    return legs


def channel_counts(legs):
    counts = {}
    for leg in legs:
        channel = leg.get("channel") or "?"
        counts[channel] = counts.get(channel, 0) + 1
    return ", ".join("%s=%d" % item for item in sorted(counts.items()))


# ---------------------------------------------------------------------------
# Collect every source
# ---------------------------------------------------------------------------

modsets, modsets_error = load_modsets(MODSETS_PATH)

runner_text = read(RUNNER_PATH)
if runner_text is None:
    run_case = set()
    run_case_error = "%s is missing" % rel(RUNNER_PATH)
    run_blocks = {}
else:
    parsed_case = parse_run_case(runner_text)
    if parsed_case is None:
        run_case = set()
        run_case_error = (
            'could not find case "$FUNIT_MODSET" in ... esac in %s' % rel(RUNNER_PATH)
        )
    elif not parsed_case:
        run_case = set()
        run_case_error = "the case block in %s accepts no modset names" % rel(RUNNER_PATH)
    else:
        run_case = set(parsed_case)
        run_case_error = None
    run_blocks = parse_run_blocks(runner_text)

expected = set(modsets) | run_case | set(REQUIRE_MISSING)

workflow_text = read(WORKFLOW_PATH)
if workflow_text is None:
    workflow_error = "%s is missing" % rel(WORKFLOW_PATH)
    unit_legs = None
    parse_legs = None
else:
    workflow_error = None
    unit_legs = parse_matrix(find_job_section(workflow_text, "unit-test-job"))
    parse_legs = parse_matrix(find_job_section(workflow_text, "parse-results-job"))

# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------

if modsets_error:
    add("modsets-module", "FAIL", modsets_error)
else:
    missing = expected - set(modsets)
    if missing:
        add(
            "modsets-module",
            "FAIL",
            "MODSETS in %s is missing expected modset(s): %s"
            % (rel(MODSETS_PATH), names(missing)),
        )
    else:
        add(
            "modsets-module",
            "PASS",
            "%d modset(s) in %s: %s"
            % (len(modsets), rel(MODSETS_PATH), names(modsets)),
        )

if run_case_error:
    add("run-case", "FAIL", run_case_error)
else:
    missing = expected - run_case
    if missing:
        add(
            "run-case",
            "FAIL",
            "run.sh does not accept expected modset(s): %s" % names(missing),
        )
    else:
        add(
            "run-case",
            "PASS",
            "%d modset(s) accepted by %s: %s"
            % (len(run_case), rel(RUNNER_PATH), names(run_case)),
        )

if run_case_error:
    add("run-blocks", "FAIL", "cannot check add blocks: " + run_case_error)
else:
    problems = []
    checked = sorted(run_case - NO_ADD_BLOCK)
    for name in checked:
        counts = run_blocks.get(name, {"link": 0, "mod_names": 0, "other": 0})
        if counts["link"] < 1:
            problems.append("%s has no dependency link block" % name)
        if counts["mod_names"] < 1:
            problems.append("%s has no MOD_NAMES block" % name)
    if problems:
        add("run-blocks", "FAIL", "; ".join(problems))
    else:
        add(
            "run-blocks",
            "PASS",
            "%d modset(s) with added mods have a link block and a MOD_NAMES block"
            % len(checked),
        )


def check_workflow_matrix(check_name, job, legs, expected_modsets):
    if workflow_error:
        add(check_name, "FAIL", workflow_error)
        return None
    if legs is None:
        add(
            check_name,
            "FAIL",
            "could not find the %s matrix include list in %s"
            % (job, rel(WORKFLOW_PATH)),
        )
        return None

    modset_list = [leg.get("modset", "") for leg in legs]
    actual = {value for value in modset_list if value}
    missing = expected_modsets - actual
    extra = actual - expected_modsets
    no_modset = [str(position) for position, value in enumerate(modset_list, 1) if not value]
    pairs = [(leg.get("channel", ""), leg.get("modset", "")) for leg in legs]
    duplicates = sorted({pair for pair in pairs if pairs.count(pair) > 1})

    problems = []
    if missing:
        problems.append("matrix is missing expected modset(s): " + names(missing))
    if extra:
        problems.append(
            "matrix names modset(s) unknown to MODSETS/run.sh: " + names(extra)
        )
    if no_modset:
        problems.append("leg(s) without a modset: " + ", ".join(no_modset))
    if duplicates:
        problems.append(
            "duplicate leg(s): "
            + ", ".join(
                "%s/%s" % (channel or "?", modset or "?")
                for channel, modset in duplicates
            )
        )

    if problems:
        add(check_name, "FAIL", "; ".join(problems))
    else:
        add(
            check_name,
            "PASS",
            "%d leg(s) [%s]; modsets: %s"
            % (len(legs), channel_counts(legs), names(actual)),
        )
    return actual


unit_set = check_workflow_matrix(
    "workflow-unit-test-job", "unit-test-job", unit_legs, expected
)
parse_set = check_workflow_matrix(
    "workflow-parse-results-job", "parse-results-job", parse_legs, expected
)

if unit_set is None or parse_set is None:
    add(
        "workflow-matrices-agree",
        "FAIL",
        "cannot compare the two matrices because one could not be parsed",
    )
else:
    only_unit = unit_set - parse_set
    only_parse = parse_set - unit_set
    if only_unit or only_parse:
        parts = []
        if only_unit:
            parts.append("unit-test-job only: " + names(only_unit))
        if only_parse:
            parts.append("parse-results-job only: " + names(only_parse))
        add(
            "workflow-matrices-agree",
            "FAIL",
            "the two matrices disagree: " + "; ".join(parts),
        )
    else:
        add(
            "workflow-matrices-agree",
            "PASS",
            "both matrices cover the same %d modset(s)" % len(unit_set),
        )

expected_legs = len(expected) * 2
if workflow_error:
    add("workflow-leg-count", "FAIL", workflow_error)
else:
    problems = []
    for job, legs in (("unit-test-job", unit_legs), ("parse-results-job", parse_legs)):
        if legs is None:
            continue  # already reported by the per-matrix check
        if len(legs) != expected_legs:
            problems.append(
                "%s has %d leg(s), expected %d (%d modset(s) x 2 channels)"
                % (job, len(legs), expected_legs, len(expected))
            )
    if problems:
        add("workflow-leg-count", "FAIL", "; ".join(problems))
    else:
        add(
            "workflow-leg-count",
            "PASS",
            "both matrices have %d leg(s) (%d modset(s) x 2 channels)"
            % (expected_legs, len(expected)),
        )

if REQUIRE_MISSING:
    defined = sorted(
        name
        for name in REQUIRE_MISSING
        if name in modsets or name in run_case or name in (unit_set or set()) or name in (parse_set or set())
    )
    absent = sorted(set(REQUIRE_MISSING) - set(defined))
    parts = []
    if absent:
        parts.append(
            "confirmed %s is missing from every modset source (expected negative self-test)"
            % names(absent)
        )
    if defined:
        parts.append(
            "already defined, so it cannot prove the detector: " + names(defined)
        )
    add("require-missing", "FAIL", "; ".join(parts))

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

passed = sum(1 for check in CHECKS if check["status"] == "PASS")
failed = len(CHECKS) - passed
status = "OK" if failed == 0 else "FAILED"

if JSON_OUTPUT:
    payload = {
        "status": status,
        "ok": status == "OK",
        "expected": sorted(expected),
        "sources": {
            "modsets": {
                "path": rel(MODSETS_PATH),
                "modsets": sorted(modsets),
                "error": modsets_error,
            },
            "run_case": {
                "path": rel(RUNNER_PATH),
                "modsets": sorted(run_case),
                "error": run_case_error,
            },
            "run_blocks": run_blocks,
            "workflow": {
                "path": rel(WORKFLOW_PATH),
                "error": workflow_error,
                "unit-test-job": {
                    "legs": unit_legs,
                    "modsets": sorted(unit_set) if unit_set is not None else None,
                },
                "parse-results-job": {
                    "legs": parse_legs,
                    "modsets": sorted(parse_set) if parse_set is not None else None,
                },
            },
        },
        "checks": CHECKS,
        "differences": DIFFERENCES,
        "summary": {"pass": passed, "fail": failed},
    }
    if REQUIRE_MISSING:
        payload["require_missing"] = REQUIRE_MISSING
    print(json.dumps(payload))
else:
    print("Sources")
    if modsets_error:
        print("  MODSETS   %s: %s" % (rel(MODSETS_PATH), modsets_error))
    else:
        print(
            "  MODSETS   %s: %s (%d)"
            % (rel(MODSETS_PATH), names(modsets), len(modsets))
        )
    if run_case_error:
        print("  run.sh    case: %s" % run_case_error)
    else:
        print("  run.sh    case: %s (%d)" % (names(run_case), len(run_case)))
    if run_blocks:
        print(
            "  run.sh    blocks: "
            + ", ".join(
                "%s(link=%d,names=%d,other=%d)"
                % (name, counts["link"], counts["mod_names"], counts["other"])
                for name, counts in sorted(run_blocks.items())
            )
        )
    else:
        print("  run.sh    blocks: (none found)")
    for label, legs in (("unit-test-job", unit_legs), ("parse-results-job", parse_legs)):
        if legs is None:
            print("  workflow  %s: (matrix not found)" % label)
            continue
        print(
            "  workflow  %s: %d leg(s) [%s]; modsets: %s"
            % (
                label,
                len(legs),
                channel_counts(legs),
                names({leg.get("modset") for leg in legs if leg.get("modset")}),
            )
        )
    print("  expected: %s (%d)" % (names(expected), len(expected)))
    print("")

    for check in CHECKS:
        print("[%s] %s: %s" % (check["status"], check["name"], check["detail"]))

    print("")
    print("Differences")
    if DIFFERENCES:
        for difference in DIFFERENCES:
            print("  - " + difference)
    else:
        print("  (none)")
    print("")
    print("Summary: %s (%d passed, %d failed)" % (status, passed, failed))

sys.exit(0 if status == "OK" else 1)
PY
