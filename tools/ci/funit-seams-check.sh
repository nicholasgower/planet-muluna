#!/usr/bin/env bash
# Check that FUnit test seams are wired up and documented.
#
# This is a development helper for planet-muluna. It is not shipped with the mod.
#
# Usage:
#   tools/ci/funit-seams-check.sh
#   tools/ci/funit-seams-check.sh --json
#   tools/ci/funit-seams-check.sh --require-missing get_storage
#
# The checker compares:
#   - `stage().name` calls in scripts/funit.lua with `Muluna.funit.name` exports
#     in scripts/*.lua;
#   - `helpers.funit_call(...)` / `remote.call("muluna_funit", ...)` names in the
#     FUnit suite with remote keys in scripts/funit.lua;
#   - every remote key with the "Test-only production seams" section in
#     test-mods/planet-muluna-funit/README.md.
#
# `--require-missing NAME` adds NAME to the required README list. Use a name that
# is intentionally absent; the checker must report it missing and exit 1. This is
# the negative self-test that proves the README detector works.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

JSON_OUTPUT=0
REQUIRE_MISSING=""

usage() {
  sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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
      [ "$#" -ge 2 ] || {
        echo "funit-seams-check.sh: --require-missing requires a value" >&2
        exit 2
      }
      REQUIRE_MISSING="$2"
      shift 2
      ;;
    --require-missing=*)
      REQUIRE_MISSING="${1#*=}"
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "funit-seams-check.sh: unknown option: $1" >&2
      exit 2
      ;;
    *)
      echo "funit-seams-check.sh: unexpected argument: $1" >&2
      exit 2
      ;;
  esac
done
[ "$#" -eq 0 ] || {
  echo "funit-seams-check.sh: unexpected argument: $1" >&2
  exit 2
}

REPO_DIR="$REPO_DIR" JSON_OUTPUT="$JSON_OUTPUT" REQUIRE_MISSING="$REQUIRE_MISSING" \
  exec python3 - <<'PY'
import json
import os
import re
import sys
from pathlib import Path

REPO = Path(os.environ["REPO_DIR"])
JSON_OUTPUT = os.environ["JSON_OUTPUT"] == "1"
REQUIRE_MISSING = os.environ["REQUIRE_MISSING"]
PROG = "funit-seams-check.sh"

CHECKS = []


def add(name, status, detail):
    CHECKS.append({"name": name, "status": status, "detail": detail})


def read(path):
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return ""


def sort_names(names):
    return ", ".join(sorted(names))


funit_path = REPO / "scripts" / "funit.lua"
funit_text = read(funit_path)
if not funit_text:
    add("scripts-funit-present", "FAIL", "scripts/funit.lua is missing")
    remote_keys = set()
else:
    block_match = re.search(
        r'remote\.add_interface\(\s*"muluna_funit"\s*,\s*\{(.*?)^\}\)',
        funit_text,
        re.S | re.M,
    )
    if not block_match:
        add("remote-interface", "FAIL", "could not find remote.add_interface(\"muluna_funit\", { ... })")
        remote_keys = set()
    else:
        remote_keys = set(
            re.findall(r"^\s*([A-Za-z_]\w*)\s*=\s*function\b", block_match.group(1), re.M)
        )
        add("remote-interface", "PASS", "%d remote key(s) found" % len(remote_keys))

exports = set()
for path in (REPO / "scripts").rglob("*.lua"):
    exports.update(re.findall(r"Muluna\.funit\.([A-Za-z_]\w*)\s*=", read(path)))

stage_refs = set(re.findall(r"stage\(\)\.([A-Za-z_]\w*)", funit_text))
missing_exports = stage_refs - exports
if missing_exports:
    add(
        "remote-export-refs",
        "FAIL",
        "scripts/funit.lua calls stage().NAME with no Muluna.funit.NAME export: "
        + sort_names(missing_exports),
    )
else:
    add("remote-export-refs", "PASS", "every stage() helper has a Muluna.funit export")

test_calls = set()
for path in (REPO / "test-mods" / "planet-muluna-funit").rglob("*.lua"):
    text = read(path)
    test_calls.update(re.findall(r"funit_call\(\s*[\"']([A-Za-z_]\w*)", text))
    test_calls.update(
        re.findall(
            r"remote\.call\(\s*[\"']muluna_funit[\"']\s*,\s*[\"']([A-Za-z_]\w*)",
            text,
        )
    )
missing_wrappers = test_calls - remote_keys
if missing_wrappers:
    add(
        "test-remote-calls",
        "FAIL",
        "FUnit tests call remote functions that scripts/funit.lua does not define: "
        + sort_names(missing_wrappers),
    )
else:
    add("test-remote-calls", "PASS", "every tested remote function has a wrapper")

readme_path = REPO / "test-mods" / "planet-muluna-funit" / "README.md"
readme_text = read(readme_path)
section_match = re.search(
    r"^## Test-only production seams\s*$(.*?)(?=^## |\Z)",
    readme_text,
    re.S | re.M,
)
if not section_match:
    add("readme-seam-section", "FAIL", "README has no 'Test-only production seams' section")
    section = ""
else:
    section = section_match.group(1)

if REQUIRE_MISSING:
    remote_keys = set(remote_keys)
    remote_keys.add(REQUIRE_MISSING)

missing_readme = []
for name in remote_keys:
    if "`%s`" % name not in section:
        missing_readme.append(name)
if missing_readme:
    add(
        "readme-seams",
        "FAIL",
        "remote seams missing from the README seam list: " + sort_names(missing_readme),
    )
else:
    add("readme-seams", "PASS", "all remote seams are listed in the README")

if REQUIRE_MISSING:
    if "`%s`" % REQUIRE_MISSING in section:
        add(
            "require-missing",
            "FAIL",
            "%s is already documented; the self-test needs a name that is absent" % REQUIRE_MISSING,
        )
    else:
        add(
            "require-missing",
            "FAIL",
            "confirmed %s is missing from the README (expected negative self-test)" % REQUIRE_MISSING,
        )

passed = sum(1 for check in CHECKS if check["status"] == "PASS")
failed = len(CHECKS) - passed
status = "OK" if failed == 0 else "FAILED"

if JSON_OUTPUT:
    print(
        json.dumps(
            {
                "status": status,
                "ok": status == "OK",
                "checks": CHECKS,
                "summary": {"pass": passed, "fail": failed},
            },
            indent=2,
        )
    )
else:
    for check in CHECKS:
        print("[%s] %s: %s" % (check["status"], check["name"], check["detail"]))
    print("\nSummary: %s (%d passed, %d failed)" % (status, passed, failed))

sys.exit(0 if status == "OK" else 1)
PY
