#!/usr/bin/env bash
# Syntax-check Lua files changed in this worktree (or named on the command line).
#
# This is a development helper for planet-muluna. It is not shipped with the mod.
#
# Usage:
#   tools/ci/lua-check.sh                  # changed Lua files + git diff --check
#   tools/ci/lua-check.sh --all            # every tracked/untracked Lua file
#   tools/ci/lua-check.sh path/to/file.lua # explicit files
#   tools/ci/lua-check.sh --no-diff-check  # syntax only
#
# LUAC may select a specific interpreter, for example LUAC=luac5.2.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

ALL=0
DIFF_CHECK=1
FILES=()

usage() {
  sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while (($# > 0)); do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --all)
      ALL=1
      shift
      ;;
    --no-diff-check)
      DIFF_CHECK=0
      shift
      ;;
    --)
      shift
      break
      ;;
    -* )
      echo "lua-check.sh: unknown option: $1" >&2
      exit 2
      ;;
    *)
      FILES+=("$1")
      shift
      ;;
  esac
done

if (($# > 0)); then
  FILES+=("$@")
fi

if [[ -n "${LUAC:-}" ]]; then
  LUAC_BIN="$LUAC"
elif command -v luac5.2 >/dev/null 2>&1; then
  LUAC_BIN="luac5.2"
elif command -v luac >/dev/null 2>&1; then
  LUAC_BIN="luac"
else
  echo "lua-check.sh: no Lua compiler found; set LUAC or install luac5.2." >&2
  exit 2
fi

if ((${#FILES[@]} == 0)); then
  if (( ALL == 1 )); then
    mapfile -t FILES < <(
      git -C "$REPO_DIR" ls-files --cached --others --exclude-standard -- '*.lua' |
        sort -u
    )
  else
    mapfile -t FILES < <(
      {
        git -C "$REPO_DIR" diff --name-only --diff-filter=ACMRTUXB -- '*.lua'
        git -C "$REPO_DIR" diff --cached --name-only --diff-filter=ACMRTUXB -- '*.lua'
        git -C "$REPO_DIR" ls-files --others --exclude-standard -- '*.lua'
      } | sort -u
    )
  fi
fi

checked=0
failed=0
for file in "${FILES[@]}"; do
  [[ -n "$file" ]] || continue
  path="$file"
  if [[ "$path" != /* ]]; then
    path="$REPO_DIR/$path"
  fi
  if [[ ! -f "$path" ]]; then
    echo "lua-check.sh: skipping missing file: $file" >&2
    continue
  fi
  checked=$((checked + 1))
  if ! "$LUAC_BIN" -p "$path"; then
    echo "lua-check.sh: syntax error: $file" >&2
    failed=$((failed + 1))
  fi
done

if (( DIFF_CHECK == 1 )); then
  if ! git -C "$REPO_DIR" diff --check; then
    failed=$((failed + 1))
  fi
fi

if (( failed > 0 )); then
  echo "lua-check.sh: $failed check(s) failed ($checked Lua file(s) scanned)." >&2
  exit 1
fi

echo "lua-check.sh: $checked Lua file(s) OK."
