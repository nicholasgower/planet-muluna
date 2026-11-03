#!/usr/bin/env bash
# Report read, write, initialization and cleanup sites for control-stage storage
# keys.
#
# Usage:
#   tools/ci/storage-keys-report.sh
#   tools/ci/storage-keys-report.sh --key nav_beacon_players
#   tools/ci/storage-keys-report.sh --strict
#   tools/ci/storage-keys-report.sh --json
#   tools/ci/storage-keys-report.sh --require-missing some_unused_key
#
# The report is heuristic and read-only: it masks comments and strings, then
# classifies each `storage.KEY` access by the assignment that follows it. A
# write counts as an initialization when the value is `{}` or `<same> or {}`,
# which is how this repository initializes storage.
#
# `--strict` exits 1 when a key is read but no initialization-like write was
# found. `--require-missing NAME` is the negative self-test: it confirms NAME is
# absent and exits 1.
#
# Exit codes: 0 clean, 1 strict findings or self-test, 2 usage error.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

JSON_OUTPUT=0
STRICT=0
KEY=""
REQUIRE_MISSING=""
ROOT=""

usage() {
  sed -n '2,23p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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
    --strict)
      STRICT=1
      shift
      ;;
    --key)
      [ "$#" -ge 2 ] || {
        echo "storage-keys-report.sh: --key requires a value" >&2
        exit 2
      }
      KEY="$2"
      shift 2
      ;;
    --key=*)
      KEY="${1#*=}"
      shift
      ;;
    --root)
      [ "$#" -ge 2 ] || {
        echo "storage-keys-report.sh: --root requires a value" >&2
        exit 2
      }
      ROOT="$2"
      shift 2
      ;;
    --root=*)
      ROOT="${1#*=}"
      shift
      ;;
    --require-missing)
      [ "$#" -ge 2 ] || {
        echo "storage-keys-report.sh: --require-missing requires a value" >&2
        exit 2
      }
      REQUIRE_MISSING="$2"
      shift 2
      ;;
    --require-missing=*)
      REQUIRE_MISSING="${1#*=}"
      shift
      ;;
    *)
      echo "storage-keys-report.sh: unexpected argument: $1" >&2
      exit 2
      ;;
  esac
done

REPO_DIR="$REPO_DIR" JSON_OUTPUT="$JSON_OUTPUT" STRICT="$STRICT" KEY="$KEY" \
  REQUIRE_MISSING="$REQUIRE_MISSING" ROOT="$ROOT" \
  exec python3 - <<'PY'
import json
import os
import re
import sys
from pathlib import Path

REPO = Path(os.environ["REPO_DIR"])
JSON_OUTPUT = os.environ["JSON_OUTPUT"] == "1"
STRICT = os.environ["STRICT"] == "1"
ONLY_KEY = os.environ["KEY"]
REQUIRE_MISSING = os.environ["REQUIRE_MISSING"]
ROOT = Path(os.environ["ROOT"]) if os.environ["ROOT"] else REPO

STORAGE_RE = re.compile(r"\bstorage\.([A-Za-z_]\w*)")
DYNAMIC_RE = re.compile(r"\bstorage\s*\[")
CHAIN_RE = re.compile(r"^\s*(?:(?:\[[^\]]*\]|\.\w+))*\s*([=~]=?)\s*(.*)$")


def mask_lua(text):
    """Blank comments and string literals, preserving offsets and newlines."""
    out = list(text)
    i = 0
    n = len(text)
    while i < n:
        if text.startswith("--", i):
            long = re.match(r"--\[(=*)\[", text[i:])
            if long:
                close = "]" + long.group(1) + "]"
                end = text.find(close, i + len(long.group(0)))
                end = n if end == -1 else end + len(close)
            else:
                end = text.find("\n", i)
                end = n if end == -1 else end
            for j in range(i, end):
                if out[j] != "\n":
                    out[j] = " "
            i = end
            continue
        if text[i] == "[":
            long = re.match(r"\[(=*)\[", text[i:])
            if long:
                close = "]" + long.group(1) + "]"
                end = text.find(close, i + len(long.group(0)))
                end = n if end == -1 else end + len(close)
                for j in range(i, end):
                    if out[j] != "\n":
                        out[j] = " "
                i = end
                continue
        if text[i] in ("'", '"'):
            quote = text[i]
            j = i + 1
            while j < n:
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == quote:
                    j += 1
                    break
                j += 1
            for k in range(i, min(j, n)):
                if out[k] != "\n":
                    out[k] = " "
            i = j
            continue
        i += 1
    return "".join(out)


