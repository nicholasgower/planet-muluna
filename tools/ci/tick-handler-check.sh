#!/usr/bin/env bash
# Check the control-stage tick-handler convention.
#
# Every on_tick / on_nth_tick handler must contain nothing but one `for` loop
# over a storage table, so an unused feature costs a single empty iteration.
#
# Usage:
#   tools/ci/tick-handler-check.sh
#   tools/ci/tick-handler-check.sh --json
#   tools/ci/tick-handler-check.sh --root DIR
#   tools/ci/tick-handler-check.sh --require-finding 'TEXT'
#   tools/ci/tick-handler-check.sh --self-test
#
# The checker reads scripts/**/*.lua and control.lua (comments and strings are
# masked, so a mention in a comment does not count). A handler is accepted when
# its body is exactly one `for ... in pairs(...) do ... end` loop; declarations,
# guards and cleanup belong inside the loop body or in a function it calls.
#
# Add `-- tick-handler-ok: <reason>` to a registration line to allow a
# documented exception.
#
# `--require-finding TEXT` adds a synthetic finding, so the detector's failure
# path is exercised and the command exits 1. `--self-test` runs the parser
# against embedded valid and invalid handlers.
#
# Exit codes: 0 clean, 1 findings, 2 usage error.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

JSON_OUTPUT=0
ROOT=""
REQUIRE_FINDING=""
SELF_TEST=0

usage() {
  sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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
      [ "$#" -ge 2 ] || {
        echo "tick-handler-check.sh: --root requires a value" >&2
        exit 2
      }
      ROOT="$2"
      shift 2
      ;;
    --root=*)
      ROOT="${1#*=}"
      shift
      ;;
    --require-finding)
      [ "$#" -ge 2 ] || {
        echo "tick-handler-check.sh: --require-finding requires a value" >&2
        exit 2
      }
      REQUIRE_FINDING="$2"
      shift 2
      ;;
    --require-finding=*)
      REQUIRE_FINDING="${1#*=}"
      shift
      ;;
    --self-test)
      SELF_TEST=1
      shift
      ;;
    *)
      echo "tick-handler-check.sh: unexpected argument: $1" >&2
      exit 2
      ;;
  esac
done

REPO_DIR="$REPO_DIR" JSON_OUTPUT="$JSON_OUTPUT" ROOT="$ROOT" \
  REQUIRE_FINDING="$REQUIRE_FINDING" SELF_TEST="$SELF_TEST" \
  exec python3 - <<'PY'
import json
import os
import re
import sys
from pathlib import Path

REPO = Path(os.environ["REPO_DIR"])
JSON_OUTPUT = os.environ["JSON_OUTPUT"] == "1"
ROOT = Path(os.environ["ROOT"]) if os.environ["ROOT"] else REPO
REQUIRE_FINDING = os.environ["REQUIRE_FINDING"]
SELF_TEST = os.environ["SELF_TEST"] == "1"

TOKEN_RE = re.compile(r"\b(function|if|elseif|for|while|do|repeat|until|end)\b")
NTH_TICK_RE = re.compile(r"\b(?:Muluna\s*\.\s*events\s*\.\s*on_nth_tick|script\s*\.\s*on_nth_tick)\s*\(")
ON_EVENT_RE = re.compile(r"\b(?:Muluna\s*\.\s*events\s*\.\s*on_event|script\s*\.\s*on_event)\s*\(")
NAME_RE = re.compile(r"^[A-Za-z_]\w*$")


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


def line_text(text, offset):
    start = text.rfind("\n", 0, offset) + 1
    end = text.find("\n", offset)
    if end == -1:
        end = len(text)
    return text[start:end]


def match_block(masked, start):
    """Return the closing `end`/`until` match of the block opened at `start`."""
    first = TOKEN_RE.search(masked, start)
    if not first or first.group(1) not in ("function", "if", "for", "while", "do", "repeat"):
        return None
    depth = 1
    expect_do = 1 if first.group(1) in ("for", "while") else 0
    for token in TOKEN_RE.finditer(masked, first.end()):
        word = token.group(1)
        if word in ("function", "if", "for", "while"):
            depth += 1
            if word in ("for", "while"):
                expect_do += 1
        elif word == "do":
            if expect_do:
                expect_do -= 1
            else:
                depth += 1
        elif word == "repeat":
            depth += 1
        elif word in ("end", "until"):
            depth -= 1
            if depth == 0:
                return token
    return None


def split_args(masked, open_index):
    """Return the (start, end) offset pairs of a call's top-level arguments."""
    depth = 0
    args = []
    start = open_index + 1
    index = open_index
    while index < len(masked):
        char = masked[index]
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
            if depth == 0:
                args.append((start, index))
                return args
        elif char == "," and depth == 1:
            args.append((start, index))
            start = index + 1
        index += 1
    return None


def verify_body(masked, body_start, body_end):
    token = TOKEN_RE.search(masked, body_start)
    if not token or token.start() >= body_end:
        return "handler body is empty"
    if token.group(1) != "for":
        return "handler body starts with '%s', expected a single 'for' loop" % token.group(1)
    if masked[body_start:token.start()].strip():
        return "handler has a statement before the for loop"
    close = match_block(masked, token.start())
    if not close or close.end() > body_end:
        return "could not match the handler's for loop"
    if masked[close.end():body_end].strip():
        return "handler has a statement after the for loop"
    return None


def find_function(masked, name):
    pattern = re.compile(r"\b(?:local\s+)?function\s+" + re.escape(name) + r"\s*\(")
    return pattern.search(masked)


