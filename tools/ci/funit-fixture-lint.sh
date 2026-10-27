#!/usr/bin/env bash
# Lint the FUnit suite for load-stage mistakes.
#
# This is a development helper for planet-muluna. It is not shipped with the mod.
#
# Runtime suites (control stage) and data-stage fixtures see different globals.
# A mistake usually surfaces as a confusing runtime error or a silently skipped
# assertion instead of a clear load failure, so this lint looks for the common
# confusions before Factorio ever starts:
#
#   runtime suites  (test-mods/planet-muluna-funit/tests/**/*.lua)
#     - the data-stage global `mods`; use `script.active_mods` at runtime
#     - `data.raw` / `data:extend`; the data table does not exist in control
#     - `assert(true)` / `runner.assert(true)`; an assertion that cannot fail
#
#   data fixtures  (test-mods/planet-muluna-funit/prototypes/fixtures/**/*.lua)
#     - `script.active_mods`; the data stage must use `mods`
#
# Comments and string literals are masked before matching, so a mention inside a
# comment or a player-facing message does not trip the lint.
#
# Usage: tools/ci/funit-fixture-lint.sh [--json] [--root DIR]
# Run "tools/ci/funit-fixture-lint.sh --help" for details.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

JSON_OUTPUT=0
ROOT="$DEFAULT_ROOT"

usage() {
  cat <<'EOF'
Usage: tools/ci/funit-fixture-lint.sh [--json] [--root DIR]

Scan the FUnit suite for load-stage mistakes: data-stage globals used at
runtime, and control-stage globals used in data-stage fixtures.

Runtime suites (test-mods/planet-muluna-funit/tests/**/*.lua) are checked for:
  - `mods[` / `mods.`         the data-stage global; use script.active_mods
  - `data.raw`, `data:extend` not available in the control stage
  - `assert(true)` / `runner.assert(true)`
                              an assertion that cannot fail

Data-stage fixtures (test-mods/planet-muluna-funit/prototypes/fixtures/**/*.lua)
are checked for:
  - `script.active_mods`      the data stage must use the `mods` global

Options:
  --json         Print one JSON object instead of the text report.
  --root DIR     Repository root to scan (default: the root above this script).
                 DIR must contain test-mods/planet-muluna-funit.
  -h, --help     Show this help.

Output:
  Text mode prints one line per finding as
  path:line: check-id: message, followed by the offending source line.
  JSON mode prints {"ok":BOOL,"root":...,"findings":[...],"summary":{...}}.

Exit status:
  0  no findings
  1  at least one finding
  2  usage error, or the expected suite directories are missing

Notes:
  - Comment lines and Lua block comments are ignored, and string literals are
    masked, so text inside a comment or a message string is not reported.
  - The masking is a small heuristic scanner, not a full Lua parser: an
    unterminated long bracket or an unusual escape can shift what counts as
    code. Keep the scanner conservative rather than clever.
  - A runtime suite that declares its own `local mods` table and indexes it is
    indistinguishable from the data-stage global; that (rare) shadowing case is
    a known false positive.
  - Only Python's standard library is used.
EOF
}

