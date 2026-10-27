#!/usr/bin/env python3
"""Download the required and recommended dependencies for Muluna's FUnit run.

The Factorio mod portal requires a *player* token (the `service-token` from
player-data.json), not a ModPortal upload API key, to download mod files.  The
workflow passes that token in FACTORIO_PLAYER_TOKEN / TOKEN.

Dependencies are read from info.json and from the companion test mod's
info.json, so this list stays in sync with the mod's dependency declarations:

  * no prefix  -> required
  * "+"         -> recommended
  * "?"         -> optional (skipped)
  * "(?)"       -> optional and hidden (skipped)
  * "!"         -> incompatible (skipped)

The paid Space Age mods are built into the factorio-docker image, and the main
mod, test mod and FUnit are packaged from this repository.  Everything else is
resolved to the newest release for the target Factorio version and downloaded
into the test artifacts directory.

The target version may be a concrete version (e.g. "2.1.22") or one of the
release-channel labels:

  * "latest" -> newest experimental release (the factorio-docker "latest" tag)
  * "stable" -> newest stable release (the factorio-docker "stable" tag)

Labels are resolved from the game installed in this environment when possible
and from factorio.com's matching release channel otherwise.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

PORTAL = "https://mods.factorio.com"
FACTORIO_RELEASES = "https://factorio.com/api/latest-releases"
USER_AGENT = "planet-muluna-funit-ci/1.0"

# Labels accepted in place of a concrete Factorio version, mapped to the
# factorio.com release channel they track. The docker image publishes "latest"
# as the newest release (experimental while one is in testing) and "stable" as
# the newest stable build.
VERSION_LABELS = {"latest": "experimental", "stable": "stable"}

BUILTIN_MODS = ["base", "elevated-rails", "quality", "recycler", "space-age"]
LOCAL_MODS = ["planet-muluna", "planet-muluna-funit", "funit"]

# Named mod sets used by the FUnit matrix. Each list is the seed mod plus the
# dependencies that are not already declared by info.json or the test mod.
# Keep this in sync with test-mods/planet-muluna-funit/run.sh and K2SO's
# info.json; a new required dependency will fail the run with a missing mod
# instead of being silently skipped.
MODSETS = {
    "vanilla": {"add": [], "disable": []},
    "aai": {"add": ["aai-industry"], "disable": []},
    "k2so": {
        "add": [
            "Krastorio2-spaced-out",
            "Krastorio2",
            "Krastorio2Assets",
            "Krastorio2MenuSimulations",
            "k2so-assets",
            "ChangeInserterDropLane",
        ],
        "disable": [],
    },
    # Quality is optional for both space-age and Muluna. Disable it to keep the
    # no-quality code paths covered. It must stay in mod-list.json with
    # enabled=false: Factorio auto-enables an installed mod that an enabled mod
    # recommends, so omitting it is not enough.
    "no-quality": {"add": [], "disable": ["quality"]},
}


def parse_dependency(spec: str):
    """Return (prefix, name, requirement) for a Factorio dependency string."""
    spec = spec.strip()
    if not spec:
        return None

    prefix = ""
    if spec.startswith("(?)"):
        prefix = "(?)"
        spec = spec[3:].strip()
    elif spec[0] in "!?+":
        prefix = spec[0]
        spec = spec[1:].strip()

    match = re.match(r"([A-Za-z0-9_.-]+)", spec)
    if not match:
        return None
    return prefix, match.group(1), spec[match.end() :].strip()


def version_tuple(value: str):
    return tuple(int(part) for part in re.findall(r"\d+", value))


def version_ge(a: str, b: str) -> bool:
    left = version_tuple(a)
    right = version_tuple(b)
    width = max(len(left), len(right))
    return left + (0,) * (width - len(left)) >= right + (0,) * (width - len(right))


def installed_factorio_version():
    """Return the version of the Factorio install in this environment, if any.

    The FUnit jobs run inside the factorio-docker image, and each image tag
    selects whichever build it ships ("stable" or "latest"). Reading the
    installed version keeps the mod selection in sync with the game that will
    load the mods, even if factorio.com has already moved on to a newer release.
    """
    candidates = []
    explicit = os.environ.get("FACTORIO_BIN")
    if explicit:
        candidates.append(Path(explicit))
    on_path = shutil.which("factorio")
    if on_path:
        candidates.append(Path(on_path))
    candidates.append(Path("/opt/factorio/bin/x64/factorio"))

    for binary in candidates:
        if not binary.is_file():
            continue

        # <install>/bin/x64/factorio -> <install>/data/base/info.json
        data_info = binary.parent.parent.parent / "data" / "base" / "info.json"
        try:
            version = json.loads(data_info.read_text()).get("version")
        except (OSError, ValueError):
            version = None
        if isinstance(version, str) and version:
            return version

        try:
            result = subprocess.run(
                [str(binary), "--version"],
                capture_output=True,
                text=True,
                timeout=30,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired):
            continue
        match = re.search(r"Version:\s*(\d+\.\d+\.\d+)", result.stdout)
        if match:
            return match.group(1)

    return None


def channel_version(channel: str) -> str:
    """Resolve a release channel from factorio.com's latest-releases API."""
    data = fetch_json(FACTORIO_RELEASES)
    releases = data.get(channel) or {}
    for key in ("headless", "alpha", "expansion", "demo"):
        version = releases.get(key)
        if version:
            return str(version)
    raise SystemExit(f"error: factorio.com lists no {channel} Factorio version")