def handler_span(masked, start, end):
    text = masked[start:end].strip()
    if not text:
        return None, "handler argument is empty"
    if text.startswith("function"):
        function_at = masked.find("function", start, end)
        params_open = masked.find("(", function_at)
        if params_open == -1 or params_open >= end:
            return None, "could not find the handler's parameter list"
        close = match_block(masked, function_at)
        if not close:
            return None, "could not match the handler function"
        params_close = masked.find(")", params_open)
        return (params_close + 1 if params_close != -1 else params_open + 1, close.start()), None
    if NAME_RE.match(text):
        definition = find_function(masked, text)
        if not definition:
            return None, "handler '%s' is not a function defined in this file" % text
        function_at = definition.start() + definition.group(0).find("function")
        params_close = masked.find(")", definition.end())
        close = match_block(masked, function_at)
        if not close:
            return None, "could not match the handler function '%s'" % text
        return (params_close + 1, close.start()), None
    return None, "handler is not an inline function or a function name"


def check_source(path, text):
    masked = mask_lua(text)
    findings = []
    for pattern, is_nth_tick in ((NTH_TICK_RE, True), (ON_EVENT_RE, False)):
        for match in pattern.finditer(masked):
            open_index = match.end() - 1
            args = split_args(masked, open_index)
            if not args or len(args) < 2:
                continue
            if not is_nth_tick:
                first_arg = masked[args[0][0]:args[0][1]]
                if "on_tick" not in first_arg:
                    continue
            handler = args[1]
            line = line_of(text, match.start())
            if "tick-handler-ok:" in line_text(text, match.start()):
                continue
            span, error = handler_span(masked, handler[0], handler[1])
            if error:
                findings.append((path, line, "handler", error))
                continue
            problem = verify_body(masked, span[0], span[1])
            if problem:
                findings.append((path, line, "body", problem))
    return findings


def self_test():
    cases = [
        (
            "inline single loop",
            """Muluna.events.on_nth_tick(30, function(event)
                for i, entry in pairs(storage.things) do
                    do_work(entry, event)
                end
            end)""",
            0,
        ),
        (
            "named function",
            """local function update(event)
                for i, entry in pairs(storage.things) do
                    do_work(entry, event)
                end
            end
            Muluna.events.on_nth_tick(30, update)""",
            0,
        ),
        (
            "on_tick inline loop",
            """Muluna.events.on_event(defines.events.on_tick, function(event)
                for i, player in pairs(storage.players) do end
            end)""",
            0,
        ),
        (
            "statement before the loop",
            """Muluna.events.on_nth_tick(30, function(event)
                local cache = {}
                for i, entry in pairs(storage.things) do end
            end)""",
            1,
        ),
        (
            "two loops",
            """Muluna.events.on_nth_tick(30, function(event)
                for i, entry in pairs(storage.a) do end
                for i, entry in pairs(storage.b) do end
            end)""",
            1,
        ),
        (
            "statement after the loop",
            """Muluna.events.on_nth_tick(30, function(event)
                for i, entry in pairs(storage.things) do end
                sync()
            end)""",
            1,
        ),
        (
            "comment before the loop is allowed",
            """Muluna.events.on_nth_tick(30, function(event)
                -- one loop only
                for i, entry in pairs(storage.things) do end
            end)""",
            0,
        ),
    ]
    failures = 0
    for name, source, expected in cases:
        found = check_source(name, source)
        status = "PASS" if len(found) == expected else "FAIL"
        if status == "FAIL":
            failures += 1
        print("[%s] self-test: %s (expected %d finding(s), got %d)" % (status, name, expected, len(found)))
    return failures


def iter_sources(root):
    control = root / "control.lua"
    if control.is_file():
        yield control
    scripts = root / "scripts"
    if scripts.is_dir():
        for path in sorted(scripts.rglob("*.lua")):
            yield path


if SELF_TEST:
    failures = self_test()
    print("\nSummary: %s" % ("OK" if failures == 0 else "FAILED"))
    sys.exit(0 if failures == 0 else 1)

findings = []
scanned = 0
for path in iter_sources(ROOT):
    text = path.read_text(encoding="utf-8")
    scanned += 1
    for finding_path, line, check, message in check_source(path, text):
        findings.append(
            {
                "file": str(finding_path.relative_to(ROOT)) if str(finding_path).startswith(str(ROOT)) else str(finding_path),
                "line": line,
                "check": check,
                "message": message,
            }
        )

if REQUIRE_FINDING:
    findings.append(
        {
            "file": "<self-test>",
            "line": 0,
            "check": "require-finding",
            "message": "synthetic finding requested by --require-finding: " + REQUIRE_FINDING,
        }
    )

ok = not findings
if JSON_OUTPUT:
    print(
        json.dumps(
            {
                "ok": ok,
                "status": "OK" if ok else "FAILED",
                "scanned": scanned,
                "findings": findings,
                "summary": {"pass": 0 if findings else scanned, "fail": len(findings)},
            },
            indent=2,
        )
    )
else:
    for finding in findings:
        print(
            "[FAIL] %s:%d %s: %s"
            % (finding["file"], finding["line"], finding["check"], finding["message"])
        )
    if ok:
        print("[PASS] tick-handler-check: %d source file(s) follow the storage-loop convention" % scanned)
    print("\nSummary: %s (%d finding(s) in %d file(s))" % ("OK" if ok else "FAILED", len(findings), scanned))

sys.exit(0 if ok else 1)
PY