die() {
  echo "funit-fixture-lint.sh: $*" >&2
  echo "Try 'tools/ci/funit-fixture-lint.sh --help' for usage." >&2
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
    --root)
      [[ $# -ge 2 ]] || die "--root requires a directory."
      ROOT="$2"
      shift 2
      ;;
    --root=*)
      ROOT="${1#*=}"
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

[[ -n "$ROOT" ]] || die "--root must not be empty."
[[ -d "$ROOT" ]] || die "root directory not found: $ROOT"
ROOT="$(cd "$ROOT" && pwd)"

SUITE_DIR="$ROOT/test-mods/planet-muluna-funit/tests"
FIXTURE_DIR="$ROOT/test-mods/planet-muluna-funit/prototypes/fixtures"
[[ -d "$SUITE_DIR" ]] || die "runtime suite directory not found: $SUITE_DIR"
[[ -d "$FIXTURE_DIR" ]] || die "data fixture directory not found: $FIXTURE_DIR"

command -v python3 >/dev/null 2>&1 || die "python3 is required."

ROOT="$ROOT" JSON_OUTPUT="$JSON_OUTPUT" exec python3 - <<'PY'
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(os.environ["ROOT"])
JSON_OUTPUT = os.environ["JSON_OUTPUT"] == "1"
PROG = "funit-fixture-lint.sh"

SUITE_REL = Path("test-mods/planet-muluna-funit/tests")
FIXTURE_REL = Path("test-mods/planet-muluna-funit/prototypes/fixtures")

# A long bracket starts a long string or block comment: [[, [=[, [==[, ...
LONG_BRACKET = re.compile(r"\[(=*)\[")

RUNTIME_CHECKS = [
    (
        "runtime-global-mods",
        re.compile(r"(?<![\w.])mods\s*[\[.]"),
        "runtime tests must use script.active_mods, not the data-stage global 'mods'",
    ),
    (
        "runtime-data-raw",
        re.compile(r"(?<![\w.])data\.raw(?![A-Za-z0-9_])"),
        "data.raw does not exist in the control stage",
    ),
    (
        "runtime-data-extend",
        re.compile(r"(?<![\w.])data\s*:\s*extend\b"),
        "data:extend does not exist in the control stage",
    ),
    (
        "weak-assert",
        re.compile(r"(?<![\w])assert\s*\(\s*true\s*[,)]"),
        "assert(true) can never fail; assert on the observed value instead",
    ),
]

FIXTURE_CHECKS = [
    (
        "fixture-script-active-mods",
        re.compile(r"(?<![\w.])script\.active_mods\b"),
        "data-stage fixtures must use the 'mods' global, not script.active_mods",
    ),
]


def mask_lua(text):
    """Blank comments and string literals, keeping offsets and newlines intact."""
    chars = list(text)
    length = len(text)

    def blank(start, end):
        for index in range(start, min(end, length)):
            if chars[index] != "\n":
                chars[index] = " "

    def long_bracket_end(start, match):
        close = "]" + match.group(1) + "]"
        found = text.find(close, match.end())
        return length if found < 0 else found + len(close)

    index = 0
    while index < length:
        char = text[index]

        if char == "-" and text.startswith("--", index):
            match = LONG_BRACKET.match(text, index + 2)
            if match:
                end = long_bracket_end(index, match)
            else:
                newline = text.find("\n", index)
                end = length if newline < 0 else newline
            blank(index, end)
            index = end
            continue

        if char in ("'", '"'):
            cursor = index + 1
            while cursor < length:
                current = text[cursor]
                if current == "\\":
                    cursor += 2
                    continue
                if current == char:
                    cursor += 1
                    break
                if current == "\n":
                    # Unterminated short string; do not swallow the next line.
                    break
                cursor += 1
            blank(index, cursor)
            index = cursor
            continue

        if char == "[":
            match = LONG_BRACKET.match(text, index)
            if match:
                end = long_bracket_end(index, match)
                blank(index, end)
                index = end
                continue

        index += 1

    return "".join(chars)


def scan(paths, checks):
    findings = []
    for path in paths:
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError as error:
            print("%s: cannot read %s: %s" % (PROG, path, error), file=sys.stderr)
            raise SystemExit(2)

        masked = mask_lua(text)
        lines = text.splitlines()
        rel = path.relative_to(ROOT).as_posix()

        for check_id, pattern, message in checks:
            for match in pattern.finditer(masked):
                line_number = masked.count("\n", 0, match.start()) + 1
                source = lines[line_number - 1].strip() if line_number <= len(lines) else ""
                findings.append(
                    {
                        "file": rel,
                        "line": line_number,
                        "check": check_id,
                        "message": message,
                        "text": source,
                    }
                )

    return findings


suite_files = sorted((ROOT / SUITE_REL).rglob("*.lua"))
fixture_files = sorted((ROOT / FIXTURE_REL).rglob("*.lua"))

if not suite_files:
    print("%s: no runtime suites found under %s" % (PROG, ROOT / SUITE_REL), file=sys.stderr)
    raise SystemExit(2)
if not fixture_files:
    print("%s: no data fixtures found under %s" % (PROG, ROOT / FIXTURE_REL), file=sys.stderr)
    raise SystemExit(2)

findings = scan(suite_files, RUNTIME_CHECKS) + scan(fixture_files, FIXTURE_CHECKS)
findings.sort(key=lambda finding: (finding["file"], finding["line"], finding["check"]))

ok = not findings
summary = {
    "runtime_files": len(suite_files),
    "fixture_files": len(fixture_files),
    "files_scanned": len(suite_files) + len(fixture_files),
    "findings": len(findings),
}

if JSON_OUTPUT:
    print(
        json.dumps(
            {
                "ok": ok,
                "root": str(ROOT),
                "findings": findings,
                "summary": summary,
            },
            separators=(",", ":"),
        )
    )
else:
    for finding in findings:
        print(
            "%s:%d: %s: %s"
            % (finding["file"], finding["line"], finding["check"], finding["message"])
        )
        if finding["text"]:
            print("    %s" % finding["text"])
    if ok:
        print(
            "Summary: OK (%d files scanned: %d runtime, %d fixtures)"
            % (summary["files_scanned"], summary["runtime_files"], summary["fixture_files"])
        )
    else:
        print(
            "Summary: FAILED (%d finding(s) in %d files scanned: %d runtime, %d fixtures)"
            % (
                summary["findings"],
                summary["files_scanned"],
                summary["runtime_files"],
                summary["fixture_files"],
            )
        )

sys.exit(0 if ok else 1)
PY