def line_of(text, offset):
    return text.count("\n", 0, offset) + 1


def classify(masked, offset, key_end):
    """Return (kind, rhs) for a storage access starting at `offset`."""
    line_end = masked.find("\n", offset)
    if line_end == -1:
        line_end = len(masked)
    rest = masked[key_end:line_end]
    match = CHAIN_RE.match(rest)
    if not match:
        return "read", ""
    operator, rhs = match.group(1), match.group(2).strip()
    if operator != "=":
        return "read", ""
    if re.match(r"^nil\b", rhs):
        return "clear", rhs
    return "write", rhs


def is_initialization(kind, rhs, previous_line):
    if kind != "write":
        return False
    if re.match(r"^\{\s*\}", rhs) or re.search(r"\bor\s*\{\s*\}", rhs):
        return True
    return bool(re.search(r"\bif\s+(?:not\s+storage\.\w+|storage\.\w+\s*==\s*nil)\s+then", previous_line))


def iter_sources(root):
    for name in ("control.lua",):
        path = root / name
        if path.is_file():
            yield path
    for directory in ("scripts", "lib"):
        folder = root / directory
        if folder.is_dir():
            for path in sorted(folder.rglob("*.lua")):
                yield path


sites = {}
dynamic = 0
for path in iter_sources(ROOT):
    text = path.read_text(encoding="utf-8")
    masked = mask_lua(text)
    lines = masked.split("\n")
    relative = str(path.relative_to(ROOT))
    dynamic += len(DYNAMIC_RE.findall(masked))
    for match in STORAGE_RE.finditer(masked):
        key = match.group(1)
        if ONLY_KEY and key != ONLY_KEY:
            continue
        kind, rhs = classify(masked, match.start(), match.end())
        line = line_of(text, match.start())
        previous = lines[line - 2] if line >= 2 else ""
        initialization = is_initialization(kind, rhs, previous)
        entry = sites.setdefault(
            key,
            {"reads": [], "writes": [], "clears": [], "init": [], "has_init": False},
        )
        if initialization:
            entry["has_init"] = True
            entry["init"].append("%s:%d" % (relative, line))
        bucket_name = {"read": "reads", "write": "writes", "clear": "clears"}[kind]
        entry[bucket_name].append("%s:%d" % (relative, line))

if REQUIRE_MISSING:
    present = REQUIRE_MISSING in sites
    if present:
        print(
            "[FAIL] require-missing: %s is used in the scanned sources; the "
            "negative self-test needs a name that is absent" % REQUIRE_MISSING
        )
    else:
        print(
            "[FAIL] require-missing: confirmed %s is not used (expected negative "
            "self-test)" % REQUIRE_MISSING
        )
    sys.exit(1)

missing_init = sorted(key for key, entry in sites.items() if entry["reads"] and not entry["has_init"])
ok = not missing_init or not STRICT

if JSON_OUTPUT:
    print(
        json.dumps(
            {
                "ok": ok,
                "status": "OK" if ok else "FAILED",
                "keys": sites,
                "dynamic_keys": dynamic,
                "missing_init": missing_init,
                "summary": {"keys": len(sites), "missing_init": len(missing_init)},
            },
            indent=2,
        )
    )
else:
    for key in sorted(sites):
        entry = sites[key]
        marker = "INFO" if entry["has_init"] or not entry["reads"] else "WARN"
        print(
            "[%s] %s: %d read(s), %d write(s), %d clear(s)%s"
            % (
                marker,
                key,
                len(entry["reads"]),
                len(entry["writes"]),
                len(entry["clears"]),
                (", init at " + ", ".join(entry["init"])) if entry["init"] else "",
            )
        )
        if ONLY_KEY:
            for kind in ("read", "write", "clear", "init"):
                bucket = entry["reads" if kind == "read" else "writes" if kind == "write" else "clears" if kind == "clear" else "init"]
                for site in bucket:
                    print("    %-5s %s" % (kind, site))
    if missing_init:
        print(
            "\n[WARN] %d key(s) are read but have no initialization-like write: %s"
            % (len(missing_init), ", ".join(missing_init))
        )
    print(
        "\nSummary: %s (%d key(s), %d without initialization, %d dynamic access(es))"
        % ("OK" if ok else "FAILED", len(sites), len(missing_init), dynamic)
    )

sys.exit(0 if ok else 1)
PY
