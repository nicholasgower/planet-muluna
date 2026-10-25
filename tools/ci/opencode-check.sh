#!/usr/bin/env bash
#
# opencode-check.sh - preflight checks for the OpenCode agent configuration.
#
# The issue-bugfix workflow runs `opencode run --agent issue-bugfix --auto`.
# If the agent is missing, has the wrong mode, references a missing prompt file, or
# still has an `ask` permission, the job fails (or hangs) only after a runner
# has been allocated. This script checks those conditions locally.
#
# Checks:
#   1. `opencode` exists and `opencode --version` works.
#   2. Either `opencode.json` defines `agent.<agent>` with the expected mode
#      and a valid prompt, or --agent-file names a Markdown agent whose
#      frontmatter declares the expected mode.
#   3. A `{file:...}` prompt exists relative to the repository root (JSON
#      agents only).
#   4. `opencode agent list` contains the exact `<agent> (<mode>)` line.
#   5. With --require-auto-approve: the JSON agent permission is effectively
#      `allow` (`permission: "allow"` or `"*": "allow"`) and contains no
#      remaining `ask` rules.
#   6. With --require-read-only: a Markdown agent's permission map explicitly
#      denies edit, bash, webfetch, websearch, task, question, and todowrite.
#   7. With --model: `opencode models` lists the model.
#
# No network requests are made by this script, but `opencode` itself may load
# provider metadata. Model discovery failures are warnings, not failures.
#
# Requires: bash, python3 (JSON parsing/output), and optionally timeout(1).

set -euo pipefail

PROG="$(basename "$0")"

AGENT="issue-bugfix"
AGENT_FILE=""
EXPECTED_MODE="primary"
MODEL=""
REQUIRE_AUTO=0
REQUIRE_READ_ONLY=0
JSON_OUTPUT=0
REPO=""

