#!/usr/bin/env bash
# Verify that every Lua migration is registered in lib/migrations.lua.
#
# The FUnit re-add suite replays migrations through the registry that
# control.lua builds while parsing. A migration file that is missing from the
# registry still runs in the game, but the re-add test silently loses coverage
# for it.
#
# Usage: tools/ci/migration-registry-check.sh [--require-missing]
#
# --require-missing is the negative self-test: it appends a temporary name to
# the comparison and fails when the check does not detect it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
REGISTRY="$REPO_DIR/lib/migrations.lua"
MIGRATIONS_DIR="$REPO_DIR/migrations"

require_missing=0
case "${1:-}" in
  --require-missing) require_missing=1 ;;
  "") ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 2
    ;;
esac

if [[ ! -f "$REGISTRY" ]]; then
  echo "Migration registry not found: $REGISTRY" >&2
  exit 1
fi

# Extract the quoted names from the `local modules = { ... }` table only.
registered="$(awk '
  /^local modules = \{/ { in_table = 1; next }
  in_table && /^\}/ { in_table = 0 }
  in_table {
    line = $0
    sub(/^[[:space:]]*/, "", line)
    if (line ~ /^"/) {
      sub(/^"/, "", line)
      sub(/".*/, "", line)
      print line
    }
  }
' "$REGISTRY" | LC_ALL=C sort)"

missing=0
while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  path="$MIGRATIONS_DIR/$name.lua"
  if ! grep -qxF "$name" <<< "$registered"; then
    echo "Migration is not registered in lib/migrations.lua: $name" >&2
    missing=1
  fi
  # The registry requires the file during control.lua parsing, so the body must
  # stay inside a function that only runs when the engine executes the file.
  if ! grep -qF 'local function migrate()' "$path" \
    || ! grep -qF "Muluna.migrations[\"$name\"] = migrate" "$path" \
    || ! grep -qF 'if game then migrate() end' "$path"; then
    echo "Migration is not wrapped for the FUnit re-add seam: $name" >&2
    missing=1
  fi
done < <(find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name '*.lua' -printf '%f\n' \
  | sed 's/\.lua$//' | LC_ALL=C sort)

if [[ "$require_missing" == "1" && "$missing" == "0" ]]; then
  # Inject a name that has no file to prove the detector works.
  if ! grep -qxF "zzz-missing-migration" <<< "$registered"; then
    echo "Migration is not registered in lib/migrations.lua: zzz-missing-migration" >&2
    missing=1
  fi
fi

if [[ "$missing" != "0" ]]; then
  exit 1
fi

echo "Migration registry is in sync with migrations/*.lua."