def resolve_version(label: str) -> str:
    """Turn a version label such as "latest" or "stable" into a version number."""
    channel = VERSION_LABELS.get(label.strip().lower())
    if channel is None:
        return label

    version = installed_factorio_version()
    source = "installed game"
    if not version:
        version = channel_version(channel)
        source = f"factorio.com {channel} channel"

    print(f"Resolved Factorio version '{label}' to {version} ({source}).")
    return version


def base_requirement_ok(info: dict, target: str) -> bool:
    """Check a release's `base >= x` constraint against the target version."""
    for spec in info.get("dependencies", []):
        parsed = parse_dependency(spec)
        if not parsed:
            continue
        _, name, requirement = parsed
        if name != "base" or not requirement:
            continue

        match = re.match(r"(>=|<=|>|<|=)?\s*(\d[\w.]*)", requirement)
        if not match:
            continue
        operator = match.group(1) or ">="
        required = match.group(2)

        if operator in (">=", "=") and not version_ge(target, required):
            return False
        if operator == ">" and not version_tuple(target) > version_tuple(required):
            return False
        if operator == "<=" and not version_ge(required, target):
            return False
        if operator == "<" and not version_tuple(target) < version_tuple(required):
            return False
    return True


def release_compatible(release: dict, target: str) -> bool:
    info = release.get("info_json") or {}
    if release.get("deprecated"):
        return False

    factorio_version = info.get("factorio_version")
    if factorio_version:
        target_major_minor = ".".join(target.split(".")[:2])
        release_major_minor = ".".join(str(factorio_version).split(".")[:2])
        if target_major_minor != release_major_minor:
            return False

    return base_requirement_ok(info, target)


def fetch_json(url: str):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def select_release(name: str, target: str) -> dict:
    data = fetch_json(f"{PORTAL}/api/mods/{urllib.parse.quote(name)}/full")
    for release in reversed(data.get("releases") or []):
        if release_compatible(release, target):
            return release
    raise SystemExit(f"error: no release of {name} is compatible with Factorio {target}")


def check_credentials(username: str, token: str) -> None:
    """Fail early with an actionable message if the token cannot download mods."""
    query = urllib.parse.urlencode({"username": username, "token": token})
    try:
        fetch_json(f"{PORTAL}/api/bookmarks?{query}")
    except urllib.error.HTTPError as error:
        if error.code in (401, 403):
            raise SystemExit(
                "error: the Factorio mod portal rejected the credentials "
                f"(HTTP {error.code}).\n"
                "FACTORIO_PLAYER_TOKEN must be a player token from "
                "player-data.json (factorio.com account), not a ModPortal "
                "upload API key. The existing FACTORIO_TOKEN secret is an "
                "upload key and cannot download mods."
            ) from error
        raise


def collect_dependencies(info_paths: list[Path], extra: list[str] | None = None) -> list[str]:
    names: list[str] = []
    seen: set[str] = set()

    for info_path in info_paths:
        data = json.loads(info_path.read_text())
        for spec in data.get("dependencies", []):
            parsed = parse_dependency(spec)
            if not parsed:
                continue
            prefix, name, _ = parsed
            if prefix in ("!", "?", "(?)"):
                continue
            if name in BUILTIN_MODS or name in LOCAL_MODS:
                continue
            key = name.lower()
            if key not in seen:
                seen.add(key)
                names.append(name)

    for name in extra or []:
        if name.lower() in {builtin.lower() for builtin in BUILTIN_MODS + LOCAL_MODS}:
            continue
        key = name.lower()
        if key not in seen:
            seen.add(key)
            names.append(name)

    return names


def download_release(name: str, release: dict, username: str, token: str, output_dir: Path) -> str:
    file_name = release.get("file_name") or f"{name}_{release.get('version', 'unknown')}.zip"
    download_url = release.get("download_url")
    if not download_url:
        raise SystemExit(f"error: release metadata for {name} has no download_url")

    destination = output_dir / file_name
    query = urllib.parse.urlencode({"username": username, "token": token})
    request = urllib.request.Request(
        f"{PORTAL}{download_url}?{query}", headers={"User-Agent": USER_AGENT}
    )

    try:
        with urllib.request.urlopen(request, timeout=600) as response, destination.open("wb") as handle:
            shutil.copyfileobj(response, handle, length=1024 * 1024)
    except urllib.error.HTTPError as error:
        destination.unlink(missing_ok=True)
        body = error.read(200)
        raise SystemExit(
            f"error: download failed for {name} (HTTP {error.code}): {body!r}\n"
            "Check that FACTORIO_PLAYER_TOKEN is a valid player token."
        ) from error

    if destination.stat().st_size == 0:
        destination.unlink(missing_ok=True)
        raise SystemExit(f"error: downloaded an empty file for {name}")
    try:
        with zipfile.ZipFile(destination) as archive:
            if not any(name.endswith("info.json") for name in archive.namelist()):
                raise SystemExit(f"error: {file_name} does not contain an info.json")
    except zipfile.BadZipFile as error:
        destination.unlink(missing_ok=True)
        raise SystemExit(
            f"error: {file_name} is not a mod zip (got an HTML/error page?)"
        ) from error

    print(
        f"  {name} {release.get('version', '?')} -> {file_name} "
        f"({destination.stat().st_size // 1024} KiB)"
    )
    return name


