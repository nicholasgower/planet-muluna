#!/usr/bin/env bash
# Check that the FUnit dependency downloader follows required dependencies
# transitively.
#
# This is a development helper for planet-muluna. It is not shipped with the mod.
#
# The planets mod set seeds the download with a hand-written list of planet mods.
# When one of those mods adds a new required dependency in a portal release, the
# downloader must download that dependency too, or Factorio refuses to load the
# whole mod set. This check exercises the resolution with a synthetic release
# graph, so it needs no network access or player token.
#
# Usage:
#   tools/ci/funit-download-deps-check.sh
#
# Exit status:
#   0  the downloader resolves the required dependency closure
#   1  the closure is wrong, or the resolver is missing
#   2  usage error
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)" ||
  {
    echo "funit-download-deps-check.sh: not inside a git work tree: $SCRIPT_DIR" >&2
    exit 2
  }

case "${1:-}" in
  -h | --help)
    sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  "") ;;
  *)
    echo "funit-download-deps-check.sh: unexpected argument: $1" >&2
    exit 2
    ;;
esac

REPO_DIR="$REPO_DIR" exec python3 - <<'PY'
import importlib.util
import os
import sys
from pathlib import Path

sys.dont_write_bytecode = True

repo = Path(os.environ["REPO_DIR"])
path = repo / ".github" / "funit" / "download_mods.py"

spec = importlib.util.spec_from_file_location("muluna_funit_download_mods", path)
if spec is None or spec.loader is None:
    print(f"FAIL: cannot load {path}", file=sys.stderr)
    raise SystemExit(1)
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)

expand = getattr(module, "expand_required_dependencies", None)
if expand is None:
    print(
        "FAIL: download_mods.py does not resolve required dependencies "
        "transitively (no expand_required_dependencies)",
        file=sys.stderr,
    )
    raise SystemExit(1)

failures = []


def check(name, condition, detail):
    if condition:
        print(f"PASS: {name}")
    else:
        failures.append(name)
        print(f"FAIL: {name}: {detail}", file=sys.stderr)


parse_dependency = getattr(module, "parse_dependency", None)
if parse_dependency is None:
    print(
        "FAIL: download_mods.py has no parse_dependency",
        file=sys.stderr,
    )
    raise SystemExit(1)

# Mod names may contain spaces ("Flare Stack" is a real portal mod), so the
# parser must keep the whole name and separate the version requirement.
for spec, expected in [
    ("Flare Stack >= 4.0.0", ("", "Flare Stack", ">= 4.0.0")),
    ("Flare Stack", ("", "Flare Stack", "")),
    ("+ elevated-pipes", ("+", "elevated-pipes", "")),
    ("? Muria", ("?", "Muria", "")),
    ("(?) space_age_galore", ("(?)", "space_age_galore", "")),
    ("base >= 2.1.22", ("", "base", ">= 2.1.22")),
    ("foo>=1.0", ("", "foo", ">=1.0")),
]:
    parsed = parse_dependency(spec)
    check(
        f"parse dependency {spec!r}",
        parsed == expected,
        f"expected {expected}, got {parsed}",
    )


def release(*dependencies):
    return {"info_json": {"dependencies": list(dependencies)}}


# The real failure: Paracelsin 1.13 added Crystalline-Library and
# Return-Inserter as required dependencies after the mod set seeds were written.
planets = {
    "Paracelsin": release(
        "base",
        "space-age >= 2.1.20",
        "Paracelsin-Graphics = 1.13.0",
        "PlanetsLib >= 1.21.3",
        "SolarMatrix",
        "Crystalline-Library",
        "Accumulator-V2",
        "+ elevated-pipes",
        "Return-Inserter >= 1.0.1",
        "(?) space_age_galore",
        "? Muria",
        "! incompatible-potato",
    ),
    "Paracelsin-Graphics": release("base", "space-age"),
    "PlanetsLib": release("base >= 2.1.22"),
    "SolarMatrix": release("base"),
    "Accumulator-V2": release("base >= 2.1"),
    "Crystalline-Library": release("base", "space-age", "PlanetsLib", "+ should-not-load"),
    "Return-Inserter": release("base", "space-age"),
}
seeds = [
    "Paracelsin",
    "Paracelsin-Graphics",
    "PlanetsLib",
    "SolarMatrix",
    "Accumulator-V2",
]
expected = seeds + ["Crystalline-Library", "Return-Inserter"]

calls = []


def planets_release_for(name):
    calls.append(name)
    return planets[name]


resolved = expand(seeds, planets_release_for)
check(
    "planets closure",
    resolved == expected,
    f"expected {expected}, got {resolved}",
)
check(
    "recommended and optional dependencies are not followed",
    "elevated-pipes" not in resolved
    and "should-not-load" not in resolved
    and "Muria" not in resolved
    and "incompatible-potato" not in resolved,
    f"unexpected optional/recommended mod in {resolved}",
)
check(
    "each release is resolved once",
    len(calls) == len(set(name.lower() for name in calls)),
    f"resolved releases more than once: {calls}",
)

# A cycle in the required graph must terminate, and names are case-insensitive.
cycle = {
    "Cycle-A": release("Cycle-B"),
    "Cycle-B": release("cycle-a", "Cycle-C"),
    "Cycle-C": release("base"),
}
resolved = expand(["Cycle-A"], lambda name: cycle[name])
check(
    "required dependency cycles terminate",
    resolved == ["Cycle-A", "Cycle-B", "Cycle-C"],
    f"got {resolved}",
)

# Built-in and locally packaged mods are never downloaded.
local = {
    "Seed": release("base", "space-age", "planet-muluna", "funit", "Needed"),
    "Needed": release("base"),
}
resolved = expand(["Seed"], lambda name: local[name])
check(
    "built-in and local mods are skipped",
    resolved == ["Seed", "Needed"],
    f"got {resolved}",
)

if failures:
    print(f"funit-download-deps-check.sh: {len(failures)} check(s) failed", file=sys.stderr)
    raise SystemExit(1)

print("funit-download-deps-check.sh: all checks passed")
PY