usage() {
  cat <<EOF
Usage:
  $PROG [options]

Preflight checks for the OpenCode agent used by the GitHub workflows.

Options:
  --agent NAME            Agent to validate (default: $AGENT).
  --agent-file PATH       Validate a Markdown agent definition instead of
                          \`opencode.json\`. Relative paths are resolved from
                          the repository root.
  --mode MODE             Expected agent mode (default: $EXPECTED_MODE).
                          Used for both JSON and Markdown agents.
  --model PROVIDER/MODEL  Verify the model appears in \`opencode models\`.
  --require-auto-approve  Require the JSON agent permission to resolve to
                          allow: either \`"permission": "allow"\` or
                          \`"*": "allow"\`, with no remaining \`ask\` rules.
  --require-read-only     Require a Markdown agent's permission map to deny
                          edit, bash, webfetch, websearch, task, question,
                          and todowrite. Requires --agent-file.
  --json                  Emit a machine-readable JSON report on stdout
                          instead of human-readable lines.
  --repo DIR              Repository root. Defaults to the git top-level
                          directory, then the current directory.
  -h, --help              Show this help and exit.

Exit status:
  0  no checks failed (warnings are allowed)
  1  one or more checks failed, or the report could not be produced
  2  usage error

Examples:
  $PROG
  $PROG --agent issue-bugfix --require-auto-approve
  $PROG --agent issue-bugfix --model opencode-go/deepseek-v4.1-flash --json
  $PROG --agent self-learn --agent-file .opencode/agents/self-learn.md \\
        --mode subagent --require-read-only
  $PROG --repo /path/to/checkout --require-auto-approve
EOF
}

say()  { printf '%s\n' "$*"; }
die()  { printf '%s: error: %s\n' "$PROG" "$*" >&2; exit 1; }
usage_error() {
  printf '%s: error: %s\n' "$PROG" "$*" >&2
  printf "Try '%s --help'.\n" "$PROG" >&2
  exit 2
}

need_value() {
  # need_value <flag> <remaining-args-count>
  if [ "$2" -lt 2 ]; then
    usage_error "$1 requires a value"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

run_with_timeout() {
  # run_with_timeout <seconds> <command> [args...]
  local seconds="$1"
  shift
  if require_cmd timeout; then
    timeout "$seconds" "$@"
  else
    "$@"
  fi
}

# ---------------------------------------------------------------- arg parsing

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --agent)
      need_value "$1" "$#"
      AGENT="$2"; shift 2
      ;;
    --agent=*)
      AGENT="${1#*=}"; shift
      ;;
    --agent-file)
      need_value "$1" "$#"
      AGENT_FILE="$2"; shift 2
      ;;
    --agent-file=*)
      AGENT_FILE="${1#*=}"; shift
      ;;
    --mode)
      need_value "$1" "$#"
      EXPECTED_MODE="$2"; shift 2
      ;;
    --mode=*)
      EXPECTED_MODE="${1#*=}"; shift
      ;;
    --model)
      need_value "$1" "$#"
      MODEL="$2"; shift 2
      ;;
    --model=*)
      MODEL="${1#*=}"; shift
      ;;
    --require-auto-approve)
      REQUIRE_AUTO=1; shift
      ;;
    --require-read-only)
      REQUIRE_READ_ONLY=1; shift
      ;;
    --json)
      JSON_OUTPUT=1; shift
      ;;
    --repo)
      need_value "$1" "$#"
      REPO="$2"; shift 2
      ;;
    --repo=*)
      REPO="${1#*=}"; shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      usage_error "unknown option: $1"
      ;;
    *)
      usage_error "unexpected argument: $1"
      ;;
  esac
done

if [ "$#" -gt 0 ]; then
  usage_error "unexpected argument: $1"
fi

[ -n "$AGENT" ] || usage_error "--agent must not be empty"
[ -n "$EXPECTED_MODE" ] || usage_error "--mode must not be empty"
if [ "$REQUIRE_READ_ONLY" -eq 1 ] && [ -z "$AGENT_FILE" ]; then
  usage_error "--require-read-only requires --agent-file"
fi
if [ "$REQUIRE_AUTO" -eq 1 ] && [ -n "$AGENT_FILE" ]; then
  usage_error "--require-auto-approve is only supported for opencode.json agents"
fi

# ------------------------------------------------------------------ repo root

if [ -z "$REPO" ]; then
  if REPO="$(git rev-parse --show-toplevel 2>/dev/null)" && [ -n "$REPO" ]; then
    :
  else
    REPO="$PWD"
  fi
fi

[ -d "$REPO" ] || usage_error "repository directory does not exist: $REPO"
REPO="$(cd "$REPO" && pwd -P)"
CONFIG_FILE="$REPO/opencode.json"
if [ -n "$AGENT_FILE" ]; then
  case "$AGENT_FILE" in
    /*) ;;
    *) AGENT_FILE="$REPO/$AGENT_FILE" ;;
  esac
  AGENT_FILE_DIR="$(dirname "$AGENT_FILE")"
  if [ -d "$AGENT_FILE_DIR" ]; then
    AGENT_FILE="$(cd "$AGENT_FILE_DIR" && pwd -P)/$(basename "$AGENT_FILE")"
  fi
fi

if ! require_cmd python3; then
  if [ "$JSON_OUTPUT" -eq 1 ]; then
    printf '%s\n' '{"agent":null,"agent_file":null,"mode":null,"repo":null,"model":null,"require_auto_approve":false,"require_read_only":false,"status":"FAIL","ok":false,"summary":{"pass":0,"fail":1,"warn":0},"checks":[{"name":"python3","status":"FAIL","detail":"python3 is required but was not found on PATH"}]}'
  else
    printf '[FAIL] python3: python3 is required but was not found on PATH\n' >&2
    printf '\nSummary: FAIL (0 passed, 1 failed, 0 warnings)\n' >&2
  fi
  exit 1
fi

# --------------------------------------------------------------- result store

TMP_ROOT="${TMPDIR:-/tmp}"
RESULTS_FILE="$(mktemp "$TMP_ROOT/opencode-check.XXXXXX")" || die "could not create a temporary file"
cleanup() {
  rm -f -- "$RESULTS_FILE" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

add_check() {
  # add_check <status> <name> <detail>
  local status="$1" name="$2" detail="${3:-}"
  # Keep the tab-separated record and the human line on one line each.
  detail="${detail//$'\r'/ }"
  detail="${detail//$'\n'/ }"
  detail="${detail//$'\t'/ }"

  printf '%s\t%s\t%s\n' "$name" "$status" "$detail" >> "$RESULTS_FILE"

  case "$status" in
    PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
    FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    WARN) WARN_COUNT=$((WARN_COUNT + 1)) ;;
  esac

  if [ "$JSON_OUTPUT" -eq 0 ]; then
    printf '[%s] %s: %s\n' "$status" "$name" "$detail"
  fi
}

# The config analyser is used twice: once for checks 2-4, and once for check 6
# (after `opencode agent list`, so the output stays in a readable order).
analyze_config() {
  local phase="$1"
  python3 - "$CONFIG_FILE" "$AGENT" "$REQUIRE_AUTO" "$REPO" "$EXPECTED_MODE" "$phase" <<'PY'
import json
import os
import re
import sys

config_path, agent, require_auto_arg, repo, expected_mode, phase = sys.argv[1:7]
require_auto = require_auto_arg == "1"
ALLOWED_ACTIONS = {"allow", "deny", "ask"}


def emit(name, status, detail=""):
    detail = " ".join(str(detail).replace("\t", " ").split())
    print("%s\t%s\t%s" % (name, status, detail))


def load_config():
    checks = []
    if not os.path.isfile(config_path):
        checks.append(("config-exists", "FAIL", "%s not found" % config_path))
        checks.append(("config-json", "FAIL", "skipped: config file missing"))
        return None, checks
    checks.append(("config-exists", "PASS", config_path))
    try:
        with open(config_path, "r", encoding="utf-8") as handle:
            config = json.load(handle)
    except Exception as exc:
        checks.append(("config-json", "FAIL", "invalid JSON: %s" % exc))
        return None, checks
    if not isinstance(config, dict):
        checks.append(("config-json", "FAIL", "top-level JSON value is not an object"))
        return None, checks
    checks.append(("config-json", "PASS", "valid JSON object"))
    return config, checks


def get_entry(config, checks):
    if config is None:
        checks.append(("agent-entry", "FAIL", "skipped: config unavailable"))
        return None
    agents = config.get("agent")
    if not isinstance(agents, dict):
        checks.append(("agent-entry", "FAIL", "'agent' is missing or not an object"))
        return None
    entry = agents.get(agent)
    if not isinstance(entry, dict):
        defined = ", ".join(sorted(str(key) for key in agents)) or "none"
        checks.append(
            ("agent-entry", "FAIL", "agent '%s' is not defined (defined: %s)" % (agent, defined))
        )
        return None
    checks.append(("agent-entry", "PASS", "agent '%s' is defined" % agent))
    return entry


def check_prompt(entry):
    prompt = entry.get("prompt")
    if prompt is None:
        return ("agent-prompt", "PASS", "no prompt configured")

    if isinstance(prompt, dict):
        if "file" not in prompt:
            return ("agent-prompt", "WARN", "prompt object has no 'file' key")
        path = prompt["file"]
        if not isinstance(path, str):
            return ("agent-prompt", "FAIL", "prompt.file is not a string")
    elif isinstance(prompt, str):
        stripped = prompt.strip()
        if stripped.startswith("{file:"):
            match = re.match(r"^\{file:(.*)\}$", stripped, re.S)
            if not match:
                return ("agent-prompt", "FAIL", "prompt has a malformed {file:...} reference")
            path = match.group(1).strip()
        else:
            return ("agent-prompt", "PASS", "inline prompt (no file reference)")
    else:
        return ("agent-prompt", "FAIL", "prompt is neither a string nor an object")

    if not path:
        return ("agent-prompt", "FAIL", "prompt file reference is empty")

    resolved = os.path.expanduser(path)
    if not os.path.isabs(resolved):
        resolved = os.path.join(repo, resolved)
    resolved = os.path.normpath(resolved)

    if not os.path.isfile(resolved):
        return ("agent-prompt", "FAIL", "prompt file not found: %s" % resolved)
    try:
        size = os.path.getsize(resolved)
    except OSError:
        size = -1
    if size == 0:
        return ("agent-prompt", "WARN", "prompt file is empty: %s" % resolved)
    return ("agent-prompt", "PASS", "prompt file exists: %s" % resolved)


def analyze_permission(permission):
    """Return (status, detail) for --require-auto-approve."""
    if permission is None:
        return (
            "FAIL",
            "agent has no permission block; cannot guarantee auto-approval",
        )

    asks = []
    invalid = []
    root = None

    def walk(value, path, inherited):
        if isinstance(value, str):
            if value == "ask":
                asks.append(path)
            elif value not in ALLOWED_ACTIONS:
                invalid.append("%s=%r" % (path, value))
            return

        if isinstance(value, dict):
            if "*" in value:
                default = value["*"]
                if isinstance(default, str):
                    if default == "ask":
                        asks.append("%s.*" % path)
                    elif default not in ALLOWED_ACTIONS:
                        invalid.append("%s.*=%r" % (path, default))
                else:
                    invalid.append("%s.* is not a string action" % path)
                    default = inherited
            else:
                default = inherited

            for key, sub_value in value.items():
                if key == "*":
                    continue
                walk(sub_value, "%s.%s" % (path, key), default)
            return

        invalid.append("%s is neither a string nor an object" % path)

    if isinstance(permission, str):
        root = permission
        if root not in ALLOWED_ACTIONS:
            invalid.append("permission=%r" % root)
    elif isinstance(permission, dict):
        if "*" in permission:
            root_value = permission["*"]
            if isinstance(root_value, str):
                root = root_value
            else:
                invalid.append('"*" is not a string action')
        for key, value in permission.items():
            if key == "*":
                continue
            walk(value, key, root)
    else:
        return ("FAIL", "permission is neither a string nor an object")

    if root == "ask" and "*" not in asks:
        asks.append("*")

    # Preserve order while removing duplicates.
    asks = list(dict.fromkeys(asks))

    if invalid:
        return ("FAIL", "invalid permission values: %s" % ", ".join(invalid))
    if root != "allow":
        detail = 'root permission is %r; expected "*": "allow" or permission "allow"' % root
        if asks:
            detail += "; explicit ask rules: %s" % ", ".join(asks)
        return ("FAIL", detail)
    if asks:
        return ("FAIL", "explicit ask rules can still prompt: %s" % ", ".join(asks))
    return ("PASS", 'root "*" is allow and no explicit ask rules remain')


if phase == "config":
    config, checks = load_config()
    entry = get_entry(config, checks)

    if entry is None:
        checks.append(("agent-mode", "FAIL", "skipped: agent entry unavailable"))
        checks.append(("agent-prompt", "FAIL", "skipped: agent entry unavailable"))
    else:
        mode = entry.get("mode")
        if mode == expected_mode:
            checks.append(("agent-mode", "PASS", "mode is %r" % mode))
        else:
            checks.append(("agent-mode", "FAIL", "mode is %r; expected %r" % (mode, expected_mode)))
        checks.append(check_prompt(entry))

    for check in checks:
        emit(*check)

elif phase == "permission":
    if not require_auto:
        emit("auto-approve", "WARN", "skipped: --require-auto-approve not set")
    else:
        config, checks = load_config()
        entry = get_entry(config, checks)
        if entry is None:
            emit("auto-approve", "FAIL", "skipped: agent entry unavailable")
        else:
            status, detail = analyze_permission(entry.get("permission"))
            emit("auto-approve", status, detail)

else:
    emit("auto-approve", "FAIL", "internal error: unknown phase %r" % phase)
PY
}

analyze_agent_file() {
  python3 - "$AGENT_FILE" "$AGENT" "$EXPECTED_MODE" "$REQUIRE_READ_ONLY" <<'PY'
import os
import sys

path, agent, expected_mode, require_read_only_arg = sys.argv[1:5]
require_read_only = require_read_only_arg == "1"
READ_ONLY_KEYS = ("edit", "bash", "webfetch", "websearch", "task", "question", "todowrite")


def emit(name, status, detail=""):
    detail = " ".join(str(detail).replace("\t", " ").split())
    print("%s\t%s\t%s" % (name, status, detail))


def unquote(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def parse_frontmatter(text):
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None, "missing opening '---'"
    values = {}
    permission = {}
    current = None
    closed = False
    for line_number, raw in enumerate(lines[1:], start=2):
        line = raw.rstrip()
        stripped = line.strip()
        if stripped == "---":
            closed = True
            break
        if not stripped or stripped.startswith("#"):
            continue
        if line[:1] in (" ", "\t"):
            if current != "permission":
                return None, "unexpected indented line %d" % line_number
            if ":" not in stripped:
                return None, "invalid permission line %d" % line_number
            key, value = stripped.split(":", 1)
            permission[unquote(key)] = unquote(value)
            continue
        if ":" not in stripped:
            return None, "invalid frontmatter line %d" % line_number
        key, value = stripped.split(":", 1)
        key = unquote(key)
        value = value.strip()
        current = key
        if key == "permission":
            if value:
                return None, "inline permission maps are not supported"
            values[key] = permission
        else:
            values[key] = unquote(value)
    if not closed:
        return None, "missing closing '---'"
    return values, None


if not os.path.isfile(path):
    emit("agent-file", "FAIL", "file not found: %s" % path)
    emit("agent-frontmatter", "FAIL", "skipped: agent file missing")
    emit("agent-mode", "FAIL", "skipped: agent file missing")
    if require_read_only:
        emit("agent-read-only", "FAIL", "skipped: agent file missing")
    sys.exit(0)

emit("agent-file", "PASS", path)
expected_name = agent + ".md"
basename = os.path.basename(path)
if basename == expected_name:
    emit("agent-file-name", "PASS", "filename matches agent name")
else:
    emit("agent-file-name", "FAIL", "filename is %r; expected %r" % (basename, expected_name))

try:
    with open(path, "r", encoding="utf-8") as handle:
        text = handle.read()
except Exception as exc:
    emit("agent-frontmatter", "FAIL", "could not read file: %s" % exc)
    sys.exit(0)

values, error = parse_frontmatter(text)
if error:
    emit("agent-frontmatter", "FAIL", error)
    emit("agent-mode", "FAIL", "skipped: frontmatter unavailable")
    if require_read_only:
        emit("agent-read-only", "FAIL", "skipped: frontmatter unavailable")
    sys.exit(0)

emit("agent-frontmatter", "PASS", "parsed YAML frontmatter")
description = values.get("description")
if description:
    emit("agent-description", "PASS", description)
else:
    emit("agent-description", "WARN", "no description in frontmatter")

mode = values.get("mode")
if mode == expected_mode:
    emit("agent-mode", "PASS", "mode is %r" % mode)
else:
    emit("agent-mode", "FAIL", "mode is %r; expected %r" % (mode, expected_mode))

if require_read_only:
    permission = values.get("permission")
    if not isinstance(permission, dict):
        emit("agent-read-only", "FAIL", "permission map is missing")
    else:
        allowed = []
        invalid = []
        for key in READ_ONLY_KEYS:
            action = permission.get(key)
            if action == "deny":
                allowed.append(key)
            elif action is None:
                invalid.append("%s is missing" % key)
            else:
                invalid.append("%s=%r" % (key, action))
        if invalid:
            emit("agent-read-only", "FAIL", "read-only permissions incomplete: %s" % ", ".join(invalid))
        else:
            emit("agent-read-only", "PASS", "permissions deny: %s" % ", ".join(allowed))

sys.exit(0)
PY
}

# --------------------------------------------------------------------- checks

if [ "$JSON_OUTPUT" -eq 0 ]; then
  printf 'opencode preflight\n'
  printf '  repo:  %s\n' "$REPO"
  printf '  agent: %s (%s)\n' "$AGENT" "$EXPECTED_MODE"
  if [ -n "$AGENT_FILE" ]; then
    printf '  file:  %s\n' "$AGENT_FILE"
  fi
  if [ -n "$MODEL" ]; then
    printf '  model: %s\n' "$MODEL"
  fi
  printf '\n'
fi

# 1. opencode CLI.
OPENCODE_OK=0
if require_cmd opencode; then
  OPENCODE_BIN="$(command -v opencode)"
  if VERSION_OUT="$(cd "$REPO" && run_with_timeout 60 opencode --version 2>&1)"; then
    VERSION_LINE="$(printf '%s\n' "$VERSION_OUT" | sed -n '1p' | tr -d '\r')"
    add_check PASS opencode-cli "found $OPENCODE_BIN (version ${VERSION_LINE:-unknown})"
    OPENCODE_OK=1
  else
    rc=$?
    add_check FAIL opencode-cli "found $OPENCODE_BIN but 'opencode --version' failed (exit $rc)"
  fi
else
  add_check FAIL opencode-cli "opencode not found on PATH"
fi

# 2-4. Agent definition: opencode.json or a Markdown agent file.
if [ -n "$AGENT_FILE" ]; then
  if FILE_OUT="$(analyze_agent_file)"; then
    while IFS=$'\t' read -r name status detail; do
      [ -n "${name:-}" ] || continue
      add_check "$status" "$name" "${detail:-}"
    done <<< "$FILE_OUT"
  else
    rc=$?
    add_check FAIL agent-file "agent file analysis failed (exit $rc)"
  fi
else
  if CONFIG_OUT="$(analyze_config config)"; then
    while IFS=$'\t' read -r name status detail; do
      [ -n "${name:-}" ] || continue
      add_check "$status" "$name" "${detail:-}"
    done <<< "$CONFIG_OUT"
  else
    rc=$?
    add_check FAIL config-json "config analysis failed (exit $rc)"
  fi
fi

# 5. Effective agent list, as seen by the CLI that the workflow will use.
if [ "$OPENCODE_OK" -eq 1 ]; then
  if AGENT_LIST_OUT="$(cd "$REPO" && run_with_timeout 60 opencode agent list 2>&1)"; then
    ESC="$(printf '\033')"
    AGENT_LIST_CLEAN="$(printf '%s\n' "$AGENT_LIST_OUT" | sed -e "s/${ESC}\\[[0-9;]*[A-Za-z]//g" -e 's/\r$//')"
    if printf '%s\n' "$AGENT_LIST_CLEAN" | awk -v want="$AGENT ($EXPECTED_MODE)" '
      {
        line = $0
        gsub(/^[ \t]+/, "", line)
        gsub(/[ \t]+$/, "", line)
        if (line == want) found = 1
      }
      END { exit(found ? 0 : 1) }
    '; then
      add_check PASS agent-list "'opencode agent list' contains '$AGENT ($EXPECTED_MODE)'"
    else
      add_check FAIL agent-list "'opencode agent list' does not contain '$AGENT ($EXPECTED_MODE)'"
    fi
  else
    rc=$?
    add_check FAIL agent-list "'opencode agent list' failed (exit $rc)"
  fi
else
  add_check WARN agent-list "skipped: opencode CLI unavailable"
fi

# 6. JSON auto-approve permissions. Markdown agents were checked above.
if [ -z "$AGENT_FILE" ]; then
  if PERMISSION_OUT="$(analyze_config permission)"; then
    while IFS=$'\t' read -r name status detail; do
      [ -n "${name:-}" ] || continue
      add_check "$status" "$name" "${detail:-}"
    done <<< "$PERMISSION_OUT"
  else
    rc=$?
    add_check FAIL auto-approve "permission analysis failed (exit $rc)"
  fi
fi

# 7. Requested model.
if [ -z "$MODEL" ]; then
  add_check WARN model-check "skipped: no --model supplied"
elif [ "$OPENCODE_OK" -ne 1 ]; then
  add_check WARN model-check "skipped: opencode CLI unavailable"
elif MODELS_OUT="$(cd "$REPO" && run_with_timeout 90 opencode models 2>&1)"; then
  ESC="$(printf '\033')"
  MODELS_CLEAN="$(printf '%s\n' "$MODELS_OUT" | sed -e "s/${ESC}\\[[0-9;]*[A-Za-z]//g" -e 's/\r$//')"
  if printf '%s\n' "$MODELS_CLEAN" | awk -v want="$MODEL" '
    {
      line = $0
      gsub(/^[ \t]+/, "", line)
      gsub(/[ \t]+$/, "", line)
      if (line == want || index(line, want " ") == 1) found = 1
    }
    END { exit(found ? 0 : 1) }
  '; then
    add_check PASS model-check "model '$MODEL' is listed by 'opencode models'"
  else
    add_check FAIL model-check "model '$MODEL' is not listed by 'opencode models'"
  fi
else
  rc=$?
  add_check WARN model-check "'opencode models' could not be used offline (exit $rc); not verified"
fi

# --------------------------------------------------------------------- report

STATUS="OK"
if [ "$FAIL_COUNT" -gt 0 ]; then
  STATUS="FAIL"
fi

if [ "$JSON_OUTPUT" -eq 1 ]; then
  python3 - "$RESULTS_FILE" "$AGENT" "$MODEL" "$REPO" "$STATUS" "$REQUIRE_AUTO" "$AGENT_FILE" "$EXPECTED_MODE" "$REQUIRE_READ_ONLY" <<'PY'
import json
import sys

(
    results_path,
    agent,
    model,
    repo,
    status,
    require_auto,
    agent_file,
    mode,
    require_read_only,
) = sys.argv[1:10]

checks = []
with open(results_path, "r", encoding="utf-8", errors="replace") as handle:
    for line in handle:
        line = line.rstrip("\n")
        if not line:
            continue
        parts = line.split("\t")
        name = parts[0]
        check_status = parts[1] if len(parts) > 1 else "FAIL"
        detail = "\t".join(parts[2:]) if len(parts) > 2 else ""
        checks.append({"name": name, "status": check_status, "detail": detail})

counts = {
    "pass": sum(1 for check in checks if check["status"] == "PASS"),
    "fail": sum(1 for check in checks if check["status"] == "FAIL"),
    "warn": sum(1 for check in checks if check["status"] == "WARN"),
}

print(
    json.dumps(
        {
            "agent": agent,
            "agent_file": agent_file or None,
            "mode": mode,
            "model": model or None,
            "repo": repo,
            "require_auto_approve": require_auto == "1",
            "require_read_only": require_read_only == "1",
            "status": status,
            "ok": status == "OK",
            "summary": counts,
            "checks": checks,
        },
        indent=2,
        sort_keys=False,
    )
)
PY
else
  printf '\nSummary: %s (%d passed, %d failed, %d warnings)\n' \
    "$STATUS" "$PASS_COUNT" "$FAIL_COUNT" "$WARN_COUNT"
  if [ "$STATUS" = "FAIL" ]; then
    printf 'Fix the FAIL entries above before running the workflow.\n'
  fi
fi

if [ "$STATUS" = "FAIL" ]; then
  exit 1
fi
exit 0