def write_mod_list(
    path: Path, downloaded: list[str], disable: list[str] | None = None
) -> None:
    disabled = {name.lower() for name in (disable or [])}
    ordered = list(BUILTIN_MODS) + list(LOCAL_MODS) + sorted(
        downloaded, key=str.lower
    )
    seen: set[str] = set()
    mods = []
    for name in ordered:
        key = name.lower()
        if key in seen:
            continue
        seen.add(key)
        mods.append({"name": name, "enabled": key not in disabled})

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"mods": mods}, indent=2) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--info", default="info.json", type=Path)
    parser.add_argument(
        "--test-info",
        default=Path(
            os.environ.get("TEST_MOD_DIR", "test-mods/planet-muluna-funit")
        )
        / "info.json",
        type=Path,
    )
    parser.add_argument(
        "--output-dir",
        default=Path("artifacts") / os.environ.get("MOD_NAME", "planet-muluna"),
        type=Path,
    )
    parser.add_argument(
        "--mod-list",
        default=None,
        type=Path,
        help="defaults to <output-dir>/scenarios/__funit__muluna/mod-list.json",
    )
    parser.add_argument(
        "--factorio-version",
        default=os.environ.get("FACTORIO_VERSION", "2.1.22"),
        help=(
            "target Factorio version, or a release label: 'latest' for the "
            "installed/experimental build, 'stable' for the installed/stable build"
        ),
    )
    parser.add_argument(
        "--modset",
        default="vanilla",
        choices=sorted(MODSETS),
        help=(
            "mod set to download and enable: 'vanilla' (default), 'aai' "
            "(vanilla plus aai-industry), 'k2so' (Krastorio 2 Spaced Out and "
            "its dependencies), or 'no-quality' (vanilla without quality)"
        ),
    )
    parser.add_argument(
        "--skip-local-check",
        action="store_true",
        help=(
            "do not require the locally packaged planet-muluna, "
            "planet-muluna-funit and funit zips (used when only the "
            "dependency mods are wanted)"
        ),
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    username = (
        os.environ.get("USERNAME")
        or os.environ.get("FACTORIO_USERNAME")
        or "MeteorSwarm"
    )
    token = (
        os.environ.get("TOKEN")
        or os.environ.get("FACTORIO_PLAYER_TOKEN")
        or os.environ.get("FACTORIO_TOKEN")
        or ""
    )

    modset = MODSETS[args.modset]
    dependencies = collect_dependencies(
        [args.info, args.test_info], extra=modset["add"]
    )
    factorio_version = resolve_version(args.factorio_version)

    if not args.dry_run:
        if not token:
            raise SystemExit(
                "error: no download token. Set FACTORIO_PLAYER_TOKEN to a player "
                "token from player-data.json."
            )
        check_credentials(username, token)

    print(f"Required/recommended dependencies for Factorio {factorio_version}:")
    print(f"  modset: {args.modset}")
    print("  " + ", ".join(dependencies))

    releases = []
    for name in dependencies:
        release = select_release(name, factorio_version)
        releases.append((name, release))
        print(f"  {name}: {release.get('version', '?')} ({release.get('file_name', '?')})")

    if args.dry_run:
        return 0

    args.output_dir.mkdir(parents=True, exist_ok=True)

    downloaded: list[str] = []
    for name, release in releases:
        for stale in args.output_dir.glob(f"{name}_*.zip"):
            stale.unlink()
        downloaded.append(download_release(name, release, username, token, args.output_dir))

    # The three locally packaged mods come from the build job.
    if not args.skip_local_check:
        for name in LOCAL_MODS:
            if not list(args.output_dir.glob(f"{name}_*.zip")):
                raise SystemExit(
                    f"error: expected a locally packaged {name}_*.zip in {args.output_dir}"
                )

    mod_list = args.mod_list or (
        args.output_dir / "scenarios" / "__funit__muluna" / "mod-list.json"
    )
    write_mod_list(mod_list, downloaded, disable=modset["disable"])
    print(f"Wrote mod list to {mod_list}")
    print("Downloaded mods:")
    for name in sorted(downloaded, key=str.lower):
        print(f"  {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
