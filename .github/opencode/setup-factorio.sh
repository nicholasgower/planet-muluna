#!/usr/bin/env bash
# Prepare a headless Factorio install and the FUnit dependency mods.
#
# Usage:
#   FACTORIO_PLAYER_TOKEN=... ./.github/opencode/setup-factorio.sh
#
# The script is used by .github/workflows/opencode-bugfix.yml before OpenCode
# starts, so the agent can run test-mods/planet-muluna-funit/run.sh without
# installing anything itself. It writes FACTORIO_BIN and FACTORIO_MODS to
# $GITHUB_ENV when running in GitHub Actions.
#
# Environment:
#   FACTORIO_PLAYER_TOKEN  Factorio player token (required unless reusing an
#                          existing FACTORIO_BIN/FACTORIO_MODS pair)
#   FACTORIO_USERNAME      Mod portal username (default: MeteorSwarm)
#   FACTORIO_VERSION       Factorio version or "latest" (default: latest)
#   FUNIT_COMMIT           Pinned FUnit revision (matches .github/workflows/funit.yml)
#   RUNNER_TEMP            Scratch root (default: /tmp/opencode)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FACTORIO_VERSION="${FACTORIO_VERSION:-latest}"
FUNIT_COMMIT="${FUNIT_COMMIT:-b69c2f277a467726e3a8c555d48df5b647ec5a64}"
WORK_ROOT="${RUNNER_TEMP:-/tmp/opencode}/muluna-opencode"
FACTORIO_DIR="$WORK_ROOT/factorio"
MODS_DIR="$WORK_ROOT/mods"
FUNIT_SRC="$WORK_ROOT/funit-src"

# Local development shortcut: use an install and mod directory that are
# already present instead of downloading them again.
if [[ -n "${FACTORIO_BIN:-}" && -n "${FACTORIO_MODS:-}" \
      && -x "$FACTORIO_BIN" && -d "$FACTORIO_MODS" ]]; then
  echo "Using existing Factorio install: $FACTORIO_BIN"
  echo "Using existing mod directory:  $FACTORIO_MODS"
  exit 0
fi

if [[ -z "${FACTORIO_PLAYER_TOKEN:-}" ]]; then
  echo "FACTORIO_PLAYER_TOKEN is required to download the FUnit dependencies." >&2
  echo "It must be a player token from Factorio's player-data.json, not the mod-portal upload key." >&2
  exit 1
fi

mkdir -p "$WORK_ROOT" "$MODS_DIR"

# ---------------------------------------------------------------------------
# Factorio
# ---------------------------------------------------------------------------
# factorio.com serves a public headless tarball for the requested release. The
# "latest" alias tracks the newest experimental build, the same policy as the
# factoriotools/factorio:latest image used by the FUnit workflow. The tarball
# includes the Space Age expansion data, so no DLC download is needed.
if [[ ! -x "$FACTORIO_DIR/bin/x64/factorio" ]]; then
  echo "Downloading Factorio $FACTORIO_VERSION (headless)..."
  archive="$WORK_ROOT/factorio-headless.tar.xz"
  curl -fsSL "https://factorio.com/get-download/${FACTORIO_VERSION}/headless/linux64" -o "$archive"
  rm -rf "$FACTORIO_DIR"
  tar -xJf "$archive" -C "$WORK_ROOT"
  rm -f "$archive"
fi

FACTORIO_BIN="$FACTORIO_DIR/bin/x64/factorio"
if [[ ! -x "$FACTORIO_BIN" ]]; then
  echo "Factorio binary is missing after extraction: $FACTORIO_BIN" >&2
  exit 1
fi
FACTORIO_REAL_VERSION="$("$FACTORIO_BIN" --version | sed -n 's/^Version: \([^ ]*\).*/\1/p' | head -n 1)"
echo "Factorio: $FACTORIO_REAL_VERSION"

# ---------------------------------------------------------------------------
# Dependency mods
# ---------------------------------------------------------------------------
# Reuse the FUnit dependency resolver so versions stay in sync with info.json
# and the test companion mod. Extra downloaded mods are harmless: the FUnit
# runner links only the mods it needs into its own scratch mod directory.
echo "Resolving required and recommended dependencies..."
USERNAME="${FACTORIO_USERNAME:-MeteorSwarm}" \
TOKEN="$FACTORIO_PLAYER_TOKEN" \
FACTORIO_BIN="$FACTORIO_BIN" \
python3 "$REPO_DIR/.github/funit/download_mods.py" \
  --info "$REPO_DIR/info.json" \
  --test-info "$REPO_DIR/test-mods/planet-muluna-funit/info.json" \
  --output-dir "$MODS_DIR" \
  --mod-list "$WORK_ROOT/funit-mod-list.json" \
  --factorio-version "$FACTORIO_VERSION" \
  --skip-local-check

# The FUnit runner expects PlanetsLib and muluna-graphics as directories (it
# links them with `link_mod`), while the downloader fetches them as zips.
extract_dir_mod() {
  local name="$1"
  local zip
  zip="$(find "$MODS_DIR" -maxdepth 1 -type f -name "${name}_*.zip" | sort -V | tail -n 1)"
  if [[ -z "$zip" ]]; then
    echo "No downloaded zip found for $name" >&2
    exit 1
  fi

  local tmp="$WORK_ROOT/extract-$name"
  local inner
  rm -rf "$tmp" "$MODS_DIR/$name"
  mkdir -p "$tmp"
  unzip -q "$zip" -d "$tmp"
  inner="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  if [[ -z "$inner" ]]; then
    echo "$zip does not contain a mod directory" >&2
    exit 1
  fi
  mv "$inner" "$MODS_DIR/$name"
  rm -rf "$tmp"
  echo "  $name -> $MODS_DIR/$name"
}

extract_dir_mod PlanetsLib
extract_dir_mod muluna-graphics

# FUnit is not distributed through the mod portal. Package the same pinned
# revision the FUnit CI workflow uses.
if ! compgen -G "$MODS_DIR/funit_*.zip" >/dev/null; then
  echo "Packaging FUnit at $FUNIT_COMMIT..."
  rm -rf "$FUNIT_SRC"
  git clone --depth 1 https://gitlab.com/jfletcher94/funit.git "$FUNIT_SRC"
  git -C "$FUNIT_SRC" fetch --depth 1 origin "$FUNIT_COMMIT"
  git -C "$FUNIT_SRC" checkout --detach "$FUNIT_COMMIT"
  funit_version="$(python3 -c \
    'import json, sys; print(json.load(open(sys.argv[1]))["version"])' \
    "$FUNIT_SRC/funit/info.json")"
  test -n "$funit_version"
  (cd "$FUNIT_SRC" && zip -qr "$MODS_DIR/funit_${funit_version}.zip" funit)
fi

# ---------------------------------------------------------------------------
# Export for later steps
# ---------------------------------------------------------------------------
export FACTORIO_BIN FACTORIO_MODS="$MODS_DIR"
if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "FACTORIO_BIN=$FACTORIO_BIN"
    echo "FACTORIO_MODS=$FACTORIO_MODS"
    echo "FACTORIO_REAL_VERSION=$FACTORIO_REAL_VERSION"
  } >> "$GITHUB_ENV"
fi

echo
echo "Headless Factorio is ready."
echo "  FACTORIO_BIN=$FACTORIO_BIN"
echo "  FACTORIO_MODS=$FACTORIO_MODS"
echo "  run: ./test-mods/planet-muluna-funit/run.sh"
